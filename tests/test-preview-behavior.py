#!/usr/bin/env python3
"""
Test to verify that global counters don't increment on re-renders.
This simulates the behavior of quarto preview re-rendering individual chapters.

Usage:
  python test-preview-behavior.py
"""

import subprocess
import sys
import re
from pathlib import Path


def run_command(cmd, cwd):
    """Run a command and return success status."""
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=120,
        )
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)


def extract_task_numbers(html_content):
    """Extract task numbers from HTML content."""
    # Look for patterns like <strong>Task 1</strong>, <strong>Task 2</strong>, etc.
    pattern = r'<strong>Task\s+(\d+)'
    matches = re.findall(pattern, html_content)
    return [int(m) for m in matches]


def main():
    # Setup paths
    script_dir = Path(__file__).parent
    book_dir = script_dir / "book"
    output_dir = book_dir / "_output"
    chapter2_html = output_dir / "chapter2.html"
    
    print("=" * 60)
    print("Testing: Global counter stability during re-renders")
    print("=" * 60)
    
    # Step 1: Add extension
    print("\n1. Adding extension to book project...")
    success, stdout, stderr = run_command(
        ["quarto", "add", "../..", "--no-prompt"],
        book_dir
    )
    if not success:
        print(f"❌ Failed to add extension: {stderr}")
        return 1
    print("✓ Extension added")
    
    # Step 2: Render the entire book
    print("\n2. Rendering entire book (first time)...")
    success, stdout, stderr = run_command(
        ["quarto", "render", "--to", "html"],
        book_dir
    )
    if not success:
        print(f"❌ Failed to render book: {stderr}")
        return 1
    print("✓ Book rendered")
    
    # Step 3: Extract task numbers from first render
    if not chapter2_html.exists():
        print(f"❌ Output file not found: {chapter2_html}")
        return 1
    
    with open(chapter2_html, "r", encoding="utf-8") as f:
        first_render_content = f.read()
    
    first_render_tasks = extract_task_numbers(first_render_content)
    print(f"   Task numbers after first render: {first_render_tasks}")
    
    # Step 4: Re-render chapter2 only (simulating quarto preview behavior)
    print("\n3. Re-rendering chapter2.qmd (simulating preview save)...")
    success, stdout, stderr = run_command(
        ["quarto", "render", "chapter2.qmd", "--to", "html"],
        book_dir
    )
    if not success:
        print(f"❌ Failed to re-render chapter2: {stderr}")
        return 1
    print("✓ Chapter2 re-rendered")
    
    # Step 5: Extract task numbers from second render
    with open(chapter2_html, "r", encoding="utf-8") as f:
        second_render_content = f.read()
    
    second_render_tasks = extract_task_numbers(second_render_content)
    print(f"   Task numbers after re-render: {second_render_tasks}")
    
    # Step 6: Verify task numbers haven't changed
    print("\n4. Verifying task numbers are stable...")
    if first_render_tasks == second_render_tasks:
        print(f"✓ Task numbers are stable: {first_render_tasks}")
        print("\n" + "=" * 60)
        print("✅ TEST PASSED")
        print("=" * 60)
        return 0
    else:
        print(f"❌ Task numbers changed!")
        print(f"   Expected: {first_render_tasks}")
        print(f"   Got:      {second_render_tasks}")
        print(f"   This indicates the bug is still present.")
        print("\n" + "=" * 60)
        print("❌ TEST FAILED")
        print("=" * 60)
        return 1


if __name__ == "__main__":
    sys.exit(main())
