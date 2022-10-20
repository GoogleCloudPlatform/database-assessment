# pylint: disable=[invalid-name]
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
import sys
from pathlib import Path


def main() -> None:
    current_path = Path(__file__).parent.resolve()
    sys.path.append(str(current_path))
    try:
        from dbma import cli  # pylint: disable=[import-outside-toplevel]

    except ImportError:
        print(  # noqa: T201
            "💣 Could not load required libraries.  ",
            "Please check your installation and make sure you activated any necessary virtual environment",
        )
        sys.exit(1)
    cli.app()


if __name__ == "__main__":
    main()
