AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

ENT.IllegalToPickup = false
ENT.SpawningHealth = 400 -- two crossbow bolts
ENT.MaxHealth = ENT.SpawningHealth
ENT.PlayerSpawnOffset = Vector( 0, 0, 0 )
ENT.PlayerSpawnOffsetWorld = Vector( 0, 0, 16 )
ENT.SpawnpointFxOffset = Vector( 0, 0, 0 )

ENT.LegalMass = 100
ENT.LegalMaxs = Vector( 5, 5, 2 )

ENT.SpawnpointModel = "models/props_combine/combine_mine01.mdl"

local HUD_PRINTCENTER = HUD_PRINTCENTER

local function miniSpark( pos, scale )
    local effectdata = EffectData()
    effectdata:SetOrigin( pos )
    effectdata:SetNormal( VectorRand() )
    effectdata:SetMagnitude( 3 * scale ) --amount and shoot hardness
    effectdata:SetScale( 1 * scale ) --length of strands
    effectdata:SetRadius( 3 * scale ) --thickness of strands
    util.Effect( "Sparks", effectdata )

end

local function isFriendly( ply, otherPly )
    if ply == otherPly then return true end

    -- simple player squads
    if ply.GetSquadID then
        local plysId = ply:GetSquadID()
        if plysId == -1 then return false end

        local othersId = otherPly:GetSquadID()
        if othersId == -1 then return false end

        print( plysId, othersId )

        if plysId == othersId then return true end

    end

    return false

end

function unlinkPlayerFromSpawnPoint( ply, spawnPoint )
    if not IsValid( ply ) then return end
    if not IsValid( spawnPoint ) then return end

    ply.LinkedSpawnPoint = nil
    spawnPoint.LinkedPlayers[ply] = nil
    spawnPoint:DoQuietSound( "npc/roller/code2.wav" )

end

function linkPlayerToSpawnPoint( ply, spawnPoint )
    if not IsValid( ply ) then return end
    if not IsValid( spawnPoint ) then return end
    if not isFriendly( spawnPoint:GetCreator(), ply ) then return end
    if IsValid( ply.LinkedSpawnPoint ) then
        unlinkPlayerFromSpawnPoint( ply, ply.LinkedSpawnPoint )

    end

    ply.LinkedSpawnPoint = spawnPoint
    spawnPoint.LinkedPlayers[ply] = "Linked"

    return true
end

function unlinkAllPlayersFromSpawnPoint( spawnPoint, excludedPlayers, reason )
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


local defaultRespawnLinkDelay = 10
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

local defaultLinkDelay = 1.75
desc = "How long does a spawnpoint have to exist for, before a player can link to it, -1 for default (" .. tostring( defaultLinkDelay ) .. ")"

local linkDelayVar = CreateConVar( "cfc_mobilespawn_linkdelay", -1, FCVAR_ARCHIVE, desc )
local function linkDelay()
    local var = linkDelayVar:GetFloat()
    if var <= -1 then
        return defaultLinkDelay

    else
        return var

    end
end


-- Entity Methods
function ENT:SpawnFunction( spawner, tr )
    if not tr.Hit then return end
    local spawnPos = tr.HitPos
    local spawnAng = Angle( 0, spawner:EyeAngles().y, 0 )
    local ent = ents.Create( "sent_spawnpoint" )
    ent:SetPos( spawnPos + -tr.HitNormal )
    ent:SetAngles( spawnAng )
    ent:Spawn()
    ent:Activate()

    return ent
end

function ENT:ResetData()
    self:SetShielded( false )
    self:SetShieldHealth( 0 )

end

function ENT:Initialize()
    self:ResetData()

    self.SpawnpointHealth = self.SpawningHealth
    self.nextDamageWhine = 0
    self.nextLinkedFX = 0

    self:SetTrigger( true )

    self:SetModel( self.SpawnpointModel )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )
    self.LinkedPlayers = {}

    self.mobileSpawns_LinkAge = CurTime() + linkDelay()

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:Wake()
        phys:EnableDrag( true )
        phys:EnableMotion( false )

    end

    self:SpawnpointPostInitialize()

    local effData = EffectData()
    effData:SetOrigin( self:LocalToWorld( self.SpawnpointFxOffset ) )
    effData:SetScale( 0.5 )
    util.Effect( "spawnpoint_start", effData )

    self:MakeLegal()

end

function ENT:OnRemove()
    local effData = EffectData()
    effData:SetOrigin( self:LocalToWorld( self.SpawnpointFxOffset ) )
    effData:SetScale( 1 )
    util.Effect( "spawnpoint_start", effData )

    self:OnSpawnRemoved()

    local message = "Your linked spawnpoint was removed"
    if self.spawnpointBroken then
        message = "Your linked spawnpoint died"

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
        local effData = EffectData()
        effData:SetOrigin( self:LocalToWorld( self.SpawnpointFxOffset ) )
        effData:SetScale( 0.5 )
        util.Effect( "spawnpoint_start", effData )

    end )

    local playerLinkedToSpawnPoint = ply.LinkedSpawnPoint == self

    if playerLinkedToSpawnPoint and not enableOnly then
        unlinkPlayerFromSpawnPoint( ply, self )
        ply:PrintMessage( HUD_PRINTCENTER, "Spawn Point unlinked" )
    elseif not playerLinkedToSpawnPoint then
        local is, _, reason = self:IsIllegal()
        if is then
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

        if self.mobileSpawns_LinkAge > CurTime() then
            local untilTime = math.abs( self.mobileSpawns_LinkAge - CurTime() )
            untilTime = math.Round( untilTime, 1 )

            self:DoQuietSound( "npc/roller/code2.wav" )
            ply:PrintMessage( HUD_PRINTCENTER, "That spawnpoint was just created!\nCan link in " .. untilTime .. " seconds." )
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

        elseif not enableOnly then
            self:DoQuietSound( "npc/roller/code2.wav" )
            ply:PrintMessage( HUD_PRINTCENTER, "Unable to set spawnpoint. You are not in the same squad as the owner." )

        end
    end
end

-- where respawned players are placed
function ENT:RespawnPos()
    return self:LocalToWorld( self.PlayerSpawnOffset ) + self.PlayerSpawnOffsetWorld

end

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

-- play a really obvious sound the first time someone sets their spawn as me
function ENT:DoFirstTimeSetupFX( _ )
    -- ignore PAS
    local filterAllPlayers = RecipientFilter()
    filterAllPlayers:AddAllPlayers()
    self:EmitSound( "npc/roller/mine/combine_mine_deactivate1.wav", 80, math.random( 110, 120 ), 1, CHAN_STATIC, nil, nil, filterAllPlayers )

end

function ENT:DoSpawningFX( _ )
    local effData = EffectData()
    effData:SetOrigin( self:LocalToWorld( self.SpawnpointFxOffset ) )
    effData:SetScale( 2 )
    util.Effect( "spawnpoint_start", effData )

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

local legalMaterial = ""
local legalColor = Color( 255, 255, 255, 255 )

function ENT:MakeLegal()
    self:SetMaterial( legalMaterial )
    self:SetColor( legalColor )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )
    self:SetNotSolid( false )
    local obj = self:GetPhysicsObject()
    if IsValid( obj ) then
        obj:SetMass( self.LegalMass )

    end
end

function ENT:IsIllegal()
    local myMat = self:GetMaterial()
    if myMat ~= legalMaterial then
        return true, true, "It's material was changed."

    end
    local myColor = self:GetColor()
    if myColor ~= legalColor then
        return true, true, "It's color was changed."

    end
    local pickedUp = self:IsPlayerHolding()
    if pickedUp and self.IllegalToPickup then
        return true, true, "It's being held."

    end

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

    local obj = self:GetPhysicsObject()
    local illegalMass = IsValid( obj ) and obj:GetMass() ~= self.LegalMass and not pickedUp
    if illegalMass then
        return true, true, "It's mass was changed."

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
            if not canIgnore and IsValid( blockersObj ) and blockersObj:GetMass() <= self.LegalMass then
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
    local is, doUnlink, reason = self:IsIllegal()
    if is then
        self:MakeLegal()
        if doUnlink then
            unlinkAllPlayersFromSpawnPoint( self, {}, "You've been disconnected from your spawnpoint because...\n" .. reason )

        else
            displayMessageToAllSpawners( self, "You won't respawn at your spawnpoint because...\n" .. reason )

        end
    end
    if self.nextLinkedFX < CurTime() then
        self.nextLinkedFX = CurTime() + math.random( 5, 10 )
        if table.Count( self.LinkedPlayers ) >= 1 then
            local effData = EffectData()
            effData:SetOrigin( self:LocalToWorld( self.SpawnpointFxOffset ) )
            effData:SetScale( 0.5 )
            util.Effect( "spawnpoint_start", effData )

        end
    end
    self:SpawnpointThink()
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

    if self:SpawnpointPreTakeDamage( dmg ) then return end

    local damage = dmg:GetDamage()
    self.SpawnpointHealth = self.SpawnpointHealth - damage

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
        local pitch = math.random( 110, 120 ) + ( -damage / 4 )
        self:EmitSound( "Computer.BulletImpact" )
        self:EmitSound( "physics/metal/metal_canister_impact_hard" .. math.random( 1, 3 ) .. ".wav", 75, pitch, 1, CHAN_STATIC )

    end
end

-- take no acf damage when we're above half health
function ENT:ACF_PreDamage()
    return false

end

-- Stubs from here on

function ENT:SpawnpointPreTakeDamage() end

function ENT:SpawnpointPostInitialize() end

function ENT:SpawnpointThink() end

function ENT:OnSpawnRemoved() end

function ENT:PhysicsUpdate() end

function ENT:PhysicsCollide() end
