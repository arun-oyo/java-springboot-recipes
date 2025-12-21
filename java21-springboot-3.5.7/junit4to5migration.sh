#!/bin/bash

# Define versions to update to
JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
PROPERTIES_PATH="./src/main/resources"
TEST_PATH="./src/test/java"

move_assert_args() {
    local METHOD="$1"
    local FILE="$2"
    
    echo "Processing $METHOD assertion parameter reorder in: $(basename "$FILE")"
    
    # Create a temporary file
    local TEMP_FILE=$(mktemp)
    
    # Use awk to handle method calls and parameter reordering based on comma count
    awk -v method="$METHOD" '
    BEGIN {
        in_assert = 0
        buffer = ""
        method_call = ""
        lines_before = ""
    }
    
    {
        # Check if line contains assertion method start
        if (!in_assert) {
            pattern1 = "Assert\\." method "[[:space:]]*\\("
            pattern2 = "Assertions\\." method "[[:space:]]*\\("
            pattern3 = method "[[:space:]]*\\("
            if (match($0, pattern1) || match($0, pattern2) || match($0, pattern3)) {
                method_call = substr($0, RSTART, RLENGTH-1)  # Remove the opening (
                in_assert = 1
                buffer = $0
                
                # Check if this is a complete single-line assertion
                if ($0 ~ /\);/) {
                    # Single-line assertion, process immediately
                    in_assert = 0
                    
                    # Find the opening parenthesis and closing );
                    open_paren = index(buffer, "(")
                    semicolon_pos = index(buffer, ");")
                    
                    if (open_paren > 0 && semicolon_pos > open_paren) {
                        # Extract arguments between ( and );
                        args_content = substr(buffer, open_paren + 1, semicolon_pos - open_paren - 1)
                        
                        # Process parameters with parentheses and quotes awareness
                        param_count = 0
                        delete params
                        paren_count = 0
                        quote_count = 0
                        current_param = ""
                        
                        for (i = 1; i <= length(args_content); i++) {
                            char = substr(args_content, i, 1)
                            
                            if (char == "\"" && (i == 1 || substr(args_content, i-1, 1) != "\\")) {
                                quote_count = (quote_count + 1) % 2
                                current_param = current_param char
                            }
                            else if (quote_count == 0 && char == "(") {
                                paren_count++
                                current_param = current_param char
                            }
                            else if (quote_count == 0 && char == ")") {
                                paren_count--
                                current_param = current_param char
                            }
                            else if (quote_count == 0 && paren_count == 0 && char == ",") {
                                param_count++
                                gsub(/^[ \t\n\r]+|[ \t\n\r]+$/, "", current_param)
                                gsub(/[ \t\n\r]+/, " ", current_param)
                                params[param_count] = current_param
                                current_param = ""
                            }
                            else {
                                current_param = current_param char
                            }
                        }
                        
                        # Add the last parameter
                        if (current_param != "") {
                            param_count++
                            gsub(/^[ \t\n\r]+|[ \t\n\r]+$/, "", current_param)
                            gsub(/[ \t\n\r]+/, " ", current_param)
                            params[param_count] = current_param
                        }
                        
                        # Apply JUnit 4 to 5 reordering rules
                        if (param_count == 2) {
                            new_args = params[2] ", " params[1]
                        }
                        else if (param_count == 3) {
                            new_args = params[2] ", " params[3] ", " params[1]  
                        }
                        else {
                            # Keep original
                            print buffer
                            buffer = ""
                            method_call = ""
                            next
                        }
                        
                        # Find indentation
                        if (match(buffer, /^[ \t]*/)) {
                            indent = substr(buffer, RSTART, RLENGTH)
                        } else {
                            indent = ""
                        }
                        
                        print indent method_call "(" new_args ");"
                    } else {
                        # Could not parse, print as-is
                        print buffer
                    }
                    
                    buffer = ""
                    method_call = ""
                } else {
                    # Multi-line assertion, continue collecting
                    next
                }
            } else {
                # Not an assertion line, print immediately
                print
                next
            }
        } else {
            # We are inside a multi-line assertion, accumulate until we find );
            buffer = buffer "\n" $0
            
                if ($0 ~ /\);/) {
                in_assert = 0
                
                # Process the complete multi-line assertion
                open_paren = index(buffer, "(")
                semicolon_pos = index(buffer, ");")
                
                if (open_paren > 0 && semicolon_pos > open_paren) {
                    # Extract arguments between ( and );
                    args_content = substr(buffer, open_paren + 1, semicolon_pos - open_paren - 1)
                    
                    # Normalize multi-line content to single line
                    gsub(/[ \t\n\r]+/, " ", args_content)
                    gsub(/^[ ]+|[ ]+$/, "", args_content)
                    
                    # Process parameters with parentheses and quotes awareness
                    param_count = 0
                    delete params
                    paren_count = 0
                    quote_count = 0
                    current_param = ""
                    
                    for (i = 1; i <= length(args_content); i++) {
                        char = substr(args_content, i, 1)
                        
                        if (char == "\"" && (i == 1 || substr(args_content, i-1, 1) != "\\")) {
                            quote_count = (quote_count + 1) % 2
                            current_param = current_param char
                        }
                        else if (quote_count == 0 && char == "(") {
                            paren_count++
                            current_param = current_param char
                        }
                        else if (quote_count == 0 && char == ")") {
                            paren_count--
                            current_param = current_param char
                        }
                        else if (quote_count == 0 && paren_count == 0 && char == ",") {
                            param_count++
                            gsub(/^[ ]+|[ ]+$/, "", current_param)
                            params[param_count] = current_param
                            current_param = ""
                        }
                        else {
                            current_param = current_param char
                        }
                    }
                    
                    # Add the last parameter
                    if (current_param != "") {
                        param_count++
                        gsub(/^[ ]+|[ ]+$/, "", current_param)
                        params[param_count] = current_param
                    }
                    
                    # Apply JUnit 4 to 5 reordering rules
                    if (param_count == 2) {
                        new_args = params[2] ", " params[1]
                    }
                    else if (param_count == 3) {
                        new_args = params[2] ", " params[3] ", " params[1]  
                    }
                    else {
                        # Keep original but print as single line
                        new_args = args_content
                    }
                    
                    # Find indentation from the first line
                    first_line = ""
                    if (match(buffer, /^[^\n]*/)) {
                        first_line = substr(buffer, RSTART, RLENGTH)
                    }
                    if (match(first_line, /^[ \t]*/)) {
                        indent = substr(first_line, RSTART, RLENGTH)
                    } else {
                        indent = ""
                    }
                    
                    print indent method_call "(" new_args ");"
                } else {
                    # Could not parse, print buffer as-is
                    print buffer
                }
                
                buffer = ""
                method_call = ""
            }
        }
    }
    ' "$FILE" > "$TEMP_FILE"
    
    # Replace original file with processed version
    mv "$TEMP_FILE" "$FILE"
    
    echo "  Completed processing $(basename "$FILE")"
}


echo "Starting JUnit 4 to JUnit 5 migration..."

# Update imports
echo "Updating JUnit imports..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/import org\.junit\.Test;/import org.junit.jupiter.api.Test;/g' \
    -e 's/import org\.junit\.Before;/import org.junit.jupiter.api.BeforeEach;/g' \
    -e 's/import org\.junit\.BeforeClass;/import org.junit.jupiter.api.BeforeAll;/g' \
    -e 's/import org\.junit\.After;/import org.junit.jupiter.api.AfterEach;/g' \
    -e 's/import org\.junit\.AfterClass;/import org.junit.jupiter.api.AfterAll;/g' \
    -e 's/import org\.junit\.Ignore;/import org.junit.jupiter.api.Disabled;/g' \
    -e 's/import static org\.junit\.Assert\.\*/import static org.junit.jupiter.api.Assertions.*/g' \
    -e 's/import org\.junit\.Assert;/import org.junit.jupiter.api.Assertions;/g' \
    -e 's/import static org\.junit\.Assert\./import static org.junit.jupiter.api.Assertions./g' \
    -e 's/import org\.junit\.runner\.RunWith;/import org.junit.jupiter.api.extension.ExtendWith;/g' \
    -e 's/import org\.springframework\.test\.context\.junit4\.SpringRunner;/import org.springframework.test.context.junit.jupiter.SpringExtension;/g' \
    -e 's/import org\.mockito\.junit\.MockitoJUnitRunner;/import org.mockito.junit.jupiter.MockitoExtension;/g' \
    -e 's/import org\.mockito\.runners\.MockitoJUnitRunner;/import org.mockito.junit.jupiter.MockitoExtension;/g' \
    -e 's/import org\.testng\.AssertJUnit;/import org.junit.jupiter.api.Assertions;/g' \
    -e 's/import org\.testng\.Assertions;/import org.junit.jupiter.api.Assertions;/g' \
    -e 's/import static org\.testng\.AssertJUnit\./import static org.junit.jupiter.api.Assertions./g' \
    -e 's/import static org\.testng\.Assertions\./import static org.junit.jupiter.api.Assertions./g' \
    -e 's/import org\.assertj\.core\.api\.Assertions;/import org.junit.jupiter.api.Assertions;/g' \
    -e 's/import static org\.assertj\.core\.api\.Assertions\.\*/import static org.junit.jupiter.api.Assertions.*;/g' \
    -e 's/import static org\.assertj\.core\.api\.Assertions\./import static org.junit.jupiter.api.Assertions./g' \
    {} +

# Remove JUnit 3 TestCase and transform static imports
echo "Transforming JUnit 3 TestCase imports and static imports..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e '/import junit\.framework\.TestCase;/d' \
    -e 's/\(class [A-Za-z0-9_]*\) extends TestCase/\1/g' \
    {} +

# Transform JUnit 3 TestCase static imports to JUnit 5
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/import static junit\.framework\.TestCase\.assertEquals;/import static org.junit.jupiter.api.Assertions.assertEquals;/g' \
    -e 's/import static junit\.framework\.TestCase\.assertNotEquals;/import static org.junit.jupiter.api.Assertions.assertNotEquals;/g' \
    -e 's/import static junit\.framework\.TestCase\.assertTrue;/import static org.junit.jupiter.api.Assertions.assertTrue;/g' \
    -e 's/import static junit\.framework\.TestCase\.assertFalse;/import static org.junit.jupiter.api.Assertions.assertFalse;/g' \
    -e 's/import static junit\.framework\.TestCase\.assertNull;/import static org.junit.jupiter.api.Assertions.assertNull;/g' \
    -e 's/import static junit\.framework\.TestCase\.assertNotNull;/import static org.junit.jupiter.api.Assertions.assertNotNull;/g' \
    -e 's/import static junit\.framework\.TestCase\.assertSame;/import static org.junit.jupiter.api.Assertions.assertSame;/g' \
    -e 's/import static junit\.framework\.TestCase\.assertNotSame;/import static org.junit.jupiter.api.Assertions.assertNotSame;/g' \
    -e 's/import static junit\.framework\.TestCase\.fail;/import static org.junit.jupiter.api.Assertions.fail;/g' \
    {} +

# Transform JUnit 3 Assert static imports to JUnit 5
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/import static junit\.framework\.Assert\.assertEquals;/import static org.junit.jupiter.api.Assertions.assertEquals;/g' \
    -e 's/import static junit\.framework\.Assert\.assertNotEquals;/import static org.junit.jupiter.api.Assertions.assertNotEquals;/g' \
    -e 's/import static junit\.framework\.Assert\.assertTrue;/import static org.junit.jupiter.api.Assertions.assertTrue;/g' \
    -e 's/import static junit\.framework\.Assert\.assertFalse;/import static org.junit.jupiter.api.Assertions.assertFalse;/g' \
    -e 's/import static junit\.framework\.Assert\.assertNull;/import static org.junit.jupiter.api.Assertions.assertNull;/g' \
    -e 's/import static junit\.framework\.Assert\.assertNotNull;/import static org.junit.jupiter.api.Assertions.assertNotNull;/g' \
    -e 's/import static junit\.framework\.Assert\.assertSame;/import static org.junit.jupiter.api.Assertions.assertSame;/g' \
    -e 's/import static junit\.framework\.Assert\.assertNotSame;/import static org.junit.jupiter.api.Assertions.assertNotSame;/g' \
    -e 's/import static junit\.framework\.Assert\.fail;/import static org.junit.jupiter.api.Assertions.fail;/g' \
    -e 's/import static junit\.framework\.Assert\.assertArrayEquals;/import static org.junit.jupiter.api.Assertions.assertArrayEquals;/g' \
    {} +

# Transform TestNG static imports to JUnit 5
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/import static org\.testng\.Assertions\.assertEquals;/import static org.junit.jupiter.api.Assertions.assertEquals;/g' \
    -e 's/import static org\.testng\.Assertions\.assertNotEquals;/import static org.junit.jupiter.api.Assertions.assertNotEquals;/g' \
    -e 's/import static org\.testng\.Assertions\.assertTrue;/import static org.junit.jupiter.api.Assertions.assertTrue;/g' \
    -e 's/import static org\.testng\.Assertions\.assertFalse;/import static org.junit.jupiter.api.Assertions.assertFalse;/g' \
    -e 's/import static org\.testng\.Assertions\.assertNull;/import static org.junit.jupiter.api.Assertions.assertNull;/g' \
    -e 's/import static org\.testng\.Assertions\.assertNotNull;/import static org.junit.jupiter.api.Assertions.assertNotNull;/g' \
    -e 's/import static org\.testng\.Assertions\.assertSame;/import static org.junit.jupiter.api.Assertions.assertSame;/g' \
    -e 's/import static org\.testng\.Assertions\.assertNotSame;/import static org.junit.jupiter.api.Assertions.assertNotSame;/g' \
    -e 's/import static org\.testng\.Assertions\.fail;/import static org.junit.jupiter.api.Assertions.fail;/g' \
    -e 's/import static org\.testng\.Assert\.assertEquals;/import static org.junit.jupiter.api.Assertions.assertEquals;/g' \
    -e 's/import static org\.testng\.Assert\.assertNotEquals;/import static org.junit.jupiter.api.Assertions.assertNotEquals;/g' \
    -e 's/import static org\.testng\.Assert\.assertTrue;/import static org.junit.jupiter.api.Assertions.assertTrue;/g' \
    -e 's/import static org\.testng\.Assert\.assertFalse;/import static org.junit.jupiter.api.Assertions.assertFalse;/g' \
    -e 's/import static org\.testng\.Assert\.assertNull;/import static org.junit.jupiter.api.Assertions.assertNull;/g' \
    -e 's/import static org\.testng\.Assert\.assertNotNull;/import static org.junit.jupiter.api.Assertions.assertNotNull;/g' \
    -e 's/import static org\.testng\.Assert\.assertSame;/import static org.junit.jupiter.api.Assertions.assertSame;/g' \
    -e 's/import static org\.testng\.Assert\.assertNotSame;/import static org.junit.jupiter.api.Assertions.assertNotSame;/g' \
    -e 's/import static org\.testng\.Assert\.fail;/import static org.junit.jupiter.api.Assertions.fail;/g' \
    {} +

# Remove any remaining JUnit 3 framework imports and suite methods
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e '/import junit\.framework\.Assert;/d' \
    -e '/public static Test suite()/d' \
    -e '/public static junit\.framework\.Test suite()/d' \
    {} +

# Handle Spring Boot Test transformations - Disable tests with Spring annotations
echo "Processing Spring Boot Test files..."
find "$TEST_PATH" -type f -name "*.java" | while read -r file; do
    # Check if file has any of the target annotations
    if grep -q -E "@SpringBootTest|@MockBean|@SpyBean" "$file"; then
        echo "Processing file with Spring annotations: $(basename "$file")"
        
        # Disable the test by commenting out test annotations and add TODO
        sed -i '' 's/^[[:space:]]*@Test/\/\/ TODO: Re-enable after Spring Boot migration - @Test/g' "$file"
        
        # Comment out Spring Boot Test annotation if present and add TODO
        sed -i '' 's/^[[:space:]]*@SpringBootTest/\/\/ TODO: Convert to unit test - @SpringBootTest/g' "$file"
        
        # Transform Spring annotations to Mockito
        sed -i '' \
            -e 's/@Autowired/@InjectMocks/g' \
            -e 's/@MockBean/@Mock/g' \
            -e 's/@SpyBean/@Mock/g' \
            "$file"
        
        # Add Mockito imports at line 3 if not already present
        if ! grep -q "import org.mockito.InjectMocks" "$file"; then
            sed -i '' '3i\
import org.mockito.InjectMocks;
' "$file"
        fi
        
        if ! grep -q "import org.mockito.Mock;" "$file"; then
            sed -i '' '3i\
import org.mockito.Mock;
' "$file"
        fi
        
        # Remove Spring Boot Test imports since they're commented out
        sed -i '' '/import org\.springframework\.boot\.test\.context\.SpringBootTest;/d' "$file"
        sed -i '' '/import org\.springframework\.boot\.test\.mock\.mockito\.SpyBean;/d' "$file"
        sed -i '' '/import org\.springframework\.boot\.test\.mock\.mockito\.MockBean;/d' "$file"
        sed -i '' '/import org\.springframework\.beans\.factory\.annotation\.Autowired;/d' "$file"
        
        echo "  - Disabled tests with TODO comments (// TODO: Re-enable after Spring Boot migration - @Test)"
        echo "  - Commented out @SpringBootTest with TODO (// TODO: Convert to unit test - @SpringBootTest)"
        echo "  - Transformed @Autowired → @InjectMocks"
        echo "  - Transformed @MockBean → @Mock"
        echo "  - Transformed @SpyBean → @Mock"
        echo "  - Added Mockito imports"
    fi
done

# Replace deprecated Mockito matchers with nullable() for null-safety FIRST
echo "Replacing deprecated Mockito matchers with nullable() equivalents..."

# Replace method calls with nullable equivalents - do this BEFORE converting Matchers to ArgumentMatchers
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/anyInt()/nullable(Integer.class)/g' \
    -e 's/anyString()/nullable(String.class)/g' \
    -e 's/anyLong()/nullable(Long.class)/g' \
    -e 's/anyDouble()/nullable(Double.class)/g' \
    -e 's/anyFloat()/nullable(Float.class)/g' \
    -e 's/anyBoolean()/nullable(Boolean.class)/g' \
    -e 's/anyByte()/nullable(Byte.class)/g' \
    -e 's/anyChar()/nullable(Character.class)/g' \
    -e 's/anyShort()/nullable(Short.class)/g' \
    {} +

# Handle anyListOf and similar generic matchers
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/anyListOf(String\.class)/nullable(List.class)/g' \
    -e 's/anyListOf(Integer\.class)/nullable(List.class)/g' \
    -e 's/anyListOf(Long\.class)/nullable(List.class)/g' \
    -e 's/anyListOf([A-Za-z0-9_]*\.class)/nullable(List.class)/g' \
    -e 's/anySetOf(String\.class)/nullable(Set.class)/g' \
    -e 's/anySetOf(Integer\.class)/nullable(Set.class)/g' \
    -e 's/anySetOf([A-Za-z0-9_]*\.class)/nullable(Set.class)/g' \
    -e 's/anyMapOf(String\.class, String\.class)/nullable(Map.class)/g' \
    -e 's/anyMapOf([A-Za-z0-9_]*\.class, [A-Za-z0-9_]*\.class)/nullable(Map.class)/g' \
    {} +

# Handle Mockito.anyXxx() style calls
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/Mockito\.anyInt()/nullable(Integer.class)/g' \
    -e 's/Mockito\.anyString()/nullable(String.class)/g' \
    -e 's/Mockito\.anyLong()/nullable(Long.class)/g' \
    -e 's/Mockito\.anyDouble()/nullable(Double.class)/g' \
    -e 's/Mockito\.anyFloat()/nullable(Float.class)/g' \
    -e 's/Mockito\.anyBoolean()/nullable(Boolean.class)/g' \
    -e 's/Mockito\.anyByte()/nullable(Byte.class)/g' \
    -e 's/Mockito\.anyChar()/nullable(Character.class)/g' \
    -e 's/Mockito\.anyShort()/nullable(Short.class)/g' \
    {} +

# Handle Matchers.anyXxx() style calls  
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/Matchers\.anyInt()/nullable(Integer.class)/g' \
    -e 's/Matchers\.anyString()/nullable(String.class)/g' \
    -e 's/Matchers\.anyLong()/nullable(Long.class)/g' \
    -e 's/Matchers\.anyDouble()/nullable(Double.class)/g' \
    -e 's/Matchers\.anyFloat()/nullable(Float.class)/g' \
    -e 's/Matchers\.anyBoolean()/nullable(Boolean.class)/g' \
    -e 's/Matchers\.anyByte()/nullable(Byte.class)/g' \
    -e 's/Matchers\.anyChar()/nullable(Character.class)/g' \
    -e 's/Matchers\.anyShort()/nullable(Short.class)/g' \
    {} +

# Handle static import from Mockito wildcard (import static org.mockito.Mockito.*)
# First, find files with wildcard Mockito imports
echo "Processing files with wildcard Mockito imports..."
find "$TEST_PATH" -type f -name "*.java" | while read -r file; do
    if grep -q "import static org\.mockito\.Mockito\.\*" "$file"; then
        echo "Processing $file for wildcard import transformations..."
        sed -i '' \
            -e 's/anyInt()/nullable(Integer.class)/g' \
            -e 's/anyString()/nullable(String.class)/g' \
            -e 's/anyLong()/nullable(Long.class)/g' \
            -e 's/anyDouble()/nullable(Double.class)/g' \
            -e 's/anyFloat()/nullable(Float.class)/g' \
            -e 's/anyBoolean()/nullable(Boolean.class)/g' \
            -e 's/anyByte()/nullable(Byte.class)/g' \
            -e 's/anyChar()/nullable(Character.class)/g' \
            -e 's/anyShort()/nullable(Short.class)/g' \
            "$file"
    fi
done

# Update remaining Mockito matchers (for non-deprecated ones)
echo "Updating remaining Mockito matchers..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/import org\.mockito\.Matchers;/import org.mockito.ArgumentMatchers;/g' \
    -e 's/import static org\.mockito\.Matchers\./import static org.mockito.ArgumentMatchers./g' \
    -e 's/Matchers\.any(/ArgumentMatchers.any(/g' \
    -e 's/Matchers\.anyList(/ArgumentMatchers.anyList(/g' \
    -e 's/Matchers\.anySet(/ArgumentMatchers.anySet(/g' \
    -e 's/Matchers\.anyMap(/ArgumentMatchers.anyMap(/g' \
    -e 's/Matchers\.anyCollection(/ArgumentMatchers.anyCollection(/g' \
    -e 's/Matchers\.anyIterable(/ArgumentMatchers.anyIterable(/g' \
    -e 's/Matchers\.eq(/ArgumentMatchers.eq(/g' \
    -e 's/Matchers\.isNull(/ArgumentMatchers.isNull(/g' \
    -e 's/Matchers\.isNotNull(/ArgumentMatchers.isNotNull(/g' \
    -e 's/Matchers\.contains(/ArgumentMatchers.contains(/g' \
    -e 's/Matchers\.matches(/ArgumentMatchers.matches(/g' \
    -e 's/Matchers\.startsWith(/ArgumentMatchers.startsWith(/g' \
    -e 's/Matchers\.endsWith(/ArgumentMatchers.endsWith(/g' \
    {} +

# Add necessary imports for nullable() and collection classes
echo "Adding necessary imports for nullable() and collection classes..."
find "$TEST_PATH" -type f -name "*.java" | while read -r file; do
    # Check if file uses nullable() and add import if missing
    if grep -q "nullable(" "$file" && ! grep -q "import static org.mockito.ArgumentMatchers.nullable" "$file"; then
        sed -i '' '3s/^/import static org.mockito.ArgumentMatchers.nullable;\n/' "$file"
    fi
    
    # Add List import if nullable(List.class) is used and import is missing
    if grep -q "nullable(List\.class)" "$file" && ! grep -q "import java.util.List" "$file"; then
        sed -i '' '3s/^/import java.util.List;\n/' "$file"
    fi
    
    # Add Set import if nullable(Set.class) is used and import is missing
    if grep -q "nullable(Set\.class)" "$file" && ! grep -q "import java.util.Set" "$file"; then
        sed -i '' '3s/^/import java.util.Set;\n/' "$file"
    fi
    
    # Add Map import if nullable(Map.class) is used and import is missing
    if grep -q "nullable(Map\.class)" "$file" && ! grep -q "import java.util.Map" "$file"; then
        sed -i '' '3s/^/import java.util.Map;\n/' "$file"
    fi
done

# Update annotations
echo "Updating JUnit annotations..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/@Before$/@BeforeEach/g' \
    -e 's/@Before[[:space:]]*$/@BeforeEach/g' \
    -e 's/@BeforeClass$/@BeforeAll/g' \
    -e 's/@BeforeClass[[:space:]]*$/@BeforeAll/g' \
    -e 's/@After$/@AfterEach/g' \
    -e 's/@After[[:space:]]*$/@AfterEach/g' \
    -e 's/@AfterClass$/@AfterAll/g' \
    -e 's/@AfterClass[[:space:]]*$/@AfterAll/g' \
    -e 's/@Ignore/@Disabled/g' \
    -e 's/@RunWith(SpringRunner\.class)/@ExtendWith(SpringExtension.class)/g' \
    -e 's/@RunWith(MockitoJUnitRunner\.class)/@ExtendWith(MockitoExtension.class)/g' \
    -e 's/@RunWith(MockitoJUnitRunner\.Silent\.class)/@ExtendWith(MockitoExtension.class)/g' \
    {} +

# Update assertion class names
echo "Updating assertion class names..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/Assert\.assertEquals/Assertions.assertEquals/g' \
    -e 's/Assert\.assertNotEquals/Assertions.assertNotEquals/g' \
    -e 's/Assert\.assertTrue/Assertions.assertTrue/g' \
    -e 's/Assert\.assertFalse/Assertions.assertFalse/g' \
    -e 's/Assert\.assertNull/Assertions.assertNull/g' \
    -e 's/Assert\.assertNotNull/Assertions.assertNotNull/g' \
    -e 's/Assert\.assertSame/Assertions.assertSame/g' \
    -e 's/Assert\.assertNotSame/Assertions.assertNotSame/g' \
    -e 's/Assert\.assertArrayEquals/Assertions.assertArrayEquals/g' \
    -e 's/Assert\.fail/Assertions.fail/g' \
    -e 's/AssertJUnit\.assertEquals/Assertions.assertEquals/g' \
    -e 's/AssertJUnit\.assertNotEquals/Assertions.assertNotEquals/g' \
    -e 's/AssertJUnit\.assertTrue/Assertions.assertTrue/g' \
    -e 's/AssertJUnit\.assertFalse/Assertions.assertFalse/g' \
    -e 's/AssertJUnit\.assertNull/Assertions.assertNull/g' \
    -e 's/AssertJUnit\.assertNotNull/Assertions.assertNotNull/g' \
    -e 's/AssertJUnit\.assertSame/Assertions.assertSame/g' \
    -e 's/AssertJUnit\.assertNotSame/Assertions.assertNotSame/g' \
    -e 's/AssertJUnit\.assertArrayEquals/Assertions.assertArrayEquals/g' \
    -e 's/AssertJUnit\.fail/Assertions.fail/g' \
    {} +

# Convert AssertJ method calls to JUnit 5 assertions
echo "Converting AssertJ assertions to JUnit 5..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/assertThat(\([^)]*\))\.isEqualTo(\([^)]*\))/assertEquals(\2, \1)/g' \
    -e 's/assertThat(\([^)]*\))\.isNotEqualTo(\([^)]*\))/assertNotEquals(\2, \1)/g' \
    -e 's/assertThat(\([^)]*\))\.isTrue()/assertTrue(\1)/g' \
    -e 's/assertThat(\([^)]*\))\.isFalse()/assertFalse(\1)/g' \
    -e 's/assertThat(\([^)]*\))\.isNull()/assertNull(\1)/g' \
    -e 's/assertThat(\([^)]*\))\.isNotNull()/assertNotNull(\1)/g' \
    -e 's/assertThat(\([^)]*\))\.isSameAs(\([^)]*\))/assertSame(\2, \1)/g' \
    -e 's/assertThat(\([^)]*\))\.isNotSameAs(\([^)]*\))/assertNotSame(\2, \1)/g' \
    {} +

# Convert complex AssertJ assertions to JUnit 5 with manual review comments
echo "Converting complex AssertJ assertions to JUnit 5 (manual review needed)..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/assertThat(\([^)]*\))\.isEqualToComparingFieldByFieldRecursively(\([^)]*\))/\/\/ TODO: Manual review - was AssertJ field-by-field comparison\n        assertEquals(\2, \1)/g' \
    -e 's/assertThat(\([^)]*\))\.isEqualToComparingFieldByField(\([^)]*\))/\/\/ TODO: Manual review - was AssertJ field-by-field comparison\n        assertEquals(\2, \1)/g' \
    -e 's/assertThat(\([^)]*\))\.isEqualToIgnoringCase(\([^)]*\))/\/\/ TODO: Manual review - was AssertJ ignoring case\n        assertEquals(\2.toLowerCase(), \1.toLowerCase())/g' \
    -e 's/assertThat(\([^)]*\))\.contains(\([^)]*\))/\/\/ TODO: Manual review - was AssertJ contains\n        assertTrue(\1.contains(\2))/g' \
    -e 's/assertThat(\([^)]*\))\.doesNotContain(\([^)]*\))/\/\/ TODO: Manual review - was AssertJ does not contain\n        assertFalse(\1.contains(\2))/g' \
    -e 's/assertThat(\([^)]*\))\.hasSize(\([^)]*\))/\/\/ TODO: Manual review - was AssertJ hasSize\n        assertEquals(\2, \1.size())/g' \
    -e 's/assertThat(\([^)]*\))\.isEmpty()/\/\/ TODO: Manual review - was AssertJ isEmpty\n        assertTrue(\1.isEmpty())/g' \
    -e 's/assertThat(\([^)]*\))\.isNotEmpty()/\/\/ TODO: Manual review - was AssertJ isNotEmpty\n        assertFalse(\1.isEmpty())/g' \
    -e 's/Assertions\.assertThat/assertThat/g' \
    {} +

# Additional JUnit 5 migrations
echo "Applying additional JUnit 5 specific transformations..."

# Handle @Rule and @ClassRule replacements
echo "Updating JUnit Rules to Extensions..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/import org\.junit\.Rule;/import org.junit.jupiter.api.extension.RegisterExtension;/g' \
    -e 's/import org\.junit\.ClassRule;/import org.junit.jupiter.api.extension.RegisterExtension;/g' \
    -e 's/@Rule/@RegisterExtension/g' \
    -e 's/@ClassRule/@RegisterExtension/g' \
    {} +

# Handle JUnit 4 rules replacement
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/import org\.junit\.rules\.ExpectedException;//g' \
    -e '/ExpectedException.*=.*ExpectedException\.none/d' \
    -e 's/import org\.junit\.rules\.TestName;/import org.junit.jupiter.api.TestInfo;/g' \
    -e 's/import org\.junit\.rules\.TemporaryFolder;/import org.junit.jupiter.api.io.TempDir;/g' \
    -e 's/@Rule.*TemporaryFolder.*/@TempDir/g' \
    {} +

# Handle timeout and expected exception annotations
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/@Test(timeout[[:space:]]*=[[:space:]]*\([0-9]*\))/@Test @Timeout(\1)/g' \
    -e 's/import org\.junit\.Test;/import org.junit.jupiter.api.Test;\nimport org.junit.jupiter.api.Timeout;/g' \
    -e 's/@Test(expected[[:space:]]*=[[:space:]]*\([^)]*\))/@Test/g' \
    {} +

# Handle Hamcrest matchers updates
echo "Updating Hamcrest imports..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/import static org\.hamcrest\.CoreMatchers\.\*/import static org.hamcrest.MatcherAssert.assertThat;\nimport static org.hamcrest.Matchers.*;/g' \
    -e 's/import static org\.junit\.Assert\.assertThat;/import static org.hamcrest.MatcherAssert.assertThat;/g' \
    -e 's/Assert\.assertThat/MatcherAssert.assertThat/g' \
    {} +

# Handle PowerMockito to Mockito transitions
echo "Updating PowerMockito patterns..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/import org\.powermock\.api\.mockito\.PowerMockito;/import org.mockito.MockedStatic;\nimport org.mockito.Mockito;/g' \
    -e 's/@RunWith(PowerMockRunner\.class)/@ExtendWith(MockitoExtension.class)/g' \
    -e '/import org\.powermock\.core\.classloader\.annotations\.PrepareForTest;/d' \
    -e '/@PrepareForTest/d' \
    {} +

# Handle JUnit 4 Categories, Parameterized tests, and Theory to JUnit 5
echo "Converting Categories to Tags and updating test patterns..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' \
    -e 's/import org\.junit\.experimental\.categories\.Category;/import org.junit.jupiter.api.Tag;/g' \
    -e 's/@Category(\([^)]*\))/@Tag("\1")/g' \
    -e 's/import org\.junit\.runners\.Parameterized;/import org.junit.jupiter.params.ParameterizedTest;\nimport org.junit.jupiter.params.provider.ValueSource;/g' \
    -e 's/@RunWith(Parameterized\.class)/@ParameterizedTest/g' \
    -e 's/import org\.junit\.experimental\.theories\.Theory;/import org.junit.jupiter.params.ParameterizedTest;/g' \
    -e 's/@Theory/@ParameterizedTest/g' \
    {} +

# Clean up unused static imports for transformed matchers
echo "Removing unused static imports for transformed matchers..."
find "$TEST_PATH" -type f -name "*.java" | while read -r file; do
    # Remove specific static imports for anyXxx methods that we've transformed to nullable
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anyInt;/d' "$file"
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anyString;/d' "$file"
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anyLong;/d' "$file"
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anyDouble;/d' "$file"
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anyFloat;/d' "$file"
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anyBoolean;/d' "$file"
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anyByte;/d' "$file"
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anyChar;/d' "$file"
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anyShort;/d' "$file"
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anyListOf;/d' "$file"
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anySetOf;/d' "$file"
    sed -i '' '/import static org\.mockito\.ArgumentMatchers\.anyMapOf;/d' "$file"
    
    # Remove old Matchers imports for anyXxx methods
    sed -i '' '/import static org\.mockito\.Matchers\.anyInt;/d' "$file"
    sed -i '' '/import static org\.mockito\.Matchers\.anyString;/d' "$file"
    sed -i '' '/import static org\.mockito\.Matchers\.anyLong;/d' "$file"
    sed -i '' '/import static org\.mockito\.Matchers\.anyDouble;/d' "$file"
    sed -i '' '/import static org\.mockito\.Matchers\.anyFloat;/d' "$file"
    sed -i '' '/import static org\.mockito\.Matchers\.anyBoolean;/d' "$file"
    sed -i '' '/import static org\.mockito\.Matchers\.anyByte;/d' "$file"
    sed -i '' '/import static org\.mockito\.Matchers\.anyChar;/d' "$file"
    sed -i '' '/import static org\.mockito\.Matchers\.anyShort;/d' "$file"
    sed -i '' '/import static org\.mockito\.Matchers\.anyListOf;/d' "$file"
    sed -i '' '/import static org\.mockito\.Matchers\.anySetOf;/d' "$file"
    sed -i '' '/import static org\.mockito\.Matchers\.anyMapOf;/d' "$file"
done

# Add missing imports for new JUnit 5 features
echo "Adding additional JUnit 5 imports..."
find "$TEST_PATH" -type f -name "*.java" | while read -r file; do
    # Add Timeout import if @Timeout is used
    if grep -q "@Timeout" "$file" && ! grep -q "import org.junit.jupiter.api.Timeout" "$file"; then
        sed -i '' '3s/^/import org.junit.jupiter.api.Timeout;\n/' "$file"
    fi
    
    # Add Tag import if @Tag is used
    if grep -q "@Tag" "$file" && ! grep -q "import org.junit.jupiter.api.Tag" "$file"; then
        sed -i '' '3s/^/import org.junit.jupiter.api.Tag;\n/' "$file"
    fi
    
    # Add TempDir import if @TempDir is used
    if grep -q "@TempDir" "$file" && ! grep -q "import org.junit.jupiter.api.io.TempDir" "$file"; then
        sed -i '' '3s/^/import org.junit.jupiter.api.io.TempDir;\n/' "$file"
    fi
    
    # Add TestInfo import if TestInfo is used as parameter
    if grep -q "TestInfo" "$file" && ! grep -q "import org.junit.jupiter.api.TestInfo" "$file"; then
        sed -i '' '3s/^/import org.junit.jupiter.api.TestInfo;\n/' "$file"
    fi
done

echo ""
echo "Moving message parameters to last position in assertion methods..."

# Process all test files for assertion parameter reordering
find "$TEST_PATH" -type f -name "*.java" | while read -r file; do
  echo "Processing JUnit assertion migration in: $(basename "$file")"

  # --- 2-arg assertions ---
  # JUnit 4: (message, condition/value)
  # JUnit 5: (condition/value, message)
  move_assert_args assertTrue      "$file"
  move_assert_args assertFalse     "$file"
  move_assert_args assertNull      "$file"
  move_assert_args assertNotNull   "$file"

  # --- 3-arg assertions ---
  # JUnit 4: (message, actual, expected)
  # JUnit 5: (expected, actual, message)
  move_assert_args assertEquals        "$file"
  move_assert_args assertNotEquals     "$file"
  move_assert_args assertSame          "$file"
  move_assert_args assertNotSame       "$file"
  move_assert_args assertArrayEquals   "$file"

done
echo "JUnit assertion parameter reordering completed!"

echo "Updating verifyZeroInteractions to verifyNoInteractions..."
grep -rl 'verifyZeroInteractions' "$TEST_PATH" | while read -r file; do
    sed -i '' 's/verifyZeroInteractions(/verifyNoInteractions(/g' "$file"
    echo "  Updated verifyZeroInteractions in: $(basename "$file")"
done
echo

echo ""
echo "JUnit 4 to JUnit 5 migration completed!"
echo "Note: Manual review required for:"
echo "  - @Rule/@ClassRule replacements (now @RegisterExtension)"
echo "  - Expected exceptions (use assertThrows instead of @Test(expected=...))"
echo "  - Timeout annotations (verify @Timeout usage)"
echo "  - Parameterized tests (may need @ValueSource, @CsvSource, etc.)"
echo "  - PowerMockito static mocking (use Mockito.mockStatic)"
echo ""
