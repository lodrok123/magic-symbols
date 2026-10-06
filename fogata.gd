extends Area2D

## FOGATA — un fuego de mapa que se enciende y se apaga con las mismas reglas que la pira
## (calor la enciende; agua o frio la apagan), pero SIN sprite de llama pintado en la base:
## la llama es una capa aparte (art/fogata_llama.png) que SOLO se ve mientras arde.
## Apagada se ve un aro de piedras con troncos oscuros: no hay llama que confunda al jugador.

signal lit
signal extinguished

const FIRE_RUNE: RuneData = preload("res://fire_rune.tres")

@export var start_lit: bool = true
@export var escala: float = 1.0
## Particulas de llama extra (ademas del sprite). Desactivadas: el sprite ya es la llama.
@export var con_particulas: bool = false

var is_lit: bool = false
var base: Sprite2D
var llama: Sprite2D
var tex_encendida: Texture2D
var tex_apagada: Texture2D
var flame_fx: GPUParticles2D = null
var fuego_luz: PointLight2D = null
var _t: float = 0.0


func _ready() -> void:
	add_to_group("ground")
	base = Sprite2D.new()
	tex_encendida = load("res://art/fogata_base.png")
	tex_apagada = load("res://art/fogata_apagada.png")
	base.texture = tex_encendida
	base.scale = Vector2(escala, escala)
	add_child(base)
	llama = Sprite2D.new()
	llama.texture = load("res://art/fogata_llama.png")
	llama.scale = Vector2(escala, escala)
	llama.visible = false
	add_child(llama)
	var shape := ConvexPolygonShape2D.new()
	var puntos := PackedVector2Array()
	for v in [Vector2(0, -12), Vector2(26, 2), Vector2(0, 16), Vector2(-26, 2)]:
		puntos.append(v * escala)
	shape.points = puntos
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	if start_lit:
		_light(false)
	else:
		base.texture = tex_apagada


func _process(delta: float) -> void:
	if not is_lit:
		return
	_t += delta
	var k: float = 1.0 + 0.05 * sin(_t * 9.0) + 0.03 * sin(_t * 17.0 + 1.3)
	llama.scale = Vector2(escala * (2.0 - k) * 0.5 + escala * 0.5, escala * k)
	llama.modulate.a = 0.93 + 0.07 * sin(_t * 13.0)


func on_spell_hit(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
	if rune_data == null:
		return
	if rune_data.tags.has("calor") and not is_lit:
		_light(true)
	elif (rune_data.tags.has("agua") or rune_data.tags.has("frio")) and is_lit:
		_extinguish()


func spell_reacts(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> bool:
	if rune_data == null:
		return false
	if rune_data.tags.has("calor"):
		return not is_lit
	if rune_data.tags.has("agua") or rune_data.tags.has("frio"):
		return is_lit
	return false


## Si arde, el viento puede llevarse el fuego (igual que la pira).
func carried_element() -> RuneData:
	return FIRE_RUNE if is_lit else null


func _light(con_efectos: bool) -> void:
	is_lit = true
	llama.visible = true
	base.texture = tex_encendida
	base.modulate = Color(1.0, 0.95, 0.9)
	fuego_luz = Glow.attach(self, Glow.LUZ_FUEGO, 200.0, 1.2, true)
	if con_particulas:
		flame_fx = BlockFx.flames(self)
	if con_efectos:
		BlockFx.burst(self, "chispas")
		Sfx.play(self, "pira")
	lit.emit()


func _extinguish() -> void:
	is_lit = false
	llama.visible = false          # se quita la llama: apagada no queda ningun sprite de fuego
	base.texture = tex_apagada     # sprite dibujado de fogata apagada (piedras + troncos cruzados)
	base.modulate = Color(1, 1, 1)
	if flame_fx:
		flame_fx.queue_free()
		flame_fx = null
	if fuego_luz:
		fuego_luz.queue_free()
		fuego_luz = null
	BlockFx.burst(self, "ceniza")
	extinguished.emit()
