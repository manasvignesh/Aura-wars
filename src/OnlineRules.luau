-- Server reads these defaults at match boundaries. Studio overrides are optional.
return table.freeze({
	WinsRequired = 2,
	TurnSeconds = 45,
	WarningSeconds = 10,
	IntroductionSeconds = 2.2,
	ResultSeconds = 3.5,
	DrawReplaySeconds = 2.2,
	RematchSeconds = .35,
})
