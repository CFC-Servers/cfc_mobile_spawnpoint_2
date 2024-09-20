include( "shared.lua" )

local MESSAGE_DRAW_DISTANCE = 500
local MESSAGE_BOTTOM_HEIGHT = 20
local MESSAGE_CRISPNESS = 4
local MESSAGE_FONT_SIZE = 24 * MESSAGE_CRISPNESS
local MESSAGE_SCALE = 0.25 / MESSAGE_CRISPNESS
local MESSAGE_OUTLINE_SIZE = 0.5 * MESSAGE_CRISPNESS
local MESSAGE_OUTLINE_COLOR = Color( 0, 0, 0 )

local MESSAGE_TEXT_POINT_SPAWN_COOLDOWN = "CANNOT LINK\n\nWAIT FOR\nTHE SPAWN POINT\nTO CHARGE"
local MESSAGE_COLOR_POINT_SPAWN_COOLDOWN = Color( 255, 0, 0 )

local MESSAGE_TEXT_PLAYER_SPAWN_COOLDOWN = "CANNOT LINK\n\nWAIT FOR\nYOUR SOUL\nTO STRENGTHEN"
local MESSAGE_COLOR_PLAYER_SPAWN_COOLDOWN = Color( 255, 0, 0 )

local MESSAGE_TEXT_LINK = "PRESS E\nTO LINK"
local MESSAGE_COLOR_LINK = Color( 250, 255, 0 )

local MESSAGE_ZOFFSET_HEALTH = -1 * MESSAGE_FONT_SIZE
local MESSAGE_COLOR_HEALTH = Color( 0, 180, 255 )

surface.CreateFont( "CFC_SpawnPoints_3D2DMessage", {
    font = "Arial",
    size = MESSAGE_FONT_SIZE,
    weight = 500,
    antialias = true,
    shadow = false,
} )


----- PRIVATE FUNCTIONS -----

local function shouldShowPointSpawnCooldown( spawnPoint, ply, now )
    if now >= spawnPoint:GetCreationCooldownEndTime() then return false end
    if hook.Run( "CFC_SpawnPoints_IgnorePointSpawnCooldown", spawnPoint, ply ) then return false end

    return true
end

local function shouldShowPlayerSpawnCooldown( _spawnPoint, ply, now )
    if now >= ply:GetNWFloat( "CFC_SpawnPoints_SpawnCooldownEndTime", 0 ) then return false end
    if hook.Run( "CFC_SpawnPoints_IgnorePlayerSpawnCooldown", ply ) then return false end

    return true
end


----- ENTITY METHODS -----

function ENT:Initialize()
end

function ENT:Draw()
    self:DrawModel()
    self:TryDrawMessage()
end

function ENT:TryDrawMessage()
    local ply = LocalPlayer()

    if EyePos():Distance( self:GetPos() ) > MESSAGE_DRAW_DISTANCE then return end

    -- Health message
    local maxHealth = self:GetMaxHealth()

    if maxHealth > 0 then
        local health = self:Health()

        self:DrawMessage( "INTEGRITY: " .. math.Round( health ) .. "/" .. maxHealth, MESSAGE_COLOR_HEALTH, MESSAGE_ZOFFSET_HEALTH )
    end

    -- Link message
    if ply:GetNWEntity( "CFC_SpawnPoints_LinkedSpawnPoint" ) == self then return end
    if not CFC_SpawnPoints.IsFriendly( self, ply ) then return end

    local now = CurTime()

    if shouldShowPointSpawnCooldown( self, ply, now ) then
        self:DrawMessage( MESSAGE_TEXT_POINT_SPAWN_COOLDOWN, MESSAGE_COLOR_POINT_SPAWN_COOLDOWN )
    elseif shouldShowPlayerSpawnCooldown( self, ply, now ) then
        self:DrawMessage( MESSAGE_TEXT_PLAYER_SPAWN_COOLDOWN, MESSAGE_COLOR_PLAYER_SPAWN_COOLDOWN )
    else
        self:DrawMessage( MESSAGE_TEXT_LINK, MESSAGE_COLOR_LINK )
    end
end

function ENT:DrawMessage( text, color, zOffset )
    local lines = string.Split( text, "\n" )
    local lineCount = #lines
    zOffset = zOffset or 0

    local pos = self:GetPos() + Vector( 0, 0, MESSAGE_BOTTOM_HEIGHT + ( MESSAGE_FONT_SIZE + zOffset ) * MESSAGE_SCALE * lineCount )
    local ang = ( pos - EyePos() ):Angle()

    ang[1] = 0
    ang:RotateAroundAxis( ang:Up(), -90 )
    ang:RotateAroundAxis( ang:Forward(), 90 )

    cam.Start3D2D( pos, ang, MESSAGE_SCALE )
        local y = 0

        for _, line in ipairs( lines ) do
            draw.SimpleTextOutlined( line, "CFC_SpawnPoints_3D2DMessage", 0, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, MESSAGE_OUTLINE_SIZE, MESSAGE_OUTLINE_COLOR )
            y = y + MESSAGE_FONT_SIZE
        end
    cam.End3D2D()
end
