# Sonnette Spéléo

Application web libre de **déclaration des sorties spéléo** avec suivi « sonnette » et alerte secours, conçue par et pour un club de spéléologie. Gratuite à héberger, sans rien à installer pour les membres.

> Sous terre, il n'y a pas de réseau. La **sonnette**, c'est la personne qui reste en surface et qui déclenche les secours si l'équipe ne ressort pas à l'heure convenue. Cette app outille toute la chaîne : déclaration de la sortie, message WhatsApp complet pour la sonnette, suivi entrée/sortie en temps réel, et alerte automatique (email, et WhatsApp en option) si l'heure de secours est dépassée.

## Fonctionnalités

- **Nouvelle sortie** : participants cochés depuis la liste du club (âges et niveaux automatiques), grotte choisie dans les fiches (type, département, GPS de l'entrée, profondeur, durée), véhicules au parking (plusieurs), horaires avec sélecteur à roues façon iPhone. L'heure de secours est proposée automatiquement (sortie prévue + 3 h de délai de grâce), toujours modifiable.
- **Message de sonnette** généré en direct, à copier ou envoyer sur WhatsApp : lieu, point GPS, participants, matériel, plaques, sonnette, heure de déclenchement des secours.
- **Suivi** : « Nous entrons sous terre » / « Nous sommes sortis ! », compte à rebours, et alerte rouge avec la marche à suivre (en France : 112 ou Spéléo Secours Français 0800 121 123, préciser « accident de spéléologie »).
- **Fiches** membres (avec personne à prévenir), grottes et véhicules, réutilisées à chaque sortie. Chaque fiche grotte peut porter des **documents** (topo PDF, photos — 10 Mo max), stockés dans un bucket Supabase Storage privé : visibles par les membres connectés, gérés par l'admin.
- **Règle d'encadrement** : avertissement si la sortie ne compte ni initiateur ni moniteur.
- **Deux niveaux d'accès** : un mot de passe « membre » (déclarer, suivre, consulter les grottes) et un mot de passe « admin » (tout gérer), vérifiés par le serveur.
- **Onglet Alertes (admin)** : activer/désactiver les alertes automatiques email et WhatsApp, choisir les destinataires, et gérer la liste des **canaux d'alerte** (par défaut en France : [ssfalert.fr](https://ssfalert.fr), 112, Spéléo Secours Français 0800 121 123) — la liste alimente la bannière d'alerte, le message de sonnette et les alertes automatiques, et s'adapte à votre pays ou aux outils futurs.
- **Journal infalsifiable** : aucune sortie ne peut être supprimée, une sortie annulée reste archivée.
- **Rappel automatique** (option) : un workflow n8n vérifie toutes les 5 minutes les sorties « sous terre » en dépassement et alerte par email et WhatsApp (via CallMeBot) — une seule fois par sortie.

## Architecture

- `index.html` — l'app complète : une seule page, JavaScript vanilla, aucune dépendance, aucun build. S'installe sur l'écran d'accueil comme une app (PWA).
- [Supabase](https://supabase.com) (offre gratuite) — base de données et authentification. Toute la sécurité est appliquée côté serveur (Row Level Security) : sans mot de passe, la base ne rend rien, et le code de la page ne contient aucun secret exploitable.
- N'importe quel hébergement de fichiers statiques (mutualisé, VPS, Netlify, GitHub Pages…) — il n'y a que `index.html` et `manifest.json` à servir en HTTPS.
- En option : [n8n](https://n8n.io) pour le rappel automatique (`workflow-rappel-sonnette.json`).

## Installation (~30 minutes)

### 1. Créer la base Supabase (gratuit)

1. [supabase.com](https://supabase.com) → **New project** (région EU recommandée pour un club français).
2. Choisissez l'email de votre futur **compte admin** (ex. `sonnette-admin@votreclub.fr` — pas besoin que la boîte existe) et remplacez `admin@example.org` par cet email **aux deux endroits** : dans `schema.sql` (fonction `is_admin`) et dans le bloc `CONFIG` de `index.html`.
3. **SQL Editor** → collez tout `schema.sql` → **Run**.

### 2. Créer les deux comptes et verrouiller

1. **Authentication → Users → Add user** : votre email admin, un mot de passe fort, **Auto Confirm User** coché.
2. Recommencez avec l'email membre (ex. `membre@votreclub.fr`, à reporter dans `CONFIG.MEMBRE_EMAIL`) et le mot de passe qui sera partagé à tous les membres.
3. **Authentication → Sign In / Providers** : désactivez **« Allow new users to sign up »** (indispensable : sinon n'importe qui peut se créer un compte).

### 3. Configurer et mettre en ligne l'app

1. Dans `index.html`, bloc `CONFIG` en haut du `<script>` : `SUPABASE_URL` et `SUPABASE_ANON_KEY` (Project Settings → Data API et API Keys), les deux emails, et le nom de votre club (`CLUB`).
2. Déposez `index.html` et `manifest.json` sur votre hébergement, servi en HTTPS (un sous-domaine dédié est pratique : `sonnette.votreclub.fr`).
3. Ouvrez le site, connectez-vous avec un des deux mots de passe : l'app détecte le rôle toute seule. Ajoutez vos membres, grottes et véhicules (onglets admin).

### 4. (Option) Rappel automatique par email et WhatsApp

1. Dans `workflow-rappel-sonnette.json`, remplacez les valeurs `VOTRE-PROJET`, `EXPEDITEUR@example.org` et `VOTRE-SITE-SONNETTE.example.org`.
2. Dans n8n, créez un credential **Header Auth** (Credentials → Add credential) : Name `apikey`, Value la **clé secrète** de votre projet Supabase (Project Settings → API Keys, clé `sb_secret_…`), telle quelle, sans préfixe. Elle ne sort jamais de n8n et n'apparaît dans aucun fichier. (Les clés `sb_secret_…` ne sont pas des JWT : Supabase les attend dans l'en-tête `apikey`, pas dans `Authorization`.)
3. **Import from File**, puis attachez ce credential aux nœuds « Reglages alertes », « Canaux d'alerte », « Sorties sous terre », « Membres alerte » et « Marquer alertee », choisissez votre credential SMTP sur « Email d'alerte », et activez. Les destinataires des emails et l'activation des branches email/WhatsApp se règlent ensuite directement dans l'app (onglet Alertes).
3. Pour la branche WhatsApp : chaque personne du cercle d'alerte s'enregistre sur [CallMeBot](https://www.callmebot.com/blog/free-api-whatsapp-messages/) (gratuit, une fois) et l'admin colle sa clé dans sa fiche membre, champ « Clé CallMeBot ». Le workflow lit les clés directement dans la base. Conseil : réservez l'alerte à un petit cercle (initiateurs, sonnettes habituelles) — une alerte reçue par peu de gens qui savent quoi faire vaut mieux qu'une liste de diffusion.

## Sécurité — le modèle

- Les mots de passe sont vérifiés par Supabase (jamais dans la page) ; sans connexion, la base ne rend aucune donnée, en lecture comme en écriture.
- Les inscriptions sont désactivées : seuls les deux comptes créés existent.
- Les droits admin/membre sont appliqués par des policies SQL (`is_admin()`), pas seulement masqués à l'écran.
- Les sorties ne peuvent jamais être supprimées (journal de sécurité).
- La clé « anon/publishable » visible dans la page est prévue pour être publique : elle ne donne accès à rien sans authentification.

## Avertissement

Cette application est une **aide à l'organisation**, pas un dispositif de secours certifié. La sonnette humaine, les procédures de votre club et de votre fédération, et le bon sens restent la référence. Fournie telle quelle, sans garantie (licence MIT).

## Crédits

Conçu par **Gaël Genard** (Spéléo Club de Vienne) et son papa. Les numéros d'urgence cités (112, Spéléo Secours Français) concernent la France : adaptez-les à votre pays dans `index.html` et le workflow si besoin.
