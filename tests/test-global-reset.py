#!/usr/bin/env python3
"""
Test script to verify that global numbering resets between renders.

This script:
1. Renders the global-reset test project multiple times
2. Verifies that the counter values are the same each time (starting from 1)
"""

import subprocess
import sys
import re
from pathlib import Path


def extract_task_numbers(html_content):
    """Extract Task numbers from HTML content."""
    # Pattern to match Task numbers in the theorem title
    pattern = r'<span class="theorem-title"><strong>Task (\d+)'
    matches = re.findall(pattern, html_content)
    return [int(m) for m in matches]


def render_project(project_dir):
    """Render the project and return True if successful."""
    print(f"Rendering {project_dir.name}...")
    
    # Add extension
    result = subprocess.run(
        ["quarto", "add", "../..", "--no-prompt"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        timeout=120,
    )
    
    if result.returncode != 0:
        print(f"Error adding extension: {result.stderr}")
        return False
    
    # Render
    result = subprocess.run(
        ["quarto", "render", "--to", "html"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        timeout=120,
    )
    
    if result.returncode != 0:
        print(f"Error rendering: {result.stderr}")
        return False
    
    return True


def main():
    script_dir = Path(__file__).parent
    project_dir = script_dir / "global-reset"
    output_file = project_dir / "_output" / "test-global.html"
    
    if not project_dir.exists():
        print(f"Error: Project directory not found: {project_dir}")
        sys.exit(1)
    
    print("=" * 60)
    print("Testing Global Numbering Reset")
    print("=" * 60)
    
    # Test multiple renders
    num_renders = 3
    all_task_numbers = []
    
    for i in range(num_renders):
        print(f"\n--- Render {i+1}/{num_renders} ---")
        
        if not render_project(project_dir):
            print(f"Failed to render on attempt {i+1}")
            sys.exit(1)
        
        if not output_file.exists():
            print(f"Output file not found: {output_file}")
            sys.exit(1)
        
        with open(output_file, "r") as f:
            html_content = f.read()
        
        task_numbers = extract_task_numbers(html_content)
        print(f"Task numbers found: {task_numbers}")
        all_task_numbers.append(task_numbers)
    
    # Verify all renders produced the same numbering
    print("\n" + "=" * 60)
    print("Verification")
    print("=" * 60)
    
    expected_numbers = [1, 2, 3]
    all_passed = True
    
    for i, task_numbers in enumerate(all_task_numbers):
        if task_numbers == expected_numbers:
            print(f"✓ Render {i+1}: PASS (numbers: {task_numbers})")
        else:
            print(f"✗ Render {i+1}: FAIL (expected {expected_numbers}, got {task_numbers})")
            all_passed = False
    
    print("\n" + "=" * 60)
    if all_passed:
        print("SUCCESS: All renders produced correct numbering")
        print("=" * 60)
        sys.exit(0)
    else:
        print("FAILURE: Numbering did not reset properly between renders")
        print("=" * 60)
        sys.exit(1)


if __name__ == "__main__":
    main()
