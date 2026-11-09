class_name HazGas
extends Node3D

## PORT FIEL A GODOT 4.7 de la demo de gas de three.js «Force Field VFX» — https://github.com/lejrimostfa/force-field-vfx-threejs
## (MIT, Copyright (c) 2026 lejrimostfa; aviso completo en laboratorios/haz_gas/LICENSE_force_field_vfx.txt). PRUEBA AISLADA del lab: no toca el juego.
## Este nodo es src/main.js + src/render/stage.js + figures.js + hud.js + config.js: monta la escena de la demo (suelo y acantilado de roca iluminados SOLO por los
## campos de luz del gas, escudo, siluetas, lámpara azul), el bucle (un paso de 1/60 s por fotograma), la cámara (la de la demo, su órbita automática, o la del juego),
## los ocho mandos en pantalla y las teclas. La simulación es HazGasSolver (compute), el volumen HazGasRaymarch (CompositorEffect).
##
## Coordenadas: las del DOMINIO son las de la demo (1 unidad = 1 m de la demo, caja x -12..12, y 0..12, z -6..6). El nodo puede ir escalado y girado en el mundo
## (vista «juego»: la boquilla en la mano de la jugadora del lab); todo lo que dibuja recibe mundo_a_dominio.
## Lo abre el LabVfxComparativa3D con Mayús+F12 (esfera → muro → nada). Teclas dentro: ver AYUDA.

const AYUDA: String = "arrastrar: orbitar · rueda: zoom · ESPACIO chorro sí/no · C cámara (demo / órbita automática / juego) · U/J largo · I/K alto · O/L ancho · B obstáculo (esfera / caja / nada) · N/M su tamaño · V/F su distancia · 1-4 calidad · R dibujo TOON / realista · Y paleta (pablo / demo) · T filtro temporal · P pausa · Mayús+F12 salir"
const DT: float = HazGasSolver.DT
## config.js TUNABLES: [nombre en params, etiqueta, máximo]
const MANDOS: Array = [["wind", "Viento", 30.0], ["push", "Empuje tras el choque", 30.0], ["turbulence", "Turbulencia", 150.0], ["confine", "Remolinos", 80.0],
	["subgrid", "Desgarro fino", 20.0], ["viscosity", "Viscosidad", 0.3], ["thickness", "Espesor del humo", 4.0], ["sootYield", "Humo del fuego", 4.0]]
## Muro del lab como obstáculo (caja): misma cara delantera que la piel de la esfera de la demo (x = -0,1), 1 m de grueso, 4,8 de alto, 4,4 de ancho.
const MURO_C: Vector3 = Vector3(-0.6, 2.4, 0.0)
const MURO_H: Vector3 = Vector3(0.5, 2.4, 2.2)
const VISTAS: PackedStringArray = ["demo", "orbita", "juego", "lateral"]          ## «lateral»: el dominio a escala de juego (como «juego») visto de lado con la cámara propia
const ESCALA_JUEGO: float = 0.35              ## vista «juego» con la configuración EXACTA de la demo: metros del lab por unidad de la demo

## Dominio y obstáculo de ESTA instancia (los de la demo, o los que deriva derivar_haz en el modo procedural).
var mundo_lo: Vector3 = HazGasSolver.WORLD_MIN
var mundo_tam: Vector3 = HazGasSolver.WORLD_SIZE
var muro_c: Vector3 = MURO_C
var muro_h: Vector3 = MURO_H
var escala_masa: float = 1.0                ## M (ver gas_comun.glslinc ESC_M): 1 = la demo
var metros_por_unidad: float = ESCALA_JUEGO ## en las vistas de juego: metros del lab por unidad del dominio
var res_dominio: Vector3i = Vector3i.ZERO   ## rejilla de gas propia (ZERO = la de la calidad)
var haz_cfg: Dictionary = {}                ## entrada del modo procedural (vacío = la demo tal cual); ver derivar_haz
var haz_der: Dictionary = {}                ## lo que se deriva de haz_cfg
var _target_base: Vector3 = Vector3(-1.2, 2.0, 0.0)
## EN EL JUEGO (HazGasJuego): sin escena de la demo, sin HUD, sin cámara propia ni teclas; el obstáculo es el CAMPO de sólidos reales (obstaculo «campo»,
## primitivas en coordenadas del dominio: `prims_dom`, 12 floats cada una, ver solido.glsl) y el nodo se coloca con `colocar`.
var modo_juego: bool = false
var prims_dom: PackedFloat32Array = PackedFloat32Array()

## params.js makeParams (valores de la demo)
var params: Dictionary = {
	"beamOn": 1.0, "beamSpeed": 34.0, "beamR0": 0.3, "beamR1": 0.8,
	"nozzle": Vector3(9.4, 1.5, 0.0), "target": Vector3(-1.2, 2.0, 0.0),
	"shieldC": Vector3(-2.2, 2.0, 0.0), "shieldR": 2.1, "wrap": 42.0,
	"burnRate": 2.2, "heat": 0.85, "sootYield": 1.3, "expansion": 1.5, "cool": 1.1, "sootFade": 0.45, "dustFade": 0.35,
	"buoyancy": 2.8, "weight": 0.0, "drag": 0.7, "wind": 8.0, "push": 5.0, "confine": 24.0, "subgrid": 8.0, "viscosity": 0.03, "turbulence": 55.0,
	"thickness": 0.75, "relief": 0.7, "edge": 0.35, "smokeAlbedo": 0.3, "flameBody": 5.0, "emitGain": 6.5, "fireOnSmoke": 2.2, "farOnSmoke": 1.6,
	"fireOnRock": 7.0, "lampOnSmoke": 720.0, "lampOnRock": 3.2, "keyPos": Vector3(-12.5, 1.8, 1.5),
	"saturacion": 1.3, "vineta": 1.0,
	"paleta": 1.0,              ## 1 = «pablo» (rojos y naranjas, nunca amarillo ni blanco: tecla K), 0 = la de la demo tal cual
}
var calidad: String = "low"
var obstaculo: String = "esfera"            ## «esfera» (el escudo de la demo), «muro» (caja) o «nada»
var vista: String = "demo"
var pausa: bool = false
var temporal: bool = true
var mostrar_hud: bool = true
## Vista «juego»: la cámara, la mano y la dirección de la jugadora del lab (los pone el lab).
var camara_juego: Camera3D = null
var mano_juego: Vector3 = Vector3(0, 0.7, -0.5)
var dir_juego: Vector3 = Vector3(0, 0, -1)
var jugadora_juego: Node3D = null

## MODO TOON (prototipo A de Pablo, 9/11): la simulación es la misma; cambia SOLO EL DIBUJO por el lenguaje del fuego aprobado del juego (fuego_lelu + la rampa
## de la bola de FuegoToy, raymarch_toon.glsl), visto en el entorno NORMAL del lab. false = el dibujo realista de la demo. Tecla R. Por defecto, toon.
signal dibujo_cambiado(es_toon: bool)
var toon: bool = true
## Mandos del dibujo toon (los de fuego_lelu.gdshaderinc donde existen: umbral 0,3, blandura 0,22, contraste 1,1, chisporroteo 0,6; tope 0,62 = HAZ_TOPE_CALOR).
var toon_params: Dictionary = {"umbral": 0.3, "blandura": 0.22, "contraste": 1.1, "tope": 0.62, "k_T": 1.0, "k_c": 0.5, "amplitud": 0.45, "escala": 0.45,
	"umbral_humo": 0.9, "opacidad_humo": 0.8, "escala_rampa": 1.0, "sube": 0.9, "chisporroteo": 0.6, "profundidad": 0.6}
const TEX_LELU: String = "res://assets/vfx/lelu_noise/"
var _toon_tex: Array = []                   ## [lenguas, ruido_a, ruido_fino, rampa de la bola]: las MISMAS texturas que FuegoToy._mat_fuego
var _esfera: MeshInstance3D = null
var _mat_muro_roca: ShaderMaterial = null
var _mat_lab: StandardMaterial3D = null
var _mat_chispas_real: ShaderMaterial = null
var _mat_chispas_toon: ShaderMaterial = null

var solver: HazGasSolver = null
var efecto: HazGasRaymarch = null
var frame: int = 0
var gpu_ms: Dictionary = {}
var gpu_viewport_ms: float = 0.0

var _compositor: Compositor = null
var _cam: Camera3D = null
var _env: Environment = null
var _suelo: MeshInstance3D = null
var _acantilado: MeshInstance3D = null
var _muro: MeshInstance3D = null
var _defensor: Node3D = null
var _atacante: Node3D = null
var _chispas_mi: MultiMeshInstance3D = null
var _mat_roca: Array[ShaderMaterial] = []
var _mat_chispas: ShaderMaterial = null
var _tex_luz: Texture3DRD = null
var _tex_lejos: Texture3DRD = null
var _tex_clave: Texture3DRD = null
var _tex_chispas: Texture2DRD = null
var _acum: float = 0.0
var _hud: CanvasLayer = null
var _linea: Label = null
var _ayuda: Label = null
var _sliders: Dictionary = {}
var _orbita: Vector3 = Vector3.ZERO        ## yaw, pitch, distancia (mando de ratón, como OrbitControls)
var _arrastrando: bool = false
var _t_medida: float = 0.0
var _n_medida: int = 0
var _acum_gpu: Dictionary = {}


func _ready() -> void:
	_montar_escena()
	_montar_hud()
	if modo_juego:
		_hud.visible = false
		mostrar_hud = false
	_cam = Camera3D.new()
	_cam.name = "CamaraDemo"
	_cam.fov = 32.0
	_cam.near = 0.1
	_cam.far = 200.0
	add_child(_cam)
	var o: Vector3 = Vector3(2.5, 6, 23) - Vector3(1.4, 2.4, 0)
	_orbita = Vector3(atan2(o.x, o.z), asin(o.y / o.length()), o.length())
	efecto = HazGasRaymarch.new()
	_compositor = Compositor.new()
	_compositor.compositor_effects = [efecto]
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	FuegoToy._rampas()
	_toon_tex = [load(TEX_LELU + "T_FirePanningCyl45.png"), load(TEX_LELU + "T_PerlinNoise_Tiled.png"), load(TEX_LELU + "T_Noise1_tiled.png"), FuegoToy._rampa_de_bola()]
	configurar_haz(haz_cfg)              # crea la simulación, la geometría y la vista (vacío = la demo tal cual)


func _exit_tree() -> void:
	for c in [_cam, camara_juego]:
		if c != null and is_instance_valid(c) and c.compositor == _compositor:
			c.compositor = null
	_liberar_solver()


## (Re)crea la simulación con una calidad de config.js QUALITY (low / med / high / ultra). Vacía el gas.
func crear_solver(q: String, jacobi: int = 0) -> bool:
	_liberar_solver()
	calidad = q if HazGasSolver.CALIDADES.has(q) else "low"
	solver = HazGasSolver.new(calidad, jacobi, res_dominio, mundo_lo, mundo_tam)
	RenderingServer.call_on_render_thread(solver.crear)
	if not solver.valido:
		push_warning("HazGas: sin RenderingDevice no hay gas (las pruebas de GPU necesitan ventana)")
		return false
	efecto.solver = solver
	_tex_luz = Texture3DRD.new()
	_tex_luz.texture_rd_rid = solver.luz[0]
	_tex_lejos = Texture3DRD.new()
	_tex_lejos.texture_rd_rid = solver.luz_lejos[0]
	_tex_clave = Texture3DRD.new()
	_tex_clave.texture_rd_rid = solver.clave
	_tex_chispas = Texture2DRD.new()
	_tex_chispas.texture_rd_rid = solver.chispas
	for m in _mat_roca:
		m.set_shader_parameter("luz", _tex_luz)
		m.set_shader_parameter("luz_lejos", _tex_lejos)
		m.set_shader_parameter("clave", _tex_clave)
	_mat_chispas_real.set_shader_parameter("estado", _tex_chispas)
	_mat_chispas_toon.set_shader_parameter("estado", _tex_chispas)
	frame = 0
	_acum_gpu.clear()
	return true


func _liberar_solver() -> void:
	if efecto != null:
		efecto.solver = null
	for m in _mat_roca:
		for n in ["luz", "luz_lejos", "clave"]:
			m.set_shader_parameter(n, null)
	for mc in [_mat_chispas_real, _mat_chispas_toon]:
		if mc != null:
			mc.set_shader_parameter("estado", null)
	_tex_luz = null
	_tex_lejos = null
	_tex_clave = null
	_tex_chispas = null
	if solver != null:
		var s: HazGasSolver = solver
		RenderingServer.call_on_render_thread(s.liberar)
	solver = null


func listo() -> bool:
	return solver != null and solver.valido


# ------------------------------------------------------------------------------------------------------------------------------------------------ PROCEDURAL

## Haz de referencia del lab (FuegoToy.REF_HAZ, la figura «haz» de F7): largo 3 m, radio 0,15, eje a 0,5 m; esfera de 0,8 m a 2/3 del largo (el F12 del lab).
const HAZ_REF: Dictionary = {"largo": 3.0, "ancho": 0.15, "alto": 0.5, "obstaculo": "esfera", "tam": 0.8, "dist": 2.0}
const L_CHORRO: float = 10.6          ## unidades que mide SIEMPRE el chorro (boquilla → objetivo en la demo): la unidad de longitud del modo procedural
const H_DEMO: float = 0.1875          ## celda de gas de la demo en calidad low (24 / 128)
const RES_MAX: Vector3i = Vector3i(320, 192, 192)


## MODO PROCEDURAL (9/11, Pablo: «que cambios en la longitud, en el ancho, etc. sigan haciendo que se respete la estructura»). De los datos del haz del juego
## {largo (m, = 2 · semieje_x), ancho (m, radio = semieje_z), alto (m, eje = semieje_y), obstaculo ("esfera" | "caja" | "nada"), tam (m: radio de la esfera o
## semialtura de la caja, que tiene las proporciones del muro de prueba del lab 1 x 2,4 x 0,3), dist (m de la mano a la cara del obstáculo)} saca TODO lo demás:
##   · s = largo / L_CHORRO m por unidad: el chorro mide siempre lo mismo en unidades, así que la velocidad del chorro, el viento, el empuje, la flotación, el
##     enfriamiento, el arrastre y los tiempos de la demo NO cambian (la estructura a lo largo del chorro es la misma por construcción);
##   · w = (ancho / 0,15) / (largo / 3): el grosor relativo al largo → beamR0 = 0,3 w, beamR1 = 0,8 w;
##   · el obstáculo en unidades (tam / s, dist / s) y M = max(R1 / 0,8, tamaño del obstáculo / el de la demo) = la escala TRANSVERSAL de la masa: con ella se escalan
##     la piel y el tirón (wrap) del escudo, el radio y las ráfagas de la alimentación (y su punto, a 0,35 M de la piel), el bamboleo del eje y del objetivo, los
##     periodos de la turbulencia y del desgarro fino, las lenguas del toon y los márgenes del dominio;
##   · el DOMINIO: 2,6 detrás de la boquilla, 7,7 M más allá del obstáculo (o 10,8 M más allá del final del chorro sin obstáculo), 7,9 M por encima, 3,9 M a los lados;
##   · la CELDA: h = 0,1875 · clamp(min(M, R1 / 0,8), 0,5, 2): el radio del chorro tiene siempre ~4 celdas y la masa la misma resolución que en la demo. La
##     rejilla se ajusta (múltiplo de 8) y, si pasa de RES_MAX, la celda crece (se avisa en «celda_crecida»).
## Devuelve un diccionario con todo (también lo usa la prueba sin GPU).
static func derivar_haz(cfg: Dictionary) -> Dictionary:
	var c: Dictionary = HAZ_REF.duplicate()
	c.merge(cfg, true)
	var largo: float = maxf(float(c["largo"]), 0.2)
	var s: float = largo / L_CHORRO
	var w: float = (float(c["ancho"]) / 0.15) / (largo / 3.0)
	var r0: float = 0.3 * w
	var r1: float = 0.8 * w
	var nz_y: float = maxf(float(c["alto"]) / s, r1 * 0.6)
	var tipo: String = c["obstaculo"]
	var d_u: float = float(c["dist"]) / s
	var tam_u: float = float(c["tam"]) / s
	var noz: Vector3 = Vector3(0.0, nz_y, 0.0)
	var centro: Vector3 = Vector3.ZERO
	var semi: Vector3 = Vector3.ZERO        ## caja: semiejes (x a lo largo del chorro)
	var radio: float = 0.0
	var obst_tam_rel: float = 0.0
	var objetivo: Vector3
	var lejos_x: float                       ## x del final del obstáculo (o del chorro) aguas abajo
	var arriba: float                        ## y más alta del obstáculo (o del eje)
	var lado: float                          ## semiancho del obstáculo en z
	if tipo == "esfera" and d_u < L_CHORRO * 1.2:
		radio = tam_u
		centro = Vector3(-(d_u + radio), nz_y * (2.0 / 1.5), 0.0)            # como la demo: el centro un poco por encima del eje (2 frente a 1,5)
		objetivo = Vector3(-(d_u + minf(1.1, radio * 0.5)), centro.y, 0.0)   # la demo apunta 1,1 dentro de la piel
		obst_tam_rel = radio / 2.1
		lejos_x = centro.x - radio
		arriba = centro.y + radio
		lado = radio
	elif tipo == "caja" and d_u < L_CHORRO * 1.2:
		var k: float = tam_u / 1.2
		semi = Vector3(0.15, 1.2, 0.5) * k
		centro = Vector3(-(d_u + semi.x), semi.y, 0.0)
		objetivo = Vector3(-(d_u + minf(1.1, semi.x)), minf(nz_y + 0.3, semi.y * 1.8), 0.0)
		obst_tam_rel = maxf(semi.y, semi.z) / 2.4
		lejos_x = centro.x - semi.x
		arriba = semi.y * 2.0
		lado = semi.z
	elif tipo == "campo" and d_u < L_CHORRO * 1.2:
		# EN EL JUEGO: el sólido real (las casillas, la barrera...) lo pone el campo de sólidos; aquí solo su tamaño típico (tam = media casilla) y la altura de su
		# cara de arriba (alto_solido, m sobre el suelo) para el dominio y la escala de la masa. La cara está a `dist` (el tope de la lógica).
		var alto_u: float = maxf(float(c.get("alto_solido", c["tam"] * 2.0)) / s, nz_y)
		centro = Vector3(-(d_u + tam_u), alto_u * 0.5, 0.0)
		objetivo = Vector3(-(d_u + minf(1.1, tam_u * 0.5)), nz_y, 0.0)
		obst_tam_rel = tam_u / 2.1
		lejos_x = centro.x - tam_u
		arriba = alto_u
		lado = tam_u
	else:
		tipo = "nada"
		objetivo = Vector3(-L_CHORRO, nz_y + (0.0 if c.get("juego", false) else 0.5), 0.0)
		lejos_x = objetivo.x
		arriba = nz_y
		lado = 0.0
	var m: float = clampf(maxf(r1 / 0.8, obst_tam_rel), 0.4, 3.0)
	var margen_x: float = (10.8 if tipo == "nada" else 7.7) * m
	var x_lo: float = minf(lejos_x, objetivo.x) - margen_x
	var x_hi: float = 2.6
	var y_hi: float = maxf(maxf(arriba + 7.9 * m, nz_y + 6.0 * m), nz_y + (10.5 * m if tipo == "nada" else 0.0))
	var z_semi: float = maxf(6.0 * m, lado + 3.9 * m)
	var h: float = H_DEMO * clampf(minf(m, r1 / 0.8), 0.5, 2.0)
	var tam: Vector3 = Vector3(x_hi - x_lo, y_hi, 2.0 * z_semi)
	var crecida: bool = false
	var res: Vector3i = Vector3i(ceili(tam.x / h / 8.0) * 8, ceili(tam.y / h / 8.0) * 8, ceili(tam.z / h / 8.0) * 8)
	var f: float = maxf(maxf(float(res.x) / RES_MAX.x, float(res.y) / RES_MAX.y), float(res.z) / RES_MAX.z)
	if f > 1.0:
		h *= f
		crecida = true
		res = Vector3i(ceili(tam.x / h / 8.0) * 8, ceili(tam.y / h / 8.0) * 8, ceili(tam.z / h / 8.0) * 8)
	res = res.max(Vector3i(16, 16, 16))
	var tam_real: Vector3 = Vector3(res) * h
	var lo: Vector3 = Vector3(x_hi - tam_real.x, 0.0, -tam_real.z * 0.5)
	return {"cfg": c, "s": s, "w": w, "M": m, "beamR0": r0, "beamR1": r1, "nozzle": noz, "target": objetivo, "obstaculo": tipo,
		"centro": centro, "radio": radio, "semi": semi, "res": res, "h": h, "lo": lo, "tam": tam_real, "celda_crecida": crecida,
		"keyPos": Vector3(lo.x - 0.5, 1.8 * m, 1.5 * m), "d_u": d_u}


## Configuración procedural de un Hechizo REAL de haz: FuegoToy.describir (la misma regla que el juego) da el largo (x = semilargo), el eje (y) y el radio (z).
static func cfg_de_hechizo(h: Hechizo, obstaculo_: String = "esfera", tam: float = 0.8, dist_rel: float = 2.0 / 3.0) -> Dictionary:
	var d: Dictionary = FuegoToy.describir(h)
	var largo: float = float(d["x"]) * 2.0
	return {"largo": largo, "ancho": float(d["z"]), "alto": float(d["y"]), "obstaculo": obstaculo_, "tam": tam, "dist": largo * dist_rel}


## Pone el modo procedural con esta entrada y rehace la simulación (y la geometría y la vista). cfg vacío = la demo tal cual.
func configurar_haz(cfg: Dictionary) -> void:
	haz_cfg = cfg.duplicate()
	if haz_cfg.is_empty():
		haz_der = {}
		mundo_lo = HazGasSolver.WORLD_MIN
		mundo_tam = HazGasSolver.WORLD_SIZE
		res_dominio = Vector3i.ZERO
		escala_masa = 1.0
		metros_por_unidad = ESCALA_JUEGO
		muro_c = MURO_C
		muro_h = MURO_H
		params["nozzle"] = Vector3(9.4, 1.5, 0.0)
		_target_base = Vector3(-1.2, 2.0, 0.0)
		params["target"] = _target_base
		params["shieldC"] = Vector3(-2.2, 2.0, 0.0)
		params["shieldR"] = 2.1
		params["beamR0"] = 0.3
		params["beamR1"] = 0.8
		params["keyPos"] = Vector3(-12.5, 1.8, 1.5)
	else:
		var d: Dictionary = derivar_haz(haz_cfg)
		haz_der = d
		mundo_lo = d["lo"]
		mundo_tam = d["tam"]
		res_dominio = d["res"]
		escala_masa = d["M"]
		metros_por_unidad = d["s"]
		obstaculo = {"esfera": "esfera", "caja": "muro", "campo": "campo"}.get(String(d["obstaculo"]), "nada")
		if obstaculo == "muro":
			muro_c = d["centro"]
			muro_h = d["semi"]
		if obstaculo == "esfera":
			params["shieldC"] = d["centro"]
			params["shieldR"] = d["radio"]
		params["nozzle"] = d["nozzle"]
		_target_base = d["target"]
		params["target"] = _target_base
		params["beamR0"] = d["beamR0"]
		params["beamR1"] = d["beamR1"]
		params["keyPos"] = d["keyPos"]
	if is_inside_tree():
		_aplicar_geometria()
		crear_solver(calidad)
		if modo_juego:
			rehacer_solido()
		else:
			poner_vista(vista)


## EN EL JUEGO: coloca el dominio en el mundo: la boquilla en `mano`, el chorro a lo largo de `dir` (en el plano) y el suelo del dominio en `suelo`.
func colocar(mano: Vector3, dir: Vector3, suelo: float) -> void:
	var sm: float = metros_por_unidad
	var x: Vector3 = -Vector3(dir.x, 0.0, dir.z).normalized()
	var b: Basis = Basis(x * sm, Vector3.UP * sm, x.cross(Vector3.UP) * sm)
	global_transform = Transform3D(b, Vector3(mano.x, suelo, mano.z) - b * ((params["nozzle"] as Vector3) * Vector3(1, 0, 1)))


## Sube las primitivas (prims_dom) al campo de sólidos. Hace falta el UBO con el dominio: se sube antes.
func rehacer_solido() -> void:
	if not listo():
		return
	RenderingServer.call_on_render_thread(solver.solo_parametros.bind(parametros_gpu(frame * DT)))
	RenderingServer.call_on_render_thread(solver.rehacer_solido.bind(prims_dom))


## Rehace las mallas del obstáculo, el defensor y el acantilado con el dominio y el obstáculo de ahora.
func _aplicar_geometria() -> void:
	if _muro == null:
		return
	(_muro.mesh as BoxMesh).size = muro_h * 2.0
	_muro.position = muro_c
	_muro.visible = obstaculo == "muro"
	var sm: SphereMesh = _esfera.mesh as SphereMesh
	sm.radius = float(params["shieldR"])
	sm.height = float(params["shieldR"]) * 2.0
	_esfera.position = params["shieldC"]
	_acantilado.position = Vector3(0, 20, mundo_lo.z)
	_defensor.position = Vector3((params["shieldC"] as Vector3).x - 0.2, 0, 0) if obstaculo != "muro" else Vector3(muro_c.x - muro_h.x - 0.9, 0, 0)
	_aplicar_dibujo()


## Cambia un valor de la entrada procedural (×f) y rehace. Lo usan las teclas U/J, I/K, O/L, N/M, V/F.
func cambiar_haz(clave: String, f: float) -> void:
	var c: Dictionary = HAZ_REF.duplicate() if haz_cfg.is_empty() else haz_cfg.duplicate()
	c[clave] = clampf(float(c[clave]) * f, 0.05, 30.0)
	configurar_haz(c)


func _texto_haz() -> String:
	if haz_der.is_empty():
		return "configuración EXACTA de la demo (U/J I/K O/L para pasar al modo procedural)"
	var c: Dictionary = haz_der["cfg"]
	var r: Vector3i = haz_der["res"]
	return "HAZ largo %.2f m (U/J) · alto %.2f (I/K) · ancho %.2f (O/L) · obstáculo %s (B) tam %.2f (N/M) a %.2f m (V/F)  →  %.3f m/u · M %.2f · R %.2f→%.2f u · rejilla %dx%dx%d, celda %.3f u%s" % [
		float(c["largo"]), float(c["alto"]), float(c["ancho"]), String(haz_der["obstaculo"]), float(c["tam"]), float(c["dist"]), float(haz_der["s"]),
		float(haz_der["M"]), float(haz_der["beamR0"]), float(haz_der["beamR1"]), r.x, r.y, r.z, float(haz_der["h"]), " (CELDA CRECIDA: tope de rejilla)" if haz_der["celda_crecida"] else ""]


## «esfera»: el escudo de la demo (invisible: lo dibuja el gas). «muro»: la caja del lab. Vacía el gas (si no, queda gas dentro del nuevo sólido).
func poner_obstaculo(tipo: String) -> void:
	obstaculo = tipo
	if _muro != null:
		_muro.visible = tipo == "muro"
	if _esfera != null:
		_aplicar_dibujo()
	if _defensor != null:
		_defensor.position = Vector3((params["shieldC"] as Vector3).x - 0.2, 0, 0) if tipo != "muro" else Vector3(muro_c.x - muro_h.x - 0.9, 0, 0)
	if listo():
		crear_solver(calidad)


func poner_vista(v: String) -> void:
	vista = v if v in VISTAS else "demo"
	var de_juego: bool = vista in ["juego", "lateral"] and camara_juego != null and is_instance_valid(camara_juego)
	if de_juego:
		# La boquilla delante de la jugadora, el chorro a lo largo de su dirección y el suelo del dominio en su suelo. ESCALA_JUEGO deja el chorro
		# (boquilla → piel del escudo, 9,5 m en la demo) en ~3,3 m, el largo del haz del juego; la boquilla queda a 0,5 m del suelo (la mano está a 0,7).
		var s: float = metros_por_unidad
		var x: Vector3 = -dir_juego.normalized()
		var b: Basis = Basis(x * s, Vector3.UP * s, x.cross(Vector3.UP) * s)
		var en_suelo: Vector3 = Vector3(mano_juego.x, 0.0, mano_juego.z)
		global_transform = Transform3D(b, en_suelo - b * ((params["nozzle"] as Vector3) * Vector3(1, 0, 1)))
		if vista == "juego":
			camara_juego.compositor = _compositor
			camara_juego.make_current()
			_cam.compositor = null
		else:
			camara_juego.compositor = null
			_cam.compositor = _compositor
			_cam.make_current()
			camara_en_lateral()
	else:
		global_transform = Transform3D.IDENTITY
		if camara_juego != null and is_instance_valid(camara_juego) and camara_juego.compositor == _compositor:
			camara_juego.compositor = null
		_cam.compositor = _compositor
		_cam.fov = 32.0
		_cam.make_current()
	if jugadora_juego != null and is_instance_valid(jugadora_juego):
		jugadora_juego.visible = de_juego
	_aplicar_dibujo()
	if vista != "lateral":
		_colocar_camara()


## Cámara propia en coordenadas de MUNDO (las capturas del toon la ponen igual que la del FuegoToy del lab).
func camara_mundo(desde: Vector3, mira: Vector3, fov: float = 60.0) -> void:
	_cam.fov = fov
	_cam.global_position = desde
	_cam.look_at(mira, Vector3.UP)


## Vista «lateral»: de lado al chorro y algo alta, a escala de juego (como las capturas laterales del haz del juego: herramientas/captura_haz_masa.gd).
func camara_en_lateral() -> void:
	_cam.fov = 40.0
	if not haz_der.is_empty():
		# modo procedural: de lado al tramo boquilla → masa, a una distancia que lo abarca entero (el encuadre escala con el hechizo)
		var noz: Vector3 = haz_der["nozzle"]
		var fin: Vector3 = haz_der["target"]
		var m: float = float(haz_der["M"])
		var centro: Vector3 = (noz + fin) * 0.5 + Vector3(-1.5 * m, 1.2 * m, 0.0)
		var d: float = (noz.x - fin.x) * 0.85 + 9.0 * m
		_cam.global_transform = global_transform * Transform3D(Basis(), centro + Vector3(0.0, 0.3 * d, d))
		_cam.look_at(global_transform * centro, Vector3.UP)
		return
	_cam.global_transform = global_transform * Transform3D(Basis(), Vector3(2.0, 6.5, 19.0))
	_cam.look_at(global_transform * Vector3(1.5, 2.2, 0.0), Vector3.UP)


## R: dibujo toon (lenguaje de FuegoToy, entorno normal del lab) o realista (el de la demo, escenario negro). La simulación no se toca.
func poner_toon(si: bool) -> void:
	toon = si
	_aplicar_dibujo()
	dibujo_cambiado.emit(toon)


## Qué se ve de la escena de la demo según el dibujo y la vista. Toon: nada del escenario negro (ni roca, ni acantilado, ni siluetas): el suelo y el sol son los del
## lab, la esfera y el muro llevan el gris del muro de prueba del lab y las chispas el color de las del FuegoToy.
func _aplicar_dibujo() -> void:
	if _suelo == null:
		return
	var de_juego: bool = vista in ["juego", "lateral"] and camara_juego != null
	_suelo.visible = not toon
	_acantilado.visible = not toon and not de_juego
	_atacante.visible = not toon and not de_juego
	_defensor.visible = not toon
	_esfera.visible = toon and obstaculo == "esfera"
	_muro.material_override = _mat_lab if toon else _mat_muro_roca
	_chispas_mi.material_override = _mat_chispas_toon if toon else _mat_chispas_real
	_mat_chispas = _chispas_mi.material_override as ShaderMaterial
	if modo_juego:                                   # en el juego solo se ve el gas y sus chispas: el resto de la escena de la demo no existe
		for n in [_suelo, _acantilado, _atacante, _defensor, _esfera, _muro]:
			(n as Node3D).visible = false


func chorro(encendido: bool) -> void:
	params["beamOn"] = 1.0 if encendido else 0.0


func entorno() -> Environment:
	if _env == null:
		_env = Environment.new()
		_env.background_mode = Environment.BG_COLOR
		_env.background_color = Color(0, 0, 0)
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = Color(0, 0, 0)
		_env.ambient_light_energy = 0.0
		_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		# renderer.toneMapping = ACESFilmicToneMapping con exposición 0,85. El ACESFilmic de three hace color · exposición / 0,6 y el ajuste de Hill; el ACES de
		# Godot hace el MISMO ajuste con color · 1,8 · exposición y divide por el blanco mapeado. 1,8 · 0,787 = 0,85 / 0,6 y blanco 16 (el ajuste ya está en su asíntota).
		_env.tonemap_mode = Environment.TONE_MAPPER_ACES
		_env.tonemap_exposure = 0.85 / 0.6 / 1.8
		_env.tonemap_white = 16.0
		# bloom(min(hdr, 9), 0.32, 0.55, 1.1) de main.js: en Godot, el glow (umbral 1,1, aditivo, niveles medios y anchos)
		_env.glow_enabled = true
		_env.glow_hdr_threshold = 1.1
		_env.glow_hdr_luminance_cap = 9.0
		_env.glow_intensity = 0.32
		_env.glow_strength = 1.0
		_env.glow_bloom = 0.0
		_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		for i in 7:
			_env.set_glow_level(i, [0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.6][i])
	return _env


# ------------------------------------------------------------------------------------------------------------------------------------------------ bucle

func _process(delta: float) -> void:
	if not listo():
		return
	# Un paso de simulación por cada 1/60 s, sea cual sea la pantalla (main.js loop: now - lastStep >= DT * 900 ms).
	_acum += delta
	if not pausa and _acum >= DT * 0.9:
		_acum = 0.0
		var t: float = frame * DT
		var tg: Vector3 = params["target"]
		tg.y = _target_base.y + sin(t * 0.7) * 0.5 * escala_masa
		tg.z = _target_base.z + sin(t * 0.43) * 0.7 * escala_masa
		params["target"] = tg
		var datos: PackedFloat32Array = parametros_gpu(t)
		RenderingServer.call_on_render_thread(solver.paso.bind(datos, true, not toon))     # el toon no usa la luz por volúmenes
		frame += 1
	if vista == "orbita":
		_mover_camara(frame * DT)
	elif vista == "juego" and camara_juego != null and is_instance_valid(camara_juego):
		if not camara_juego.current:
			camara_juego.make_current()
	var m2d: Transform3D = global_transform.affine_inverse()
	efecto.mundo_a_dominio = m2d
	var cam_act: Camera3D = get_viewport().get_camera_3d()
	if cam_act != null:
		efecto.proyeccion = cam_act.get_camera_projection()
		efecto.camara = cam_act.global_transform
	efecto.temporal = temporal
	efecto.toon = toon
	if toon:
		var tp: Dictionary = toon_params
		efecto.toon_param = PackedFloat32Array([tp["umbral"], tp["blandura"], tp["contraste"], tp["tope"], tp["k_T"], tp["k_c"], tp["amplitud"], float(tp["escala"]) / escala_masa,
			tp["umbral_humo"], tp["opacidad_humo"], tp["escala_rampa"], frame * DT, tp["sube"], tp["chisporroteo"], tp["profundidad"], mundo_tam.x / float(solver.res.x)])
		var rids: Array[RID] = []
		for tx in _toon_tex:
			var r: RID = RenderingServer.texture_get_rd_texture((tx as Texture2D).get_rid()) if tx != null else RID()
			if r.is_valid():
				rids.append(r)
		efecto.toon_tex = rids
	efecto.aspecto = PackedFloat32Array([params["thickness"], params["relief"], params["edge"], params["smokeAlbedo"], params["flameBody"], params["emitGain"],
		params["fireOnSmoke"], params["farOnSmoke"], params["lampOnSmoke"], 1.0 if toon else params["saturacion"], 0.0 if toon else params["vineta"]])
	var m2d_p: Projection = Projection(m2d)
	for m in _mat_roca:
		m.set_shader_parameter("mundo_a_dominio", m2d_p)
		m.set_shader_parameter("mundo_lo", mundo_lo)
		m.set_shader_parameter("mundo_tam", mundo_tam)
		m.set_shader_parameter("fire_on_rock", params["fireOnRock"])
		m.set_shader_parameter("lamp_on_rock", params["lampOnRock"])
		m.set_shader_parameter("key_pos", params["keyPos"])
	for mc in [_mat_chispas_real, _mat_chispas_toon]:
		mc.set_shader_parameter("dominio_a_mundo", Projection(global_transform))
	_mat_chispas.set_shader_parameter("paleta", params["paleta"])
	_medir(delta)


## El bloque Parametros de gas_comun.glslinc (16 vec4).
func parametros_gpu(t: float) -> PackedFloat32Array:
	var p: Dictionary = params
	var noz: Vector3 = p["nozzle"]
	var tg: Vector3 = p["target"]
	var tipo: float = {"esfera": 0.0, "muro": 1.0, "campo": 3.0}.get(obstaculo, 2.0)
	if modo_juego and not prims_dom.is_empty():
		tipo = 3.0                  # en el juego el mundo real cuenta SIEMPRE (árboles y escalones junto a un haz que acaba al aire), haya tope o no
	var c: Vector3 = muro_c if obstaculo == "muro" else p["shieldC"]
	var h: Vector3 = muro_h
	var cont: Vector3 = contacto()
	var kp: Vector3 = p["keyPos"]
	return PackedFloat32Array([
		noz.x, noz.y, noz.z, p["beamOn"],
		tg.x, tg.y, tg.z, p["beamSpeed"],
		c.x, c.y, c.z, tipo,
		h.x, h.y, h.z, p["shieldR"],
		1.0, 0.0, 0.0, float(p["wrap"]) * escala_masa,
		0.0, 1.0, 0.0, t,
		0.0, 0.0, 1.0, DT,
		cont.x, cont.y, cont.z, p["beamR0"],
		p["beamR1"], p["burnRate"], p["heat"], p["sootYield"],
		p["expansion"], p["cool"], p["sootFade"], p["dustFade"],
		p["buoyancy"], p["weight"], p["drag"], p["wind"],
		p["push"], p["confine"], p["subgrid"], p["viscosity"],
		p["turbulence"], p["paleta"], 1.0 if _acantilado == null or _acantilado.visible else 0.0, escala_masa,
		kp.x, kp.y, kp.z, 0.0,
		mundo_lo.x, mundo_lo.y, mundo_lo.z, 0.0,
		mundo_tam.x, mundo_tam.y, mundo_tam.z, 0.0])


## Distancia con signo al obstáculo y su normal (la misma que obst_sd de gas_comun.glslinc). [sd, n]
func sd_obstaculo(w: Vector3) -> Array:
	if obstaculo == "esfera":
		var d: Vector3 = w - (params["shieldC"] as Vector3)
		var l: float = d.length()
		return [l - float(params["shieldR"]), d / maxf(l, 0.001)]
	if obstaculo == "campo" or (modo_juego and not prims_dom.is_empty()):
		return sd_prims(prims_dom, w)
	if obstaculo != "muro":
		return [1000.0, Vector3.UP]
	var q: Vector3 = w - muro_c
	var hq: Vector3 = q.abs() - muro_h
	var afuera: float = hq.max(Vector3.ZERO).length()
	var dentro: float = minf(maxf(hq.x, maxf(hq.y, hq.z)), 0.0)
	var n: Vector3
	if afuera > 0.0:
		n = q.sign() * hq.max(Vector3.ZERO) / afuera
	elif hq.x > hq.y and hq.x > hq.z:
		n = Vector3(signf(q.x), 0, 0)
	elif hq.y > hq.z:
		n = Vector3(0, signf(q.y), 0)
	else:
		n = Vector3(0, 0, signf(q.z))
	return [afuera + dentro, n]


## La misma distancia que solido.glsl, en la CPU (pruebas y punto de contacto): [sd, n] del mínimo sobre las primitivas.
static func sd_prims(pr: PackedFloat32Array, w: Vector3) -> Array:
	var mejor: float = 1000.0
	var nm: Vector3 = Vector3.UP
	for i in range(0, pr.size() - 11, 12):
		var a: Vector3 = Vector3(pr[i], pr[i + 1], pr[i + 2])
		var b: Vector3 = Vector3(pr[i + 4], pr[i + 5], pr[i + 6])
		var sd: float
		var n: Vector3
		if pr[i + 3] < 0.5:
			var ex: Vector3 = Vector3(pr[i + 8], 0.0, pr[i + 9])
			var ez: Vector3 = Vector3(pr[i + 10], 0.0, pr[i + 11])
			var d: Vector3 = w - a
			var l: Vector3 = Vector3(d.dot(ex), d.y, d.dot(ez))
			var hq: Vector3 = l.abs() - b
			var afuera: float = hq.max(Vector3.ZERO).length()
			sd = afuera + minf(maxf(hq.x, maxf(hq.y, hq.z)), 0.0)
			var gl: Vector3
			if afuera > 0.0:
				gl = l.sign() * hq.max(Vector3.ZERO) / afuera
			elif hq.x > hq.y and hq.x > hq.z:
				gl = Vector3(signf(l.x), 0, 0)
			elif hq.y > hq.z:
				gl = Vector3(0, signf(l.y), 0)
			else:
				gl = Vector3(0, 0, signf(l.z))
			n = ex * gl.x + Vector3(0, gl.y, 0) + ez * gl.z
		else:
			var pa: Vector3 = w - a
			var ba: Vector3 = b - a
			var hh: float = clampf(pa.dot(ba) / maxf(ba.dot(ba), 1e-6), 0.0, 1.0)
			var v: Vector3 = pa - ba * hh
			n = v.normalized() if v.length() > 1e-4 else Vector3.UP
			sd = v.length() - pr[i + 7]
		if sd < mejor:
			mejor = sd
			nm = n
	return [mejor, nm]


## sources.js: contact = shieldC + normalize(nozzle - shieldC) * (R + 0,35). Con SDF: el punto de la piel más cercano a la boquilla, a 0,35 m hacia fuera.
func contacto() -> Vector3:
	var noz: Vector3 = params["nozzle"]
	if obstaculo == "nada":
		return params["target"]
	if obstaculo == "campo" and not haz_der.is_empty():
		return Vector3(-(float(haz_der["d_u"]) - 0.35 * escala_masa), noz.y, 0.0)          # 0,35 M delante de la cara que dice la lógica
	var r: Array = sd_obstaculo(noz)
	return noz - (r[1] as Vector3) * (float(r[0]) - 0.35 * escala_masa)


func _medir(delta: float) -> void:
	_t_medida += delta
	_n_medida += 1
	var tg: Dictionary = solver.tiempos_gpu()
	for k in tg:
		_acum_gpu[k] = float(_acum_gpu.get(k, 0.0)) + float(tg[k])
	_acum_gpu["_n"] = int(_acum_gpu.get("_n", 0)) + (1 if not tg.is_empty() else 0)
	var vp: float = RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	_acum_gpu["_vp"] = float(_acum_gpu.get("_vp", 0.0)) + vp
	if _t_medida >= 0.5:
		var n: int = maxi(int(_acum_gpu.get("_n", 0)), 1)
		gpu_ms = {}
		for k in _acum_gpu:
			if not String(k).begins_with("_"):
				gpu_ms[k] = float(_acum_gpu[k]) / n
		gpu_viewport_ms = float(_acum_gpu["_vp"]) / _n_medida
		var fps: float = _n_medida / _t_medida
		_t_medida = 0.0
		_n_medida = 0
		_acum_gpu.clear()
		if _linea != null:
			var r: Vector3i = solver.res
			_linea.text = "%s %dx%dx%d  %.1fM celdas  %d fps  gpu %.1f ms (sim %.1f · luz %.1f · chispas %.2f · volumen %.1f · fotograma entero %.1f)  %s · paleta %s%s%s\n" % [
				calidad, r.x, r.y, r.z, solver.celdas / 1.0e6, roundi(fps), float(gpu_ms.get("total", 0.0)),
				float(gpu_ms.get("gas", 0.0)) + float(gpu_ms.get("velocidad", 0.0)), float(gpu_ms.get("luz", 0.0)), float(gpu_ms.get("chispas", 0.0)),
				float(gpu_ms.get("volumen", 0.0)), gpu_viewport_ms, obstaculo, "pablo" if float(params["paleta"]) > 0.5 else "demo", " · CHORRO APAGADO" if float(params["beamOn"]) < 0.5 else "", " · PAUSA" if pausa else ""] + _texto_haz()


# ------------------------------------------------------------------------------------------------------------------------------------------------ cámara

## main.js moveCamera: vuelta lenta alrededor del escenario, baja y a tres cuartos.
func _mover_camara(t: float) -> void:
	var a: float = 0.1 + sin(t * 0.13) * 0.32
	_cam.global_transform = global_transform * Transform3D(Basis(), Vector3(1.4 + sin(a) * 23.0, 4.6 + sin(t * 0.21) * 1.4, cos(a) * 23.0))
	_cam.look_at(global_transform * Vector3(1.4, 2.4, 0.0), Vector3.UP)


func _colocar_camara() -> void:
	if vista == "juego" or _cam == null:
		return
	var foco: Vector3 = Vector3(1.4, 2.4, 0.0)
	var o: Vector3 = Vector3(sin(_orbita.x) * cos(_orbita.y), sin(_orbita.y), cos(_orbita.x) * cos(_orbita.y)) * _orbita.z
	_cam.global_transform = global_transform * Transform3D(Basis(), foco + o)
	_cam.look_at(global_transform * foco, Vector3.UP)


## Cámara fija dada en coordenadas del DOMINIO (para las capturas).
func camara_en(desde: Vector3, mira: Vector3, fov: float = 32.0) -> void:
	vista = "demo"
	_cam.fov = fov
	_cam.global_transform = global_transform * Transform3D(Basis(), desde)
	_cam.look_at(global_transform * mira, Vector3.UP)


func _input(ev: InputEvent) -> void:
	if modo_juego:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: InputEventKey = ev as InputEventKey
		if k.keycode == KEY_F12:
			return                       # Mayús+F12 lo maneja el lab (cambia de obstáculo o sale)
		var usada: bool = true
		match k.keycode:
			KEY_SPACE:
				chorro(float(params["beamOn"]) < 0.5)    # main.js beamToggled
			KEY_C:
				poner_vista(VISTAS[(VISTAS.find(vista) + 1) % VISTAS.size()] if camara_juego != null else ("orbita" if vista == "demo" else "demo"))
			KEY_U:
				cambiar_haz("largo", 1.2)
			KEY_J:
				cambiar_haz("largo", 1.0 / 1.2)
			KEY_I:
				cambiar_haz("alto", 1.2)
			KEY_K:
				cambiar_haz("alto", 1.0 / 1.2)
			KEY_O:
				cambiar_haz("ancho", 1.2)
			KEY_L:
				cambiar_haz("ancho", 1.0 / 1.2)
			KEY_N:
				cambiar_haz("tam", 1.0 / 1.2)
			KEY_M:
				cambiar_haz("tam", 1.2)
			KEY_V:
				cambiar_haz("dist", 1.0 / 1.2)
			KEY_F:
				cambiar_haz("dist", 1.2)
			KEY_B:
				if haz_cfg.is_empty():
					poner_obstaculo("muro" if obstaculo == "esfera" else "esfera")
				else:
					var c: Dictionary = haz_cfg.duplicate()
					c["obstaculo"] = {"esfera": "caja", "caja": "nada"}.get(String(c.get("obstaculo", "esfera")), "esfera")
					configurar_haz(c)
			KEY_1:
				crear_solver("low")
			KEY_2:
				crear_solver("med")
			KEY_3:
				crear_solver("high")
			KEY_4:
				crear_solver("ultra")
			KEY_T:
				temporal = not temporal
			KEY_R:
				poner_toon(not toon)
			KEY_Y:
				params["paleta"] = 0.0 if float(params["paleta"]) > 0.5 else 1.0
			KEY_P:
				pausa = not pausa
			KEY_H:
				mostrar_hud = not mostrar_hud
				_hud.visible = mostrar_hud
			_:
				usada = false
		if usada:
			get_viewport().set_input_as_handled()


func _unhandled_input(ev: InputEvent) -> void:
	if modo_juego:
		return
	if vista == "juego":
		return
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_arrastrando = mb.pressed
			if mb.pressed and vista == "orbita":
				vista = "demo"                 # la vuelta automática para en cuanto se coge la cámara (main.js cameraGrabbed)
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_orbita.z = clampf(_orbita.z * (0.92 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.08), 7.0, 45.0)
			_colocar_camara()
	elif ev is InputEventMouseMotion and _arrastrando:
		var mm: InputEventMouseMotion = ev as InputEventMouseMotion
		_orbita.x -= mm.relative.x * 0.006
		_orbita.y = clampf(_orbita.y + mm.relative.y * 0.006, 0.02, PI * 0.49)        # maxPolarAngle 0,49 π: siempre por encima del suelo
		_colocar_camara()


# ------------------------------------------------------------------------------------------------------------------------------------------------ escena

func _montar_escena() -> void:
	var roca: Texture2D = load("res://laboratorios/haz_gas/roca_1024.png") as Texture2D
	var sh: Shader = load("res://laboratorios/haz_gas/haz_gas_roca.gdshader") as Shader
	# stage.js: suelo de 90 x 90 y acantilado de 90 x 40 en z = -6
	_suelo = MeshInstance3D.new()
	_suelo.name = "SueloGas"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(90, 90)
	_suelo.mesh = pm
	_suelo.material_override = _roca(sh, roca, 0, 2.2)
	add_child(_suelo)
	_acantilado = MeshInstance3D.new()
	_acantilado.name = "Acantilado"
	var pa: PlaneMesh = PlaneMesh.new()
	pa.size = Vector2(90, 40)
	pa.orientation = PlaneMesh.FACE_Z
	_acantilado.mesh = pa
	_acantilado.position = Vector3(0, 20, mundo_lo.z)
	_acantilado.material_override = _roca(sh, roca, 1, 4.0)
	add_child(_acantilado)
	_muro = MeshInstance3D.new()
	_muro.name = "MuroGas"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = muro_h * 2.0
	_muro.mesh = bm
	_muro.position = muro_c
	_mat_muro_roca = _roca(sh, roca, 2, 3.0)
	_muro.material_override = _mat_muro_roca
	_muro.visible = false
	add_child(_muro)
	# Modo toon: la esfera y el muro con el gris del muro de prueba del lab (lab_vfx_comparativa_3d.gd _muro_haz), iluminados por el sol del lab.
	_mat_lab = StandardMaterial3D.new()
	_mat_lab.albedo_color = Color(0.5, 0.5, 0.52)
	_mat_lab.roughness = 0.95
	_esfera = MeshInstance3D.new()
	_esfera.name = "EsferaGas"
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = float(params["shieldR"])
	sm.height = float(params["shieldR"]) * 2.0
	_esfera.mesh = sm
	_esfera.position = params["shieldC"]
	_esfera.material_override = _mat_lab
	_esfera.visible = false
	add_child(_esfera)
	# figures.js
	var mat_fig: ShaderMaterial = ShaderMaterial.new()
	mat_fig.shader = load("res://laboratorios/haz_gas/haz_gas_figura.gdshader") as Shader
	_defensor = _figura(1.0, mat_fig)
	_defensor.name = "Defensor"
	_defensor.position = Vector3((params["shieldC"] as Vector3).x - 0.2, 0, 0)
	add_child(_defensor)
	_atacante = _jugadora_atacante(mat_fig)
	# sparks.js: 1000 quads instanciados
	_mat_chispas_real = ShaderMaterial.new()
	_mat_chispas_real.shader = load("res://laboratorios/haz_gas/haz_gas_chispas.gdshader") as Shader
	_mat_chispas_toon = ShaderMaterial.new()
	_mat_chispas_toon.shader = load("res://laboratorios/haz_gas/haz_gas_chispas_toon.gdshader") as Shader
	_mat_chispas = _mat_chispas_real
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = HazGasSolver.N_CHISPAS
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
	mm.custom_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
	_chispas_mi = MultiMeshInstance3D.new()
	_chispas_mi.name = "Chispas"
	_chispas_mi.multimesh = mm
	_chispas_mi.material_override = _mat_chispas
	_chispas_mi.custom_aabb = mm.custom_aabb
	_chispas_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_chispas_mi)


func _roca(sh: Shader, tex: Texture2D, modo: int, llanura: float) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("roca", tex)
	m.set_shader_parameter("modo", modo)
	m.set_shader_parameter("llanura", llanura)
	m.set_shader_parameter("mundo_lo", mundo_lo)
	m.set_shader_parameter("mundo_tam", mundo_tam)
	m.set_shader_parameter("mundo_a_dominio", Projection(Transform3D.IDENTITY))
	_mat_roca.append(m)
	return m


## figures.js figure(reach): postura apoyada mirando a +x con reach 1; los dos brazos empujan hacia el otro. Unos 1,8 m. Cápsulas: solo se leen como sombras contra el fuego.
func _figura(reach: float, mat: Material) -> Node3D:
	var g: Node3D = Node3D.new()
	var f: Callable = func(x: float) -> float: return x * reach
	var miembros: Array = [
		[[f.call(-0.05), 0.95, 0], [f.call(0.08), 1.42, 0], 0.17],
		[[f.call(-0.05), 0.92, 0.1], [f.call(-0.42), 0.48, 0.16], 0.075],
		[[f.call(-0.42), 0.48, 0.16], [f.call(-0.5), 0.04, 0.18], 0.065],
		[[f.call(-0.05), 0.92, -0.1], [f.call(0.32), 0.5, -0.14], 0.075],
		[[f.call(0.32), 0.5, -0.14], [f.call(0.28), 0.04, -0.16], 0.065],
		[[f.call(0.08), 1.5, 0.16], [f.call(0.52), 1.42, 0.12], 0.055],
		[[f.call(0.52), 1.42, 0.12], [f.call(0.9), 1.5, 0.04], 0.05],
		[[f.call(0.08), 1.5, -0.16], [f.call(0.5), 1.38, -0.12], 0.055],
		[[f.call(0.5), 1.38, -0.12], [f.call(0.9), 1.48, -0.04], 0.05]]
	for mb in miembros:
		var a: Vector3 = Vector3(mb[0][0], mb[0][1], mb[0][2])
		var b: Vector3 = Vector3(mb[1][0], mb[1][1], mb[1][2])
		var r: float = mb[2]
		var mi: MeshInstance3D = MeshInstance3D.new()
		var cm: CapsuleMesh = CapsuleMesh.new()
		cm.radius = r
		cm.height = a.distance_to(b) + 2.0 * r          # CapsuleGeometry(r, largo) de three: largo = el tramo recto
		mi.mesh = cm
		mi.material_override = mat
		mi.position = (a + b) * 0.5
		mi.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
		g.add_child(mi)
	var cabeza: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.26
	cabeza.mesh = sm
	cabeza.material_override = mat
	cabeza.position = Vector3(f.call(0.12), 1.72, 0)
	g.add_child(cabeza)
	return g


## El atacante: la jugadora del juego (Pj3D, 1,8 m como la silueta de la demo, con el material de silueta) junto a la boquilla mirando al escudo.
## Si no carga el modelo, la silueta de cápsulas de la demo (figure(-1)).
func _jugadora_atacante(mat: Material) -> Node3D:
	var noz: Vector3 = params["nozzle"]
	var pj: Pj3D = Pj3D.new()
	pj.name = "Atacante"
	add_child(pj)
	if pj.cargar("jugadora_base"):
		pj.set_alto(1.8)
		pj.position = Vector3(noz.x + 0.55, 0.0, noz.z)
		pj.rotation.y = -PI * 0.5           # los modelos miran a +Z: así mira a -X (al escudo)
		for mi in pj.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
		pj.apagar_sombra()                  # la mancha de contacto del juego: aquí el suelo lo ilumina solo el fuego
		if pj._arbol != null:
			pj._arbol.active = false
		if pj._ap != null:
			pj._ap.active = true
			for rol in ["cast_empuje", "cast_mano_frente", "cast", "idle"]:        # el empuje a dos manos, como la silueta de la demo
				var c: String = pj.clip_de(rol)
				if c != "":
					pj._ap.play(c)
					break
		return pj
	remove_child(pj)
	pj.queue_free()
	var g: Node3D = _figura(-1.0, mat)
	g.name = "Atacante"
	g.position = Vector3(noz.x + 0.95, 0.02, noz.z)
	add_child(g)
	return g


# ------------------------------------------------------------------------------------------------------------------------------------------------ HUD (hud.js)

func _montar_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HudGas"
	_hud.layer = 20
	add_child(_hud)
	var fuente_col: Color = Color(0.81, 0.84, 0.9)
	_linea = Label.new()
	_linea.position = Vector2(12, 8)
	_linea.add_theme_font_size_override("font_size", 13)
	_linea.add_theme_color_override("font_color", fuente_col)
	_linea.text = "%s  compilando los shaders..." % calidad
	_hud.add_child(_linea)
	_ayuda = Label.new()
	_ayuda.anchor_top = 1.0
	_ayuda.anchor_bottom = 1.0
	_ayuda.offset_left = 12
	_ayuda.offset_top = -26
	_ayuda.add_theme_font_size_override("font_size", 12)
	_ayuda.add_theme_color_override("font_color", Color(fuente_col, 0.6))
	_ayuda.text = AYUDA
	_hud.add_child(_ayuda)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -222
	panel.offset_right = -12
	panel.offset_top = 10
	panel.add_theme_constant_override("separation", 2)
	_hud.add_child(panel)
	for d in MANDOS:
		var et: Label = Label.new()
		et.add_theme_font_size_override("font_size", 12)
		et.add_theme_color_override("font_color", fuente_col)
		var sl: HSlider = HSlider.new()
		sl.min_value = 0.0
		sl.max_value = float(d[2])
		sl.step = float(d[2]) / 200.0
		sl.value = float(params[d[0]])
		sl.custom_minimum_size = Vector2(210, 16)
		sl.focus_mode = Control.FOCUS_NONE
		var nombre: String = d[0]
		var mostrar: Callable = func(v: float) -> void:
			et.text = "%s %s" % [d[1], ("%.3f" % v) if float(d[2]) < 1.0 else ("%.1f" % v)]
		sl.value_changed.connect(func(v: float) -> void:
			params[nombre] = v
			mostrar.call(v))
		mostrar.call(sl.value)
		panel.add_child(et)
		panel.add_child(sl)
		_sliders[nombre] = sl


## Pone un mando como si se moviera su barra (pruebas y capturas).
func poner_mando(nombre: String, v: float) -> void:
	if _sliders.has(nombre):
		(_sliders[nombre] as HSlider).value = v
	params[nombre] = v
