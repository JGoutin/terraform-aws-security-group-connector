/*
Tests various possible configurations.

Requires 2 AWS accounts with 2 VPCs in peering (Or connected with transit gateway) to run.
*/

variable "sg1_aws_profile" {
  type        = string
  description = "AWS credentials profile to connect to SG1"
}

variable "sg2_aws_profile" {
  type        = string
  description = "AWS credentials profile to connect to SG2"
}

variable "sg1_vpc_id" {
  type        = string
  description = "VPC ID were create security groups on SG1"
}

variable "sg2_vpc_id" {
  type        = string
  description = "VPC ID were create security groups on SG2"
}

provider "aws" {
  alias   = "sg1"
  profile = var.sg1_aws_profile
}

provider "aws" {
  alias   = "sg2"
  profile = var.sg2_aws_profile
}

data "aws_caller_identity" "sg1" {
  provider = aws.sg1
}

data "aws_caller_identity" "sg2" {
  provider = aws.sg2
}

/* Cross account, both sides rules

Two security groups to connect in two different accounts. A provider for each account.

Rules added:
- Each security group, Egress: Services provided by itself to the other security group
- Each security group, Ingress: Services provided by the other security group to itself
*/

resource "aws_security_group" "xaccount_both_side_1" {
  provider    = aws.sg1
  description = "xaccount_both_side_1"
  vpc_id      = var.sg1_vpc_id
}

resource "aws_security_group" "xaccount_both_side_2" {
  provider    = aws.sg2
  description = "xaccount_both_side_2"
  vpc_id      = var.sg2_vpc_id
}

module "xaccount_both_side" {
  source    = "./.."
  providers = { aws.sg1 = aws.sg1, aws.sg2 = aws.sg2 }

  sg1_security_group = {
    id = aws_security_group.xaccount_both_side_1.id
  }
  sg2_security_group = {
    id = aws_security_group.xaccount_both_side_2.id
  }
  sg1_services = [
    { protocol = "https" },
    { protocol = "nfs" },
    {
      protocol  = "icmp"
      from_port = -1
      to_port   = -1
    },
  ]
  sg2_services = [
    { protocol = "ssh" },
    {
      protocol  = "tcp"
      from_port = 8080
    },
    {
      protocol    = "udp"
      from_port   = 8000
      to_port     = 8010
      description = "Streaming ports"
    }
  ]
}

/* Cross account, SG1 side only rules

Two security groups to connect in two different accounts. A provider for each account.

Rules added:
- SG1 security group, Egress: Services provided by itself to the SG2 security group
- SG1 security group, Ingress: Services provided by the SG2 security group to itself
- SG2 security group : None
*/

resource "aws_security_group" "xaccount_sg1_side_1" {
  provider    = aws.sg1
  description = "xaccount_sg1_side_1"
  vpc_id      = var.sg1_vpc_id
}

resource "aws_security_group" "xaccount_sg1_side_2" {
  provider    = aws.sg2
  description = "xaccount_sg1_side_2"
  vpc_id      = var.sg2_vpc_id
}

module "xaccount_sg1_side" {
  source    = "./.."
  providers = { aws.sg1 = aws.sg1, aws.sg2 = aws.sg2 }

  sg1_security_group = {
    id = aws_security_group.xaccount_sg1_side_1.id
  }
  sg2_security_group = {
    id = aws_security_group.xaccount_sg1_side_2.id
  }
  sg1_services = [
    { protocol = "all" }
  ]
  sg2_services = [
    { protocol = "postgres" }
  ]
  sg2_add_rules = false
}

/* Cross account, SG1 side only rules, no SG2 provider

Two security groups to connect in two different accounts. A provider only for SG1 account.

Rules added:
- SG1 security group, Egress: Services provided by itself to the SG2 security group
- SG1 security group, Ingress: Services provided by the SG2 security group to itself
- SG2 security group : None
*/

resource "aws_security_group" "xaccount_sg1_side_implicit_1" {
  provider    = aws.sg1
  description = "xaccount_sg1_side_implicit_1"
  vpc_id      = var.sg1_vpc_id
}

resource "aws_security_group" "xaccount_sg1_side_implicit_2" {
  provider    = aws.sg2
  description = "xaccount_sg1_side_implicit_2"
  vpc_id      = var.sg2_vpc_id
}

module "xaccount_sg1_side_implicit" {
  source    = "./.."
  providers = { aws.sg1 = aws.sg1, aws.sg2 = aws.sg1 }

  sg1_security_group = {
    id         = aws_security_group.xaccount_sg1_side_implicit_1.id
    account_id = data.aws_caller_identity.sg1.account_id
  }
  sg2_security_group = {
    id         = aws_security_group.xaccount_sg1_side_implicit_2.id,
    account_id = data.aws_caller_identity.sg2.account_id
  }
  sg2_services = [
    { protocol = "https" }
  ]
  sg2_add_rules = false
}

/* Same account

Two security groups to connect in the same accounts.

Rules added:
- Each security group, Egress: Services provided by itself to the other security group
- Each security group, Ingress: Services provided by the other security group to itself
*/

resource "aws_security_group" "same_account_1" {
  provider    = aws.sg1
  description = "same_account_1"
  vpc_id      = var.sg1_vpc_id
}

resource "aws_security_group" "same_account_2" {
  provider    = aws.sg1
  description = "same_account_2"
  vpc_id      = var.sg1_vpc_id
}

module "same_account" {
  source    = "./.."
  providers = { aws.sg1 = aws.sg1, aws.sg2 = aws.sg1 }

  sg1_security_group = {
    id = aws_security_group.same_account_1.id
  }
  sg2_security_group = {
    id = aws_security_group.same_account_2.id
  }
  sg1_services = [
    { protocol = "all" }
  ]
  sg2_services = [
    { protocol = "postgres" }
  ]
}

/* Same account, SG1 side only rules, implicit SG2 account ID

Two security groups to connect in the same accounts.

Rules added:
- SG1 security group, Egress: Services provided by itself to the SG2 security group
- SG1 security group, Ingress: Services provided by the SG2 security group to itself
- SG2 security group : None
*/

resource "aws_security_group" "same_account_implicit_1" {
  provider    = aws.sg1
  description = "same_account_implicit_1"
  vpc_id      = var.sg1_vpc_id
}

resource "aws_security_group" "same_account_implicit_2" {
  provider    = aws.sg1
  description = "same_account_implicit_2"
  vpc_id      = var.sg1_vpc_id
}

module "same_account_implicit" {
  source    = "./.."
  providers = { aws.sg1 = aws.sg1, aws.sg2 = aws.sg1 }

  sg1_security_group = {
    id = aws_security_group.same_account_implicit_1.id
  }
  sg2_security_group = {
    id = aws_security_group.same_account_implicit_2.id
  }
  sg1_services = [
    { protocol = "http3" }
  ]
  sg2_services = [
    { protocol = "smtp" }
  ]
  sg2_add_rules = false
}


/* Same account, SG1 side only rules, explicit SG2 account ID

Two security groups to connect in the same accounts. "account_id" is passed explicitly.

Rules added:
- SG1 security group, Egress: Services provided by itself to the SG2 security group
- SG1 security group, Ingress: Services provided by the SG2 security group to itself
- SG2 security group : None
*/

resource "aws_security_group" "same_account_explicit_1" {
  provider    = aws.sg1
  description = "same_account_explicit_1"
  vpc_id      = var.sg1_vpc_id
}

resource "aws_security_group" "same_account_explicit_2" {
  provider    = aws.sg1
  description = "same_account_explicit_2"
  vpc_id      = var.sg1_vpc_id
}

module "same_account_explicit" {
  source    = "./.."
  providers = { aws.sg1 = aws.sg1, aws.sg2 = aws.sg1 }

  sg1_security_group = {
    id         = aws_security_group.same_account_explicit_1.id
    account_id = data.aws_caller_identity.sg1.account_id
  }
  sg2_security_group = {
    id         = aws_security_group.same_account_explicit_2.id
    account_id = data.aws_caller_identity.sg1.account_id
  }
  sg1_services = [
    { protocol = "-1" }
  ]
  sg2_services = [
    { protocol = "dns" }
  ]
  sg2_add_rules = false
}
