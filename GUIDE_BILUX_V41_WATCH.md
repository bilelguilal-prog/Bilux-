# BILUX V4.1 — Nuclear Watch (Series 10)

Cette archive est un **projet Xcode source**, pas un fichier déjà compilé et installé.
Elle se base sur le dépôt `Bilux--main` transmis le 14 novembre 2026.

## Contenu livré

- **iPhone :** l'application BILUX existante est conservée, y compris le journal local, la nutrition, les bilans et les écrans.
- **Apple Watch :** nouvelle cible SwiftUI watchOS **monocible** `BiluxWatch`, optimisée pour watchOS 11 ou ultérieur ; 4 écrans (QG, Santé, Quêtes, Sport).
- **Synchronisation :** `WatchConnectivity` envoie un **résumé** de l'iPhone vers la montre (XP, rang, quêtes, statistiques). Pas de transfert de TSH/T4L, de notes médicales, de sauvegardes ou de traitements.
- **Santé sur la montre :** lecture *facultative* depuis HealthKit des pas, de l'énergie active et de la dernière mesure cardiaque, après autorisation ; pas de mesure continue en arrière-plan.
- **Séances :** chronomètre manuel sur la montre et transmission d'une entrée `Séance Apple Watch` au journal de l'iPhone (25 XP par séance effectivement enregistrée, indépendamment des exercices éventuellement présents dans Santé). Aucune séance n'est écrite dans HealthKit ; l'envoi différé peut prendre du temps.
- **Dernier état en cache** sur la montre lorsque l'iPhone est indisponible. Les données peuvent être anciennes ; consulter l'heure de synchronisation.

## Fichiers ajoutés et modifiés

- `BiluxWatch/` — quatre fichiers Swift, Info.plist, entitlements et assets.
- `BiluxShared/WatchSnapshot.swift` — modèle partagé iPhone/Watch.
- `BiluxIOS/WatchPhoneBridge.swift` — échange des données.
- `BiluxIOS/BiluxApp.swift` — initialisation du pont dès le démarrage.
- `BiluxIOS.xcodeproj/project.pbxproj` — véritable **cible watchOS + dépendance + intégration dans l'iPhone**.
- `BiluxIOS.xcodeproj/xcshareddata/xcschemes/BiluxWatch.xcscheme` — schéma Watch.
- `BiluxIOS/Info.plist` — version 1.0, **build 3** (build 2 déjà distribué).
- `BiluxIOS/BiluxScreens.swift` — suppression d’un modificateur de taille dupliqué dans la bannière Avatar, trouvé dans le ZIP reçu.
- `codemagic.yaml` — nouveau workflow de vérification watchOS et intégration TestFlight conservée.
- `create_xcodeproj.py` — ancien générateur protégé pour éviter d'écraser la cible Watch.

## Avant de compiler — Apple Developer

1. **Conserver** l'identifiant iPhone `com.bilux.nuclearascension` et l'application App Store Connect existante.
2. Créer/enregistrer le **nouvel identifiant watchOS** `com.bilux.nuclearascension.watchkitapp` dans Apple Developer > Identifiers, si Codemagic ne peut pas le créer automatiquement ; activer HealthKit pour cette cible.
3. Vérifier que la connexion `BILUX-Codemagic` et les profils de signature de distribution sont disponibles pour **les deux cibles** (iPhone et Watch). Les entitlements HealthKit ne doivent pas être supprimés pour résoudre une erreur de signature.
4. Le numéro de build est **3** sur les deux cibles, avec la version utilisateur 1.0. Apple peut demander à nouveau une déclaration de chiffrement pour le nouveau build.

## Vérification avant TestFlight

1. Déposer les fichiers **extraits** dans le dépôt GitHub en conservant l'arborescence. **Importer le ZIP comme fichier unique dans GitHub ne suffit pas**. Le fichier projet `BiluxIOS.xcodeproj/project.pbxproj` doit être remplacé en entier. Ne pas utiliser `create_xcodeproj.py` pour écraser ce projet.
2. Dans Codemagic, lancer d'abord le workflow **BILUX V4.1 - Verifier Apple Watch (sans signature)**.
3. Puis lancer **BILUX - Verifier le projet iOS (sans Apple Developer)** : doit compiler l'app iPhone **et son app Watch intégrée**.
4. Si les deux compilations réussissent, lancer **BILUX - Publier sur TestFlight** sur `main`. En cas d'erreur de signature/profil watchOS, consulter le log `Appliquer les profils Apple (iPhone et Watch)` et l'identifiant watchkitapp ; ne pas modifier la cible iPhone existante au hasard.
5. Dans App Store Connect, valider les informations manquantes si nécessaire, puis ajouter le build **1.0 (3)** au groupe interne **BILUX — Personnel**.
6. Ouvrir TestFlight sur l'iPhone, installer la mise à jour, puis utiliser l'application Watch de l'iPhone > Général > Installation automatique des apps, ou installer **BILUX Watch** manuellement depuis « Apps disponibles ».

## Première synchronisation et sécurité

- Garder la montre jumelée à l'iPhone ; ouvrir BILUX sur l'iPhone, accorder l'accès Santé, toucher « Actualiser les données Santé ».
- Ouvrir BILUX Watch, écran QG, toucher « Synchroniser ».
- La montre reçoit des **résumés** et non le journal médical. La synchronisation iPhone → montre n'est pas temps réel en permanence.
- Sur la montre, écran Santé, « Lire sur la montre » demande l'accès local à Apple Santé pour les catégories de lecture.
- Une séance de montre est chronométrée et transmise à l'iPhone, mais **ne crée pas d'entraînement Apple Santé**. Ne pas utiliser simultanément les deux journaux pour compter deux fois une même séance.
- L'XP et les quêtes sont calculés par l'iPhone ; ils ne sont **pas diagnostiques ni médicaux**.

## Limitation de validation de cette archive

Les fichiers Swift ont été contrôlés syntaxiquement et le `.pbxproj`/XML/YAML validés dans un environnement Linux. **Aucun Xcode / SDK watchOS n'est installé ici** : la compilation réelle, la signature et l'installation sur Series 10 devront être confirmées dans Codemagic/TestFlight. Un correctif Xcode ultérieur peut être nécessaire selon la version Xcode et les profils de signature disponibles.

Pour revenir au build 2, il suffit de conserver une branche ou une copie du projet d'origine, et de ne pas désinstaller l'application iPhone (ses données sont stockées localement).
