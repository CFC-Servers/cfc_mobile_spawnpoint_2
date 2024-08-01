ENT.Type 			= "anim"
ENT.Base 			= "base_gmodentity"
ENT.PrintName		= "Mobile Spawnpoint"
ENT.Author			= "Esik1er + CFC"

ENT.Spawnable			= true
ENT.AdminSpawnable		= true

ENT.SpawnsActive        = true

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", 0, "SpawnpointEnabled" )
    self:NetworkVar( "Bool", 1, "Shielded" )
    self:NetworkVar( "Float", 0,  "ShieldHealth" )
    if not SERVER then return end
    self:ResetData()

end