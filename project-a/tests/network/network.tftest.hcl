mock_provider "aws" {}

run "accepts_private_network_boundary" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "10.20.0.0/16"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.20.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
    }
  }

  assert {
    condition     = output.private_subnet_count == 2
    error_message = "The template must preserve two private subnets."
  }
}

run "rejects_public_vpc_cidr" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "198.51.100.0/24"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "198.51.100.0/26" }
      az2 = { availability_zone = "us-east-1b", cidr = "198.51.100.64/26" }
    }
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_single_private_subnet" {
  command = plan

  variables {
    environment               = "production"
    vpc_cidr                  = "10.30.0.0/16"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.30.1.0/24" }
    }
  }

  expect_failures = [var.private_subnets]
}
