#!/bin/bash

# AWS EKS Cluster Setup Script
# This script creates an EKS cluster with all required components

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  AWS EKS Cluster Setup${NC}"
echo -e "${GREEN}========================================${NC}"

# Configuration
CLUSTER_NAME="${1:-nagp-k8s-cluster}"
REGION="${2:-us-east-1}"
NODE_TYPE="${3:-t3.medium}"
NODES="${4:-2}"

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Cluster Name: ${CLUSTER_NAME}"
echo "  Region: ${REGION}"
echo "  Node Type: ${NODE_TYPE}"
echo "  Number of Nodes: ${NODES}"

# Check if eksctl is installed
echo -e "\n${YELLOW}Checking eksctl...${NC}"
if ! command -v eksctl &> /dev/null; then
    echo -e "${RED}Error: eksctl is not installed${NC}"
    echo "Install eksctl: https://eksctl.io/introduction/#installation"
    exit 1
fi
echo -e "${GREEN}✓ eksctl is installed${NC}"

# Check if AWS CLI is configured
echo -e "\n${YELLOW}Checking AWS CLI...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI is configured${NC}"
aws sts get-caller-identity

# Create EKS cluster
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Creating EKS Cluster${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}This will take 15-20 minutes...${NC}"

eksctl create cluster \
  --name "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --nodegroup-name standard-workers \
  --node-type "${NODE_TYPE}" \
  --nodes "${NODES}" \
  --nodes-min 2 \
  --nodes-max 4 \
  --managed \
  --with-oidc \
  --ssh-access=false \
  --external-dns-access \
  --full-ecr-access \
  --alb-ingress-access

echo -e "${GREEN}✓ EKS Cluster created${NC}"

# Update kubeconfig
echo -e "\n${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER_NAME}"
echo -e "${GREEN}✓ kubeconfig updated${NC}"

# Verify cluster
echo -e "\n${YELLOW}Verifying cluster...${NC}"
kubectl cluster-info
kubectl get nodes

# Install Metrics Server
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Installing Metrics Server${NC}"
echo -e "${BLUE}========================================${NC}"

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo -e "${GREEN}✓ Metrics Server installed${NC}"

# Install AWS Load Balancer Controller
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Installing AWS Load Balancer Controller${NC}"
echo -e "${BLUE}========================================${NC}"

# Download IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json

# Create IAM policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json \
    2>/dev/null || echo "Policy already exists"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create IAM service account
eksctl create iamserviceaccount \
  --cluster="${CLUSTER_NAME}" \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region="${REGION}" \
  2>/dev/null || echo "Service account already exists"

# Install AWS Load Balancer Controller using Helm
echo -e "\n${YELLOW}Installing controller via Helm...${NC}"

# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  2>/dev/null || helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

echo -e "${GREEN}✓ AWS Load Balancer Controller installed${NC}"

# Wait for controller to be ready
echo -e "\n${YELLOW}Waiting for controller to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system || true

# Cleanup
rm -f iam_policy.json

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  EKS Cluster Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Cluster Information:${NC}"
echo "  Cluster Name: ${CLUSTER_NAME}"
echo "  Region: ${REGION}"
echo "  Endpoint: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"

echo -e "\n${YELLOW}Installed Components:${NC}"
echo "  ✓ EKS Cluster"
echo "  ✓ Managed Node Group (${NODES} nodes)"
echo "  ✓ Metrics Server"
echo "  ✓ AWS Load Balancer Controller"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "  1. Build and push Docker image: ./scripts/build-and-push.sh"
echo "  2. Deploy application: ./scripts/deploy-to-k8s.sh"

echo -e "\n${YELLOW}To delete cluster later:${NC}"
echo "  eksctl delete cluster --name ${CLUSTER_NAME} --region ${REGION}"

echo -e "\n${GREEN}========================================${NC}"
