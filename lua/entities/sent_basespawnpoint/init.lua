AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

local function allPlayersRecipientFilter()
    local filterAllPlayers = RecipientFilter()
    filterAllPlayers:AddAllPlayers()

    return filterAllPlayers

end

local defaultInterferenceDist = 2000
local desc = "Distance that shielded base spawnpoints, interfere with other spawnpoints, -1 for default (" .. tostring( defaultInterferenceDist ) .. ")"

local baseInterferenceVar = CreateConVar( "cfc_basespawn_interferedist", -1, FCVAR_ARCHIVE, desc )
function interferenceDist()
    local var = baseInterferenceVar:GetInt()
    if var <= -1 then
        return defaultInterferenceDist

    else
        return var

    end
end

local defaultMaxShieldHealth = 50000
desc = "Max shield health of the base_spawnpoint, -1 for default (" .. tostring( defaultMaxShieldHealth ) .. ")"

local baseShieldHealthVar = CreateConVar( "cfc_basespawn_shieldhealth", -1, FCVAR_ARCHIVE, desc )
function maxShieldHealth()
    local var = baseShieldHealthVar:GetInt()
    if var <= -1 then
        return defaultMaxShieldHealth

    else
        return var

    end
end

local defaultShieldRegen = 1000
desc = "How much shield health does the base_spawnpoint regen, per second? -1 for default (" .. tostring( defaultShieldRegen ) .. ")"

local baseShieldRegenVar = CreateConVar( "cfc_basespawn_shieldregen", -1, FCVAR_ARCHIVE, desc )
function shieldRegen()
    local var = baseShieldRegenVar:GetInt()
    if var <= -1 then
        return defaultShieldRegen

    else
        return var

    end
end

local defaultShapedShieldDamage = maxShieldHealth() * 0.6
desc = "base_spawnpoint shield damage, dealt by the Shaped Charge. -1 for default (" .. tostring( defaultShapedShieldDamage ) .. ")"

local shapedShieldDamageVar = CreateConVar( "cfc_basespawn_shapedshielddamage", -1, FCVAR_ARCHIVE, desc )
function shapedShieldDamage()
    local var = shapedShieldDamageVar:GetInt()
    if var <= -1 then
        return defaultShapedShieldDamage

    else
        return var

    end
end

local CurTime = CurTime

ENT.IllegalToPickup = true
ENT.SpawningHealth = 400
ENT.MaxHealth = ENT.SpawningHealth
ENT.MaxShieldHealth = maxShieldHealth()
ENT.ShieldHealthRegen = shieldRegen()
ENT.ShieldRegenDelay = 10
ENT.PlayerSpawnOffset = Vector( -10, 45, -90 )
ENT.PlayerSpawnOffsetWorld = Vector( 0, 0, 15 )
ENT.SpawnpointFxOffset = Vector( -10, 30, -40 )

ENT.IsBaseSpawnpoint = true

ENT.LegalMass = 1000
ENT.LegalMaxs = Vector( 10, 10, 25 )

ENT.SpawnpointModel = "models/props_combine/combine_generator01.mdl"

function ENT:SpawnpointPostInitialize()
    self.nextFindInterfering = 0
    self.interferingSpawns = {}
    self.blockShieldHealthRegen = CurTime() + self.ShieldSetupTime + self.ShieldRegenDelay / 4
    timer.Simple( self.ShieldSetupTime, function()
        if not IsValid( self ) then return end
        -- tell all players that this is setup, ignoring PAS
        self:EmitSound( "npc/scanner/scanner_electric2.wav", 100, math.random( 70, 80 ), 1, CHAN_STATIC, nil, nil, allPlayersRecipientFilter() )
        self:EmitSound( "plats/platform_citadel_ring.wav", 100, math.random( 100, 110 ), 1, CHAN_STATIC, nil, nil, allPlayersRecipientFilter() )
        self:EmitSound( "weapons/physcannon/physcannon_charge.wav", 75, 80, 1, CHAN_STATIC )

        self:SetShielded( true )
        self:SetShieldHealth( self.MaxShieldHealth / 2 )

    end )
    timer.Simple( 1, function()
        if not IsValid( self ) then return end
        self:EmitSound( "ambient/levels/labs/machine_stop1.wav", 100, math.random( 160, 180 ), 1, CHAN_STATIC, nil, nil, allPlayersRecipientFilter() )

    end )
end

-- Entity Methods
function ENT:SpawnFunction( spawner, tr )
    if not tr.Hit then return end
    local spawnPos = tr.HitPos
    local spawnAng = Angle( 0, spawner:EyeAngles().y + 90, 0 )
    local ent = ents.Create( "sent_basespawnpoint" )
    ent:SetPos( spawnPos )
    ent:SetAngles( spawnAng )
    ent:Spawn()
    ent:Activate()

    return ent

end

local baseLegalMassVar = CreateConVar( "cfc_basespawn_mass", -1, FCVAR_ARCHIVE, "The mass of the base spawnpoint, -1 for default ( 1000 )" )
function ENT:MyLegalMass()
    local var = baseLegalMassVar:GetInt()
    if var <= -1 then
        return self.LegalMass

    else
        return var

    end
end

local regenerateSounds = {
    "weapons/physcannon/superphys_small_zap1.wav",
    "weapons/physcannon/superphys_small_zap2.wav",
    "weapons/physcannon/superphys_small_zap3.wav",
    "weapons/physcannon/superphys_small_zap4.wav",

}

function ENT:SpawnpointThink()
    if self:GetShielded() then
        local currHealth = self:GetShieldHealth()
        self:InterferingThink( currHealth )
        self:ShieldThink( currHealth )
    end
end

function ENT:InterferingThink( currHealth )
    if currHealth <= 0 then return end

    if self.nextFindInterfering < CurTime() then
        self.nextFindInterfering = CurTime() + 5

        local spawns = ents.FindByClass( "sent_spawnpoint" )
        local baseSpawns = ents.FindByClass( "sent_basespawnpoint" )
        table.Add( spawns, baseSpawns )

        local myPos = self:GetPos()
        local distSqr = interferenceDist()^2
        local tooCloseSpawns = {}
        for _, currSpawn in ipairs( spawns ) do
            if currSpawn ~= self and currSpawn:GetPos():DistToSqr( myPos ) < distSqr then
                table.insert( tooCloseSpawns, currSpawn )

            end
        end

        self.interferingSpawns = tooCloseSpawns

    end


    local interfering = self.interferingSpawns

    if #interfering <= 0 then return end
    for _, spawn in ipairs( interfering ) do
        self:InterfereWith( spawn )

    end
end

function ENT:InterfereWith( otherSpawn )
    print( "a", otherSpawn )

end

function ENT:ShieldThink( currHealth )
    local maxHealth = self.MaxShieldHealth
    local blockRegen = self.blockShieldHealthRegen > CurTime()

    -- play alarm
    local PANIC
    local nextPanicSound = self.nextPanicSound or 0

    if currHealth < maxHealth * 0.5 and blockRegen then
        PANIC = true

    end
    local children = self:GetChildren()
    if #children >= 0 then
        for _, child in ipairs( children ) do
            if child:GetClass() == "cfc_shaped_charge"then PANIC = true end
        end
    end

    if PANIC and nextPanicSound < CurTime() then
        local time = 2
        -- when really low shield health, play alarm faster
        if currHealth < maxHealth * 0.25 then
            time = 0

        end
        self.nextPanicSound = CurTime() + time
        self:EmitSound( "ambient/alarms/klaxon1.wav", 90, math.random( 120, 130 ), 0.75, CHAN_STATIC )
        util.ScreenShake( self:WorldSpaceCenter(), 3, 10, 0.1, 1000 )

    end

    -- no shield alarm
    if currHealth == 0 and ( not self.panicSound or not self.panicSound:IsPlaying() ) then
        self.panicSound = CreateSound( self, "ambient/alarms/apc_alarm_loop1.wav" )
        self.panicSound:SetSoundLevel( 85 )
        self.panicSound:PlayEx( 1, 130 )

    elseif currHealth > 0 and ( self.panicSound and self.panicSound:IsPlaying() ) then
        self.panicSound:Stop()

    end

    if blockRegen then return end
    if currHealth >= maxHealth then return end

    -- regenerate
    self:EmitSound( regenerateSounds[math.random( 1, #regenerateSounds )], 65, math.random( 80, 90 ), 1, CHAN_BODY )
    self:ShieldTakeDamage( -self.ShieldHealthRegen )
end

-- cleanup sound 
function ENT:OnSpawnRemoved()
    if not self.panicSound or not self.panicSound:IsPlaying() then return end
    self.panicSound:Stop()

end

function ENT:ShieldTakeDamage( dmg )
    local oldHealth = self:GetShieldHealth()

    local newHealth = oldHealth - dmg
    newHealth = math.Clamp( newHealth, 0, self.MaxShieldHealth )
    newHealth = math.Round( newHealth )
    self:SetShieldHealth( newHealth )

    if newHealth < oldHealth then
        self.blockShieldHealthRegen = CurTime() + self.ShieldRegenDelay

    end
    -- shield just broke
    if newHealth == 0 then
        self:EmitSound( "weapons/physcannon/energy_sing_explosion2.wav", 90, math.random( 80, 90 ) )
        self:EmitSound( "npc/turret_floor/die.wav", 75, math.random( 40, 50 ), 1, CHAN_STATIC )
        util.ScreenShake( self:WorldSpaceCenter(), 10, 10, 0.5, 1500 )

    end
end

local shieldReflect = {
    "weapons/physcannon/superphys_small_zap1.wav",
    "weapons/physcannon/superphys_small_zap2.wav",
    "weapons/physcannon/superphys_small_zap3.wav",
    "weapons/physcannon/superphys_small_zap4.wav",
    "weapons/physcannon/energy_bounce1.wav",
    "weapons/physcannon/energy_bounce2.wav",

}
local breakingSounds = {
    "physics/metal/metal_sheet_impact_bullet1.wav",
    "physics/metal/metal_sheet_impact_bullet2.wav",

}

hook.Add( "CFC_SWEP_ShapedCharge_CanDestroyQuery", "CFC_BaseSpawnpoint_ShieldInteraction", function( charge, prop )
    if not prop.IsBaseSpawnpoint then return end

    if not prop:GetShielded() then return end
    if not prop:ShieldIsHolding() then return end

    prop:ShieldTakeDamage( shapedShieldDamage() )

    -- block destruction
    return false

end )


function ENT:DoFirstTimeSetupFX( _ )
end

function ENT:DoSpawningFX( _ )
    local effData = EffectData()
    effData:SetOrigin( self:GetPos() )
    effData:SetScale( 4 )
    util.Effect( "spawnpoint_start", effData )

    self:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 80, math.random( 120, 130 ), 1, CHAN_STATIC )
    self:EmitSound( "items/medshot4.wav", 80, math.random( 70, 80 ), 1, CHAN_ITEM )
    util.ScreenShake( self:WorldSpaceCenter(), 5, 10, 0.1, 750 )

end

local function splode( pos )
    local effData = EffectData()
    effData:SetOrigin( pos )
    effData:SetScale( 1 )
    effData:SetMagnitude( 1 )

    util.Effect( "Explosion", effData )

end

local function miniSpark( pos, scale )
    local effectdata = EffectData()
    effectdata:SetOrigin( pos )
    effectdata:SetNormal( VectorRand() )
    effectdata:SetMagnitude( 3 * scale ) --amount and shoot hardness
    effectdata:SetScale( 1 * scale ) --length of strands
    effectdata:SetRadius( 3 * scale ) --thickness of strands
    util.Effect( "Sparks", effectdata )

end

function ENT:DoBreakFX()
    local breakPos = self:SpawnpointMassCenter()
    -- i was shielded, BIG BOOM!
    if self:GetShielded() then
        for _ = 1, 6 do
            splode( breakPos + VectorRand() * math.random( 20, 40 ) )

        end

        self:EmitSound( "ambient/explosions/explode_1.wav", 110, 60, 0.75, CHAN_STATIC, nil, nil, allPlayersRecipientFilter() )

        util.BlastDamage( self, self, breakPos, 300, 300 )

    -- wasnt shielded, smal boom
    else
        for _ = 1, 6 do
            miniSpark( breakPos, math.Rand( 1, 2 ) )

        end
        self:EmitSound( "ambient/fire/gascan_ignite1.wav", 80, math.random( 90, 100 ), 1, CHAN_STATIC )
        self:EmitSound( "npc/scanner/cbot_energyexplosion1.wav", 80, math.random( 120, 130 ), 1, CHAN_STATIC )

    end
end

function ENT:SpawnpointPreTakeDamage( dmg )
    if self:GetShielded() then
        local damage = dmg:GetDamage()
        if not self:ShieldIsHolding() then
            util.ScreenShake( self:WorldSpaceCenter(), 10, 10, 0.1, 1500 )
            self:EmitSound( breakingSounds[math.random( 1, #breakingSounds )], 75, math.random( 90, 110 ), 1, CHAN_STATIC )

            local nextDyingSplode = self.nextDyingSplode or 0

            if nextDyingSplode > CurTime() then return end
            self.nextDyingSplode = CurTime() + 0.5
            timer.Simple( 0.1, function()
                if not IsValid( self ) then return end
                splode( self:WorldSpaceCenter() + VectorRand() * 10 )
            end )

            return

        end


        -- explosions are too easy!
        if dmg:IsExplosionDamage() then
            damage = damage / 4

        end
        self:EmitSound( shieldReflect[math.random( 1, #shieldReflect )], 75, math.random( 80, 90 ), 1, CHAN_BODY )

        util.ScreenShake( self:WorldSpaceCenter(), 1, 10, 0.1, 1000 )

        self:ShieldTakeDamage( damage )

        return true
    end
end

function ENT:ACF_PreDamage()
    if self:GetShielded() then return false end

end
