class_name Botin
extends Area2D

## UN OBJETO EN EL SUELO: oro, pociones o ingredientes.
##
##   oro y poción ....... se recogen solos al pasar por encima (si cabe en la mochila)
##   ingredientes ....... se quedan en el suelo; al hacer CLIC encima aparece su nombre
##                        un momento, y se recogen con E estando cerca
##
## Al recogerlo suena un efecto y el héroe hace el gesto de agacharse a coger.

const RADIO_RECOGER: float = 80.0

var id: String = "oro"
var cantidad: int = 1
var _t: float = 0.0
var _rotulo: float = 0.0
var _cogido: bool = false
var _protegido: float = 0.6        ## justo al caer no se coge (para verlo salir)


## Crea un botín en `pos`, lanzado con un pequeño salto.
static func soltar(nivel: Node, p_id: String, p_cantidad: int, pos: Vector2) -> Botin:
	var b := Botin.new()
	b.id = p_id
	b.cantidad = p_cantidad
	b.y_sort_enabled = true
	nivel.add_child(b)
	b.global_position = pos
	var destino: Vector2 = pos + Vector2(randf_range(-30.0, 30.0), randf_range(8.0, 26.0))
	var tw := b.create_tween()
	tw.tween_property(b, "global_position", destino, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return b


func es_manual() -> bool:
	return Objetos.es_ingrediente(id)


func _ready() -> void:
	add_to_group("botin")
	_t = randf() * TAU
	collision_layer = 0
	collision_mask = 1
	var forma := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 22.0
	forma.shape = c
	add_child(forma)
	body_entered.connect(_on_body)
	if id != "oro":
		Glow.attach(self, Objetos.color(id), 50.0, 0.25)


func _process(delta: float) -> void:
	_t += delta
	if _protegido > 0.0:
		_protegido -= delta
	if _rotulo > 0.0:
		_rotulo -= delta
	queue_redraw()
	if _protegido <= 0.0 and not es_manual() and not _cogido:
		for b in get_overlapping_bodies():
			if b.is_in_group("player"):
				intentar_coger(b)


func _draw() -> void:
	var k: float = 1.0 - 0.1 * sin(_t * 2.4)
	var pts := PackedVector2Array()
	for i in range(17):
		var a: float = TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 11.0 * k, 2.0 + sin(a) * 4.0 * k))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.28))
	Objetos.dibujar(self, id, Vector2(0.0, -12.0 + sin(_t * 2.4) * 2.5), 10.0)
	if _rotulo > 0.0:
		var f: Font = ThemeDB.fallback_font
		var txt: String = Objetos.nombre(id) + ("  x%d" % cantidad if cantidad > 1 else "")
		var ancho: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var a2: float = clampf(_rotulo / 0.5, 0.0, 1.0)
		draw_rect(Rect2(-ancho * 0.5 - 5.0, -48.0, ancho + 10.0, 19.0), Color(0, 0, 0, 0.6 * a2))
		draw_string(f, Vector2(-ancho * 0.5, -34.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a2))


func _input(event: InputEvent) -> void:
	var m := event as InputEventMouseButton
	if m == null or not m.pressed or m.button_index != MOUSE_BUTTON_LEFT:
		return
	if get_global_mouse_position().distance_to(global_position + Vector2(0, -12)) < 26.0:
		_rotulo = 3.0


func _on_body(body: Node) -> void:
	if _protegido <= 0.0 and not es_manual() and body.is_in_group("player"):
		intentar_coger(body)


## Intenta meterlo en la mochila. Devuelve si lo cogió.
func intentar_coger(jugador: Node) -> bool:
	if _cogido:
		return false
	var e: Estado = Estado.i()
	if id == "oro":
		e.dar_oro(cantidad)
		Sonidos.play(self, "moneda", -8.0)
		CombateComun.flotante(self, global_position + Vector2(0, -40), "+%d oro" % cantidad, Color(1, 0.88, 0.3))
	else:
		var entra: int = e.agregar(id, cantidad)
		if entra <= 0:
			if _rotulo <= 0.0:
				CombateComun.flotante(self, global_position + Vector2(0, -40), "Mochila llena", Color(1, 0.5, 0.4))
			return false
		Sonidos.play(self, "recoger", -8.0)
		CombateComun.flotante(self, global_position + Vector2(0, -40), "+%d %s" % [entra, Objetos.nombre(id)], Objetos.color(id).lightened(0.3))
		cantidad -= entra
		if cantidad > 0:
			return true
	_cogido = true
	if jugador != null and jugador.has_method("recoger_anim"):
		jugador.call("recoger_anim")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 22.0, 0.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)
	return true


## El ingrediente más cercano al punto (para la tecla E).
static func cercano(arbol: SceneTree, pos: Vector2) -> Botin:
	var mejor: Botin = null
	var dmin: float = RADIO_RECOGER
	for b in arbol.get_nodes_in_group("botin"):
		var bb := b as Botin
		if bb == null or bb._cogido or not bb.es_manual():
			continue
		var d: float = pos.distance_to(bb.global_position)
		if d < dmin:
			dmin = d
			mejor = bb
	return mejor
