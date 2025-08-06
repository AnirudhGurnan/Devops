# Development Environment Configuration for MongoDB Atlas

# Atlas Organization and Project
project_name = "mongodb-dev-cluster"
environment = "development"

project_tags = {
  Environment = "development"
  Team        = "platform"
  Purpose     = "development-testing"
  Owner       = "devops-team"
}

# Cluster Configuration - Smaller for development
cluster_name    = "dev-mongodb-cluster"
mongodb_version = "7.0"

cluster_labels = {
  environment = "development"
  team        = "platform"
  purpose     = "dev-testing"
}

cluster_tags = {
  Environment = "development"
  Team        = "platform"
  CostCenter  = "engineering"
}

# Shards Configuration - Single shard for development
shards_config = [
  {
    num_shards = 1
    zone_name  = "Development Zone"
    regions = [
      {
        region_name             = "US_EAST_1"
        provider_name          = "AWS"
        priority               = 7
        electable_nodes        = 3
        read_only_nodes        = 0
        instance_size          = "M10"  # Smaller instance for dev
        min_instance_size      = "M10"
        max_instance_size      = "M30"
        analytics_instance_size = "M10"
        analytics_node_count    = 0     # No analytics for dev
        readonly_instance_size  = "M10"
      }
    ]
  }
]

# Backup Configuration - Shorter retention for dev
backup_enabled                 = true
pit_enabled                   = false  # Disabled for cost savings
termination_protection_enabled = false # Allow easy cleanup

# Feature flags - Minimal features for dev
bi_connector_enabled = false
auto_scaling_disk_gb_enabled = true
auto_scaling_compute_enabled = false  # Disabled for predictable costs
compute_scale_down_enabled   = false

# Network Access - More permissive for development
ip_access_list = {
  "10.0.0.0/8"    = "Internal development network"
  "172.16.0.0/12" = "Docker networks"
  "192.168.0.0/16" = "Local development"
}

# Database Users - Development users
database_users = {
  "dev_admin" = {
    username           = "dev_admin"
    password           = "DevAdminPassword123!"
    auth_database_name = "admin"
    roles = [
      {
        role_name     = "dbAdminAnyDatabase"
        database_name = "admin"
      }
    ]
    scopes = []
    labels = {
      environment = "development"
      purpose     = "administration"
    }
  }
  "dev_app" = {
    username           = "dev_app"
    password           = "DevAppPassword123!"
    auth_database_name = "admin"
    roles = [
      {
        role_name     = "readWriteAnyDatabase"
        database_name = "admin"
      }
    ]
    scopes = []
    labels = {
      environment = "development"
      purpose     = "application"
    }
  }
}

# AWS Configuration for development
aws_region = "us-east-1"

# Feature flags - Disabled for development
enable_private_endpoint = false
enable_network_peering  = false
enable_data_lake       = false
enable_search_index    = false