# MongoDB Sharded Cluster Deployment on AWS with Ansible

This repository contains Ansible playbooks and roles to deploy a production-ready MongoDB sharded cluster on AWS EC2 instances.

## Architecture

The deployment creates a MongoDB sharded cluster with the following components:

- **Config Servers**: 3 instances in a replica set for metadata storage
- **Shard Servers**: 2 shards, each with 3 instances in a replica set
- **Mongos Routers**: 2 instances for query routing and load balancing

## Prerequisites

### Software Requirements

1. **Ansible** (>= 2.15)
2. **Python** (>= 3.8) with boto3 and botocore
3. **AWS CLI** configured with appropriate credentials

### AWS Requirements

1. **AWS Account** with EC2 permissions
2. **VPC** with public subnets in multiple availability zones
3. **Security Group** with the following rules:
   - SSH (22) from your IP
   - MongoDB Config (27019) from cluster instances
   - MongoDB Shard (27018) from cluster instances
   - MongoDB Mongos (27017) from application instances
4. **EC2 Key Pair** for SSH access

## Installation

1. **Clone this repository**:
   ```bash
   git clone <repository-url>
   cd mongodb-sharded-cluster
   ```

2. **Install Ansible collections**:
   ```bash
   ansible-galaxy collection install -r requirements.yml
   ```

3. **Generate MongoDB keyfile**:
   ```bash
   ./scripts/generate-keyfile.sh
   ```

4. **Configure variables**:
   Edit `vars/mongodb-cluster.yml` and update the following:
   - AWS region, VPC, subnets, and security groups
   - EC2 key pair name and private key path
   - MongoDB keyfile content (from step 3)
   - Instance types and configuration

## Configuration

### AWS Configuration

Update the following variables in `vars/mongodb-cluster.yml`:

```yaml
# AWS Configuration
aws_region: "us-west-2"
aws_ami_id: "ami-0c02fb55956c7d316"  # Amazon Linux 2 AMI
aws_key_name: "your-ec2-key-pair"
aws_security_groups: ["mongodb-cluster-sg"]
aws_vpc_id: "vpc-xxxxxxxxx"
aws_private_key_path: "~/.ssh/your-private-key.pem"
```

### MongoDB Configuration

The default configuration creates:
- 3 config servers (t3.medium)
- 6 shard servers (t3.large) - 3 per shard
- 2 mongos routers (t3.medium)

Adjust instance types and counts in the `mongodb_instances` variable as needed.

## Deployment

### Step 1: Deploy Infrastructure and MongoDB

```bash
ansible-playbook -i inventory/aws_ec2.yml mongodb-sharded-cluster.yml
```

### Step 2: Verify Deployment

1. **Connect to a mongos router**:
   ```bash
   mongo <mongos-ip>:27017
   ```

2. **Check cluster status**:
   ```javascript
   sh.status()
   ```

3. **Enable sharding for a database**:
   ```javascript
   sh.enableSharding("myapp")
   sh.shardCollection("myapp.users", {"_id": "hashed"})
   ```

## Security Considerations

1. **Network Security**:
   - Use security groups to restrict access
   - Deploy in private subnets with NAT gateway for production

2. **Authentication**:
   - Keyfile authentication is enabled between cluster members
   - Create application users with appropriate permissions

3. **Encryption**:
   - Consider enabling encryption at rest and in transit for production

## Monitoring and Maintenance

### Log Files

- **Config Servers**: `/var/log/mongodb/mongod.log`
- **Shard Servers**: `/var/log/mongodb/mongod.log`
- **Mongos Routers**: `/var/log/mongodb/mongos.log`

### Service Management

```bash
# Check service status
sudo systemctl status mongod
sudo systemctl status mongos

# Restart services
sudo systemctl restart mongod
sudo systemctl restart mongos
```

### Backup Strategy

Implement regular backups using:
- MongoDB Atlas backup (if using Atlas)
- `mongodump` for logical backups
- EBS snapshots for physical backups

## Scaling

### Adding New Shards

1. Update `vars/mongodb-cluster.yml` with new shard instances
2. Run the playbook to deploy new shard servers
3. Add the new shard to the cluster:
   ```javascript
   sh.addShard("shard3ReplSet/shard3-1:27018,shard3-2:27018,shard3-3:27018")
   ```

### Scaling Existing Shards

1. Update instance configuration in variables file
2. Deploy new instances with the playbook
3. Add new members to the replica set

## Troubleshooting

### Common Issues

1. **Connection Timeout**:
   - Check security group rules
   - Verify MongoDB is listening on correct ports

2. **Replica Set Initialization Failed**:
   - Check network connectivity between instances
   - Verify keyfile permissions and content

3. **Shard Addition Failed**:
   - Ensure shard replica set is properly initialized
   - Check mongos logs for detailed error messages

### Useful Commands

```bash
# Check cluster configuration
ansible-inventory -i inventory/aws_ec2.yml --list

# Test connectivity to instances
ansible all -i inventory/aws_ec2.yml -m ping

# View MongoDB processes
ansible all -i inventory/aws_ec2.yml -a "ps aux | grep mongo"
```

## Cost Optimization

1. **Instance Types**: Adjust based on workload requirements
2. **Reserved Instances**: Use for long-term deployments
3. **Spot Instances**: Consider for development environments
4. **Auto Scaling**: Implement based on metrics

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review MongoDB documentation
3. Check Ansible and AWS documentation
4. Create an issue in this repository

## License

This project is licensed under the MIT License - see the LICENSE file for details.