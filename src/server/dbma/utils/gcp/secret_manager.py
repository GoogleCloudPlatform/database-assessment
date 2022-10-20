import hashlib
from typing import cast

from google.cloud import secretmanager as sm


def get_secret(project_id: str, secret_id: str, version_id: str = "latest") -> str:
    """Load Secret from GCP Secret Manager

    Args:
        project_id (str): _description_
        secret_id (str): _description_
        version_id (str, optional): _description_. Defaults to "latest".

    Returns:
        str: _description_
    """
    client = sm.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"
    response = client.access_secret_version(request={"name": name})
    return cast("str", response.payload.data.decode("UTF-8"))


def secret_hash(secret_value: str) -> str:
    """Get hash of value

    Args:
        secret_value (str): _description_

    Returns:
        str: _description_
    """
    # return the sha224 hash of the secret value
    return hashlib.sha224(bytes(secret_value, "utf-8")).hexdigest()
