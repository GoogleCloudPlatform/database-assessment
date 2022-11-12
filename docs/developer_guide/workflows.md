# Workflows

## Release

- Linting and testing steps must pass before the release steps can begin.
- Documentation is automatically published to the `gh-pages` branch and hosted on github pages.
- All github release tags, docker image tags, and PyPI version numbers are in agreement with one another and follow semantic versioning standards.
- Builds collections packages and attaches to release

## Build and Publish Docs

- Build the documentation, publish to the `gh-pages` branch, and release to github pages.
- Runs only on a manual trigger in the github actions tab.
