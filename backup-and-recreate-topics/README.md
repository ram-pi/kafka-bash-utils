# Kafka Topic Backup and Restore Scripts

This repository contains two scripts for backing up and restoring Kafka topic configurations:

- `backup_topics.sh`: Creates a backup of Kafka topic configurations
- `restore_topics.sh`: Restores topics from a backup file

## Prerequisites

- Bash shell
- `jq` command-line tool for JSON processing
- Kafka command-line tools in your PATH
- Access to Kafka cluster

## Backup Topics

The `backup_topics.sh` script creates a JSON backup of Kafka topic configurations.

### Usage

```bash
./backup_topics.sh [--debug] [--bootstrap-server <server:port>] [--command-config <config-file>] <topics_file> <output_file>
```

### Arguments

- `--debug`: Show detailed debug information
- `--bootstrap-server`: Kafka broker address (default: localhost:9092)
- `--command-config`: Client configuration file
- `topics_file`: File containing list of topics to backup (one per line)
- `output_file`: JSON file to store the backup

### Examples

1. Basic usage:
```bash
./backup_topics.sh topics.txt backup.json
```

2. With custom server:
```bash
./backup_topics.sh --bootstrap-server myserver:9092 topics.txt backup.json
```

3. With client config:
```bash
./backup_topics.sh --bootstrap-server myserver:9092 --command-config client.properties topics.txt backup.json
```

4. With debug output:
```bash
./backup_topics.sh --debug --bootstrap-server myserver:9092 --command-config client.properties topics.txt backup.json
```

## Restore Topics

The `restore_topics.sh` script recreates topics from a backup file.

### Usage

```bash
./restore_topics.sh [--debug] [--dry-run] [--bootstrap-server <server:port>] [--command-config <config-file>] <backup_file>
```

### Arguments

- `--debug`: Show detailed debug information
- `--dry-run`: Show what would be done without making changes
- `--bootstrap-server`: Kafka broker address (default: localhost:9092)
- `--command-config`: Client configuration file
- `backup_file`: JSON backup file to restore from

### Examples

1. Basic usage:
```bash
./restore_topics.sh backup.json
```

2. Dry run (no changes):
```bash
./restore_topics.sh --dry-run backup.json
```

3. With custom server:
```bash
./restore_topics.sh --bootstrap-server myserver:9092 backup.json
```

4. With all options:
```bash
./restore_topics.sh --debug --dry-run --bootstrap-server myserver:9092 --command-config client.properties backup.json
```

## Backup File Format

The backup file is a JSON file with the following structure:

```json
{
  "topics": [
    {
      "name": "topic-name",
      "partition_count": 3,
      "replication_factor": 3,
      "configs": {
        "min.insync.replicas": "2",
        "cleanup.policy": "compact"
      }
    }
  ]
}
```

## Notes

- Both scripts require `jq` to be installed
- The restore script will delete existing topics before recreating them
- Use `--dry-run` with the restore script to preview changes
- Make sure you have the necessary permissions to delete and create topics 