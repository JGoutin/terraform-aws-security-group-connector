Terraform module that connects two security groups by adding to them the required mutual security group rules.

Features:
* Supports connecting security groups on the same account and on different accounts
  (With VPC connected by peering or transit gateway).
* Provides the ability to update only a security group, but not the other one.
* Supports same `protocol`, `from_port`, `to_port` arguments than the `aws_security_group_rule` resource 
  (Including `all`, `icpm`, ports ranges, etc.) but also:
  * Provides predefined `protocol` values for common ports configurations like `https`, `nfs`, etc.
  * Provide predefined `protocol` values for some AWS service ports configurations like SES or EFS.
  * Assume `to_port` is equal `from_port` value if `to_port` is not set.

## Usage

Single-account example to connect a frontend to a backend:
```hcl
provider "aws" {
  alias   = "account"
}

resource "aws_security_group" "frontend" {
  provider    = aws.account
  description = "Application frontend"
}

resource "aws_security_group" "backend" {
  provider    = aws.account
  description = "Application backend"
}

module "frontend_to_backend" {
  source    = "JGoutin/security-group-connector/aws"
  providers = {
    aws.sg1 = aws.account,
    aws.sg2 = aws.account
  }

  sg1_security_group = {
    id = aws_security_group.frontend.id
  }
  sg2_security_group = {
    id = aws_security_group.backend.id
  }

  sg1_services = [
    # Frontend webhook provided to the backend (Using custom ports)
    # This add an ingress rule to SG1 (the frontend) and a egress rule to SG2 (the backend)
    {
      protocol  = "tcp"
      from_port = 8080
    },
  ]
  sg2_services = [
    # Backend HTTP server provided to the frontend (using standard HTTPS ports)
    # This add an ingress rule to SG2 (the backend) and a egress rule to SG1 (the frontend)
    {
      protocol  = "https"
    },
  ]
}
```

Cross-account example to connect a microservice to a database:
```hcl
provider "aws" {
  alias   = "database_account"
}

provider "aws" {
  alias   = "microservice_account"
}

resource "aws_security_group" "database" {
  provider    = aws.database_account
  description = "Aurora PostgreSQL database security group"
}

resource "aws_security_group" "microservice" {
  provider    = aws.microservice_account
  description = "Micro-service security group"
}

module "microservice_to_database" {
  source    = "JGoutin/security-group-connector/aws"
  providers = {
    aws.sg1 = aws.database_account,
    aws.sg2 = aws.microservice_account
  }

  sg1_security_group = {
    id = aws_security_group.database.id
  }
  sg2_security_group = {
    id = aws_security_group.microservice.id
  }

  sg1_services = [
    # Database ports provided to microservice
    # This add an ingress rule to SG1 (the database) and a egress rule to SG2 (the microservice)
    {
      protocol  = "postgres"
    },
  ]
}
```

Cross-account example to connect a microservice to an AWS EFS share, but modify only the microservice security group
and don't have any provider to the AWS EFS share account:
```hcl
provider "aws" {
  alias   = "account"
}

resource "aws_security_group" "microservice" {
  provider    = aws.account
  description = "Micro-service security group"
}

module "microservice_to_share" {
  source    = "JGoutin/security-group-connector/aws"
  providers = {
    aws.sg1 = aws.account,
    # Terraform requires to specify a "aws.sg2" provider, but nothing is modified.
    aws.sg2 = aws.account
  }
  
   # Do not modify SG2 (The AWS EFS share)
  sg2_add_rules = false
  
  sg1_security_group = {
    id = aws_security_group.microservice.id
  }
  sg2_security_group = {
    id = "sg-XXXXXXXXXXXX"
    # AWS Account ID is required in this case in addition to the security group ID
    account_id="XXXXXXXXXXXXXXXX"
  }

  sg2_services = [
    # AWS EFS share ports provided to microservice
    # This add an egress rule to SG1 (the microservice) but no rule to SG2 (The AWS EFS share)
    {
      protocol  = "aws-efs"
    },
  ]
}
```

## Requirements

| Name                                                                      | Version |
|---------------------------------------------------------------------------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0  |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 4.0  |

## Providers

| Name                                                          | Version |
|---------------------------------------------------------------|---------|
| <a name="provider_aws.sg1"></a> [aws.sg1](#provider\_aws.sg1) | >= 4.0  |
| <a name="provider_aws.sg2"></a> [aws.sg2](#provider\_aws.sg2) | >= 4.0  |

Two `aws` providers are used, one for each security group to connect.

Both can refer to the same parent provider in the case of a single account configuration.

## Resources

| Name                                                                                                                                   | Type     |
|----------------------------------------------------------------------------------------------------------------------------------------|----------|
| [aws_security_group_rule.sg1_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule)  | resource |
| [aws_security_group_rule.sg1_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.sg2_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule)  | resource |
| [aws_security_group_rule.sg2_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |

## Inputs

| Name                                                                                         | Description                                                                                                                                                                                                                                                                                            | Type                                                                                                                                                                               | Default | Required |
|----------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|:--------:|
| <a name="input_sg1_security_group"></a> [sg1\_security\_group](#input\_sg1\_security\_group) | SG1 Security group information. `id` is Security group ID and `account_id` is AWS account ID. `account_id` is always optional for SG1.                                                                                                                                                                 | <pre>object({<br>    id         = string<br>    account_id = optional(string)<br>  })</pre>                                                                                        | n/a     |   yes    |
| <a name="input_sg1_services"></a> [sg1\_services](#input\_sg1\_services)                     | List of services definition that SG1 provides to SG2. Arguments are passed to the `aws_security_group_rule` resource. If `to_port` is not set, it default to the `from_port` value. `protocol` also support some extra preconfigured common higher level protocol like `http`, `ssh`, etc (See Below). | <pre>list(object({<br>    protocol    = string<br>    from_port   = optional(number, 0)<br>    to_port     = optional(number)<br>    description = optional(string)<br>  }))</pre> | `[]`    |    no    |
| <a name="input_sg2_add_rules"></a> [sg2\_add\_rules](#input\_sg2\_add\_rules)                | If `true`, add security group rules to SG2. `false` may be required if SG2 is already pre-configured.                                                                                                                                                                                                  | `bool`                                                                                                                                                                             | `true`  |    no    |
| <a name="input_sg2_security_group"></a> [sg2\_security\_group](#input\_sg2\_security\_group) | SG2 Security group information. `id` is Security group ID and `account_id` is AWS account ID. `account_id` is only required for SG2 when `sg2_add_rules=false` and SG1 is on a different account than SG2.                                                                                             | <pre>object({<br>    id         = string<br>    account_id = optional(string)<br>  })</pre>                                                                                        | n/a     |   yes    |
| <a name="input_sg2_services"></a> [sg2\_services](#input\_sg2\_services)                     | List of services definition that SG2 provides to SG1. See `sg1_services` description for more details.                                                                                                                                                                                                 | <pre>list(object({<br>    protocol    = string<br>    from_port   = optional(number, 0)<br>    to_port     = optional(number)<br>    description = optional(string)<br>  }))</pre> | `[]`    |    no    |

### Protocols

Extra predefined `protocol` values that can be set in addition to [`aws_security_group_rule`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule#protocol) resource values.

#### Common protocols

* dns
* dot (DNS over TLS, DNS over QUIC)
* ftp
* ftps
* http
* http3 (With HTTPS fallback)
* https
* ldap
* ldaps
* mysql
* nfs
* postgres
* sftp
* smb
* smtp
* smtps
* ssh

#### AWS service

* aws-efs
* aws-redshift
* aws-ses
