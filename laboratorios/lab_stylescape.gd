extends Node3D

## LABORATORIO de PRUEBA del pack «Stylescape: Ruins» (Fab, Unreal → Godot, 25/11/2026).
## DOS SALAS IDÉNTICAS montadas con piezas del pack sobre hierba (25/11: Pablo pidió compararlas lado a lado), cada una con su material
## (por defecto la A con el 3 anterior —modo 5— y la B con el 3 nuevo), con la luz del Bosque y la jugadora (1 u) dentro. A la derecha, nuestras piezas
## (muro en ruina, muro agrietado, roca musgosa, árboles) para comparar. Detrás, el muestrario con TODAS las piezas (va con la sala A).
## Teclas:  T material de la sala A · Y material de la sala B · L luz (bosque / ruinas / clásico) · flechas/WASD mover · rueda o +/- zoom
##          1 las dos salas · 2 el muestrario · 3 nuestras piezas · N nombres sí/no
## Modos de material:  1) el pack tal cual  2) el pack con su musgo arriba  3) teñido con el beige de nuestros muros  4) paleta casi plana
##                     5) el 3 anterior (gris lila de Paleta3D)
## Si no hay piezas: exportarlas desde Unreal (tools/ue_exportar_stylescape.py) y prepararlas (tools/preparar_stylescape.py); no viajan en git.
## Captura sin tocar nada:  Godot --path . res://laboratorios/LabStylescape.tscn -- --captura   (deja PNG en docs/capturas/stylescape/)

const MALLAS: String = "res://arte/stylescape/mallas/"
const TEX: String = "res://arte/stylescape/texturas/"
const ESCALA: float = 0.575        ## u por metro de Unreal: un módulo de 4 m = 2,3 u = una casilla; el muro de 3 m sale de 1,7 u (jugadora 1 u)
const HUECO: float = 0.8
const ANCHO_FILA: float = 40.0

## Material de Unreal -> texturas (Diffuse, Normal, AO/Rugosidad/Especular) y tipo (para el color de la paleta).
const RECETAS: Dictionary = {
	"MI_Walls": ["T_WallTrim_NoMoss_D", "T_WallTrim_NoMoss_N", "T_WallTrim_NoMoss_AORS", "piedra"],
	"MI_Floors": ["T_WallTrim_NoMoss_D", "T_WallTrim_NoMoss_N", "T_WallTrim_NoMoss_AORS", "losa"],
	"MI_Walls_Dmg": ["T_WallTrim_Dmg_D", "T_WallTrim_Dmg_N", "T_WallTrim_Dmg_AORM", "piedra"],
	"MI_Stones": ["T_StoneRuins_D", "T_StoneRuins_N", "T_StoneRuins_AORM", "piedra"],
	"MI_Stairs": ["T_StoneRuins_D", "T_StoneRuins_N", "T_StoneRuins_AORM", "losa"],
	"MI_Wall_Wood": ["T_Wood_D", "T_Wood_N", "T_Wood_AORM", "madera"],
	"MI_Ivy_Leaf": ["T_IvyLeaves_D", "", "", "hiedra"],
	"MI_Ivy_Vine_01": ["T_IvyBranch_01_D", "", "", "hiedra"],
	"MI_Ivy_Vine_02": ["T_IvyBranch_02_D", "", "", "hiedra"],
}
## Colores de la paleta del juego (Paleta3D) por tipo, para los modos 3 y 4.
var COLOR_TIPO: Dictionary = {
	"piedra": Paleta3D.PIEDRA, "losa": Paleta3D.PIEDRA.lerp(Paleta3D.PIEDRA_OSCURA, 0.25), "madera": Paleta3D.MADERA, "hiedra": Paleta3D.HIERBA_SOMBRA,
}
## 25/11 (Pablo: «el 3 como está no me convence»): el 3 ahora tiñe con el BEIGE de nuestros muros de Meshy y el musgo lleva textura.
## Medido de las texturas de arte/meshy/piezas/muro_ruina.glb y muro_agrietado.glb (piedra sin los píxeles verdes: media de los dos)
## y del verde de roca_musgosa.glb (solo sus píxeles verdes). El gris lila de Paleta3D.PIEDRA queda en el modo 5 («3 anterior»).
## Calibrado en pantalla (25/11): con el beige medido tal cual (0,49·0,43·0,32) el frente de la sala salía 0,41·0,37·0,24 y nuestro muro
## 0,60·0,53·0,42 (el claroscuro y la oclusión del pack oscurecen); se multiplicó canal a canal por esa diferencia.
const PIEDRA_MUROS: Color = Color(0.715, 0.62, 0.555)
const PIEDRA_MUROS_OSCURA: Color = Color(0.61, 0.555, 0.43)
const MUSGO_ROCA: Color = Color(0.50, 0.575, 0.32)
const MUSGO_ESCALA_BEIGE: float = 2.0   ## repeticiones de la textura de musgo por u en el modo 3 (más alto = grano más fino)
var COLOR_TIPO_BEIGE: Dictionary = {
	"piedra": PIEDRA_MUROS, "losa": PIEDRA_MUROS.lerp(PIEDRA_MUROS_OSCURA, 0.3), "madera": Paleta3D.MADERA, "hiedra": Paleta3D.HIERBA_SOMBRA,
}
## [nombre, mezcla_textura, detalle, musgo, musgo_textura, fuerza_normal, cobertura del musgo, paleta («lila» o «beige»), musgo_detalle]
## 25/11: en 3, 4 y 5 el musgo va a manchas (cobertura 0,4) para que la cara de arriba de los muros siga siendo piedra y no se funda con la hierba.
const MODOS: Array = [
	["1 · pack tal cual", 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, "lila", 0.0],
	["2 · pack con su musgo arriba", 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, "lila", 0.0],
	["3 · teñido con el beige de nuestros muros, musgo con textura", 0.0, 0.75, 1.0, 0.0, 0.7, 0.4, "beige", 1.0],
	["4 · paleta casi plana", 0.0, 0.2, 1.0, 0.0, 0.3, 0.4, "lila", 0.0],
	["5 · el 3 anterior (gris lila, musgo liso)", 0.0, 0.75, 1.0, 0.0, 0.7, 0.4, "lila", 0.0],
]
const LUCES: Array = ["bosque", "ruinas", "clasico"]
## Cuánto musgo lleva cada tipo en los modos con musgo (las losas del suelo y las cajas, nada: se confundían con la hierba).
const MUSGO_TIPO: Dictionary = {"piedra": 1.0, "losa": 0.0, "madera": 0.0, "hiedra": 0.0}
## Color del musgo con la paleta: el verde de sombra de la hierba OSCURECIDO, para que se distinga del suelo (con el verde tal cual desaparecía).
const MUSGO_OSCURECER: float = 0.35

## La ruina, en METROS de Unreal: [malla, esquina mínima (x, y, z), largo a lo largo de X (true) o de Z (false)]
const RUINA: Array = [
	["SM_Floor_6x4_01", Vector3(0, 0, 0), true],
	["SM_Floor_4x4_01_Dmg", Vector3(6, 0, 0), true],
	["SM_Wall_01_Corner", Vector3(-0.5, 0, -0.5), true],
	["SM_Wall_04", Vector3(0, 0, -0.5), true],
	["SM_Wall_Windows_01", Vector3(4, 0, -0.5), true],
	["SM_Wall_Dmg_02_Half_01", Vector3(8, 0, -0.5), true],
	["SM_Wall_Dmg_04", Vector3(-0.5, 0, 0), false],
	["SM_Wall_Dmg_01_Half_01", Vector3(-0.5, 0, 4), false],
	["SM_Wall_Arch_01", Vector3(10, 0, 0), false],
	["SM_Wall_LedgeDetail_04", Vector3(0, 2.72, -0.08), true],
	["SM_Pillar_04", Vector3(1.0, 0.1, 4.6), true],
	["SM_Pillar_01_Dmg", Vector3(7.5, 0, 4.8), true],
	["SM_Stairs_Half", Vector3(3.3, 0, 4.0), true],
	["SM_Rubble_01", Vector3(8.6, 0.1, 2.2), true],
	["SM_Rubble_02", Vector3(0.6, 0.1, 2.6), true],
	["SM_Stone_01", Vector3(5.6, 0.1, 1.4), true],
	["SM_Stone_02", Vector3(9.0, 0, 6.6), true],
	["SM_Stone_03", Vector3(-1.4, 0, 5.8), true],
	["SM_Crate_01", Vector3(6.3, 0.1, 0.4), true],
	["SM_Crate_01", Vector3(2.4, 0.1, 0.3), true],
	["SM_HangingIvy_05", Vector3(0.6, 1.2, 0.02), true],
	["SM_HangingIvy_02", Vector3(4.6, 1.0, 0.02), true],
	["SM_HangingIvy_04", Vector3(-0.1, 1.5, 1.2), false],
]
## Nuestras piezas para comparar: [escena, posición en u, escala]. Los muros y la roca, a la derecha de la sala B; el árbol, a la izquierda de la A.
const NUESTRAS: Array = [
	["res://arte/piezas/muro_ruina.tscn", Vector3(17.4, 0, 0.6), 1.0],
	["res://arte/piezas/muro_agrietado.tscn", Vector3(19.6, 0, 0.6), 1.0],
	["res://arte/piezas/roca_musgosa.tscn", Vector3(17.8, 0, 3.0), 1.0],
	["res://arte/piezas/arbol_redondo.tscn", Vector3(-1.8, 0, -1.2), 0.9],
	["res://arte/piezas/pino.tscn", Vector3(21.6, 0, -0.6), 1.0],
]
## Las dos salas: posición en u de cada una y su modo de material al abrir (índices de MODOS: 2 = modo 3, 4 = modo 5).
const SALAS: Array = [Vector3(0, 0, 0), Vector3(9.0, 0, 0)]
const MODOS_INICIALES: Array = [4, 2]   ## A: el 3 anterior · B: el 3 nuevo
const FOCO_RUINA: Vector3 = Vector3(7.6, 0, 0.0)
const ZOOM_RUINA: float = 10.5
const FOCO_NUESTRAS: Vector3 = Vector3(18.5, 0, 1.6)

var _cam: Camera3D
var _foco: Vector3 = FOCO_RUINA
var _zoom: float = ZOOM_RUINA
var _sol: DirectionalLight3D
var _entorno: Environment
var _modos: Array = MODOS_INICIALES.duplicate()     ## modo de cada sala (el muestrario va con la sala A)
var _luz: int = 0
var _materiales: Array[ShaderMaterial] = []
var _tipos: Array[String] = []
var _grupos: Array[int] = []                       ## a qué sala pertenece cada material
var _grupo_actual: int = 0
var _rotulos_sala: Array[Label3D] = []
var _rotulos: Array[Label3D] = []
var _hud: Label
var _escenas: Dictionary = {}
var _z_muestrario: float = -12.0


func _ready() -> void:
	_montar_luz()
	if not DirAccess.dir_exists_absolute(MALLAS):
		push_warning("LabStylescape: no hay mallas en %s (ver la cabecera del script)" % MALLAS)
	else:
		for i in range(SALAS.size()):
			_grupo_actual = i
			_montar_ruina(SALAS[i], i)
		_grupo_actual = 0
		_montar_nuestras()
		_montar_muestrario()
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.far = 600.0
	_cam.current = true
	add_child(_cam)
	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 18)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	var capa := CanvasLayer.new()
	add_child(capa)
	capa.add_child(_hud)
	_aplicar_modo()
	_actualizar_hud()
	if OS.get_cmdline_user_args().has("--captura"):
		_capturar()


func _montar_luz() -> void:
	var e := WorldEnvironment.new()
	_entorno = Environment.new()
	_entorno.background_mode = Environment.BG_COLOR
	_entorno.background_color = Color(0.80, 0.86, 0.90)
	_entorno.glow_enabled = true
	Paleta3D.aplicar_ajuste(_entorno)
	e.environment = _entorno
	add_child(e)
	_sol = DirectionalLight3D.new()
	_sol.shadow_enabled = true
	add_child(_sol)
	LuzZona3D.aplicar(_entorno, _sol, LUCES[_luz])
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(300, 300)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Paleta3D.HIERBA
	sm.roughness = 1.0
	suelo.material_override = sm
	suelo.position = Vector3(0, -0.01, -40)
	add_child(suelo)


func _cargar(nombre: String) -> Node3D:
	if not _escenas.has(nombre):
		_escenas[nombre] = load(MALLAS + nombre + ".fbx")
	var ps: PackedScene = _escenas[nombre]
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	_vestir(n)
	return n


## Cambia cada superficie por el material de prueba según el nombre del material de Unreal que trae el FBX.
func _vestir(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in range(m.mesh.get_surface_count()):
			var orig: Material = m.mesh.surface_get_material(s)
			var nombre: String = orig.resource_name if orig != null else ""
			if not RECETAS.has(nombre):
				continue
			var r: Array = RECETAS[nombre]
			var sm := ShaderMaterial.new()
			sm.shader = preload("res://laboratorios/ruina_stylescape.gdshader")
			sm.set_shader_parameter("tex_albedo", load(TEX + r[0] + ".png"))
			if r[1] != "":
				sm.set_shader_parameter("tex_normal", load(TEX + r[1] + ".png"))
				sm.set_shader_parameter("tex_orm", load(TEX + r[2] + ".png"))
			else:
				sm.set_shader_parameter("usa_orm", 0.0)
				sm.set_shader_parameter("recorte", 0.4)
			sm.set_shader_parameter("tex_musgo", load(TEX + "T_RockyMoss_D.png"))
			m.set_surface_override_material(s, sm)
			_materiales.append(sm)
			_tipos.append(String(r[3]))
			_grupos.append(_grupo_actual)


## Pone la pieza con su caja empezando en `esquina` (metros), girada para que lo largo vaya por X o por Z. Devuelve la caja en metros.
func _poner(padre: Node3D, nombre: String, esquina: Vector3, largo_x: bool) -> AABB:
	var n: Node3D = _cargar(nombre)
	if n == null:
		return AABB()
	padre.add_child(n)
	var caja: AABB = _caja(n, Transform3D())
	if (caja.size.x >= caja.size.z) != largo_x:
		n.rotation_degrees.y = 90.0
		caja = _caja(n, Transform3D(Basis(Vector3.UP, deg_to_rad(90.0))))
	n.position = esquina - caja.position
	return AABB(esquina, caja.size)


func _caja(n: Node3D, giro: Transform3D) -> AABB:
	var total := AABB()
	var primera: bool = true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		var t: Transform3D = Transform3D()
		var p: Node = m
		while p != null and p != n:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		var c: AABB = giro * t * m.mesh.get_aabb()
		total = c if primera else total.merge(c)
		primera = false
	return total


func _montar_ruina(origen: Vector3, sala: int) -> void:
	var raiz := Node3D.new()
	raiz.name = "sala_%s" % ["A", "B"][sala]
	raiz.scale = Vector3.ONE * ESCALA
	raiz.position = origen
	add_child(raiz)
	for p in RUINA:
		_poner(raiz, p[0], p[1], p[2])
	_jugadora(origen + Vector3(3.0, 0.11, 2.4) * ESCALA)
	var r := Label3D.new()
	r.font_size = 40
	r.pixel_size = 0.01
	r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	r.no_depth_test = true
	r.outline_size = 10
	r.position = origen + Vector3(3.3, 3.2, 0.0)
	add_child(r)
	_rotulos.append(r)
	_rotulos_sala.append(r)


func _montar_nuestras() -> void:
	for p in NUESTRAS:
		var ps: PackedScene = load(p[0])
		if ps == null:
			continue
		var n: Node3D = ps.instantiate() as Node3D
		add_child(n)
		n.position = p[1]
		n.scale = Vector3.ONE * float(p[2])
	_rotulo_libre("nuestras piezas", Vector3(18.5, 3.0, 0.6))


func _montar_muestrario() -> void:
	var ficheros: PackedStringArray = DirAccess.get_files_at(MALLAS)
	var x: float = 0.0
	var z: float = _z_muestrario
	var fondo: float = 0.0
	for f in ficheros:
		if not f.ends_with(".fbx"):
			continue
		var nombre: String = f.get_basename()
		var raiz := Node3D.new()
		raiz.scale = Vector3.ONE * ESCALA
		add_child(raiz)
		var caja_m: AABB = _poner(raiz, nombre, Vector3.ZERO, true)
		var caja: Vector3 = caja_m.size * ESCALA
		if x > 0.0 and x + caja.x > ANCHO_FILA:
			z -= fondo + 2.0
			x = 0.0
			fondo = 0.0
		raiz.position = Vector3(x, 0.0, z - caja.z)
		var r := Label3D.new()
		r.text = nombre.trim_prefix("SM_")
		r.font_size = 28
		r.pixel_size = 0.008
		r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		r.no_depth_test = true
		r.outline_size = 8
		r.position = Vector3(x + caja.x * 0.5, caja.y + 0.3, z - caja.z * 0.5)
		add_child(r)
		_rotulos.append(r)
		x += caja.x + HUECO
		fondo = maxf(fondo, caja.z)


func _rotulo_libre(texto: String, pos: Vector3) -> void:
	var r := Label3D.new()
	r.text = texto
	r.font_size = 40
	r.pixel_size = 0.01
	r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	r.no_depth_test = true
	r.outline_size = 10
	r.position = pos
	add_child(r)
	_rotulos.append(r)


func _jugadora(pos: Vector3) -> void:
	var j := Pj3D.new()
	add_child(j)
	j.cargar("jugadora_base")
	j.set_alto(1.0)
	j.position = pos


func _aplicar_modo() -> void:
	for i in range(_rotulos_sala.size()):
		_rotulos_sala[i].text = "%s · %s" % [["A", "B"][i], String(MODOS[_modos[i]][0]).get_slice(",", 0).get_slice(" (", 0)]
	for i in range(_materiales.size()):
		var m: Array = MODOS[_modos[_grupos[i]]]
		var sm: ShaderMaterial = _materiales[i]
		var tipo: String = _tipos[i]
		sm.set_shader_parameter("mezcla_textura", m[1])
		sm.set_shader_parameter("detalle", m[2])
		sm.set_shader_parameter("musgo", float(m[3]) * float(MUSGO_TIPO[tipo]))
		sm.set_shader_parameter("musgo_textura", m[4])
		var beige: bool = m[7] == "beige"
		sm.set_shader_parameter("color_musgo", MUSGO_ROCA if beige else Paleta3D.HIERBA_SOMBRA.darkened(MUSGO_OSCURECER))
		sm.set_shader_parameter("musgo_detalle", m[8])
		sm.set_shader_parameter("musgo_escala", MUSGO_ESCALA_BEIGE if beige else 0.5)
		sm.set_shader_parameter("musgo_cobertura", m[6])
		sm.set_shader_parameter("fuerza_normal", m[5])
		sm.set_shader_parameter("color_piedra", Color.WHITE if float(m[1]) > 0.5 else (COLOR_TIPO_BEIGE[tipo] if beige else COLOR_TIPO[tipo]))


func _process(delta: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		v.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		v.z -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		v.z += 1
	_foco += v * delta * _zoom * 0.9
	_colocar_camara()


func _colocar_camara() -> void:
	_cam.size = _zoom
	var e: float = deg_to_rad(30.0)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _foco - dir * 200.0)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(3.0, _zoom * 0.88)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(120.0, _zoom * 1.14)
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
				_zoom = maxf(3.0, _zoom * 0.8)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom = minf(120.0, _zoom * 1.25)
			KEY_T:
				_modos[0] = (int(_modos[0]) + 1) % MODOS.size()
				_aplicar_modo()
			KEY_Y:
				_modos[1] = (int(_modos[1]) + 1) % MODOS.size()
				_aplicar_modo()
			KEY_L:
				_luz = (_luz + 1) % LUCES.size()
				LuzZona3D.aplicar(_entorno, _sol, LUCES[_luz])
			KEY_1:
				_foco = FOCO_RUINA
				_zoom = ZOOM_RUINA
			KEY_2:
				_foco = Vector3(ANCHO_FILA * 0.5, 0, _z_muestrario - 4.0)
				_zoom = 30.0
			KEY_3:
				_foco = FOCO_NUESTRAS
				_zoom = 9.5
			KEY_N:
				for r in _rotulos:
					r.visible = not r.visible
		_actualizar_hud()


func _actualizar_hud() -> void:
	_hud.text = "Stylescape: Ruins (prueba) · sala A: %s · sala B: %s · luz: %s\nT material A · Y material B · L luz · 1 salas · 2 muestrario · 3 nuestras · N nombres · WASD/flechas · rueda zoom" % [
		MODOS[_modos[0]][0], MODOS[_modos[1]][0], LUCES[_luz]]


## Capturas en docs/capturas/stylescape/: las dos salas como abren (A el 3 anterior, B el 3 nuevo), cada modo en las dos salas y el muestrario; y sale.
func _capturar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/capturas/stylescape"))
	await _foto(FOCO_RUINA, ZOOM_RUINA, "salas_A3anterior_B3nuevo.png")
	for i in range(MODOS.size()):
		_modos = [i, i]
		await _foto(SALAS[0] + Vector3(3.4, 0, 1.6), 9.0, "ruina_modo%d.png" % (i + 1))
	_modos = MODOS_INICIALES.duplicate()
	await _foto(Vector3(ANCHO_FILA * 0.5, 0, _z_muestrario - 4.0), 30.0, "muestrario.png")
	get_tree().quit()


func _foto(foco: Vector3, zoom: float, archivo: String) -> void:
	_aplicar_modo()
	_actualizar_hud()
	_foco = foco
	_zoom = zoom
	_colocar_camara()
	for k in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/capturas/stylescape/" + archivo)
