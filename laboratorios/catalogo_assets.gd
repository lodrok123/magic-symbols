extends Node3D

## CATÁLOGO DE ASSETS de la prueba pastel: todas las piezas de las bibliotecas de Meshy (bosque, objetos,
## magia) en fila, a la medida con la que salen en la maqueta de Test 2, con su nombre encima; y los
## personajes chibi uno al lado de otro, a la misma altura, para comparar proporciones.
## Sirve para revisar de un vistazo qué pieza está mal (rota, mezclada, mal medida, mal orientada).
##
## Teclas: 1 piezas · 2 personajes · Q/E girar todo · R/F inclinación · +/- zoom · flechas mover · L luz
##         (personajes) 3/4 cabeza · 5/6 piernas · 7/8 torso de los que tienen proporciones (chibi_elf)
##                      0 proporciones originales / ajustadas · A siguiente animación

const BIBLIOTECAS: Array = ["res://poc_25d/meshy/bosque.glb", "res://poc_25d/meshy/objetos.glb",
	"res://poc_25d/meshy/magia.glb"]
const PERSONAJES: Array = ["chibi_elf_v2", "chibi_elf", "bookseller_chibi", "goblin_warrior_chibi", "goblin_espadachin", "chibi_test"]
const POR_FILA: int = 6
const HUECO: float = 3.4

@export var modo: int = 0             ## 0 piezas, 1 personajes
@export var uniforme: bool = true     ## piezas todas al mismo tamaño (para ver la forma) o a su medida de la maqueta
@export var solo_biblioteca: String = ""  ## "bosque", "objetos" o "magia" para ver solo una
@export var solo_pieza: String = ""       ## id de una pieza para verla sola
@export var giro: float = 25.0        ## grados alrededor de la vertical
@export var inclinacion: float = 30.0 ## grados sobre el horizonte de la cámara
@export var zoom: float = 0.0         ## 0 = automático
@export var foco: Vector3 = Vector3.INF
@export var limpio: bool = false       ## sin textos ni rayas (para sacar imágenes de referencia)

var _raiz: Node3D = null
var _camara: Camera3D = null
var _hud: Label = null
var _centro: Vector3 = Vector3.ZERO
var _tam: float = 10.0
var _luz_suave: bool = true
var _originales: bool = false
var _anim: int = 0


## Pone a todos los personajes en una animación (idle, walk, run...).
func animar(nombre: String) -> void:
	for h in _raiz.get_children():
		if h is Pj3D:
			(h as Pj3D).jugar(nombre)


## Línea del HUD con las proporciones de los personajes ajustables.
func _texto_proporciones() -> void:
	var t: PackedStringArray = PackedStringArray()
	for h in _raiz.get_children():
		if h is Pj3D and (h as Pj3D).proporcion != null:
			var pr: ProporcionChibi = (h as Pj3D).proporcion
			t.append("%s: cabeza %.2f · piernas %.2f · torso %.2f" % [(h as Pj3D).id, pr.cabeza, pr.piernas, pr.torso])
	var lineas: PackedStringArray = _hud.text.split("\n")
	_hud.text = lineas[0] + "\n" + lineas[1] + "\n" + "  ".join(t)


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.94, 1.0)
	env.ambient_light_energy = 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sol.light_energy = 0.75
	sol.shadow_enabled = true
	add_child(sol)

	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200.0, 200.0)
	suelo.mesh = plano
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.78, 0.88, 0.72)
	ms.roughness = 1.0
	suelo.material_override = ms
	add_child(suelo)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.far = 400.0
	add_child(_camara)

	var capa := CanvasLayer.new()
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 8.0)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)
	_montar()


func _montar() -> void:
	if _raiz != null:
		_raiz.free()
	_raiz = Node3D.new()
	add_child(_raiz)
	if modo == 0:
		_montar_piezas()
	else:
		_montar_personajes()
	if foco != Vector3.INF:
		_centro = foco
	if limpio:
		_hud.visible = false
		for h in _raiz.get_children():
			if h is Label3D or (h is MeshInstance3D and (h as MeshInstance3D).mesh is BoxMesh):
				(h as Node3D).visible = false
	if zoom > 0.0:
		_tam = zoom
	_colocar_camara()


func _montar_piezas() -> void:
	var medidas: Dictionary = _medidas_maqueta()
	var i: int = 0
	var avisos: PackedStringArray = PackedStringArray()
	for ruta in BIBLIOTECAS:
		var r: String = String(ruta)
		if solo_biblioteca != "" and not r.contains(solo_biblioteca):
			continue
		if not ResourceLoader.exists(r):
			avisos.append("falta " + r.get_file())
			continue
		var lib: Node3D = (load(r) as PackedScene).instantiate() as Node3D
		for pieza in _piezas_de(lib):
			var id: String = String(pieza.name)
			if solo_pieza != "" and id != solo_pieza:
				continue
			var copia: Node3D = pieza.duplicate() as Node3D
			copia.transform = Transform3D.IDENTITY
			var caja: AABB = _caja(copia, Transform3D.IDENTITY)
			var cont := Node3D.new()
			cont.add_child(copia)
			var alto: float = float(medidas.get(id, 1.0))
			var f: float = alto / maxf(caja.size.y, 0.0001)
			if _medidas_ancho().has(id):
				f = float(_medidas_ancho()[id]) / maxf(caja.size.x, caja.size.z)
			if uniforme:
				alto = 2.2 * caja.size.y / maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
				f = 2.2 / maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
			copia.scale *= f
			copia.position = -Vector3(caja.position.x + caja.size.x * 0.5, caja.position.y, caja.position.z + caja.size.z * 0.5) * f
			cont.position = Vector3(float(i % POR_FILA) * HUECO, 0.0, float(floori(float(i) / float(POR_FILA))) * HUECO * 1.1)
			cont.rotation_degrees.y = giro
			_raiz.add_child(cont)
			var l := Label3D.new()
			l.text = "%s  (%d tri)" % [id, _triangulos(copia)]
			l.font_size = 40
			l.outline_size = 10
			l.pixel_size = 0.009
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.position = cont.position + Vector3(0.0, (2.5 if uniforme else maxf(alto, 0.4) + 0.35), 0.0)
			_raiz.add_child(l)
			i += 1
		lib.free()
	var filas: int = int(ceil(float(i) / float(POR_FILA)))
	_centro = Vector3(float(POR_FILA - 1) * HUECO * 0.5, 1.0, float(filas - 1) * HUECO * 1.1 * 0.5)
	_tam = float(filas) * HUECO * 1.1 + 3.0
	_hud.text = "CATÁLOGO · %d piezas %s\n1 piezas · 2 personajes · Q/E girar · R/F inclinación · +/- zoom · flechas · L luz" % [i, " ".join(avisos)]


## Las piezas son los hijos de la raíz de la biblioteca (o del primer nivel que tenga varios).
func _piezas_de(lib: Node3D) -> Array[Node3D]:
	var n: Node = lib
	while n.get_child_count() == 1 and not (n.get_child(0) is MeshInstance3D):
		n = n.get_child(0)
	var res: Array[Node3D] = []
	for h in n.get_children():
		if h is Node3D:
			res.append(h as Node3D)
	return res


func _montar_personajes() -> void:
	var x: float = 0.0
	for id in PERSONAJES:
		if not ResourceLoader.exists("res://poc_25d/%s.glb" % Pj3D.glb_de(String(id))):
			continue
		var pj := Pj3D.new()
		pj.position = Vector3(x, 0.0, 0.0)
		_raiz.add_child(pj)
		pj.cargar(String(id))
		pj.set_alto(1.0)
		pj.rotation_degrees.y = giro
		var l := Label3D.new()
		l.text = String(id)
		l.font_size = 40
		l.outline_size = 10
		l.pixel_size = 0.0015
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(x, 1.12, 0.0)
		_raiz.add_child(l)
		# Rayas cada 1/6 del alto para medir cabezas.
		for k in range(7):
			var raya := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.9, 0.004, 0.004)
			raya.mesh = b
			raya.position = Vector3(x, float(k) / 6.0, -0.45)
			_raiz.add_child(raya)
		x += 1.3
	_centro = Vector3(x * 0.5 - 0.65, 0.55, 0.0)
	_tam = maxf(1.6, x / 1.7)
	_hud.text = "PERSONAJES a la misma altura (rayas cada 1/6)\n1 piezas · 2 personajes · Q/E girar · R/F inclinación · +/- zoom · 3/4 cabeza · 5/6 piernas · 7/8 torso · 0 original/ajustada · A animación"
	_texto_proporciones()


func _triangulos(n: Node) -> int:
	var t: int = 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		for s in range(m.get_surface_count()):
			var arr: Array = m.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).size() > 0:
				t += floori((idx as PackedInt32Array).size() / 3.0)
			else:
				t += floori((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
	for h in n.get_children():
		t += _triangulos(h)
	return t


func _caja(n: Node, acum: Transform3D) -> AABB:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	var res := AABB()
	var vacia: bool = true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		res = t * (n as MeshInstance3D).mesh.get_aabb()
		vacia = false
	for h in n.get_children():
		var sub: AABB = _caja(h, t)
		if sub.size != Vector3.ZERO:
			res = sub if vacia else res.merge(sub)
			vacia = false
	return res


## Las mismas medidas que la maqueta, para ver las piezas tal como salen allí.
func _medidas_maqueta() -> Dictionary:
	var s: Script = load("res://poc_25d/prueba_test2.gd") as Script
	if s != null and s.get_script_constant_map().has("MEDIDA"):
		return s.get_script_constant_map()["MEDIDA"]
	return {}


func _medidas_ancho() -> Dictionary:
	var s: Script = load("res://poc_25d/prueba_test2.gd") as Script
	if s != null and s.get_script_constant_map().has("MEDIDA_ANCHO"):
		return s.get_script_constant_map()["MEDIDA_ANCHO"]
	return {}


func _colocar_camara() -> void:
	_camara.size = _tam
	var e: float = deg_to_rad(inclinacion)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	_camara.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _centro - dir * 60.0)


func _process(delta: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		v.z += 1.0
	if v != Vector3.ZERO:
		_centro += v * delta * _tam * 0.6
		_colocar_camara()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not (ev as InputEventKey).pressed:
		return
	match (ev as InputEventKey).keycode:
		KEY_1:
			modo = 0
			_montar()
		KEY_2:
			modo = 1
			_montar()
		KEY_Q, KEY_E:
			giro += 30.0 if (ev as InputEventKey).keycode == KEY_E else -30.0
			for h in _raiz.get_children():
				if h is Pj3D or (h is Node3D and not (h is Label3D) and not (h is MeshInstance3D)):
					(h as Node3D).rotation_degrees.y = giro
		KEY_R:
			inclinacion = clampf(inclinacion + 5.0, 0.0, 90.0)
			_colocar_camara()
		KEY_F:
			inclinacion = clampf(inclinacion - 5.0, 0.0, 90.0)
			_colocar_camara()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_tam *= 0.85
			_colocar_camara()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_tam /= 0.85
			_colocar_camara()
		KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			var k: int = (ev as InputEventKey).keycode
			var d: float = 0.03 if k == KEY_4 or k == KEY_6 or k == KEY_8 else -0.03
			for h in _raiz.get_children():
				if h is Pj3D and (h as Pj3D).proporcion != null:
					var pr: ProporcionChibi = (h as Pj3D).proporcion
					var c: float = pr.cabeza + (d if k == KEY_3 or k == KEY_4 else 0.0)
					var pi: float = pr.piernas + (d if k == KEY_5 or k == KEY_6 else 0.0)
					var t: float = pr.torso + (d if k == KEY_7 or k == KEY_8 else 0.0)
					(h as Pj3D).set_proporcion(c, pi, t)
			_texto_proporciones()
		KEY_0:
			_originales = not _originales
			for h in _raiz.get_children():
				if h is Pj3D and (h as Pj3D).proporcion != null:
					var pj: Pj3D = h as Pj3D
					var p: Array = [1.0, 1.0, 1.0] if _originales else Pj3D.PROPORCIONES.get(pj.id, [1.0, 1.0, 1.0])
					pj.set_proporcion(float(p[0]), float(p[1]), float(p[2]))
			_texto_proporciones()
		KEY_A:
			_anim += 1
			for h in _raiz.get_children():
				if h is Pj3D:
					var lista: Array = ["idle", "walk", "run"]
					(h as Pj3D).jugar(String(lista[_anim % lista.size()]))
		KEY_L:
			_luz_suave = not _luz_suave
			for h in _raiz.get_children():
				if h is Pj3D:
					(h as Pj3D).set_modo_luz(1 if _luz_suave else 0)
