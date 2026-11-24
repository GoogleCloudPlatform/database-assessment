# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License").
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Helper functions for Oracle Estate Explorer (OEE) integration.
# This script is sourced by collect-data.sh / dma_batch_run.sh and is not directly executable.
# Supports unmodified upstream oee_group_extract-SA.sh v5.1 and v6.1.1 standalone scripts.
#

# In-memory credential store (unexported; never written to persistent driver files).
# On Bash 4+, uses associative arrays for O(1) lookup across hundreds/thousands of DBs.
# On Bash 3.2 (legacy macOS/Solaris), falls back to parallel indexed arrays.
# Guard against double-sourcing resetting previously registered credentials.
if [[ -z "${_DMA_OEE_LIB_LOADED:-}" ]]; then
  _DMA_OEE_LIB_LOADED=1
  _DMA_OEE_USE_ASSOC=0
  if [[ -n "${BASH_VERSINFO[0]:-}" ]] && [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
    if ( declare -gA _DMA_OEE_TEST_ASSOC 2>/dev/null ); then
      declare -gA _DMA_OEE_PASS_MAP=()
      declare -gA _DMA_OEE_ENDPOINT_PASS_MAP=()
      declare -gA _DMA_OEE_ENDPOINT_AMBIG_MAP=()
      _DMA_OEE_USE_ASSOC=1
    elif declare -A _DMA_OEE_PASS_MAP 2>/dev/null \
      && declare -A _DMA_OEE_ENDPOINT_PASS_MAP 2>/dev/null \
      && declare -A _DMA_OEE_ENDPOINT_AMBIG_MAP 2>/dev/null; then
      _DMA_OEE_USE_ASSOC=1
    fi
  fi
  _DMA_OEE_PASS_KEYS=()
  _DMA_OEE_PASS_VALS=()
  _DMA_OEE_ENDPOINT_KEYS=()
  _DMA_OEE_ENDPOINT_VALS=()
  _DMA_OEE_ENDPOINT_AMBIG_KEYS=()
  _DMA_OEE_KEY_LIST=()
  _DMA_OEE_ACTIVE_SECRETS=()
  _DMA_OEE_LOOKUP_RESULT=""
  _DMA_OEE_CHILD_PID=""
fi


# Validate that an OEE run ID is safe to use as a single path component.
function _oee_validate_runid() {
  local runid="${1:-}"
  local valid_re='^[A-Za-z0-9._-]+$'
  if [[ -z "${runid}" ]] || [[ "${runid}" == "." ]] || [[ "${runid}" == ".." ]]; then
    return 1
  fi
  if [[ ! "${runid}" =~ ${valid_re} ]]; then
    return 1
  fi
  return 0
}


# Securely overwrite and delete a single file. Best-effort when shredding is unavailable.
function _oee_secure_remove() {
  local target="${1:-}"
  if [[ -z "${target}" ]]; then
    return 0
  fi
  if [[ -L "${target}" ]]; then
    rm -f -- "${target}" 2>/dev/null || true
    return 0
  fi
  if [[ ! -f "${target}" ]]; then
    return 0
  fi
  chmod -- u+w "${target}" 2>/dev/null || true
  if command -v shred >/dev/null 2>&1; then
    shred -u -f -n 1 -- "${target}" 2>/dev/null && return 0
  fi
  local size_bytes=0
  local digits_re='^[0-9]+$'
  size_bytes=$(wc -c < "${target}" 2>/dev/null | tr -d '[:space:]') || size_bytes=0
  if [[ -n "${size_bytes}" ]] && [[ "${size_bytes}" =~ ${digits_re} ]] && [[ "${size_bytes}" -gt 0 ]]; then
    dd if=/dev/zero of="${target}" bs=4096 count=$(( (size_bytes + 4095) / 4096 )) conv=notrunc 2>/dev/null || true
  fi
  : > "${target}" 2>/dev/null || true
  rm -f -- "${target}" 2>/dev/null || true
}


# Detect whether oee_group_extract-SA.sh is v6.1.1+ ("v6") or v5.x ("v5").
function _oee_detect_extractor_version() {
  local script_path="${1:-}"
  local grep_bin="${grep_cmd:-grep}"
  if [[ -f "${script_path}" ]] \
    && "${grep_bin}" -q 'OEE_GROUP_PARALLELISM' "${script_path}" 2>/dev/null \
    && "${grep_bin}" -q 'archive_prefix=' "${script_path}" 2>/dev/null; then
    printf 'v6\n'
  else
    printf 'v5\n'
  fi
}


# Store an exact record password in memory, scoped to oee_runid.
function _oee_store_password() {
  local runid="${1}"
  local record_key="${2}"
  local password="${3}"
  local composite="${runid}|${record_key}"

  if [[ "${_DMA_OEE_USE_ASSOC}" -eq 1 ]]; then
    if [[ -z "${_DMA_OEE_PASS_MAP["${composite}"]+set}" ]]; then
      _DMA_OEE_KEY_LIST+=("${composite}")
    fi
    _DMA_OEE_PASS_MAP["${composite}"]="${password}"
  else
    local i
    for ((i = 0; i < ${#_DMA_OEE_PASS_KEYS[@]}; i++)); do
      if [[ "${_DMA_OEE_PASS_KEYS[$i]}" == "${composite}" ]]; then
        _DMA_OEE_PASS_VALS[$i]="${password}"
        return 0
      fi
    done
    _DMA_OEE_PASS_KEYS+=("${composite}")
    _DMA_OEE_PASS_VALS+=("${password}")
  fi
}


# Check whether a fallback endpoint key was marked ambiguous (multiple distinct passwords).
function _oee_is_endpoint_ambiguous() {
  local endpoint_key="${1}"
  if [[ "${_DMA_OEE_USE_ASSOC}" -eq 1 ]]; then
    [[ -n "${_DMA_OEE_ENDPOINT_AMBIG_MAP["${endpoint_key}"]+set}" ]]
    return $?
  fi
  local i
  for ((i = 0; i < ${#_DMA_OEE_ENDPOINT_AMBIG_KEYS[@]}; i++)); do
    if [[ "${_DMA_OEE_ENDPOINT_AMBIG_KEYS[$i]}" == "${endpoint_key}" ]]; then
      return 0
    fi
  done
  return 1
}


# Store an endpoint password in memory (for cross-process CSV lookup).
# When mark_conflicts=1 (host-level fallback for PDBs), conflicting distinct passwords
# mark the key ambiguous instead of overwriting so lookup fails closed rather than
# sending the wrong database's password.
function _oee_store_endpoint_password() {
  local endpoint_key="${1}"
  local password="${2}"
  local mark_conflicts="${3:-0}"

  if [[ "${mark_conflicts}" -eq 1 ]] && _oee_is_endpoint_ambiguous "${endpoint_key}"; then
    return 0
  fi

  if [[ "${_DMA_OEE_USE_ASSOC}" -eq 1 ]]; then
    if [[ "${mark_conflicts}" -eq 1 ]] && [[ -n "${_DMA_OEE_ENDPOINT_PASS_MAP["${endpoint_key}"]+set}" ]]; then
      if [[ "${_DMA_OEE_ENDPOINT_PASS_MAP["${endpoint_key}"]}" != "${password}" ]]; then
        _DMA_OEE_ENDPOINT_AMBIG_MAP["${endpoint_key}"]=1
        _DMA_OEE_ENDPOINT_PASS_MAP["${endpoint_key}"]=""
        unset '_DMA_OEE_ENDPOINT_PASS_MAP[$endpoint_key]'
        return 0
      fi
    fi
    _DMA_OEE_ENDPOINT_PASS_MAP["${endpoint_key}"]="${password}"
  else
    local i
    for ((i = 0; i < ${#_DMA_OEE_ENDPOINT_KEYS[@]}; i++)); do
      if [[ "${_DMA_OEE_ENDPOINT_KEYS[$i]}" == "${endpoint_key}" ]]; then
        if [[ "${mark_conflicts}" -eq 1 ]] && [[ "${_DMA_OEE_ENDPOINT_VALS[$i]}" != "${password}" ]]; then
          _DMA_OEE_ENDPOINT_AMBIG_KEYS+=("${endpoint_key}")
          _DMA_OEE_ENDPOINT_VALS[$i]=""
          return 0
        fi
        _DMA_OEE_ENDPOINT_VALS[$i]="${password}"
        return 0
      fi
    done
    _DMA_OEE_ENDPOINT_KEYS+=("${endpoint_key}")
    _DMA_OEE_ENDPOINT_VALS+=("${password}")
  fi
}


# Look up the password for a password-less driver record line.
# Sets _DMA_OEE_LOOKUP_RESULT without spawning a subshell. Returns 0 if found, 1 if missing.
function _oee_lookup_password() {
  local runid="${1}"
  local record_key="${2}"
  local composite="${runid}|${record_key}"
  _DMA_OEE_LOOKUP_RESULT=""

  # 1. Exact in-process record match (handles distinct passwords for any number of targets).
  if [[ "${_DMA_OEE_USE_ASSOC}" -eq 1 ]]; then
    if [[ -n "${_DMA_OEE_PASS_MAP["${composite}"]+set}" ]]; then
      _DMA_OEE_LOOKUP_RESULT="${_DMA_OEE_PASS_MAP["${composite}"]}"
      return 0
    fi
  else
    local i
    for ((i = 0; i < ${#_DMA_OEE_PASS_KEYS[@]}; i++)); do
      if [[ "${_DMA_OEE_PASS_KEYS[$i]}" == "${composite}" ]]; then
        _DMA_OEE_LOOKUP_RESULT="${_DMA_OEE_PASS_VALS[$i]}"
        return 0
      fi
    done
  fi

  # 2. Cross-process fallback via optional endpoint credentials loaded from dma_db_list.csv.
  if [[ "${record_key}" == *"://"* ]]; then
    local rest="${record_key#*://}"
    local host_port="${rest%%/*}"
    local after_slash="${rest#*/}"
    local svc="${after_slash%%:*}"
    local user_part="${after_slash#*:}"
    local user="${user_part%%:*}"
    local host="${host_port%%:*}"
    local port=""
    if [[ "${host_port}" == *":"* ]]; then
      port="${host_port#*:}"
    fi
    local exact_ep="${host}:${port}/${svc}:${user}"
    local host_ep="${host}:${port}:${user}"

    if [[ "${_DMA_OEE_USE_ASSOC}" -eq 1 ]]; then
      if [[ -n "${_DMA_OEE_ENDPOINT_PASS_MAP["${exact_ep}"]+set}" ]]; then
        _DMA_OEE_LOOKUP_RESULT="${_DMA_OEE_ENDPOINT_PASS_MAP["${exact_ep}"]}"
        return 0
      fi
      if ! _oee_is_endpoint_ambiguous "${host_ep}" \
        && [[ -n "${_DMA_OEE_ENDPOINT_PASS_MAP["${host_ep}"]+set}" ]]; then
        _DMA_OEE_LOOKUP_RESULT="${_DMA_OEE_ENDPOINT_PASS_MAP["${host_ep}"]}"
        return 0
      fi
    else
      local k
      for ((k = 0; k < ${#_DMA_OEE_ENDPOINT_KEYS[@]}; k++)); do
        if [[ "${_DMA_OEE_ENDPOINT_KEYS[$k]}" == "${exact_ep}" ]]; then
          _DMA_OEE_LOOKUP_RESULT="${_DMA_OEE_ENDPOINT_VALS[$k]}"
          return 0
        fi
      done
      if ! _oee_is_endpoint_ambiguous "${host_ep}"; then
        for ((k = 0; k < ${#_DMA_OEE_ENDPOINT_KEYS[@]}; k++)); do
          if [[ "${_DMA_OEE_ENDPOINT_KEYS[$k]}" == "${host_ep}" ]]; then
            _DMA_OEE_LOOKUP_RESULT="${_DMA_OEE_ENDPOINT_VALS[$k]}"
            return 0
          fi
        done
      fi
    fi
  fi

  return 1
}


# Append a secret value to _DMA_OEE_ACTIVE_SECRETS if non-empty and not already present.
function _oee_append_unique_secret() {
  local val="${1}"
  [[ -n "${val}" ]] || return 0
  local existing
  for existing in ${_DMA_OEE_ACTIVE_SECRETS[@]+"${_DMA_OEE_ACTIVE_SECRETS[@]}"}; do
    if [[ "${existing}" == "${val}" ]]; then
      return 0
    fi
  done
  _DMA_OEE_ACTIVE_SECRETS+=("${val}")
}


# Collect unique non-empty secrets for a runid (used solely for in-memory log redaction).
function _oee_get_run_secrets() {
  local runid="${1}"
  _DMA_OEE_ACTIVE_SECRETS=()
  local prefix="${runid}|"
  if [[ "${_DMA_OEE_USE_ASSOC}" -eq 1 ]]; then
    local key
    for key in ${_DMA_OEE_KEY_LIST[@]+"${_DMA_OEE_KEY_LIST[@]}"}; do
      if [[ "${key}" == "${prefix}"* ]] && [[ -n "${_DMA_OEE_PASS_MAP["${key}"]+set}" ]]; then
        _oee_append_unique_secret "${_DMA_OEE_PASS_MAP["${key}"]}"
      fi
    done
    if [[ ${#_DMA_OEE_ENDPOINT_PASS_MAP[@]} -gt 0 ]]; then
      local ep_key
      for ep_key in "${!_DMA_OEE_ENDPOINT_PASS_MAP[@]}"; do
        _oee_append_unique_secret "${_DMA_OEE_ENDPOINT_PASS_MAP["${ep_key}"]}"
      done
    fi
  else
    local i
    for ((i = 0; i < ${#_DMA_OEE_PASS_KEYS[@]}; i++)); do
      if [[ "${_DMA_OEE_PASS_KEYS[$i]}" == "${prefix}"* ]]; then
        _oee_append_unique_secret "${_DMA_OEE_PASS_VALS[$i]}"
      fi
    done
    local k
    for ((k = 0; k < ${#_DMA_OEE_ENDPOINT_VALS[@]}; k++)); do
      _oee_append_unique_secret "${_DMA_OEE_ENDPOINT_VALS[$k]}"
    done
  fi
}


# Clear only in-memory credentials scoped to the given runid.
function _oee_clear_passwords() {
  local runid="${1}"
  local prefix="${runid}|"
  _DMA_OEE_LOOKUP_RESULT=""

  if [[ "${_DMA_OEE_USE_ASSOC}" -eq 1 ]]; then
    local -a remaining_keys=()
    local key
    for key in ${_DMA_OEE_KEY_LIST[@]+"${_DMA_OEE_KEY_LIST[@]}"}; do
      if [[ "${key}" == "${prefix}"* ]]; then
        _DMA_OEE_PASS_MAP["${key}"]=""
        unset '_DMA_OEE_PASS_MAP[$key]'
      else
        remaining_keys+=("${key}")
      fi
    done
    if [[ ${#remaining_keys[@]} -gt 0 ]]; then
      _DMA_OEE_KEY_LIST=("${remaining_keys[@]}")
    else
      _DMA_OEE_KEY_LIST=()
      _DMA_OEE_ENDPOINT_PASS_MAP=()
      _DMA_OEE_ENDPOINT_AMBIG_MAP=()
    fi
  else
    local -a new_keys=()
    local -a new_vals=()
    local i
    for ((i = 0; i < ${#_DMA_OEE_PASS_KEYS[@]}; i++)); do
      if [[ "${_DMA_OEE_PASS_KEYS[$i]}" == "${prefix}"* ]]; then
        _DMA_OEE_PASS_VALS[$i]=""
      else
        new_keys+=("${_DMA_OEE_PASS_KEYS[$i]}")
        new_vals+=("${_DMA_OEE_PASS_VALS[$i]}")
      fi
    done
    if [[ ${#new_keys[@]} -gt 0 ]]; then
      _DMA_OEE_PASS_KEYS=("${new_keys[@]}")
      _DMA_OEE_PASS_VALS=("${new_vals[@]}")
    else
      _DMA_OEE_PASS_KEYS=()
      _DMA_OEE_PASS_VALS=()
      _DMA_OEE_ENDPOINT_KEYS=()
      _DMA_OEE_ENDPOINT_VALS=()
      _DMA_OEE_ENDPOINT_AMBIG_KEYS=()
    fi
  fi
}


# Load per-database credentials into memory from an existing dma_db_list.csv config file.
# Enables cross-process hydration for batch runs with hundreds of databases without writing
# duplicate password copies to disk.
function oee_load_credentials_csv() {
  local csv_file="${1:-}"
  if [[ -z "${csv_file}" ]] || [[ ! -f "${csv_file}" ]] || [[ ! -r "${csv_file}" ]]; then
    echo "ERROR: OEE credential CSV file not found or not readable: ${csv_file}" >&2
    return 1
  fi

  local raw_line sys_user user_field db_field rest_fields
  while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
    raw_line="${raw_line%$'\r'}"
    # Trim leading whitespace to skip comments and blank lines.
    local trimmed="${raw_line#"${raw_line%%[![:space:]]*}"}"
    [[ -z "${trimmed}" || "${trimmed}" == \#* ]] && continue

    IFS=, read -r sys_user user_field db_field rest_fields <<< "${raw_line}"
    # Trim surrounding horizontal whitespace from user_field and db_field.
    user_field="${user_field#"${user_field%%[![:space:]]*}"}"
    user_field="${user_field%"${user_field##*[![:space:]]}"}"
    db_field="${db_field#"${db_field%%[![:space:]]*}"}"
    db_field="${db_field%"${db_field##*[![:space:]]}"}"

    # Strip optional matching single/double quotes wrapping user/pass or db target.
    if [[ "${user_field}" == \'*\' && ${#user_field} -ge 2 ]]; then
      user_field="${user_field:1:${#user_field}-2}"
    elif [[ "${user_field}" == \"*\" && ${#user_field} -ge 2 ]]; then
      user_field="${user_field:1:${#user_field}-2}"
    fi
    if [[ "${db_field}" == \'*\' && ${#db_field} -ge 2 ]]; then
      db_field="${db_field:1:${#db_field}-2}"
    elif [[ "${db_field}" == \"*\" && ${#db_field} -ge 2 ]]; then
      db_field="${db_field:1:${#db_field}-2}"
    fi

    [[ "${user_field}" == */* ]] || continue
    local csv_user="${user_field%%/*}"
    local csv_pass="${user_field#*/}"

    local db_target="${db_field#@}"
    db_target="${db_target#//}"
    [[ -n "${db_target}" && "${db_target}" == */* ]] || continue
    local host_port="${db_target%%/*}"
    local svc="${db_target#*/}"
    local host="${host_port%%:*}"
    local port=""
    if [[ "${host_port}" == *":"* ]]; then
      port="${host_port#*:}"
    fi

    _oee_store_endpoint_password "${host}:${port}/${svc}:${csv_user}" "${csv_pass}" 0
    _oee_store_endpoint_password "${host}:${port}:${csv_user}" "${csv_pass}" 1
  done < "${csv_file}"
  return 0
}


# Copy an OEE diagnostic file with password fields replaced by <REDACTED> (mode 0600).
function _oee_write_redacted_file() {
  local src_file="${1}"
  local dst_file="${2}"
  local runid="${3}"
  local prev_umask
  prev_umask=$(umask)
  umask 077

  _oee_get_run_secrets "${runid}"
  : > "${dst_file}"
  chmod -- 600 "${dst_file}" 2>/dev/null || true

  local re_ec='^(.*[[:space:]|])?([A-Za-z0-9._-]+:[^/:[:space:]]+://[^/:]+(:[0-9]+)?/[^:]+:[^:]+:)([^|]*)(.*)$'
  local re_tns='^(.*[[:space:]|])?([0-9a-fA-F]{16,}:[^:]+:[^:/]+:[^:]+:)([^|]*)(.*)$'
  local slash_redacted='/<REDACTED>@'
  local colon_space_redacted=':<REDACTED> '
  local colon_pipe_redacted=':<REDACTED>|'

  local line out
  while IFS= read -r line || [[ -n "${line}" ]]; do
    out="${line}"
    # Redact Easy Connect and TNS driver record password fields (both anchored and prefixed,
    # with or without port, preserving spaces inside passwords up to '|' or EOL).
    if [[ "${out}" =~ ${re_ec} ]]; then
      out="${BASH_REMATCH[1]:-}${BASH_REMATCH[2]:-}<REDACTED>${BASH_REMATCH[5]:-}"
    elif [[ "${out}" != *"://"* ]] && [[ "${out}" =~ ${re_tns} ]]; then
      out="${BASH_REMATCH[1]:-}${BASH_REMATCH[2]:-}<REDACTED>${BASH_REMATCH[4]:-}"
    fi
    # Belt-and-suspenders scrub for SQL*Plus-style user/pass@ strings and known passwords.
    local secret
    for secret in ${_DMA_OEE_ACTIVE_SECRETS[@]+"${_DMA_OEE_ACTIVE_SECRETS[@]}"}; do
      if [[ "${out}" == *"/${secret}@"* ]]; then
        out="${out//"/${secret}@"/${slash_redacted}}"
      fi
      if [[ "${out}" == *":${secret} "* ]]; then
        out="${out//":${secret} "/${colon_space_redacted}}"
      fi
      if [[ "${out}" == *":${secret}|"* ]]; then
        out="${out//":${secret}|"/${colon_pipe_redacted}}"
      fi
      if [[ "${out}" == *":${secret}" ]]; then
        out="${out%":${secret}"}:<REDACTED>"
      fi
      if [[ ${#secret} -ge 4 ]] && [[ "${out}" == *"${secret}"* ]]; then
        out="${out//"${secret}"/<REDACTED>}"
      fi
    done
    printf '%s\n' "${out}" >> "${dst_file}"
  done < "${src_file}"

  _DMA_OEE_ACTIVE_SECRETS=()
  umask "${prev_umask}"
}


# Save redacted copies of OEE diagnostic logs/failures/summaries to log_dir on error (Option A).
function _oee_save_redacted_diagnostics() {
  local stage_dir="${1}"
  local oee_runid="${2}"
  local dest_log_dir="${log_dir:-}"

  if [[ -z "${dest_log_dir}" ]] || [[ ! -d "${stage_dir}" ]]; then
    return 0
  fi
  mkdir -p -- "${dest_log_dir}" 2>/dev/null || return 0

  local diag_file saved_count=0
  local nullglob_was_set=0
  shopt -q nullglob && nullglob_was_set=1
  shopt -s nullglob

  local -a candidates=(
    "${stage_dir}"/*.log
    "${stage_dir}"/*.failures
    "${stage_dir}"/*.summary
    "${stage_dir}"/*_output/*.failures
    "${stage_dir}"/*_output/*.summary
    "${stage_dir}"/*_output/logs/*.log
  )
  for diag_file in ${candidates[@]+"${candidates[@]}"}; do
    [[ -f "${diag_file}" && -s "${diag_file}" ]] || continue
    local base_name
    base_name=$(basename -- "${diag_file}")
    local out_path="${dest_log_dir}/oee_${oee_runid}_${base_name}"
    if [[ -e "${out_path}" ]]; then
      out_path="${dest_log_dir}/oee_${oee_runid}_${saved_count}_${base_name}"
    fi
    _oee_write_redacted_file "${diag_file}" "${out_path}" "${oee_runid}"
    saved_count=$((saved_count + 1))
  done

  if [[ "${nullglob_was_set}" -eq 0 ]]; then
    shopt -u nullglob
  fi
  if [[ "${saved_count}" -gt 0 ]]; then
    echo "Saved ${saved_count} redacted OEE diagnostic file(s) to ${dest_log_dir} (mode 0600)."
  fi
}


# Clean up all driver files, transient credential files, staging directories,
# failure/summary logs, and in-memory secrets scoped strictly to oee_runid.
function oee_cleanup_run() {
  local target_oee_dir="${1:-${oee_dir:-}}"
  local oee_runid="${2:-}"

  if ! _oee_validate_runid "${oee_runid}"; then
    return 1
  fi

  local nullglob_was_set=0
  shopt -q nullglob && nullglob_was_set=1
  shopt -s nullglob

  if [[ -n "${target_oee_dir}" ]] && [[ -d "${target_oee_dir}" ]]; then
    local stage_dir="${target_oee_dir}/${oee_runid}"
    # If the current working directory is inside stage_dir, leave before deleting it.
    if [[ -d "${stage_dir}" ]]; then
      local cwd_now
      cwd_now=$(pwd 2>/dev/null || true)
      if [[ "${cwd_now}" == "${stage_dir}" || "${cwd_now}" == "${stage_dir}/"* ]]; then
        cd -- "${target_oee_dir}" 2>/dev/null || true
      fi

      local sensitive_file
      for sensitive_file in \
        "${stage_dir}"/*driverfile* \
        "${stage_dir}"/*.failures \
        "${stage_dir}"/*.summary \
        "${stage_dir}"/*.log \
        "${stage_dir}"/status.txt \
        "${stage_dir}"/oee_temp*.txt \
        "${stage_dir}"/*_output/*.failures \
        "${stage_dir}"/*_output/*.summary \
        "${stage_dir}"/*_output/logs/*.log \
        "${stage_dir}"/*_output/failed/*; do
        _oee_secure_remove "${sensitive_file}"
      done
      rm -rf -- "${stage_dir}" 2>/dev/null || true
    fi

    local base_driver
    for base_driver in "${target_oee_dir}"/*driverfile."${oee_runid}"; do
      _oee_secure_remove "${base_driver}"
    done
  fi

  if [[ "${nullglob_was_set}" -eq 0 ]]; then
    shopt -u nullglob
  fi

  _oee_clear_passwords "${oee_runid}"
  return 0
}


# Derive OEE driver file packaging labels for both v5.1 and v6.1.1 naming conventions.
function _oee_dest_zip_base() {
  local fname="${1}"
  local oee_runid="${2}"
  local base
  base=$(basename -- "${fname}")
  base="${base%."${oee_runid}"}"
  base="${base%.driverfile}"
  base="${base%.csv}"
  printf '%s\n' "${base}"
}


function _oee_move_driver_zips() {
  local fname="${1}"
  local oee_runid="${2}"
  local target_output_dir="${output_dir}"
  local base_fname
  base_fname=$(basename -- "${fname}")
  local after_prefix="${base_fname#*_}"
  local group_label_v6="${after_prefix%%.*}"
  local group_label_v5="${group_label_v6%%_*}"
  local dest_base
  dest_base=$(_oee_dest_zip_base "${fname}" "${oee_runid}")

  local nullglob_was_set=0
  shopt -q nullglob && nullglob_was_set=1
  shopt -s nullglob

  # v5.1 produces a single <groupLabel>.zip archive.
  local v5_zip=""
  if [[ -f "${group_label_v6}.zip" ]]; then
    v5_zip="${group_label_v6}.zip"
  elif [[ -f "${group_label_v5}.zip" ]]; then
    v5_zip="${group_label_v5}.zip"
  fi

  if [[ -n "${v5_zip}" ]]; then
    echo "Moving OEE file ${v5_zip} to DMA output directory as ${target_output_dir}/${dest_base}.zip ."
    mv -f -- "${v5_zip}" "${target_output_dir}/${dest_base}.zip"
    local rc=$?
    [[ "${nullglob_was_set}" -eq 0 ]] && shopt -u nullglob
    return "${rc}"
  fi

  # v6.1.1 produces rolling chunked archives: <groupLabel>_<extract_label>_<NNN>.zip.
  local -a v6_zips=(
    "${group_label_v6}"_*_[0-9][0-9][0-9].zip
    "${group_label_v6}"_*_[0-9][0-9][0-9][0-9].zip
  )
  if [[ "${#v6_zips[@]}" -eq 0 ]] && [[ "${group_label_v5}" != "${group_label_v6}" ]]; then
    v6_zips=(
      "${group_label_v5}"_*_[0-9][0-9][0-9].zip
      "${group_label_v5}"_*_[0-9][0-9][0-9][0-9].zip
    )
  fi

  if [[ "${#v6_zips[@]}" -eq 1 ]]; then
    local single_zip="${v6_zips[0]}"
    echo "Moving OEE file ${single_zip} to DMA output directory as ${target_output_dir}/${dest_base}.zip ."
    mv -f -- "${single_zip}" "${target_output_dir}/${dest_base}.zip"
    local rc=$?
    [[ "${nullglob_was_set}" -eq 0 ]] && shopt -u nullglob
    return "${rc}"
  elif [[ "${#v6_zips[@]}" -gt 1 ]]; then
    local chunk_zip suffix rc=0
    for chunk_zip in "${v6_zips[@]}"; do
      suffix="${chunk_zip##*_}"
      suffix="${suffix%.zip}"
      echo "Moving OEE chunk ${chunk_zip} to DMA output directory as ${target_output_dir}/${dest_base}_${suffix}.zip ."
      mv -f -- "${chunk_zip}" "${target_output_dir}/${dest_base}_${suffix}.zip" || rc=1
    done
    [[ "${nullglob_was_set}" -eq 0 ]] && shopt -u nullglob
    return "${rc}"
  fi

  [[ "${nullglob_was_set}" -eq 0 ]] && shopt -u nullglob
  echo "Error: Could not locate OEE output zip file for ${group_label_v6} !!"
  return 1
}


# Write password-less driver file with owner-only permissions (0600) and hold
# per-database passwords strictly in memory so they are never persisted on disk.
function oee_generate_config() {
  local oee_guid="${1}"
  local oee_database="${2}"
  local oee_host_name="${3}"
  local oee_port="${4}"
  local oee_user="${5}"
  local oee_pass="${6}"
  local oee_group="${7}"
  local oee_runid="${8}"
  local v_file_tag="${9}"

  if ! _oee_validate_runid "${oee_runid}"; then
    echo "ERROR: Invalid OEE run id: ${oee_runid}" >&2
    return 1
  fi

  local grep_bin="${grep_cmd:-grep}"
  local md5_bin="${md5_cmd:-md5sum}"
  local md5_field="${md5_col:-1}"
  local prev_umask
  prev_umask=$(umask)
  umask 077

  if [[ ! -d "${oee_dir}" ]]; then
    mkdir -p -m 700 -- "${oee_dir}"
  fi

  local v_container_count=0
  local base_guid="${oee_guid}"
  local target_guid=""
  local record_prefix=""
  local driver_file_name="${oee_dir}/mpack_DMA-OEE-${oee_group}.${v_file_tag}.driverfile.${oee_runid}"

  echo "Generating driver file ${driver_file_name}"

  # Ensure existing or newly created driver file is locked down to owner read/write only (0600).
  : >> "${driver_file_name}"
  chmod -- 600 "${driver_file_name}"

  local dbdomain=""
  if [[ -f "${output_dir}/opdb__dbparameters__${v_file_tag}" ]]; then
    dbdomain=$( ("${grep_bin}" db_domain "${output_dir}/opdb__dbparameters__${v_file_tag}" 2>/dev/null || true) | cut -d '|' -f 5 | uniq | head -1 )
    if [[ -n "${dbdomain}" ]]; then
      dbdomain=".${dbdomain}"
    fi
  fi

  # For multitenant, add entries for all pluggable databases except root or seed.
  if [[ -f "${output_dir}/opdb__pdb_summary__${v_file_tag}" ]] ; then
    local pdbname pdb_list
    pdb_list=$( ("${grep_bin}" -v -e PKEY -e "CDB\$ROOT" -e "PDB\$SEED" "${output_dir}/opdb__pdb_summary__${v_file_tag}" 2>/dev/null || true) | ("${grep_bin}" -e "READ WRITE" -e "READ ONLY" -e "^----" || true) | cut -d '|' -f 4 )
    for pdbname in ${pdb_list}
    do
      [[ -n "${pdbname}" ]] || continue
      echo "Adding pluggable database ${pdbname} to driverfile ${oee_runid}"
      target_guid=$(printf '%s%s%s\n' "${base_guid}" "${pdbname}" "${dbdomain}" | "${md5_bin}" | cut -d ' ' -f "${md5_field}")
      record_prefix="${target_guid}:${pdbname}://${oee_host_name}:${oee_port}/${pdbname}${dbdomain}:${oee_user}:"
      printf '%s\n' "${record_prefix}" >> "${driver_file_name}"
      _oee_store_password "${oee_runid}" "${record_prefix}" "${oee_pass}"
      v_container_count=$((v_container_count + 1))
    done
  elif [[ -f "${output_dir}/opdb__pdbsopenmode__${v_file_tag}" ]] ; then
    local pdbname pdb_list
    pdb_list=$( ("${grep_bin}" -v -e PKEY -e "CDB\$ROOT" -e "PDB\$SEED" "${output_dir}/opdb__pdbsopenmode__${v_file_tag}" 2>/dev/null || true) | ("${grep_bin}" -e "READ WRITE" -e "READ ONLY" -e "^----" || true) | cut -d '|' -f 3 )
    for pdbname in ${pdb_list}
    do
      [[ -n "${pdbname}" ]] || continue
      echo "Adding pluggable database ${pdbname} to driverfile ${oee_runid}"
      target_guid=$(printf '%s%s\n' "${base_guid}" "${pdbname}" | "${md5_bin}" | cut -d ' ' -f "${md5_field}")
      record_prefix="${target_guid}:${pdbname}://${oee_host_name}:${oee_port}/${pdbname}${dbdomain}:${oee_user}:"
      printf '%s\n' "${record_prefix}" >> "${driver_file_name}"
      _oee_store_password "${oee_runid}" "${record_prefix}" "${oee_pass}"
      v_container_count=$((v_container_count + 1))
    done
  fi

  if [[ "${v_container_count}" -eq 0 ]]; then
    # For single tenant or container databases.
    target_guid=$(printf '%s\n' "${base_guid}" | "${md5_bin}" | cut -d ' ' -f "${md5_field}")
    record_prefix="${target_guid}:${oee_database}://${oee_host_name}:${oee_port}/${oee_database}:${oee_user}:"
    printf '%s\n' "${record_prefix}" >> "${driver_file_name}"
    _oee_store_password "${oee_runid}" "${record_prefix}" "${oee_pass}"
  fi

  chmod -- 600 "${driver_file_name}"
  umask "${prev_umask}"
  return 0
}


# Hydrate a transient 0600 driver file from a password-less template for one extractor invocation.
function _oee_hydrate_driver_file() {
  local template_file="${1}"
  local transient_file="${2}"
  local oee_runid="${3}"
  local extractor_ver="${4}"

  local prev_umask
  prev_umask=$(umask)
  umask 077
  : > "${transient_file}"
  chmod -- 600 "${transient_file}"

  local line pass has_error=0
  local sorted_tmp="${transient_file}.sorted.$$"
  LC_ALL=C sort -u -- "${template_file}" > "${sorted_tmp}"
  chmod -- 600 "${sorted_tmp}"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" ]] && continue
    if [[ "${line}" == *: ]]; then
      if ! _oee_lookup_password "${oee_runid}" "${line}"; then
        echo "ERROR: Missing in-memory credential for OEE target ${line}<REDACTED>. Run within the same session or provide DMA_OEE_CRED_FILE." >&2
        has_error=1
        break
      fi
      pass="${_DMA_OEE_LOOKUP_RESULT}"
      if [[ "${pass}" == *$'\n'* || "${pass}" == *$'\r'* ]]; then
        echo "ERROR: OEE password contains unsupported newline character for target ${line}<REDACTED>." >&2
        has_error=1
        break
      fi
      if [[ "${pass}" == *":"* ]]; then
        echo "ERROR: OEE driver file uses ':' as a delimiter; password for target ${line}<REDACTED> cannot contain ':'." >&2
        has_error=1
        break
      fi
      if [[ "${extractor_ver}" == "v6" ]]; then
        case "${pass}" in
          */*|*@*|*[[:space:]]*)
            echo "WARNING: Password for target ${line}<REDACTED> contains '/', '@', or whitespace, which may not be accepted by unmodified OEE v6.1.1." >&2
            ;;
        esac
      fi
      printf '%s%s\n' "${line}" "${pass}" >> "${transient_file}"
    else
      # Legacy inline record supplied externally (not created by oee_generate_config).
      printf '%s\n' "${line}" >> "${transient_file}"
    fi
  done < "${sorted_tmp}"

  _oee_secure_remove "${sorted_tmp}"
  _DMA_OEE_LOOKUP_RESULT=""
  umask "${prev_umask}"

  if [[ "${has_error}" -ne 0 ]]; then
    _oee_secure_remove "${transient_file}"
    return 1
  fi
  return 0
}


# Handle INT/TERM/HUP during an active oee_run() invocation so transient files are always wiped.
function _oee_handle_signal() {
  local exit_code="${1:-143}"
  if [[ -n "${_DMA_OEE_CHILD_PID:-}" ]]; then
    kill -TERM "${_DMA_OEE_CHILD_PID}" 2>/dev/null || true
    wait "${_DMA_OEE_CHILD_PID}" 2>/dev/null || true
    _DMA_OEE_CHILD_PID=""
  fi
  if [[ -n "${_DMA_OEE_ACTIVE_RUNID:-}" ]]; then
    if [[ -n "${_DMA_OEE_ACTIVE_STAGE_PARENT:-}" ]]; then
      cd -- "${_DMA_OEE_ACTIVE_STAGE_PARENT}" 2>/dev/null || true
      oee_cleanup_run "${_DMA_OEE_ACTIVE_STAGE_PARENT}" "${_DMA_OEE_ACTIVE_RUNID}" || true
    fi
    _DMA_OEE_ACTIVE_RUNID=""
    _DMA_OEE_ACTIVE_STAGE_PARENT=""
  fi
  if [[ -n "${_DMA_OEE_SAVED_UMASK:-}" ]]; then
    umask "${_DMA_OEE_SAVED_UMASK}" 2>/dev/null || true
  fi
  exit "${exit_code}"
}


function oee_run_standalone_extract() {
  local oee_runid="${1}"
  local extractor_ver
  extractor_ver=$(_oee_detect_extractor_version "./oee_group_extract-SA.sh")
  local package_each="${_DMA_OEE_PACKAGE_EACH:-0}"
  local overall_rc=0
  local had_files=0

  local nullglob_was_set=0
  shopt -q nullglob && nullglob_was_set=1
  shopt -s nullglob

  local fname
  for fname in *driverfile."${oee_runid}"
  do
    [[ -f "${fname}" ]] || continue
    had_files=1
    echo "Processing file ${fname} (OEE extractor: ${extractor_ver})"

    local new_name="${fname%."${oee_runid}"}"
    if ! _oee_hydrate_driver_file "${fname}" "${new_name}" "${oee_runid}" "${extractor_ver}"; then
      overall_rc=1
      continue
    fi

    local extract_rc=0
    local -a extract_args=( "${new_name}" )
    if [[ "${extractor_ver}" == "v6" ]]; then
      case "${DMA_OEE_EXTRACT_MODE:-}" in
        -all|-security)
          extract_args+=( "${DMA_OEE_EXTRACT_MODE}" )
          ;;
      esac
      OEE_GROUP_RESUME=N ./oee_group_extract-SA.sh "${extract_args[@]}" <<'EOF' &
2
EOF
      _DMA_OEE_CHILD_PID=$!
      wait "${_DMA_OEE_CHILD_PID}" && extract_rc=0 || extract_rc=$?
      _DMA_OEE_CHILD_PID=""
    else
      ./oee_group_extract-SA.sh "${new_name}" <<'EOF' &
2
EOF
      _DMA_OEE_CHILD_PID=$!
      wait "${_DMA_OEE_CHILD_PID}" && extract_rc=0 || extract_rc=$?
      _DMA_OEE_CHILD_PID=""
    fi

    # Immediately wipe the transient hydrated driver file after extractor exits.
    _oee_secure_remove "${new_name}"

    if [[ "${extract_rc}" -ne 0 ]]; then
      overall_rc=1
    fi

    # Check v5/v6 non-empty failure log markers (v5 masks exit code via tee).
    local f_check
    for f_check in "${new_name}"_*.failures ./*_output/*.failures; do
      if [[ -f "${f_check}" && -s "${f_check}" ]]; then
        overall_rc=1
      fi
    done

    # Package this driver file's ZIP(s) immediately so subsequent driver files in the
    # same group cannot overwrite an earlier <groupLabel>.zip archive.
    if [[ "${package_each}" -eq 1 ]]; then
      if ! _oee_move_driver_zips "${fname}" "${oee_runid}"; then
        overall_rc=1
      fi
    fi
  done

  if [[ "${nullglob_was_set}" -eq 0 ]]; then
    shopt -u nullglob
  fi

  if [[ "${had_files}" -eq 0 ]]; then
    echo "WARNING: No OEE driver files found for run id ${oee_runid}." >&2
    return 1
  fi
  return "${overall_rc}"
}


function oee_package_zips() {
  local oee_runid="${1}"
  local overall_rc=0
  local had_files=0

  local nullglob_was_set=0
  shopt -q nullglob && nullglob_was_set=1
  shopt -s nullglob

  local fname
  for fname in *driverfile."${oee_runid}"
  do
    [[ -f "${fname}" ]] || continue
    had_files=1
    if ! _oee_move_driver_zips "${fname}" "${oee_runid}"; then
      overall_rc=1
    fi
  done

  if [[ "${nullglob_was_set}" -eq 0 ]]; then
    shopt -u nullglob
  fi

  if [[ "${had_files}" -eq 0 ]]; then
    return 1
  fi
  return "${overall_rc}"
}


function oee_run() {
  local oee_runid="${1:-}"
  local cred_csv="${2:-${DMA_OEE_CRED_FILE:-}}"

  if ! _oee_validate_runid "${oee_runid}"; then
    echo "ERROR: Invalid OEE run id: ${oee_runid}" >&2
    return 1
  fi

  if [[ -n "${cred_csv}" ]]; then
    oee_load_credentials_csv "${cred_csv}" || return 1
  fi

  local start_dir
  start_dir=$(pwd)
  local prev_umask
  prev_umask=$(umask)
  _DMA_OEE_SAVED_UMASK="${prev_umask}"
  _DMA_OEE_ACTIVE_STAGE_PARENT="${start_dir}"
  _DMA_OEE_ACTIVE_RUNID="${oee_runid}"
  umask 077

  local prev_trap_int prev_trap_term prev_trap_hup
  prev_trap_int=$(trap -p INT)
  prev_trap_term=$(trap -p TERM)
  prev_trap_hup=$(trap -p HUP)
  trap '_oee_handle_signal 130' INT
  trap '_oee_handle_signal 143' TERM
  trap '_oee_handle_signal 129' HUP

  echo "Running OEE for runid ${oee_runid}"
  mkdir -p -m 700 -- "${oee_runid}"
  chmod -- 700 "${oee_runid}"

  local nullglob_was_set=0
  shopt -q nullglob && nullglob_was_set=1
  shopt -s nullglob

  local -a sh_files=( ./*.sh )
  local -a sql_files=( ./*.sql )
  local -a drv_files=( ./*driverfile."${oee_runid}" )

  if [[ "${#sh_files[@]}" -gt 0 ]]; then
    cp -- "${sh_files[@]}" "${oee_runid}/"
  fi
  if [[ "${#sql_files[@]}" -gt 0 ]]; then
    cp -- "${sql_files[@]}" "${oee_runid}/"
  fi
  if [[ "${#drv_files[@]}" -gt 0 ]]; then
    cp -- "${drv_files[@]}" "${oee_runid}/"
    chmod -- 600 "${oee_runid}"/*driverfile."${oee_runid}"
  fi

  if [[ "${nullglob_was_set}" -eq 0 ]]; then
    shopt -u nullglob
  fi

  local run_rc=0
  local _DMA_OEE_PACKAGE_EACH=1
  if cd -- "${oee_runid}"; then
    if oee_run_standalone_extract "${oee_runid}"; then
      run_rc=0
    else
      run_rc=$?
    fi
    cd -- "${start_dir}" || true
  else
    run_rc=1
  fi

  # Option A: if errors occurred, retain redacted diagnostic logs (0600) in log_dir before wiping staging dir.
  if [[ "${run_rc}" -ne 0 ]] || [[ "${DMA_OEE_KEEP_REDACTED_LOGS:-}" == "Y" ]]; then
    _oee_save_redacted_diagnostics "${start_dir}/${oee_runid}" "${oee_runid}"
  fi

  oee_cleanup_run "${start_dir}" "${oee_runid}"
  _DMA_OEE_ACTIVE_RUNID=""
  _DMA_OEE_ACTIVE_STAGE_PARENT=""
  _DMA_OEE_SAVED_UMASK=""

  if [[ -n "${prev_trap_int}" ]]; then eval "${prev_trap_int}"; else trap - INT; fi
  if [[ -n "${prev_trap_term}" ]]; then eval "${prev_trap_term}"; else trap - TERM; fi
  if [[ -n "${prev_trap_hup}" ]]; then eval "${prev_trap_hup}"; else trap - HUP; fi
  umask "${prev_umask}"

  if [[ "${run_rc}" -eq 0 ]]; then
    return 0
  fi
  return 1
}


# OEE Requires SQL*Plus version 12.1 or higher
function oee_check_sqlplus_release {
  local retval="FAIL"
  local sql_client
  sql_client=$("${sqlplus_cmd}" -s /nolog <<EOF
  prompt &_SQLPLUS_RELEASE
  exit;
EOF
  )
  if [[ "${sql_client}" == *"SP2-"* ]]; then
    retval="FAIL: ${sql_client}"
  else
    local sqlclientver
    sqlclientver=$(printf '%s' "${sql_client}" | cut -c 1-2)
    if [[ "${sqlclientver}" -ge 12 ]]
    then
      retval="PASS"
    else
      retval="FAIL: ${sql_client}"
    fi
  fi
  echo "${retval}"
}


# OEE Requires database 10g or higher
function oee_check_db_version {
  local connection_string="$1"
  local ret_val="FAIL"
  local db_version

  db_version=$(
"${sqlplus_cmd}" -s /nolog << EOF
SET DEFINE OFF
connect ${connection_string}
@${sql_dir}/dma_set_sql_env.sql
set pagesize 0 lines 400 feedback off verify off heading off echo off timing off time off
WITH mj AS (
SELECT substr(version, 1, INSTR(version, '.', 1, 2)-1) AS version
FROM v\$instance)
SELECT 'CONNECTED|' ||
       SUBSTR(version, 1, INSTR(version, '.')-1) || '|' || -- Major
       SUBSTR(version, INSTR(version, '.')+1)              -- Minor
FROM mj;
exit;
EOF
)
  if [[ "${db_version}" == "CONNECTED"* ]] ; then
    local db_version_major db_version_minor
    db_version_major=$(printf '%s' "${db_version}" | cut -d '|' -f 2)
    db_version_minor=$(printf '%s' "${db_version}" | cut -d '|' -f 3)

    if [[ ${db_version_major} -gt 10 ]] ; then
        ret_val="PASS"
    else
      if [[ ${db_version_major} -eq 10 ]] ; then
        if [[ ${db_version_minor} -ge 2 ]] ; then
          ret_val="PASS"
        fi
      fi
    fi
  else
    ret_val="FAIL: ${db_version}"
  fi
  echo "${ret_val}"
}


# Check the platform on which the script is running.
# Fail on all platforms other than officially supported.
function oee_check_platform() {
  local platform
  platform=$(uname)
  local ret_val="FAIL"
  case "${platform}" in
    "Linux" )
      if [[ "$(uname -a)" == *"microsoft"* ]]; then
        ret_val="FAIL due to unsupported platform WSL.  Oracle Estate Explorer collector is not compatible with the operating system on this machine.  Either disable OEE collection in the configuration file or execute these scripts on a supported platform."
      else
        ret_val="PASS"
      fi
      ;;
    * )
      ret_val="FAIL due to unsupported platform ${platform}.  Oracle Estate Explorer collector is not compatible with the operating system on this machine.  Either disable OEE collection in the configuration file or execute these scripts on a supported platform."
  esac
  echo "${ret_val}"
}


# Check that all conditions are correct for running OEE (v5.1 or v6.1.1).
function oee_check_conditions {
  local connection_string="${1:-}"
  local connection_destination="<REDACTED>"
  if [[ "${connection_string}" == *"@//"* ]]; then
    connection_destination="//${connection_string##*@//}"
  elif [[ "${connection_string}" == *"@"* ]]; then
    connection_destination="${connection_string##*@}"
  fi
  local ret_val="FAIL"
  local database_version="N/A"
  local sqlplus_version=""
  local platform=""
  local extra_check="PASS"

  if [[ -f "${oee_dir}/oee_group_extract-SA.sh" ]] ; then
    local extractor_ver
    extractor_ver=$(_oee_detect_extractor_version "${oee_dir}/oee_group_extract-SA.sh")
    platform="$(oee_check_platform)"
    sqlplus_version=$(oee_check_sqlplus_release)
    database_version="$(oee_check_db_version "${connection_string}")"

    if ! command -v zip >/dev/null 2>&1; then
      extra_check="FAIL: zip command is required for OEE extraction."
    elif [[ "${extractor_ver}" == "v6" ]]; then
      if [[ -z "${BASH_VERSINFO[0]:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        extra_check="FAIL: OEE v6.1.1 requires Bash 4.0 or higher."
      elif ! command -v unzip >/dev/null 2>&1; then
        extra_check="FAIL: OEE v6.1.1 requires unzip command."
      elif [[ ! -f "${oee_dir}/oee_group_dbsecurity-SA.sql" ]]; then
        extra_check="FAIL: OEE v6.1.1 requires oee_group_dbsecurity-SA.sql in ${oee_dir}."
      fi
    fi

    if [[ "${sqlplus_version}" == "PASS" ]] && [[ "${database_version}" == "PASS" ]] && [[ "${platform}" == "PASS" ]] && [[ "${extra_check}" == "PASS" ]]; then
      ret_val="PASS"
    fi
  fi

  if [[ "${ret_val}" != "PASS" ]] ; then
    echo "Failure testing connection ${connection_destination}"
    echo "SQLPlus Release   ${sqlplus_version}"
    echo "Database Version  ${database_version}"
    echo "Platform          ${platform}"
    if [[ "${extra_check}" != "PASS" ]]; then
      echo "OEE Prerequisites ${extra_check}"
    fi
  else
    echo "${ret_val}"
  fi
}
