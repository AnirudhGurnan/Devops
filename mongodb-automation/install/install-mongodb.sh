#!/bin/bash

# MongoDB Installation Script
# Supports Ubuntu/Debian, CentOS/RHEL, and Amazon Linux
# Usage: ./install-mongodb.sh [version] [--replica-set] [--config-server] [--shard-server]

set -e

# Default configuration
MONGODB_VERSION="${1:-7.0}"
INSTALL_TYPE="standalone"
DATA_DIR="/var/lib/mongodb"
LOG_DIR="/var/log/mongodb"
CONFIG_FILE="/etc/mongod.conf"
SERVICE_USER="mongod"
SERVICE_GROUP="mongod"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --replica-set)
            INSTALL_TYPE="replica-set"
            shift
            ;;
        --config-server)
            INSTALL_TYPE="config-server"
            shift
            ;;
        --shard-server)
            INSTALL_TYPE="shard-server"
            shift
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [version] [options]"
            echo "Options:"
            echo "  --replica-set     Install for replica set"
            echo "  --config-server   Install as config server"
            echo "  --shard-server    Install as shard server"
            echo "  --data-dir DIR    Custom data directory"
            echo "  --log-dir DIR     Custom log directory"
            exit 0
            ;;
        *)
            if [[ $1 =~ ^[0-9]+\.[0-9]+$ ]]; then
                MONGODB_VERSION="$1"
            fi
            shift
            ;;
    esac
done

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        log_error "Cannot detect operating system"
        exit 1
    fi
    
    log_info "Detected OS: $OS $VER"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Create MongoDB user and directories
create_user_and_dirs() {
    log_info "Creating MongoDB user and directories..."
    
    # Create user and group
    if ! getent group $SERVICE_GROUP > /dev/null 2>&1; then
        groupadd $SERVICE_GROUP
    fi
    
    if ! getent passwd $SERVICE_USER > /dev/null 2>&1; then
        useradd -r -g $SERVICE_GROUP -d /var/lib/mongodb -s /bin/false $SERVICE_USER
    fi
    
    # Create directories
    mkdir -p $DATA_DIR $LOG_DIR /etc/mongodb
    chown -R $SERVICE_USER:$SERVICE_GROUP $DATA_DIR $LOG_DIR
    chmod 755 $DATA_DIR $LOG_DIR
    
    log_success "User and directories created"
}

# Install MongoDB on Ubuntu/Debian
install_ubuntu_debian() {
    log_info "Installing MongoDB on Ubuntu/Debian..."
    
    # Install dependencies
    apt-get update
    apt-get install -y wget gnupg curl
    
    # Add MongoDB repository
    curl -fsSL https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc | \
        gpg -o /usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg --dearmor
    
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg ] \
        https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/${MONGODB_VERSION} multiverse" | \
        tee /etc/apt/sources.list.d/mongodb-org-${MONGODB_VERSION}.list
    
    # Install MongoDB
    apt-get update
    apt-get install -y mongodb-org
    
    # Hold packages to prevent accidental upgrades
    apt-mark hold mongodb-org mongodb-org-database mongodb-org-server \
        mongodb-org-shell mongodb-org-mongos mongodb-org-tools
}

# Install MongoDB on CentOS/RHEL
install_centos_rhel() {
    log_info "Installing MongoDB on CentOS/RHEL..."
    
    # Create repository file
    cat > /etc/yum.repos.d/mongodb-org-${MONGODB_VERSION}.repo << EOF
[mongodb-org-${MONGODB_VERSION}]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/${MONGODB_VERSION}/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc
EOF
    
    # Install MongoDB
    yum install -y mongodb-org
    
    # Exclude MongoDB packages from updates
    echo "exclude=mongodb-org,mongodb-org-database,mongodb-org-server,mongodb-org-shell,mongodb-org-mongos,mongodb-org-tools" >> /etc/yum.conf
}

# Install MongoDB on Amazon Linux
install_amazon_linux() {
    log_info "Installing MongoDB on Amazon Linux..."
    
    # Create repository file
    cat > /etc/yum.repos.d/mongodb-org-${MONGODB_VERSION}.repo << EOF
[mongodb-org-${MONGODB_VERSION}]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/${MONGODB_VERSION}/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc
EOF
    
    # Install MongoDB
    yum install -y mongodb-org
}

# Generate MongoDB configuration
generate_config() {
    log_info "Generating MongoDB configuration for $INSTALL_TYPE..."
    
    case $INSTALL_TYPE in
        "replica-set")
            generate_replica_config
            ;;
        "config-server")
            generate_config_server_config
            ;;
        "shard-server")
            generate_shard_server_config
            ;;
        *)
            generate_standalone_config
            ;;
    esac
}

# Generate standalone configuration
generate_standalone_config() {
    cat > $CONFIG_FILE << EOF
# MongoDB Configuration File - Standalone
storage:
  dbPath: $DATA_DIR
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1

systemLog:
  destination: file
  logAppend: true
  path: $LOG_DIR/mongod.log
  logRotate: rename

net:
  port: 27017
  bindIp: 127.0.0.1,$(hostname -I | awk '{print $1}')

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled

setParameter:
  enableLocalhostAuthBypass: false
EOF
}

# Generate replica set configuration
generate_replica_config() {
    cat > $CONFIG_FILE << EOF
# MongoDB Configuration File - Replica Set
storage:
  dbPath: $DATA_DIR
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1

systemLog:
  destination: file
  logAppend: true
  path: $LOG_DIR/mongod.log
  logRotate: rename

net:
  port: 27017
  bindIp: 0.0.0.0

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled
  keyFile: /etc/mongodb/keyfile

replication:
  replSetName: rs0

setParameter:
  enableLocalhostAuthBypass: false
EOF
}

# Generate config server configuration
generate_config_server_config() {
    cat > $CONFIG_FILE << EOF
# MongoDB Configuration File - Config Server
storage:
  dbPath: $DATA_DIR
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 0.5

systemLog:
  destination: file
  logAppend: true
  path: $LOG_DIR/mongod.log
  logRotate: rename

net:
  port: 27019
  bindIp: 0.0.0.0

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled
  keyFile: /etc/mongodb/keyfile

sharding:
  clusterRole: configsvr

replication:
  replSetName: configReplSet

setParameter:
  enableLocalhostAuthBypass: false
EOF
}

# Generate shard server configuration
generate_shard_server_config() {
    cat > $CONFIG_FILE << EOF
# MongoDB Configuration File - Shard Server
storage:
  dbPath: $DATA_DIR
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 2

systemLog:
  destination: file
  logAppend: true
  path: $LOG_DIR/mongod.log
  logRotate: rename

net:
  port: 27018
  bindIp: 0.0.0.0

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled
  keyFile: /etc/mongodb/keyfile

sharding:
  clusterRole: shardsvr

replication:
  replSetName: shard0

setParameter:
  enableLocalhostAuthBypass: false
EOF
}

# Generate keyfile for replica sets and sharding
generate_keyfile() {
    if [[ $INSTALL_TYPE != "standalone" ]]; then
        log_info "Generating keyfile for authentication..."
        openssl rand -base64 756 > /etc/mongodb/keyfile
        chown $SERVICE_USER:$SERVICE_GROUP /etc/mongodb/keyfile
        chmod 400 /etc/mongodb/keyfile
        log_success "Keyfile generated"
    fi
}

# Create systemd service
create_service() {
    log_info "Creating systemd service..."
    
    # Create run directory
    mkdir -p /var/run/mongodb
    chown $SERVICE_USER:$SERVICE_GROUP /var/run/mongodb
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable mongod
    systemctl start mongod
    
    log_success "MongoDB service created and started"
}

# Configure firewall
configure_firewall() {
    log_info "Configuring firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        # Ubuntu/Debian firewall
        case $INSTALL_TYPE in
            "config-server")
                ufw allow 27019/tcp
                ;;
            "shard-server")
                ufw allow 27018/tcp
                ;;
            *)
                ufw allow 27017/tcp
                ;;
        esac
    elif command -v firewall-cmd >/dev/null 2>&1; then
        # CentOS/RHEL firewall
        case $INSTALL_TYPE in
            "config-server")
                firewall-cmd --permanent --add-port=27019/tcp
                ;;
            "shard-server")
                firewall-cmd --permanent --add-port=27018/tcp
                ;;
            *)
                firewall-cmd --permanent --add-port=27017/tcp
                ;;
        esac
        firewall-cmd --reload
    fi
    
    log_success "Firewall configured"
}

# Optimize system settings
optimize_system() {
    log_info "Optimizing system settings..."
    
    # Disable transparent huge pages
    cat > /etc/systemd/system/disable-transparent-huge-pages.service << EOF
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null'
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null'

[Install]
WantedBy=basic.target
EOF
    
    systemctl daemon-reload
    systemctl enable disable-transparent-huge-pages
    systemctl start disable-transparent-huge-pages
    
    # Set ulimits
    cat > /etc/security/limits.d/99-mongodb-nproc.conf << EOF
mongod soft nproc 32000
mongod hard nproc 32000
mongod soft nofile 64000
mongod hard nofile 64000
EOF
    
    # Set kernel parameters
    cat >> /etc/sysctl.conf << EOF

# MongoDB optimizations
net.core.somaxconn = 4096
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_max_syn_backlog = 4096
EOF
    
    sysctl -p
    
    log_success "System optimizations applied"
}

# Verify installation
verify_installation() {
    log_info "Verifying MongoDB installation..."
    
    # Check if service is running
    if systemctl is-active --quiet mongod; then
        log_success "MongoDB service is running"
    else
        log_error "MongoDB service is not running"
        return 1
    fi
    
    # Check if MongoDB is responding
    sleep 5
    local port
    case $INSTALL_TYPE in
        "config-server") port=27019 ;;
        "shard-server") port=27018 ;;
        *) port=27017 ;;
    esac
    
    if netstat -tulpn | grep -q ":$port "; then
        log_success "MongoDB is listening on port $port"
    else
        log_error "MongoDB is not listening on port $port"
        return 1
    fi
    
    # Show version
    local version=$(mongod --version | head -1)
    log_success "Installation verified: $version"
}

# Show post-installation information
show_post_install_info() {
    log_success "MongoDB installation completed!"
    echo ""
    echo "=== Installation Summary ==="
    echo "Type: $INSTALL_TYPE"
    echo "Version: $MONGODB_VERSION"
    echo "Data Directory: $DATA_DIR"
    echo "Log Directory: $LOG_DIR"
    echo "Configuration: $CONFIG_FILE"
    echo ""
    echo "=== Next Steps ==="
    case $INSTALL_TYPE in
        "standalone")
            echo "1. Connect to MongoDB: mongosh"
            echo "2. Create admin user:"
            echo "   use admin"
            echo "   db.createUser({user: 'admin', pwd: 'password', roles: ['root']})"
            ;;
        "replica-set")
            echo "1. Initialize replica set on primary:"
            echo "   rs.initiate()"
            echo "2. Add members: rs.add('hostname:27017')"
            echo "3. Create admin user on primary"
            ;;
        "config-server")
            echo "1. Initialize config replica set:"
            echo "   rs.initiate()"
            echo "2. Add config servers to replica set"
            ;;
        "shard-server")
            echo "1. Initialize shard replica set:"
            echo "   rs.initiate()"
            echo "2. Add shard members to replica set"
            ;;
    esac
    echo ""
    echo "=== Service Management ==="
    echo "Start:   systemctl start mongod"
    echo "Stop:    systemctl stop mongod"
    echo "Restart: systemctl restart mongod"
    echo "Status:  systemctl status mongod"
    echo "Logs:    tail -f $LOG_DIR/mongod.log"
}

# Main installation function
main() {
    log_info "Starting MongoDB $MONGODB_VERSION installation ($INSTALL_TYPE)"
    
    check_root
    detect_os
    create_user_and_dirs
    
    # Install based on OS
    case $OS in
        "Ubuntu"|"Debian"*)
            install_ubuntu_debian
            ;;
        "CentOS"*|"Red Hat"*|"Rocky"*|"AlmaLinux"*)
            install_centos_rhel
            ;;
        "Amazon Linux"*)
            install_amazon_linux
            ;;
        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    generate_config
    generate_keyfile
    optimize_system
    create_service
    configure_firewall
    verify_installation
    show_post_install_info
}

# Run main function
main "$@"