#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Set

import requests
import yaml
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ----------------------------
# Models
# ----------------------------

@dataclass
class ProxmoxNode:
    name: str
    status: str
    maxcpu: int
    cpu: float
    maxmem: int
    mem: int

    @property
    def free_mem_mb(self):
        return int((self.maxmem - self.mem) / (1024 * 1024))

    @property
    def free_cpu(self):
        return self.maxcpu - (self.cpu * self.maxcpu)
    
@dataclass
class ProxmoxVM:
    vmid: int
    name: str
    node: str
    cpus: int
    mem_mb: int
    status: str


@dataclass
class NodeRequest:
    key: str
    role: str
    cores: int
    mem: int
    disk: int


# ----------------------------
# Load Config
# ----------------------------

def load_config(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)
    
def normalize_endpoint(endpoint: str) -> str:
    endpoint = endpoint.strip().rstrip("/")
    if not endpoint.endswith("/api2/json"):
        endpoint = endpoint + "/api2/json"
    return endpoint

def get_auth_headers(config: dict) -> tuple[str, dict]:
    endpoint = os.getenv(config["proxmox"]["endpoint_env"])
    api_token = os.getenv("TF_VAR_proxmox_host_api_token")

    if not endpoint:
        raise RuntimeError("Missing Proxmox endpoint env var")

    if not api_token:
        raise RuntimeError("Missing Proxmox API token env var")
    
    endpoint = normalize_endpoint(endpoint)
    headers = {
        "Authorization": f"PVEAPIToken={api_token}"
    }
    return endpoint, headers



# ----------------------------
# Proxmox API
# ----------------------------

def get_nodes(config: dict) -> List[ProxmoxNode]:
    endpoint, headers = get_auth_headers(config)

    r = requests.get(f"{endpoint}/nodes", headers=headers, verify=False, timeout=10)
    r.raise_for_status()

    nodes: List[ProxmoxNode] = []
    for n in r.json()["data"]:
        nodes.append(
            ProxmoxNode(
                name=n["node"],
                status=n.get("status", "unknown"),
                maxcpu=int(n.get("maxcpu", 0)),
                cpu=float(n.get("cpu", 0.0)),
                maxmem=int(n.get("maxmem", 0)),
                mem=int(n.get("mem", 0)),
            )
        )
    return nodes

def get_all_qemu_vms(config: dict, candidate_nodes: List[str]) -> List[ProxmoxVM]:
    endpoint, headers = get_auth_headers(config)

    r = requests.get(
        f"{endpoint}/cluster/resources?type=vm",
        headers=headers,
        verify=False,
        timeout=15,
    )
    r.raise_for_status()

    vms: List[ProxmoxVM] = []

    for vm in r.json()["data"]:
        # Only keep QEMU VMs on candidate nodes
        if vm.get("type") != "qemu":
            continue

        node_name = vm.get("node")
        if node_name not in candidate_nodes:
            continue

        vmid = vm.get("vmid")
        if vmid is None:
            print(f"[warn] skipping VM entry without vmid: {vm}")
            continue

        vms.append(
            ProxmoxVM(
                vmid=int(vmid),
                name=vm.get("name", f"vm-{vmid}"),
                node=node_name,
                cpus=int(vm.get("maxcpu", vm.get("cpus", 0))),
                mem_mb=int(vm.get("maxmem", 0) / (1024 * 1024)),
                status=vm.get("status", "unknown"),
            )
        )

    return vms

def build_reclaimable_vmids(config: dict) -> Set[int]:
    vmids: Set[int] = set()

    cp_vmid = int(config["vmid_ranges"]["cp_base"])
    wk_base_vmid = int(config["vmid_ranges"]["wk_base"])
    observer_vmid = int(config["vmid_ranges"]["observer_vmid"])
    worker_count = int(config["layout"]["worker_count"])

    vmids.add(cp_vmid)
    vmids.add(observer_vmid)

    for i in range(worker_count):
        vmids.add(wk_base_vmid + i + 1)
    return vmids


# ----------------------------
# Build Requests
# ----------------------------

def build_requests(config):
    defaults = config["defaults"]
    layout = config["layout"]

    reqs: List[NodeRequest] = []

    # Control plane
    reqs.append(NodeRequest(
        key="controlplane",
        role="controlplane",
        cores=int(defaults["controlplane"]["cores"]),
        mem=int(defaults["controlplane"]["mem"]),
        disk=int(defaults["controlplane"]["disk"]),
    ))

    # Workers
    for i in range(layout["worker_count"]):
        reqs.append(NodeRequest(
            key=f"wk-{i+1:02d}",
            role="worker",
            cores=int(defaults["worker"]["cores"]),
            mem=int(defaults["worker"]["mem"]),
            disk=int(defaults["worker"]["disk"]),
        ))

    # Sméagol
    if layout["include_smeagol"]:
        reqs.append(NodeRequest(
            key="smeagol",
            role="observer",
            cores=int(defaults["observer"]["cores"]),
            mem=int(defaults["observer"]["mem"]),
            disk=int(defaults["observer"]["disk"]),
        ))

    return reqs

def apply_reclaim_capacity(
        nodes: List[ProxmoxNode],
        vms: List[ProxmoxVM],
        config: dict,
) -> Dict[str, Dict[str, float]]:
    simulated = {
        n.name: {
            "mem": float(n.free_mem_mb),
            "cpu": float(n.free_cpu),
        }
        for n in nodes
    }

    reclaim_enabled = bool(config.get("planning", {}).get("reclaim_existing_managed_k8s_vms", False))
    reclaimable_vmids = build_reclaimable_vmids(config) if reclaim_enabled else set()

    if reclaim_enabled:
        print(f"[info] reclaim mode enabled for VMIDs: {sorted(reclaimable_vmids)}")

    for vm in vms:
        if vm.vmid in reclaimable_vmids:
            simulated[vm.node]["mem"] += vm.mem_mb
            simulated[vm.node]["cpu"] += vm.cpus
            print(
                f"[reclaim] vmid={vm.vmid} name={vm.name} node={vm.node} "
                f"+{vm.mem_mb}MB +{vm.cpus} CPU"
            )

    return simulated


def preferred_node_bonus(config: dict, role: str, node_name: str) -> float:
    policy = config.get("placement_policy", {})

    if role == "controlplane":
        preferred = policy.get("controlplane_preferred_nodes", [])
        if node_name in preferred:
            return 40.0

    if role == "observer":
        preferred = policy.get("observer_preferred_nodes", [])
        if node_name in preferred:
            return 40.0

    return 0.0


def score_node(
    node: ProxmoxNode,
    req: NodeRequest,
    sim: Dict[str, Dict[str, float]],
    counts: Dict[str, Dict[str, int]],
    config: dict,
) -> float:
    reserves = config["reserves"]

    if node.status != "online":
        return float("-inf")

    free_mem_after = sim[node.name]["mem"] - req.mem
    free_cpu_after = sim[node.name]["cpu"] - req.cores

    if free_mem_after < float(reserves["memory_mb"]):
        return float("-inf")

    if free_cpu_after < float(reserves["cpu_cores"]):
        return float("-inf")

    # Spread by role: penalize stacking same role on same PVE.
    same_role_count = counts[node.name].get(req.role, 0)
    spread_bonus = max(0, 3 - same_role_count) * 10.0

    # Best-fit bias: avoid leaving large fragments, but preserve safe headroom.
    mem_fragmentation_penalty = free_mem_after / 1024.0
    cpu_fragmentation_penalty = free_cpu_after

    # Prefer explicit nodes for some roles.
    role_preference = preferred_node_bonus(config, req.role, node.name)

    # Slight bonus for healthier remaining headroom.
    headroom_bonus = (free_cpu_after * 4.0) + (free_mem_after / 2048.0)

    score = (
        role_preference
        + spread_bonus
        + headroom_bonus
        - (mem_fragmentation_penalty * 2.0)
        - (cpu_fragmentation_penalty * 1.25)
    )
    return score


def schedule(nodes: List[ProxmoxNode], requests_: List[NodeRequest], config: dict) -> Dict[str, Dict[str, int | str]]:
    candidate_nodes = [n.name for n in nodes]
    all_vms = get_all_qemu_vms(config, candidate_nodes)
    sim = apply_reclaim_capacity(nodes, all_vms, config)
    counts: Dict[str, Dict[str, int]] = {n.name: {} for n in nodes}
    result: Dict[str, Dict[str, int | str]] = {}

    # Role order: conservative placement first.
    order = {"controlplane": 0, "observer": 1, "worker": 2}
    requests_ordered = sorted(requests_, key=lambda r: order[r.role])

    print("[info] effective capacity after reclaim:")
    for node_name, cap in sim.items():
        print(
            f"  - {node_name}: free_mem={cap['mem']:.0f}MB "
            f"free_cpu={cap['cpu']:.2f}"
        )

    for req in requests_ordered:
        candidates = []
        for node in nodes:
            s = score_node(node, req, sim, counts, config)
            if s != float("-inf"):
                candidates.append((node, s))

        if not candidates:
            raise RuntimeError(
                f"No valid placement for {req.key} "
                f"(role={req.role}, cores={req.cores}, mem={req.mem}MB, disk={req.disk}GB)"
            )

        best_node, best_score = max(candidates, key=lambda x: x[1])

        result[req.key] = {
            "proxmox_node": best_node.name,
            "cores": req.cores,
            "mem": req.mem,
            "disk": req.disk,
        }

        sim[best_node.name]["mem"] -= req.mem
        sim[best_node.name]["cpu"] -= req.cores
        counts[best_node.name][req.role] = counts[best_node.name].get(req.role, 0) + 1

        print(
            f"[place] {req.key:<12} role={req.role:<12} -> {best_node.name} "
            f"(score={best_score:.2f}, remaining_mem={sim[best_node.name]['mem']:.0f}MB, "
            f"remaining_cpu={sim[best_node.name]['cpu']:.2f})"
        )

    return result


# ----------------------------
# Main
# ----------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description="Generate scheduler-driven placement plan for 20-k8s")
    parser.add_argument("--config", required=True, help="Path to scheduler config YAML")
    parser.add_argument("--output", required=True, help="Output tfvars JSON path")
    args = parser.parse_args()

    config = load_config(args.config)
    nodes = get_nodes(config)
    candidate_names = set(config["candidate_nodes"])
    nodes = [n for n in nodes if n.name in candidate_names]

    if not nodes:
        print("ERROR: no candidate Proxmox nodes found", file=sys.stderr)
        return 1

    requests_ = build_requests(config)

    try:
        plan = schedule(nodes, requests_, config)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    output = {"k8s_node_plan": plan}

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")

    print(f"[ok] wrote {out_path}")
    return 0

# python3 scripts/breaking_of_the_fellowship.py --config terraform/envs/20-k8s/scheduler-config.yaml --output terraform/envs/20-k8s/generated-placement.auto.tfvars.json
# cd envs/20-k8s
# terraform plan

if __name__ == "__main__":
    raise SystemExit(main())