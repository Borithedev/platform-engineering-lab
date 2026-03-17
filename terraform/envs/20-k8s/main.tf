locals {

  ring_bearers = [
    "frodo-ringbearer",
    "samwise-ringbearer",
    "merry-ringbearer",
    "pippin-ringbearer",
    "bilbo-ringbearer",
  ]

  workers_pool = [
    "aragorn",
    "legolas",
    "gimli",
    "gandalf",
    "samwise",
    "merry",
    "pippin",
    "boromir",
  ]

  dns_servers     = ["192.168.0.75", "1.1.1.1"]
  dns_domain      = "home.arpa"
  ssh_public_key  = file("../ssh/provisioner/cluster.pub")
  additional_tags = "kubernetes"

  # stable base IDs; avoid clashes with 300/400 and my other pre-existing
  cp_vmid_base = 900
  wk_vmid_base = 910
  smeagol_vmid = 920

  # default specs
  cp_specs      = { cpu = 2, mem = 4096, disk = 40 }
  wk_specs      = { cpu = 2, mem = 4096, disk = 40 }
  smeagol_specs = { cpu = 2, mem = 2048, disk = 50 }
}

# Pick ring-bearer for control plane (persists in state)
resource "random_integer" "ringbearer_index" {
  min = 0
  max = length(local.ring_bearers) - 1
}

locals {
  controlplane_name = local.ring_bearers[random_integer.ringbearer_index.result]
  ringbearer_base   = replace(local.controlplane_name, "-ringbearer", "")
  eligible_workers  = [for n in local.workers_pool : n if n != local.ringbearer_base]
  #stable keys for workers using indices, without it the for.each will fail as random_shuffle.worker_names.result can't be used for worker_map as it'll be empty until apply as Randomly generated names are not static
  worker_keys = [for i in range(var.worker_count) : format("wk-%02d", i + 1)]
}

# Pick worker names (unique) for worker_count
resource "random_shuffle" "worker_names" {
  input        = local.eligible_workers
  result_count = var.worker_count
}

locals {
  worker_names = random_shuffle.worker_names.result
}
# map stable key -> object containing random name + placement(Deterministic placement: round-robin across proxmox_nodes) + vmid
locals {
  cp_node = var.proxmox_nodes[0]

  worker_map = {
    for idx, key in local.worker_keys : key => {
      name = random_shuffle.worker_names.result[idx]
      node = var.proxmox_nodes[idx % length(var.proxmox_nodes)]
      vmid = local.wk_vmid_base + idx + 1
    }
  }
}

module "k8s_controlplane" {
  providers = {
    proxmox = proxmox.dc1
  }
  source = "../../modules/proxmox_ubuntu_vm"

  node_name           = local.cp_node
  bridge              = var.bridge
  template_vmid       = var.template_vmid[local.cp_node]
  hostname            = local.controlplane_name
  name                = local.controlplane_name
  clone_vmid          = local.cp_vmid_base + 1
  cores               = local.cp_specs.cpu
  memory              = local.cp_specs.mem
  disk_gb             = local.cp_specs.disk
  cloud_config_prefix = local.cp_vmid_base + 1
  dns_servers         = local.dns_servers
  dns_domain          = local.dns_domain
  ci_user             = local.controlplane_name
  ssh_public_key      = local.ssh_public_key
  tags                = local.additional_tags
}

module "k8s_workers" {
  providers = {
    proxmox = proxmox.dc1
  }
  for_each = local.worker_map
  source   = "../../modules/proxmox_ubuntu_vm"

  node_name           = each.value.node
  bridge              = var.bridge
  template_vmid       = var.template_vmid[each.value.node]
  hostname            = each.value.name
  name                = each.value.name
  clone_vmid          = each.value.vmid
  cores               = local.wk_specs.cpu
  memory              = local.wk_specs.mem
  disk_gb             = local.wk_specs.disk
  cloud_config_prefix = each.value.vmid
  dns_servers         = local.dns_servers
  dns_domain          = local.dns_domain
  ci_user             = each.value.name
  ssh_public_key      = local.ssh_public_key
  tags                = local.additional_tags
}

# Optional "observer" node: smeagol
module "k8s_smeagol" {
  providers = {
    proxmox = proxmox.dc1
  }
  for_each            = var.enable_smeagol ? { smeagol = true } : {}
  source              = "../../modules/proxmox_ubuntu_vm"
  node_name           = var.proxmox_nodes[1 % length(var.proxmox_nodes)]
  bridge              = var.bridge
  template_vmid       = var.template_vmid[var.proxmox_nodes[1 % length(var.proxmox_nodes)]]
  hostname            = "smeagol"
  name                = "smeagol"
  clone_vmid          = local.smeagol_vmid
  cloud_config_prefix = local.smeagol_vmid
  cores               = local.smeagol_specs.cpu
  memory              = local.smeagol_specs.mem
  disk_gb             = local.smeagol_specs.disk
  dns_servers         = local.dns_servers
  dns_domain          = local.dns_domain
  ci_user             = "smeagol"
  ssh_public_key      = local.ssh_public_key
  tags                = local.additional_tags
}

resource "local_file" "ansible_inventory" {
  filename = "${path.root}/../../ansible/inventories/k8s/hosts.ini"

  content = templatefile("${path.module}/templates/hosts.tpl", {
    controlplane = module.k8s_controlplane
    workers      = module.k8s_workers
    smeagol      = module.k8s_smeagol
  })
}
