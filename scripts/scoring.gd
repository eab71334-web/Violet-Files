class_name Scoring
extends RefCounted
## تقييم الملف عند التسليم (الوثيقة 21). الدرجة من 100:
##   الأدلة 40  : 10 لكل دليل حقيقي موثّق بجودة جيدة (حتى 4)، وخصم 10 لكل دليل مضلل في الملف
##   الحكم  30  : المتهم الصحيح 30، شريك/جزء من الحقيقة 15، بريء 0
##   الأسلوب 15 : يبدأ 15 وينقص مع الأفعال غير القانونية وظلم الأبرياء
##   الوقت والأعصاب 15 : تسليم قبل المهلة (8) + أعصاب سليمة (7)
## النتائج: 85+ مكافأة 100%، 60-84 مكافأة 70%، 40-59 مكافأة 30%، أقل من 40 بلا مكافأة.

const GOOD_QUALITY := 0.5
const MAX_EVIDENCE := 4
const ILLEGAL_PENALTY := 5.0


static func evaluate(case_def: Dictionary, state: Dictionary) -> Dictionary:
	var q: Dictionary = case_def.get("question", {})
	var answer := str(state.get("answer", ""))
	var correct := false
	var partial := false
	for o in q.get("options", []):
		if str(o.get("id", "")) == answer:
			correct = bool(o.get("correct", false))
			partial = bool(o.get("partial", false))

	# الحكم (30)
	var verdict_score := 30.0 if correct else (15.0 if partial else 0.0)

	# الأدلة (40)
	var by_id := {}
	for e in state.get("evidence", []):
		by_id[str(e.get("id", ""))] = e
	var good := 0
	var misleading := 0
	for sid in state.get("support", []):
		if not by_id.has(sid):
			continue
		var e: Dictionary = by_id[sid]
		if str(e.get("kind", "real")) == "misleading":
			misleading += 1
		else:
			var sup_for: Array = e.get("supports", [])
			# دليل حقيقي يدعم إجابة أخرى لا يفيد هذا الحكم.
			if float(e.get("quality", 0.0)) >= GOOD_QUALITY and (sup_for.is_empty() or answer in sup_for):
				good += 1
	var evidence_score := clampf(10.0 * mini(good, MAX_EVIDENCE) - 10.0 * misleading, 0.0, 40.0)

	# الأسلوب (15)
	var illegal := int(state.get("illegal", 0))
	var style_score := 15.0 - ILLEGAL_PENALTY * illegal
	if not correct and not partial:
		style_score -= 5.0   # ظلم بريء
	style_score = clampf(style_score, 0.0, 15.0)

	# الوقت والأعصاب (15)
	var time_score := 8.0 if int(state.get("hours_left", 0)) > 0 else 0.0
	var nerves := int(state.get("nerves", 100))
	var nerves_score := 7.0 if nerves >= 50 else (3.0 if nerves >= 25 else 0.0)

	var total := evidence_score + verdict_score + style_score + time_score + nerves_score
	# حكم ظالم لا يمكن أن يعدّ نجاحًا مهما كانت الأدلة الجانبية.
	if not correct and not partial:
		total = minf(total, 39.0)
	total = clampf(total, 0.0, 100.0)

	var stars := 0
	var share := 0.0
	if total >= 85.0:
		stars = 3
		share = 1.0
	elif total >= 60.0:
		stars = 2
		share = 0.7
	elif total >= 40.0:
		stars = 1
		share = 0.3
	var price := int(state.get("price", 0))
	var reward := int(round(price * share))

	return {
		"correct": correct,
		"partial": partial,
		"evidence_score": evidence_score,
		"verdict_score": verdict_score,
		"style_score": style_score,
		"time_score": time_score + nerves_score,
		"illegal": illegal,
		"total": total,
		"stars": stars,
		"share": share,
		"reward": reward,
	}


## ما فاتك (الوثيقة 19.5): بدون عقاب إضافي. يرجع قوائم للعرض.
static func missed(case_def: Dictionary, state: Dictionary) -> Dictionary:
	var have := {}
	for e in state.get("evidence", []):
		have[str(e.get("id", ""))] = true
	var items: Array = []
	for sc in case_def.get("scenes", []):
		for it in sc.get("items", []):
			if not have.has(str(it["id"])) and str(it.get("kind", "real")) == "real":
				items.append(it["label"])
		var rw = sc.get("reward", null)
		if rw != null and not have.has(str(rw["id"])):
			items.append(rw["label"])
	for w in case_def.get("witnesses", []):
		for k in w.get("clues", {}):
			if not have.has(k):
				items.append(w["clues"][k]["label"])
	var lies_missed: Array = []
	var false_flags: Array = []
	var right := 0
	var stm: Array = state.get("statements", [])
	for s in stm:
		var flagged := bool(s.get("flagged", false))
		var lie := bool(s.get("lie", false))
		if flagged == lie:
			right += 1
		elif lie:
			lies_missed.append(s["text"])
		else:
			false_flags.append(s["text"])
	var acc := 100 if stm.is_empty() else int(round(100.0 * right / stm.size()))
	return {"items": items, "lies_missed": lies_missed, "false_flags": false_flags, "note_accuracy": acc}
