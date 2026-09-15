class_name UrbanFighter
extends RefCounted

var name := ""
var home := ""
var color := Color.WHITE
var accent := Color.BLACK
var speed := 260.0
var power := 1.0
var special_name := ""
var health := 100.0
var energy := 0.0
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := 1.0
var grounded := true
var blocking := false
var crouching := false
var attack_kind := ""
var attack_timer := 0.0
var hit_flash := 0.0
var stun_timer := 0.0
var special_fx := 0.0
var ai_cooldown := 0.0
var wins := 0

func configure(data: Dictionary) -> void:
	name = data.name
	home = data.home
	color = data.color
	accent = data.accent
	speed = data.speed
	power = data.power
	special_name = data.special

func reset(spawn: Vector2, direction: float) -> void:
	health = 100.0
	energy = 0.0
	position = spawn
	velocity = Vector2.ZERO
	facing = direction
	grounded = true
	blocking = false
	crouching = false
	attack_kind = ""
	attack_timer = 0.0
	hit_flash = 0.0
	stun_timer = 0.0
	special_fx = 0.0
	ai_cooldown = 0.0

func start_attack(kind: String) -> bool:
	if stun_timer > 0.0 or attack_timer > 0.0 or blocking:
		return false
	if kind == "special" and energy < 50.0:
		return false
	attack_kind = kind
	attack_timer = 0.34 if kind == "punch" else 0.46
	if kind == "special":
		attack_timer = 0.65
		energy -= 50.0
		special_fx = 0.65
	return true

func receive_hit(damage: float, push: float) -> void:
	if blocking:
		damage *= 0.25
		push *= 0.35
	health = maxf(0.0, health - damage)
	energy = minf(100.0, energy + damage * 1.25)
	velocity.x = push
	stun_timer = 0.12 if blocking else 0.28
	hit_flash = 0.16

func tick(delta: float, floor_y: float) -> void:
	attack_timer = maxf(0.0, attack_timer - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	stun_timer = maxf(0.0, stun_timer - delta)
	special_fx = maxf(0.0, special_fx - delta)
	ai_cooldown = maxf(0.0, ai_cooldown - delta)
	if not grounded:
		velocity.y += 1300.0 * delta
	position += velocity * delta
	velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
	if position.y >= floor_y:
		position.y = floor_y
		velocity.y = 0.0
		grounded = true

