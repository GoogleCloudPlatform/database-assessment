import pytest

from dma.collector.workflows.readiness_check._postgres.helpers import get_db_major_version, get_db_minor_version

pytestmark = pytest.mark.anyio


@pytest.mark.parametrize(
    ("version_string", "expected_minor_version"),
    [
        [["9.4.1", 1], ["9.4", -1], ["16", -1], ["15.0.100", 100], ["14.2", -1], ["2.0", -1], ["asdf", -1]],
    ],
)
async def test_get_db_minor_version(version_string: str, expected_minor_version: int) -> None:
    """Test get db version from file."""
    version = get_db_minor_version(version_string)
    assert version == expected_minor_version


@pytest.mark.parametrize(
    ("version_string", "expected_major_version"),
    [["9.4.1", 9.4], ["9.4", 9.4], ["16", 16], ["15.0.100", 15], ["14.2", 14], ["2.0", -1], ["asdf", -1]],
)
async def test_get_db_major_version(version_string: str, expected_major_version: float) -> None:
    """Test get db version from file."""
    version = get_db_major_version(version_string)
    assert version == expected_major_version
