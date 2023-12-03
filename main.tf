/*
Providers and account configuration
*/

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.sg1, aws.sg2]
    }
  }
}

locals {
  sg1_account_id = data.aws_caller_identity.sg1.account_id
  sg2_account_id = (
    var.sg2_add_rules ? data.aws_caller_identity.sg2.account_id : # Use provider if SG2 require modification
    (
      var.sg2_security_group.account_id == null ?
      data.aws_caller_identity.sg1.account_id : # Assume SG2 is on the same account as SG1
      var.sg2_security_group.account_id         # Use account ID explicitly passed as variable to SG2
    )
  )
}

data "aws_caller_identity" "sg1" {
  provider = aws.sg1
}

data "aws_caller_identity" "sg2" {
  provider = aws.sg2
}

/*
Security group rules
*/

locals {
  sg1_ingress_rules = {
    for rule in flatten([for rule in var.sg2_services : lookup(local.protocols, rule.protocol, rule)]) :
    "${rule.from_port}:${rule.to_port != null ? rule.to_port : rule.from_port}/${rule.protocol}" => rule
  }
  sg1_egress_rules = {
    for rule in flatten([for rule in var.sg1_services : lookup(local.protocols, rule.protocol, rule)]) :
    "${rule.from_port}:${rule.to_port != null ? rule.to_port : rule.from_port}/${rule.protocol}" => rule
  }
  sg2_ingress_rules = var.sg2_add_rules ? local.sg1_egress_rules : {}
  sg2_egress_rules  = var.sg2_add_rules ? local.sg1_ingress_rules : {}

  sg1_security_group_fqid = (
    local.sg1_account_id != local.sg2_account_id ?
    "${local.sg1_account_id}/${var.sg1_security_group.id}" : var.sg1_security_group.id
  )
  sg2_security_group_fqid = (
    local.sg1_account_id != local.sg2_account_id ?
    "${local.sg2_account_id}/${var.sg2_security_group.id}" : var.sg2_security_group.id
  )
}

resource "aws_security_group_rule" "sg1_ingress" {
  provider                 = aws.sg1
  for_each                 = local.sg1_ingress_rules
  security_group_id        = var.sg1_security_group.id
  source_security_group_id = local.sg2_security_group_fqid
  description              = each.value.description
  type                     = "ingress"
  from_port                = each.value.from_port
  to_port                  = each.value.to_port != null ? each.value.to_port : each.value.from_port
  protocol                 = each.value.protocol
}

resource "aws_security_group_rule" "sg1_egress" {
  provider                 = aws.sg1
  for_each                 = local.sg1_egress_rules
  security_group_id        = var.sg1_security_group.id
  source_security_group_id = local.sg2_security_group_fqid
  description              = each.value.description
  type                     = "egress"
  from_port                = each.value.from_port
  to_port                  = each.value.to_port != null ? each.value.to_port : each.value.from_port
  protocol                 = each.value.protocol
}

resource "aws_security_group_rule" "sg2_ingress" {
  provider                 = aws.sg2
  for_each                 = local.sg2_ingress_rules
  security_group_id        = var.sg2_security_group.id
  source_security_group_id = local.sg1_security_group_fqid
  description              = each.value.description
  type                     = "ingress"
  from_port                = each.value.from_port
  to_port                  = each.value.to_port != null ? each.value.to_port : each.value.from_port
  protocol                 = each.value.protocol

}

resource "aws_security_group_rule" "sg2_egress" {
  provider                 = aws.sg2
  for_each                 = local.sg2_egress_rules
  security_group_id        = var.sg2_security_group.id
  source_security_group_id = local.sg1_security_group_fqid
  description              = each.value.description
  type                     = "egress"
  from_port                = each.value.from_port
  to_port                  = each.value.to_port != null ? each.value.to_port : each.value.from_port
  protocol                 = each.value.protocol
}

/*
Protocols definition
*/

locals {
  protocols = {
    # Generic protocols
    ftp = [
      {
        from_port = 20
        to_port   = 20
        protocol  = "udp"
        description : "FTP data"
      },
      {
        from_port = 21
        to_port   = 21
        protocol  = "tcp"
        description : "FTP control"
      },
    ]
    ssh = [
      {
        from_port = 22
        to_port   = 22
        protocol  = "tcp"
        description : "SSH"
      }
    ]
    smtp = [
      {
        from_port = 25
        to_port   = 25
        protocol  = "tcp"
        description : "SMTP"
      },
      {
        from_port = 587
        to_port   = 587
        protocol  = "tcp"
        description : "SMTP submission"
      }
    ]
    dns = [
      {
        from_port = 53
        to_port   = 53
        protocol  = "tcp"
        description : "DNS (TCP)"
      },
      {
        from_port = 53
        to_port   = 53
        protocol  = "udp"
        description : "DNS (UDP)"
      }
    ]
    http = [
      {
        from_port = 80
        to_port   = 80
        protocol  = "tcp"
        description : "HTTP"
      }
    ]
    sftp = [
      {
        from_port = 115
        to_port   = 115
        protocol  = "tcp"
        description : "SFTP"
      }
    ]
    ldap = [
      {
        from_port = 389
        to_port   = 389
        protocol  = "tcp"
        description : "LDAP"
      }
    ]
    https = [
      {
        from_port = 443
        to_port   = 443
        protocol  = "tcp"
        description : "HTTPS"
      }
    ]
    http3 = [
      {
        from_port = 443
        to_port   = 443
        protocol  = "udp"
        description : "HTTP/3"
      },
      {
        # HTTPS Fallback (HTTP/2) if client don't support HTTP/3
        from_port = 443
        to_port   = 443
        protocol  = "tcp"
        description : "HTTPS"
      },
    ]
    smb = [
      {
        from_port = 445
        to_port   = 445
        protocol  = "tcp"
        description : "SMB"
      }
    ]
    smtps = [
      {
        from_port = 465
        to_port   = 465
        protocol  = "tcp"
        description : "SMTPS"
      }
    ]
    ldaps = [
      {
        from_port = 636
        to_port   = 636
        protocol  = "tcp"
        description : "LDAPS"
      }
    ]
    dot = [
      {
        from_port = 853
        to_port   = 853
        protocol  = "tcp"
        description : "DNS over TLS"
      },
      {
        from_port = 853
        to_port   = 853
        protocol  = "udp"
        description : "DNS over QUIC"
      }
    ]
    ftps = [
      {
        from_port = 20
        to_port   = 20
        protocol  = "tcp"
        description : "FTPS data (TCP)"
      },
      {
        from_port = 20
        to_port   = 20
        protocol  = "udp"
        description : "FTPS data (UDP)"
      },
      {
        from_port = 21
        to_port   = 21
        protocol  = "tcp"
        description : "FTPS control (TCP)"
      },
      {
        from_port = 21
        to_port   = 21
        protocol  = "udp"
        description : "FTPS control (UDP)"
      },
    ]
    nfs = [
      {
        from_port = 2049
        to_port   = 2049
        protocol  = "tcp"
        description : "NFS (TCP)"
      },
      {
        from_port = 2049
        to_port   = 2049
        protocol  = "udp"
        description : "NFS (UDP)"
      }
    ]
    mysql = [
      {
        from_port = 3306
        to_port   = 3306
        protocol  = "tcp"
        description : "MySQL"
      }
    ]
    postgres = [
      {
        from_port = 5432
        to_port   = 5432
        protocol  = "tcp"
        description : "PostgreSQL"
      }
    ]

    # AWS Services
    aws-efs = [
      {
        from_port = 2049
        to_port   = 2049
        protocol  = "tcp"
        description : "NFS (TCP)"
      },
      {
        from_port = 2049
        to_port   = 2049
        protocol  = "udp"
        description : "NFS (UDP)"
      }
    ]
    aws-redshift = [
      {
        from_port = 5431
        to_port   = 5455
        protocol  = "tcp"
        description : "AWS Redshift"
      },
      {
        from_port = 8191
        to_port   = 8215
        protocol  = "tcp"
        description : "AWS Redshift"
      }
    ]
    aws-ses = [
      {
        from_port = 25
        to_port   = 25
        protocol  = "tcp"
        description : "SMTP"
      },
      {
        from_port = 465
        to_port   = 465
        protocol  = "tcp"
        description : "SMTPS"
      },
      {
        from_port = 587
        to_port   = 587
        protocol  = "tcp"
        description : "SMTP submission"
      },
      {
        from_port = 2465
        to_port   = 2465
        protocol  = "tcp"
        description : "SMTPS (AWS SES)"
      },
      {
        from_port = 2587
        to_port   = 2587
        protocol  = "tcp"
        description : "SMTP submission (AWS SES)"
      },
    ]
  }
}
