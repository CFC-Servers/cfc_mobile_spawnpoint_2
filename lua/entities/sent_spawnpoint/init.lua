AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( 'shared.lua' )

function ENT:SpawnFunction( ply, tr )
	if ( !tr.Hit ) then return end
		local SpawnPos = tr.HitPos
		local ent = ents.Create( "sent_spawnpoint" )
			ent:SetPos( SpawnPos )
			ent:Spawn()
			ent:Activate()
	return ent
end

function ENT:Initialize()

	local selfent = self.Entity
	local effectdata1 = EffectData()
		effectdata1:SetOrigin( self.Entity:GetPos() )
	util.Effect( "spawnpoint_start", effectdata1, true, true )
	
	self.Entity:SetModel("models/props_combine/combine_mine01.mdl")
	self.Entity:PhysicsInit( SOLID_VPHYSICS )
	self.Entity:SetMoveType( MOVETYPE_VPHYSICS )
	self.Entity:SetSolid( SOLID_VPHYSICS )
	self:SetUseType( SIMPLE_USE )

	local phys = self.Entity:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:Wake()
		phys:EnableDrag(true)
		phys:EnableMotion(false)
	end	
end





function ENT:OnRemove()
	local effectdata1 = EffectData()
		effectdata1:SetOrigin( self.Entity:GetPos() )
	util.Effect( "spawnpoint_start", effectdata1, true, true )
//	activator.SpawnPoint = nil
//	hook.Remove( "PlayerSpawn", "SpawnerHook" )
end

function ENT:Use(activator, caller)
if activator.SpawnPoint and activator.SpawnPoint == self.Entity then
activator.SpawnPoint = nil
activator:PrintMessage(4, "Spawn point reset.")
else
activator.SpawnPoint = self.Entity
activator:PrintMessage(4, "Spawn point set.")
end
end 

local function SpawnerHook(pl)
if pl.SpawnPoint and pl.SpawnPoint:IsValid() then pl:SetPos(pl.SpawnPoint:GetPos() + Vector(0,0,16)) end
end
hook.Add("PlayerSpawn", "SpawnerHook", SpawnerHook) 

// Stubs for here on.

function ENT:Think() end

function ENT:OnTakeDamage( dmginfo ) end

function ENT:PhysicsUpdate() end

function ENT:PhysicsCollide( data, physobj ) end