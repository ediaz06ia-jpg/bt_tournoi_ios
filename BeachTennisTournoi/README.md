# Tournoi Beach Tennis · application iOS

Application iPhone (iOS 16+) construite à partir de l'artefact « Beach tennis · Gestion de tournoi (v2) ».
Le moteur du tournoi (règles FFT, tirage, TMC, poules, programmation, classement BT25 à BT1000) est dans
`BeachTennisTournoi/index.html`, embarqué dans une coque SwiftUI native, 100 % hors ligne.

## Fonctions
- Import des inscriptions exportées du logiciel de la FFT (`.xls`, `.xlsx`, `.csv`) : paires, licences, clubs, classements.
  Les courriels, téléphones et dates de naissance sont ignorés.
- Classements FFT : lecture locale des PDF mensuels « Dames » et « Messieurs » (choisis par l'utilisateur), retrouvés par numéro de licence ; remplissage automatique du classement, comparaison avec l'inscription et mise à jour en un geste. Seuls licences et rangs sont conservés.
- Rappels « ton match commence dans 10 min » (notifications locales), pour tous les matchs ou pour des équipes choisies.
- Export PDF (A4 paysage) : tableaux, poules, programme, classement, aux couleurs du club.
- Affichage public plein écran pour l'écran du club (rotation automatique, écran toujours allumé, AirPlay possible).
- Nom, logo et couleurs du club (application, PDF, affichage public).
- Sauvegarde native, export/import de fichier, partage de résultats, vibrations.

## Dossiers
- `BeachTennisTournoi.xcodeproj` : projet Xcode (Xcode 16 ou plus).
- `BeachTennisTournoi/` : code Swift, `index.html`, SheetJS (`xlsx.full.min.js`, Apache 2.0), icône, politique de confidentialité intégrée à l'app.
- `AppStore/` : fiche App Store, notes de validation, politique de confidentialité à héberger, checklist de conformité Apple, fichier d'exemple fictif.

## Installer sur ton iPhone
1. Installer **Xcode** (App Store), l'ouvrir une fois et installer la plateforme iOS.
2. Ouvrir `BeachTennisTournoi.xcodeproj`, cible *BeachTennisTournoi* → **Signing & Capabilities** : choisir ton Apple ID dans *Team*
   et remplacer `fr.beachtennis.tournoi` par un identifiant unique (par exemple `fr.tonnom.beachtennis`).
3. Brancher l'iPhone, activer le **Mode développeur** (Réglages → Confidentialité et sécurité), le choisir dans Xcode, puis ⌘R.
4. Au premier lancement : Réglages → Général → VPN et gestion de l'appareil → faire confiance au développeur.

Avec un Apple ID gratuit, l'app doit être réinstallée tous les 7 jours (les données restent). Un compte Apple Developer (99 €/an)
est nécessaire pour TestFlight et l'App Store : voir `AppStore/conformite-apple.md`.

## Modifier l'app
Les règles et l'interface sont dans `index.html`. Conserver la clé de stockage `bt-tournoi-v2` pour garder les tournois existants.
Les fonctions natives (notifications, PDF, affichage public) sont dans `TournamentWebView.swift` et `BeachTennisTournoiApp.swift`.

> État de la vérification : la page et son pont avec iOS ont été testés dans un navigateur ; le code Swift a seulement été
> vérifié syntaxiquement (Xcode absent de la machine de développement). Compile et teste sur un iPhone avant toute diffusion.
