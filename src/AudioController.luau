local SoundService=game:GetService("SoundService")
local ContentProvider=game:GetService("ContentProvider")
local Debris=game:GetService("Debris")
local Catalog=require(game.ReplicatedStorage.PenFight.AudioCatalog)
local Audio={}
Audio.__index=Audio
function Audio.new(prefs,gui)
	local self=setmetatable({prefs=prefs,gui=gui,sounds={},voices={},lastCrowd=-math.huge},Audio)
	self.folder=Instance.new("Folder");self.folder.Name="PenFightAudio";self.folder.Parent=SoundService
	self.effects=Instance.new("SoundGroup");self.effects.Name="Effects";self.effects.Parent=self.folder
	self.ambience=Instance.new("SoundGroup");self.ambience.Name="Ambience";self.ambience.Parent=self.folder
	for name,entry in pairs(Catalog) do
		local sound=Instance.new("Sound");sound.Name=name;sound.SoundId=entry.id;sound.Volume=entry.gain
		sound.SoundGroup=if name=="Ambience" then self.ambience else self.effects
		sound.Parent=self.folder;self.sounds[name]=sound
	end
	local function volumes() self.effects.Volume=prefs.Effects;self.ambience.Volume=prefs.Ambience end
	volumes();prefs.Changed:Connect(volumes)
	task.spawn(function()
		local list={};for _,sound in pairs(self.sounds) do table.insert(list,sound) end
		pcall(function() ContentProvider:PreloadAsync(list) end)
		for name,sound in pairs(self.sounds) do gui:SetAttribute("Audio"..name,if sound.IsLoaded then "Loaded" else "Unavailable") end
	end)
	task.spawn(function()
		task.wait(4)
		while self.folder.Parent do
			if prefs.Ambience>0 then self:Play("Ambience",.65,1) end
			task.wait(15+math.random()*9)
		end
	end)
	return self
end
function Audio:Play(name,strength,pitch)
	if name=="Ambience" and self.prefs.Ambience==0 then return end
	if name~="Ambience" and self.prefs.Effects==0 then return end
	local source=self.sounds[name];if not source then return end
	local active={};for _,sound in ipairs(self.voices) do if sound.Parent then table.insert(active,sound) end end
	self.voices=active
	if #active>=7 then return end
	local sound=source:Clone();sound.Name=name.."Voice"
	-- Built-in engine landing sample: quiet fallback for unavailable impact audio.
	if not source.IsLoaded then
		if name~="Impact" then sound:Destroy();return end
		sound.SoundId="rbxasset://sounds/action_jump_land.mp3"
	end
	sound.Volume=source.Volume*math.clamp(strength,0,1)
	sound.PlaybackSpeed=pitch or 1;sound.Parent=self.folder
	table.insert(self.voices,sound);Debris:AddItem(sound,12)
	sound.Ended:Once(function() sound:Destroy() end)
	pcall(function() sound:Play() end)
end
function Audio:Impact(intensity)
	self:Play("Impact",.15+.85*intensity,.97+math.random()*.08)
	if intensity>.65 and os.clock()-self.lastCrowd>4 then
		self.lastCrowd=os.clock();self:Play("Crowd",.28,1)
	end
end
function Audio:Winner()
	self.lastCrowd=os.clock();self:Play("Crowd",.7,1)
end
return Audio
