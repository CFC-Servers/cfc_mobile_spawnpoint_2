AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )


----- PRIVATE FUNCTIONS -----

local function isFriendly( ply, otherPly )
    if ply == otherPly then return true end

    local friends = ply:CPPIGetFriends()
    if friends == CPPI.CPPI_DEFER then return false end
    return table.HasValue( friends, otherPly )
end

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

    self:UnlinkAllPlayers( {} )
end

function ENT:Use( ply )
    local playerLinkedToSpawnPoint = ply.LinkedSpawnPoint == self

    if playerLinkedToSpawnPoint then
        self:UnlinkPlayer( ply )
        ply:PrintMessage( 4, "Spawn Point unlinked" )
    else
        local success = self:LinkPlayer( ply )

        if success then
            ply:PrintMessage( 4, "Spawn Point set. Say !unlinkspawn to unlink" )
        else
            ply:PrintMessage( 4, "Unable to set spawnpoint. You are not in the friends or in same faction with the owner.")
        end
    end
end

function ENT:LinkPlayer( ply )
    if not IsValid( ply ) then return end
    if not isFriendly( self:CPPIGetOwner(), ply ) then return end

    ply.LinkedSpawnPoint = self
    self.LinkedPlayers[ply] = "Linked"

    return true
end

function ENT:UnlinkPlayer( ply )
    if not IsValid( ply ) then return end

    ply.LinkedSpawnPoint = nil
    self.LinkedPlayers[ply] = nil
end

function ENT:UnlinkAllPlayers( excludedPlayers )
    local linkedPlayers = self.LinkedPlayers
    local owner = self:CPPIGetOwner()

    for ply, _ in pairs( linkedPlayers ) do
        if IsValid( ply ) then
            local playerIsNotExcluded = excludedPlayers[ply] == nil
            local playerIsNotOwner = owner ~= ply

            if playerIsNotExcluded and playerIsNotOwner then
               self:UnlinkPlayer( ply )
               ply:PrintMessage( 4, "You've been unlinked from a Spawn Point!" )
            end
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
