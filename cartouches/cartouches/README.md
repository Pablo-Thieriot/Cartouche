# Cartouches compatibles

Application Android hors ligne : correspondance entre imprimantes (HP, Canon, Epson) et cartouches.

## Obtenir l'APK sans rien installer

Le fichier `.github/workflows/build-apk.yml` compile l'APK dans le cloud, gratuitement, depuis un navigateur.

1. Sur github.com, créez un nouveau dépôt (bouton **New**).
2. Ouvrez-le, puis cliquez sur **Add file > Upload files** et envoyez le contenu du dossier décompressé : `pubspec.yaml`, `lib/`, `assets/`, `README.md`.
3. Pour le workflow : **Add file > Create new file**, tapez le nom `.github/workflows/build-apk.yml` (GitHub crée les dossiers tout seul), collez le contenu du fichier, puis **Commit changes**.
4. Ouvrez l'onglet **Actions**, choisissez **Build APK**, attendez 5 à 10 minutes que la coche verte apparaisse.
5. Ouvrez l'exécution terminée, descendez à **Artifacts** et téléchargez `cartouches-apk`.
6. Décompressez, copiez `app-release.apk` sur votre téléphone et installez-le (autorisez l'installation depuis une source inconnue).

## Modifier les données

Les modèles et références sont dans `assets/data/imprimantes.json`. Vérifiez les références sur les sites officiels HP, Canon et Epson avant diffusion. Après une modification, relancez le workflow pour obtenir un nouvel APK.

## Remarque

L'APK produit est signé avec une clé de débogage. Il s'installe normalement sur votre téléphone, mais il ne peut pas être publié sur le Google Play Store.
