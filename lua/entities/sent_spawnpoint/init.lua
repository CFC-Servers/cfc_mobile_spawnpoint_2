AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( 'shared.lua' )

spawnPointCommands = {
	["clearSpawnPoint"] = { "!clearspawn" }
}

function createPlayerList( players )
	local playerList = {}
	table.forEach( players, function( _, player )
		playerList[player] = true
	end)
	
	return playerList
end

function linkPlayerToSpawnPoint( player, spawnPoint )
	player.LinkedSpawnPoint = spawnPoint
	spawnPoint.linkedPlayers[player] = "Linked"
end

function unlinkPlayerFromSpawnPoint( player, spawnPoint )
	player.LinkedSpawnPoint = nil
	spawnPoint.linkedPlayers[player] = nil
end

function unlinkAllPlayersFromSpawnPoint( spawnPoint )
	local linkedPlayers = spawnPoint.linkedPlayers
	table.forEach( linkedPlayers, function( _, player )
		unlinkPlayerFromSpawnPoint( spawnPoint, player )
	end)
end

function clearSpawnCommand( player, text, _, _ )
	local text = string.lower( text )
	local clearSpawnCommands = spawnPointCommands.clearSpawnPoint
	
	if ( clearSpawnCommands[text] ) then
		local linkedSpawnPoint = player.linkedSpawnPoint	
		unlinkPlayerFromSpawnPoint( player, linkedSpawnPoint )
		player:PrintMessage("Spawn point cleared.")
	end
end
hook.Remove( "PlayerSay", "clearSpawnPointCommand", clearSpawnPointCommand )

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

	local effectdata1 = EffectData()
		effectdata1:SetOrigin( self.Entity:GetPos() )
	util.Effect( "spawnpoint_start", effectdata1, true, true )
	
	self.Entity:SetModel("models/props_combine/combine_mine01.mdl")
	self.Entity:PhysicsInit( SOLID_VPHYSICS )
	self.Entity:SetMoveType( MOVETYPE_VPHYSICS )
	self.Entity:SetSolid( SOLID_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	self.Entity.linkedPlayers = {}

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
	
	unlinkAllPlayersFromSpawnPoint(self.Entity)
end

function ENT:Use( player, caller )
	if player.LinkedSpawnPoint and player.LinkedSpawnPoint == self.Entity then
		unlinkPlayerFromSpawnPoint( player, self.Entity )
		player:PrintMessage(4, "Spawn point cleared.")
	else
		linkPlayerToSpawnPoint( player, self.Entity )
		player:PrintMessage(4, "Spawn point set.")
	end
end 

local function SpawnPointHook(player)
	local spawnPoint = player.LinkedSpawnPoint
	if spawnPoint and spawnPoint:IsValid() then
		local spawnPos = spawnPoint:GetPos() + Vector(0,0,16)
		player:SetPos(spawnPos)
	end
end
hook.Add("PlayerSpawn", "SpawnerHook", SpawnPointHook) 

-- Stubs from here on

function ENT:Think() end

function ENT:OnTakeDamage( dmginfo ) end

function ENT:PhysicsUpdate() end

function ENT:PhysicsCollide( data, physobj ) end
