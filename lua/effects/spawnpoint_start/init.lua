EFFECT.r = math.random( 100, 255 )
EFFECT.b = math.random( 100, 255 )
EFFECT.g = math.random( 100, 255 )

function EFFECT:Init( data )
	local pos = data:GetOrigin()
	local emitter = ParticleEmitter( pos )
	local scale = data:GetScale()
	for _ = 0, 4 do
		local vel = ( VectorRand() * 20 ) * math.Rand( 0.001, 0.2 )
		vel.z = -( ( vel.x * vel.x ) + ( vel.y * vel.y ) )

		local dist = 16

		local particle = emitter:Add( "ss/light", pos + VectorRand() * dist )
		particle:SetVelocity( vel )
		particle:SetDieTime( math.Rand( 1, 3 ) )
		particle:SetStartAlpha( 250 )
		particle:SetEndAlpha( 250 )
		particle:SetStartSize( 32 * scale )
		particle:SetEndSize( 0 )
		particle:SetRoll( math.Rand( 0, 360 ) )
		particle:SetRollDelta( math.Rand( -5.5, 5.5 ) )
		particle:SetColor( self.r, self.b, self.g )

	end
	emitter:Finish()

end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end



