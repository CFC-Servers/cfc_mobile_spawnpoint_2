AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

-- Chat command config
spawnPointCommands = {
    ["unlinkSpawnPoint"] = {
        ["!unlinkspawn"] = true,
        ["!unlinkspawnpoint"] = true
    },
    ["unlinkThisSpawnPoint"] = {
        ["!unlinkthis"] = true
    }
}

-- Helper Functions
function createPlayerList( players )
    local playerList = {}
    for _, ply in pairs( players ) do
        playerList[ply] = true
    end

    return playerList
end

local function isFriendly( ply, otherPly )
    if ply == otherPly then return true end

    local friends = ply:CPPIGetFriends()
    if friends == CPPI.CPPI_DEFER then return false end
    return table.HasValue( friends, otherPly )
end

function linkPlayerToSpawnPoint( ply, spawnPoint )
    if not IsValid( ply ) then return end
    if not IsValid( spawnPoint ) then return end
    if not isFriendly( spawnPoint:CPPIGetOwner(), ply ) then return end

    ply.LinkedSpawnPoint = spawnPoint
    spawnPoint.LinkedPlayers[ply] = "Linked"

    return true
end

function unlinkPlayerFromSpawnPoint( ply, spawnPoint )
    if not IsValid( ply ) then return end
    if not IsValid( spawnPoint ) then return end

    ply.LinkedSpawnPoint = nil
    spawnPoint.LinkedPlayers[ply] = nil
end

function unlinkAllPlayersFromSpawnPoint( spawnPoint, excludedPlayers )
    if not IsValid( spawnPoint ) then return end

    local linkedPlayers = spawnPoint.LinkedPlayers
    local spawnPointOwner = spawnPoint:CPPIGetOwner()

    for ply, _ in pairs( linkedPlayers ) do
        if IsValid( ply ) then
            local playerIsNotExcluded = excludedPlayers[ply] == nil
            local playerIsNotSpawnPointOwner = spawnPointOwner ~= ply

            if playerIsNotExcluded and playerIsNotSpawnPointOwner then
               unlinkPlayerFromSpawnPoint( ply, spawnPoint )
               ply:PrintMessage( 4, "You've been unlinked from a Spawn Point!" )
            end
        end
    end
end

-- Chat commands
function unlinkSpawnPointCommand( ply, txt, _, _ )
    -- Removes whitepace from text
    local text = string.lower( txt ):gsub( "%s+", "" )
    local unlinkSpawnCommands = spawnPointCommands.unlinkSpawnPoint

    if not unlinkSpawnCommands[text] then return end

    local linkedSpawnPoint = ply.LinkedSpawnPoint
    unlinkPlayerFromSpawnPoint( ply, linkedSpawnPoint )
    ply:PrintMessage( 4, "Spawn Point unlinked" )
end
hook.Remove( "PlayerSay", "UnlinkSpawnPointCommand" )
hook.Add( "PlayerSay", "UnlinkSpawnPointCommand", unlinkSpawnPointCommand )

function unlinkThisSpawnPointCommand( ply, txt, _, _ )
    local text = string.lower( txt ):gsub( "%s+", "" )
    local unlinkThisSpawnCommands = spawnPointCommands.unlinkThisSpawnPoint

    if not unlinkThisSpawnCommands[text] then return end

    local targetedEntity = ply:GetEyeTraceNoCursor().Entity
    if not ( targetedEntity and targetedEntity:IsValid() ) then return end

    local isSpawnPoint = targetedEntity:GetClass() == "sent_spawnpoint"
    if not isSpawnPoint then return ply:PrintMessage( 4, "You must be looking at a Spawn Point to use this command" ) end

    local spawnPoint = targetedEntity
    local spawnPointOwner = spawnPoint:CPPIGetOwner()
    local playerOwnsSpawnPoint = spawnPointOwner == ply
    local playerIsAdmin = ply:IsAdmin()

    if not ( playerOwnsSpawnPoint or playerIsAdmin ) then return ply:PrintMessage( 4, "That's not yours! You can't unlink others from this Spawn Point" ) end

    local excludedPlayers = createPlayerList( { spawnPointOwner } )

    unlinkAllPlayersFromSpawnPoint( spawnPoint, excludedPlayers )
    ply:PrintMessage( 4, "All players except the owner have been unlinked from this Spawn Point" )
end

hook.Remove( "PlayerSay", "UnlinkThisSpawnPointCommand" )
hook.Add( "PlayerSay", "UnlinkThisSpawnPointCommand", unlinkThisSpawnPointCommand )


local function unlinkPlayerOnDisconnect( ply )
    local linkedSpawnPoint = ply.LinkedSpawnPoint
    if not linkedSpawnPoint then return end

    unlinkPlayerFromSpawnPoint( ply, linkedSpawnPoint )
end
hook.Remove( "PlayerDisconnected", "UnlinkPlayerOnDisconnect" )
hook.Add( "PlayerDisconnected", "UnlinkPlayerOnDisconnect", unlinkPlayerOnDisconnect )

-- Entity Methods
function ENT:SpawnFunction( _, tr )
    if not tr.Hit then return end
    local SpawnPos = tr.HitPos
    local ent = ents.Create( "sent_spawnpoint" )
    ent:SetPos( SpawnPos )
    ent:Spawn()
    ent:Activate()

    return ent
end

function ENT:Initialize()
    local effectdata1 = EffectData()
    effectdata1:SetOrigin( self:GetPos() )
    util.Effect( "spawnpoint_start", effectdata1, true, true )

    self:SetModel( "models/props_combine/combine_mine01.mdl" )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )
    self.LinkedPlayers = {}

    local phys = self:GetPhysicsObject()
    if not phys:IsValid() then return end

    phys:Wake()
    phys:EnableDrag( true )
    phys:EnableMotion( false )
end

function ENT:OnRemove()
    local effectdata1 = EffectData()
    effectdata1:SetOrigin( self:GetPos() )
    util.Effect( "spawnpoint_start", effectdata1, true, true )

    unlinkAllPlayersFromSpawnPoint( self, {} )
end

function ENT:Use( ply )
    local playerLinkedToSpawnPoint = ply.LinkedSpawnPoint == self

    if playerLinkedToSpawnPoint then
        unlinkPlayerFromSpawnPoint( ply, self )
        ply:PrintMessage( 4, "Spawn Point unlinked" )
    else
        local success = linkPlayerToSpawnPoint( ply, self )

        if success then
            ply:PrintMessage( 4, "Spawn Point set. Say !unlinkspawn to unlink" )
        else
            ply:PrintMessage( 4, "Unable to set spawnpoint. You are not in the friends or in same faction with the owner.")
        end
    end
end

local heightOfSpawnPointPlusOne = 16
local function SpawnPointHook( ply )
    local spawnPoint = ply.LinkedSpawnPoint
    if not spawnPoint or not spawnPoint:IsValid() then return end
    if not spawnPoint:IsInWorld() then
        ply:ChatPrint( "Your linked spawn point is in an invalid location" )
        return
    end

    local spawnPos = spawnPoint:GetPos() + Vector( 0, 0, heightOfSpawnPointPlusOne )
    ply:SetPos( spawnPos )
end
hook.Remove( "PlayerSpawn", "SpawnPointHook" )
hook.Add( "PlayerSpawn", "SpawnPointHook", SpawnPointHook )

local function unlinkSpawnpointWhenEnteringPvp( ply )
    if not IsValid( ply.LinkedSpawnPoint ) then return end
    local linkedSpawnPoint = ply.LinkedSpawnPoint
    unlinkPlayerFromSpawnPoint( ply, linkedSpawnPoint )
    ply:ChatPrint( "You've been unlinked from a Spawn Point, because you entered PvP!" )
end

-- Stubs from here on

function ENT:Think() end

function ENT:OnTakeDamage() end

function ENT:PhysicsUpdate() end

function ENT:PhysicsCollide() end
