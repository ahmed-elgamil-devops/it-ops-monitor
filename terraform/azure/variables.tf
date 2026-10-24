variable "location" {
  type    = string
  default = "uaenorth" # Azure UAE North (Dubai)
}

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}

variable "admin_cidr" {
  description = "Your public IP in CIDR form, e.g. 203.0.113.10/32"
  type        = string
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}
