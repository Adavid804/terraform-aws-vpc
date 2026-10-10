# tests/setup.tftest.hcl

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
}

variables {
  vpc_name             = "test-vpc"
  cidr_block           = "10.0.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets      = ["10.0.3.0/24", "10.0.4.0/24"]
  database_subnets     = ["10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_vpc_flow_logs = true
  mandatory_tags = {
    Environment = "test"
    CostCenter  = "12345"
  }
}

run "create_vpc" {
  command = plan

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block did not match expected value"
  }

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Number of public subnets did not match expected value"
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Number of private subnets did not match expected value"
  }

  assert {
    condition     = length(aws_subnet.database) == 2
    error_message = "Number of database subnets did not match expected value"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Expected exactly one NAT Gateway since single_nat_gateway is true"
  }

  assert {
    condition     = aws_vpc.this.tags["Environment"] == "test"
    error_message = "Mandatory tags were not applied to VPC"
  }
}
