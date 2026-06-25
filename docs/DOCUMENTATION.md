# NAGP Kubernetes DevOps Assignment - Comprehensive Documentation

## Table of Contents
1. [Requirement Understanding](#requirement-understanding)
2. [Assumptions](#assumptions)
3. [Solution Overview](#solution-overview)
4. [Architecture](#architecture)
5. [Justification for Resources Utilized](#justification-for-resources-utilized)
6. [FinOps Considerations](#finops-considerations)

---

## 1. Requirement Understanding

### Objective
Design, containerize, and deploy a multi-tier architecture on Kubernetes with:
- **Service API Tier**: Microservice exposing REST API endpoints
- **Database Tier**: Persistent database with sample data

### Key Requirements

#### Service API Tier
- ✅ Exposes API endpoint to fetch data from database
- ✅ Built using Spring Boot (Java)
- ✅ Uses connection pooling and configuration separation
- ✅ Supports rolling updates
- ✅ Externally accessible via Ingress
- ✅ Demonstrates self-healing capabilities
- ✅ Implements Horizontal Pod Autoscaler (HPA)
- ✅ Runs 4 replicas

#### Database Tier
- ✅ MySQL 8.0 with 10 employee records
- ✅ Supports data persistence using PersistentVolumeClaim
- ✅ Accessible only within the cluster (ClusterIP)
- ✅ Automatically recovers after pod deletion
- ✅ Runs 1 replica

#### Kubernetes Features
- ✅ ConfigMap for database configuration
- ✅ Secrets for sensitive data (passwords)
- ✅ PersistentVolumeClaim for database storage
- ✅ Services for pod communication
- ✅ Ingress for external access
- ✅ HPA for autoscaling
- ✅ Resource requests and limits (FinOps)

---

## 2. Assumptions

### Technology Stack
- **Backend Framework**: Spring Boot 3.2.0 with Java 17
- **Database**: MySQL 8.0
- **Container Registry**: Docker Hub
- **Kubernetes Platform**: AWS EKS (Elastic Kubernetes Service)
- **Ingress Controller**: AWS Load Balancer Controller
- **Storage Class**: AWS EBS (gp2)

### Infrastructure Assumptions
1. AWS account with appropriate IAM permissions for EKS
2. AWS CLI and kubectl configured locally
3. Docker installed in WSL environment
4. eksctl or AWS Console access for cluster creation
5. Metrics Server installed for HPA functionality
6. AWS Load Balancer Controller installed for Ingress

### Application Assumptions
1. Database initialization happens automatically on first deployment
2. Application uses environment variables for configuration
3. Health checks available via Spring Boot Actuator
4. Connection pooling configured with HikariCP (default in Spring Boot)

### Cost Assumptions
1. Using t3.medium EC2 instances for worker nodes
2. EBS gp2 storage for database persistence
3. Application Load Balancer for external access
4. Development/testing environment (not production-grade HA)

---

## 3. Solution Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  AWS Application Load Balancer              │
│                    (Created by Ingress)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (EKS)                  │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              Ingress Controller                     │    │
│  │         (AWS Load Balancer Controller)              │    │
│  └──────────────────────┬─────────────────────────────┘    │
│                         │                                    │
│                         ▼                                    │
│  ┌────────────────────────────────────────────────────┐    │
│  │         employee-api-service (ClusterIP)            │    │
│  └──────────────────────┬─────────────────────────────┘    │
│                         │                                    │
│         ┌───────────────┼───────────────┬─────────┐        │
│         ▼               ▼               ▼         ▼        │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────┐   │
│  │ API Pod 1│   │ API Pod 2│   │ API Pod 3│   │Pod 4 │   │
│  │          │   │          │   │          │   │      │   │
│  │ Spring   │   │ Spring   │   │ Spring   │   │Spring│   │
│  │ Boot     │   │ Boot     │   │ Boot     │   │Boot  │   │
│  └────┬─────┘   └────┬─────┘   └────┬─────┘   └──┬───┘   │
│       │              │              │             │        │
│       └──────────────┼──────────────┼─────────────┘        │
│                      │              │                       │
│                      ▼              │                       │
│         ┌────────────────────────┐  │                      │
│         │  mysql-service         │  │                      │
│         │    (ClusterIP)         │  │                      │
│         └──────────┬─────────────┘  │                      │
│                    │                │                       │
│                    ▼                │                       │
│         ┌────────────────────────┐  │                      │
│         │    MySQL Pod           │  │                      │
│         │                        │  │                      │
│         │  ┌──────────────────┐ │  │                      │
│         │  │  MySQL 8.0       │ │  │                      │
│         │  └──────────────────┘ │  │                      │
│         │           │            │  │                      │
│         │           ▼            │  │                      │
│         │  ┌──────────────────┐ │  │                      │
│         │  │ Persistent Volume│ │  │                      │
│         │  │   (AWS EBS)      │ │  │                      │
│         │  └──────────────────┘ │  │                      │
│         └────────────────────────┘  │                      │
│                                     │                       │
│  ┌──────────────────────────────────┼─────────────────┐   │
│  │         HPA (Autoscaler)         │                 │   │
│  │  Monitors CPU/Memory ────────────┘                 │   │
│  │  Scales API Pods (4-10 replicas)                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         ConfigMaps & Secrets                        │   │
│  │  - api-config (DB connection details)               │   │
│  │  - api-secret (DB password)                         │   │
│  │  - mysql-secret (MySQL root password)               │   │
│  │  - mysql-initdb-config (Initialization SQL)         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Component Description

#### 1. **Service API Tier (Employee Service)**
- **Technology**: Spring Boot 3.2.0, Java 17
- **Functionality**: REST API to manage employee data
- **Endpoints**:
  - `GET /api/employees` - Fetch all employees
  - `GET /api/employees/{id}` - Fetch employee by ID
  - `GET /api/health` - Health check endpoint
  - `GET /actuator/health` - Spring Boot actuator health
- **Replicas**: 4 (can scale to 10 with HPA)
- **Resource Allocation**:
  - Requests: 250m CPU, 512Mi Memory
  - Limits: 500m CPU, 1Gi Memory

#### 2. **Database Tier (MySQL)**
- **Technology**: MySQL 8.0
- **Data**: 10 employee records pre-populated
- **Storage**: 5Gi persistent volume (AWS EBS)
- **Replicas**: 1 (single instance)
- **Resource Allocation**:
  - Requests: 250m CPU, 512Mi Memory
  - Limits: 500m CPU, 1Gi Memory

#### 3. **Kubernetes Resources**

**ConfigMaps**:
- `api-config`: Database connection parameters (host, port, database name, username)
- `mysql-initdb-config`: SQL initialization script

**Secrets**:
- `api-secret`: Database password for API tier
- `mysql-secret`: MySQL root password and database name

**Services**:
- `employee-api-service`: ClusterIP service for API pods (port 80 → 8080)
- `mysql-service`: ClusterIP service for MySQL (port 3306)

**Storage**:
- `mysql-pvc`: PersistentVolumeClaim (5Gi, ReadWriteOnce, gp2 storage class)

**Ingress**:
- `employee-api-ingress`: AWS ALB Ingress for external access

**Autoscaling**:
- `employee-api-hpa`: HPA with CPU (70%) and Memory (80%) thresholds

---

## 4. Architecture

### Data Flow

1. **External Request** → User sends HTTP request to ALB DNS
2. **Load Balancer** → AWS ALB routes to Ingress Controller
3. **Ingress** → Routes to employee-api-service
4. **Service** → Load balances across 4 API pods
5. **API Pod** → Processes request, queries database
6. **Database Service** → Routes to MySQL pod
7. **MySQL Pod** → Fetches data from persistent volume
8. **Response** → Data flows back through the chain

### Self-Healing Mechanism

**API Tier**:
- Kubernetes monitors pod health via liveness/readiness probes
- If pod fails, Deployment controller creates new pod automatically
- Service automatically routes traffic away from unhealthy pods

**Database Tier**:
- Liveness probe checks MySQL availability
- If pod crashes, Deployment recreates it
- PersistentVolume ensures data survives pod restarts

### Rolling Update Strategy

**API Tier**:
- Strategy: RollingUpdate
- MaxSurge: 1 (one extra pod during update)
- MaxUnavailable: 1 (one pod can be down during update)
- Process: New pods created → become ready → old pods terminated

**Database Tier**:
- Strategy: Recreate (appropriate for stateful apps)
- Old pod terminated before new pod starts

### Autoscaling Behavior

**Scale Up**:
- Triggers: CPU > 70% OR Memory > 80%
- Action: Add up to 2 pods or 100% increase (whichever is higher)
- Delay: Immediate (0 seconds stabilization)

**Scale Down**:
- Triggers: CPU < 70% AND Memory < 80%
- Action: Remove up to 50% of pods
- Delay: 5 minutes stabilization window

---

## 5. Justification for Resources Utilized

### Kubernetes Resources

#### 1. **Deployment** (2 instances)
**Why**: 
- Manages desired state for pods
- Provides declarative updates
- Enables rolling updates and rollbacks
- Ensures specified number of replicas are running

**API Deployment**: 4 replicas for high availability and load distribution
**MySQL Deployment**: 1 replica (single instance sufficient for demo)

#### 2. **Service** (2 instances)
**Why**:
- Provides stable network endpoint for pods
- Load balances traffic across pod replicas
- Enables service discovery within cluster

**employee-api-service**: ClusterIP for internal communication, exposed via Ingress
**mysql-service**: ClusterIP for internal-only database access

#### 3. **ConfigMap** (2 instances)
**Why**:
- Separates configuration from application code
- Allows configuration changes without rebuilding images
- Follows 12-factor app principles

**api-config**: Database connection parameters
**mysql-initdb-config**: Database initialization SQL script

#### 4. **Secret** (2 instances)
**Why**:
- Stores sensitive data securely
- Base64 encoded (can be encrypted at rest with KMS)
- Not visible in pod definitions or logs

**api-secret**: Database password for application
**mysql-secret**: MySQL root password

#### 5. **PersistentVolumeClaim**
**Why**:
- Ensures data persistence across pod restarts
- Decouples storage from pod lifecycle
- Uses AWS EBS for reliable storage

**mysql-pvc**: 5Gi storage for MySQL data directory

#### 6. **Ingress**
**Why**:
- Provides external access to services
- Single entry point for HTTP traffic
- Integrates with AWS ALB for load balancing
- Supports path-based routing and SSL termination

**employee-api-ingress**: Exposes API to internet via AWS ALB

#### 7. **HorizontalPodAutoscaler**
**Why**:
- Automatically scales pods based on metrics
- Optimizes resource utilization
- Handles traffic spikes automatically
- Reduces costs during low traffic

**employee-api-hpa**: Scales API pods from 4 to 10 based on CPU/Memory

### Resource Requests and Limits

#### API Tier
```yaml
requests:
  cpu: 250m      # Guaranteed CPU
  memory: 512Mi  # Guaranteed memory
limits:
  cpu: 500m      # Maximum CPU
  memory: 1Gi    # Maximum memory
```

**Justification**:
- **Requests**: Ensures minimum resources for stable operation
- **Limits**: Prevents resource hogging and ensures fair sharing
- **Ratio**: 2:1 limit-to-request ratio allows burst capacity
- **Spring Boot**: Typical Spring Boot app needs 512Mi-1Gi memory

#### Database Tier
```yaml
requests:
  cpu: 250m
  memory: 512Mi
limits:
  cpu: 500m
  memory: 1Gi
```

**Justification**:
- **MySQL**: Moderate resources sufficient for demo workload
- **Buffer**: Allows for query processing and caching
- **Persistence**: Prevents OOM kills that could corrupt data

### Probes Configuration

#### Liveness Probe
- **Purpose**: Detects if container is alive
- **Action**: Restarts container if fails
- **API**: HTTP GET /actuator/health
- **MySQL**: mysqladmin ping

#### Readiness Probe
- **Purpose**: Detects if container is ready to serve traffic
- **Action**: Removes from service endpoints if fails
- **Timing**: Faster than liveness to quickly detect issues

---

## 6. FinOps Considerations

### Current Resource Allocation

#### Per-Pod Resources
| Component | Pods | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|------|-------------|-----------|----------------|--------------|
| API       | 4    | 250m        | 500m      | 512Mi          | 1Gi          |
| MySQL     | 1    | 250m        | 500m      | 512Mi          | 1Gi          |
| **Total** | **5**| **1.25 CPU**| **2.5 CPU**| **2.5Gi**     | **5Gi**      |

### Cost Optimization Opportunities

#### 1. **Right-Sizing Resources** ⭐ IMPLEMENTED
**Current State**: Resource requests and limits defined based on expected load

**Optimization**:
- Monitor actual CPU/Memory usage using Kubernetes metrics
- Adjust requests/limits based on observed patterns
- Use Vertical Pod Autoscaler (VPA) for automatic recommendations

**Implementation**:
```bash
# Monitor resource usage
kubectl top pods
kubectl top nodes

# Analyze over 7 days and adjust
# Example: If API pods use only 150m CPU, reduce request to 200m
```

**Expected Savings**: 20-30% reduction in resource allocation

#### 2. **Horizontal Pod Autoscaler Optimization** ⭐ IMPLEMENTED
**Current State**: HPA configured with CPU (70%) and Memory (80%) thresholds

**Optimization**:
- Fine-tune thresholds based on actual traffic patterns
- Implement custom metrics (requests per second, response time)
- Adjust min/max replicas based on traffic analysis

**Implementation**:
```yaml
# Current: minReplicas: 4, maxReplicas: 10
# Optimized: minReplicas: 2, maxReplicas: 8 (during low traffic hours)
```

**Expected Savings**: 25-40% during off-peak hours

#### 3. **Cluster Autoscaler** ⭐ RECOMMENDED
**Current State**: Fixed number of worker nodes

**Optimization**:
- Enable Cluster Autoscaler to add/remove nodes based on demand
- Scale down nodes during low traffic periods
- Use node affinity to pack pods efficiently

**Implementation**:
```bash
# Install Cluster Autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Configure min/max nodes
eksctl scale nodegroup --cluster=nagp-k8s-cluster --nodes-min=1 --nodes-max=4 --name=standard-workers
```

**Expected Savings**: 30-50% on compute costs

#### 4. **Spot Instances for Worker Nodes** ⭐ RECOMMENDED
**Current State**: On-demand EC2 instances

**Optimization**:
- Use EC2 Spot Instances for worker nodes (up to 90% discount)
- Mix of on-demand and spot for reliability
- Use Spot Instance interruption handling

**Implementation**:
```bash
# Create mixed node group
eksctl create nodegroup \
  --cluster=nagp-k8s-cluster \
  --name=spot-workers \
  --node-type=t3.medium \
  --nodes=2 \
  --nodes-min=1 \
  --nodes-max=4 \
  --spot
```

**Expected Savings**: 60-70% on compute costs

#### 5. **Storage Optimization** ⭐ RECOMMENDED
**Current State**: gp2 EBS volumes (5Gi for MySQL)

**Optimization**:
- Use gp3 instead of gp2 (20% cheaper, better performance)
- Right-size PVC based on actual data growth
- Implement backup/restore instead of over-provisioning

**Implementation**:
```yaml
# Change storageClassName from gp2 to gp3
storageClassName: gp3
```

**Expected Savings**: 20% on storage costs

#### 6. **Load Balancer Optimization** ⭐ RECOMMENDED
**Current State**: Application Load Balancer per Ingress

**Optimization**:
- Share single ALB across multiple services using IngressGroup
- Use NLB instead of ALB if Layer 7 features not needed
- Delete unused load balancers

**Implementation**:
```yaml
annotations:
  alb.ingress.kubernetes.io/group.name: shared-alb
```

**Expected Savings**: 50-70% on load balancer costs

#### 7. **Resource Quotas and Limit Ranges** ⭐ RECOMMENDED
**Current State**: No namespace-level limits

**Optimization**:
- Implement ResourceQuota to prevent over-provisioning
- Set LimitRange for default resource limits
- Prevent runaway pods from consuming excessive resources

**Implementation**:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
```

**Expected Savings**: Prevents cost overruns

#### 8. **Idle Resource Cleanup** ⭐ RECOMMENDED
**Current State**: Resources run 24/7

**Optimization**:
- Schedule cluster shutdown during non-business hours (dev/test)
- Use CronJobs to scale down deployments at night
- Delete unused PVCs and snapshots

**Implementation**:
```bash
# Scale down at night (example)
kubectl scale deployment employee-api --replicas=1
kubectl scale deployment mysql --replicas=0  # For dev only!
```

**Expected Savings**: 50-60% for dev/test environments

### Implemented Optimizations Summary

| Optimization | Status | Expected Savings | Priority |
|--------------|--------|------------------|----------|
| Resource Requests/Limits | ✅ Implemented | 20-30% | High |
| HPA Configuration | ✅ Implemented | 25-40% | High |
| Cluster Autoscaler | 📋 Recommended | 30-50% | High |
| Spot Instances | 📋 Recommended | 60-70% | High |
| Storage Optimization (gp3) | 📋 Recommended | 20% | Medium |
| Shared ALB | 📋 Recommended | 50-70% | Medium |
| Resource Quotas | 📋 Recommended | Prevents overruns | Medium |
| Idle Resource Cleanup | 📋 Recommended | 50-60% | Low |

### Monitoring and Continuous Optimization

**Tools to Use**:
1. **Kubernetes Metrics Server**: Real-time resource usage
2. **AWS Cost Explorer**: Track spending trends
3. **Kubecost**: Kubernetes-specific cost analysis
4. **Prometheus + Grafana**: Detailed metrics and dashboards

**Best Practices**:
- Review resource usage weekly
- Adjust HPA thresholds based on traffic patterns
- Implement tagging for cost allocation
- Set up billing alerts
- Regular cleanup of unused resources

---

## Conclusion

This solution demonstrates a production-ready, cost-optimized Kubernetes deployment with:
- ✅ High availability (4 API replicas)
- ✅ Self-healing capabilities
- ✅ Data persistence
- ✅ Autoscaling (HPA)
- ✅ Security (Secrets, non-root containers)
- ✅ Observability (health checks, metrics)
- ✅ Cost optimization (resource limits, HPA, recommendations)

The architecture follows Kubernetes best practices and cloud-native principles while maintaining cost efficiency through proper resource management and optimization strategies.
