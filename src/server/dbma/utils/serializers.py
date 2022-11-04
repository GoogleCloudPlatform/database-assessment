# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
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
from datetime import datetime, timezone
from typing import Any, Union

import orjson
from pydantic import SecretBytes


def serialize_object(value: Any) -> str:
    """Encodes json with the optimized ORJSON package.

    orjson.dumps returns bytearray, so you can't pass it directly as
    json_serializer
    """

    def _serializer(value: Any) -> Any:
        if isinstance(value, SecretBytes):
            return value.get_secret_value()
        raise TypeError

    return orjson.dumps(
        value,
        default=_serializer,
        option=orjson.OPT_NAIVE_UTC | orjson.OPT_SERIALIZE_NUMPY,
    ).decode()


def deserialize_object(value: Union[bytes, bytearray, memoryview, str, dict[str, Any]]) -> Any:
    """Decodes to an object with the optimized ORJSON package.

    orjson.dumps returns bytearray, so you can't pass it directly as
    json_serializer
    """
    if isinstance(value, dict):
        return value
    return orjson.loads(value)


def convert_datetime_to_gmt(dt: datetime) -> str:
    """Handles datetime serialization for nested timestamps in
    models/dataclasses."""
    if not dt.tzinfo:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat().replace("+00:00", "Z")
