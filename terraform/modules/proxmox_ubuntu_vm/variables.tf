variable "name" {

}

variable "node_name" {

}

variable "template_vmid" {
  type = number
}

variable "clone_vmid" {
  type = number
}


variable "cores" {
  type = number
}

variable "memory" {
  type = number
}

variable "disk_gb" {
  type = number
}


variable "dns_servers" {
  type = list(string)
}

variable "dns_domain" {
  type = string
}

variable "hostname" {
  type = string
}

variable "bridge" {
  type = string
}


variable "ci_user" {

}

variable "ssh_public_key" {
  type = string
}

variable "cloud_config_prefix" {
  type = string
}

variable "tags" {

}
