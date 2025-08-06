# Project Information
output "project_id" {
  description = "MongoDB Atlas Project ID"
  value       = mongodbatlas_project.mongodb_project.id
}

output "project_name" {
  description = "MongoDB Atlas Project Name"
  value       = mongodbatlas_project.mongodb_project.name
}

# Cluster Information
output "cluster_id" {
  description = "MongoDB Atlas Cluster ID"
  value       = mongodbatlas_advanced_cluster.mongodb_cluster.cluster_id
}

output "cluster_name" {
  description = "MongoDB Atlas Cluster Name"
  value       = mongodbatlas_advanced_cluster.mongodb_cluster.name
}

output "cluster_state" {
  description = "MongoDB Atlas Cluster State"
  value       = mongodbatlas_advanced_cluster.mongodb_cluster.state_name
}

output "cluster_type" {
  description = "MongoDB Atlas Cluster Type"
  value       = mongodbatlas_advanced_cluster.mongodb_cluster.cluster_type
}

output "mongodb_version" {
  description = "MongoDB Version"
  value       = mongodbatlas_advanced_cluster.mongodb_cluster.mongo_db_version
}

# Connection Information
output "connection_strings" {
  description = "MongoDB Atlas connection strings"
  value = {
    standard          = mongodbatlas_advanced_cluster.mongodb_cluster.connection_strings[0].standard
    standard_srv      = mongodbatlas_advanced_cluster.mongodb_cluster.connection_strings[0].standard_srv
    aws_private_link  = try(mongodbatlas_advanced_cluster.mongodb_cluster.connection_strings[0].aws_private_link, null)
    aws_private_link_srv = try(mongodbatlas_advanced_cluster.mongodb_cluster.connection_strings[0].aws_private_link_srv, null)
  }
  sensitive = true
}

output "mongo_uri" {
  description = "MongoDB connection URI (standard)"
  value       = mongodbatlas_advanced_cluster.mongodb_cluster.connection_strings[0].standard
  sensitive   = true
}

output "mongo_uri_srv" {
  description = "MongoDB connection URI (SRV)"
  value       = mongodbatlas_advanced_cluster.mongodb_cluster.connection_strings[0].standard_srv
  sensitive   = true
}

# Database Users
output "database_users" {
  description = "Database users created"
  value = {
    for k, v in mongodbatlas_database_user.db_users : k => {
      username           = v.username
      auth_database_name = v.auth_database_name
      roles             = v.roles
    }
  }
}

# Network Configuration
output "private_endpoint_id" {
  description = "Private endpoint ID (if enabled)"
  value       = var.enable_private_endpoint ? mongodbatlas_privatelink_endpoint.private_endpoint[0].private_link_id : null
}

output "private_endpoint_service_name" {
  description = "Private endpoint service name (if enabled)"
  value       = var.enable_private_endpoint ? mongodbatlas_privatelink_endpoint.private_endpoint[0].endpoint_service_name : null
}

output "vpc_endpoint_id" {
  description = "AWS VPC endpoint ID (if enabled)"
  value       = var.enable_private_endpoint ? aws_vpc_endpoint.mongodb_vpc_endpoint[0].id : null
}

output "network_peering_id" {
  description = "Network peering connection ID (if enabled)"
  value       = var.enable_network_peering ? mongodbatlas_network_peering.aws_peering[0].connection_id : null
}

output "network_container_id" {
  description = "Network container ID (if peering enabled)"
  value       = var.enable_network_peering ? mongodbatlas_network_container.container[0].container_id : null
}

# Backup Information
output "backup_enabled" {
  description = "Whether backup is enabled"
  value       = mongodbatlas_advanced_cluster.mongodb_cluster.backup_enabled
}

output "pit_enabled" {
  description = "Whether point-in-time recovery is enabled"
  value       = mongodbatlas_advanced_cluster.mongodb_cluster.pit_enabled
}

# Cluster Configuration Details
output "cluster_configuration" {
  description = "Detailed cluster configuration"
  value = {
    cluster_type               = mongodbatlas_advanced_cluster.mongodb_cluster.cluster_type
    backup_enabled            = mongodbatlas_advanced_cluster.mongodb_cluster.backup_enabled
    pit_enabled              = mongodbatlas_advanced_cluster.mongodb_cluster.pit_enabled
    termination_protection   = mongodbatlas_advanced_cluster.mongodb_cluster.termination_protection_enabled
    bi_connector_enabled     = mongodbatlas_advanced_cluster.mongodb_cluster.bi_connector_config[0].enabled
    paused                   = mongodbatlas_advanced_cluster.mongodb_cluster.paused
    version_release_system   = mongodbatlas_advanced_cluster.mongodb_cluster.version_release_system
  }
}

# Shard Information
output "shard_configuration" {
  description = "Shard configuration details"
  value = {
    for idx, spec in mongodbatlas_advanced_cluster.mongodb_cluster.replication_specs : 
    "shard_${idx}" => {
      num_shards = spec.num_shards
      zone_name  = spec.zone_name
      regions    = [
        for region in spec.region_configs : {
          region_name     = region.region_name
          provider_name   = region.provider_name
          priority        = region.priority
          electable_nodes = region.electable_nodes
          read_only_nodes = region.read_only_nodes
          analytics_nodes = region.analytics_nodes
        }
      ]
    }
  }
}

# Data Lake Information (if enabled)
output "data_lake_name" {
  description = "Data Lake pipeline name (if enabled)"
  value       = var.enable_data_lake ? mongodbatlas_data_lake_pipeline.data_lake[0].name : null
}

output "data_lake_id" {
  description = "Data Lake pipeline ID (if enabled)"
  value       = var.enable_data_lake ? mongodbatlas_data_lake_pipeline.data_lake[0].id : null
}

# Search Index Information (if enabled)
output "search_index_id" {
  description = "Search index ID (if enabled)"
  value       = var.enable_search_index ? mongodbatlas_search_index.search_index[0].index_id : null
}

output "search_index_status" {
  description = "Search index status (if enabled)"
  value       = var.enable_search_index ? mongodbatlas_search_index.search_index[0].status : null
}

# Cost and Performance Information
output "cluster_cost_estimation" {
  description = "Estimated monthly cost information"
  value = {
    instance_sizes = {
      for idx, spec in mongodbatlas_advanced_cluster.mongodb_cluster.replication_specs :
      "shard_${idx}" => [
        for region in spec.region_configs : {
          region        = region.region_name
          instance_size = region.electable_specs[0].instance_size
          node_count    = region.electable_specs[0].node_count
        }
      ]
    }
    backup_enabled = mongodbatlas_advanced_cluster.mongodb_cluster.backup_enabled
    pit_enabled    = mongodbatlas_advanced_cluster.mongodb_cluster.pit_enabled
  }
}

# Security Information
output "security_configuration" {
  description = "Security configuration summary"
  value = {
    tls_protocol           = mongodbatlas_advanced_cluster.mongodb_cluster.advanced_configuration[0].minimum_enabled_tls_protocol
    javascript_enabled     = mongodbatlas_advanced_cluster.mongodb_cluster.advanced_configuration[0].javascript_enabled
    termination_protection = mongodbatlas_advanced_cluster.mongodb_cluster.termination_protection_enabled
    private_endpoint       = var.enable_private_endpoint
    network_peering        = var.enable_network_peering
  }
}

# Atlas Dashboard URLs
output "atlas_cluster_url" {
  description = "MongoDB Atlas cluster dashboard URL"
  value       = "https://cloud.mongodb.com/v2/${mongodbatlas_project.mongodb_project.id}#/clusters/detail/${mongodbatlas_advanced_cluster.mongodb_cluster.name}"
}

output "atlas_project_url" {
  description = "MongoDB Atlas project dashboard URL"
  value       = "https://cloud.mongodb.com/v2/${mongodbatlas_project.mongodb_project.id}"
}