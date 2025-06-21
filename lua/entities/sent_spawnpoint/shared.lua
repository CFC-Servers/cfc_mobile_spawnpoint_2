ENT.Type 			= "anim"
ENT.Base 			= "base_gmodentity"
ENT.PrintName			= "Mobile Spawnpoint V2"
ENT.Author			= "Esik1er"

ENT.Spawnable			= true
ENT.AdminSpawnable		= true
ENT.Editable	     	= true


function ENT:SetupDataTables()
    self:NetworkVar( "Entity", 0, "CreatingPlayer" )
    self:NetworkVar( "Float", 0, "CreationCooldownEndTime" )
    self:NetworkVar( "Float", 1, "PointMaxHealth" ) -- Starfall can manipulate :SetMaxHealth(), so bypass it by using a custom NetworkVar.
    self:NetworkVar( "Float", 2, "PointHealth" )
    self:NetworkVar( "Float", 3, "SpawnRadius", { KeyName = "spawn_radius", Edit = { type = "Float", title = "Spawn Radius", order = 1, min = 0, max = 1000 } } )

    if SERVER then return end

    self:NetworkVarNotify( "SpawnRadius", function( ent )
        ent._showSpawnRadiusEndTime = CurTime() + 5
    end )
end
