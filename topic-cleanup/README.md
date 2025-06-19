# Topic Cleanup Scripts

This directory contains scripts for cleaning up and deleting Kafka topics.

## Scripts

### delete_topics.sh

Deletes Kafka topics from a list specified in a file. The script reads topic names from a text file (one topic per line) and deletes them from the Kafka cluster.

#### Features

- **Dry run mode**: Preview what would be deleted without making changes
- **Debug mode**: Enable verbose output for troubleshooting
- **Flexible configuration**: Support for custom bootstrap servers and command configs
- **Error handling**: Graceful handling of non-existent topics
- **Comment support**: Skip lines starting with `#` in the topics file

#### Usage

```bash
./delete_topics.sh [options] <topics_file>
```

#### Options

- `--debug`: Enable debug output
- `--dry-run`: Preview changes without making them
- `--bootstrap-server <server:port>`: Kafka broker address (default: localhost:9092)
- `--command-config <config-file>`: Client configuration file

#### Examples

Basic usage:
```bash
./delete_topics.sh topics.txt
```

Dry run to preview changes:
```bash
./delete_topics.sh --dry-run topics.txt
```

With custom bootstrap server:
```bash
./delete_topics.sh --bootstrap-server myserver:9092 topics.txt
```

With debug output:
```bash
./delete_topics.sh --debug topics.txt
```

With command config for authentication:
```bash
./delete_topics.sh --bootstrap-server myserver:9092 --command-config client.properties topics.txt
```

#### Topics File Format

Create a text file with one topic name per line. Lines starting with `#` are treated as comments and ignored.

Example `topics.txt`:
```
# Topics to delete
test-topic-1
test-topic-2
# Another topic
test-topic-3
```

#### Prerequisites

- Kafka command-line tools installed and in PATH
- Access to Kafka cluster
- Appropriate permissions to delete topics

#### Safety Features

- **Dry run mode**: Always test with `--dry-run` first
- **Topic existence check**: Script checks if topics exist before attempting deletion
- **Error reporting**: Clear feedback on success/failure for each topic
- **Comment support**: Use `#` to comment out topics you don't want to delete

#### Notes

- Topic deletion is irreversible - use with caution
- Consider backing up topic configurations before deletion
- Some topics may be protected from deletion by ACLs
- The script will skip topics that don't exist and report warnings 