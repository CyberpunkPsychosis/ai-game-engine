extends CharacterBody2D
## 史莱姆敌人：可被挑空/空中连击/俯冲砸落，可被打死。受击有击退+闪红+硬直。

@export var max_hp := 3
@export var speed := 40.0
@export var clip := "SlimeGreen"

const GRAV := 1800.0
var _hp := 0
var _dir := 1
var _flash := 0.0
var _knock := 0.0
var _inv := 0.0
var spr: AnimatedSprite2D
var _dead := false

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4    # enemy
	collision_mask = 1     # 只与世界碰撞(玩家可穿过去打)
	_hp = max_hp
	var shape := RectangleShape2D.new()
	shape.size = Vector2(78, 52)
	var cs := CollisionShape2D.new(); cs.shape = shape; cs.position = Vector2(0, -26)
	add_child(cs)
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = _build_frames()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.scale = Vector2(0.5, 0.5)
	spr.position = Vector2(0, -26)
	spr.play("default")
	add_child(spr)

func _build_frames() -> SpriteFrames:
	var by := {}
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://assets/anim/manifest.json"))["animations"]:
		by[c["name"]] = c
	var m = by[clip]
	var tex: Texture2D = load("res://assets/anim/" + m["file"])
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", m["fps"])
	sf.set_animation_loop("default", true)
	var fw := int(m["fw"]); var fh := int(m["fh"]); var cols := int(m["cols"]); var cnt := int(m["count"])
	for i in cnt:
		var at := AtlasTexture.new(); at.atlas = tex
		at.region = Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
		sf.add_frame("default", at)
	return sf

func _physics_process(delta: float) -> void:
	if _dead: return
	_inv = maxf(_inv - delta, 0.0)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAV * delta, 1500.0)
	elif velocity.y > 0.0:
		velocity.y = 0.0
	if _knock > 0.0:
		_knock -= delta
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
	else:
		velocity.x = _dir * speed
		if is_on_wall():
			_dir *= -1
	move_and_slide()
	if _flash > 0.0:
		_flash -= delta
		spr.modulate = Color(1.0, 0.5, 0.5)
	else:
		spr.modulate = Color.WHITE
	if absf(velocity.x) > 5.0:
		spr.flip_h = velocity.x < 0.0

func hurt(dmg: int, kb: Vector2) -> void:
	if _dead or _inv > 0.0: return
	_inv = 0.13
	_hp -= dmg
	velocity = kb
	_knock = 0.35
	_flash = 0.12
	Juice.hitstop(0.05)
	if _hp <= 0:
		_die()

func _die() -> void:
	_dead = true
	var b := preload("res://scenes/spore_burst.tscn").instantiate()
	b.global_position = global_position + Vector2(0, -26)
	b.scale = Vector2(0.5, 0.5)
	get_parent().add_child(b)
	Juice.shake(8.0)
	queue_free()
