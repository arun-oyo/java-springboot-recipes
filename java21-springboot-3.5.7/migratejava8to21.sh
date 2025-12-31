#!/bin/bash

# Define versions to update to
JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
PROPERTIES_PATH="./src/main/resources"
TEST_PATH="./src/test/java"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo "SCRIPT_DIR: $SCRIPT_DIR"

##################################  POM changes begin ##################################
echo "Updating pom.xml"
sh "$SCRIPT_DIR/pommigration.sh"
echo "Updated pom.xml"
##################################  POM changes end ##################################



################################## .java files changes begin ###########################
echo "Updating java files"
sh "$SCRIPT_DIR/dotjavamigration.sh"
echo "Updated java files"
################################## .java files changes end ###########################


################################## .properties files changes begin ###########################

echo "Updating properties files"
sh "$SCRIPT_DIR/propertiesmigration.sh"
echo "Properties files updated"
################################## .properties files changes end ###########################


################################## JUnit 4 to 5 migration begin ###########################

echo "Migrating JUnit 4 tests to JUnit 5"
sh "$SCRIPT_DIR/junit4to5migration.sh"
echo "JUnit tests migrated to JUnit 5"
################################## JUnit 4 to 5 migration end ###########################


################################## Repository SaveAll Method Migration ###########################
echo "Changing repository saveAll calls"
sh "$SCRIPT_DIR/repositorysavemigration.sh"
echo "Changed repository saveAll calls"
################################## Repository SaveAll Method Migration End ###########################

################################## Kafka Callback Migration ###########################
echo "Migrating Kafka producer callbacks"
sh "$SCRIPT_DIR/kafkacallbackmigration.sh"
echo "Kafka producer callbacks migrated"
################################## Kafka Callback Migration End ###########################
echo "Java 8 to 21 migration completed!"

################################## Mongodb API Migration ###########################
echo "Migrating MongoDB API usages"
sh "$SCRIPT_DIR/mongodbapimigration.sh"
echo "MongoDB API usages migrated"
################################## Mongodb API Migration End ###########################


################################## Resources Migration ###########################
echo "Migrating resource files"
sh "$SCRIPT_DIR/resourcesmigration.sh"
echo "Resource files migrated"
################################## Resources Migration End ###########################


################################## @Serial Annotation Migration ###########################
echo "Adding @Serial annotations"
sh "$SCRIPT_DIR/serialmigration.sh"
echo "@Serial annotations added"
################################## @Serial Annotation Migration End ###########################
