Flyte v2 Architecture & Single-Binary Helm Chart Guide
1. Architecture Overview
Flyte v2 simplifies the deployment model into a Unified Binary approach while shifting the execution model to a Kubernetes Operator pattern.

Key Components
Unified Binary (flyte): The core application, built from 
manager/cmd/main.go
. It bundles the following services:

QueueService: Manages execution queues (queue/).
RunService: Manages workflow runs (runs/).
StateService: Manages state persistence (state/).
DataProxy: Handles data interactions (dataproxy/).
Executor: A Kubernetes Controller (executor/).
Executor (The Operator): The "new executor" is a Kubernetes Operator built with controller-runtime.

Role: It watches TaskAction Custom Resources (CRs) and reconciles them to execute tasks.
Mechanism: Instead of passively receiving work, it actively watches the K8s API for TaskAction objects created by the other services.
Database: All services share a PostgreSQL database (configured via pgx and gorm).

2. Requirements for a Single-Binary Helm Chart
To deploy Flyte v2 as a simple single-binary setup, your Helm chart needs to manage the following resources.

A. Kubernetes Resources
Custom Resource Definitions (CRDs)

You MUST install the TaskAction CRD.
Reference File: 
executor/config/crd/bases/flyte.org_taskactions.yaml
Group/Kind: flyte.org/TaskAction.
RBAC (Critical for Executor)

The binary runs the Executor controller, which creates/updates/watches TaskAction resources.
ServiceAccount: Create a SA (e.g., flyte-manager).
ClusterRole: Needs the following permissions (based on 
executor/config/rbac/role.yaml
):
yaml
rules:
- apiGroups: ["flyte.org"]
  resources: ["taskactions", "taskactions/status", "taskactions/finalizers"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
ClusterRoleBinding: Bind the SA to the ClusterRole.
Deployment

Image: Your built image (using the root 
Dockerfile
).
Command: flyte all --config /etc/flyte/config.yaml (runs all services + executor).
ServiceAccount: Use the one created above.
Ports:
8090: Main GRPC/HTTP traffic (Connect API).
8081: Health probes (/healthz, /readyz).
Service

Expose port 8090 for internal/external communication.
ConfigMap

Mount 
config.yaml
 to /etc/flyte/config.yaml.
B. Configuration (
config.yaml
)
The single binary needs a consolidated config:

yaml
server:
  host: "0.0.0.0"
  port: 8090
executor:
  healthProbePort: 8081
  # Defines where the operator looks for resources
  kubernetes:
    namespace: "flyte" 
database:
  postgres:
    host: "postgres-service"
    port: 5432
    dbname: "flyte"
    user: "postgres"
    password: "password" # Or file path for secrets
3. Deployment Strategy
Since there is no existing chart, you can create a simple one:

Templates:
crd.yaml: Copy content from 
executor/config/crd/bases/flyte.org_taskactions.yaml
.
deployment.yaml: Standard Deployment using the single binary image.
rbac.yaml: ServiceAccount, ClusterRole, Binding.
configmap.yaml: The unified configuration.
service.yaml: Service for port 8090.
Dependencies:
Include a PostgreSQL chart (e.g., bitnami/postgresql) or assume external DB.
This approach gives you a fully functional Flyte v2 environment with a single pod (plus database).
