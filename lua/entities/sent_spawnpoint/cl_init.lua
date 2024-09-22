include( "shared.lua" )

local CurTime = CurTime

function ENT:OnRemove()
    SafeRemoveEntity( self.Model1 )
    if self.settingUpSound1 then self.settingUpSound1:Stop() end
    if self.shieldSound then self.shieldSound:Stop() end

end

local model1Offset = Vector( 0, 0, 0 )
local model1AngOffset = Angle( 0, 0, 0 )
local textOffs = Vector( 0, 0, 25 )

local CurTime = CurTime
local tostring = tostring
local math_Round = math.Round
local LocalPlayer = LocalPlayer

local tooFar = 150^2
local color_hud = Color( 255, 210, 0 )

function ENT:Draw()
    self:DrawModel()

end

local hasLinkedAtLeastOnce

net.Receive( "CFC_spawnpoints_linkedtospawn", function()
    hasLinkedAtLeastOnce = true

end )

function ENT:DrawTranslucent()
    local drawPos = self:LocalToWorld( textOffs )

    if drawPos:DistToSqr( LocalPlayer():GetShootPos() ) > tooFar then return end
    local toScreen = drawPos:ToScreen()

    cam.Start2D()
        surface.SetFont( "CreditsText" )
        surface.SetTextColor( color_hud )

        local setupTime = self:GetShieldSetupTime()

        local text = ""
        if not hasLinkedAtLeastOnce then
            text = "Press E"

        elseif not self:GetShieldOn() then
            text = "Shield OFF"

        elseif setupTime > CurTime() then
            local shieldTimeLeft = setupTime - CurTime()
            shieldTimeLeft = math_Round( shieldTimeLeft )
            text = "Shield: " .. tostring( shieldTimeLeft ) .. ""

        else
            text = "Shield HP: " .. tostring( self:GetShieldHealth() )

        end

        local width1 = surface.GetTextSize( text )
        surface.SetTextPos( toScreen.x - width1 / 2, toScreen.y )
        surface.DrawText( text )

    cam.End2D()
end

function ENT:Think()
    local cur = CurTime()

    self:DoDetails()
    local setupTime = self:GetShieldSetupTime()

    if setupTime > cur then
        if not self.settingUpSound1 or not self.settingUpSound1:IsPlaying() then
            local setupTimeTaken = self:ShieldSetupTimeTaken()
            self.settingUpSound1 = CreateSound( self, "ambient/levels/canals/manhack_machine_loop1.wav" )
            self.settingUpSound1:SetSoundLevel( 58 )
            self.settingUpSound1:PlayEx( 0.5, 90 )
            self.settingUpSound1:ChangeVolume( 1, setupTimeTaken )
            self.settingUpSound1:ChangePitch( 125, setupTimeTaken )
        end
    else
        if self.settingUpSound1 and self.settingUpSound1:IsPlaying() then
            self.settingUpSound1:Stop()
        end
    end

    local shieldMdl = self.Model1
    if IsValid( shieldMdl ) then
        local holding = self:ShieldIsHolding() and self:GetShieldOn()
        -- shield is on, show shield model
        if holding and shieldMdl:GetNoDraw() then
            shieldMdl:SetNoDraw( false )
        -- shield is broken, hide shield model
        elseif not holding and not shieldMdl:GetNoDraw() then
            shieldMdl:SetNoDraw( true )
        end
        if holding then
            if not self.shieldSound or not self.shieldSound:IsPlaying() then
                self.shieldSound = CreateSound( self, "ambient/machines/combine_shield_loop3.wav" )
                self.shieldSound:SetSoundLevel( 60 )
                self.shieldSound:PlayEx( 1, 120 )
            end
        elseif self.shieldSound and self.shieldSound:IsPlaying() then
            self.shieldSound:Stop()
        end
    end

    self:SetNextClientThink( cur + 0.5 )
    return true
end

local IsValid = IsValid

function ENT:DoDetails()
    if not IsValid( self.Model1 ) then
        self.Model1 = ClientsideModel( self:GetModel() )
        self.Model1.vecOffset = model1Offset
        self.Model1.angOffset = model1AngOffset

        self.Model1:SetPos( self:LocalToWorld( self.Model1.vecOffset ) )
        self.Model1:SetAngles( self:LocalToWorldAngles( self.Model1.angOffset ) )
        self.Model1:SetModelScale( 1.1, 0 )
        self.Model1:SetParent( self )
        self.Model1:SetNoDraw( not self:GetShielded() )
        self.Model1:SetMaterial( "effects/combineshield/comshieldwall" )
    end
    self.Models = { self.Model1 }

    -- reparent if we re-enter pvs
    for _, model in ipairs( self.Models ) do
        if model:GetParent() == self then continue end
        model:SetPos( self:LocalToWorld( model.vecOffset ) )
        model:SetAngles( self:LocalToWorldAngles( model.angOffset ) )
        model:SetParent( self )
    end
end