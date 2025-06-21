include( "shared.lua" )

local entMeta = FindMetaTable( "Entity" )
local vecMeta = FindMetaTable( "Vector" )
local LocalPlayer = LocalPlayer
local EyePos = EyePos

local LEGAL_MATERIAL = ""
local LEGAL_ALPHA = 255

local MESSAGE_DRAW_DISTANCE = 500
local MESSAGE_FADE_START_DISTANCE = 300 -- 0 to disable fading
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

local MESSAGE_TEXT_LINKHINT = "PRESS %s"
local MESSAGE_COLOR_LINKHINT = Color( 250, 255, 0 )

local MESSAGE_ZOFFSET_HEALTH = -1 * MESSAGE_FONT_SIZE
local MESSAGE_COLOR_HEALTH = Color( 255, 255, 255 )
local MESSAGE_COLOR_HEALTH_BAR_FRIENDLY = Color( 0, 180, 255 )
local MESSAGE_COLOR_HEALTH_BAR_BG_FRIENDLY = Color( 0, 50, 70 )
local MESSAGE_COLOR_HEALTH_BAR_ENEMY = Color( 255, 0, 0 )
local MESSAGE_COLOR_HEALTH_BAR_BG_ENEMY = Color( 70, 0, 0 )
local MESSAGE_BAR_WIDTH = 100 * MESSAGE_CRISPNESS
local MESSAGE_BAR_HEIGHT = 20 * MESSAGE_CRISPNESS

local FRIENDLINESS_CACHE_COOLDOWN = 1 -- Friendliness is cached periodically while within draw distance.

surface.CreateFont( "CFC_SpawnPoints_3D2DMessage", {
    font = "Arial",
    size = MESSAGE_FONT_SIZE,
    weight = 500,
    antialias = true,
    shadow = false,
} )

local spawnRadiusMatrix = Matrix()


----- PRIVATE FUNCTIONS -----

local function shouldShowPointSpawnCooldown( spawnPoint, ply, now )
    if now >= spawnPoint:GetCreationCooldownEndTime() then return false end
    if hook.Run( "CFC_SpawnPoints_IgnorePointSpawnCooldown", spawnPoint, ply ) then return false end

    return true
end

local function shouldShowPlayerSpawnCooldown( _spawnPoint, ply, now )
    if now >= CFC_SpawnPoints.GetSpawnCooldownEndTime( ply ) then return false end
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
    local myTbl = entMeta.GetTable( self )
    entMeta.DrawModel( self )
    myTbl.TryDrawMessage( self, myTbl )
    myTbl.TryDrawSpawnRadius( self, myTbl )
end

function ENT:TryDrawMessage( myTbl )
    local ply = LocalPlayer()
    local myPos = entMeta.GetPos( self )
    local eyeDist = vecMeta.Distance( EyePos(), myPos )

    -- Draw distance check.
    if eyeDist > MESSAGE_DRAW_DISTANCE then
        if myTbl._inDrawDistance then -- Leaving draw distance
            myTbl._inDrawDistance = false
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
    local maxHealth = self:GetPointMaxHealth()
    local isFriendly = self._isFriendlyCache
    local alpha = 255

    if MESSAGE_FADE_START_DISTANCE ~= 0 and eyeDist > MESSAGE_FADE_START_DISTANCE then
        local distFromStart = ( eyeDist - MESSAGE_FADE_START_DISTANCE )
        local fadeRange = MESSAGE_DRAW_DISTANCE - MESSAGE_FADE_START_DISTANCE
        local farFrac = distFromStart / fadeRange

        alpha = ( 1 - farFrac ) * 255
    end

    if maxHealth > 0 then
        local health = self:GetPointHealth()
        local healthFrac = health / maxHealth

        if healthFrac < 1 then
            -- Health bar background
            local barColor = isFriendly and MESSAGE_COLOR_HEALTH_BAR_BG_FRIENDLY or MESSAGE_COLOR_HEALTH_BAR_BG_ENEMY

            self:DrawBar( 1, MESSAGE_BAR_WIDTH, MESSAGE_BAR_HEIGHT, barColor, alpha, MESSAGE_ZOFFSET_HEALTH )
        end

        local barColor = isFriendly and MESSAGE_COLOR_HEALTH_BAR_FRIENDLY or MESSAGE_COLOR_HEALTH_BAR_ENEMY

        self:DrawBar( healthFrac, MESSAGE_BAR_WIDTH, MESSAGE_BAR_HEIGHT, barColor, alpha, MESSAGE_ZOFFSET_HEALTH )
        self:DrawMessage( tostring( math.Round( health ) ), MESSAGE_COLOR_HEALTH, alpha, MESSAGE_ZOFFSET_HEALTH )
    end

    -- Link message
    if not isFriendly then return end
    if CFC_SpawnPoints.GetLinkedSpawnPoint( ply ) == self then return end

    local now = CurTime()

    if shouldShowPointSpawnCooldown( self, ply, now ) then
        self:DrawMessage( MESSAGE_TEXT_POINT_SPAWN_COOLDOWN, MESSAGE_COLOR_POINT_SPAWN_COOLDOWN, alpha )
    elseif shouldShowPlayerSpawnCooldown( self, ply, now ) then
        self:DrawMessage( MESSAGE_TEXT_PLAYER_SPAWN_COOLDOWN, MESSAGE_COLOR_PLAYER_SPAWN_COOLDOWN, alpha )
    else
        local useKey = input.LookupBinding( "+use" )
        if useKey then -- how are you playing without +use bound?
            self:DrawMessage( string.format( MESSAGE_TEXT_LINKHINT, string.upper( useKey ) ), MESSAGE_COLOR_LINKHINT, alpha )
        end
    end
end

function ENT:TryDrawSpawnRadius( myTbl )
    local endTime = myTbl._showSpawnRadiusEndTime
    if not endTime then return end

    local radius = self:GetSpawnRadius()

    if radius < 16 or CurTime() > endTime then
        myTbl._showSpawnRadiusEndTime = nil
        return
    end

    spawnRadiusMatrix:SetTranslation( entMeta.GetPos( self ) )
    spawnRadiusMatrix:SetAngles( entMeta.GetAngles( self ) )

    cam.PushModelMatrix( spawnRadiusMatrix, true )
    surface.DrawCircle( 0, 0, radius, 255, 150, 50, 255 )
    cam.PopModelMatrix()
end

function ENT:DrawMessage( text, color, alpha, zOffset )
    local lines = string.Split( text, "\n" )
    local lineCount = #lines
    zOffset = zOffset or 0

    local pos = self:GetPos() + Vector( 0, 0, MESSAGE_BOTTOM_HEIGHT + ( MESSAGE_FONT_SIZE + zOffset ) * MESSAGE_SCALE * lineCount )
    local ang = ( pos - EyePos() ):Angle()

    if alpha then
        color.a = alpha
        MESSAGE_OUTLINE_COLOR.a = alpha
    else
        MESSAGE_OUTLINE_COLOR.a = color.a
    end

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

function ENT:DrawBar( frac, width, height, color, alpha, zOffset )
    zOffset = zOffset or 0

    local pos = self:GetPos() + Vector( 0, 0, MESSAGE_BOTTOM_HEIGHT + ( MESSAGE_FONT_SIZE + zOffset ) * MESSAGE_SCALE )
    local ang = ( pos - EyePos() ):Angle()

    if alpha then
        color.a = alpha
    end

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

function ENT:Think()
    if entMeta.IsDormant( self ) then
        entMeta.SetNextClientThink( self, CurTime() + 1 )
        return true
    end

    local color = entMeta.GetColor( self )

    -- Enforce color and material in clientside think, to combat serverside setcolor-on-tick.
    -- Also less serverside perf cost, no networking nonsense, and only applies within PVS.
    -- Doesn't check draw distance, as :Draw() isn't called when alpha is zero, so it would need to be checked manually, defeating the purpose of the optimization.
    if color.a ~= LEGAL_ALPHA then
        color.a = LEGAL_ALPHA
        entMeta.SetColor( self, color )
    end

    if entMeta.GetMaterial( self ) ~= LEGAL_MATERIAL then
        entMeta.SetMaterial( self, LEGAL_MATERIAL )
    end

    entMeta.SetNextClientThink( self, 0 )

    return true
end
