AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( 'shared.lua' )

-- Chat command config
spawnPointCommands = {
	["unlinkSpawnPoint"] = { ["!unlinkspawn"] = true, ["!unlinkspawnpoint"] = true },
	["unlinkThisSpawnPoint"] = { ["!unlinkthis"] = true }
}

-- Helper Functions
function createPlayerList( players )
	local playerList = {}
	for _, player in pairs( players ) do
		playerList[player] = true
	end
	
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

function unlinkAllPlayersFromSpawnPoint( spawnPoint, excludePlayers )
	local linkedPlayers = spawnPoint.linkedPlayers
	local spawnPointOwner = spawnPoint:CCPIGetOwner()
	
	for player, _ in pairs( linkedPlayers ) do
		local playerOwnsSpawnPoint = spawnPointOwner == player
		if ( not excludePlayers[player] and not playerOwnsSpawnPoint ) then
			unlinkPlayerFromSpawnPoint( player, spawnPoint )
			player:PrintMessage(4, "You've been unlinked from a Spawn point!")
		end
	end
end

-- Chat commands
function unlinkSpawnPointCommand( player, text, _, _ )
	local text = string.lower( text ):gsub("%s+", "")
	local unlinkSpawnCommands = spawnPointCommands.unlinkSpawnPoint
	
	if ( unlinkSpawnCommands[text] ) then
		local linkedSpawnPoint = player.LinkedSpawnPoint	
		unlinkPlayerFromSpawnPoint( player, linkedSpawnPoint )
		player:PrintMessage(4, "Spawn point unlinked.")
	end
end
hook.Remove( "PlayerSay", "UnlinkSpawnPointCommand" )
hook.Add( "PlayerSay", "UnlinkSpawnPointCommand", unlinkSpawnPointCommand )

function unlinkThisSpawnPointCommand( player, text, _, _ )
	local text = string.lower( text ):gsub("%s+", "")
	local unlinkThisSpawnCommands = spawnPointCommands.unlinkThisSpawnPoint
	
	if ( unlinkThisSpawnCommands[text] ) then
		local targetedEntity = player:GetEyeTraceNoCursor().Entity
		
		if ( targetedEntity and targetedEntity:IsValid() ) then
			local isSpawnPoint = targetedEntity:GetClass() == "sent_spawnpoint"
			
			if ( isSpawnPoint ) then
				local spawnPoint = targetedEntity
				local spawnPointOwner = spawnPoint:CPPIGetOwner()
				local playerOwnsSpawnPoint = spawnPointOwner == player
				local playerIsAdmin = player:IsAdmin()
				
				if ( playerOwnsSpawnPoint or playerIsAdmin ) then
					local excludedPlayers = createPlayerList( { spawnPointOwner } )
					unlinkAllPlayersFromSpawnPoint(spawnPoint, excludedPlayers)
					player:PrintMessage(4, "All players except the owner have been unlinked from this spawn point")
				else
					player:PrintMessage(4, "That's not yours! You can't unlink others from this Spawn Point.")
				end
			else
				player:PrintMessage(4, "You must be looking at a spawn point to use this command.")
			end
		end
	end
end

hook.Remove( "PlayerSay", "UnlinkThisSpawnPointCommand" )
hook.Add( "PlayerSay", "UnlinkThisSpawnPointCommand", unlinkThisSpawnPointCommand )

-- Entity Methods
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
	if ( phys:IsValid() ) then
		phys:Wake()
		phys:EnableDrag(true)
		phys:EnableMotion(false)
	end	
end

function ENT:OnRemove()
	local effectdata1 = EffectData()
	effectdata1:SetOrigin( self.Entity:GetPos() )
	util.Effect( "spawnpoint_start", effectdata1, true, true )
	
	unlinkAllPlayersFromSpawnPoint(self.Entity, {})
end

function ENT:Use( player, caller )
	if ( player.LinkedSpawnPoint and player.LinkedSpawnPoint == self.Entity ) then
		unlinkPlayerFromSpawnPoint( player, self.Entity )
		player:PrintMessage(4, "Spawn point unlinked.")
	else
		linkPlayerToSpawnPoint( player, self.Entity )
		player:PrintMessage(4, "Spawn point set. Say !unlinkspawn to unlink.")
	end
end 

local function SpawnPointHook(player)
	local spawnPoint = player.LinkedSpawnPoint
	if ( spawnPoint and spawnPoint:IsValid() ) then
		local spawnPos = spawnPoint:GetPos() + Vector(0,0,16)
		player:SetPos(spawnPos)
	end
end
hook.Remove("PlayerSpawn", "SpawnPointHook")
hook.Add("PlayerSpawn", "SpawnPointHook", SpawnPointHook) 

-- Stubs from here on

function ENT:Think() end

function ENT:OnTakeDamage( dmginfo ) end

function ENT:PhysicsUpdate() end

function ENT:PhysicsCollide( data, physobj ) end
