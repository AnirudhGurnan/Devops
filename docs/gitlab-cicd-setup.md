# GitLab CI/CD Setup for MongoDB Automation

This document provides comprehensive instructions for setting up GitLab CI/CD pipelines to automate MongoDB deployment and management.

## 🚀 Overview

The GitLab CI/CD pipeline automates:

- **Code Validation**: Shell script linting, Terraform validation, Ansible syntax checking
- **Security Scanning**: Secret detection, security vulnerability scanning
- **Testing**: MongoDB script testing, integration testing
- **Multi-Environment Deployment**: Development, staging, and production deployments
- **Monitoring**: Health checks, performance monitoring
- **Backup Automation**: Scheduled backups with S3 integration
- **Maintenance**: Automated database maintenance and cleanup

## 📋 Prerequisites

### GitLab Setup
1. **GitLab Project**: Create or use existing GitLab project
2. **GitLab Runner**: Ensure runners are available (Docker executor recommended)
3. **Container Registry**: Enable GitLab Container Registry

### Required Integrations
1. **MongoDB Atlas Account** (for Atlas deployments)
2. **AWS Account** (for S3 backups and infrastructure)
3. **Slack Workspace** (optional, for notifications)
4. **Email Service** (for alerts and notifications)

## 🔐 GitLab Variables Configuration

### Navigate to Project Settings > CI/CD > Variables

#### **MongoDB Atlas Variables**
```bash
# Atlas API Credentials
MONGODBATLAS_PUBLIC_KEY: "your-atlas-public-key"
MONGODBATLAS_PRIVATE_KEY: "your-atlas-private-key"  # Protected, Masked
ATLAS_ORG_ID: "your-atlas-organization-id"

# Atlas Connection Details
MONGODB_HOST: "cluster0.xxxxx.mongodb.net"
MONGODB_USER: "admin"
MONGODB_PASSWORD: "your-password"  # Protected, Masked
```

#### **AWS Variables**
```bash
# AWS Credentials for S3 and infrastructure
AWS_ACCESS_KEY_ID: "your-aws-access-key"
AWS_SECRET_ACCESS_KEY: "your-aws-secret-key"  # Protected, Masked
AWS_DEFAULT_REGION: "us-east-1"

# S3 Backup Configuration
BACKUP_S3_BUCKET: "mongodb-backups-prod"
STAGING_BACKUP_S3_BUCKET: "mongodb-backups-staging"

# VPC Configuration (for private endpoints)
AWS_VPC_ID: "vpc-12345678"
AWS_SUBNET_IDS: "subnet-12345678,subnet-87654321"
AWS_SECURITY_GROUP_IDS: "sg-12345678"
```

#### **Notification Variables**
```bash
# Slack Integration
SLACK_WEBHOOK: "https://hooks.slack.com/services/..."  # Protected

# Email Notifications
ALERT_EMAIL: "alerts@company.com"
BACKUP_ALERT_EMAIL: "backup-alerts@company.com"
```

#### **MongoDB Connection Variables**
```bash
# Production MongoDB
MONGODB_PROD_HOST: "prod-cluster.xxxxx.mongodb.net"
MONGODB_BACKUP_USER: "backup_user"
MONGODB_BACKUP_PASSWORD: "backup-password"  # Protected, Masked

# Staging MongoDB
MONGODB_STAGING_HOST: "staging-cluster.xxxxx.mongodb.net"

# Encryption
ENCRYPTION_KEY_FILE: "/path/to/encryption.key"  # File variable
```

#### **Environment-Specific Variables**

Create environment-specific variable groups:

**Development Environment:**
```bash
MONGODB_DEV_HOST: "dev-cluster.xxxxx.mongodb.net"
DEV_S3_BUCKET: "mongodb-backups-dev"
```

**Staging Environment:**
```bash
MONGODB_STAGING_HOST: "staging-cluster.xxxxx.mongodb.net"
STAGING_S3_BUCKET: "mongodb-backups-staging"
```

**Production Environment:**
```bash
MONGODB_PROD_HOST: "prod-cluster.xxxxx.mongodb.net"
PROD_S3_BUCKET: "mongodb-backups-prod"
```

## 🏗️ Pipeline Stages

### 1. Validation Stage
- **Shell Script Linting**: Uses ShellCheck to validate bash scripts
- **Terraform Validation**: Validates Terraform syntax and formatting
- **Ansible Validation**: Checks Ansible playbook syntax

### 2. Security Scanning
- **Secret Detection**: Scans for accidentally committed secrets
- **SAST Scanning**: Static application security testing
- **Ansible Security**: Security checks for Ansible playbooks

### 3. Testing Stage
- **MongoDB Script Testing**: Tests automation scripts against MongoDB instance
- **Terraform Planning**: Creates and validates Terraform plans
- **Integration Testing**: End-to-end testing of deployments

### 4. Build Stage
- **Docker Image Building**: Creates MongoDB tools and backup containers
- **Image Registry**: Pushes images to GitLab Container Registry

### 5. Deployment Stages
- **Development**: Automatic deployment to dev environment
- **Staging**: Manual deployment to staging (after dev tests pass)
- **Production**: Manual deployment to production (requires approval)

### 6. Monitoring Stage
- **Health Checks**: Automated health monitoring
- **Performance Monitoring**: Performance metrics collection
- **Alerting**: Slack/email notifications for issues

### 7. Backup Stage
- **Automated Backups**: Scheduled backup operations
- **Backup Verification**: Validates backup integrity
- **Cleanup**: Removes old backups based on retention policy

## 🔄 Pipeline Triggers

### Automatic Triggers
- **Push to `develop`**: Triggers development deployment
- **Push to `main`**: Triggers staging deployment (manual approval for production)
- **Scheduled Pipelines**: For monitoring and backups

### Manual Triggers
- **Production Deployment**: Requires manual approval
- **Rollback Operations**: Manual rollback procedures
- **Maintenance Tasks**: Database maintenance and cleanup

## 📅 Scheduled Pipelines

Configure scheduled pipelines in GitLab:

### Daily Schedules
```yaml
# Daily backup at 2 AM UTC
Schedule: "0 2 * * *"
Variables:
  CI_PIPELINE_SOURCE: "schedule"
  SCHEDULE_TYPE: "backup"

# Daily health check at 6 AM UTC
Schedule: "0 6 * * *"
Variables:
  CI_PIPELINE_SOURCE: "schedule"
  SCHEDULE_TYPE: "health-check"
```

### Weekly Schedules
```yaml
# Weekly maintenance on Sunday at 3 AM UTC
Schedule: "0 3 * * 0"
Variables:
  CI_PIPELINE_SOURCE: "schedule"
  SCHEDULE_TYPE: "maintenance"
```

### Monthly Schedules
```yaml
# Monthly disaster recovery test
Schedule: "0 4 1 * *"
Variables:
  CI_PIPELINE_SOURCE: "schedule"
  SCHEDULE_TYPE: "dr-test"
```

## 🐳 Docker Configuration

### Building Custom Images

The pipeline builds two specialized Docker images:

1. **MongoDB Tools Image**: Contains all automation scripts and MongoDB tools
2. **MongoDB Backup Image**: Specialized for backup operations

### Using Images in Pipeline

```yaml
# Use the tools image
image: $CI_REGISTRY_IMAGE/mongodb-tools:latest

# Use the backup image
image: $CI_REGISTRY_IMAGE/mongodb-backup:latest
```

## 🚀 Deployment Strategies

### Atlas Deployment (Terraform)
```yaml
deploy-atlas-production:
  stage: deploy-production
  image: hashicorp/terraform:1.6
  script:
    - terraform workspace select prod
    - terraform apply -auto-approve
```

### On-Premises Deployment (Ansible)
```yaml
deploy-onprem-production:
  stage: deploy-production
  image: quay.io/ansible/ansible-runner:latest
  script:
    - ansible-playbook -i inventory/prod mongodb-sharded-cluster.yml
```

### Hybrid Deployment
Run both Atlas and on-premises deployments in parallel or sequence based on requirements.

## 📊 Monitoring Integration

### Nagios Integration
```yaml
monitor-health:
  script:
    - ./mongodb-automation/monitoring/health-check.sh --nagios
```

### Prometheus Integration
```yaml
performance-monitor:
  script:
    - ./mongodb-automation/monitoring/health-check.sh --format json > metrics.json
```

### Slack Integration
```yaml
variables:
  SLACK_WEBHOOK: $SLACK_WEBHOOK
script:
  - ./mongodb-automation/monitoring/health-check.sh --slack-webhook $SLACK_WEBHOOK
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Pipeline Fails at Validation
```bash
# Check shell scripts
shellcheck mongodb-automation/**/*.sh

# Validate Terraform
cd atlas && terraform validate

# Check Ansible syntax
ansible-playbook --syntax-check mongodb-sharded-cluster.yml
```

#### 2. Docker Build Failures
```bash
# Check Dockerfile syntax
docker build -f docker/Dockerfile.tools .

# Verify base images are accessible
docker pull ubuntu:22.04
```

#### 3. Terraform Deployment Issues
```bash
# Check Terraform state
terraform show

# Validate credentials
terraform plan
```

#### 4. Ansible Deployment Issues
```bash
# Test inventory
ansible-inventory --list

# Test connectivity
ansible all -m ping
```

### Debug Mode

Enable debug mode by setting variables:
```yaml
variables:
  ANSIBLE_VERBOSITY: "3"
  TF_LOG: "DEBUG"
  CI_DEBUG_TRACE: "true"
```

## 📈 Best Practices

### Security
1. **Use Protected Variables**: Mark sensitive variables as protected and masked
2. **Rotate Credentials**: Regularly rotate API keys and passwords
3. **Limit Permissions**: Use principle of least privilege for service accounts
4. **Enable MFA**: Enable multi-factor authentication where possible

### Performance
1. **Use Caching**: Cache Terraform and Ansible dependencies
2. **Parallel Jobs**: Run independent jobs in parallel
3. **Optimize Images**: Use minimal base images for Docker builds
4. **Resource Limits**: Set appropriate resource limits for jobs

### Reliability
1. **Retry Logic**: Implement retry logic for flaky operations
2. **Health Checks**: Include comprehensive health checks
3. **Rollback Procedures**: Define clear rollback procedures
4. **Monitoring**: Implement comprehensive monitoring and alerting

### Cost Optimization
1. **Resource Cleanup**: Clean up temporary resources after jobs
2. **Scheduled Jobs**: Use appropriate schedules for recurring jobs
3. **Environment Sizing**: Use appropriate instance sizes for each environment
4. **Auto-scaling**: Enable auto-scaling to optimize costs

## 📚 Additional Resources

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [MongoDB Atlas API Documentation](https://docs.atlas.mongodb.com/api/)
- [Terraform MongoDB Atlas Provider](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs)
- [Ansible MongoDB Collection](https://docs.ansible.com/ansible/latest/collections/community/mongodb/)

## 🆘 Support

For issues and questions:
1. Check pipeline logs in GitLab CI/CD > Pipelines
2. Review job artifacts and logs
3. Check MongoDB Atlas dashboard for cluster status
4. Contact DevOps team: devops@company.com