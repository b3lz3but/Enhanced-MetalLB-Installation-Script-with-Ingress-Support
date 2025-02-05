#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration variables
METALLB_VERSION="${1:-v0.14.8}"
LOADBALANCER_IP="${2:-194.53.136.89}"
METALLB_URL="https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
DOMAIN="${3:-example.com}"  # Replace with your domain or pass as an argument
LOG_FILE="metallb_setup.log"

# Function to log messages
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Function to check Kubernetes cluster access
check_cluster() {
    log "${BLUE}Checking Kubernetes cluster access...${NC}"
    if ! kubectl cluster-info &> /dev/null; then
        log "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    log "${GREEN}✓ Kubernetes cluster is accessible${NC}"
}

# Function to check required tools
check_requirements() {
    log "${BLUE}Checking required tools...${NC}"
    
    if ! command -v kubectl &> /dev/null; then
        log "${RED}Error: kubectl is not installed${NC}"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log "${RED}Error: curl is not installed${NC}"
        exit 1
    fi
    
    log "${GREEN}✓ Required tools are installed${NC}"
}

# Function to clean existing MetalLB installation
clean_metallb() {
    log "${BLUE}Checking for existing MetalLB installation...${NC}"
    
    # Clean up any existing test deployments first
    kubectl delete ingress nginx-ingress &> /dev/null
    kubectl delete service nginx &> /dev/null
    kubectl delete deployment nginx &> /dev/null
    
    # Check for namespace
    if kubectl get namespace metallb-system &> /dev/null; then
        log "${YELLOW}Found existing metallb-system namespace${NC}"
        log "Deleting existing MetalLB installation..."
        kubectl delete namespace metallb-system
        
        log "Waiting for namespace deletion..."
        while kubectl get namespace metallb-system &> /dev/null; do
            log -n "."
            sleep 1
        done
        log "\n${GREEN}✓ Existing namespace deleted${NC}"
    fi

    # Clean up CRDs
    log "Cleaning up MetalLB CRDs..."
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
    log "${GREEN}✓ CRDs cleanup completed${NC}"
}

# Function to install MetalLB
install_metallb() {
    log "\n${BLUE}Installing MetalLB ${METALLB_VERSION}...${NC}"
    
    if ! kubectl apply -f $METALLB_URL; then
        log "${RED}Failed to install MetalLB${NC}"
        exit 1
    fi

    log "Waiting for MetalLB pods to start..."
    sleep 15

    # Wait for pods to be ready with a more generous timeout
    kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=app=metallb \
        --timeout=120s || {
            log "${RED}Timeout waiting for MetalLB pods${NC}"
            exit 1
        }
    log "${GREEN}✓ MetalLB installation completed${NC}"
    
    # Show pod status
    log "\n${YELLOW}MetalLB Pod Status:${NC}"
    kubectl get pods -n metallb-system
}

# Function to configure IP address pool
configure_ip_pool() {
    log "\n${BLUE}Configuring MetalLB with IP: ${LOADBALANCER_IP}${NC}"
    
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
    log "\n${YELLOW}Verifying IP pool configuration:${NC}"
    kubectl get ipaddresspool -n metallb-system first-pool -o yaml
    kubectl get l2advertisement -n metallb-system l2advertisement -o yaml
    
    log "${GREEN}✓ IP pool configuration completed${NC}"
}

# Function to deploy test application with Ingress
deploy_test_application() {
    log "\n${BLUE}Deploying test application with Ingress...${NC}"
    
    # Deploy nginx
    log "Creating nginx deployment..."
    kubectl create deployment nginx --image=nginx

    # Create ClusterIP service
    log "Exposing nginx as ClusterIP service..."
    kubectl expose deployment nginx --port=80 --type=ClusterIP

    # Create Ingress resource
    log "Creating Ingress resource..."
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

    log "${GREEN}✓ Test application deployment completed${NC}"
}

# Function to test the setup
test_setup() {
    log "\n${BLUE}Testing the setup...${NC}"
    
    # Test 1: Verify all pods are running
    log "\n${YELLOW}Test 1: Checking pod status${NC}"
    if ! kubectl get pods | grep -q "nginx.*Running"; then
        log "${RED}✗ Nginx pod is not running properly${NC}"
        kubectl get pods
        return 1
    fi
    log "${GREEN}✓ Nginx pod is running${NC}"
    
    # Test 2: Verify Ingress creation
    log "\n${YELLOW}Test 2: Checking Ingress status${NC}"
    if ! kubectl get ingress nginx-ingress &> /dev/null; then
        log "${RED}✗ Ingress not created properly${NC}"
        return 1
    fi
    log "${GREEN}✓ Ingress created successfully${NC}"
    
    # Test 3: Show access information
    log "\n${YELLOW}Access Information:${NC}"
    log "Your application should be accessible at:"
    log "Domain-based access: http://nginx.${DOMAIN}"
    log "Path-based access: http://${LOADBALANCER_IP}/nginx"
    
    return 0
}

# Function to show debug information
show_debug_info() {
    log "\n${YELLOW}Gathering debug information...${NC}"
    
    log "\n${BLUE}MetalLB Pods:${NC}"
    kubectl get pods -n metallb-system -o wide
    
    log "\n${BLUE}MetalLB Services:${NC}"
    kubectl get services -n metallb-system
    
    log "\n${BLUE}IP Address Pools:${NC}"
    kubectl get ipaddresspools.metallb.io -n metallb-system
    
    log "\n${BLUE}L2 Advertisements:${NC}"
    kubectl get l2advertisements.metallb.io -n metallb-system
    
    log "\n${BLUE}Ingress Status:${NC}"
    kubectl describe ingress nginx-ingress
    
    log "\n${BLUE}Controller Logs:${NC}"
    kubectl logs -n metallb-system -l component=controller --tail=30
    
    log "\n${BLUE}Speaker Logs:${NC}"
    kubectl logs -n metallb-system -l component=speaker --tail=30
}

# Function to display help
display_help() {
    echo "Usage: $0 [METALLB_VERSION] [LOADBALANCER_IP] [DOMAIN]"
    echo
    echo "METALLB_VERSION: Version of MetalLB to install (default: v0.14.8)"
    echo "LOADBALANCER_IP: IP address for the load balancer (default: 194.53.136.89)"
    echo "DOMAIN: Domain name for ingress (default: example.com)"
    exit 0
}

# Check if help is requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    display_help
fi

# Main script execution
log "${BLUE}Starting MetalLB ${METALLB_VERSION} Installation Process${NC}"
log "${YELLOW}Using IP: ${LOADBALANCER_IP}${NC}\n"

# Run all installation and test steps
check_requirements || exit 1
check_cluster || exit 1
clean_metallb || exit 1
install_metallb || exit 1
configure_ip_pool || exit 1
deploy_test_application || exit 1

log "\n${GREEN}Installation completed. Running tests...${NC}"

if test_setup; then
    log "\n${GREEN}✓ All tests passed successfully! MetalLB and Ingress are working correctly.${NC}"
else
    log "\n${RED}✗ Some tests failed. Gathering debug information...${NC}"
    show_debug_info
    exit 1
fi

log "\n${GREEN}All operations completed successfully!${NC}"
log "\n${YELLOW}Next Steps:${NC}"
log "1. Update your DNS records to point nginx.${DOMAIN} to ${LOADBALANCER_IP}"
log "2. Or access the application directly via http://${LOADBALANCER_IP}/nginx"
log -e "3. Monitor the application using: kubectl get pods,svc,ingress\n"