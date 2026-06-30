# OPTIMISATION.md — Optimisation du Dockerfile

**Dépôt GitHub :** <https://github.com/Ynov-Alan-Projects/capstone-dplc-student>

> Mission 1 du Capstone : le Dockerfile fourni est volontairement mauvais et
> contient **5 anti-patterns**. Ce document explique ce qui a été corrigé et
> **pourquoi**.

## 1. Avant / Après

### Dockerfile fourni (mauvais)

```dockerfile
FROM node:latest

WORKDIR /app

COPY . .

RUN npm install

EXPOSE 3000

CMD ["node", "main.js"]
```

### Dockerfile optimisé (`app/Dockerfile`)

```dockerfile
# syntax=docker/dockerfile:1

# --- build stage: install production deps only ---
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# --- runtime stage: minimal, non-root ---
FROM node:20-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY . .
USER node
EXPOSE 3000
CMD ["node", "main.js"]
```

### Résultat mesuré

| Indicateur | Avant (`node:latest`) | Après (`node:20-alpine` multi-stage) |
|---|---|---|
| Taille de l'image | ~1,1 Go | **~205 Mo** (≈ 5× plus petit) |
| Utilisateur d'exécution | `root` (uid 0) | `node` (**uid 1000**, non-root) |
| Dépendances de dev embarquées | Oui | **Non** (`--omit=dev`) |
| Reproductibilité du build | Faible (`npm install`) | **Forte** (`npm ci` sur lockfile) |
| Score `teacher-tools/check-dockerfile.sh` | 0/5 | **5/5** |

---

## 2. Les 5 anti-patterns corrigés

### ① Tag d'image flottant et lourd : `node:latest`

**Problème.** `node:latest` est (a) **non versionné** : le build n'est pas
reproductible, l'image peut changer du jour au lendemain et casser la prod ;
(b) **basé sur Debian complet** (~1 Go) avec une foule d'outils inutiles au
runtime → surface d'attaque et temps de pull plus grands.

**Correctif.** Tag **épinglé** et **base minimale** : `node:20-alpine`.
Alpine fait quelques dizaines de Mo, la version majeure 20 est figée → builds
déterministes.

> Couvre le **check 1** du barème technique : « last FROM image is a pinned
> slim/alpine tag, not node:latest ».

### ② Conteneur qui tourne en `root`

**Problème.** Sans instruction `USER`, le process Node tourne en **root**
dans le conteneur. En cas de compromission de l'app (RCE), l'attaquant est
root dans le conteneur → escalade beaucoup plus facile. C'est aussi
incompatible avec une politique Kubernetes `runAsNonRoot: true`.

**Correctif.** `USER node` : l'image `node:*-alpine` fournit déjà un
utilisateur non privilégié `node` (**uid/gid 1000**). On applique le principe
du **moindre privilège**.

> Note déploiement : côté Helm on déclare l'UID **numérique**
> (`runAsUser: 1000`) car Kubernetes ne peut pas vérifier qu'un user *nommé*
> (`node`) est non-root sous `runAsNonRoot: true`.
>
> Couvre le **check 2** : « a non-root USER instruction is present ».

### ③ Build mono-stage → image polluée

**Problème.** Un seul `FROM` : tout ce qui sert à **construire** (cache npm,
sources superflues, éventuels outils de compilation des modules natifs) se
retrouve dans l'**image finale** livrée en production. Image plus grosse,
plus de surface d'attaque.

**Correctif.** **Build multi-stage** :
- *stage `build`* : installe uniquement les dépendances de production.
- *stage runtime* : repart d'une base propre et ne copie que
  `node_modules` (`COPY --from=build`) + le code.

Seul l'artefact utile traverse la frontière entre les stages.

> Couvre le **check 3** : « multi-stage build (≥ 2 FROM instructions) ».

### ④ Pas de `.dockerignore`

**Problème.** `COPY . .` embarque **tout le contexte de build** : `.git`,
`node_modules` locaux (potentiellement d'une autre archi), `tests/`,
`coverage/`, fichiers `*.md`… → image gonflée, cache invalidé en permanence,
risque de fuite de fichiers sensibles.

**Correctif.** Ajout de `app/.dockerignore` :

```
node_modules
npm-debug.log
tests
coverage
*.md
.git
.gitignore
.dockerignore
Dockerfile
```

Le contexte envoyé au démon Docker est réduit au strict nécessaire.

> Couvre le **check 4** : « a .dockerignore exists alongside the Dockerfile ».

### ⑤ Mauvais ordre des couches (cache cassé) + `npm install`

**Problème.** `COPY . .` **avant** `RUN npm install` : la moindre modification
d'une ligne de code invalide la couche `COPY`, donc **toutes** les couches
suivantes, dont l'installation des dépendances. Résultat : `npm install` est
ré-exécuté à **chaque** build, même si `package.json` n'a pas bougé. De plus
`npm install` peut faire dériver les versions (pas de respect strict du
lockfile).

**Correctif.** Ordonnancement optimal pour le **cache de couches Docker** :

```dockerfile
COPY package*.json ./     # 1. juste les manifestes
RUN npm ci --omit=dev     # 2. install reproductible, prod-only
COPY . .                  # 3. le code en dernier
```

Tant que `package*.json` ne change pas, la couche d'install est **réutilisée
depuis le cache** → builds beaucoup plus rapides. `npm ci` :
- installe **exactement** ce qui est dans `package-lock.json` (reproductible) ;
- `--omit=dev` exclut les dépendances de développement de l'image runtime.

> Couvre le **check 5** : « optimal layer order :
> `COPY *package*` < `RUN npm ci` < `COPY . .` ».

---

## 3. Bonus : durcissements complémentaires

- `ENV NODE_ENV=production` : désactive le mode debug d'Express et certains
  comportements coûteux ; aligne le runtime sur le profil de dépendances.
- `# syntax=docker/dockerfile:1` : active le frontend BuildKit moderne
  (meilleur cache, fonctionnalités récentes).
- `EXPOSE 3000` conservé : documente le port applicatif (cohérent avec le
  Service / l'Ingress Kubernetes).

## 4. Vérification

```bash
# Score automatique (contrat du barème, 5 checks)
bash teacher-tools/check-dockerfile.sh app/Dockerfile
# → "5/5 checks passed"

# Build + taille
docker build -t worldcup-app ./app
docker images worldcup-app           # ~205 Mo

# Vérifier l'utilisateur non-root
docker run --rm worldcup-app id      # uid=1000(node) gid=1000(node)
```

Le test property-based `app/tests/dockerfile-check.property.test.js` encode
ce même contrat et passe au vert dans la CI.
