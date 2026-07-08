variable "location" {
  description = "Default Azure Region"
  type = string
  default = "West Europe"
}

variable "rails_master_key" {
  description = "Rails Master Key for decrypting credentials"
  type        = string
  sensitive   = true
}

