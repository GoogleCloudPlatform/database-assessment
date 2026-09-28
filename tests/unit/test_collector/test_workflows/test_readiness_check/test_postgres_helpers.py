# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import pytest

from dma.collector.util.postgres.helpers import get_db_major_version, get_db_minor_version

pytestmark = pytest.mark.anyio


@pytest.mark.parametrize(
    ("version_string, expected_minor_version"),
    [["9.4.1", 1], ["9.4", -1], ["16", -1], ["15.0.100", 0], ["14.2", 2], ["2.0", 0], ["asdf", -1]],
)
async def test_get_db_minor_version(version_string: str, expected_minor_version: int) -> None:
    """Test get db version from file."""
    version = get_db_minor_version(version_string)
    assert version == expected_minor_version


@pytest.mark.parametrize(
    ("version_string, expected_major_version"),
    [["9.4.1", 9.4], ["9.4", 9.4], ["16", 16], ["15.0.100", 15], ["14.2", 14], ["2.0", 2], ["asdf", -1]],
)
async def test_get_db_major_version(version_string: str, expected_major_version: float) -> None:
    """Test get db version from file."""
    version = get_db_major_version(version_string)
    assert version == expected_major_version
