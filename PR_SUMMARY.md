# Pull Request Summary

## Issue Fixed
Resolves the global numbering reset issue where counters with `numbering-style: global` would increment across multiple Quarto renders instead of resetting.

## Problem Description
When using `numbering-style: global`, the counter state was persisting between renders:
- **Expected behavior**: First render shows Task 1, 2, 3; second render shows Task 1, 2, 3
- **Actual behavior (before fix)**: First render shows Task 1, 2, 3; second render shows Task 4, 5, 6

## Root Cause
Lua module-level variables were persisting across multiple Quarto render operations when Quarto reused the same Lua interpreter state. While the state file was being reset correctly, the in-memory Lua variables retained their old values.

## Solution
Added explicit reset of all in-memory state variables (`custom_amsthm_envs`, `amsthm_counters`, `current_counters`, `section_counters`, `new_ids_this_chapter`) when processing:
1. Non-book documents (standalone articles)
2. First chapter of books

This ensures proper state management while preserving the intended behavior of accumulating counters across book chapters.

## Changes Made

### Core Fix
- **_extensions/custom-amsthm-environments/custom-amsthm-environments.lua**
  - Added `current_section = nil` reset at line 110
  - Added in-memory state reset (5 variables) before file state reset
  - Total: 8 lines added, minimal surgical change

### New Test Infrastructure
- **tests/global-reset/** - New test project with 3 tasks using global numbering
- **tests/test-global-reset.py** - Automated script that renders 3 times and verifies counters reset
- **tests/expected/global-reset-test-global-html.txt** - Expected output for the test

### Documentation
- **GLOBAL_NUMBERING_FIX.md** - Summary of the issue and fix
- **VERIFICATION_GUIDE.md** - Manual testing instructions
- **TECHNICAL_DETAILS.md** - In-depth technical analysis
- **tests/README.md** - Updated with new test instructions

### CI/CD
- **.github/workflows/test.yml** - Added `test-global-reset.py` to CI workflow

## Testing

### Automated Tests
1. **New test**: `test-global-reset.py` - Verifies numbering resets across multiple renders
2. **Existing tests**: All existing tests should continue to pass
   - Article test: Verifies global numbering in standalone document
   - Book test: Verifies global numbering accumulates across chapters

### Manual Verification
See VERIFICATION_GUIDE.md for step-by-step manual testing instructions.

### Test Coverage
- ✅ Multiple renders of standalone article reset counters
- ✅ Book chapters accumulate counters correctly
- ✅ Section-based numbering still works
- ✅ Mixed numbering styles work together
- ✅ Cross-chapter references in books still work

## Backward Compatibility
✅ Fully backward compatible:
- No API changes
- No configuration changes required
- Existing documents work unchanged
- Book chapter behavior preserved
- Section-based numbering unchanged

## Impact
- **Fixes**: Global numbering now correctly resets for standalone documents
- **Preserves**: Book chapter numbering still accumulates correctly
- **No Breaking Changes**: All existing functionality maintained
- **Performance**: Negligible impact (a few variable assignments)

## How to Review
1. Check the core fix in the Lua file (minimal 8-line change)
2. Review the test project in `tests/global-reset/`
3. Read the documentation files for context
4. CI will run the automated tests

## Files Changed
```
.github/workflows/test.yml                                            |   3 +-
 GLOBAL_NUMBERING_FIX.md                                               |  92 ++++++++++++
 TECHNICAL_DETAILS.md                                                  | 144 ++++++++++++++++++
 VERIFICATION_GUIDE.md                                                 |  94 ++++++++++++
 _extensions/custom-amsthm-environments/custom-amsthm-environments.lua |  10 +-
 tests/README.md                                                       |  22 ++-
 tests/expected/global-reset-test-global-html.txt                      |  23 +++
 tests/global-reset/_quarto.yml                                        |   3 +
 tests/global-reset/test-global.qmd                                    |  34 +++++
 tests/test-global-reset.py                                            | 119 +++++++++++++++
 10 files changed, 541 insertions(+), 3 deletions(-)
```

## Commits
1. `10a0e1b` - Fix global numbering reset issue and add test
2. `1e19700` - Add documentation and update CI workflow for global reset test
3. `b07e527` - Add technical documentation for global numbering fix
