[minio]
${minio.hostname} ansible_host=${minio.ipv4} ansible_user=ubuntu

[vault]
${vault.hostname} ansible_host=${vault.ipv4} ansible_user=ubuntu