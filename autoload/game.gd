extends Node
## الحالة العامة للعبة + الحفظ (JSON) + تحميل القضايا.
## Global game state, JSON save/load and case loading.

signal state_changed

const SAVE_PATH := "user://violet_save.json"
const BAG_SIZE := 4
const RENT_EVERY := 7
const HOURS_PER_SCENE := 2

# الأدوات والهواتف تُحمَّل من data/shop.json
var TOOLS: Dictionary = {}
var PHONES: Dictionary = {}

const DISTRICTS := {
	"rust": {"ar": "حي الصدأ", "en": "Rust District"},
	"downtown": {"ar": "وسط المدينة", "en": "Downtown"},
	"hill": {"ar": "الضواحي (الهضبة)", "en": "The Hill"},
	"port": {"ar": "الميناء", "en": "The Port"},
}

const APARTMENTS := [
	{"ar": "غرفة رخيصة", "en": "Cheap Room", "rent": 250},
	{"ar": "شقة صغيرة", "en": "Small Flat", "rent": 400},
	{"ar": "شقة جيدة", "en": "Nice Flat", "rent": 600},
]

const CAR := {"ar": "الخنفساء الصدئة", "en": "The Rusty Beetle", "fuel": 10}

var money: int = 500
var day: int = 1
var next_rent_day: int = 7
var nerves: int = 100
var apartment_tier: int = 1
var reputation := {"rust": 0, "downtown": 0, "hill": 0, "port": 0}
var owned: Array = ["flashlight", "phone_cheap"]
var completed := {}            # case_id -> stars
var yasser_pieces: Array = []  # [{id, text}]
var decisions := {}            # قرارات تنتقل للمواسم القادمة
var police_rep: int = 0   # سمعة عند الشرطة (قانوني)
var street_rep: int = 0   # سمعة عند الشارع (رمادي)
var settings := {"difficulty": "detective", "lang": "ar", "music": 0.8, "sfx": 0.8, "low_gfx": false, "big_font": false, "no_scares": false}

var pending_case: String = ""
var active_case: String = ""
var case_state := {}           # حالة القضية الجارية
var engines := {}              # محركات الاستجواب المؤقتة (لا تُحفظ)
var return_to: String = "main_menu"   # أين يرجع زر «عودة» في المتجر والأرشيف

var _case_cache := {}


func _ready() -> void:
	randomize()
	var shop = _read_json("res://data/shop.json")
	if shop is Dictionary:
		TOOLS = shop["tools"]
		PHONES = shop["phones"]
	load_settings_only()


# ---------------------------------------------------------------- scenes
func goto(scene_name: String) -> void:
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene_name)


# ---------------------------------------------------------------- data
func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing file: " + path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Bad JSON: " + path)
	return parsed


func case_index() -> Array:
	return _read_json("res://data/cases/index.json")


func load_case(id: String) -> Dictionary:
	if _case_cache.has(id):
		return _case_cache[id]
	var d = _read_json("res://data/cases/%s.json" % id)
	if d == null:
		return {}
	_case_cache[id] = d
	return d


## أول قضية قابلة للعب لم تُكمل بعد. فارغ لو لم يبق شيء.
func next_case_id() -> String:
	for entry in case_index():
		if entry.get("playable", false) and not completed.has(entry["id"]):
			return str(entry["id"])
	return ""


# ---------------------------------------------------------------- economy
func add_money(n: int) -> void:
	money += n
	state_changed.emit()


func spend(n: int) -> bool:
	if money < n:
		return false
	money -= n
	state_changed.emit()
	return true


func change_rep(district: String, delta: int) -> void:
	if reputation.has(district):
		reputation[district] = clampi(int(reputation[district]) + delta, -100, 100)
	state_changed.emit()


## الأعصاب تصل صفرًا = إغماء (الوثيقة 21): علاج 150 وتخسر 3 ساعات من المهلة.
func change_nerves(delta: int) -> void:
	nerves = clampi(nerves + delta, 0, 100)
	if nerves <= 0:
		nerves = 30
		money = maxi(0, money - 150)
		if not case_state.is_empty():
			case_state["hours_left"] = maxi(0, int(case_state.get("hours_left", 0)) - 3)
			case_state["fainted"] = true
	state_changed.emit()


func hours_factor() -> float:
	match str(settings.get("difficulty", "detective")):
		"beginner":
			return 1.25
		"expert":
			return 0.75
	return 1.0


func change_police_rep(d: int) -> void:
	police_rep = clampi(police_rep + d, -100, 100)


func change_street_rep(d: int) -> void:
	street_rep = clampi(street_rep + d, -100, 100)


func phone_quality() -> float:
	var best := 0.0
	for k in PHONES:
		if k in owned:
			best = maxf(best, float(PHONES[k]["quality"]))
	return best


func rent_now() -> int:
	return int(APARTMENTS[apartment_tier]["rent"])


func in_bag(tool_id: String) -> bool:
	return tool_id in case_state.get("bag", [])


## يبدأ يومًا جديدًا ويفحص الإيجار. يرجع مفتاح رسالة.
func _new_day() -> String:
	day += 1
	var msg := ""
	if day >= next_rent_day:
		var r := rent_now()
		if money >= r:
			money -= r
			msg = "rent_paid"
		else:
			# الخسارة بدون نهاية: شقة أسوأ ويبقى لغز أخيك مفتوحًا
			apartment_tier = maxi(0, apartment_tier - 1)
			money = 40
			msg = "bankrupt"
		next_rent_day += RENT_EVERY
	return msg


## ينام: راحة أعصاب + يوم جديد.
func sleep() -> String:
	nerves = mini(100, nerves + 40)
	var msg := _new_day()
	if msg == "":
		msg = "slept"
	state_changed.emit()
	save()
	return msg


# ---------------------------------------------------------------- cases
func start_case(id: String, price: int) -> void:
	var c := load_case(id)
	active_case = id
	pending_case = ""
	engines.clear()
	case_state = {
		"price": price,
		"hours_left": int(round(float(c.get("hours", 8)) * hours_factor())),
		"decided": [],
		"difficulty": str(settings.get("difficulty", "detective")),
		"battery": 100.0,
		"bag": ["flashlight"],
		"evidence": [],
		"statements": [],
		"illegal": 0,
		"scenes_done": [],
		"witnesses_done": [],
		"answer": "",
		"support": [],
	}


func add_evidence(e: Dictionary) -> void:
	for x in case_state["evidence"]:
		if x["id"] == e["id"]:
			return
	case_state["evidence"].append(e)


func has_evidence(id: String) -> bool:
	for x in case_state.get("evidence", []):
		if x["id"] == id:
			return true
	return false


func add_yasser(id: String, text: String) -> void:
	for p in yasser_pieces:
		if p["id"] == id:
			return
	yasser_pieces.append({"id": id, "text": text})


## ينهي القضية ويطبّق النتيجة على المال والسمعة والأرشيف.
func finish_case(result: Dictionary) -> void:
	var c := load_case(active_case)
	var district := str(c.get("district", "downtown"))
	add_money(int(result["reward"]))
	if result["correct"]:
		change_rep(district, 6)
	elif result["partial"]:
		change_rep(district, 1)
	else:
		change_rep(district, -10)
		decisions["wronged_" + active_case] = case_state.get("answer", "")
	completed[active_case] = int(result["stars"])
	nerves = maxi(20, nerves - 10)
	var rent_msg := _new_day()   # كل قضية تأخذ يومًا
	case_state["rent_msg"] = rent_msg
	state_changed.emit()
	save()


# ---------------------------------------------------------------- save / load
func new_game() -> void:
	var keep_settings := settings.duplicate()
	money = 500
	day = 1
	next_rent_day = RENT_EVERY
	nerves = 100
	apartment_tier = 1
	reputation = {"rust": 0, "downtown": 0, "hill": 0, "port": 0}
	owned = ["flashlight", "phone_cheap"]
	completed = {}
	police_rep = 0
	street_rep = 0
	yasser_pieces = []
	decisions = {}
	pending_case = ""
	active_case = ""
	case_state = {}
	engines.clear()
	settings = keep_settings
	save()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save() -> void:
	var d := {
		"v": 1,
		"money": money, "day": day, "next_rent_day": next_rent_day, "nerves": nerves,
		"apartment_tier": apartment_tier, "reputation": reputation, "owned": owned,
		"police_rep": police_rep, "street_rep": street_rep, "completed": completed, "yasser_pieces": yasser_pieces, "decisions": decisions,
		"settings": settings, "pending_case": pending_case, "active_case": active_case,
		"case_state": case_state,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func _read_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func load_settings_only() -> void:
	var d := _read_save()
	if d.has("settings"):
		for k in d["settings"]:
			settings[k] = d["settings"][k]
	Loc.set_lang(str(settings.get("lang", "ar")))


func load_game() -> bool:
	var d := _read_save()
	if d.is_empty():
		return false
	money = int(d.get("money", 500))
	day = int(d.get("day", 1))
	next_rent_day = int(d.get("next_rent_day", RENT_EVERY))
	nerves = int(d.get("nerves", 100))
	apartment_tier = clampi(int(d.get("apartment_tier", 1)), 0, APARTMENTS.size() - 1)
	var rep: Dictionary = d.get("reputation", {})
	for k in reputation:
		reputation[k] = int(rep.get(k, 0))
	owned = d.get("owned", ["flashlight", "phone_cheap"])
	police_rep = int(d.get("police_rep", 0))
	street_rep = int(d.get("street_rep", 0))
	completed = {}
	for k in d.get("completed", {}):
		completed[k] = int(d["completed"][k])
	yasser_pieces = d.get("yasser_pieces", [])
	decisions = d.get("decisions", {})
	for k in d.get("settings", {}):
		settings[k] = d["settings"][k]
	pending_case = str(d.get("pending_case", ""))
	active_case = str(d.get("active_case", ""))
	case_state = d.get("case_state", {})
	engines.clear()
	Loc.set_lang(str(settings.get("lang", "ar")))
	return true
