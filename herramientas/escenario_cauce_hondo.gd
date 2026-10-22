extends "res://herramientas/escenario_base.gd"
## ESCENARIO «CAUCE HONDO» (22/10, decisión de Pablo: «que el jugador se caiga, y que tenga un desnivel; si no, no habrá sensación de profundidad»).
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_cauce_hondo.gd
##
## Carga el Bosque 01 de verdad (PruebaBosque01.tscn, agua física y filtro) y comprueba, con el jugador andando con las teclas:
##   1  el foso: fondo = el de la simulación (0,95 − 0,9), profundidad PROF_CAUCE ≈ 0,94 u (≈ un nivel de terraza), y_pies/pisable/Caminos coherentes, foso dibujado
##   2  el jugador entra por un borde, CAE con la gravedad de Jugador3D (no se teletransporta ni atraviesa el fondo), anda por el fondo y sale trepando por el otro lado
##   3  goblins: no se rutean por el foso (lo rodean); con el interruptor apagado el cauce es transitable como antes
##   4  el agua: pisar la losa abre el manantial; el agua SUBE desde el fondo real hasta su nivel; el jugador dentro nada a la altura de la superficie; no hay bloques opacos
##   5  el interruptor: apagado vuelve el cauce de 0,1 u (se pisa a ras); encendido, el foso
##
## HONESTO: en headless no hay GPU. Esto mide lógica y geometría. Cómo SE VE hay que mirarlo con ventana (capturas pendientes: Pablo tenía el editor abierto).

const RUTA: String = "res://escenas/PruebaBosque01.tscn"
const S: float = 2.3


## Anota cada fotograma la posición del jugador (para medir la caída y la trepada).
class Muestreo extends Node:
	var jug: Node3D = null
	var t: float = 0.0
	var datos: Array = []             ## [t, x, y, z, en_suelo, nadando]
	func _process(delta: float) -> void:
		t += delta
		if jug != null:
			datos.append([t, jug.position.x, jug.position.y, jug.position.z, bool(jug.get("en_suelo")), bool(jug.get("nadando"))])


var muestreo: Muestreo = null
var fondo: float = 0.0
var alto: float = 0.0


func _escenario() -> void:
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	alto = Terreno3D.alto_suelo
	fondo = Terreno3D.fondo_cauce()
	muestreo = Muestreo.new()
	muestreo.jug = jugador
	root.add_child(muestreo)
	_foso()
	await _entrar_y_salir()
	await _goblins()
	await _interruptor()
	await _agua()


func _celdas_c() -> Array:
	var r: Array = []
	var lado: int = Terreno3D.lado_del_mapa()
	for y in range(lado):
		for x in range(lado):
			if Terreno3D.letra_de(Vector2i(x, y)) == "c":
				r.append(Vector2i(x, y))
	return r


# ---------------------------------------------------------------------------------------------------------------------
func _foso() -> void:
	var cs: Array = _celdas_c()
	_ok("1.0 el Bosque 01 trae su estanque de 15 casillas c", cs.size() == 15, "%d" % cs.size())
	_ok("1.1 cauce_hondo está encendido de serie (maqueta y Terreno3D)", bool(maqueta.get("cauce_hondo")) and Terreno3D.cauce_hondo)
	var c: Vector2i = Vector2i(16, 16)
	var prof: float = alto - Terreno3D.y_pies(c)
	_ok("1.2 el fondo del foso es el de la simulación (alto_agua − LECHO_AGUA = %.3f)" % fondo, absf(Terreno3D.y_pies(c) - fondo) < 1.0e-4, "y_pies %.3f" % Terreno3D.y_pies(c))
	_ok("1.3 PROF_CAUCE es la profundidad real (%.3f u) y cabe entre media terraza y una" % Terreno3D.PROF_CAUCE, absf(prof - Terreno3D.PROF_CAUCE) < 1.0e-4 and Terreno3D.PROF_CAUCE > 0.5 * Terreno3D.ALTO_NIVEL and Terreno3D.PROF_CAUCE < Terreno3D.ALTO_NIVEL, "prof %.3f, nivel %.3f" % [prof, Terreno3D.ALTO_NIVEL])
	var sim_suelo: float = Terreno3D.agua_sim.superficie_en(Terreno3D.centro_de(c, 0.0)) - Terreno3D.agua_sim.profundidad_en(Terreno3D.centro_de(c, 0.0))
	_ok("1.4 coincide con el suelo de la simulación de agua en esa casilla (%.3f)" % sim_suelo, absf(sim_suelo - fondo) < 1.0e-3)
	_ok("1.5 es_cauce_hondo / es_hueco_cauce; una casilla de suelo no", Terreno3D.es_cauce_hondo(c) and Terreno3D.es_hueco_cauce(c) and not Terreno3D.es_hueco_cauce(Vector2i(15, 16)))
	_ok("1.6 sigue siendo pisable para quien camina (no es pared ni agua)", Terreno3D.pisable(c, 0, true, 1, false) and not Terreno3D.es_agua(c) and not Terreno3D.bloqueada(c))
	_ok("1.7 y_pies de la orilla sigue siendo el suelo", absf(Terreno3D.y_pies(Vector2i(15, 16)) - alto) < 1.0e-4)
	_ok("1.8 superficie_agua de un foso seco = su fondo (no hay agua)", absf(Terreno3D.superficie_agua(c) - fondo) < 1.0e-3)
	# Dibujo: cada c es un foso (PozoCauce3D) y no hay tapa; los bordes llegan al fondo.
	var pozos: Dictionary = maqueta.get("_pozos_cauce")
	var tapas: Dictionary = maqueta.get("_tapas_cauce")
	var visibles: int = 0
	var tapas_vis: int = 0
	for q in cs:
		if pozos.has(q) and (pozos[q] as Node3D).visible:
			visibles += 1
		if tapas.has(q) and (tapas[q] as MeshInstance3D).visible:
			tapas_vis += 1
	_ok("1.9 las 15 casillas c se dibujan como foso (PozoCauce3D) y ninguna con tapa", visibles == 15 and tapas_vis == 0, "fosos %d, tapas %d" % [visibles, tapas_vis])
	var b1: BordePiedras3D = maqueta.get("_bordes_cauce") as BordePiedras3D
	var b2: BordePiedras3D = maqueta.get("_bordes_cauce_abierto") as BordePiedras3D
	_ok("1.10 los bordes (labio, falda, cantos) están: 26 aristas suelo ↔ foso", b1.n_bordes() + b2.n_bordes() == 26 and b1.n_bordes() == 26, "seco %d, orilla %d" % [b1.n_bordes(), b2.n_bordes()])
	var faldas: MeshInstance3D = null
	for h in b1.get_children():
		if h is MeshInstance3D and (h as MeshInstance3D).mesh != null and (((h as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2] == null):
			faldas = h as MeshInstance3D
	var y_min: float = INF
	if faldas != null:
		for v in (faldas.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			y_min = minf(y_min, (v as Vector3).y)
	_ok("1.11 la falda de la pared llega al fondo real (y mín %.3f ≈ %.3f)" % [y_min, fondo], faldas != null and absf(y_min - fondo) < 0.01)
	_ok("1.12 el labio proyecta sombra y el pie se ilumina como pared", b1.labio_proyecta_sombra and b1.labio_pie_arriba == 0.0)
	_ok("1.13 Caminos3D: el foso no es transitable (los goblins lo rodean)", not Caminos3D.transitable(c) and Caminos3D.transitable(Vector2i(15, 16)))
	var tr: TroncoEstanque3D = maqueta.get_node("Reglas").get("_tronco_estanque") as TroncoEstanque3D
	if tr != null:
		_ok("1.14 el tronco del estanque yace DENTRO del foso: su cara de arriba (%.2f) queda bajo el suelo (%.2f)" % [tr.position.y + TroncoEstanque3D.RADIO_MODELO, alto], tr.position.y + TroncoEstanque3D.RADIO_MODELO < alto - 0.1)
		_ok("1.15 el tronco del estanque (en el fondo) BLOQUEA al jugador: su centro, a pies del fondo, es obstáculo; a pies sobre su cara de arriba o fuera de su largo, no", tr.bloquea(tr.position, fondo) and not tr.bloquea(tr.position, alto) and not tr.bloquea(tr.position + Vector3(TroncoEstanque3D.LARGO, 0.0, 0.0), fondo) and not tr.bloquea(tr.position + Vector3(0.0, 0.0, 1.0), fondo) and TroncoEstanque3D.bloquea_a(tr.position, fondo))


# ---------------------------------------------------------------------------------------------------------------------
## Cuántos fotogramas del muestreo hay hasta ahora (para recortar un tramo).
func _n() -> int:
	return muestreo.datos.size()


func _entrar_y_salir() -> void:
	# Por el este-oeste, a la altura de la fila 16: (14,16) → foso (16,16) → (18,16).
	colocar_jugador(Vector2i(14, 16))
	await avanzar(10)
	var i0: int = _n()
	var llego: bool = await mover_hacia(Vector2i(16, 16), 12.0, 0.2)
	await avanzar_s(1.0)
	var tramo: Array = muestreo.datos.slice(i0)
	_ok("2.1 el jugador llega andando al centro del foso", llego, "celda %s" % str(celda_jugador()))
	# Entrada: primer fotograma en una casilla c, y primero en el fondo.
	var k_ent: int = -1
	var k_fondo: int = -1
	var v_min: float = 0.0
	var y_min: float = INF
	for k in range(tramo.size()):
		var d: Array = tramo[k]
		var cc: Vector2i = Terreno3D.celda_de(Vector3(d[1], 0.0, d[3]))
		if k_ent < 0 and Terreno3D.letra_de(cc) == "c":
			k_ent = k
		if k_ent >= 0 and k_fondo < 0 and float(d[2]) <= fondo + 0.03:
			k_fondo = k
		if k > 0:
			v_min = minf(v_min, (float(d[2]) - float((tramo[k - 1] as Array)[2])) / (float(d[0]) - float((tramo[k - 1] as Array)[0])))
		y_min = minf(y_min, float(d[2]))
	_ok("2.2 entra en una casilla c y llega al fondo", k_ent >= 0 and k_fondo > k_ent, "entra en el muestreo %d, fondo en %d" % [k_ent, k_fondo])
	if k_ent >= 0 and k_fondo > k_ent:
		var dt: float = float((tramo[k_fondo] as Array)[0]) - float((tramo[k_ent] as Array)[0])
		var y_ent: float = float((tramo[k_ent] as Array)[2])
		_ok("2.3 CAE: baja %.2f u en %.2f s (< 1 s; una caída libre de esa altura son ~0,29 s: no es un teletransporte)" % [y_ent - fondo, dt], dt < 1.0 and dt > 0.15 and y_ent - fondo > 0.6, "y de entrada %.3f" % y_ent)
	_ok("2.4 con la gravedad del jugador: velocidad de caída máxima %.1f u/s (> 3)" % -v_min, -v_min > 3.0)
	_ok("2.5 nunca atraviesa el fondo (y mín %.3f, fondo %.3f)" % [y_min, fondo], y_min >= fondo - 0.01)
	var d_f: Array = muestreo.datos[_n() - 1]
	_ok("2.6 se queda de pie en el fondo (y %.3f)" % float(d_f[2]), absf(float(d_f[2]) - fondo) < 0.03 and bool(d_f[4]) and not bool(d_f[5]))
	# Andar por el fondo hasta (16,15), sin elevarse ni hundirse. Más al norte yace el tronco del estanque (16,14): bloquea el fondo (22/10).
	var i1: int = _n()
	var llego2: bool = await mover_hacia(Vector2i(16, 15), 12.0, 0.25)
	var ys: Array = muestreo.datos.slice(i1).map(func(d: Array) -> float: return float(d[2]))
	var y_max_f: float = -INF
	var y_min_f: float = INF
	for y in ys:
		y_max_f = maxf(y_max_f, y)
		y_min_f = minf(y_min_f, y)
	_ok("2.7 anda por el fondo de (16,16) a (16,15) con los pies a la altura del lecho (%.3f..%.3f)" % [y_min_f, y_max_f], llego2 and y_max_f - fondo < 0.03 and y_min_f >= fondo - 0.01, "celda %s" % str(celda_jugador()))
	# El tronco del estanque (aún en el fondo) NO se atraviesa: empujar hacia el norte desde (16,15) no pasa de su casilla ni del fondo.
	await mover_hacia(Vector2i(16, 13), 4.0, 0.25)
	var tr_b: TroncoEstanque3D = maqueta.get_node("Reglas").get("_tronco_estanque") as TroncoEstanque3D
	_ok("2.7b el tronco del estanque no se atraviesa por el fondo (z %.2f, tronco z %.2f)" % [jugador.position.z, tr_b.position.z], tr_b != null and jugador.position.z > tr_b.position.z + TroncoEstanque3D.RADIO_MODELO and absf(jugador.position.y - fondo) < 0.03)
	await mover_hacia(Vector2i(16, 16), 6.0, 0.25)
	# Salir: por el este, de (16,16) a (18,16), trepando el borde.
	var i2: int = _n()
	var llego3: bool = await mover_hacia(Vector2i(18, 16), 12.0, 0.25)
	await avanzar_s(1.0)
	var sal: Array = muestreo.datos.slice(i2)
	var y_fin: float = float((sal[sal.size() - 1] as Array)[2])
	_ok("2.8 sale por el borde este (fila 16) y queda de pie en el suelo (y %.3f)" % y_fin, llego3 and absf(y_fin - alto) < 0.03 and not Terreno3D.es_hueco_cauce(celda_jugador()), "celda %s" % str(celda_jugador()))
	# La trepada dura un rato (TASA_TREPAR) y la y sube de forma continua, sin saltos de más de 0,2 u por fotograma.
	var salto_max: float = 0.0
	var k_c: int = -1
	for k in range(sal.size()):
		if k_c < 0 and Terreno3D.celda_de(Vector3((sal[k] as Array)[1], 0.0, (sal[k] as Array)[3])) == Vector2i(16, 16) and float((sal[k] as Array)[1]) > 16.0 * S + S * 0.5 + 0.2:
			k_c = k          # a partir de aquí el jugador ya sale del centro del foso hacia el este (antes, mover_hacia mide el empuje de las teclas y recoloca)
	var k_salto: int = 0
	for k in range(maxi(k_c, 1), sal.size()):
		var dy_k: float = absf(float((sal[k] as Array)[2]) - float((sal[k - 1] as Array)[2]))
		if dy_k > salto_max:
			salto_max = dy_k
			k_salto = k
	print("      [trepada] k_c=%d de %d, mayor salto en k=%d: %s -> %s" % [k_c, sal.size(), k_salto, str(sal[maxi(k_salto - 1, 0)]), str(sal[k_salto])])
	_ok("2.9 la trepada es continua (salto máximo %.3f u por fotograma < 0,2)" % salto_max, salto_max < 0.2)
	# Salir saltando (Espacio) también vale; no se prueba aquí: la regla de trepar cubre el caso y el salto sólo añade altura.
	# Ver que el jugador puede volver a bajar y salir por donde entró (sin quedarse atrapado).
	await mover_hacia(Vector2i(18, 13), 8.0, 0.25)
	var llego4: bool = await mover_hacia(Vector2i(14, 13), 15.0, 0.25)
	_ok("2.10 ida y vuelta: cruza el foso hasta el otro lado (no queda atrapado)", llego4 and absf(jugador.position.y - alto) < 0.05, "celda %s y %.3f" % [str(celda_jugador()), jugador.position.y])


# ---------------------------------------------------------------------------------------------------------------------
func _goblins() -> void:
	var a: Vector2i = Vector2i(14, 13)
	var b: Vector2i = Vector2i(18, 13)
	var r1: Array = Caminos3D.camino(a, b)
	var cruza1: bool = false
	for c in r1:
		if Terreno3D.letra_de(c) == "c":
			cruza1 = true
	_ok("3.1 con el foso, ninguna ruta de goblin pasa por una casilla c", not cruza1, "ruta de %d casillas" % r1.size())
	# Un goblin real en la orilla, el jugador al otro lado: no se mete en el foso.
	var goblin: Combate3D = null
	for n in get_nodes_in_group("goblins"):
		if n is Combate3D and not (n as Combate3D).elemental and is_instance_valid(n):
			goblin = n
			break
	if goblin == null:
		_aviso("3.2 sin goblin en el nivel; se salta la prueba del goblin real")
		return
	colocar_jugador(Vector2i(18, 13))
	goblin.position = Terreno3D.centro_de(Vector2i(14, 13), Terreno3D.y_pies(Vector2i(14, 13)))
	goblin.casa = goblin.position
	goblin.objetivo = jugador
	goblin.estado = "persigue"
	var entro: bool = false
	var y_max_g: float = -INF
	var y_min_g: float = INF
	var inicio: float = reloj.t
	while reloj.t - inicio < 10.0:
		await process_frame
		var cg: Vector2i = Terreno3D.celda_de(goblin.position)
		if Terreno3D.letra_de(cg) == "c":
			entro = true
		y_max_g = maxf(y_max_g, goblin.position.y)
		y_min_g = minf(y_min_g, goblin.position.y)
	_ok("3.2 un goblin que persigue al jugador al otro lado del foso NO se mete en él (10 s)", not entro, "celda final %s, y %.2f..%.2f" % [str(Terreno3D.celda_de(goblin.position)), y_min_g, y_max_g])
	# Control con el interruptor apagado: el cauce de 0,1 u es transitable y la ruta lo atraviesa.
	maqueta.set("cauce_hondo", false)
	await avanzar(3)
	var r2: Array = Caminos3D.camino(a, b)
	var cruza2: bool = false
	for c in r2:
		if Terreno3D.letra_de(c) == "c":
			cruza2 = true
	_ok("3.3 con cauce_hondo apagado el cauce es transitable y la ruta lo cruza", Caminos3D.transitable(Vector2i(16, 13)) and cruza2 and r2.size() > 0, "ruta %d casillas" % r2.size())
	# Control del goblin real (aviso, no fallo: depende de la IA de persecución): con el cauce a ras el mismo goblin SÍ cruza.
	goblin.position = Terreno3D.centro_de(Vector2i(14, 13), Terreno3D.y_pies(Vector2i(14, 13)))
	goblin.objetivo = jugador
	goblin.estado = "persigue"
	var entro2: bool = false
	var inicio2: float = reloj.t
	while reloj.t - inicio2 < 10.0 and not entro2:
		await process_frame
		if Terreno3D.letra_de(Terreno3D.celda_de(goblin.position)) == "c":
			entro2 = true
	if entro2:
		_ok("3.3b control: con el cauce a ras el mismo goblin SÍ cruza por el cauce", true)
	else:
		_aviso("3.3b control: el goblin no cruzó el cauce a ras en 10 s (la IA no lo persiguió); 3.2 prueba poco por sí sola", "celda %s estado %s" % [str(Terreno3D.celda_de(goblin.position)), goblin.estado])
	maqueta.set("cauce_hondo", true)
	await avanzar(3)
	_ok("3.4 al volver a encenderlo, otra vez rodean", not Caminos3D.transitable(Vector2i(16, 13)))
	goblin.objetivo = null
	goblin.estado = "patrulla"
	goblin.position = goblin.casa


# ---------------------------------------------------------------------------------------------------------------------
func _interruptor() -> void:
	var c: Vector2i = Vector2i(16, 16)
	maqueta.set("cauce_hondo", false)
	await avanzar(3)
	_ok("5.1 apagado: se pisa a ras de suelo (y_pies %.3f) y la tapa vuelve" % Terreno3D.y_pies(c), absf(Terreno3D.y_pies(c) - alto) < 1.0e-4 and not Terreno3D.es_hueco_cauce(c))
	var tapas: Dictionary = maqueta.get("_tapas_cauce")
	var pozos: Dictionary = maqueta.get("_pozos_cauce")
	_ok("5.2 apagado: tapas visibles, sin fosos", (tapas[c] as MeshInstance3D).visible and pozos.is_empty())
	# Caminar en cauce de 0,1 u: no cae.
	colocar_jugador(Vector2i(14, 16))
	await avanzar(10)
	var i0: int = _n()
	await mover_hacia(Vector2i(18, 16), 12.0, 0.25)
	var ys: Array = muestreo.datos.slice(i0).map(func(d: Array) -> float: return float(d[2]))
	var dmin: float = INF
	for y in ys:
		dmin = minf(dmin, y)
	_ok("5.3 apagado: cruza el cauce sin caer (y mínima %.3f, suelo %.3f)" % [dmin, alto], dmin > alto - 0.05)
	maqueta.set("cauce_hondo", true)
	await avanzar(3)
	_ok("5.4 encendido de nuevo: el foso vuelve (y_pies %.3f)" % Terreno3D.y_pies(c), absf(Terreno3D.y_pies(c) - fondo) < 1.0e-4)
	pozos = maqueta.get("_pozos_cauce")
	tapas = maqueta.get("_tapas_cauce")
	var n_pozos: int = 0
	for q in _celdas_c():
		if pozos.has(q) and (pozos[q] as Node3D).visible and not (tapas[q] as MeshInstance3D).visible:
			n_pozos += 1
	_ok("5.5 encendido de nuevo: las 15 casillas son foso y sin tapa", n_pozos == 15, "%d" % n_pozos)


# ---------------------------------------------------------------------------------------------------------------------
func _agua() -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	var c: Vector2i = Vector2i(16, 11)
	_ok("4.0 el foso empieza vacío", sim.profundidad_casilla(c) == 0.0 and sim.profundidad_casilla(Vector2i(16, 13)) == 0.0)
	# Camino real: bajar al foso por la fila 13, subir por el fondo hasta (16,10) y trepar a la losa (16,9).
	colocar_jugador(Vector2i(14, 13))
	await avanzar(10)
	var ok1: bool = await mover_hacia(Vector2i(16, 13), 12.0, 0.25)
	var ok2: bool = await mover_hacia(Vector2i(16, 10), 12.0, 0.25)
	var ok3: bool = await mover_hacia(Vector2i(16, 9), 12.0, 0.25)
	await avanzar_s(1.5)
	_ok("4.1 llega a la losa T_C (16,9) andando: baja al foso, lo recorre y trepa el borde norte", ok1 and ok2 and ok3 and celda_jugador() == Vector2i(16, 9) and absf(jugador.position.y - alto) < 0.05, "celda %s y %.3f" % [str(celda_jugador()), jugador.position.y])
	# La losa abrió el manantial (presencia): el agua sube.
	await avanzar_s(8.0)
	var abiertas: bool = Terreno3D.cauces_abiertos.has(Vector2i(16, 13))
	_ok("4.2 pisar la losa abre el cauce a la simulación", abiertas)
	# Sigue siendo el mismo foso con agua; mientras es 'c' sigue siendo hueco.
	var superf: Array = []
	var prev: float = -1.0
	var sube_siempre: bool = true
	var d_nado: float = -1.0
	var t_nado: float = -1.0
	# El jugador baja otra vez al foso por la fila 12 (16,12) y se queda: el agua le llega.
	colocar_jugador(Vector2i(16, 12))
	await avanzar(5)
	var t0: float = reloj.t
	var d_ant: float = 0.0
	while reloj.t - t0 < 90.0:
		await avanzar_s(1.0)
		var cj: Vector2i = celda_jugador()
		var d: float = sim.profundidad_casilla(cj)
		var s: float = Terreno3D.superficie_agua(cj)
		superf.append(snappedf(s, 0.01))
		if s < prev - 0.01 and d > d_ant - 0.001:
			sube_siempre = false
		prev = s
		d_ant = d
		if bool(jugador.get("nadando")) and t_nado < 0.0:
			t_nado = reloj.t - t0
			d_nado = d
			break
	_ok("4.3 el agua sube desde el fondo (superficie en la casilla del jugador: %s)" % str(superf.slice(0, 8)), superf.size() > 1 and float(superf[0]) <= fondo + 0.2 and float(superf[superf.size() - 1]) > fondo + 0.2)
	_ok("4.4 el jugador dentro NO nada hasta que el agua es agua (≥ UMBRAL_AGUA %.2f) y entonces nada (a %.2f u de agua, %.0f s)" % [AguaSim3D.UMBRAL_AGUA, d_nado, t_nado], t_nado > 0.0 and d_nado >= AguaSim3D.UMBRAL_AGUA - 0.02 and d_nado < AguaSim3D.UMBRAL_AGUA + 0.35, "nadando %s" % str(jugador.get("nadando")))
	# Mientras sube, el jugador flota con la superficie (superficie − HUNDIDO).
	await avanzar_s(10.0)
	var cj2: Vector2i = celda_jugador()
	var s2: float = Terreno3D.superficie_agua(cj2)
	var hundido: float = float(jugador.get("HUNDIDO")) if jugador.get("HUNDIDO") != null else 0.35
	_ok("4.5 sigue nadando y flota en la superficie del foso (y %.3f, superficie %.3f − 0,35)" % [jugador.position.y, s2], bool(jugador.get("nadando")) and absf(jugador.position.y - (s2 - 0.35)) < 0.12, "celda %s" % str(cj2))
	await avanzar_s(50.0)
	# Nivel final: cada casilla del foso al mismo nivel de agua y por debajo del borde.
	var perfil: Array = []
	var s_min: float = INF
	var s_max: float = -INF
	for y in range(11, 21):
		var q := Vector2i(16, y)
		var sq: float = sim.superficie_en(Terreno3D.centro_de(q, 0.0))
		perfil.append("%.2f" % sq)
		if sim.profundidad_casilla(q) > 0.05:
			s_min = minf(s_min, sq)
			s_max = maxf(s_max, sq)
	_ok("4.6 el agua queda a su nivel dentro del hueco: por debajo del borde (%.2f) y plana entre casillas (%.2f..%.2f)" % [alto, s_min, s_max], s_max < alto and s_max - s_min < 0.25, "perfil col 16: " + " ".join(perfil))
	_ok("4.7 la casilla del jugador es agua de verdad (es_agua) y se nada", Terreno3D.es_agua(celda_jugador()) and Terreno3D.se_nada(celda_jugador()))
	# Bloques opacos: ninguno de los bloques de agua `_agua_cauce` se enseña con agua física.
	var visibles: int = 0
	for q in (maqueta.get("_agua_cauce") as Dictionary).keys():
		if ((maqueta.get("_agua_cauce") as Dictionary)[q] as MeshInstance3D).visible:
			visibles += 1
	_ok("4.8 con agua física no se enseña ningún bloque opaco de agua (los «bloques blancos»)", visibles == 0, "%d visibles" % visibles)
	# El tronco: ha subido con el agua y su casilla es puente.
	var tr: TroncoEstanque3D = maqueta.get_node("Reglas").get("_tronco_estanque") as TroncoEstanque3D
	if tr != null:
		_ok("4.9 el tronco del estanque ha subido del fondo a ras con el agua", tr.abierto and absf(tr.position.y + TroncoEstanque3D.RADIO_MODELO - alto) < 0.12, "y %.3f abierto %s" % [tr.position.y, str(tr.abierto)])
	# El foso con agua conserva su forma (sigue siendo foso aunque ya sea agua).
	var pozos: Dictionary = maqueta.get("_pozos_cauce")
	var n_vis: int = 0
	for q in (maqueta.get("_tapas_cauce") as Dictionary).keys():
		if pozos.has(q) and (pozos[q] as Node3D).visible:
			n_vis += 1
	_ok("4.10 con el agua, las 15 casillas siguen dibujadas como foso", n_vis == 15, "%d" % n_vis)




