# Conformité aux consignes de validation d'Apple

Référence : [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), lues le 12/10/2026. Aucune garantie d'acceptation : la décision appartient à Apple. Ce tableau indique ce qui est fait dans le projet et ce qu'il te reste à faire.

## Fait dans le projet
| Règle | Mesure |
|---|---|
| **4.2** Fonctions minimales (« plus qu'un site web empaqueté ») | Contenu 100 % embarqué et utilisable hors ligne. Fonctions natives d'iOS : notifications locales, export PDF multi-pages (moteur d'impression d'iOS), feuille de partage, import de fichiers (Excel FFT, sauvegarde), écran toujours allumé et barre d'état masquée en affichage public, vibrations, sauvegarde dans le dossier de l'app. |
| **2.5.2** Pas de code téléchargé | Aucun appel réseau. Tout le JavaScript (dont la lecture Excel SheetJS) est dans l'application. Polices Google supprimées. |
| **5.1.1(i)** Politique de confidentialité | Texte dans l'app (Tournoi → « À propos · Confidentialité ») **et** version hébergeable `politique-de-confidentialite.html`. |
| **5.2.2** Contenu d'un service tiers (classements FFT) | Option A : l'app ne se connecte pas au site de la FFT. L'utilisateur télécharge lui-même les PDF publics et les choisit dans Fichiers ; seuls numéros de licence et rangs sont gardés sur l'appareil (noms et clubs ignorés). |
| **5.1.1** Données, minimisation | Les courriels, téléphones et dates de naissance du fichier FFT sont ignorés et jamais enregistrés. Sélecteur de fichiers hors processus d'iOS, aucun accès aux contacts, photos, localisation, micro ou caméra. |
| **5.1.2** / **4.5.4** Autorisations non exigées | Les notifications ne sont demandées qu'au moment où l'utilisateur active les rappels, et leur refus ne bloque rien. Aucun suivi (pas d'ATT). |
| Privacy manifest | `PrivacyInfo.xcprivacy` : pas de suivi, aucune donnée collectée, aucune API à justification requise. |
| **5.2.1** / **4.1** Marques | Nom « Tournoi Beach Tennis », sans « FFT », ni logo ni identité visuelle de la FFT. Mention d'indépendance dans l'app et dans la description. Règles décrites comme issues des textes publiés par la FFT, à vérifier avant homologation. |
| **2.3** Métadonnées exactes | Description, mots-clés et captures à partir du texte de `fiche-app-store.md`, qui ne promet que ce que fait l'app. Aucune fonction cachée (2.3.1) : les boutons « Exemple 8/16/32 » sont visibles. Aucune mention d'autres plateformes (2.3.10). |
| **2.1** Version finale | Aucun texte provisoire visible. Identifiant de bundle à remplacer par le tien. |
| **3.1.1** Achats | Aucun achat dans cette version (app gratuite) : rien à implémenter. À prévoir avant tout paiement (achat intégré obligatoire pour débloquer des fonctions). |
| Cible | iPhone seulement (évite les captures iPad), iOS 16 minimum. Chiffrement : `ITSAppUsesNonExemptEncryption = NO`. |
| Accessibilité | Zoom de la page autorisé, boutons de 40 à 52 px, libellés pour lecteur d'écran sur les boutons-icônes, mode sombre. |

## À faire de ton côté avant l'envoi
1. **Compte Apple Developer** (99 €/an) : obligatoire pour TestFlight et l'App Store.
2. **Compiler et tester sur un iPhone réel** : le projet n'a pas pu être compilé ni lancé sur simulateur par moi (Xcode absent de cette machine). Il peut y avoir des erreurs de compilation à corriger. Tester en particulier : import `.xls`, rappels (régler l'heure de départ à +15 min), export PDF, affichage public, couleurs du club.
3. **Héberger la politique de confidentialité** (page web publique, par exemple un lien public pCloud, GitHub Pages ou ton site), remplir les crochets `[…]` (éditeur, e-mail, date), puis coller l'URL dans App Store Connect. Idem pour l'URL d'assistance.
4. **Identifiant de bundle** : remplacer `fr.beachtennis.tournoi` par un identifiant à toi (Signing & Capabilities).
5. **Nom** : vérifier que « Tournoi Beach Tennis » est libre dans App Store Connect (sinon : « Tournoi Beach Tennis Pro », « Planning Tournoi Beach Tennis »…).
6. **Captures d'écran** : 5 captures de l'app réelle aux tailles demandées par App Store Connect.
7. **App Privacy** : « Données non collectées ». **Notes pour la validation** : copier celles de `fiche-app-store.md` et joindre `exemple-inscriptions.xls` en pièce jointe.
8. **TestFlight d'abord** : 1 à 2 semaines avec quelques organisateurs, puis soumission.
9. **FFT** : l'app ne remplace pas leur outil de saisie des résultats ; il est prudent de prévenir la FFT ou ta ligue, et de ne jamais présenter l'app comme officielle.

## Risques résiduels honnêtes
- **4.2** reste une appréciation du relecteur. Le meilleur argument est la valeur d'usage hors ligne et les fonctions natives ; s'il y a un refus, la réponse type est de détailler ces fonctions dans les notes. Un renfort possible : des widgets ou une Live Activity du prochain match.
- **Droits sur l'outil de la FFT** : l'import lit le fichier que l'utilisateur exporte lui-même. Il n'y a ni connexion au site de la FFT ni récupération automatique, ce qui évite la règle 5.2.2 (contenu d'un service tiers).
- **Points de classement et règles** : indicatifs, issus des textes publics de la FFT. Une erreur de règle affichée comme « conforme FFT » pourrait être reprochée (2.3 exactitude). Les badges « Conforme FFT » ont déjà été remplacés par « 3 matchs minimum assurés » ; il reste la section « Règles FFT appliquées » et le cahier des charges, qui citent les textes sources.
