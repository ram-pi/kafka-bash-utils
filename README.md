# Kafka Management Scripts

This repository contains a collection of scripts for managing various aspects of Kafka clusters, including topic management, Schema Registry cleanup, and ACL management.

## Scripts Overview

### [Backup and Recreate Topics](./backup-and-recreate-topics/)
Scripts for backing up and recreating Kafka topics with their configurations:
- `backup_topics.sh`: Creates a backup of topic configurations in JSON format
- `restore_topics.sh`: Restores topics from a backup file

### [Schema Registry Cleanup](./cloud-schema-registry-cleanup/)
Scripts for managing and cleaning up Schema Registry:
- `schema_registry_cleanup.sh`: Interactive script for reviewing and removing unused schemas

### [ACL Management](./restore-kafka-acls/)
Scripts for managing Kafka ACLs:
- `restore_kafka_acls.sh`: Restores ACLs from a backup file

### [Replication Factor Management](./veryfi-rf-minisr/)
Scripts for managing replication factors and minimum ISR:
- `verify_rf_and_min_isr.sh`: Verifies and reports on replication factor and minimum ISR settings

## Prerequisites

- Bash shell
- Kafka command-line tools
- `jq` for JSON processing
- `curl` for HTTP requests
- Access to Kafka cluster

## Common Usage

Most scripts support the following common arguments:
- `--bootstrap-server`: Kafka broker address (default: localhost:9092)
- `--command-config`: Client configuration file
- `--debug`: Enable debug output

## Directory Structure

```
.
├── backup-and-recreate-topics/    # Topic backup and recreation scripts
│   ├── backup_topics.sh
│   └── restore_topics.sh
├── cloud-schema-registry-cleanup/  # Schema Registry management scripts
│   └── schema_registry_cleanup.sh
├── restore-kafka-acls/            # ACL management scripts
│   └── restore_kafka_acls.sh
└── veryfi-rf-minisr/             # Replication factor verification scripts
    └── verify_rf_and_min_isr.sh
```

## Getting Started

1. Clone the repository
2. Make scripts executable: `chmod +x */.*.sh`
3. Review the README in each directory for specific usage instructions
4. Run scripts with appropriate arguments

## Notes

- Always review script behavior before running in production
- Some scripts require confirmation before making changes
- Consider using `--debug` flag when troubleshooting
- Make sure you have necessary permissions before running scripts

## Contributing

Feel free to submit issues and enhancement requests! 