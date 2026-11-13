class_name InterrogationEngine
extends RefCounted
## نظام التوتر المخفي وقراءة الكذب (الوثيقة 6.2)
## لكل شخصية: توتر، ثقة، تعب، وخط أساس (Baseline).
## Hidden tension system: tension, trust, fatigue and a personal baseline.

const WEIGHT := {"normal": 3.0, "peripheral": 10.0, "hidden": 25.0}

var data: Dictionary
var tension: float
var trust: float
var fatigue: float = 0.0
var baseline_offset: float = 0.0   # العصبي +25 (يرمش وهو صادق)، البارد -25 (لا يظهر عليه شيء)
var break_at: float
var min_trust: float
var asked: Dictionary = {}
var shown_evidence: Dictionary = {}


func _init(witness: Dictionary) -> void:
	data = witness
	match str(witness.get("baseline", "normal")):
		"nervous":
			baseline_offset = 25.0
		"cold":
			baseline_offset = -25.0
	tension = float(witness.get("start_tension", 15))
	trust = float(witness.get("start_trust", 40))
	break_at = float(witness.get("break_at", 60))
	min_trust = float(witness.get("min_trust", 25))


## التوتر الذي يراه اللاعب على الوجه (يختلف عن الحقيقي بسبب خط الأساس والتعب).
func visible_tension() -> float:
	return clampf(tension + baseline_offset + fatigue * 0.3, 0.0, 100.0)


## 0 منخفض، 1 متوسط، 2 عالٍ
func tier() -> int:
	var v := visible_tension()
	if v < 30.0:
		return 0
	if v < 60.0:
		return 1
	return 2


func tell_key() -> String:
	return ["tell_low", "tell_mid", "tell_high"][tier()]


func trust_hint_key() -> String:
	if trust >= 60.0:
		return "trust_high"
	if trust >= 30.0:
		return "trust_mid"
	return "trust_low"


## تسأل سؤالًا. يرجع {text, lie, reveals, broke}
func ask(q: Dictionary) -> Dictionary:
	var cat := str(q.get("cat", "normal"))
	var delta: float = WEIGHT.get(cat, 3.0)
	if trust > 60.0:
		delta *= 0.8
	elif trust < 20.0:
		delta *= 1.2
	tension = clampf(tension + delta, 0.0, 100.0)
	fatigue = clampf(fatigue + 4.0, 0.0, 100.0)
	asked[str(q.get("id", ""))] = true

	var result := {
		"text": q.get("answer", ""),
		"lie": bool(q.get("lie", false)),
		"reveals": "",
		"broke": false,
	}
	if cat == "hidden" and q.has("truth"):
		# الكاذب ينهار فقط لو ارتفع توتره بما يكفي وكان يثق بك قليلًا على الأقل.
		if tension >= break_at and trust >= min_trust:
			result["text"] = q["truth"]
			result["lie"] = false
			result["reveals"] = str(q.get("reveals", ""))
			result["broke"] = true
	elif cat == "hidden" and q.has("reveals") and not bool(q.get("lie", false)):
		# شاهد صادق لكنه عصبي: يعطيك المعلومة حتى لو بدا متوترًا.
		result["reveals"] = str(q["reveals"])
	return result


## أدوات الضغط والتهدئة. يرجع مفتاح رسالة.
func apply_tool(tool_id: String, evidence_id: String = "") -> String:
	fatigue = clampf(fatigue + 2.0, 0.0, 100.0)
	match tool_id:
		"lean":
			tension += 8.0
			trust -= 3.0
		"silence":
			tension += 6.0
			fatigue += 2.0
		"evidence":
			var weak: Array = data.get("weak_to", [])
			if evidence_id in weak and not shown_evidence.has(evidence_id):
				tension += 15.0
			else:
				tension += 2.0
			shown_evidence[evidence_id] = true
		"recording":
			tension += 10.0
			trust -= 6.0
		"kindness":
			tension -= 10.0
			trust += 8.0
		"water":
			tension -= 12.0
			trust += 4.0
			fatigue -= 5.0
		"away":
			tension -= 6.0
			trust += 3.0
		"subject":
			tension -= 5.0
	tension = clampf(tension, 0.0, 100.0)
	trust = clampf(trust, 0.0, 100.0)
	fatigue = clampf(fatigue, 0.0, 100.0)
	return "tool_" + tool_id
