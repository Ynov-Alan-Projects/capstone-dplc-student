#!/usr/bin/env bash
# Provision a single-node k3s cluster with ingress TLS + monitoring for the
# World Cup capstone. Idempotent: safe to re-run. Run as root on the VPS.
#
# Env:
#   PUBLIC_IP           public IPv4 of the VPS (used for grafana nip.io host)
#   LETSENCRYPT_EMAIL   email for the ACME account (default: admin@example.com)
set -euo pipefail

EMAIL="${LETSENCRYPT_EMAIL:-admin@example.com}"

echo "==> 1. Install k3s (Traefik + local-path + metrics-server included)"
if ! command -v k3s >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | sh -
fi
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes

echo "==> 2. Install Helm"
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "==> 3. cert-manager (for Let's Encrypt TLS)"
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true --wait

echo "==> 4. Let's Encrypt ClusterIssuer (HTTP-01 via Traefik)"
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: traefik
EOF

echo "==> 5. kube-prometheus-stack (Prometheus + Grafana)"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.ingress.enabled=true \
  --set "grafana.ingress.ingressClassName=traefik" \
  --set "grafana.ingress.hosts[0]=grafana.${PUBLIC_IP:-127.0.0.1}.nip.io" \
  --set prometheus.prometheusSpec.retention=7d \
  --wait

echo "==> Done. Grafana admin password:"
kubectl -n monitoring get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
