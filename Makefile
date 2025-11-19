.PHONY: help init plan apply destroy validate fmt lint test

# Configuration
ENVIRONMENT ?= development/robotics-prod
TF_DIR = infra/environments/$(ENVIRONMENT)
ANSIBLE_DIR = infra/ansible

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m # No Color

help:
	@echo "$(BLUE)Robotics Automation Platform - Make Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Terraform Commands:$(NC)"
	@echo "  make init              Initialize Terraform"
	@echo "  make plan              Plan infrastructure changes"
	@echo "  make apply             Apply infrastructure changes"
	@echo "  make destroy           Destroy all infrastructure"
	@echo "  make validate          Validate Terraform configuration"
	@echo "  make fmt               Format Terraform files"
	@echo ""
	@echo "$(GREEN)Ansible Commands:$(NC)"
	@echo "  make provision-cp      Provision control plane"
	@echo "  make provision-workers Provision worker nodes"
	@echo "  make deploy-cni        Deploy CNI (Cilium/Flannel)"
	@echo "  make deploy-kubeedge   Deploy KubeEdge"
	@echo "  make deploy-ros2       Deploy ROS 2"
	@echo "  make deploy-all        Run all Ansible playbooks"
	@echo ""
	@echo "$(GREEN)Kubernetes Commands:$(NC)"
	@echo "  make kubeconfig        Get kubeconfig"
	@echo "  make get-nodes         Get cluster nodes"
	@echo "  make get-pods          Get all pods"
	@echo "  make get-services      Get all services"
	@echo "  make cluster-info      Show cluster information"
	@echo ""
	@echo "$(GREEN)Utility Commands:$(NC)"
	@echo "  make outputs           Show Terraform outputs"
	@echo "  make inventory         Generate Ansible inventory"
	@echo "  make cost              Show estimated costs"
	@echo "  make lint              Lint Terraform files"
	@echo "  make test              Run tests"
	@echo "  make clean             Clean up local files"
	@echo ""
	@echo "$(GREEN)Usage Examples:$(NC)"
	@echo "  make init plan apply   # Quick start"
	@echo "  make ENVIRONMENT=staging apply  # Use different environment"
	@echo ""

# Terraform targets
init:
	@echo "$(BLUE)Initializing Terraform in $(TF_DIR)$(NC)"
	cd $(TF_DIR) && terraform init

plan:
	@echo "$(BLUE)Planning infrastructure changes$(NC)"
	cd $(TF_DIR) && terraform plan

apply:
	@echo "$(BLUE)Applying infrastructure changes$(NC)"
	@read -p "Are you sure you want to apply? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(TF_DIR) && terraform apply; \
	fi

destroy:
	@echo "$(RED)Destroying infrastructure$(NC)"
	@read -p "Are you sure you want to destroy? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(TF_DIR) && terraform destroy; \
	fi

validate:
	@echo "$(BLUE)Validating Terraform configuration$(NC)"
	cd $(TF_DIR) && terraform validate

fmt:
	@echo "$(BLUE)Formatting Terraform files$(NC)"
	cd infra && terraform fmt -recursive

lint:
	@echo "$(BLUE)Linting Terraform files$(NC)"
	@command -v tflint >/dev/null 2>&1 || { echo "$(RED)tflint not installed$(NC)"; exit 1; }
	cd $(TF_DIR) && tflint

# Ansible targets
provision-cp:
	@echo "$(BLUE)Provisioning control plane$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/provision-control-plane.yml

provision-workers:
	@echo "$(BLUE)Provisioning worker nodes$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/provision-worker-nodes.yml

deploy-cni:
	@echo "$(BLUE)Deploying CNI$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-cni.yml

deploy-kubeedge:
	@echo "$(BLUE)Deploying KubeEdge$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-kubeedge.yml

deploy-ros2:
	@echo "$(BLUE)Deploying ROS 2$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-ros2.yml

deploy-all: provision-cp provision-workers deploy-cni deploy-kubeedge deploy-ros2
	@echo "$(GREEN)All deployments complete$(NC)"

# Kubernetes targets
kubeconfig:
	@echo "$(BLUE)Getting kubeconfig$(NC)"
	@cd $(TF_DIR) && terraform output kubeconfig_path
	@echo "$(GREEN)Set KUBECONFIG:$(NC)"
	@echo "  export KUBECONFIG=\$$(cd $(TF_DIR) && terraform output -raw kubeconfig_path)"

get-nodes:
	@echo "$(BLUE)Cluster nodes:$(NC)"
	kubectl get nodes -o wide

get-pods:
	@echo "$(BLUE)All pods:$(NC)"
	kubectl get pods -A

get-services:
	@echo "$(BLUE)All services:$(NC)"
	kubectl get svc -A

cluster-info:
	@echo "$(BLUE)Cluster information:$(NC)"
	@echo ""
	@echo "Control Plane:"
	kubectl cluster-info
	@echo ""
	@echo "Nodes:"
	kubectl get nodes -o wide
	@echo ""
	@echo "Namespaces:"
	kubectl get ns
	@echo ""
	@echo "Pod counts:"
	kubectl get pods -A -o json | jq '.items | length'

# Utility targets
outputs:
	@echo "$(BLUE)Terraform outputs$(NC)"
	cd $(TF_DIR) && terraform output

inventory:
	@echo "$(BLUE)Generating Ansible inventory from Terraform$(NC)"
	cd $(ANSIBLE_DIR) && \
	cat > inventory-terraform.yml << 'EOF'
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
  children:
    k8s_control_plane:
      hosts:
        k8s-cp-1:
          ansible_host: $(shell cd $(TF_DIR) && terraform output -json | jq -r '.control_plane_ips.value[0]')
        k8s-cp-2:
          ansible_host: $(shell cd $(TF_DIR) && terraform output -json | jq -r '.control_plane_ips.value[1]')
        k8s-cp-3:
          ansible_host: $(shell cd $(TF_DIR) && terraform output -json | jq -r '.control_plane_ips.value[2]')
    k8s_workers:
      hosts:
        k8s-worker-1:
          ansible_host: $(shell cd $(TF_DIR) && terraform output -json | jq -r '.worker_node_ips.value[0]')
        k8s-worker-2:
          ansible_host: $(shell cd $(TF_DIR) && terraform output -json | jq -r '.worker_node_ips.value[1]')
        k8s-worker-3:
          ansible_host: $(shell cd $(TF_DIR) && terraform output -json | jq -r '.worker_node_ips.value[2]')
EOF
	@echo "$(GREEN)Inventory generated: ansible/inventory-terraform.yml$(NC)"

cost:
	@echo "$(BLUE)Estimated monthly costs:$(NC)"
	@echo ""
	@echo "On-Demand Configuration:"
	@echo "  - 3x m6g.large (control plane): ~\$$110/month"
	@echo "  - 3x t4g.large (workers): ~\$$50/month"
	@echo "  - RDS Aurora PostgreSQL: ~\$$150/month"
	@echo "  - Data transfer: ~\$$20/month"
	@echo "  - Total: ~\$$330/month"
	@echo ""
	@echo "SPOT Configuration (40% savings):"
	@echo "  - 3x m6g.large (control plane): ~\$$110/month"
	@echo "  - 3x t4g.large (SPOT workers): ~\$$10/month"
	@echo "  - RDS Aurora PostgreSQL: ~\$$150/month"
	@echo "  - Data transfer: ~\$$20/month"
	@echo "  - Total: ~\$$290/month"
	@echo ""

test:
	@echo "$(BLUE)Running tests$(NC)"
	@echo "Terraform validation:"
	cd $(TF_DIR) && terraform validate
	@echo "Ansible syntax check:"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/*.yml --syntax-check
	@echo "$(GREEN)Tests passed$(NC)"

clean:
	@echo "$(RED)Cleaning up local files$(NC)"
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.tfstate*" -type f -delete 2>/dev/null || true
	find . -name ".kubeconfig" -type f -delete 2>/dev/null || true
	find . -name "inventory-terraform.yml" -type f -delete 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete$(NC)"

# Full deployment workflow
deploy: init validate plan apply inventory provision-cp provision-workers deploy-cni deploy-kubeedge deploy-ros2
	@echo "$(GREEN)Complete deployment finished!$(NC)"
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  1. Wait 2-3 minutes for pods to be ready"
	@echo "  2. Run: $(RED)make get-pods$(NC)"
	@echo "  3. Test ROS 2: Check QUICKSTART.md for commands"

# Development helpers
watch-pods:
	@watch kubectl get pods -A

watch-nodes:
	@watch kubectl get nodes -o wide

logs-kubeedge:
	@kubectl logs -n kubeedge -l app=cloudcore -f

logs-ros2:
	@kubectl logs -n ros2-workloads -l app=ros2-workload -f

shell:
	@POD=$$(kubectl get pods -n ros2-workloads -o jsonpath='{.items[0].metadata.name}'); \
	kubectl exec -it $$POD -n ros2-workloads -- bash

# CI/CD helpers
validate-all: validate lint test
	@echo "$(GREEN)All validations passed$(NC)"

tf-version:
	@echo "$(BLUE)Terraform version requirements:$(NC)"
	cd $(TF_DIR) && terraform version

versions:
	@echo "$(BLUE)Tool versions:$(NC)"
	@echo "Terraform:"; terraform version
	@echo "Ansible:"; ansible --version
	@echo "kubectl:"; kubectl version --client
	@echo "Helm:"; helm version
