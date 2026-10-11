# Roblox Server-Side Anti-Cheat

Anti-cheat **côté serveur** pour Roblox (Luau) : sécurisation des `RemoteEvent` / `RemoteFunction`
et détection des mouvements impossibles (speed-hack, téléportation, fly-hack).

## Fonctionnalités

| Module | Rôle |
|---|---|
| `RemoteGuard` | Enveloppe chaque Remote : autorisation, rate limit, cooldown, validation stricte des arguments (types, bornes, NaN/inf, Instances), compteur d'infractions avec kick |
| `MovementMonitor` | Contrôle serveur de la vitesse horizontale, des téléportations et du vol, avec rubber-banding vers la dernière position sûre |
| Honeypot (`Main.server.lua`) | Faux Remote `AdminGiveCash` : quiconque le déclenche (Remote Spy, exécuteur) est kické |

## Installation

**Avec Rojo** : clone le dépôt, puis `rojo serve` (ou `rojo build -o game.rbxlx`).

**À la main** : copie le dossier `src/ServerScriptService/AntiCheat` dans `ServerScriptService`
(`Main.server.lua` = Script, les deux autres = ModuleScripts).

Le dossier `Examples` montre comment sécuriser un achat et une attaque. Supprime-le ou adapte-le.

## Utilisation

```lua
local RemoteGuard = require(path.to.RemoteGuard)
local V = RemoteGuard.Validators

RemoteGuard.OnEvent(myRemoteEvent, {
	rateLimit = 5,
	window = 1,
	cooldown = 0.4,
	authorize = function(player) return player:GetRankInGroup(123) >= 10 end,
	schema = { V.string(32), V.number(0, 100) },
}, function(player, name, amount)
end)
```

Validateurs : `string(maxLen)`, `number(min, max)`, `integer(min, max)`, `boolean()`,
`oneOf(list)`, `instance(className, ancestor?)`, `vector3(maxMagnitude)`, `optional(v)`.

Pour un déplacement légitime géré par ton jeu (téléporteur, dash, knockback) :

```lua
MovementMonitor.Grant(player, 2)
```

Branche `RemoteGuard.OnViolation` et `MovementMonitor.OnViolation` (dans `Main.server.lua`)
sur ton système de logs / bans (DataStore, webhook...).

## Ce que cet anti-cheat ne fait pas (et pourquoi)

- **Protéger `CoreGui` ou empêcher Dex Explorer / Remote Spy de s'exécuter n'est pas possible.**
  Le client appartient au joueur : tout code client (y compris un « anti-cheat » local) peut être
  lu, modifié ou désactivé par un exécuteur. Les scripts locaux de détection sont contournés en
  quelques minutes et donnent une fausse impression de sécurité.
- Ce projet suit donc le seul modèle fiable : **le serveur est l'autorité**. Peu importe que le
  joueur voie vos Remotes ou les spamme : ils ne servent à rien s'ils valident tout côté serveur.

## Bonnes pratiques

1. Le client envoie des **intentions**, jamais des résultats (pas de `GiveMoney(500)`).
2. Prix, dégâts, inventaire, cooldowns : **stockés et calculés sur le serveur**.
3. Revérifie côté serveur la portée, l'état de la cible, la propriété d'un objet, etc.
4. Évite `RemoteFunction:InvokeClient` (un client peut bloquer le thread indéfiniment).
5. Évite les Remotes génériques du type `Fire("action", données)` : un Remote = une action précise.
6. Utilise des **kicks progressifs** et des logs avant de bannir automatiquement, pour limiter les faux positifs (lag).

## Réglages

`RemoteGuard.Config` et `MovementMonitor.Config` exposent les seuils (tolérance de vitesse,
temps max en l'air, seuil de kick...). Ajuste-les selon ton jeu : un jeu avec WalkSpeed variable ou
des véhicules demande une tolérance différente.

## Licence

Ajoute le fichier de licence de ton choix (MIT recommandé pour un projet open source).
