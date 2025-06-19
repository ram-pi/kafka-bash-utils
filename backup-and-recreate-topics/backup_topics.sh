#!/bin/bash

# Initialize variables
DEBUG=false
BOOTSTRAP_SERVER="localhost:9092"
COMMAND_CONFIG=""

# Check if kafka-topics.sh is available
if ! command -v kafka-topics.sh &> /dev/null; then
    echo "Error: kafka-topics.sh is not available. Please ensure Kafka tools are installed and in your PATH"
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG=true
            shift
            ;;
        --bootstrap-server)
            BOOTSTRAP_SERVER="$2"
            shift 2
            ;;
        --command-config)
            COMMAND_CONFIG="$2"
            shift 2
            ;;
        *)
            if [ -z "$TOPICS_FILE" ]; then
                TOPICS_FILE=$1
            elif [ -z "$OUTPUT_FILE" ]; then
                OUTPUT_FILE=$1
            fi
            shift
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$TOPICS_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: $0 [--debug] [--bootstrap-server <server:port>] [--command-config <config-file>] <topics_file> <output_file>"
    echo "Example: $0 topics.txt backup.json"
    echo "Example with debug: $0 --debug topics.txt backup.json"
    echo "Example with custom server: $0 --bootstrap-server myserver:9092 topics.txt backup.json"
    echo "Example with command config: $0 --bootstrap-server myserver:9092 --command-config client.properties topics.txt backup.json"
    exit 1
fi

# Check if the topics file exists
if [ ! -f "$TOPICS_FILE" ]; then
    echo "Error: Topics file '$TOPICS_FILE' not found"
    exit 1
fi

# Check if command config file exists if provided
if [ ! -z "$COMMAND_CONFIG" ] && [ ! -f "$COMMAND_CONFIG" ]; then
    echo "Error: Command config file '$COMMAND_CONFIG' not found"
    exit 1
fi

# Create or clear the output file
echo "{" > "$OUTPUT_FILE"
echo "  \"topics\": [" >> "$OUTPUT_FILE"

# Function to get topic configuration
get_topic_config() {
    local topic=$1
    local cmd="kafka-topics.sh --bootstrap-server \"$BOOTSTRAP_SERVER\" --describe --topic \"$topic\""
    
    # Add command config if provided
    if [ ! -z "$COMMAND_CONFIG" ]; then
        cmd="$cmd --command-config \"$COMMAND_CONFIG\""
    fi
    
    eval "$cmd" 2>/dev/null
}

# Function to print debug information
print_debug() {
    if [ "$DEBUG" = true ]; then
        echo "$1"
    fi
}

# Process each topic in the file
first_topic=true
while IFS= read -r topic || [ -n "$topic" ]; do
    # Skip empty lines and comments
    [[ -z "$topic" || "$topic" =~ ^[[:space:]]*# ]] && continue
    
    # Remove any leading/trailing whitespace
    topic=$(echo "$topic" | xargs)
    
    echo "Processing topic: $topic"
    
    # Get current topic configuration
    config=$(get_topic_config "$topic")
    if [ -z "$config" ]; then
        echo "Error: Could not get configuration for topic $topic"
        continue
    fi
    
    # Extract topic information from the first line
    topic_info=$(echo "$config" | head -n 1)
    
    # Extract topic name
    topic_name=$(echo "$topic_info" | awk -F'\t' '{print $1}' | awk '{print $2}')
    
    # Extract partition count and replication factor
    partition_count=$(echo "$topic_info" | grep -o "PartitionCount: [0-9]*" | awk '{print $2}')
    replication_factor=$(echo "$topic_info" | grep -o "ReplicationFactor: [0-9]*" | awk '{print $2}')
    
    # Extract configs
    configs=$(echo "$topic_info" | awk -F'Configs: ' '{print $2}')
    
    # Print debug information
    print_debug "Debug - Topic info: $topic_info"
    print_debug "Debug - Partition count: $partition_count"
    print_debug "Debug - Replication factor: $replication_factor"
    print_debug "Debug - Configs: $configs"
    
    # Convert configs to JSON format
    config_json=""
    if [ ! -z "$configs" ]; then
        config_json=$(echo "$configs" | tr ',' '\n' | while IFS='=' read -r key value; do
            echo "      \"$key\": \"$value\""
        done | paste -sd "," -)
    fi
    
    # Add comma if not the first topic
    if [ "$first_topic" = true ]; then
        first_topic=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi
    
    # Write topic configuration to output file
    cat << EOF >> "$OUTPUT_FILE"
    {
      "name": "$topic_name",
      "partition_count": $partition_count,
      "replication_factor": $replication_factor,
      "configs": {
        $config_json
      }
    }
EOF
    
done < "$TOPICS_FILE"

# Close the JSON structure
echo "  ]" >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

echo "Backup completed. Results saved to $OUTPUT_FILE" 