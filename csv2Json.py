#!/usr/bin/env python3
"""
Convert grade CSV files to JSON format for Y grade analysis.
Usage: python3 convert_csv_to_json.py input_file.csv [input_file2.csv ...]
"""

import csv
import json
import sys
import os
import re
from collections import defaultdict

# Grade mapping: CSV grade -> JSON field name
GRADE_MAP = {
    'A+': 'aplus',
    'A': 'a',
    'A-': 'aminus',
    'B+': 'bplus',
    'B': 'b',
    'B-': 'bminus',
    'C+': 'cplus',
    'C': 'c',
    'C-': 'cminus',
    'D+': 'dplus',
    'D': 'd',
    'D-': 'dminus',
    'F': 'f',
    'I': 'I',
    'P': 'P',
    'P*': 'P',  # P* counts as P
    'NP': 'NP',
    'NP*': 'NP',  # NP* counts as NP
    'Y': 'Y',
    'RW': 'Y',  # RW counts as Y
}

def parse_term_from_filename(filename):
    """
    Extract term info from filename like '202301 Winter Quarter 2023.csv'
    Returns: (quarter_code, output_filename)
    e.g., ('WQ2023', 'courses_Winter_2023.json')
    """
    basename = os.path.basename(filename)
    # Try to match pattern like "202301 Winter Quarter 2023.csv"
    match = re.search(r'(\d{6})\s+(Winter|Spring|Summer|Fall)\s+Quarter\s+(\d{4})', basename)

    if match:
        term_code = match.group(1)
        quarter_name = match.group(2)
        year = match.group(3)

        # Map quarter name to code
        quarter_codes = {
            'Winter': 'WQ',
            'Spring': 'SQ',
            'Summer': 'SMQ',
            'Fall': 'FQ'
        }

        quarter_code = quarter_codes.get(quarter_name, 'UQ') + year
        output_filename = f"courses_{quarter_name}_{year}.json"

        return quarter_code, output_filename

    # Fallback
    return "UNKNOWN", "courses_output.json"

def parse_csv_to_json(csv_filename):
    """
    Parse CSV file and convert to JSON format.
    Groups by unique course sections and aggregates grade counts.
    """
    quarter_code, output_filename = parse_term_from_filename(csv_filename)

    # Dictionary to hold course data grouped by unique identifier
    courses = defaultdict(lambda: {
        'enrollment': [],
        '_id': '',
        'name': '',
        'crn': [],
        'subj': '',
        'code': '',
        'course_id': '',
        'instructor': '',
        'aplus': 0, 'a': 0, 'aminus': 0,
        'bplus': 0, 'b': 0, 'bminus': 0,
        'cplus': 0, 'c': 0, 'cminus': 0,
        'dplus': 0, 'd': 0, 'dminus': 0,
        'f': 0, 'I': 0, 'P': 0, 'NP': 0, 'Y': 0,
        'quarter': quarter_code,
        'ge_list': [],
        'units': '',
        'seats': '',
        'max_seats': '',
        'description': '',
        'final_exam': '',
        'prereq': ''
    })

    try:
        with open(csv_filename, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)

            for row in reader:
                # Create unique identifier for each course section
                subj = row.get('SUBJ', '').strip()
                crse = row.get('CRSE', '').strip()
                section = row.get('SECTION', '').strip()
                instructor_last = row.get('ILNAME', '').strip()
                instructor_first = row.get('IFNAME', '').strip()

                # Unique key for this course offering
                course_key = f"{subj}_{crse}_{section}_{instructor_last}_{instructor_first}"

                # Initialize course data if first time seeing this course
                if not courses[course_key]['name']:
                    courses[course_key]['name'] = row.get('CRSE_TITLE', '').strip()
                    courses[course_key]['subj'] = subj
                    courses[course_key]['code'] = crse
                    courses[course_key]['course_id'] = f"{subj}{crse}"
                    courses[course_key]['instructor'] = f"{instructor_first} {instructor_last}".strip()
                    courses[course_key]['units'] = row.get('UNITS', '').strip()

                # Get grade and count
                grade = row.get('GRADE', '').strip()
                count = int(row.get('CNTOFGRADE', '0'))

                # Map grade to JSON field and add to count
                if grade in GRADE_MAP:
                    field_name = GRADE_MAP[grade]
                    courses[course_key][field_name] += count

        # Convert to list
        courses_list = list(courses.values())

        # Write to output file
        with open(output_filename, 'w', encoding='utf-8') as f:
            json.dump(courses_list, f, indent=2)

        print(f"✓ Converted {csv_filename} -> {output_filename}")
        print(f"  Found {len(courses_list)} unique course sections")

        # Count total Y grades for verification
        total_y = sum(course['Y'] for course in courses_list)
        courses_with_y = sum(1 for course in courses_list if course['Y'] > 0)
        if total_y > 0:
            print(f"  Total Y grades: {total_y} across {courses_with_y} courses")

        return output_filename

    except FileNotFoundError:
        print(f"Error: File '{csv_filename}' not found")
        return None
    except Exception as e:
        print(f"Error processing {csv_filename}: {e}")
        return None

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 convert_csv_to_json.py <csv_file1> [csv_file2 ...]")
        print("Example: python3 convert_csv_to_json.py '202301 Winter Quarter 2023.csv'")
        sys.exit(1)

    print("CSV to JSON Converter for Grade Data")
    print("=" * 50)
    print()

    output_files = []
    for csv_file in sys.argv[1:]:
        output_file = parse_csv_to_json(csv_file)
        if output_file:
            output_files.append(output_file)
        print()

    print("=" * 50)
    print(f"Conversion complete! Generated {len(output_files)} file(s).")

    if output_files:
        print("\nYou can now run your analysis script:")
        print(f"./y_grade_analysis.sh {' '.join(output_files)}")

if __name__ == "__main__":
    main()
