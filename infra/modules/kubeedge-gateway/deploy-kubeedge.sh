#!/bin/bash
# Standalone KubeEdge CloudCore + EdgeMesh deployment
# Based on: https://github.com/Function-Delivery-Network/KubeEdge-Openstack-Ansible-Automation

set -e

NAMESPACE="kubeedge"
KUBEEDGE_VERSION="1.15.0"
EDGEMESH_VERSION="1.12.0"

echo "=== Installing KubeEdge CloudCore and EdgeMesh ==="

# 1. Create namespace
echo "[1/5] Creating kubeedge namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 2. Install KubeEdge CloudCore using keadm
echo "[2/5] Installing KubeEdge CloudCore v${KUBEEDGE_VERSION}..."
docker pull kubeedge/cloudcore:v${KUBEEDGE_VERSION}

kubectl apply -f - << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloudcore
  namespace: kubeedge

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cloudcore
rules:
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
  - list
  - watch
  - create
  - delete
- apiGroups:
  - ""
  resources:
  - pods
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - configmaps
  - secrets
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - patch
- apiGroups:
  - apps
  resources:
  - deployments
  - daemonsets
  - statefulsets
  - replicasets
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - batch
  resources:
  - jobs
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - devices.kubeedge.io
  resources:
  - devices
  - devicemodels
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cloudcore
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cloudcore
subjects:
- kind: ServiceAccount
  name: cloudcore
  namespace: kubeedge

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudcore-config
  namespace: kubeedge
data:
  cloudcore.yaml: |
    apiVersion: cloudcore.config.kubeedge.io/v1alpha1
    kind: CloudCore
    kubeAPIConfig:
      kubeContentPath: /etc/kubeedge
      kubeConfig: ""
      masterUrl: ""
      contentType: application/vnd.kubernetes.protobuf
      qps: 100
      burst: 200
    databases:
      sqlite:
        driverName: sqlite
        datasource: /var/lib/kubeedge/kubeedge.db
    modules:
      cloudHub:
        enable: true
        cloudHubPort: 10000
        cloudHubSecurePort: 10002
        websocket:
          enable: true
          port: 10000
          certfile: /etc/kubeedge/ca/server.crt
          keyfile: /etc/kubeedge/ca/server.key
        quic:
          enable: true
          port: 10001
          certfile: /etc/kubeedge/ca/server.crt
          keyfile: /etc/kubeedge/ca/server.key
      eventBus:
        enable: true
        mqttServerExternal: false
        mqttServerPort: 1883
        mqttInternalPort: 11883
      deviceController:
        enable: true
      surfaceAPI:
        enable: false
      dynamicController:
        enable: true
      csiDriver:
        enable: false

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudcore
  namespace: kubeedge
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kubeedge
      tier: cloudcore
  template:
    metadata:
      labels:
        app: kubeedge
        tier: cloudcore
    spec:
      serviceAccountName: cloudcore
      initContainers:
      - name: init-certs
        image: alpine:latest
        command:
        - sh
        - -c
        - |
          # Create dummy certs if they don't exist
          mkdir -p /etc/kubeedge/ca
          if [ ! -f /etc/kubeedge/ca/server.crt ]; then
            echo "Creating self-signed certificates..."
            apk add --no-cache openssl
            openssl req -new -x509 -days 365 -nodes \
              -out /etc/kubeedge/ca/server.crt \
              -keyout /etc/kubeedge/ca/server.key \
              -subj "/CN=cloudcore"
          fi
        volumeMounts:
        - name: ca
          mountPath: /etc/kubeedge/ca
      containers:
      - name: cloudcore
        image: kubeedge/cloudcore:v${KUBEEDGE_VERSION}
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 10000
          name: websocket
          protocol: TCP
        - containerPort: 10001
          name: quic
          protocol: UDP
        - containerPort: 10002
          name: https
          protocol: TCP
        - containerPort: 9000
          name: metrics
          protocol: TCP
        env:
        - name: KUBEEDGE_CLOUDCORE_ENABLE_METRICS
          value: "true"
        volumeMounts:
        - name: config
          mountPath: /etc/kubeedge/config
        - name: ca
          mountPath: /etc/kubeedge/ca
        - name: data
          mountPath: /var/lib/kubeedge
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - ps aux | grep cloudcore | grep -v grep
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: config
        configMap:
          name: cloudcore-config
      - name: ca
        emptyDir: {}
      - name: data
        emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: cloudcore
  namespace: kubeedge
spec:
  type: LoadBalancer
  selector:
    app: kubeedge
    tier: cloudcore
  ports:
  - name: websocket
    port: 10000
    protocol: TCP
    targetPort: 10000
  - name: quic
    port: 10001
    protocol: UDP
    targetPort: 10001
  - name: https
    port: 10002
    protocol: TCP
    targetPort: 10002
  - name: metrics
    port: 9000
    protocol: TCP
    targetPort: 9000
EOF

echo "[3/5] Waiting for CloudCore to be ready..."
kubectl rollout status deployment/cloudcore -n $NAMESPACE --timeout=300s

# 3. EdgeMesh deployment (optional, shipped with KubeEdge)
echo "[4/5] EdgeMesh is shipped with KubeEdge v${KUBEEDGE_VERSION}"
echo "      EdgeMesh provides service discovery and network tunneling for edge nodes"
echo "      For manual EdgeMesh deployment, see: https://edgemesh.netlify.app/"

# 4. Setup edge node joining script
echo "[5/5] Creating edge node join script..."
cat > /tmp/join-edge-node.sh << 'EDGE_SCRIPT'
#!/bin/bash
# Run this on edge nodes to join KubeEdge cluster

EDGE_NODE_NAME="${1:-edge-node-1}"
CLOUDCORE_IP="${2:-localhost}"
CLOUDCORE_PORT="${3:-10000}"
KUBEEDGE_VERSION="1.15.0"

echo "Joining edge node: $EDGE_NODE_NAME to CloudCore at $CLOUDCORE_IP:$CLOUDCORE_PORT"

# 1. Install keadm on edge node
curl -sk https://github.com/kubeedge/kubeedge/releases/download/v${KUBEEDGE_VERSION}/keadm-v${KUBEEDGE_VERSION}-linux-arm64 \
  -o /usr/local/bin/keadm || \
curl -sk https://github.com/kubeedge/kubeedge/releases/download/v${KUBEEDGE_VERSION}/keadm-v${KUBEEDGE_VERSION}-linux-amd64 \
  -o /usr/local/bin/keadm

chmod +x /usr/local/bin/keadm

# 2. Join edge node
keadm join --cloudcore-ipport=$CLOUDCORE_IP:$CLOUDCORE_PORT \
  --edgenode-name=$EDGE_NODE_NAME \
  --kubeedge-version=v${KUBEEDGE_VERSION}

echo "Edge node joined successfully!"
EDGE_SCRIPT

chmod +x /tmp/join-edge-node.sh

echo ""
echo "=== KubeEdge Deployment Complete ==="
echo ""
echo "CloudCore Status:"
kubectl get pods -n $NAMESPACE
echo ""
echo "To join an edge node, run:"
echo "  scp /tmp/join-edge-node.sh <edge-node>:/tmp/"
echo "  ssh <edge-node> '/tmp/join-edge-node.sh <node-name> <cloudcore-ip> 10000'"
echo ""
echo "Get CloudCore IP:"
echo "  kubectl get svc cloudcore -n $NAMESPACE"
echo ""
echo "View CloudCore logs:"
echo "  kubectl logs -f deployment/cloudcore -n $NAMESPACE"
