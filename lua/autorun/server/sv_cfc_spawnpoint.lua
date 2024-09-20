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

local COOLDOWN_ON_PLY_SPAWN

local commands = CFC_SpawnPoints.COMMANDS
local bannedTools = CFC_SpawnPoints.BANNED_TOOLS

local heightOfSpawnPointPlusOne = 16

util.AddNetworkString( "CFC_SpawnPoints_CreationDenied" )
util.AddNetworkString( "CFC_SpawnPoints_LinkDenySound" )
util.AddNetworkString( "CFC_SpawnPoints_CreationCooldownOver" )


----- SETUP -----

local function localizeConvars()
    COOLDOWN_ON_PLY_SPAWN = GetConVar( "cfc_spawnpoints_cooldown_on_ply_spawn" )
end


hook.Add( "InitPostEntity", "CFC_SpawnPoints_Setup", localizeConvars )
if Entity( 0 ) ~= NULL then localizeConvars() end -- Work with auto-refresh

hook.Add( "PlayerSpawn", "SpawnPointHook", function( ply )
    local spawnPoint = ply:GetNWEntity( "CFC_SpawnPoints_LinkedSpawnPoint" )
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

    ply:SetNWFloat( "CFC_SpawnPoints_SpawnCooldownEndTime", CurTime() + cooldown )
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
    local spawnPoint = ply:GetNWEntity( "CFC_SpawnPoints_LinkedSpawnPoint" )
    if not IsValid( spawnPoint ) then return end
    if not spawnPoint.UnlinkPlayer then return end

    spawnPoint:UnlinkPlayer( ply )
end )

hook.Add( "CFC_SpawnPoints_DenyCreation", "CFC_SpawnPoints_EnforcePlayerSpawnCooldown", function( ply, data )
    local cooldownEndTime = ply:GetNWFloat( "CFC_SpawnPoints_SpawnCooldownEndTime", 0 )

    local timeLeft = cooldownEndTime - CurTime()

    if timeLeft > 0 then
        if hook.Run( "CFC_SpawnPoints_IgnorePlayerSpawnCooldown", ply ) then return end

        -- If this cooldown stops a creation attempt, notify the player when it's over.
        timer.Create( "CFC_SpawnPoints_NotifyPlayerSpawnCooldownOver_" .. ply:SteamID(), timeLeft + 0.1, 1, function()
            if not IsValid( ply ) then return end

            -- Don't notify if something else is still blocking spawnpoint creation.
            if not hook.Run( "CFC_SpawnPoints_DenyCreation", ply, data ) then
                net.Start( "CFC_SpawnPoints_CreationCooldownOver" )
                net.Send( ply )
            end
        end )

        return "You must wait " .. math.ceil( timeLeft ) .. " second(s) before creating a new Spawn Point"
    end
end )

hook.Add( "CFC_SpawnPoints_DenyLink", "CFC_SpawnPoints_EnforcePlayerSpawnCooldown", function( _, ply )
    local cooldownEndTime = ply:GetNWFloat( "CFC_SpawnPoints_SpawnCooldownEndTime", 0 )

    if CurTime() < cooldownEndTime then
        if hook.Run( "CFC_SpawnPoints_IgnorePlayerSpawnCooldown", ply ) then return end

        return "You must wait after spawning to make any links."
    end
end )

hook.Add( "CFC_SpawnPoints_DenyLink", "CFC_SpawnPoints_EnforcePointSpawnCooldown", function( spawnPoint, ply )
    local cooldownEndTime = spawnPoint:GetCreationCooldownEndTime()

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

    local spawnPoint = ply:GetNWEntity( "CFC_SpawnPoints_LinkedSpawnPoint" )
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
