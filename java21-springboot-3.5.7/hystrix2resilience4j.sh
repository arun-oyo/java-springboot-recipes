#!/bin/bash

JAVA_VERSION=21
SPRING_BOOT_VERSION=3.5.7
CLASS_PATH="./src/main/java"
TEST_PATH="./src/test/java"
PROPERTIES_PATH="./src/main/resources"


insert_line_if_not_exists() {
	local line_number=$1
	local line=$2
	local file=$3

	if ! grep -q "$line" "$file"; then
		sed -i '' "${line_number} i\\
$line
" $file
	fi
}

get_interfaces_list_from_class() {
	local file=$1
	local interfaces

	class_definition=$(awk '
	    BEGIN {definition=""; capture=0}
	    /class / {capture=1}                     # Start capturing when "class" is found
	    capture {
	        definition = definition " " $0;     # Append the current line to "definition"
	        if ($0 ~ /[{]/) {capture=0}         # Stop capturing when "{" is found
	    }
	    END {print definition}                  # Output the captured definition
	' "$file" | tr -d '\n')                     # Remove any newlines

	interfaces=$(echo "$class_definition" | ggrep -oP '(?<=implements\s)[^{]*' | tr -d '\n' | sed 's/, */, /g')
	echo $interfaces
}

update_interfaces() {
	local function_name=$1
	local formal_num_arguments=$2
	local file=$3
	local interface
	# Extract the entire class definition, combining lines until the opening brace '{'
	class_definition=$(awk '
	    BEGIN {definition=""; capture=0}
	    /class / {capture=1}                     # Start capturing when "class" is found
	    capture {
	        definition = definition " " $0;     # Append the current line to "definition"
	        if ($0 ~ /[{]/) {capture=0}         # Stop capturing when "{" is found
	    }
	    END {print definition}                  # Output the captured definition
	' "$file" | tr -d '\n')                     # Remove any newlines


	# Extract the class after `extends`
	extends_class=$(echo "$class_definition" | ggrep -oP '(?<=extends\s)[^\s{]+')

	# Extract the interfaces after `implements`
	interfaces=$(echo "$class_definition" | ggrep -oP '(?<=implements\s)[^{]*' | tr -d '\n' | sed 's/, */, /g')
	if [[ -n "$interfaces" ]]; then
	    IFS=','
	    for interface in $interfaces; do
	        interface=$(echo "$interface" | xargs)
	        echo "Transforming interface: $interface"
	        find "$CLASS_PATH" -type f -name "$interface.java" | while read -r file; do
	        	grep -n "$function_name(" "$file" | cut -d: -f1 | while read -r line_number; do
					contract=$(awk "NR >= $line_number" "$file" | awk '
					    BEGIN {call=""}
					    {
					        call = call " " $0;
					        if ($0 ~ /\);/) { exit }
					    }
					    END { print call }
					' | sed -E 's/^[[:space:]]+|;.*$//g' | tr -d '\n')


					arguments=$(echo "$contract" | ggrep -oP "$function_name\s*\(([^)]*)\)" | ggrep -oP '(?<=\().*(?=\))')

					#echo "interface args: $arguments"

					if [[ -n "$arguments" ]]; then
					    contract_num_arguments=$(echo "$arguments" | awk -F',' '{print NF}')
					else
					    contract_num_arguments=0
					fi


					#echo "formal num args and contract: $formal_num_arguments $contract_num_arguments"
					if [[ "$formal_num_arguments" == "$contract_num_arguments" ]]; then
						#echo "updating interface ------- 1"
		            	return_type=$(sed -n "${line_number}p" "$file"  | xargs | cut -d " " -f 1)
		            	if [[ "$return_type" != "void" ]] && [[ "$return_type" != *"CompletableFuture"* ]]; then
		            		sed -i '' "${line_number}s/${return_type}/CompletableFuture<${return_type}>/" $file
		            		insert_line_if_not_exists "3" "import java.util.concurrent.CompletableFuture;" "$file"
		            	fi
					fi
				done
			done
	    done
	    unset IFS
	fi

}


update_mockito_returns() {
    local ffile="$1"
    local function_name="$2"
    
    echo "Updating Mockito thenReturn and doReturn for function: $function_name in test file: $ffile"
    
    # Handle thenReturn pattern: when(...).thenReturn(value)
    grep -n "thenReturn(" "$ffile" | while read -r return_line; do
        line_num=$(echo "$return_line" | cut -d: -f1)
        line_content=$(echo "$return_line" | cut -d: -f2-)
        
        # Check if this line is related to our function by looking for when() call above it
        context_start=$((line_num - 5))
        if [ $context_start -lt 1 ]; then
            context_start=1
        fi
        
        # Look for when() call with our function in the previous few lines
        when_found=$(sed -n "${context_start},${line_num}p" "$ffile" | grep -c "when.*${function_name}(")
        
        if [ "$when_found" -gt 0 ]; then
            echo "    Found thenReturn at line $line_num for function $function_name"
            
            # Extract the return value from thenReturn(value)
            return_value=$(echo "$line_content" | sed -E 's/.*thenReturn\(([^)]*)\).*/\1/')
            
            # Skip if already wrapped in CompletableFuture
            if [[ "$return_value" != *"CompletableFuture"* ]]; then
                # Replace thenReturn(value) with thenReturn(CompletableFuture.completedFuture(value))
                sed -i '' "${line_num}s/thenReturn(${return_value})/thenReturn(CompletableFuture.completedFuture(${return_value}))/" "$ffile"
                echo "    Updated thenReturn at line $line_num: wrapped '$return_value' with CompletableFuture.completedFuture()"
				insert_line_if_not_exists "3" "import java.util.concurrent.CompletableFuture;" "$ffile"
            fi
        fi
    done
    
    # Handle doReturn pattern: doReturn(value).when(...).method()
    grep -n "doReturn(" "$ffile" | while read -r return_line; do
        line_num=$(echo "$return_line" | cut -d: -f1)
        line_content=$(echo "$return_line" | cut -d: -f2-)
        
        # Check if this line is related to our function by looking for when() call after it
        context_end=$((line_num + 5))
        total_lines=$(wc -l < "$ffile")
        if [ $context_end -gt $total_lines ]; then
            context_end=$total_lines
        fi
        
        # Look for when() call with our function in the next few lines
        when_found=$(sed -n "${line_num},${context_end}p" "$ffile" | grep -c "when.*${function_name}(")
        
        if [ "$when_found" -gt 0 ]; then
            echo "    Found doReturn at line $line_num for function $function_name"
            
            # Extract the return value from doReturn(value)
            return_value=$(echo "$line_content" | sed -E 's/.*doReturn\(([^)]*)\).*/\1/')
            
            # Skip if already wrapped in CompletableFuture
            if [[ "$return_value" != *"CompletableFuture"* ]]; then
                # Replace doReturn(value) with doReturn(CompletableFuture.completedFuture(value))
                sed -i '' "${line_num}s/doReturn(${return_value})/doReturn(CompletableFuture.completedFuture(${return_value}))/" "$ffile"
                echo "    Updated doReturn at line $line_num: wrapped '$return_value' with CompletableFuture.completedFuture()"
				insert_line_if_not_exists "3" "import java.util.concurrent.CompletableFuture;" "$ffile"
            fi
        fi
    done
}

update_caller_util() {
	local line_number=$1
	local ffile=$2
	local function_name=$3
	local formal_num_arguments=$4

	echo "Updating caller at line $line_number in file: $ffile"

	caller=$(awk "NR >= $line_number" "$ffile" | awk -v func_name="$function_name" '
	    BEGIN { call = ""; parens = 0; target_found = 0; caller_def = ""}
	    {
	        for (i = 1; i <= length($0); i++) {
	            char = substr($0, i, 1);
	            call = call char;

	            # Identify the function name and start tracking parentheses
	            if (!target_found && match(call, func_name "\\(")) {
	                target_found = 1;
	                caller_def = func_name
	            }

	            if (target_found) {
	            	if (char == "(") parens++;
	            	if (char == ")") parens--;
	            	caller_def = caller_def char;
	            }

	            # Stop when we find the closing parenthesis for the target function
	            if (target_found && parens == 0) {
	                print caller_def;
	                exit;
	            }
	        }
	    }
	' | tr -d '\n')

	echo "caller: $caller"

	# Extract the arguments
	arguments_actual=$(echo "$caller" | ggrep -oP "$function_name\s*\((\K.*(?=\)))")

	#echo "arguments_actual: $arguments_actual"

	# Count the number of arguments
	if [[ -n "$arguments_actual" ]]; then
	    actual_num_arguments=$(echo "$arguments_actual" | awk -F',' '{print NF}')

	   	commas_in_parentheses=$(echo "$arguments_actual" | awk '
		    BEGIN { parens = 0; comma_count = 0 }
		    {
		        for (i = 1; i <= length($0); i++) {
		            char = substr($0, i, 1);

		            if (char == "(") parens++;
		            if (char == ")") parens--;

		            if (char == "," && parens > 0) comma_count++;
		        }
		    }
		    END { print comma_count }
		')
	   	actual_num_arguments=$((actual_num_arguments - commas_in_parentheses))
	else
	    actual_num_arguments=0
	fi
	local end_line
	if [[ "$formal_num_arguments" == "$actual_num_arguments" ]]; then
		end_line=$(awk -v start="$line_number" -v func_name="$function_name" '
		    BEGIN {call = ""; parens = 0; last_close_pos = 0; line = 0; target_found = 0}
		    NR >= start {
		        for (i = 1; i <= length($0); i++) {
		            char = substr($0, i, 1);
		            call = call char;
		            # Check if the function name appears and track parentheses
		            if (!target_found && match(call, func_name "\\(")) {
		                target_found = 1; # Mark target function as found
		            }

		            if (target_found) {
		            	if (char == "(") parens++;
	            		if (char == ")") parens--;
		            }

		            # Stop when we find the closing parenthesis of the target function
		            if (target_found && parens == 0) {
		                last_close_pos = i;
		                line = NR;
		                print call, line, last_close_pos;
		                exit;
		            }
		        }
		    }
		' "$ffile")
	    # Extract line number and position of the last closing parenthesis
	    end_line_number=$(echo "$end_line" | rev | cut -d" " -f 2 | rev)
	    last_close_pos=$(echo "$end_line" | rev | cut -d" " -f 1 | rev)

	    #echo "endline: $end_line $end_line_number $last_close_pos"

	    if [[ -n "$last_close_pos" ]]; then
	        # Only add .join() for non-test files
	        if [[ "$ffile" != *"/test/"* ]]; then
	        	sed -i '' "${end_line_number}s/\(.\{$last_close_pos\}\)/\1.join()/" "$ffile"
	        else
	            # Handle test files with Mockito mocks
	            update_mockito_returns "$ffile" "$function_name"
	        fi
	    fi
	fi
}


update_caller() {
	local ffile=$1
	local target_var_name=$2
	local function_name=$3
	local formal_num_arguments=$4

	echo "Updating callers in file: $ffile for variable: $target_var_name and function: $function_name"

	awk -v target_var="$target_var_name" -v func_name="$function_name" '
	{
        if (match($0, target_var "$")) {
            next_line = getline;
            if (next_line && $0 ~ func_name "\\(") {
                print NR;
            }
        }
	}
	' "$ffile" | while read -r line_number; do
		echo "Updating caller at line $line_number in file: $ffile"
		update_caller_util "$line_number" "$ffile" "$function_name" "$formal_num_arguments"
	done

	echo "Checking for direct calls to $target_var_name $function_name in file: $ffile"
    grep -n "$target_var_name\.$function_name(" "$ffile" | cut -d: -f1 | while read -r line_number; do
		echo "Updating direct caller at line $line_number in file: $ffile with formal arguments: $formal_num_arguments"
		update_caller_util "$line_number" "$ffile" "$function_name" "$formal_num_arguments"
	done
}


update_callers() {
	local target_file=$1
	local start_line=$2
	local target_class_name
	local target_var_name

	echo "Starting updating callers:::: "


	function_header=$(awk -v start="$start_line" '
	    NR >= start {
	    	if (!target_found && match($0, "public")) {
	    		target_found = 1;
	    	}
	    	if (target_found) {
	        	header = header " " $0; 
	        	if ($0 ~ /[{]/) {
	        		print header;
	        		exit;
	        	}
	        }
	    }
	' "$target_file" | tr -d '\n')

	# Extract the function name
	function_name=$(echo "$function_header" | cut -d"(" -f 1 | rev | cut -d" " -f 1 | rev)

	if [[ -z "$function_name" ]]; then
		return 0
	fi


	#echo  "----- update callers function_header: $function_header"
	# Extract arguments
	arguments=$(echo "$function_header" | ggrep -oP '\(.*\)' | ggrep -oP '(?<=\().*(?=\))')

	arguments=$(echo "$arguments" | sed -E 's/<[^>]*>//g')

	#echo  "----- update callers arguments: $arguments"
	# Count the number of arguments
	if [[ -n "$arguments" ]]; then
	    formal_num_arguments=$(echo "$arguments" | awk -F',' '{print NF}')
	else
	    formal_num_arguments=0
	fi

	update_interfaces "$function_name" "$formal_num_arguments" "$target_file"


	target_class_name=$(basename "$target_file" ".java")

	interfaces_list=$(get_interfaces_list_from_class "$target_file")

	#echo "function_name::::: $function_name"
	grep -rl "\.$function_name(" $CLASS_PATH $TEST_PATH | while read -r ffile; do
		if [[ "$(basename "$target_file")" == "$(basename "$ffile")" ]] ; then
			echo "In the same file: $ffile"
		fi
		target_var_name=$(perl -ne '
			next if /^\s*import/;
			if (/\b'"$target_class_name"'\b\s+(\w+)\s*(=|;)/) {
				print $1;
				exit;
			}
			' "$ffile")

		if [[ -z "$target_var_name" ]]; then
			continue
		fi
		#echo "target class name ------- $target_class_name, $target_var_name"
		update_caller "$ffile" "$target_var_name" "$function_name" "$formal_num_arguments"
	done

	if [[ -n "$interfaces_list" ]]; then
	    IFS=','
	    for interface in $interfaces_list; do
	    	#echo "interface------ $interface"
	    	grep -rl "\.$function_name(" $CLASS_PATH $TEST_PATH | while read -r ffile; do
				if [[ "$(basename "$target_file")" == "$(basename "$ffile")" ]] ; then
					echo "In the same file: $ffile"
				fi
				target_var_name=$(perl -ne '
					next if /^\s*import/;
					if (/\b'"$interface"'\b\s+(\w+)\s*(=|;)/) {
						print $1;
						exit;
					}
					' "$ffile")

				if [[ -z "$target_var_name" ]]; then
					continue
				fi
				update_caller "$ffile" "$target_var_name" "$function_name" "$formal_num_arguments"
			done
	    done
	fi
	echo "Updated callers "
}


add_resilience_property() {
	local property=$1
	local value=$2

	if [[ -z "$value" ]]; then
		return 1
	fi

    local file
	local filepattern
	for file in $(grep -rl "hystrix.command" "$PROPERTIES_PATH"); do
	    if [[ "$file" == *"hystrix"* ]]; then
	        filepattern="hystrix*.properties"
	    else
	        filepattern="application*.properties"
	    fi
	    break
	done

	for file in $PROPERTIES_PATH/$filepattern; do
	    if [[ -e "$file" ]]; then
	        sed -i '' "/${property}/d" "$file"
	        if [[ -n $(tail -c1 "$file") ]]; then
                echo "" >> "$file"
            fi
	        echo "${property}=${value}" >> "$file"
	    else
	        echo "No files found matching the pattern 'application*.properties'."
	        break
	    fi
	done
}


add_ignore_exception() {
	local exceptions=$1
	local file=$2
	local commandKey=$3
	IFS=',' read -ra exceptions_array <<< "$exceptions"
	local final_result=""
	for exception in "${exceptions_array[@]}"; do
    	trimmed_exception=$(echo "$exception" | xargs)
    	exception_prefix=$(echo $trimmed_exception | cut -d "." -f 1)
    	matched_line=$(grep -E "import.*${exception_prefix}.*" "$file")
    	exception_without_class=${trimmed_exception%.class}
	    modified_exception=$(echo "$exception_without_class" | sed 's/\./\$/g')
	    if [[ -n $matched_line ]]; then
	       result=$(echo "$matched_line" | sed -E 's/^import (.*);/\1/' | sed -E "s/${exception_prefix}/${modified_exception}/")
	       final_result+="$result,"
	       sed -i '' "/${matched_line}/d" "$file"
	    else
	       final_result+="java.lang.$modified_exception,"
	    fi
	done
	final_result=$(echo "$final_result" | sed 's/,$//')
	add_resilience_property "resilience4j.circuitbreaker.instances.$commandKey.ignore-exceptions" "$final_result"
}


hystrix_get_or_default() {
	local property=$1
	local default_property=$2
	local file=$3

	propertyMatched=$(grep -E "${property}" "$file")
	if [[ -z "$propertyMatched" ]]; then
		propertyMatched=$(grep -E "${default_property}" "$file")
	fi
	echo "$propertyMatched"
}


finalize_resilience_bulkhead_properties() {
	local coreSize=$1
	local maximumSize=$2
	local maxQueueSize=$3
	local threadPoolKey=$4

	local file
	local filepattern
	for file in $(grep -rl "hystrix.command" "$PROPERTIES_PATH"); do
	    if [[ "$file" == *"hystrix"* ]]; then
	        filepattern="hystrix*.properties"
	    else
	        filepattern="application*.properties"
	    fi
	    break
	done

	hystrixCPProperty="hystrix.threadpool.$threadPoolKey.coreSize"
	hystrixCPDefaultProperty="hystrix.threadpool.default.coreSize"

	hystrixMPProperty="hystrix.threadpool.$threadPoolKey.maximumSize"
	hystrixMPDefaultProperty="hystrix.threadpool.default.maximumSize"

	hystrixQSProperty="hystrix.threadpool.$threadPoolKey.maxQueueSize"
	hystrixQSDefaultProperty="hystrix.threadpool.default.maxQueueSize"

	resilience4jCPProperty="resilience4j.thread-pool-bulkhead.instances.$threadPoolKey.core-thread-pool-size"
	resilience4jMPProperty="resilience4j.thread-pool-bulkhead.instances.$threadPoolKey.max-thread-pool-size"
	resilience4jQSProperty="resilience4j.thread-pool-bulkhead.instances.$threadPoolKey.queue-capacity"

	for file in $PROPERTIES_PATH/$filepattern; do
	    hystrixCPPropertyMatched=$(hystrix_get_or_default "$hystrixCPProperty" "$hystrixCPDefaultProperty" "$file")
	    corePoolSize=10

	    if [[ -z "$hystrixCPPropertyMatched" ]]; then
	    	resilience4jCPPropertyMatched=$(grep -E "${resilience4jCPProperty}" "$file")
	    	if [[ -n "$resilience4jCPPropertyMatched" ]]; then
	    		corePoolSize=$(echo $resilience4jCPPropertyMatched | cut -d "=" -f 2-)
	        	if [[ -z "$corePoolSize" ]]; then
	        		corePoolSize=$(echo $resilience4jCPPropertyMatched | cut -d ":" -f 2-)
	        	fi
	        fi
	    	if [[ -n $(tail -c1 "$file") ]]; then
                echo "" >> "$file"
            fi

            sed -i '' "/${resilience4jCPProperty}/d" "$file"
            echo "${resilience4jCPProperty}=${corePoolSize}" >> "$file"
        else
        	corePoolSize=$(echo $hystrixCPPropertyMatched | cut -d "=" -f 2-)
        	if [[ -z "$corePoolSize" ]]; then
        		corePoolSize=$(echo $hystrixCPPropertyMatched | cut -d ":" -f 2-)
        	fi
        	sed -i '' "/${resilience4jCPProperty}/d" "$file"
        	sed -i '' "s/${hystrixCPProperty}/${resilience4jCPProperty}/" "$file"
        fi


        maxPoolSize=$corePoolSize
        hystrixMPPropertyMatched=$(hystrix_get_or_default "$hystrixMPProperty" "$hystrixMPDefaultProperty" "$file")
        if [[ -z "$hystrixMPPropertyMatched" ]]; then

        	resilience4jMPPropertyMatched=$(grep -E "${resilience4jMPProperty}" "$file")
	    	if [[ -n "$resilience4jMPPropertyMatched" ]]; then
	    		maxPoolSize=$(echo $resilience4jMPPropertyMatched | cut -d "=" -f 2-)
	        	if [[ -z "$corePoolSize" ]]; then
	        		maxPoolSize=$(echo $resilience4jMPPropertyMatched | cut -d ":" -f 2-)
	        	fi
	        fi

        	if [[ -n $(tail -c1 "$file") ]]; then
                echo "" >> "$file"
            fi
            sed -i '' "/${resilience4jMPProperty}/d" "$file"
            echo "${resilience4jMPProperty}=${maxPoolSize}" >> "$file"
        else
        	sed -i '' "/${resilience4jMPProperty}/d" "$file"
        	sed -i '' "s/${hystrixMPProperty}/${resilience4jMPProperty}/" "$file"
        fi

        sed -i '' "s/${hystrixQSProperty}/${resilience4jQSProperty}/" "$file"
	done
}


finalize_resilience_timelimiter_properties() {
	local commandKey=$1

	local file
	local filepattern
	for file in $(grep -rl "hystrix.command" "$PROPERTIES_PATH"); do
	    if [[ "$file" == *"hystrix"* ]]; then
	        filepattern="hystrix*.properties"
	    else
	        filepattern="application*.properties"
	    fi
	    break
	done

	hystrixTOProperty="hystrix.command.$commandKey.execution.isolation.thread.timeoutInMilliseconds"
	hystrixTODefaultProperty="hystrix.command.default.execution.isolation.thread.timeoutInMilliseconds"

	hystrixCFProperty="hystrix.command.$commandKey.execution.isolation.thread.interruptOnTimeout"
	hystrixCFDefaultProperty="hystrix.command.default.execution.isolation.thread.interruptOnTimeout"

	resilience4jTOProperty="resilience4j.timelimiter.instances.$commandKey.timeout-duration"
	resilience4jCFProperty="resilience4j.timelimiter.instances.$commandKey.cancel-running-future"

	for file in $PROPERTIES_PATH/$filepattern; do
		hystrixTOPropertyMatched=$(hystrix_get_or_default "$hystrixTOProperty" "$hystrixTODefaultProperty" "$file")
		if [[ -n "$hystrixTOPropertyMatched" ]]; then
	    	sed -i '' "/${resilience4jTOProperty}/d" "$file"
	    fi
	    sed -i '' "s/${hystrixTOProperty}/${resilience4jTOProperty}/" "$file"

	    hystrixCFPropertyMatched=$(hystrix_get_or_default "$hystrixCFProperty" "$hystrixCFDefaultProperty" "$file")
		if [[ -n "$hystrixCFPropertyMatched" ]]; then
	    	sed -i '' "/${resilience4jCFProperty}/d" "$file"
	    fi
	    sed -i '' "s/${hystrixCFProperty}/${resilience4jCFProperty}/" "$file"
	done
}


finalize_resilience_circuitbreaker_properties() {
	local commandKey=$1

	local file
	local filepattern
	for file in $(grep -rl "hystrix.command" "$PROPERTIES_PATH"); do
	    if [[ "$file" == *"hystrix"* ]]; then
	        filepattern="hystrix*.properties"
	    else
	        filepattern="application*.properties"
	    fi
	    break
	done

	hystrixRVProperty="hystrix.command.$commandKey.circuitBreaker.requestVolumeThreshold"
	hystrixRVDefaultProperty="hystrix.command.default.circuitBreaker.requestVolumeThreshold"

	hystrixSWProperty="hystrix.command.$commandKey.circuitBreaker.sleepWindowInMilliseconds"
	hystrixSWDefaultProperty="hystrix.command.default.circuitBreaker.sleepWindowInMilliseconds"

	hystrixETProperty="hystrix.command.$commandKey.circuitBreaker.errorThresholdPercentage"
	hystrixETDefaultProperty="hystrix.command.default.circuitBreaker.errorThresholdPercentage"

	resilience4jRVProperty="resilience4j.circuitbreaker.instances.$commandKey.minimum-number-of-calls"
	resilience4jSWProperty="resilience4j.circuitbreaker.instances.$commandKey.wait-duration-in-open-state"
	resilience4jETProperty="resilience4j.circuitbreaker.instances.$commandKey.failure-rate-threshold"

	for file in $PROPERTIES_PATH/$filepattern; do
		hystrixRVPropertyMatched=$(hystrix_get_or_default "$hystrixRVProperty" "$hystrixRVDefaultProperty" "$file")
		if [[ -n "$hystrixRVPropertyMatched" ]]; then
	    	sed -i '' "/${resilience4jRVProperty}/d" "$file"
	    fi
	    sed -i '' "s/${hystrixRVProperty}/${resilience4jRVProperty}/" "$file"

	    hystrixSWPropertyMatched=$(hystrix_get_or_default "$hystrixSWProperty" "$hystrixSWDefaultProperty" "$file")
		if [[ -n "$hystrixSWPropertyMatched" ]]; then
	    	sed -i '' "/${resilience4jSWProperty}/d" "$file"
	    fi
	    sed -i '' "s/${hystrixSWProperty}/${resilience4jSWProperty}/" "$file"

	    hystrixETPropertyMatched=$(hystrix_get_or_default "$hystrixETProperty" "$hystrixETDefaultProperty" "$file")
		if [[ -n "$hystrixETPropertyMatched" ]]; then
	    	sed -i '' "/${resilience4jETProperty}/d" "$file"
	    fi
	    sed -i '' "s/${hystrixETProperty}/${resilience4jETProperty}/" "$file"
	done
}


update_return_type() {
	local method_start_line=$1
	local file=$2
	local function_name=$3
	echo "update_return_type args: $method_start_line, $file, $function_name"
	method_range=$(awk -v start="$method_start_line" -v func_name="$function_name" '
	BEGIN {target_found=0; method_start=0; parens=0; call=""; method_found=0; in_multiline_comment=0}
	NR > start {
		if (in_multiline_comment) {
	        if ($0 ~ /\*\//) in_multiline_comment = 0;
	        next;
	    }

	    if ($0 ~ /^\s*\/\//) next;

	    if ($0 ~ /\/\*/) {
	        in_multiline_comment = 1;
	        next;
	    }
        for (i = 1; i <= length($0); i++) {
        	char = substr($0, i, 1);
        	call = call char

        	if (!method_found && match(call, func_name "\\(")) {
        		method_found = 1;
        		method_start = NR;
        	}

        	if (method_found && char == "{") {
        		target_found = 1;
	        }

	        if (target_found) {
	        	if (char == "{") parens++;
	        	if (char == "}") parens--;
	        }
            
            if (target_found && parens == 0) {
                print method_start, NR;
                exit;
            }
        }
	}
	' "$file")

	echo "Method range: $method_range"
	meth_start=$(echo $method_range | cut -d' ' -f1)
	meth_end=$(echo $method_range | cut -d' ' -f2)
	sed -n "${meth_start},${meth_end}p" "$file"

	awk -v start="$meth_start" -v end="$meth_end" '
	BEGIN {in_multiline_comment=0}
	NR >= start && NR <= end {
		line = $0;
	    gsub(/^[ \t]+|[ \t]+$/, "", line);
	    if (line ~ /return/) {

	    	if (in_multiline_comment) {
		        if (line ~ /\*\//) in_multiline_comment = 0;
		        next;
		    }

		    if (line ~ /^\s*\/\//) next;

		    if (line ~ /\/\*/) {
		        in_multiline_comment = 1;
		        next;
		    }

	        return_start = NR;            
	        statement = line;             
	        while (statement !~ /;/) {    
	            getline;                  
	            gsub(/^[ \t]+|[ \t]+$/, "", $0); 
	            statement = statement " " $0;    
	        }
	        return_end = NR;                     
	        print return_start, return_end;
	    }
	}
	' "$file" | while read return_range; do
					echo "return_range inside: $return_range"
					return_start=$(echo $return_range | cut -d' ' -f1)
					return_end=$(echo $return_range | cut -d' ' -f2)
					return_line=$(sed -n "${return_start}p" "$file")
					if [[ "$return_line" != *"return CompletableFuture"* ]]; then
						sed -i '' "${return_start}s/return[[:space:]]*/return CompletableFuture.completedFuture(/" "$file"
						sed -i '' "${return_end}s/;/);/" "$file"
					fi
				done
}


profile_specific_hystrix_props_file=$(grep -rl "hystrix.command" "./src/main/resources" | grep "hystrix-" | wc -l | xargs)

# HystrixCommand annotation changes - Hystrix -> Resilience4j
echo "Transforming HystrixCommand annotations"
grep -rl "HystrixCommand" "$CLASS_PATH" | while read -r file; do
	echo "Processing HystrixCommand for file: $file"

	class_name=$(basename "$file" ".java")
	is_interface=$(grep "interface $class_name" "$file")
	if [[ -n "$is_interface" ]]; then
		echo "Skipping the interface"
		continue
	fi


	sed -i '' '/import[[:space:]\n]*com.netflix.hystrix/d' "$file"
	insert_line_if_not_exists "3" "import io.github.resilience4j.bulkhead.annotation.Bulkhead;" "$file"
	insert_line_if_not_exists "3" "import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;" "$file"
	insert_line_if_not_exists "3" "import io.github.resilience4j.timelimiter.annotation.TimeLimiter;" "$file"
	insert_line_if_not_exists "3" "import java.util.concurrent.CompletableFuture;" "$file"

	while :; do
	    line=$(awk '
		/@HystrixCommand/ {start=1; output=$0; paren_count+=gsub(/\(/, "(") - gsub(/\)/, ")"); next}
		start {
		    output = output "\n" $0;
		    paren_count += gsub(/\(/, "(") - gsub(/\)/, ")");
		    if (paren_count == 0) {print output; exit}
		}
		' "$file" | tr '\n' ' ')


	    if [ -z "$line" ]; then
            break
        fi

        if echo "$line" | xargs | grep -q "^//"; then
        	echo "$line"
		    echo "The line starts with //"
		    sed -i '' 's|^//[[:space:]]*@HystrixCommand|//    @ResilienceChanges|' $file
		    continue
		fi

	    echo "Annotation: $line"
	    
	    fallback=$(echo "$line" | ggrep -Po 'fallbackMethod\s*=\s*"\K[^"]*')
	    commandKey=$(echo "$line" | ggrep -Po 'commandKey\s*=\s*"\K[^"]*')
	    if [[ -z "$commandKey" ]]; then
	    	commandKey=$(echo "$line" | ggrep -Po 'commandKey\s*=\s*(?:"[^"]*"|[^\s,)]*)' | ggrep -Po '(?<=\=\s)(.*)')
	    	strConstant=$(echo "$commandKey" | rev | cut -d"." -f 1 | rev)
	    	commandKey=$(grep -rE "String[[:space:]]+${strConstant}[[:space:]]*=[[:space:]]*\"[^\"]*\";" "$CLASS_PATH" | head -n 1 | cut -d "=" -f 2 | cut -d";"  -f 1 | xargs)
	    fi
	    threadPoolKey=$(echo "$line" | ggrep -Po 'threadPoolKey\s*=\s*"\K[^"]*')
	    if [[ -z "$threadPoolKey" ]]; then
	    	threadPoolKey=$(echo "$line" | ggrep -Po 'threadPoolKey\s*=\s*(?:"[^"]*"|[^\s,)]*)' | ggrep -Po '(?<=\=\s)(.*)')
	    	if [[ -n "$threadPoolKey" ]]; then
	    		strConstant=$(echo "$threadPoolKey" | rev | cut -d"." -f 1 | rev)
	    		threadPoolKey=$(grep -rE "String[[:space:]]+${strConstant}[[:space:]]*=[[:space:]]*\"[^\"]*\";" "$CLASS_PATH" | head -n 1 | cut -d "=" -f 2 | cut -d";"  -f 1 | xargs)
	    	else
		    	threadPoolKey=$commandKey"_ThreadPool"
		    fi
	    fi

	    echo "commandKey-- $commandKey, threadPoolKey-- $threadPoolKey"
	    
	    requestVolumeThreshold=$(echo "$line" | ggrep -Po 'name\s*=\s*"circuitBreaker.requestVolumeThreshold",\s*value\s*=\s*"\K[^"]*')
	    sleepWindowInMilliseconds=$(echo "$line" | ggrep -Po 'name\s*=\s*"circuitBreaker.sleepWindowInMilliseconds",\s*value\s*=\s*"\K[^"]*')
	    errorThresholdPercentage=$(echo "$line" | ggrep -Po 'name\s*=\s*"circuitBreaker.errorThresholdPercentage",\s*value\s*=\s*"\K[^"]*')
	    ignoreExceptions=$(echo "$line" | ggrep -Po 'ignoreExceptions\s*=\s*\{\K[^\}]*')

	    timeoutMs=$(echo "$line" | ggrep -Po 'name\s*=\s*"execution.isolation.thread.timeoutInMilliseconds",\s*value\s*=\s*"\K[^"]*')
	    interruptOnTimeout=$(echo "$line" | ggrep -Po 'name\s*=\s*"execution.isolation.thread.interruptOnTimeout",\s*value\s*=\s*"\K[^"]*')

	    coreSize=$(echo "$line" | ggrep -Po 'name\s*=\s*"coreSize",\s*value\s*=\s*"\K[^"]*')
	    maximumSize=$(echo "$line" | ggrep -Po 'name\s*=\s*"maximumSize",\s*value\s*=\s*"\K[^"]*')
	    maxQueueSize=$(echo "$line" | ggrep -Po 'name\s*=\s*"maxQueueSize",\s*value\s*=\s*"\K[^"]*')
        
        if [[ -n "$fallback" ]]; then
        	r4jCircuitBreaker="@CircuitBreaker(name = \"$commandKey\", fallbackMethod = \"$fallback\")"
        else
        	r4jCircuitBreaker="@CircuitBreaker(name = \"$commandKey\")"
        fi
        r4jTimeLimiter="@TimeLimiter(name = \"$commandKey\")"
        r4jBulkhead="@Bulkhead(name = \"$threadPoolKey\", type = Bulkhead.Type.THREADPOOL)"

		awk '
		/@HystrixCommand/ { 
		    start = NR;                                # Record the starting line number
		    paren_count += gsub(/\(/, "(") - gsub(/\)/, ")");  # Adjust parentheses count
		    if (paren_count == 0) {                   # Single-line case
		        print start "," start;                # Output the single-line range
		        exit;
		    }
		    next;
		}
		start && paren_count > 0 {
		    paren_count += gsub(/\(/, "(") - gsub(/\)/, ")");  # Continue tracking parentheses
		    if (paren_count == 0) {                   # Multiline case when balanced
		        print start "," NR;                   # Output the range
		        exit;
		    }
		}
		' "$file" | while read range; do
            start_line=$(echo $range | cut -d',' -f1)
            end_line=$(echo $range | cut -d',' -f2)

            # return_type=$(awk -v start="$end_line" '
			#     NR > start {
			# 	    if ($0 ~ /public/) {                     # Check for the keyword 'public'
			# 	        split($0, tokens, " ");              # Split the line into tokens using spaces
			# 	        for (i = 1; i <= length(tokens); i++) {
			# 	            if (tokens[i] == "public") {     # Find the 'public' keyword
			# 	                print tokens[i + 1];         # Print the word after 'public' (the return type)
			# 	                exit;                        # Exit after finding the first match
			# 	            }
			# 	        }
			# 	    }
			# 	}
			#     ' "$file")


			function_header=$(awk -v start="$end_line" '
			    NR > start {
			    	if (!target_found && match($0, "public")) {
			    		target_found = 1;
			    	}
			    	if (target_found) {
			        	header = header " " $0; 
			        	if ($0 ~ /[(]/) {
			        		print header;
			        		exit;
			        	}
			        }
			    }
			' "$file" | tr -d '\n')


			#echo "function header: $function_header"
			# Extract the function name
			function_name=$(echo "$function_header" | cut -d"(" -f 1 | rev | cut -d" " -f 1 | rev)

			method_line=$(awk -v start="$end_line" 'NR > start && /public/ {print NR; exit}' "$file")

			method_public_line=$(awk -v start="$end_line" 'NR > start && /public/ {print $0; exit}' "$file")

			#echo "method_line: $method_public_line"
			#echo "return line: $(sed -n "${method_line}p" "$file")"
			#echo "function_name: $function_name"
			return_type=$(sed -n "${method_line}p" "$file" | ggrep -oP "(?<=public).*(?=${function_name}\()" | xargs)

			#echo "return type: $return_type"

            fallback_method_start_lines=$(grep -nE "$return_type[[:space:]]+$fallback\(" "$file")
            if [[ "$return_type" == "void" ]]; then
            	echo "return type is void: not encapsulating in CompletableFuture"
            elif [[ "$return_type" == *"CompletableFuture"* ]]; then
            	echo "seems return type is already encapsulated in CompletableFuture"
            else
			    sed -i '' "${method_line}s/public ${return_type}/public CompletableFuture<${return_type}>/" "$file"
			    if [[ -n "$fallback" ]]; then
			    	sed -i '' "s/${return_type}[[:space:]]*${fallback}(/CompletableFuture<${return_type}> ${fallback}(/" "$file"
			    fi
			    update_return_type "$end_line" "$file" "$function_name"
			    update_callers "$file" "$method_line"
			    if [[ -n "$fallback_method_start_lines" ]]; then
					echo "$fallback_method_start_lines" | while read -r fallback_line_start; do
						#echo "updating fallback method returns: $fallback -- $fallback_line_start"
						fallback_line_start_line_number=$(echo $fallback_line_start | cut -d':' -f1)
						update_return_type "$((fallback_line_start_line_number - 1))" "$file" "$fallback"
					done
				fi
			fi

            sed -i '' "${range}d" $file
            sed -i '' "$((start_line)) i\\
" $file
			if [[ "$return_type" != "void" ]]; then
            	sed -i '' "$((start_line)) i\\
    $r4jBulkhead
        " $file
           		sed -i '' "$((start_line)) i\\
    $r4jTimeLimiter
        " $file
            	sed -i '' "$((start_line)) i\\
    $r4jCircuitBreaker
        " $file
        	fi
        done

        add_resilience_property "resilience4j.thread-pool-bulkhead.instances.$threadPoolKey.core-thread-pool-size" $coreSize
        add_resilience_property "resilience4j.thread-pool-bulkhead.instances.$threadPoolKey.max-thread-pool-size" $maximumSize
        add_resilience_property "resilience4j.thread-pool-bulkhead.instances.$threadPoolKey.queue-capacity" $maxQueueSize

        add_resilience_property "resilience4j.timelimiter.instances.$commandKey.timeout-duration" $timeoutMs
        add_resilience_property "resilience4j.timelimiter.instances.$commandKey.cancel-running-future" $interruptOnTimeout

        add_resilience_property "resilience4j.circuitbreaker.instances.$commandKey.minimum-number-of-calls" $requestVolumeThreshold
        add_resilience_property "resilience4j.circuitbreaker.instances.$commandKey.wait-duration-in-open-state" $sleepWindowInMilliseconds
        add_resilience_property "resilience4j.circuitbreaker.instances.$commandKey.failure-rate-threshold" $errorThresholdPercentage

        add_ignore_exception "$ignoreExceptions" "$file" "$commandKey"

        finalize_resilience_bulkhead_properties "$coreSize" "$maximumSize" "$maxQueueSize" "$threadPoolKey"
        finalize_resilience_timelimiter_properties "$commandKey"
        finalize_resilience_circuitbreaker_properties "$commandKey"
	done
done


if [[ -f "$PROPERTIES_PATH/hystrix.properties" ]]; then
	if [[ ! -f "$PROPERTIES_PATH/application.properties" ]]; then
		touch "$PROPERTIES_PATH/application.properties"
	fi

	if [[ -n $(tail -c1 "$PROPERTIES_PATH/application.properties") ]]; then
        echo "" >> "$PROPERTIES_PATH/application.properties"
    fi
    sed -i '' "/spring.config.import/d" "$PROPERTIES_PATH/application.properties"
    echo "spring.config.import=classpath:hystrix.properties" >> "$PROPERTIES_PATH/application.properties"
fi


if ((profile_specific_hystrix_props_file > 0)); then
	for file in $PROPERTIES_PATH/application-*.properties; do
		if [[ "$file" != *"application-default.properties"* ]]; then
			if [[ -n $(tail -c1 "$file") ]]; then
	        	echo "" >> "$file"
		    fi
		    sed -i '' "/spring.config.import/d" "$file"
		    echo 'spring.config.import=classpath:hystrix-${spring.profiles.active}.properties' >> "$file"
		fi
	done

fi
