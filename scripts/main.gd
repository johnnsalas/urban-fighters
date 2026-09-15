extends Node2D

enum GameState { TITLE, SELECT, FIGHT, RESULT }

const Fighter = preload("res://scripts/fighter.gd")
const FLOOR_Y := 570.0
const LEFT_LIMIT := 90.0
const RIGHT_LIMIT := 1190.0

var roster := [
	{"name":"KAEL", "home":"Barcelona", "color":Color("e94b35"), "accent":Color("ffd166"), "speed":285.0, "power":0.95, "special":"Ráfaga BCN"},
	{"name":"LUNA", "home":"Madrid", "color":Color("8f5cff"), "accent":Color("52e5e7"), "speed":310.0, "power":0.87, "special":"Pulso Neón"},
	{"name":"DANI", "home":"Sevilla", "color":Color("1dbf73"), "accent":Color("fff0a5"), "speed":250.0, "power":1.08, "special":"Impacto Sur"},
	{"name":"NAIRA", "home":"València", "color":Color("ff8c42"), "accent":Color("073b4c"), "speed":270.0, "power":1.02, "special":"Furia Levante"}
]

var stages := ["AZOTEAS DE BARCELONA", "METRO DE MADRID", "PUERTO DE VALÈNCIA"]
var state := GameState.TITLE
var selected := 0
var stage_index := 0
var player: UrbanFighter
var enemy: UrbanFighter
var round_number := 1
var timer := 60.0
var round_pause := 0.0
var announcement := ""
var announcement_time := 0.0
var hit_registered := false
var shake := 0.0
var touch_actions := {}
var title_pulse := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	title_pulse += delta
	if state == GameState.FIGHT:
		update_fight(delta)
	if announcement_time > 0.0:
		announcement_time -= delta
	shake = maxf(0.0, shake - delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			handle_touch(event.position)
		else:
			touch_actions.clear()
	elif event is InputEventMouseButton and event.pressed:
		handle_touch(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			confirm_action()
		elif event.keycode == KEY_ESCAPE:
			back_action()
		elif state == GameState.SELECT:
			if event.keycode in [KEY_LEFT, KEY_A]: selected = wrapi(selected - 1, 0, roster.size())
			if event.keycode in [KEY_RIGHT, KEY_D]: selected = wrapi(selected + 1, 0, roster.size())

func confirm_action() -> void:
	if state == GameState.TITLE:
		state = GameState.SELECT
	elif state == GameState.SELECT:
		start_match()
	elif state == GameState.RESULT:
		state = GameState.SELECT

func back_action() -> void:
	if state == GameState.SELECT: state = GameState.TITLE
	elif state == GameState.RESULT: state = GameState.SELECT

func start_match() -> void:
	player = Fighter.new()
	player.configure(roster[selected])
	var enemy_index := (selected + rng.randi_range(1, roster.size() - 1)) % roster.size()
	enemy = Fighter.new()
	enemy.configure(roster[enemy_index])
	stage_index = rng.randi_range(0, stages.size() - 1)
	player.wins = 0
	enemy.wins = 0
	round_number = 1
	state = GameState.FIGHT
	reset_round()

func reset_round() -> void:
	player.reset(Vector2(350, FLOOR_Y), 1.0)
	enemy.reset(Vector2(930, FLOOR_Y), -1.0)
	timer = 60.0
	round_pause = 1.6
	announcement = "ROUND %d" % round_number
	announcement_time = 1.5
	hit_registered = false

func update_fight(delta: float) -> void:
	if round_pause > 0.0:
		round_pause -= delta
		return
	if player.health <= 0.0 or enemy.health <= 0.0 or timer <= 0.0:
		finish_round(delta)
		return
	timer = maxf(0.0, timer - delta)
	read_player_input()
	update_enemy_ai()
	player.facing = 1.0 if player.position.x < enemy.position.x else -1.0
	enemy.facing = -player.facing
	player.tick(delta, FLOOR_Y)
	enemy.tick(delta, FLOOR_Y)
	player.position.x = clampf(player.position.x, LEFT_LIMIT, RIGHT_LIMIT)
	enemy.position.x = clampf(enemy.position.x, LEFT_LIMIT, RIGHT_LIMIT)
	separate_fighters()
	resolve_attack(player, enemy)
	resolve_attack(enemy, player)

func read_player_input() -> void:
	if player.stun_timer > 0.0:
		return
	var axis := Input.get_axis("move_left", "move_right")
	if touch_actions.has("left"): axis = -1.0
	if touch_actions.has("right"): axis = 1.0
	player.blocking = Input.is_action_pressed("block") or touch_actions.has("block")
	player.crouching = Input.is_action_pressed("crouch") or touch_actions.has("down")
	if player.attack_timer <= 0.0 and not player.blocking:
		player.velocity.x = axis * player.speed
	if (Input.is_action_just_pressed("jump") or touch_actions.has("jump")) and player.grounded:
		player.velocity.y = -590.0
		player.grounded = false
	if Input.is_action_just_pressed("punch") or touch_actions.has("punch"):
		if player.start_attack("punch"): hit_registered = false
		touch_actions.erase("punch")
	if Input.is_action_just_pressed("kick") or touch_actions.has("kick"):
		if player.start_attack("kick"): hit_registered = false
		touch_actions.erase("kick")
	if Input.is_action_just_pressed("special") or touch_actions.has("special"):
		if player.start_attack("special"): hit_registered = false
		touch_actions.erase("special")

func update_enemy_ai() -> void:
	if enemy.stun_timer > 0.0:
		return
	var distance := absf(player.position.x - enemy.position.x)
	enemy.blocking = false
	if player.attack_timer > 0.12 and distance < 150.0 and rng.randf() < 0.10:
		enemy.blocking = true
		return
	if distance > 125.0:
		enemy.velocity.x = signf(player.position.x - enemy.position.x) * enemy.speed * 0.72
	elif enemy.ai_cooldown <= 0.0 and enemy.attack_timer <= 0.0:
		var choice := rng.randf()
		if enemy.energy >= 50.0 and choice > 0.78:
			enemy.start_attack("special")
		elif choice > 0.42:
			enemy.start_attack("kick")
		else:
			enemy.start_attack("punch")
		enemy.ai_cooldown = rng.randf_range(0.35, 0.85)
		hit_registered = false

func resolve_attack(attacker: UrbanFighter, defender: UrbanFighter) -> void:
	if attacker.attack_timer <= 0.0:
		return
	var active := false
	if attacker.attack_kind == "punch": active = attacker.attack_timer < 0.23 and attacker.attack_timer > 0.12
	elif attacker.attack_kind == "kick": active = attacker.attack_timer < 0.31 and attacker.attack_timer > 0.15
	elif attacker.attack_kind == "special": active = attacker.attack_timer < 0.44 and attacker.attack_timer > 0.15
	if not active or hit_registered:
		return
	var reach := 105.0 if attacker.attack_kind == "punch" else 145.0
	if attacker.attack_kind == "special": reach = 205.0
	if absf(attacker.position.x - defender.position.x) < reach and absf(attacker.position.y - defender.position.y) < 100.0:
		var damage := 7.0
		if attacker.attack_kind == "kick": damage = 11.0
		if attacker.attack_kind == "special": damage = 18.0
		defender.receive_hit(damage * attacker.power, attacker.facing * (260.0 if attacker.attack_kind != "special" else 480.0))
		attacker.energy = minf(100.0, attacker.energy + damage * 0.8)
		hit_registered = true
		shake = 0.13

func separate_fighters() -> void:
	var gap := enemy.position.x - player.position.x
	if absf(gap) < 72.0:
		var correction := (72.0 - absf(gap)) * 0.5
		player.position.x -= signf(gap) * correction
		enemy.position.x += signf(gap) * correction

func finish_round(delta: float) -> void:
	if round_pause <= 0.0:
		var player_won := player.health > enemy.health
		if player_won: player.wins += 1
		else: enemy.wins += 1
		announcement = "¡GANAS!" if player_won else "K.O."
		announcement_time = 2.0
		round_pause = 2.2
	elif round_pause > 0.0:
		round_pause -= delta
		if round_pause <= 0.0:
			if player.wins >= 2 or enemy.wins >= 2:
				state = GameState.RESULT
			else:
				round_number += 1
				reset_round()

func handle_touch(pos: Vector2) -> void:
	if state == GameState.TITLE:
		confirm_action()
		return
	if state == GameState.SELECT:
		if pos.y > 570:
			confirm_action()
		else:
			selected = clampi(int(pos.x / 320.0), 0, 3)
		return
	if state == GameState.RESULT:
		confirm_action()
		return
	if state != GameState.FIGHT:
		return
	if pos.x < 420:
		if pos.y < 560: touch_actions["jump"] = true
		elif pos.x < 140: touch_actions["left"] = true
		elif pos.x < 280: touch_actions["down"] = true
		else: touch_actions["right"] = true
	else:
		if pos.x > 1060 and pos.y < 590: touch_actions["special"] = true
		elif pos.x > 1030: touch_actions["kick"] = true
		elif pos.x > 850: touch_actions["punch"] = true
		else: touch_actions["block"] = true

func _draw() -> void:
	match state:
		GameState.TITLE: draw_title()
		GameState.SELECT: draw_select()
		GameState.FIGHT: draw_fight()
		GameState.RESULT: draw_result()

func draw_title() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("101426"))
	for i in range(18):
		var x := float((i * 83 + int(title_pulse * 22.0)) % 1400) - 60.0
		draw_line(Vector2(x, 0), Vector2(x - 360, 720), Color(0.13, 0.18, 0.35, 0.55), 18)
	draw_string(ThemeDB.fallback_font, Vector2(640, 235), "URBAN", HORIZONTAL_ALIGNMENT_CENTER, 0, 112, Color("f6d743"))
	draw_string(ThemeDB.fallback_font, Vector2(640, 340), "FIGHTERS", HORIZONTAL_ALIGNMENT_CENTER, 0, 112, Color("f04444"))
	draw_string(ThemeDB.fallback_font, Vector2(640, 400), "ESPAÑA ENTRA EN COMBATE", HORIZONTAL_ALIGNMENT_CENTER, 0, 30, Color.WHITE)
	var pulse := 0.65 + sin(title_pulse * 4.0) * 0.35
	draw_string(ThemeDB.fallback_font, Vector2(640, 570), "TOCA PARA EMPEZAR", HORIZONTAL_ALIGNMENT_CENTER, 0, 30, Color(1, 1, 1, pulse))
	draw_string(ThemeDB.fallback_font, Vector2(640, 655), "PROTOTIPO ARCADE", HORIZONTAL_ALIGNMENT_CENTER, 0, 18, Color("7980a8"))

func draw_select() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("15192d"))
	draw_string(ThemeDB.fallback_font, Vector2(640, 75), "ELIGE TU LUCHADOR", HORIZONTAL_ALIGNMENT_CENTER, 0, 46, Color.WHITE)
	for i in range(roster.size()):
		var rect := Rect2(28 + i * 312, 125, 288, 390)
		draw_rect(rect, Color(roster[i].color).darkened(0.55))
		draw_rect(rect, Color("f6d743") if i == selected else Color("394060"), false, 7 if i == selected else 3)
		draw_character_preview(Vector2(rect.position.x + 144, 355), roster[i], i == selected)
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 144, 445), roster[i].name, HORIZONTAL_ALIGNMENT_CENTER, 0, 34, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 144, 480), roster[i].home, HORIZONTAL_ALIGNMENT_CENTER, 0, 20, Color("cbd0e8"))
	draw_rect(Rect2(410, 570, 460, 82), Color("e94b35"))
	draw_string(ThemeDB.fallback_font, Vector2(640, 625), "LUCHAR", HORIZONTAL_ALIGNMENT_CENTER, 0, 34, Color.WHITE)

func draw_character_preview(center: Vector2, data: Dictionary, active: bool) -> void:
	var bob := sin(title_pulse * 5.0) * 4.0 if active else 0.0
	center.y += bob
	draw_circle(center + Vector2(0, -118), 38, Color("d99a70"))
	draw_rect(Rect2(center.x - 48, center.y - 78, 96, 120), data.color)
	draw_rect(Rect2(center.x - 62, center.y + 38, 48, 94), data.accent)
	draw_rect(Rect2(center.x + 14, center.y + 38, 48, 94), data.accent)
	draw_rect(Rect2(center.x - 88, center.y - 67, 40, 105), data.color)
	draw_rect(Rect2(center.x + 48, center.y - 67, 40, 105), data.color)
	draw_rect(Rect2(center.x - 34, center.y - 160, 68, 22), data.accent)

func draw_fight() -> void:
	var offset := Vector2(rng.randf_range(-7, 7), rng.randf_range(-4, 4)) if shake > 0 else Vector2.ZERO
	draw_set_transform(offset)
	draw_stage()
	draw_fighter(player)
	draw_fighter(enemy)
	draw_set_transform(Vector2.ZERO)
	draw_hud()
	draw_controls()
	if announcement_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(640, 340), announcement, HORIZONTAL_ALIGNMENT_CENTER, 0, 72, Color("fff3b0"))

func draw_stage() -> void:
	var sky := [Color("4a2b78"), Color("14213d"), Color("f28c54")][stage_index]
	draw_rect(Rect2(0, 0, 1280, 720), sky)
	if stage_index == 0:
		for i in range(12):
			var h := 100 + (i % 4) * 45
			draw_rect(Rect2(i * 116, FLOOR_Y - h, 94, h), Color("272345"))
		draw_circle(Vector2(1070, 130), 65, Color("ffcf70"))
	elif stage_index == 1:
		draw_rect(Rect2(0, 165, 1280, 330), Color("26344f"))
		for i in range(7): draw_rect(Rect2(35 + i * 190, 215, 135, 125), Color("a7d8de"))
		draw_line(Vector2(0, 430), Vector2(1280, 430), Color("e63946"), 20)
	else:
		draw_rect(Rect2(0, 330, 1280, 240), Color("176b87"))
		for i in range(5):
			draw_line(Vector2(100 + i * 280, 340), Vector2(180 + i * 280, 180), Color("182234"), 18)
			draw_line(Vector2(180 + i * 280, 180), Vector2(255 + i * 280, 340), Color("182234"), 12)
	draw_rect(Rect2(0, FLOOR_Y, 1280, 150), Color("282631"))
	for i in range(20): draw_rect(Rect2(i * 68, FLOOR_Y + 28, 45, 8), Color("474451"))
	draw_string(ThemeDB.fallback_font, Vector2(640, 535), stages[stage_index], HORIZONTAL_ALIGNMENT_CENTER, 0, 18, Color(1,1,1,0.55))

func draw_fighter(f: UrbanFighter) -> void:
	var p := f.position
	var tint := Color.WHITE if f.hit_flash <= 0 else Color("fff5c2")
	var crouch := 25.0 if f.crouching else 0.0
	draw_circle(p + Vector2(0, -142 + crouch), 30, Color("d99a70") * tint)
	draw_rect(Rect2(p.x - 34, p.y - 112 + crouch, 68, 88), f.color * tint)
	draw_rect(Rect2(p.x - 32, p.y - 28, 25, 55), f.accent * tint)
	draw_rect(Rect2(p.x + 7, p.y - 28, 25, 55), f.accent * tint)
	var arm := 52.0
	if f.attack_timer > 0 and f.attack_kind == "punch": arm = 94.0
	draw_rect(Rect2(p.x + (34 if f.facing > 0 else -34 - arm), p.y - 100 + crouch, arm, 19), f.color * tint)
	if f.attack_timer > 0 and f.attack_kind in ["kick", "special"]:
		var kick_len := 102.0 if f.attack_kind == "kick" else 158.0
		draw_rect(Rect2(p.x + (12 if f.facing > 0 else -12 - kick_len), p.y - 48, kick_len, 24), f.accent * tint)
	if f.blocking:
		draw_arc(p + Vector2(f.facing * 45, -85), 55, -1.2, 1.2, 12, Color("73e8ff"), 7)
	if f.special_fx > 0:
		draw_arc(p + Vector2(f.facing * 85, -75), 90 * (f.special_fx / 0.65), 0, TAU, 18, f.accent, 9)

func draw_hud() -> void:
	draw_rect(Rect2(25, 20, 1230, 115), Color(0.03, 0.04, 0.09, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(45, 56), player.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(1235, 56), enemy.name, HORIZONTAL_ALIGNMENT_RIGHT, 220, 25, Color.WHITE)
	draw_rect(Rect2(45, 70, 475, 28), Color("401b27"))
	draw_rect(Rect2(45, 70, 475 * player.health / 100.0, 28), Color("50d890"))
	draw_rect(Rect2(760, 70, 475, 28), Color("401b27"))
	draw_rect(Rect2(1235 - 475 * enemy.health / 100.0, 70, 475 * enemy.health / 100.0, 28), Color("50d890"))
	draw_rect(Rect2(45, 105, 300, 12), Color("222944"))
	draw_rect(Rect2(45, 105, 300 * player.energy / 100.0, 12), Color("48cae4"))
	draw_rect(Rect2(935, 105, 300, 12), Color("222944"))
	draw_rect(Rect2(1235 - 300 * enemy.energy / 100.0, 105, 300 * enemy.energy / 100.0, 12), Color("48cae4"))
	draw_string(ThemeDB.fallback_font, Vector2(640, 87), "%02d" % ceili(timer), HORIZONTAL_ALIGNMENT_CENTER, 0, 45, Color("ffd166"))
	draw_string(ThemeDB.fallback_font, Vector2(640, 119), "%d - %d" % [player.wins, enemy.wins], HORIZONTAL_ALIGNMENT_CENTER, 0, 20, Color.WHITE)

func draw_controls() -> void:
	var ghost := Color(1, 1, 1, 0.20)
	for item in [[Vector2(85,650),"◀"],[Vector2(220,650),"▼"],[Vector2(355,650),"▶"],[Vector2(220,535),"▲"]]:
		draw_circle(item[0], 48, ghost)
		draw_string(ThemeDB.fallback_font, item[0] + Vector2(0, 12), item[1], HORIZONTAL_ALIGNMENT_CENTER, 0, 28, Color.WHITE)
	for item in [[Vector2(760,650),"BLOQ"],[Vector2(900,630),"PUÑO"],[Vector2(1040,660),"PAT"],[Vector2(1165,555),"ESP"]]:
		draw_circle(item[0], 55, ghost)
		draw_string(ThemeDB.fallback_font, item[0] + Vector2(0, 8), item[1], HORIZONTAL_ALIGNMENT_CENTER, 0, 17, Color.WHITE)

func draw_result() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("11162b"))
	var victory := player.wins > enemy.wins
	draw_string(ThemeDB.fallback_font, Vector2(640, 220), "VICTORIA" if victory else "DERROTA", HORIZONTAL_ALIGNMENT_CENTER, 0, 88, Color("f6d743") if victory else Color("ef476f"))
	draw_string(ThemeDB.fallback_font, Vector2(640, 310), player.name + "  %d - %d  " % [player.wins, enemy.wins] + enemy.name, HORIZONTAL_ALIGNMENT_CENTER, 0, 34, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(640, 440), "TOCA PARA ELEGIR LUCHADOR", HORIZONTAL_ALIGNMENT_CENTER, 0, 28, Color("cbd0e8"))

