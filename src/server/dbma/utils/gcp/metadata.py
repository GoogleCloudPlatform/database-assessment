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
from pathlib import Path
from typing import cast

import httpx

from dbma import log

logger = log.get_logger()


class GCPMetadata:
    """
    Concrete implementation of the GCP cloud provider.
    """

    identifier = "gcp"

    def __init__(self) -> None:
        self.metadata_url = "http://metadata.google.internal/computeMetadata/v1/"
        self.vendor_file = "/sys/class/dmi/id/product_name"
        self.headers = {"Metadata-Flavor": "Google"}

    def is_running_in_gcp(self) -> bool:
        """Detect if the application is currently running in GCP"""
        # return self.check_vendor_file() or self.check_metadata_server()
        return self.check_metadata_server()

    def check_metadata_server(self) -> bool:
        """
        Tries to identify if the request is coming from within GCP or external
        """
        try:
            slug = "instance/zone"
            response = httpx.get(f"{self.metadata_url}{slug}", headers=self.headers)
            if response:
                return True
            return False
        except httpx.RequestError:  # noqa: F841
            return False

    def check_vendor_file(self) -> bool:
        """
        Tries to identify GCP provider by reading the /sys/class/dmi/id/product_name
        """
        gcp_path = Path(self.vendor_file)
        if gcp_path.is_file() and "Google" in gcp_path.read_text(encoding="UTF-8"):
            return True
        return False

    def get_project_id(self) -> str:
        """Get the project ID from the Google Metadata servers

        *Note* - Be aware that when running this outside of Cloudtop, you'll get back the Cloudtop project
        Returns:
            str: project ID string
        """
        slug = "project/project-id"
        response = httpx.get(f"{self.metadata_url}{slug}", headers=self.headers)
        return response.content.decode()

    def get_project_number(self) -> int:
        """Get the project number from the Google Metadata servers

        *Note* - Be aware that when running this outside of Cloudtop, you'll get back the Cloudtop project
        Returns:
            str: project number
        """
        slug = "project/numeric-project-id"
        response = httpx.get(f"{self.metadata_url}{slug}", headers=self.headers)
        return cast("int", response.content.decode())
