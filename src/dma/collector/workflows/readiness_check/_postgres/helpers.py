from __future__ import annotations

import re

# Matches version numbers of both old (Eg: 9.6.2) and new formats (Eg: 10.2).
pg_version_regex = re.compile(r"(?P<version>\d+\.\d+(\.\d+)?).*")


def get_db_minor_version(db_version: str) -> int:
    version_match = pg_version_regex.match(db_version)
    if not version_match:
        return -1
    version = version_match.group("version")
    split = version.split(".")
    if db_version.startswith("9"):
        if len(split) > 2:
            return int(split[2])
    elif len(split) > 1:
        return int(split[1])
    return -1


def get_db_major_version(db_version: str) -> float:
    index = db_version.find("beta")
    if index != -1:
        db_version = db_version[:index] + ".0"

    split = db_version.split(".")
    db_version = ".".join(split[:2]) if db_version.startswith("9") else ".".join(split[:1])
    return float(db_version)
