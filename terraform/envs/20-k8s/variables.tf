variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint"
}

variable "proxmox_host_api_token" {
  type        = string
  description = "Proxmox API token"
  sensitive   = true
}

variable "proxmox_nodes" {
  type        = list(string)
  description = "Proxmox node names in the cluster"
  default     = ["pve-01", "pve-02"]
}

variable "proxmox_username" {
  type      = string
  sensitive = true
}

variable "proxmox_password" {
  type      = string
  sensitive = true

}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "template_vmid" {
  type        = map(number)
  description = "Template VMID to clone from for each Proxmox node"
  default = {
    pve-01 = 800
    pve-02 = 810
  }
}

variable "worker_count" {
  type        = number
  description = "How many worker nodes to create (not including smeagol if enabled)"
  default     = 2

  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 8
    error_message = "worker_count must be between 1 and 8 (based on the current worker name pool)."
  }
}

variable "enable_smeagol" {
  type        = bool
  description = "Create a small 'observer' node named smeagol"
  default     = true
}

variable "ssh_public_key_path" {
  type    = string
  default = "../ssh/provisioner/cluster.pub"
}
