local Preferences = {
	ReducedMotion = false,
	PrecisionView = false,
	Effects = 0.65,
	Ambience = 0.35,
	CameraSensitivity = 1.0,
	VisualQuality = "Auto",
}

local changed = Instance.new("BindableEvent")
Preferences.Changed = changed.Event

function Preferences.Set(key, value)
	if key == "ReducedMotion" or key == "PrecisionView" then
		Preferences[key] = value == true
	elseif key == "Effects" or key == "Ambience" then
		Preferences[key] = math.clamp(value, 0, 1)
	elseif key == "CameraSensitivity" then
		Preferences[key] = math.clamp(value, 0.2, 3.0)
	elseif key == "VisualQuality" and (value == "Auto" or value == "Rich" or value == "Simple") then
		Preferences[key] = value
	else
		return
	end
	changed:Fire(key, Preferences[key])
end

return Preferences
