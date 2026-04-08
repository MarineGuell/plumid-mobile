# Script `plum` — GitHub workflow helper

Script en ligne de commande pour créer des issues, branches et pull requests sur GitHub en suivant le même workflow que GitLab (ticket → branche nommée d'après le ticket → merge request).

---

## Prérequis

### Dépendances

Le script nécessite les outils suivants :

| Outil     | Mac                | Linux                       | Windows                    |
|-----------|--------------------|-----------------------------|----------------------------|
| `bash`    | Inclus             | Inclus                      | WSL ou Git Bash            |
| `curl`    | Inclus             | `sudo apt install curl`     | Inclus dans WSL / Git Bash |
| `python3` | Inclus (macOS 12+) | `sudo apt install python3`  | Inclus dans WSL            |
| `iconv`   | Inclus             | Inclus                      | Inclus dans WSL / Git Bash |

> **Windows** : le script est un script Bash. Il ne fonctionne pas dans PowerShell ou cmd.exe natif.
> Utiliser **WSL** (Windows Subsystem for Linux) ou **Git Bash** (inclus avec [Git for Windows](https://gitforwindows.org)).

---

## Configuration du token GitHub

### 1. Créer un Personal Access Token

Aller sur GitHub : **Settings → Developer settings → Personal access tokens → Tokens (classic)**
[github.com/settings/tokens/new](https://github.com/settings/tokens/new)

> **Important** : utiliser un **classic token**, pas un fine-grained token.
> Les fine-grained tokens sont restreints aux repos dont tu es propriétaire et ne fonctionnent pas sur les repos où tu es simple collaborateur.

Scope requis :

- **`repo`** (englobe issues, pull requests, branches et contenus)

### 2. Ajouter le token dans `.env`

Créer ou éditer le fichier `.env` à la racine du projet.

#### Mac / Linux / WSL / Git Bash

```bash
echo 'GITHUB_TOKEN=ghp_xxxxxxxxxxxx' >> .env
```

#### Windows (Bloc-notes)

```text
Ouvrir .env avec le Bloc-notes et ajouter la ligne :
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

Le `.env` est ignoré par git (voir `.gitignore`). Ne jamais commiter de token.

---

## Installation

### Rendre le script exécutable

#### Mac / Linux / WSL / Git Bash (chmod)

```bash
chmod +x ./plum
```

#### Windows natif

Non supporté directement. Utiliser WSL ou Git Bash (voir Prérequis).

---

### Accès global (optionnel)

Pour utiliser `plum` depuis n'importe quel répertoire :

#### Mac / Linux / WSL

```bash
sudo ln -s "$(pwd)/plum" /usr/local/bin/plum
```

#### Git Bash (Windows)

Copier le script dans un dossier inclus dans le `PATH`, par exemple :

```bash
cp ./plum "$HOME/bin/plum"
# Si ~/bin n'est pas dans le PATH, l'ajouter dans ~/.bashrc :
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

---

## Commandes

### `create issue`

Crée une issue, et optionnellement une branche et une PR associées.

```bash
plum create issue [OPTIONS] "Titre de l'issue"
```

| Option         | Description                                              |
|----------------|----------------------------------------------------------|
| `-b`           | Crée une branche liée à l'issue (nommage style GitLab)   |
| `-mr`          | Crée une PR depuis la branche (nécessite `-b`)           |
| `-t <branche>` | Branche de base / cible PR (défaut : `main`)             |

---

### `create branch`

Crée une branche à partir d'un numéro d'issue existant. Le nom de la branche est construit automatiquement depuis le titre du ticket. Lève une erreur si l'issue n'existe pas.

```bash
plum create branch [OPTIONS] <numéro-issue>
```

| Option         | Description                                             |
|----------------|---------------------------------------------------------|
| `-t <branche>` | Branche de base à partir de laquelle brancher (défaut : `main`) |

---

### `create mr`

Crée une pull request depuis la **branche courante** vers une branche cible. Lève une erreur si la branche source et la cible sont identiques.

```bash
plum create mr [OPTIONS] "Titre de la PR"
```

| Option         | Description                              |
|----------------|------------------------------------------|
| `-t <branche>` | Branche cible de la PR (défaut : `main`) |

---

## Exemples

### Issue simple

```bash
./plum create issue "Fix login bug"
```

Crée une issue GitHub et retourne son URL.

---

### Issue + branche

```bash
./plum create issue -b "Fix login bug"
```

Crée l'issue, puis une branche nommée d'après le numéro et le titre :

```text
42-fix-login-bug
```

La branche est créée depuis `main` par défaut.

---

### Issue + branche + pull request vers main

```bash
./plum create issue -b -mr "Fix login bug"
```

Crée l'issue, la branche, puis une pull request vers `main`. La PR contient automatiquement `Closes #42` pour lier l'issue.

---

### Issue + branche + pull request vers une branche spécifique

```bash
./plum create issue -b -mr -t develop "Fix login bug"
```

Même chose, mais la PR cible `develop` au lieu de `main`.

---

### Branche depuis un ticket existant

```bash
./plum create branch 42
```

Récupère le titre du ticket #42 sur GitHub et crée une branche `42-fix-login-bug` depuis `main`.

```bash
./plum create branch -t develop 42
```

Même chose, mais la branche est créée depuis `develop`.

> Si le ticket #42 n'existe pas, le script s'arrête avec une erreur.

---

### Pull request depuis la branche courante

```bash
git checkout 42-fix-login-bug
./plum create mr "Fix login bug"
```

Crée une PR de `42-fix-login-bug` vers `main`.

```bash
./plum create mr -t develop "Fix login bug"
```

Même chose, mais vers `develop`.

> Si la branche courante est identique à la cible, le script s'arrête avec une erreur.

---

## Nommage des branches

Le nom de la branche suit la convention GitLab :

```text
{numéro-issue}-{titre-en-minuscule-avec-tirets}
```

Exemples :

| Titre de l'issue          | Branche générée            |
|---------------------------|----------------------------|
| `Fix login bug`           | `12-fix-login-bug`         |
| `Ajout écran profil`      | `27-ajout-ecran-profil`    |
| `[API] Auth token expiry` | `53-api-auth-token-expiry` |

Les accents sont translittérés, les caractères spéciaux remplacés par des tirets.

---

## Résolution de problèmes

### `GITHUB_TOKEN is not set`

Le fichier `.env` est absent ou ne contient pas `GITHUB_TOKEN`. Vérifier :

```bash
cat .env
```

### `Issue #X not found`

Le numéro de ticket passé à `create branch` n'existe pas dans le repo. Vérifier sur GitHub ou avec :

```bash
./plum create issue "Nouveau ticket"
```

### `Cannot create a PR from 'X' to itself`

La branche courante et la branche cible sont identiques. Changer de branche ou utiliser `-t` pour spécifier une cible différente.

### `Base branch 'main' not found`

La branche de base spécifiée n'existe pas sur le remote. Vérifier le nom avec :

```bash
git branch -r
```

### `Failed to create issue`

Le token n'a pas les permissions requises ou est expiré. Régénérer un classic token avec le scope `repo` sur GitHub.

### `bash: ./plum: Permission denied` (Mac / Linux)

Le script n'est pas exécutable :

```bash
chmod +x ./plum
```

### `python3: command not found`

- Mac : `brew install python3`
- Linux : `sudo apt install python3`
- WSL : `sudo apt install python3`
- Git Bash : installer [Python pour Windows](https://www.python.org/downloads) et cocher "Add to PATH"
