# platform-engineering-lab
This project demonstrates a platform engineering environment designed to simulate production-grade infrastructure using Infrastructure as Code, configuration management, and container orchestration.
## Architecture Overview

- Infrastructure provisioned using Terraform (Proxmox)
- Configuration automated using Ansible
- Kubernetes cluster deployed using kubeadm
- Networking implemented using Cilium
- Ingress managed via Traefik
- Observability stack using Prometheus and Grafana
- Secrets management using HashiCorp Vault

## Key Features

- Fully automated infrastructure provisioning
- Reproducible environment builds
- Kubernetes-based workload orchestration
- Integrated observability and monitoring
- Infrastructure lifecycle managed via IaC

## Technologies Used

- Terraform
- Ansible
- Kubernetes
- Docker
- Prometheus & Grafana
- Vault

## Purpose

This project was built to simulate enterprise platform engineering practices, focusing on scalability, automation, and reliability.

##Architecture

<img width="1859" height="1295" alt="HomeLab-1-ach drawio (3)" src="https://github.com/user-attachments/assets/f126ce44-2b61-4e83-873b-638bb6ea32be" />

## Architecture Decisions

- **Terraform** was used to ensure reproducible infrastructure provisioning and enable declarative infrastructure management.

- **Ansible** was implemented for configuration management to standardise node setup and eliminate manual configuration steps.

- **Kubernetes (kubeadm)** was selected to provide full control over cluster configuration and simulate production-like environments.

- **Cilium** was chosen for networking to leverage eBPF-based observability and advanced network control.

- **Prometheus and Grafana** were implemented to provide real-time observability and system metrics.

- **Traefik** was used as an ingress controller to manage routing of external traffic into the cluster.

- ## Key Outcomes

- Reduced infrastructure provisioning time from several hours to under 20 minutes using Infrastructure as Code.

- Eliminated 15+ manual configuration steps through automation using Ansible.

- Achieved consistent environment rebuilds across multiple deployments.

- Implemented a fully automated, reproducible platform environment simulating enterprise infrastructure.

## Future Improvements

- Implement high availability control plane nodes
- Introduce automated backup and disaster recovery strategies
- Enhance secrets management integration
- Expand CI/CD integration for full GitOps workflows
