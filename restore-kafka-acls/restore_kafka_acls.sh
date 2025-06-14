#!/usr/bin/env bash

# Help function
show_help() {
    echo "Usage: $0 [acls-file] [--format|--generate]"
    echo ""
    echo "This script reads and parses Kafka ACLs from a file (output of kafka-acls --list)."
    echo ""
    echo "Parameters:"
    echo "  acls-file    File containing Kafka ACLs (required)"
    echo "  --format     Optional: Format the output in a more readable way"
    echo "  --generate   Optional: Generate kafka-acls commands to recreate ACLs"
    echo ""
    echo "Examples:"
    echo "  $0 acls.txt              # Read ACLs from acls.txt"
    echo "  $0 acls.txt --format     # Read and format ACLs from acls.txt"
    echo "  $0 acls.txt --generate   # Generate commands to recreate ACLs"
    echo ""
    exit 0
}

# Show help if requested or no arguments provided
if [ "$1" == "-h" ] || [ "$1" == "--help" ] || [ -z "$1" ]; then
    show_help
fi

# Check if file exists
if [ ! -f "$1" ]; then
    echo "Error: File $1 does not exist"
    exit 1
fi

ACLS_FILE="$1"
OUTPUT_MODE="$2"

# Get bootstrap server and command config if generating commands
if [ "$OUTPUT_MODE" == "--generate" ]; then
    # Ask for bootstrap server
    read -p "Enter the bootstrap server (e.g., localhost:9092): " TARGET_BOOTSTRAP_SERVER
    if [ -z "$TARGET_BOOTSTRAP_SERVER" ]; then
        TARGET_BOOTSTRAP_SERVER="localhost:9092"
        echo "Using default bootstrap server: $TARGET_BOOTSTRAP_SERVER"
    fi

    # Ask for command config
    read -p "Enter the command config file path (press enter to skip): " TARGET_COMMAND_CONFIG
fi

# Create a temporary file for ACL recreation commands
if [ "$OUTPUT_MODE" == "--generate" ]; then
    echo "Generating ACL recreation commands..."
    RECREATE_COMMANDS_FILE=$(mktemp)
    echo "RECREATE_COMMANDS_FILE: $RECREATE_COMMANDS_FILE"
    echo "#!/usr/bin/env bash" > "$RECREATE_COMMANDS_FILE"
    echo "# Commands to recreate Kafka ACLs" >> "$RECREATE_COMMANDS_FILE"
    echo "" >> "$RECREATE_COMMANDS_FILE"
fi

# Function to process resource pattern line
process_resource() {
    local line="$1"
    # Extract resource type and name from ResourcePattern
    local resource_type=$(echo "$line" | grep -o "resourceType=\w\+" | cut -d'=' -f2)
    local resource_name=$(echo "$line" | grep -o "name=[^,]\+" | cut -d'=' -f2)
    local pattern_type=$(echo "$line" | grep -o "patternType=\w\+" | cut -d'=' -f2)
    
    echo "$resource_type|$resource_name|$pattern_type"
}

# Function to process ACL entry line
process_acl_entry() {
    local line="$1"
    local resource_info="$2"
    
    # Split resource info
    IFS='|' read -r resource_type resource_name pattern_type <<< "$resource_info"
    
    # Extract principal - match everything between principal= and host=
    local principal=$(echo "$line" | sed -E 's/.*principal=([^,]+(,[^,]+)*), host=.*/\1/')
    # Extract operation
    local operation=$(echo "$line" | grep -o "operation=\w\+" | cut -d'=' -f2)
    # Extract permission type
    local permission=$(echo "$line" | grep -o "permissionType=\w\+" | cut -d'=' -f2)
    
    if [ "$OUTPUT_MODE" == "--format" ]; then
        echo "Principal: $principal"
        echo "Operation: $operation"
        echo "Permission: $permission"
        echo "Resource Type: $resource_type"
        echo "Resource Name: $resource_name"
        echo "Pattern Type: $pattern_type"
        echo "----------------------------------------"
    elif [ "$OUTPUT_MODE" == "--generate" ]; then
        # Convert resource type to lowercase for the command
        local resource_type_lower=$(echo "$resource_type" | tr '[:upper:]' '[:lower:]')
        
        # Build the kafka-acls command
        local cmd="kafka-acls --bootstrap-server $TARGET_BOOTSTRAP_SERVER"
        # Add command config if provided
        if [ -n "$TARGET_COMMAND_CONFIG" ]; then
            cmd+=" --command-config $TARGET_COMMAND_CONFIG"
        fi
        cmd+=" --add"
        cmd+=" --allow-principal '$principal'"
        cmd+=" --operation $operation"
        cmd+=" --$resource_type_lower $resource_name"
        
        # Add pattern type if it's not LITERAL
        if [ "$pattern_type" != "LITERAL" ]; then
            cmd+=" --resource-pattern-type $pattern_type"
        fi
        
        echo "$cmd" >> "$RECREATE_COMMANDS_FILE"
    else
        echo "$line"
    fi
}

# Variables to track current resource
current_resource=""

# Read the file
while IFS= read -r line; do
    # Skip empty lines
    if [ -z "$line" ]; then
        continue
    fi
    
    # Check if this is a resource pattern line
    if [[ "$line" == *"Current ACLs for resource"* ]]; then
        current_resource=$(process_resource "$line")
        continue
    fi
    
    # Process ACL entry if we have a current resource
    if [ -n "$current_resource" ] && [[ "$line" == *"principal="* ]]; then
        process_acl_entry "$line" "$current_resource"
    fi
done < "$ACLS_FILE"

# If generating commands, show next steps
if [ "$OUTPUT_MODE" == "--generate" ]; then
    echo "ACL recreation commands have been generated in: $RECREATE_COMMANDS_FILE"
    echo ""
    echo "The commands will use:"
    echo "- Bootstrap Server: $TARGET_BOOTSTRAP_SERVER"
    if [ -n "$TARGET_COMMAND_CONFIG" ]; then
        echo "- Command Config: $TARGET_COMMAND_CONFIG"
    else
        echo "- No command config file specified"
    fi
    echo ""
    echo "To execute the commands:"
    echo "1. Review the generated commands in $RECREATE_COMMANDS_FILE"
    echo "2. Make the file executable: chmod +x $RECREATE_COMMANDS_FILE"
    echo "3. Run the commands: $RECREATE_COMMANDS_FILE"
fi 