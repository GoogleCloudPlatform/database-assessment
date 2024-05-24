from __future__ import annotations

from typing import Final

RDS_MINOR_VERSION_SUPPORT_MAP: Final[dict[float, int]] = {}
DB_TYPE_MAP: Final[dict[float, str]] = {
    5.6: "MYSQL_5_6",
    5.7: "MYSQL_5_7",
    8.0: "MYSQL_8_0",
}
