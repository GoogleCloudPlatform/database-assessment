from __future__ import annotations

from typing import Final

RDS_MINOR_VERSION_SUPPORT_MAP: Final[dict[float, int]] = {
    9.6: 10,
    10: 5,
    11: 1,
    12: 2,
}
DB_TYPE_MAP: Final[dict[float, str]] = {
    9.4: "POSTGRES_9_4",
    9.5: "POSTGRES_9_5",
    9.6: "POSTGRES_9_6",
    10: "POSTGRES_10",
    11: "POSTGRES_11",
    12: "POSTGRES_12",
    13: "POSTGRES_13",
    14: "POSTGRES_14",
    15: "POSTGRES_15",
    16: "POSTGRES_16",
}

ALLOYDB_SUPPORTED_EXTENSIONS: Final[set[str]] = set()
CLOUDSQL_SUPPORTED_EXTENSIONS: Final[set[str]] = set()
ALLOYDB_SUPPORTED_COLLATIONS: Final[set[str]] = {
    "default",
    "C",
    "POSIX",
    "ucs_basic",
    "C.UTF-8",
    "en_US",
    "en_US.iso88591",
    "en_US.utf8",
    "und-x-icu",
    "af-x-icu",
    "af-NA-x-icu",
    "af-ZA-x-icu",
    "agq-x-icu",
    "agq-CM-x-icu",
    "ak-x-icu",
    "ak-GH-x-icu",
    "am-x-icu",
    "am-ET-x-icu",
    "ar-x-icu",
    "ar-001-x-icu",
    "ar-AE-x-icu",
    "ar-BH-x-icu",
    "ar-DJ-x-icu",
    "ar-DZ-x-icu",
    "ar-EG-x-icu",
    "ar-EH-x-icu",
    "ar-ER-x-icu",
    "ar-IL-x-icu",
    "ar-IQ-x-icu",
    "ar-JO-x-icu",
    "ar-KM-x-icu",
    "ar-KW-x-icu",
    "ar-LB-x-icu",
    "ar-LY-x-icu",
    "ar-MA-x-icu",
    "ar-MR-x-icu",
    "ar-OM-x-icu",
    "ar-PS-x-icu",
    "ar-QA-x-icu",
    "ar-SA-x-icu",
    "ar-SD-x-icu",
    "ar-SO-x-icu",
    "ar-SS-x-icu",
    "ar-SY-x-icu",
    "ar-TD-x-icu",
    "ar-TN-x-icu",
    "ar-XB-x-icu",
    "ar-YE-x-icu",
    "as-x-icu",
    "as-IN-x-icu",
    "asa-x-icu",
    "asa-TZ-x-icu",
    "ast-x-icu",
    "ast-ES-x-icu",
    "az-x-icu",
    "az-Cyrl-x-icu",
    "az-Cyrl-AZ-x-icu",
    "az-Latn-x-icu",
    "az-Latn-AZ-x-icu",
    "bas-x-icu",
    "bas-CM-x-icu",
    "be-x-icu",
    "be-BY-x-icu",
    "bem-x-icu",
    "bem-ZM-x-icu",
    "bez-x-icu",
    "bez-TZ-x-icu",
    "bg-x-icu",
    "bg-BG-x-icu",
    "bm-x-icu",
    "bm-ML-x-icu",
    "bn-x-icu",
    "bn-BD-x-icu",
    "bn-IN-x-icu",
    "bo-x-icu",
    "bo-CN-x-icu",
    "bo-IN-x-icu",
    "br-x-icu",
    "br-FR-x-icu",
    "brx-x-icu",
    "brx-IN-x-icu",
    "bs-x-icu",
    "bs-Cyrl-x-icu",
    "bs-Cyrl-BA-x-icu",
    "bs-Latn-x-icu",
    "bs-Latn-BA-x-icu",
    "ca-x-icu",
    "ca-AD-x-icu",
    "ca-ES-x-icu",
    "ca-FR-x-icu",
    "ca-IT-x-icu",
    "ccp-x-icu",
    "ccp-BD-x-icu",
    "ccp-IN-x-icu",
    "ce-x-icu",
    "ce-RU-x-icu",
    "ceb-x-icu",
    "ceb-PH-x-icu",
    "cgg-x-icu",
    "cgg-UG-x-icu",
    "chr-x-icu",
    "chr-US-x-icu",
    "ckb-x-icu",
    "ckb-Arab-x-icu",
    "ckb-Arab-IQ-x-icu",
    "ckb-Arab-IR-x-icu",
    "ckb-IQ-x-icu",
    "ckb-IR-x-icu",
    "cs-x-icu",
    "cs-CZ-x-icu",
    "cy-x-icu",
    "cy-GB-x-icu",
    "da-x-icu",
    "da-DK-x-icu",
    "da-GL-x-icu",
    "dav-x-icu",
    "dav-KE-x-icu",
    "de-x-icu",
    "de-AT-x-icu",
    "de-BE-x-icu",
    "de-CH-x-icu",
    "de-DE-x-icu",
    "de-IT-x-icu",
    "de-LI-x-icu",
    "de-LU-x-icu",
    "dje-x-icu",
    "dje-NE-x-icu",
    "doi-x-icu",
    "doi-IN-x-icu",
    "dsb-x-icu",
    "dsb-DE-x-icu",
    "dua-x-icu",
    "dua-CM-x-icu",
    "dyo-x-icu",
    "dyo-SN-x-icu",
    "dz-x-icu",
    "dz-BT-x-icu",
    "ebu-x-icu",
    "ebu-KE-x-icu",
    "ee-x-icu",
    "ee-GH-x-icu",
    "ee-TG-x-icu",
    "el-x-icu",
    "el-CY-x-icu",
    "el-GR-x-icu",
    "en-x-icu",
    "en-001-x-icu",
    "en-150-x-icu",
    "en-AE-x-icu",
    "en-AG-x-icu",
    "en-AI-x-icu",
    "en-AS-x-icu",
    "en-AT-x-icu",
    "en-AU-x-icu",
    "en-BB-x-icu",
    "en-BE-x-icu",
    "en-BI-x-icu",
    "en-BM-x-icu",
    "en-BS-x-icu",
    "en-BW-x-icu",
    "en-BZ-x-icu",
    "en-CA-x-icu",
    "en-CC-x-icu",
    "en-CH-x-icu",
    "en-CK-x-icu",
    "en-CM-x-icu",
    "en-CX-x-icu",
    "en-CY-x-icu",
    "en-DE-x-icu",
    "en-DG-x-icu",
    "en-DK-x-icu",
    "en-DM-x-icu",
    "en-ER-x-icu",
    "en-FI-x-icu",
    "en-FJ-x-icu",
    "en-FK-x-icu",
    "en-FM-x-icu",
    "en-GB-x-icu",
    "en-GD-x-icu",
    "en-GG-x-icu",
    "en-GH-x-icu",
    "en-GI-x-icu",
    "en-GM-x-icu",
    "en-GU-x-icu",
    "en-GY-x-icu",
    "en-HK-x-icu",
    "en-IE-x-icu",
    "en-IL-x-icu",
    "en-IM-x-icu",
    "en-IN-x-icu",
    "en-IO-x-icu",
    "en-JE-x-icu",
    "en-JM-x-icu",
    "en-KE-x-icu",
    "en-KI-x-icu",
    "en-KN-x-icu",
    "en-KY-x-icu",
    "en-LC-x-icu",
    "en-LR-x-icu",
    "en-LS-x-icu",
    "en-MG-x-icu",
    "en-MH-x-icu",
    "en-MO-x-icu",
    "en-MP-x-icu",
    "en-MS-x-icu",
    "en-MT-x-icu",
    "en-MU-x-icu",
    "en-MV-x-icu",
    "en-MW-x-icu",
    "en-MY-x-icu",
    "en-NA-x-icu",
    "en-NF-x-icu",
    "en-NG-x-icu",
    "en-NL-x-icu",
    "en-NR-x-icu",
    "en-NU-x-icu",
    "en-NZ-x-icu",
    "en-PG-x-icu",
    "en-PH-x-icu",
    "en-PK-x-icu",
    "en-PN-x-icu",
    "en-PR-x-icu",
    "en-PW-x-icu",
    "en-RW-x-icu",
    "en-SB-x-icu",
    "en-SC-x-icu",
    "en-SD-x-icu",
    "en-SE-x-icu",
    "en-SG-x-icu",
    "en-SH-x-icu",
    "en-SI-x-icu",
    "en-SL-x-icu",
    "en-SS-x-icu",
    "en-SX-x-icu",
    "en-SZ-x-icu",
    "en-TC-x-icu",
    "en-TK-x-icu",
    "en-TO-x-icu",
    "en-TT-x-icu",
    "en-TV-x-icu",
    "en-TZ-x-icu",
    "en-UG-x-icu",
    "en-UM-x-icu",
    "en-US-x-icu",
    "en-US-u-va-posix-x-icu",
    "en-VC-x-icu",
    "en-VG-x-icu",
    "en-VI-x-icu",
    "en-VU-x-icu",
    "en-WS-x-icu",
    "en-XA-x-icu",
    "en-ZA-x-icu",
    "en-ZM-x-icu",
    "en-ZW-x-icu",
    "eo-x-icu",
    "eo-001-x-icu",
    "es-x-icu",
    "es-419-x-icu",
    "es-AR-x-icu",
    "es-BO-x-icu",
    "es-BR-x-icu",
    "es-BZ-x-icu",
    "es-CL-x-icu",
    "es-CO-x-icu",
    "es-CR-x-icu",
    "es-CU-x-icu",
    "es-DO-x-icu",
    "es-EA-x-icu",
    "es-EC-x-icu",
    "es-ES-x-icu",
    "es-GQ-x-icu",
    "es-GT-x-icu",
    "es-HN-x-icu",
    "es-IC-x-icu",
    "es-MX-x-icu",
    "es-NI-x-icu",
    "es-PA-x-icu",
    "es-PE-x-icu",
    "es-PH-x-icu",
    "es-PR-x-icu",
    "es-PY-x-icu",
    "es-SV-x-icu",
    "es-US-x-icu",
    "es-UY-x-icu",
    "es-VE-x-icu",
    "et-x-icu",
    "et-EE-x-icu",
    "eu-x-icu",
    "eu-ES-x-icu",
    "ewo-x-icu",
    "ewo-CM-x-icu",
    "fa-x-icu",
    "fa-AF-x-icu",
    "fa-IR-x-icu",
    "ff-x-icu",
    "ff-Adlm-x-icu",
    "ff-Adlm-BF-x-icu",
    "ff-Adlm-CM-x-icu",
    "ff-Adlm-GH-x-icu",
    "ff-Adlm-GM-x-icu",
    "ff-Adlm-GN-x-icu",
    "ff-Adlm-GW-x-icu",
    "ff-Adlm-LR-x-icu",
    "ff-Adlm-MR-x-icu",
    "ff-Adlm-NE-x-icu",
    "ff-Adlm-NG-x-icu",
    "ff-Adlm-SL-x-icu",
    "ff-Adlm-SN-x-icu",
    "ff-Latn-x-icu",
    "ff-Latn-BF-x-icu",
    "ff-Latn-CM-x-icu",
    "ff-Latn-GH-x-icu",
    "ff-Latn-GM-x-icu",
    "ff-Latn-GN-x-icu",
    "ff-Latn-GW-x-icu",
    "ff-Latn-LR-x-icu",
    "ff-Latn-MR-x-icu",
    "ff-Latn-NE-x-icu",
    "ff-Latn-NG-x-icu",
    "ff-Latn-SL-x-icu",
    "ff-Latn-SN-x-icu",
    "fi-x-icu",
    "fi-FI-x-icu",
    "fil-x-icu",
    "fil-PH-x-icu",
    "fo-x-icu",
    "fo-DK-x-icu",
    "fo-FO-x-icu",
    "fr-x-icu",
    "fr-BE-x-icu",
    "fr-BF-x-icu",
    "fr-BI-x-icu",
    "fr-BJ-x-icu",
    "fr-BL-x-icu",
    "fr-CA-x-icu",
    "fr-CD-x-icu",
    "fr-CF-x-icu",
    "fr-CG-x-icu",
    "fr-CH-x-icu",
    "fr-CI-x-icu",
    "fr-CM-x-icu",
    "fr-DJ-x-icu",
    "fr-DZ-x-icu",
    "fr-FR-x-icu",
    "fr-GA-x-icu",
    "fr-GF-x-icu",
    "fr-GN-x-icu",
    "fr-GP-x-icu",
    "fr-GQ-x-icu",
    "fr-HT-x-icu",
    "fr-KM-x-icu",
    "fr-LU-x-icu",
    "fr-MA-x-icu",
    "fr-MC-x-icu",
    "fr-MF-x-icu",
    "fr-MG-x-icu",
    "fr-ML-x-icu",
    "fr-MQ-x-icu",
    "fr-MR-x-icu",
    "fr-MU-x-icu",
    "fr-NC-x-icu",
    "fr-NE-x-icu",
    "fr-PF-x-icu",
    "fr-PM-x-icu",
    "fr-RE-x-icu",
    "fr-RW-x-icu",
    "fr-SC-x-icu",
    "fr-SN-x-icu",
    "fr-SY-x-icu",
    "fr-TD-x-icu",
    "fr-TG-x-icu",
    "fr-TN-x-icu",
    "fr-VU-x-icu",
    "fr-WF-x-icu",
    "fr-YT-x-icu",
    "fur-x-icu",
    "fur-IT-x-icu",
    "fy-x-icu",
    "fy-NL-x-icu",
    "ga-x-icu",
    "ga-GB-x-icu",
    "ga-IE-x-icu",
    "gd-x-icu",
    "gd-GB-x-icu",
    "gl-x-icu",
    "gl-ES-x-icu",
    "gsw-x-icu",
    "gsw-CH-x-icu",
    "gsw-FR-x-icu",
    "gsw-LI-x-icu",
    "gu-x-icu",
    "gu-IN-x-icu",
    "guz-x-icu",
    "guz-KE-x-icu",
    "gv-x-icu",
    "gv-IM-x-icu",
    "ha-x-icu",
    "ha-GH-x-icu",
    "ha-NE-x-icu",
    "ha-NG-x-icu",
    "haw-x-icu",
    "haw-US-x-icu",
    "he-x-icu",
    "he-IL-x-icu",
    "hi-x-icu",
    "hi-IN-x-icu",
    "hi-Latn-x-icu",
    "hi-Latn-IN-x-icu",
    "hr-x-icu",
    "hr-BA-x-icu",
    "hr-HR-x-icu",
    "hsb-x-icu",
    "hsb-DE-x-icu",
    "hu-x-icu",
    "hu-HU-x-icu",
    "hy-x-icu",
    "hy-AM-x-icu",
    "ia-x-icu",
    "ia-001-x-icu",
    "id-x-icu",
    "id-ID-x-icu",
    "ig-x-icu",
    "ig-NG-x-icu",
    "ii-x-icu",
    "ii-CN-x-icu",
    "is-x-icu",
    "is-IS-x-icu",
    "it-x-icu",
    "it-CH-x-icu",
    "it-IT-x-icu",
    "it-SM-x-icu",
    "it-VA-x-icu",
    "ja-x-icu",
    "ja-JP-x-icu",
    "jgo-x-icu",
    "jgo-CM-x-icu",
    "jmc-x-icu",
    "jmc-TZ-x-icu",
    "jv-x-icu",
    "jv-ID-x-icu",
    "ka-x-icu",
    "ka-GE-x-icu",
    "kab-x-icu",
    "kab-DZ-x-icu",
    "kam-x-icu",
    "kam-KE-x-icu",
    "kde-x-icu",
    "kde-TZ-x-icu",
    "kea-x-icu",
    "kea-CV-x-icu",
    "kgp-x-icu",
    "kgp-BR-x-icu",
    "khq-x-icu",
    "khq-ML-x-icu",
    "ki-x-icu",
    "ki-KE-x-icu",
    "kk-x-icu",
    "kk-KZ-x-icu",
    "kkj-x-icu",
    "kkj-CM-x-icu",
    "kl-x-icu",
    "kl-GL-x-icu",
    "kln-x-icu",
    "kln-KE-x-icu",
    "km-x-icu",
    "km-KH-x-icu",
    "kn-x-icu",
    "kn-IN-x-icu",
    "ko-x-icu",
    "ko-KP-x-icu",
    "ko-KR-x-icu",
    "kok-x-icu",
    "kok-IN-x-icu",
    "ks-x-icu",
    "ks-Arab-x-icu",
    "ks-Arab-IN-x-icu",
    "ks-Deva-x-icu",
    "ks-Deva-IN-x-icu",
    "ksb-x-icu",
    "ksb-TZ-x-icu",
    "ksf-x-icu",
    "ksf-CM-x-icu",
    "ksh-x-icu",
    "ksh-DE-x-icu",
    "ku-x-icu",
    "ku-TR-x-icu",
    "kw-x-icu",
    "kw-GB-x-icu",
    "ky-x-icu",
    "ky-KG-x-icu",
    "lag-x-icu",
    "lag-TZ-x-icu",
    "lb-x-icu",
    "lb-LU-x-icu",
    "lg-x-icu",
    "lg-UG-x-icu",
    "lkt-x-icu",
    "lkt-US-x-icu",
    "ln-x-icu",
    "ln-AO-x-icu",
    "ln-CD-x-icu",
    "ln-CF-x-icu",
    "ln-CG-x-icu",
    "lo-x-icu",
    "lo-LA-x-icu",
    "lrc-x-icu",
    "lrc-IQ-x-icu",
    "lrc-IR-x-icu",
    "lt-x-icu",
    "lt-LT-x-icu",
    "lu-x-icu",
    "lu-CD-x-icu",
    "luo-x-icu",
    "luo-KE-x-icu",
    "luy-x-icu",
    "luy-KE-x-icu",
    "lv-x-icu",
    "lv-LV-x-icu",
    "mai-x-icu",
    "mai-IN-x-icu",
    "mas-x-icu",
    "mas-KE-x-icu",
    "mas-TZ-x-icu",
    "mer-x-icu",
    "mer-KE-x-icu",
    "mfe-x-icu",
    "mfe-MU-x-icu",
    "mg-x-icu",
    "mg-MG-x-icu",
    "mgh-x-icu",
    "mgh-MZ-x-icu",
    "mgo-x-icu",
    "mgo-CM-x-icu",
    "mi-x-icu",
    "mi-NZ-x-icu",
    "mk-x-icu",
    "mk-MK-x-icu",
    "ml-x-icu",
    "ml-IN-x-icu",
    "mn-x-icu",
    "mn-MN-x-icu",
    "mni-x-icu",
    "mni-Beng-x-icu",
    "mni-Beng-IN-x-icu",
    "mr-x-icu",
    "mr-IN-x-icu",
    "ms-x-icu",
    "ms-BN-x-icu",
    "ms-ID-x-icu",
    "ms-MY-x-icu",
    "ms-SG-x-icu",
    "mt-x-icu",
    "mt-MT-x-icu",
    "mua-x-icu",
    "mua-CM-x-icu",
    "my-x-icu",
    "my-MM-x-icu",
    "mzn-x-icu",
    "mzn-IR-x-icu",
    "naq-x-icu",
    "naq-NA-x-icu",
    "nb-x-icu",
    "nb-NO-x-icu",
    "nb-SJ-x-icu",
    "nd-x-icu",
    "nd-ZW-x-icu",
    "ne-x-icu",
    "ne-IN-x-icu",
    "ne-NP-x-icu",
    "nl-x-icu",
    "nl-AW-x-icu",
    "nl-BE-x-icu",
    "nl-BQ-x-icu",
    "nl-CW-x-icu",
    "nl-NL-x-icu",
    "nl-SR-x-icu",
    "nl-SX-x-icu",
    "nmg-x-icu",
    "nmg-CM-x-icu",
    "nn-x-icu",
    "nn-NO-x-icu",
    "nnh-x-icu",
    "nnh-CM-x-icu",
    "no-x-icu",
    "nus-x-icu",
    "nus-SS-x-icu",
    "nyn-x-icu",
    "nyn-UG-x-icu",
    "om-x-icu",
    "om-ET-x-icu",
    "om-KE-x-icu",
    "or-x-icu",
    "or-IN-x-icu",
    "os-x-icu",
    "os-GE-x-icu",
    "os-RU-x-icu",
    "pa-x-icu",
    "pa-Arab-x-icu",
    "pa-Arab-PK-x-icu",
    "pa-Guru-x-icu",
    "pa-Guru-IN-x-icu",
    "pcm-x-icu",
    "pcm-NG-x-icu",
    "pl-x-icu",
    "pl-PL-x-icu",
    "ps-x-icu",
    "ps-AF-x-icu",
    "ps-PK-x-icu",
    "pt-x-icu",
    "pt-AO-x-icu",
    "pt-BR-x-icu",
    "pt-CH-x-icu",
    "pt-CV-x-icu",
    "pt-GQ-x-icu",
    "pt-GW-x-icu",
    "pt-LU-x-icu",
    "pt-MO-x-icu",
    "pt-MZ-x-icu",
    "pt-PT-x-icu",
    "pt-ST-x-icu",
    "pt-TL-x-icu",
    "qu-x-icu",
    "qu-BO-x-icu",
    "qu-EC-x-icu",
    "qu-PE-x-icu",
    "rm-x-icu",
    "rm-CH-x-icu",
    "rn-x-icu",
    "rn-BI-x-icu",
    "ro-x-icu",
    "ro-MD-x-icu",
    "ro-RO-x-icu",
    "rof-x-icu",
    "rof-TZ-x-icu",
    "ru-x-icu",
    "ru-BY-x-icu",
    "ru-KG-x-icu",
    "ru-KZ-x-icu",
    "ru-MD-x-icu",
    "ru-RU-x-icu",
    "ru-UA-x-icu",
    "rw-x-icu",
    "rw-RW-x-icu",
    "rwk-x-icu",
    "rwk-TZ-x-icu",
    "sa-x-icu",
    "sa-IN-x-icu",
    "sah-x-icu",
    "sah-RU-x-icu",
    "saq-x-icu",
    "saq-KE-x-icu",
    "sat-x-icu",
    "sat-Olck-x-icu",
    "sat-Olck-IN-x-icu",
    "sbp-x-icu",
    "sbp-TZ-x-icu",
    "sc-x-icu",
    "sc-IT-x-icu",
    "sd-x-icu",
    "sd-Arab-x-icu",
    "sd-Arab-PK-x-icu",
    "sd-Deva-x-icu",
    "sd-Deva-IN-x-icu",
    "se-x-icu",
    "se-FI-x-icu",
    "se-NO-x-icu",
    "se-SE-x-icu",
    "seh-x-icu",
    "seh-MZ-x-icu",
    "ses-x-icu",
    "ses-ML-x-icu",
    "sg-x-icu",
    "sg-CF-x-icu",
    "shi-x-icu",
    "shi-Latn-x-icu",
    "shi-Latn-MA-x-icu",
    "shi-Tfng-x-icu",
    "shi-Tfng-MA-x-icu",
    "si-x-icu",
    "si-LK-x-icu",
    "sk-x-icu",
    "sk-SK-x-icu",
    "sl-x-icu",
    "sl-SI-x-icu",
    "smn-x-icu",
    "smn-FI-x-icu",
    "sn-x-icu",
    "sn-ZW-x-icu",
    "so-x-icu",
    "so-DJ-x-icu",
    "so-ET-x-icu",
    "so-KE-x-icu",
    "so-SO-x-icu",
    "sq-x-icu",
    "sq-AL-x-icu",
    "sq-MK-x-icu",
    "sq-XK-x-icu",
    "sr-x-icu",
    "sr-Cyrl-x-icu",
    "sr-Cyrl-BA-x-icu",
    "sr-Cyrl-ME-x-icu",
    "sr-Cyrl-RS-x-icu",
    "sr-Cyrl-XK-x-icu",
    "sr-Latn-x-icu",
    "sr-Latn-BA-x-icu",
    "sr-Latn-ME-x-icu",
    "sr-Latn-RS-x-icu",
    "sr-Latn-XK-x-icu",
    "su-x-icu",
    "su-Latn-x-icu",
    "su-Latn-ID-x-icu",
    "sv-x-icu",
    "sv-AX-x-icu",
    "sv-FI-x-icu",
    "sv-SE-x-icu",
    "sw-x-icu",
    "sw-CD-x-icu",
    "sw-KE-x-icu",
    "sw-TZ-x-icu",
    "sw-UG-x-icu",
    "ta-x-icu",
    "ta-IN-x-icu",
    "ta-LK-x-icu",
    "ta-MY-x-icu",
    "ta-SG-x-icu",
    "te-x-icu",
    "te-IN-x-icu",
    "teo-x-icu",
    "teo-KE-x-icu",
    "teo-UG-x-icu",
    "tg-x-icu",
    "tg-TJ-x-icu",
    "th-x-icu",
    "th-TH-x-icu",
    "ti-x-icu",
    "ti-ER-x-icu",
    "ti-ET-x-icu",
    "tk-x-icu",
    "tk-TM-x-icu",
    "to-x-icu",
    "to-TO-x-icu",
    "tr-x-icu",
    "tr-CY-x-icu",
    "tr-TR-x-icu",
    "tt-x-icu",
    "tt-RU-x-icu",
    "twq-x-icu",
    "twq-NE-x-icu",
    "tzm-x-icu",
    "tzm-MA-x-icu",
    "ug-x-icu",
    "ug-CN-x-icu",
    "uk-x-icu",
    "uk-UA-x-icu",
    "ur-x-icu",
    "ur-IN-x-icu",
    "ur-PK-x-icu",
    "uz-x-icu",
    "uz-Arab-x-icu",
    "uz-Arab-AF-x-icu",
    "uz-Cyrl-x-icu",
    "uz-Cyrl-UZ-x-icu",
    "uz-Latn-x-icu",
    "uz-Latn-UZ-x-icu",
    "vai-x-icu",
    "vai-Latn-x-icu",
    "vai-Latn-LR-x-icu",
    "vai-Vaii-x-icu",
    "vai-Vaii-LR-x-icu",
    "vi-x-icu",
    "vi-VN-x-icu",
    "vun-x-icu",
    "vun-TZ-x-icu",
    "wae-x-icu",
    "wae-CH-x-icu",
    "wo-x-icu",
    "wo-SN-x-icu",
    "xh-x-icu",
    "xh-ZA-x-icu",
    "xog-x-icu",
    "xog-UG-x-icu",
    "yav-x-icu",
    "yav-CM-x-icu",
    "yi-x-icu",
    "yi-001-x-icu",
    "yo-x-icu",
    "yo-BJ-x-icu",
    "yo-NG-x-icu",
    "yrl-x-icu",
    "yrl-BR-x-icu",
    "yrl-CO-x-icu",
    "yrl-VE-x-icu",
    "yue-x-icu",
    "yue-Hans-x-icu",
    "yue-Hans-CN-x-icu",
    "yue-Hant-x-icu",
    "yue-Hant-HK-x-icu",
    "zgh-x-icu",
    "zgh-MA-x-icu",
    "zh-x-icu",
    "zh-Hans-x-icu",
    "zh-Hans-CN-x-icu",
    "zh-Hans-HK-x-icu",
    "zh-Hans-MO-x-icu",
    "zh-Hans-SG-x-icu",
    "zh-Hant-x-icu",
    "zh-Hant-HK-x-icu",
    "zh-Hant-MO-x-icu",
    "zh-Hant-TW-x-icu",
    "zu-x-icu",
    "zu-ZA-x-icu",
}
CLOUDSQL_SUPPORTED_COLLATIONS: Final[set[str]] = {
    "default",
    "C",
    "POSIX",
    "ucs_basic",
    "C.UTF-8",
    "en_US",
    "en_US.iso88591",
    "en_US.utf8",
    "und-x-icu",
    "af-x-icu",
    "af-NA-x-icu",
    "af-ZA-x-icu",
    "agq-x-icu",
    "agq-CM-x-icu",
    "ak-x-icu",
    "ak-GH-x-icu",
    "am-x-icu",
    "am-ET-x-icu",
    "ar-x-icu",
    "ar-001-x-icu",
    "ar-AE-x-icu",
    "ar-BH-x-icu",
    "ar-DJ-x-icu",
    "ar-DZ-x-icu",
    "ar-EG-x-icu",
    "ar-EH-x-icu",
    "ar-ER-x-icu",
    "ar-IL-x-icu",
    "ar-IQ-x-icu",
    "ar-JO-x-icu",
    "ar-KM-x-icu",
    "ar-KW-x-icu",
    "ar-LB-x-icu",
    "ar-LY-x-icu",
    "ar-MA-x-icu",
    "ar-MR-x-icu",
    "ar-OM-x-icu",
    "ar-PS-x-icu",
    "ar-QA-x-icu",
    "ar-SA-x-icu",
    "ar-SD-x-icu",
    "ar-SO-x-icu",
    "ar-SS-x-icu",
    "ar-SY-x-icu",
    "ar-TD-x-icu",
    "ar-TN-x-icu",
    "ar-XB-x-icu",
    "ar-YE-x-icu",
    "as-x-icu",
    "as-IN-x-icu",
    "asa-x-icu",
    "asa-TZ-x-icu",
    "ast-x-icu",
    "ast-ES-x-icu",
    "az-x-icu",
    "az-Cyrl-x-icu",
    "az-Cyrl-AZ-x-icu",
    "az-Latn-x-icu",
    "az-Latn-AZ-x-icu",
    "bas-x-icu",
    "bas-CM-x-icu",
    "be-x-icu",
    "be-BY-x-icu",
    "bem-x-icu",
    "bem-ZM-x-icu",
    "bez-x-icu",
    "bez-TZ-x-icu",
    "bg-x-icu",
    "bg-BG-x-icu",
    "bm-x-icu",
    "bm-ML-x-icu",
    "bn-x-icu",
    "bn-BD-x-icu",
    "bn-IN-x-icu",
    "bo-x-icu",
    "bo-CN-x-icu",
    "bo-IN-x-icu",
    "br-x-icu",
    "br-FR-x-icu",
    "brx-x-icu",
    "brx-IN-x-icu",
    "bs-x-icu",
    "bs-Cyrl-x-icu",
    "bs-Cyrl-BA-x-icu",
    "bs-Latn-x-icu",
    "bs-Latn-BA-x-icu",
    "ca-x-icu",
    "ca-AD-x-icu",
    "ca-ES-x-icu",
    "ca-FR-x-icu",
    "ca-IT-x-icu",
    "ccp-x-icu",
    "ccp-BD-x-icu",
    "ccp-IN-x-icu",
    "ce-x-icu",
    "ce-RU-x-icu",
    "ceb-x-icu",
    "ceb-PH-x-icu",
    "cgg-x-icu",
    "cgg-UG-x-icu",
    "chr-x-icu",
    "chr-US-x-icu",
    "ckb-x-icu",
    "ckb-Arab-x-icu",
    "ckb-Arab-IQ-x-icu",
    "ckb-Arab-IR-x-icu",
    "ckb-IQ-x-icu",
    "ckb-IR-x-icu",
    "cs-x-icu",
    "cs-CZ-x-icu",
    "cy-x-icu",
    "cy-GB-x-icu",
    "da-x-icu",
    "da-DK-x-icu",
    "da-GL-x-icu",
    "dav-x-icu",
    "dav-KE-x-icu",
    "de-x-icu",
    "de-AT-x-icu",
    "de-BE-x-icu",
    "de-CH-x-icu",
    "de-DE-x-icu",
    "de-IT-x-icu",
    "de-LI-x-icu",
    "de-LU-x-icu",
    "dje-x-icu",
    "dje-NE-x-icu",
    "doi-x-icu",
    "doi-IN-x-icu",
    "dsb-x-icu",
    "dsb-DE-x-icu",
    "dua-x-icu",
    "dua-CM-x-icu",
    "dyo-x-icu",
    "dyo-SN-x-icu",
    "dz-x-icu",
    "dz-BT-x-icu",
    "ebu-x-icu",
    "ebu-KE-x-icu",
    "ee-x-icu",
    "ee-GH-x-icu",
    "ee-TG-x-icu",
    "el-x-icu",
    "el-CY-x-icu",
    "el-GR-x-icu",
    "en-x-icu",
    "en-001-x-icu",
    "en-150-x-icu",
    "en-AE-x-icu",
    "en-AG-x-icu",
    "en-AI-x-icu",
    "en-AS-x-icu",
    "en-AT-x-icu",
    "en-AU-x-icu",
    "en-BB-x-icu",
    "en-BE-x-icu",
    "en-BI-x-icu",
    "en-BM-x-icu",
    "en-BS-x-icu",
    "en-BW-x-icu",
    "en-BZ-x-icu",
    "en-CA-x-icu",
    "en-CC-x-icu",
    "en-CH-x-icu",
    "en-CK-x-icu",
    "en-CM-x-icu",
    "en-CX-x-icu",
    "en-CY-x-icu",
    "en-DE-x-icu",
    "en-DG-x-icu",
    "en-DK-x-icu",
    "en-DM-x-icu",
    "en-ER-x-icu",
    "en-FI-x-icu",
    "en-FJ-x-icu",
    "en-FK-x-icu",
    "en-FM-x-icu",
    "en-GB-x-icu",
    "en-GD-x-icu",
    "en-GG-x-icu",
    "en-GH-x-icu",
    "en-GI-x-icu",
    "en-GM-x-icu",
    "en-GU-x-icu",
    "en-GY-x-icu",
    "en-HK-x-icu",
    "en-IE-x-icu",
    "en-IL-x-icu",
    "en-IM-x-icu",
    "en-IN-x-icu",
    "en-IO-x-icu",
    "en-JE-x-icu",
    "en-JM-x-icu",
    "en-KE-x-icu",
    "en-KI-x-icu",
    "en-KN-x-icu",
    "en-KY-x-icu",
    "en-LC-x-icu",
    "en-LR-x-icu",
    "en-LS-x-icu",
    "en-MG-x-icu",
    "en-MH-x-icu",
    "en-MO-x-icu",
    "en-MP-x-icu",
    "en-MS-x-icu",
    "en-MT-x-icu",
    "en-MU-x-icu",
    "en-MV-x-icu",
    "en-MW-x-icu",
    "en-MY-x-icu",
    "en-NA-x-icu",
    "en-NF-x-icu",
    "en-NG-x-icu",
    "en-NL-x-icu",
    "en-NR-x-icu",
    "en-NU-x-icu",
    "en-NZ-x-icu",
    "en-PG-x-icu",
    "en-PH-x-icu",
    "en-PK-x-icu",
    "en-PN-x-icu",
    "en-PR-x-icu",
    "en-PW-x-icu",
    "en-RW-x-icu",
    "en-SB-x-icu",
    "en-SC-x-icu",
    "en-SD-x-icu",
    "en-SE-x-icu",
    "en-SG-x-icu",
    "en-SH-x-icu",
    "en-SI-x-icu",
    "en-SL-x-icu",
    "en-SS-x-icu",
    "en-SX-x-icu",
    "en-SZ-x-icu",
    "en-TC-x-icu",
    "en-TK-x-icu",
    "en-TO-x-icu",
    "en-TT-x-icu",
    "en-TV-x-icu",
    "en-TZ-x-icu",
    "en-UG-x-icu",
    "en-UM-x-icu",
    "en-US-x-icu",
    "en-US-u-va-posix-x-icu",
    "en-VC-x-icu",
    "en-VG-x-icu",
    "en-VI-x-icu",
    "en-VU-x-icu",
    "en-WS-x-icu",
    "en-XA-x-icu",
    "en-ZA-x-icu",
    "en-ZM-x-icu",
    "en-ZW-x-icu",
    "eo-x-icu",
    "eo-001-x-icu",
    "es-x-icu",
    "es-419-x-icu",
    "es-AR-x-icu",
    "es-BO-x-icu",
    "es-BR-x-icu",
    "es-BZ-x-icu",
    "es-CL-x-icu",
    "es-CO-x-icu",
    "es-CR-x-icu",
    "es-CU-x-icu",
    "es-DO-x-icu",
    "es-EA-x-icu",
    "es-EC-x-icu",
    "es-ES-x-icu",
    "es-GQ-x-icu",
    "es-GT-x-icu",
    "es-HN-x-icu",
    "es-IC-x-icu",
    "es-MX-x-icu",
    "es-NI-x-icu",
    "es-PA-x-icu",
    "es-PE-x-icu",
    "es-PH-x-icu",
    "es-PR-x-icu",
    "es-PY-x-icu",
    "es-SV-x-icu",
    "es-US-x-icu",
    "es-UY-x-icu",
    "es-VE-x-icu",
    "et-x-icu",
    "et-EE-x-icu",
    "eu-x-icu",
    "eu-ES-x-icu",
    "ewo-x-icu",
    "ewo-CM-x-icu",
    "fa-x-icu",
    "fa-AF-x-icu",
    "fa-IR-x-icu",
    "ff-x-icu",
    "ff-Adlm-x-icu",
    "ff-Adlm-BF-x-icu",
    "ff-Adlm-CM-x-icu",
    "ff-Adlm-GH-x-icu",
    "ff-Adlm-GM-x-icu",
    "ff-Adlm-GN-x-icu",
    "ff-Adlm-GW-x-icu",
    "ff-Adlm-LR-x-icu",
    "ff-Adlm-MR-x-icu",
    "ff-Adlm-NE-x-icu",
    "ff-Adlm-NG-x-icu",
    "ff-Adlm-SL-x-icu",
    "ff-Adlm-SN-x-icu",
    "ff-Latn-x-icu",
    "ff-Latn-BF-x-icu",
    "ff-Latn-CM-x-icu",
    "ff-Latn-GH-x-icu",
    "ff-Latn-GM-x-icu",
    "ff-Latn-GN-x-icu",
    "ff-Latn-GW-x-icu",
    "ff-Latn-LR-x-icu",
    "ff-Latn-MR-x-icu",
    "ff-Latn-NE-x-icu",
    "ff-Latn-NG-x-icu",
    "ff-Latn-SL-x-icu",
    "ff-Latn-SN-x-icu",
    "fi-x-icu",
    "fi-FI-x-icu",
    "fil-x-icu",
    "fil-PH-x-icu",
    "fo-x-icu",
    "fo-DK-x-icu",
    "fo-FO-x-icu",
    "fr-x-icu",
    "fr-BE-x-icu",
    "fr-BF-x-icu",
    "fr-BI-x-icu",
    "fr-BJ-x-icu",
    "fr-BL-x-icu",
    "fr-CA-x-icu",
    "fr-CD-x-icu",
    "fr-CF-x-icu",
    "fr-CG-x-icu",
    "fr-CH-x-icu",
    "fr-CI-x-icu",
    "fr-CM-x-icu",
    "fr-DJ-x-icu",
    "fr-DZ-x-icu",
    "fr-FR-x-icu",
    "fr-GA-x-icu",
    "fr-GF-x-icu",
    "fr-GN-x-icu",
    "fr-GP-x-icu",
    "fr-GQ-x-icu",
    "fr-HT-x-icu",
    "fr-KM-x-icu",
    "fr-LU-x-icu",
    "fr-MA-x-icu",
    "fr-MC-x-icu",
    "fr-MF-x-icu",
    "fr-MG-x-icu",
    "fr-ML-x-icu",
    "fr-MQ-x-icu",
    "fr-MR-x-icu",
    "fr-MU-x-icu",
    "fr-NC-x-icu",
    "fr-NE-x-icu",
    "fr-PF-x-icu",
    "fr-PM-x-icu",
    "fr-RE-x-icu",
    "fr-RW-x-icu",
    "fr-SC-x-icu",
    "fr-SN-x-icu",
    "fr-SY-x-icu",
    "fr-TD-x-icu",
    "fr-TG-x-icu",
    "fr-TN-x-icu",
    "fr-VU-x-icu",
    "fr-WF-x-icu",
    "fr-YT-x-icu",
    "fur-x-icu",
    "fur-IT-x-icu",
    "fy-x-icu",
    "fy-NL-x-icu",
    "ga-x-icu",
    "ga-GB-x-icu",
    "ga-IE-x-icu",
    "gd-x-icu",
    "gd-GB-x-icu",
    "gl-x-icu",
    "gl-ES-x-icu",
    "gsw-x-icu",
    "gsw-CH-x-icu",
    "gsw-FR-x-icu",
    "gsw-LI-x-icu",
    "gu-x-icu",
    "gu-IN-x-icu",
    "guz-x-icu",
    "guz-KE-x-icu",
    "gv-x-icu",
    "gv-IM-x-icu",
    "ha-x-icu",
    "ha-GH-x-icu",
    "ha-NE-x-icu",
    "ha-NG-x-icu",
    "haw-x-icu",
    "haw-US-x-icu",
    "he-x-icu",
    "he-IL-x-icu",
    "hi-x-icu",
    "hi-IN-x-icu",
    "hi-Latn-x-icu",
    "hi-Latn-IN-x-icu",
    "hr-x-icu",
    "hr-BA-x-icu",
    "hr-HR-x-icu",
    "hsb-x-icu",
    "hsb-DE-x-icu",
    "hu-x-icu",
    "hu-HU-x-icu",
    "hy-x-icu",
    "hy-AM-x-icu",
    "ia-x-icu",
    "ia-001-x-icu",
    "id-x-icu",
    "id-ID-x-icu",
    "ig-x-icu",
    "ig-NG-x-icu",
    "ii-x-icu",
    "ii-CN-x-icu",
    "is-x-icu",
    "is-IS-x-icu",
    "it-x-icu",
    "it-CH-x-icu",
    "it-IT-x-icu",
    "it-SM-x-icu",
    "it-VA-x-icu",
    "ja-x-icu",
    "ja-JP-x-icu",
    "jgo-x-icu",
    "jgo-CM-x-icu",
    "jmc-x-icu",
    "jmc-TZ-x-icu",
    "jv-x-icu",
    "jv-ID-x-icu",
    "ka-x-icu",
    "ka-GE-x-icu",
    "kab-x-icu",
    "kab-DZ-x-icu",
    "kam-x-icu",
    "kam-KE-x-icu",
    "kde-x-icu",
    "kde-TZ-x-icu",
    "kea-x-icu",
    "kea-CV-x-icu",
    "kgp-x-icu",
    "kgp-BR-x-icu",
    "khq-x-icu",
    "khq-ML-x-icu",
    "ki-x-icu",
    "ki-KE-x-icu",
    "kk-x-icu",
    "kk-KZ-x-icu",
    "kkj-x-icu",
    "kkj-CM-x-icu",
    "kl-x-icu",
    "kl-GL-x-icu",
    "kln-x-icu",
    "kln-KE-x-icu",
    "km-x-icu",
    "km-KH-x-icu",
    "kn-x-icu",
    "kn-IN-x-icu",
    "ko-x-icu",
    "ko-KP-x-icu",
    "ko-KR-x-icu",
    "kok-x-icu",
    "kok-IN-x-icu",
    "ks-x-icu",
    "ks-Arab-x-icu",
    "ks-Arab-IN-x-icu",
    "ks-Deva-x-icu",
    "ks-Deva-IN-x-icu",
    "ksb-x-icu",
    "ksb-TZ-x-icu",
    "ksf-x-icu",
    "ksf-CM-x-icu",
    "ksh-x-icu",
    "ksh-DE-x-icu",
    "ku-x-icu",
    "ku-TR-x-icu",
    "kw-x-icu",
    "kw-GB-x-icu",
    "ky-x-icu",
    "ky-KG-x-icu",
    "lag-x-icu",
    "lag-TZ-x-icu",
    "lb-x-icu",
    "lb-LU-x-icu",
    "lg-x-icu",
    "lg-UG-x-icu",
    "lkt-x-icu",
    "lkt-US-x-icu",
    "ln-x-icu",
    "ln-AO-x-icu",
    "ln-CD-x-icu",
    "ln-CF-x-icu",
    "ln-CG-x-icu",
    "lo-x-icu",
    "lo-LA-x-icu",
    "lrc-x-icu",
    "lrc-IQ-x-icu",
    "lrc-IR-x-icu",
    "lt-x-icu",
    "lt-LT-x-icu",
    "lu-x-icu",
    "lu-CD-x-icu",
    "luo-x-icu",
    "luo-KE-x-icu",
    "luy-x-icu",
    "luy-KE-x-icu",
    "lv-x-icu",
    "lv-LV-x-icu",
    "mai-x-icu",
    "mai-IN-x-icu",
    "mas-x-icu",
    "mas-KE-x-icu",
    "mas-TZ-x-icu",
    "mer-x-icu",
    "mer-KE-x-icu",
    "mfe-x-icu",
    "mfe-MU-x-icu",
    "mg-x-icu",
    "mg-MG-x-icu",
    "mgh-x-icu",
    "mgh-MZ-x-icu",
    "mgo-x-icu",
    "mgo-CM-x-icu",
    "mi-x-icu",
    "mi-NZ-x-icu",
    "mk-x-icu",
    "mk-MK-x-icu",
    "ml-x-icu",
    "ml-IN-x-icu",
    "mn-x-icu",
    "mn-MN-x-icu",
    "mni-x-icu",
    "mni-Beng-x-icu",
    "mni-Beng-IN-x-icu",
    "mr-x-icu",
    "mr-IN-x-icu",
    "ms-x-icu",
    "ms-BN-x-icu",
    "ms-ID-x-icu",
    "ms-MY-x-icu",
    "ms-SG-x-icu",
    "mt-x-icu",
    "mt-MT-x-icu",
    "mua-x-icu",
    "mua-CM-x-icu",
    "my-x-icu",
    "my-MM-x-icu",
    "mzn-x-icu",
    "mzn-IR-x-icu",
    "naq-x-icu",
    "naq-NA-x-icu",
    "nb-x-icu",
    "nb-NO-x-icu",
    "nb-SJ-x-icu",
    "nd-x-icu",
    "nd-ZW-x-icu",
    "ne-x-icu",
    "ne-IN-x-icu",
    "ne-NP-x-icu",
    "nl-x-icu",
    "nl-AW-x-icu",
    "nl-BE-x-icu",
    "nl-BQ-x-icu",
    "nl-CW-x-icu",
    "nl-NL-x-icu",
    "nl-SR-x-icu",
    "nl-SX-x-icu",
    "nmg-x-icu",
    "nmg-CM-x-icu",
    "nn-x-icu",
    "nn-NO-x-icu",
    "nnh-x-icu",
    "nnh-CM-x-icu",
    "no-x-icu",
    "nus-x-icu",
    "nus-SS-x-icu",
    "nyn-x-icu",
    "nyn-UG-x-icu",
    "om-x-icu",
    "om-ET-x-icu",
    "om-KE-x-icu",
    "or-x-icu",
    "or-IN-x-icu",
    "os-x-icu",
    "os-GE-x-icu",
    "os-RU-x-icu",
    "pa-x-icu",
    "pa-Arab-x-icu",
    "pa-Arab-PK-x-icu",
    "pa-Guru-x-icu",
    "pa-Guru-IN-x-icu",
    "pcm-x-icu",
    "pcm-NG-x-icu",
    "pl-x-icu",
    "pl-PL-x-icu",
    "ps-x-icu",
    "ps-AF-x-icu",
    "ps-PK-x-icu",
    "pt-x-icu",
    "pt-AO-x-icu",
    "pt-BR-x-icu",
    "pt-CH-x-icu",
    "pt-CV-x-icu",
    "pt-GQ-x-icu",
    "pt-GW-x-icu",
    "pt-LU-x-icu",
    "pt-MO-x-icu",
    "pt-MZ-x-icu",
    "pt-PT-x-icu",
    "pt-ST-x-icu",
    "pt-TL-x-icu",
    "qu-x-icu",
    "qu-BO-x-icu",
    "qu-EC-x-icu",
    "qu-PE-x-icu",
    "rm-x-icu",
    "rm-CH-x-icu",
    "rn-x-icu",
    "rn-BI-x-icu",
    "ro-x-icu",
    "ro-MD-x-icu",
    "ro-RO-x-icu",
    "rof-x-icu",
    "rof-TZ-x-icu",
    "ru-x-icu",
    "ru-BY-x-icu",
    "ru-KG-x-icu",
    "ru-KZ-x-icu",
    "ru-MD-x-icu",
    "ru-RU-x-icu",
    "ru-UA-x-icu",
    "rw-x-icu",
    "rw-RW-x-icu",
    "rwk-x-icu",
    "rwk-TZ-x-icu",
    "sa-x-icu",
    "sa-IN-x-icu",
    "sah-x-icu",
    "sah-RU-x-icu",
    "saq-x-icu",
    "saq-KE-x-icu",
    "sat-x-icu",
    "sat-Olck-x-icu",
    "sat-Olck-IN-x-icu",
    "sbp-x-icu",
    "sbp-TZ-x-icu",
    "sc-x-icu",
    "sc-IT-x-icu",
    "sd-x-icu",
    "sd-Arab-x-icu",
    "sd-Arab-PK-x-icu",
    "sd-Deva-x-icu",
    "sd-Deva-IN-x-icu",
    "se-x-icu",
    "se-FI-x-icu",
    "se-NO-x-icu",
    "se-SE-x-icu",
    "seh-x-icu",
    "seh-MZ-x-icu",
    "ses-x-icu",
    "ses-ML-x-icu",
    "sg-x-icu",
    "sg-CF-x-icu",
    "shi-x-icu",
    "shi-Latn-x-icu",
    "shi-Latn-MA-x-icu",
    "shi-Tfng-x-icu",
    "shi-Tfng-MA-x-icu",
    "si-x-icu",
    "si-LK-x-icu",
    "sk-x-icu",
    "sk-SK-x-icu",
    "sl-x-icu",
    "sl-SI-x-icu",
    "smn-x-icu",
    "smn-FI-x-icu",
    "sn-x-icu",
    "sn-ZW-x-icu",
    "so-x-icu",
    "so-DJ-x-icu",
    "so-ET-x-icu",
    "so-KE-x-icu",
    "so-SO-x-icu",
    "sq-x-icu",
    "sq-AL-x-icu",
    "sq-MK-x-icu",
    "sq-XK-x-icu",
    "sr-x-icu",
    "sr-Cyrl-x-icu",
    "sr-Cyrl-BA-x-icu",
    "sr-Cyrl-ME-x-icu",
    "sr-Cyrl-RS-x-icu",
    "sr-Cyrl-XK-x-icu",
    "sr-Latn-x-icu",
    "sr-Latn-BA-x-icu",
    "sr-Latn-ME-x-icu",
    "sr-Latn-RS-x-icu",
    "sr-Latn-XK-x-icu",
    "su-x-icu",
    "su-Latn-x-icu",
    "su-Latn-ID-x-icu",
    "sv-x-icu",
    "sv-AX-x-icu",
    "sv-FI-x-icu",
    "sv-SE-x-icu",
    "sw-x-icu",
    "sw-CD-x-icu",
    "sw-KE-x-icu",
    "sw-TZ-x-icu",
    "sw-UG-x-icu",
    "ta-x-icu",
    "ta-IN-x-icu",
    "ta-LK-x-icu",
    "ta-MY-x-icu",
    "ta-SG-x-icu",
    "te-x-icu",
    "te-IN-x-icu",
    "teo-x-icu",
    "teo-KE-x-icu",
    "teo-UG-x-icu",
    "tg-x-icu",
    "tg-TJ-x-icu",
    "th-x-icu",
    "th-TH-x-icu",
    "ti-x-icu",
    "ti-ER-x-icu",
    "ti-ET-x-icu",
    "tk-x-icu",
    "tk-TM-x-icu",
    "to-x-icu",
    "to-TO-x-icu",
    "tr-x-icu",
    "tr-CY-x-icu",
    "tr-TR-x-icu",
    "tt-x-icu",
    "tt-RU-x-icu",
    "twq-x-icu",
    "twq-NE-x-icu",
    "tzm-x-icu",
    "tzm-MA-x-icu",
    "ug-x-icu",
    "ug-CN-x-icu",
    "uk-x-icu",
    "uk-UA-x-icu",
    "ur-x-icu",
    "ur-IN-x-icu",
    "ur-PK-x-icu",
    "uz-x-icu",
    "uz-Arab-x-icu",
    "uz-Arab-AF-x-icu",
    "uz-Cyrl-x-icu",
    "uz-Cyrl-UZ-x-icu",
    "uz-Latn-x-icu",
    "uz-Latn-UZ-x-icu",
    "vai-x-icu",
    "vai-Latn-x-icu",
    "vai-Latn-LR-x-icu",
    "vai-Vaii-x-icu",
    "vai-Vaii-LR-x-icu",
    "vi-x-icu",
    "vi-VN-x-icu",
    "vun-x-icu",
    "vun-TZ-x-icu",
    "wae-x-icu",
    "wae-CH-x-icu",
    "wo-x-icu",
    "wo-SN-x-icu",
    "xh-x-icu",
    "xh-ZA-x-icu",
    "xog-x-icu",
    "xog-UG-x-icu",
    "yav-x-icu",
    "yav-CM-x-icu",
    "yi-x-icu",
    "yi-001-x-icu",
    "yo-x-icu",
    "yo-BJ-x-icu",
    "yo-NG-x-icu",
    "yrl-x-icu",
    "yrl-BR-x-icu",
    "yrl-CO-x-icu",
    "yrl-VE-x-icu",
    "yue-x-icu",
    "yue-Hans-x-icu",
    "yue-Hans-CN-x-icu",
    "yue-Hant-x-icu",
    "yue-Hant-HK-x-icu",
    "zgh-x-icu",
    "zgh-MA-x-icu",
    "zh-x-icu",
    "zh-Hans-x-icu",
    "zh-Hans-CN-x-icu",
    "zh-Hans-HK-x-icu",
    "zh-Hans-MO-x-icu",
    "zh-Hans-SG-x-icu",
    "zh-Hant-x-icu",
    "zh-Hant-HK-x-icu",
    "zh-Hant-MO-x-icu",
    "zh-Hant-TW-x-icu",
    "zu-x-icu",
    "zu-ZA-x-icu",
}
