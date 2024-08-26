ENT.Type 			= "anim"
ENT.Base 			= "base_gmodentity"
ENT.PrintName			= "Mobile Spawnpoint V2"
ENT.Author			= "Esik1er"

ENT.Spawnable			= true
ENT.AdminSpawnable		= true


function ENT:SetupDataTables()
    self:NetworkVar( "Entity", 0, "CreatingPlayer" )
end
