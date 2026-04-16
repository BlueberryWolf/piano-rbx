local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PianoMain = require(script.Parent.PianoMain)

type Props = {
	Scope: any,
	PressedKeys: Fusion.UsedAs<{ [number]: boolean }>,
	SustainActive: Fusion.UsedAs<boolean>,
	SoundfontName: Fusion.UsedAs<string>,
	CurrentLayout: Fusion.UsedAs<string>,
	CustomMapping: Fusion.UsedAs<{ [Enum.KeyCode]: number }>,
	BindingMidi: Fusion.UsedAs<number?>,
	OnKeyPressed: (midi: number) -> (),
	OnKeyReleased: (midi: number) -> (),
	OnSustainToggled: () -> (),
	OnSetLayout: (layout: string) -> (),
	OnStartBinding: (midi: number) -> (),
	OnClearMapping: (midi: number) -> (),
	IsPreloading: Fusion.UsedAs<boolean>,
	OnPanic: () -> (),
}

return function(props: Props)
	local scope = props.Scope

	return scope:New("ScreenGui")({
		Name = "PianoGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		[Fusion.Children] = PianoMain(props),
	})
end
