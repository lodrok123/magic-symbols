extends "res://herramientas/escenario_base.gd"
## 23/11 (puzles por bioma): las tres plantillas nuevas del catálogo del generador, JUGADAS de verdad. Para cada una y CADA solución por separado (se recarga el mapa entre
## una y otra: lo resuelto no se deshace) el escenario genera un mapa con la plantilla puesta a mano en una sala, lo exporta con un nombre temporal, lo carga y lo juega
## con las piezas de verdad y con hechizos reales (`lanzar_a_celda`: el hechizo sale del Lanzador3D y llega al objeto por su `on_spell_hit`), no llamando acciones.
##   P1 `puente_aliviadero` (Bosque, fuego): (A) fuego a la cuerda → el puente se tiende · (B) fuego al tapón → el cauce se vacía por el desagüe.
##   P3 `cofre_balsa` (Ruinas, agua o fuego): (A) agua al pulsador → la balsa trae el cofre · (B) fuego al tapón → el foso seco · (C) llenar a medias y vaciar.
##   P5 `veta_dos_caminos` (Cuevas, tierra y fuego): estado inicial y golpes que NO resuelven · (A) tierra en el hueco + fuego al cristal · (B) prisma girado + fuego al cristal.
## Al acabar borra los mapas y escenas temporales.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_catalogo_demo.gd
## Con `-- p1`, `-- p3` o `-- p5` juega solo esa plantilla.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const PREFIJO: String = "CatDemo"
const UMBRAL_PISABLE: float = 0.25                     ## con menos agua que esto (u) el cauce se pisa

## Mira cada fotograma si la jugadora nada: un cruce «andando» que en realidad es a nado no resuelve el puzle.
class VigiaNado extends Node:
	var jugador: Node = null
	var nado_s: float = 0.0
	func _process(delta: float) -> void:
		if jugador != null and is_instance_valid(jugador) and bool(jugador.get("nadando")):
			nado_s += delta

var _vigia: VigiaNado = null
var _nombres: Array = []
var _m: Dictionary = {}
var _z: Puzle3D = null
var _o: Vector2i = Vector2i.ZERO                       ## la casilla del mapa donde cae la esquina (0,0) de la plantilla
var _tw: int = 0                                       ## ancho de la plantilla ya estirada


func _escenario() -> void:
	_limpiar()
	var solo: PackedStringArray = OS.get_cmdline_user_args()
	var t0: float = Time.get_ticks_msec() * 0.001
	if solo.is_empty() or solo.has("p1"):
		await _p1("A")
		await _p1("B")
	if solo.is_empty() or solo.has("p3"):
		await _p3("A")
		await _p3("B")
		await _p3("C")
	if solo.is_empty() or solo.has("p5"):
		await _p5("0")
		await _p5("A")
		await _p5("B")
	_limpiar()
	print("TIEMPO DE PARED: %.0f s" % (Time.get_ticks_msec() * 0.001 - t0))


# ---------------------------------------------------------------------------------------------------------------------
#  Armazón: generar, exportar, cargar
# ---------------------------------------------------------------------------------------------------------------------

func _limpiar() -> void:
	for n in _nombres:
		for ruta in [Exportador.ruta_mapa(String(n)), Exportador.ruta_escena(String(n))]:
			if FileAccess.file_exists(ruta):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	_nombres.clear()


## Las palabras de la línea `; pieza <id> …` del mapa generado (vacío si no está).
func _linea(id: String) -> PackedStringArray:
	for l in _m["lineas"]:
		var t: PackedStringArray = String(l).substr(1).strip_edges().split(" ", false)
		if t.size() >= 5 and t[0] == "pieza" and t[1] == id:
			return t
	return PackedStringArray()


## Una casilla de la plantilla (coordenadas locales) llevada al mapa.
func _c(x: int, y: int) -> Vector2i:
	return _o + Vector2i(x, y)


## Genera un mapa con la plantilla `cid` puesta a mano en la primera sala libre donde cabe (salas, semillas 1…), lo exporta con un nombre temporal, recarga el juego y
## deja listos `_z`, `_o` y `_tw`. `ancla` es la pieza local que fija la esquina de la plantilla y (dx, dy) su casilla local.
func _caso(cid: String, etiqueta: String, ancla: String, dx: int, dy: int) -> bool:
	Flags.nuevo()
	Estado.nuevo()
	var nombre: String = PREFIJO + etiqueta
	_nombres.append(nombre)
	_m = {}
	for semilla in range(1, 25):
		var par: Dictionary = {"algoritmo": "salas", "semilla": semilla, "enemigos": 0.0, "nombre": nombre}
		var base: Dictionary = Generador.new().generar(par)
		for sala in base["salas"]:
			if String(sala["rol"]) == "inicio":
				continue
			var m: Dictionary = Generador.new().generar(par, {}, {}, {int(sala["id"]): cid})
			if (m["puzles"] as Dictionary).get(int(sala["id"]), "") == cid and (m["errores"] as Array).is_empty():
				_m = m
				break
		if not _m.is_empty():
			break
	_ok("%s: el generador pone «%s» en una sala" % [etiqueta, cid], not _m.is_empty())
	if _m.is_empty():
		return false
	var a: PackedStringArray = _linea("cat1_" + ancla)
	_o = Vector2i(a[3].to_int() - dx, a[4].to_int() - dy)
	if cid == "puente_aliviadero":
		var ca: PackedStringArray = _linea("cat1_cauce")
		var fin: String = ""
		for k in ca:
			if k.begins_with("celdas="):
				fin = k.substr(k.rfind("..") + 2)
		_tw = fin.split(",")[0].to_int() - _o.x + 1
	var res: Dictionary = Exportador.exportar(_m, true)
	_ok("%s: se exporta el mapa temporal %s" % [etiqueta, nombre], bool(res.get("ok", false)), str(res.get("error", "")))
	if not bool(res.get("ok", false)):
		return false
	if maqueta != null:
		maqueta.queue_free()
		maqueta = null
		await avanzar(8)
	await cargar(Exportador.ruta_escena(nombre), true)
	if maqueta == null:
		return false
	await avanzar(20)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("%s: el nivel monta sus piezas sin avisos" % etiqueta, _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "sin Puzle3D")
	lanzador.tinta = null
	return _z != null


# ---------------------------------------------------------------------------------------------------------------------
#  Medidas
# ---------------------------------------------------------------------------------------------------------------------

func _prof(c: Vector2i) -> float:
	return Terreno3D.agua_sim.profundidad_casilla(c)


## Lo que la jugadora puede pisar: ni agua ni foso con agua (`es_agua`) y suelo alcanzable sin nadar.
func _pisa(c: Vector2i) -> bool:
	return not Terreno3D.es_agua(c) and Terreno3D.pisable(c, 0, true, 1, false)


func _todas(celdas: Array, cond: Callable) -> bool:
	for c in celdas:
		if not bool(cond.call(c)):
			return false
	return true


func _rect(x0: int, y0: int, x1: int, y1: int) -> Array:
	var r: Array = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			r.append(_c(x, y))
	return r


## Espera (tiempo de simulación) a que se cumpla `cond`; devuelve los segundos que tardó o -1 si no llegó en `max_s`.
func _hasta(cond: Callable, max_s: float) -> float:
	var t: float = 0.0
	while not bool(cond.call()):
		if t >= max_s:
			return -1.0
		t += await avanzar_s(0.1)
	return t


func _dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Distancia (u) de `p` a la casilla pisable más cercana de `zona`.
func _mas_cerca(p: Vector3, zona: Array) -> Dictionary:
	var mejor: float = INF
	var donde: Vector2i = Vector2i(-1, -1)
	for c in zona:
		if _pisa(c as Vector2i):
			var d: float = _dist(Terreno3D.centro_de(c as Vector2i, 0.0), p)
			if d < mejor:
				mejor = d
				donde = c
	return {"d": mejor, "c": donde}


## E de verdad: la tecla `interactuar` (CofrePuzle comprueba el alcance de 2,7 u). Espera a que acabe de abrirse.
func _pulsar_e_cofre(cofre: Variant, max_s: float = 6.0) -> bool:
	var t0: float = reloj.t
	while reloj.t - t0 < max_s and not bool(cofre.get("es_abierto")):
		_tecla(KEY_E, true)
		await avanzar(2)
		_tecla(KEY_E, false)
		await avanzar_s(0.3)
	return bool(cofre.get("es_abierto"))


## Anda de verdad (WASD) a `c` y dice si llegó. Los segundos que se pasó nadando quedan en `_nado_s`.
var _nado_s: float = 0.0


func _andar(c: Vector2i, max_s: float = 15.0) -> bool:
	if _vigia == null or not is_instance_valid(_vigia):
		_vigia = VigiaNado.new()
		root.add_child(_vigia)
	_vigia.jugador = jugador
	_vigia.nado_s = 0.0
	var llego: bool = await mover_hacia(c, max_s, 0.1)
	_nado_s = _vigia.nado_s
	return llego


# ---------------------------------------------------------------------------------------------------------------------
#  P1 · El puente y el aliviadero
# ---------------------------------------------------------------------------------------------------------------------

func _p1(sol: String) -> void:
	var et: String = "P1" + sol
	if not await _caso("puente_aliviadero", et, "desague", 0, 2):
		return
	# La plantilla: fila 0 orilla norte, filas 1-2 el cauce, fila 3 orilla sur. El desagüe está en (0,2), el tapón en (1,2) y el cauce de x2 a $X1.
	var xc: int = int((_tw - 1) * 0.5)
	var cauce: Array = _rect(2, 1, _tw - 1, 2)
	var puente: Array = [_c(xc, 1), _c(xc, 2)]
	var cuerda: Cuerda3D = _z.nodo("cat1_cuerda") as Cuerda3D
	var tapon: Node = _z.nodo("cat1_tapon")
	_ok(et + ": hay cuerda, tapón y la sala mide %d de ancho (puente en x=%d)" % [_tw, xc], cuerda != null and tapon != null and _tw >= 5)
	if cuerda == null or tapon == null:
		return
	var t_llena: float = await _hasta(func() -> bool: return _todas(cauce, func(c: Vector2i) -> bool: return Terreno3D.es_agua(c)), 40.0)
	print("      [P1] el cauce (%d casillas) tarda %.1f s en estar inundado" % [cauce.size(), t_llena])
	_ok(et + ": al empezar todas las casillas del cauce son agua y NO se pisan", t_llena >= 0.0 and _todas(cauce, func(c: Vector2i) -> bool: return not _pisa(c)) and _todas(puente, func(c: Vector2i) -> bool: return not _pisa(c)))
	var sur: int = _o.y + 3
	# Aserción (23/11, decisión de Pablo «desactivar el nadar»): sin hacer nada, andando contra el cauce lleno la jugadora NO entra al agua: se queda en la orilla sur.
	colocar_jugador(Vector2i(_o.x + xc, sur))
	await avanzar_s(0.3)
	var cruzo_sin_nada: bool = await _andar(Vector2i(_o.x + xc, _o.y), 12.0)
	print("      [P1] control: andando hacia el norte con el cauce lleno acaba en %s (llegó: %s, %.1f s nadando)" % [str(celda_jugador()), str(cruzo_sin_nada), _nado_s])
	_ok(et + ": con el cauce lleno la jugadora NO entra al agua: no cruza, no nada y se queda en la orilla sur (%.1f s nadando)" % _nado_s,
		not cruzo_sin_nada and _nado_s == 0.0 and not bool(jugador.get("nadando")) and celda_jugador().y >= sur, str(celda_jugador()))
	if sol == "A":
		# La cuerda está en la cabecera sur del puente (xc, 3): se dispara desde la casilla de al lado, por la propia orilla, sin cruzar agua.
		var ok_tiro: bool = lanzar_a_celda("fuego", ["flecha"], _c(xc, 3), _c(xc - 1, 3))
		_ok(et + ": fuego + flecha a la cuerda (desde la casilla vecina de la orilla sur) sale", ok_tiro)
		var t: float = await _hasta(func() -> bool: return _todas(puente, func(c: Vector2i) -> bool: return _pisa(c)), 8.0)
		print("      [P1-A] el puente se tiende a los %.1f s del golpe (cuerda rota %s)" % [t, str(cuerda.rota_ya)])
		_ok(et + ": la cuerda se rompe y las casillas del puente se pisan en <= 6 s (%.1f s)" % t, cuerda.rota_ya and t >= 0.0 and t <= 6.0)
		_ok(et + ": el resto del cauce sigue siendo agua (el puente es el único paso)", _todas(_rect(2, 1, _tw - 1, 2).filter(func(c: Vector2i) -> bool: return c.x != _o.x + xc), func(c: Vector2i) -> bool: return Terreno3D.es_agua(c)))
		colocar_jugador(Vector2i(_o.x + xc, sur))
		await avanzar_s(0.3)
		var llego: bool = await _andar(Vector2i(_o.x + xc, _o.y))
		_ok(et + ": se cruza ANDANDO por el puente hasta la orilla norte, sin nadar (%.1f s nadando)" % _nado_s, llego and _nado_s == 0.0, str(celda_jugador()))
	else:
		# El tapón (1,2) se ve desde la orilla sur: se dispara desde la casilla de debajo (1,3).
		var ok_tiro: bool = lanzar_a_celda("fuego", ["flecha"], _c(1, 2), _c(1, 3))
		_ok(et + ": fuego + flecha al tapón (desde la orilla sur, justo debajo) sale", ok_tiro)
		var t: float = await _hasta(func() -> bool: return _todas(cauce, func(c: Vector2i) -> bool: return _prof(c) < UMBRAL_PISABLE), 90.0)
		print("      [P1-B] el cauce tarda %.1f s en bajar de %.2f u en TODAS sus casillas (máx. ahora %.2f; tapón abierto %s)" % [t, UMBRAL_PISABLE, _max(cauce), str(tapon.get("abierta"))])
		_ok(et + ": el tapón se derrite y todo el cauce baja de %.2f u (%.1f s)" % [UMBRAL_PISABLE, t], t >= 0.0, "máx. %.2f" % _max(cauce))
		if t > 15.0 or t < 0.0:
			_aviso(et + ": el vaciado tarda más de 15 s", "%.1f s" % t)
		_ok(et + ": el cauce vacío se pisa en todas sus casillas", _todas(cauce, func(c: Vector2i) -> bool: return _pisa(c)))
		colocar_jugador(Vector2i(_o.x + xc, sur))
		await avanzar_s(0.3)
		var llego: bool = await _andar(Vector2i(_o.x + xc, _o.y))
		_ok(et + ": se cruza ANDANDO por el fondo seco hasta la orilla norte, sin nadar (%.1f s nadando)" % _nado_s, llego and _nado_s == 0.0, str(celda_jugador()))


## Diagnóstico: letra, agua, profundidad y si se pisa, de cada casilla.
func _diag(etiqueta: String, celdas: Array) -> void:
	var t: PackedStringArray = PackedStringArray()
	for c in celdas:
		var cc: Vector2i = c
		t.append("%s:%s%s %.2f%s" % [str(cc), Terreno3D.letra_de(cc), " agua" if Terreno3D.es_agua(cc) else "", _prof(cc), " PISA" if _pisa(cc) else ""])
	print("      [diag %s] %s" % [etiqueta, " | ".join(t)])


func _max(celdas: Array) -> float:
	var m: float = 0.0
	for c in celdas:
		m = maxf(m, _prof(c as Vector2i))
	return m


# ---------------------------------------------------------------------------------------------------------------------
#  P3 · El cofre que viene a ti
# ---------------------------------------------------------------------------------------------------------------------

func _p3(sol: String) -> void:
	var et: String = "P3" + sol
	if not await _caso("cofre_balsa", et, "foso", 3, 2):
		return
	var foso: Array = _rect(3, 2, 5, 4)
	var zona: Array = _rect(-2, -2, 11, 10)
	var balsa: Balsa3D = _z.nodo("cat1_balsa") as Balsa3D
	var cofre: Variant = _z.nodo("cat1_cofre")
	_ok(et + ": hay balsa y cofre", balsa != null and cofre != null)
	if balsa == null or cofre == null:
		return
	await avanzar_s(6.0)
	var cerca0: Dictionary = _mas_cerca((cofre as Node3D).global_position, zona)
	_ok(et + ": al empezar el foso (0,35 u) no se pisa, la balsa descansa sin flotar en el fondo y su ruta (con el reposo) mide %d" % balsa.ruta.size(),
		_todas(foso, func(c: Vector2i) -> bool: return not _pisa(c)) and not balsa.flota and not balsa.atracada and balsa.celda_actual() == _c(5, 2) and balsa.ruta.size() == 5 and balsa.ruta.back() == _c(3, 4),
		"prof. %s" % str(profundidades(foso)))
	_ok(et + ": al empezar el cofre queda a %.2f u de la casilla pisable más cercana %s (> %.1f)" % [cerca0["d"], str(cerca0["c"]), Puzle3D.ALCANCE_COFRE], float(cerca0["d"]) > Puzle3D.ALCANCE_COFRE)
	colocar_jugador(cerca0["c"])
	await avanzar_s(0.3)
	_ok(et + ": y con E desde esa casilla el cofre NO se abre", not await _pulsar_e_cofre(cofre, 1.5))
	# Aserción (23/11, decisión de Pablo «desactivar el nadar»): con el foso inundado la jugadora que anda hacia el agua desde la orilla sur NO entra.
	colocar_jugador(_c(4, 5))
	await avanzar_s(0.3)
	var entro_foso: bool = await _andar(_c(4, 3), 8.0)
	print("      [P3] control: andando al foso inundado acaba en %s (llegó: %s, %.1f s nadando)" % [str(celda_jugador()), str(entro_foso), _nado_s])
	_ok(et + ": con el foso inundado la jugadora NO entra al agua: no llega, no nada y se queda en la orilla (%.1f s nadando)" % _nado_s,
		not entro_foso and _nado_s == 0.0 and not bool(jugador.get("nadando")) and celda_jugador().y >= (_c(4, 5)).y, str(celda_jugador()))
	var desde_riego: Vector2i = _c(2, 7)
	var desde_tapon: Vector2i = _c(4, 5)
	if sol == "A" or sol == "C":
		_ok(et + ": agua + flecha al pulsador de riego (2,6) sale", lanzar_a_celda("agua", ["flecha"], _c(2, 6), desde_riego))
	if sol == "A":
		var t_atraca: float = await _hasta(func() -> bool: return balsa.atracada, 40.0)
		print("      [P3-A] la balsa atraca a los %.1f s del riego (flota: %s)" % [t_atraca, str(balsa.flota)])
		_ok(et + ": la balsa atraca en el muelle en <= 20 s (%.1f s)" % t_atraca, t_atraca >= 0.0 and t_atraca <= 20.0 and balsa.celda_actual() == _c(3, 4))
		var cerca: Dictionary = _mas_cerca((cofre as Node3D).global_position, zona)
		_ok(et + ": el cofre queda a %.2f u de la casilla pisable %s (<= %.1f)" % [cerca["d"], str(cerca["c"]), Puzle3D.ALCANCE_COFRE], float(cerca["d"]) <= Puzle3D.ALCANCE_COFRE)
		colocar_jugador(cerca["c"])
		var oro0: int = Estado.i().oro
		await avanzar_s(0.3)
		_ok(et + ": se abre con E desde la orilla y da su botín (40 de oro)", await _pulsar_e_cofre(cofre) and Estado.i().oro - oro0 == 40, "oro +%d" % (Estado.i().oro - oro0))
	elif sol == "B":
		_ok(et + ": fuego + flecha al tapón (5,5) (desde la orilla, casilla vecina) sale", lanzar_a_celda("fuego", ["flecha"], _c(5, 5), desde_tapon))
		var t_seco: float = await _hasta(func() -> bool: return _todas(foso, func(c: Vector2i) -> bool: return _prof(c) < UMBRAL_PISABLE), 90.0)
		print("      [P3-B] el foso tarda %.1f s en bajar de %.2f u en todas sus casillas (máx. ahora %.2f)" % [t_seco, UMBRAL_PISABLE, _max(foso)])
		_ok(et + ": el foso se seca (< %.2f u en todas sus casillas) en %.1f s" % [UMBRAL_PISABLE, t_seco], t_seco >= 0.0, "máx. %.2f" % _max(foso))
		var cerca: Dictionary = _mas_cerca((cofre as Node3D).global_position, zona)
		_ok(et + ": la casilla vecina del cofre es pisable (%s, a %.2f u)" % [str(cerca["c"]), cerca["d"]], float(cerca["d"]) <= Puzle3D.ALCANCE_COFRE and _pisa(_c(5, 3)))
		# Se baja andando desde la orilla: del suelo al foso seco.
		colocar_jugador(_c(5, 6))
		await avanzar_s(0.3)
		var llego: bool = await _andar(_c(5, 3))
		_ok(et + ": se llega ANDANDO por el desagüe al foso hasta la casilla vecina del cofre, sin nadar (%.1f s nadando)" % _nado_s, llego and _nado_s == 0.0, str(celda_jugador()))
		var oro0: int = Estado.i().oro
		_ok(et + ": el cofre se abre con E desde esa casilla y da su botín (40 de oro)", await _pulsar_e_cofre(cofre) and Estado.i().oro - oro0 == 40, "oro +%d" % (Estado.i().oro - oro0))
	else:
		# C · llenar a medias y vaciar: en cuanto la balsa flote (el foso lleva algo de agua) se funde el tapón y se espera a que todo se asiente.
		var t_flota: float = await _hasta(func() -> bool: return balsa.flota, 30.0)
		_ok(et + ": el riego hace flotar la balsa (%.1f s)" % t_flota, t_flota >= 0.0)
		print("      [P3-C] la balsa flota a los %.1f s; está en %s (índice %d)" % [t_flota, str(balsa.celda_actual()), balsa.indice])
		_ok(et + ": fuego + flecha al tapón con el foso a medias sale", lanzar_a_celda("fuego", ["flecha"], _c(5, 5), desde_tapon))
		var t_fin: float = await _hasta(func() -> bool:
			var seco: bool = _todas(foso, func(c: Vector2i) -> bool: return _prof(c) < UMBRAL_PISABLE)
			return balsa.atracada or seco, 120.0)
		await avanzar_s(10.0)           # que se asiente (el riego aún puede estar echando agua)
		print("      [P3-C] fin a los %.1f s: atracada %s, seco %s, balsa en %s (flota %s), máx. foso %.2f" % [t_fin, str(balsa.atracada), str(_todas(foso, func(c: Vector2i) -> bool: return _prof(c) < UMBRAL_PISABLE)), str(balsa.celda_actual()), str(balsa.flota), _max(foso)])
		var cerca: Dictionary = _mas_cerca((cofre as Node3D).global_position, zona)
		_ok(et + ": al final el cofre está a %.2f u de una casilla pisable %s: nunca queda inalcanzable" % [cerca["d"], str(cerca["c"])], float(cerca["d"]) <= Puzle3D.ALCANCE_COFRE)
		if float(cerca["d"]) <= Puzle3D.ALCANCE_COFRE:
			colocar_jugador(cerca["c"])
			var oro0: int = Estado.i().oro
			await avanzar_s(0.3)
			_ok(et + ": y se abre con E desde ella", await _pulsar_e_cofre(cofre) and Estado.i().oro - oro0 == 40, "oro +%d" % (Estado.i().oro - oro0))


# ---------------------------------------------------------------------------------------------------------------------
#  P5 · La veta de los dos caminos
# ---------------------------------------------------------------------------------------------------------------------

func _p5(sol: String) -> void:
	var et: String = "P5" + sol
	if not await _caso("veta_dos_caminos", et, "cristal", 2, 5):
		return
	var cristal: CristalPulso3D = _z.nodo("cat1_cristal") as CristalPulso3D
	var receptor: ReceptorPulso3D = _z.nodo("cat1_receptor") as ReceptorPulso3D
	var prisma: PrismaPulso3D = _z.nodo("cat1_prisma") as PrismaPulso3D
	_ok(et + ": hay cristal, receptor de fuego y prisma", cristal != null and receptor != null and prisma != null and receptor.elemento == "fuego")
	if cristal == null or receptor == null or prisma == null:
		return
	var hueco: Vector2i = _c(5, 5)
	var desde: Vector2i = _c(2, 6)
	await avanzar_s(4.0)
	_ok(et + ": al empezar el receptor está apagado, el cristal no ha latido (dormido) y el prisma mira al norte", not receptor.activo and cristal.latidos == 0 and prisma.dir == "n")
	if sol == "0":
		var l0: int = cristal.latidos
		_ok(et + ": fuego + flecha al cristal sale", lanzar_a_celda("fuego", ["flecha"], _c(2, 5), desde))
		await avanzar_s(14.0)
		_ok(et + ": el golpe de fuego late el cristal (%d pulso) y, sin hacer nada más, el receptor sigue apagado" % (cristal.latidos - l0), cristal.latidos > l0 and not receptor.activo, "emisiones del prisma %d" % prisma.emisiones)
		var l1: int = cristal.latidos
		_ok(et + ": tierra + flecha al cristal sale", lanzar_a_celda("tierra", ["flecha"], _c(2, 5), desde))
		await avanzar_s(14.0)
		_ok(et + ": el golpe de tierra late el cristal (%d pulso) y el receptor de fuego sigue apagado" % (cristal.latidos - l1), cristal.latidos > l1 and not receptor.activo)
		return
	if sol == "A":
		_ok(et + ": tierra + barrera sobre el hueco (5,5) sale", await _lanzar_en_punto("tierra", ["barrera"], hueco, _c(5, 6)))
		await avanzar_s(1.5)
		_ok(et + ": el bloque de tierra tiende el hueco", Pulso3D.enlace_tendido(hueco))
		colocar_jugador(desde)
		await avanzar_s(0.3)
		var l0: int = cristal.latidos
		var t_golpe: float = reloj.t
		_ok(et + ": fuego + flecha al cristal sale", lanzar_a_celda("fuego", ["flecha"], _c(2, 5), desde))
		var t: float = await _hasta(func() -> bool: return receptor.activo, 20.0)
		print("      [P5-A] el receptor se activa a los %.1f s del golpe (hueco tendido: %s)" % [t, str(Pulso3D.enlace_tendido(hueco))])
		_ok(et + ": el pulso de fuego cruza por el trayecto corto y ACTIVA el receptor (%.1f s)" % t, t >= 0.0 and cristal.latidos > l0)
		_ok(et + ": el prisma sigue sin girar (mira al norte, a la pared): el ramal largo no aporta nada", prisma.dir == "n" and prisma.giros == 0)
	else:
		# B · girar el prisma de verdad: un golpe de hechizo desde el sur de la columna x=1 (la veta larga), sin pisar el circuito más de lo necesario.
		var giros0: int = prisma.giros
		_ok(et + ": fuego + flecha al prisma (2,1) sale", lanzar_a_celda("agua", ["flecha"], _c(2, 1), _c(2, 3)))
		await _hasta(func() -> bool: return prisma.giros > giros0, 4.0)
		_ok(et + ": un golpe de hechizo gira el prisma de norte a este", prisma.dir == "e", prisma.dir)
		_ok(et + ": girar el prisma por sí solo no activa el receptor", not receptor.activo)
		colocar_jugador(desde)
		await avanzar_s(0.3)
		var l0: int = cristal.latidos
		_ok(et + ": fuego + flecha al cristal sale", lanzar_a_celda("fuego", ["flecha"], _c(2, 5), desde))
		var t: float = await _hasta(func() -> bool: return receptor.activo, 25.0)
		print("      [P5-B] el receptor se activa a los %.1f s del golpe por el ramal largo (emisiones del prisma %d, sin tierra: hueco tendido %s)" % [t, prisma.emisiones, str(Pulso3D.enlace_tendido(hueco))])
		_ok(et + ": el pulso de fuego sube, cruza por el prisma y baja: ACTIVA el receptor sin tierra (%.1f s)" % t, t >= 0.0 and cristal.latidos > l0 and not Pulso3D.enlace_tendido(hueco))
		_ok(et + ": el flag del receptor se pone (la salida del puzle)", Flags.i().tiene(receptor.flag), receptor.flag)


## Como `_lanzar` de la Cueva Resonante: lo que nace donde se apunta (la barrera de tierra) sale en el punto del suelo, dentro del anillo de 3 casillas de la jugadora.
func _lanzar_en_punto(elemento: String, glifos: Array, objetivo: Vector2i, desde: Vector2i) -> bool:
	colocar_jugador(desde)
	await avanzar_s(0.3)
	var yo: Vector3 = jugador.position
	var meta: Vector3 = Terreno3D.centro_de(objetivo, 0.0)
	var hacia: Vector3 = Vector3(meta.x - yo.x, 0.0, meta.z - yo.z)
	var tope: float = Lanzador3D.ALCANCE_ORIGEN * Terreno3D.casilla
	var origen: Vector3 = yo + (hacia if hacia.length() <= tope else hacia.normalized() * tope)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	return lanzador.lanzar_pagina_ya(0, origen, hacia.normalized())
