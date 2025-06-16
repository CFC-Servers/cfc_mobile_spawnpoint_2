AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

local entMeta = FindMetaTable( "Entity" )
local cvarMeta = FindMetaTable( "ConVar" )

local CurTime = CurTime

local COOLDOWN_ON_POINT_SPAWN = CreateConVar( "cfc_spawnpoints_cooldown_on_point_spawn", 5, { FCVAR_ARCHIVE }, "When a spawn point is created, it cannot be linked to for this many seconds.", 0, 1000 )
local INTERACT_COOLDOWN = CreateConVar( "cfc_spawnpoints_interact_cooldown", 0.5, { FCVAR_ARCHIVE }, "Per-player interaction cooldown for spawn points.", 0, 1000 )
local HEALTH_MAX = CreateConVar( "cfc_spawnpoints_health_max", 1500, { FCVAR_ARCHIVE }, "Max health of spawnpoints. 0 to disable.", 0, 10000 )
local HEALTH_REGEN = CreateConVar( "cfc_spawnpoints_health_regen", 200, { FCVAR_ARCHIVE }, "Health regenerated per second by spawnpoints. 0 to disable.", 0, 10000 )
local HEALTH_REGEN_COOLDOWN = CreateConVar( "cfc_spawnpoints_health_regen_cooldown", 10, { FCVAR_ARCHIVE }, "If a spawnpoint takes damage, it must wait this long before it can start regenerating. 0 to disable.", 0, 10000 )

local EFF_SPAWN_COLOR_ANG = Angle( 150, 150, 255 )
local EFF_COOLDOWN_FINISHED_COLOR_ANG = Angle( 150, 255, 150 )
local EFF_REMOVE_COLOR_ANG = Angle( 240, 70, 100 )
local EFF_LINK_COLOR_ANG = Angle( 50, 255, 50 )
local EFF_UNLINK_COLOR_ANG = Angle( 70, 0, 140 )

local REGEN_SOUND = "ambient/levels/canals/manhack_machine_loop1.wav"

local LEGAL_CHECK_INTERVAL = 5
local LEGAL_MATERIAL = ""
local LEGAL_ALPHA = 255
local LEGAL_COLGROUP_MAIN = COLLISION_GROUP_NONE
local LEGAL_COLGROUPS = {
    [COLLISION_GROUP_NONE] = true,
    [COLLISION_GROUP_WORLD] = true,
    [COLLISION_GROUP_PASSABLE_DOOR] = true,
    [COLLISION_GROUP_INTERACTIVE_DEBRIS] = true,
}


----- PRIVATE FUNCTIONS -----


local function miniSpark( pos, scale )
    local effectdata = EffectData()
    effectdata:SetOrigin( pos )
    effectdata:SetNormal( VectorRand() )
    effectdata:SetMagnitude( 3 * scale ) --amount and shoot hardness
    effectdata:SetScale( 1 * scale ) --length of strands
    effectdata:SetRadius( 3 * scale ) --thickness of strands
    util.Effect( "Sparks", effectdata )
end

local function doPointEffect( spawnPoint, colorAng )
    local eff = EffectData()
    eff:SetOrigin( spawnPoint:GetPos() )
    eff:SetAngles( colorAng )
    util.Effect( "spawnpoint_start", eff, true, true )
end

-- If the spawn cooldown stops a creation attempt, notify the player when it's over.
local function notifyWhenSpawnCooldownEnds( ply, data )
    local cooldownEndTime = CFC_SpawnPoints.GetSpawnCooldownEndTime( ply )
    local timeLeft = cooldownEndTime - CurTime()

    timer.Create( "CFC_SpawnPoints_NotifyPlayerSpawnCooldownOver_" .. ply:SteamID(), timeLeft + 0.1, 1, function()
        if not IsValid( ply ) then return end

        -- Don't notify if something is still blocking spawnpoint creation.
        if not CFC_SpawnPoints.IsCreationBlocked( ply, data ) then
            net.Start( "CFC_SpawnPoints_CreationCooldownOver" )
            net.Send( ply )
        end
    end )
end

local function makeSpawnPoint( ply, data )
    local validPly = IsValid( ply )
    if validPly and not ply:CheckLimit( "sent_spawnpoint" ) then return end

    local denyReason, denyReasonID = CFC_SpawnPoints.IsCreationBlocked( ply, data )

    if denyReason then
        denyReason = type( denyReason ) == "string" and denyReason

        net.Start( "CFC_SpawnPoints_CreationDenied" )
        net.WriteString( denyReason or "Failed to create Spawn Point" )
        net.Send( ply )

        if denyReasonID == "CFC_SpawnPoints_SpawnCooldown" then
            notifyWhenSpawnCooldownEnds( ply, data )
        end

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
        ent:SetCreatingPlayer( ply )
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
    self._regenStartTime = 0
    self._lastRegenTime = CurTime()
    self._playingRegenSound = false
    self._nextLegalCheck = 0

    local maxHealth = HEALTH_MAX:GetInt()

    if maxHealth > 0 then
        self:SetMaxHealth( maxHealth )
        self:SetHealth( maxHealth )
    end

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
        phys:EnableDrag( true )
        phys:EnableMotion( false )
    end

    local cooldown = COOLDOWN_ON_POINT_SPAWN:GetFloat()

    self:SetCreationCooldownEndTime( CurTime() + cooldown )

    if cooldown > 0 then
        timer.Simple( cooldown, function()
            if not IsValid( self ) then return end

            -- No need to do the effect if the main owner isn't under point spawn cooldown.
            local owner = CPPI and self:CPPIGetOwner() or self:GetCreatingPlayer()
            if not IsValid( owner ) then return end
            if hook.Run( "CFC_SpawnPoints_IgnorePointSpawnCooldown", self, owner ) then return end

            doPointEffect( self, EFF_COOLDOWN_FINISHED_COLOR_ANG )
            self:EmitSound( "npc/roller/remote_yes.wav", 85, 110 )
        end )
    end

    self:EnforceLegality() -- enforce once on spawn
end

function ENT:OnRemove()
    local atLeastOneLinked = false
    local now = CurTime()

    self:StopSound( REGEN_SOUND )

    for ply in pairs( self._linkedPlayers ) do
        if IsValid( ply ) then
            atLeastOneLinked = true
            CFC_SpawnPoints.SetLastRemovedTime( ply, now )
            break
        end
    end

    if atLeastOneLinked then
        self:EmitSound( "npc/roller/mine/rmine_blades_out2.wav", 90, 90 )
        self:EmitSound( "ambient/machines/catapult_throw.wav", 90, 80 )
        self:EmitSound( "ambient/machines/catapult_throw.wav", 90, 80 )
    end

    doPointEffect( self, EFF_REMOVE_COLOR_ANG )
    self:UnlinkAllPlayers()

    local owner = CPPI and self:CPPIGetOwner() or self:GetCreatingPlayer()

    if IsValid( owner ) then
        CFC_SpawnPoints.SetLastRemovedTime( owner, now )
    end
end

function ENT:Use( ply )
    local interactCooldown = INTERACT_COOLDOWN:GetFloat()

    if interactCooldown > 0 then
        local now = CurTime()
        local nextPlyInteract = ply._nextMobileSpawnInteract or 0

        if nextPlyInteract and nextPlyInteract > now then return end

        ply._nextMobileSpawnInteract = now + interactCooldown
    end

    local isLinked = CFC_SpawnPoints.GetLinkedSpawnPoint( ply ) == self

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
    local oldSpawnPoint = CFC_SpawnPoints.GetLinkedSpawnPoint( ply )
    if oldSpawnPoint == self then return end

    local denyReason = hook.Run( "CFC_SpawnPoints_DenyLink", self, ply )

    if denyReason then
        denyReason = type( denyReason ) == "string" and denyReason or nil

        return false, denyReason
    end

    if IsValid( oldSpawnPoint ) then
        oldSpawnPoint:UnlinkPlayer( ply )
    end

    CFC_SpawnPoints.SetLinkedSpawnPoint( ply, self )
    self._linkedPlayers[ply] = "Linked"

    return true
end

function ENT:UnlinkPlayer( ply )
    if not IsValid( ply ) then return end
    if CFC_SpawnPoints.GetLinkedSpawnPoint( ply ) ~= self then return end

    CFC_SpawnPoints.SetLinkedSpawnPoint( ply, NULL )
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

function ENT:OnDied()
    local boxC = self:WorldSpaceCenter()
    for _ = 1, 6 do
        miniSpark( boxC, math.Rand( 0.5, 1.5 ) )

    end

    util.BlastDamage( self, self, boxC, 120, 5 ) -- 5 damage explosion, practically just fluff

    self:EmitSound( "ambient/fire/gascan_ignite1.wav", 80, math.random( 90, 100 ), 1, CHAN_STATIC )
    self:EmitSound( "npc/scanner/cbot_energyexplosion1.wav", 80, math.random( 120, 130 ), 1, CHAN_STATIC )
end

function ENT:OnSpawnedPlayer()
    self:EmitSound( "items/medshot4.wav", 72, math.random( 120, 130 ), 1, CHAN_ITEM )
end

function ENT:DoHealthRegen( myTbl )
    local maxHealth = entMeta.GetMaxHealth( self )
    if maxHealth <= 0 then return end

    local regen = cvarMeta.GetFloat( HEALTH_REGEN )
    if regen <= 0 then return end

    local now = CurTime()
    if now <= myTbl._regenStartTime then return end

    local health = entMeta.Health( self )
    if health >= maxHealth then return end

    local timeSince = now - myTbl._lastRegenTime

    health = math.min( health + regen * timeSince, maxHealth )

    entMeta.SetHealth( self, health )
    myTbl._lastRegenTime = now

    if health >= maxHealth then
        if myTbl._playingRegenSound then
            myTbl._playingRegenSound = false
            entMeta.StopSound( self, REGEN_SOUND )
            entMeta.EmitSound( self, "ambient/levels/prison/radio_random12.wav", 80, 100 )
        end
    else
        if not myTbl._playingRegenSound then
            myTbl._playingRegenSound = true
            entMeta.EmitSound( self, REGEN_SOUND, 80, 105 )
        end
    end
end

function ENT:EnforceLegality( myTbl )
    myTbl = myTbl or entMeta.GetTable( self )

    if myTbl._nextLegalCheck < CurTime() then return end
    myTbl._nextLegalCheck = CurTime() + LEGAL_CHECK_INTERVAL

    local color = entMeta.GetColor( self )

    if color.a ~= LEGAL_ALPHA then
        color.a = LEGAL_ALPHA
        entMeta.SetColor( self, LEGAL_COLOR )
    end
    if entMeta.GetMaterial( self ) ~= LEGAL_MATERIAL then
        entMeta.SetMaterial( self, LEGAL_MATERIAL )
    end
    if not entMeta.IsSolid( self ) then
        entMeta.SetSolid( self, SOLID_VPHYSICS )
    end
    if not LEGAL_COLGROUPS[entMeta.GetCollisionGroup( self )] then
        entMeta.SetCollisionGroup( self, LEGAL_COLGROUP_MAIN )
    end
end

function ENT:Think()
    local myTbl = entMeta.GetTable( self )
    myTbl.DoHealthRegen( self, myTbl )
    myTbl.EnforceLegality( self, myTbl )
end

function ENT:OnTakeDamage( dmg )
    if self:GetMaxHealth() <= 0 then return end
    if self._dyingSpawnpoint then return end

    local health = self:Health()
    local newHealth = health - dmg:GetDamage()

    if self._playingRegenSound then
        self._playingRegenSound = false
        self:StopSound( REGEN_SOUND )
    end

    if newHealth <= 0 then
        self._dyingSpawnpoint = true
        self:OnDied()
        self:Remove()
    else
        local regenStartTime = CurTime() + HEALTH_REGEN_COOLDOWN:GetFloat()

        self:SetHealth( newHealth )
        self._regenStartTime = regenStartTime
        self._lastRegenTime = regenStartTime
    end
end

function ENT:ACF_PreDamage()
    return false -- Block ACF damage.
end

function ENT:PhysicsUpdate() end

function ENT:PhysicsCollide() end


----- SETUP -----

-- Needed to prevent dupes from bypassing the spawn limit
duplicator.RegisterEntityClass( "sent_spawnpoint", makeSpawnPoint, "Data" )
