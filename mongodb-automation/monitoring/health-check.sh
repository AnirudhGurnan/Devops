#!/bin/bash

# MongoDB Health Check and Monitoring Script
# Comprehensive monitoring for standalone, replica sets, and sharded clusters
# Usage: ./health-check.sh [options]

set -e

# Default configuration
MONGODB_HOST="localhost"
MONGODB_PORT="27017"
MONGODB_USER=""
MONGODB_PASSWORD=""
MONGODB_AUTH_DB="admin"
CHECK_TYPE="all"
OUTPUT_FORMAT="text"
LOG_FILE="/var/log/mongodb/health-check.log"
ALERT_THRESHOLDS_FILE="/etc/mongodb/alert-thresholds.conf"
NAGIOS_MODE=false
SLACK_WEBHOOK=""
EMAIL_ALERT=""
METRICS_FILE="/var/log/mongodb/metrics.json"

# Default alert thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
CONNECTIONS_THRESHOLD=80
REPLICATION_LAG_THRESHOLD=10
SLOW_QUERY_THRESHOLD=1000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Status codes
STATUS_OK=0
STATUS_WARNING=1
STATUS_CRITICAL=2
STATUS_UNKNOWN=3

# Global status
OVERALL_STATUS=$STATUS_OK
HEALTH_ISSUES=()

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[OK]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[CRITICAL]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"; }

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host) MONGODB_HOST="$2"; shift 2 ;;
        --port) MONGODB_PORT="$2"; shift 2 ;;
        --username) MONGODB_USER="$2"; shift 2 ;;
        --password) MONGODB_PASSWORD="$2"; shift 2 ;;
        --auth-db) MONGODB_AUTH_DB="$2"; shift 2 ;;
        --check) CHECK_TYPE="$2"; shift 2 ;;
        --format) OUTPUT_FORMAT="$2"; shift 2 ;;
        --nagios) NAGIOS_MODE=true; shift ;;
        --slack-webhook) SLACK_WEBHOOK="$2"; shift 2 ;;
        --email) EMAIL_ALERT="$2"; shift 2 ;;
        --thresholds) ALERT_THRESHOLDS_FILE="$2"; shift 2 ;;
        -h|--help) show_help; exit 0 ;;
        *) log_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# Show help
show_help() {
    cat << EOF
MongoDB Health Check Script

Usage: $0 [OPTIONS]

Connection Options:
  --host HOST           MongoDB host (default: localhost)
  --port PORT           MongoDB port (default: 27017)
  --username USER       MongoDB username
  --password PASS       MongoDB password
  --auth-db DB          Authentication database (default: admin)

Check Options:
  --check TYPE          Check type: all, basic, replica, sharding, performance (default: all)
  --format FORMAT       Output format: text, json, nagios (default: text)
  --nagios              Enable Nagios-compatible output
  --thresholds FILE     Alert thresholds configuration file

Alerting Options:
  --slack-webhook URL   Slack webhook URL for alerts
  --email EMAIL         Email address for alerts

Available Checks:
  - Connection status
  - Server status and version
  - Database statistics
  - Replica set status
  - Sharding status
  - Performance metrics
  - Disk usage
  - Memory usage
  - Active connections
  - Slow queries
  - Index usage
  - Oplog status

Examples:
  # Basic health check
  $0

  # Check replica set status only
  $0 --check replica --format json

  # Full check with Slack alerts
  $0 --slack-webhook https://hooks.slack.com/...

  # Nagios monitoring
  $0 --nagios --check performance
EOF
}

# Load alert thresholds
load_thresholds() {
    if [[ -f "$ALERT_THRESHOLDS_FILE" ]]; then
        source "$ALERT_THRESHOLDS_FILE"
    fi
}

# Get MongoDB connection parameters
get_connection_params() {
    local params="--host $MONGODB_HOST --port $MONGODB_PORT --quiet"
    if [[ -n "$MONGODB_USER" ]]; then
        params="$params --username $MONGODB_USER --password $MONGODB_PASSWORD --authenticationDatabase $MONGODB_AUTH_DB"
    fi
    echo "$params"
}

# Execute MongoDB command
mongo_exec() {
    local command="$1"
    local connection_params=$(get_connection_params)
    mongosh $connection_params --eval "$command" 2>/dev/null
}

# Check MongoDB connectivity
check_connectivity() {
    log_info "Checking MongoDB connectivity..."
    
    if mongo_exec "db.runCommand('ping')" >/dev/null 2>&1; then
        log_success "MongoDB connection successful"
        return $STATUS_OK
    else
        log_error "Cannot connect to MongoDB at $MONGODB_HOST:$MONGODB_PORT"
        HEALTH_ISSUES+=("MongoDB connection failed")
        return $STATUS_CRITICAL
    fi
}

# Check server status
check_server_status() {
    log_info "Checking server status..."
    
    local server_status=$(mongo_exec "JSON.stringify(db.runCommand('serverStatus'))")
    
    if [[ $? -eq 0 ]]; then
        local version=$(echo "$server_status" | jq -r '.version')
        local uptime=$(echo "$server_status" | jq -r '.uptime')
        local uptime_hours=$((uptime / 3600))
        
        log_success "MongoDB version: $version, uptime: ${uptime_hours}h"
        
        # Check if server is primary (for replica sets)
        local is_master=$(echo "$server_status" | jq -r '.repl.ismaster // false')
        if [[ "$is_master" == "true" ]]; then
            log_success "Server is PRIMARY"
        fi
        
        return $STATUS_OK
    else
        log_error "Failed to get server status"
        HEALTH_ISSUES+=("Server status check failed")
        return $STATUS_CRITICAL
    fi
}

# Check database statistics
check_database_stats() {
    log_info "Checking database statistics..."
    
    local db_stats=$(mongo_exec "
        var dbs = db.adminCommand('listDatabases');
        var totalSize = 0;
        var dbCount = 0;
        
        dbs.databases.forEach(function(database) {
            if (database.name !== 'admin' && database.name !== 'local' && database.name !== 'config') {
                totalSize += database.sizeOnDisk || 0;
                dbCount++;
            }
        });
        
        JSON.stringify({
            totalDatabases: dbCount,
            totalSizeGB: Math.round(totalSize / (1024*1024*1024) * 100) / 100,
            databases: dbs.databases.length
        });
    ")
    
    if [[ $? -eq 0 ]]; then
        local total_dbs=$(echo "$db_stats" | jq -r '.totalDatabases')
        local total_size=$(echo "$db_stats" | jq -r '.totalSizeGB')
        
        log_success "Databases: $total_dbs, Total size: ${total_size}GB"
        return $STATUS_OK
    else
        log_warning "Failed to get database statistics"
        return $STATUS_WARNING
    fi
}

# Check replica set status
check_replica_set() {
    log_info "Checking replica set status..."
    
    local rs_status=$(mongo_exec "
        try {
            var status = rs.status();
            JSON.stringify({
                set: status.set,
                members: status.members.length,
                primary: status.members.find(m => m.state === 1) ? 
                    status.members.find(m => m.state === 1).name : 'none',
                healthy: status.members.filter(m => m.health === 1).length
            });
        } catch(e) {
            JSON.stringify({error: 'Not a replica set member'});
        }
    ")
    
    if [[ $? -eq 0 ]]; then
        local error=$(echo "$rs_status" | jq -r '.error // empty')
        
        if [[ -n "$error" ]]; then
            log_info "Not running as replica set"
            return $STATUS_OK
        fi
        
        local set_name=$(echo "$rs_status" | jq -r '.set')
        local members=$(echo "$rs_status" | jq -r '.members')
        local primary=$(echo "$rs_status" | jq -r '.primary')
        local healthy=$(echo "$rs_status" | jq -r '.healthy')
        
        if [[ "$healthy" -eq "$members" ]]; then
            log_success "Replica set '$set_name': $healthy/$members members healthy, primary: $primary"
            return $STATUS_OK
        else
            log_warning "Replica set '$set_name': only $healthy/$members members healthy"
            HEALTH_ISSUES+=("Replica set has unhealthy members")
            return $STATUS_WARNING
        fi
    else
        log_error "Failed to check replica set status"
        return $STATUS_CRITICAL
    fi
}

# Check sharding status
check_sharding() {
    log_info "Checking sharding status..."
    
    local shard_status=$(mongo_exec "
        try {
            var shards = db.adminCommand('listShards');
            var chunks = db.getSiblingDB('config').chunks.count();
            JSON.stringify({
                shards: shards.shards ? shards.shards.length : 0,
                chunks: chunks,
                isSharded: true
            });
        } catch(e) {
            JSON.stringify({isSharded: false});
        }
    ")
    
    if [[ $? -eq 0 ]]; then
        local is_sharded=$(echo "$shard_status" | jq -r '.isSharded')
        
        if [[ "$is_sharded" == "true" ]]; then
            local shards=$(echo "$shard_status" | jq -r '.shards')
            local chunks=$(echo "$shard_status" | jq -r '.chunks')
            
            log_success "Sharded cluster: $shards shards, $chunks chunks"
            return $STATUS_OK
        else
            log_info "Not running in sharded mode"
            return $STATUS_OK
        fi
    else
        log_error "Failed to check sharding status"
        return $STATUS_CRITICAL
    fi
}

# Check performance metrics
check_performance() {
    log_info "Checking performance metrics..."
    
    local perf_stats=$(mongo_exec "
        var status = db.runCommand('serverStatus');
        JSON.stringify({
            connections: {
                current: status.connections.current,
                available: status.connections.available,
                totalCreated: status.connections.totalCreated
            },
            opcounters: status.opcounters,
            mem: status.mem,
            globalLock: status.globalLock,
            wiredTiger: status.wiredTiger ? {
                cache: status.wiredTiger.cache,
                concurrentTransactions: status.wiredTiger.concurrentTransactions
            } : null
        });
    ")
    
    if [[ $? -eq 0 ]]; then
        # Check connections
        local current_conn=$(echo "$perf_stats" | jq -r '.connections.current')
        local available_conn=$(echo "$perf_stats" | jq -r '.connections.available')
        local conn_usage=$((current_conn * 100 / (current_conn + available_conn)))
        
        if [[ $conn_usage -gt $CONNECTIONS_THRESHOLD ]]; then
            log_warning "High connection usage: ${conn_usage}% ($current_conn connections)"
            HEALTH_ISSUES+=("High connection usage: ${conn_usage}%")
            OVERALL_STATUS=$STATUS_WARNING
        else
            log_success "Connection usage: ${conn_usage}% ($current_conn connections)"
        fi
        
        # Check memory usage
        local resident_mb=$(echo "$perf_stats" | jq -r '.mem.resident')
        local virtual_mb=$(echo "$perf_stats" | jq -r '.mem.virtual')
        
        log_success "Memory usage: ${resident_mb}MB resident, ${virtual_mb}MB virtual"
        
        # Check global lock
        local lock_ratio=$(echo "$perf_stats" | jq -r '.globalLock.ratio // 0')
        if (( $(echo "$lock_ratio > 0.1" | bc -l) )); then
            log_warning "High global lock ratio: $lock_ratio"
            HEALTH_ISSUES+=("High global lock ratio: $lock_ratio")
            OVERALL_STATUS=$STATUS_WARNING
        fi
        
        return $STATUS_OK
    else
        log_error "Failed to get performance statistics"
        return $STATUS_CRITICAL
    fi
}

# Check disk usage
check_disk_usage() {
    log_info "Checking disk usage..."
    
    local data_dir="/var/lib/mongodb"
    if [[ -d "$data_dir" ]]; then
        local disk_usage=$(df "$data_dir" | tail -1 | awk '{print $5}' | sed 's/%//')
        
        if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
            log_error "Critical disk usage: ${disk_usage}%"
            HEALTH_ISSUES+=("Critical disk usage: ${disk_usage}%")
            return $STATUS_CRITICAL
        elif [[ $disk_usage -gt $((DISK_THRESHOLD - 10)) ]]; then
            log_warning "High disk usage: ${disk_usage}%"
            HEALTH_ISSUES+=("High disk usage: ${disk_usage}%")
            return $STATUS_WARNING
        else
            log_success "Disk usage: ${disk_usage}%"
            return $STATUS_OK
        fi
    else
        log_warning "Cannot check disk usage - data directory not found"
        return $STATUS_WARNING
    fi
}

# Check slow queries
check_slow_queries() {
    log_info "Checking for slow queries..."
    
    local slow_queries=$(mongo_exec "
        db.runCommand('profile', -1).was > 0 ? 
        db.system.profile.find().limit(10).toArray().length : 0
    ")
    
    if [[ $slow_queries -gt 0 ]]; then
        log_warning "Found $slow_queries recent slow queries"
        HEALTH_ISSUES+=("Slow queries detected: $slow_queries")
        return $STATUS_WARNING
    else
        log_success "No recent slow queries found"
        return $STATUS_OK
    fi
}

# Check index usage
check_index_usage() {
    log_info "Checking index usage..."
    
    local index_stats=$(mongo_exec "
        var dbs = db.adminCommand('listDatabases');
        var totalIndexes = 0;
        var unusedIndexes = 0;
        
        dbs.databases.forEach(function(database) {
            if (database.name !== 'admin' && database.name !== 'local' && database.name !== 'config') {
                var db_conn = db.getSiblingDB(database.name);
                var collections = db_conn.getCollectionNames();
                
                collections.forEach(function(collection) {
                    var indexes = db_conn[collection].getIndexes();
                    totalIndexes += indexes.length;
                    
                    indexes.forEach(function(index) {
                        var stats = db_conn[collection].aggregate([
                            {'\$indexStats': {}},
                            {'\$match': {'name': index.name}}
                        ]).toArray();
                        
                        if (stats.length > 0 && stats[0].accesses.ops === 0) {
                            unusedIndexes++;
                        }
                    });
                });
            }
        });
        
        JSON.stringify({
            totalIndexes: totalIndexes,
            unusedIndexes: unusedIndexes
        });
    ")
    
    if [[ $? -eq 0 ]]; then
        local total=$(echo "$index_stats" | jq -r '.totalIndexes')
        local unused=$(echo "$index_stats" | jq -r '.unusedIndexes')
        
        if [[ $unused -gt 0 ]]; then
            log_warning "Found $unused unused indexes out of $total total"
            HEALTH_ISSUES+=("Unused indexes detected: $unused")
            return $STATUS_WARNING
        else
            log_success "Index usage: $total indexes, all in use"
            return $STATUS_OK
        fi
    else
        log_warning "Failed to check index usage"
        return $STATUS_WARNING
    fi
}

# Check oplog status (for replica sets)
check_oplog() {
    log_info "Checking oplog status..."
    
    local oplog_stats=$(mongo_exec "
        try {
            var oplogStats = db.getSiblingDB('local').oplog.rs.stats();
            var firstEntry = db.getSiblingDB('local').oplog.rs.find().sort({'\$natural': 1}).limit(1).toArray()[0];
            var lastEntry = db.getSiblingDB('local').oplog.rs.find().sort({'\$natural': -1}).limit(1).toArray()[0];
            
            var timeDiff = (lastEntry.ts.getTime() - firstEntry.ts.getTime()) / 1000;
            var hours = Math.round(timeDiff / 3600 * 100) / 100;
            
            JSON.stringify({
                sizeGB: Math.round(oplogStats.size / (1024*1024*1024) * 100) / 100,
                hours: hours,
                count: oplogStats.count
            });
        } catch(e) {
            JSON.stringify({error: 'Not a replica set'});
        }
    ")
    
    if [[ $? -eq 0 ]]; then
        local error=$(echo "$oplog_stats" | jq -r '.error // empty')
        
        if [[ -n "$error" ]]; then
            log_info "Oplog check skipped (not a replica set)"
            return $STATUS_OK
        fi
        
        local size=$(echo "$oplog_stats" | jq -r '.sizeGB')
        local hours=$(echo "$oplog_stats" | jq -r '.hours')
        local count=$(echo "$oplog_stats" | jq -r '.count')
        
        if (( $(echo "$hours < 24" | bc -l) )); then
            log_warning "Oplog window is less than 24 hours: ${hours}h"
            HEALTH_ISSUES+=("Short oplog window: ${hours}h")
            return $STATUS_WARNING
        else
            log_success "Oplog: ${size}GB, ${hours}h window, $count entries"
            return $STATUS_OK
        fi
    else
        log_error "Failed to check oplog status"
        return $STATUS_CRITICAL
    fi
}

# Generate metrics in JSON format
generate_metrics() {
    local metrics=$(mongo_exec "
        var status = db.runCommand('serverStatus');
        JSON.stringify({
            timestamp: new Date().toISOString(),
            host: '$MONGODB_HOST:$MONGODB_PORT',
            version: status.version,
            uptime: status.uptime,
            connections: status.connections,
            opcounters: status.opcounters,
            memory: status.mem,
            network: status.network,
            globalLock: status.globalLock,
            wiredTiger: status.wiredTiger || {}
        });
    ")
    
    echo "$metrics" > "$METRICS_FILE"
    log_info "Metrics saved to $METRICS_FILE"
}

# Send Slack notification
send_slack_notification() {
    local status="$1"
    local message="$2"
    
    if [[ -z "$SLACK_WEBHOOK" ]]; then
        return 0
    fi
    
    local color="good"
    [[ $status == "WARNING" ]] && color="warning"
    [[ $status == "CRITICAL" ]] && color="danger"
    
    local payload=$(cat <<EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "MongoDB Health Check - $status",
            "text": "$message",
            "fields": [
                {
                    "title": "Host",
                    "value": "$MONGODB_HOST:$MONGODB_PORT",
                    "short": true
                },
                {
                    "title": "Time",
                    "value": "$(date)",
                    "short": true
                }
            ]
        }
    ]
}
EOF
    )
    
    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" "$SLACK_WEBHOOK" >/dev/null 2>&1
}

# Send email notification
send_email_notification() {
    local status="$1"
    local message="$2"
    
    if [[ -z "$EMAIL_ALERT" ]]; then
        return 0
    fi
    
    local subject="MongoDB Health Check - $status on $(hostname)"
    echo "$message" | mail -s "$subject" "$EMAIL_ALERT"
}

# Output results based on format
output_results() {
    local status="$1"
    local message="$2"
    
    case "$OUTPUT_FORMAT" in
        "json")
            cat <<EOF
{
    "status": "$status",
    "message": "$message",
    "host": "$MONGODB_HOST:$MONGODB_PORT",
    "timestamp": "$(date -Iseconds)",
    "issues": [$(printf '"%s",' "${HEALTH_ISSUES[@]}" | sed 's/,$//')],
    "exit_code": $OVERALL_STATUS
}
EOF
            ;;
        "nagios")
            echo "MongoDB $status - $message | issues=${#HEALTH_ISSUES[@]}"
            ;;
        *)
            echo ""
            echo "=== MongoDB Health Check Summary ==="
            echo "Host: $MONGODB_HOST:$MONGODB_PORT"
            echo "Status: $status"
            echo "Message: $message"
            echo "Time: $(date)"
            
            if [[ ${#HEALTH_ISSUES[@]} -gt 0 ]]; then
                echo ""
                echo "Issues found:"
                for issue in "${HEALTH_ISSUES[@]}"; do
                    echo "  - $issue"
                done
            fi
            ;;
    esac
}

# Main health check function
main() {
    log_info "Starting MongoDB health check..."
    
    # Load thresholds
    load_thresholds
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Run checks based on type
    case "$CHECK_TYPE" in
        "basic")
            check_connectivity
            check_server_status
            check_database_stats
            ;;
        "replica")
            check_connectivity
            check_replica_set
            check_oplog
            ;;
        "sharding")
            check_connectivity
            check_sharding
            ;;
        "performance")
            check_connectivity
            check_performance
            check_disk_usage
            check_slow_queries
            ;;
        "all"|*)
            check_connectivity || OVERALL_STATUS=$STATUS_CRITICAL
            check_server_status || OVERALL_STATUS=$STATUS_CRITICAL
            check_database_stats
            check_replica_set
            check_sharding
            check_performance
            check_disk_usage
            check_slow_queries
            check_index_usage
            check_oplog
            ;;
    esac
    
    # Generate metrics
    generate_metrics
    
    # Determine overall status
    local status_text="OK"
    local message="All checks passed"
    
    if [[ $OVERALL_STATUS -eq $STATUS_CRITICAL ]]; then
        status_text="CRITICAL"
        message="Critical issues detected"
    elif [[ $OVERALL_STATUS -eq $STATUS_WARNING ]]; then
        status_text="WARNING"
        message="Warning conditions detected"
    elif [[ ${#HEALTH_ISSUES[@]} -gt 0 ]]; then
        status_text="WARNING"
        message="Some issues detected"
        OVERALL_STATUS=$STATUS_WARNING
    fi
    
    # Output results
    output_results "$status_text" "$message"
    
    # Send notifications if issues found
    if [[ $OVERALL_STATUS -ne $STATUS_OK ]]; then
        send_slack_notification "$status_text" "$message"
        send_email_notification "$status_text" "$message"
    fi
    
    # Exit with appropriate code
    exit $OVERALL_STATUS
}

# Run main function
main "$@"