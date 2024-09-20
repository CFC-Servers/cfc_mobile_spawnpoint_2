ENT.Type 			= "anim"
ENT.Base 			= "base_gmodentity"
ENT.PrintName		= "Mobile Spawnpoint"
ENT.Author			= "Esik1er + CFC"

ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Spawnable			= true
ENT.AdminSpawnable		= true


local defaultShieldSetuptime = 35
desc = "Time it takes for spawnpoint's shield to setup, -1 for default (" .. tostring( defaultShieldSetuptime ) .. ")"

local shieldSetuptimeVar = CreateConVar( "cfc_mobilespawn_shield_setuptime", -1, FCVAR_ARCHIVE, desc )
local function spawnpointShieldSetuptime()
    local var = shieldSetuptimeVar:GetFloat()
    if var <= -1 then
        return defaultShieldSetuptime

    else
        return var

    end
end
function ENT:ShieldSetupTimeTaken()
    return spawnpointShieldSetuptime()

end


function ENT:SetupDataTables()
    self:NetworkVar( "Bool", 0,     "Shielded" )
    self:NetworkVar( "Bool", 1,     "ShieldOn" )
    self:NetworkVar( "Float", 0,    "ShieldHealth" )
    self:NetworkVar( "Float", 1,    "ShieldSetupTime" )
    self:NetworkVar( "Float", 1,    "ShieldSetupTime" )
    if not SERVER then return end
    self:ResetData()

end

function ENT:ShieldIsHolding()
    if self:GetShieldHealth() <= 0 then return end
    return true

end