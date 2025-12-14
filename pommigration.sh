#!/bin/bash

# Define versions to update to
JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
PROPERTIES_PATH="./src/main/resources"
TEST_PATH="./src/test/java"


ns="http://maven.apache.org/POM/4.0.0"

update_artifact() {
  local pom_file=$1
  local ns=$2
  local group_id=$3
  local artifact_id=$4
  local new_group_id=$5
  local new_artifact_id=$6

  if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[x:groupId='$group_id' and x:artifactId='$artifact_id']" "$pom_file" >/dev/null; then
        xmlstarlet ed --inplace \
            -N x="$ns" \
            -u "//x:project/x:dependencies/x:dependency[x:artifactId='$artifact_id']/x:artifactId" -v "$new_artifact_id" \
            "$pom_file"

        if [[ -n "$new_group_id" ]]; then
            xmlstarlet ed --inplace \
                -N x="$ns" \
                -u "//x:project/x:dependencies/x:dependency[x:artifactId='$new_artifact_id']/x:groupId" -v "$new_group_id" \
                "$pom_file"
        fi
  fi

}

update_version() {
  local pom_file=$1
  local ns=$2
  local group_id=$3
  local artifact_id=$4
  local version=$5

  if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[x:groupId='$group_id' and x:artifactId='$artifact_id']/x:version" "$pom_file" >/dev/null; then
        xmlstarlet ed --inplace \
            -N x="$ns" \
            -u "//x:project/x:dependencies/x:dependency[x:groupId='$group_id' and x:artifactId='$artifact_id']/x:version" -v "$version" \
            "$pom_file"
  else
     xmlstarlet ed --inplace \
        -N x="$ns" \
        -s "//x:project/x:dependencies/x:dependency[x:groupId='$group_id' and x:artifactId='$artifact_id']" -t elem -n "version" -v "$version" \
        "$pom_file"
  fi

}

update_version_or_add_dependency() {
  local pom_file=$1
  local ns=$2
  local group_id=$3
  local artifact_id=$4
  local version=$5

    if ! xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[x:artifactId='$artifact_id']" "$pom_file" >/dev/null; then
      # Add the dependency to the pom file
      xmlstarlet ed --inplace \
        -N x="$ns" \
        -s "//x:project/x:dependencies" -t elem -n "dependency" -v "" \
        "$pom_file"

      xmlstarlet ed --inplace \
        -N x="$ns" \
        -s "//x:project/x:dependencies/x:dependency[last()]" -t elem -n "groupId" -v "$group_id" \
        -s "//x:project/x:dependencies/x:dependency[last()]" -t elem -n "artifactId" -v "$artifact_id" \
        "$pom_file"
    fi
    if [[ -n "$version" ]]; then
        update_version "$pom_file" "$ns" "$group_id" "$artifact_id" "$version"
    fi
}


delete_dependency() {
  local pom_file=$1
  local ns=$2
  local group_id=$3
  local artifact_id=$4

  xmlstarlet ed --inplace \
        -N x="$ns" \
        -d "//x:project/x:dependencies/x:dependency[x:groupId='$group_id' and x:artifactId='$artifact_id']" \
        "$pom_file"
}


delete_version() {
  local pom_file=$1
  local ns=$2
  local group_id=$3
  local artifact_id=$4

  xmlstarlet ed --inplace \
        -N x="$ns" \
        -d "//x:project/x:dependencies/x:dependency[x:groupId='$group_id' and x:artifactId='$artifact_id']/x:version" \
        "$pom_file"
}


# Find all pom.xml files and iterate over them
pom_file="pom.xml"
echo "Processing $pom_file..."

# Remove the java.version property if it exists
    xmlstarlet ed --inplace \
        -N x="$ns" \
        -d "//x:project/x:properties/x:java.version" \
        "$pom_file"

# Update Spring Boot version in the parent
    xmlstarlet ed --inplace \
        -N x="$ns" \
        -u "//x:project/x:parent[x:artifactId='spring-boot-starter-parent']/x:version" -v "$SPRING_BOOT_VERSION" \
        "$pom_file"


# Plugin changes
    # Add/Update the maven compiler plugin
    if ! xmlstarlet sel -N x="$ns" -t -c "//x:plugins/x:plugin[x:artifactId='maven-compiler-plugin']" "$pom_file" >/dev/null; then
        if ! xmlstarlet sel -N x="$ns" -t -c "//x:project/x:build/x:plugins" "$pom_file" >/dev/null; then
            xmlstarlet ed --inplace \
                -N x="$ns" \
                -s "//x:project/x:build" -t elem -n "plugins" -v "" \
                "$pom_file"
        fi

        xmlstarlet ed --inplace \
            -N x="$ns" \
            -s "//x:project/x:build/x:plugins" -t elem -n "plugin" -v "" \
            "$pom_file"

        xmlstarlet ed --inplace \
            -N x="$ns" \
            -s "//x:project/x:build/x:plugins/x:plugin[last()]" -t elem -n "groupId" -v "org.apache.maven.plugins" \
            -s "//x:project/x:build/x:plugins/x:plugin[last()]" -t elem -n "artifactId" -v "maven-compiler-plugin" \
            -s "//x:project/x:build/x:plugins/x:plugin[last()]" -t elem -n "version" -v "3.13.0" \
            "$pom_file"

        xmlstarlet ed --inplace \
            -N x="$ns" \
            -s "//x:project/x:build/x:plugins/x:plugin[last()]" -t elem -n "configuration" -v "" \
            "$pom_file"

        xmlstarlet ed --inplace \
            -N x="$ns" \
            -s "//x:project/x:build/x:plugins/x:plugin[last()]/x:configuration" -t elem -n "source" -v "21" \
            -s "//x:project/x:build/x:plugins/x:plugin[last()]/x:configuration" -t elem -n "target" -v "21" \
            "$pom_file"


    else
        # Update source and target if maven-compiler-plugin exists
        xmlstarlet ed --inplace \
            -N x="$ns" \
            -u "//x:project/x:build/x:plugins/x:plugin[x:artifactId='maven-compiler-plugin']/x:configuration/x:source" -v "$JAVA_VERSION" \
            -u "//x:project/x:build/x:plugins/x:plugin[x:artifactId='maven-compiler-plugin']/x:configuration/x:target" -v "$JAVA_VERSION" \
            "$pom_file"
    fi

    if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:build/x:plugins/x:plugin[x:artifactId='avro-maven-plugin']" "$pom_file" >/dev/null; then
        xmlstarlet ed --inplace \
            -N x="$ns" \
            -u "//x:project/x:build/x:plugins/x:plugin[x:artifactId='avro-maven-plugin']/x:version" -v "1.11.3" \
            "$pom_file"
    fi

    if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:build/x:plugins/x:plugin[x:artifactId='jacoco-maven-plugin']" "$pom_file" >/dev/null; then
        xmlstarlet ed --inplace \
            -N x="$ns" \
            -u "//x:project/x:build/x:plugins/x:plugin[x:artifactId='jacoco-maven-plugin']/x:version" -v "0.8.12" \
            "$pom_file"

        if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:build/x:plugins/x:plugin[x:artifactId='maven-surefire-plugin']" "$pom_file" >/dev/null; then
            xmlstarlet ed --inplace \
                -N x="$ns" \
                -u "//x:project/x:build/x:plugins/x:plugin[x:artifactId='maven-surefire-plugin']/x:version" -v "3.5.0" \
                "$pom_file"
        else
            xmlstarlet ed --inplace \
                -N x="$ns" \
                -s "//x:project/x:build/x:plugins" -t elem -n "plugin" -v "" \
                "$pom_file"

            xmlstarlet ed --inplace \
                -N x="$ns" \
                -s "//x:project/x:build/x:plugins/x:plugin[last()]" -t elem -n "groupId" -v "org.apache.maven.plugins" \
                -s "//x:project/x:build/x:plugins/x:plugin[last()]" -t elem -n "artifactId" -v "maven-surefire-plugin" \
                -s "//x:project/x:build/x:plugins/x:plugin[last()]" -t elem -n "version" -v "3.5.0" \
                "$pom_file"
        fi
    fi



# DependencyManagement Changes

    # update or add springboot dependencies
    if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:parent[x:artifactId='spring-boot-starter-parent']/x:version" "$pom_file" >/dev/null; then
        if ! xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencyManagement/x:dependencies/x:dependency[x:groupId='org.springframework.boot' and x:artifactId='spring-boot-dependencies']" "$pom_file" >/dev/null; then
            if ! xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencyManagement" "$pom_file" >/dev/null; then
                xmlstarlet ed --inplace \
                    -N x="$ns" \
                    -s "//x:project" -t elem -n "dependencyManagement" -v "" \
                    "$pom_file"
            fi
            if ! xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencyManagement/x:dependencies" "$pom_file" >/dev/null; then
                xmlstarlet ed --inplace \
                    -N x="$ns" \
                    -s "//x:project/x:dependencyManagement" -t elem -n "dependencies" -v "" \
                    "$pom_file"
            fi

            xmlstarlet ed --inplace \
                -N x="$ns" \
                -s "//x:project/x:dependencyManagement/x:dependencies" -t elem -n "dependency" -v "" \
                "$pom_file"

            xmlstarlet ed --inplace \
                -N x="$ns" \
                -s "//x:project/x:dependencyManagement/x:dependencies/x:dependency[last()]" -t elem -n "groupId" -v "org.springframework.boot" \
                -s "//x:project/x:dependencyManagement/x:dependencies/x:dependency[last()]" -t elem -n "artifactId" -v "spring-boot-dependencies" \
                -s "//x:project/x:dependencyManagement/x:dependencies/x:dependency[last()]" -t elem -n "version" -v "$SPRING_BOOT_VERSION" \
                -s "//x:project/x:dependencyManagement/x:dependencies/x:dependency[last()]" -t elem -n "type" -v "pom" \
                -s "//x:project/x:dependencyManagement/x:dependencies/x:dependency[last()]" -t elem -n "scope" -v "import" \
                "$pom_file"
        fi
    fi

    # update spring cloud version
    if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[contains(x:artifactId, 'hystrix')]" "$pom_file" >/dev/null; then
        if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencyManagement/x:dependencies/x:dependency[x:groupId='org.springframework.cloud' and x:artifactId='spring-cloud-dependencies']" "$pom_file" >/dev/null; then
            echo "going to update spring cloud"
            xmlstarlet ed --inplace \
                -N x="$ns" \
                -u "//x:project/x:dependencyManagement/x:dependencies/x:dependency[x:groupId='org.springframework.cloud' and x:artifactId='spring-cloud-dependencies']/x:version" -v "2023.0.3" \
                "$pom_file"
        else
            xmlstarlet ed --inplace \
                -N x="$ns" \
                -s "//x:project/x:dependencyManagement/x:dependencies" -t elem -n "dependency" -v "" \
                "$pom_file"
            xmlstarlet ed --inplace \
                -N x="$ns" \
                -s "//x:project/x:dependencyManagement/x:dependencies/x:dependency[last()]" -t elem -n "groupId" -v "org.springframework.cloud" \
                -s "//x:project/x:dependencyManagement/x:dependencies/x:dependency[last()]" -t elem -n "artifactId" -v "spring-cloud-dependencies" \
                -s "//x:project/x:dependencyManagement/x:dependencies/x:dependency[last()]" -t elem -n "version" -v "2023.0.3" \
                -s "//x:project/x:dependencyManagement/x:dependencies/x:dependency[last()]" -t elem -n "type" -v "pom" \
                -s "//x:project/x:dependencyManagement/x:dependencies/x:dependency[last()]" -t elem -n "scope" -v "import" \
                "$pom_file"
        fi
    fi

# Extension changes
    if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:build/x:extensions/x:extension[x:groupId='com.github.platform-team' and x:artifactId='aws-maven']" "$pom_file" >/dev/null; then
        xmlstarlet ed --inplace \
            -N x="$ns" \
            -d "//x:project/x:build/x:extensions/x:extension[x:groupId='com.github.platform-team' and x:artifactId='aws-maven']" \
            "$pom_file"
    fi
    if ! xmlstarlet sel -N x="$ns" -t -c "//x:project/x:build/x:extensions/x:extension[x:groupId='org.kuali.maven.wagons' and x:artifactId='maven-s3-wagon']" "$pom_file" >/dev/null; then
        xmlstarlet ed --inplace \
            -N x="$ns" \
            -s "//x:project/x:build/x:extensions" -t elem -n "extension" -v "" \
            "$pom_file"
        xmlstarlet ed --inplace \
            -N x="$ns" \
            -s "//x:project/x:build/x:extensions/x:extension[last()]" -t elem -n "groupId" -v "org.kuali.maven.wagons" \
            -s "//x:project/x:build/x:extensions/x:extension[last()]" -t elem -n "artifactId" -v "maven-s3-wagon" \
            -s "//x:project/x:build/x:extensions/x:extension[last()]" -t elem -n "version" -v "1.2.1" \
            "$pom_file"
    else
        xmlstarlet ed --inplace \
            -N x="$ns" \
            -u "//x:project/x:build/x:extensions/x:extension[x:groupId='org.kuali.maven.wagons' and x:artifactId='maven-s3-wagon']/x:version" -v "1.2.1" \
            "$pom_file"
    fi



## Dependency Changes

# deduplicate
    xmlstarlet ed --inplace \
      -N x="$ns" \
      -d "//x:project/x:dependencies/x:dependency[position() > 1 and x:groupId=preceding-sibling::x:dependency/x:groupId and x:artifactId=preceding-sibling::x:dependency/x:artifactId]" \
      "$pom_file"

    echo "Updated $pom_file"

# spring-boot-starter changes
    xmlstarlet ed --inplace \
        -N x="$ns" \
        -d "//x:project/x:dependencies/x:dependency[x:artifactId[starts-with(., 'spring-boot-starter-')]]/x:version" \
        "$pom_file"


# lombok changes
    xmlstarlet ed --inplace \
        -N x="$ns" \
        -d "//x:project/x:dependencies/x:dependency[x:groupId='org.projectlombok' and x:artifactId='lombok']/x:version" \
        "$pom_file"


# starter velocity changes
    xmlstarlet ed --inplace \
        -N x="$ns" \
        -d "//x:project/x:dependencies/x:dependency[x:groupId='org.springframework.boot' and x:artifactId='spring-boot-starter-velocity']" \
        "$pom_file"


# apache velocity changes
    xmlstarlet ed --inplace \
        -N x="$ns" \
        -d "//x:project/x:dependencies/x:dependency[x:groupId='org.apache.velocity' and x:artifactId='velocity']" \
        "$pom_file"


# swagger changes
    if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[contains(x:artifactId, 'swagger')]" "$pom_file" >/dev/null; then
        xmlstarlet ed --inplace \
            -N x="$ns" \
            -d "//x:project/x:dependencies/x:dependency[contains(x:artifactId, 'swagger')]" \
            "$pom_file"

        delete_dependency "pom.xml" "$ns" "org.springdoc" "springdoc-openapi-ui"

        update_version_or_add_dependency "pom.xml" "$ns" "org.springdoc" "springdoc-openapi-starter-webmvc-ui" "2.5.0"
    fi


# spring-boot-starter-cache changes
    if ! xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[x:groupId='org.springframework.boot' and x:artifactId='spring-boot-starter-cache']" "$pom_file" >/dev/null; then
        # Only add if guava or caffeine is present
        if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[x:groupId='com.google.guava' and x:artifactId='guava']" "$pom_file" >/dev/null || xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[x:groupId='com.github.ben-manes.caffeine' and x:artifactId='caffeine']" "$pom_file" >/dev/null; then
            update_version_or_add_dependency "pom.xml" "$ns" "org.springframework.boot" "spring-boot-starter-cache" ""
        fi
    fi

# caffeine changes
    update_version "pom.xml" "$ns" "com.github.ben-manes.caffeine" "caffeine" "3.2.3"


# httpclient changes
    if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[x:groupId='org.apache.httpcomponents' and x:artifactId='httpclient']" "$pom_file" >/dev/null; then
        delete_dependency "pom.xml" "$ns" "org.apache.httpcomponents" "httpclient"
        update_version_or_add_dependency "pom.xml" "$ns" "org.apache.httpcomponents.client5" "httpclient5" "5.1.3"
    fi


# elastic apm changes
    update_version "pom.xml" "$ns" "co.elastic.apm" "apm-agent-api" "1.49.0"

# newrelic changes
    xmlstarlet ed --inplace \
        -N x="$ns" \
        -d "//x:project/x:dependencies/x:dependency[contains(x:artifactId, 'newrelic')]" \
        "$pom_file"

    xmlstarlet ed --inplace \
        -N x="$ns" \
        -d "//x:project/x:build/x:plugins/x:plugin[x:artifactId='maven-dependency-plugin']/x:executions/x:execution[x:configuration/x:includeArtifactIds[contains(., 'newrelic')]]" \
        "$pom_file"

    xmlstarlet ed --inplace \
        -N x="$ns" \
        -d "//x:project/x:build/x:plugins/x:plugin[x:artifactId='maven-dependency-plugin' and not(x:executions/x:execution)]" \
        "$pom_file"


# validation api changes
    if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[x:groupId='javax.validation' and x:artifactId='validation-api']" "$pom_file" >/dev/null; then
        delete_dependency "pom.xml" "$ns" "javax.validation" "validation-api"
        update_version_or_add_dependency "pom.xml" "$ns" "jakarta.validation" "jakarta.validation-api" "3.0.2"
    fi

# jackson changes
    update_version "pom.xml" "$ns" "com.fasterxml.jackson.core" "jackson-core" "2.14.2"
    update_version "pom.xml" "$ns" "com.fasterxml.jackson.core" "jackson-databind" "2.14.2"
    update_version "pom.xml" "$ns" "com.fasterxml.jackson.core" "jackson-annotations" "2.14.2"

# apache commons-lang changes
    update_artifact "pom.xml" "$ns" "org.apache.commons" "commons-lang" "org.apache.commons" "commons-lang3"
    update_version "pom.xml" "$ns" "org.apache.commons" "commons-lang3" "3.12.0"

# micrometer changes
    xmlstarlet ed --inplace \
        -N x="$ns" \
        -d "//x:project/x:dependencies/x:dependency[x:groupId='io.micrometer' and x:artifactId='micrometer-registry-prometheus']/x:version" \
        "$pom_file"
    
    update_artifact "pom.xml" "$ns" "io.micrometer" "micrometer-spring-legacy" "io.micrometer" "micrometer-core"
    update_version "pom.xml" "$ns" "io.micrometer" "micrometer-core" "1.10.2"


# netflix hystrix changes
        if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[contains(x:artifactId, 'hystrix')]" "$pom_file" >/dev/null; then
            xmlstarlet ed --inplace \
                -N x="$ns" \
                -d "//x:project/x:dependencies/x:dependency[contains(x:artifactId, 'hystrix')]" \
                "$pom_file"
            update_version_or_add_dependency "pom.xml" "$ns" "io.github.resilience4j" "resilience4j-spring-boot3"
        fi

# hibernate changes
    update_artifact "pom.xml" "$ns" "com.vladmihalcea" "hibernate-types-52" "com.vladmihalcea" "hibernate-types-60"
    update_version "pom.xml" "$ns" "com.vladmihalcea" "hibernate-types-60" "2.21.1"

    delete_dependency "pom.xml" "$ns" "org.hibernate" "hibernate-java8"
    delete_dependency "pom.xml" "$ns" "org.hibernate" "antlr"

    update_artifact "pom.xml" "$ns" "org.hibernate" "hibernate-core" "org.hibernate.orm" "hibernate-core"
    delete_version "pom.xml" "$ns" "org.hibernate.orm" "hibernate-core"
    
    update_artifact "pom.xml" "$ns" "org.hibernate" "hibernate-jpamodelgen" "org.hibernate.orm" "hibernate-jpamodelgen"
    delete_version "pom.xml" "$ns" "org.hibernate.orm" "hibernate-jpamodelgen"

    update_artifact "pom.xml" "$ns" "org.hibernate" "hibernate-validator" "org.hibernate.validator" "hibernate-validator"
    delete_version "pom.xml" "$ns" "org.hibernate.validator" "hibernate-validator"

# javax activation changes
    update_artifact "pom.xml" "$ns" "javax.activation" "activation" "jakarta.activation" "jakarta.activation-api"
    update_version "pom.xml" "$ns" "jakarta.activation" "jakarta.activation-api" "2.1.3"


# spring-test changes
    update_version "pom.xml" "$ns" "org.springframework" "spring-test" "6.1.6"

# Remove versions from all org.springframework.* dependencies (managed by Spring Boot BOM)
    echo "Removing versions from org.springframework.* dependencies..."
    
    # Get all org.springframework.* dependencies and remove their versions
    xmlstarlet sel -N x="$ns" -t -m "//x:project/x:dependencies/x:dependency[starts-with(x:groupId,'org.springframework.')]" \
        -v "x:groupId" -o ":" -v "x:artifactId" -n "pom.xml" 2>/dev/null | while read dependency; do
        if [ -n "$dependency" ]; then
            group_id=$(echo "$dependency" | cut -d: -f1)
            artifact_id=$(echo "$dependency" | cut -d: -f2)
            echo "  Removing version for $group_id:$artifact_id"
            delete_version "pom.xml" "$ns" "$group_id" "$artifact_id"
        fi
    done

# amazon sdk s3 changes
    update_version "pom.xml" "$ns" "com.amazonaws" "aws-java-sdk-s3" "1.12.261"

# org.json changes
    update_version "pom.xml" "$ns" "org.json" "json" "20231013"

# json-simple changes
    update_version "pom.xml" "$ns" "com.googlecode.json-simple" "json-simple" "1.1.1"

# avro changes
    update_version "pom.xml" "$ns" "org.apache.avro" "avro" "1.11.3"
    update_version "pom.xml" "$ns" "io.confluent" "kafka-schema-registry-client" "7.4.0"
    update_version "pom.xml" "$ns" "io.confluent" "kafka-avro-serializer" "7.4.6"
    update_version "pom.xml" "$ns" "io.confluent" "kafka-streams-avro-serde" "7.4.0"

# javax.xml.bind changes
    update_artifact "pom.xml" "$ns" "javax.xml.bind" "jaxb-api" "jakarta.xml.bind" "jakarta.xml.bind-api"
    delete_version "pom.xml" "$ns" "jakarta.xml.bind" "jakarta.xml.bind-api"

# prometheus client changes
    update_version "pom.xml" "$ns" "io.prometheus" "simpleclient" "0.16.0"
    update_version "pom.xml" "$ns" "io.prometheus" "simpleclient_spring_boot" "0.16.0"

# Hikari CP changes
    delete_version "pom.xml" "$ns" "com.zaxxer" "HikariCP"

# com.sun.xml.bind changes
    delete_version "pom.xml" "$ns" "com.sun.xml.bind" "jaxb-core"
    delete_version "pom.xml" "$ns" "com.sun.xml.bind" "jaxb-impl"

# powermockito changes
    update_version "pom.xml" "$ns" "org.powermock" "powermock-module-junit4" "2.0.9"
    update_version "pom.xml" "$ns" "org.powermock" "powermock-api-mockito2" "2.0.9"

# slf4j and log4j changes
    update_version "pom.xml" "$ns" "org.slf4j" "slf4j-api" "2.0.10"
    update_version "pom.xml" "$ns" "org.apache.logging.log4j" "log4j-core" "2.22.1"
    update_version "pom.xml" "$ns" "org.apache.logging.log4j" "log4j-api" "2.22.1"
    update_version "pom.xml" "$ns" "org.apache.logging.log4j" "log4j-slf4j-impl" "2.22.1"

# mockito changes
    update_artifact "pom.xml" "$ns" "org.mockito" "mockito-all" "org.mockito" "mockito-core"
    update_version "pom.xml" "$ns" "org.mockito" "mockito-core" "5.14.0"
    update_version_or_add_dependency "pom.xml" "$ns" "org.mockito" "mockito-junit-jupiter" "5.8.0"

# jedis changes
    update_version "pom.xml" "$ns" "redis-clients" "jedis" "5.2.0"

# guava cache changes
    update_version "pom.xml" "$ns" "com.google.guava" "guava" "32.1.2-jre"

# common beans utils
    update_version "pom.xml" "$ns" "commons-beanutils" "commons-beanutils" "1.9.4"

# oyo dependencies
    update_version "pom.xml" "$ns" "com.oyo.platform" "platform-logger" "0.2.0"
    update_version "pom.xml" "$ns" "com.oyo.platform" "pdf-sdk" "0.1.0"
    update_version "pom.xml" "$ns" "com.oyo.platform" "platform-service-discovery" "0.1.0"
    update_version "pom.xml" "$ns" "com.oyo.platform" "platform-encryption" "0.2.0"

    if xmlstarlet sel -N x="$ns" -t -c "//x:project/x:dependencies/x:dependency[x:groupId='com.oyo.platform' and x:artifactId='platform-config-service']" "$pom_file" >/dev/null; then
        delete_dependency "pom.xml" "$ns" "com.oyo.platform" "platform-config-service"
        update_version_or_add_dependency "pom.xml" "$ns" "com.oyo.platform" "platform-config-service-client" "1.1.0"
    fi

# de-duplicating the dependencies:
    xmlstarlet ed --inplace \
      -N x="$ns" \
      -d "//x:project/x:dependencies/x:dependency[position() > 1 and x:groupId=preceding-sibling::x:dependency/x:groupId and x:artifactId=preceding-sibling::x:dependency/x:artifactId]" \
      "$pom_file"
