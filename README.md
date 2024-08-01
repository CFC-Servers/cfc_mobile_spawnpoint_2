# cfc_mobile_spawnpoint_2
CFC's refactor of the CFC Mobile SpawnPoint 2 


## Server Convars

| Convar | Description | Default |
| :---: | :---: | :---: |
| sbox_maxsent_spawnpoint | The max number of spawn points per player. | 1 |


## Server Hooks

- `denyReason = CFC_SpawnPoints_DenyLink( spawnPoint, ply )`
  - Return true or a string to prevent a player from linking to a spawn point.
  - Returning a string will display it to the player to show why they couldn't do the link.
  - By default, `CFC_SpawnPoints_FriendCheck` will listen to this hook and check CPPI ownership/friend status.
- `denyReason = CFC_SpawnPoints_DenyCreation( ply, data )`
  - Return true or a string to prevent a player from creating a spawn point.
  - Returning a string will display it to the player to show why they couldn't create the spawn point.
  - `data` is a table with keys `Pos` and `Angle`, for where the spawn point will be located.
