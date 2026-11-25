extends Node3D

## COMPARATIVA DE IMPACTOS: LO DE AHORA FRENTE A LO TRADUCIDO DE EFFEKSEER (25/11/2026). Va aparte para que lab_vfx_comparativa_3d.gd solo lleve unas teclas.
## Pablo: «ejecuta toda la lista y implementa una comparación con lo que ya hay para ver qué merece la pena y qué no».
## Cada PAR se repite solo: a la IZQUIERDA el impacto de ahora (ImpactoFuegoToy, ExplosionFuegoToy, ImpactoAguaToy, ImpactoTierraToy) y a la DERECHA la receta de Effekseer
## traducida a nuestras piezas (impacto_capas_toy.gd + recetas_effekseer.gd), los dos a la vez, en la misma superficie y con la misma bola (radio 0,4).
## Teclas (dentro de LabVfxComparativa3D):
##   Ctrl+4  pone / quita la comparativa (esconde a la jugadora; al quitarla vuelve todo como estaba)
##   Ctrl+5  par siguiente (Mayús+Ctrl+5: anterior): 1 golpe hit01 · 2 golpe toon · 3 explosión fire02 · 4 salpicadura toon · 5 golpe de tierra
##   Ctrl+6  vista: juego (ortogonal, 30°) → cerca (perspectiva) → solo el traducido de cerca
##   Ctrl+7  cámara lenta ×0,25 sí / no
## Capturas: herramientas/captura_impactos_effekseer.gd.

const Recetas = preload("res://presentacion/vfx/toy/recetas_effekseer.gd")
const ImpactoCapasToy = preload("res://presentacion/vfx/toy/impacto_capas_toy.gd")
const EstelaMundo = preload("res://presentacion/vfx/toy/estela_mundo_toy.gd")
const NOMBRE: String = "ComparativaEffekseer"
const CENTRO: Vector3 = Vector3(0.0, 0.0, -2.5)     ## entre los cubos del mapa del lab
const SEPARACION: float = 1.8                         ## m del centro a cada impacto
const RADIO: float = 0.4                              ## la bola del lab (RADIO_BOLA_LAB)
const ALTO_PARED: float = 1.1                         ## m sobre el suelo donde choca la bola en la pared
const PAUSA: float = 0.8                              ## s entre una repetición y la siguiente
const VISTAS: PackedStringArray = ["juego", "cerca", "traducido"]
const LENTO: float = 0.25

var par: int = 0
var vista: int = 0
var lento: bool = false
var auto: bool = true                                 ## false: no se repite solo (las capturas lanzan a mano)
var _lab: Node3D = null
var _cam: Camera3D = null
var _escenario: Node3D = null
var _efectos: Node3D = null
var _rotulo: Label = null
var _reloj: float = 0.0
var _ciclo: float = 1.5
var _pj_visible: bool = true
var _panel_lab: bool = true


# ------------------------------------------------------------------ desde el lab ------------------------------------------------------------------

## Ctrl+4 / 5 / 6 / 7 del lab. Devuelve el nodo de la comparativa (o null si se ha quitado).
static func tecla(lab: Node3D, keycode: int, mayus: bool) -> Node:
	var c: Node = lab.get_node_or_null(NOMBRE)
	if keycode == KEY_8:                                  # 25/11: estela que se queda en el mundo (EstelaMundoToy) en las bolas de fuego, agua y tierra: F4 lanza la bola en vuelo, Z cambia de elemento
		EstelaMundo.activa = not EstelaMundo.activa
		return c
	if keycode == KEY_4:
		if c != null:
			c.call("quitar")
			return null
		return poner(lab)
	if c == null:
		c = poner(lab)
	match keycode:
		KEY_5:
			c.call("poner_par", (int(c.get("par")) + (Recetas.RECETAS.size() - 1 if mayus else 1)) % Recetas.RECETAS.size())
		KEY_6:
			c.call("poner_vista", (int(c.get("vista")) + 1) % VISTAS.size())
		KEY_7:
			c.call("poner_lento", not bool(c.get("lento")))
	return c


static func poner(lab: Node3D) -> Node:
	var c: Node3D = (load("res://laboratorios/lab_impactos_effekseer.gd") as GDScript).new()
	c.name = NOMBRE
	c.set("_lab", lab)
	lab.add_child(c)
	return c


static func texto(lab: Node3D) -> String:
	return "\nCtrl+4 COMPARATIVA de impactos: ahora (izq.) frente a Effekseer traducido (der.) · Ctrl+5 par · Ctrl+6 vista · Ctrl+7 cámara lenta" + \
		(" · PUESTA" if lab.get_node_or_null(NOMBRE) != null else "") + \
		"\nCtrl+8 ESTELA EN EL MUNDO de la bola (fuego, agua, tierra; F4 bola en vuelo, Z elemento): " + ("SÍ" if EstelaMundo.activa else "no")


# ------------------------------------------------------------------ montaje ------------------------------------------------------------------

func _ready() -> void:
	var pj: Node3D = _lab.get("_pj") if _lab != null else null
	if pj != null:
		_pj_visible = pj.visible
		pj.visible = false
	if _lab != null:                                   # el panel del lab taparía el rótulo de la comparativa
		_panel_lab = bool(_lab.get("_panel_visible"))
		_lab.set("_panel_visible", false)
	_escenario = Node3D.new()
	_escenario.name = "Escenario"
	add_child(_escenario)
	_efectos = Node3D.new()
	_efectos.name = "Efectos"
	add_child(_efectos)
	_cam = Camera3D.new()
	_cam.name = "CamaraComparativa"
	add_child(_cam)
	_cam.make_current()
	var capa: CanvasLayer = CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.position = Vector2(16, 16)
	_rotulo.add_theme_font_size_override("font_size", 17)
	_rotulo.add_theme_color_override("font_color", Color(1, 1, 1))
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_rotulo.add_theme_constant_override("outline_size", 5)
	capa.add_child(_rotulo)
	poner_par(par)


func quitar() -> void:
	poner_lento(false)
	var pj: Node3D = _lab.get("_pj") if _lab != null else null
	if pj != null:
		pj.visible = _pj_visible
	if _lab != null:
		_lab.set("_panel_visible", _panel_lab)
	var cam_lab: Camera3D = _lab.get("_cam") if _lab != null else null
	if cam_lab != null:
		cam_lab.make_current()
	queue_free()


func receta() -> Dictionary:
	return Recetas.RECETAS[par]


func poner_par(i: int) -> void:
	par = clampi(i, 0, Recetas.RECETAS.size() - 1)
	for h in _escenario.get_children():
		h.queue_free()
	if _es_pared():
		for lado in [-1.0, 1.0]:
			_pared(CENTRO + Vector3(lado * SEPARACION, 0, -0.15))
	for lado2 in [-1.0, 1.0]:
		var l3: Label3D = Label3D.new()
		l3.text = ("AHORA\n" + String(receta()["actual"])) if lado2 < 0.0 else ("EFFEKSEER → NUESTRO\n" + String(receta()["titulo"]))
		l3.font_size = 40
		l3.pixel_size = 0.004
		l3.outline_size = 10
		l3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l3.no_depth_test = true
		l3.position = CENTRO + Vector3(lado2 * SEPARACION, 0.05, 1.6)          # a ras de suelo, delante: no tapa el impacto ni el rótulo de arriba
		_escenario.add_child(l3)
	poner_vista(vista)
	lanzar_par()


## Las capturas esconden los rótulos (el de arriba y los del suelo) para que no tapen los impactos.
func rotulos(si: bool) -> void:
	if _rotulo != null:
		_rotulo.visible = si
	for h in _escenario.get_children():
		if h is Label3D:
			(h as Label3D).visible = si


func _es_pared() -> bool:
	return String(receta()["superficie"]) == "pared"


func _pared(pos: Vector3) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(3.0, 2.6, 0.3)
	mi.mesh = bm
	var mt: StandardMaterial3D = StandardMaterial3D.new()
	mt.albedo_color = Color(0.56, 0.52, 0.47)          # el gris de la pared de impacto del lab
	mt.roughness = 0.95
	mi.material_override = mt
	mi.position = pos + Vector3(0, 1.3, 0)
	_escenario.add_child(mi)


## Punto de impacto y normal de cada lado (-1 izquierda = lo de ahora, +1 derecha = lo traducido).
func _punto(lado: float) -> Vector3:
	return CENTRO + Vector3(lado * SEPARACION, ALTO_PARED if _es_pared() else 0.0, 0.0)


func _normal() -> Vector3:
	return Vector3.BACK if _es_pared() else Vector3.UP


## Lanza los dos impactos del par a la vez. Devuelve [actual, traducido].
func lanzar_par() -> Array:
	for h in _efectos.get_children():
		h.queue_free()
	var r: Dictionary = receta()
	var a: Node3D = _actual(String(r["id"]))
	_efectos.add_child(a)
	a.global_position = _punto(-1.0)
	var b: Node3D = ImpactoCapasToy.crear(r, String(r["elemento"]), _normal(), RADIO)
	b.set("suelo_y", 0.0)
	_efectos.add_child(b)
	b.global_position = _punto(1.0)
	var d_a: float = float(a.call("duracion")) if a.has_method("duracion") else 1.5
	_ciclo = maxf(d_a, float(b.call("duracion"))) + PAUSA
	_reloj = 0.0
	_rotular()
	return [a, b]


## El impacto de ahora con el que se compara cada receta.
func _actual(id: String) -> Node3D:
	match id:
		"fire02":
			return ExplosionFuegoToy.crear(1.8)
		"toonwater":
			return ImpactoAguaToy.crear(ImpactoAguaToy.Variante.GOLPE, Vector3.UP, RADIO)
		"tierra":
			return ImpactoTierraToy.crear(ImpactoTierraToy.Variante.GOLPE, Vector3.UP, RADIO)
	return ImpactoFuegoToy.crear(ImpactoFuegoToy.Variante.GOLPE, _normal(), RADIO, ImpactoFuegoToy.Estilo.C)


func poner_vista(v: int) -> void:
	vista = clampi(v, 0, VISTAS.size() - 1)
	var foco: Vector3 = CENTRO + Vector3(0, 0.8, 0)
	match VISTAS[vista]:
		"juego":                                     # como el juego: ortogonal, 30° sobre el suelo (PruebaTest2), con los dos impactos dentro
			_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			_cam.size = 6.0
			_cam.global_position = foco + Vector3(0, sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0))) * 20.0
			_cam.look_at(foco, Vector3.UP)
		"cerca":
			_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			_cam.fov = 50.0
			_cam.global_position = foco + Vector3(0, 1.2, 5.6)
			_cam.look_at(foco, Vector3.UP)
		_:
			var f2: Vector3 = _punto(1.0) + Vector3(0, 0.6 if not _es_pared() else 0.0, 0)
			_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			_cam.fov = 50.0
			_cam.global_position = f2 + Vector3(0, 0.9, 3.0)
			_cam.look_at(f2, Vector3.UP)
	_rotular()


func poner_lento(si: bool) -> void:
	lento = si
	Engine.time_scale = LENTO if si else 1.0
	_rotular()


func _exit_tree() -> void:
	if lento:
		Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if not auto:
		return
	_reloj += delta
	if _reloj >= _ciclo:
		lanzar_par()


func _rotular() -> void:
	if _rotulo == null:
		return
	var r: Dictionary = receta()
	var nt: String = ""
	for s in r.get("no_traducido", []):
		nt += "\n   · " + String(s)
	_rotulo.text = ("COMPARATIVA DE IMPACTOS %d/%d: %s   (elemento %s, %s)\nizquierda AHORA: %s\nderecha EFFEKSEER traducido a nuestras piezas: %s   ·   escala %s\nNo traducido:%s\n" +
		"Ctrl+5 par siguiente (Mayús: anterior) · Ctrl+6 vista: %s · Ctrl+7 cámara lenta: %s · Ctrl+4 salir   ·   se repite cada %.1f s") % [
		par + 1, Recetas.RECETAS.size(), String(r["titulo"]), String(r["elemento"]), String(r["superficie"]), String(r["actual"]), String(r["origen"]), String(r["escala"]), nt,
		VISTAS[vista], "SÍ" if lento else "no", _ciclo]
