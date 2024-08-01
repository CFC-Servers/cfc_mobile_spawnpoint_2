
function EFFECT:Init( data )
    local pos = data:GetOrigin()
    local emitter = ParticleEmitter( pos )

    -- Angle is used to store the color, since eff:SetColor() is limited to a single 0-255 number.
    local colorAng = data:GetAngles()
    local r = colorAng.p
    local g = colorAng.y
    local b = colorAng.r

    for _ = 0, 4 do
        local vel = ( VectorRand() * 20 ) * math.Rand( 0.001, 0.2 )
        vel.z = -( ( vel.x * vel.x ) + ( vel.y * vel.y ) )

        local particle = emitter:Add( "ss/light", pos + VectorRand() * 16 )
        particle:SetVelocity( vel )
        particle:SetDieTime( math.Rand( 2, 5 ) )
        particle:SetStartAlpha( 250 )
        particle:SetEndAlpha( 250 )
        particle:SetStartSize( 32 )
        particle:SetEndSize( 0 )
        particle:SetRoll( math.Rand( 0, 360 ) )
        particle:SetRollDelta( math.Rand( -5.5, 5.5 ) )
        particle:SetColor( r, b, g )
    end

    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end
