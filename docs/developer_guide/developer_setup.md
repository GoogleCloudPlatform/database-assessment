# Developer Setup

To begin local development, clone the [GoogleCloudPlatform/database-assessment](https://github.com/GoogleCloudPlatform/database-assessment) repository and use one of the following methods to build it. All commands should be executed from inside of the project home folder.

## Configure environment

Assuming you are using an Ubuntu/Debian based x86_64 machine for development, the following will install the required OS dependencies:

- Python 3 and associated development libraries
- NPM for frontend templating
- Postgres 15 client, redis (optional), Rust (required for binary standalone build)

```bash
# install  development essentials
sudo apt update \
 && sudo apt install -y libpq-dev python3-dev pipx unixodbc-dev libmysqlclient-dev python-is-python3 rustc npm nodejs libbz2-dev libffi-dev liblzma-dev libreadline-dev libsqlite3-dev libssl-dev tk-dev zlib1g-dev build-essential pkg-config cmake-data

if ! grep -qe "^export PATH=\"\${HOME}/.local/bin:\${PATH}\"" ~/.bashrc; then
  echo "" >> ~/.bashrc
  echo "export PATH=\"\${HOME}/.local/bin:\${PATH}\"" >> ~/.bashrc
fi
```

Install the application:

```bash
make install
```

## Tools Used & Manual Development Configuration

The following tools are used for managing this project:

- [pipx]: Globally installs Hatch, Ruff, and UV in an isolated environment
- [hatch]: Package building utility.  `hatch-pip-compile` is used to provide requirement lock files.  Hatch will auto-install all Python versions required for testing.
- [uv]: Python package installation and caching
- [ruff], [mypy], and [pre-commit]: Linting utilities

To set up [hatch] and [pre-commit] for the first time:

1. Ensure [pipx] is available in your environment and you do not currently have `hatch` installed. (`python3 -m pip install --upgrade --user pipx`)
2. install [hatch] globally with [pipx] (`pipx install hatch --force`),
3. Inject [hatch-pip-compile], [uv], and [ruff] into the `hatch` installation. (`pipx inject hatch ruff uv hatch-pip-compile hatch-vcs --include-deps --include-apps --force`),
4. optionally run `hatch config set dirs.env.virtual .direnv` and `hatch config set dirs.env.pip-compile .direnv`
   to let [VS Code] find your virtual environments,

!!! tip
    There is a `Makefile` entry to automate the setup of the repository.  Executing `make install` will install and configure `pipx`, `hatch`, `uv`, `mypy`, and `ruff` for development.

A special feature that makes hatch very different from other familiar tools is that you almost never
activate, or enter, an environment. Instead, you use `hatch run env_name:command` and the `default` environment
is assumed for a command if there is no colon found. Thus you must always define your environment in a declarative
way and hatch makes sure that the environment reflects your declaration by updating it whenever you issue
a `hatch run ...`. This helps with reproducibility and avoids forgetting to specify dependencies since the
hatch workflow is to specify everything directly in [pyproject.toml]. Only in rare cases, you
will use `hatch local:shell` to enter the `local` environment, which is similar to what you may know from other tools.

To get you started, use `hatch run test:cov` or `hatch run test:no-cov` to run the unit test with or without coverage reports,
respectively. Use `hatch run lint:all` to run all kinds of typing and linting checks. Try to automatically fix linting
problems with `hatch run lint:fix` and use `hatch run docs:serve` to build and serve your documentation.
You can also easily define your own environments and commands. Check out the environment setup of hatch
in [pyproject.toml] for more commands as well as the package, build and tool configuration.

!!! tip
    There is a `Makefile` entry to automate testing and linting.  Executing `make test` will test all supported Python versions.  `make lint` will run the linting workflow against the source code, and `make serve-docs` will launch the local documentation server.

The environments defined by hatch are configured to generate lock files using [hatch-pip-compile] under `requirements`.
To upgrade all packages in an environment like `test`, just run `hatch run test:upgrade-all`. To upgrade specific
packages, type `hatch run test:upgrade-pkg pkg1,pkg2`.

!!! tip
    There is a `Makefile` entry to automate updating package dependencies.  Executing `make upgrade` will install automatically upgrade all dependencies for all `hatch` environments, `pre-commit` actions, and `npm` packages.

To manage database infrastructure that could be useful for testing, run `hatch run local:start-infra` to start and `hatch run local:stop-infra` to shut them down.

[ruff]: https://github.com/astral-sh/ruff
[uv]: https://github.com/astral-sh/uv
[mypy]: https://mypy.readthedocs.io/en/stable/
[pipx]: https://pypa.github.io/pipx/
[hatch]: https://hatch.pypa.io/
[pre-commit]: https://pre-commit.com/
[VS Code]: https://code.visualstudio.com/docs/python/environments#_where-the-extension-looks-for-environments
[hatch-pip-compile]: https://github.com/juftin/hatch-pip-compile
[pyproject.toml]: https://packaging.python.org/en/latest/guides/writing-pyproject-toml/
