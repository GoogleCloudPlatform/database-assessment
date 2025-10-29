# Task Summary: Develop a Templated Collector Packager CLI

This task involved creating a new, standalone Python package `collector_cli` to replace the existing Makefile-based build process for database collector scripts. The primary goal was to leverage templating (Jinja2) to enable shareable SQL and script logic across different database types, while also handling database-specific complexities.

**Key Objectives Achieved:**
-   **New Package Foundation:** Established `src/collector_cli` as a distinct Python package.
-   **Centralized Templates:** Migrated all collector scripts and SQL into `src/collector_cli/templates` as `.j2` files.
-   **Jinja2 Macro System:** Implemented a macro system (`_macros.j2`) for target-aware rendering (e.g., CSV quoting for shell scripts vs. clean SQL for Python).
-   **Specialized Builders:** Developed custom builder classes (`OracleScriptRenderer`, `SqlServerPackageBuilder`, `StandardScriptBuilder`) to handle the unique requirements of Oracle (SQL*Plus pre-processor emulation), SQL Server (PowerShell templating and packaging), and standard shell scripts (PostgreSQL/MySQL).
-   **CLI Integration:** Integrated the packaging logic into a `rich-click` CLI for a user-friendly interface.
-   **Initial Unit Tests:** Created unit tests to validate the core packaging logic and macro rendering.

**Challenges Encountered & Addressed:**
-   **Python Packaging:** Resolved persistent `ModuleNotFoundError` issues by correctly configuring `pyproject.toml` and ensuring proper package discoverability.
-   **File Structure:** Refined the internal structure of the `packaging` module to ensure clarity and avoid naming conflicts.
-   **Oracle SQL*Plus Emulation:** Implemented logic within `OracleScriptRenderer` to handle `DEFINE` statements, `&variable` substitutions, and intelligent `@include` processing, distinguishing between Jinja2 includes and runtime SQL*Plus directives.
-   **Jinja2 Environment Configuration:** Corrected the Jinja2 `FileSystemLoader` and `ChoiceLoader` configurations in tests to ensure templates and macros are correctly discovered.
-   **Zip Archive Structure:** Fixed issues where packaged files were incorrectly nested within an `output/` directory inside the generated ZIP archives.

---

# Collector Packager CLI - TODO

This document outlines the remaining tasks to complete the `collector_cli` packaging tool.

## 1. Fix Unit Test Failures

The test suite is currently failing. The following areas need to be addressed:

### 1.1. `TestJinja2Macros` Failures

-   **Problem:** The tests for the Jinja2 macros (`_macros.j2`) are failing with `AssertionError`. The macros are not rendering the `target='script'` output correctly, suggesting an issue with how the `target` variable is being passed or scoped within the test's Jinja2 environment.
-   **Action:** Investigate the Jinja2 context/environment in the test setup and ensure the `target` variable is correctly influencing the macro's conditional logic.

### 1.2. `TestStandardScriptBuilder` & `TestSqlServerPackageBuilder` Failures

-   **Problem:** The zip file creation logic is flawed. The tests show that instead of a flat structure, the files are being placed inside an `output/` directory within the zip archive.
-   **Action:** Correct the path handling in the `_create_zip_package` method in `packager.py` to ensure the archive paths are relative to the build directory, not the output directory.

### 1.3. `TestOracleScriptRenderer` Failures

-   **Problem:** The Oracle script renderer is still failing to resolve dynamic `@include` paths that use variables, resulting in a `TemplateNotFound` error for an empty string `''`. This happens even after correcting the test syntax.
-   **Action:** Debug the `_render_recursive` method in `_oracle_renderer.py`. The logic that resolves the include name from a variable is likely producing an empty string, which the Jinja2 loader cannot handle. Add checks to ensure a valid file path is always passed to the loader.

## 2. Makefile Integration

-   **Problem:** The new `collector-cli` is a standalone tool, but the project's primary build process is managed by the root `Makefile`.
-   **Action:**
    -   Create a new `make package-collectors` target in the root `Makefile`.
    -   This target should invoke the `uv run collector_cli package-scripts` command.
    -   Remove the old, script-based `make zip` targets and any associated logic from the `Makefile` from the `Makefile`.

## 3. Documentation

-   **Problem:** The project's documentation needs to be updated to reflect the new build process.
-   **Action:**
    -   Update `docs/developer_guide/developer_setup.md` to include instructions for installing and using the new `collector-cli` tool.
    -   Update `README.md` to mention the new packaging command.
    -   Review all developer-facing documentation to ensure there are no outdated references to the old `make zip` process.
