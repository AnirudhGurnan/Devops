#!/bin/bash

# MongoDB Sharded Cluster Status Check Script
# Usage: ./cluster-status.sh <mongos-host> [port]

MONGOS_HOST="${1:-localhost}"
MONGOS_PORT="${2:-27017}"

if [ -z "$1" ]; then
    echo "Usage: $0 <mongos-host> [port]"
    echo "Example: $0 10.0.1.100 27017"
    exit 1
fi

echo "Checking MongoDB Sharded Cluster Status..."
echo "Mongos Host: $MONGOS_HOST:$MONGOS_PORT"
echo "========================================"

# Check if mongos is reachable
if ! nc -z "$MONGOS_HOST" "$MONGOS_PORT" 2>/dev/null; then
    echo "ERROR: Cannot connect to mongos at $MONGOS_HOST:$MONGOS_PORT"
    exit 1
fi

# MongoDB commands to check cluster status
mongo "$MONGOS_HOST:$MONGOS_PORT" --quiet --eval "
print('\\n=== CLUSTER STATUS ===');
sh.status();

print('\\n=== CONFIG SERVERS ===');
sh.getConfigDB();

print('\\n=== SHARDS ===');
db.adminCommand('listShards');

print('\\n=== DATABASES ===');
db.adminCommand('listDatabases');

print('\\n=== BALANCER STATUS ===');
sh.getBalancerState();
sh.isBalancerRunning();
"

echo ""
echo "Status check completed."