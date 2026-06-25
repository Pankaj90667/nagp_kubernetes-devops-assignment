#!/bin/bash

# Build and Push Docker Images Script
# This script builds the Spring Boot application and pushes to Docker Hub

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Docker Build and Push Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Configuration
DOCKER_USERNAME="${1:-pankaj90667}"  # Replace with your Docker Hub username
IMAGE_NAME="employee-service"
VERSION="${2:-1.0.0}"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
LATEST_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:latest"

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Docker Username: ${DOCKER_USERNAME}"
echo "  Image Name: ${IMAGE_NAME}"
echo "  Version: ${VERSION}"
echo "  Full Image: ${FULL_IMAGE_NAME}"

# Check if Docker is running
echo -e "\n${YELLOW}Checking Docker...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"

# Login to Docker Hub
echo -e "\n${YELLOW}Logging in to Docker Hub...${NC}"
echo "Please enter your Docker Hub password:"
docker login -u "${DOCKER_USERNAME}"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Docker login failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Logged in to Docker Hub${NC}"

# Build Docker image
echo -e "\n${YELLOW}Building Docker image...${NC}"
docker build -t "${FULL_IMAGE_NAME}" -t "${LATEST_IMAGE_NAME}" .

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Docker build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker image built successfully${NC}"

# Show image details
echo -e "\n${YELLOW}Image Details:${NC}"
docker images | grep "${IMAGE_NAME}"

# Push to Docker Hub
echo -e "\n${YELLOW}Pushing image to Docker Hub...${NC}"
docker push "${FULL_IMAGE_NAME}"
docker push "${LATEST_IMAGE_NAME}"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Docker push failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Image pushed successfully${NC}"

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Build and Push Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nDocker Hub URLs:"
echo "  ${FULL_IMAGE_NAME}"
echo "  ${LATEST_IMAGE_NAME}"
echo -e "\nYou can now deploy to Kubernetes using:"
echo "  kubectl apply -f k8s/"
echo -e "${GREEN}========================================${NC}"
