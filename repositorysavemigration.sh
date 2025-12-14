#!/bin/bash

# Repository Save Method Migration Script - Step-by-Step Approach
# Migrates save() method calls to saveAll() for collections in Spring Data JPA repositories
# In Java 21/Spring Boot 3.x, save() is only for single entities, saveAll() for collections

# Define versions to update to
JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
TEST_PATH="./src/test/java"

echo "Starting Repository save() method migration for Java 21..."
echo "Following 7-step process:"
echo "1. Find repository classes"
echo "2. Find their declaration in classes (autowired/injected/constructor injection)"
echo "3. Find statements with save method calls"
echo "4. Identify argument in save method"
echo "5. Check argument type in that method"
echo "6. If list type, convert save to saveAll"
echo "7. Repeat for every save method"
echo ""

# Function to find repository variables used in save calls
find_repository_declarations() {
    local file="$1"
    local repo_declarations=$(mktemp)
    
    # Extract repository variables from save method calls in this file
    # Look for patterns like: someRepo.save(...)
    grep -oE "[a-zA-Z_][a-zA-Z0-9_]*\.save\(" "$file" 2>/dev/null | while read -r save_call; do
        repo_var=$(echo "$save_call" | sed -E 's/([a-zA-Z_][a-zA-Z0-9_]*)\.save\(.*/\1/')
        if [ -n "$repo_var" ]; then
            echo "$repo_var" >> "$repo_declarations"
        fi
    done
    
    # Remove duplicates and return
    if [ -f "$repo_declarations" ]; then
        sort "$repo_declarations" | uniq > "${repo_declarations}.tmp"
        mv "${repo_declarations}.tmp" "$repo_declarations"
    fi
    
    echo "$repo_declarations"
}

# Function to find and process save method calls
find_save_method_calls() {
    local file="$1"
    local repo_declarations_file="$2"
    
    echo "Step 3: Finding save method calls in $file"
    
    # Process each save call
    grep -n "\.save(" "$file" 2>/dev/null | while read -r save_line; do
        line_num=$(echo "$save_line" | cut -d: -f1)
        save_content=$(echo "$save_line" | cut -d: -f2-)
        
        # Extract repository variable and argument
        repo_var=$(echo "$save_content" | sed -E 's/^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*).*/\1/' 2>/dev/null)
        save_arg=$(echo "$save_content" | sed -E 's/.*\.save\(([^)]+)\).*/\1/' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        
        if [ -n "$repo_var" ] && [ -n "$save_arg" ]; then
            # Check if this repository variable is in our declarations
            if grep -q "^$repo_var$" "$repo_declarations_file" 2>/dev/null; then
                echo "    Line $line_num: $repo_var.save($save_arg)"
                check_argument_type_and_convert "$file" "$line_num" "$repo_var" "$save_arg"
            fi
        fi
    done
}

# Function to check argument type and convert if needed - Enhanced with 100-line lookback
check_argument_type_and_convert() {
    local file="$1"
    local line_num="$2"
    local repo_var="$3"
    local save_arg="$4"
    
    echo "Step 5: Checking argument type for $save_arg"
    
    # Look at 100 lines before the save call to find variable declarations
    start_line=$((line_num - 100))
    if [ $start_line -lt 1 ]; then
        start_line=1
    fi
    
    echo "    Analyzing lines $start_line to $line_num for variable type"
    
    # Extract the variable name (remove method calls like .values())
    var_name=$(echo "$save_arg" | sed 's/\..*$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    # Check if the argument is a collection type
    is_collection=false
    
    # Check 1: Direct collection indicators in argument (method calls, explicit types)
    if echo "$save_arg" | grep -qE "(\.values\(\)|\.keySet\(\)|\.toList\(\)|\.stream\(\)\.collect)"; then
        is_collection=true
        echo "    ✓ Collection detected: Method call returning collection ($save_arg)"
    
    # Check 2: Variable name contains collection indicators  
    elif echo "$save_arg" | grep -qiE "(list|collection|set|array)"; then
        is_collection=true
        echo "    ✓ Collection detected: Variable name suggests collection ($save_arg)"
    
    # Check 3: Look for variable declaration by searching BACKWARDS from save call line
    else
        # Search backwards from current line to find the most recent declaration of this variable
        found_declaration=""
        current_search_line=$line_num
        
        while [ $current_search_line -ge 1 ] && [ -z "$found_declaration" ]; do
            line_content=$(sed -n "${current_search_line}p" "$file" 2>/dev/null)
            
            # Check if this line declares our variable
            if echo "$line_content" | grep -qE "[[:space:]]+$var_name[[:space:]]*[=;]"; then
                found_declaration="$line_content"
                break
            fi
            current_search_line=$((current_search_line - 1))
        done
        
        if [ -n "$found_declaration" ]; then
            echo "    Most recent declaration: $found_declaration"
            
            # Check if the found declaration is a collection type
            if echo "$found_declaration" | grep -qE "(List|ArrayList|LinkedList|Set|HashSet|LinkedHashSet|TreeSet|Collection|Vector|Iterable)<[^>]*>[[:space:]]+$var_name[[:space:]]*[=;]"; then
                is_collection=true
                echo "    ✓ Collection detected: Variable '$var_name' declared as collection/iterable type"
            
            # Check for assignment to collection constructors: varName = new ArrayList<>()
            elif echo "$found_declaration" | grep -qE "$var_name[[:space:]]*=[[:space:]]*new[[:space:]]+(List|ArrayList|LinkedList|Set|HashSet|LinkedHashSet|TreeSet|Collection|Vector)"; then
                is_collection=true
                echo "    ✓ Collection detected: Variable '$var_name' assigned collection constructor"
        
        # Check 4: Look for collection assignment or initialization
        elif echo "$context_content" | grep -qE "$var_name.*=.*(Arrays\.asList|Collections\.|Stream\.|\.collect\(|\.toList\(|\.toSet\()"; then
            is_collection=true
            echo "    ✓ Collection detected: Variable '$var_name' assigned collection value"
        
            else
                echo "    ✗ Single entity detected: Variable '$var_name' is not a collection type"
            fi
        else
            echo "    ✗ Single entity detected: No declaration found for variable '$var_name'"
        fi
    fi
    
    # Step 6: Convert only if collection type detected
    if [ "$is_collection" = true ]; then
        echo "Step 6: Converting $repo_var.save($save_arg) to $repo_var.saveAll($save_arg)"
        
        # Create backup
        cp "$file" "${file}.bak"
        
        # Perform the conversion
        sed -i.tmp "${line_num}s/\.save(/\.saveAll(/g" "$file"
        
        # Clean up temporary files immediately
        rm -f "${file}.bak" "${file}.tmp"
        
        echo "    ✅ CONVERTED to saveAll()"
    else
        echo "Step 6: Keeping $repo_var.save($save_arg) - single entity detected"
    fi
}

# Main function to process a single file
process_file() {
    local file="$1"
    echo ""
    echo "=========================================="
    echo "Processing file: $file"
    echo "=========================================="
    
    # Step 2: Find repository declarations
    repo_declarations_file=$(find_repository_declarations "$file")
    
    if [ ! -s "$repo_declarations_file" ]; then
        echo "No repository declarations found - skipping file"
        rm -f "$repo_declarations_file"
        return
    fi
    
    echo "Found repositories:"
    while read -r repo; do
        echo "  - $repo"
    done < "$repo_declarations_file"
    
    # Step 3, 4, 5, 6: Find and process save method calls
    find_save_method_calls "$file" "$repo_declarations_file"
    
    # Clean up
    rm -f "$repo_declarations_file"
}

# Main execution
echo ""

# Check if a specific file was provided as argument
if [ $# -gt 0 ]; then
    if [ -f "$1" ]; then
        echo "Processing single file provided as argument: $1"
        process_file "$1"
        exit 0
    else
        echo "Error: File '$1' not found!"
        exit 1
    fi
fi

# Check if directories exist
echo "Checking directories:"
echo "  CLASS_PATH: $CLASS_PATH"
if [ -d "$CLASS_PATH" ]; then
    echo "    ✓ Exists"
    echo "    Files: $(find "$CLASS_PATH" -name "*.java" 2>/dev/null | wc -l | tr -d ' ') Java files found"
else
    echo "    ✗ Does not exist"
fi

echo "  TEST_PATH: $TEST_PATH"  
if [ -d "$TEST_PATH" ]; then
    echo "    ✓ Exists"
    echo "    Files: $(find "$TEST_PATH" -name "*.java" 2>/dev/null | wc -l | tr -d ' ') Java files found"
else
    echo "    ✗ Does not exist"
fi

# Step 1: Find all repository classes and their usage files, then process them
echo "Step 1: Discovering repository classes and their usage..."

# Get all repository class names (without .java extension)
repo_classes=$(find "$CLASS_PATH" "$TEST_PATH" -name "*.java" -type f -exec grep -l "@Repository" {} \; 2>/dev/null | xargs basename -s .java 2>/dev/null)

if [ -z "$repo_classes" ]; then
    echo "No repository classes found with @Repository annotation"
    exit 0
fi

echo "Found repository classes:"
for repo in $repo_classes; do
    echo "  - $repo"
done
echo ""

# For each repository, find files that use it (excluding the repository interface itself)
processed_files=""
for repo in $repo_classes; do
    echo "Processing repository: $repo"
    
    # Find files that reference this repository (excluding the repository interface file)
    usage_files=$(find "$CLASS_PATH" "$TEST_PATH" -name "*.java" -type f -exec grep -l "$repo" {} \; 2>/dev/null | grep -v "/$repo\.java$")
    
    for file in $usage_files; do
        # Skip if already processed
        if echo "$processed_files" | grep -q "$file"; then
            continue
        fi
        
        # Check if file has save method calls
        save_calls=$(grep -n "\.save(" "$file" 2>/dev/null)
        if [ -n "$save_calls" ]; then
            echo "  Found save() calls in: $file"
            process_file "$file"
            processed_files="$processed_files $file"
        fi
    done
done

echo ""
echo "Repository save() method migration completed!"
echo "Summary of files processed:"
for file in $processed_files; do
    echo "  ✓ $file"
done

echo ""
echo "Cleaning up temporary files..."
# Remove any remaining .tmp files created by sed
find "$CLASS_PATH" "$TEST_PATH" -name "*.tmp" -type f -delete 2>/dev/null || true

# Remove any remaining .bak files 
find "$CLASS_PATH" "$TEST_PATH" -name "*.bak" -type f -delete 2>/dev/null || true

# Clean up any temporary files in current directory
rm -f /tmp/repo_declarations_* 2>/dev/null || true

echo "Cleanup completed!"
