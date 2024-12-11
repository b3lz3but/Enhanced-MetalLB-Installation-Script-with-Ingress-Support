#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration variables
METALLB_VERSION="v0.14.8"
LOADBALANCER_IP="194.53.136.89"
METALLB_URL="https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
DOMAIN="example.com"  # Replace with your domain

# Function to check kubernetes cluster access
check_cluster() {
    echo -e "${BLUE}Checking Kubernetes cluster access...${NC}"
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"
}

# Function to check required tools
check_requirements() {
    echo -e "${BLUE}Checking required tools...${NC}"
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl is not installed${NC}"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is not installed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Required tools are installed${NC}"
}

# Function to clean existing MetalLB installation
clean_metallb() {
    echo -e "${BLUE}Checking for existing MetalLB installation...${NC}"
    
    # Clean up any existing test deployments first
    kubectl delete ingress nginx-ingress &> /dev/null
    kubectl delete service nginx &> /dev/null
    kubectl delete deployment nginx &> /dev/null
    
    # Check for namespace
    if kubectl get namespace metallb-system &> /dev/null; then
        echo -e "${YELLOW}Found existing metallb-system namespace${NC}"
        echo "Deleting existing MetalLB installation..."
        kubectl delete namespace metallb-system
        
        echo "Waiting for namespace deletion..."
        while kubectl get namespace metallb-system &> /dev/null; do
            echo -n "."
            sleep 1
        done
        echo -e "\n${GREEN}✓ Existing namespace deleted${NC}"
    fi

    # Clean up CRDs
    echo "Cleaning up MetalLB CRDs..."
    CRDS=(
        "ipaddresspools.metallb.io"
        "l2advertisements.metallb.io"
        "bfdprofiles.metallb.io"
        "bgpadvertisements.metallb.io"
        "bgppeers.metallb.io"
        "communities.metallb.io"
    )

    for CRD in "${CRDS[@]}"; do
        kubectl delete crd $CRD &> /dev/null
    done
    echo -e "${GREEN}✓ CRDs cleanup completed${NC}"
}

# Function to install MetalLB
install_metallb() {
    echo -e "\n${BLUE}Installing MetalLB ${METALLB_VERSION}...${NC}"
    
    if ! kubectl apply -f $METALLB_URL; then
        echo -e "${RED}Failed to install MetalLB${NC}"
        exit 1
    fi

    echo "Waiting for MetalLB pods to start..."
    sleep 15

    # Wait for pods to be ready with a more generous timeout
    kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=app=metallb \
        --timeout=120s || {
            echo -e "${RED}Timeout waiting for MetalLB pods${NC}"
            exit 1
        }
    echo -e "${GREEN}✓ MetalLB installation completed${NC}"
    
    # Show pod status
    echo -e "\n${YELLOW}MetalLB Pod Status:${NC}"
    kubectl get pods -n metallb-system
}

# Function to configure IP address pool
configure_ip_pool() {
    echo -e "\n${BLUE}Configuring MetalLB with IP: ${LOADBALANCER_IP}${NC}"
    
    # Wait for CRDs to be properly established
    sleep 10
    
    cat <<EOF | kubectl apply -f -
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - ${LOADBALANCER_IP}/32
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
  nodeSelectors:
  - matchLabels: {}
EOF

    # Wait for configuration to be applied
    sleep 5
    
    # Verify the configuration
    echo -e "\n${YELLOW}Verifying IP pool configuration:${NC}"
    kubectl get ipaddresspool -n metallb-system first-pool -o yaml
    kubectl get l2advertisement -n metallb-system l2advertisement -o yaml
    
    echo -e "${GREEN}✓ IP pool configuration completed${NC}"
}

# Function to deploy test application with Ingress
deploy_test_application() {
    echo -e "\n${BLUE}Deploying test application with Ingress...${NC}"
    
    # Deploy nginx
    echo "Creating nginx deployment..."
    kubectl create deployment nginx --image=nginx

    # Create ClusterIP service
    echo "Exposing nginx as ClusterIP service..."
    kubectl expose deployment nginx --port=80 --type=ClusterIP

    # Create Ingress resource
    echo "Creating Ingress resource..."
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  rules:
  - host: nginx.${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
  # Alternative path-based rule if no domain is available
  - http:
      paths:
      - path: /nginx
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF

    echo -e "${GREEN}✓ Test application deployment completed${NC}"
}

# Function to test the setup
test_setup() {
    echo -e "\n${BLUE}Testing the setup...${NC}"
    
    # Test 1: Verify all pods are running
    echo -e "\n${YELLOW}Test 1: Checking pod status${NC}"
    if ! kubectl get pods | grep -q "nginx.*Running"; then
        echo -e "${RED}✗ Nginx pod is not running properly${NC}"
        kubectl get pods
        return 1
    fi
    echo -e "${GREEN}✓ Nginx pod is running${NC}"
    
    # Test 2: Verify Ingress creation
    echo -e "\n${YELLOW}Test 2: Checking Ingress status${NC}"
    if ! kubectl get ingress nginx-ingress &> /dev/null; then
        echo -e "${RED}✗ Ingress not created properly${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Ingress created successfully${NC}"
    
    # Test 3: Show access information
    echo -e "\n${YELLOW}Access Information:${NC}"
    echo -e "Your application should be accessible at:"
    echo -e "Domain-based access: http://nginx.${DOMAIN}"
    echo -e "Path-based access: http://${LOADBALANCER_IP}/nginx"
    
    return 0
}

# Function to show debug information
show_debug_info() {
    echo -e "\n${YELLOW}Gathering debug information...${NC}"
    
    echo -e "\n${BLUE}MetalLB Pods:${NC}"
    kubectl get pods -n metallb-system -o wide
    
    echo -e "\n${BLUE}MetalLB Services:${NC}"
    kubectl get services -n metallb-system
    
    echo -e "\n${BLUE}IP Address Pools:${NC}"
    kubectl get ipaddresspools.metallb.io -n metallb-system
    
    echo -e "\n${BLUE}L2 Advertisements:${NC}"
    kubectl get l2advertisements.metallb.io -n metallb-system
    
    echo -e "\n${BLUE}Ingress Status:${NC}"
    kubectl describe ingress nginx-ingress
    
    echo -e "\n${BLUE}Controller Logs:${NC}"
    kubectl logs -n metallb-system -l component=controller --tail=30
    
    echo -e "\n${BLUE}Speaker Logs:${NC}"
    kubectl logs -n metallb-system -l component=speaker --tail=30
}

# Main execution
echo -e "${BLUE}Starting MetalLB ${METALLB_VERSION} Installation Process${NC}"
echo -e "${YELLOW}Using IP: ${LOADBALANCER_IP}${NC}\n"

# Run all installation and test steps
check_requirements || exit 1
check_cluster || exit 1
clean_metallb || exit 1
install_metallb || exit 1
configure_ip_pool || exit 1
deploy_test_application || exit 1

echo -e "\n${GREEN}Installation completed. Running tests...${NC}"

if test_setup; then
    echo -e "\n${GREEN}✓ All tests passed successfully! MetalLB and Ingress are working correctly.${NC}"
else
    echo -e "\n${RED}✗ Some tests failed. Gathering debug information...${NC}"
    show_debug_info
    exit 1
fi

echo -e "\n${GREEN}All operations completed successfully!${NC}"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Update your DNS records to point nginx.${DOMAIN} to ${LOADBALANCER_IP}"
echo "2. Or access the application directly via http://${LOADBALANCER_IP}/nginx"
echo -e "3. Monitor the application using: kubectl get pods,svc,ingress\n"