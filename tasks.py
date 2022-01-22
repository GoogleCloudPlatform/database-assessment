from invoke.tasks import task
import requests
import json


@task
def build(ctx, tag="latest"):
    ctx.run(f"docker build . -t {ctx.image}:{tag}")


@task
def run(ctx, tag="latest"):
    local_cred_file = "${HOME}/.config/gcloud/application_default_credentials.json"
    docker_cred_file = "/tmp/creds/creds.json"
    cmd = f"docker run -e GOOGLE_APPLICATION_CREDENTIALS={docker_cred_file} -v {local_cred_file}:{docker_cred_file} -p 8080:8080 {ctx.image}:{tag}"
    ctx.run(cmd)


@task
def push(ctx, tag="latest"):
    ctx.run(f"docker push {ctx.image}:{tag}")


@task
def test(ctx, base_url=None, retrieve_token=False, local=False):
    if not base_url:
        base_url = get_beta_url(ctx)

    headers = {"Authorization": f"Bearer {authenticate(ctx, local)}"} if retrieve_token else None
    config = {
        "projectId": ctx.project,
        "dataset":  ctx.dataset,
        "collectionId": ctx.collection_id
    }
    files = get_test_files(ctx)
    result = requests.post(f"{base_url}/api/loadAssesment", files=files, data=config, headers=headers)
    result.raise_for_status()


@task
def deploy(ctx, tag="latest"):
    ctx.run(f"gcloud run deploy {ctx.service} --image {ctx.image}:{tag} --region {ctx.region} --project {ctx.project} --no-traffic --tag beta")


def get_test_files(c, testDir="sample/datacollection"):
    with c.cd(testDir):
        c.run("tar -xvf samplefiles_190_2.0.1.tar.gz")
        files = c.run('ls').stdout.split("\n")[0:-1]
        return {f"log-{i}": (f, open(f"{testDir}/{f}", 'rb')) for i, f in enumerate(files)}


@task(autoprint=True)
def get_beta_url(ctx):
    json_output = ctx.run(f"gcloud beta run services describe --region {ctx.region} --project {ctx.project} {ctx.service} --format json", hide=True).stdout
    service = json.loads(json_output)
    beta = [revision['url'] for revision in service['status']['traffic'] if revision.get('tag', None) == 'beta']
    return beta[0]


@task(autoprint=True)
def authenticate(ctx, local=False):
    if local:
        return ctx.run("gcloud auth print-identity-token", hide=True).stdout.replace('\n', '')
    else:
        METADATA_SERVER_URL = 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token?scopes=https://www.googleapis.com/auth/iam'
        METADATA_REQUEST_HEADERS = {'Metadata-Flavor': 'Google'}
        ID_TOKEN_URL = f'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{ctx.invoker_sa}:generateIdToken'

        # Get the access token for the Cloud build account
        access_token_request = requests.get(METADATA_SERVER_URL, headers=METADATA_REQUEST_HEADERS)
        access_token = access_token_request.json()['access_token']
        print('Got access token')
        identity_token_request = requests.post(
            ID_TOKEN_URL,
            headers={'Authorization': 'Bearer {}'.format(access_token), 'content-type': 'application/json'},
            data=json.dumps({'audience': ctx.api_audience, 'includeEmail': True}))
        identity_token = identity_token_request.json()['token']
        print('Got identity token')
        return identity_token


PROJECT = "optimus-prime-ci"


@task
def pull_config(ctx):
    ctx.run(f'gcloud secrets versions access latest --secret="op-api-config" --project {PROJECT} > invoke.yml')


@task
def push_config(ctx):
    ctx.run(f'gcloud secrets versions add op-api-config --data-file=invoke.yml --project {PROJECT}')
