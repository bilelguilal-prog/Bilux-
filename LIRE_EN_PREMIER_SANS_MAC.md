# BILUX — V4 iPhone sans Mac personnel

**Statut : projet SwiftUI + HealthKit prêt à être tenté sur un Mac de compilation hébergé. Ce ZIP n'est PAS une application installable.** Le code n'a pas été compilé ni vérifié sur iPhone réel.

## Ce que contient cette version

- Code natif SwiftUI de Bilux V4, lecture Apple Santé (HealthKit), saisie de séances, nutrition, suivi personnel et import JSON V3.
- `BiluxIOS.xcodeproj` et son **schéma Xcode partagé**.
- `codemagic.yaml` avec deux chemins : une compilation de vérification **sans signature Apple**, puis une construction signée à destination de **TestFlight**.
- Aucun identifiant, certificat, clé Apple ni mot de passe dans le projet.

## 1. D'abord : vérifier le code sans payer Apple

1. Créer un dépôt **privé** GitHub contenant les fichiers du dossier `BILUX_V4_CLOUD_SANS_MAC`, en conservant l'arborescence.
2. Dans [Codemagic](https://codemagic.io/), connecter ce dépôt GitHub et sélectionner **iOS Native** / configuration `codemagic.yaml`.
3. Lancer le workflow `verification-sans-signature`.
4. Examiner le journal de compilation. **Un succès est une vérification de compilation iOS, pas un test HealthKit sur iPhone.** En cas d'erreur, il faut corriger le code avant la distribution.

**Attention sur iPhone uniquement :** créer et transférer l'arborescence d'un dépôt GitHub depuis le navigateur mobile est fastidieux. Un PC Windows facilite cette étape, mais un Mac personnel n'est pas nécessaire.

## 2. Pour installer sur l'iPhone : Apple Developer + TestFlight

1. Adhérer au [programme Apple Developer](https://developer.apple.com/programs/) (99 USD/an ou tarif local affiché). Un simple Apple ID gratuit ne suffit pas à faire signer dans le cloud une app installable par cette méthode.
2. Dans Apple Developer, créer un identifiant d'app unique, correspondant au `PRODUCT_BUNDLE_IDENTIFIER` du projet et au `bundle_identifier` du `codemagic.yaml` ; activer la capacité **HealthKit**.
3. Dans App Store Connect, créer l'enregistrement d'application correspondant et les réglages TestFlight requis.
4. Dans Codemagic, ajouter l'intégration App Store Connect (certificats/profils gérés dans le compte approprié), et **remplacer `bilux_apple`** par son vrai nom dans `codemagic.yaml`.
5. Exécuter `distribution-testflight`. Une fois le traitement Apple et la configuration des testeurs accomplis, installer la bêta via **TestFlight** sur l'iPhone. Il n'est pas nécessaire de publier publiquement sur l'App Store.

La compilation est exécutée sur les Mac distants de Codemagic. Le service de compilation peut aussi appliquer sa propre tarification ou limite d'utilisation.

## 3. Synchroniser MyFitnessPal via Santé

Sur iPhone : dans MyFitnessPal, activer le partage avec Apple Santé et autoriser les nutriments. Ensuite, dans Bilux, donner les permissions Santé demandées. Le transfert concerne les résumés alimentaires et la plupart des nutriments, **pas nécessairement l'historique complet ni chaque aliment**.

## Sécurité et limites

- Utiliser un dépôt GitHub **privé**, ne jamais y publier certificats, mots de passe, clés Apple ni fichiers de données médicales.
- Les données de la V3 doivent être exportées directement sur ton iPhone depuis ta V3 et importées dans la V4 une fois installée ; aucun historique personnel n'est inclus dans le projet.
- Le développement ne nécessite pas Mac personnel, mais un vrai test HealthKit nécessite l'application signée et exécutée sur un vrai iPhone.
- Les données thyroïdiennes ne servent pas à modifier la posologie du traitement.

**Sources techniques :** https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/ ; https://developer.apple.com/programs/ ; https://support.myfitnesspal.com/hc/en-us/articles/360032271092-Apple-Health-connection-and-syncing
