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

---

# BILUX — NUCLEAR ASCENSION · iOS V4

**Projet source pour iPhone (SwiftUI + HealthKit), non compilé et non signé.**

Ce projet n'est **pas** un fichier .ipa installable. Il faut une compilation Xcode sur un Mac distant (par exemple Codemagic) ou local, la signature Apple et les tests sur un iPhone réel. Un hébergement Netlify ne permet pas de faire fonctionner HealthKit.

## Démarrage sur Mac

1. Décompresser l’archive. Ouvrir `BiluxIOS.xcodeproj` dans Xcode (version actuelle recommandée).
2. Brancher ou associer l’iPhone dans Xcode. Dans le projet > target **BiluxIOS** > **Signing & Capabilities**, activer **Automatically manage signing**, sélectionner ton équipe Apple et utiliser un identifiant d’application unique si nécessaire.
3. Vérifier que **HealthKit** figure bien dans **Signing & Capabilities**, et que `BiluxIOS.entitlements` est attaché au target. La clef `NSHealthShareUsageDescription` est dans `Info.plist`.
4. Choisir l’iPhone comme destination et lancer avec **Run** (▶). Sur iPhone, accepter les demandes de confiance / mode développeur si iOS les affiche.
5. Dans Bilux, toucher « CONNECTER APPLE SANTÉ », puis autoriser les catégories que tu souhaites.

La disponibilité des capacités de signature dépend du type de compte Apple et des réglages de Xcode. Ce dossier ne contient ni certificat, ni profil de signature, ni secrets.

## Synchronisation MyFitnessPal

Sur iPhone, dans **MyFitnessPal** : Profil/Plus > Réglages > Partage et confidentialité > Partage HealthKit, puis autoriser les catégories nutritionnelles. Dans **Santé** > Profil > Apps / Accès aux données, vérifier que MyFitnessPal peut écrire les nutriments et que Bilux peut les lire. L’interface exacte varie selon iOS.

**Le flux est MyFitnessPal → Apple Santé → Bilux.** MyFitnessPal transmet des résumés alimentaires et la plupart des nutriments, pas une synchronisation garantie des aliments individuels ou de l’historique complet. Dans l'application, une source MyFitnessPal détectée est privilégiée pour chaque nutriment afin de limiter les doubles comptes. Les totaux venant d'Apple Santé et les repas manuels Bilux ne sont pas additionnés.

## Importer les données V3

1. Ouvrir la V3 web depuis **la même adresse Safari** où tes données sont stockées.
2. **Avatar > Exporter JSON** et enregistrer le fichier dans Fichiers.
3. Dans l’application native : **Avatar > IMPORTER UNE SAUVEGARDE V3**.
4. Vérifier que le nombre de séances, repas et bilans correspond à ta sauvegarde.

L’import comprend séances, séries réalisées, charges, répétitions, effort perçu, notes, repas, macros, eau, poids et informations de suivi, TSH et **T4L** (nommé `ft4` dans la V3). Les importations identiques évitent les doublons par identifiant V3.

## Modules disponibles

- **QG** : visuel Bilux, XP, niveaux, rangs, transformations symboliques, résumés Apple Santé.
- **Sport** : création libre de séances avec exercices et séries, historique local.
- **Nutrition** : kcal et macros Santé (dont MyFitnessPal si présent), saisie manuelle sans addition entre sources.
- **Santé** : pas, cardio, poids, sommeil ; suivi personnel post-thyroïdectomie, bilans TSH/T4L.
- **Avatar** : suivi RPG, import JSON V3 et export JSON V4.

## Confidentialité et limites

- Aucune requête vers un serveur ajoutée au projet. Les entrées manuelles sont sauvegardées dans le conteneur privé de l’application avec protection iOS des fichiers. HealthKit reste géré par Apple Santé.
- Les **exports JSON sont lisibles sans mot de passe**. Éviter de les placer dans un dossier ou service de partage public.
- Lecture HealthKit seulement, après autorisation. Apple ne permet pas à une app de connaître directement chaque refus d’autorisation de lecture ; une valeur vide n’est pas une preuve d’absence de données.
- La récupération de MyFitnessPal dépend des données effectivement disponibles dans Santé et des autorisations.
- Pas de connexion directe MyFitnessPal, pas de synchronisation cloud Bilux, pas d’exécution HealthKit dans Safari, pas d’interprétation médicale ni d’adaptation de dose.
- **Non testé sur un iPhone réel ni compilé avec Xcode dans cet environnement Linux**. Les fichiers Swift sont vérifiés syntaxiquement et la conversion JSON V3 est testée séparément.

## Architecture

`BiluxApp.swift` — entrée et injection des magasins ; `BiluxScreens.swift` — interface ; `EntryForms.swift` — formulaires ; `BiluxStore.swift` — sauvegarde locale ; `Models.swift` — modèles ; `HealthKitManager.swift` — lectures Santé ; `V3Import.swift` — import JSON web ; `Assets.xcassets` — visuels.
