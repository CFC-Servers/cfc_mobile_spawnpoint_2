CFC_SpawnPoints = CFC_SpawnPoints or {}

if cleanup then
    cleanup.Register( "sent_spawnpoint" )
end

CreateConVar( "sbox_maxsent_spawnpoint", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "The max number of spawn points per player.", 0, 100 )
CreateConVar( "cfc_spawnpoints_cooldown_on_ply_spawn", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "When a player spawns, they must wait this many seconds before they can create/link spawn points.", 0, 1000 )
CreateConVar( "cfc_spawnpoints_cooldown_on_point_spawn", 5, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "When a spawn point is created, it cannot be linked to for this many seconds.", 0, 1000 )

