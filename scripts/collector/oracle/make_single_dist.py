import argparse
from pathlib import Path


class SingleDistGenerator:
    """
    Generates a single-purpose Oracle data collector distribution in memory.
    """

    def __init__(self, database_version, tenancy, stats_source, database_role):
        self.database_version = database_version
        self.tenancy = tenancy.upper()
        self.stats_source = stats_source.upper()
        self.stats_dir = self.stats_source.lower()
        self.database_role = database_role.upper()
        self.files = {}

    def _gen_file(self, src_path):
        """
        Reads a file, replaces substitution variables, and stores it in memory.
        """
        src_path = Path(src_path)

        content = src_path.read_text()

        var_files = [
            f"variables_{self.database_version}.txt",
            f"variables_{self.database_role}.txt",
            f"variables_{self.tenancy}.txt",
            f"variables_{self.stats_source}.txt",
            "variables_ALL.txt",
        ]

        for var_file in var_files:
            var_file_path = Path(var_file)
            if not var_file_path.exists():
                continue

            with open(var_file_path, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or line.startswith("--"):
                        continue

                    parts = line.split(":", 1)
                    if len(parts) == 2:
                        subvar = parts[0].strip().replace("&", "").replace(".", "")
                        subval = parts[1].strip().replace("\\", "")
                        content = content.replace(f"&{subvar}.", subval)

        self.files[str(src_path)] = content

    def _replace_includes(self, file_path):
        """
        Replaces all SQL*Plus includes with the contents of the file in memory.
        """
        file_path_str = str(file_path)
        if file_path_str not in self.files:
            return

        content = self.files[file_path_str]
        new_content = []
        for line in content.splitlines(True):
            if line.strip().startswith("@"):
                include_path_str = line.strip()[1:].strip()
                include_path = include_path_str
                include_path_str = str(include_path)
                if include_path_str in self.files:
                    include_content = self.files[include_path_str]
                    for include_line in include_content.splitlines(True):
                        if not include_line.strip().startswith("--"):
                            new_content.append(include_line)
                else:
                    new_content.append(line)
            else:
                new_content.append(line)
        self.files[file_path_str] = "".join(new_content)

    def _copy_file_to_memory(self, src_path):
        """
        Copies a file's content to the in-memory dictionary.
        """
        src_path = Path(src_path)
        src_path = src_path
        self.files[str(src_path)] = src_path.read_text()

    def _copy_tree_to_memory(self, src_dir):
        """
        Copies a directory's contents to the in-memory dictionary.
        """
        src_dir = Path(src_dir)
        for src_path in src_dir.rglob("*"):
            if src_path.is_file():
                src_path = src_path
                self.files[str(src_path)] = src_path.read_text()

    def sort_dict(self, sort_file):
        """
        Sorts the self.files dictionary based on the order of SQL files in op_collect.sql.
        """
        ordered_keys = []
        op_collect_path_in_memory = str(sort_file)
        if op_collect_path_in_memory not in self.files:
            return []

        op_collect_content = self.files[op_collect_path_in_memory]

        for line in op_collect_content.splitlines():
            line = line.strip()
            if line.startswith("@"):
                script_path_str = line[1:].strip()
                if script_path_str.startswith("@@"):  # To catch the "@@" includes.
                    script_path_str = script_path_str[1:]

                # ordered_keys.append(str(script_path_str))
                if script_path_str in self.files:
                    if "@" in self.files[script_path_str]:
                        # Recursive call to get nested includes
                        ordered_keys.extend(self.sort_dict(script_path_str))
                    else:
                        ordered_keys.append(str(script_path_str))

        return ordered_keys

    def make_target(self):
        """
        Generates the collector distribution in memory and returns the files.
        """
        # print(
        #    f"Generating: {self.database_version} {self.tenancy} {self.stats_source} {self.database_role}"
        # )

        # Generate files from extracts
        for fname in Path("sql/extracts").glob("*.sql"):
            self._gen_file(fname)

        # Generate files for the chosen stats_source type
        stats_extract_dir = Path("sql/extracts") / self.stats_dir
        if stats_extract_dir.exists():
            for fname in stats_extract_dir.glob("*.sql"):
                self._gen_file(fname)

        # Copy other necessary files
        self._copy_file_to_memory("sql/op_set_sql_env.sql")

        # Tenancy-specific files
        if self.tenancy == "MULTI_TENANT":
            self._gen_file("sql/op_collect_tenancy_multi.sql")
        elif self.tenancy == "SINGLE_TENANT":
            self._gen_file("sql/op_collect_tenancy_single.sql")

        # Stats source-specific files
        if self.stats_source == "AWR":
            self._gen_file("sql/op_collect_stats_awr.sql")
            self._gen_file(f"sql/extracts/{self.stats_dir}/awrhistosstat.sql")
            self._copy_file_to_memory("sql/prompt_awr.sql")
        elif self.stats_source == "NOSTATS":
            self._copy_file_to_memory("sql/op_collect_stats_nostats.sql")
            self._copy_file_to_memory("sql/prompt_nostats.sql")
        elif self.stats_source == "STATSPACK":
            self._gen_file("sql/op_collect_stats_statspack.sql")
            self._copy_file_to_memory("sql/prompt_statspack.sql")

        # Generate the main driver SQL file
        self._gen_file("sql/op_collect.sql")

        # Replace includes with the contents of the files.
        for fname in list(self.files.keys()):
            if fname.startswith(str("sql/extracts")):
                self._replace_includes(Path(fname))

        ordered_keys = self.sort_dict("sql/op_collect.sql")

        # Create a new dictionary with the sorted keys
        sorted_files = {}

        for key in ordered_keys:
            if key in self.files:
                sorted_files[key] = self.files[key]

        self.files = sorted_files

        print("Done")
        return self.files


def main():
    parser = argparse.ArgumentParser(
        description="Generate single-purpose Oracle collectors."
    )
    parser.add_argument(
        "--database_version",
        required=True,
        help="3 digit Database version, left padded with 0, including the point release. (ex: 102, 121, 190)",
    )
    parser.add_argument(
        "--tenancy", required=True, help="Tenancy (MULTI_TENANT or SINGLE_TENANT)"
    )
    parser.add_argument(
        "--stats_source",
        required=True,
        help="Statistics source (AWR, NOSTATS, or STATSPACK)",
    )
    parser.add_argument(
        "--database_role",
        required=False,
        help="Dataguard database role (PRIMARY or STANDBY)",
        default="PRIMARY",
    )
    args = parser.parse_args()

    generator = SingleDistGenerator(
        database_version=args.database_version,
        tenancy=args.tenancy,
        stats_source=args.stats_source,
        database_role=args.database_role,
    )
    generated_files = generator.make_target()

    # print("\nGenerated files (in memory):")
    for file_path in generated_files.keys():
        print("--name: ", file_path, "!", sep="")
        print(generated_files[file_path])


if __name__ == "__main__":
    main()
