# 🏆 Capstone — Coupe du Monde 2026 : Déploiement Cloud

## Le Scénario

En vue de la nouvelle Coupe de Monde, la FIFA a missionner votre entreprise pour moderniser son site internet utilisé pour suivre les résultats sportif du championnat et de l’héberger dans une solution Cloud ou Cloud-Native capable de s’adapter à la charge.

Votre équipe a été choisit pour:
- Déployer une application Node.js + PostgreSQL sur le cloud
- Démontrer la haute disponibilité, l’élasticité, la résilience et en  l’observabilité de la platforme dans sa version modernisée.

Vous présenterez votre solution lors d’une soutenance de 40 minutes

> **Votre mission :** Migrer, moderniser et sécuriser cette application pour la rendre hautement disponible, résiliente, scalable et industrialisée. Vous avez carte blanche sur les choix d'architecture, mais le temps presse : **vous avez 2,5 jours avant la mise en production officielle (le crash-test en soutenance de 40 minutes).**

---

## Démarrage rapide

```bash
# 1. Cloner le dépôt
git clone <url-du-depot>
cd capstone-dplc

# 2. Lancer en local
docker-compose up --build

# 3. Vérifier
curl http://localhost:3000/          # → {"status":"ok"}
curl http://localhost:3000/metrics   # → métriques Prometheus
```

---

## Structure du projet

```
capstone-dplc/
├── app/                    # Code source de l'application (Node.js)
│   ├── main.js             # Application Express
│   ├── Dockerfile          # Dockerfile à optimiser !
│   ├── init.sql            # Script d'initialisation PostgreSQL
│   ├── package.json        # Dépendances
│   └── tests/              # Tests property-based
├── docs/
│   └── GUIDE-ETUDIANT.md  # Guide technique (routes API, variables, conseils)
├── docker-compose.yml      # Orchestration locale
└── README.md               # Ce fichier
```

---

## Vos missions

### 1. Optimiser le Dockerfile

Le Dockerfile fourni est volontairement mauvais. Vous devez le réécrire selon les bonnes pratiques professionnelles (image légère, sécurité, performance de build). Il y a 5 anti-patterns.

### 2. Déployer sur le cloud

Choisissez **une** des deux approches :

| Option A — AWS (Cloud Managé) | Option B — Kubernetes (Cloud Agnostique) |
|-------------------------------|------------------------------------------|
| VPC multi-AZ, Load Balancer, Compute auto-scalé, Base de données managée | Deployment avec auto-scaling, Ingress, Probes, Base de données persistante |
| Observabilité via CloudWatch | Observabilité via Prometheus + Grafana |

### 3. Répondre aux challenges techniques

| Challenge | Objectif |
|-----------|----------|
| **Industrialisation** | Déploiement reproductible (IaC ou Runbook rigoureux) |
| **Mur de charge** | Votre infra doit absorber un pic de trafic sans s'effondrer |
| **Bouton rouge** | L'application doit se rétablir automatiquement après un crash |
| **FinOps** | Justifier le dimensionnement et estimer le coût mensuel |

### 4. Job créatif (bonus)

Concevez un Job qui lit les données sportives en base et produit un résultat exploitable de votre choix (stats, classement, rapport, notification…).

---

## Livrables attendus

1. **Infrastructure** — Fichiers IaC (Terraform, Helm, CloudFormation…) ou `RUNBOOK.md` reproductible
2. **Dockerfile optimisé** — Selon les bonnes pratiques de conteneurisation
3. **Schéma d'architecture** — Diagramme technique clair et légendé
4. **README.md de votre dépôt** — URL publique d'accès + accès métriques/dashboards

---

## Soutenance (35 min)

La soutenance est une **revue d'ingénierie en direct** — pas de PowerPoint.

| Phase | Durée | Contenu |
|-------|-------|---------|
| Architecture & Pitch | 10 min | Présentation du diagramme, justification des choix techniques, stratégie budgétaire |
| Démo en direct | 10 min | Preuve que l'infra fonctionne (CI/CD ou exécution du Runbook) |
| Crash Test du jury | 15 min | Tests automatisés pilotés par l'enseignant sur votre infrastructure |

---

## Grille d'évaluation (sur 20 points)

| Critère | Points |
|---------|:------:|
| **Soutenance & Maîtrise technique orale** — Clarté, profondeur technique, réponses aux questions | **6** |
| **Choix architecturaux & Design** — Pertinence, reproductibilité, sécurité | **5** |
| **Élasticité & Auto-scaling** — Réaction autonome face à la charge | **4** |
| **Résilience & Self-Healing** — Rétablissement automatique après panne | **3** |
| **Observabilité & FinOps** — Dashboard opérationnel + estimation de coût chiffrée | **2** |
| **Total** | **20** |

**Bonus** (+2 pts max, plafond à 20) : Job créatif (+1) | CI/CD ou GitOps démontré (+1)

> La soutenance orale et la maîtrise technique représentent le plus gros coefficient. Comprendre et défendre vos choix compte autant que les avoir implémentés.

---

## Documentation

Consultez le [Guide Étudiant](docs/GUIDE-ETUDIANT.md) pour les détails techniques : routes API, variables d'environnement, exemples de requêtes, et conseils.

---

## 🚀 Déploiement Cloud (k3s, VPS Ikoula)

- **URL publique :** `https://worldcup.<IP>.nip.io`
- **Health :** `/api/health` · **DB :** `/api/health/db` · **Métriques :** `/metrics`
- **Grafana :** `https://grafana.<IP>.nip.io`
- **Architecture :** voir [`docs/architecture.md`](docs/architecture.md)
- **Reproduire :** voir [`infra/RUNBOOK.md`](infra/RUNBOOK.md) ou `infra/bootstrap.sh` + `helm upgrade`
- **CI/CD :** push sur `main` → GitHub Actions → build GHCR → `helm upgrade` sur le VPS

| Capacité | Mécanisme |
|---|---|
| Élasticité | HPA CPU (2→10 replicas) sur `/api/compute` |
| Self-healing | probes + restart kubelet ; PVC persistant |
| Observabilité | kube-prometheus-stack + dashboard Grafana |
| FinOps | 1 VPS 40 €/mois vs ~250-300 € managé (~6×) |

### Structure ajoutée

```
├── charts/worldcup/      # Chart Helm (app, postgres, hpa, ingress, cronjob, monitoring)
├── infra/                # bootstrap.sh (k3s+monitoring), RUNBOOK.md, loadtest.sh
├── teacher-tools/        # check-dockerfile.sh (scorer 5 bonnes pratiques)
├── .github/workflows/    # ci.yml (test → build GHCR → deploy SSH)
└── app/jobs/report.js    # Job créatif (classement + équipe favorite)
```

