# LBP Extractor

Cet outil permet de convertir vos relevés de compte PDF La Banque Postale en fichiers CSV lisibles dans des logiciels de type tableur comme Excel et LibreOffice Calc.
Il vous suffit de rassembler vos PDFs dans un dossier et d'exécuter l'outil : un ensemble de fichiers CSV apparaîtra dans le dossier contenant vos relevés.

**Cette version est écrite entièrement en shell** (bash + awk + `pdftotext`) : plus besoin d'installer Python, pandas ou PyMuPDF, un simple script suffit.

- Dépôt officiel : [Ludo-code/LBPExtractor](https://github.com/Ludo-code/LBPExtractor)
- Dépôt original : le projet est basé sur le dépôt de hayj. [hayj/lbpextract](https://github.com/hayj/lbpextract).

## Prérequis

- `bash`
- `awk` (installé par défaut sur la plupart des systèmes)
- `pdftotext` (paquet **poppler-utils**) :
  - Debian/Ubuntu : `sudo apt install poppler-utils`
  - Fedora : `sudo dnf install poppler-utils`
  - macOS : `brew install poppler`
  - Arch : `sudo pacman -S poppler`
- **Optionnel** pour le mini-GUI : `zenity` (graphique), `whiptail` ou `dialog` (terminal) — voir le tableau des backends plus bas.

## Installation

Téléchargez le script et rendez-le exécutable :

```bash
git clone https://github.com/Ludo-code/LBPExtractor.git
cd LBPExtractor
chmod +x lbpextract
# optionnel : le rendre disponible partout
sudo cp lbpextract /usr/local/bin/
```

## Assembler vos relevés de compte

1. Créez un dossier
2. Allez sur votre espace client -> Documents et suivi -> Relevés et documents -> Recherche avancée
3. Choisissez un compte et une année puis cliquez sur Rechercher
4. Téléchargez les fichiers un par un (attention à ne pas en ouvrir plusieurs à la fois au risque de voir certains fichiers ne pas correspondre au bon mois)
5. Déplacez tous ces fichiers dans le dossier initialement créé

## Utilisation

```bash
cd /chemin/vers/votre/dossier
./lbpextract *.pdf
# ou, si installé dans le PATH :
lbpextract *.pdf
```

Les fichiers CSV sont générés dans le même répertoire que les PDF (un CSV par compte, nommé d'après le numéro de compte).

## Mini-GUI (optionnel)

Sans aucun argument (ou avec `--gui`), l'outil ouvre une petite interface interactive au lieu de la ligne de commande :

```bash
lbpextract          # lance le mini-GUI si un backend est installé
lbpextract --gui    # force le mini-GUI
```

Le mini-GUI vous demande successivement :

1. le **dossier contenant vos relevés PDF** (tous les `*.pdf` du dossier sont traités),
2. le **dossier de sortie** des CSV (vide = même dossier que les PDF),
3. si les CSV existants doivent être **écrasés** (`--remove`),
4. si les montants doivent être **séparés en income / spending** (`--separate`),

puis lance la conversion et affiche le résultat (liste des CSV créés ou erreurs).

Backends supportés, par ordre de préférence :

| Backend | Type | Installation |
|---|---|---|
| `zenity` | fenêtres graphiques (GNOME) | `sudo apt install zenity` |
| `whiptail` | dialogues dans le terminal | `sudo apt install whiptail` |
| `dialog` | dialogues dans le terminal | `sudo apt install dialog` |

Si aucun backend n'est installé, `lbpextract` sans argument affiche l'aide ; en passant des PDF en argument, le mode CLI fonctionne toujours, même sans aucun backend GUI.

### Options

| Option | Description |
|---|---|
| `-o, --output-dir DIR` | Écrire les CSV dans `DIR` au lieu du dossier des PDF (obligatoire si les PDF viennent de plusieurs dossiers). |
| `-r, --remove` | Écraser les CSV existants au lieu d'échouer. |
| `-s, --separate` | Séparer la colonne `amount` en deux colonnes `income` (positifs) et `spending` (négatifs). |
| `-k, --keep-temp` | Conserver le dossier temporaire (debug). |
| `-g, --gui` | Lancer le mini-GUI interactif (zenity, whiptail ou dialog). |
| `-V, --version` | Afficher la version. |
| `-h, --help` | Afficher l'aide. |

### Exemples

```bash
# Convertir tous les relevés du dossier courant
lbpextract *.pdf

# Avec colonnes income/spending séparées, en écrasant les anciens CSV
lbpextract --separate --remove *.pdf

# Plusieurs dossiers, sortie centralisée
lbpextract -o ~/compta/csv --remove ~/releves/*.pdf ~/autres-releves/*.pdf
```

### Format des CSV produits

Sans `--separate` :

```csv
date,amount,description
2023-01-10,2500.00,VIREMENT SALAIRE
2023-01-03,-123.45,PRELEVEMENT EDF
```

Avec `--separate` :

```csv
date,income,spending,description
2023-01-10,2500.00,0.00,VIREMENT SALAIRE
2023-01-03,0.00,-123.45,PRELEVEMENT EDF
```

Les lignes sont triées par date décroissante. Les montants négatifs (débits) sont détectés grâce à la position horizontale de la colonne dans le PDF, comme dans la version Python d'origine.

## Améliorations par rapport à la version Python

- **Zéro dépendance Python** : un seul fichier shell, aucune installation de paquets (`pip install` terminé).
- **Codes de sortie explicites** : `0` = succès, `1` = erreur d'usage, `2` = aucun PDF trouvé, `3` = au moins un PDF en échec — facilitant l'usage dans des scripts et des cron.
- **Détection de doublons** conservée (les PDF identiques sont ignorés avec un avertissement).
- **Vérification préalable** : si un CSV de sortie existe déjà, l'outil échoue **avant** d'avoir traité quoi que ce soit (sauf avec `--remove`).
- **Options courtes et longues** (`-r`/`--remove`, `-s`/`--separate`, `-o`/`--output-dir`).
- **Échappement CSV correct** des descriptions contenant virgules ou guillemets.
- **Gestion des espaces insécables** (montants « 1 234,56 » avec espaces fines) et de l'ancienne colonne « Soit en francs ».
- **Avertissement** sur les lignes non reconnues pour ne rien manquer silencieusement.

## Tests

```bash
bash tests/run_tests.sh
```

Les tests génèrent des relevés PDF synthétiques (`tests/make_fixtures.py`, nécessite PyMuPDF) et utilisent `tests/pdftotext_mock.py` comme doublure de `pdftotext` si poppler-utils n'est pas installé.

## Licence

Voir [LICENSE](LICENSE).
