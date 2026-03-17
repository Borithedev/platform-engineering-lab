terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.93.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">=5.6.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">=6.28.0"
    }
  }
}

provider "proxmox" {
  alias     = "dc1"
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_host_api_token
  insecure  = true
  ssh {
    agent    = true
    username = var.proxmox_username
    password = var.proxmox_password
  }
}