resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    data = <<-EOF
    #cloud-config
    hostname: ${var.hostname}
    timezone: Europe/London
    users:
      - name: ubuntu
        groups:
          - sudo
        shell: /bin/bash
        ssh_authorized_keys:
          - ${var.ssh_public_key}
        sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_pwauth: false
    disable_root: false
    package_update: true
    packages:
      - qemu-guest-agent
      - net-tools
      - curl
      - ca-certificates
      - gnupg
    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent
      - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "${var.cloud_config_prefix}-user-data-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  name      = var.name
  node_name = var.node_name
  vm_id     = var.clone_vmid
  tags      = ["terraform", "ubuntu", "${var.tags}"]

  clone {
    vm_id = var.template_vmid
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    size         = var.disk_gb
  }

  initialization {
    datastore_id = "local-zfs"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    dns {
      servers = var.dns_servers
      domain  = var.dns_domain
    }

    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id
  }

  network_device {
    bridge = var.bridge
  }

  serial_device {}

}

output "ipv4" {
  value = proxmox_virtual_environment_vm.ubuntu_template.ipv4_addresses[1][0]
}

output "hostname" {
  value = var.hostname
}

output "node_name" {
  value = var.node_name
}