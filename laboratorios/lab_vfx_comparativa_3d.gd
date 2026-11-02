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
## Fuego paramétrico (FuegoToy, rama fuego-toy-parametrico): F7 crea el FuegoToy con la figura y el tamaño de la prueba 3 y, pulsada otra vez, pasa a la figura siguiente
## (bola → muro → pilar → barrera → haz) · U / J x más / menos · I / K y más / menos · O / L z más / menos (×1,2 cada pulsación; la geometría se rehace sola) · V bola en vuelo (sí/no) ·
## F8 devuelve los ejes al tamaño de la prueba 3 · F9 prueba `desde_hechizo` con hechizos de ejemplo (bola, muro, pilar, barrera, flecha). Los diez mandos (RePág, +, −) valen también aquí.
const FIGURAS_PARAM: Array = [
	[0, "bola", Vector3(0.4, 0.4, 0.4)], [1, "muro", Vector3(3.45, 1.5, 0.3)], [2, "pilar", Vector3(0.5, 4.0, 0.5)], [3, "barrera", Vector3(1.5, 1.5, 1.5)], [4, "haz", Vector3(1.5, 0.5, 0.15)]]
const PASO_EJE: float = 1.2
## Hechizos de ejemplo de F9: [nombre, semiejes en casillas, velocidad, solidez]
const EJEMPLOS_HECHIZO: Array = [
	["bola (esfera 0,3)", Vector3(0.3, 0.3, 0.3), 0.0, 0.0], ["muro (1,5 x 0,13 de fondo)", Vector3(1.5, 0.3, 0.13), 0.0, 0.0], ["pilar (alto 1,7)", Vector3(0.2, 1.7, 0.2), 0.0, 0.0],
	["barrera (cúpula 0,65)", Vector3(0.65, 0.65, 0.65), 0.0, 1.5], ["flecha (viaja)", Vector3(0.3, 0.3, 0.3), 8.0, 0.0], ["barrera alargada (muro sólido)", Vector3(1.2, 0.5, 0.2), 0.0, 1.5], ["haz (ᛁ línea, alcance 3)", Vector3(0.3, 0.3, 0.3), 0.0, 0.0, true]]
## Carga e impacto del fuego (rama fuego-toy-carga-impacto, FuegoToy.empezar_carga / soltar / impactar_en / rebotar / terminar_sin_choque, ImpactoFuegoToy):
##   G carga completa (brillo y chispas en la mano, SIN bola; se suelta y la bola aparece con un pop, vuela 6 m y el impacto sale en una pared)
##   B impacto en la pared · N impacto en el suelo · M fin sin choque (el hechizo se agota en el aire) · R rebote (salpica en la pared y sigue)
##   P explosión de ÁREA (agua: ImpactoAguaToy.Variante.AREA, radio 1,8 m, 3,5 m delante; fuego: impacto de suelo grande) · V con un pilar / haz de F7: lo hace MORIR y renacer
##   T elige un mando de la carga · Q baja / E sube el mando elegido (tamaño inicial, curva, nº de chispas, brillo del destello, brillo de la mano, radio de las chispas, bola visible 0/1)
## [propiedad de FuegoToy, mínimo, máximo, paso, valor de origen]
##   Y recorre el estilo del impacto: C (POR DEFECTO: golpe sutil + chispas desde el impacto hacia afuera) → A (estallido cartoon, T_VFX_Ex1d) → B (bola de fuego redonda, flipbook). Se ve en la línea de ayuda.
##   Mandos (T los recorre): carga_brillo, carga_radio, carga_bola_visible (0 = no se ve la bola al cargar, 1 = crece en la mano como antes), tam_estallido y vel_flipbook (solo estilos A y B).
const MANDOS_CARGA: Array = [
	["carga_tam_inicial", 0.03, 0.6, 0.03, 0.12], ["carga_curva", 0.3, 3.0, 0.1, 0.8], ["carga_chispas", 0, 40, 4, 28], ["carga_destello", 0.0, 3.0, 0.2, 1.0],
	["carga_brillo", 0.0, 3.0, 0.2, 1.0], ["carga_radio", 0.5, 2.0, 0.1, 1.0], ["carga_bola_visible", 0, 1, 1, 0]]
## Mandos del impacto (propiedades ESTÁTICAS de ImpactoFuegoToy; valen para los impactos que nazcan después): [propiedad, mínimo, máximo, paso, valor de origen]
const MANDOS_IMPACTO: Array = [["tam_estallido", 0.5, 2.0, 0.1, 1.0], ["vel_flipbook", 0.4, 2.5, 0.1, 1.0]]
const DURACION_CARGA_LAB: float = 1.2              ## s que dura la carga hasta llenarse
const SOSTEN_CARGA_LAB: float = 0.6                ## s que se sostiene ya llena (respira) antes de soltar: el «⧖ carga» largo
const RADIO_BOLA_LAB: float = 0.4
const RADIO_AREA_LAB: float = 1.8                  ## m de radio de la explosión de área (P)
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
var _param = null                                  ## el FuegoToy / AguaToy vivo (F7 / F9)
var elemento: String = "fuego"                     ## «fuego» o «agua»: lo que crean G, B, N, M, R, F7, F9 y los ejes (Z lo alterna)
var _param_i: int = -1                             ## figura de F7 (índice de FIGURAS_PARAM)
var _param_ej: int = 0                             ## ejemplo de hechizo de F9
var _valores_toy: Dictionary = {}                  ## propiedad -> valor actual (lo que nazca después nace con él)
var _valores_carga: Dictionary = {}                ## mandos de la carga movidos con Q / E
var _mando_carga: int = 0                          ## el elegido con T
var _pared: Node3D = null                          ## la pared de prueba de los impactos (la crea G / B / R, la quita X)
var camara_fija: Dictionary = {}                   ## {desde, mira}: si no está vacío, las cámaras cerca / lejos usan esto (lo usan las capturas)


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
			% [int(Engine.get_frames_per_second()), lp[0], lp[1], _efectos.get_child_count(), CAMARAS[camara_actual], _texto_mandos_toon()] + _texto_param() + _texto_carga()) if _panel_visible else ""


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
		KEY_Z: alternar_elemento()
		KEY_F7: fuego_param((_param_i + 1) % FIGURAS_PARAM.size())
		KEY_F8: fuego_param(maxi(_param_i, 0))
		KEY_F9: fuego_hechizo(_param_ej); _param_ej = (_param_ej + 1) % EJEMPLOS_HECHIZO.size()
		KEY_U: eje_param(0, 1)
		KEY_J: eje_param(0, -1)
		KEY_I: eje_param(1, 1)
		KEY_K: eje_param(1, -1)
		KEY_O: eje_param(2, 1)
		KEY_L: eje_param(2, -1)
		KEY_V: viaja_param()
		KEY_P: explosion_area()
		KEY_G: carga_completa()
		KEY_B: impacto_pared()
		KEY_N: impacto_suelo()
		KEY_M: lanzar_proyectil("fin")
		KEY_R: lanzar_proyectil("rebote")
		KEY_Y: alternar_estilo_impacto()
		KEY_T: _mando_carga = (_mando_carga + 1) % (MANDOS_CARGA.size() + MANDOS_IMPACTO.size())
		KEY_Q: mover_mando_carga(_mando_carga, -1)
		KEY_E: mover_mando_carga(_mando_carga, 1)
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
			e.look_at(e.global_position + _dir, Vector3.UP)   # el -Z mira hacia donde vuela: la estela cae por +Z
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


# ---------------------------------------------------------------- fuego paramétrico (FuegoToy) ----------------------------------------------------------------

## Z: alterna el ELEMENTO (fuego / agua) de lo que se cree a partir de ahora (G, B, N, M, R, F7, F9, ejes). Si hay un efecto paramétrico vivo (F7 / F9) se rehace con el otro elemento.
func alternar_elemento() -> void:
	poner_elemento("agua" if elemento == "fuego" else "fuego")


func poner_elemento(nuevo: String) -> void:
	if nuevo == elemento:
		return
	elemento = nuevo
	if _param != null and is_instance_valid(_param):
		var fig: int = _param_i
		fuego_param(maxi(fig, 0))


## Un efecto «toy» nuevo del elemento activo (FuegoToy o AguaToy: la misma API).
func _nuevo_toy() -> Node3D:
	if elemento == "agua":
		return AguaToy.new()
	return FuegoToy.new()


## ¿Es un efecto «toy» (de cualquiera de los dos elementos)?
func _es_toy(e: Node) -> bool:
	return e is FuegoToy or e is AguaToy


## Un impacto del elemento activo (ImpactoFuegoToy o ImpactoAguaToy; las variantes GOLPE, FIN y REBOTE tienen los mismos números).
func _nuevo_impacto(variante: int, normal: Vector3, radio: float) -> Node3D:
	if elemento == "agua":
		return ImpactoAguaToy.crear(variante as ImpactoAguaToy.Variante, normal, radio)
	return ImpactoFuegoToy.crear(variante as ImpactoFuegoToy.Variante, normal, radio)


## F7 / F8: crea el FuegoToy (o AguaToy) con la figura y el tamaño de la prueba 3 (i = índice de FIGURAS_PARAM) y lo coloca como las escenas validadas.
func fuego_param(i: int) -> Node3D:
	_toy = true
	_param_i = clampi(i, 0, FIGURAS_PARAM.size() - 1)
	var d: Array = FIGURAS_PARAM[_param_i]
	var s: Vector3 = d[2]
	var e = _nuevo_toy()
	e.definir(d[0], s.x, s.y, s.z, false)
	_poner_param(e, 0.0)
	return e


## F9: crea el FuegoToy (o AguaToy) a partir de un Hechizo de ejemplo con `desde_hechizo` (figura, tamaño y vuelo salen solos).
func fuego_hechizo(i: int) -> Node3D:
	_toy = true
	var d: Array = EJEMPLOS_HECHIZO[i % EJEMPLOS_HECHIZO.size()]
	var h: Hechizo = Hechizo.new()
	var s: Vector3 = d[1]
	h.semieje_x = s.x
	h.semieje_y = s.y
	h.semieje_z = s.z
	h.velocidad = float(d[2])
	h.solidez = float(d[3])
	if d.size() > 4:
		h.glifos = {"linea_x": 1}       # ᛁ: con estado de materia que no sea sólido es un haz
		h.estado_materia = "plasma"
	var e = _nuevo_toy()
	e.desde_hechizo(h)
	var giro: float = e.rotation.y
	e.rotation = Vector3.ZERO
	_param_i = int(e.figura)
	_poner_param(e, giro)
	return e


func _poner_param(e, giro: float) -> void:
	_quitar_param()
	_aplicar_mandos_toy(e)
	_efectos.add_child(e)
	var pie: Vector3 = _pj.global_position
	match e.figura:
		FuegoToy.Figura.BOLA:
			e.global_position = pie + _dir * DISTANCIA_EFECTO + Vector3(0, 1.0, 0)
		FuegoToy.Figura.BARRERA:
			e.global_position = pie
		FuegoToy.Figura.HAZ:
			e.global_position = pie + _dir * 0.5            # sale de la mano hacia delante
			e.look_at(e.global_position + _dir, Vector3.UP)
		_:
			e.global_position = pie + _dir * DISTANCIA_EFECTO
			e.look_at(e.global_position + _dir, Vector3.UP)     # el X del muro queda de lado al tiro
	e.rotate_y(giro)
	e.lanzar(-1.0)
	_param = e
	ultimo_efecto = e
	if e.viaja:
		_lanzar_param_en_vuelo()


func _quitar_param() -> void:
	if _param != null and is_instance_valid(_param):
		_bolas = _bolas.filter(func(b: Dictionary) -> bool: return b["nodo"] != _param)
		_param.get_parent().remove_child(_param)
		_param.queue_free()
	_param = null


## U/J, I/K, O/L: sube o baja un semieje (x, y, z) un 20 %. La geometría se rehace sola.
func eje_param(eje: int, signo: int) -> void:
	if _param == null or not is_instance_valid(_param):
		fuego_param(maxi(_param_i, 0))
	var f: float = PASO_EJE if signo > 0 else 1.0 / PASO_EJE
	match eje:
		0: _param.semieje_x = clampf(_param.semieje_x * f, 0.05, 8.0)
		1: _param.semieje_y = clampf(_param.semieje_y * f, 0.05, 8.0)
		2: _param.semieje_z = clampf(_param.semieje_z * f, 0.05, 8.0)


## V: la bola (solo la figura bola) vuela en bucle por delante de la jugadora, o vuelve a quedarse quieta.
func viaja_param() -> void:
	if _param != null and is_instance_valid(_param) and int(_param.figura) != 0:
		_morir_y_rehacer_param()
		return
	if _param == null or not is_instance_valid(_param):
		fuego_param(0)
	_param.viaja = not _param.viaja
	if _param.viaja:
		_lanzar_param_en_vuelo()
	else:
		_bolas = _bolas.filter(func(b: Dictionary) -> bool: return b["nodo"] != _param)
		_param.rotation = Vector3.ZERO
		_param.global_position = _pj.global_position + _dir * DISTANCIA_EFECTO + Vector3(0, 1.0, 0)


## V con una figura que no es la bola (pilar, haz...): la hace MORIR (el pilar se desploma y deja charco; el haz se suelta) y 2,4 s después la vuelve a hacer nacer.
func _morir_y_rehacer_param() -> void:
	var fig: int = int(_param.figura)
	_param.morir()
	await get_tree().create_timer(2.4).timeout
	if _param == null or not is_instance_valid(_param):
		fuego_param(fig)


## P: EXPLOSIÓN DE ÁREA 3 m delante de la jugadora. Con agua es ImpactoAguaToy.Variante.AREA (radio 1,8 m); con fuego, el impacto de suelo grande.
func explosion_area(radio: float = RADIO_AREA_LAB) -> Node3D:
	_toy = true
	var imp: Node3D = _nuevo_impacto(3 if elemento == "agua" else 0, Vector3.UP, radio if elemento == "agua" else radio * 0.5)
	_efectos.add_child(imp)
	imp.global_position = Vector3(_pj.global_position.x, 0.0, _pj.global_position.z) + _dir * 3.5
	ultimo_efecto = imp
	return imp


func _lanzar_param_en_vuelo() -> void:
	var o: Vector3 = _pj.global_position + Vector3(0, ALTURA_MANO, 0) + _dir * 0.5
	_param.global_position = o
	_param.look_at(o + _dir, Vector3.UP)      # su -Z mira hacia donde vuela
	_bolas.append({"nodo": _param, "origen": o, "bucle": true})


func _texto_param() -> String:
	if _param == null or not is_instance_valid(_param):
		return "\nFUEGO PARAMETRICO: F7 figura (bola > muro > pilar > barrera) · F9 hechizo de ejemplo · U/J x · I/K y · O/L z · V bola en vuelo · F8 tamano de la prueba 3 · Z fuego/agua"
	return "\n%s PARAMETRICO [%s] x %.2f · y %.2f · z %.2f m%s  (F7 figura · F9 hechizo · U/J x · I/K y · O/L z · V vuelo · F8 prueba 3 · Z fuego/agua)" % [
		"AGUA" if _param is AguaToy else "FUEGO", ["bola", "muro", "pilar", "barrera", "haz"][int(_param.figura)], _param.semieje_x, _param.semieje_y, _param.semieje_z, " · EN VUELO" if _param.viaja else ""]


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
	if _pared != null and is_instance_valid(_pared):
		_pared.queue_free()
	_pared = null


# ---------------------------------------------------------------- carga e impacto del fuego (FuegoToy / ImpactoFuegoToy) ----------------------------------------------------------------

func _mano() -> Vector3:
	return _pj.global_position + Vector3(0, ALTURA_MANO, 0) + _dir * 0.5


## Pared de prueba perpendicular al tiro, a ALCANCE_BOLA m de la mano (su cara delantera está justo ahí).
func _poner_pared() -> void:
	if _pared != null and is_instance_valid(_pared):
		_pared.queue_free()
	_pared = Node3D.new()
	_pared.name = "ParedImpacto"
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(9.0, 3.2, 0.3)
	mi.mesh = bm
	var mt: StandardMaterial3D = StandardMaterial3D.new()
	mt.albedo_color = Color(0.56, 0.52, 0.47)
	mt.roughness = 0.95
	mi.material_override = mt
	mi.position = Vector3(0, 1.6, 0)
	_pared.add_child(mi)
	add_child(_pared)
	var pie: Vector3 = _pj.global_position
	_pared.global_position = Vector3(pie.x, 0.0, pie.z) + _dir * (ALCANCE_BOLA + 0.15)       # la cara delantera queda a ALCANCE_BOLA m de la jugadora
	_pared.look_at(_pared.global_position + _dir, Vector3.UP)


func _aplicar_mandos_carga(e: Node) -> void:
	for k in _valores_carga:
		e.set(k, bool(_valores_carga[k]) if k == "carga_bola_visible" else _valores_carga[k])


func mover_mando_carga(i: int, signo: int) -> void:
	if i >= MANDOS_CARGA.size():
		var di: Array = MANDOS_IMPACTO[i - MANDOS_CARGA.size()]
		var vi: float = clampf(_valor_impacto(di[0]) + float(signo) * float(di[3]), float(di[1]), float(di[2]))
		if di[0] == "tam_estallido":
			ImpactoFuegoToy.tam_estallido = snappedf(vi, 0.001)
		else:
			ImpactoFuegoToy.vel_flipbook = snappedf(vi, 0.001)
		return
	var d: Array = MANDOS_CARGA[i]
	var v: float = float(_valores_carga.get(d[0], d[4])) + float(signo) * float(d[3])
	v = clampf(v, float(d[1]), float(d[2]))
	_valores_carga[d[0]] = int(round(v)) if (d[0] == "carga_chispas" or d[0] == "carga_bola_visible") else snappedf(v, 0.001)
	for e in _efectos.get_children():
		if _es_toy(e):
			_aplicar_mandos_carga(e)


func _valor_impacto(nombre: String) -> float:
	return ImpactoFuegoToy.tam_estallido if nombre == "tam_estallido" else ImpactoFuegoToy.vel_flipbook


## Y: recorre el estilo de los impactos nuevos: C (golpe sutil + chispas hacia afuera, por defecto) → A (estallido cartoon) → B (bola de fuego redonda) → C.
func alternar_estilo_impacto() -> void:
	match ImpactoFuegoToy.estilo:
		ImpactoFuegoToy.Estilo.C:
			ImpactoFuegoToy.estilo = ImpactoFuegoToy.Estilo.A
		ImpactoFuegoToy.Estilo.A:
			ImpactoFuegoToy.estilo = ImpactoFuegoToy.Estilo.B
		_:
			ImpactoFuegoToy.estilo = ImpactoFuegoToy.Estilo.C


func nombre_estilo_impacto() -> String:
	match ImpactoFuegoToy.estilo:
		ImpactoFuegoToy.Estilo.A:
			return "A (estallido cartoon Ex1d)"
		ImpactoFuegoToy.Estilo.B:
			return "B (bola de fuego, flipbook)"
	return "C (golpe sutil + chispas)"


func _texto_carga() -> String:
	var s: String = "\nELEMENTO: %s (Z cambia fuego/agua)  ·  CARGA / IMPACTO [impacto %s]: G carga>suelta>vuelo>pared · B pared · N suelo · M fin · R rebote · P explosion de AREA (agua; el pilar de F7 nace solo, V lo hace morir) · Y estilo C/A/B (solo fuego) · T mando · Q- E+  |" % [
		elemento.to_upper(), nombre_estilo_impacto() if elemento == "fuego" else "salpicadura de agua"]
	for i in MANDOS_CARGA.size():
		var d: Array = MANDOS_CARGA[i]
		s += " %s%s %.2f" % [">" if i == _mando_carga else "", String(d[0]).replace("carga_", ""), float(_valores_carga.get(d[0], d[4]))]
	for j in MANDOS_IMPACTO.size():
		var di: Array = MANDOS_IMPACTO[j]
		s += " %s%s %.2f" % [">" if MANDOS_CARGA.size() + j == _mando_carga else "", String(di[0]), _valor_impacto(di[0])]
	return s


## G: brillo y chispas en la mano durante DURACION_CARGA_LAB s, se sostiene SOSTEN_CARGA_LAB s más (respira), se suelta (la bola aparece con un pop), vuela hasta la pared y el impacto sale por su normal.
func carga_completa(radio: float = RADIO_BOLA_LAB) -> Node3D:
	_toy = true
	_poner_pared()
	var e = _nuevo_toy()
	_aplicar_mandos_toy(e)
	_aplicar_mandos_carga(e)
	_efectos.add_child(e)
	e.global_position = _mano()
	e.look_at(e.global_position + _dir, Vector3.UP)
	e.empezar_carga(DURACION_CARGA_LAB, radio)
	ultimo_efecto = e
	_suelta_y_vuela(e, DURACION_CARGA_LAB + SOSTEN_CARGA_LAB, "golpe")
	return e


## M / R: carga corta y proyectil que (M) se agota en el aire a 3,5 m o (R) rebota en la pared y se agota 2 m después.
func lanzar_proyectil(modo: String, radio: float = RADIO_BOLA_LAB) -> Node3D:
	_toy = true
	if modo == "rebote":
		_poner_pared()
	var e = _nuevo_toy()
	_aplicar_mandos_toy(e)
	_aplicar_mandos_carga(e)
	_efectos.add_child(e)
	e.global_position = _mano()
	e.look_at(e.global_position + _dir, Vector3.UP)
	e.empezar_carga(0.35, radio)
	ultimo_efecto = e
	_suelta_y_vuela(e, 0.4, modo)
	return e


func _suelta_y_vuela(e: Node3D, tras: float, modo: String) -> void:
	var dir: Vector3 = _dir
	await get_tree().create_timer(tras).timeout
	if not is_instance_valid(e) or not e.is_inside_tree():
		return
	e.call("soltar", dir)
	_bolas.append({"nodo": e, "origen": e.global_position, "dir": dir, "modo": modo, "alcance": 3.5 if modo == "fin" else ALCANCE_BOLA - 0.5, "normal": -dir})


## B: el impacto solo (sin bola) en la pared de prueba, orientado por su normal.
func impacto_pared(variante: int = 0) -> Node3D:
	_toy = true
	_poner_pared()
	var imp: Node3D = _nuevo_impacto(variante, -_dir, RADIO_BOLA_LAB)
	_efectos.add_child(imp)
	imp.global_position = _mano() + _dir * (ALCANCE_BOLA - 0.5)
	ultimo_efecto = imp
	return imp


## N: el impacto solo en el suelo (corona hacia arriba).
func impacto_suelo(variante: int = 0) -> Node3D:
	_toy = true
	var imp: Node3D = _nuevo_impacto(variante, Vector3.UP, RADIO_BOLA_LAB)
	_efectos.add_child(imp)
	imp.global_position = Vector3(_pj.global_position.x, 0.0, _pj.global_position.z) + _dir * 3.0
	ultimo_efecto = imp
	return imp


func _mover_bolas(delta: float) -> void:
	var quedan: Array = []
	for b in _bolas:
		var n: Node3D = b["nodo"]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		if b.has("modo"):
			var dv: Vector3 = b["dir"]
			if (n.global_position - (b["origen"] as Vector3)).length() >= float(b["alcance"]):
				var punto: Vector3 = n.global_position
				match String(b["modo"]):
					"golpe":
						n.call("impactar_en", punto, b["normal"])
					"rebote":
						var nd: Vector3 = n.call("rebotar", punto, b["normal"])
						quedan.append({"nodo": n, "origen": punto, "dir": nd, "modo": "fin", "alcance": 2.0, "normal": Vector3.UP})
					_:
						n.call("terminar_sin_choque")
				continue
			n.global_position += dv * VEL_BOLA * delta
			quedan.append(b)
			continue
		var d: Vector3 = (n.global_position - (b["origen"] as Vector3))
		if d.length() >= ALCANCE_BOLA and b.get("bucle", false):
			n.global_position = b["origen"]          # el FuegoToy en vuelo (V) da vueltas: vuelve a la mano y sigue
			quedan.append(b)
			continue
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
	if not camara_fija.is_empty():
		_cam.global_position = camara_fija["desde"]
		_cam.look_at(camara_fija["mira"], Vector3.UP)
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
	if _es_toy(ultimo_efecto) and is_instance_valid(ultimo_efecto):
		# FuegoToy / AguaToy: la cámara de cada figura de la prueba 3 (CAMARA_TOY) escalada por lo que crece o mengua respecto al tamaño validado
		var ft = ultimo_efecto
		var clave: String = ["", "Muro", "Pilar", "Barrera", "Muro"][int(ft.figura)]
		var fc: Array = CAMARA_TOY.get(clave, [1.0, 0.8])
		var ref_y: float = [FuegoToy.REF_BOLA.x, FuegoToy.REF_MURO.y, FuegoToy.REF_PILAR.y, FuegoToy.REF_BARRERA.y, FuegoToy.REF_HAZ.y][int(ft.figura)]
		var ext: float = ft.extension() / FuegoToy._extension_ref(int(ft.figura) as FuegoToy.Figura)
		dist *= float(fc[0]) * clampf(ext, 0.45, 3.5)
		var yo: float = ft.semieje_y if int(ft.figura) != FuegoToy.Figura.BOLA else maxf(ft.semieje_x, ft.semieje_z)
		objetivo = ft.global_position + Vector3(0, float(fc[1]) * yo / ref_y, 0)
		if int(ft.figura) == FuegoToy.Figura.HAZ:
			objetivo = ft.global_transform * Vector3(0, maxf(ft.semieje_y, 0.4), -ft.semieje_x)       # mira al centro del haz
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
