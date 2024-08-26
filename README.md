# cfc_mobile_spawnpoint_2
CFC's refactor of the CFC Mobile SpawnPoint 2 


## Server Convars

| Convar | Description | Default |
| :---: | :---: | :---: |
| sbox_maxsent_spawnpoint | The max number of spawn points per player. | 1 |
| cfc_spawnpoints_cooldown_on_ply_spawn | When a player spawns, they must wait this many seconds before they can create/link spawn points. | 10 |
| cfc_spawnpoints_cooldown_on_point_spawn | When a spawn point is created, it cannot be linked to for this many seconds. | 5 |
| cfc_spawnpoints_interact_cooldown | Per-player interaction cooldown for spawn points. | 1 |


## Shared Functions

- `friendly, failReason = CFC_SpawnPoints.IsFriendly( spawnPoint, ply )`
  - Determines if a player is 'friendly' with a spawn point.
    - i.e. they can link to it, if no cooldowns or other restrictions block them.
  - You can override this during the `InitPostEntity` hook if you need a different check (e.g. a squad/faction system).
    - Be sure to override it in both the server and client realms.
  - Unfriendly players will automatically be denied from using the spawn point.


## Server Hooks

- `denyReason = CFC_SpawnPoints_DenyLink( spawnPoint, ply )`
  - Return true or a string to prevent a player from linking to a spawn point.
  - Returning a string will display it to the player to show why they couldn't do the link.
- `denyReason = CFC_SpawnPoints_DenyCreation( ply, data )`
  - Return true or a string to prevent a player from creating a spawn point.
  - Returning a string will display it to the player to show why they couldn't create the spawn point.
  - `data` is a table with keys `Pos` and `Angle`, for where the spawn point will be located.


## Shared Hooks

- `ignoreCooldown = CFC_SpawnPoints_IgnorePlayerSpawnCooldown( ply )`
  - Allow a player to ignore the spawn point creation/linking cooldown from the player spawning in.
  - For example, make builders ignore it if you have a build/pvp system.
- `ignoreCooldown = CFC_SpawnPoints_IgnorePointSpawnCooldown( spawnPoint, ply )`
  - Allow a player to ignore the linking cooldown of a recently-spawned spawn point.
  - For example, make builders ignore it if you have a build/pvp system.
