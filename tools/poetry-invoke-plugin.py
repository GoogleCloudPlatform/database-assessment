import os
from typing import Any

from cleo.application import Application
from cleo.helpers import argument
from poetry.console.commands.env_command import EnvCommand
from poetry.plugins.application_plugin import ApplicationPlugin


class InvokeCommand(EnvCommand):

    name = "invoke"
    description = "Delegate out to pyinvoke tasks specified in your tasks.py file"

    arguments = [
        argument("cmd", "The command to run from your tasks.py.", multiple=False),
        argument(
            "arguments",
            "Additional arguments to append to the command.",
            multiple=True,
            optional=True,
        ),
    ]

    def handle(self) -> Any:
        pyproject_folder_path = self.poetry.pyproject._file.path.parent

        cmd_name = self.argument("cmd")

        full_cmd = f"invoke {cmd_name} {' '.join(self.argument('arguments'))}"
        shell = os.environ.get("SHELL", "/bin/sh")

        # Change directory to the folder that contains the pyproject.toml so that the command runs
        # from that folder (even if you call poetry exec from a subfolder). This mimics the
        # behaviour of npm/yarn.
        os.chdir(pyproject_folder_path)

        self.line(dim(f"Invoke: {full_cmd}\n"))
        result = self.env.execute(*[shell, "-c", full_cmd])

        # NOTE: If running on mac or linux nothing will be executed after the previous line. This
        # is because poetry uses os.execvpe to run the command which means that the current process
        # is replaced by the command. If on windows it uses subprocess.run which means the code
        # after this comment will be executed.

        self.line("\n✨ Done!")

        if result:
            return result.returncode


class InvCommand(InvokeCommand):
    name = "inv"


def invoke_factory() -> InvokeCommand:
    return InvokeCommand()


def inv_factory() -> InvCommand:
    return InvCommand()


class InvokePlugin(ApplicationPlugin):
    def activate(self, application: Application, *args: Any, **kwargs: Any) -> None:
        application.command_loader.register_factory("invoke", invoke_factory)


class InvPlugin(ApplicationPlugin):
    def activate(self, application: Application, *args: Any, **kwargs: Any) -> None:
        application.command_loader.register_factory("inv", inv_factory)
