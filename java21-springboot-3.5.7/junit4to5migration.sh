#!/bin/bash

# Define versions to update to
JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
PROPERTIES_PATH="./src/main/resources"
TEST_PATH="./src/test/java"

echo "Starting JUnit 4 to JUnit 5 migration..."

# Update imports
echo "Updating JUnit imports..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.Test;/import org.junit.jupiter.api.Test;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.Before;/import org.junit.jupiter.api.BeforeEach;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.BeforeClass;/import org.junit.jupiter.api.BeforeAll;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.After;/import org.junit.jupiter.api.AfterEach;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.AfterClass;/import org.junit.jupiter.api.AfterAll;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.Ignore;/import org.junit.jupiter.api.Disabled;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import static org\.junit\.Assert\.\*/import static org.junit.jupiter.api.Assertions.*/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.Assert;/import org.junit.jupiter.api.Assertions;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import static org\.junit\.Assert\./import static org.junit.jupiter.api.Assertions./g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.runner\.RunWith;/import org.junit.jupiter.api.extension.ExtendWith;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.springframework\.test\.context\.junit4\.SpringRunner;/import org.springframework.test.context.junit.jupiter.SpringExtension;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.mockito\.junit\.MockitoJUnitRunner;/import org.mockito.junit.jupiter.MockitoExtension;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.mockito\.runners\.MockitoJUnitRunner;/import org.mockito.junit.jupiter.MockitoExtension;/g' {} +

# Remove JUnit 3 TestCase and transform static imports
echo "Transforming JUnit 3 TestCase imports and static imports..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' '/import junit\.framework\.TestCase;/d' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/\(class [A-Za-z0-9_]*\) extends TestCase/\1/g' {} +

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

# Remove any remaining JUnit 3 framework imports
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' '/import junit\.framework\.Assert;/d' {} +

# Handle JUnit 3 suite() method removal (rarely needed in modern testing)
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' '/public static Test suite()/d' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' '/public static junit\.framework\.Test suite()/d' {} +

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
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.mockito\.Matchers;/import org.mockito.ArgumentMatchers;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import static org\.mockito\.Matchers\./import static org.mockito.ArgumentMatchers./g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.any(/ArgumentMatchers.any(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.anyList(/ArgumentMatchers.anyList(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.anySet(/ArgumentMatchers.anySet(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.anyMap(/ArgumentMatchers.anyMap(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.anyCollection(/ArgumentMatchers.anyCollection(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.anyIterable(/ArgumentMatchers.anyIterable(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.eq(/ArgumentMatchers.eq(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.isNull(/ArgumentMatchers.isNull(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.isNotNull(/ArgumentMatchers.isNotNull(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.contains(/ArgumentMatchers.contains(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.matches(/ArgumentMatchers.matches(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.startsWith(/ArgumentMatchers.startsWith(/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Matchers\.endsWith(/ArgumentMatchers.endsWith(/g' {} +

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
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@Before$/@BeforeEach/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@Before[[:space:]]*$/@BeforeEach/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@BeforeClass$/@BeforeAll/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@BeforeClass[[:space:]]*$/@BeforeAll/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@After$/@AfterEach/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@After[[:space:]]*$/@AfterEach/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@AfterClass$/@AfterAll/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@AfterClass[[:space:]]*$/@AfterAll/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@Ignore/@Disabled/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@RunWith(SpringRunner\.class)/@ExtendWith(SpringExtension.class)/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@RunWith(MockitoJUnitRunner\.class)/@ExtendWith(MockitoExtension.class)/g' {} +

# Update assertion class names
echo "Updating assertion class names..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Assert\.assertEquals/Assertions.assertEquals/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Assert\.assertNotEquals/Assertions.assertNotEquals/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Assert\.assertTrue/Assertions.assertTrue/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Assert\.assertFalse/Assertions.assertFalse/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Assert\.assertNull/Assertions.assertNull/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Assert\.assertNotNull/Assertions.assertNotNull/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Assert\.assertSame/Assertions.assertSame/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Assert\.assertNotSame/Assertions.assertNotSame/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Assert\.assertArrayEquals/Assertions.assertArrayEquals/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Assert\.fail/Assertions.fail/g' {} +

# Additional JUnit 5 migrations
echo "Applying additional JUnit 5 specific transformations..."

# Handle @Rule and @ClassRule replacements
echo "Updating JUnit Rules to Extensions..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.Rule;/import org.junit.jupiter.api.extension.RegisterExtension;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.ClassRule;/import org.junit.jupiter.api.extension.RegisterExtension;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@Rule/@RegisterExtension/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@ClassRule/@RegisterExtension/g' {} +

# Handle JUnit 4 ExpectedException rule
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.rules\.ExpectedException;//g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' '/ExpectedException.*=.*ExpectedException\.none/d' {} +

# Handle TestName rule replacement
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.rules\.TestName;/import org.junit.jupiter.api.TestInfo;/g' {} +

# Handle TemporaryFolder rule
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.rules\.TemporaryFolder;/import org.junit.jupiter.api.io.TempDir;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@Rule.*TemporaryFolder.*/@TempDir/g' {} +

# Handle timeout annotations
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@Test(timeout[[:space:]]*=[[:space:]]*\([0-9]*\))/@Test @Timeout(\1)/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.Test;/import org.junit.jupiter.api.Test;\nimport org.junit.jupiter.api.Timeout;/g' {} +

# Handle expected exceptions in @Test annotations
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@Test(expected[[:space:]]*=[[:space:]]*\([^)]*\))/@Test/g' {} +

# Handle Hamcrest matchers updates
echo "Updating Hamcrest imports..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import static org\.hamcrest\.CoreMatchers\.\*/import static org.hamcrest.MatcherAssert.assertThat;\nimport static org.hamcrest.Matchers.*;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import static org\.junit\.Assert\.assertThat;/import static org.hamcrest.MatcherAssert.assertThat;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/Assert\.assertThat/MatcherAssert.assertThat/g' {} +

# Handle PowerMockito to Mockito transitions
echo "Updating PowerMockito patterns..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.powermock\.api\.mockito\.PowerMockito;/import org.mockito.MockedStatic;\nimport org.mockito.Mockito;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@RunWith(PowerMockRunner\.class)/@ExtendWith(MockitoExtension.class)/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' '/import org\.powermock\.core\.classloader\.annotations\.PrepareForTest;/d' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' '/@PrepareForTest/d' {} +

# Handle JUnit 4 Categories to JUnit 5 Tags
echo "Converting Categories to Tags..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.experimental\.categories\.Category;/import org.junit.jupiter.api.Tag;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@Category(\([^)]*\))/@Tag("\1")/g' {} +

# Handle JUnit 4 Parameterized tests to JUnit 5
echo "Updating Parameterized test patterns..."
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.runners\.Parameterized;/import org.junit.jupiter.params.ParameterizedTest;\nimport org.junit.jupiter.params.provider.ValueSource;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@RunWith(Parameterized\.class)/@ParameterizedTest/g' {} +

# Handle JUnit 4 Theory to JUnit 5 (basic replacement)
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/import org\.junit\.experimental\.theories\.Theory;/import org.junit.jupiter.params.ParameterizedTest;/g' {} +
find "$TEST_PATH" -type f -name "*.java" -exec sed -i '' 's/@Theory/@ParameterizedTest/g' {} +

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
        sed -i '' '1s/^/import org.junit.jupiter.api.Timeout;\n/' "$file"
    fi
    
    # Add Tag import if @Tag is used
    if grep -q "@Tag" "$file" && ! grep -q "import org.junit.jupiter.api.Tag" "$file"; then
        sed -i '' '1s/^/import org.junit.jupiter.api.Tag;\n/' "$file"
    fi
    
    # Add TempDir import if @TempDir is used
    if grep -q "@TempDir" "$file" && ! grep -q "import org.junit.jupiter.api.io.TempDir" "$file"; then
        sed -i '' '1s/^/import org.junit.jupiter.api.io.TempDir;\n/' "$file"
    fi
    
    # Add TestInfo import if TestInfo is used as parameter
    if grep -q "TestInfo" "$file" && ! grep -q "import org.junit.jupiter.api.TestInfo" "$file"; then
        sed -i '' '1s/^/import org.junit.jupiter.api.TestInfo;\n/' "$file"
    fi
done

echo ""
echo "JUnit 4 to JUnit 5 migration completed!"
echo "Note: Manual review required for:"
echo "  - @Rule/@ClassRule replacements (now @RegisterExtension)"
echo "  - Expected exceptions (use assertThrows instead of @Test(expected=...))"
echo "  - Timeout annotations (verify @Timeout usage)"
echo "  - Parameterized tests (may need @ValueSource, @CsvSource, etc.)"
echo "  - PowerMockito static mocking (use Mockito.mockStatic)"
echo ""
