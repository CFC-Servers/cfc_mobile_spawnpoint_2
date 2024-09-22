AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

util.AddNetworkString( "CFC_spawnpoints_linkedtospawn" )

local HUD_PRINTCENTER = HUD_PRINTCENTER

-- commands


local defaultRespawnLinkDelay = 5
desc = "Delay until a player can link to a spawnpoint, after respawning, -1 for default (" .. tostring( defaultRespawnLinkDelay ) .. ")"

local respawnLinkDelayVar = CreateConVar( "cfc_mobilespawn_respawnlinkdelay", -1, FCVAR_ARCHIVE, desc )
local function respawnLinkDelay()
    local var = respawnLinkDelayVar:GetFloat()
    if var <= -1 then
        return defaultRespawnLinkDelay

    else
        return var

    end
end
hook.Add( "PlayerSpawn", "cfc_mobilespawns_respawnlinkdelay", function( spawned )
    spawned.cfc_MobileSpawns_JustSpawnedBlock = CurTime() + respawnLinkDelay()

end )


local defaultSpawnHealth = 50
desc = "Health of the spawnpoints, -1 for default (" .. tostring( defaultSpawnHealth ) .. ")"

local spawnHealthVar = CreateConVar( "cfc_mobilespawn_spawnhealth", -1, FCVAR_ARCHIVE, desc )
local function spawnPointHealth()
    local var = spawnHealthVar:GetFloat()
    if var <= -1 then
        return defaultSpawnHealth

    else
        return var

    end
end


local defaultMaxShieldHealth = 1000
desc = "Max health of the spawnpoint's shield, -1 for default (" .. tostring( defaultMaxShieldHealth ) .. ")"

local maxShieldHealthVar = CreateConVar( "cfc_mobilespawn_shield_maxhp", -1, FCVAR_ARCHIVE, desc )
local function maxShieldHealth()
    local var = maxShieldHealthVar:GetFloat()
    if var <= -1 then
        return defaultMaxShieldHealth

    else
        return var

    end
end
function ENT:MaxShieldHealth()
    return maxShieldHealth()

end


local defaultShieldRegen = 50
desc = "Shield health regenerated every 1s, -1 for default (" .. tostring( defaultShieldRegen ) .. ")"

local shieldRegenVar = CreateConVar( "cfc_mobilespawn_shield_regen", -1, FCVAR_ARCHIVE, desc )
local function shieldRegen()
    local var = shieldRegenVar:GetFloat()
    if var <= -1 then
        return defaultShieldRegen

    else
        return var

    end
end
function ENT:ShieldHealthRegen()
    return shieldRegen()

end


-- util funcs

local function unlinkPlayerFromSpawnPoint( ply, spawnPoint )
    if not IsValid( ply ) then return end
    if not IsValid( spawnPoint ) then return end

    ply.LinkedSpawnPoint = nil
    spawnPoint.LinkedPlayers[ply] = nil
    spawnPoint:DoQuietSound( "npc/roller/code2.wav" )

end

local function linkPlayerToSpawnPoint( ply, spawnPoint )
    if not IsValid( ply ) then return end
    if not IsValid( spawnPoint ) then return end
    if not spawnPoint:PlysAreFriendly( spawnPoint:GetCreator(), ply ) then return end
    if IsValid( ply.LinkedSpawnPoint ) then
        unlinkPlayerFromSpawnPoint( ply, ply.LinkedSpawnPoint )

    end

    ply.LinkedSpawnPoint = spawnPoint
    spawnPoint.LinkedPlayers[ply] = "Linked"

    return true
end

local function unlinkAllPlayersFromSpawnPoint( spawnPoint, excludedPlayers, reason )
    if not IsValid( spawnPoint ) then return end

    reason = reason or "You've been unlinked from a Spawn Point!"
    local linkedPlayers = spawnPoint.LinkedPlayers

    for ply, _ in pairs( linkedPlayers ) do
        if IsValid( ply ) then
            local playerIsNotExcluded = excludedPlayers[ply] == nil

            if playerIsNotExcluded then
               unlinkPlayerFromSpawnPoint( ply, spawnPoint )
               ply:PrintMessage( HUD_PRINTCENTER, reason )
            end
        end
    end
end

local function displayMessageToAllSpawners( spawnPoint, message )
    if not IsValid( spawnPoint ) then return end
    local linkedPlayers = spawnPoint.LinkedPlayers

    for ply, _ in pairs( linkedPlayers ) do
        if IsValid( ply ) then
            ply:PrintMessage( HUD_PRINTCENTER, message )
        end
    end
end


local function unlinkPlayerOnDisconnect( ply )
    local linkedSpawnPoint = ply.LinkedSpawnPoint
    if not linkedSpawnPoint then return end

    unlinkPlayerFromSpawnPoint( ply, linkedSpawnPoint )
end
hook.Remove( "PlayerDisconnected", "UnlinkPlayerOnDisconnect" )
hook.Add( "PlayerDisconnected", "UnlinkPlayerOnDisconnect", unlinkPlayerOnDisconnect )

-- sound/effect funcs

local function miniSpark( pos, scale )
    local effectdata = EffectData()
    effectdata:SetOrigin( pos )
    effectdata:SetNormal( VectorRand() )
    effectdata:SetMagnitude( 3 * scale ) --amount and shoot hardness
    effectdata:SetScale( 1 * scale ) --length of strands
    effectdata:SetRadius( 3 * scale ) --thickness of strands
    util.Effect( "Sparks", effectdata )

end

function ENT:SpawnpointLightsEffect( scale )
    local effData = EffectData()
    effData:SetOrigin( self:LocalToWorld( self.SpawnpointFxOffset ) )
    effData:SetScale( scale )
    util.Effect( "spawnpoint_start", effData )
end

-- play a really obvious sound the first time someone sets their spawn as me
function ENT:DoFirstTimeSetupFX( _ )
    -- ignore PAS
    local filterAllPlayers = RecipientFilter()
    filterAllPlayers:AddAllPlayers()
    self:EmitSound( "npc/roller/mine/combine_mine_deactivate1.wav", 80, math.random( 110, 120 ), 1, CHAN_STATIC, nil, nil, filterAllPlayers )

end

function ENT:DoSpawningFX( _ )
    self:SpawnpointLightsEffect( 2 )

    self:EmitSound( "npc/scanner/combat_scan2.wav", 72, math.random( 110, 140 ), 1, CHAN_STATIC )
    self:EmitSound( "items/medshot4.wav", 72, math.random( 120, 130 ), 1, CHAN_ITEM )

end

function ENT:DoBreakFX()
    local breakPos = self:SpawnpointMassCenter()
    for _ = 1, 6 do
        miniSpark( breakPos, math.Rand( 0.5, 1.5 ) )

    end

    util.BlastDamage( self, self, breakPos, 120, 5 )

    self:EmitSound( "ambient/fire/gascan_ignite1.wav", 80, math.random( 90, 100 ), 1, CHAN_STATIC )
    self:EmitSound( "npc/scanner/cbot_energyexplosion1.wav", 80, math.random( 120, 130 ), 1, CHAN_STATIC )

end

function ENT:DoQuietSound( path )
    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        self:EmitSound( path, 70, math.Rand( 110, 120 ), 1, CHAN_ITEM )

    end )
end


local shieldReflect = {
    "weapons/physcannon/superphys_small_zap1.wav",
    "weapons/physcannon/superphys_small_zap2.wav",
    "weapons/physcannon/superphys_small_zap3.wav",
    "weapons/physcannon/superphys_small_zap4.wav",
    "weapons/physcannon/energy_bounce1.wav",
    "weapons/physcannon/energy_bounce2.wav",

}

function ENT:ShieldReflectFX()
    self:EmitSound( shieldReflect[math.random( 1, #shieldReflect )], 70, math.random( 120, 140 ), 1, CHAN_BODY )
    util.ScreenShake( self:WorldSpaceCenter(), 1, 10, 0.1, 1000 )

end


local regenerateSounds = {
    "weapons/physcannon/superphys_small_zap1.wav",
    "weapons/physcannon/superphys_small_zap2.wav",
    "weapons/physcannon/superphys_small_zap3.wav",
    "weapons/physcannon/superphys_small_zap4.wav",

}

function ENT:ShieldRegenFX()
    self:EmitSound( regenerateSounds[math.random( 1, #regenerateSounds )], 65, math.random( 80, 90 ), 1, CHAN_BODY )

end

function ENT:OnDamagedFX()
    local sparkPos = self:SpawnpointMassCenter()
    timer.Simple( 0, function()
        miniSpark( sparkPos, 1 )

    end )

    if self.SpawnpointHealth <= 0 then
        self:Break()
        return

    else
        if self.nextDamageWhine < CurTime() then
            self.nextDamageWhine = CurTime() + 0.75
            self:EmitSound( "npc/roller/mine/rmine_blip3.wav", 78, math.random( 110, 120 ), 1, CHAN_STATIC )

        end
        self:EmitSound( "Computer.BulletImpact" )
        self:EmitSound( "physics/metal/metal_canister_impact_hard" .. math.random( 1, 3 ) .. ".wav", 75, math.random( 110, 120 ), 1, CHAN_STATIC )

    end
end

-- entity vars

ENT.PlayerSpawnOffset = Vector( 0, 0, 0 )
ENT.PlayerSpawnOffsetWorld = Vector( 0, 0, 16 )
ENT.SpawnpointFxOffset = Vector( 0, 0, 0 )

ENT.ShieldRegenDelay = 10
ENT.LegalMaxs = 20
ENT.SpawnpointModel = "models/props_combine/combine_mine01.mdl"

-- Entity Methods
function ENT:SpawnFunction( spawner, tr )
    if not tr.Hit then return end
    local spawnPos = tr.HitPos
    local spawnAng = Angle( 0, spawner:EyeAngles().y, 0 )
    local ent = ents.Create( "sent_spawnpoint" )
    ent:SetCreator( spawner )
    ent:SetPos( spawnPos + -tr.HitNormal )
    ent:SetAngles( spawnAng )
    ent:Spawn()
    ent:Activate()

    return ent
end

function ENT:ResetData()
    self:SetShielded( false )
    self:SetShieldHealth( 0 )
    self:SetShieldOn( true )
    self:SetShieldSetupTime( 0 )

end

function ENT:Initialize()

    self:ResetData()

    self.SpawnpointHealth = spawnPointHealth()
    self.nextDamageWhine = 0
    self.nextLinkedFX = 0

    self:SetTrigger( true )

    self:SetModel( self.SpawnpointModel )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )
    self.LinkedPlayers = {}

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:Wake()
        phys:EnableDrag( true )
        phys:EnableMotion( false )

    end

    local effData = EffectData()
    effData:SetOrigin( self:LocalToWorld( self.SpawnpointFxOffset ) )
    effData:SetScale( 0.5 )
    util.Effect( "spawnpoint_start", effData )

    self:MakeLegal()

    hook.Run( "CFC_MobileSpawn_CreatedSpawn", self )
end

function ENT:OnRemove()
    local effData = EffectData()
    effData:SetOrigin( self:LocalToWorld( self.SpawnpointFxOffset ) )
    effData:SetScale( 1 )
    util.Effect( "spawnpoint_start", effData )

    local message = "Your linked spawnpoint was removed."
    if self.spawnpointBroken then
        message = "Your linked spawnpoint died."

    end

    unlinkAllPlayersFromSpawnPoint( self, {}, message )
end

function ENT:SpawnpointMassCenter()
    local obj = self:GetPhysicsObject()
    if not IsValid( obj ) then return self:WorldSpaceCenter() end
    return self:LocalToWorld( obj:GetMassCenter() )

end

function ENT:Use( ply )
    self:TryToLink( ply )

end

function ENT:TryToLink( ply )
    if not IsValid( ply ) then return end
    if not ply:IsPlayer() then return end

    self.nextLinkedFX = CurTime() + 5

    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        self:SpawnpointLightsEffect( 0.5 )

    end )

    local playerLinkedToSpawnPoint = ply.LinkedSpawnPoint == self

    if playerLinkedToSpawnPoint and not enableOnly then
        unlinkPlayerFromSpawnPoint( ply, self )
        ply:PrintMessage( HUD_PRINTCENTER, "Spawn Point unlinked" )
        return

    elseif not playerLinkedToSpawnPoint then
        local is, _, reason = self:IsIllegal()
        if is then
            self:MakeLegal()
            self:DoQuietSound( "npc/roller/code2.wav" )
            ply:PrintMessage( HUD_PRINTCENTER, "Can't link to this because...\n" .. reason )
            return

        end

        if ply.cfc_MobileSpawns_JustSpawnedBlock > CurTime() then
            local untilTime = math.abs( ply.cfc_MobileSpawns_JustSpawnedBlock - CurTime() )
            untilTime = math.Round( untilTime, 1 )

            self:DoQuietSound( "npc/roller/code2.wav" )
            ply:PrintMessage( HUD_PRINTCENTER, "You just respawned.\nCan link to spawns in... " .. untilTime .. " seconds." )
            return

        end

        local success = linkPlayerToSpawnPoint( ply, self )

        if success then
            if not self.SetupFirstTime then
                self.SetupFirstTime = true
                self:DoFirstTimeSetupFX( ply )

            end
            self:DoQuietSound( "npc/roller/remote_yes.wav" )
            ply:PrintMessage( HUD_PRINTCENTER, "Spawn Point set." )
            net.Start( "CFC_spawnpoints_linkedtospawn", true )
            net.Send( ply )
            return

        elseif not enableOnly then
            self:DoQuietSound( "npc/roller/code2.wav" )
            ply:PrintMessage( HUD_PRINTCENTER, "Unable to set spawnpoint. You are not in the same squad as the owner." )
            return

        end
    end
end

-- where respawned players are placed
function ENT:RespawnPos()
    return self:LocalToWorld( self.PlayerSpawnOffset ) + self.PlayerSpawnOffsetWorld

end

-- respawns people at the spawn

local function SpawnPointHook( ply )
    local spawnPoint = ply.LinkedSpawnPoint
    if not spawnPoint or not spawnPoint:IsValid() then return end
    if spawnPoint:IsIllegal() then return end

    local spawnPos = spawnPoint:RespawnPos()
    ply:SetPos( spawnPos )

    spawnPoint:DoSpawningFX( ply )
    spawnPoint.nextLinkedFX = CurTime() + 5

end

hook.Remove( "PlayerSpawn", "SpawnPointHook" )
hook.Add( "PlayerSpawn", "SpawnPointHook", SpawnPointHook )

-- legality

local legalMaterial = ""
local legalColor = Color( 255, 255, 255, 255 )

function ENT:MakeLegal()
    self:SetMaterial( legalMaterial )
    for ind = 0, #self:GetMaterials() do
        self:SetSubMaterial( ind, legalMaterial )

    end
    self:SetColor( legalColor )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )
    self:SetNotSolid( false )
end

function ENT:IsIllegal()
    local hasParent = IsValid( self:GetParent() )
    if hasParent then
        return true, true, "It's parented to something."

    end

    local illegalCollisions = self:GetCollisionGroup() ~= COLLISION_GROUP_NONE
    if illegalCollisions then
        return true, true, "It's collisions were disabled."

    end
    if not self:IsSolid() then
        return true, true, "It was made non-solid."

    end

    local myMat = self:GetMaterial()
    if myMat ~= legalMaterial then return true, true, "It's material was changed." end

    local myMats = self:GetMaterials()
    for ind = 0, #myMats do
        local matSet = self:GetSubMaterial( ind )
        if matSet ~= legalMaterial then
            return true, true, "It's submaterial was changed."

        end
    end

    local myColor = self:GetColor()
    if myColor ~= legalColor then
        return true, true, "It's color was changed."

    end

    local legalCheckPos = self:SpawnpointMassCenter()

    local legalTraceCheck = {
        start = legalCheckPos,
        endpos = legalCheckPos,
        filter = self,
        collisiongroup = self:GetCollisionGroup(),
        maxs = self.LegalMaxs,
        mins = -self.LegalMaxs,
    }
    local legalTrace = util.TraceHull( legalTraceCheck )
    if legalTrace.Hit or legalTrace.StartSolid then
        if legalTrace.HitWorld then
            return true, true, "It's inside/intersecting the world."

        elseif legalTrace.Entity then
            local blocker = legalTrace.Entity
            local blockersObj = blocker:GetPhysicsObject()
            local canIgnore = blocker:IsPlayer()
            if not canIgnore and IsValid( blockersObj ) and blockersObj:GetMass() <= 100 then
                canIgnore = true

            end
            if not canIgnore and blocker:IsPlayerHolding() then
                canIgnore = true

            end
            if not canIgnore then
                return true, false, "It's inside/intersecting an entity."

            end
        end
    end
end

function ENT:Think()

    self:ShieldThink()

    local linkedPlysCount = table.Count( self.LinkedPlayers )
    if self.nextLinkedFX < CurTime() then
        self.nextLinkedFX = CurTime() + math.random( 5, 10 )
        if linkedPlysCount then
            local effData = EffectData()
            effData:SetOrigin( self:LocalToWorld( self.SpawnpointFxOffset ) )
            effData:SetScale( 0.5 )
            util.Effect( "spawnpoint_start", effData )

        end
    end
    if linkedPlysCount > 0 then
        local is, doUnlink, reason = self:IsIllegal()
        if is then
            self:MakeLegal()
            if doUnlink then
                unlinkAllPlayersFromSpawnPoint( self, {}, "You've been disconnected from your spawnpoint because...\n" .. reason )

            else
                displayMessageToAllSpawners( self, "You won't respawn at your spawnpoint because...\n" .. reason )

            end
        end
    end
    self:NextThink( CurTime() + 1 )
    return true

end

function ENT:Break()
    if self.spawnpointBroken then return end
    self.spawnpointBroken = true
    self:DoBreakFX()
    SafeRemoveEntity( self )

end

function ENT:OnTakeDamage( dmg )

    if self.spawnpointBroken then return end
    self:TakePhysicsDamage( dmg )

    local damage = dmg:GetDamage()

    if self:ShieldIsHolding() then
        self:ShieldReflectFX()

        -- explosions are too easy!
        if dmg:IsExplosionDamage() then
            damage = damage / 2

        end

        self:ShieldTakeDamage( damage )

        return
    end

    self.SpawnpointHealth = self.SpawnpointHealth - damage

    self:OnDamagedFX()
end

function ENT:PlysAreFriendly( ply, otherPly )
    if ply == otherPly then return true end

    -- simple player squads
    if ply.GetSquadID then
        local plysId = ply:GetSquadID()
        if plysId == -1 then return false end

        local othersId = otherPly:GetSquadID()
        if othersId == -1 then return false end

        if plysId == othersId then return true end

    end

    return false

end

-- take no acf damage
function ENT:ACF_PreDamage()
    return false

end

-- Stubs

function ENT:PhysicsUpdate() end

function ENT:PhysicsCollide() end

-- shield stuff

function ENT:SetupShield()
    self:EmitSound( "npc/scanner/scanner_electric2.wav", 75, math.random( 120, 140 ), 1, CHAN_STATIC )
    self:EmitSound( "weapons/physcannon/physcannon_charge.wav", 70, 130, 1, CHAN_STATIC )

    self:SetShielded( true )
    self:SetShieldHealth( 0 )
    self.blockShieldHealthRegen = 0
end

function ENT:TeardownShield()
    self:SetShielded( false )
    self:SetShieldHealth( 0 )
    self.blockShieldHealthRegen = 0
end

function ENT:ShieldThink()
    local canThink = self:GetShieldOn()
    if canThink then
        if not self.spawnpointShieldSetupTime then
            local setupTime = CurTime() + self:ShieldSetupTimeTaken()
            self.spawnpointShieldSetupTime = setupTime
            self:SetShieldSetupTime( setupTime )

        elseif self.spawnpointShieldSetupTime < CurTime() then
            if not self:GetShielded() then
                self:SetupShield()

            else
                local currHealth = self:GetShieldHealth()
                local maxHealth = self:MaxShieldHealth()
                local blockRegen = self.blockShieldHealthRegen > CurTime()

                if blockRegen then return end
                if currHealth >= maxHealth then return end

                -- regenerate
                self:ShieldRegenFX()
                self:ShieldTakeDamage( -self:ShieldHealthRegen() )

            end
        end
    elseif not canThink then
        if self:GetShielded() then
            self:TeardownShield()
            self:SetShieldSetupTime( 0 )
            self.spawnpointShieldSetupTime = nil

        end
    end
end

function ENT:ShieldTakeDamage( dmg )
    local oldHealth = self:GetShieldHealth()

    local newHealth = oldHealth - dmg
    newHealth = math.Clamp( newHealth, 0, self:MaxShieldHealth() )
    newHealth = math.Round( newHealth )
    self:SetShieldHealth( newHealth )

    if newHealth < oldHealth then
        self.blockShieldHealthRegen = CurTime() + 10

    end
    -- shield just broke
    if newHealth == 0 then
        self:EmitSound( "weapons/physcannon/energy_sing_explosion2.wav", 75, math.random( 110, 120 ) )
        self:EmitSound( "npc/turret_floor/die.wav", 75, math.random( 140, 150 ), 1, CHAN_STATIC )
        util.ScreenShake( self:WorldSpaceCenter(), 10, 10, 0.5, 1500 )

    end
end


--[[ TODO: replace/move hacky code below this 

-- shields off in build
-- restarts the countdown when players enter pvpmode too 
local function checkShields()
    for _, spawn in ipairs( ents.FindByClass( "sent_spawnpoint" ) ) do
        local creator = spawn:GetCreator()
        if IsValid( creator ) then
            local inPvp = creator:IsInPvp()
            if inPvp then
                spawn:SetShieldOn( true )
            else
                spawn:SetShieldOn( false )
            end
        end
    end
end

hook.Add( "CFC_MobileSpawn_CreatedSpawn", "mobileSpawns_CheckShields", checkShields )

hook.Add( "CFC_PvP_PlayerExitPvp", "mobileSpawns_TurnOffShields", checkShields )

hook.Add( "CFC_PvP_PlayerEnterPvp", "mobileSpawns_TurnOnShields", checkShields )
--]]