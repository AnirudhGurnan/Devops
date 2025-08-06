#!/bin/bash

# MongoDB User and Security Management Script
# Comprehensive user management for MongoDB
# Usage: ./user-management.sh [command] [options]

set -e

# Default configuration
MONGODB_HOST="localhost"
MONGODB_PORT="27017"
MONGODB_ADMIN_USER=""
MONGODB_ADMIN_PASSWORD=""
MONGODB_AUTH_DB="admin"
ACTION=""
USERNAME=""
PASSWORD=""
ROLES=""
DATABASE="admin"
UPDATE_PASSWORD=false
DRY_RUN=false

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
        create|delete|update|list|enable|disable|change-password|audit)
            ACTION="$1"
            shift
            ;;
        --host)
            MONGODB_HOST="$2"
            shift 2
            ;;
        --port)
            MONGODB_PORT="$2"
            shift 2
            ;;
        --admin-user)
            MONGODB_ADMIN_USER="$2"
            shift 2
            ;;
        --admin-password)
            MONGODB_ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --username)
            USERNAME="$2"
            shift 2
            ;;
        --password)
            PASSWORD="$2"
            shift 2
            ;;
        --roles)
            ROLES="$2"
            shift 2
            ;;
        --database)
            DATABASE="$2"
            shift 2
            ;;
        --update-password)
            UPDATE_PASSWORD=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
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
MongoDB User and Security Management Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  create              Create a new user
  delete              Delete a user
  update              Update user roles
  list                List all users
  enable              Enable a user account
  disable             Disable a user account
  change-password     Change user password
  audit               Show user access audit

Connection Options:
  --host HOST         MongoDB host (default: localhost)
  --port PORT         MongoDB port (default: 27017)
  --admin-user USER   Admin username for authentication
  --admin-password    Admin password for authentication

User Options:
  --username USER     Target username
  --password PASS     User password
  --roles ROLES       Comma-separated roles (e.g., "read,readWrite")
  --database DB       Target database (default: admin)
  --update-password   Update password during user update
  --dry-run           Show what would be done without executing

Built-in Roles:
  Database User Roles:
    - read            Provides read access to all non-system collections
    - readWrite       Provides read and write access to all non-system collections
  
  Database Administration Roles:
    - dbAdmin         Provides administrative privileges on a database
    - dbOwner         Provides full privileges on a database
    - userAdmin       Provides user administration privileges on a database
  
  Cluster Administration Roles:
    - clusterAdmin    Provides administrative privileges on the cluster
    - clusterManager  Provides management and monitoring privileges on the cluster
    - clusterMonitor  Provides read-only access to monitoring tools
    - hostManager     Provides monitoring and management privileges on the host
  
  Backup and Restoration Roles:
    - backup          Provides privileges needed to back up data
    - restore         Provides privileges needed to restore data
  
  All-Database Roles:
    - readAnyDatabase    Provides read privileges on all databases
    - readWriteAnyDatabase Provides read and write privileges on all databases
    - userAdminAnyDatabase Provides user administration privileges on all databases
    - dbAdminAnyDatabase   Provides database administration privileges on all databases
  
  Superuser Roles:
    - root            Provides superuser privileges

Examples:
  # Create a read-only user for a specific database
  $0 create --username reader --password secret123 --roles read --database myapp

  # Create an application user with read-write access
  $0 create --username appuser --password apppass123 --roles readWrite --database myapp

  # Create a database administrator
  $0 create --username dbadmin --password adminpass123 --roles dbAdmin,userAdmin --database myapp

  # Create a backup user
  $0 create --username backup --password backuppass123 --roles backup,clusterMonitor

  # Create a monitoring user
  $0 create --username monitor --password monitorpass123 --roles clusterMonitor,read

  # List all users
  $0 list

  # Update user roles
  $0 update --username appuser --roles readWrite,dbAdmin --database myapp

  # Change user password
  $0 change-password --username appuser --password newpassword123

  # Delete a user
  $0 delete --username olduser

  # Audit user access
  $0 audit --username appuser
EOF
}

# Get MongoDB connection parameters
get_connection_params() {
    local params="--host $MONGODB_HOST --port $MONGODB_PORT --quiet"
    if [[ -n "$MONGODB_ADMIN_USER" ]]; then
        params="$params --username $MONGODB_ADMIN_USER --password $MONGODB_ADMIN_PASSWORD --authenticationDatabase admin"
    fi
    echo "$params"
}

# Execute MongoDB command
mongo_exec() {
    local command="$1"
    local connection_params=$(get_connection_params)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would execute: $command"
        return 0
    fi
    
    mongosh $connection_params --eval "$command" 2>/dev/null
}

# Generate secure password
generate_password() {
    local length=${1:-16}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Validate roles
validate_roles() {
    local roles="$1"
    local valid_roles=(
        "read" "readWrite" "dbAdmin" "dbOwner" "userAdmin"
        "clusterAdmin" "clusterManager" "clusterMonitor" "hostManager"
        "backup" "restore"
        "readAnyDatabase" "readWriteAnyDatabase" "userAdminAnyDatabase" "dbAdminAnyDatabase"
        "root"
    )
    
    IFS=',' read -ra ROLE_ARRAY <<< "$roles"
    for role in "${ROLE_ARRAY[@]}"; do
        if [[ ! " ${valid_roles[@]} " =~ " ${role} " ]]; then
            log_warning "Unknown role: $role"
        fi
    done
}

# Create user
create_user() {
    if [[ -z "$USERNAME" || -z "$PASSWORD" || -z "$ROLES" ]]; then
        log_error "Username, password, and roles are required for user creation"
        return 1
    fi
    
    validate_roles "$ROLES"
    
    log_info "Creating user '$USERNAME' with roles: $ROLES"
    
    # Convert comma-separated roles to MongoDB array format
    local roles_array=""
    IFS=',' read -ra ROLE_ARRAY <<< "$ROLES"
    for role in "${ROLE_ARRAY[@]}"; do
        if [[ -n "$roles_array" ]]; then
            roles_array="$roles_array, "
        fi
        roles_array="$roles_array{role: '$role', db: '$DATABASE'}"
    done
    
    local create_command="
        use $DATABASE;
        db.createUser({
            user: '$USERNAME',
            pwd: '$PASSWORD',
            roles: [$roles_array]
        });
    "
    
    if mongo_exec "$create_command"; then
        log_success "User '$USERNAME' created successfully"
    else
        log_error "Failed to create user '$USERNAME'"
        return 1
    fi
}

# Delete user
delete_user() {
    if [[ -z "$USERNAME" ]]; then
        log_error "Username is required for user deletion"
        return 1
    fi
    
    log_info "Deleting user '$USERNAME' from database '$DATABASE'"
    
    local delete_command="
        use $DATABASE;
        db.dropUser('$USERNAME');
    "
    
    if mongo_exec "$delete_command"; then
        log_success "User '$USERNAME' deleted successfully"
    else
        log_error "Failed to delete user '$USERNAME'"
        return 1
    fi
}

# Update user roles
update_user() {
    if [[ -z "$USERNAME" || -z "$ROLES" ]]; then
        log_error "Username and roles are required for user update"
        return 1
    fi
    
    validate_roles "$ROLES"
    
    log_info "Updating user '$USERNAME' with roles: $ROLES"
    
    # Convert comma-separated roles to MongoDB array format
    local roles_array=""
    IFS=',' read -ra ROLE_ARRAY <<< "$ROLES"
    for role in "${ROLE_ARRAY[@]}"; do
        if [[ -n "$roles_array" ]]; then
            roles_array="$roles_array, "
        fi
        roles_array="$roles_array{role: '$role', db: '$DATABASE'}"
    done
    
    local update_command="
        use $DATABASE;
        db.updateUser('$USERNAME', {
            roles: [$roles_array]
        });
    "
    
    # Update password if requested
    if [[ "$UPDATE_PASSWORD" == "true" && -n "$PASSWORD" ]]; then
        update_command="
            use $DATABASE;
            db.updateUser('$USERNAME', {
                pwd: '$PASSWORD',
                roles: [$roles_array]
            });
        "
    fi
    
    if mongo_exec "$update_command"; then
        log_success "User '$USERNAME' updated successfully"
    else
        log_error "Failed to update user '$USERNAME'"
        return 1
    fi
}

# List users
list_users() {
    log_info "Listing all users..."
    
    local list_command="
        use admin;
        db.system.users.find({}, {user: 1, db: 1, roles: 1}).forEach(
            function(user) {
                print('User: ' + user.user + '@' + user.db);
                print('Roles: ' + JSON.stringify(user.roles, null, 2));
                print('---');
            }
        );
    "
    
    mongo_exec "$list_command"
}

# Change user password
change_password() {
    if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
        log_error "Username and new password are required"
        return 1
    fi
    
    log_info "Changing password for user '$USERNAME'"
    
    local change_command="
        use $DATABASE;
        db.changeUserPassword('$USERNAME', '$PASSWORD');
    "
    
    if mongo_exec "$change_command"; then
        log_success "Password changed successfully for user '$USERNAME'"
    else
        log_error "Failed to change password for user '$USERNAME'"
        return 1
    fi
}

# Enable user account
enable_user() {
    if [[ -z "$USERNAME" ]]; then
        log_error "Username is required"
        return 1
    fi
    
    log_info "Enabling user '$USERNAME'"
    
    local enable_command="
        use $DATABASE;
        db.runCommand({
            updateUser: '$USERNAME',
            mechanisms: ['SCRAM-SHA-1', 'SCRAM-SHA-256']
        });
    "
    
    if mongo_exec "$enable_command"; then
        log_success "User '$USERNAME' enabled successfully"
    else
        log_error "Failed to enable user '$USERNAME'"
        return 1
    fi
}

# Disable user account
disable_user() {
    if [[ -z "$USERNAME" ]]; then
        log_error "Username is required"
        return 1
    fi
    
    log_info "Disabling user '$USERNAME'"
    
    local disable_command="
        use $DATABASE;
        db.runCommand({
            updateUser: '$USERNAME',
            mechanisms: []
        });
    "
    
    if mongo_exec "$disable_command"; then
        log_success "User '$USERNAME' disabled successfully"
    else
        log_error "Failed to disable user '$USERNAME'"
        return 1
    fi
}

# Audit user access
audit_user() {
    if [[ -z "$USERNAME" ]]; then
        log_error "Username is required for audit"
        return 1
    fi
    
    log_info "Auditing access for user '$USERNAME'..."
    
    local audit_command="
        use admin;
        var user = db.system.users.findOne({user: '$USERNAME'});
        if (user) {
            print('=== User Audit Report ===');
            print('Username: ' + user.user);
            print('Database: ' + user.db);
            print('Created: ' + (user.credentials ? 'Yes' : 'No'));
            print('');
            print('Roles and Privileges:');
            user.roles.forEach(function(role) {
                print('  Role: ' + role.role + ' on database: ' + role.db);
            });
            print('');
            print('Inherited Roles:');
            user.inheritedRoles && user.inheritedRoles.forEach(function(role) {
                print('  Inherited: ' + role.role + ' on database: ' + role.db);
            });
            print('');
            print('Authentication Methods:');
            if (user.credentials) {
                Object.keys(user.credentials).forEach(function(method) {
                    print('  ' + method + ': Enabled');
                });
            }
        } else {
            print('User not found: $USERNAME');
        }
    "
    
    mongo_exec "$audit_command"
}

# Setup security best practices
setup_security() {
    log_info "Setting up MongoDB security best practices..."
    
    local security_command="
        use admin;
        
        // Enable authentication
        print('Checking authentication status...');
        var serverStatus = db.runCommand('serverStatus');
        if (serverStatus.security && serverStatus.security.authentication) {
            print('Authentication is enabled');
        } else {
            print('WARNING: Authentication may not be enabled');
        }
        
        // Check for default users
        print('Checking for default/weak users...');
        db.system.users.find({user: {\$in: ['admin', 'root', 'test', 'guest']}}).forEach(function(user) {
            print('WARNING: Found default user: ' + user.user);
        });
        
        // Check role assignments
        print('Checking role assignments...');
        db.system.users.find().forEach(function(user) {
            user.roles.forEach(function(role) {
                if (role.role === 'root' || role.role === 'readWriteAnyDatabase') {
                    print('WARNING: User ' + user.user + ' has high-privilege role: ' + role.role);
                }
            });
        });
    "
    
    mongo_exec "$security_command"
}

# Main function
main() {
    if [[ -z "$ACTION" ]]; then
        log_error "No action specified"
        show_help
        exit 1
    fi
    
    # Check MongoDB connection
    if ! mongo_exec "db.runCommand('ping')" >/dev/null 2>&1; then
        log_error "Cannot connect to MongoDB at $MONGODB_HOST:$MONGODB_PORT"
        exit 1
    fi
    
    case "$ACTION" in
        "create")
            create_user
            ;;
        "delete")
            delete_user
            ;;
        "update")
            update_user
            ;;
        "list")
            list_users
            ;;
        "enable")
            enable_user
            ;;
        "disable")
            disable_user
            ;;
        "change-password")
            change_password
            ;;
        "audit")
            audit_user
            ;;
        "security-check")
            setup_security
            ;;
        *)
            log_error "Unknown action: $ACTION"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"