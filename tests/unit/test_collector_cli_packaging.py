import shutil
import zipfile
from pathlib import Path

import pytest
from jinja2 import ChoiceLoader, Environment, FileSystemLoader

from collector_cli.packager import CollectorPackager
from collector_cli.packaging import (
    OracleScriptRenderer,
    SqlServerPackageBuilder,
    StandardScriptBuilder,
)

# Define paths relative to the test file
TEST_TEMPLATES_DIR = Path(__file__).parent.parent.parent / "src" / "collector_cli" / "templates"
TEST_OUTPUT_DIR = Path(__file__).parent / "test_output"


@pytest.fixture(autouse=True)
def cleanup_test_output_dir():
    """Fixture to clean up the test output directory before and after tests."""
    if TEST_OUTPUT_DIR.exists():
        shutil.rmtree(TEST_OUTPUT_DIR)
    TEST_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    yield
    if TEST_OUTPUT_DIR.exists():
        shutil.rmtree(TEST_OUTPUT_DIR)


@pytest.fixture
def jinja_env():
    """Fixture for a Jinja2 environment configured for testing macros."""
    return Environment(
        loader=ChoiceLoader([
            FileSystemLoader(str(TEST_TEMPLATES_DIR)),
            FileSystemLoader(str(TEST_TEMPLATES_DIR / "macros")),
        ]),
        autoescape=False,  # We're generating shell scripts, not HTML  # noqa: S701
        trim_blocks=True,
        lstrip_blocks=True,
    )


class TestJinja2Macros:
    """Tests for the Jinja2 macro system."""

    def test_script_col_macro(self, jinja_env):
        """Test the script_col macro for CSV quoting."""
        template = jinja_env.get_template("_macros.j2")
        jinja_env.globals["target"] = "script"
        result = template.module.col("test")
        assert result.strip() == "chr(34) || test || chr(34)"

    def test_python_col_macro(self, jinja_env):
        """Test the python_col macro for clean output."""
        template = jinja_env.get_template("_macros.j2")
        jinja_env.globals["target"] = "python"
        result = template.module.col("test")
        assert result.strip() == "test"

    def test_col_macro_with_expression(self, jinja_env):
        """Test the col macro with a more complex expression."""
        template = jinja_env.get_template("_macros.j2")
        jinja_env.globals["target"] = "script"
        script_result = template.module.col("replace(src.setting_category, chr(34), chr(39))")
        jinja_env.globals["target"] = "python"
        python_result = template.module.col("replace(src.setting_category, chr(34), chr(39))")
        assert script_result.strip() == "chr(34) || replace(src.setting_category, chr(34), chr(39)) || chr(34)"
        assert python_result.strip() == "replace(src.setting_category, chr(34), chr(39))"


class TestOracleScriptRenderer:
    """Tests for the OracleScriptRenderer class."""

    @pytest.fixture
    def oracle_templates_dir(self):
        """Fixture for Oracle templates directory."""
        return TEST_TEMPLATES_DIR / "scripts" / "oracle"

    def test_define_and_substitution(self, oracle_templates_dir):
        """Test DEFINE statements and variable substitution."""
        # Create mock template files
        (oracle_templates_dir / "test_main.sql.j2").write_text(
            "DEFINE my_var='test_value'\nSELECT '&my_var' FROM DUAL;"
        )
        renderer = OracleScriptRenderer(oracle_templates_dir, TEST_TEMPLATES_DIR / "macros")
        result = renderer.render("test_main.sql.j2", {})
        assert "SELECT 'test_value' FROM DUAL;" in result

    def test_recursive_includes(self, oracle_templates_dir):
        """Test recursive @include statements."""
        (oracle_templates_dir / "main.sql.j2").write_text("@include1.sql.j2")
        (oracle_templates_dir / "include1.sql.j2").write_text("SELECT 1 FROM DUAL;\n@include2.sql.j2")
        (oracle_templates_dir / "include2.sql.j2").write_text("SELECT 2 FROM DUAL;")

        renderer = OracleScriptRenderer(oracle_templates_dir, TEST_TEMPLATES_DIR / "macros")
        result = renderer.render("main.sql.j2", {})
        assert "SELECT 1 FROM DUAL;" in result
        assert "SELECT 2 FROM DUAL;" in result

    def test_dynamic_include_with_variable(self, oracle_templates_dir):
        """Test dynamic @include paths using variables."""
        (oracle_templates_dir / "dynamic_main.sql.j2").write_text(
            "DEFINE script_name='dynamic_part.sql'\n@{{script_name}}"
        )
        (oracle_templates_dir / "dynamic_part.sql.j2").write_text("SELECT 'Dynamic Content' FROM DUAL;")

        renderer = OracleScriptRenderer(oracle_templates_dir, TEST_TEMPLATES_DIR / "macros")
        result = renderer.render("dynamic_main.sql.j2", {})
        assert "SELECT 'Dynamic Content' FROM DUAL;" in result


class TestSqlServerPackageBuilder:
    """Tests for the SqlServerPackageBuilder class."""

    @pytest.fixture
    def sqlserver_templates_dir(self):
        """Fixture for SQL Server templates directory."""
        return TEST_TEMPLATES_DIR / "scripts" / "sqlserver"

    def test_build_package(self, sqlserver_templates_dir):
        """Test that the SQL Server package builds correctly."""
        # Create a dummy template file
        (sqlserver_templates_dir / "test_script.ps1.j2").write_text("Write-Host 'Hello, {{ version }}'")
        (sqlserver_templates_dir / "sql" / "test_query.sql.j2").write_text("SELECT '{{ target }}' FROM DUAL;")

        builder = SqlServerPackageBuilder(
            template_path=TEST_TEMPLATES_DIR,
            macros_path=TEST_TEMPLATES_DIR / "macros",
            build_dir=TEST_OUTPUT_DIR,
            output_dir=TEST_OUTPUT_DIR,
            version="1.0.0",
        )
        result = builder.build_package()

        assert result["database_type"] == "sqlserver"
        assert Path(result["package_path"]).exists()

        # Verify contents of the zip file
        with zipfile.ZipFile(result["package_path"], "r") as zipf:
            assert "test_script.ps1" in zipf.namelist()
            assert "sql/test_query.sql" in zipf.namelist()
            with zipf.open("test_script.ps1") as f:
                content = f.read().decode("utf-8")
                assert "Hello, 1.0.0" in content
            with zipf.open("sql/test_query.sql") as f:
                content = f.read().decode("utf-8")
                assert "SELECT 'script' FROM DUAL;" in content


class TestStandardScriptBuilder:
    """Tests for the StandardScriptBuilder class."""

    @pytest.fixture
    def postgres_templates_dir(self):
        """Fixture for PostgreSQL templates directory."""
        return TEST_TEMPLATES_DIR / "scripts" / "postgres"

    def test_build_package(self, postgres_templates_dir):
        """Test that the standard package builds correctly for PostgreSQL."""
        # Create dummy template files
        (postgres_templates_dir / "collect-data.sh.j2").write_text(
            "#!/bin/bash\necho 'Version: {{ version }}'\npsql -f sql/test_query.sql"
        )
        (postgres_templates_dir / "sql" / "test_query.sql.j2").write_text("SELECT {{ macros.col(':PKEY') }} FROM DUAL;")

        builder = StandardScriptBuilder(
            template_path=TEST_TEMPLATES_DIR,
            macros_path=TEST_TEMPLATES_DIR / "macros",
            build_dir=TEST_OUTPUT_DIR,
            output_dir=TEST_OUTPUT_DIR,
            version="1.0.0",
            database_type="postgres",
        )
        result = builder.build_package()

        assert result["database_type"] == "postgres"
        assert Path(result["package_path"]).exists()

        with zipfile.ZipFile(result["package_path"], "r") as zipf:
            assert "collect-data.sh" in zipf.namelist()
            assert "sql/test_query.sql" in zipf.namelist()
            with zipf.open("collect-data.sh") as f:
                content = f.read().decode("utf-8")
                assert "Version: 1.0.0" in content
            with zipf.open("sql/test_query.sql") as f:
                content = f.read().decode("utf-8")
                assert "SELECT chr(34) || :PKEY || chr(34) FROM DUAL;" in content


class TestCollectorPackager:
    """Tests for the main CollectorPackager class."""

    def test_package_all_collectors(self, mocker):
        """Test that package_all_collectors calls the correct builders."""
        mock_oracle_builder = mocker.patch(
            "collector_cli.packaging._oracle_renderer.OracleScriptRenderer.render", return_value="oracle script content"
        )
        mock_sqlserver_builder = mocker.patch(
            "collector_cli.packaging._sqlserver_builder.SqlServerPackageBuilder.build_package",
            return_value={"package_path": "sqlserver.zip"},
        )
        mock_standard_builder = mocker.patch(
            "collector_cli.packaging._standard_builder.StandardScriptBuilder.build_package",
            return_value={"package_path": "standard.zip"},
        )

        packager = CollectorPackager(output_dir=str(TEST_OUTPUT_DIR), version="test_version")
        results = packager.package_all_collectors()

        assert "oracle" in results
        assert "sqlserver" in results
        assert "postgres" in results
        assert "mysql" in results

        mock_oracle_builder.assert_called_once()
        mock_sqlserver_builder.assert_called_once()
        assert mock_standard_builder.call_count == 2  # postgres and mysql

    def test_package_single_collector(self, mocker):
        """Test packaging a single collector."""
        mock_sqlserver_builder = mocker.patch(
            "collector_cli.packaging._sqlserver_builder.SqlServerPackageBuilder.build_package",
            return_value={"package_path": "sqlserver.zip"},
        )

        packager = CollectorPackager(output_dir=str(TEST_OUTPUT_DIR), version="test_version")
        result = packager.package_collector("sqlserver")

        assert result["package_path"] == "sqlserver.zip"
        mock_sqlserver_builder.assert_called_once()
