# RUNBOOK — World Cup 2026 on k3s (Ikoula VPS)

## 0. Prerequisites
- Ubuntu VPS, root/sudo, public IP `<IP>`.
- Public URL host: `worldcup.<IP>.nip.io` (no DNS purchase; nip.io resolves to `<IP>`).
- GitHub repo with a GHCR image and the `feat/k8s-capstone` branch merged to `main`.

## 1. Provision the cluster
```bash
# Pass the variables to sudo directly: `sudo -E` is ignored on some
# hardened sudoers, which would silently fall back to the defaults.
sudo PUBLIC_IP=<IP> LETSENCRYPT_EMAIL=you@example.com bash infra/bootstrap.sh
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

## 1b. Image pull secret (private GHCR package only)
Skip this if the GHCR package is public. For a private package, create the
pull secret the chart references (token needs the `read:packages` scope):
```bash
kubectl create namespace worldcup --dry-run=client -o yaml | kubectl apply -f -
kubectl -n worldcup create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=<github-user> \
  --docker-password=<PAT-with-read:packages>
```

## 2. Deploy the app
```bash
helm upgrade --install worldcup charts/worldcup \
  --namespace worldcup --create-namespace \
  --set host=worldcup.<IP>.nip.io \
  --set image.repository=ghcr.io/<owner>/worldcup-app \
  --set image.tag=<commit-sha> \
  --set db.password='<strong-password>' \
  --set ingress.tls.enabled=true \
  --set imagePullSecrets[0].name=ghcr-pull \
  --wait
```
> Omit the `imagePullSecrets` flag if the GHCR package is public.

## 3. Verify
```bash
kubectl -n worldcup get pods,svc,hpa,ingress
curl -s https://worldcup.<IP>.nip.io/api/health        # {"status":"ok"}
curl -s https://worldcup.<IP>.nip.io/api/health/db     # {"status":"ok"}
curl -s https://worldcup.<IP>.nip.io/metrics | head
```

## 4. Demo — Elasticity (HPA)
```bash
kubectl -n worldcup get hpa -w &           # watch replicas climb
HOST=worldcup.<IP>.nip.io infra/loadtest.sh
```
Expected: replicas scale 2 -> up to 10 while CPU > 60%, then back down.

## 5. Demo — Self-healing
```bash
kubectl -n worldcup get pods -w &
curl -X POST https://worldcup.<IP>.nip.io/api/admin/kill
```
Expected: the killed pod restarts within seconds; traffic stays up (other replica serves).

## 6. Observability
- Grafana: `https://grafana.<IP>.nip.io` (admin password printed by bootstrap).
- Dashboard "World Cup App": requests/s, p95, ready replicas, restarts.

## 7. Creative job
```bash
kubectl -n worldcup create job --from=cronjob/worldcup-report manual-report
kubectl -n worldcup logs job/manual-report
```

## 8. Rollback
```bash
helm -n worldcup rollback worldcup
```

## Troubleshooting
- TLS not issued: set `ingress.tls.enabled=false`, use `http://`; check `kubectl -n worldcup describe certificate`.
- HPA shows `<unknown>` CPU: ensure metrics-server is up (`kubectl -n kube-system get deploy metrics-server`) and app resources.requests.cpu is set.
- DB init didn't run: PVC already initialized; init.sql only runs on first boot. Wipe with `kubectl -n worldcup delete pvc data-worldcup-db-0` (destroys data).
