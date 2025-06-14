# Schema Registry Cleanup Script

This script helps clean up the Schema Registry by removing unused or deprecated schemas. It provides a safe way to manage your Schema Registry by allowing you to review and remove schemas that are no longer needed.

## Prerequisites

- Bash shell
- `curl` command-line tool
- Access to Schema Registry
- Access to Kafka cluster

## Usage

```bash
./schema_registry_cleanup.sh [--bootstrap-server <server:port>] [--schema-registry <url>] [--command-config <config-file>]
```

## Arguments

- `--bootstrap-server`: Kafka broker address (default: localhost:9092)
- `--schema-registry`: Schema Registry URL (default: http://localhost:8081)
- `--command-config`: Client configuration file

## Examples

1. Basic usage:
```bash
./schema_registry_cleanup.sh
```

2. With custom Schema Registry:
```bash
./schema_registry_cleanup.sh --schema-registry http://myserver:8081
```

3. With custom Kafka broker:
```bash
./schema_registry_cleanup.sh --bootstrap-server myserver:9092
```

4. With client config:
```bash
./schema_registry_cleanup.sh --bootstrap-server myserver:9092 --command-config client.properties
```

## Behavior

The script will:
1. Connect to the Schema Registry
2. List all available subjects
3. For each subject:
   - Show the current schema versions
   - Allow you to review the schema details
   - Optionally delete specific versions
   - Optionally delete the entire subject

## Notes

- The script requires confirmation before deleting any schemas
- Make sure you have the necessary permissions to access Schema Registry
- Be careful when deleting schemas as this operation cannot be undone
- It's recommended to backup your schemas before running cleanup operations