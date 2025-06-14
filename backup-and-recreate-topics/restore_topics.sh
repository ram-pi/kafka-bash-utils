#!/bin/bash

# Initialize variables
DEBUG=false
DRY_RUN=false
BOOTSTRAP_SERVER="localhost:9092"
COMMAND_CONFIG=""

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
            if [ -z "$BACKUP_FILE" ]; then
                BACKUP_FILE=$1
            fi
            shift
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 [--debug] [--dry-run] [--bootstrap-server <server:port>] [--command-config <config-file>] <backup_file>"
    echo "Example: $0 backup.json"
    echo "Example with dry run: $0 --dry-run backup.json"
    echo "Example with custom server: $0 --bootstrap-server myserver:9092 backup.json"
    echo "Example with command config: $0 --bootstrap-server myserver:9092 --command-config client.properties backup.json"
    exit 1
fi

# Check if the backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file '$BACKUP_FILE' not found"
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
        sleep 5  # Wait for topic deletion
    fi
}

# Function to create topic
create_topic() {
    local topic=$1
    local partitions=$2
    local replication_factor=$3
    local configs_json=$4
    
    local cmd="kafka-topics.sh --bootstrap-server \"$BOOTSTRAP_SERVER\" --create --topic \"$topic\" --partitions $partitions --replication-factor $replication_factor"
    
    # Add configs
    if [ ! -z "$configs_json" ] && [ "$configs_json" != "{}" ]; then
        # Use jq to convert JSON object to key=value pairs
        while IFS='=' read -r key value; do
            cmd="$cmd --config $key=$value"
        done < <(echo "$configs_json" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"')
    fi
    
    if [ ! -z "$COMMAND_CONFIG" ]; then
        cmd="$cmd --command-config \"$COMMAND_CONFIG\""
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "Would create topic: $topic"
        echo "  Partitions: $partitions"
        echo "  Replication factor: $replication_factor"
        if [ ! -z "$configs_json" ] && [ "$configs_json" != "{}" ]; then
            echo "  Configs:"
            echo "$configs_json" | jq -r 'to_entries | .[] | "    \(.key)=\(.value)"'
        fi
    else
        echo "Creating topic: $topic"
        eval "$cmd"
    fi
}

# Read and parse the backup file
if [ "$DRY_RUN" = true ]; then
    echo "Dry run mode - no changes will be made"
    echo "Topics to be processed:"
fi

# Use jq to parse the JSON file
while IFS= read -r topic_data; do
    # Extract topic information using jq
    topic=$(echo "$topic_data" | jq -r '.name')
    partitions=$(echo "$topic_data" | jq -r '.partition_count')
    replication_factor=$(echo "$topic_data" | jq -r '.replication_factor')
    configs=$(echo "$topic_data" | jq -r '.configs')
    
    print_debug "Processing topic: $topic"
    print_debug "  Partitions: $partitions"
    print_debug "  Replication factor: $replication_factor"
    print_debug "  Configs: $configs"
    
    # Check if topic exists
    if topic_exists "$topic"; then
        delete_topic "$topic"
    elif [ "$DRY_RUN" = true ]; then
        echo "Topic $topic does not exist (no deletion needed)"
    fi
    
    # Create topic
    create_topic "$topic" "$partitions" "$replication_factor" "$configs"
    
    echo "----------------------------------------"
done < <(jq -c '.topics[]' "$BACKUP_FILE")

if [ "$DRY_RUN" = true ]; then
    echo "Dry run completed - no changes were made"
else
    echo "Topic restoration completed"
fi 