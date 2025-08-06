# MongoDB Automation Scripts Collection

A comprehensive collection of MongoDB automation scripts for installation, backup, monitoring, security, performance optimization, and maintenance.

## 🚀 Overview

This collection provides production-ready automation scripts for MongoDB database administration, covering:

- **Installation & Setup**: Automated MongoDB installation for various Linux distributions
- **Backup & Restore**: Comprehensive backup solutions with multiple strategies
- **Monitoring & Health Checks**: Real-time monitoring and alerting
- **Security Management**: User management and security automation
- **Performance Optimization**: Performance tuning and optimization
- **Replica Set Management**: Automated replica set operations
- **Sharding Management**: Sharded cluster automation
- **Maintenance & Cleanup**: Routine maintenance tasks

## 📁 Directory Structure

```
mongodb-automation/
├── install/
│   ├── install-mongodb.sh           # MongoDB installation script
│   └── configure-replica-set.sh     # Replica set configuration
├── backup/
│   ├── backup-mongodb.sh            # Comprehensive backup script
│   ├── restore-mongodb.sh           # Restore script
│   └── backup-scheduler.sh          # Automated backup scheduling
├── monitoring/
│   ├── health-check.sh              # Health monitoring script
│   ├── performance-monitor.sh       # Performance monitoring
│   └── log-analyzer.sh              # Log analysis automation
├── security/
│   ├── user-management.sh           # User and role management
│   ├── security-audit.sh            # Security audit script
│   └── ssl-setup.sh                 # SSL/TLS configuration
├── performance/
│   ├── optimize-performance.sh      # Performance optimization
│   ├── index-analyzer.sh            # Index analysis and optimization
│   └── query-profiler.sh            # Query performance profiling
├── replication/
│   ├── replica-set-manager.sh       # Replica set management
│   ├── failover-automation.sh       # Automated failover
│   └── sync-monitor.sh              # Replication lag monitoring
├── sharding/
│   ├── shard-manager.sh             # Sharding management
│   ├── balancer-control.sh          # Balancer automation
│   └── chunk-analyzer.sh            # Chunk distribution analysis
├── maintenance/
│   ├── cleanup-logs.sh              # Log cleanup automation
│   ├── compact-database.sh          # Database compaction
│   └── index-maintenance.sh         # Index maintenance
└── utilities/
    ├── connection-test.sh           # Connection testing
    ├── data-migration.sh            # Data migration utilities
    └── config-generator.sh          # Configuration generation
```

## 🛠️ Installation Scripts

### MongoDB Installation (`install/install-mongodb.sh`)

Automated MongoDB installation supporting multiple Linux distributions:

```bash
# Install standalone MongoDB
./install-mongodb.sh 7.0

# Install for replica set
./install-mongodb.sh 7.0 --replica-set

# Install config server
./install-mongodb.sh 7.0 --config-server

# Install shard server
./install-mongodb.sh 7.0 --shard-server
```

**Features:**
- Multi-OS support (Ubuntu, CentOS, RHEL, Amazon Linux)
- Automatic system optimization
- Security hardening
- Service configuration
- Firewall setup

## 💾 Backup & Restore Scripts

### Backup Script (`backup/backup-mongodb.sh`)

Comprehensive backup solution with multiple strategies:

```bash
# Basic mongodump backup
./backup-mongodb.sh --type mongodump

# Filesystem snapshot backup
./backup-mongodb.sh --type filesystem

# Oplog backup for point-in-time recovery
./backup-mongodb.sh --type oplog

# Backup with S3 upload and encryption
./backup-mongodb.sh --s3-bucket my-backups --encrypt-key /path/to/key
```

**Features:**
- Multiple backup types (mongodump, filesystem, oplog)
- Compression and encryption
- S3 integration
- Email/Slack notifications
- Automated cleanup
- Backup verification

### Restore Script (`backup/restore-mongodb.sh`)

```bash
# Restore from mongodump
./restore-mongodb.sh --backup-file /path/to/backup.tar.gz

# Point-in-time restore
./restore-mongodb.sh --backup-file /path/to/backup.tar.gz --point-in-time "2024-01-15T10:30:00Z"
```

## 📊 Monitoring Scripts

### Health Check (`monitoring/health-check.sh`)

Comprehensive health monitoring with alerting:

```bash
# Full health check
./health-check.sh

# Specific checks
./health-check.sh --check replica --format json

# Nagios integration
./health-check.sh --nagios --check performance

# With Slack alerts
./health-check.sh --slack-webhook https://hooks.slack.com/...
```

**Monitoring Features:**
- Connection status
- Server metrics
- Replica set health
- Sharding status
- Performance metrics
- Disk usage
- Slow queries
- Index usage
- Oplog status

## 🔐 Security Scripts

### User Management (`security/user-management.sh`)

Complete user and security management:

```bash
# Create application user
./user-management.sh create --username appuser --password secret123 --roles readWrite --database myapp

# Create backup user
./user-management.sh create --username backup --password backup123 --roles backup,clusterMonitor

# List all users
./user-management.sh list

# Audit user access
./user-management.sh audit --username appuser
```

**Security Features:**
- User creation/deletion
- Role management
- Password changes
- Account enable/disable
- Security auditing
- Best practices checking

## ⚡ Performance Scripts

### Performance Optimization (`performance/optimize-performance.sh`)

Automated performance tuning:

```bash
# Full performance optimization
./optimize-performance.sh

# Specific optimizations
./optimize-performance.sh --indexes-only
./optimize-performance.sh --config-only
```

### Index Analysis (`performance/index-analyzer.sh`)

Index optimization and analysis:

```bash
# Analyze all indexes
./index-analyzer.sh

# Find unused indexes
./index-analyzer.sh --unused-only

# Suggest new indexes
./index-analyzer.sh --suggest
```

## 🔄 Replication Scripts

### Replica Set Manager (`replication/replica-set-manager.sh`)

Automated replica set management:

```bash
# Initialize replica set
./replica-set-manager.sh init --members "host1:27017,host2:27017,host3:27017"

# Add member
./replica-set-manager.sh add-member --host host4:27017

# Remove member
./replica-set-manager.sh remove-member --host host4:27017

# Step down primary
./replica-set-manager.sh step-down
```

## 🗂️ Sharding Scripts

### Shard Manager (`sharding/shard-manager.sh`)

Sharded cluster management:

```bash
# Add shard
./shard-manager.sh add-shard --shard "rs1/host1:27018,host2:27018,host3:27018"

# Remove shard
./shard-manager.sh remove-shard --shard rs1

# Enable sharding
./shard-manager.sh enable-sharding --database myapp

# Shard collection
./shard-manager.sh shard-collection --database myapp --collection users --key "{userId: 1}"
```

## 🧹 Maintenance Scripts

### Log Cleanup (`maintenance/cleanup-logs.sh`)

Automated log management:

```bash
# Clean logs older than 30 days
./cleanup-logs.sh --days 30

# Archive logs
./cleanup-logs.sh --archive --days 7
```

### Database Compaction (`maintenance/compact-database.sh`)

Database maintenance and compaction:

```bash
# Compact all databases
./compact-database.sh

# Compact specific database
./compact-database.sh --database myapp
```

## 📋 Usage Examples

### Daily Operations

```bash
# Morning health check
./monitoring/health-check.sh --email admin@company.com

# Backup databases
./backup/backup-mongodb.sh --s3-bucket daily-backups

# Performance check
./performance/optimize-performance.sh --analyze-only
```

### Weekly Maintenance

```bash
# Clean old logs
./maintenance/cleanup-logs.sh --days 7

# Index maintenance
./maintenance/index-maintenance.sh

# Security audit
./security/security-audit.sh
```

### Emergency Procedures

```bash
# Failover replica set
./replication/failover-automation.sh

# Emergency backup
./backup/backup-mongodb.sh --type filesystem --priority high

# Restore from backup
./backup/restore-mongodb.sh --backup-file emergency-backup.tar.gz
```

## 🔧 Configuration

### Global Configuration

Create `/etc/mongodb/automation.conf`:

```bash
# MongoDB connection defaults
MONGODB_HOST="localhost"
MONGODB_PORT="27017"
MONGODB_ADMIN_USER="admin"
MONGODB_ADMIN_PASSWORD="password"

# Backup configuration
BACKUP_DIR="/var/backups/mongodb"
S3_BUCKET="mongodb-backups"
RETENTION_DAYS="30"

# Monitoring configuration
SLACK_WEBHOOK="https://hooks.slack.com/..."
EMAIL_ALERTS="admin@company.com"

# Performance thresholds
CPU_THRESHOLD="80"
MEMORY_THRESHOLD="85"
DISK_THRESHOLD="90"
```

### Cron Jobs Setup

```bash
# Daily backup at 2 AM
0 2 * * * /opt/mongodb-automation/backup/backup-mongodb.sh

# Health check every 5 minutes
*/5 * * * * /opt/mongodb-automation/monitoring/health-check.sh --nagios

# Weekly maintenance on Sunday at 3 AM
0 3 * * 0 /opt/mongodb-automation/maintenance/cleanup-logs.sh --days 30
```

## 🚨 Monitoring & Alerting

### Nagios Integration

```bash
# Add to Nagios configuration
define command{
    command_name    check_mongodb_health
    command_line    /opt/mongodb-automation/monitoring/health-check.sh --nagios --host $HOSTADDRESS$
}
```

### Prometheus Integration

Export metrics for Prometheus monitoring:

```bash
# Generate metrics
./monitoring/health-check.sh --format json > /var/lib/prometheus/mongodb-metrics.json
```

## 🔒 Security Best Practices

1. **Authentication**: Always enable authentication
2. **Authorization**: Use role-based access control
3. **Network Security**: Bind to specific IPs, use firewalls
4. **Encryption**: Enable TLS/SSL for connections
5. **Auditing**: Enable audit logging
6. **Regular Updates**: Keep MongoDB updated
7. **Backup Security**: Encrypt backups, secure storage

## 📈 Performance Tuning

### Automatic Optimizations

The scripts automatically apply:

- **Index Optimization**: Create missing indexes, remove unused ones
- **Configuration Tuning**: Optimize MongoDB configuration
- **System Settings**: Tune OS parameters
- **Memory Management**: Optimize cache settings
- **Connection Pooling**: Configure connection limits

### Manual Tuning

```bash
# Analyze query performance
./performance/query-profiler.sh --slow-queries

# Optimize specific collection
./performance/optimize-performance.sh --collection users --database myapp
```

## 🔄 High Availability

### Replica Set Automation

```bash
# Monitor replica set health
./replication/sync-monitor.sh

# Automatic failover
./replication/failover-automation.sh --auto
```

### Sharding Automation

```bash
# Monitor chunk distribution
./sharding/chunk-analyzer.sh

# Balance shards
./sharding/balancer-control.sh --enable
```

## 📚 Documentation

Each script includes:
- Comprehensive help (`--help`)
- Usage examples
- Configuration options
- Error handling
- Logging

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Add tests
4. Submit pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

For issues and questions:
- Check script help: `./script-name.sh --help`
- Review logs in `/var/log/mongodb/`
- Create GitHub issues
- Contact: support@company.com