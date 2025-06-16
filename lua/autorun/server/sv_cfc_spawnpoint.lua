resource.AddWorkshop( "3114959065" )

CFC_SpawnPoints = CFC_SpawnPoints or {}

CFC_SpawnPoints.COMMANDS = {
    ["unlinkSpawnPoint"] = {
        ["!unlinkspawn"] = true,
        ["!unlinkspawnpoint"] = true
    },
    ["unlinkThisSpawnPoint"] = {
        ["!unlinkthis"] = true
    }
}

CFC_SpawnPoints.BANNED_TOOLS = {
    ["nocollideeverything"] = true,
    ["nocollide"] = true,
    ["material"] = true,
    ["submaterial"] = true,
    ["fadingdoor"] = true,
    ["fading_door"] = true,
    ["colour"] = true,
}

local COOLDOWN_ON_PLY_SPAWN = CreateConVar( "cfc_spawnpoints_cooldown_on_ply_spawn", 10, { FCVAR_ARCHIVE }, "When a player spawns, they must wait this many seconds before they can create/link spawn points.", 0, 1000 )

local commands = CFC_SpawnPoints.COMMANDS
local bannedTools = CFC_SpawnPoints.BANNED_TOOLS

local spawnOffsetHeight = 16

util.AddNetworkString( "CFC_SpawnPoints_CreationDenied" )
util.AddNetworkString( "CFC_SpawnPoints_LinkDenySound" )
util.AddNetworkString( "CFC_SpawnPoints_CreationCooldownOver" )
util.AddNetworkString( "CFC_SpawnPoints_SetSpawnCooldownEndTime" )
util.AddNetworkString( "CFC_SpawnPoints_SetLastRemovedTime" )
util.AddNetworkString( "CFC_SpawnPoints_SetLinkedSpawnPoint" )


----- GLOBAL FUNCTIONS -----

--- Determines if a given spawnpoint creation attempt should be blocked.
---@param ply Player Player attempting to create a spawnpoint.
---@param data table Spawn info for the spawnpoint. At minimum, contains Pos and Angle.
---@return string|boolean|nil denyReason True or a denial reason if blocked, or nil if allowed.
---@return string? denyReasonID Optional string for identifying denial reasons. Spawn cooldown gives "CFC_SpawnPoints_SpawnCooldown"
function CFC_SpawnPoints.IsCreationBlocked( ply, data )
    -- Let other addons add blockers.
    local denyReason, denyReasonID = hook.Run( "CFC_SpawnPoints_DenyCreation", ply, data )
    if denyReason then return denyReason, denyReasonID end

    -- Enforce spawn cooldown.
    local cooldownEndTime = CFC_SpawnPoints.GetSpawnCooldownEndTime( ply )
    local timeLeft = cooldownEndTime - CurTime()
    if timeLeft <= 0 then return end
    if hook.Run( "CFC_SpawnPoints_IgnorePlayerSpawnCooldown", ply ) == true then return end

    return "You must wait " .. math.ceil( timeLeft ) .. " second(s) before creating a new Spawn Point", "CFC_SpawnPoints_SpawnCooldown"
end


----- SETUP -----

hook.Add( "PlayerSpawn", "SpawnPointHook", function( ply )
    local spawnPoint = CFC_SpawnPoints.GetLinkedSpawnPoint( ply )
    if not IsValid( spawnPoint ) then return end

    if not spawnPoint:IsInWorld() then
        ply:ChatPrint( "Your linked spawn point is in an invalid location" )
        return
    end

    local spawnPos = spawnPoint:GetPos() + Vector( 0, 0, spawnOffsetHeight )
    ply:SetPos( spawnPos )
    spawnPoint:OnSpawnedPlayer( ply )
end )

hook.Add( "PlayerSpawn", "CFC_SpawnPoints_ApplyCooldownFromPlayerSpawn", function( ply )
    local cooldown = COOLDOWN_ON_PLY_SPAWN:GetFloat()

    CFC_SpawnPoints.SetSpawnCooldownEndTime( ply, CurTime() + cooldown )
end )

hook.Add( "CanTool", "CFC_Spawnpoint2_BannedTools", function( ply, tr, tool )
    if not tr.Hit then return end
    if not IsValid( tr.Entity ) then return end
    if tr.Entity:GetClass() ~= "sent_spawnpoint" then return end

    if bannedTools[tool] then
        ply:ChatPrint( string.format( "You cant use '%s' on a spawnpoint", tool ) )
        return false
    end
end )

hook.Add( "PlayerDisconnected", "UnlinkPlayerOnDisconnect", function( ply )
    local spawnPoint = CFC_SpawnPoints.GetLinkedSpawnPoint( ply )
    if not IsValid( spawnPoint ) then return end
    if not spawnPoint.UnlinkPlayer then return end

    spawnPoint:UnlinkPlayer( ply )
end )

hook.Add( "CFC_SpawnPoints_DenyLink", "CFC_SpawnPoints_EnforcePlayerSpawnCooldown", function( _, ply )
    local cooldownEndTime = CFC_SpawnPoints.GetSpawnCooldownEndTime( ply )
    if CurTime() >= cooldownEndTime then return end
    if hook.Run( "CFC_SpawnPoints_IgnorePlayerSpawnCooldown", ply ) == true then return end

    return "You must wait after spawning to make any links."
end )

hook.Add( "CFC_SpawnPoints_DenyLink", "CFC_SpawnPoints_EnforcePointSpawnCooldown", function( spawnPoint, ply )
    local cooldownEndTime = spawnPoint:GetCreationCooldownEndTime()
    if CurTime() >= cooldownEndTime then return end
    if hook.Run( "CFC_SpawnPoints_IgnorePointSpawnCooldown", spawnPoint, ply ) == true then return end

    return "The spawn point is not ready to be linked to yet."
end )

-- Denies linking based on CFC_SpawnPoints.IsFriendly()
hook.Add( "CFC_SpawnPoints_DenyLink", "CFC_SpawnPoints_FriendCheck", function( spawnPoint, ply )
    local friendly, failReason = CFC_SpawnPoints.IsFriendly( spawnPoint, ply )

    if not friendly then return failReason end
end )


----- CHAT COMMANDS -----

hook.Add( "PlayerSay", "UnlinkSpawnPointCommand", function( ply, txt )
    local text = string.lower( txt ):gsub( "%s+", "" ) -- Remove whitespace
    local unlinkSpawnCommands = commands.unlinkSpawnPoint
    if not unlinkSpawnCommands[text] then return end

    local spawnPoint = CFC_SpawnPoints.GetLinkedSpawnPoint( ply )
    if not IsValid( spawnPoint ) then
        ply:PrintMessage( 4, "You are not linked to a Spawn Point" )

        return
    end

    spawnPoint:UnlinkPlayer( ply )
    ply:PrintMessage( 4, "Spawn Point unlinked" )
end )

hook.Add( "PlayerSay", "UnlinkThisSpawnPointCommand", function( ply, txt )
    local text = string.lower( txt ):gsub( "%s+", "" ) -- Remove whitespace
    local unlinkThisSpawnCommands = commands.unlinkThisSpawnPoint
    if not unlinkThisSpawnCommands[text] then return end

    local spawnPoint = ply:GetEyeTraceNoCursor().Entity
    if not IsValid( spawnPoint ) then return end

    if spawnPoint:GetClass() ~= "sent_spawnpoint" then
        ply:PrintMessage( 4, "You must be looking at a Spawn Point to use this command" )

        return
    end

    local owner = CPPI and spawnPoint:CPPIGetOwner() or spawnPoint:GetCreatingPlayer()

    if owner ~= ply and not ply:IsAdmin() then
        ply:PrintMessage( 4, "That's not yours! You can't unlink others from this Spawn Point" )

        return
    end

    spawnPoint:UnlinkAllPlayersExcept( { [owner] = true } )
    ply:PrintMessage( 4, "All players except the owner have been unlinked from this Spawn Point" )
end )
