#!/bin/bash

# Define versions to update to
JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
PROPERTIES_PATH="./src/main/resources"
TEST_PATH="./src/test/java"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# javax -> jakarta import changes
echo "Changing javax to jakarta imports"
grep -rl "javax." "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import[[:space:]\n]*javax\./import jakarta./g' "$file"
    echo "Processed file: $file"
done
echo "Changed javax to jakarta imports!"


# Swagger annotation changes - ApiModelProperty -> Schema
echo "Transforming swagger annotations"
sh "$SCRIPT_DIR/swaggermigration.sh"
echo "Transformed swagger annotations!"


# HystrixCommand annotation changes - Hystrix -> Resilience4j
echo "Transforming HystrixCommand annotations"
sh "$SCRIPT_DIR/hystrix2resilience4j.sh"
grep -rl "@SpringBootApplication\|@Configuration" "$CLASS_PATH" | while read -r file; do
    sed -i '' '/EnableCircuitBreaker/d' "$file"
    sed -i '' '/EnableHystrixDashboard/d' "$file"
    sed -i '' '/EnableHystrix/d' "$file"
done
echo "Transformed HystrixCommand annotations to resilience4j"


# Property Naming Strategies changes
echo "Changing PropertyNamingStrategy name to PropertyNamingStrategies"
grep -rl "PropertyNamingStrategy" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/PropertyNamingStrategy/PropertyNamingStrategies/g' "$file"
    echo "Processed file: $file"
done
echo "Changed PropertyNamingStrategy name to PropertyNamingStrategies!"


# Handler interceptor changes
echo "Changing handler inteceptors"
grep -rl "HandlerInterceptorAdapter" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import[[:space:]\n]*org.springframework.web.servlet.handler.HandlerInterceptorAdapter/import org.springframework.web.servlet.HandlerInterceptor/g' "$file"
    sed -i '' 's/extends HandlerInterceptorAdapter/implements HandlerInterceptor/g' "$file"
    sed -i '' 's/return[[:space:]\n]*super\.preHandle\(.*\);/return true;/g' "$file"
    sed -i '' '/super\.preHandle\(.*\);/d' "$file"
    echo "Processed file: $file"
done
echo "Changed handler inteceptor!"


# MapUtils changes
echo "Changing Apache MapUtils to Spring CollectionUtils"
grep -rl "MapUtils" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import[[:space:]\n]*org.apache.commons.collections.MapUtils/import org.springframework.util.CollectionUtils/g' "$file"
    sed -i '' 's/org.apache.commons.collections.MapUtils.isNotEmpty/!CollectionUtils.isEmpty/g' "$file"
    sed -i '' 's/org.apache.commons.collections.MapUtils.isEmpty/CollectionUtils.isEmpty/g' "$file"
    sed -i '' 's/MapUtils.isNotEmpty/!CollectionUtils.isEmpty/g' "$file"
    sed -i '' 's/MapUtils.isEmpty/CollectionUtils.isEmpty/g' "$file"
    line_to_delete=$(grep -n "import org.springframework.util.CollectionUtils" "$file" | awk 'NR==2 {print $1}' | cut -d':' -f1)
    if [ -n "$line_to_delete" ]; then
        sed -i '' "${line_to_delete}d" $file
    fi
    echo "Processed file: $file"
done
echo "Changed Apache MapUtils to Spring CollectionUtils"


echo "Changing Apache CollectionUtils to Spring CollectionUtils"
grep -rl "import org.apache.commons.collections.CollectionUtils" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import[[:space:]\n]*org.apache.commons.collections.CollectionUtils/import org.springframework.util.CollectionUtils/g' "$file"
    sed -i '' 's/org.apache.commons.collections.CollectionUtils.isNotEmpty/!CollectionUtils.isEmpty/g' "$file"
    sed -i '' 's/org.apache.commons.collections.CollectionUtils.isEmpty/CollectionUtils.isEmpty/g' "$file"
    sed -i '' 's/CollectionUtils.isNotEmpty/!CollectionUtils.isEmpty/g' "$file"
    line_to_delete=$(grep -n "import org.springframework.util.CollectionUtils" "$file" | awk 'NR==2 {print $1}' | cut -d':' -f1)
    if [ -n "$line_to_delete" ]; then
        sed -i '' "${line_to_delete}d" $file
    fi
    echo "Processed file: $file"
done
echo "Changed Apache CollectionUtils to Spring CollectionUtils"


echo "Changing org.springframework.util.StringUtils.isEmpty to !org.springframework.util.StringUtils.hasText"
grep -rl "org.springframework.util.StringUtils.isEmpty" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/!org.springframework.util.StringUtils.isEmpty/org.springframework.util.StringUtils.hasText/g' "$file"
    sed -i '' 's/org.springframework.util.StringUtils.isEmpty/!org.springframework.util.StringUtils.hasText/g' "$file"
    echo "Processed file: $file"
done
echo "Changed org.springframework.util.StringUtils.isEmpty to !org.springframework.util.StringUtils.hasText"


echo "Changing StringUtils.isEmpty to !StringUtils.hasText"
grep -rl "import org.springframework.util.StringUtils" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/!StringUtils.isEmpty/StringUtils.hasText/g' "$file"
    sed -i '' 's/StringUtils.isEmpty/!StringUtils.hasText/g' "$file"
    echo "Processed file: $file"
done
echo "Changed StringUtils.isEmpty to !hasText"


echo "Changing hibernate @TypeDef & @TypeDefs"
sh "$SCRIPT_DIR/hibernatemigration.sh"
echo "Changed hibernate @TypeDef"


echo "Changing Rest Template Configuration"
grep -rl "import org.apache.http.impl.conn.PoolingHttpClientConnectionManager" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import org.apache.http.impl.conn.PoolingHttpClientConnectionManager/import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManager/g' "$file"
    sed -i '' 's/import org.apache.http.client.HttpClient/import org.apache.hc.client5.http.classic.HttpClient/g' "$file"
done
echo "Changed Rest Template Configuration"


echo "Changing org.apache.commons.lang. to org.apache.commons.lang3."
grep -rl "org.apache.commons.lang." "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/org.apache.commons.lang\./org.apache.commons.lang3./g' "$file"
done

echo "Changing org.codehaus.jackson"
grep -rl "org.codehaus.jackson.annotate" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/org.codehaus.jackson.annotate/com.fasterxml.jackson.annotation/g' "$file"
done
echo "Changed org.codehaus.jackson.annotate"

echo "Changing org.codehaus.jackson.map.ObjectMapper"
grep -rl "org.codehaus.jackson.map.ObjectMapper" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/org.codehaus.jackson.map.ObjectMapper/com.fasterxml.jackson.databind.ObjectMapper/g' "$file"
done
echo "Changed org.codehaus.jackson.map.ObjectMapper"

echo "Changing jpa Specifications"
grep -rl "import org.springframework.data.jpa.domain.Specifications" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/Specifications/Specification/g' "$file"
done
grep -rl "import org.springframework.data.domain.Sort" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/new Sort/Sort.by/g' "$file"
done
echo "Changed jpa Specifications"


grep -rl "jakarta.sql" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/jakarta.sql/javax.sql/g' "$file"
done

grep -rl "import com.newrelic" "$CLASS_PATH" | while read -r file; do
    sed -i '' '/import com.newrelic/d' $file
    sed -i '' '/import com.newrelic/d' $file
done

grep -rl "import org.apache.commons.collections.map.HashedMap" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import org.apache.commons.collections.map.HashedMap/import java.util.HashMap/g' $file
    sed -i '' 's/HashedMap/HashMap/g' $file
done

grep -rl "import org.apache.commons.collections.list.HashedList" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import org.apache.commons.collections.list.HashedList/import java.util.ArrayList/g' $file
    sed -i '' 's/HashedList/ArrayList/g' $file
done

grep -rl "import com.jcabi.aspects.Async" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import com.jcabi.aspects.Async/import org.springframework.scheduling.annotation.Async/g' $file
done

grep -rl "import io.swagger.models.auth" "$CLASS_PATH" | while read -r file; do
    sed -i '' '/import io.swagger.models.auth/d' $file
done

grep -rl "import org.apache.tomcat.jni.Local" "$CLASS_PATH" "$TEST_PATH" | while read -r file; do
    sed -i '' '/import org.apache.tomcat.jni.Local/d' $file
done

# Deprecated Double constructor migration (Java 21)
echo "Replacing deprecated new Double() constructors"
grep -rl "new Double(" "$CLASS_PATH" "$TEST_PATH" | while read -r file; do
    sed -i '' 's/new Double(/Double.valueOf(/g' "$file"
    echo "Processed file: $file"
done
echo "Replaced deprecated new Double() constructors with Double.valueOf()"

# Deprecated Float constructor migration (Java 21)
echo "Replacing deprecated new Float() constructors"
grep -rl "new Float(" "$CLASS_PATH" "$TEST_PATH" | while read -r file; do
    sed -i '' 's/new Float(/Float.valueOf(/g' "$file"
    echo "Processed file: $file"
done
echo "Replaced deprecated new Float() constructors with Float.valueOf()"

# Deprecated Long constructor migration (Java 21)
echo "Replacing deprecated new Long() constructors"
grep -rl "new Long(" "$CLASS_PATH" "$TEST_PATH" | while read -r file; do
    sed -i '' 's/new Long(/Long.valueOf(/g' "$file"
    echo "Processed file: $file"
done
echo "Replaced deprecated new Long() constructors with Long.valueOf()"

# Deprecated Integer constructor migration (Java 21)
echo "Replacing deprecated new Integer() constructors"
grep -rl "new Integer(" "$CLASS_PATH" "$TEST_PATH" | while read -r file; do
    sed -i '' 's/new Integer(/Integer.valueOf(/g' "$file"
    echo "Processed file: $file"
done
echo "Replaced deprecated new Integer() constructors with Integer.valueOf()"

# Deprecated Short constructor migration (Java 21)
echo "Replacing deprecated new Short() constructors"
grep -rl "new Short(" "$CLASS_PATH" "$TEST_PATH" | while read -r file; do
    sed -i '' 's/new Short(/Short.valueOf(/g' "$file"
    echo "Processed file: $file"
done
echo "Replaced deprecated new Short() constructors with Short.valueOf()"

# Deprecated Byte constructor migration (Java 21)
echo "Replacing deprecated new Byte() constructors"
grep -rl "new Byte(" "$CLASS_PATH" "$TEST_PATH" | while read -r file; do
    sed -i '' 's/new Byte(/Byte.valueOf(/g' "$file"
    echo "Processed file: $file"
done
echo "Replaced deprecated new Byte() constructors with Byte.valueOf()"

# Deprecated Character constructor migration (Java 21)
echo "Replacing deprecated new Character() constructors"
grep -rl "new Character(" "$CLASS_PATH" "$TEST_PATH" | while read -r file; do
    sed -i '' 's/new Character(/Character.valueOf(/g' "$file"
    echo "Processed file: $file"
done
echo "Replaced deprecated new Character() constructors with Character.valueOf()"

# Deprecated Boolean constructor migration (Java 21)
echo "Replacing deprecated new Boolean() constructors"
grep -rl "new Boolean(" "$CLASS_PATH" "$TEST_PATH" | while read -r file; do
    sed -i '' 's/new Boolean(/Boolean.valueOf(/g' "$file"
    echo "Processed file: $file"
done
echo "Replaced deprecated new Boolean() constructors with Boolean.valueOf()"


grep -rl "import io.micrometer.prometheus.PrometheusMeterRegistry" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import springfox.documentation/import io.micrometer.prometheusmetrics.PrometheusMeterRegistry/g' $file
done


grep -rl "import org.springframework.boot.autoconfigure.jdbc.DataSourceBuilder;" "$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import org.springframework.boot.autoconfigure.jdbc.DataSourceBuilder;/import org.springframework.boot.jdbc.DataSourceBuilder;/g' $file
done

grep -rl "import org.hibernate.validator.constraints.""$CLASS_PATH" | while read -r file; do
    sed -i '' 's/import org.hibernate.validator.constraints./import jakarta.validation.constraints./g' $file
done
