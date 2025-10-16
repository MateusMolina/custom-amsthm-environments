# Custom AmSThm Environments - Test Framework

Automatic test runner for validating HTML/LaTeX/PDF output from Quarto projects.

## Running Tests

```bash
# Run all tests
python run-tests.py

# Run tests for specific project
python run-tests.py book
python run-tests.py article
python run-tests.py global-reset
```

## Expected File Format

Test expectations are defined in `expected/` directory with files named `{project}-{file}-{format}.txt`.

### File Naming Pattern
- `book-chapter2-html.txt` → Tests `book/_output/chapter2.html` (renders with `--to html`)
- `book-chapter2-tex.txt` → Tests `book/_output/chapter2.tex` (renders with `--to latex`)

### Test Case Format
Each test case uses `=== test-id ===` markers:

```
=== Test Problem 1 ===
<div id="prm-first" class="theorem">
<p><span class="theorem-title"><strong>Problem 1 (First Problem)</strong></span> Verify that this extension works correctly.</p>
</div>

=== Test Problem 1 reference ===
<a href="#prm-first" class="quarto-xref">Problem&nbsp;1</a>
```

The test runner:
1. Parses test cases from expected files
2. Runs `quarto render --to {format}` for each project
3. Compares expected snippets against rendered output
4. Reports pass/fail status in Maven-style format

## Adding New Tests

1. Create expected file: `expected/{project}-{file}-{format}.txt`
2. Add test cases with `=== test-id ===` markers
3. Run tests to validate

## Supported Formats

- `html` → `quarto render --to html` → `.html` files
- `tex` → `quarto render --to latex` → `.tex` files

## Special Tests

### Global Numbering Reset Test

The `global-reset` project tests that global numbering resets properly between renders. This test includes a pre-existing "dirty" state file (`.quarto/amsthm-state-53095.lua`) that simulates a previous render with counters at 3.

When the test runs, the fix ensures that:
1. The counters reset despite the dirty state file
2. Task numbers are correctly shown as 1, 2, 3 (not 4, 5, 6)
3. The state properly resets for standalone documents