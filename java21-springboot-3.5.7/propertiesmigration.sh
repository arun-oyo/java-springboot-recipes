#!/bin/bash

# Define versions to update to
JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
PROPERTIES_PATH="./src/main/resources"
TEST_PATH="./src/test/java"


add_property() {
  local property=$1
  local file=$2

  if [[ -n $(tail -c1 "$file") ]]; then
    echo "" >> "$file"
  fi

  echo "$property" >> "$file"
}

# remove spring.profiles.active property
find "$PROPERTIES_PATH" -type f -name "*.properties" -exec sed -i '' '/spring.profiles.active/d' {} +
echo "removed spring.profiles.active"

# update header size property
find "$PROPERTIES_PATH" -type f -name "*.properties" -exec sed -i '' 's/server.max-http-header-size/server.max-http-request-header-size/g' {} +
echo "max header size property renamed"

# add spring.main.allow-circular-references property
find "$PROPERTIES_PATH" -type f -name "application*.properties" | while read -r file; do
  sed -i '' '/spring.main.allow-circular-references/d' "$file"
  if [[ -n $(tail -c1 "$file") ]]; then
    echo "" >> "$file"
  fi
  echo "spring.main.allow-circular-references=true" >> "$file"
done
echo "spring.main.allow-circular-references property added"


# jackson naming strategy changes
find "$PROPERTIES_PATH" -type f -name "*.properties" | while read -r file; do
  sed -i '' 's/CAMEL_CASE_TO_LOWER_CASE_WITH_UNDERSCORES/com.fasterxml.jackson.databind.PropertyNamingStrategies.SnakeCaseStrategy/g' "$file"
done

# jpa - hibernate property changes
find "$PROPERTIES_PATH" -type f -name "*.properties" | while read -r file; do
  sed -i '' 's/org.springframework.boot.orm.jpa.hibernate.SpringPhysicalNamingStrategy/org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl/g' "$file"
  sed -i '' 's/org.springframework.boot.orm.jpa.hibernate.SpringImplicitNamingStrategy/org.hibernate.boot.model.naming.ImplicitNamingStrategyJpaCompliantImpl/g' "$file"
  sed -i '' 's/javax.persistence.query.timeout/jakarta.persistence.query.timeout/g' "$file"
done

# MongoDB UUID representation property
echo "Checking for MongoDB properties and adding UUID representation..."
find "$PROPERTIES_PATH" -type f -name "*.properties" | while read -r file; do
  # Check if file has any spring.data.mongodb properties
  if grep -q "^spring\.data\.mongodb\." "$file"; then
    echo "Found MongoDB properties in: $(basename "$file")"
    
    # Check if uuid-representation property already exists
    if ! grep -q "spring\.data\.mongodb\.uuid-representation" "$file"; then
      echo "Adding spring.data.mongodb.uuid-representation=java_legacy to: $(basename "$file")"
      
      # Add the property (without removing existing)
      if [[ -n $(tail -c1 "$file") ]]; then
        echo "" >> "$file"
      fi
      echo "spring.data.mongodb.uuid-representation=java_legacy" >> "$file"
    else
      echo "UUID representation property already exists in: $(basename "$file")"
    fi
  fi
done

# add throttler properties for resilience4j
# find "$PROPERTIES_PATH" -type f -name "*.properties" | while read -r file; do
#   add_property "resilience4j.timelimiter.instances.throttler.timeout-duration=\${THROTTLER_TIMEOUT:400}" "$file"
#   add_property "resilience4j.timelimiter.instances.throttler.cancel-running-future=true" "$file"
#   add_property "resilience4j.thread-pool-bulkhead.instances.AuthService.core-thread-pool-size=\${THROTTLER_CORE_POOL_SIZE:25}" "$file"
#   add_property "resilience4j.thread-pool-bulkhead.instances.AuthService.max-thread-pool-size=\${THROTTLER_MAX_POOL_SIZE:100}" "$file"
#   add_property "resilience4j.circuitbreaker.instances.throttler.ignore-exceptions=com.oyorooms.api.throttler.exceptions.AuthenticationFailedException,com.oyorooms.api.throttler.exceptions.AuthServiceException" "$file"
# done