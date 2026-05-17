
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-vpc"
    ResourceType = "VPC"
    Service      = "Networking"
  })
}

# Data source to get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Public Subnets (e.g., for Load Balancers, Bastion Hosts)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index] # Distribute across AZs
  map_public_ip_on_launch = true                                                     # Only for public subnets

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-public-subnet-${data.aws_availability_zones.available.names[count.index]}"
    ResourceType = "Subnet"
    Service      = "Networking"
    SubnetType   = "Public"
    AZ           = data.aws_availability_zones.available.names[count.index]
    # ELB tags for AWS Load Balancer Controller
    "kubernetes.io/role/elb"                               = "1"
    "kubernetes.io/cluster/${var.name_prefix}-eks-cluster" = "shared"
  })
}

# Private Subnets (e.g., for application servers, databases)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index] # Distribute across AZs

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-private-subnet-${data.aws_availability_zones.available.names[count.index]}"
    ResourceType = "Subnet"
    Service      = "Networking"
    SubnetType   = "Private"
    AZ           = data.aws_availability_zones.available.names[count.index]
    # Internal ELB tags for AWS Load Balancer Controller
    "kubernetes.io/role/internal-elb"                      = "1"
    "kubernetes.io/cluster/${var.name_prefix}-eks-cluster" = "shared"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-igw"
    ResourceType = "InternetGateway"
    Service      = "Networking"
  })
}

# EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  count  = 1
  domain = "vpc"
  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-nat-eip-1"
    ResourceType = "ElasticIP"
    Service      = "Networking"
    Purpose      = "NAT-Gateway"
  })
}

# NAT Gateway
resource "aws_nat_gateway" "this" {
  count         = 1
  allocation_id = aws_eip.nat_gateway_eip[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-nat-gateway-1"
    ResourceType = "NATGateway"
    Service      = "Networking"
  })

  depends_on = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-public-rt"
    ResourceType = "RouteTable"
    Service      = "Networking"
    RouteType    = "Public"
  })
}

# Private Route Tables (one per private subnet for dedicated NAT Gateway route)
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[0].id
  }

  tags = merge(var.common_tags, {
    Name         = "${var.name_prefix}-private-rt-${count.index + 1}"
    ResourceType = "RouteTable"
    Service      = "Networking"
    RouteType    = "Private"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# VPC FlowLogs

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "${var.name_prefix}-vpc-flow-logs"
  retention_in_days = 14

  # Add lifecycle management to prevent conflicts
  lifecycle {
    ignore_changes        = [name]
    prevent_destroy       = false
    create_before_destroy = false
  }

  tags = var.common_tags
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
  tags = var.common_tags

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs" {
  role       = aws_iam_role.vpc_flow_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_flow_log" "vpc" {
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  tags                 = var.common_tags

  depends_on = [
    aws_cloudwatch_log_group.vpc_flow_logs,
    aws_iam_role_policy_attachment.vpc_flow_logs
  ]
}
