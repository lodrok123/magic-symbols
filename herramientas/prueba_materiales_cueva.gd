extends "res://herramientas/escenario_base.gd"
## MATERIALES DE LA CUEVA (23/10; docs/MATERIALES_CUEVA.md, PLAN_PULSO_RESONANTE §7 y §10.4). Headless, con la escena de verdad (PruebaCueva):
## 1 · Datos: los 9 materiales están dados de alta con su calidad (7 comunes, 2 épicos morados), el alga está en PLANTAS (alga_cueva; fuego → alga_seca) y los ganchos de minerales.
## 2 · Alga: solo existe/se coge con la charca HELADA; deshelada, desaparece; el fuego la seca (alga seca).
## 3 · Basalto: solo existe/se coge sobre la lava recién enfriada y desaparece cuando la lava vuelve (10 s).
## 4 · Colmillo de goblin: la tirada tiene su probabilidad con nombre; al caer un goblin real no rompe nada y da 0 o 1.
## 5 · Aviso por calidad: común como siempre, épico con borde morado, más largo y destello; el Lanzador3D real pinta el borde.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_materiales_cueva.gd

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const COMUNES: PackedStringArray = ["seta_resonante", "alga_cueva", "alga_seca", "mineral_veta", "esquirla_cristal", "basalto", "colmillo_goblin"]
const EPICOS: PackedStringArray = ["nucleo_eco", "geoda_resonante"]
const ALGAS: PackedStringArray = ["alga_c5a", "alga_c5b", "alga_c5c"]
const CHARCA: Rect2i = Rect2i(20, 13, 5, 4)
const MUESTRAS_TIRADA: int = 4000
const MARGEN_TIRADA: float = 0.05
const T_VUELVE_LAVA: float = 10.0
const CONTRASTE_TEXTO_MIN: float = 7.0       ## razón de contraste WCAG mínima del texto contra el fondo del aviso (AAA), en el PEOR caso: fondo detrás blanco puro


## Lanzador falso: guarda lo que le piden avisar.
class FalsoLanzador extends Node:
	var jugador: Node3D = null
	var llamadas: Array = []
	func avisar(texto: String, color: Color = Color(1, 0.9, 0.6), borde: Color = Color(0, 0, 0, 0.9), duracion: float = 1.4) -> void:
		llamadas.append({"texto": texto, "color": color, "borde": borde, "duracion": duracion})


func _helar_charca(si: bool) -> void:
	for y in range(CHARCA.position.y, CHARCA.end.y):
		for x in range(CHARCA.position.x, CHARCA.end.x):
			Terreno3D.agua_sim.helar_casilla(Vector2i(x, y), si)
			Terreno3D.poner_helada(Vector2i(x, y), si)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	_datos()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 Puzle3D está y no avisa de nada", z != null and z.avisos.is_empty(), str(z.avisos) if z != null else "sin Puzle3D")
	if z == null:
		return
	await _algas(z)
	await _basalto(z)
	await _colmillo(z)
	await _avisos_calidad()


# ---------------------------------------------------------------------------------------------------------------------
func _datos() -> void:
	var todos_comunes: bool = true
	for id in COMUNES:
		if not Objetos.existe(id) or Objetos.calidad(id) != Objetos.CALIDAD_COMUN:
			todos_comunes = false
	_ok("1 los 7 comunes están en DATOS y son de calidad común", todos_comunes)
	var todos_epicos: bool = true
	for id in EPICOS:
		if not Objetos.existe(id) or Objetos.calidad(id) != Objetos.CALIDAD_EPICO or Objetos.color(id).b < 0.8 or Objetos.color(id).g > 0.5:
			todos_epicos = false
	_ok("1 los 2 épicos están en DATOS, son de calidad épica y su icono es morado", todos_epicos)
	_ok("1 un objeto de siempre (seta) y uno que no existe son comunes", Objetos.calidad("seta") == Objetos.CALIDAD_COMUN and Objetos.calidad("no_existe") == Objetos.CALIDAD_COMUN)
	var c0: Color = Objetos.CALIDADES["comun"]["color"]
	var c1: Color = Objetos.CALIDADES["epico"]["color"]
	var c2: Color = Objetos.CALIDADES["legendario"]["color"]
	_ok("1 colores de calidad: común gris/blanco, épico morado, legendario dorado", c0.get_luminance() > 0.7 and absf(c0.r - c0.b) < 0.1 and c1.b > c1.g and c1.r > c1.g and c2.r > 0.9 and c2.g > 0.7 and c2.b < 0.4)
	_ok("1 el aviso dura más cuanto más rara la calidad", float(Objetos.CALIDADES["comun"]["aviso_s"]) < float(Objetos.CALIDADES["epico"]["aviso_s"]) and float(Objetos.CALIDADES["epico"]["aviso_s"]) < float(Objetos.CALIDADES["legendario"]["aviso_s"]))
	var alga: Dictionary = Objetos.PLANTAS.get("alga", {})
	_ok("1 PLANTAS: alga con base alga_cueva y fuego → alga_seca", String(alga.get("base", "")) == "alga_cueva" and String((alga.get("tabla", {}) as Dictionary).get("fuego", "")) == "alga_seca")
	var tablas_ok: bool = true
	for fila in Objetos.PLANTAS:
		var f: Dictionary = Objetos.PLANTAS[fila]
		if not Objetos.existe(String(f["base"])):
			tablas_ok = false
		for e in (f["tabla"] as Dictionary):
			if not Objetos.existe(String((f["tabla"] as Dictionary)[e])) or not (e in Objetos.ETIQUETAS):
				tablas_ok = false
	_ok("1 toda fila de PLANTAS apunta a objetos que existen y a elementos de verdad", tablas_ok)
	_ok("1 gancho de minerales: la veta con tierra da mineral de veta; el cristal y el jarrón, esquirla; nada más", Objetos.mineral_de("veta", "tierra") == "mineral_veta"
		and Objetos.mineral_de("cristal_resonante", "golpe") == "esquirla_cristal" and Objetos.mineral_de("jarron", "romper") == "esquirla_cristal"
		and Objetos.mineral_de("veta", "fuego") == "" and Objetos.mineral_de("roca", "tierra") == "")
	var ids_minerales_ok: bool = true
	for r in Objetos.MINERALES:
		if not Objetos.existe(String((Objetos.MINERALES[r] as Dictionary)["da"])):
			ids_minerales_ok = false
	_ok("1 todo lo que da un reactivo de MINERALES existe en DATOS", ids_minerales_ok)


# ---------------------------------------------------------------------------------------------------------------------
func _algas(z: Puzle3D) -> void:
	var a: Recolectable3D = z.nodo(ALGAS[0]) as Recolectable3D
	var b: Recolectable3D = z.nodo(ALGAS[1]) as Recolectable3D
	var c: Recolectable3D = z.nodo(ALGAS[2]) as Recolectable3D
	_ok("2 las tres algas de la charca están montadas", a != null and b != null and c != null)
	if a == null or b == null or c == null:
		return
	_ok("2 con la charca sin helar el alga NO está: ni se ve ni se coge ni reacciona", not a.disponible and not a.visible_en_mundo() and not a.recoger() and not a.spell_reacts(load("res://nucleo/fire_rune.tres") as RuneData))
	_ok("2 un alga no cogida no deja nada en la bolsa", Estado.i().cuenta("alga_cueva") == 0)
	_helar_charca(true)
	await avanzar_s(0.6)
	_ok("2 con la charca helada aparecen las tres algas", a.disponible and b.disponible and c.disponible and a.visible_en_mundo())
	# El fuego seca una antes de cogerla.
	var fuego: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
	_ok("2 el alga reacciona al fuego", b.spell_reacts(fuego))
	b.on_spell_hit(fuego)
	_ok("2 tras el fuego da alga seca", b.objeto == "alga_seca")
	colocar_jugador(Vector2i(22, 17))
	_ok("2 se coge el alga (alga de cueva)", a.recoger() and Estado.i().cuenta("alga_cueva") == 1)
	_ok("2 se coge el alga quemada (alga seca)", b.recoger() and Estado.i().cuenta("alga_seca") == 1)
	_ok("2 un alga ya cogida no se vuelve a coger ni se ve", not a.recoger() and not a.visible_en_mundo())
	await avanzar_s(0.6)
	_ok("2 la cogida sigue oculta aunque la condición siga cumpliéndose", not a.visible_en_mundo())
	_helar_charca(false)
	await avanzar_s(0.6)
	_ok("2 al deshelar la charca la que quedaba sin coger desaparece y ya no se coge", not c.disponible and not c.visible_en_mundo() and not c.recoger() and Estado.i().cuenta("alga_cueva") == 1)
	_helar_charca(true)
	await avanzar_s(0.6)
	_ok("2 al helarla otra vez vuelve a estar a mano", c.disponible and c.visible_en_mundo())
	_helar_charca(false)


func _basalto(z: Puzle3D) -> void:
	var lava: Lava3D = z.nodo("rio") as Lava3D
	var a: Recolectable3D = z.nodo("basalto_c3a") as Recolectable3D
	var b: Recolectable3D = z.nodo("basalto_c3b") as Recolectable3D
	_ok("3 la lava y los dos basaltos están montados", lava != null and a != null and b != null)
	if lava == null or a == null or b == null:
		return
	_ok("3 con la lava sin enfriar el basalto NO está: ni se ve ni se coge", not a.disponible and not a.visible_en_mundo() and not a.recoger() and Estado.i().cuenta("basalto") == 0)
	lava.enfriar_en(Vector2i(13, 3))
	await avanzar_s(0.5)
	_ok("3 la lava enfriada deja la roca y el basalto de esa casilla aparece (el de la otra casilla, que sigue siendo lava, no)", a.disponible and a.visible_en_mundo() and not b.disponible)
	colocar_jugador(Vector2i(12, 3))
	_ok("3 se coge el basalto", a.recoger() and Estado.i().cuenta("basalto") == 1)
	lava.enfriar_en(Vector2i(14, 6))
	await avanzar_s(0.5)
	_ok("3 enfriando la otra casilla aparece el segundo", b.disponible and b.visible_en_mundo())
	await avanzar_s(T_VUELVE_LAVA + 1.0)
	_ok("3 cuando la lava vuelve, el basalto que no se cogió desaparece y ya no se coge", not b.disponible and not b.visible_en_mundo() and not b.recoger() and Estado.i().cuenta("basalto") == 1)


# ---------------------------------------------------------------------------------------------------------------------
func _colmillo(z: Puzle3D) -> void:
	_ok("4 la probabilidad del colmillo es una constante con nombre entre 0 y 1", BotinGoblin.PROB_COLMILLO > 0.0 and BotinGoblin.PROB_COLMILLO < 1.0 and BotinGoblin.MATERIAL == "colmillo_goblin")
	_ok("4 la tirada: gana por debajo de la probabilidad, pierde en ella y por encima", BotinGoblin.gana(0.0) and BotinGoblin.gana(BotinGoblin.PROB_COLMILLO - 0.001)
		and not BotinGoblin.gana(BotinGoblin.PROB_COLMILLO) and not BotinGoblin.gana(0.99))
	var gana: int = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for _i in range(MUESTRAS_TIRADA):
		if BotinGoblin.gana(rng.randf()):
			gana += 1
	var f: float = float(gana) / float(MUESTRAS_TIRADA)
	_ok("4 la frecuencia real de la tirada ronda la probabilidad (%.3f ≈ %.2f)" % [f, BotinGoblin.PROB_COLMILLO], absf(f - BotinGoblin.PROB_COLMILLO) < MARGEN_TIRADA)
	var antes: int = Estado.i().cuenta("colmillo_goblin")
	_ok("4 una tirada perdedora no da nada", BotinGoblin.soltar(maqueta as Node3D, Vector3.ZERO, 0.99) == "" and Estado.i().cuenta("colmillo_goblin") == antes)
	_ok("4 una tirada ganadora da el colmillo a la bolsa", BotinGoblin.soltar(maqueta as Node3D, Vector3.ZERO, 0.0) == "colmillo_goblin" and Estado.i().cuenta("colmillo_goblin") == antes + 1)
	# Goblins de verdad: matar a los de C4 por el camino de siempre (Combate3D._morir) no rompe nada y cada uno da 0 o 1.
	var antes2: int = Estado.i().cuenta("colmillo_goblin")
	var muertos: int = 0
	var vivos: Array = []
	for g in maqueta.find_children("*", "Combate3D", true, false):
		var cg: Vector2i = Terreno3D.celda_de((g as Node3D).global_position)
		if cg.x >= 19 and cg.y <= 8:
			vivos.append(g)
	_ok("4 hay goblins en C4", vivos.size() >= 2, "%d" % vivos.size())
	if vivos.size() < 2:
		return
	BotinGoblin.tirada_forzada = 0.99                       # el primero cae con la tirada perdida: no suelta nada
	vivos[0].call("receive_damage", 9999.0)
	await avanzar_s(0.5)
	_ok("4 un goblin real cae con la tirada perdida: ningún colmillo (ni en el suelo)", Estado.i().cuenta("colmillo_goblin") == antes2 and _colmillos_en_suelo().is_empty())
	BotinGoblin.tirada_forzada = 0.0                        # el segundo, con la ganada: F1 (29/10): el colmillo CAE AL SUELO (BotinObjeto3D) desde Combate3D._morir
	for i in range(1, vivos.size()):
		vivos[i].call("receive_damage", 9999.0)
		muertos += 1
	await avanzar_s(0.5)
	BotinGoblin.tirada_forzada = -1.0
	var en_suelo: Array = _colmillos_en_suelo()
	_ok("4 los goblins reales que caen con la tirada ganada sueltan un colmillo cada uno al suelo (%d)" % muertos, en_suelo.size() == muertos and Estado.i().cuenta("colmillo_goblin") == antes2)
	for b in en_suelo:
		(b as BotinObjeto3D).recoger()
	_ok("4 y al cogerlos llegan a la bolsa (%d)" % muertos, Estado.i().cuenta("colmillo_goblin") == antes2 + muertos)


## Los colmillos que hay sueltos en el suelo del mundo ahora mismo.
func _colmillos_en_suelo() -> Array:
	var r: Array = []
	for b in maqueta.find_children("Botin_colmillo_goblin*", "", true, false):
		if b is BotinObjeto3D and not (b as BotinObjeto3D).recogido:
			r.append(b)
	return r


# ---------------------------------------------------------------------------------------------------------------------
## Luminancia relativa WCAG (sRGB lineal).
func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * float(f.call(c.r)) + 0.7152 * float(f.call(c.g)) + 0.0722 * float(f.call(c.b))


## Contraste del color de texto de `etiqueta` contra `fondo` (con su alfa) puesto SOBRE BLANCO y SOBRE NEGRO: el peor de los dos debe pasar el umbral.
func _contraste(nombre: String, etiqueta: Label, fondo: Color) -> void:
	var texto: Color = etiqueta.get_theme_color("font_color")
	var peor: float = 1.0e9
	for detras in [Color.WHITE, Color.BLACK]:
		var f: Color = Color(fondo.r, fondo.g, fondo.b, 1.0).lerp(detras, 1.0 - fondo.a)
		var l1: float = _lum(texto)
		var l2: float = _lum(f)
		peor = minf(peor, (maxf(l1, l2) + 0.05) / (minf(l1, l2) + 0.05))
	_ok("5 contraste del texto %s contra su fondo (peor caso %.1f, mínimo %.1f)" % [nombre, peor, CONTRASTE_TEXTO_MIN], peor >= CONTRASTE_TEXTO_MIN)


func _avisos_calidad() -> void:
	var l := FalsoLanzador.new()
	var pj := Node3D.new()
	root.add_child(l)
	root.add_child(pj)
	l.jugador = pj
	var c: Color = AvisoObjeto.mostrar(l, "seta", 1)
	_ok("5 común: un solo aviso «Seta (+1)» sin color ni borde propios (el de siempre)", l.llamadas.size() == 1 and String(l.llamadas[0]["texto"]) == "Seta (+1)"
		and Color(l.llamadas[0]["borde"]) == Color(0, 0, 0, 0.9) and absf(float(l.llamadas[0]["duracion"]) - 1.4) < 0.001 and c == Objetos.color_calidad("seta"))
	_ok("5 común: sin destello", pj.get_child_count() == 0)
	l.llamadas.clear()
	var ce: Color = AvisoObjeto.mostrar(l, "nucleo_eco", 1)
	var d: Dictionary = l.llamadas[0] if not l.llamadas.is_empty() else {}
	_ok("5 épico: aviso «Núcleo de eco (+1)» con el borde MORADO de la calidad", String(d.get("texto", "")) == "Núcleo de eco (+1)" and Color(d.get("borde", Color.BLACK)).is_equal_approx(ce) and ce.b > ce.g)
	_ok("5 épico: el aviso dura más que el común", float(d.get("duracion", 0.0)) > 1.4 + 0.5)
	var luz: OmniLight3D = pj.get_node_or_null("DestelloMaterial") as OmniLight3D
	_ok("5 épico: destello de luz morada sobre la jugadora", luz != null and luz.light_color.is_equal_approx(ce))
	await avanzar_s(AvisoObjeto.DESTELLO_SUBE_S + AvisoObjeto.DESTELLO_BAJA_S + 0.3)
	_ok("5 épico: el destello es corto y se borra solo", not is_instance_valid(luz) or luz.is_queued_for_deletion())
	_ok("5 sin lanzador no pasa nada", AvisoObjeto.mostrar(null, "nucleo_eco", 1) == ce)
	# El Lanzador3D de verdad pinta el borde y lo devuelve al negro con el siguiente aviso común.
	var aviso: Label = lanzador.get("_aviso") as Label
	AvisoObjeto.mostrar(lanzador, "geoda_resonante", 1)
	var caja: StyleBoxFlat = aviso.get_theme_stylebox("normal") as StyleBoxFlat if aviso != null else null
	var morado: Color = AvisoObjeto.color_borde(Objetos.color_calidad("geoda_resonante"))
	_ok("5 Lanzador3D real: el aviso épico lleva el texto y un panel con el borde morado saturado y franjas laterales", aviso != null and aviso.text == "Geoda resonante (+1)"
		and caja != null and caja.border_color.is_equal_approx(morado) and caja.border_color.s >= AvisoObjeto.BORDE_SATURACION_MIN - 0.001
		and caja.border_width_left == AvisoObjeto.FRANJA_PX and caja.border_width_top == AvisoObjeto.BORDE_PX)
	_ok("5 aviso épico: el texto es claro y su contorno oscuro (el color de calidad no va en el texto)", aviso.get_theme_color("font_color").is_equal_approx(AvisoObjeto.COLOR_TEXTO)
		and aviso.get_theme_color("font_outline_color").get_luminance() < 0.1)
	_contraste("épico", aviso, AvisoObjeto.FONDO_CALIDAD)
	AvisoObjeto.mostrar_texto(lanzador, "Glifo de resonancia (+1)", Objetos.CALIDAD_LEGENDARIO)
	caja = aviso.get_theme_stylebox("normal") as StyleBoxFlat
	_ok("5 aviso legendario: panel con el borde dorado saturado y texto claro", caja != null and caja.border_color.is_equal_approx(AvisoObjeto.color_borde(Objetos.CALIDADES["legendario"]["color"]))
		and aviso.get_theme_color("font_color").is_equal_approx(AvisoObjeto.COLOR_TEXTO))
	_contraste("legendario", aviso, AvisoObjeto.FONDO_CALIDAD)
	AvisoObjeto.mostrar(lanzador, "seta", 1)
	caja = aviso.get_theme_stylebox("normal") as StyleBoxFlat
	_ok("5 Lanzador3D real: el siguiente aviso común vuelve al panel suave, sin borde de color ni franjas", aviso != null and aviso.text == "Seta (+1)" and caja != null
		and caja.border_width_left == 0 and caja.bg_color.is_equal_approx(AvisoObjeto.FONDO_COMUN) and aviso.get_theme_color("font_outline_color").get_luminance() < 0.1)
	_contraste("común", aviso, AvisoObjeto.FONDO_COMUN)
	_ok("5 el panel del aviso se encoge al texto (no es una barra de lado a lado)", aviso.size.x < aviso.get_viewport_rect().size.x * 0.6 and aviso.size.x > 0.0, "%.0f px" % aviso.size.x)
	l.queue_free()
	pj.queue_free()
