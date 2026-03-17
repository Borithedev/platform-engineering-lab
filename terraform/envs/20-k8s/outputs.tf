
output "controlplane" {
  value = {
    name = module.k8s_controlplane.hostname
    ip   = module.k8s_controlplane.ipv4
    node = module.k8s_controlplane.node_name
  }
}

output "workers" {
  value = {
    for k, m in module.k8s_workers :
    k => {
      name = m.hostname
      ip   = m.ipv4
      node = m.node_name
    }
  }
}

output "smeagol" {
  value = contains(keys(module.k8s_smeagol), "smeagol") ? {
    name = module.k8s_smeagol["smeagol"].hostname
    ip   = module.k8s_smeagol["smeagol"].ipv4
    node = module.k8s_smeagol["smeagol"].node_name
  } : null
}
