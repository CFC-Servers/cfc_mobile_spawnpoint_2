CFC_SpawnPoints = CFC_SpawnPoints or {}

if cleanup then
    cleanup.Register( "sent_spawnpoint" )
end

CreateConVar( "sbox_maxsent_spawnpoint", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "The max number of spawn points per player.", 0, 100 )
CreateConVar( "cfc_spawnpoints_cooldown_on_ply_spawn", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "When a player spawns, they must wait this many seconds before they can create/link spawn points.", 0, 1000 )
CreateConVar( "cfc_spawnpoints_cooldown_on_point_spawn", 5, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "When a spawn point is created, it cannot be linked to for this many seconds.", 0, 1000 )
CreateConVar( "cfc_spawnpoints_interact_cooldown", 0.5, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Per-player interaction cooldown for spawn points.", 0, 1000 )
CreateConVar( "cfc_spawnpoints_health_max", 1500, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Max health of spawnpoints. 0 to disable.", 0, 10000 )
CreateConVar( "cfc_spawnpoints_health_regen", 200, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Health regenerated per second by spawnpoints. 0 to disable.", 0, 10000 )
CreateConVar( "cfc_spawnpoints_health_regen_cooldown", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "If a spawnpoint takes damage, it must wait this long before it can start regenerating. 0 to disable.", 0, 10000 )

local REMOVAL_WINDOW = CreateConVar( "cfc_spawnpoints_removal_window", 30, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Player/point cooldowns only apply if a previous spawn point was removed in the past X seconds. 0 to not alter cooldowns.", 0, 1000 )


----- GLOBAL FUNCTIONS -----

--[[
    - Determines whether or not a player is considered 'friendly' to a spawn point.
        - i.e. they can link to it, if no cooldowns or other restrictions block them.
    - Returns friendly, failReason
    - You can override this function in InitPostEntity if you need a different 'friendliness' check.
--]]
function CFC_SpawnPoints.IsFriendly( spawnPoint, ply )
    if not CPPI then
        if spawnPoint:GetCreatingPlayer() == ply then return true end

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

function CFC_SpawnPoints.SetSpawnCooldownEndTime( ply, time )
    ply._cfcSpawnPoints_SpawnCooldownEndTime = time

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

hook.Add( "InitPostEntity", "CFC_SpawnPoints_BlockInvisibility", function()
    local entityMeta = FindMetaTable( "Entity" )

    local setColor = entityMeta.SetColor
    function entityMeta:SetColor( color )
        if color and color.a ~= 255 and self:GetClass() == "sent_spawnpoint" then
            setColor( self, Color( color.r, color.g, color.b, 255 ) )
        else
            setColor( self, color )
        end
    end

    local setMaterial = entityMeta.SetMaterial
    function entityMeta:SetMaterial( material )
        if self:GetClass() == "sent_spawnpoint" then
            setMaterial( self, "" )
        else
            setMaterial( self, material )
        end
    end

    local setSubMaterial = entityMeta.SetSubMaterial
    function entityMeta:SetSubMaterial( index, material )
        if self:GetClass() == "sent_spawnpoint" then
            material = ""
        end

        setSubMaterial( self, index, material )
    end
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
