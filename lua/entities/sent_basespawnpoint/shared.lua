ENT.Type 			= "anim"
ENT.Base 			= "sent_spawnpoint"
ENT.PrintName		= "Base Spawnpoint"
ENT.Author			= "CFC"

ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Spawnable			= true
ENT.AdminSpawnable		= true

ENT.SpawnsActive        = false
ENT.ShieldSetupTime     = 45

function ENT:ShieldIsHolding()
    if self:GetShieldHealth() <= 0 then return end
    return true

end