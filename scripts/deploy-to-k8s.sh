#!/bin/bash

# Deploy to Kubernetes Script
# This script deploys all Kubernetes resources in the correct order

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Kubernetes Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if kubectl is installed
echo -e "\n${YELLOW}Checking kubectl...${NC}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl is installed${NC}"

# Check cluster connection
echo -e "\n${YELLOW}Checking cluster connection...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    echo "Please configure kubectl to connect to your cluster"
    exit 1
fi
echo -e "${GREEN}✓ Connected to cluster${NC}"
kubectl cluster-info

# Deploy in order
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 1: Deploy Secrets${NC}"
echo -e "${BLUE}========================================${NC}"
kubectl apply -f k8s/database/mysql-secret.yaml
kubectl apply -f k8s/api/api-secret.yaml
echo -e "${GREEN}✓ Secrets created${NC}"

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 2: Deploy ConfigMaps${NC}"
echo -e "${BLUE}========================================${NC}"
kubectl apply -f k8s/database/mysql-configmap.yaml
kubectl apply -f k8s/api/api-configmap.yaml
echo -e "${GREEN}✓ ConfigMaps created${NC}"

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 3: Deploy PersistentVolumeClaim${NC}"
echo -e "${BLUE}========================================${NC}"
kubectl apply -f k8s/database/mysql-pvc.yaml
echo -e "${GREEN}✓ PVC created${NC}"

echo -e "\n${YELLOW}Waiting for PVC to be bound...${NC}"
kubectl wait --for=condition=Bound pvc/mysql-pvc --timeout=120s || true
kubectl get pvc mysql-pvc

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 4: Deploy Database${NC}"
echo -e "${BLUE}========================================${NC}"
kubectl apply -f k8s/database/mysql-deployment.yaml
kubectl apply -f k8s/database/mysql-service.yaml
echo -e "${GREEN}✓ MySQL deployment and service created${NC}"

echo -e "\n${YELLOW}Waiting for MySQL to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/mysql || true
kubectl get pods -l app=mysql

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 5: Deploy API Service${NC}"
echo -e "${BLUE}========================================${NC}"
kubectl apply -f k8s/api/api-deployment.yaml
kubectl apply -f k8s/api/api-service.yaml
echo -e "${GREEN}✓ API deployment and service created${NC}"

echo -e "\n${YELLOW}Waiting for API pods to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/employee-api || true
kubectl get pods -l app=employee-api

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 6: Deploy HPA${NC}"
echo -e "${BLUE}========================================${NC}"
kubectl apply -f k8s/api/api-hpa.yaml
echo -e "${GREEN}✓ HPA created${NC}"

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 7: Deploy Ingress${NC}"
echo -e "${BLUE}========================================${NC}"
kubectl apply -f k8s/ingress/api-ingress.yaml
echo -e "${GREEN}✓ Ingress created${NC}"

# Show deployment status
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Deployment Status:${NC}"
echo -e "\n${BLUE}Pods:${NC}"
kubectl get pods

echo -e "\n${BLUE}Services:${NC}"
kubectl get services

echo -e "\n${BLUE}Deployments:${NC}"
kubectl get deployments

echo -e "\n${BLUE}PVC:${NC}"
kubectl get pvc

echo -e "\n${BLUE}HPA:${NC}"
kubectl get hpa

echo -e "\n${BLUE}Ingress:${NC}"
kubectl get ingress

echo -e "\n${YELLOW}Waiting for Ingress to get external address...${NC}"
echo "This may take 2-3 minutes..."
sleep 10

INGRESS_ADDRESS=""
for i in {1..30}; do
    INGRESS_ADDRESS=$(kubectl get ingress employee-api-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$INGRESS_ADDRESS" ]; then
        break
    fi
    echo -n "."
    sleep 10
done

echo ""
if [ -n "$INGRESS_ADDRESS" ]; then
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}  Access Your Application${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "\nAPI Endpoint: ${GREEN}http://${INGRESS_ADDRESS}${NC}"
    echo -e "\nTest endpoints:"
    echo "  curl http://${INGRESS_ADDRESS}/api/employees"
    echo "  curl http://${INGRESS_ADDRESS}/api/health"
    echo "  curl http://${INGRESS_ADDRESS}/actuator/health"
else
    echo -e "\n${YELLOW}Ingress address not yet available. Check later with:${NC}"
    echo "  kubectl get ingress employee-api-ingress"
fi

echo -e "\n${GREEN}========================================${NC}"
