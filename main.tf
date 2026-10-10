# main.tf

locals {
  nat_gateway_count = var.single_nat_gateway ? 1 : length(var.private_subnets)
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    { "Name" = var.vpc_name },
    var.mandatory_tags
  )
}

resource "aws_internet_gateway" "this" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(
    { "Name" = "${var.vpc_name}-igw" },
    var.mandatory_tags
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = merge(
    { "Name" = "${var.vpc_name}-public-${element(var.azs, count.index)}" },
    var.mandatory_tags
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = element(var.azs, count.index)

  tags = merge(
    { "Name" = "${var.vpc_name}-private-${element(var.azs, count.index)}" },
    var.mandatory_tags
  )
}

# Database Subnets
resource "aws_subnet" "database" {
  count             = length(var.database_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.database_subnets[count.index]
  availability_zone = element(var.azs, count.index)

  tags = merge(
    { "Name" = "${var.vpc_name}-database-${element(var.azs, count.index)}" },
    var.mandatory_tags
  )
}

# Elastic IPs for NAT
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? local.nat_gateway_count : 0
  domain = "vpc"

  tags = merge(
    { "Name" = "${var.vpc_name}-eip-${count.index}" },
    var.mandatory_tags
  )
  depends_on = [aws_internet_gateway.this]
}

# NAT Gateways
resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? local.nat_gateway_count : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id

  tags = merge(
    { "Name" = "${var.vpc_name}-nat-${count.index}" },
    var.mandatory_tags
  )
  depends_on = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(
    { "Name" = "${var.vpc_name}-public-rt" },
    var.mandatory_tags
  )
}

resource "aws_route" "public_internet_gateway" {
  count                  = length(var.public_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Private Route Tables
resource "aws_route_table" "private" {
  count  = length(var.private_subnets) > 0 ? local.nat_gateway_count : 0
  vpc_id = aws_vpc.this.id

  tags = merge(
    { "Name" = "${var.vpc_name}-private-rt-${count.index}" },
    var.mandatory_tags
  )
}

resource "aws_route" "private_nat_gateway" {
  count                  = var.enable_nat_gateway ? local.nat_gateway_count : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# Database Route Table (No Internet access by default)
resource "aws_route_table" "database" {
  count  = length(var.database_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(
    { "Name" = "${var.vpc_name}-database-rt" },
    var.mandatory_tags
  )
}

resource "aws_route_table_association" "database" {
  count          = length(var.database_subnets)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database[0].id
}

# VPC Flow Logs (FinOps Guardrail/Security)
resource "aws_cloudwatch_log_group" "flow_log" {
  count             = var.enable_vpc_flow_logs ? 1 : 0
  name              = "/aws/vpc-flow-logs/${var.vpc_name}"
  retention_in_days = 30 # Guardrail: Do not keep logs forever
  kms_key_id        = var.flow_log_kms_key_id

  tags = var.mandatory_tags
}

data "aws_iam_policy_document" "flow_log_assume_role" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "flow_log" {
  count              = var.enable_vpc_flow_logs ? 1 : 0
  name               = "${var.vpc_name}-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role[0].json

  tags = var.mandatory_tags
}

data "aws_iam_policy_document" "flow_log_policy" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_log" {
  count  = var.enable_vpc_flow_logs ? 1 : 0
  name   = "${var.vpc_name}-flow-log-policy"
  role   = aws_iam_role.flow_log[0].id
  policy = data.aws_iam_policy_document.flow_log_policy[0].json
}

resource "aws_flow_log" "this" {
  count           = var.enable_vpc_flow_logs ? 1 : 0
  log_destination = aws_cloudwatch_log_group.flow_log[0].arn
  iam_role_arn    = aws_iam_role.flow_log[0].arn
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"

  tags = merge(
    { "Name" = "${var.vpc_name}-flow-logs" },
    var.mandatory_tags
  )
}
