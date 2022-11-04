# type: ignore
import json
import logging
from typing import Final

import requests
from invoke.tasks import task

logger = logging.getLogger()

PROJECT: Final = "optimus-prime-ci"


@task
def build(ctx, tag="latest"):
    ctx.run(f"docker build . -t {ctx.image}:{tag}")


@task
def run(ctx, tag="latest"):
    local_cred_file = "${HOME}/.config/gcloud/application_default_credentials.json"  # pylint: disable=[line-too-long]
    docker_cred_file = "/tmp/creds/creds.json"
    cmd = f"docker run -e FLASK_ENV=development -e GOOGLE_APPLICATION_CREDENTIALS={docker_cred_file} -v {local_cred_file}:{docker_cred_file} -p 8080:8080 {ctx.image}:{tag}"  # pylint: disable=[line-too-long]
    ctx.run(cmd)


@task
def push(ctx, tag="latest"):
    ctx.run(f"docker push {ctx.image}:{tag}")


@task
def test(ctx, base_url=None, local=False):
    with ctx.cd("sample/datacollection"):
        ctx.run(f"tar -xvf {ctx.test_file}")
    if not base_url:
        base_url = get_beta_url(ctx)
    logger.info(base_url)
    id_token = authenticate(ctx, local)
    cmd = f"python3 -m db_assessment.optimusprime --remote --files-location sample/datacollection --dataset {ctx.dataset} --project {ctx.project} --collection-id {ctx.collection_id} --remote-url {base_url}"  # pylint: disable=[line-too-long]
    logger.info(cmd)
    ctx.run(cmd, env={"ID_TOKEN": id_token})


@task
def deploy(ctx, tag="latest"):
    ctx.run(
        f"gcloud run deploy {ctx.service} --image {ctx.image}:{tag} --region {ctx.region} --project {ctx.project} --no-traffic --tag beta"  # pylint: disable=[line-too-long]
    )


@task(autoprint=True)
def get_beta_url(ctx):
    """_summary_

    Args:
        ctx (_type_): _description_

    Returns:
        _type_: _description_
    """
    json_output = ctx.run(
        f"gcloud beta run services describe --region {ctx.region} --project {ctx.project} {ctx.service} --format json",
        hide=True,
    ).stdout
    service = json.loads(json_output)
    beta = [revision["url"] for revision in service["status"]["traffic"] if revision.get("tag", None) == "beta"]
    return beta[0]


@task(autoprint=True)
def authenticate(ctx, local=False):
    """_summary_

    Args:
        ctx (_type_): _description_
        local (bool, optional): _description_. Defaults to False.

    Returns:
        _type_: _description_
    """
    if local:
        token_cmd = ctx.run("gcloud auth print-identity-token", hide=True)
        return token_cmd.stdout.replace("\n", "")
    METADATA_SERVER_URL: Final = "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token?scopes=https://www.googleapis.com/auth/iam"  # pylint: disable=[line-too-long, invalid-name]
    METADATA_REQUEST_HEADERS: Final = {"Metadata-Flavor": "Google"}  # pylint: disable=[invalid-name]
    ID_TOKEN_URL: Final = (  # pylint: disable=[invalid-name]
        f"https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{ctx.invoker_sa}:generateIdToken"
    )
    # Get the access token for the Cloud build account
    access_token_request = requests.get(METADATA_SERVER_URL, headers=METADATA_REQUEST_HEADERS, timeout=10)
    access_token = access_token_request.json()["access_token"]
    logger.info("Got access token")
    identity_token_resp = requests.post(
        ID_TOKEN_URL,
        headers={
            "Authorization": f"Bearer {access_token}",
            "content-type": "application/json",
        },
        data=json.dumps({"audience": ctx.api_audience, "includeEmail": True}),
        timeout=10,
    )
    identity_token = identity_token_resp.json()["token"]
    logger.info("Got identity token")
    return identity_token


@task
def pull_config(ctx):
    ctx.run("gcloud secrets versions access latest " f'--secret="op-api-config" --project {PROJECT} > invoke.yml')


@task
def push_config(ctx):
    ctx.run("gcloud secrets versions add op-api-config " f"--data-file=invoke.yml --project {PROJECT}")
