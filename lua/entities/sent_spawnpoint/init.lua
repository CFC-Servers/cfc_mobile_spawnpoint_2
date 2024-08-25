AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

local COOLDOWN_ON_POINT_SPAWN
local INTERACT_COOLDOWN

local EFF_SPAWN_COLOR_ANG = Angle( 150, 150, 255 )
local EFF_COOLDOWN_FINISHED_COLOR_ANG = Angle( 150, 255, 150 )
local EFF_REMOVE_COLOR_ANG = Angle( 240, 70, 100 )
local EFF_LINK_COLOR_ANG = Angle( 50, 255, 50 )
local EFF_UNLINK_COLOR_ANG = Angle( 70, 0, 140 )


----- PRIVATE FUNCTIONS -----

local function doPointEffect( spawnPoint, colorAng )
    local eff = EffectData()
    eff:SetOrigin( spawnPoint:GetPos() )
    eff:SetAngles( colorAng )
    util.Effect( "spawnpoint_start", eff, true, true )
end

local function makeSpawnPoint( ply, data )
    local validPly = IsValid( ply )
    if validPly and not ply:CheckLimit( "sent_spawnpoint" ) then return end

    local denyReason = hook.Run( "CFC_SpawnPoints_DenyCreation", ply, data )

    if denyReason then
        denyReason = type( denyReason ) == "string" and denyReason

        net.Start( "CFC_SpawnPoints_CreationDenied" )
        net.WriteString( denyReason or "Failed to create Spawn Point" )
        net.Send( ply )

        return
    end

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

    local pos = tr.HitPos
    local ent = makeSpawnPoint( ply, {
        Pos = pos,
        Angle = Angle( 0, 0, 0 ),
    } )

    -- Forcefully set the position next tick, as gmod's TryFixPropPosition() breaks with the combine mine model.
    timer.Simple( 0, function()
        if not IsValid( ent ) then return end

        ent:SetPos( pos )
    end )

    return ent
end

function ENT:Initialize()
    doPointEffect( self, EFF_SPAWN_COLOR_ANG )

    self:SetModel( "models/props_combine/combine_mine01.mdl" )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )
    self._linkedPlayers = {}
    self._interactCooldownEndTimes = {}

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
        phys:EnableDrag( true )
        phys:EnableMotion( false )
    end

    local cooldown = COOLDOWN_ON_POINT_SPAWN:GetFloat()

    self._spawnPointCooldownEndTime = CurTime() + cooldown

    if cooldown > 0 then
        timer.Simple( cooldown, function()
            if not IsValid( self ) then return end

            doPointEffect( self, EFF_COOLDOWN_FINISHED_COLOR_ANG )
            self:EmitSound( "npc/roller/remote_yes.wav", 85, 110 )
        end )
    end
end

function ENT:OnRemove()
    local atLeastOneLinked = false

    for ply in pairs( self._linkedPlayers ) do
        if IsValid( ply ) then
            atLeastOneLinked = true
            break
        end
    end

    if atLeastOneLinked then
        self:EmitSound( "npc/roller/mine/rmine_blades_out2.wav", 90, 90 )
    end

    doPointEffect( self, EFF_REMOVE_COLOR_ANG )
    self:UnlinkAllPlayers()
end

function ENT:Use( ply )
    local interactCooldown = INTERACT_COOLDOWN:GetFloat()

    if interactCooldown > 0 then
        local now = CurTime()
        local endTimes = self._interactCooldownEndTimes
        local plyEndTime = endTimes[ply]

        if plyEndTime and plyEndTime > now then return end

        endTimes[ply] = now + interactCooldown
    end

    local isLinked = ply._linkedSpawnPoint == self

    if isLinked then
        -- Unlink
        self:UnlinkPlayer( ply )
        self:EmitSound( "npc/dog/dog_disappointed.wav", 85, 90 )
        doPointEffect( self, EFF_UNLINK_COLOR_ANG )
        ply:PrintMessage( 4, "Spawn Point unlinked" )
    else
        local success, failReason = self:LinkPlayer( ply )

        if success then
            -- Link
            self:EmitSound( "buttons/button17.wav", 85, 90 )
            doPointEffect( self, EFF_LINK_COLOR_ANG )
            ply:PrintMessage( 4, "Spawn Point set. Say !unlinkspawn to unlink" )
        else
            -- Link Failed
            net.Start( "CFC_SpawnPoints_LinkDenySound" )
            net.Send( ply )

            if failReason then
                ply:PrintMessage( 4, "Unable to set spawnpoint. " .. failReason )
            else
                ply:PrintMessage( 4, "Unable to set spawnpoint." )
            end
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
    for ply in pairs( self._linkedPlayers ) do
        if IsValid( ply ) then
            self:UnlinkPlayer( ply )
            ply:PrintMessage( 4, "You've been unlinked from a Spawn Point!" )
        end
    end
end

function ENT:UnlinkAllPlayersExcept( excludedPlayersLookup )
    for ply in pairs( self._linkedPlayers ) do
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

hook.Add( "InitPostEntity", "CFC_SpawnPoints_SentSpawnPoint_Setup", function()
    COOLDOWN_ON_POINT_SPAWN = GetConVar( "cfc_spawnpoints_cooldown_on_point_spawn" )
    INTERACT_COOLDOWN = GetConVar( "cfc_spawnpoints_interact_cooldown" )
end )
