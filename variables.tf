/*
Input variables.
*/

variable "sg1_services" {
  description = "List of services definition that SG1 provides to SG2."
  type = list(object({
    protocol    = string
    from_port   = optional(number, 0)
    to_port     = optional(number)
    description = optional(string)
  }))
  default = []
}

variable "sg1_security_group" {
  description = "SG1 Security group information."
  type = object({
    id         = string
    account_id = optional(string)
  })
}

variable "sg2_services" {
  description = "List of services definition that SG2 provides to SG1."
  type = list(object({
    protocol    = string
    from_port   = optional(number, 0)
    to_port     = optional(number)
    description = optional(string)
  }))
  default = []
}

variable "sg2_security_group" {
  description = "SG2 Security group information."
  type = object({
    id         = string
    account_id = optional(string)
  })
}

variable "sg2_add_rules" {
  description = "If 'true', add security group rules to SG2. 'false' may be required if SG2 is already pre-configured."
  type        = bool
  default     = true
}
