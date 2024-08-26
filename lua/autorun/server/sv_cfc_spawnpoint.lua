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
}

local COOLDOWN_ON_PLY_SPAWN

local commands = CFC_SpawnPoints.COMMANDS
local bannedTools = CFC_SpawnPoints.BANNED_TOOLS

local heightOfSpawnPointPlusOne = 16

util.AddNetworkString( "CFC_SpawnPoints_CreationDenied" )
util.AddNetworkString( "CFC_SpawnPoints_LinkDenySound" )


----- GLOBAL FUNCTIONS -----

--[[
    - Determines whether or not a player is considered 'friendly' to a spawn point.
        - i.e. they can link to it, if no cooldowns or other restrictions block them.
    - Returns friendly, failReason
    - You can override this function in InitPostEntity if you need a different 'friendliness' check.
--]]
function CFC_SpawnPoints.IsFriendly( spawnPoint, ply )
    if not CPPI then
        if spawnPoint._spawnPointCreator == ply then return end

        return false, "You can only link to your own Spawn Points."
    end

    local owner = spawnPoint:CPPIGetOwner()
    if ply == owner then return true end

    local friends = owner:CPPIGetFriends()

    if friends == CPPI.CPPI_DEFER then
        return false, "You can only link to your own Spawn Points."
    end

    if table.HasValue( friends, ply ) then return true end

    return false, "You are not buddied with the Spawn Point's owner."
end


----- SETUP -----

hook.Add( "InitPostEntity", "CFC_SpawnPoints_Setup", function()
    COOLDOWN_ON_PLY_SPAWN = GetConVar( "cfc_spawnpoints_cooldown_on_ply_spawn" )
end )

hook.Add( "PlayerSpawn", "SpawnPointHook", function( ply )
    local spawnPoint = ply._linkedSpawnPoint
    if not spawnPoint or not spawnPoint:IsValid() then return end
    if not spawnPoint:IsInWorld() then
        ply:ChatPrint( "Your linked spawn point is in an invalid location" )
        return
    end

    local spawnPos = spawnPoint:GetPos() + Vector( 0, 0, heightOfSpawnPointPlusOne )
    ply:SetPos( spawnPos )
end )

hook.Add( "PlayerSpawn", "CFC_SpawnPoints_ApplyCooldownFromPlayerSpawn", function( ply )
    local cooldown = COOLDOWN_ON_PLY_SPAWN:GetFloat()

    ply._spawnPointCooldownEndTime = CurTime() + cooldown
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
    local spawnPoint = ply._linkedSpawnPoint
    if not IsValid( spawnPoint ) then return end
    if not spawnPoint.UnlinkPlayer then return end

    spawnPoint:UnlinkPlayer( ply )
end )

hook.Add( "CFC_SpawnPoints_DenyCreation", "CFC_SpawnPoints_EnforcePlayerSpawnCooldown", function( ply )
    local cooldownEndTime = ply._spawnPointCooldownEndTime
    if not cooldownEndTime then return end

    if CurTime() < cooldownEndTime then
        if hook.Run( "CFC_SpawnPoints_IgnorePlayerSpawnCooldown", ply ) then return end

        return "You must wait before creating a new Spawn Point"
    end
end )

hook.Add( "CFC_SpawnPoints_DenyLink", "CFC_SpawnPoints_EnforcePlayerSpawnCooldown", function( _, ply )
    local cooldownEndTime = ply._spawnPointCooldownEndTime
    if not cooldownEndTime then return end

    if CurTime() < cooldownEndTime then
        if hook.Run( "CFC_SpawnPoints_IgnorePlayerSpawnCooldown", ply ) then return end

        return "You must wait after spawning to make any links."
    end
end )

hook.Add( "CFC_SpawnPoints_DenyLink", "CFC_SpawnPoints_EnforcePointSpawnCooldown", function( spawnPoint, ply )
    local cooldownEndTime = spawnPoint._spawnPointCooldownEndTime
    if not cooldownEndTime then return end

    if CurTime() < cooldownEndTime then
        if hook.Run( "CFC_SpawnPoints_IgnorePointSpawnCooldown", spawnPoint, ply ) then return end

        return "The spawn point is not ready to be linked to yet."
    end
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

    local spawnPoint = ply._linkedSpawnPoint
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

    local owner = spawnPoint:CPPIGetOwner()

    if owner ~= ply and not ply:IsAdmin() then
        ply:PrintMessage( 4, "That's not yours! You can't unlink others from this Spawn Point" )

        return
    end

    spawnPoint:UnlinkAllPlayersExcept( { [owner] = true } )
    ply:PrintMessage( 4, "All players except the owner have been unlinked from this Spawn Point" )
end )
