# Commands

- `make install` - Creates a new virtual environment for development.

- `make upgrade` - Upgrade dependencies in all environments.

- `make test` - Execute test framework

- `make clean` - Remove all build, testing, and static documentation files.

- `make build` - Build a folder containing a set of the latest database collection scripts.

- `make docs` - Generate HTML documentation.

- `make serve-docs` - Generate HTML documentation and serve it to the browser.

- `make pre-release increment={major/minor/patch}` - Bump the version and create a release tag. Should only be run from the _main_ branch. Passes the increment value to bump2version to create a new version number dynamically. The new version number will be added to _\_\_version\_\_.py_ and _pyproject.toml_ and a new commit will be logged. The tag will be created from the new commit.
