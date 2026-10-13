class_name CombateComun
extends Node2D

## LO QUE COMPARTEN TODOS LOS ENEMIGOS NUEVOS (goblin guerrero, arquero y dummy).
##
## Es un nodo hijo del enemigo ("Combate") que se encarga de:
##   - la barra de vida sobre la cabeza (solo aparece tras recibir daño, y se desvanece);
##   - la DEBILIDAD y la RESISTENCIA por elemento (x2 y x0,5) y el marcador de debilidad;
##   - los EFECTOS de cada elemento (quemadura, mojado, congelado, aturdido, derribo...);
##   - los números flotantes, el destello al ser golpeado y el botín al morir.
##
## El enemigo en sí solo hace su IA y llama a `golpe()` desde `on_spell_hit()`.
##
## PROPIEDADES POR ELEMENTO (todas salen de aquí, no de los hechizos):
##   fuego   daño + QUEMADURA (3 de daño cada 0,5 s durante 3 s). Mojado la apaga.
##   agua    daño + MOJADO (6 s): va un 25 % más lento y el rayo le hace +50 % y salta.
##   rayo    daño alto + ATURDE; si está mojado, daño x1,5 y SALTA al enemigo más cercano.
##   hielo   poco daño + CONGELA (no se mueve ni ataca); mojado, congela más y hace +15.
##   viento  casi sin daño: INTERRUMPE lo que esté haciendo y lo EMPUJA lejos.
##   tierra  pedrada con daño propio + RETROCESO fuerte y lentitud (3 s).

const COLORES: Dictionary = {
	"fuego": Color(1.0, 0.45, 0.2), "agua": Color(0.35, 0.65, 1.0), "rayo": Color(1.0, 0.95, 0.35),
	"hielo": Color(0.65, 0.95, 1.0), "viento": Color(0.75, 1.0, 0.8), "tierra": Color(0.75, 0.55, 0.3),
}
const DANO_EXTRA: Dictionary = {"tierra": 18.0, "viento": 0.0}
const MULT_DEBIL: float = 2.0
const MULT_RESISTE: float = 0.5
const TIEMPO_BARRA: float = 4.0

var host: Node2D = null
var sprite: CanvasItem = null
var vida_max: float = 100.0
var debil: String = ""
var resiste: String = ""
var nombre: String = ""
var nombre_fijo: bool = false      ## el dummy lleva su nombre siempre a la vista
var oro: int = 10                  ## botín de oro al morir
var tinte: Color = Color.WHITE     ## color propio del enemigo (su paleta)
var altura: float = 120.0          ## a qué altura sobre sus pies va la barra

var quemando: float = 0.0
var mojado: float = 0.0
var congelado: float = 0.0
var lento: float = 0.0
var _tick_fuego: float = 0.0
var _barra_t: float = 0.0
var _vida_mostrada: float = 1.0
var _destello: float = 0.0
var _muerto: bool = false


## Crea el componente y lo cuelga del enemigo.
static func equipar(en: Node2D, p_vida: float, p_debil: String, p_resiste: String,
		p_nombre: String, p_tinte: Color = Color.WHITE) -> CombateComun:
	var c := CombateComun.new()
	c.name = "Combate"
	c.host = en
	c.vida_max = p_vida
	c.debil = p_debil
	c.resiste = p_resiste
	c.nombre = p_nombre
	c.tinte = p_tinte
	c.z_index = 50
	en.add_child(c)
	return c


func _ready() -> void:
	sprite = host.get_node_or_null("Sprite2D") as CanvasItem
	_calcular_altura()
	if sprite != null:
		sprite.self_modulate = tinte


## Altura de la cabeza a partir del tamaño del dibujo del personaje.
func _calcular_altura() -> void:
	var s := sprite as Sprite2D
	if s == null:
		return
	var alto: float = 240.0
	if s.texture != null:
		alto = s.texture.get_size().y
	altura = clampf(absf(s.offset.y) * s.scale.y + alto * s.scale.y * 0.30, 70.0, 190.0)


## --- Daño ---

func multiplicador(elemento: String) -> float:
	if elemento == "":
		return 1.0
	if elemento == debil:
		return MULT_DEBIL
	if elemento == resiste or (resiste == "agua" and elemento == "hielo"):
		return MULT_RESISTE
	return 1.0


func vel_mult() -> float:
	if congelado > 0.0:
		return 0.0
	var m: float = 1.0
	if mojado > 0.0:
		m *= 0.75
	if lento > 0.0:
		m *= 0.6
	return m


## Un hechizo alcanza al enemigo. Calcula daño y efectos y se los aplica al anfitrión.
func golpe(rune_data: RuneData, direccion: Vector2) -> void:
	if _muerto or rune_data == null:
		return
	var el: String = Objetos.elemento_de(rune_data)
	var base: float = rune_data.damage + float(DANO_EXTRA.get(el, 0.0))
	var mult: float = multiplicador(el)

	# Interacciones entre elementos
	match el:
		"fuego":
			if mojado > 0.0:
				mojado = 0.0
				texto("¡Vapor!", Color(0.85, 0.9, 1.0))
			else:
				quemando = 3.0
		"agua":
			mojado = 6.0
			quemando = 0.0
		"rayo":
			if mojado > 0.0:
				base *= 1.5
				_arco_cercano(base * 0.5)
		"hielo":
			congelado = 2.5 if mojado > 0.0 else 1.5
			if mojado > 0.0:
				base += 15.0
			quemando = 0.0
		"viento":
			host.set("interrupcion", 0.7)
			_cancelar_acciones()
		"tierra":
			lento = 3.0

	var dano: float = base * mult
	if mult > 1.0:
		texto("¡Débil!", COLORES.get(debil, Color.WHITE), -22.0)
	elif mult < 1.0 and base > 0.0:
		texto("Resiste", Color(0.7, 0.7, 0.7), -22.0)

	# Retroceso: cada elemento empuja distinto.
	var fuerza: float = {"viento": 2600.0, "tierra": 2200.0, "agua": 600.0, "fuego": 500.0,
		"hielo": 300.0, "rayo": 400.0}.get(el, 400.0)
	if direccion != Vector2.ZERO and host.has_method("push"):
		host.call("push", direccion, fuerza)

	if rune_data.tags.has("electrico") and host.has_method("_stun"):
		host.call("_stun")

	if dano > 0.0:
		host.call("receive_damage", dano)
	else:
		_destello = 0.12


func _cancelar_acciones() -> void:
	host.set("charge", 0.0)
	host.set("aim_timer", 0.0)


func _arco_cercano(dano: float) -> void:
	var mejor: Node2D = null
	var dmin: float = 190.0
	for n in get_tree().get_nodes_in_group("goblins"):
		if n == host or not is_instance_valid(n):
			continue
		# Un cadaver no recibe el arco (1.2): el pestillo es la vida, como en receive_damage().
		if float(n.get("health")) <= 0.0:
			continue
		var d: float = host.global_position.distance_to((n as Node2D).global_position)
		if d < dmin:
			dmin = d
			mejor = n
	if mejor != null:
		BlockFx.burst(mejor, "chispas")
		mejor.call("receive_damage", dano)
		texto("¡Descarga!", COLORES["rayo"])


## --- Reacciones visuales ---

## Lo llama el enemigo cada vez que pierde vida.
func herido(cantidad: float, vida: float) -> void:
	_barra_t = TIEMPO_BARRA
	_destello = 0.10
	_vida_mostrada = clampf(vida / vida_max, 0.0, 1.0)
	texto(str(int(round(cantidad))), Color(1, 0.95, 0.85))
	Sonidos.play(host, "golpe", -9.0, randf_range(0.9, 1.1))
	# Hitstop minúsculo: sensación de impacto.
	if cantidad >= 20.0:
		Engine.time_scale = 0.12
		get_tree().create_timer(0.045, true, false, true).timeout.connect(
			func(): Engine.time_scale = 1.0)


func texto(txt: String, color: Color, desplazamiento: float = 0.0) -> void:
	CombateComun.flotante(host, host.global_position + Vector2(0.0, -altura + desplazamiento), txt, color)


static func flotante(origen: Node, pos: Vector2, txt: String, color: Color, tam: int = 18) -> void:
	if origen == null or not origen.is_inside_tree():
		return
	var l := Label.new()
	l.text = txt
	l.z_index = 200
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.top_level = true
	l.global_position = pos + Vector2(-20.0 + randf_range(-10.0, 10.0), 0.0)
	origen.get_tree().current_scene.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", pos.y - 34.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


## --- Estado ---

func _process(delta: float) -> void:
	if _muerto or not is_instance_valid(host):
		return
	if _barra_t > 0.0:
		_barra_t -= delta
	if _destello > 0.0:
		_destello -= delta
	if quemando > 0.0:
		quemando -= delta
		_tick_fuego -= delta
		if _tick_fuego <= 0.0:
			_tick_fuego = 0.5
			host.call("receive_damage", 3.0 * (MULT_DEBIL if debil == "fuego" else 1.0))
	mojado = maxf(0.0, mojado - delta)
	congelado = maxf(0.0, congelado - delta)
	lento = maxf(0.0, lento - delta)

	if sprite != null:
		var c: Color = tinte
		if congelado > 0.0:
			c = c.lerp(Color(0.6, 0.9, 1.4), 0.7)
		elif quemando > 0.0:
			c = c.lerp(Color(1.5, 0.7, 0.4), 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.02))
		elif mojado > 0.0:
			c = c.lerp(Color(0.6, 0.75, 1.2), 0.45)
		if _destello > 0.0:
			c = Color(2.2, 2.2, 2.2)
		sprite.self_modulate = c
	queue_redraw()


func _draw() -> void:
	if _muerto:
		return
	var w: float = 70.0
	var y: float = -altura - 12.0
	var fr: float = clampf(float(host.get("health")) / vida_max, 0.0, 1.0)
	_vida_mostrada = lerpf(_vida_mostrada, fr, 0.25)
	# La barra se ve SIEMPRE (así se sabe que el enemigo se puede herir); al recibir daño
	# se ve más fuerte un momento.
	var a: float = 0.75 + 0.25 * clampf(_barra_t / 0.8, 0.0, 1.0)
	# Marco
	draw_rect(Rect2(-w * 0.5 - 2.0, y - 5.0, w + 4.0, 10.0), Color(0, 0, 0, 0.8 * a))
	draw_rect(Rect2(-w * 0.5, y - 3.0, w, 6.0), Color(0.18, 0.05, 0.05, 0.9 * a))
	# Estela blanca de lo que se acaba de perder
	draw_rect(Rect2(-w * 0.5, y - 3.0, w * _vida_mostrada, 6.0), Color(1, 1, 1, 0.55 * a))
	var col: Color = Color(0.35, 0.9, 0.4) if fr > 0.5 else (Color(1.0, 0.8, 0.25) if fr > 0.25 else Color(1.0, 0.3, 0.25))
	draw_rect(Rect2(-w * 0.5, y - 3.0, w * fr, 6.0), Color(col.r, col.g, col.b, a))
	# Marcador de debilidad: un rombo del color del elemento, a la derecha de la barra.
	if debil != "":
		var cd: Color = COLORES.get(debil, Color.WHITE)
		var cx: float = w * 0.5 + 13.0
		var pts := PackedVector2Array([Vector2(cx, y - 7.0), Vector2(cx + 7.0, y), Vector2(cx, y + 7.0), Vector2(cx - 7.0, y)])
		draw_colored_polygon(pts, Color(cd.r, cd.g, cd.b, 0.95))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.85), 1.5)
	if nombre != "" and (nombre_fijo or _barra_t > 0.0):
		var f: Font = ThemeDB.fallback_font
		draw_string(f, Vector2(-w * 0.5, y - 10.0), nombre, HORIZONTAL_ALIGNMENT_LEFT, 160.0, 14, Color(1, 1, 1, 0.95))


## --- Muerte y botín ---

func morir(suelta_botin: bool = true) -> void:
	if _muerto:
		return
	_muerto = true
	queue_redraw()
	var nivel: Node = host.get_tree().current_scene
	var pos: Vector2 = host.global_position
	BlockFx.burst(host, "ceniza")
	Sfx.play(host, "muerte")
	if suelta_botin and oro > 0:
		Botin.soltar(nivel, "oro", oro, pos)
	Estado.i().enemigo_muerto.emit(pos, nombre)


## Quita lo que se dibuja encima del enemigo (por ejemplo, al reaparecer el dummy).
func revivir() -> void:
	_muerto = false
	quemando = 0.0
	mojado = 0.0
	congelado = 0.0
	lento = 0.0
	_barra_t = 0.0


## --- Utilidades de movimiento e IA (estáticas) ---

## ¿Ve el enemigo al jugador? Distancia + línea de visión (los muros la cortan).
static func ve(en: Node2D, jugador: Node2D, radio: float) -> bool:
	if jugador == null or not is_instance_valid(jugador) or jugador.get("is_dead") == true:
		return false
	var d: float = en.global_position.distance_to(jugador.global_position)
	if d > radio:
		return false
	var q := PhysicsRayQueryParameters2D.create(en.global_position + Vector2(0, -20),
		jugador.global_position + Vector2(0, -20), 1)
	q.exclude = [(jugador as CollisionObject2D).get_rid()] if jugador is CollisionObject2D else []
	q.collide_with_areas = false
	return en.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


static func libre(en: Node2D, pos: Vector2, jugador: Node2D) -> bool:
	var forma := CircleShape2D.new()
	forma.radius = 13.0
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = forma
	q.transform = Transform2D(0.0, pos)
	q.collision_mask = 1
	q.collide_with_areas = false
	# No cuenta ni el jugador ni los cuerpos del propio enemigo (enemy.tscn lleva un
	# "SolidBody" que, si no, lo dejaría clavado en el sitio).
	var fuera: Array[RID] = []
	if jugador is CollisionObject2D:
		fuera.append((jugador as CollisionObject2D).get_rid())
	for h in en.get_children():
		if h is CollisionObject2D:
			fuera.append((h as CollisionObject2D).get_rid())
	q.exclude = fuera
	return en.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


## Mueve `paso` píxeles, deslizando por los ejes si hay un muro. Devuelve si se movió.
static func mover(en: Node2D, paso: Vector2, jugador: Node2D) -> bool:
	if paso.length() < 0.001:
		return false
	var p: Vector2 = en.global_position
	if libre(en, p + paso, jugador):
		en.global_position = p + paso
		return true
	if absf(paso.x) > 0.01 and libre(en, p + Vector2(paso.x, 0.0), jugador):
		en.global_position = p + Vector2(paso.x, 0.0)
		return true
	if absf(paso.y) > 0.01 and libre(en, p + Vector2(0.0, paso.y), jugador):
		en.global_position = p + Vector2(0.0, paso.y)
		return true
	return false
