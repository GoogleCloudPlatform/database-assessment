"""Installation commands for external prerequisites."""

from __future__ import annotations

import os
import shutil
import subprocess  # noqa: S404
import sys
from pathlib import Path

import httpx
import rich_click as click
from rich.console import Console
from rich.prompt import Confirm
from rich.table import Table

from tools.lib.utils import (
    configure_gemini_mcp_extensions,
    configure_gemini_mcp_sqlcl,
    configure_sqlcl_connection_with_password,
    detect_deployment_mode,
    is_mcp_server_configured,
    is_tool_installed,
    run_command,
)

console = Console()


@click.group(name="install")
def install_group() -> None:
    """Install external tool prerequisites.

    Manages installation of:
    - UV: Astral's fast Python package manager
    - Gemini CLI: Google's AI terminal assistant
    - MCP Toolbox: Database MCP server
    """


@install_group.command(name="all")
@click.option(
    "--mode",
    type=click.Choice(["managed", "external"], case_sensitive=False),
    help="Install prerequisites for specific mode (auto-detect if not specified)",
)
@click.option(
    "--force",
    is_flag=True,
    help="Force reinstall even if already installed",
)
@click.option(
    "--yes",
    "-y",
    is_flag=True,
    help="Skip confirmation prompts",
)
def install_all_command(mode: str | None, force: bool, yes: bool) -> None:
    """Install all prerequisites for deployment mode.

    Idempotent: Safe to run multiple times. Skips if already installed unless --force is used.

    Mode-specific installations:
    - managed: UV, Docker check
    - external: UV
    """
    if mode is None:
        mode = detect_deployment_mode()

    console.rule(f"[bold blue]Installing Prerequisites for '{mode}' Mode", style="blue")
    console.print()

    # UV is required for all modes
    console.print("[bold]Required for all modes:[/bold]")
    console.print("  • UV package manager")
    console.print()

    if mode == "managed":
        console.print("[bold]Additional for managed mode:[/bold]")
        console.print("  • Docker or Podman (checked, not auto-installed)")
        console.print()

    if not yes and not Confirm.ask("Proceed with installation?", default=True):
        console.print("[yellow]Installation cancelled[/yellow]")
        return

    # Install UV
    ctx = click.get_current_context()
    if ctx:
        ctx.invoke(install_uv_command, version=None, force=force)

    # For managed mode, check Docker/Podman
    if mode == "managed":
        console.print()
        console.print("[yellow]🐋 Checking for Docker/Podman...[/yellow]")

        has_docker = shutil.which("docker") is not None
        has_podman = shutil.which("podman") is not None

        if has_docker:
            console.print("[green]✓ Docker found[/green]")
        elif has_podman:
            console.print("[green]✓ Podman found[/green]")
        else:
            console.print("[red]✗ Neither Docker nor Podman found[/red]")
            console.print()
            console.print("[yellow]⚠ Managed mode requires Docker or Podman[/yellow]")
            console.print("[dim]Install from: https://www.docker.com/get-started[/dim]")

    console.print()
    console.print("[green]✓ Installation complete![/green]")


@install_group.command(name="list")
def install_list_command() -> None:
    """List available installation components."""
    console.rule("[bold blue]Available Installation Components", style="blue")
    console.print()

    table = Table(show_header=True, header_style="bold cyan")
    table.add_column("Component", style="cyan", width=15)
    table.add_column("Required", width=10)
    table.add_column("Modes", width=30)
    table.add_column("Description")

    table.add_row(
        "uv",
        "[green]Yes[/green]",
        "managed, external",
        "Fast Python package manager",
    )
    table.add_row(
        "java",
        "[yellow]Optional[/yellow]",
        "managed, external",
        "Java 11+ (required for SQLcl)",
    )
    table.add_row(
        "sqlcl",
        "[yellow]Optional[/yellow]",
        "managed, external",
        "Oracle SQL command-line tool",
    )
    table.add_row(
        "docker",
        "[yellow]Optional[/yellow]",
        "managed",
        "Container runtime (not auto-installed)",
    )
    table.add_row(
        "gemini-cli",
        "[yellow]Optional[/yellow]",
        "managed, external",
        "Google Gemini CLI (AI terminal assistant)",
    )
    table.add_row(
        "mcp-toolbox",
        "[yellow]Optional[/yellow]",
        "managed, external",
        "MCP Toolbox for Databases",
    )

    console.print(table)
    console.print()
    console.print("[dim]Tip: Run 'python3 manage.py install <component>' to install[/dim]")
    console.print()


@install_group.command(name="uv")
@click.option(
    "--version",
    help="Specific version to install (default: latest)",
)
@click.option(
    "--force",
    is_flag=True,
    help="Force reinstall even if already installed",
)
def install_uv_command(version: str | None, force: bool) -> None:
    r"""Install Astral's UV package manager.

    Idempotent: Safe to run multiple times. Skips installation if UV is already
    installed unless --force flag is used.

    UV is a fast Python package manager and project manager.
    Required for all deployment modes.

    Installation:
    - Downloads from: https://astral.sh/uv/install.sh (Linux/Mac)
    - Installs to: ~/.local/bin or %USERPROFILE%\\.local\\bin
    - Adds to PATH if needed
    """
    console.print("[yellow]📦 Checking UV installation...[/yellow]")
    console.print()

    # ALWAYS check if already installed (not just when flag is set)
    is_installed, version_str = is_tool_installed("uv")
    if is_installed and not force:
        console.print(f"[green]✓ UV already installed: {version_str}[/green]")
        uv_path = shutil.which("uv")
        console.print(f"[dim]  Location: {uv_path}[/dim]")
        console.print("[dim]  Use --force to reinstall[/dim]")
        return

    # Proceed with installation
    if is_installed and force:
        console.print("[yellow]⚠ Reinstalling UV (--force flag used)[/yellow]")
        console.print()
    else:
        console.print("[yellow]📦 Installing UV package manager...[/yellow]")
        console.print()

    # Platform-specific installation
    if sys.platform.startswith("win"):
        console.print("[yellow]⚠ Windows installation not yet automated[/yellow]")
        console.print()
        console.print("[bold]Manual installation:[/bold]")
        console.print("  1. Visit: https://astral.sh/uv/")
        console.print("  2. Download and run the Windows installer")
        console.print("  3. Add UV to your PATH")
        return

    # Linux/macOS installation
    console.print("[cyan]Downloading UV installer...[/cyan]")

    install_cmd = "curl -LsSf https://astral.sh/uv/install.sh | sh"

    console.print(f"[dim]Running: {install_cmd}[/dim]")
    console.print()

    try:
        subprocess.run(  # noqa: S602
            install_cmd,  # Secure: curl from official source, no user input
            shell=True,
            check=True,
            text=True,
        )

        console.print()
        console.print("[green]✓ UV installed successfully![/green]")
        console.print()

        # Check if in PATH
        uv_path_after = shutil.which("uv")
        if not uv_path_after:
            console.print("[yellow]⚠ UV is not in your PATH yet[/yellow]")
            console.print()
            console.print("[bold]Add to PATH:[/bold]")

            shell = os.getenv("SHELL", "")
            if "zsh" in shell:
                console.print("  echo 'export PATH=\"$HOME/.local/bin:$PATH\"' >> ~/.zshrc")
                console.print("  source ~/.zshrc")
            elif "bash" in shell:
                console.print("  echo 'export PATH=\"$HOME/.local/bin:$PATH\"' >> ~/.bashrc")
                console.print("  source ~/.bashrc")
            else:
                console.print("  Add $HOME/.local/bin to your PATH")
            console.print()
            console.print("[dim]Or restart your terminal[/dim]")
        else:
            console.print(f"[green]✓ UV is in PATH: {uv_path_after}[/green]")

    except subprocess.CalledProcessError as e:
        console.print(f"[red]✗ Installation failed: {e}[/red]")
        raise click.Abort from e


@install_group.command(name="sqlcl")
@click.option(
    "--dir",
    "install_dir",
    type=click.Path(),
    help="Installation directory (default: ~/.local/bin)",
)
@click.option(
    "--force",
    is_flag=True,
    help="Reinstall even if already installed",
)
@click.option(
    "--connection-name",
    default="cymbal_coffee",
    help="Name for saved SQLcl connection (default: cymbal_coffee)",
)
def install_sqlcl_command(install_dir: str | None, force: bool, connection_name: str) -> None:
    """Install Oracle SQLcl command-line tool.

    Idempotent: Safe to run multiple times. Skips installation if SQLcl is already
    installed unless --force flag is used.

    Optional tool for advanced Oracle database operations.
    Requires Java 11 or higher to be installed.

    IMPORTANT: SQLcl requires Java 11+. Check with 'java -version'.
    """
    console.print("[yellow]📦 Checking SQLcl installation...[/yellow]")
    console.print()

    # Check for Java before proceeding
    java_path = shutil.which("java")
    if not java_path:
        console.print("[red]✗ Java not found![/red]")
        console.print()
        console.print("[bold]SQLcl requires Java 11 or higher.[/bold]")
        console.print()
        console.print("[yellow]Install Java on Ubuntu/Debian:[/yellow]")
        console.print("  [cyan]sudo apt update && sudo apt install -y default-jre[/cyan]")
        console.print()
        console.print("[yellow]Or install a specific version (Ubuntu/Debian):[/yellow]")
        console.print("  [cyan]sudo apt install openjdk-17-jre-headless[/cyan]  # Java 17 (recommended)")
        console.print("  [cyan]sudo apt install openjdk-21-jre-headless[/cyan]  # Java 21 (latest LTS)")
        console.print("  [cyan]sudo apt install openjdk-11-jre-headless[/cyan]  # Java 11 (minimum)")
        console.print()
        console.print("[yellow]RHEL/CentOS/Fedora (yum/dnf):[/yellow]")
        console.print("  [cyan]sudo yum install java-17-openjdk[/cyan]           # RHEL/CentOS 7-8")
        console.print("  [cyan]sudo dnf install java-17-openjdk[/cyan]           # RHEL/CentOS 9+, Fedora")
        console.print("  [cyan]sudo dnf install java-21-openjdk[/cyan]           # Latest LTS")
        console.print()
        console.print("[yellow]Other platforms:[/yellow]")
        console.print("  • macOS: [cyan]brew install openjdk@17[/cyan]")
        console.print("  • Download from: [dim]https://adoptium.net/[/dim]")
        console.print()
        console.print("[dim]After installing Java, run this command again.[/dim]")
        raise click.Abort

    # Check Java version
    returncode, _stdout, _ = run_command(["java", "-version"], check=False)
    if returncode == 0:
        console.print("[green]✓ Java found[/green]")
        console.print()

    # Check if already installed
    is_installed, version_str = is_tool_installed("sql", "-V")
    if is_installed and not force:
        console.print(f"[green]✓ SQLcl already installed: {version_str.split(chr(10))[0]}[/green]")
        sqlcl_path = shutil.which("sql")
        console.print(f"[dim]  Location: {sqlcl_path}[/dim]")
        console.print("[dim]  Use --force to reinstall[/dim]")

        # Still check for Gemini MCP configuration
        gemini_path = shutil.which("gemini")
        if gemini_path:
            console.print()
            console.print("[yellow]🔐 Checking Gemini MCP integration...[/yellow]")

            # Check if already configured
            if is_mcp_server_configured("sqlcl"):
                console.print("[green]✓ SQLcl MCP server already configured[/green]")
            else:
                console.print("[yellow]🔐 Configuring SQLcl for Gemini MCP...[/yellow]")

                # Step 1: Configure saved connection with password
                success, message = configure_sqlcl_connection_with_password(connection_name)
                if success:
                    console.print(f"[green]✓ {message}[/green]")
                else:
                    console.print(f"[yellow]⚠ Password configuration: {message}[/yellow]")

                # Step 2: Configure Gemini MCP server
                if configure_gemini_mcp_sqlcl():
                    console.print("[green]✓ Configured SQLcl as Gemini MCP server[/green]")

        return

    # If force flag, show warning
    if is_installed and force:
        console.print("[yellow]⚠ Reinstalling SQLcl (--force flag used)[/yellow]")
        console.print()

    console.print("[yellow]📦 Installing Oracle SQLcl...[/yellow]")
    console.print()

    # Use SQLcl installer directly
    from tools.oracle.sqlcl_installer import SQLclConfig, SQLclInstaller

    try:
        config = SQLclConfig()
        if install_dir:
            config.install_dir = Path(install_dir)

        installer = SQLclInstaller(config=config, console=console)
        installed_path = installer.install(force=force)

        console.print(f"[green]✓ SQLcl installed to: {installed_path}[/green]")

        # Check if in PATH
        if not installer.is_in_path():
            console.print("\n[yellow]⚠ SQLcl is not in your PATH[/yellow]")
            instructions = installer.get_path_instructions()
            for instruction in instructions:
                console.print(f"  {instruction}")
    except Exception as e:
        console.print(f"[red]✗ Installation failed: {e}[/red]")
        raise click.Abort from e

    # Post-installation instructions
    console.print()
    console.print("[bold]Test SQLcl:[/bold]")
    console.print("  [cyan]sql -V[/cyan]")
    console.print()
    console.print("[dim]Note: Make sure ~/.local/bin is in your PATH[/dim]")

    # Configure Gemini MCP integration if Gemini CLI is installed
    gemini_path = shutil.which("gemini")
    if gemini_path:
        console.print()
        console.print("[yellow]🔐 Configuring SQLcl MCP integration...[/yellow]")

        # Step 1: Configure saved connection with password
        success, message = configure_sqlcl_connection_with_password(connection_name)
        if success:
            console.print(f"[green]✓ {message}[/green]")
        else:
            console.print(f"[yellow]⚠ Password configuration: {message}[/yellow]")
            console.print(
                "[dim]  Ensure .env has DATABASE_USER, DATABASE_PASSWORD, DATABASE_HOST, DATABASE_SERVICE_NAME[/dim]"
            )

        # Step 2: Configure Gemini MCP server
        if configure_gemini_mcp_sqlcl():
            console.print("[green]✓ Configured SQLcl as Gemini MCP server[/green]")
            if success:
                console.print("[dim]  SQLcl is now fully configured for MCP access[/dim]")
            else:
                console.print("[dim]  Note: Password still needs to be configured[/dim]")
        else:
            console.print("[yellow]⚠ Could not auto-configure Gemini MCP[/yellow]")
            console.print("[dim]  You can manually add SQLcl to ~/.gemini/settings.json[/dim]")


def _configure_missing_mcp_extensions() -> None:
    """Configure MCP extensions that are not already configured.

    Checks for:
    - SQLcl (if installed and not configured)
    - Sequential Thinking (if not configured)
    - Context7 (if not configured)

    Only prompts for missing extensions.
    """
    # Check SQLcl
    sqlcl_path = shutil.which("sql")
    if sqlcl_path and not is_mcp_server_configured("sqlcl"):
        console.print()
        console.print("[bold cyan]SQLcl (Oracle Database)[/bold cyan]")
        console.print("[dim]Oracle database operations and SQL execution[/dim]")
        if Confirm.ask("Configure SQLcl MCP server?", default=True):
            # Step 1: Configure saved connection with password
            success, message = configure_sqlcl_connection_with_password()
            if success:
                console.print(f"[green]✓[/green] {message}")
            else:
                console.print(f"[yellow]⚠[/yellow] Password config: {message}")

            # Step 2: Configure Gemini MCP server
            if configure_gemini_mcp_sqlcl():
                console.print("[green]✓[/green] SQLcl MCP server configured")
    elif sqlcl_path:
        console.print("[dim]i SQLcl MCP server already configured[/dim]")

    # Configure other MCP extensions (only missing ones)
    results = configure_gemini_mcp_extensions(interactive=True)

    # Show summary
    console.print()
    console.print("[bold]MCP Configuration Summary:[/bold]")
    if sqlcl_path and is_mcp_server_configured("sqlcl"):
        console.print("  [green]✓[/green] sqlcl (Oracle Database)")
    for key, success in results.items():
        if success:
            console.print(f"  [green]✓[/green] {key}")
        else:
            console.print(f"  [dim]⊘ {key} (skipped)[/dim]")


@install_group.command(name="gemini-cli")
@click.option(
    "--force",
    is_flag=True,
    help="Force reinstall even if already installed",
)
@click.option(
    "--configure-mcp",
    is_flag=True,
    default=True,
    help="Configure MCP extensions (default: True)",
)
def install_gemini_cli_command(force: bool, configure_mcp: bool) -> None:
    """Install Google Gemini CLI.

    Idempotent: Safe to run multiple times. Skips installation if Gemini CLI is
    already installed unless --force flag is used.

    AI-powered terminal assistant with access to Gemini 2.5 Pro.
    Requires Node.js 18 or higher.

    Features:
    - Free tier: 60 requests/min, 1000 requests/day
    - 1M token context window
    - Built-in tools: Google Search, file ops, shell commands
    """
    console.print("[yellow]📦 Checking Gemini CLI installation...[/yellow]")
    console.print()

    # ALWAYS check if already installed
    is_installed, version_str = is_tool_installed("gemini")
    if is_installed and not force:
        console.print(f"[green]✓ Gemini CLI already installed: {version_str}[/green]")
        gemini_path = shutil.which("gemini")
        console.print(f"[dim]  Location: {gemini_path}[/dim]")
        console.print("[dim]  Use --force to reinstall[/dim]")

        # Still check for MCP configuration
        if configure_mcp:
            console.print()
            console.print("[yellow]🔧 Checking MCP configuration...[/yellow]")
            _configure_missing_mcp_extensions()

        return

    # Check for Node.js
    node_path = shutil.which("node")
    if not node_path:
        console.print("[red]✗ Node.js not found![/red]")
        console.print()
        console.print("[bold]Gemini CLI requires Node.js 18 or higher.[/bold]")
        console.print()
        console.print("[yellow]Install Node.js on Ubuntu/Debian:[/yellow]")
        console.print("  [cyan]curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -[/cyan]")
        console.print("  [cyan]sudo apt-get install -y nodejs[/cyan]")
        console.print()
        console.print("[yellow]RHEL/CentOS/Fedora:[/yellow]")
        console.print("  [cyan]curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -[/cyan]")
        console.print("  [cyan]sudo yum install -y nodejs[/cyan]  # or dnf")
        console.print()
        console.print("[yellow]Other platforms:[/yellow]")
        console.print("  • macOS: [cyan]brew install node@20[/cyan]")
        console.print("  • Download from: [dim]https://nodejs.org/[/dim]")
        console.print()
        raise click.Abort

    # Check Node.js version
    returncode, stdout, _ = run_command(["node", "--version"], check=False)
    if returncode == 0:
        version = stdout.strip()
        console.print(f"[green]✓ Node.js found: {version}[/green]")
        console.print()

    # Install via npm
    console.print("[cyan]Installing via npm...[/cyan]")
    console.print("[dim]Running: npm install -g @google/gemini-cli[/dim]")
    console.print()

    try:
        subprocess.run(
            ["npm", "install", "-g", "@google/gemini-cli"],
            check=True,
            text=True,
        )

        console.print()
        console.print("[green]✓ Gemini CLI installed successfully![/green]")
        console.print()

        # Configure popular MCP extensions
        console.rule("[bold cyan]MCP Extensions Configuration", style="cyan", align="left")
        console.print()
        console.print("[bold]Gemini CLI supports MCP (Model Context Protocol) extensions.[/bold]")
        console.print("These extensions enhance Gemini with additional capabilities.")
        console.print()

        # Check if SQLcl is installed and configure if available
        sqlcl_path = shutil.which("sql")
        sqlcl_configured = False
        if sqlcl_path:
            console.print()
            console.print("[bold cyan]SQLcl (Oracle Database)[/bold cyan]")
            console.print("[dim]Oracle database operations and SQL execution[/dim]")
            if Confirm.ask("Configure SQLcl MCP server?", default=True):
                # Step 1: Configure saved connection with password
                success, message = configure_sqlcl_connection_with_password()
                if success:
                    console.print(f"[green]✓[/green] {message}")
                else:
                    console.print(f"[yellow]⚠[/yellow] Password config: {message}")
                    console.print(
                        "[dim]  Ensure .env has DATABASE_USER, DATABASE_PASSWORD, DATABASE_HOST, DATABASE_SERVICE_NAME[/dim]"
                    )

                # Step 2: Configure Gemini MCP server
                if configure_gemini_mcp_sqlcl():
                    console.print("[green]✓[/green] SQLcl MCP server configured")
                    sqlcl_configured = True
                else:
                    console.print("[red]✗[/red] Failed to configure SQLcl MCP server")

        results = configure_gemini_mcp_extensions(interactive=True)

        # Show configuration results
        console.print()
        console.print("[bold]MCP Configuration Summary:[/bold]")
        if sqlcl_configured:
            console.print("  [green]✓[/green] sqlcl (Oracle Database)")
        for key, success in results.items():
            if success:
                console.print(f"  [green]✓[/green] {key}")
            else:
                console.print(f"  [dim]⊘ {key} (skipped)[/dim]")

        console.print()
        console.print("[bold]First run:[/bold]")
        console.print("  [cyan]gemini[/cyan]  # Launch interactive CLI")
        console.print()
        console.print("[bold]Authentication:[/bold]")
        console.print("  • Login with Google (free tier)")
        console.print("  • Or use API key from Google AI Studio")
        console.print()
        console.print("[dim]Learn more: https://github.com/google-gemini/gemini-cli[/dim]")

    except subprocess.CalledProcessError as e:
        console.print(f"[red]✗ Installation failed: {e}[/red]")
        raise click.Abort from e


@install_group.command(name="mcp-toolbox")
@click.option(
    "--force",
    is_flag=True,
    help="Force reinstall even if already installed",
)
@click.option(
    "--version",
    default="v0.16.0",
    help="Specific version to install (default: v0.16.0)",
)
def install_mcp_toolbox_command(force: bool, version: str) -> None:
    """Install MCP Toolbox for Databases.

    Idempotent: Safe to run multiple times. Skips installation if MCP Toolbox
    is already installed unless --force flag is used.

    Open-source MCP server for databases (AlloyDB, Spanner, Cloud SQL, etc.)
    Requires Go 1.21 or higher for installation from source.

    Binary downloads available for Linux, macOS (Intel/ARM), and Windows.
    """
    console.print("[yellow]📦 Checking MCP Toolbox installation...[/yellow]")
    console.print()

    # ALWAYS check if already installed
    is_installed, _version_str = is_tool_installed("toolbox")
    if is_installed and not force:
        console.print("[green]✓ MCP Toolbox already installed[/green]")
        toolbox_path = shutil.which("toolbox")
        console.print(f"[dim]  Location: {toolbox_path}[/dim]")
        console.print("[dim]  Use --force to reinstall[/dim]")
        return

    # If force flag, show warning
    if is_installed and force:
        console.print("[yellow]⚠ Reinstalling MCP Toolbox (--force flag used)[/yellow]")
        console.print()

    console.print("[yellow]📦 Installing MCP Toolbox for Databases...[/yellow]")
    console.print()

    # Detect platform
    import platform

    system = platform.system().lower()
    machine = platform.machine().lower()

    # Map to download OS/arch
    if (system == "linux" and "x86_64" in machine) or "amd64" in machine:
        os_arch = "linux/amd64"
    elif system == "darwin" and ("arm64" in machine or "aarch64" in machine):
        os_arch = "darwin/arm64"
    elif system == "darwin":
        os_arch = "darwin/amd64"
    elif system == "windows":
        os_arch = "windows/amd64"
    else:
        console.print(f"[red]✗ Unsupported platform: {system}/{machine}[/red]")
        raise click.Abort

    console.print(f"[cyan]Detected platform: {os_arch}[/cyan]")
    console.print()

    # Download binary
    download_url = f"https://storage.googleapis.com/genai-toolbox/{version}/{os_arch}/toolbox"
    install_path = Path.home() / ".local" / "bin" / "toolbox"

    console.print(f"[cyan]Downloading from: {download_url}[/cyan]")
    console.print()

    try:
        with httpx.stream("GET", download_url, follow_redirects=True, timeout=60) as response:
            response.raise_for_status()

            # Create install directory
            install_path.parent.mkdir(parents=True, exist_ok=True)

            # Download file
            with install_path.open("wb") as f:
                f.writelines(response.iter_bytes(chunk_size=8192))

        # Make executable
        install_path.chmod(0o755)

        console.print(f"[green]✓ MCP Toolbox installed to {install_path}[/green]")
        console.print()
        console.print("[bold]Verify installation:[/bold]")
        console.print("  [cyan]toolbox --version[/cyan]")
        console.print()
        console.print("[bold]Supported databases:[/bold]")
        console.print("  • AlloyDB for PostgreSQL (including AlloyDB Omni)")
        console.print("  • Cloud SQL (PostgreSQL, MySQL, SQL Server)")
        console.print("  • Spanner, Bigtable")
        console.print("  • Self-managed MySQL and PostgreSQL")
        console.print()
        console.print("[dim]Learn more: https://googleapis.github.io/genai-toolbox/[/dim]")

    except Exception as e:
        console.print(f"[red]✗ Installation failed: {e}[/red]")
        console.print()
        console.print("[yellow]Alternative: Install via Go[/yellow]")
        console.print(f"  [cyan]go install github.com/googleapis/genai-toolbox@{version}[/cyan]")
        raise click.Abort from e
