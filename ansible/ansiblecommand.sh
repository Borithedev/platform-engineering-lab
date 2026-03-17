#!/bin/bash

#bootstrap setup
ansible-playbook -i inventories/bootstrap/hosts.ini playbooks/bootstrap_minio.yaml --extra-vars "minio_root_user=minioadmin minio_root_password= tfstate_user_secret_key="
ansible-playbook -i inventories/bootstrap/hosts.ini playbooks/bootstrap_vault.yaml
#Vault commands
#inital
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator init -key-shares=5 -key-threshold=3
vault operator unseal x3
#put secret in path
vault secrets enable -path=kv kv-v2
vault login <root token>
vault kv put kv/<secret_path (iac/proxmox)> key=secret
#create policy/approle for terraform(kv/iac/proxmox[endpoint, api_token, credential] and kv/iac/minio[accesskey, bucket, endpoint, secretkey] secrets) and ansible(kv/iac/gitlab-runner[url, token])
path "secret_data_path(kv/data/iac/proxmox)" {
    capabilities = ["read"]
} >> policy.hcl
vault policy write policy_name policy.hcl
vault write auth/approle/role/role_name token_policies=policy_name token_ttl="30m" token_max_ttl="60m"
vault read -field=role_id auth/approle/role/role_name/role_id
vault write -force -field=secret_id auth/approle/role/role_name/secret_id


#cluster setup
ansible-playbook -i inventories/k8s/hosts.ini playbooks/k8s_prereqs.yaml
ansible-playbook -i inventories/k8s/hosts.ini playbooks/k8s_controlplane_init.yaml
ansible-playbook -i inventories/k8s/hosts.ini playbooks/k8s_cilium.yaml
ansible-playbook -i inventories/k8s/hosts.ini playbooks/k8s_join_token.yaml
ansible-playbook -i inventories/k8s/hosts.ini playbooks/k8s_workers_join.yaml
#copy kubeconfig to local
mkdir -p ~/.kube
scp ubuntu@192.168.0.44:/home/ubuntu/.kube/config ~/.kube/config # scp ubuntu@<CONTROL_PLANE_IP>:/home/ubuntu/.kube/config ~/.kube/config
k label node smeagol node-role.kubernetes.io/observability=true
k taint node smeagol observability=true:NoSchedule
#addons
ansible-playbook -i inventories/k8s/hosts.ini playbooks/addons/00_metallb.yaml
ansible-playbook -i inventories/k8s/hosts.ini playbooks/addons/10_traefik.yaml
ansible-playbook -i inventories/k8s/hosts.ini playbooks/addons/20_cert_manager.yaml
ansible-playbook -i inventories/k8s/hosts.ini playbooks/addons/30_rancher.yaml
ansible-playbook -i inventories/k8s/hosts.ini playbooks/addons/40_longhorn.yaml
ansible-playbook -i inventories/k8s/hosts.ini playbooks/addons/50_kube_prometheus_stack.yaml
ansible-playbook -i inventories/k8s/hosts.ini playbooks/addons/60_monitoring_ingress.yaml
ansible-playbook -i inventories/k8s/hosts.ini playbooks/addons/70_gitlab_runner.yaml --extra-vars "vault_role_id= vault_secret_id="