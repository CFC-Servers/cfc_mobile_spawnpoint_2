include( "shared.lua" )

local CurTime = CurTime

function ENT:Initialize()
    self.shieldSetupTime = CurTime() + self.ShieldSetupTime
end

function ENT:OnRemove()
    SafeRemoveEntity( self.Model1 )
    SafeRemoveEntity( self.Model2 )
    SafeRemoveEntity( self.Model3 )
    if self.settingUpSound1 then self.settingUpSound1:Stop() end
    if self.settingUpSound2 then self.settingUpSound2:Stop() end
    if self.shieldSound then self.shieldSound:Stop() end
    if self.terminalSound then self.terminalSound:Stop() end

end

local model1Offset = Vector( 0, 0, 0 )
local model1AngOffset = Angle( 0, 0, 0 )

local model2Offset = Vector( -10, 0, -50 )
local model2AngOffset = Angle( 0, 90, 0 )

local model2OffsetToScreen = Vector( 0, 30, 20 )

local model3Offset = Vector( -10, 45, -95 )
local model3AngOffset = Angle( 0, 0, 0 )

local CurTime = CurTime
local tostring = tostring
local math_Round = math.Round
local LocalPlayer = LocalPlayer

local tooFar = 250^2
local color_hud = Color( 200, 210, 255 )

function ENT:Draw()
    self:DrawModel()

end

function ENT:DrawTranslucent()
    local drawPos = self:LocalToWorld( model2Offset + model2OffsetToScreen )

    if drawPos:DistToSqr( LocalPlayer():GetShootPos() ) > tooFar then return end
    local toScreen = drawPos:ToScreen()

    cam.Start2D()
        surface.SetFont( "CreditsText" )
        surface.SetTextColor( color_hud )

        local text1 = ""
        if not self.shieldSetup then
            local shieldTimeLeft = self.shieldSetupTime - CurTime()
            shieldTimeLeft = math_Round( shieldTimeLeft, 1 )
            text1 = "Shield: " .. tostring( shieldTimeLeft ) .. "\n"

        else
            text1 = "Shield HP: " .. tostring( self:GetShieldHealth() )

        end

        local width = surface.GetTextSize( text1 )
        surface.SetTextPos( toScreen.x - width / 2, toScreen.y )
        surface.DrawText( text1 )

    cam.End2D()
end

function ENT:Think()
    self:DoDetails()
    local cur = CurTime()
    if self.shieldSetupTime > cur then
        if not self.settingUpSound1 or not self.settingUpSound1:IsPlaying() then
            self.settingUpSound1 = CreateSound( self, "ambient/levels/labs/machine_moving_loop3.wav" )
            self.settingUpSound1:SetSoundLevel( 65 )
            self.settingUpSound1:Play()
            self.settingUpSound1:ChangePitch( 120, self.ShieldSetupTime )

        end
        if not self.settingUpSound2 or not self.settingUpSound2:IsPlaying() then
            self.settingUpSound2 = CreateSound( self, "npc/scanner/scanner_combat_loop1.wav" )
            self.settingUpSound2:PlayEx( 1, 80 )
            self.settingUpSound2:ChangePitch( 110, self.ShieldSetupTime )

        end
    else
        if not self.shieldSetup then
            self.shieldSetup = true

        end
        local shieldMdl = self.Model1
        if IsValid( shieldMdl ) then
            local holding = self:ShieldIsHolding()
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
                    self.shieldSound:SetSoundLevel( 70 )
                    self.shieldSound:PlayEx( 1, 90 )

                end
            elseif self.shieldSound and self.shieldSound:IsPlaying() then
                self.shieldSound:Stop()

            end
        end
        if self.settingUpSound1 and self.settingUpSound1:IsPlaying() then
            self.settingUpSound1:Stop()

        end
        if self.settingUpSound2 and self.settingUpSound2:IsPlaying() then
            self.settingUpSound2:Stop()

        end


        if not self.terminalSound or not self.terminalSound:IsPlaying() then
            self.terminalSound = CreateSound( self, "ambient/machines/combine_terminal_loop1.wav" )
            self.terminalSound:SetSoundLevel( 65 )
            self.terminalSound:PlayEx( 1, 90 )

        end
    end

    self:SetNextClientThink( cur + 0.25 )
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
        self.Model1:SetMaterial( "effects/combineshield/comshieldwall3" )

    end
    if not IsValid( self.Model2 ) then
        self.Model2 = ClientsideModel( "models/props_combine/combine_intmonitor003.mdl", RENDERGROUP_OPAQUE )
        self.Model2.vecOffset = model2Offset
        self.Model2.angOffset = model2AngOffset

        self.Model2:SetPos( self:LocalToWorld( self.Model2.vecOffset ) )
        self.Model2:SetAngles( self:LocalToWorldAngles( self.Model2.angOffset ) )
        self.Model2:SetModelScale( 0.75, 0 )
        self.Model2:SetParent( self )

    end
    if not IsValid( self.Model3 ) then
        self.Model3 = ClientsideModel( "models/props_combine/combine_mine01.mdl" )
        self.Model3.vecOffset = model3Offset
        self.Model3.angOffset = model3AngOffset

        self.Model3:SetPos( self:LocalToWorld( self.Model3.vecOffset ) )
        self.Model3:SetAngles( self:LocalToWorldAngles( self.Model3.angOffset ) )
        self.Model3:SetModelScale( 1, 0 )
        self.Model3:SetParent( self )
        self.Model3:SetRenderMode( RENDERMODE_TRANSADD )
        self.Model3:SetColor( Color( 255, 255, 255, 100 ) )
        self.Model3:SetRenderFX( 16 ) --kRenderFxHologram

    end
    self.Models = { self.Model1, self.Model2, self.Model3 }

    -- reparent if we re-enter pvs
    for _, model in ipairs( self.Models ) do
        if model:GetParent() == self then continue end
        model:SetPos( self:LocalToWorld( model.vecOffset ) )
        model:SetAngles( self:LocalToWorldAngles( model.angOffset ) )
        model:SetParent( self )

    end
end