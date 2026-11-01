extends Node3D

## LABORATORIO DE LA COMPARATIVA DE VFX (1/11, Dirección, docs/COMPARATIVA_VFX_GODOT_UNREAL_2026-11-01.md §1.4). El mapa mínimo de la prueba A:
## un plano de 20×20 m, cuatro cubos, la jugadora montada como el juego (Pj3D.cargar + set_alto, con su clip de andar) y los tres efectos de
## presentacion/vfx/efectos instanciados DIRECTAMENTE (sin pasar por el sistema de hechizos: aquí se juzga el aspecto, no la integración).
## Teclas:  1 bola de fuego · 2 muro de fuego · 3 columna de fuego · 0 diez muros a la vez (medida de fps) · X limpia ·
##          C cámara (juego → cerca 2 m → lejos 10 m) · flechas / WASD andar · H oculta el panel.
## Prueba 2 (fuego toon, docs/PRUEBA2_VFX_TOON_2026-11-01.md): 5 muro de fuego toon · 6 columna toon · 7 bola toon · 9 diez muros toon · RePág / AvPág eligen uno de los diez mandos · + / − lo suben y bajan ·
##          Retroceso lo devuelve a su valor de origen · el panel enseña los diez con su valor (el elegido va con «>»). Valen para los muros toon que nazcan después y para el vivo.
## El panel muestra fps, luces y partículas vivas (el mismo recuento que LabVfx3D._luces_y_particulas) y las teclas.
## Abrir: laboratorios/LabVfxComparativa3D.tscn y F6. Capturas: herramientas/captura_vfx_comparativa.gd.

const ESCENA_BOLA: String = "res://presentacion/vfx/efectos/BolaFuego.tscn"
const ESCENA_MURO: String = "res://presentacion/vfx/efectos/MuroFuego.tscn"
const ESCENA_COLUMNA: String = "res://presentacion/vfx/efectos/ColumnaFuego.tscn"
const ESCENA_MURO_TOON: String = "res://presentacion/vfx/toon/MuroFuegoToon.tscn"
const ESCENA_COLUMNA_TOON: String = "res://presentacion/vfx/toon/ColumnaFuegoToon.tscn"
const ESCENA_BOLA_TOON: String = "res://presentacion/vfx/toon/BolaFuegoToon.tscn"
const RAMPAS_TOON: PackedStringArray = ["res://presentacion/vfx/toon/rampa_fuego_5.tres", "res://presentacion/vfx/toon/rampa_azul_5.tres"]
## Los diez mandos del fuego toon: [nombre del parámetro en fuego_toon.gdshader, mínimo, máximo, paso, valor de origen]. «rampa» no es un número: + / − cambian de rampa (fuego, azul).
const MANDOS_TOON: Array = [
	["fps", 2.0, 60.0, 2.0, 12.0], ["umbral", 0.0, 0.7, 0.02, 0.3], ["altura_llama", 0.2, 1.5, 0.05, 1.0], ["desplazamiento", 0.0, 1.0, 0.05, 0.5],
	["contorno", 0.0, 1.0, 0.1, 0.0], ["rampa", 0.0, 1.0, 1.0, 0.0], ["velocidad", 0.1, 6.0, 0.2, 1.4], ["escala_ruido", 2.0, 24.0, 1.0, 9.0],
	["brillo", 0.2, 3.0, 0.05, 0.86], ["erosion", 0.0, 1.0, 0.1, 0.0]]
## Prueba 3 (fuego «toy», docs/PRUEBA3_VFX_TOY_2026-11-01.md): F1 bola estática · F2 muro · F3 pilar · F4 bola en vuelo con impacto · F5 barrera · F6 diez muros toy ·
##          los mismos RePág / AvPág / + / − / Retroceso mueven los DIEZ mandos del raíz (EfectoToy) de lo que haya vivo; el panel los muestra en castellano.
const ESCENA_TOY: Dictionary = {"bola_toy": "res://presentacion/vfx/toy/BolaFuegoToy.tscn", "bola_vuelo_toy": "res://presentacion/vfx/toy/BolaFuegoToy.tscn",
	"muro_toy": "res://presentacion/vfx/toy/MuroFuegoToy.tscn", "pilar_toy": "res://presentacion/vfx/toy/PilarFuegoToy.tscn", "barrera_toy": "res://presentacion/vfx/toy/BarreraFuegoToy.tscn"}
## [propiedad de EfectoToy, mínimo, máximo, paso, valor de origen]
const MANDOS_TOY: Array = [
	["altura", 0.3, 3.0, 0.1, 1.0], ["chisporroteo", 0.0, 1.0, 0.1, 0.6], ["blandura", 0.05, 1.0, 0.05, 0.22], ["ondulacion", 0.0, 1.5, 0.1, 0.6], ["velocidad", 0.1, 4.0, 0.1, 1.0],
	["brillo", 0.3, 3.0, 0.1, 1.0], ["halo", 0.0, 3.0, 0.1, 1.0], ["tono", 0.0, 1.0, 0.1, 0.0], ["chispas", 0.0, 1.0, 0.1, 1.0], ["luz", 0.0, 4.0, 0.1, 1.0]]
const CAMARA_TOY: Dictionary = {"Barrera": [1.9, 0.9], "Pilar": [2.1, 1.7], "Muro": [1.15, 0.7]}   ## [factor de distancia, altura a la que mira]
const ID_JUGADORA: String = "jugadora_base"
const ALTO_JUEGO: float = 1.0
const LADO_MAPA: float = 20.0
const VEL_ANDAR: float = 3.0                       ## m/s
const VEL_BOLA: float = 8.0                        ## m/s (COMPARATIVA §0)
const ALCANCE_BOLA: float = 6.0                    ## m que vuela antes de caer al suelo
const ALTURA_MANO: float = 0.7
const DISTANCIA_EFECTO: float = 3.0                ## m delante de la jugadora donde nacen muro y columna
const VIDA_MURO: float = 4.8                       ## nacer 0,3 + vivir 4 + morir 0,5
const VIDA_COLUMNA: float = 4.8
const DIEZ_MUROS: int = 10
const TAM_CAMARA_JUEGO: float = 6.0                ## PruebaTest2.ZOOM_INICIAL
const ELEVACION_JUEGO: float = 30.0                ## 90° − inclinación 60° de PruebaTest2
const CAMARAS: PackedStringArray = ["juego", "cerca", "lejos"]
const DIST_CERCA: float = 2.0
const DIST_LEJOS: float = 10.0
const CUBOS: Array = [Vector3(4, 0.6, 3), Vector3(-5, 0.6, -2), Vector3(2, 0.6, -6), Vector3(-3, 0.6, 6)]

var camara_actual: int = 0
var ultimo_efecto: Node3D = null                   ## al que miran las cámaras cerca / lejos
var _pj: Pj3D = null
var _dir: Vector3 = Vector3(0, 0, -1)
var _cam: Camera3D = null
var _panel: Label = null
var _panel_visible: bool = true
var _efectos: Node3D = null
var _bolas: Array = []                             ## [{nodo, origen}]
var _mando_toon: int = 0                           ## el mando elegido con RePág / AvPág
var _valores_toon: Dictionary = {}
var _toy: bool = false                             ## true: los mandos son los de EfectoToy (prueba 3)
var _valores_toy: Dictionary = {}                  ## propiedad -> valor actual (lo que nazca después nace con él)


func _ready() -> void:
	_montar_mapa()
	_montar_jugadora()
	_efectos = Node3D.new()
	_efectos.name = "Efectos"
	add_child(_efectos)
	_cam = Camera3D.new()
	_cam.name = "Camara"
	add_child(_cam)
	_montar_panel()
	poner_camara(0)


func _montar_mapa() -> void:
	var suelo: MeshInstance3D = MeshInstance3D.new()
	suelo.name = "Suelo"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(LADO_MAPA, LADO_MAPA)
	suelo.mesh = pm
	var ms: StandardMaterial3D = StandardMaterial3D.new()
	ms.albedo_color = Color(0.42, 0.44, 0.4)
	ms.roughness = 0.9
	suelo.material_override = ms
	add_child(suelo)
	var mc: StandardMaterial3D = StandardMaterial3D.new()
	mc.albedo_color = Color(0.5, 0.42, 0.34)
	for i in CUBOS.size():
		var c: MeshInstance3D = MeshInstance3D.new()
		c.name = "Cubo%d" % i
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(1.2, 1.2, 1.2)
		c.mesh = bm
		c.material_override = mc
		c.position = CUBOS[i]
		add_child(c)
	var sol: DirectionalLight3D = DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.light_energy = 1.0
	sol.shadow_enabled = true
	add_child(sol)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "Ambiente"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.3
	we.environment = env
	add_child(we)


## La jugadora como el juego (igual que LabJugadora3D._montar_jugadora): si no está el modelo, una cápsula.
func _montar_jugadora() -> void:
	_pj = Pj3D.new()
	_pj.name = "Jugadora"
	add_child(_pj)
	if not _pj.cargar(ID_JUGADORA):
		var cap: MeshInstance3D = MeshInstance3D.new()
		var cm: CapsuleMesh = CapsuleMesh.new()
		cm.radius = 0.25
		cm.height = 1.0
		cap.mesh = cm
		cap.position = Vector3(0, 0.5, 0)
		_pj.add_child(cap)
		return
	_pj.set_alto(ALTO_JUEGO)
	if _pj._arbol != null:
		_pj._arbol.active = false
	if _pj._ap != null:
		_pj._ap.active = true
		_clip("idle")


func _clip(rol: String) -> void:
	if _pj == null or _pj._ap == null:
		return
	var c: String = _pj.clip_de(rol)
	if c != "" and _pj._ap.current_animation != c:
		_pj._ap.play(c)


func _montar_panel() -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	capa.name = "Panel"
	add_child(capa)
	_panel = Label.new()
	_panel.position = Vector2(12, 10)
	_panel.add_theme_font_size_override("font_size", 15)
	_panel.add_theme_color_override("font_color", Color(1, 1, 1))
	_panel.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_panel.add_theme_constant_override("outline_size", 4)
	capa.add_child(_panel)


func _process(delta: float) -> void:
	_andar(delta)
	_mover_bolas(delta)
	_seguir_camara()
	if _panel != null:
		var lp: Array = luces_y_particulas()
		_panel.text = ("fps %d · luces %d · partículas %d · efectos %d · cámara %s\n1 bola · 2 muro · 3 columna · 5 muro toon · 6 columna toon · 7 bola toon · 0 diez muros · 9 diez toon · X limpia · C cámara · flechas andar · H panel\n%s"
			% [int(Engine.get_frames_per_second()), lp[0], lp[1], _efectos.get_child_count(), CAMARAS[camara_actual], _texto_mandos_toon()]) if _panel_visible else ""


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.is_pressed() or ev.is_echo():
		return
	match (ev as InputEventKey).keycode:
		KEY_1: efecto("bola")
		KEY_2: efecto("muro")
		KEY_3: efecto("columna")
		KEY_5: _toy = false; efecto("muro_toon")
		KEY_6: _toy = false; efecto("columna_toon")
		KEY_7: _toy = false; efecto("bola_toon")
		KEY_F1: _toy = true; efecto("bola_toy")
		KEY_F2: _toy = true; efecto("muro_toy")
		KEY_F3: _toy = true; efecto("pilar_toy")
		KEY_F4: _toy = true; efecto("bola_vuelo_toy")
		KEY_F5: _toy = true; efecto("barrera_toy")
		KEY_F6: _toy = true; diez_muros(false, true)
		KEY_PAGEUP: _mando_toon = (_mando_toon + _n_mandos() - 1) % _n_mandos()
		KEY_PAGEDOWN: _mando_toon = (_mando_toon + 1) % _n_mandos()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: mover_mando_toon(_mando_toon, 1)
		KEY_MINUS, KEY_KP_SUBTRACT: mover_mando_toon(_mando_toon, -1)
		KEY_BACKSPACE: reponer_mando_toon(_mando_toon)
		KEY_9: _toy = false; diez_muros(true)
		KEY_0: diez_muros()
		KEY_X: limpiar()
		KEY_C: poner_camara((camara_actual + 1) % CAMARAS.size())
		KEY_H: _panel_visible = not _panel_visible


# ---------------------------------------------------------------- efectos ----------------------------------------------------------------

## Lanza un efecto delante de la jugadora. Devuelve el nodo (o null si falta la escena).
func efecto(cual: String) -> Node3D:
	_toy = cual.ends_with("_toy")
	var ruta: String = ESCENA_TOY[cual] if ESCENA_TOY.has(cual) else {"bola": ESCENA_BOLA, "muro": ESCENA_MURO, "columna": ESCENA_COLUMNA, "muro_toon": ESCENA_MURO_TOON, "columna_toon": ESCENA_COLUMNA_TOON, "bola_toon": ESCENA_BOLA_TOON}.get(cual, "")
	if ruta == "" or not ResourceLoader.exists(ruta):
		push_warning("falta la escena del efecto «%s»" % cual)
		return null
	var e: Node3D = (load(ruta) as PackedScene).instantiate() as Node3D
	_efectos.add_child(e)
	var pie: Vector3 = _pj.global_position
	match cual:
		"bola_toy":
			e.global_position = pie + _dir * DISTANCIA_EFECTO + Vector3(0, 1.0, 0)
			_aplicar_mandos_toy(e)
			e.call("lanzar", -1.0)
		"bola_vuelo_toy":
			e.global_position = pie + Vector3(0, ALTURA_MANO, 0) + _dir * 0.5
			e.set("proyectil", true)
			_aplicar_mandos_toy(e)
			e.call("lanzar", -1.0)
			_bolas.append({"nodo": e, "origen": e.global_position})
		"muro_toy":
			e.global_position = pie + _dir * DISTANCIA_EFECTO
			e.look_at(e.global_position + _dir, Vector3.UP)
			_aplicar_mandos_toy(e)
			e.call("lanzar", VIDA_MURO)
		"pilar_toy":
			e.global_position = pie + _dir * DISTANCIA_EFECTO
			_aplicar_mandos_toy(e)
			e.call("lanzar", VIDA_COLUMNA)
		"barrera_toy":
			e.global_position = pie
			_aplicar_mandos_toy(e)
			e.call("lanzar", -1.0)
		"bola", "bola_toon":
			e.global_position = pie + Vector3(0, ALTURA_MANO, 0) + _dir * 0.5
			e.call("lanzar", -1.0)
			_bolas.append({"nodo": e, "origen": e.global_position})
		"muro", "muro_toon":
			e.global_position = pie + _dir * DISTANCIA_EFECTO
			e.look_at(e.global_position + _dir, Vector3.UP)   # el plano del muro (su X) queda perpendicular al tiro
			if cual == "muro_toon":
				_aplicar_mandos_toon(e)
			e.call("lanzar", VIDA_MURO)
		"columna", "columna_toon":
			e.global_position = pie + _dir * DISTANCIA_EFECTO
			e.call("lanzar", VIDA_COLUMNA)
	ultimo_efecto = e
	return e


## Diez muros en dos filas, para leer el fps con el presupuesto a tope.
func diez_muros(toon: bool = false, toy: bool = false) -> void:
	_toy = toy
	var ruta: String = ESCENA_TOY["muro_toy"] if toy else (ESCENA_MURO_TOON if toon else ESCENA_MURO)
	if not ResourceLoader.exists(ruta):
		return
	for i in DIEZ_MUROS:
		var e: Node3D = (load(ruta) as PackedScene).instantiate() as Node3D
		_efectos.add_child(e)
		if toon:
			_aplicar_mandos_toon(e)
		if toy:
			_aplicar_mandos_toy(e)
		e.global_position = Vector3(-7.0 + float(i % 5) * 3.5, 0.0, -6.0 + float(i / 5) * 5.0)
		e.rotation_degrees = Vector3(0, 90.0, 0)
		e.call("lanzar", VIDA_MURO)
		ultimo_efecto = e


# ---------------------------------------------------------------- mandos del fuego toon ----------------------------------------------------------------

## Materiales de fuego (los de los planos) de un efecto toon.
func _materiales_toon(e: Node) -> Array:
	var r: Array = []
	for n in e.find_children("*", "GeometryInstance3D", true, false):
		var m: ShaderMaterial = (n as GeometryInstance3D).material_override as ShaderMaterial
		if m != null and m.shader != null and m.shader.resource_path.get_file() in ["fuego_toon.gdshader", "lengua_toon.gdshader", "cinta_toon.gdshader", "base_toon.gdshader", "halo_toon.gdshader", "chispa_toon.gdshader"]:
			r.append(m)
	return r


func _valor_mando_toon(i: int) -> float:
	var d: Array = MANDOS_TOON[i]
	return float(_valores_toon.get(d[0], d[4]))


## Pone en un efecto toon los valores que el usuario ha movido con el teclado.
func _aplicar_mandos_toon(e: Node) -> void:
	if _valores_toon.has("fps"):
		for gp in e.find_children("*", "GPUParticles3D", true, false):
			(gp as GPUParticles3D).fixed_fps = int(_valores_toon["fps"])   # las partículas llevan su propio fps
	for m in _materiales_toon(e):
		for i in MANDOS_TOON.size():
			var nombre: String = MANDOS_TOON[i][0]
			if not _valores_toon.has(nombre):
				continue
			if nombre == "rampa":
				m.set_shader_parameter("rampa", load(RAMPAS_TOON[int(_valores_toon[nombre]) % RAMPAS_TOON.size()]))
			else:
				m.set_shader_parameter(nombre, _valores_toon[nombre])


## Sube (+1) o baja (−1) un mando un paso, dentro de su rango, en todos los muros toon vivos.
func mover_mando_toon(i: int, signo: int) -> void:
	if _toy:
		var dt: Array = MANDOS_TOY[i]
		_valores_toy[dt[0]] = snappedf(clampf(_valor_mando_toy(i) + float(signo) * float(dt[3]), float(dt[1]), float(dt[2])), 0.001)
		for e in _efectos.get_children():
			_aplicar_mandos_toy(e)
		return
	var d: Array = MANDOS_TOON[i]
	var nuevo: float
	if d[0] == "rampa":
		nuevo = float((int(_valor_mando_toon(i)) + signo + RAMPAS_TOON.size()) % RAMPAS_TOON.size())
	else:
		nuevo = clampf(_valor_mando_toon(i) + float(signo) * float(d[3]), float(d[1]), float(d[2]))
	_valores_toon[d[0]] = nuevo
	for e in _efectos.get_children():
		_aplicar_mandos_toon(e)


func reponer_mando_toon(i: int) -> void:
	if _toy:
		_valores_toy.erase(MANDOS_TOY[i][0])
		for e in _efectos.get_children():
			if e.has_method("lanzar"):
				e.set(MANDOS_TOY[i][0], MANDOS_TOY[i][4])
		return
	_valores_toon.erase(MANDOS_TOON[i][0])
	var d: Array = MANDOS_TOON[i]
	for e in _efectos.get_children():
		for m in _materiales_toon(e):
			if d[0] == "rampa":
				m.set_shader_parameter("rampa", load(RAMPAS_TOON[0]))
			else:
				m.set_shader_parameter(d[0], d[4])


func _n_mandos() -> int:
	return MANDOS_TOY.size() if _toy else MANDOS_TOON.size()


func _valor_mando_toy(i: int) -> float:
	return float(_valores_toy.get(MANDOS_TOY[i][0], MANDOS_TOY[i][4]))


## Pone en un efecto de la prueba 3 los valores que se han movido con el teclado (el raíz es un EfectoToy: son sus exports).
func _aplicar_mandos_toy(e: Node) -> void:
	if not e.has_method("lanzar"):
		return
	for k in _valores_toy:
		e.set(k, _valores_toy[k])


func _texto_mandos_toon() -> String:
	if _toy:
		var st: String = "MANDOS TOY (RePág/AvPág elige · +/− cambia · Retroceso repone):"
		for i in MANDOS_TOY.size():
			st += "\n%s %s %.2f" % [">" if i == _mando_toon else " ", String(MANDOS_TOY[i][0]), _valor_mando_toy(i)]
		return st
	var s: String = "MANDOS TOON (RePág/AvPág elige · +/− cambia · Retroceso repone):"
	for i in MANDOS_TOON.size():
		var d: Array = MANDOS_TOON[i]
		var v: float = _valor_mando_toon(i)
		var txt: String = ["fuego", "azul"][int(v) % 2] if d[0] == "rampa" else ("%.2f" % v)
		s += "\n%s %s %s" % [">" if i == _mando_toon else " ", String(d[0]), txt]
	return s


func limpiar() -> void:
	for h in _efectos.get_children():
		h.queue_free()
	_bolas.clear()
	ultimo_efecto = null


func _mover_bolas(delta: float) -> void:
	var quedan: Array = []
	for b in _bolas:
		var n: Node3D = b["nodo"]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var d: Vector3 = (n.global_position - (b["origen"] as Vector3))
		if d.length() >= ALCANCE_BOLA:
			n.global_position.y = 0.05
			n.call("impactar")
			if _efectos.get_child_count() > 0 and _efectos.get_child(_efectos.get_child_count() - 1) != n:
				ultimo_efecto = _efectos.get_child(_efectos.get_child_count() - 1) as Node3D   # las cámaras cerca / lejos miran la llamarada
			continue
		n.global_position += _dir * VEL_BOLA * delta
		quedan.append(b)
	_bolas = quedan


# ---------------------------------------------------------------- jugadora y cámara ----------------------------------------------------------------

func _andar(delta: float) -> void:
	var v: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		v.z += 1.0
	if v.length() > 0.0:
		v = v.normalized()
		_dir = v
		_pj.global_position += v * VEL_ANDAR * delta
		_pj.global_position.x = clampf(_pj.global_position.x, -LADO_MAPA * 0.5, LADO_MAPA * 0.5)
		_pj.global_position.z = clampf(_pj.global_position.z, -LADO_MAPA * 0.5, LADO_MAPA * 0.5)
		_pj.look_at(_pj.global_position + v, Vector3.UP)
		_pj.rotate_y(PI)      # los modelos miran a +Z
		_clip("walk")
	else:
		_clip("idle")


func poner_camara(i: int) -> void:
	camara_actual = clampi(i, 0, CAMARAS.size() - 1)
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL if camara_actual == 0 else Camera3D.PROJECTION_PERSPECTIVE
	_cam.size = TAM_CAMARA_JUEGO
	_cam.fov = 60.0
	_seguir_camara()


func _seguir_camara() -> void:
	if _cam == null or _pj == null:
		return
	var foco: Vector3 = _pj.global_position + Vector3(0, 0.85, 0)
	if camara_actual == 0:
		var atras: Vector3 = Vector3(0, sin(deg_to_rad(ELEVACION_JUEGO)), cos(deg_to_rad(ELEVACION_JUEGO))) * 20.0
		_cam.global_position = foco + atras
		_cam.look_at(foco, Vector3.UP)
		return
	var objetivo: Vector3 = foco + _dir * DISTANCIA_EFECTO
	if ultimo_efecto != null and is_instance_valid(ultimo_efecto) and ultimo_efecto.is_inside_tree():
		objetivo = ultimo_efecto.global_position + Vector3(0, 0.8, 0)
	var dist: float = DIST_CERCA if camara_actual == 1 else DIST_LEJOS
	if ultimo_efecto != null and is_instance_valid(ultimo_efecto):
		for clave in CAMARA_TOY:                     # los efectos grandes piden la cámara más atrás y más alta (la barrera mide 3 m, el pilar 4)
			if ultimo_efecto.name.begins_with(clave):
				dist *= float(CAMARA_TOY[clave][0])
				objetivo = ultimo_efecto.global_position + Vector3(0, float(CAMARA_TOY[clave][1]), 0)
	var lado: Vector3 = Vector3(-_dir.z, 0, _dir.x) * 0.6 - _dir * 0.8
	var desde: Vector3 = objetivo + lado.normalized() * dist + Vector3(0, dist * 0.35, 0)
	_cam.global_position = desde
	_cam.look_at(objetivo, Vector3.UP)


## [luces, partículas] visibles en el árbol de efectos (el mismo recuento que LabVfx3D).
func luces_y_particulas() -> Array:
	var luces: int = 0
	var part: int = 0
	for n in _efectos.find_children("*", "", true, false):
		if n is Light3D and (n as Light3D).visible:
			luces += 1
		elif n is GPUParticles3D and (n as GPUParticles3D).emitting:
			part += (n as GPUParticles3D).amount
	return [luces, part]
