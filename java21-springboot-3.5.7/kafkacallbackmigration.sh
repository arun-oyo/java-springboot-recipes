#!/bin/bash

# Kafka Producer Callback Migration Script
# Migrates ListenableFuture.addCallback() to CompletableFuture.whenComplete()

CLASS_PATH="./src/main/java"
TEST_PATH="./src/test/java"

echo "Starting Kafka producer callback migration..."

# Import changes - ListenableFuture to CompletableFuture
echo "Changing ListenableFuture imports to CompletableFuture..."
find "$CLASS_PATH" "$TEST_PATH" -type f -name "*.java" -exec grep -l "ListenableFuture" {} \; | while read -r file; do
    sed -i '' \
        -e 's/import org\.springframework\.util\.concurrent\.ListenableFuture/import java.util.concurrent.CompletableFuture/g' \
        -e 's/ListenableFuture/CompletableFuture/g' \
        "$file"
    echo "Updated imports in: $(basename "$file")"
done

# Remove ListenableFutureCallback imports
echo "Removing ListenableFutureCallback imports..."
find "$CLASS_PATH" "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e '/import org\.springframework\.util\.concurrent\.ListenableFutureCallback/d' \
    -e '/import.*ListenableFutureCallback/d' \
    {} +

# Transform .addCallback() to .whenComplete()
echo "Transforming .addCallback() to .whenComplete()..."
find "$CLASS_PATH" "$TEST_PATH" -type f -name "*.java" -exec grep -l "\.addCallback" {} \; | while read -r file; do
    echo "Processing callbacks in: $(basename "$file")"
    
    # Process callbacks serially using awk to extract and rebuild one callback at a time
    temp_file="${file}.processing"
    cp "$file" "$temp_file"
    
    # Keep processing until no more .addCallback patterns exist
    while grep -q "\.addCallback" "$temp_file"; do
        awk '
        BEGIN { 
            in_callback = 0
            callback_depth = 0
            success_content = ""
            failure_content = ""
            current_method = ""
            method_brace_count = 0
            found_callback = 0
        }
        
        # Find first .addCallback and start processing
        !found_callback && /\.addCallback\(/ {
            # Replace with whenComplete
            gsub(/\.addCallback\(.*/, ".whenComplete((result, ex) -> {")
            print $0
            in_callback = 1
            found_callback = 1
            next
        }
        
        # Skip callback instantiation and @Override
        in_callback && (/new.*FutureCallback/ || /^[[:space:]]*@Override[[:space:]]*$/) {
            next  
        }
        
        # Detect onSuccess method start
        in_callback && !current_method && /public void onSuccess/ {
            current_method = "success"
            method_brace_count = 0
            success_content = ""
            next
        }
        
        # Detect onFailure method start  
        in_callback && !current_method && /public void onFailure/ {
            current_method = "failure" 
            method_brace_count = 0
            failure_content = ""
            next
        }
        
        # Capture method content
        in_callback && current_method {
            # Count braces to find method end
            line = $0
            open_count = gsub(/{/, "{", line)
            close_count = gsub(/}/, "}", line) 
            method_brace_count += (open_count - close_count)
            
            # If this is the method closing brace
            if (method_brace_count <= -1 && /^[[:space:]]*}[[:space:]]*$/) {
                current_method = ""
                next
            } else {
                # Add content to appropriate method body
                if (current_method == "success") {
                    success_content = success_content $0 "\n"
                } else if (current_method == "failure") {
                    failure_content = failure_content $0 "\n"  
                }
            }
            next
        }
        
        # End of callback - reconstruct with if-else
        in_callback && /^[[:space:]]*}\);[[:space:]]*$/ {
            print "                if (ex == null) {"
            printf "%s", success_content
            print "                } else {"
            printf "%s", failure_content
            print "                }"
            print "            });"
            in_callback = 0
            next
        }
        
        # Print non-callback lines normally
        !in_callback || !found_callback {
            print $0
        }
        ' "$temp_file" > "${temp_file}.tmp"
        
        mv "${temp_file}.tmp" "$temp_file"
    done
    
    # Replace original file with processed version
    mv "$temp_file" "$file"
    
    # Remove any remaining duplicate }); patterns
    sed -i '' 's/});[[:space:]]*});/});/g' "$file"
    
    # Ensure class closing brace exists (safety check)
    if ! tail -1 "$file" | grep -q "^}[[:space:]]*$"; then
        echo "}" >> "$file"
        echo "    Added missing class closing brace to: $(basename "$file")"
    fi
done

# Clean up any remaining callback artifacts
# Fix orphaned callback methods (when nested callbacks weren't transformed properly)
echo "Fixing orphaned callback method signatures..."
find "$CLASS_PATH" "$TEST_PATH" -type f -name "*.java" -exec grep -l "public void onSuccess.*SendResult" {} \; | while read -r file; do
    echo "Fixing orphaned methods in: $(basename "$file")"
    
    # Use awk to detect and fix orphaned callback methods
    awk '
    BEGIN {
        in_orphaned_callback = 0
        success_content = ""
        failure_content = ""
        current_method = ""
        method_brace_count = 0
        retry_future_line = ""
    }
    
    # Detect CompletableFuture line followed by orphaned methods
    /CompletableFuture.*publishRetryFuture.*kafkaTemplate\.send/ {
        retry_future_line = $0
        print $0
        next
    }
    
    # Detect orphaned onSuccess method (not inside a proper callback)
    !in_orphaned_callback && /^[[:space:]]*public void onSuccess.*SendResult/ {
        in_orphaned_callback = 1
        current_method = "success"
        method_brace_count = 0
        success_content = ""
        next
    }
    
    # Capture method content when in orphaned callback
    in_orphaned_callback && current_method {
        line = $0
        open_count = gsub(/{/, "{", line)
        close_count = gsub(/}/, "}", line)
        method_brace_count += (open_count - close_count)
        
        # Check if this is method closing brace
        if (method_brace_count <= -1 && /^[[:space:]]*}[[:space:]]*$/) {
            if (current_method == "success") {
                current_method = ""
                # Look for onFailure method next
                next
            } else if (current_method == "failure") {
                # End of failure method - reconstruct the callback
                print "                    publishRetryFuture.whenComplete((result, ex) -> {"
                print "                        if (ex == null) {"
                printf "%s", success_content
                print "                        } else {"
                printf "%s", failure_content
                print "                        }"
                print "                    });"
                
                in_orphaned_callback = 0
                current_method = ""
                next
            }
        } else {
            # Add content to appropriate method body
            if (current_method == "success") {
                success_content = success_content $0 "\n"
            } else if (current_method == "failure") {
                failure_content = failure_content $0 "\n"
            }
        }
        next
    }
    
    # Detect orphaned onFailure method
    in_orphaned_callback && !current_method && /public void onFailure/ {
        current_method = "failure"
        method_brace_count = 0
        failure_content = ""
        next
    }
    
    # Skip the closing }); of orphaned callback
    in_orphaned_callback && /^[[:space:]]*}\);[[:space:]]*$/ {
        next
    }
    
    # Print normal lines
    !in_orphaned_callback {
        print $0
    }
    ' "$file" > "${file}.tmp"
    
    mv "${file}.tmp" "$file"
done

echo "Cleaning up callback artifacts..."
find "$CLASS_PATH" "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e '/ListenableFutureCallback/d' \
    -e 's/});[[:space:]]*});/});/g' \
    {} +

# Clean up any remaining callback-related patterns
find "$CLASS_PATH" "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e '/new ListenableFutureCallback<.*>/d' \
    -e '/new ListenableFutureCallback<>/d' \
    -e 's/});[[:space:]]*});[[:space:]]*$/});/' \
    {} +

# Final cleanup for any duplicate }); patterns
find "$CLASS_PATH" "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e '/^[[:space:]]*});[[:space:]]*$/N; s/});[[:space:]]*\n[[:space:]]*});/});/' \
    {} +

grep -rl "import java.util.concurrent.CompletableFutureCallback" "$CLASS_PATH" "$TEST_PATH" | xargs sed -i '' '/import java.util.concurrent.CompletableFutureCallback/d'

echo ""
echo "Kafka callback migration completed!"
echo ""
echo "Changes applied:"
echo "✅ ListenableFuture → CompletableFuture imports"
echo "✅ Removed ListenableFutureCallback imports"
echo "✅ .addCallback(...) → .whenComplete((result, ex) -> {...})"
echo "✅ onSuccess(result) → if (ex == null) {...}"
echo "✅ onFailure(ex) → } else {...}"
echo ""
echo "⚠️  Please verify the callback transformations manually!"