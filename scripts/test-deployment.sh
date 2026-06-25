#!/bin/bash

# Test Deployment Script
# This script tests all assignment requirements

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Testing Kubernetes Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

# Get Ingress URL
INGRESS_URL=$(kubectl get ingress employee-api-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$INGRESS_URL" ]; then
    echo -e "${RED}Error: Ingress URL not found${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Ingress URL: ${GREEN}http://${INGRESS_URL}${NC}"

# Test 1: API Endpoint
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Test 1: API Endpoint${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Testing: GET /api/employees"
RESPONSE=$(curl -s "http://${INGRESS_URL}/api/employees")
COUNT=$(echo $RESPONSE | jq -r '.count' 2>/dev/null || echo "0")

if [ "$COUNT" == "10" ]; then
    echo -e "${GREEN}✓ PASSED: API returned 10 employees${NC}"
else
    echo -e "${RED}✗ FAILED: Expected 10 employees, got ${COUNT}${NC}"
fi

# Test 2: Self-Healing - API
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Test 2: Self-Healing (API Tier)${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Deleting one API pod..."
POD_NAME=$(kubectl get pods -l app=employee-api -o jsonpath='{.items[0].metadata.name}')
echo "Deleting pod: ${POD_NAME}"
kubectl delete pod ${POD_NAME} --force --grace-period=0

echo "Waiting for pod to regenerate..."
sleep 10
kubectl wait --for=condition=ready pod -l app=employee-api --timeout=120s

NEW_COUNT=$(kubectl get pods -l app=employee-api --no-headers | wc -l)
if [ "$NEW_COUNT" == "4" ]; then
    echo -e "${GREEN}✓ PASSED: Pod regenerated, 4 pods running${NC}"
else
    echo -e "${RED}✗ FAILED: Expected 4 pods, got ${NEW_COUNT}${NC}"
fi

# Test 3: Data Persistence
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Test 3: Data Persistence${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Testing API before MySQL pod deletion..."
BEFORE_COUNT=$(curl -s "http://${INGRESS_URL}/api/employees" | jq -r '.count' 2>/dev/null || echo "0")
echo "Records before: ${BEFORE_COUNT}"

echo "Deleting MySQL pod..."
MYSQL_POD=$(kubectl get pods -l app=mysql -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod ${MYSQL_POD} --force --grace-period=0

echo "Waiting for MySQL pod to regenerate..."
sleep 15
kubectl wait --for=condition=ready pod -l app=mysql --timeout=180s

echo "Testing API after MySQL pod deletion..."
sleep 10
AFTER_COUNT=$(curl -s "http://${INGRESS_URL}/api/employees" | jq -r '.count' 2>/dev/null || echo "0")
echo "Records after: ${AFTER_COUNT}"

if [ "$BEFORE_COUNT" == "$AFTER_COUNT" ] && [ "$AFTER_COUNT" == "10" ]; then
    echo -e "${GREEN}✓ PASSED: Data persisted across pod restart${NC}"
else
    echo -e "${RED}✗ FAILED: Data not persisted${NC}"
fi

# Test 4: HPA Status
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Test 4: HPA Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
kubectl get hpa employee-api-hpa

HPA_EXISTS=$(kubectl get hpa employee-api-hpa --no-headers 2>/dev/null | wc -l)
if [ "$HPA_EXISTS" == "1" ]; then
    echo -e "${GREEN}✓ PASSED: HPA is configured${NC}"
else
    echo -e "${RED}✗ FAILED: HPA not found${NC}"
fi

# Test 5: Resource Limits
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Test 5: Resource Limits (FinOps)${NC}"
echo -e "${BLUE}========================================${NC}"
API_LIMITS=$(kubectl get deployment employee-api -o jsonpath='{.spec.template.spec.containers[0].resources.limits}')
echo "API Resource Limits: ${API_LIMITS}"

if [[ "$API_LIMITS" == *"cpu"* ]] && [[ "$API_LIMITS" == *"memory"* ]]; then
    echo -e "${GREEN}✓ PASSED: Resource limits configured${NC}"
else
    echo -e "${RED}✗ FAILED: Resource limits not configured${NC}"
fi

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Test Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}All tests completed!${NC}"
echo -e "\nManual tests to perform:"
echo "  1. Rolling update: kubectl set image deployment/employee-api employee-api=pankaj90667/employee-service:1.0.1"
echo "  2. Load test for HPA: ab -n 10000 -c 100 http://${INGRESS_URL}/api/employees"
echo "  3. Monitor scaling: kubectl get hpa -w"

echo -e "\n${GREEN}========================================${NC}"
