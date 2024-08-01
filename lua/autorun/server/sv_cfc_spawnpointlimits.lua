local limits = {
    sent_basespawnpoint = 1,
    sent_spawnpoint = 2,

}


for name, limit in pairs( limits ) do
    CreateConVar( "sbox_max" .. name, tostring( limit ) )

end

local function playerCanSpawn( ply, class )
    if not limits[ class ] then return end

    local canSpawn = ply:CheckLimit( class )
    if not canSpawn then return false end

end

local function playerSpawnedEnt( ply, ent )
    local class = ent:GetClass()

    if not limits[ class ] then return end
    print( class, ent )

    ply:AddCount( class, ent )

end

hook.Remove( "PlayerSpawnSENT", "mobileSpawn_Limits_CanPlayerSpawn" )
hook.Add( "PlayerSpawnSENT", "mobileSpawn_Limits_CanPlayerSpawn", playerCanSpawn )

hook.Remove( "PlayerSpawnedSENT", "mobileSpawn_Limits_PlayerSpawnedEnt" )
hook.Add( "PlayerSpawnedSENT", "mobileSpawn_Limits_PlayerSpawnedEnt", playerSpawnedEnt )