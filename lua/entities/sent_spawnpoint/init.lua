AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )


----- PRIVATE FUNCTIONS -----

local function makeSpawnPoint( ply, data )
    local validPly = IsValid( ply )
    if validPly and not ply:CheckLimit( "sent_spawnpoint" ) then return end

    local ent = ents.Create( "sent_spawnpoint" )
    if not ent:IsValid() then return end

    duplicator.DoGeneric( ent, data )
    ent:Spawn()
    ent:Activate()

    duplicator.DoGenericPhysics( ent, ply, data )

    if validPly then
        ply:AddCount( "sent_spawnpoint", ent )
        ply:AddCleanup( "sent_spawnpoint", ent )
        ent._spawnPointCreator = ply
    end

    return ent
end


----- ENTITY METHODS -----

function ENT:SpawnFunction( ply, tr )
    if not tr.Hit then return end

    local ent = makeSpawnPoint( ply, {
        Pos = tr.HitPos,
        Angle = Angle( 0, 0, 0 ),
    } )

    return ent
end

function ENT:Initialize()
    local eff = EffectData()
    eff:SetOrigin( self:GetPos() )
    util.Effect( "spawnpoint_start", eff, true, true )

    self:SetModel( "models/props_combine/combine_mine01.mdl" )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )
    self._linkedPlayers = {}

    local phys = self:GetPhysicsObject()
    if not phys:IsValid() then return end

    phys:Wake()
    phys:EnableDrag( true )
    phys:EnableMotion( false )
end

function ENT:OnRemove()
    local eff = EffectData()
    eff:SetOrigin( self:GetPos() )
    util.Effect( "spawnpoint_start", eff, true, true )

    self:UnlinkAllPlayers()
end

function ENT:Use( ply )
    local isLinked = ply._linkedSpawnPoint == self

    if isLinked then
        self:UnlinkPlayer( ply )
        ply:PrintMessage( 4, "Spawn Point unlinked" )
    else
        local success, failReason = self:LinkPlayer( ply )

        if success then
            ply:PrintMessage( 4, "Spawn Point set. Say !unlinkspawn to unlink" )
        elseif failReason then
            ply:PrintMessage( 4, "Unable to set spawnpoint. " .. failReason )
        else
            ply:PrintMessage( 4, "Unable to set spawnpoint." )
        end
    end
end

function ENT:LinkPlayer( ply )
    if not IsValid( ply ) then return end
    local oldSpawnPoint = ply._linkedSpawnPoint
    if oldSpawnPoint == self then return end

    local denyReason = hook.Run( "CFC_SpawnPoints_DenyLink", self, ply )

    if denyReason then
        denyReason = type( denyReason ) == "string" and denyReason or nil

        return false, denyReason
    end

    if IsValid( oldSpawnPoint ) then
        oldSpawnPoint:UnlinkPlayer( ply )
    end

    ply._linkedSpawnPoint = self
    self._linkedPlayers[ply] = "Linked"

    return true
end

function ENT:UnlinkPlayer( ply )
    if not IsValid( ply ) then return end
    if ply._linkedSpawnPoint ~= self then return end

    ply._linkedSpawnPoint = nil
    self._linkedPlayers[ply] = nil
end

function ENT:UnlinkAllPlayers()
    for ply, _ in pairs( self._linkedPlayers ) do
        if IsValid( ply ) then
            self:UnlinkPlayer( ply )
            ply:PrintMessage( 4, "You've been unlinked from a Spawn Point!" )
        end
    end
end

function ENT:UnlinkAllPlayersExcept( excludedPlayersLookup )
    for ply, _ in pairs( self._linkedPlayers ) do
        if IsValid( ply ) and not excludedPlayersLookup[ply] then
            self:UnlinkPlayer( ply )
            ply:PrintMessage( 4, "You've been unlinked from a Spawn Point!" )
        end
    end
end

function ENT:Think() end

function ENT:OnTakeDamage() end

function ENT:PhysicsUpdate() end

function ENT:PhysicsCollide() end


----- SETUP -----

-- Needed to prevent dupes from bypassing the spawn limit
duplicator.RegisterEntityClass( "sent_spawnpoint", makeSpawnPoint, "Data" )
