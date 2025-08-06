# MongoDB Atlas Provider Configuration
variable "mongodbatlas_public_key" {
  description = "MongoDB Atlas API public key"
  type        = string
  sensitive   = true
}

variable "mongodbatlas_private_key" {
  description = "MongoDB Atlas API private key"
  type        = string
  sensitive   = true
}

# Atlas Organization and Project
variable "atlas_org_id" {
  description = "MongoDB Atlas Organization ID"
  type        = string
}

variable "project_name" {
  description = "Name of the MongoDB Atlas project"
  type        = string
  default     = "mongodb-sharded-cluster"
}

variable "project_tags" {
  description = "Tags for the MongoDB Atlas project"
  type        = map(string)
  default = {
    Environment = "production"
    Team        = "platform"
    Purpose     = "sharded-cluster"
  }
}

# Cluster Configuration
variable "cluster_name" {
  description = "Name of the MongoDB Atlas cluster"
  type        = string
  default     = "mongodb-sharded-cluster"
}

variable "mongodb_version" {
  description = "MongoDB major version"
  type        = string
  default     = "7.0"
  validation {
    condition     = contains(["6.0", "7.0"], var.mongodb_version)
    error_message = "MongoDB version must be 6.0 or 7.0."
  }
}

variable "cluster_labels" {
  description = "Labels for the MongoDB cluster"
  type        = map(string)
  default = {
    environment = "production"
    team        = "platform"
  }
}

variable "cluster_tags" {
  description = "Tags for the MongoDB cluster"
  type        = map(string)
  default = {
    Environment = "production"
    Team        = "platform"
  }
}

# Shards Configuration
variable "shards_config" {
  description = "Configuration for sharded cluster"
  type = list(object({
    num_shards = number
    zone_name  = string
    regions = list(object({
      region_name               = string
      provider_name            = string
      priority                 = number
      electable_nodes          = number
      read_only_nodes          = number
      instance_size            = string
      min_instance_size        = string
      max_instance_size        = string
      analytics_instance_size  = string
      analytics_node_count     = number
      readonly_instance_size   = string
    }))
  }))
  default = [
    {
      num_shards = 2
      zone_name  = "Zone 1"
      regions = [
        {
          region_name             = "US_EAST_1"
          provider_name          = "AWS"
          priority               = 7
          electable_nodes        = 3
          read_only_nodes        = 0
          instance_size          = "M30"
          min_instance_size      = "M10"
          max_instance_size      = "M80"
          analytics_instance_size = "M30"
          analytics_node_count    = 1
          readonly_instance_size  = "M30"
        }
      ]
    }
  ]
}

# Backup Configuration
variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "pit_enabled" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "termination_protection_enabled" {
  description = "Enable termination protection"
  type        = bool
  default     = true
}

# BI Connector Configuration
variable "bi_connector_enabled" {
  description = "Enable BI Connector"
  type        = bool
  default     = false
}

# Auto-scaling Configuration
variable "auto_scaling_disk_gb_enabled" {
  description = "Enable disk auto-scaling"
  type        = bool
  default     = true
}

variable "auto_scaling_compute_enabled" {
  description = "Enable compute auto-scaling"
  type        = bool
  default     = true
}

variable "compute_scale_down_enabled" {
  description = "Enable compute scale down"
  type        = bool
  default     = true
}

# Advanced Configuration
variable "fail_index_key_too_long" {
  description = "Fail when index key is too long"
  type        = bool
  default     = false
}

variable "javascript_enabled" {
  description = "Enable server-side JavaScript"
  type        = bool
  default     = true
}

variable "minimum_enabled_tls_protocol" {
  description = "Minimum TLS protocol version"
  type        = string
  default     = "TLS1_2"
}

variable "no_table_scan" {
  description = "Disable table scans"
  type        = bool
  default     = false
}

variable "oplog_size_mb" {
  description = "Oplog size in MB"
  type        = number
  default     = 2048
}

variable "sample_size_bi_connector" {
  description = "Sample size for BI Connector"
  type        = number
  default     = 5000
}

variable "sample_refresh_interval_bi_connector" {
  description = "Sample refresh interval for BI Connector"
  type        = number
  default     = 300
}

variable "transaction_lifetime_limit_seconds" {
  description = "Transaction lifetime limit in seconds"
  type        = number
  default     = 60
}

# Network Access Configuration
variable "ip_access_list" {
  description = "IP access list for the project"
  type        = map(string)
  default = {
    "0.0.0.0/0" = "Allow all IPs (not recommended for production)"
  }
}

# Database Users Configuration
variable "database_users" {
  description = "Database users configuration"
  type = map(object({
    username           = string
    password           = string
    auth_database_name = string
    roles = list(object({
      role_name     = string
      database_name = string
    }))
    scopes = list(object({
      name = string
      type = string
    }))
    labels = map(string)
  }))
  default = {
    "app_user" = {
      username           = "app_user"
      password           = "SecurePassword123!"
      auth_database_name = "admin"
      roles = [
        {
          role_name     = "readWriteAnyDatabase"
          database_name = "admin"
        }
      ]
      scopes = []
      labels = {
        environment = "production"
      }
    }
    "readonly_user" = {
      username           = "readonly_user"
      password           = "ReadOnlyPassword123!"
      auth_database_name = "admin"
      roles = [
        {
          role_name     = "readAnyDatabase"
          database_name = "admin"
        }
      ]
      scopes = []
      labels = {
        environment = "production"
      }
    }
  }
  sensitive = true
}

# AWS Configuration for Private Endpoints and Peering
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS Account ID for network peering"
  type        = string
  default     = ""
}

variable "aws_vpc_id" {
  description = "AWS VPC ID for peering and private endpoints"
  type        = string
  default     = ""
}

variable "aws_vpc_cidr" {
  description = "AWS VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aws_subnet_ids" {
  description = "AWS subnet IDs for private endpoints"
  type        = list(string)
  default     = []
}

variable "aws_security_group_ids" {
  description = "AWS security group IDs for private endpoints"
  type        = list(string)
  default     = []
}

variable "atlas_cidr_block" {
  description = "Atlas CIDR block for network peering"
  type        = string
  default     = "192.168.248.0/21"
}

# Feature Flags
variable "enable_private_endpoint" {
  description = "Enable private endpoint"
  type        = bool
  default     = false
}

variable "enable_network_peering" {
  description = "Enable network peering"
  type        = bool
  default     = false
}

variable "enable_data_lake" {
  description = "Enable data lake"
  type        = bool
  default     = false
}

variable "enable_search_index" {
  description = "Enable search index"
  type        = bool
  default     = false
}

# Data Lake Configuration
variable "data_lake_database" {
  description = "Database for data lake"
  type        = string
  default     = "sample_database"
}

variable "data_lake_collection" {
  description = "Collection for data lake"
  type        = string
  default     = "sample_collection"
}

variable "data_lake_s3_bucket" {
  description = "S3 bucket for data lake"
  type        = string
  default     = ""
}

# Search Index Configuration
variable "search_index_name" {
  description = "Name of the search index"
  type        = string
  default     = "default_search_index"
}

variable "search_index_database" {
  description = "Database for search index"
  type        = string
  default     = "sample_database"
}

variable "search_index_collection" {
  description = "Collection for search index"
  type        = string
  default     = "sample_collection"
}

variable "search_index_mappings_dynamic" {
  description = "Enable dynamic mappings for search index"
  type        = bool
  default     = true
}

variable "search_index_mappings_fields" {
  description = "Static field mappings for search index"
  type        = string
  default     = "{}"
}