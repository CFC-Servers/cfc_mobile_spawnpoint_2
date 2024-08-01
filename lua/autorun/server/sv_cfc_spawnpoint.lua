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

local commands = CFC_SpawnPoints.COMMANDS
local bannedTools = CFC_SpawnPoints.BANNED_TOOLS

local heightOfSpawnPointPlusOne = 16


----- PRIVATE FUNCTIONS -----

local function createPlayerList( players )
    local playerList = {}
    for _, ply in pairs( players ) do
        playerList[ply] = true
    end

    return playerList
end


----- SETUP -----

hook.Add( "PlayerSpawn", "SpawnPointHook", function( ply )
    local spawnPoint = ply.LinkedSpawnPoint
    if not spawnPoint or not spawnPoint:IsValid() then return end
    if not spawnPoint:IsInWorld() then
        ply:ChatPrint( "Your linked spawn point is in an invalid location" )
        return
    end

    local spawnPos = spawnPoint:GetPos() + Vector( 0, 0, heightOfSpawnPointPlusOne )
    ply:SetPos( spawnPos )
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
    local linkedSpawnPoint = ply.LinkedSpawnPoint
    if not IsValid( linkedSpawnPoint ) then return end
    if not linkedSpawnPoint.UnlinkPlayer then return end

    linkedSpawnPoint:UnlinkPlayer( ply )
end )


----- CHAT COMMANDS -----

hook.Add( "PlayerSay", "UnlinkSpawnPointCommand", function( ply, txt, _, _ )
    -- Removes whitepace from text
    local text = string.lower( txt ):gsub( "%s+", "" )
    local unlinkSpawnCommands = commands.unlinkSpawnPoint

    if not unlinkSpawnCommands[text] then return end

    local linkedSpawnPoint = ply.LinkedSpawnPoint
    if not IsValid( linkedSpawnPoint ) then
        ply:PrintMessage( 4, "You are not linked to a Spawn Point" )

        return
    end

    linkedSpawnPoint:UnlinkPlayer( ply )
    ply:PrintMessage( 4, "Spawn Point unlinked" )
end )

hook.Add( "PlayerSay", "UnlinkThisSpawnPointCommand", function( ply, txt, _, _ )
    local text = string.lower( txt ):gsub( "%s+", "" )
    local unlinkThisSpawnCommands = commands.unlinkThisSpawnPoint

    if not unlinkThisSpawnCommands[text] then return end

    local targetedEntity = ply:GetEyeTraceNoCursor().Entity
    if not ( targetedEntity and targetedEntity:IsValid() ) then return end

    local isSpawnPoint = targetedEntity:GetClass() == "sent_spawnpoint"
    if not isSpawnPoint then return ply:PrintMessage( 4, "You must be looking at a Spawn Point to use this command" ) end

    local spawnPoint = targetedEntity
    local spawnPointOwner = spawnPoint:CPPIGetOwner()
    local playerOwnsSpawnPoint = spawnPointOwner == ply
    local playerIsAdmin = ply:IsAdmin()

    if not ( playerOwnsSpawnPoint or playerIsAdmin ) then
        ply:PrintMessage( 4, "That's not yours! You can't unlink others from this Spawn Point" )

        return
    end

    local excludedPlayers = createPlayerList( { spawnPointOwner } )

    spawnPoint:UnlinkAllPlayers( excludedPlayers )
    ply:PrintMessage( 4, "All players except the owner have been unlinked from this Spawn Point" )
end )
