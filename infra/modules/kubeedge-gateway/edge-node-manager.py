#!/usr/bin/env python3
"""
KubeEdge Edge Node Manager
Manages edge node registration, monitoring, and ROS2 deployment
"""

import subprocess
import json
import sys
import argparse
from pathlib import Path
from typing import Optional, Dict, List

class EdgeNodeManager:
    def __init__(self, namespace: str = "kubeedge"):
        self.namespace = namespace
        self.kubeedge_version = "1.15.0"
    
    def get_cloudcore_endpoint(self) -> Dict[str, str]:
        """Get CloudCore service endpoint"""
        try:
            result = subprocess.run(
                f"kubectl get svc cloudcore -n {self.namespace} -o json",
                shell=True, capture_output=True, text=True
            )
            svc = json.loads(result.stdout)
            
            # For kind, use port-forward or internal IP
            cluster_ip = svc['spec']['clusterIP']
            return {
                'ip': cluster_ip,
                'port': '10000',
                'ws_port': '10000',
                'quic_port': '10001',
                'https_port': '10002'
            }
        except Exception as e:
            print(f"Error getting CloudCore endpoint: {e}")
            return {}
    
    def generate_join_script(self, node_name: str, cloudcore_ip: str) -> str:
        """Generate edge node join script"""
        return f"""#!/bin/bash
set -e

EDGE_NODE_NAME="{node_name}"
CLOUDCORE_IP="{cloudcore_ip}"
CLOUDCORE_PORT="10000"
KUBEEDGE_VERSION="{self.kubeedge_version}"

echo "Joining edge node: $EDGE_NODE_NAME to $CLOUDCORE_IP:$CLOUDCORE_PORT"

# Install keadm
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    ARCH="arm64"
fi

curl -L https://github.com/kubeedge/kubeedge/releases/download/v${{KUBEEDGE_VERSION}}/keadm-v${{KUBEEDGE_VERSION}}-linux-$ARCH \\
  -o /tmp/keadm && chmod +x /tmp/keadm

# Join cluster
/tmp/keadm join --cloudcore-ipport=$CLOUDCORE_IP:$CLOUDCORE_PORT \\
  --edgenode-name=$EDGE_NODE_NAME \\
  --kubeedge-version=v${{KUBEEDGE_VERSION}}

echo "Edge node $EDGE_NODE_NAME joined successfully!"
"""
    
    def list_edge_nodes(self) -> List[str]:
        """List all edge nodes in cluster"""
        try:
            result = subprocess.run(
                "kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels.kubeedge == \"true\") | .metadata.name'",
                shell=True, capture_output=True, text=True
            )
            return result.stdout.strip().split('\n') if result.stdout else []
        except Exception as e:
            print(f"Error listing edge nodes: {e}")
            return []
    
    def get_edge_node_status(self, node_name: str) -> Dict:
        """Get status of edge node"""
        try:
            result = subprocess.run(
                f"kubectl get node {node_name} -o json",
                shell=True, capture_output=True, text=True
            )
            node = json.loads(result.stdout)
            
            status = {
                'name': node_name,
                'ready': False,
                'version': node['status']['nodeInfo']['kubeletVersion'],
                'conditions': {}
            }
            
            for condition in node['status']['conditions']:
                status['conditions'][condition['type']] = condition['status']
                if condition['type'] == 'Ready':
                    status['ready'] = condition['status'] == 'True'
            
            return status
        except Exception as e:
            print(f"Error getting status for {node_name}: {e}")
            return {}
    
    def deploy_ros2_app(self, app_name: str, image: str, domain_id: str = "42") -> str:
        """Deploy ROS2 app on edge nodes"""
        yaml = f"""apiVersion: apps/v1
kind: Deployment
metadata:
  name: {app_name}-edge
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {app_name}-edge
  template:
    metadata:
      labels:
        app: {app_name}-edge
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/edge
                operator: In
                values:
                - "true"
      
      containers:
      - name: ros2-app
        image: {image}
        imagePullPolicy: IfNotPresent
        env:
        - name: ROS_DOMAIN_ID
          value: "{domain_id}"
        - name: ROS_LOCALHOST_ONLY
          value: "0"
        - name: RCUTILS_LOGGING_USE_STDOUT
          value: "1"
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1Gi
"""
        return yaml
    
    def show_status(self):
        """Show KubeEdge cluster status"""
        print("=== KubeEdge Cluster Status ===\n")
        
        # CloudCore status
        print("CloudCore:")
        subprocess.run(f"kubectl get deployment cloudcore -n {self.namespace}", shell=True)
        
        # Edge nodes
        print("\nEdge Nodes:")
        edge_nodes = self.list_edge_nodes()
        if edge_nodes:
            for node in edge_nodes:
                status = self.get_edge_node_status(node)
                ready = "✓" if status.get('ready') else "✗"
                print(f"  {ready} {status['name']} ({status['version']})")
        else:
            print("  No edge nodes registered")
        
        # CloudCore endpoint
        print("\nCloudCore Endpoint:")
        endpoint = self.get_cloudcore_endpoint()
        print(f"  IP: {endpoint.get('ip')}")
        print(f"  WebSocket: {endpoint.get('port')}")
        print(f"  QUIC: {endpoint.get('quic_port')}")

def main():
    parser = argparse.ArgumentParser(description='Manage KubeEdge edge nodes and simulations')
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # status command
    subparsers.add_parser('status', help='Show KubeEdge cluster status')
    
    # join command
    join_parser = subparsers.add_parser('join-script', help='Generate edge node join script')
    join_parser.add_argument('--node-name', required=True, help='Edge node name')
    join_parser.add_argument('--cloudcore-ip', required=True, help='CloudCore IP')
    join_parser.add_argument('--output', help='Output file path')
    
    # list command
    subparsers.add_parser('list', help='List edge nodes')
    
    # simulate command
    sim_parser = subparsers.add_parser('simulate-edge', help='Simulate an edge node with ROS2')
    sim_parser.add_argument('--node-name', default='robot-edge-01', help='Edge node name')
    sim_parser.add_argument('--worker-node', default='robotics-dev-worker', help='Kubernetes worker node')
    sim_parser.add_argument('--domain-id', default='42', help='ROS_DOMAIN_ID')
    
    # deploy command
    deploy_parser = subparsers.add_parser('deploy-ros2', help='Deploy ROS2 app on edge')
    deploy_parser.add_argument('--app-name', required=True, help='Application name')
    deploy_parser.add_argument('--image', required=True, help='Container image')
    deploy_parser.add_argument('--domain-id', default='42', help='ROS_DOMAIN_ID')
    deploy_parser.add_argument('--output', help='Output YAML file')
    
    args = parser.parse_args()
    manager = EdgeNodeManager()
    
    if args.command == 'status':
        manager.show_status()
    
    elif args.command == 'join-script':
        script = manager.generate_join_script(args.node_name, args.cloudcore_ip)
        if args.output:
            Path(args.output).write_text(script)
            print(f"Join script written to {args.output}")
        else:
            print(script)
    
    elif args.command == 'list':
        nodes = manager.list_edge_nodes()
        for node in nodes:
            print(node)
    
    elif args.command == 'simulate-edge':
        print(f"Simulating edge node: {args.node_name}")
        print(f"Worker node: {args.worker_node}")
        print(f"ROS Domain ID: {args.domain_id}")
        print("")
        
        script_path = Path(__file__).parent / "simulate-edge-node.sh"
        cmd = f"bash {script_path} {args.node_name} {args.worker_node} {args.domain_id}"
        subprocess.run(cmd, shell=True)
    
    elif args.command == 'deploy-ros2':
        yaml = manager.deploy_ros2_app(args.app_name, args.image, args.domain_id)
        if args.output:
            Path(args.output).write_text(yaml)
            print(f"Deployment YAML written to {args.output}")
            subprocess.run(f"kubectl apply -f {args.output}", shell=True)
        else:
            print(yaml)
    
    else:
        parser.print_help()

if __name__ == '__main__':
    main()
