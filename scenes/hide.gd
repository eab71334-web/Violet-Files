extends Screen
## مشهد الاختباء (الوثيقة 6.6): ابقَ ساكنًا أثناء اقتراب الخطوات.
## Hold the button to stay still while footsteps approach.

const DURATION := 12.0

var sc: Dictionary
var t := 0.0
var holding := false
var exposure := 0.0
var finished := false
var windows: Array = []
var danger_label: Label
var exposure_bar: ProgressBar
var time_bar: ProgressBar
var hold_btn: Button


func _ready() -> void:
	setup(Loc.t("hide_title"))
	var case_def := Game.load_case(Game.active_case)
	var sid := str(Game.case_state.get("current_scene", ""))
	for s in case_def["scenes"]:
		if s["id"] == sid:
			sc = s
	box.add_child(UI.label(Loc.pick(sc.get("intro", "")), 32, UI.TEXT))
	if Game.settings.get("no_scares", false):
		box.add_child(UI.label(Loc.t("hide_skipped"), 30, UI.MUTED))
		_finish(true)
		return
	var tt := 1.5
	while tt < DURATION - 1.0:
		windows.append(Vector2(tt, tt + randf_range(1.0, 1.6)))
		tt += randf_range(2.6, 3.4)
	danger_label = UI.label("", 40, UI.MUTED, true)
	box.add_child(danger_label)
	time_bar = UI.bar(0, DURATION, UI.GLOW)
	box.add_child(time_bar)
	box.add_child(UI.label(Loc.t("exposure"), 28, UI.RED))
	exposure_bar = UI.bar(0, 100, UI.RED)
	box.add_child(exposure_bar)
	hold_btn = Button.new()
	hold_btn.text = Loc.t("hold_still")
	hold_btn.custom_minimum_size = Vector2(0, 360)
	hold_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hold_btn.add_theme_font_size_override("font_size", UI.fs(44))
	hold_btn.button_down.connect(func(): holding = true)
	hold_btn.button_up.connect(func(): holding = false)
	box.add_child(hold_btn)


func _in_danger() -> bool:
	for w in windows:
		if t >= w.x and t <= w.y:
			return true
	return false


func _process(delta: float) -> void:
	if finished or hold_btn == null:
		return
	t += delta
	var danger := _in_danger()
	if danger:
		danger_label.text = Loc.t("steps_near")
		danger_label.add_theme_color_override("font_color", UI.RED)
		if not holding:
			exposure += delta * 45.0
	else:
		danger_label.text = Loc.t("steps_far")
		danger_label.add_theme_color_override("font_color", UI.MUTED)
		exposure = maxf(0.0, exposure - delta * 10.0)
	exposure_bar.value = exposure
	time_bar.value = t
	if exposure >= 100.0:
		_finish(false)
	elif t >= DURATION:
		_finish(true)


func _finish(ok: bool) -> void:
	finished = true
	if hold_btn != null:
		hold_btn.disabled = true
	Game.change_nerves(-10 if ok else -30)
	if ok:
		var clue: Dictionary = sc.get("reward", {})
		if not clue.is_empty():
			Game.add_evidence({
				"id": str(clue["id"]), "label": Loc.pick(clue["label"]), "desc": Loc.pick(clue["desc"]),
				"kind": "real", "quality": 0.85, "src": "hide", "supports": clue.get("supports", []),
			})
			box.add_child(UI.label(Loc.pick(clue["desc"]), 32, UI.GOLD))
		box.add_child(UI.label(Loc.t("hide_ok"), 36, UI.GLOW, true))
	else:
		box.add_child(UI.label(Loc.t("hide_caught"), 36, UI.RED, true))
	if bool(Game.case_state.get("fainted", false)):
		Game.case_state.erase("fainted")
		box.add_child(UI.label(Loc.t("fainted"), 32, UI.RED, true))
	Game.save()
	box.add_child(UI.button(Loc.t("back"), func(): Game.goto("case_hub")))
