# Fix: Global Counter Reset Issue in Quarto Preview

## Problem

When using `numbering-style: global` in Quarto Books, counters would increment every time a change was saved during `quarto preview`, instead of maintaining stable numbers across re-renders.

### Example of the Bug

Initial render:
- Task 1
- Task 2  
- Task 3

After saving a file in preview mode:
- Task 4
- Task 5
- Task 6

After another save:
- Task 7
- Task 8
- Task 9

## Root Cause

When running `quarto preview` on a book:
1. The entire book is rendered initially, creating a state file with counter values
2. When you save a file, Quarto re-renders that specific chapter
3. The chapter restores global counters from the state file
4. **BUG**: The chapter then increments the counter again for the same IDs that were already numbered
5. This causes counters to grow unbounded with each save

## Solution

The fix adds a check before incrementing the global counter. If an ID already has an assigned number (from a previous render), that number is reused instead of incrementing the counter.

### Code Change

In `_extensions/custom-amsthm-environments/custom-amsthm-environments.lua`:

```lua
-- Global numbering
if current_counters[key][id] then
  -- ID already numbered (from previous render of this file), reuse the number
  current_number = current_counters[key][id]
else
  -- New ID, increment counter
  amsthm_counters[key] = amsthm_counters[key] + 1
  current_number = tostring(amsthm_counters[key])
end
```

## Verification

Three scenarios are tested:

1. **Initial render**: Tasks get sequential numbers (1, 2, 3)
2. **Re-render (preview save)**: Tasks keep the same numbers (1, 2, 3 - not 4, 5, 6)
3. **Add new task**: New task gets the next available number (4)

Run `python tests/verify-fix-logic.py` to see the verification.

## Testing

Two new tests were added:

1. **test-preview-behavior.py**: Integration test that simulates `quarto preview` by:
   - Rendering the entire book
   - Re-rendering a single chapter
   - Verifying counters remain stable

2. **verify-fix-logic.py**: Logic verification that simulates state management to prove the fix works correctly

Run the tests:
```bash
cd tests
python verify-fix-logic.py          # Quick verification
python test-preview-behavior.py     # Full integration test (requires Quarto)
```
