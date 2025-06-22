CFC_SpawnPoints = CFC_SpawnPoints or {}

if cleanup then
    cleanup.Register( "sent_spawnpoint" )
end

CreateConVar( "sbox_maxsent_spawnpoint", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "The max number of spawn points per player.", 0, 100 )

local REMOVAL_WINDOW = CreateConVar( "cfc_spawnpoints_removal_window", 30, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Player/point cooldowns only apply if a previous spawn point was removed in the past X seconds. 0 to not alter cooldowns.", 0, 1000 )


----- GLOBAL FUNCTIONS -----

--- Determines whether or not a player is considered 'friendly' to a spawn point.
--- i.e. they can link to it, if no cooldowns or other restrictions block them.
--- You can return (true/false, denyReason) in the CFC_SpawnPoints_IsFriendly( spawnPoint, owner, ply ) hook to override the default behavior.
--- Must be well-defined in both server and client realms.
---@param spawnPoint Entity The spawn point entity.
---@param ply Player The player.
---@return boolean friendly True if the player is friendly to the spawn point.
---@return string? failReason The reason the player is not friendly to the spawn point, if any.
function CFC_SpawnPoints.IsFriendly( spawnPoint, ply )
    local owner = CPPI and spawnPoint:CPPIGetOwner() or spawnPoint:GetCreatingPlayer()
    local friendlyOverride, reason = hook.Run( "CFC_SpawnPoints_IsFriendly", spawnPoint, owner, ply ) -- true for friendly, false for not

    if friendlyOverride ~= nil then
        return friendlyOverride, reason
    end

    if ply == owner then return true end

    if not CPPI or not IsValid( owner ) then
        return false, "You can only link to your own Spawn Points."
    end

    local friends = owner.CPPIGetFriends and owner:CPPIGetFriends()

    if not friends or friends == CPPI.CPPI_DEFER or friends == CPPI.CPPI_NOTIMPLEMENTED then
        return false, "You can only link to your own Spawn Points."
    end

    if table.HasValue( friends, ply ) then return true end

    return false, "You are not buddied with the Spawn Point's owner."
end

function CFC_SpawnPoints.SetSpawnCooldownEndTime( ply, time )
    ply._cfcSpawnPoints_SpawnCooldownEndTime = math.max( time, ply._cfcSpawnPoints_SpawnCooldownEndTime or 0 )

    if CLIENT then return end

    net.Start( "CFC_SpawnPoints_SetSpawnCooldownEndTime" )
    net.WriteFloat( time )
    net.Send( ply )
end

function CFC_SpawnPoints.GetSpawnCooldownEndTime( ply )
    return ply._cfcSpawnPoints_SpawnCooldownEndTime or 0
end

function CFC_SpawnPoints.SetLastRemovedTime( ply, time )
    ply._cfcSpawnPoints_LastRemovedTime = time

    if CLIENT then return end

    net.Start( "CFC_SpawnPoints_SetLastRemovedTime" )
    net.WriteFloat( time )
    net.Send( ply )
end

function CFC_SpawnPoints.GetLastRemovedTime( ply )
    return ply._cfcSpawnPoints_LastRemovedTime or 0
end

function CFC_SpawnPoints.SetLinkedSpawnPoint( ply, spawnpoint )
    spawnpoint = IsValid( spawnpoint ) and spawnpoint or nil
    ply._cfcSpawnPoints_LinkedSpawnPoint = spawnpoint

    if CLIENT then return end

    net.Start( "CFC_SpawnPoints_SetLinkedSpawnPoint" )
    net.WriteEntity( spawnpoint or game.GetWorld() )
    net.Send( ply )
end

function CFC_SpawnPoints.GetLinkedSpawnPoint( ply )
    return ply._cfcSpawnPoints_LinkedSpawnPoint
end


----- PRIVATE FUNCTIONS -----

local function ignoreCooldownsDueToRemovalWindow( ply )
    if REMOVAL_WINDOW:GetFloat() <= 0 then return false end

    local lastRemoval = CFC_SpawnPoints.GetLastRemovedTime( ply )
    local hasBeenALongTime = CurTime() - lastRemoval > REMOVAL_WINDOW:GetFloat()

    return hasBeenALongTime
end


----- SETUP -----

hook.Add( "CFC_SpawnPoints_IgnorePlayerSpawnCooldown", "CFC_SpawnPoints_RemovalWindow", function( ply )
    if ignoreCooldownsDueToRemovalWindow( ply ) then return true end
end )

hook.Add( "CFC_SpawnPoints_IgnorePointSpawnCooldown", "CFC_SpawnPoints_RemovalWindow", function( _spawnPoint, ply )
    if ignoreCooldownsDueToRemovalWindow( ply ) then return true end
end )


if CLIENT then
    net.Receive( "CFC_SpawnPoints_SetSpawnCooldownEndTime", function()
        CFC_SpawnPoints.SetSpawnCooldownEndTime( LocalPlayer(), net.ReadFloat() )
    end )

    net.Receive( "CFC_SpawnPoints_SetLastRemovedTime", function()
        CFC_SpawnPoints.SetLastRemovedTime( LocalPlayer(), net.ReadFloat() )
    end )

    net.Receive( "CFC_SpawnPoints_SetLinkedSpawnPoint", function()
        CFC_SpawnPoints.SetLinkedSpawnPoint( LocalPlayer(), net.ReadEntity() )
    end )
end
