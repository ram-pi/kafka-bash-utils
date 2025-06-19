#!/bin/bash

# Initialize variables
DEBUG=false
DRY_RUN=false
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
        --dry-run)
            DRY_RUN=true
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
            fi
            shift
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$TOPICS_FILE" ]; then
    echo "Usage: $0 [--debug] [--dry-run] [--bootstrap-server <server:port>] [--command-config <config-file>] <topics_file>"
    echo "Example: $0 topics.txt"
    echo "Example with dry run: $0 --dry-run topics.txt"
    echo "Example with debug: $0 --debug topics.txt"
    echo "Example with custom server: $0 --bootstrap-server myserver:9092 topics.txt"
    echo "Example with command config: $0 --bootstrap-server myserver:9092 --command-config client.properties topics.txt"
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

# Function to print debug information
print_debug() {
    if [ "$DEBUG" = true ]; then
        echo "$1"
    fi
}

# Function to check if topic exists
topic_exists() {
    local topic=$1
    local cmd="kafka-topics.sh --bootstrap-server \"$BOOTSTRAP_SERVER\" --describe --topic \"$topic\""
    
    if [ ! -z "$COMMAND_CONFIG" ]; then
        cmd="$cmd --command-config \"$COMMAND_CONFIG\""
    fi
    
    eval "$cmd" &>/dev/null
    return $?
}

# Function to delete topic
delete_topic() {
    local topic=$1
    local cmd="kafka-topics.sh --bootstrap-server \"$BOOTSTRAP_SERVER\" --delete --topic \"$topic\""
    
    if [ ! -z "$COMMAND_CONFIG" ]; then
        cmd="$cmd --command-config \"$COMMAND_CONFIG\""
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "Would delete topic: $topic"
    else
        echo "Deleting topic: $topic"
        eval "$cmd"
        if [ $? -eq 0 ]; then
            echo "Successfully deleted topic: $topic"
        else
            echo "Error: Failed to delete topic: $topic"
        fi
    fi
}

# Process each topic in the file
if [ "$DRY_RUN" = true ]; then
    echo "Dry run mode - no changes will be made"
    echo "Topics to be processed:"
fi

while IFS= read -r topic || [ -n "$topic" ]; do
    # Skip empty lines and comments
    [[ -z "$topic" || "$topic" =~ ^[[:space:]]*# ]] && continue
    
    # Remove any leading/trailing whitespace
    topic=$(echo "$topic" | xargs)
    
    print_debug "Processing topic: $topic"
    
    # Check if topic exists
    if topic_exists "$topic"; then
        delete_topic "$topic"
    else
        if [ "$DRY_RUN" = true ]; then
            echo "Topic $topic does not exist (no deletion needed)"
        else
            echo "Warning: Topic $topic does not exist, skipping deletion"
        fi
    fi
    
    echo "----------------------------------------"
done < "$TOPICS_FILE"

if [ "$DRY_RUN" = true ]; then
    echo "Dry run completed - no changes were made"
else
    echo "Topic deletion completed"
fi 