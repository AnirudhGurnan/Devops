# MongoDB Atlas Sharded Cluster Deployment
# This configuration creates a production-ready MongoDB Atlas sharded cluster

terraform {
  required_version = ">= 1.0"
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.15"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the MongoDB Atlas Provider
provider "mongodbatlas" {
  public_key  = var.mongodbatlas_public_key
  private_key = var.mongodbatlas_private_key
}

# Configure AWS Provider for VPC peering
provider "aws" {
  region = var.aws_region
}

# Create MongoDB Atlas Project
resource "mongodbatlas_project" "mongodb_project" {
  name   = var.project_name
  org_id = var.atlas_org_id

  # Project settings
  is_collect_database_specifics_statistics_enabled = true
  is_data_explorer_enabled                         = true
  is_performance_advisor_enabled                   = true
  is_realtime_performance_panel_enabled            = true
  is_schema_advisor_enabled                        = true

  tags = var.project_tags
}

# Create IP Access List for the project
resource "mongodbatlas_project_ip_access_list" "ip_access_list" {
  for_each = var.ip_access_list

  project_id = mongodbatlas_project.mongodb_project.id
  ip_address = each.key
  comment    = each.value
}

# Create MongoDB Atlas Sharded Cluster
resource "mongodbatlas_advanced_cluster" "mongodb_cluster" {
  project_id     = mongodbatlas_project.mongodb_project.id
  name           = var.cluster_name
  cluster_type   = "SHARDED"
  mongo_db_major_version = var.mongodb_version

  # Backup configuration
  backup_enabled = var.backup_enabled
  pit_enabled    = var.pit_enabled

  # Termination protection
  termination_protection_enabled = var.termination_protection_enabled

  # Bi-Connector configuration
  bi_connector_config {
    enabled         = var.bi_connector_enabled
    read_preference = "secondary"
  }

  # Replication specs for sharded cluster
  dynamic "replication_specs" {
    for_each = var.shards_config
    content {
      num_shards = replication_specs.value.num_shards
      zone_name  = replication_specs.value.zone_name

      # Regions configuration for each shard
      dynamic "region_configs" {
        for_each = replication_specs.value.regions
        content {
          region_name     = region_configs.value.region_name
          provider_name   = region_configs.value.provider_name
          priority        = region_configs.value.priority
          electable_nodes = region_configs.value.electable_nodes
          read_only_nodes = region_configs.value.read_only_nodes

          # Auto-scaling configuration
          auto_scaling {
            disk_gb_enabled = var.auto_scaling_disk_gb_enabled
            compute_enabled = var.auto_scaling_compute_enabled

            compute_scale_down_enabled = var.compute_scale_down_enabled
            compute_min_instance_size  = region_configs.value.min_instance_size
            compute_max_instance_size  = region_configs.value.max_instance_size
          }

          # Analytics specs for analytics nodes
          analytics_specs {
            ebbs_volume_type   = "STANDARD"
            instance_size      = region_configs.value.analytics_instance_size
            node_count         = region_configs.value.analytics_node_count
          }

          # Electable specs for primary and secondary nodes
          electable_specs {
            ebbs_volume_type   = "STANDARD"
            instance_size      = region_configs.value.instance_size
            node_count         = region_configs.value.electable_nodes
          }

          # Read-only specs
          read_only_specs {
            ebbs_volume_type   = "STANDARD"
            instance_size      = region_configs.value.readonly_instance_size
            node_count         = region_configs.value.read_only_nodes
          }
        }
      }
    }
  }

  # Advanced configuration
  advanced_configuration {
    fail_index_key_too_long              = var.fail_index_key_too_long
    javascript_enabled                   = var.javascript_enabled
    minimum_enabled_tls_protocol         = var.minimum_enabled_tls_protocol
    no_table_scan                       = var.no_table_scan
    oplog_size_mb                       = var.oplog_size_mb
    sample_size_bi_connector            = var.sample_size_bi_connector
    sample_refresh_interval_bi_connector = var.sample_refresh_interval_bi_connector
    transaction_lifetime_limit_seconds   = var.transaction_lifetime_limit_seconds
  }

  # Labels for the cluster
  dynamic "labels" {
    for_each = var.cluster_labels
    content {
      key   = labels.key
      value = labels.value
    }
  }

  tags = var.cluster_tags
}

# Create Database User
resource "mongodbatlas_database_user" "db_users" {
  for_each = var.database_users

  username           = each.value.username
  password           = each.value.password
  project_id         = mongodbatlas_project.mongodb_project.id
  auth_database_name = each.value.auth_database_name

  # Roles for the user
  dynamic "roles" {
    for_each = each.value.roles
    content {
      role_name     = roles.value.role_name
      database_name = roles.value.database_name
    }
  }

  # Scopes for the user (optional)
  dynamic "scopes" {
    for_each = each.value.scopes
    content {
      name = scopes.value.name
      type = scopes.value.type
    }
  }

  # Labels for the user
  dynamic "labels" {
    for_each = each.value.labels
    content {
      key   = labels.key
      value = labels.value
    }
  }
}

# Create Private Endpoint (if enabled)
resource "mongodbatlas_privatelink_endpoint" "private_endpoint" {
  count = var.enable_private_endpoint ? 1 : 0

  project_id    = mongodbatlas_project.mongodb_project.id
  provider_name = "AWS"
  region        = var.aws_region
}

# Create VPC Endpoint (AWS side)
resource "aws_vpc_endpoint" "mongodb_vpc_endpoint" {
  count = var.enable_private_endpoint ? 1 : 0

  vpc_id              = var.aws_vpc_id
  service_name        = mongodbatlas_privatelink_endpoint.private_endpoint[0].endpoint_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.aws_subnet_ids
  security_group_ids  = var.aws_security_group_ids
  private_dns_enabled = true

  tags = {
    Name = "${var.cluster_name}-mongodb-endpoint"
  }
}

# Complete Private Endpoint configuration
resource "mongodbatlas_privatelink_endpoint_service" "private_endpoint_service" {
  count = var.enable_private_endpoint ? 1 : 0

  project_id          = mongodbatlas_project.mongodb_project.id
  private_link_id     = mongodbatlas_privatelink_endpoint.private_endpoint[0].private_link_id
  endpoint_service_id = aws_vpc_endpoint.mongodb_vpc_endpoint[0].id
  provider_name       = "AWS"
}

# Create Network Peering (if enabled)
resource "mongodbatlas_network_peering" "aws_peering" {
  count = var.enable_network_peering ? 1 : 0

  project_id     = mongodbatlas_project.mongodb_project.id
  container_id   = mongodbatlas_network_container.container[0].container_id
  accepter_region_name = var.aws_region
  provider_name  = "AWS"
  route_table_cidr_block = var.aws_vpc_cidr
  vpc_id         = var.aws_vpc_id
  aws_account_id = var.aws_account_id
}

# Create Network Container for peering
resource "mongodbatlas_network_container" "container" {
  count = var.enable_network_peering ? 1 : 0

  project_id       = mongodbatlas_project.mongodb_project.id
  atlas_cidr_block = var.atlas_cidr_block
  provider_name    = "AWS"
  region_name      = var.aws_region
}

# Create Data Lake (if enabled)
resource "mongodbatlas_data_lake_pipeline" "data_lake" {
  count = var.enable_data_lake ? 1 : 0

  project_id = mongodbatlas_project.mongodb_project.id
  name       = "${var.cluster_name}-data-lake"
  
  # Source configuration
  source {
    type         = "ON_DEMAND_CPS"
    cluster_name = mongodbatlas_advanced_cluster.mongodb_cluster.name
    database_name = var.data_lake_database
    collection_name = var.data_lake_collection
  }

  # Sink configuration
  sink {
    type = "DLS"
    config = jsonencode({
      providers = {
        aws = {
          testS3Bucket = {
            bucket = var.data_lake_s3_bucket
            region = var.aws_region
          }
        }
      }
    })
  }
}

# Create Search Index (if enabled)
resource "mongodbatlas_search_index" "search_index" {
  count = var.enable_search_index ? 1 : 0

  project_id   = mongodbatlas_project.mongodb_project.id
  cluster_name = mongodbatlas_advanced_cluster.mongodb_cluster.name
  name         = var.search_index_name
  database     = var.search_index_database
  collection   = var.search_index_collection

  mappings_dynamic = var.search_index_mappings_dynamic
  mappings_fields  = var.search_index_mappings_fields

  wait_for_index_build_completion = true
}