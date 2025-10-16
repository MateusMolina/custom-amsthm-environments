# Technical Details: Global Numbering Reset Fix

## Problem Analysis

### Root Cause

The issue occurred because Lua filter state persists across multiple Quarto render operations when Quarto reuses the same Lua interpreter state. The extension used module-level variables to track counters:

```lua
local custom_amsthm_envs = {}
local amsthm_counters = {}
local current_counters = {}
local section_counters = {}
local new_ids_this_chapter = {}
```

These variables are initialized once when the Lua module loads and persist across multiple document renders in the same Lua session.

### Symptoms

For documents with `numbering-style: global`:
- First render: Task 1, Task 2, Task 3 ✓
- Second render (same Quarto session): Task 4, Task 5, Task 6 ✗
- Third render: Task 7, Task 8, Task 9 ✗

The counters were incrementing instead of resetting because:
1. The state file was being reset correctly
2. BUT the in-memory Lua variables retained their old values
3. When processing environments, the code would increment the already-high counter values

### Why It Only Affected Global Numbering

Section-based numbering (`numbering-style: section`) was not affected because:
- It uses `section_counters` which is indexed by section number
- Each section resets its own counter
- The logic is self-contained within each render

Global numbering was affected because:
- It uses `amsthm_counters` which accumulates across all environments
- The accumulation is intentional for book chapters
- But it should reset for standalone articles

## Solution

### Code Changes

The fix adds explicit reset of all in-memory state variables when processing:
1. Non-book documents (where `current_section` is `nil`)
2. First chapter of a book (where `current_section == "1"`)

```lua
-- Reset state file on first chapter or non-book documents
if not current_section or current_section == "1" then
  -- Reset in-memory state for fresh start
  custom_amsthm_envs = {}
  amsthm_counters = {}
  current_counters = {}
  section_counters = {}
  new_ids_this_chapter = {}
  
  local file = io.open(state_file, "w")
  if file then
    file:write(serialize_table({counters = {}, values = {}, files = {}}) .. "\n")
    file:close()
  end
end
```

### Why This Works

**For standalone articles:**
- `current_section` is always `nil`
- Condition triggers on every render
- All state is reset, both in-memory and on disk
- Counters start fresh from 0
- Result: Task 1, Task 2, Task 3 on every render ✓

**For book chapters:**
- Chapter 1: `current_section == "1"`, state is reset
- Chapter 2+: `current_section` is "2", "3", etc., state is NOT reset
- Counters accumulate across chapters
- Result: Chapter 2 has Task 1, 2; Chapter 3 has Task 3 (continuing) ✓

### Additional Fix

The code also explicitly resets `current_section = nil` at the start of each document processing:

```lua
-- Extract chapter number from Span with class "chapter-number" in title
current_section = nil  -- Reset for each document
```

This ensures that if Quarto processes multiple documents in sequence, each document starts with a clean `current_section` state and properly detects whether it's a book chapter or standalone article.

## Testing Strategy

### Unit Test: global-reset Project

A new test project specifically tests the reset behavior:
- Contains 3 tasks with global numbering
- Expected output always shows Task 1, 2, 3
- Can be rendered multiple times to verify reset

### Integration Test: test-global-reset.py

A Python script that:
1. Renders the global-reset project 3 times consecutively
2. Extracts task numbers from each render's HTML output
3. Verifies all renders produce [1, 2, 3] (not incrementing)
4. Fails if any render shows different numbering

### Regression Tests

Existing tests verify that:
- Article test: Tasks still numbered correctly with global style
- Book test: Tasks accumulate correctly across chapters
- Section-based numbering still works as before

## Edge Cases Considered

1. **Multiple renders in same session**: Fixed ✓
2. **Book chapters in sequence**: Preserved ✓
3. **Mixed numbering styles**: Section + global both work ✓
4. **Cross-chapter references in books**: Still work ✓
5. **First render ever**: Works as before ✓
6. **State file corruption**: Reset overwrites with clean state ✓

## Performance Impact

Minimal:
- Adds one assignment (`current_section = nil`)
- Adds 5 table resets (empty assignment)
- Only executes when condition is met (first chapter or article)
- No impact on subsequent chapters in books
- No impact on overall render time

## Backward Compatibility

✓ Fully backward compatible:
- No API changes
- No configuration changes required
- Existing documents continue to work
- Book chapter accumulation preserved
- Section-based numbering unchanged
