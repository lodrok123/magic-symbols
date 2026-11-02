class_name MarcadorMision
extends Control

## MARCADOR DE MISIÓN EN EL MUNDO (tercera tanda, lote 3, tarea C1; 2/11). Una flecha dorada en el borde de la pantalla hacia el objetivo de la misión seguida, con la distancia en metros
## (1 casilla = 1 m: `Terreno3D.casilla`); cuando el objetivo se ve en pantalla, un rombo pequeño flota sobre él. Se oculta a menos de `DIST_OCULTAR_MARCADOR` u del objetivo.
##
## DE DÓNDE SALE EL PUNTO. `Misiones.i().punto_objetivo(seguida)`: el punto del primer objetivo pendiente de la misión seguida (o el de la misión) que puso el nivel con
## `Misiones.fijar_punto`. Sin punto no hay marcador; al completar la misión (deja de estar activa) desaparece. Un punto es un Vector3 o el nombre de un grupo (el primer nodo del grupo).
##
## DIBUJO. La proyección al borde es la de las flechas de aviso de ataque (`Sensacion3D.punta_flecha`, DirectorSensacion): del centro de la pantalla hacia el objetivo hasta el rectángulo
## interior, con la flecha de triángulo con sombra negra. Aquí se vuelve a calcular con el mismo método (`punta_en_borde`) porque aquella está atada a un `AvisoAtaque3D`.
## Es INFORMACIÓN, no sensación: `Sensacion3D.ACTIVA = false` no la apaga (solo quita el latido del rombo).
##
## En el juego lo monta el Lanzador3D en su capa de interfaz, junto a la línea de misión del HUD.

static var MARCADOR_MISION_ACTIVO: bool = true
static var DIST_OCULTAR_MARCADOR: float = 5.0          ## u: más cerca que esto del objetivo, no se enseña nada
static var MARGEN_MARCADOR: float = 46.0               ## px del borde de la pantalla a los que se pega la flecha
static var TAM_FLECHA_MARCADOR: float = 15.0           ## px de la mitad de la base de la flecha
static var TAM_ROMBO_MARCADOR: float = 9.0             ## px del radio del rombo
static var ALTO_ROMBO_U: float = 3.0                   ## u sobre el objetivo a las que flota el rombo
static var LATIDO_ROMBO: float = 0.12                  ## fracción que respira el rombo (solo con Sensacion3D.ACTIVA)
static var COLOR_MARCADOR: Color = TemaInterfaz.BORDE_CALIDO
static var TAM_TEXTO_MARCADOR: int = 14

## Qué se ve ahora: «oculto», «flecha» o «rombo». Las pruebas lo leen.
var estado: String = "oculto"
var metros: int = 0                                    ## distancia horizontal al objetivo en casillas (1 m)
var distancia_u: float = 0.0
var punta: Vector2 = Vector2.ZERO                      ## dónde está la punta de la flecha (estado «flecha») o el centro del rombo (estado «rombo»)
var objetivo: Variant = null                           ## el Vector3 resuelto del objetivo, o null
var jugador: Node3D = null                             ## si no se da, el de `Lanzador3D` (grupo «spellcaster»)
var camara: Camera3D = null                            ## si no se da, la del viewport
var tamano: Vector2 = Vector2.ZERO                     ## si es cero, el del control
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "MarcadorMision"


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.01)
	actualizar()
	queue_redraw()


## Recalcula `estado`, `metros` y `punta`. Lo llama el `_process`; las pruebas lo llaman a mano tras mover al jugador o la cámara.
func actualizar() -> void:
	estado = "oculto"
	objetivo = null
	if not MARCADOR_MISION_ACTIVO or not is_inside_tree():
		return
	var mi: Misiones = Misiones.i()
	var id: String = mi.seguida_id()
	if id == "":
		return
	var p: Variant = _resolver(mi.punto_objetivo(id))
	if p == null:
		return
	var j: Node3D = _jugador()
	if j == null:
		return
	objetivo = p
	var dv: Vector3 = (p as Vector3) - j.global_position
	distancia_u = Vector2(dv.x, dv.z).length()
	metros = int(round(distancia_u / maxf(Terreno3D.casilla, 0.01)))
	if distancia_u < DIST_OCULTAR_MARCADOR:
		return
	var cam: Camera3D = camara if camara != null else get_viewport().get_camera_3d()
	if cam == null:
		return
	var tam: Vector2 = tamano if tamano != Vector2.ZERO else size
	if tam.x < 1.0 or tam.y < 1.0:
		tam = get_viewport_rect().size
	var m: float = MARGEN_MARCADOR
	var dentro := Rect2(Vector2(m, m), tam - Vector2(m, m) * 2.0)
	var sobre: Vector3 = (p as Vector3) + Vector3(0.0, ALTO_ROMBO_U, 0.0)
	if not cam.is_position_behind(sobre) and Rect2(Vector2.ZERO, tam).grow(-8.0).has_point(cam.unproject_position(sobre)):
		estado = "rombo"
		punta = cam.unproject_position(sobre)
		return
	var b: Variant = punta_en_borde(cam, tam, dentro, p as Vector3)
	if b == null:
		return
	estado = "flecha"
	punta = b


## Dónde toca el borde del rectángulo `dentro` la recta del centro de la pantalla hacia `p` (la misma cuenta que `Sensacion3D.punta_flecha`). null si cae justo en el centro.
static func punta_en_borde(cam: Camera3D, tam: Vector2, dentro: Rect2, p: Vector3) -> Variant:
	var detras: bool = cam.is_position_behind(p)
	var s: Vector2 = cam.unproject_position(p)
	var c: Vector2 = tam * 0.5
	var dir: Vector2 = (s - c) * (-1.0 if detras else 1.0)
	if dir.length() < 0.001:
		return null
	dir = dir.normalized()
	var k: float = INF
	if absf(dir.x) > 0.0001:
		k = minf(k, ((dentro.end.x if dir.x > 0.0 else dentro.position.x) - c.x) / dir.x)
	if absf(dir.y) > 0.0001:
		k = minf(k, ((dentro.end.y if dir.y > 0.0 else dentro.position.y) - c.y) / dir.y)
	return c + dir * k


func _resolver(punto: Variant) -> Variant:
	if punto is Vector3:
		return punto
	if punto is String or punto is StringName:
		var n: Node3D = get_tree().get_first_node_in_group(String(punto)) as Node3D
		if n != null and is_instance_valid(n) and n.is_inside_tree():
			return n.global_position
	return null


func _jugador() -> Node3D:
	if jugador != null and is_instance_valid(jugador) and jugador.is_inside_tree():
		return jugador
	var lz: Node = get_tree().get_first_node_in_group("spellcaster")
	if lz != null:
		var j: Variant = lz.get("jugador")
		if j is Node3D and is_instance_valid(j):
			return j as Node3D
	return null


func _draw() -> void:
	if estado == "oculto":
		return
	var tam: Vector2 = tamano if tamano != Vector2.ZERO else size
	var col: Color = COLOR_MARCADOR
	if estado == "rombo":
		var r: float = TAM_ROMBO_MARCADOR * (1.0 + (LATIDO_ROMBO * sin(_t * 4.0) if Sensacion3D.ACTIVA else 0.0))
		var pts := PackedVector2Array([punta + Vector2(0, -r), punta + Vector2(r * 0.7, 0), punta + Vector2(0, r), punta + Vector2(-r * 0.7, 0)])
		draw_colored_polygon(PackedVector2Array([pts[0] + Vector2(0, -2), pts[1] + Vector2(2, 0), pts[2] + Vector2(0, 2), pts[3] + Vector2(-2, 0)]), Color(0, 0, 0, 0.55))
		draw_colored_polygon(pts, col)
		_texto("%d m" % metros, punta + Vector2(0, -r - 6.0), 0)
		return
	var dir: Vector2 = (punta - tam * 0.5).normalized()
	var f: float = TAM_FLECHA_MARCADOR
	var lado := Vector2(-dir.y, dir.x)
	var base: Vector2 = punta - dir * f * 1.3
	draw_colored_polygon(PackedVector2Array([punta + dir * 3.0, base + lado * (f + 3.0), base - lado * (f + 3.0)]), Color(0, 0, 0, 0.55))
	draw_colored_polygon(PackedVector2Array([punta, base + lado * f, base - lado * f]), col)
	# La distancia, hacia dentro de la flecha (lejos del borde).
	_texto("%d m" % metros, base - dir * (f + 6.0), 1)


func _texto(t: String, centro: Vector2, _modo: int) -> void:
	var fuente: Font = ThemeDB.fallback_font
	var ancho: float = fuente.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TEXTO_MARCADOR).x
	var pos: Vector2 = centro - Vector2(ancho * 0.5, -TAM_TEXTO_MARCADOR * 0.35)
	draw_string_outline(fuente, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TEXTO_MARCADOR, 5, Color(0, 0, 0, 0.9))
	draw_string(fuente, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_TEXTO_MARCADOR, TemaInterfaz.TEXTO)
