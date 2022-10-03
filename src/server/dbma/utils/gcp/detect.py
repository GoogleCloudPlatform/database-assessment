from pathlib import Path

import httpx

from dbma import log

logger = log.get_logger()


class GCPDetector:
    """
    Concrete implementation of the GCP cloud provider.
    """

    identifier = "gcp"

    def __init__(self) -> None:
        self.metadata_url = "http://metadata.google.internal/computeMetadata/v1/instance/tags"
        self.vendor_file = "/sys/class/dmi/id/product_name"
        self.headers = {"Metadata-Flavor": "Google"}

    def is_running_in_gcp(self) -> bool:
        """Detect if the application is currently running in GCP"""
        return self.check_vendor_file() or self.check_metadata_server()

    def check_metadata_server(self) -> bool:
        """
        Tries to identify GCP via metadata server
        """
        try:
            response = httpx.get(self.metadata_url)
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
