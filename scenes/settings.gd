extends Screen
## الإعدادات (الوثيقة 3): لغة، صوت، رسوميات، وصول.

var _confirm_reset := false


func _ready() -> void:
	setup(Loc.t("settings_title"), false)
	_render()


func _render() -> void:
	clear_box()
	box.add_child(UI.button(Loc.t("language") + ": " + ("العربية" if Loc.lang == "ar" else "English"), _toggle_lang))
	box.add_child(UI.button(Loc.t("difficulty") + ": " + Loc.t("diff_" + str(Game.settings.get("difficulty", "detective"))), _cycle_difficulty))
	box.add_child(_slider(Loc.t("music"), "music"))
	box.add_child(_slider(Loc.t("sfx"), "sfx"))
	box.add_child(_toggle(Loc.t("low_gfx"), "low_gfx"))
	box.add_child(_toggle(Loc.t("big_font"), "big_font"))
	box.add_child(_toggle(Loc.t("no_scares"), "no_scares"))
	box.add_child(UI.label(Loc.t("audio_note"), 24, UI.MUTED))
	var rb := UI.button(Loc.t("reset_confirm") if _confirm_reset else Loc.t("reset_save"), _reset)
	rb.add_theme_color_override("font_color", UI.RED)
	box.add_child(rb)
	box.add_child(UI.button(Loc.t("back"), func(): Game.goto("main_menu"), 90))


func _cycle_difficulty() -> void:
	var order := ["beginner", "detective", "expert"]
	var i := order.find(str(Game.settings.get("difficulty", "detective")))
	Game.settings["difficulty"] = order[(i + 1) % order.size()]
	Game.save()
	_render()


func _toggle_lang() -> void:
	Loc.set_lang("en" if Loc.lang == "ar" else "ar")
	Game.settings["lang"] = Loc.lang
	Game.save()
	Game.goto("settings")


func _slider(title: String, key: String) -> Control:
	var c := VBoxContainer.new()
	c.add_child(UI.label(title, 30))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Game.settings.get(key, 0.8))
	s.custom_minimum_size = Vector2(0, 60)
	s.value_changed.connect(func(v: float): _set_value(key, v))
	c.add_child(s)
	return c


func _toggle(title: String, key: String) -> Control:
	var cb := CheckButton.new()
	cb.text = title
	cb.add_theme_font_size_override("font_size", UI.fs(32))
	cb.button_pressed = bool(Game.settings.get(key, false))
	cb.toggled.connect(func(on: bool): _set_flag(key, on))
	return cb


func _set_value(key: String, v: float) -> void:
	Game.settings[key] = v
	Game.save()


func _set_flag(key: String, on: bool) -> void:
	Game.settings[key] = on
	Game.save()


func _reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_render()
		return
	Game.new_game()
	_confirm_reset = false
	toast(Loc.t("reset_done"))
	_render()
