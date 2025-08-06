#!/bin/bash

# MongoDB Backup Script
# Supports mongodump, filesystem snapshots, and replica set backups
# Usage: ./backup-mongodb.sh [options]

set -e

# Default configuration
BACKUP_TYPE="mongodump"
BACKUP_DIR="/var/backups/mongodb"
MONGODB_HOST="localhost"
MONGODB_PORT="27017"
MONGODB_USER=""
MONGODB_PASSWORD=""
MONGODB_AUTH_DB="admin"
DATABASES=""
COLLECTIONS=""
COMPRESSION="gzip"
RETENTION_DAYS="30"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/var/log/mongodb/backup.log"
NOTIFICATION_EMAIL=""
S3_BUCKET=""
S3_PREFIX="mongodb-backups"
ENCRYPTION_KEY=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { 
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
log_success() { 
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
log_warning() { 
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
log_error() { 
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        --host)
            MONGODB_HOST="$2"
            shift 2
            ;;
        --port)
            MONGODB_PORT="$2"
            shift 2
            ;;
        --username)
            MONGODB_USER="$2"
            shift 2
            ;;
        --password)
            MONGODB_PASSWORD="$2"
            shift 2
            ;;
        --auth-db)
            MONGODB_AUTH_DB="$2"
            shift 2
            ;;
        --databases)
            DATABASES="$2"
            shift 2
            ;;
        --collections)
            COLLECTIONS="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --compression)
            COMPRESSION="$2"
            shift 2
            ;;
        --retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --email)
            NOTIFICATION_EMAIL="$2"
            shift 2
            ;;
        --s3-bucket)
            S3_BUCKET="$2"
            shift 2
            ;;
        --s3-prefix)
            S3_PREFIX="$2"
            shift 2
            ;;
        --encrypt-key)
            ENCRYPTION_KEY="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Show help
show_help() {
    cat << EOF
MongoDB Backup Script

Usage: $0 [OPTIONS]

Backup Types:
  --type TYPE           Backup type: mongodump, filesystem, oplog (default: mongodump)

Connection Options:
  --host HOST           MongoDB host (default: localhost)
  --port PORT           MongoDB port (default: 27017)
  --username USER       MongoDB username
  --password PASS       MongoDB password
  --auth-db DB          Authentication database (default: admin)

Backup Options:
  --databases DBS       Comma-separated list of databases to backup (all if empty)
  --collections COLS    Comma-separated list of collections to backup
  --backup-dir DIR      Backup directory (default: /var/backups/mongodb)
  --compression TYPE    Compression: gzip, none (default: gzip)
  --retention DAYS      Retention period in days (default: 30)

Storage Options:
  --s3-bucket BUCKET    S3 bucket for remote storage
  --s3-prefix PREFIX    S3 prefix (default: mongodb-backups)
  --encrypt-key KEY     Encryption key file for backup encryption

Notification:
  --email EMAIL         Email for notifications

Examples:
  # Basic backup
  $0

  # Backup specific databases
  $0 --databases "myapp,logs" --compression gzip

  # Backup with S3 upload
  $0 --s3-bucket my-backups --email admin@example.com

  # Filesystem snapshot backup
  $0 --type filesystem --backup-dir /snapshots

  # Oplog backup for point-in-time recovery
  $0 --type oplog --retention 7
EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if MongoDB tools are installed
    if ! command -v mongodump >/dev/null 2>&1; then
        log_error "mongodump not found. Please install MongoDB tools."
        exit 1
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Check MongoDB connection
    if ! check_mongodb_connection; then
        log_error "Cannot connect to MongoDB"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Check MongoDB connection
check_mongodb_connection() {
    local auth_params=""
    if [[ -n "$MONGODB_USER" ]]; then
        auth_params="--username $MONGODB_USER --password $MONGODB_PASSWORD --authenticationDatabase $MONGODB_AUTH_DB"
    fi
    
    mongosh --host "$MONGODB_HOST" --port "$MONGODB_PORT" $auth_params --quiet --eval "db.runCommand('ping')" >/dev/null 2>&1
}

# Get MongoDB connection string
get_connection_params() {
    local params="--host $MONGODB_HOST --port $MONGODB_PORT"
    if [[ -n "$MONGODB_USER" ]]; then
        params="$params --username $MONGODB_USER --password $MONGODB_PASSWORD --authenticationDatabase $MONGODB_AUTH_DB"
    fi
    echo "$params"
}

# Perform mongodump backup
backup_mongodump() {
    log_info "Starting mongodump backup..."
    
    local backup_path="$BACKUP_DIR/mongodump_$TIMESTAMP"
    mkdir -p "$backup_path"
    
    local connection_params=$(get_connection_params)
    local dump_params="$connection_params --out $backup_path"
    
    # Add database filter if specified
    if [[ -n "$DATABASES" ]]; then
        IFS=',' read -ra DB_ARRAY <<< "$DATABASES"
        for db in "${DB_ARRAY[@]}"; do
            log_info "Backing up database: $db"
            mongodump $connection_params --db "$db" --out "$backup_path"
        done
    else
        log_info "Backing up all databases"
        mongodump $dump_params
    fi
    
    # Compress backup if requested
    if [[ "$COMPRESSION" == "gzip" ]]; then
        log_info "Compressing backup..."
        tar -czf "$backup_path.tar.gz" -C "$BACKUP_DIR" "$(basename "$backup_path")"
        rm -rf "$backup_path"
        backup_path="$backup_path.tar.gz"
    fi
    
    # Encrypt backup if key provided
    if [[ -n "$ENCRYPTION_KEY" ]]; then
        log_info "Encrypting backup..."
        gpg --symmetric --cipher-algo AES256 --batch --yes --passphrase-file "$ENCRYPTION_KEY" "$backup_path"
        rm "$backup_path"
        backup_path="$backup_path.gpg"
    fi
    
    local backup_size=$(du -h "$backup_path" | cut -f1)
    log_success "Mongodump backup completed: $backup_path ($backup_size)"
    echo "$backup_path"
}

# Perform filesystem snapshot backup
backup_filesystem() {
    log_info "Starting filesystem snapshot backup..."
    
    # Stop MongoDB for consistent snapshot
    log_info "Stopping MongoDB for consistent backup..."
    systemctl stop mongod
    
    local backup_path="$BACKUP_DIR/filesystem_$TIMESTAMP"
    mkdir -p "$backup_path"
    
    # Copy data directory
    log_info "Copying MongoDB data directory..."
    cp -r /var/lib/mongodb/* "$backup_path/"
    
    # Start MongoDB
    log_info "Starting MongoDB..."
    systemctl start mongod
    
    # Wait for MongoDB to be ready
    sleep 10
    while ! check_mongodb_connection; do
        log_info "Waiting for MongoDB to be ready..."
        sleep 5
    done
    
    # Compress if requested
    if [[ "$COMPRESSION" == "gzip" ]]; then
        log_info "Compressing filesystem backup..."
        tar -czf "$backup_path.tar.gz" -C "$BACKUP_DIR" "$(basename "$backup_path")"
        rm -rf "$backup_path"
        backup_path="$backup_path.tar.gz"
    fi
    
    local backup_size=$(du -h "$backup_path" | cut -f1)
    log_success "Filesystem backup completed: $backup_path ($backup_size)"
    echo "$backup_path"
}

# Perform oplog backup
backup_oplog() {
    log_info "Starting oplog backup..."
    
    local backup_path="$BACKUP_DIR/oplog_$TIMESTAMP"
    mkdir -p "$backup_path"
    
    local connection_params=$(get_connection_params)
    
    # Backup oplog
    log_info "Backing up oplog..."
    mongodump $connection_params --db local --collection oplog.rs --out "$backup_path"
    
    # Also backup config data for restoration context
    log_info "Backing up config data..."
    mongodump $connection_params --db config --out "$backup_path"
    
    # Compress if requested
    if [[ "$COMPRESSION" == "gzip" ]]; then
        log_info "Compressing oplog backup..."
        tar -czf "$backup_path.tar.gz" -C "$BACKUP_DIR" "$(basename "$backup_path")"
        rm -rf "$backup_path"
        backup_path="$backup_path.tar.gz"
    fi
    
    local backup_size=$(du -h "$backup_path" | cut -f1)
    log_success "Oplog backup completed: $backup_path ($backup_size)"
    echo "$backup_path"
}

# Upload backup to S3
upload_to_s3() {
    local backup_file="$1"
    
    if [[ -z "$S3_BUCKET" ]]; then
        return 0
    fi
    
    log_info "Uploading backup to S3..."
    
    local s3_key="$S3_PREFIX/$(basename "$backup_file")"
    
    if aws s3 cp "$backup_file" "s3://$S3_BUCKET/$s3_key"; then
        log_success "Backup uploaded to S3: s3://$S3_BUCKET/$s3_key"
    else
        log_error "Failed to upload backup to S3"
        return 1
    fi
}

# Clean old backups
cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days..."
    
    # Local cleanup
    find "$BACKUP_DIR" -type f -name "*" -mtime +$RETENTION_DAYS -delete
    
    # S3 cleanup if configured
    if [[ -n "$S3_BUCKET" ]]; then
        local cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
        aws s3 ls "s3://$S3_BUCKET/$S3_PREFIX/" | while read -r line; do
            local file_date=$(echo "$line" | awk '{print $1}')
            local file_name=$(echo "$line" | awk '{print $4}')
            
            if [[ "$file_date" < "$cutoff_date" ]]; then
                log_info "Deleting old S3 backup: $file_name"
                aws s3 rm "s3://$S3_BUCKET/$S3_PREFIX/$file_name"
            fi
        done
    fi
    
    log_success "Cleanup completed"
}

# Send notification
send_notification() {
    local status="$1"
    local message="$2"
    local backup_file="$3"
    
    if [[ -z "$NOTIFICATION_EMAIL" ]]; then
        return 0
    fi
    
    local subject="MongoDB Backup $status - $(hostname)"
    local body="MongoDB backup completed with status: $status

Backup Details:
- Timestamp: $TIMESTAMP
- Type: $BACKUP_TYPE
- Host: $MONGODB_HOST:$MONGODB_PORT
- File: $backup_file
- Size: $(du -h "$backup_file" 2>/dev/null | cut -f1 || echo "Unknown")

Message: $message

Server: $(hostname)
Date: $(date)"
    
    echo "$body" | mail -s "$subject" "$NOTIFICATION_EMAIL"
    log_info "Notification sent to $NOTIFICATION_EMAIL"
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"
    
    log_info "Verifying backup integrity..."
    
    case "$backup_file" in
        *.tar.gz)
            if tar -tzf "$backup_file" >/dev/null 2>&1; then
                log_success "Backup archive is valid"
                return 0
            else
                log_error "Backup archive is corrupted"
                return 1
            fi
            ;;
        *.gpg)
            if gpg --batch --quiet --decrypt --passphrase-file "$ENCRYPTION_KEY" "$backup_file" >/dev/null 2>&1; then
                log_success "Encrypted backup is valid"
                return 0
            else
                log_error "Encrypted backup cannot be decrypted"
                return 1
            fi
            ;;
        *)
            if [[ -d "$backup_file" ]]; then
                log_success "Backup directory exists"
                return 0
            else
                log_error "Backup verification failed"
                return 1
            fi
            ;;
    esac
}

# Get backup statistics
get_backup_stats() {
    log_info "Gathering backup statistics..."
    
    local connection_params=$(get_connection_params)
    
    # Database statistics
    mongosh --host "$MONGODB_HOST" --port "$MONGODB_PORT" $(echo $connection_params | sed 's/--/--/g') --quiet --eval "
        db.runCommand('listCollections').cursor.firstBatch.forEach(function(collection) {
            var stats = db.getCollection(collection.name).stats();
            print('Collection: ' + collection.name + ', Documents: ' + stats.count + ', Size: ' + stats.size);
        });
        
        var dbStats = db.stats();
        print('Database Size: ' + dbStats.dataSize + ' bytes');
        print('Index Size: ' + dbStats.indexSize + ' bytes');
        print('Total Size: ' + (dbStats.dataSize + dbStats.indexSize) + ' bytes');
    " >> "$LOG_FILE"
}

# Main backup function
main() {
    local start_time=$(date +%s)
    local backup_file=""
    local status="SUCCESS"
    local message="Backup completed successfully"
    
    log_info "Starting MongoDB backup (Type: $BACKUP_TYPE)"
    
    # Trap errors
    trap 'status="FAILED"; message="Backup failed with error"; log_error "Backup failed"' ERR
    
    # Check prerequisites
    check_prerequisites
    
    # Get backup statistics
    get_backup_stats
    
    # Perform backup based on type
    case "$BACKUP_TYPE" in
        "mongodump")
            backup_file=$(backup_mongodump)
            ;;
        "filesystem")
            backup_file=$(backup_filesystem)
            ;;
        "oplog")
            backup_file=$(backup_oplog)
            ;;
        *)
            log_error "Unknown backup type: $BACKUP_TYPE"
            exit 1
            ;;
    esac
    
    # Verify backup
    if ! verify_backup "$backup_file"; then
        status="FAILED"
        message="Backup verification failed"
    fi
    
    # Upload to S3 if configured
    if [[ "$status" == "SUCCESS" ]]; then
        upload_to_s3 "$backup_file"
    fi
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Calculate backup time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "Backup process completed in ${duration}s"
    
    # Send notification
    send_notification "$status" "$message" "$backup_file"
    
    # Exit with appropriate code
    if [[ "$status" == "SUCCESS" ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"