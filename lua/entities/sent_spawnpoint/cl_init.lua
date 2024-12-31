include( "shared.lua" )

local MESSAGE_DRAW_DISTANCE = 500
local MESSAGE_BOTTOM_HEIGHT = 20
local MESSAGE_CRISPNESS = 4
local MESSAGE_FONT_SIZE = 20 * MESSAGE_CRISPNESS
local MESSAGE_SCALE = 0.25 / MESSAGE_CRISPNESS
local MESSAGE_OUTLINE_SIZE = 0.5 * MESSAGE_CRISPNESS
local MESSAGE_OUTLINE_COLOR = Color( 0, 0, 0 )

local MESSAGE_TEXT_POINT_SPAWN_COOLDOWN = "CANNOT LINK\nCHARGING"
local MESSAGE_COLOR_POINT_SPAWN_COOLDOWN = Color( 255, 0, 0 )

local MESSAGE_TEXT_PLAYER_SPAWN_COOLDOWN = "CANNOT LINK\nCHARGING"
local MESSAGE_COLOR_PLAYER_SPAWN_COOLDOWN = Color( 255, 0, 0 )

local MESSAGE_TEXT_LINK = "PRESS E"
local MESSAGE_COLOR_LINK = Color( 250, 255, 0 )

local MESSAGE_ZOFFSET_HEALTH = -1 * MESSAGE_FONT_SIZE
local MESSAGE_COLOR_HEALTH = Color( 255, 255, 255 )
local MESSAGE_COLOR_HEALTH_BAR_FRIENDLY = Color( 0, 180, 255 )
local MESSAGE_COLOR_HEALTH_BAR_BG_FRIENDLY = Color( 0, 50, 70 )
local MESSAGE_COLOR_HEALTH_BAR_ENEMY = Color( 255, 0, 0 )
local MESSAGE_COLOR_HEALTH_BAR_BG_ENEMY = Color( 70, 0, 0 )
local MESSAGE_BAR_WIDTH = 100 * MESSAGE_CRISPNESS
local MESSAGE_BAR_HEIGHT = 20 * MESSAGE_CRISPNESS

local FRIENDLINESS_CACHE_COOLDOWN = 1 -- Friendliness is cached periodically while being drawn.

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
    self._inDrawDistance = false
    self._isFriendlyCache = false
    self._nextFriendlinessCacheTime = 0
end

function ENT:Draw()
    self:DrawModel()
    self:TryDrawMessage()
end

function ENT:TryDrawMessage()
    local ply = LocalPlayer()

    -- Draw distance check.
    if EyePos():Distance( self:GetPos() ) > MESSAGE_DRAW_DISTANCE then
        if self._inDrawDistance then -- Leaving draw distance
            self._inDrawDistance = false
        end

        return
    end

    if not self._inDrawDistance then -- Entering draw distance
        self._inDrawDistance = true
        self:UpdateFriendlinessCache( true ) -- Force update on enter
    else
        self:UpdateFriendlinessCache( false ) -- Periodic update while in draw distance
    end

    -- Health message
    local maxHealth = self:GetMaxHealth()
    local isFriendly = self._isFriendlyCache

    if maxHealth > 0 then
        local health = self:Health()
        local healthFrac = health / maxHealth

        if healthFrac < 1 then
            -- Health bar background
            local barColor = isFriendly and MESSAGE_COLOR_HEALTH_BAR_BG_FRIENDLY or MESSAGE_COLOR_HEALTH_BAR_BG_ENEMY

            self:DrawBar( 1, MESSAGE_BAR_WIDTH, MESSAGE_BAR_HEIGHT, barColor, MESSAGE_ZOFFSET_HEALTH )
        end

        local barColor = isFriendly and MESSAGE_COLOR_HEALTH_BAR_FRIENDLY or MESSAGE_COLOR_HEALTH_BAR_ENEMY

        self:DrawBar( healthFrac, MESSAGE_BAR_WIDTH, MESSAGE_BAR_HEIGHT, barColor, MESSAGE_ZOFFSET_HEALTH )
        self:DrawMessage( tostring( math.Round( health ) ), MESSAGE_COLOR_HEALTH, MESSAGE_ZOFFSET_HEALTH )
    end

    -- Link message
    if not isFriendly then return end
    if ply:GetNWEntity( "CFC_SpawnPoints_LinkedSpawnPoint" ) == self then return end

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

function ENT:DrawBar( frac, width, height, color, zOffset )
    zOffset = zOffset or 0

    local pos = self:GetPos() + Vector( 0, 0, MESSAGE_BOTTOM_HEIGHT + ( MESSAGE_FONT_SIZE + zOffset ) * MESSAGE_SCALE )
    local ang = ( pos - EyePos() ):Angle()

    ang[1] = 0
    ang:RotateAroundAxis( ang:Up(), -90 )
    ang:RotateAroundAxis( ang:Forward(), 90 )

    cam.Start3D2D( pos, ang, MESSAGE_SCALE )
        surface.SetDrawColor( color )
        surface.DrawRect( -width / 2, -height / 2, width * frac, height )
    cam.End3D2D()
end

function ENT:UpdateFriendlinessCache( force )
    if not force then
        local now = CurTime()
        if now < self._nextFriendlinessCacheTime then return end

        self._nextFriendlinessCacheTime = now + FRIENDLINESS_CACHE_COOLDOWN
    end

    self._isFriendlyCache = CFC_SpawnPoints.IsFriendly( self, LocalPlayer() )
end
