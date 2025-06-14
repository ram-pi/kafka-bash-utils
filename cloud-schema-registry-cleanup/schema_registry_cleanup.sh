#!/usr/bin/env bash

# Function to search for soft-deleted schemas in a context
search_soft_deleted_schemas() {
    local context="$1"
    local deleted_schemas=$(curl -s -u "$SR_API_KEY:$SR_API_SECRET" "$SR_URL/contexts/$context/schemas?deleted=true")
    
    if [ "$(echo "$deleted_schemas" | jq 'length')" -gt 0 ]; then
        # Print status for display
        echo "Found soft-deleted schemas in context $context:" >&2
        echo "$deleted_schemas" | jq -r '.[].subject' >&2
        # Return only the subjects
        echo "$deleted_schemas" | jq -r '.[].subject'
    else
        echo "No soft-deleted schemas found in context $context" >&2
    fi
}

# Function to perform deletion for a subject
delete_subject() {
    local subject="$1"
    echo "Processing subject: $subject"
    
    # Perform soft delete
    echo "Performing soft delete for subject: $subject"
    soft_delete_response=$(curl -s -X DELETE -u "$SR_API_KEY:$SR_API_SECRET" "$SR_URL/subjects/$subject")
    echo "Soft delete response: $soft_delete_response"
    
    # Perform hard delete
    echo "Performing hard delete for subject: $subject"
    hard_delete_response=$(curl -s -X DELETE -u "$SR_API_KEY:$SR_API_SECRET" "$SR_URL/subjects/$subject?permanent=true")
    echo "Hard delete response: $hard_delete_response"
    
    echo "Completed processing subject: $subject"
    echo "----------------------------------------"
}

# Check if all required arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <schema-registry-url> <api-key> <api-secret>"
    echo "Example: $0 https://schema-registry-url your-api-key your-api-secret"
    exit 1
fi

# Store input arguments in variables
SR_URL="$1"
SR_API_KEY="$2"
SR_API_SECRET="$3"

# Validate that none of the inputs are empty
if [ -z "$SR_URL" ] || [ -z "$SR_API_KEY" ] || [ -z "$SR_API_SECRET" ]; then
    echo "Error: All arguments must have non-empty values"
    exit 1
fi

# Store credentials in variables
SR_URL="${SR_URL}"
SR_API_KEY="${SR_API_KEY}"
SR_API_SECRET="${SR_API_SECRET}"

# Get all contexts
echo "Fetching all contexts from Schema Registry..."
contexts=($(curl -s -u "$SR_API_KEY:$SR_API_SECRET" "$SR_URL/contexts" | jq -r '.[]'))

# Check if contexts were retrieved successfully
if [ ${#contexts[@]} -eq 0 ]; then
    echo "No contexts found in the Schema Registry"
    exit 0
fi

echo "Found ${#contexts[@]} contexts:"
printf '%s\n' "${contexts[@]}"

# First pass: collect all soft-deleted schemas
echo -e "\nSearching for soft-deleted schemas in all contexts..."
soft_deleted_subjects=()
for context in "${contexts[@]}"; do
    echo "Processing context: $context"
    # Get the subjects and add them to our array
    while IFS= read -r subject; do
        if [ ! -z "$subject" ]; then
            soft_deleted_subjects+=("$subject")
        fi
    done < <(search_soft_deleted_schemas "$context")
    echo "----------------------------------------"
done

# If no soft-deleted schemas found, exit
if [ ${#soft_deleted_subjects[@]} -eq 0 ]; then
    echo "No soft-deleted schemas found in any context"
    exit 0
fi

# Remove duplicates and sort
unique_subjects=($(printf "%s\n" "${soft_deleted_subjects[@]}" | sort -u))

# Show summary of soft-deleted schemas
echo -e "\nFound ${#unique_subjects[@]} unique soft-deleted schemas:"
printf '%s\n' "${unique_subjects[@]}"

# Ask for confirmation to proceed with deletion
echo -e "\nWARNING: This will perform both soft and hard deletes for ALL soft-deleted schemas listed above."
echo "This action cannot be undone for hard deletes."
read -p "Are you sure you want to proceed with deletion? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Operation cancelled"
    exit 0
fi

echo -e "\nProceeding with deletions..."

# Second pass: perform deletions
for subject in "${unique_subjects[@]}"; do
    delete_subject "$subject"
done

echo "All soft-deleted schemas have been processed"

