CFC_SpawnPoints = CFC_SpawnPoints or {}

if cleanup then
    cleanup.Register( "sent_spawnpoint" )
end

CreateConVar( "sbox_maxsent_spawnpoint", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "The max number of spawn points per player.", 0, 100 )
CreateConVar( "cfc_spawnpoints_cooldown_on_ply_spawn", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "When a player spawns, they must wait this many seconds before they can create/link spawn points.", 0, 1000 )
CreateConVar( "cfc_spawnpoints_cooldown_on_point_spawn", 5, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "When a spawn point is created, it cannot be linked to for this many seconds.", 0, 1000 )
CreateConVar( "cfc_spawnpoints_interact_cooldown", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Per-player interaction cooldown for spawn points.", 0, 1000 )


--[[
    - Determines whether or not a player is considered 'friendly' to a spawn point.
        - i.e. they can link to it, if no cooldowns or other restrictions block them.
    - Returns friendly, failReason
    - You can override this function in InitPostEntity if you need a different 'friendliness' check.
--]]
function CFC_SpawnPoints.IsFriendly( spawnPoint, ply )
    if not CPPI then
        if spawnPoint:GetCreatingPlayer() == ply then return end

        return false, "You can only link to your own Spawn Points."
    end

    local owner = spawnPoint:CPPIGetOwner()
    if ply == owner then return true end

    local friends = owner.CPPIGetFriends and owner:CPPIGetFriends()

    if not friends or friends == CPPI.CPPI_DEFER or friends == CPPI.CPPI_NOTIMPLEMENTED then
        return false, "You can only link to your own Spawn Points."
    end

    if table.HasValue( friends, ply ) then return true end

    return false, "You are not buddied with the Spawn Point's owner."
end
