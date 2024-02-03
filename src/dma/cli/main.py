from __future__ import annotations

from typing import TYPE_CHECKING

from ._utils import RICH_CLICK_INSTALLED

if TYPE_CHECKING or not RICH_CLICK_INSTALLED:  # pragma: no cover
    import click
    from click import Context, group, pass_context
else:  # pragma: no cover
    import rich_click as click
    from rich_click import Context, group, pass_context
    from rich_click.cli import patch as rich_click_patch

    rich_click_patch()
    click.rich_click.USE_RICH_MARKUP = True
    click.rich_click.USE_MARKDOWN = False
    click.rich_click.SHOW_ARGUMENTS = True
    click.rich_click.GROUP_ARGUMENTS_OPTIONS = True
    click.rich_click.SHOW_ARGUMENTS = True
    click.rich_click.GROUP_ARGUMENTS_OPTIONS = True
    click.rich_click.STYLE_ERRORS_SUGGESTION = "magenta italic"
    click.rich_click.ERRORS_SUGGESTION = ""
    click.rich_click.ERRORS_EPILOGUE = ""
    click.rich_click.MAX_WIDTH = 80
    click.rich_click.SHOW_METAVARS_COLUMN = True
    click.rich_click.APPEND_METAVARS_HELP = True


__all__ = ("app_group",)


@group(context_settings={"help_option_names": ["-h", "--help"]})
@pass_context
def app_group(ctx: Context) -> None:
    ...
