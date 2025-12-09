#!/bin/bash

# Usage: ./analyze_y_by_department.sh course_data/*.json

if [ $# -eq 0 ]; then
    echo "Usage: $0 <json_files...>"
    echo "Example: $0 course_data/*.json"
    exit 1
fi

OUTPUT_FILE="y_grade_by_department_postGenAI.txt"
TEMP_DIR=$(mktemp -d)

echo "=================================="
echo "Y GRADE BY DEPARTMENT ANALYSIS"
echo "=================================="
echo ""
echo "Processing files..."

# Combine all files
for file in "$@"; do
    echo "  - $(basename "$file")"
    
    # Check if file is not empty
    file_size=$(jq 'length' "$file" 2>/dev/null || echo "0")
    if [ "$file_size" -gt 0 ]; then
        jq -c '.[] | select(.Y > 0)' "$file" 2>/dev/null >> "$TEMP_DIR/all_y_courses.json" || true
        jq -c '.[]' "$file" 2>/dev/null >> "$TEMP_DIR/all_courses.json" || true
    fi
done

# Check if we have any data
if [ ! -f "$TEMP_DIR/all_y_courses.json" ] || [ ! -s "$TEMP_DIR/all_y_courses.json" ]; then
    echo ""
    echo "ERROR: No courses with Y grades found!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo ""
echo "=================================="
echo "ANALYSIS RESULTS"
echo "=================================="

# Start output file
cat > "$OUTPUT_FILE" << 'EOF'
================================
Y GRADE BY DEPARTMENT ANALYSIS
================================

EOF

# 1. Calculate Y grades per department using the 'subj' field
echo ""
echo "1. Y GRADES BY DEPARTMENT (SORTED BY TOTAL Y GRADES)" | tee -a "$OUTPUT_FILE"
echo "=====================================================" | tee -a "$OUTPUT_FILE"

# Extract department (subj) and Y grades
jq -r '"\(.subj)|\(.Y)"' "$TEMP_DIR/all_y_courses.json" 2>/dev/null | \
awk -F'|' '{
    dept = $1
    y_count = $2
    dept_totals[dept] += y_count
    dept_courses[dept] += 1
} END {
    for (dept in dept_totals) {
        print dept_totals[dept] "|" dept_courses[dept] "|" dept
    }
}' | sort -t'|' -k1 -nr > "$TEMP_DIR/dept_summary.txt"

# Display results
awk -F'|' 'BEGIN {
    count=1
    printf "%-5s %-10s %10s %10s\n", "Rank", "Department", "Y Grades", "Courses"
    printf "%-5s %-10s %10s %10s\n", "----", "----------", "--------", "-------"
} {
    printf "%-5d %-10s %10d %10d\n", count++, $3, $1, $2
}' "$TEMP_DIR/dept_summary.txt" | tee -a "$OUTPUT_FILE"

echo ""
echo "2. AVERAGE Y GRADES PER COURSE BY DEPARTMENT" | tee -a "$OUTPUT_FILE"
echo "=============================================" | tee -a "$OUTPUT_FILE"

awk -F'|' '{
    dept = $3
    y_total = $1
    course_count = $2
    avg = y_total / course_count
    print avg "|" dept "|" y_total "|" course_count
}' "$TEMP_DIR/dept_summary.txt" | sort -t'|' -k1 -nr > "$TEMP_DIR/dept_avg.txt"

awk -F'|' 'BEGIN {
    count=1
    printf "%-5s %-10s %8s %10s %10s\n", "Rank", "Department", "Avg Y", "Total Y", "Courses"
    printf "%-5s %-10s %8s %10s %10s\n", "----", "----------", "------", "-------", "-------"
} {
    printf "%-5d %-10s %8.2f %10d %10d\n", count++, $2, $1, $3, $4
}' "$TEMP_DIR/dept_avg.txt" | tee -a "$OUTPUT_FILE"

echo ""
echo "3. DEPARTMENTS WITH HIGHEST Y GRADE RATES" | tee -a "$OUTPUT_FILE"
echo "==========================================" | tee -a "$OUTPUT_FILE"
echo "(Showing departments with at least 5 courses)" | tee -a "$OUTPUT_FILE"
echo ""

awk -F'|' '{
    if ($4 >= 5) {
        print $0
    }
}' "$TEMP_DIR/dept_avg.txt" | head -15 | \
awk -F'|' 'BEGIN {
    count=1
    printf "%-5s %-10s %8s %10s %10s\n", "Rank", "Department", "Avg Y", "Total Y", "Courses"
    printf "%-5s %-10s %8s %10s %10s\n", "----", "----------", "------", "-------", "-------"
} {
    printf "%-5d %-10s %8.2f %10d %10d\n", count++, $2, $1, $3, $4
}' | tee -a "$OUTPUT_FILE"

echo ""
echo "4. TOTAL COURSES BY DEPARTMENT (WITH AND WITHOUT Y GRADES)" | tee -a "$OUTPUT_FILE"
echo "===========================================================" | tee -a "$OUTPUT_FILE"

# Calculate total courses per department
jq -r '.subj' "$TEMP_DIR/all_courses.json" 2>/dev/null | sort | uniq -c | \
awk '{print $2 "|" $1}' > "$TEMP_DIR/dept_all_courses.txt"

# Join with Y grade data
join -t'|' -a1 -e0 -o 1.3,1.1,1.2,2.2 \
    <(sort -t'|' -k3 "$TEMP_DIR/dept_summary.txt") \
    <(sort -t'|' -k1 "$TEMP_DIR/dept_all_courses.txt") 2>/dev/null | \
awk -F'|' '{
    dept = $1
    y_total = $2
    y_courses = $3
    total_courses = ($4 == "" || $4 == "0") ? $3 : $4
    pct = (y_courses / total_courses) * 100
    print pct "|" dept "|" y_total "|" y_courses "|" total_courses
}' | sort -t'|' -k1 -nr | \
awk -F'|' 'BEGIN {
    printf "%-10s %10s %12s %12s %8s\n", "Department", "Y Grades", "Y Courses", "All Courses", "% w/ Y"
    printf "%-10s %10s %12s %12s %8s\n", "----------", "--------", "---------", "-----------", "------"
} {
    printf "%-10s %10d %12d %12d %7.1f%%\n", $2, $3, $4, $5, $1
}' | tee -a "$OUTPUT_FILE"

echo ""
echo "5. SUMMARY STATISTICS" | tee -a "$OUTPUT_FILE"
echo "=====================" | tee -a "$OUTPUT_FILE"

total_y_grades=$(awk -F'|' '{sum+=$1} END {print sum}' "$TEMP_DIR/dept_summary.txt")
total_depts=$(wc -l < "$TEMP_DIR/dept_summary.txt")
total_courses_with_y=$(wc -l < "$TEMP_DIR/all_y_courses.json")
total_all_courses=$(wc -l < "$TEMP_DIR/all_courses.json")

echo "Total Y grades across all departments: $total_y_grades" | tee -a "$OUTPUT_FILE"
echo "Total departments with Y grades: $total_depts" | tee -a "$OUTPUT_FILE"
echo "Total courses with Y grades: $total_courses_with_y" | tee -a "$OUTPUT_FILE"
echo "Total courses overall: $total_all_courses" | tee -a "$OUTPUT_FILE"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=================================="
echo "Analysis complete!"
echo "Full report saved to: $OUTPUT_FILE"
echo "=================================="
