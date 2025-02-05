# MetalLB with Traefik Ingress Controller
## Introduction

This guide provides a comprehensive walkthrough for setting up MetalLB with Traefik Ingress Controller in a Kubernetes environment. MetalLB is a load-balancer implementation for bare metal Kubernetes clusters, while Traefik is a versatile reverse proxy and load balancer. Together, they enable efficient traffic management and routing within your cluster.

## Why Use MetalLB and Traefik?

- **MetalLB**: Provides network load balancing for Kubernetes clusters running on bare metal.
- **Traefik**: Offers dynamic routing, SSL termination, and load balancing with minimal configuration.

By combining MetalLB and Traefik, you can achieve a robust and scalable ingress solution for your Kubernetes applications.
## Table of Contents

- [MetalLB with Traefik Ingress Controller](#metallb-with-traefik-ingress-controller)
  - [Introduction](#introduction)
  - [Why Use MetalLB and Traefik?](#why-use-metallb-and-traefik)
  - [Table of Contents](#table-of-contents)
  - [Quick Start](#quick-start)
  - [Overview](#overview)
  - [Repository Structure](#repository-structure)
  - [Prerequisites](#prerequisites)
  - [Features](#features)
  - [Installation](#installation)
  - [Configuration](#configuration)
    - [Basic Configuration Example](#basic-configuration-example)
    - [Ingress Example](#ingress-example)
  - [Usage Examples](#usage-examples)
    - [Host-based Routing](#host-based-routing)
    - [Path-based Routing](#path-based-routing)
  - [Monitoring](#monitoring)
  - [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
  - [Production Checklist](#production-checklist)
  - [Contributing](#contributing)
  - [License](#license)
  - [Acknowledgments](#acknowledgments)
  - [FAQ](#faq)
    - [How do I update MetalLB or Traefik?](#how-do-i-update-metallb-or-traefik)
    - [Can I use Let's Encrypt for SSL certificates?](#can-i-use-lets-encrypt-for-ssl-certificates)
    - [How do I add more IP addresses to the IP pool?](#how-do-i-add-more-ip-addresses-to-the-ip-pool)
    - [How do I enable high availability for Traefik?](#how-do-i-enable-high-availability-for-traefik)
    - [What monitoring tools are supported?](#what-monitoring-tools-are-supported)
    - [FAQ](#faq-1)
      - [How do I update MetalLB or Traefik?](#how-do-i-update-metallb-or-traefik-1)
      - [Can I use Let's Encrypt for SSL certificates?](#can-i-use-lets-encrypt-for-ssl-certificates-1)
      - [How do I add more IP addresses to the IP pool?](#how-do-i-add-more-ip-addresses-to-the-ip-pool-1)
      - [How do I enable high availability for Traefik?](#how-do-i-enable-high-availability-for-traefik-1)
      - [What monitoring tools are supported?](#what-monitoring-tools-are-supported-1)
## Quick Start

```bash
git clone https://github.com/yourusername/metallb-traefik-setup
cd metallb-traefik-setup
chmod +x setup-metallb.sh
./setup-metallb.sh
```

## Overview

This repository provides a complete solution for setting up MetalLB load balancer with Traefik ingress controller in a Kubernetes cluster. The setup includes automatic SSL/TLS configuration, host-based and path-based routing, and comprehensive monitoring capabilities.

## Repository Structure

```
.
├── setup-metallb.sh         # Main installation script
├── docs/
│   └── installation.md      # Detailed installation guide
├── examples/
│   ├── ingress-routes/      # Example ingress configurations
│   └── ssl-config/          # SSL configuration examples
├── LICENSE
└── README.md               # This file
```

## Prerequisites

- Kubernetes cluster (v1.20+)
- kubectl installed and configured
- Single public IP address
- OpenSSL (for certificate generation)

## Features

- 🚀 Automated installation process
- 🔒 SSL/TLS support with automatic certificate management
- 🌐 Flexible routing (host-based and path-based)
- 📊 Built-in monitoring and metrics
- 🔄 High availability configuration
- 🛡️ Security best practices

## Installation

1. Update configuration in `setup-metallb.sh`:
```bash
METALLB_VERSION="v0.14.8"
LOADBALANCER_IP="your.ip.address"
DOMAIN="your.domain.com"
```

2. Run the installation script:
```bash
./setup-metallb.sh
```

## Configuration

### Basic Configuration Example
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - your.ip.address/32
  autoAssign: true
```

### Ingress Example
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
  - host: your.domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
```

## Usage Examples

### Host-based Routing
```bash
curl -H "Host: your.domain.com" https://your.ip.address
```

### Path-based Routing
```bash
curl https://your.ip.address/path
```

## Monitoring

Access Traefik dashboard:
```bash
kubectl port-forward -n kube-system $(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik -o name) 9000:9000
```

Visit `http://localhost:9000/dashboard/` in your browser.

## Troubleshooting

### Common Issues

1. **LoadBalancer IP not assigned**
   ```bash
   kubectl get svc -n kube-system traefik
   kubectl describe svc -n kube-system traefik
   ```

2. **Certificate Issues**
   ```bash
   kubectl describe secret nginx-tls
   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
   ```

3. **Routing Issues**
   ```bash
   kubectl get ingress
   kubectl describe ingress your-ingress-name
   ```

For more troubleshooting guides, see [Troubleshooting](docs/installation.md#troubleshooting).

## Production Checklist

- [ ] Replace self-signed certificates
- [ ] Configure backup strategy
- [ ] Set up monitoring and alerting
- [ ] Implement rate limiting
- [ ] Configure access controls
- [ ] Set up SSL/TLS
- [ ] Configure health checks

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [MetalLB Documentation](https://metallb.universe.tf/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
## FAQ

### How do I update MetalLB or Traefik?

To update MetalLB or Traefik, modify the version numbers in the `setup-metallb.sh` script and re-run the installation script. Ensure you review the release notes for any breaking changes.

### Can I use Let's Encrypt for SSL certificates?

Yes, you can use Let's Encrypt for SSL certificates. Traefik supports automatic certificate generation and renewal using Let's Encrypt. Refer to the [Traefik documentation](https://doc.traefik.io/traefik/https/acme/) for detailed instructions.

### How do I add more IP addresses to the IP pool?

To add more IP addresses to the IP pool, update the `addresses` field in the `IPAddressPool` resource and apply the changes:
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - your.ip.address/32
  - another.ip.address/32
  autoAssign: true
```
Apply the updated configuration:
```bash
kubectl apply -f ipaddresspool.yaml
```

### How do I enable high availability for Traefik?

To enable high availability for Traefik, deploy Traefik with multiple replicas and configure a persistent storage backend for the Traefik configuration. This ensures that Traefik instances share the same configuration and state.

### What monitoring tools are supported?

This setup supports monitoring with Prometheus and Grafana. Traefik provides built-in metrics that can be scraped by Prometheus. You can visualize these metrics using Grafana dashboards.

### FAQ

#### How do I update MetalLB or Traefik?

To update MetalLB or Traefik, modify the version numbers in the `setup-metallb.sh` script and re-run the installation script. Ensure you review the release notes for any breaking changes.

#### Can I use Let's Encrypt for SSL certificates?

Yes, you can use Let's Encrypt for SSL certificates. Traefik supports automatic certificate generation and renewal using Let's Encrypt. Refer to the [Traefik documentation](https://doc.traefik.io/traefik/https/acme/) for detailed instructions.

#### How do I add more IP addresses to the IP pool?

To add more IP addresses to the IP pool, update the `addresses` field in the `IPAddressPool` resource and apply the changes:
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - your.ip.address/32
  - another.ip.address/32
  autoAssign: true
```
Apply the updated configuration:
```bash
kubectl apply -f ipaddresspool.yaml
```

#### How do I enable high availability for Traefik?

To enable high availability for Traefik, deploy Traefik with multiple replicas and configure a persistent storage backend for the Traefik configuration. This ensures that Traefik instances share the same configuration and state.

#### What monitoring tools are supported?

This setup supports monitoring with Prometheus and Grafana. Traefik provides built-in metrics that can be scraped by Prometheus. You can visualize these metrics using Grafana dashboards.
