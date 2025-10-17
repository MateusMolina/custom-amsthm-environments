# Demonstration: Global Counter Fix

This document demonstrates the fix for the global counter increment issue.

## Before the Fix

When using `numbering-style: global` in Quarto Books, the following would happen:

### First Render
```
Book rendered:
- Chapter 2: Task 1, Task 2
- Chapter 3: Task 3
```

### After Editing chapter2.qmd (quarto preview save)
```
❌ BUG: Counters increment again for the same IDs
- Chapter 2: Task 4, Task 5  (should be Task 1, Task 2)
- Chapter 3: Task 3
```

### After Another Edit
```
❌ BUG: Counters keep growing
- Chapter 2: Task 7, Task 8  (should be Task 1, Task 2)
- Chapter 3: Task 3
```

## After the Fix

### First Render
```
Book rendered:
- Chapter 2: Task 1, Task 2
- Chapter 3: Task 3
```

### After Editing chapter2.qmd (quarto preview save)
```
✓ FIX: Numbers remain stable
- Chapter 2: Task 1, Task 2  (correct!)
- Chapter 3: Task 3
```

### After Another Edit
```
✓ FIX: Numbers still stable
- Chapter 2: Task 1, Task 2  (correct!)
- Chapter 3: Task 3
```

### Adding a New Task to chapter2.qmd
```
✓ FIX: New task gets next number
- Chapter 2: Task 1, Task 2, Task 4  (Task 4 is next after Task 3)
- Chapter 3: Task 3
```

## How It Works

The fix checks if an ID has already been numbered:

```lua
if current_counters[key][id] then
  -- ID already numbered, reuse the number
  current_number = current_counters[key][id]
else
  -- New ID, increment counter
  amsthm_counters[key] = amsthm_counters[key] + 1
  current_number = tostring(amsthm_counters[key])
end
```

This ensures:
1. ✓ Existing IDs keep their numbers across re-renders
2. ✓ New IDs get the next available number
3. ✓ Global numbering remains consistent throughout the book
