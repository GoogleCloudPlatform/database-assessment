from enum import Enum
from typing import TYPE_CHECKING, List, Union

from packaging.version import LegacyVersion, Version

if TYPE_CHECKING:
    from pydantic import UUID4


class OpKeyLog:
    key: "UUID4"


class RuleAction(str, Enum):
    CREATE = "CREATE"
    EXECUTE_SQL = "DISABLED"
    ADD_OR_UPDATE_COLUMN = "ADD_OR_UPDATE_COLUMN"


class RuleActionType(str, Enum):
    FREESTYLE = "FREESTYLE"


class RuleActionStore(str, Enum):
    CREATE = "CREATE"
    EXECUTE_SQL = "DISABLED"


class TransformerStatus(str, Enum):
    ENABLED = "ENABLED"
    DISABLED = "DISABLED"


class TableSchema:
    """Represents a table schema that can be attached to a version"""


class TransformerParameter:
    """Represents a table schema that can be attached to a version"""


class TransformerRule:
    """Represents a table schema that can be attached to a version"""

    priority: int = 0
    applies_to_script_version: Union[Version, LegacyVersion]
    execution_group: int
    status: TransformerStatus
    action


class TransformerConfig:
    table_schemas: List[TableSchema] = []
    parameters: List[TransformerParameter] = []
    rules: List[TransformerRule] = []


class TransformerActionDetail:
    priority: int = 0
    applies_to_script_version
    execution_group: int
    status: TransformerStatus
