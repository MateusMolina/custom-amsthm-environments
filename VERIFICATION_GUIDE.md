# Manual Verification Guide

## How to Verify the Fix

This guide explains how to manually verify that the global numbering reset issue has been fixed.

### Prerequisites

- Quarto installed
- Extension installed in the test project

### Test Procedure

1. **Navigate to the test directory:**
   ```bash
   cd tests/global-reset
   ```

2. **First render:**
   ```bash
   quarto render
   ```
   
3. **Check the output:**
   ```bash
   # Open _output/test-global.html in a browser
   # You should see:
   # - Task 1 (First Task)
   # - Task 2 (Second Task)
   # - Task 3 (Third Task)
   ```

4. **Second render (without any changes):**
   ```bash
   quarto render
   ```

5. **Check the output again:**
   ```bash
   # Open _output/test-global.html in a browser
   # You should STILL see:
   # - Task 1 (First Task)  <- Should be 1, not 4!
   # - Task 2 (Second Task)  <- Should be 2, not 5!
   # - Task 3 (Third Task)   <- Should be 3, not 6!
   ```

6. **Third render (to be absolutely sure):**
   ```bash
   quarto render
   ```

7. **Final check:**
   ```bash
   # The numbering should still be 1, 2, 3
   # Not 7, 8, 9!
   ```

### Expected Behavior

**BEFORE the fix:**
- 1st render: Task 1, Task 2, Task 3 ✓
- 2nd render: Task 4, Task 5, Task 6 ✗ (BUG!)
- 3rd render: Task 7, Task 8, Task 9 ✗ (BUG!)

**AFTER the fix:**
- 1st render: Task 1, Task 2, Task 3 ✓
- 2nd render: Task 1, Task 2, Task 3 ✓ (FIXED!)
- 3rd render: Task 1, Task 2, Task 3 ✓ (FIXED!)

### What About Books?

For books, global numbering should still accumulate across chapters:

```bash
cd tests/book
quarto render
```

Check the output:
- Chapter 2: Task 1, Task 2
- Chapter 3: Task 3 (continues from Chapter 2)

This behavior is preserved and should NOT change.

### Clean State

To ensure a clean test, you can delete the state file between renders:

```bash
rm -rf .quarto/
quarto render
```

This is not necessary with the fix, but can help if you want to verify from a completely clean slate.
