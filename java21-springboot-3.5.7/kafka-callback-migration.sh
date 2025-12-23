#!/bin/bash

# Kafka Producer Callback Migration Script  
# Migrates ListenableFuture.addCallback() to CompletableFuture.whenComplete()
# SINGLE OCCURRENCE MODE: Converts only ONE addCallback per run

process_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo "Error: File '$file' not found!"
        exit 1
    fi
    
    echo "Processing file: $file"
    
    # STEP 1: Find the FIRST .addCallback() by line number and extract its variable
    local target_info=$(awk '
        BEGIN { 
            future_vars[""] = 0
            delete future_vars[""]
            first_callback_line = 0
            first_callback_var = ""
        }
        
        # Collect all ListenableFuture<SendResult> variable names with line numbers
        /ListenableFuture<SendResult<.*>>/ {
            var_line = $0
            gsub(/.*ListenableFuture<SendResult<[^>]*>>[[:space:]]*/, "", var_line)
            gsub(/[[:space:]]*[=;].*/, "", var_line)
            gsub(/[[:space:]]*$/, "", var_line)
            if (var_line != "") {
                future_vars[var_line] = NR
            }
        }
        
        # Find .addCallback() calls and track the first one by line number
        /\.addCallback\(/ {
            if (first_callback_line == 0) {
                # Extract variable name before .addCallback
                callback_line = $0
                if (match(callback_line, /[a-zA-Z_][a-zA-Z0-9_]*\.addCallback\(/)) {
                    var_part = callback_line
                    sub(/\.addCallback\(.*/, "", var_part)
                    gsub(/^[[:space:]]*/, "", var_part)
                    gsub(/.*[[:space:]]/, "", var_part)
                    
                    # Check if this variable is in our future_vars
                    if (var_part in future_vars) {
                        first_callback_line = NR
                        first_callback_var = var_part
                    }
                }
            }
        }
        
        END {
            if (first_callback_var != "") {
                print first_callback_var ":" first_callback_line
            }
        }
    ' "$file")
    
    if [ -z "$target_info" ]; then
        echo "  ℹ️  No ListenableFuture<SendResult> with .addCallback() found"
        exit 0
    fi
    
    local target_var=$(echo "$target_info" | cut -d':' -f1)
    local target_line=$(echo "$target_info" | cut -d':' -f2)
    
    echo "  → Found first addCallback on line $target_line for variable: $target_var"
    
    # STEP 2: Process the file and convert only this specific addCallback occurrence
    local temp_file=$(mktemp)
    
    awk -v target_var="$target_var" -v target_line="$target_line" '
        BEGIN {
            found_target_declaration = 0
            processing_callback = 0
        }
        
        # Convert the ListenableFuture type to CompletableFuture for target variable
        /ListenableFuture<SendResult<.*>>/ && match($0, target_var) && !found_target_declaration {
            found_target_declaration = 1
            gsub(/ListenableFuture<SendResult</, "CompletableFuture<SendResult<", $0)
            print "  → Converting type declaration" > "/dev/stderr"
            print $0
            next
        }
        
        # Look for .addCallback( on target variable at the specific line number
        !processing_callback {
            callback_pattern = target_var "\\.addCallback\\("
            if (NR == target_line && match($0, callback_pattern)) {
                print "  → Converting addCallback to whenComplete on line " NR > "/dev/stderr"
                processing_callback = 1
                # Extract indentation from the original line
                original_indent = $0
                sub(/[^[:space:]].*/, "", original_indent)
                process_callback(target_var, original_indent)
                next
            }
        }
        
        # Print lines that are not being processed
        !processing_callback {
            print $0
        }
        
        function process_callback(var_name, indent) {
            success_param_name = ""
            failure_param_name = ""
            success_body = ""
            failure_body = ""
            in_success_method = 0
            in_failure_method = 0
            success_brace_count = 0
            failure_brace_count = 0
            callback_depth = 0
            
            # Read subsequent lines to find callback pattern
            while ((getline next_line) > 0) {
                
                # Track overall callback depth to find the end
                line_copy = next_line
                open_braces = gsub(/\{/, "&", line_copy)
                close_braces = gsub(/\}/, "&", line_copy)
                callback_depth += (open_braces - close_braces)
                
                # Check for end of entire addCallback (closing });) at depth -1
                if (callback_depth == -1 && next_line ~ /^[[:space:]]*\}\);[[:space:]]*$/) {
                    # INSERT the whenComplete transformation with proper indentation
                    print indent var_name ".whenComplete((" success_param_name ", " failure_param_name ") -> {"
                    print indent "    if (" failure_param_name " == null) {"
                    printf "%s", success_body
                    print indent "    } else {"
                    printf "%s", failure_body
                    print indent "    }"
                    print indent "});"
                    
                    processing_callback = 0
                    return
                }
                
                # Skip the "new ListenableFutureCallback" line ONLY at top level (not inside method bodies)
                if (!in_success_method && !in_failure_method && (next_line ~ /new.*FutureCallback/ || next_line ~ /new.*ListenableFutureCallback/)) {
                    continue
                }
                
                # Skip @Override and empty lines at top level (before methods start)
                if (!in_success_method && !in_failure_method && (next_line ~ /^[[:space:]]*@Override[[:space:]]*$/ || next_line ~ /^[[:space:]]*$/)) {
                    continue
                }
                
                # DETECT Interface syntax: onSuccess method
                if (next_line ~ /public void onSuccess\(/ && !in_success_method && !in_failure_method) {
                    # Extract parameter name
                    success_param_line = next_line
                    match(success_param_line, /onSuccess\([^)]*[[:space:]]([a-zA-Z_][a-zA-Z0-9_]*)\)/)
                    if (RSTART > 0) {
                        full_match = substr(success_param_line, RSTART, RLENGTH)
                        gsub(/.*[[:space:]]/, "", full_match)
                        gsub(/\).*/, "", full_match)
                        success_param_name = full_match
                    } else {
                        success_param_name = "result"
                    }
                    
                    in_success_method = 1
                    success_brace_count = 0
                    success_body = ""
                    continue
                }
                
                # DETECT Interface syntax: onFailure method
                if (next_line ~ /public void onFailure\(/ && !in_success_method && !in_failure_method) {
                    # Extract parameter name
                    failure_param_line = next_line
                    match(failure_param_line, /onFailure\([^)]*[[:space:]]([a-zA-Z_][a-zA-Z0-9_]*)\)/)
                    if (RSTART > 0) {
                        full_match = substr(failure_param_line, RSTART, RLENGTH)
                        gsub(/.*[[:space:]]/, "", full_match)
                        gsub(/\).*/, "", full_match)
                        failure_param_name = full_match
                    } else {
                        failure_param_name = "ex"
                    }
                    
                    in_failure_method = 1
                    failure_brace_count = 0
                    failure_body = ""
                    continue
                }
                
                # Extract success body - preserve EVERYTHING including nested callbacks
                if (in_success_method) {
                    line_copy_for_count = next_line
                    open_for_count = gsub(/\{/, "&", line_copy_for_count)
                    close_for_count = gsub(/\}/, "&", line_copy_for_count)
                    success_brace_count += (open_for_count - close_for_count)
                    
                    # Check if this is the closing brace of onSuccess method
                    if (success_brace_count < 0 && next_line ~ /^[[:space:]]*\}[[:space:]]*$/) {
                        in_success_method = 0
                        continue
                    } else {
                        # Add EVERYTHING to success body - no exceptions
                        success_body = success_body next_line "\n"
                        continue
                    }
                }
                
                # Extract failure body - preserve EVERYTHING including nested callbacks
                if (in_failure_method) {
                    line_copy_for_count = next_line
                    open_for_count = gsub(/\{/, "&", line_copy_for_count)
                    close_for_count = gsub(/\}/, "&", line_copy_for_count)
                    failure_brace_count += (open_for_count - close_for_count)
                    
                    # Check if this is the closing brace of onFailure method
                    if (failure_brace_count < 0 && next_line ~ /^[[:space:]]*\}[[:space:]]*$/) {
                        in_failure_method = 0
                        continue
                    } else {
                        # Add EVERYTHING to failure body - no exceptions
                        failure_body = failure_body next_line "\n"
                        continue
                    }
                }
            }
        }
    ' "$file" > "$temp_file"
    
    # Replace original file
    mv "$temp_file" "$file"
    
    echo "  ✅ Conversion completed for variable: $target_var"
}

# Main execution
echo "Starting Kafka callback migration (SINGLE OCCURRENCE MODE)..."
echo ""

if [ $# -gt 0 ]; then
    if [ -f "$1" ]; then
        process_file "$1"
        exit 0
    else
        echo "Error: File '$1' not found!"
        exit 1
    fi
fi

echo "Error: Please provide a file path as argument"
exit 1
