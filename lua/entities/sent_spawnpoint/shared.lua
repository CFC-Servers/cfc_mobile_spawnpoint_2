ENT.Type 			= "anim"
ENT.Base 			= "base_gmodentity"
ENT.PrintName			= "Mobile Spawnpoint V2"
ENT.Author			= "Esik1er"

ENT.Spawnable			= true
ENT.AdminSpawnable		= true


function ENT:SetupDataTables()
    self:NetworkVar( "Entity", 0, "CreatingPlayer" )
    self:NetworkVar( "Float", 0, "CreationCooldownEndTime" )
    self:NetworkVar( "Float", 1, "PointMaxHealth" ) -- Starfall can manipulate :SetMaxHealth(), so bypass it by using a custom NetworkVar.
    self:NetworkVar( "Float", 2, "PointHealth" )
end
