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
      az1 = { availability_zone = "us-east-1a", cidr = "10.20.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
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

run "rejects_invalid_private_subnet_cidr" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "10.20.0.0/16"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.20.1.0/99" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
    }
  }

  expect_failures = [var.private_subnets]
}

run "rejects_empty_subnet_availability_zone" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "10.20.0.0/16"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    private_subnets = {
      az1 = { availability_zone = "", cidr = "10.20.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
    }
  }

  expect_failures = [var.private_subnets]
}

run "rejects_public_subnet_cidr_edge" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "10.20.0.0/16"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "198.51.100.0/26" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
    }
  }

  expect_failures = [var.private_subnets]
}

run "rejects_subnet_cidr_outside_vpc" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "10.20.0.0/16"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.30.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
    }
  }

  expect_failures = [check.private_subnets_inside_vpc]
}

run "rejects_overlapping_private_subnet_cidrs" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "10.20.0.0/16"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.20.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.1.0/25" }
    }
  }

  expect_failures = [var.private_subnets]
}

run "rejects_unrestricted_ingress_exception" {
  command = plan

  variables {
    environment                = "nonproduction"
    vpc_cidr                   = "10.20.0.0/16"
    flow_logs_destination_arn  = "arn:aws:s3:::example-log-archive"
    allow_unrestricted_ingress = true
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.20.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
    }
  }

  expect_failures = [var.allow_unrestricted_ingress]
}

run "rejects_unrestricted_egress_exception" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "10.20.0.0/16"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    allow_unrestricted_egress = true
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.20.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
    }
  }

  expect_failures = [var.allow_unrestricted_egress]
}

run "rejects_sg_exception_cidr_shape" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "10.20.0.0/16"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    sg_exception_attempts = {
      cidrs    = ["10.0.0.0/8"]
      ports    = []
      protocol = ""
    }
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.20.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
    }
  }

  expect_failures = [var.sg_exception_attempts]
}

run "rejects_sg_exception_port_shape" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "10.20.0.0/16"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    sg_exception_attempts = {
      cidrs    = []
      ports    = [443]
      protocol = ""
    }
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.20.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
    }
  }

  expect_failures = [var.sg_exception_attempts]
}

run "rejects_sg_exception_protocol_shape" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "10.20.0.0/16"
    flow_logs_destination_arn = "arn:aws:s3:::example-log-archive"
    sg_exception_attempts = {
      cidrs    = []
      ports    = []
      protocol = "tcp"
    }
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.20.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
    }
  }

  expect_failures = [var.sg_exception_attempts]
}

run "rejects_non_s3_flow_logs_destination_arn" {
  command = plan

  variables {
    environment               = "nonproduction"
    vpc_cidr                  = "10.20.0.0/16"
    flow_logs_destination_arn = "arn:aws:logs:us-east-1:123456789012:log-group:example"
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.20.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.20.2.0/24" }
    }
  }

  expect_failures = [var.flow_logs_destination_arn]
}

run "enforces_default_deny_security_group" {
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
    condition     = length(aws_security_group.private_workload.ingress) == 0
    error_message = "Public or any ingress exception must not appear on the private workload security group."
  }

  assert {
    condition     = length(aws_security_group.private_workload.egress) == 0
    error_message = "Egress exceptions must not appear on the default-deny private workload security group."
  }
}
