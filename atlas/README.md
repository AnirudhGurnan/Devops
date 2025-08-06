# MongoDB Atlas Sharded Cluster - Terraform

Deploy a production-ready MongoDB Atlas sharded cluster on AWS using Terraform.

## 🏗️ Architecture

- **Sharded Cluster**: 2 shards with 3 nodes each (configurable)
- **Instance Size**: M30 (production-ready, auto-scaling enabled)
- **Regions**: Multi-region support with high availability
- **Security**: Private endpoints, VPC peering, IP whitelisting
- **Backup**: Automated backups with point-in-time recovery
- **Advanced Features**: Data Lake, Search Index, BI Connector

## 🚀 Quick Start

### 1. Prerequisites
- Terraform >= 1.0
- MongoDB Atlas account
- AWS CLI (for private endpoints)

### 2. Setup
```bash
# Clone and navigate
cd atlas

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Atlas API keys and org ID
```

### 3. Deploy
```bash
terraform init
terraform plan
terraform apply
```

### 4. Connect
```bash
# Get connection string
terraform output mongo_uri_srv

# Connect with mongosh
mongosh "$(terraform output -raw mongo_uri_srv)" --username app_user
```

## ⚙️ Configuration

### Required Variables
```hcl
mongodbatlas_public_key  = "your-atlas-public-key"
mongodbatlas_private_key = "your-atlas-private-key" 
atlas_org_id            = "your-atlas-organization-id"
```

### Cluster Customization
```hcl
# Scale shards and instance sizes
shards_config = [
  {
    num_shards = 3  # Number of shards
    zone_name  = "Production"
    regions = [
      {
        region_name     = "US_EAST_1"
        instance_size   = "M50"  # Instance size
        electable_nodes = 3      # Nodes per shard
        # ... more options
      }
    ]
  }
]
```

### Security Features
- **IP Access Lists**: Restrict network access
- **Database Users**: Role-based access control
- **Private Endpoints**: AWS PrivateLink integration
- **VPC Peering**: Direct network connectivity
- **TLS Encryption**: End-to-end security

### Advanced Features
```hcl
# Enable optional features
enable_private_endpoint = true   # AWS PrivateLink
enable_network_peering  = true   # VPC Peering
enable_data_lake       = true   # Real-time analytics
enable_search_index    = true   # Full-text search
```

## 📊 Outputs

After deployment, get important information:

```bash
# Connection details
terraform output connection_strings
terraform output mongo_uri_srv

# Cluster information
terraform output cluster_configuration
terraform output shard_configuration

# Security details
terraform output database_users
terraform output security_configuration

# Atlas dashboard URLs
terraform output atlas_cluster_url
```

## 💰 Cost Estimation

| Configuration | Monthly Cost |
|---------------|-------------|
| Development (M10) | ~$90 |
| Production (M30) | ~$620 |
| High-Performance (M80) | ~$1,500 |

## 🔐 Security Best Practices

1. **Network Security**
   - Use IP access lists (avoid 0.0.0.0/0)
   - Enable private endpoints for production
   - Configure VPC peering

2. **Authentication**
   - Use strong passwords
   - Follow least privilege principle
   - Rotate credentials regularly

3. **Encryption**
   - TLS 1.2+ (enabled by default)
   - Encryption at rest (enabled by default)

## 🛠️ Operations

### Scaling
```bash
# Vertical scaling - change instance size
terraform apply -var='instance_size=M50'

# Horizontal scaling - add shards
terraform apply -var='num_shards=3'
```

### Monitoring
- Atlas Dashboard: Available in outputs
- Performance Advisor: Built-in optimization
- Custom Alerts: Configure in Atlas UI
- Real-time Metrics: Live performance data

### Backup & Recovery
- **Automated Backups**: Enabled by default
- **Point-in-Time Recovery**: 72-hour window
- **Cross-Region Replication**: Available
- **On-Demand Snapshots**: Via Atlas UI

## 🔧 Troubleshooting

### Common Issues

**Authentication Failed**
```bash
# Check API keys and permissions
terraform plan
# Error: 401 Unauthorized
```
Solution: Verify Atlas API keys in terraform.tfvars

**VPC Peering Issues**
```bash
# Error creating network peering
```
Solution: Check AWS account ID, VPC ID, and IAM permissions

**Connection Timeouts**
```bash
# Cannot connect to cluster
```
Solution: Verify IP access list and security groups

### Useful Commands
```bash
# Validate configuration
terraform validate

# Format files
terraform fmt

# Show current state
terraform show

# Refresh state
terraform refresh
```

## 📁 Project Structure

```
atlas/
├── main.tf                    # Main resources
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example configuration
└── README.md                  # This file
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes with `terraform plan`
4. Submit a pull request

## 📚 Resources

- [MongoDB Atlas Documentation](https://docs.atlas.mongodb.com/)
- [Terraform MongoDB Atlas Provider](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs)
- [MongoDB Atlas Pricing](https://www.mongodb.com/pricing)

## 📄 License

MIT License - see LICENSE file for details.