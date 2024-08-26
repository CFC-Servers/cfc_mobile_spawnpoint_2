include( "shared.lua" )

local MESSAGE_DRAW_DISTANCE = 300
local MESSAGE_FONT_SIZE = 32
local MESSAGE_BOTTOM_HEIGHT = 50

local MESSAGE_TEXT_POINT_SPAWN_COOLDOWN = "CANNOT LINK\n\nWAIT FOR\nTHE POINT\nTO CHARGE"
local MESSAGE_COLOR_POINT_SPAWN_COOLDOWN = Color( 255, 0, 0 )

local MESSAGE_TEXT_PLAYER_SPAWN_COOLDOWN = "CANNOT LINK\n\nWAIT FOR\nYOUR SOUL\nTO STRENGTHEN"
local MESSAGE_COLOR_PLAYER_SPAWN_COOLDOWN = Color( 255, 0, 0 )

local MESSAGE_TEXT_LINK = "PRESS E\nTO LINK"
local MESSAGE_COLOR_LINK = Color( 250, 255, 0 )

surface.CreateFont( "CFC_SpawnPoints_3D2DMessage", {
    font = "Arial",
    size = MESSAGE_FONT_SIZE,
    weight = 500,
    antialias = true,
    shadow = true,
} )


function ENT:Initialize()
end

function ENT:Draw()
    self:DrawModel()
    self:TryDrawMessage()
end

function ENT:TryDrawMessage()
    local ply = LocalPlayer()

    if self:GetNWEntity( "CFC_SpawnPoints_LinkedSpawnPoint" ) == ply then return end
    if EyePos():Distance( self:GetPos() ) > MESSAGE_DRAW_DISTANCE then return end
    if not CFC_SpawnPoints.IsFriendly( self, ply ) then return end

    local now = CurTime()

    if now < self:GetCreationCooldownEndTime() then
        self:DrawMessage( MESSAGE_TEXT_POINT_SPAWN_COOLDOWN, MESSAGE_COLOR_POINT_SPAWN_COOLDOWN )
    elseif now < ply:GetNWFloat( "CFC_SpawnPoints_SpawnCooldownEndTime", 0 ) then
        self:DrawMessage( MESSAGE_TEXT_PLAYER_SPAWN_COOLDOWN, MESSAGE_COLOR_PLAYER_SPAWN_COOLDOWN )
    else
        self:DrawMessage( MESSAGE_TEXT_LINK, MESSAGE_COLOR_LINK )
    end
end

function ENT:DrawMessage( text, color )
    local lines = string.Split( text, "\n" )
    local lineCount = #lines

    local pos = self:GetPos() + Vector( 0, 0, MESSAGE_BOTTOM_HEIGHT + MESSAGE_FONT_SIZE * lineCount )
    local ang = ( pos - EyePos() ):Angle()

    ang[1] = 0
    ang:RotateAroundAxis( ang:Up(), 90 )
    ang:RotateAroundAxis( ang:Forward(), 90 )

    cam.Start3D2D( pos, ang, 1 )
        local y = 0

        for _, line in ipairs( lines ) do
            draw.SimpleText( line, "CFC_SpawnPoints_3D2DMessage", 0, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
            y = y + MESSAGE_FONT_SIZE
        end
    cam.End3D2D()
end
