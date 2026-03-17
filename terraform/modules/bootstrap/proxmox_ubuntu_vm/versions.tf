terraform {
  required_providers {
    proxmox = {
      source                = "bpg/proxmox"
      version               = ">= 0.93.0"
      configuration_aliases = [proxmox]
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.8.0"
    }
  }
}