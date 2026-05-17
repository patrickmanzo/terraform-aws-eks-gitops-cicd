#!/bin/bash
# User data script for bastion host setup

# Update system
dnf update -y

# Install required packages
dnf install -y aws-cli postgresql15 git htop nano unzip vim jq

# Install kubectl
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.0/2024-09-12/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl

# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Configure kubectl for EKS (if cluster name is provided)
%{ if eks_cluster_name != "" }
# Configure kubectl for ec2-user
sudo -u ec2-user aws eks update-kubeconfig --region ${region} --name ${eks_cluster_name}
%{ endif }

# Create useful aliases
cat >> /home/ec2-user/.bashrc << 'EOF'
# Kubernetes aliases
alias k='kubectl'
alias ll='ls -la'
alias kgp='kubectl get pods -A'
alias kgs='kubectl get services -A'
alias kgn='kubectl get nodes -A'
alias kgd='kubectl get deployments -A'
alias kga='kubectl get all -A'

# EC2 aliases
alias ec2-list='aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress,PrivateIpAddress,Tags[?Key==\`Name\`].Value|[0]]" --output table'
alias ec2-running='aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,InstanceType,PublicIpAddress,Tags[?Key==\`Name\`].Value|[0]]" --output table'

# ECR aliases
alias ecr-repos='aws ecr describe-repositories --query "repositories[*].[repositoryName,createdAt]" --output table'
alias ecr-images='aws ecr list-images --repository-name'

# RDS aliases
alias rds-instances='aws rds describe-db-instances --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine,DBInstanceClass,Endpoint.Address]" --output table'
alias rds-clusters='aws rds describe-db-clusters --query "DBClusters[*].[DBClusterIdentifier,Status,Engine,ReaderEndpoint,Endpoint]" --output table'
EOF

# Create .kube directory for ec2-user
mkdir -p /home/ec2-user/.kube
chown -R ec2-user:ec2-user /home/ec2-user/.kube

# Install Session Manager plugin
dnf install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm

# Create startup script for convenience
cat > /home/ec2-user/setup-eks.sh << 'EOF'
#!/bin/bash
# Quick setup script for EKS access
%{ if eks_cluster_name != "" }
echo "Configuring kubectl for EKS cluster: ${eks_cluster_name}"
aws eks update-kubeconfig --region ${region} --name ${eks_cluster_name}
kubectl get nodes
%{ else }
echo "No EKS cluster name provided. To configure kubectl manually:"
echo "aws eks update-kubeconfig --region ${region} --name YOUR_CLUSTER_NAME"
%{ endif }
EOF

chmod +x /home/ec2-user/setup-eks.sh
chown ec2-user:ec2-user /home/ec2-user/setup-eks.sh

# Create ECR management script
cat > /home/ec2-user/ecr-helper.sh << 'EOF'
#!/bin/bash
# ECR Helper Script

REGION="${region}"

ecr_list_repos() {
    echo "📋 ECR Repositories:"
    aws ecr describe-repositories --query "repositories[*].[repositoryName,createdAt,repositoryUri]" --output table
}

ecr_list_images() {
    if [ -z "$1" ]; then
        echo "Usage: ecr_list_images <repository-name>"
        return 1
    fi
    echo "🖼️  Images in repository: $1"
    aws ecr list-images --repository-name $1 --query "imageIds[*].[imageTag,imageDigest]" --output table
}

ecr_get_uri() {
    if [ -z "$1" ]; then
        echo "Usage: ecr_get_uri <repository-name>"
        return 1
    fi
    aws ecr describe-repositories --repository-names $1 --query "repositories[0].repositoryUri" --output text
}

ecr_describe_repo() {
    if [ -z "$1" ]; then
        echo "Usage: ecr_describe_repo <repository-name>"
        return 1
    fi
    echo "📋 Repository Details: $1"
    aws ecr describe-repositories --repository-names $1 --output table
}

case "$1" in
    repos|list)
        ecr_list_repos
        ;;
    images)
        ecr_list_images $2
        ;;
    uri)
        ecr_get_uri $2
        ;;
    describe)
        ecr_describe_repo $2
        ;;
    *)
        echo "ECR Helper Script"
        echo "Usage: $0 {repos|images <repo-name>|uri <repo-name>|describe <repo-name>}"
        echo ""
        echo "Commands:"
        echo "  repos              - List all repositories"
        echo "  images <repo-name> - List images in repository"
        echo "  uri <repo-name>    - Get repository URI"
        echo "  describe <repo-name> - Describe repository details"
        ;;
esac
EOF

chmod +x /home/ec2-user/ecr-helper.sh
chown ec2-user:ec2-user /home/ec2-user/ecr-helper.sh

# Create EC2 management script
cat > /home/ec2-user/ec2-helper.sh << 'EOF'
#!/bin/bash
# EC2 Helper Script

ec2_list_all() {
    echo "🖥️  All EC2 Instances:"
    aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PublicIpAddress,PrivateIpAddress,Tags[?Key==\`Name\`].Value|[0]]" --output table
}

ec2_list_running() {
    echo "▶️  Running EC2 Instances:"
    aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,InstanceType,PublicIpAddress,PrivateIpAddress,Tags[?Key==\`Name\`].Value|[0]]" --output table
}

ec2_describe() {
    if [ -z "$1" ]; then
        echo "Usage: ec2_describe <instance-id>"
        return 1
    fi
    echo "📋 Instance Details: $1"
    aws ec2 describe-instances --instance-ids $1 --output table
}

ec2_start() {
    if [ -z "$1" ]; then
        echo "Usage: ec2_start <instance-id>"
        return 1
    fi
    echo "▶️  Starting instance: $1"
    aws ec2 start-instances --instance-ids $1
}

ec2_stop() {
    if [ -z "$1" ]; then
        echo "Usage: ec2_stop <instance-id>"
        return 1
    fi
    echo "⏹️  Stopping instance: $1"
    aws ec2 stop-instances --instance-ids $1
}

case "$1" in
    list|all)
        ec2_list_all
        ;;
    running)
        ec2_list_running
        ;;
    describe)
        ec2_describe $2
        ;;
    start)
        ec2_start $2
        ;;
    stop)
        ec2_stop $2
        ;;
    *)
        echo "EC2 Helper Script"
        echo "Usage: $0 {list|running|describe <id>|start <id>|stop <id>}"
        echo ""
        echo "Commands:"
        echo "  list               - List all instances"
        echo "  running            - List running instances"
        echo "  describe <id>      - Describe specific instance"
        echo "  start <id>         - Start instance"
        echo "  stop <id>          - Stop instance"
        ;;
esac
EOF

chmod +x /home/ec2-user/ec2-helper.sh
chown ec2-user:ec2-user /home/ec2-user/ec2-helper.sh

# Create RDS management script
cat > /home/ec2-user/rds-helper.sh << 'EOF'
#!/bin/bash
# RDS Helper Script

rds_list_instances() {
    echo "🗄️  RDS Instances:"
    aws rds describe-db-instances --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine,DBInstanceClass,Endpoint.Address,AvailabilityZone]" --output table
}

rds_list_clusters() {
    echo "🗄️  RDS Clusters:"
    aws rds describe-db-clusters --query "DBClusters[*].[DBClusterIdentifier,Status,Engine,Endpoint,ReaderEndpoint,DatabaseName]" --output table
}

rds_describe_instance() {
    if [ -z "$1" ]; then
        echo "Usage: rds_describe_instance <db-instance-identifier>"
        return 1
    fi
    echo "📋 RDS Instance Details: $1"
    aws rds describe-db-instances --db-instance-identifier $1 --output table
}

rds_describe_cluster() {
    if [ -z "$1" ]; then
        echo "Usage: rds_describe_cluster <db-cluster-identifier>"
        return 1
    fi
    echo "📋 RDS Cluster Details: $1"
    aws rds describe-db-clusters --db-cluster-identifier $1 --output table
}

rds_get_endpoint() {
    if [ -z "$1" ]; then
        echo "Usage: rds_get_endpoint <db-instance-identifier>"
        return 1
    fi
    echo "🔗 RDS Endpoint for $1:"
    aws rds describe-db-instances --db-instance-identifier $1 --query "DBInstances[0].Endpoint.Address" --output text
}

rds_connect_help() {
    if [ -z "$1" ]; then
        echo "Usage: rds_connect_help <db-instance-identifier>"
        return 1
    fi

    ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $1 --query "DBInstances[0].Endpoint.Address" --output text 2>/dev/null)
    ENGINE=$(aws rds describe-db-instances --db-instance-identifier $1 --query "DBInstances[0].Engine" --output text 2>/dev/null)
    PORT=$(aws rds describe-db-instances --db-instance-identifier $1 --query "DBInstances[0].Endpoint.Port" --output text 2>/dev/null)

    if [ "$ENDPOINT" != "None" ] && [ "$ENDPOINT" != "" ]; then
        echo "🔗 Connection info for $1:"
        echo "Engine: $ENGINE"
        echo "Endpoint: $ENDPOINT"
        echo "Port: $PORT"
        echo ""
        case $ENGINE in
            postgres*)
                echo "PostgreSQL connection command:"
                echo "psql -h $ENDPOINT -p $PORT -U <username> -d <database>"
                ;;
            mysql*)
                echo "MySQL connection command:"
                echo "mysql -h $ENDPOINT -P $PORT -u <username> -p <database>"
                ;;
            *)
                echo "Connection command depends on engine: $ENGINE"
                ;;
        esac
    else
        echo "❌ Could not find instance: $1"
    fi
}

case "$1" in
    instances|list)
        rds_list_instances
        ;;
    clusters)
        rds_list_clusters
        ;;
    describe-instance)
        rds_describe_instance $2
        ;;
    describe-cluster)
        rds_describe_cluster $2
        ;;
    endpoint)
        rds_get_endpoint $2
        ;;
    connect)
        rds_connect_help $2
        ;;
    *)
        echo "RDS Helper Script"
        echo "Usage: $0 {instances|clusters|describe-instance <id>|describe-cluster <id>|endpoint <id>|connect <id>}"
        echo ""
        echo "Commands:"
        echo "  instances          - List all RDS instances"
        echo "  clusters           - List all RDS clusters"
        echo "  describe-instance <id> - Describe RDS instance"
        echo "  describe-cluster <id>  - Describe RDS cluster"
        echo "  endpoint <id>      - Get RDS endpoint"
        echo "  connect <id>       - Get connection help for RDS instance"
        ;;
esac
EOF

chmod +x /home/ec2-user/rds-helper.sh
chown ec2-user:ec2-user /home/ec2-user/rds-helper.sh

# Create database connection script if RDS is available
cat > /home/ec2-user/connect-db.sh << 'EOF'
#!/bin/bash
# Database connection helper script
echo "To connect to RDS PostgreSQL:"
echo "psql -h YOUR_RDS_ENDPOINT -U YOUR_USERNAME -d YOUR_DATABASE"
echo ""
echo "Example:"
echo "psql -h mydb.cluster-xyz.us-east-1.rds.amazonaws.com -U postgres -d myapp"
EOF

chmod +x /home/ec2-user/connect-db.sh
chown ec2-user:ec2-user /home/ec2-user/connect-db.sh

# Set proper permissions for ec2-user files
chown -R ec2-user:ec2-user /home/ec2-user/

# Log setup completion
echo "Bastion host setup completed at $(date)" > /var/log/bastion-setup.log
echo "Region: ${region}" >> /var/log/bastion-setup.log
%{ if eks_cluster_name != "" }
echo "EKS Cluster: ${eks_cluster_name}" >> /var/log/bastion-setup.log
%{ endif }
%{ if s3_bucket_name != "" }
echo "S3 Bucket: ${s3_bucket_name}" >> /var/log/bastion-setup.log
%{ endif }

# Create welcome message
cat > /etc/motd << 'EOF'
================================================================================
                          🚀 AWS Bastion Host 🚀
================================================================================

Welcome to bastion host!

Quick Commands:
  - kubectl (k): Kubernetes CLI tool
  - eksctl: EKS management tool
  - helm: Kubernetes package manager
  - psql: PostgreSQL client

Helpful Scripts:
  - ~/setup-eks.sh: Configure kubectl for EKS
  - ~/connect-db.sh: Database connection examples
  - ~/ecr-helper.sh: ECR repository management
  - ~/ec2-helper.sh: EC2 instance management
  - ~/rds-helper.sh: RDS database management

ECR Commands:
  - ./ecr-helper.sh repos: List repositories
  - ./ecr-helper.sh images <repo>: List images
  - ./ecr-helper.sh describe <repo>: Repository details

EC2 Commands:
  - ./ec2-helper.sh list: List all instances
  - ./ec2-helper.sh running: List running instances
  - ec2-list: Quick instance list alias
  - ec2-running: Quick running instances alias

RDS Commands:
  - ./rds-helper.sh instances: List RDS instances
  - ./rds-helper.sh clusters: List RDS clusters
  - ./rds-helper.sh connect <id>: Get connection info
  - rds-instances: Quick instance list alias

Useful Aliases:
  - k (kubectl), kgp (get pods), kgs (get services), kgn (get nodes)

Session Manager: This instance is configured for AWS Session Manager access
================================================================================
EOF

# Install CloudWatch agent (optional)
dnf install -y amazon-cloudwatch-agent

echo "Bastion host initialization complete!"
