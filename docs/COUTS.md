# COUTS.md — Estimation de coût (FinOps)

**Dépôt GitHub :** <https://github.com/Ynov-Alan-Projects/capstone-dplc-student>

> Mission « Déployer sur le cloud » → livrable **estimation de coût chiffrée**.
> Ce document chiffre notre solution réelle (VPS + k3s) et la compare à une
> solution managée équivalente, avec les hypothèses retenues.

## 1. Résumé (le chiffre à retenir)

| Solution | Coût mensuel | Coût annuel |
|---|---:|---:|
| **Notre solution — VPS + k3s** ✅ | **40 €/mois** | **480 €/an** |
| Référence — Kubernetes managé (AWS) | ~250–300 €/mois | ~3 000–3 600 €/an |
| **Économie** | **≈ 6× moins cher** | **~2 500–3 100 €/an** |

**Synthèse :** pour un projet de cette taille, la facture est divisée par ~6
en assumant un compromis clair (un seul serveur), tout en gardant une
architecture **prête à grossir**.

---

## 2. Détail de NOTRE solution (40 €/mois)

| Poste | Détail | Coût/mois |
|---|---|---:|
| **VPS Ikoula** | 16 vCPU / 16 Go RAM / 50 Go SSD, Ubuntu | **40 €** |
| Nom de domaine | `*.nip.io` (adresse gratuite basée sur l'IP) | 0 € |
| Certificat HTTPS | Let's Encrypt (gratuit, renouvellement auto) | 0 € |
| Orchestrateur | k3s (open-source, inclus sur le VPS) | 0 € |
| Monitoring | Prometheus + Grafana (open-source) | 0 € |
| Registre d'images | GHCR (gratuit pour notre usage) | 0 € |
| CI/CD | GitHub Actions (offre gratuite suffisante) | 0 € |
| **TOTAL** | | **40 €/mois** |

> Tout ce qui entoure le VPS est **gratuit et open-source**. Le seul poste
> payant est la machine elle-même.

---

## 3. À quoi ressemblerait une solution managée (référence)

Pour la même application en **Kubernetes managé sur AWS**, ordre de grandeur :

| Composant AWS | Rôle | Coût/mois (ordre de grandeur) |
|---|---|---:|
| EKS (control plane) | Le « cerveau » Kubernetes managé | ~70 € |
| 2 nœuds EC2 (t3.medium) | Les machines qui font tourner les pods | ~60–70 € |
| RDS PostgreSQL | Base de données managée | ~30–50 € |
| Load Balancer (ALB) | Porte d'entrée managée | ~20 € |
| Stockage EBS + ECR + trafic | Disques, registre, réseau | ~20–40 € |
| CloudWatch | Monitoring managé | ~10–30 € |
| **TOTAL approximatif** | | **~250–300 €/mois** |

> Le managé apporte de la **vraie haute disponibilité multi-zones** et moins
> de maintenance — mais à un coût hors budget d'un projet étudiant.

---

## 4. Hypothèses & périmètre

- Trafic modéré (projet / démo), pas de très gros volumes de données sortantes.
- Pas d'engagement longue durée AWS (les « Reserved Instances » baisseraient
  la facture managée, mais avec un engagement de 1–3 ans).
- Coûts AWS = **ordres de grandeur** (varient selon région, trafic, taille).
- Notre VPS est **à prix fixe** : pas de mauvaise surprise de facturation à
  l'usage (un vrai avantage FinOps pour un budget contraint).

---

## 5. Coût si on doit grandir (élasticité du budget)

- **Notre solution** : monter en gamme de VPS, ou ajouter 1–2 VPS pour faire
  un vrai cluster multi-serveurs → on resterait **bien en dessous** du managé
  (ex. 3 VPS ≈ 120 €/mois).
- **Managé** : grimpe vite avec le nombre de nœuds, le trafic et les options.

| Scénario | Notre solution | Managé |
|---|---:|---:|
| Démo / projet (actuel) | 40 €/mois | ~250 €/mois |
| Petite prod (3 serveurs, vraie HA) | ~120 €/mois | ~400 €/mois |

---

## 6. Coûts « cachés » (vision complète)

Le prix de la machine n'est pas le seul coût réel :

- **Temps humain** : auto-hébergé = c'est **nous** qui gérons mises à jour,
  sauvegardes, incidents. Le managé « achète » ce temps.
- **Risque** : un seul serveur = si la machine tombe, le site tombe. C'est le
  compromis qu'on a choisi pour le budget (voir `SOUTENANCE.md`, section recul
  critique).

**Conclusion :** notre choix est optimal sur le **rapport coût/valeur** pour ce
projet ; on sait exactement ce qu'on « paie » en échange (du temps de gestion
et un point de panne unique), et comment évoluer si le besoin grandit.
