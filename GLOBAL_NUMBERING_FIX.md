# Global Numbering Reset Fix - Summary

## Problem Description

When using `numbering-style: global` in custom amsthm environments, the counter was not resetting between Quarto renders. This caused the numbering to increment continuously across multiple renders of the same document, leading to incorrect numbering (e.g., Task 4, Task 5, Task 6 instead of Task 1, Task 2, Task 3 on the second render).

## Root Cause

The issue was caused by Lua module-level variables persisting across multiple Quarto renders when Quarto reuses the same Lua state. The variables:

- `custom_amsthm_envs`
- `amsthm_counters`
- `current_counters`
- `section_counters`
- `new_ids_this_chapter`

were initialized once when the Lua module loaded and never reset for non-book documents or first chapters. While the state file was being reset, the in-memory Lua variables were retaining their values from the previous render.

## Solution

The fix adds explicit reset of all in-memory state variables in the `process_custom_amsthm` function when processing:
1. Non-book documents (where `current_section` is `nil`)
2. The first chapter of a book (where `current_section == "1"`)

Additionally, `current_section` is now explicitly reset to `nil` at the beginning of each document processing to ensure proper detection of non-book documents.

### Changes Made

1. **File**: `_extensions/custom-amsthm-environments/custom-amsthm-environments.lua`
   - Added `current_section = nil` at line 110 to reset for each document
   - Added in-memory state reset (lines 127-132) before resetting the state file
   - This ensures both file-based and in-memory state are properly reset

## Test Coverage

A new test was created to verify the fix:

### Test Project: `tests/global-reset/`

- **File**: `test-global.qmd` - A simple document with three tasks using global numbering
- **Expected**: `tests/expected/global-reset-test-global-html.txt` - Expected HTML output
- **Script**: `tests/test-global-reset.py` - Automated test that renders the project multiple times and verifies numbering resets correctly

### Running the Test

```bash
cd tests
python test-global-reset.py
```

The test will:
1. Render the global-reset project 3 times
2. Extract Task numbers from each render
3. Verify that all renders produce Tasks numbered 1, 2, 3 (not incrementing)

### Integration with Existing Tests

The new test also integrates with the existing test framework:

```bash
cd tests
python run-tests.py global-reset
```

## Verification

To verify the fix works:

1. **Manual Test**:
   ```bash
   cd tests/global-reset
   quarto render  # First render - should show Task 1, 2, 3
   quarto render  # Second render - should still show Task 1, 2, 3 (not 4, 5, 6)
   ```

2. **Automated Test**:
   ```bash
   cd tests
   python test-global-reset.py
   ```

3. **Full Test Suite**:
   ```bash
   cd tests
   python run-tests.py
   ```

## Impact

- ✅ **Fixes**: Global numbering now correctly resets for standalone documents
- ✅ **Preserves**: Book chapter numbering still works correctly (state accumulates across chapters)
- ✅ **No Breaking Changes**: Existing behavior for section-based numbering remains unchanged
