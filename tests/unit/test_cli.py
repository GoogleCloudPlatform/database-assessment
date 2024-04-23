from click.testing import CliRunner

from dma.cli.main import app


def test_collect_data() -> None:
    runner = CliRunner()
    result = runner.invoke(app, ["collect-data"])
    assert result.exit_code == 0


def test_readiness_check() -> None:
    runner = CliRunner()
    result = runner.invoke(app, ["readiness-check"])
    assert result.exit_code == 0
