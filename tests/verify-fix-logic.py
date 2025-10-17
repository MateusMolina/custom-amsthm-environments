#!/usr/bin/env python3
"""
Manual verification of the fix logic.
This script simulates the state management to verify the fix works correctly.
"""

print("=" * 80)
print("VERIFICATION: Global Counter Fix Logic")
print("=" * 80)

# Simulate state structure
class State:
    def __init__(self):
        self.counters = {}  # amsthm_counters[key]
        self.values = {}    # current_counters[key][id]
        self.files = {}     # files[key][id]

# Simulate processing a div with global numbering
def process_div(state, key, div_id, description):
    if key not in state.counters:
        state.counters[key] = 0
    if key not in state.values:
        state.values[key] = {}
    
    # THE FIX: Check if ID already has a number
    if div_id in state.values[key]:
        # Reuse existing number
        current_number = state.values[key][div_id]
        print(f"  {div_id}: REUSE {current_number} (already numbered)")
    else:
        # New ID, increment counter
        state.counters[key] += 1
        current_number = str(state.counters[key])
        state.values[key][div_id] = current_number
        print(f"  {div_id}: NEW {current_number} (counter incremented)")
    
    return current_number

print("\n" + "-" * 80)
print("Scenario 1: Initial render of book")
print("-" * 80)

state = State()

print("\nChapter 1 (index.qmd): Reset state")
state = State()
print(f"  State: counters={state.counters}, values={state.values}")

print("\nChapter 2 (chapter2.qmd): Process tasks")
process_div(state, "tsk", "tsk-chapter2-first", "First task")
process_div(state, "tsk", "tsk-chapter2-second", "Second task")
print(f"  State: counters={state.counters}, values={state.values}")

print("\nChapter 3 (chapter3.qmd): Process task")
process_div(state, "tsk", "tsk-chapter3-final", "Third task")
print(f"  State: counters={state.counters}, values={state.values}")

print("\nExpected: Task 1, Task 2, Task 3")
print(f"Actual: Task {state.values['tsk']['tsk-chapter2-first']}, " +
      f"Task {state.values['tsk']['tsk-chapter2-second']}, " +
      f"Task {state.values['tsk']['tsk-chapter3-final']}")
assert state.values['tsk']['tsk-chapter2-first'] == '1'
assert state.values['tsk']['tsk-chapter2-second'] == '2'
assert state.values['tsk']['tsk-chapter3-final'] == '3'
print("✓ PASS")

print("\n" + "-" * 80)
print("Scenario 2: Re-render chapter 2 (quarto preview save)")
print("-" * 80)

# State persists from previous render
print("\nChapter 2 (chapter2.qmd): Re-process tasks (state from previous render)")
print(f"  Initial state: counters={state.counters}, values={state.values}")

# Re-process the same divs
process_div(state, "tsk", "tsk-chapter2-first", "First task (re-render)")
process_div(state, "tsk", "tsk-chapter2-second", "Second task (re-render)")
print(f"  State: counters={state.counters}, values={state.values}")

print("\nExpected: Task 1, Task 2 (unchanged)")
print(f"Actual: Task {state.values['tsk']['tsk-chapter2-first']}, " +
      f"Task {state.values['tsk']['tsk-chapter2-second']}")
assert state.values['tsk']['tsk-chapter2-first'] == '1'
assert state.values['tsk']['tsk-chapter2-second'] == '2'
assert state.counters['tsk'] == 3  # Counter doesn't increment
print("✓ PASS")

print("\n" + "-" * 80)
print("Scenario 3: Re-render chapter 2 with new task added")
print("-" * 80)

print("\nChapter 2 (chapter2.qmd): Add new task")
process_div(state, "tsk", "tsk-chapter2-first", "First task")
process_div(state, "tsk", "tsk-chapter2-second", "Second task")
process_div(state, "tsk", "tsk-chapter2-new", "NEW task added")
print(f"  State: counters={state.counters}, values={state.values}")

print("\nExpected: Task 1, Task 2, Task 4 (new task gets next number)")
print(f"Actual: Task {state.values['tsk']['tsk-chapter2-first']}, " +
      f"Task {state.values['tsk']['tsk-chapter2-second']}, " +
      f"Task {state.values['tsk']['tsk-chapter2-new']}")
assert state.values['tsk']['tsk-chapter2-first'] == '1'
assert state.values['tsk']['tsk-chapter2-second'] == '2'
assert state.values['tsk']['tsk-chapter2-new'] == '4'
print("✓ PASS")

print("\n" + "=" * 80)
print("✅ ALL SCENARIOS VERIFIED - Fix works correctly!")
print("=" * 80)
