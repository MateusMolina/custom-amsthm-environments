#!/usr/bin/env python3
"""
Automatic test runner for custom-amsthm-environments
Auto-detects tests from expected/ folder and runs quarto render for each project.

Usage:
  python run-tests.py [project-name]

Examples:
  python run-tests.py          # Run all tests
  python run-tests.py book     # Run only book tests
  python run-tests.py article  # Run only article tests
"""

import sys
import subprocess
import re
import logging
from pathlib import Path
from dataclasses import dataclass


# ANSI color codes
class Colors:
    RESET = "\033[0m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    CYAN = "\033[36m"
    BOLD = "\033[1m"


class TestConfig:
    """Configuration constants for the test framework."""

    # Test case marker pattern
    test_marker: str = "==="

    # Format type to quarto render argument mapping
    format_mappings = {
        "html": "html",
        "tex": "latex",
    }

    # Format type to file extension mapping
    extension_mappings = {
        "html": ".html",
        "tex": ".tex",
    }

    # Preview length for failed test output
    preview_length: int = 200

    # Render timeout in seconds
    render_timeout: int = 120

    def get_render_format(self, format_type):
        """Get the quarto render --to argument for a given format type."""
        return self.format_mappings.get(format_type, format_type)

    def get_file_extension(self, format_type):
        """Get the file extension for a given format type."""
        return self.extension_mappings.get(format_type, f".{format_type}")


# Global test configuration
TEST_CONFIG = TestConfig()


# Custom formatter with colors
class ColoredFormatter(logging.Formatter):
    """Custom formatter with color support."""

    FORMATS = {
        logging.DEBUG: Colors.CYAN + "%(message)s" + Colors.RESET,
        logging.INFO: "%(message)s",
        logging.WARNING: Colors.YELLOW + "%(message)s" + Colors.RESET,
        logging.ERROR: Colors.RED + "%(message)s" + Colors.RESET,
    }

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno, "%(message)s")
        formatter = logging.Formatter(log_fmt)
        return formatter.format(record)


# Setup logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
handler.setFormatter(ColoredFormatter())
logger.addHandler(handler)


@dataclass
class TestCase:
    """Represents a single test case with expected snippet."""

    test_id: str
    expected_content: str


@dataclass
class TestFile:
    """Represents a test configuration derived from expected file."""

    expected_file: Path
    project_name: str
    output_file: str
    format_type: str
    test_cases: list


def print_header(title):
    """Print header."""
    logger.info(
        f"\n{Colors.CYAN}-------------------------------------------------------{Colors.RESET}"
    )
    logger.info(f"{Colors.CYAN} {' '.join(title.upper())}{Colors.RESET}")
    logger.info(
        f"{Colors.CYAN}-------------------------------------------------------{Colors.RESET}"
    )


def parse_expected_file(filepath):
    """
    Parse expected file to extract test cases.
    Each test case starts with === test-id === and continues until the next marker.
    """
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    test_cases = []
    # Split by the === marker pattern
    marker = TEST_CONFIG.test_marker
    pattern = rf"{marker}\s+(.+?)\s+{marker}"
    parts = re.split(pattern, content)

    # parts[0] is content before first marker (usually empty or comments)
    # Then alternates between test_id and content
    for i in range(1, len(parts), 2):
        if i + 1 < len(parts):
            test_id = parts[i].strip()
            expected_content = parts[i + 1].strip()

            if expected_content:  # Only add non-empty test cases
                test_cases.append(
                    TestCase(test_id=test_id, expected_content=expected_content)
                )

    return test_cases


def parse_filename(filename):
    """
    Parse expected filename to extract project name, output file, and format type.

    Pattern: {project}-{outputfile}-{format}.txt
    Examples:
      - article-article-html.txt -> (article, article, html)
      - book-chapter2-html.txt -> (book, chapter2, html)
      - book-chapter2-tex.txt -> (book, chapter2, tex)
      - book-index-html.txt -> (book, index, html)
    """
    # Remove .txt extension
    name = filename.replace(".txt", "")

    # Split by last hyphen to get format type
    parts = name.rsplit("-", 1)
    if len(parts) != 2:
        raise ValueError(f"Invalid filename format: {filename}")

    format_type = parts[1]

    # Split the remaining part by first hyphen to get project and output file
    remaining = parts[0]
    parts = remaining.split("-", 1)
    if len(parts) != 2:
        raise ValueError(f"Invalid filename format: {filename}")

    project_name = parts[0]
    output_file_base = parts[1]

    # Get the appropriate file extension for this format
    extension = TEST_CONFIG.get_file_extension(format_type)
    output_file = f"{output_file_base}{extension}"

    return project_name, output_file, format_type


def discover_tests(expected_dir):
    """
    Discover all test files from expected/ directory.
    Returns a dictionary mapping project names to their test files.
    """
    tests_by_project = {}

    for expected_file in expected_dir.glob("*-*.txt"):
        try:
            project_name, output_file, format_type = parse_filename(expected_file.name)
            test_cases = parse_expected_file(expected_file)

            test_file = TestFile(
                expected_file=expected_file,
                project_name=project_name,
                output_file=output_file,
                format_type=format_type,
                test_cases=test_cases,
            )

            if project_name not in tests_by_project:
                tests_by_project[project_name] = []

            tests_by_project[project_name].append(test_file)

        except Exception as e:
            logger.warning(f"Could not parse {expected_file.name}: {e}")

    return tests_by_project


def normalize_whitespace(text: str) -> str:
    """Normalize whitespace for comparison."""
    # Remove leading/trailing whitespace
    text = text.strip()
    # Normalize multiple spaces/newlines to single space
    text = re.sub(r"\s+", " ", text)
    return text


def render_project(project_dir, format_type):
    """
    Run quarto render --to {format} for the specified project.
    Returns True if successful, False otherwise.
    """
    render_format = TEST_CONFIG.get_render_format(format_type)
    logger.info(
        f"{Colors.BLUE}Rendering project: {project_dir.name} (format: {render_format}){Colors.RESET}"
    )

    try:
        # Add extension if missing
        result = subprocess.run(
            ["quarto", "add", "../..", "--no-prompt"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            timeout=TEST_CONFIG.render_timeout,
        )

        if result.returncode != 0:
            logger.error(f"Error adding extension to {project_dir.name}:")
            logger.error(result.stderr)
            return False

        logger.info(
            f"{Colors.GREEN}✓ Added extension to {project_dir.name}{Colors.RESET}"
        )

        result = subprocess.run(
            ["quarto", "render", "--to", render_format],
            cwd=project_dir,
            capture_output=True,
            text=True,
            timeout=TEST_CONFIG.render_timeout,
        )

        if result.returncode != 0:
            logger.error(f"Error rendering {project_dir.name}:")
            logger.error(result.stderr)
            return False

        logger.info(
            f"{Colors.GREEN}✓ Successfully rendered {project_dir.name}{Colors.RESET}"
        )
        return True

    except subprocess.TimeoutExpired:
        logger.error(f"✗ Timeout rendering {project_dir.name}")
        return False
    except Exception as e:
        logger.error(f"✗ Error rendering {project_dir.name}: {e}")
        return False


def run_test_file(test_file, tests_dir):
    """
    Run tests for a single test file.
    Returns (passed_count, failed_count, test_results).
    """
    # Determine actual HTML file path
    project_dir = tests_dir / test_file.project_name
    output_path = project_dir / "_output" / test_file.output_file

    if not output_path.exists():
        logger.error(f"Output file not found: {output_path}")
        return 0, len(test_file.test_cases), []

    # Read actual HTML content
    with open(output_path, "r", encoding="utf-8") as f:
        actual_content = f.read()

    normalized_actual = normalize_whitespace(actual_content)

    passed = 0
    failed = 0
    test_results = []

    # Run each test case
    for test_case in test_file.test_cases:
        normalized_expected = normalize_whitespace(test_case.expected_content)

        if normalized_expected in normalized_actual:
            passed += 1
            test_results.append((test_case.test_id, True, None))
        else:
            failed += 1
            # Show first N chars of expected content
            display_content = test_case.expected_content[: TEST_CONFIG.preview_length]
            if len(test_case.expected_content) > TEST_CONFIG.preview_length:
                display_content += "..."
            test_results.append((test_case.test_id, False, display_content))

    return passed, failed, test_results


def run_tests_for_project(project_name, test_files, tests_dir):
    """
    Run all tests for a specific project.
    Returns True if all tests passed, False otherwise.
    """
    print_header("Tests")

    # Render the project - get format from first test file (all should have same format for a project)
    project_dir = tests_dir / project_name
    if not project_dir.exists():
        logger.error(f"Project directory not found: {project_dir}")
        return False

    # Get the format type from the first test file
    format_type = test_files[0].format_type if test_files else "html"

    if not render_project(project_dir, format_type):
        return False

    logger.info("")  # Blank line

    # Run tests for each output file
    total_passed = 0
    total_failed = 0
    all_test_results = []

    for test_file in test_files:
        test_name = f"{test_file.project_name}.{test_file.output_file}"
        logger.info(f"Running {test_name}")

        passed, failed, test_results = run_test_file(test_file, tests_dir)
        total_passed += passed
        total_failed += failed
        all_test_results.extend(test_results)

        total = passed + failed
        logger.info(f"Tests run: {total}, Failures: {failed}")

        # Show failures if any
        if failed > 0:
            logger.info("")
            for test_id, success, error_msg in test_results:
                if not success:
                    logger.error(f"  {test_id}  FAILED!")
                    if error_msg:
                        logger.info(f"    Expected snippet not found:")
                        logger.info(f"    {error_msg}")
            logger.info("")

    # Summary for this project
    logger.info(f"\nResults :\n")

    # Show all failures
    failures = [(tid, err) for tid, success, err in all_test_results if not success]
    if failures:
        logger.error("Failed tests:")
        for test_id, error_msg in failures:
            logger.error(f"  {test_id}")
        logger.info("")

    total = total_passed + total_failed
    logger.info(f"Tests run: {total}, Failures: {total_failed}")
    logger.info("")

    return total_failed == 0


def main():
    # Determine directories
    script_dir = Path(__file__).parent
    tests_dir = script_dir
    expected_dir = tests_dir / "expected"

    if not expected_dir.exists():
        logger.error("[ERROR] expected/ directory not found")
        sys.exit(1)

    # Discover tests
    tests_by_project = discover_tests(expected_dir)

    if not tests_by_project:
        logger.warning(f"No tests found in {expected_dir}")
        sys.exit(0)

    # Filter by command line argument if provided
    if len(sys.argv) > 1:
        requested_project = sys.argv[1]
        if requested_project not in tests_by_project:
            logger.error(f"[ERROR] Project '{requested_project}' not found")
            logger.info(f"Available projects: {', '.join(tests_by_project.keys())}")
            sys.exit(1)
        tests_by_project = {requested_project: tests_by_project[requested_project]}

    # Run tests for each project
    all_passed = True
    results = {}
    total_tests = 0
    total_failures = 0

    for project_name, test_files in sorted(tests_by_project.items()):
        # Count total tests for this project
        project_test_count = sum(len(tf.test_cases) for tf in test_files)
        total_tests += project_test_count

        project_passed = run_tests_for_project(project_name, test_files, tests_dir)
        results[project_name] = project_passed

        if not project_passed:
            all_passed = False
            # Count failures for this project
            for test_file in test_files:
                output_path = (
                    tests_dir
                    / test_file.project_name
                    / "_output"
                    / test_file.output_file
                )
                if output_path.exists():
                    with open(output_path, "r", encoding="utf-8") as f:
                        actual_content = f.read()
                    normalized_actual = normalize_whitespace(actual_content)
                    for test_case in test_file.test_cases:
                        normalized_expected = normalize_whitespace(
                            test_case.expected_content
                        )
                        if normalized_expected not in normalized_actual:
                            total_failures += 1

    # Final summary - Maven style
    print_header("Results")

    if all_passed:
        logger.info(f"{Colors.GREEN}[INFO] SUCCESS{Colors.RESET}")
    else:
        logger.error(f"[ERROR] FAILURE")
        logger.info("")
        logger.error("Failed tests:")
        for project_name, passed in sorted(results.items()):
            if not passed:
                logger.error(f"  {project_name}")

    logger.info(
        f"{Colors.CYAN}-------------------------------------------------------{Colors.RESET}"
    )
    logger.info("")

    if all_passed:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
