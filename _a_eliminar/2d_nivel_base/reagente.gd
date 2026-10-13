class_name Reagente
extends Area2D

## UNA PLANTA REACTIVA. Se saca un INGREDIENTE haciéndola reaccionar con un elemento
## (estilo Breath of the Wild): un rayo sobre una seta da una "seta electrificada", el
## fuego sobre una flor da una "flor ardiente"... Lo que sale queda en el SUELO como
## botín (se recoge con E) y la planta vuelve a crecer pasado un rato.
##
## Qué sale de cada cruce está en Objetos.PLANTAS. Si el elemento no está en la tabla de
## la planta, no pasa nada (y el hechizo la atraviesa, ver spell_reacts).

const REBROTE: float = 25.0

var planta: String = "seta"
var _viva: bool = true
var _t: float = 0.0
var _rotulo: float = 0.0
var _escala: float = 1.0


func _ready() -> void:
	add_to_group("reagentes")
	_t = randf() * TAU
	var forma := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 26.0
	forma.shape = c
	add_child(forma)


func _id_base() -> String:
	return String(Objetos.PLANTAS[planta]["base"])


func _process(delta: float) -> void:
	_t += delta
	if _rotulo > 0.0:
		_rotulo -= delta
	queue_redraw()


func _draw() -> void:
	if not _viva and _escala <= 0.01:
		return
	var k: float = _escala
	# sombra
	var pts := PackedVector2Array()
	for i in range(17):
		var a: float = TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 15.0 * k, 3.0 + sin(a) * 5.5 * k))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.25))
	# Un grupito de tres para que se lea como planta y no como objeto.
	var base: String = _id_base()
	for off in [Vector2(-11, 2), Vector2(11, 3), Vector2(0, -2)]:
		Objetos.dibujar(self, base, (off as Vector2) * k + Vector2(0, -9.0 * k + sin(_t * 1.6 + off.x) * 0.8), (11.0 if off.y < 0 else 8.5) * k)
	if _rotulo > 0.0:
		var f: Font = ThemeDB.fallback_font
		var txt: String = Objetos.nombre(base)
		var ancho: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var a2: float = clampf(_rotulo / 0.5, 0.0, 1.0)
		draw_rect(Rect2(-ancho * 0.5 - 5.0, -52.0, ancho + 10.0, 19.0), Color(0, 0, 0, 0.6 * a2))
		draw_string(f, Vector2(-ancho * 0.5, -38.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a2))


func _input(event: InputEvent) -> void:
	var m := event as InputEventMouseButton
	if m == null or not m.pressed or m.button_index != MOUSE_BUTTON_LEFT or not _viva:
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(0, -12)) < 28.0:
		_rotulo = 3.0


func spell_reacts(rune_data: RuneData, _direccion: Vector2 = Vector2.ZERO) -> bool:
	return _viva and Objetos.PLANTAS[planta]["tabla"].has(Objetos.elemento_de(rune_data))


func on_spell_hit(rune_data: RuneData, _direccion: Vector2 = Vector2.ZERO) -> void:
	if not _viva:
		return
	var el: String = Objetos.elemento_de(rune_data)
	var tabla: Dictionary = Objetos.PLANTAS[planta]["tabla"]
	if not tabla.has(el):
		return
	_viva = false
	var resultado: String = String(tabla[el])
	BlockFx.burst(self, "chispas" if el == "rayo" else ("ceniza" if el == "fuego" else "magia"))
	# Diferido: on_spell_hit llega en mitad de la física y ahí no se pueden crear áreas.
	call_deferred("_soltar", resultado)
	CombateComun.flotante(self, global_position + Vector2(0, -50), Objetos.nombre(resultado), CombateComun.COLORES.get(el, Color.WHITE))
	var tw := create_tween()
	tw.tween_property(self, "_escala", 0.0, 0.25)
	tw.tween_interval(REBROTE)
	tw.tween_callback(func(): _viva = true)
	tw.tween_property(self, "_escala", 1.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _soltar(resultado: String) -> void:
	Botin.soltar(get_tree().current_scene, resultado, 1, global_position + Vector2(0, 4))
