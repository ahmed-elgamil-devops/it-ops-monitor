variable "region" {
  type    = string
  default = "me-central-1" # UAE region
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "admin_cidr" {
  description = "Your public IP in CIDR form, e.g. 203.0.113.10/32"
  type        = string
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}
