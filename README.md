# Database Migration Assessment

## Features

- Get the recommended Google Cloud configuration your current Oracle and Microsoft SQL Server environments.
- Facts based approach to sizing that leverages metadata from your environment.
- Supports the following RDBMS types:
    - Oracle from 10g to 21c - Exadata, RDS, and OCI workloads included by leveraging AWR data (requires tuning and diagnostics pack for Oracle) or statspack for sizing.
    - Microsoft SQL Server for Windows Versions 2008R2 (SP2) to SQL Server 2022

## Getting Started

- Grab the collection scripts from the latest release [here](https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-oracle.zip). Instructions for execution are included in the bundled README.
- Execute collection scripts against targeted database environments.
- Return archived output from scripts for processing.
- For detailed instructions, please refer to the our [official documentation](https://googlecloudplatform.github.io/database-assessment/) for more information.

## Development

To set up [hatch] and [pre-commit] for the first time:

1. install [hatch] globally, e.g. with [pipx], i.e. `pipx install hatch`,
2. optionally run `hatch config set dirs.env.virtual .direnv` and `hatch config set dirs.env.pip-compile .direnv`
   to let [VS Code] find your virtual environments,
3. make sure `pre-commit` is installed globally, e.g. with `pipx install pre-commit`,

A special feature that makes hatch very different from other familiar tools is that you almost never
activate, or enter, an environment. Instead, you use `hatch run env_name:command` and the `default` environment
is assumed for a command if there is no colon found. Thus you must always define your environment in a declarative
way and hatch makes sure that the environment reflects your declaration by updating it whenever you issue
a `hatch run ...`. This helps with reproducibility and avoids forgetting to specify dependencies since the
hatch workflow is to specify everything directly in [pyproject.toml](pyproject.toml). Only in rare cases, you
will use `hatch shell` to enter the `default` environment, which is similar to what you may know from other tools.

To get you started, use `hatch run test:cov` or `hatch run test:no-cov` to run the unit test with or without coverage reports,
respectively. Use `hatch run lint:all` to run all kinds of typing and linting checks. Try to automatically fix linting
problems with `hatch run lint:fix` and use `hatch run docs:serve` to build and serve your documentation.
You can also easily define your own environments and commands. Check out the environment setup of hatch
in [pyproject.toml](pyproject.toml) for more commands as well as the package, build and tool configuration.

The environments defined by hatch are configured to generate lock files using [hatch-pip-compile] under `locks`.
To upgrade all packages in an environment like `test`, just run `hatch run test:upgrade-all`. To upgrade specific
packages, type `hatch run test:upgrade-pkg pkg1,pkg2`.

[pipx]: https://pypa.github.io/pipx/
[hatch]: https://hatch.pypa.io/
[pre-commit]: https://pre-commit.com/
[VS Code]: https://code.visualstudio.com/docs/python/environments#_where-the-extension-looks-for-environments
[hatch-pip-compile]: https://github.com/juftin/hatch-pip-compile
