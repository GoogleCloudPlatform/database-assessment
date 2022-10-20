# pylint: disable=[invalid-name]
import sys
from pathlib import Path


def main() -> None:
    current_path = Path(__file__).parent.resolve()
    sys.path.append(str(current_path))
    try:
        from dbma import cli  # pylint: disable=[import-outside-toplevel]

    except ImportError:
        print(  # noqa: T201
            "💣 Could not load required libraries.  ",
            "Please check your installation and make sure you activated any necessary virtual environment",
        )
        sys.exit(1)
    cli.app()


if __name__ == "__main__":
    main()
