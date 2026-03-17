locals {
  ci_user         = "ubuntu"
  ssh_public_key  = file("../ssh/provisioner/cluster.pub")
  bootstrap_specs = { cpu = 2, mem = 4096, disk = 40 }
  clone_vmid      = { minio = 300, vault = 400 }
  template_vmid   = var.template_vmid
  dns_servers     = ["192.168.0.75", "1.1.1.1"]
  dns_domain      = "home.arpa"
}


module "minio" {
  source = "../../modules/bootstrap/proxmox_ubuntu_vm"
  providers = {
    proxmox = proxmox.dc1
  }
  template_vmid       = local.template_vmid
  node_name           = var.node_name
  clone_vmid          = local.clone_vmid.minio
  name                = "minio-01"
  cores               = local.bootstrap_specs.cpu
  memory              = local.bootstrap_specs.mem
  disk_gb             = local.bootstrap_specs.disk
  hostname            = "minio-01"
  bridge              = var.bridge
  dns_servers         = local.dns_servers
  dns_domain          = local.dns_domain
  ci_user             = local.ci_user
  ssh_public_key      = local.ssh_public_key
  cloud_config_prefix = local.clone_vmid.minio
  tags                = "minio"
}

module "vault" {
  source = "../../modules/bootstrap/proxmox_ubuntu_vm"
  providers = {
    proxmox = proxmox.dc1
  }
  template_vmid       = local.template_vmid
  node_name           = var.node_name
  clone_vmid          = local.clone_vmid.vault
  name                = "vault-01"
  cores               = local.bootstrap_specs.cpu
  memory              = local.bootstrap_specs.mem
  disk_gb             = local.bootstrap_specs.disk
  hostname            = "vault-01"
  bridge              = var.bridge
  dns_servers         = local.dns_servers
  dns_domain          = local.dns_domain
  ci_user             = local.ci_user
  ssh_public_key      = local.ssh_public_key
  cloud_config_prefix = local.clone_vmid.vault

  tags = "vault"
}



output "minio_ip" {
  value = module.minio.ipv4
}

output "vault_ip" {
  value = module.vault.ipv4
}


output "minio_hostname" {
  value = module.minio.hostname
}

output "vault_hostname" {
  value = module.vault.hostname
}

resource "local_file" "ansible_inventory" {
  filename = "${path.root}/../../ansible/inventories/bootstrap/hosts.ini"
  content = templatefile("${path.module}/templates/hosts.tpl", {
    minio = module.minio
    vault = module.vault
  })
}