# NAGP Kubernetes DevOps Assignment

## 🎯 Project Overview

This project demonstrates a **production-ready multi-tier application** deployed on **AWS EKS (Elastic Kubernetes Service)** with complete DevOps and FinOps best practices.

### Architecture
- **Service API Tier**: Spring Boot REST API (4 replicas with autoscaling)
- **Database Tier**: MySQL 8.0 with persistent storage
- **Infrastructure**: AWS EKS with Application Load Balancer

---

## 📦 Repository Information

- **GitHub Repository**: https://github.com/Pankaj90667/nagp_kubernetes-devops-assignment
- **Docker Hub Images**: 
  - `goyalpankaj/nagp-kubernetes-devops-assignment:v1`

---

## 🚀 Quick Start Guide

### Prerequisites

Before starting, ensure you have:

1. **AWS Account** with appropriate IAM permissions
2. **AWS CLI** configured (`aws configure`)
3. **Docker** installed and running (in WSL)
4. **kubectl** installed
5. **eksctl** installed (for EKS cluster creation)
6. **Helm** installed (for AWS Load Balancer Controller)
7. **Docker Hub account**

### Installation Steps

#### Step 1: Clone the Repository

```bash
git clone https://github.com/Pankaj90667/nagp_kubernetes-devops-assignment.git
cd nagp_kubernetes-devops-assignment
```

#### Step 2: Setup AWS EKS Cluster (15-20 minutes)

```bash
# Make script executable
chmod +x scripts/setup-eks-cluster.sh

# Create EKS cluster
./scripts/setup-eks-cluster.sh nagp-k8s-cluster us-east-1 t3.medium 2
```

This script will:
- Create EKS cluster with 2 worker nodes
- Install Metrics Server (for HPA)
- Install AWS Load Balancer Controller (for Ingress)
- Configure kubectl

#### Step 3: Build and Push Docker Image (5-10 minutes)

```bash
# Make script executable
chmod +x scripts/build-and-push.sh

# Build and push (replace with your Docker Hub username)
./scripts/build-and-push.sh YOUR_DOCKERHUB_USERNAME 1.0.0
```

**Important**: Update the image name in `k8s/api/api-deployment.yaml` with your Docker Hub username:
```yaml
image: YOUR_DOCKERHUB_USERNAME/employee-service:1.0.0
```

#### Step 4: Deploy to Kubernetes (5-10 minutes)

```bash
# Make script executable
chmod +x scripts/deploy-to-k8s.sh

# Deploy all resources
./scripts/deploy-to-k8s.sh
```

This script will deploy in order:
1. Secrets
2. ConfigMaps
3. PersistentVolumeClaim
4. MySQL Database
5. API Service
6. HPA
7. Ingress

#### Step 5: Access the Application

Wait for the Ingress to get an external address (2-3 minutes):

```bash
kubectl get ingress employee-api-ingress
```

Once you have the ALB DNS name, test the API:

```bash
# Get all employees
curl http://<ALB-DNS>/api/employees

# Get health status
curl http://<ALB-DNS>/api/health

# Spring Boot actuator health
curl http://<ALB-DNS>/actuator/health
```

---

## 🔗 API Endpoints

Once deployed, access these endpoints via the Ingress URL:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/employees` | GET | Fetch all employees from database |
| `/api/employees/{id}` | GET | Fetch employee by ID |
| `/api/health` | GET | Custom health check |
| `/actuator/health` | GET | Spring Boot actuator health |

### Sample Response

```json
{
  "status": "success",
  "message": "Employees fetched successfully from database",
  "count": 10,
  "podName": "employee-api-7d8f9c5b6d-xyz12",
  "data": [
    {
      "id": 1,
      "firstName": "Rajesh",
      "lastName": "Kumar",
      "email": "rajesh.kumar@nagp.com",
      "department": "Engineering",
      "salary": 95000.0
    }
  ]
}
```

---

## 📊 Kubernetes Resources

### Deployed Resources

```bash
# View all resources
kubectl get all

# View specific resources
kubectl get pods
kubectl get services
kubectl get deployments
kubectl get pvc
kubectl get hpa
kubectl get ingress
kubectl get configmaps
kubectl get secrets
```

### Resource Summary

| Resource Type | Name | Purpose |
|---------------|------|---------|
| Deployment | employee-api | API service (4 replicas) |
| Deployment | mysql | Database (1 replica) |
| Service | employee-api-service | ClusterIP for API |
| Service | mysql-service | ClusterIP for MySQL |
| ConfigMap | api-config | Database connection config |
| ConfigMap | mysql-initdb-config | Database initialization SQL |
| Secret | api-secret | Database password for API |
| Secret | mysql-secret | MySQL root password |
| PVC | mysql-pvc | Persistent storage (5Gi) |
| Ingress | employee-api-ingress | External access via ALB |
| HPA | employee-api-hpa | Autoscaling (4-10 replicas) |

---

## ✅ Testing Requirements

### 1. Self-Healing - API Tier

```bash
# Delete an API pod
kubectl delete pod -l app=employee-api --force --grace-period=0 | head -1

# Watch pods regenerate
kubectl get pods -l app=employee-api -w

# Verify service continues to work
curl http://<ALB-DNS>/api/employees
```

**Expected**: Pod automatically recreates, service remains available.

### 2. Self-Healing - Database Tier

```bash
# Delete MySQL pod
kubectl delete pod -l app=mysql --force --grace-period=0

# Watch pod regenerate
kubectl get pods -l app=mysql -w

# Verify data persists
curl http://<ALB-DNS>/api/employees
```

**Expected**: Pod recreates, data remains intact (10 employees).

### 3. Rolling Updates

```bash
# Update image version
kubectl set image deployment/employee-api employee-api=pankaj90667/employee-service:1.0.1

# Watch rolling update
kubectl rollout status deployment/employee-api

# View rollout history
kubectl rollout history deployment/employee-api
```

**Expected**: Pods update one at a time, zero downtime.

### 4. Horizontal Pod Autoscaler (HPA)

```bash
# Check HPA status
kubectl get hpa employee-api-hpa

# Generate load (install Apache Bench)
ab -n 10000 -c 100 http://<ALB-DNS>/api/employees

# Watch HPA scale up
kubectl get hpa employee-api-hpa -w

# Watch pods scale
kubectl get pods -l app=employee-api -w
```

**Expected**: Pods scale from 4 to max 10 based on CPU/Memory usage.

### 5. Data Persistence

```bash
# Check PVC status
kubectl get pvc mysql-pvc

# Verify data exists
curl http://<ALB-DNS>/api/employees | jq '.count'

# Delete and recreate MySQL pod
kubectl delete pod -l app=mysql --force --grace-period=0
kubectl get pods -l app=mysql -w

# Verify data still exists
curl http://<ALB-DNS>/api/employees | jq '.count'
```

**Expected**: Data persists across pod restarts (count = 10).

---

## 💰 FinOps Implementation

### Implemented Optimizations

1. **Resource Requests & Limits** ✅
   - CPU: 250m request, 500m limit
   - Memory: 512Mi request, 1Gi limit
   - Prevents resource hogging

2. **Horizontal Pod Autoscaler** ✅
   - Min: 4 replicas, Max: 10 replicas
   - CPU threshold: 70%
   - Memory threshold: 80%
   - Scales based on demand

3. **Efficient Container Images** ✅
   - Multi-stage Docker build
   - Alpine-based runtime (smaller size)
   - Non-root user for security

### Cost Optimization Opportunities

| Optimization | Status | Expected Savings |
|--------------|--------|------------------|
| Resource Right-Sizing | ✅ Implemented | 20-30% |
| HPA Configuration | ✅ Implemented | 25-40% |
| Cluster Autoscaler | 📋 Recommended | 30-50% |
| Spot Instances | 📋 Recommended | 60-70% |
| Storage Optimization (gp3) | 📋 Recommended | 20% |

**See [DOCUMENTATION.md](docs/DOCUMENTATION.md) for detailed FinOps analysis.**

---

## 📹 Demonstration Video

**Video Link**: [To be added after recording]

### Video Contents:
1. ✅ All Kubernetes objects deployed and running
2. ✅ API call retrieving records from database
3. ✅ Self-healing: API pod deletion and regeneration
4. ✅ Self-healing: Database pod deletion with data persistence
5. ✅ Rolling update demonstration
6. ✅ HPA scaling demonstration
7. ✅ FinOps resource monitoring

---

## 📚 Documentation

- **[Comprehensive Documentation](docs/DOCUMENTATION.md)**: Detailed architecture, justifications, and FinOps analysis
- **[Kubernetes Manifests](k8s/)**: All YAML files for deployment
- **[Deployment Scripts](scripts/)**: Automated setup and deployment scripts

---

## 🛠️ Useful Commands

### Monitoring

```bash
# View logs
kubectl logs -f deployment/employee-api
kubectl logs -f deployment/mysql

# Resource usage
kubectl top nodes
kubectl top pods

# Describe resources
kubectl describe deployment employee-api
kubectl describe hpa employee-api-hpa
kubectl describe ingress employee-api-ingress
```

### Troubleshooting

```bash
# Check pod status
kubectl get pods -o wide

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check service endpoints
kubectl get endpoints

# Port forward for local testing
kubectl port-forward svc/employee-api-service 8080:80
```

### Cleanup

```bash
# Delete all resources
kubectl delete -f k8s/ingress/
kubectl delete -f k8s/api/
kubectl delete -f k8s/database/

# Delete EKS cluster
eksctl delete cluster --name nagp-k8s-cluster --region us-east-1
```

---

## 📁 Project Structure

```
nagp_kubernetes-devops-assignment/
├── src/                              # Spring Boot source code
│   └── main/
│       ├── java/com/nagp/employee/
│       │   ├── EmployeeServiceApplication.java
│       │   ├── controller/
│       │   │   └── EmployeeController.java
│       │   ├── model/
│       │   │   └── Employee.java
│       │   └── repository/
│       │       └── EmployeeRepository.java
│       └── resources/
│           └── application.properties
├── k8s/                              # Kubernetes manifests
│   ├── database/
│   │   ├── mysql-secret.yaml
│   │   ├── mysql-configmap.yaml
│   │   ├── mysql-pvc.yaml
│   │   ├── mysql-deployment.yaml
│   │   └── mysql-service.yaml
│   ├── api/
│   │   ├── api-secret.yaml
│   │   ├── api-configmap.yaml
│   │   ├── api-deployment.yaml
│   │   ├── api-service.yaml
│   │   └── api-hpa.yaml
│   └── ingress/
│       └── api-ingress.yaml
├── scripts/                          # Deployment scripts
│   ├── setup-eks-cluster.sh
│   ├── build-and-push.sh
│   └── deploy-to-k8s.sh
├── docker/
│   └── init.sql                      # Database initialization
├── docs/
│   └── DOCUMENTATION.md              # Comprehensive documentation
├── Dockerfile                        # Multi-stage Docker build
├── .dockerignore
├── pom.xml                           # Maven configuration
└── README.md                         # This file
```

---

## 🔐 Security Considerations

1. **Secrets Management**: Passwords stored in Kubernetes Secrets (base64 encoded)
2. **Non-Root Containers**: Application runs as non-root user
3. **Network Policies**: Database accessible only within cluster (ClusterIP)
4. **Resource Limits**: Prevents resource exhaustion attacks
5. **Health Checks**: Liveness and readiness probes configured

---

## 🎓 Key Features Demonstrated

- ✅ Multi-tier application architecture
- ✅ Containerization with Docker
- ✅ Kubernetes orchestration on AWS EKS
- ✅ ConfigMaps for configuration management
- ✅ Secrets for sensitive data
- ✅ Persistent storage with PVC
- ✅ Service discovery and load balancing
- ✅ External access via Ingress (ALB)
- ✅ Horizontal Pod Autoscaling (HPA)
- ✅ Rolling updates with zero downtime
- ✅ Self-healing capabilities
- ✅ Health checks and monitoring
- ✅ FinOps best practices
- ✅ Infrastructure as Code

---

## 📞 Support

For issues or questions:
1. Check the [DOCUMENTATION.md](docs/DOCUMENTATION.md)
2. Review Kubernetes events: `kubectl get events`
3. Check pod logs: `kubectl logs <pod-name>`

---

## 📝 Assignment Checklist

- [x] Spring Boot microservice with REST API
- [x] MySQL database with 10 sample records
- [x] Dockerfile with multi-stage build
- [x] Docker images pushed to Docker Hub
- [x] Kubernetes Deployments (API: 4 replicas, DB: 1 replica)
- [x] Kubernetes Services (ClusterIP)
- [x] ConfigMaps for configuration
- [x] Secrets for passwords
- [x] PersistentVolumeClaim for database
- [x] Ingress for external access
- [x] HPA for autoscaling
- [x] Rolling update strategy
- [x] Self-healing demonstration
- [x] Data persistence demonstration
- [x] Resource requests and limits (FinOps)
- [x] Cost optimization opportunities identified
- [x] Comprehensive documentation
- [x] README with all required information

---

## 🏆 Author

**Pankaj Goyal**  
NAGP 2026 - Technology Band III  
Workshop on Kubernetes, DevOps & FinOps

---

## 📄 License

This project is created for educational purposes as part of NAGP 2026 assignment.

---

**Note**: Remember to delete your EKS cluster after completing the assignment to avoid unnecessary AWS charges:

```bash
eksctl delete cluster --name nagp-k8s-cluster --region us-east-1
```
