#!/usr/bin/env bash

# Help function
show_help() {
    echo "Usage: $0 [bootstrap-server] [command-config]"
    echo ""
    echo "This script checks Kafka topics for their replication factor and min.insync.replicas settings."
    echo "It will warn if the difference between these values is not 1 and suggest fixes."
    echo ""
    echo "Parameters:"
    echo "  bootstrap-server    Kafka bootstrap server (default: localhost:9092)"
    echo "  command-config     Optional Kafka admin client configuration file (e.g., admin.properties)"
    echo ""
    echo "Examples:"
    echo "  $0                              # Use default localhost:9092"
    echo "  $0 kafka1:9092                 # Use custom bootstrap server"
    echo "  $0 kafka1:9092 admin.properties # Use custom bootstrap server and command config"
    echo ""
    echo "The script will:"
    echo "  1. Check all topics in the cluster"
    echo "  2. Verify replication factor and min.insync.replicas settings"
    echo "  3. Warn if the difference is not 1"
    echo "  4. Suggest fixes for topics where the difference is greater than 1"
    echo "  5. Optionally apply the suggested fixes"
    exit 0
}

# Show help if requested
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_help
fi

# Default bootstrap server
BOOTSTRAP_SERVER=${1:-"localhost:9092"}
COMMAND_CONFIG=${2:-""}

# Check if Kafka topics CLI is available
if ! command -v kafka-topics &> /dev/null; then
    echo "Error: kafka-topics command not found. Please ensure Kafka CLI tools are installed."
    exit 1
fi

# Create a temporary file for alter commands
ALTER_COMMANDS_FILE=$(mktemp)
echo "#!/usr/bin/env bash" > "$ALTER_COMMANDS_FILE"
echo "# This file contains commands to fix min.insync.replicas settings" >> "$ALTER_COMMANDS_FILE"
echo "" >> "$ALTER_COMMANDS_FILE"

# Get all topics description
if [ -n "$COMMAND_CONFIG" ]; then
    topics_info=$(kafka-topics --describe --bootstrap-server "$BOOTSTRAP_SERVER" --command-config "$COMMAND_CONFIG")
else
    topics_info=$(kafka-topics --describe --bootstrap-server "$BOOTSTRAP_SERVER")
fi

# Process each topic's information
echo "$topics_info" | while read -r line; do
    # Skip empty lines and partition information lines
    if [ -z "$line" ] || [[ "$line" == *"Partition:"* ]]; then
        continue
    fi

    # Extract topic name
    topic=$(echo "$line" | awk -F'Topic: ' '{print $2}' | awk '{print $1}')
    if [ -z "$topic" ]; then
        continue
    fi

    echo "Checking topic: $topic"
    
    # Extract replication factor
    rf=$(echo "$line" | awk -F'ReplicationFactor: ' '{print $2}' | awk '{print $1}')
    echo "Replication Factor: $rf"
    
    # Extract min.insync.replicas
    min_isr=$(echo "$line" | awk -F'min.insync.replicas=' '{print $2}' | awk -F',' '{print $1}')
    echo "min.insync.replicas: $min_isr"
    
    # If min_isr is not set, default to 1
    if [ -z "$min_isr" ]; then
        min_isr=1
        echo "min.insync.replicas not set, using default value: 1"
    fi
    
    # Calculate the difference
    diff=$((rf - min_isr))
    echo "Difference (RF - min.insync.replicas): $diff"
    
    # Check if difference is not 1
    if [ "$diff" -ne 1 ]; then
        echo "WARNING: Topic '$topic' has ReplicationFactor=$rf and min.insync.replicas=$min_isr (difference=$diff)"
        if [ "$diff" -gt 1 ]; then
            suggested_min_isr=$((rf - 1))
            echo "SUGGESTION: Set min.insync.replicas to $suggested_min_isr (RF-1)"
            if [ -n "$COMMAND_CONFIG" ]; then
                echo "kafka-configs --alter --topic $topic --bootstrap-server $BOOTSTRAP_SERVER --command-config $COMMAND_CONFIG --add-config min.insync.replicas=$suggested_min_isr" >> "$ALTER_COMMANDS_FILE"
            else
                echo "kafka-configs --alter --topic $topic --bootstrap-server $BOOTSTRAP_SERVER --add-config min.insync.replicas=$suggested_min_isr" >> "$ALTER_COMMANDS_FILE"
            fi
        fi
    fi
    echo "----------------------------------------"
done

# Check if we have any commands to execute
if [ $(wc -l < "$ALTER_COMMANDS_FILE") -gt 3 ]; then
    echo ""
    echo "Commands to fix min.insync.replicas settings have been collected in: $ALTER_COMMANDS_FILE"
    echo "Would you like to execute these commands now? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Executing commands..."
        chmod +x "$ALTER_COMMANDS_FILE"
        "$ALTER_COMMANDS_FILE"
        echo "Commands executed."
    else
        echo "Commands have been saved to $ALTER_COMMANDS_FILE"
        echo "You can review and execute them later."
    fi
else
    echo "No configuration changes needed."
    rm "$ALTER_COMMANDS_FILE"
fi 