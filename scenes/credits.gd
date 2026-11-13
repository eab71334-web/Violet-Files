extends Screen
## الاعتمادات.


func _ready() -> void:
	setup(Loc.t("credits"), false)
	var c := UI.card(box)
	c.add_child(UI.label(Loc.t("game_title"), 56, UI.GLOW, true))
	c.add_child(UI.label(Loc.t("credits_text"), 30))
	box.add_child(UI.button(Loc.t("back"), func(): Game.goto("main_menu"), 90))
