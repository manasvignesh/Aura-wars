-- All force/feel tuning lives here. Shared curve; server recomputes speed from charge.
local T = {
	MinSpeed = 1.5,
	MaxSpeed = 28,
	PowerExponent = 1.65,
	MinPower = .025,
	DragDeadzonePixels = 8,
	DragScreenFraction = .34,
	MinDragPixels = 115,
	MaxDragPixels = 210,
	SurfaceFriction = .10,
	PenElasticity = .08,
	DeskElasticity = .04,
	Density = 1.4,
	LinearDamping = .18,
	SpinDamping = 1.35,
	SpinTransfer = .58,
	MaxContactOffset = 1.35,
	RestLinear = .12,
	RestAngular = .18,
	RestDuration = .55,
	MinShotTime = .6,
	MaxShotTime = 12,
	ImpactMinSpeed = 1.1,
	ImpactFullSpeed = 18,
	ImpactCooldown = .20,
	-- Phase 2B: Character Movement, Reach & Tactical System
	MaxReachDistance = 5.3,
	MaxServerReachTolerance = 5.6,
	MinReachDot = -0.40,
	WalkSpeed = 16,
	CharacterScale = 1.85,
	CameraSensitivity = 1.0,
	TrackingDuration = 2.2,
}
function T.EffectivePower(charge)
	return math.clamp(charge,0,1)^T.PowerExponent
end
function T.Speed(charge)
	return T.MinSpeed+(T.MaxSpeed-T.MinSpeed)*T.EffectivePower(charge)
end
function T.ChargeFromPixels(distance, viewport)
	local maximum=math.clamp(math.min(viewport.X,viewport.Y)*T.DragScreenFraction,T.MinDragPixels,T.MaxDragPixels)
	return math.clamp((distance-T.DragDeadzonePixels)/maximum,0,1)
end
return table.freeze(T)
