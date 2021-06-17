# Copyright 2020 Google LLC
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

# Handwritten HTTP clients
from google.api_core import client_info as http_client_info

# Importing Optimus Prime Version
import version

# Information for analytics and tool improvement
__version__= version.__version__

APPLICATION_NAME = "google-pso-tool/optimus-prime-db-assessment"
USER_AGENT = "{}/{}".format(APPLICATION_NAME, __version__)


def get_http_client_info():
    return http_client_info.ClientInfo(user_agent=USER_AGENT)