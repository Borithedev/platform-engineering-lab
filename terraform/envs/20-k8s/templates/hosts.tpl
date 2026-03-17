[k8s_controlplane]
${controlplane.hostname} ansible_host=${controlplane.ipv4} ansible_user=ubuntu
[k8s_workers]
%{ for _, w in workers ~}
${w.hostname} ansible_host=${w.ipv4} ansible_user=ubuntu
%{ endfor ~}
%{ if length(keys(smeagol)) > 0 ~}
[k8s_observability]
%{ for _, s in smeagol ~}
${s.hostname} ansible_host=${s.ipv4} ansible_user=ubuntu
%{ endfor ~}
%{ endif ~}

[k8s:children]
k8s_controlplane
k8s_workers
%{ if length(keys(smeagol)) > 0 ~}
k8s_observability
%{ endif ~}