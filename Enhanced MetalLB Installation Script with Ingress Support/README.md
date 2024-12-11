# MetalLB with Traefik Ingress Controller

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

For detailed installation instructions, see [Installation Guide](docs/installation.md).

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

## Security

For security issues, please see [SECURITY.md](SECURITY.md) or email security@yourdomain.com.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [MetalLB Documentation](https://metallb.universe.tf/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Support

For support:
1. Check the [documentation](docs/installation.md)
2. Open an issue
3. Join our [Slack channel](#)

## Further Reading

For detailed documentation about installation, configuration, and best practices, please refer to our [Installation Guide](docs/installation.md).