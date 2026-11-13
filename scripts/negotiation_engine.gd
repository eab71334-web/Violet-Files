class_name NegotiationEngine
extends RefCounted
## نظام التفاوض (الوثيقة 6.1)
## لكل عميل أرقام مخفية: الصبر، الجشع، الميزانية القصوى، الصدق.
## Hidden client numbers: patience, greed, max budget, honesty of anger.

enum State { OPEN, ACCEPTED, EXPLODED, LEFT }

var opening: int
var patience: int          # كم رفضًا يتحمل
var greed: float           # نسبة الزيادة في كل مرة
var max_budget: int        # أعلى مبلغ يقدر يدفعه
var honest_anger: bool     # هل غضبه حقيقي أم تمثيل

var offer: int
var rejects: int = 0
var state: int = State.OPEN


func _init(client: Dictionary) -> void:
	opening = int(client.get("opening", 100))
	patience = int(client.get("patience", 3))
	greed = float(client.get("greed", 0.3))
	max_budget = int(client.get("max", opening * 2))
	honest_anger = bool(client.get("honest_anger", true))
	offer = opening


## المرحلة الحالية: 0 عرض أول، 1 رفض أول، 2 رفض ثانٍ، 3 رفض ثالث...
func phase() -> int:
	return rejects


## ترفض العرض. يرجع "raise" أو "explode".
func reject() -> String:
	if state != State.OPEN:
		return "none"
	rejects += 1
	if rejects > patience:
		state = State.EXPLODED
		return "explode"
	var raise_by := int(round(offer * greed))
	offer = mini(max_budget, offer + maxi(raise_by, 5))
	return "raise"


## تقبل العرض. يرجع السعر المتفق عليه.
func accept() -> int:
	if state != State.OPEN:
		return 0
	state = State.ACCEPTED
	return offer


## تطرده بنفسك.
func kick_out() -> void:
	if state == State.OPEN:
		state = State.LEFT


## مستوى الغضب الظاهر 0..100
func anger() -> float:
	if rejects == 0:
		return 5.0
	return clampf(float(rejects) / float(patience + 1) * 100.0, 0.0, 100.0)


## هل وصل العرض لأعلى مبلغ يقدر يدفعه؟
func at_cap() -> bool:
	return offer >= max_budget


## وصف لغة الجسد (الغضب الحقيقي يظهر في العين، والتمثيل لا).
func tell_key() -> String:
	if rejects == 0:
		return "tell_calm"
	if honest_anger:
		return "tell_anger_real"
	return "tell_anger_fake"
