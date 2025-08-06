# Production Environment Configuration for MongoDB Atlas

# Atlas Organization and Project
project_name = "mongodb-production-cluster"
environment = "production"

project_tags = {
  Environment = "production"
  Team        = "platform"
  Purpose     = "production-workload"
  Owner       = "platform-team"
  Compliance  = "required"
}

# Cluster Configuration - Production-ready
cluster_name    = "prod-mongodb-cluster"
mongodb_version = "7.0"

cluster_labels = {
  environment = "production"
  team        = "platform"
  purpose     = "production-database"
  compliance  = "required"
}

cluster_tags = {
  Environment = "production"
  Team        = "platform"
  CostCenter  = "engineering"
  Backup      = "required"
  Monitoring  = "critical"
}

# Shards Configuration - Full production setup
shards_config = [
  {
    num_shards = 2
    zone_name  = "Production Zone"
    regions = [
      {
        region_name             = "US_EAST_1"
        provider_name          = "AWS"
        priority               = 7
        electable_nodes        = 3
        read_only_nodes        = 1      # Read replicas for production
        instance_size          = "M30"  # Production instance size
        min_instance_size      = "M30"
        max_instance_size      = "M80"
        analytics_instance_size = "M30"
        analytics_node_count    = 1     # Analytics enabled
        readonly_instance_size  = "M30"
      },
      {
        region_name             = "US_WEST_2"
        provider_name          = "AWS"
        priority               = 6      # Secondary region
        electable_nodes        = 2
        read_only_nodes        = 1
        instance_size          = "M30"
        min_instance_size      = "M30"
        max_instance_size      = "M80"
        analytics_instance_size = "M30"
        analytics_node_count    = 0
        readonly_instance_size  = "M30"
      }
    ]
  }
]

# Backup Configuration - Full backup for production
backup_enabled                 = true
pit_enabled                   = true  # Point-in-time recovery enabled
termination_protection_enabled = true # Prevent accidental deletion

# Feature flags - Full features for production
bi_connector_enabled = true   # BI Connector for analytics
auto_scaling_disk_gb_enabled = true
auto_scaling_compute_enabled = true
compute_scale_down_enabled   = true

# Advanced Configuration - Production optimized
fail_index_key_too_long              = false
javascript_enabled                   = true
minimum_enabled_tls_protocol         = "TLS1_2"
no_table_scan                       = false
oplog_size_mb                       = 4096  # Larger oplog for production
sample_size_bi_connector            = 10000
sample_refresh_interval_bi_connector = 300
transaction_lifetime_limit_seconds   = 60

# Network Access - Restricted for production
ip_access_list = {
  "10.0.0.0/16"     = "Production VPC"
  "10.1.0.0/16"     = "Staging VPC"
  "203.0.113.0/24"  = "Office network"
  "198.51.100.0/24" = "DR site"
}

# Database Users - Production users with proper roles
database_users = {
  "prod_admin" = {
    username           = "prod_admin"
    password           = "ProdAdminSecurePassword123!"
    auth_database_name = "admin"
    roles = [
      {
        role_name     = "clusterAdmin"
        database_name = "admin"
      },
      {
        role_name     = "userAdminAnyDatabase"
        database_name = "admin"
      }
    ]
    scopes = []
    labels = {
      environment = "production"
      purpose     = "administration"
      compliance  = "required"
    }
  }
  "prod_app" = {
    username           = "prod_app"
    password           = "ProdAppSecurePassword123!"
    auth_database_name = "admin"
    roles = [
      {
        role_name     = "readWrite"
        database_name = "application"
      }
    ]
    scopes = [
      {
        name = "application"
        type = "DATABASE"
      }
    ]
    labels = {
      environment = "production"
      purpose     = "application"
    }
  }
  "prod_backup" = {
    username           = "prod_backup"
    password           = "ProdBackupSecurePassword123!"
    auth_database_name = "admin"
    roles = [
      {
        role_name     = "backup"
        database_name = "admin"
      },
      {
        role_name     = "clusterMonitor"
        database_name = "admin"
      }
    ]
    scopes = []
    labels = {
      environment = "production"
      purpose     = "backup"
    }
  }
  "prod_monitor" = {
    username           = "prod_monitor"
    password           = "ProdMonitorSecurePassword123!"
    auth_database_name = "admin"
    roles = [
      {
        role_name     = "clusterMonitor"
        database_name = "admin"
      },
      {
        role_name     = "read"
        database_name = "admin"
      }
    ]
    scopes = []
    labels = {
      environment = "production"
      purpose     = "monitoring"
    }
  }
}

# AWS Configuration for production
aws_region     = "us-east-1"
aws_account_id = "123456789012"

# VPC Configuration for private connectivity
aws_vpc_id   = "vpc-12345678"
aws_vpc_cidr = "10.0.0.0/16"

# Subnet IDs for private endpoints
aws_subnet_ids = [
  "subnet-12345678",
  "subnet-87654321",
  "subnet-abcdef12"
]

# Security Group IDs for private endpoints
aws_security_group_ids = [
  "sg-12345678"
]

# Atlas CIDR block for network peering
atlas_cidr_block = "192.168.248.0/21"

# Feature flags - Production features enabled
enable_private_endpoint = true   # Private connectivity
enable_network_peering  = true   # VPC peering for security
enable_data_lake       = true   # Data lake for analytics
enable_search_index    = true   # Search capabilities

# Data Lake Configuration
data_lake_database   = "analytics"
data_lake_collection = "events"
data_lake_s3_bucket  = "prod-mongodb-data-lake"

# Search Index Configuration
search_index_name       = "production_search_index"
search_index_database   = "application"
search_index_collection = "products"
search_index_mappings_dynamic = true