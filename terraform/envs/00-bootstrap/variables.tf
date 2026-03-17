#proxmox credentials
variable "proxmox_endpoint" {
  type      = string
  sensitive = false
}

variable "proxmox_host_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_username" {
  type      = string
  sensitive = true
}

variable "proxmox_password" {
  type      = string
  sensitive = true

}

variable "node_name" {
  default = "pve-01"
}

variable "bridge" {
  default = "vmbr0"
}

variable "template_vmid" {
  type    = number
  default = 800
}

