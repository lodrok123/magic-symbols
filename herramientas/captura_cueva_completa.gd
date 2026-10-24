extends "res://herramientas/escenario_base.gd"
## LA CUEVA, DE INICIO A FIN (24/10, fase 3 del Pulso resonante): las fotos de lo nuevo. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_cueva_completa.gd -- [carpeta] [luz]   (por defecto res://docs/capturas/cueva_completa, con .gdignore; `luz` = solo la parte 1)
## 1 · LA CUEVA EN AZUL, antes y después: cada sala (C1…C6) con la luz de antes (el preset `cueva` y las luces del Bosque `fuego`, `atardecer`, `hielo` y `ruinas`) y con la de ahora, y la media de
##     color de cada foto (se imprime: es lo que dice si la sala se «lee azul»).
## 2 · Los reactivos de la fase 3: setas que maduran, braseros con su luz, pulso de fuego al brasero, enlace de tierra, columna que cae, nicho, cascada, puente de basalto, goblin aturdido, estatuas,
##     cofre épico y legendario con su columna de luz y las motas al abrirse.
## Solo mira; los contratos los comprueba `escenario_cueva_completa.gd`.

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const SALAS: Dictionary = {"C1": Vector2i(4, 14), "C2": Vector2i(4, 4), "C3": Vector2i(11, 4), "C4": Vector2i(22, 4), "C5": Vector2i(22, 18), "C6": Vector2i(13, 15)}
const LUZ_VIEJA_DE: Dictionary = {"C1": "cueva", "C2": "cueva", "C3": "fuego", "C4": "atardecer", "C5": "hielo", "C6": "ruinas"}
## El preset `cueva` de antes del 24/10 (el de ahora está en LuzZona3D): gris azulado, casi sin azul.
const CUEVA_VIEJA: Dictionary = {
	"sol_color": Color(0.62, 0.70, 0.86), "sol_energia": 0.35, "sol_pitch": -78.0, "sol_yaw": 10.0,
	"ambiente_arriba": Color(0.42, 0.48, 0.60), "ambiente_abajo": Color(0.26, 0.26, 0.30), "ambiente_energia": 0.45,
}
const TAM_SALA: float = 11.0
const T_LUZ_S: float = 2.0                       ## que entre la luz de la zona (mezcla 0,8 s) y se asiente

var _dir: String = "res://docs/capturas/cueva_completa"
var _z: Puzle3D = null
var _zonas: Zonas3D = null
var _cam: Camera3D = null
var _medias: Dictionary = {}


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "" and a[0] != "luz":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	await avanzar(30)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_zonas = maqueta.get_node_or_null("Zonas3D") as Zonas3D
	_cam = maqueta.get("_camara") as Camera3D
	_ok("0 la Cueva monta sin avisos", _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "")
	await _general_viejo()
	await _general_nuevo()
	_imprimir_medias()
	if OS.get_cmdline_user_args().has("luz"):
		return                                  # solo la parte 1 (la luz): para afinar los presets sin esperar a los reactivos
	await _c1()
	await _c2()
	await _c3()
	await _c4()
	await _c6()


# ---------------------------------------------------------------------------------------------------------------------
#  1 · La Cueva en azul, antes y después
# ---------------------------------------------------------------------------------------------------------------------

## Con la luz de ANTES: el preset `cueva` viejo y las luces del Bosque en C3–C6. `LuzZona3D.ZONAS` es una constante: se pone la luz a mano (`aplicar_valores`) con las Zonas3D paradas.
func _general_viejo() -> void:
	_zonas.set_process(false)
	var env: Environment = maqueta.get("_env") as Environment
	var sol: DirectionalLight3D = maqueta.get("_sol") as DirectionalLight3D
	for nombre in SALAS:
		var luz: String = String(LUZ_VIEJA_DE[nombre])
		var v: Dictionary = LuzZona3D.valores(luz)
		if luz == "cueva":
			v = {"sol_color": CUEVA_VIEJA["sol_color"], "sol_energia": CUEVA_VIEJA["sol_energia"], "sol_pitch": CUEVA_VIEJA["sol_pitch"], "sol_yaw": CUEVA_VIEJA["sol_yaw"],
				"ambiente_arriba": CUEVA_VIEJA["ambiente_arriba"], "ambiente_abajo": CUEVA_VIEJA["ambiente_abajo"], "ambiente_energia": CUEVA_VIEJA["ambiente_energia"]}
		colocar_jugador(SALAS[nombre])
		LuzZona3D.aplicar_valores(env, sol, v)
		await _mirar_zoom(SALAS[nombre], TAM_SALA, 1.0)
		LuzZona3D.aplicar_valores(env, sol, v)
		await avanzar_s(0.3)
		var img: Image = await _foto("antes_%s" % nombre)
		_medias["antes_%s" % nombre] = _media(img)
	_zonas.set_process(true)

func _general_nuevo() -> void:
	await _recorrer_salas("despues")


func _recorrer_salas(prefijo: String) -> void:
	for nombre in SALAS:
		colocar_jugador(SALAS[nombre])
		_zonas.forzar()                         # tras la pasada «antes» (con las zonas paradas) la luz de cada sala se vuelve a poner de golpe
		await _mirar_zoom(SALAS[nombre], TAM_SALA, T_LUZ_S)
		var img: Image = await _foto("%s_%s" % [prefijo, nombre])
		_medias["%s_%s" % [prefijo, nombre]] = _media(img)


## Media de color de la foto (sin el 5 % de bordes: la interfaz y los viñeteos no cuentan).
func _media(img: Image) -> Color:
	var m: int = int(float(img.get_width()) * 0.05)
	var n: int = 0
	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	for y in range(m, img.get_height() - m, 4):
		for x in range(m, img.get_width() - m, 4):
			var c: Color = img.get_pixel(x, y)
			r += c.r
			g += c.g
			b += c.b
			n += 1
	return Color(r / float(n), g / float(n), b / float(n))


func _imprimir_medias() -> void:
	print("--- media de color de cada sala (R G B · azul/rojo) ---")
	for nombre in SALAS:
		var a: Color = _medias["antes_%s" % nombre]
		var d: Color = _medias["despues_%s" % nombre]
		print("%s  antes %.3f %.3f %.3f (b/r %.2f)  →  después %.3f %.3f %.3f (b/r %.2f)" % [nombre, a.r, a.g, a.b, a.b / maxf(a.r, 0.001), d.r, d.g, d.b, d.b / maxf(d.r, 0.001)])


# ---------------------------------------------------------------------------------------------------------------------
#  2 · Los reactivos
# ---------------------------------------------------------------------------------------------------------------------

func _c1() -> void:
	var cristal: CristalPulso3D = _z.nodo("latido_c1") as CristalPulso3D
	var seta: Recolectable3D = _z.nodo("seta_c1a") as Recolectable3D
	# Las setas, en pleno latido y ya maduras.
	colocar_jugador(Vector2i(3, 14))
	await _mirar_zoom(Vector2i(3, 14), 6.0, 1.0)
	var t: float = 0.0
	while seta.brillo < 0.8 and t < 6.0:
		t += await avanzar_s(0.03)
	await _foto("c1_setas_maduras_latido")
	await _esperar_brillo_apagado(seta)
	await _foto("c1_setas_maduras_reposo")
	# Los braseros encendidos.
	var br_a: Reactivo3D = _z.nodo("br_c1a") as Reactivo3D
	var br_b: Reactivo3D = _z.nodo("br_c1b") as Reactivo3D
	br_a.encender_llama()
	br_b.encender_llama()
	await _mirar_zoom(Vector2i(4, 14), 9.0, 2.5)
	await _foto("c1_braseros_luz_calida")
	# Un pulso de fuego al brasero de la izquierda por la veta (se apaga uno para verlo).
	br_a.apagar_llama()
	await avanzar_s(0.6)
	cristal.latir("fuego")
	await _mirar_zoom(Vector2i(3, 14), 7.0, 0.4)
	await _foto("c1_pulso_de_fuego_por_la_veta")
	await avanzar_s(1.2)
	await _foto("c1_pulso_de_fuego_enciende_el_brasero")
	# La pared hueca del nicho, las estatuas y los cofres.
	await _mirar_zoom(Vector2i(7, 17), 6.0, 2.2)
	await _foto("c1_nicho_pared_hueca")
	var hueca: ParedHuecaPulso3D = _z.nodo("hueca_c1") as ParedHuecaPulso3D
	hueca.abrir()
	await avanzar_s(ParedHuecaPulso3D.T_ABRIR + 0.6)
	await _mirar_zoom(Vector2i(7, 22), 7.5, 1.5)
	await _foto("c1_estatuas_con_su_pista")
	var est: EstatuasPulso3D = _z.nodo("estatuas_c1") as EstatuasPulso3D
	Pulso3D.emitir(maqueta, [Vector2i(5, 22)], "fuego", 4, null, Callable(), true)
	await avanzar_s(0.7)
	Pulso3D.emitir(maqueta, [Vector2i(7, 22)], "hielo", 4, null, Callable(), true)
	await avanzar_s(0.7)
	await _foto("c1_estatuas_dos_encendidas")
	Pulso3D.emitir(maqueta, [Vector2i(9, 22)], "fuego", 4, null, Callable(), true)
	await avanzar_s(0.35)
	await _foto("c1_estatuas_completas_destello")
	await avanzar_s(1.5)
	_ok("c1 las tres estatuas quedan completas", est.hecha)
	await _foto("c1_cofre_epico_columna_cerca")
	# La columna de luz del cofre épico se ve desde la sala de arriba (cámara abierta, el jugador en C1).
	await _mirar_zoom(Vector2i(6, 15), 13.0, 1.5)
	await _foto("c1_cofre_epico_columna_desde_la_sala")
	var epico: Puzle3D.CofrePuzle = _z.nodo("cofre_epico") as Puzle3D.CofrePuzle
	await _mirar_zoom(Vector2i(8, 22), 6.0, 1.0)
	epico.abrir()
	await avanzar_s(0.8)
	await _foto("c1_cofre_epico_abriendose_motas")
	await avanzar_s(1.4)
	await _foto("c1_cofre_epico_abierto")


func _esperar_brillo_apagado(seta: Recolectable3D) -> void:
	var t: float = 0.0
	while (seta.brillo > 0.0 or (_z.nodo("latido_c1") as CristalPulso3D).destello > 0.0) and t < 4.0:
		t += await avanzar_s(0.1)


func _c2() -> void:
	var cristal: CristalPulso3D = _z.nodo("latido_c2") as CristalPulso3D
	var columna: MuroAgrietado3D = _z.nodo("columna_c2") as MuroAgrietado3D
	await _mirar_zoom(Vector2i(4, 5), 8.0, 2.0)
	await _foto("c2_veta_cortada_y_columna")
	# El bloque de tierra tiende el enlace.
	colocar_jugador(Vector2i(4, 5))
	await avanzar_s(0.6)
	lanzar("tierra", ["flecha"], Vector3(0.0, 0.0, -1.0))
	await _esperar(func() -> bool: return Terreno3D.altura_en(Vector2i(4, 3)) >= 1, 4.0)
	await avanzar_s(0.5)
	await _mirar_zoom(Vector2i(4, 5), 8.0, 0.2)
	await _foto("c2_bloque_de_enlace")
	# El pulso cruza y la columna se agrieta y cae.
	var t: float = 0.0
	while cristal.destello < 0.5 and t < 6.0:
		t += await avanzar_s(0.03)
	await avanzar_s(0.25)
	await _foto("c2_pulso_cruza_el_enlace")
	t = 0.0
	while not columna.cayendo and t < 12.0:
		t += await avanzar_s(0.05)
	await avanzar_s(T_CAER_MITAD)
	await _foto("c2_columna_cayendo")
	await avanzar_s(MuroAgrietado3D.T_CAER + 0.4)
	await _foto("c2_columna_caida_polvo")
	await avanzar_s(MuroAgrietado3D.ESPERA_DESHACER + MuroAgrietado3D.T_DESHACER + 0.5)
	colocar_jugador(Vector2i(2, 2))
	await _mirar_zoom(Vector2i(2, 2), 6.5, 1.5)
	await _foto("c2_nicho_abierto_con_cofre")
	# La cascada.
	await _mirar_zoom(Vector2i(3, 6), 6.0, 1.0)
	await _foto("c2_cascada")
	await _mirar_zoom(Vector2i(3, 6), 4.0, 0.5)
	await _foto("c2_cascada_cerca")


const T_CAER_MITAD: float = 0.45               ## s tras empezar a caer, para pillar la columna a medio camino


func _c3() -> void:
	var lava: Lava3D = _z.nodo("rio") as Lava3D
	var receptor: ReceptorPulso3D = _z.nodo("receptor_c3") as ReceptorPulso3D
	await _mirar_zoom(Vector2i(14, 5), 8.0, 1.5)
	await _foto("c3_lava_sin_puente")
	colocar_jugador(Vector2i(12, 5))
	await avanzar_s(0.5)
	await _lanzar("hielo", ["flecha"], Vector2i(13, 5))
	await _esperar(func() -> bool: return lava.es_roca(Vector2i(13, 5)), 5.0)
	await _mirar_zoom(Vector2i(14, 5), 8.0, 0.1)
	await _foto("c3_puente_de_basalto")
	await _esperar(func() -> bool: return receptor.activo, 6.0)
	await _foto("c3_receptor_activado")
	await _esperar(func() -> bool: return (_z.nodo("reja_c3") as Puzle3D.PuertaPuzle).abierta, 3.0)
	await avanzar_s(1.0)
	await _mirar_zoom(Vector2i(16, 3), 7.0, 1.2)
	await _foto("c3_reja_abierta_y_cofre")


func _c4() -> void:
	var cris_a: CristalPulso3D = _z.nodo("cris_c4a") as CristalPulso3D
	var cerrojo: Puzle3D.CerrojoPuzle = _z.nodo("entrada_c4") as Puzle3D.CerrojoPuzle
	cerrojo.abrir()                                # sin cerrar la sala: la foto es de las vetas
	await avanzar_s(0.5)
	var g: Combate3D = null
	for n in get_nodes_in_group("combate3d"):
		if n is Combate3D and Rect2i(19, 1, 7, 8).has_point(Terreno3D.celda_de((n as Combate3D).global_position)):
			g = n as Combate3D
			break
	await _mirar_zoom(Vector2i(22, 4), 9.0, 2.0)
	await _foto("c4_vetas_y_cristales")
	if g != null:
		g.quieto = true
		g.position = Terreno3D.centro_de(Vector2i(22, 2), Terreno3D.y_pies(Vector2i(22, 2)))
		g.pj.position = g.position
	cris_a.latir("")
	await avanzar_s(0.3)
	await _foto("c4_pulso_por_la_veta")
	await avanzar_s(0.5)
	await _foto("c4_goblin_aturdido")


func _c6() -> void:
	var tesoro: Puzle3D.CofrePuzle = _z.nodo("tesoro") as Puzle3D.CofrePuzle
	# La columna de luz dorada desde la puerta de la sala (el cofre sellado).
	await _mirar_zoom(Vector2i(16, 16), 12.0, 2.0)
	await _foto("c6_cofre_legendario_columna_desde_la_puerta")
	await _mirar_zoom(Vector2i(13, 14), 7.0, 1.0)
	await _foto("c6_cofre_legendario_columna_cerca")
	(_z.nodo("ante_cofre") as ReceptorPulso3D).activar()
	await avanzar_s(1.0)
	await _foto("c6_cofre_legendario_desellado")


# ---------------------------------------------------------------------------------------------------------------------
#  Ayudas
# ---------------------------------------------------------------------------------------------------------------------

func _lanzar(elemento: String, glifos: Array, objetivo: Vector2i) -> void:
	var a: Vector3 = Terreno3D.centro_de(objetivo, 0.0) - Vector3(jugador.position.x, 0.0, jugador.position.z)
	var t: float = 0.0
	while t < 8.0 and not lanzar(elemento, glifos, a):
		t += await avanzar_s(0.5)


func _lanzar_real(elemento: String, glifos: Array, dir: Vector3) -> void:
	var t: float = 0.0
	while t < 8.0:
		lanzador.select_page(0)
		lanzador.clear_sequence()
		lanzador.place_element(elemento)
		for g in glifos:
			lanzador.place_sigil(String(g))
		lanzador.cooldown_left[0] = 0.0
		if lanzador.lanzar_pagina_ya(0, jugador.position, Vector3(dir.x, 0.0, dir.z).normalized()):
			return
		t += await avanzar_s(0.5)


func _esperar(cond: Callable, max_s: float) -> void:
	var t: float = 0.0
	while not bool(cond.call()) and t < max_s:
		t += await avanzar_s(0.1)


func _mirar_zoom(c: Vector2i, tam: float, s: float) -> void:
	colocar_jugador(c)
	maqueta.set("_tam_camara", tam)
	if _cam != null:
		_cam.size = tam
	await avanzar_s(s)


func _foto(nombre: String) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join("%s.png" % nombre))
	print("foto %s" % nombre)
	return img


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
