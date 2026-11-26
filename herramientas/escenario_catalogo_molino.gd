extends "res://herramientas/escenario_base.gd"
## 23/11/2026 · AFINADO de la plantilla de catálogo `molino_paso_bajo` (P4 «El molino y el paso bajo», Ruinas/Cuevas, después de Tierra). La estampa en un mapa GENERADO («salas»),
## lo exporta (MolinoCatPrueba), lo carga en el juego y lo juega por código con las piezas reales: la tierra de verdad en la boca (`Lanzador3D.construir_tierra`, la misma puerta que el hechizo,
## como T1a) y el agua al molino con el contrato `on_spell_hit`. Cada caso RECARGA el mapa (lo que se abre o se llena no se deshace). Primero MIDE; al final imprime la tabla.
## Criterios:
##   1 · sin hacer nada, a los 30 s: toda la galería es agua (no se pisa) y la pasarela sigue plegada
##   2 · la boca del desagüe admite tierra con el agua corriendo (`puede_construir_en` == "")
##   3 · (A) tierra en la boca del desagüe → pasarela tendida en ≤ 15 s y su casilla pisable
##   5 · un golpe de Agua al molino, sin tierra (hechizo=no): la rueda se mueve pero no emite `girando` y la pasarela NO se tiende
##   6 · sin tierra el estado no cambia con el tiempo (60 s)
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_catalogo_molino.gd
## Con `-- caso <n>` solo ese caso (0 medida, 1 quieto, 2 A, 4 agua; el 3, la solución B «galería practicable», se eliminó el 23/11: la boca del molino no admite tierra bajo el agua).

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const NOMBRE: String = "MolinoCatPrueba"
const PLANTILLA: String = "molino_paso_bajo"

## Casillas de la plantilla (columna, fila) que el escenario mira; se trasladan con `_off`.
const G_X0: int = 7                    ## la galería: fila 2, de x 7 a 12 (la compuerta está en x 6 y el desagüe en x 5)
const G_X1: int = 12
const G_Y: int = 2
const BOCA_MOLINO: Vector2i = Vector2i(12, 4)
const BOCA_DESAGUE: Vector2i = Vector2i(12, 6)
const PASARELA: Vector2i = Vector2i(9, 2)
const META: Vector2i = Vector2i(9, 1)
const ORILLA_S: Vector2i = Vector2i(9, 3)
const ORILLA_N: Vector2i = Vector2i(9, 1)
const MAX_A_S: float = 15.0

var _m: Dictionary = {}
var _off: Vector2i = Vector2i.ZERO
var z: Puzle3D = null
var mol: Molino3D = null
var pas: Node = null
var _tabla: Array = []


func _escenario() -> void:
	if not _generar():
		return
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var solo: int = int(a[a.find("caso") + 1]) if a.has("caso") and a.find("caso") + 1 < a.size() else -1
	if solo < 0 or solo == 0:
		await _caso_medida()
	if solo < 0 or solo == 1:
		await _caso_quieto()
	if solo < 0 or solo == 2:
		await _caso_a()
	if solo < 0 or solo == 4:
		await _caso_agua()
	_imprimir_tabla()
	_limpiar()


# ---------------------------------------------------------------------------------------------------------------------
#  Generar, cargar y mirar
# ---------------------------------------------------------------------------------------------------------------------

## Una semilla con una sala libre donde quepa la plantilla (autoajuste incluido). Imprime lo que prueba.
func _generar() -> bool:
	for semilla in range(1, 60):
		var base: Dictionary = {"algoritmo": "salas", "semilla": semilla, "ancho": 70, "alto": 60, "sala_min": 4, "sala_max": 7, "estilo": "cueva", "luz": "cueva", "nombre": NOMBRE,
			"enemigos": 0.0, "jarrones": 0.0, "braseros": 0.0, "charcas": 0, "tesoro": false, "llave": false, "barreras": 0, "puzles": 0}
		var g0: Object = Generador.new()
		var m0: Dictionary = g0.generar(base)
		var cand: Array = []
		for s in m0["salas"]:
			if String(s["rol"]) == "":
				cand.append(s)
		cand.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return (x["rect"] as Rect2i).get_area() > (y["rect"] as Rect2i).get_area())
		for s in cand.slice(0, 4):
			var sid: int = int(s["id"])
			var g1: Object = Generador.new()
			var m1: Dictionary = g1.generar(base, {}, {}, {sid: PLANTILLA})
			if (m1["puzles"] as Dictionary).get(sid, "") != PLANTILLA:
				continue
			_m = m1
			var ok_off: bool = false
			for l in (m1["lineas"] as PackedStringArray):
				var t: PackedStringArray = String(l).split(" ", false)
				if t.size() >= 5 and t[0] == ";" and t[1] == "pieza" and t[2].ends_with("_fuente"):
					_off = Vector2i(t[4].to_int() - 5, t[5].to_int() - 5)
					ok_off = true
			_ok("0 la plantilla %s se estampa (semilla %d, sala %d, sala %s, desplazamiento %s)" % [PLANTILLA, semilla, sid, str((s["rect"] as Rect2i)), str(_off)], ok_off)
			if not ok_off:
				return false
			var res: Dictionary = Exportador.exportar(m1, true)
			_ok("0 se exporta el mapa", bool(res.get("ok", false)), str(res.get("error", "")))
			print("  errores del generador: ", m1.get("errores", []), " · avisos: ", m1.get("avisos", []))
			return bool(res.get("ok", false))
	_ok("0 hay una semilla donde cabe la plantilla", false)
	return false


func _c(x: int, y: int) -> Vector2i:
	return _off + Vector2i(x, y)


func _cv(p: Vector2i) -> Vector2i:
	return _off + p


func _cargar_mapa() -> void:
	if maqueta != null:
		maqueta.queue_free()
		maqueta = null
		await avanzar(5)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(Exportador.ruta_escena(NOMBRE), true)
	await avanzar(10)
	z = maqueta.get_node_or_null("Puzles") as Puzle3D
	if z == null:
		z = maqueta.get_node_or_null("Reglas") as Puzle3D
	_ok("0 el nivel trae sus piezas", z != null)
	mol = _nodo_por_sufijo("_molino") as Molino3D
	pas = _nodo_por_sufijo("_pasarela")
	_ok("0 están el molino y la pasarela", mol != null and pas != null, "%s %s" % [mol, pas])
	await avanzar(10)


func _nodo_por_sufijo(suf: String) -> Node:
	for pz in z.piezas():
		var id: String = String(pz.id)
		if id.ends_with(suf) and id.begins_with("cat"):
			return pz.nodo as Node
	return null


func _p(c: Vector2i) -> float:
	return Terreno3D.agua_sim.profundidad_casilla(c)


func _g_max() -> float:
	var m: float = 0.0
	for x in range(G_X0, G_X1 + 1):
		m = maxf(m, _p(_c(x, G_Y)))
	return m


func _g_min() -> float:
	var m: float = INF
	for x in range(G_X0, G_X1 + 1):
		m = minf(m, _p(_c(x, G_Y)))
	return m


func _g_toda_agua() -> bool:
	for x in range(G_X0, G_X1 + 1):
		if not Terreno3D.es_agua(_c(x, G_Y)):
			return false
	return true


func _g_toda_seca() -> bool:
	for x in range(G_X0, G_X1 + 1):
		if _p(_c(x, G_Y)) >= AguaSim3D.UMBRAL_AGUA:
			return false
	return true


func _estado(etiqueta: String) -> void:
	var g: String = ""
	for x in range(G_X0, G_X1 + 1):
		g += "%.2f " % _p(_c(x, G_Y))
	var rio: String = ""
	for x in range(5, 13):
		rio += "%.2f " % _p(_c(x, 5))
	print("      [%s] G(x7..12): %s| fila5(x5..12): %s| brazoM(12,4..3): %.2f %.2f | brazoD(12,6..7): %.2f %.2f | corriente molino %.2f flujo %s proy %.2f w_agua %.2f vel %.2f gira %s pasarela %s" % [
		etiqueta, g, rio, _p(_c(12, 4)), _p(_c(12, 3)), _p(_c(12, 6)), _p(_c(12, 7)), mol.corriente(), str(mol.flujo()), mol.flujo().dot(mol.dir_abajo()), mol._w_agua, mol.velocidad, str(mol.activo), "TENDIDA" if bool(pas.get("tendido")) else "plegada"])


# ---------------------------------------------------------------------------------------------------------------------
#  Casos
# ---------------------------------------------------------------------------------------------------------------------

## 0 · MEDIR: sin tocar nada, cada 5 s durante 40 s.
func _caso_medida() -> void:
	print("== CASO 0 · medida con medio caudal ==")
	await _cargar_mapa()
	_estado("t=0")
	# 23/11: la oleada de arranque, medida fina durante los primeros 10 s (la corriente y su proyección en el sentido bueno, −Z; negativa = hacia +Z, la oleada de la galería al río).
	var arr: Dictionary = {"cmax": 0.0, "pmin": 0.0, "pmax": 0.0, "gira_hasta": -1.0, "tendida": bool(pas.get("tendido"))}
	await avanzar_vigilando(10.0, 0.1, func(t: float) -> void:
		var pr: float = mol.flujo().dot(mol.dir_abajo())
		arr["cmax"] = maxf(float(arr["cmax"]), mol.corriente())
		arr["pmin"] = minf(float(arr["pmin"]), pr)
		arr["pmax"] = maxf(float(arr["pmax"]), pr)
		if mol.activo:
			arr["gira_hasta"] = t
		if bool(pas.get("tendido")):
			arr["tendida"] = true)
	print("      ARRANQUE 0-10 s: corriente máx %.2f u/s · proyección mín %.2f máx %.2f · gira hasta t=%.1f · pasarela tendida en algún momento: %s" % [float(arr["cmax"]), float(arr["pmin"]), float(arr["pmax"]), float(arr["gira_hasta"]), str(arr["tendida"])])
	_estado("t=10")
	for k in range(1, 7):
		await avanzar_s(1.0)
		_estado("t=%d" % (k + 10))
	var t: float = 0.0
	while t < 30.0:
		await avanzar_s(10.0)
		t += 10.0
		_estado("t=%d" % int(t))
	var fl: Vector2 = mol.flujo()
	print("      MEDIDA medio caudal: flujo %s dir_abajo %s proyección %.3f |flujo| %.3f _w_agua %.3f velocidad %.3f umbral %.2f ω_umbral %.3f" % [str(fl), str(mol.dir_abajo()), fl.dot(mol.dir_abajo()), fl.length(), mol._w_agua, mol.velocidad, mol.umbral, mol.omega_umbral()])
	print("      bocas: molino %s (%.2f) desagüe %s (%.2f)" % [lanzador.puede_construir_en(_cv(BOCA_MOLINO)), _p(_cv(BOCA_MOLINO)), lanzador.puede_construir_en(_cv(BOCA_DESAGUE)), _p(_cv(BOCA_DESAGUE))])


## 1 + 6 · quieto: a los 30 s la galería es agua y la pasarela plegada; y 60 s después sigue todo igual.
func _caso_quieto() -> void:
	print("== CASO 1/6 · sin hacer nada ==")
	await _cargar_mapa()
	await avanzar_s(30.0)
	_estado("t=30")
	var agua30: bool = _g_toda_agua()
	var pl30: bool = not bool(pas.get("tendido"))
	var gmin30: float = _g_min()
	_ok("1 a los 30 s todas las casillas de G son agua (mínimo %.2f u ≥ %.2f) y la pasarela sigue plegada" % [gmin30, AguaSim3D.UMBRAL_AGUA], agua30 and pl30)
	# Aserción (23/11, decisión de Pablo «desactivar el nadar»): con la galería inundada la jugadora que anda hacia el agua desde la orilla sur NO entra ni la cruza.
	colocar_jugador(_cv(ORILLA_S))
	await avanzar_s(0.3)
	var cruzo: bool = await mover_hacia(_cv(ORILLA_N), 12.0, 0.6)
	var cj: Vector2i = celda_jugador()
	print("      [1] control: andando al norte con la galería inundada acaba en %s (llegó: %s, nadando: %s)" % [str(cj), str(cruzo), str(jugador.get("nadando"))])
	_ok("1 con la galería inundada la jugadora NO entra al agua: no cruza, no nada y se queda en la orilla sur", not cruzo and not bool(jugador.get("nadando")) and cj.y >= _cv(ORILLA_S).y, str(cj))
	var r: Dictionary = {"cambio": false, "gmin": gmin30, "gmax": _g_max(), "gira": mol.activo}
	await avanzar_vigilando(60.0, 1.0, func(_t: float) -> void:
		r["gmin"] = minf(float(r["gmin"]), _g_min())
		r["gmax"] = maxf(float(r["gmax"]), _g_max())
		if bool(pas.get("tendido")) or not _g_toda_agua() or mol.activo != bool(r["gira"]):
			r["cambio"] = true)
	_estado("t=90")
	_ok("6 sin tierra, 60 s más (30→90 s): nada cambia (G mín %.2f máx %.2f, molino %s, pasarela plegada)" % [float(r["gmin"]), float(r["gmax"]), str(mol.activo)],
		not bool(r["cambio"]))
	_tabla.append(["sin tierra a 30 s: G mínimo / máximo", "%.2f / %.2f u" % [gmin30, _g_max()]])
	_tabla.append(["sin tierra: corriente molino / gira", "%.2f u/s / %s" % [mol.corriente(), str(mol.activo)]])
	_tabla.append(["bocas con el agua corriendo: molino / desagüe", "%.2f / %.2f u" % [_p(_cv(BOCA_MOLINO)), _p(_cv(BOCA_DESAGUE))]])


## 2 + 3 · (A) tierra en la boca del desagüe.
func _caso_a() -> void:
	print("== CASO 2/3 · (A) tierra en la boca del DESAGÜE ==")
	await _cargar_mapa()
	await avanzar_s(30.0)
	var bd: Vector2i = _cv(BOCA_DESAGUE)
	_ok("2 con el agua corriendo la boca del desagüe admite tierra (%.2f u): «%s»" % [_p(bd), lanzador.puede_construir_en(bd)], lanzador.puede_construir_en(bd) == "")
	colocar_jugador(_c(10, 6))
	_ok("3 la tierra se levanta en la boca del desagüe", lanzador.construir_tierra(bd))
	var r: Dictionary = {"t": -1.0, "t_gira": -1.0, "cmax": 0.0, "wmax": 0.0}
	var t0: float = reloj.t
	await avanzar_vigilando(24.0, 0.5, func(t: float) -> void:
		if float(r["t"]) < 0.0 and bool(pas.get("tendido")):
			r["t"] = t
		if float(r["t_gira"]) < 0.0 and mol.activo:
			r["t_gira"] = t
		r["cmax"] = maxf(float(r["cmax"]), mol.corriente())
		r["wmax"] = maxf(float(r["wmax"]), absf(mol.velocidad))
		if int(t * 2.0) % 10 == 0:
			_estado("A t=%.1f" % t))
	_ok("3 (A) la pasarela se tiende en %.1f s (≤ %.0f s): molino gira a los %.1f s, corriente máx %.2f, ω máx %.2f" % [float(r["t"]), MAX_A_S, float(r["t_gira"]), float(r["cmax"]), float(r["wmax"])],
		float(r["t"]) > 0.0 and float(r["t"]) <= MAX_A_S)
	var l: String = Terreno3D.letra_de(_cv(PASARELA))
	await avanzar_s(3.0)
	l = Terreno3D.letra_de(_cv(PASARELA))
	_ok("3 la casilla de la pasarela pasa a «b» (pisable): «%s»" % l, l == "b")
	_estado("A fin")
	_tabla.append(["(A) pasarela tendida a los", "%.1f s (molino gira %.1f s)" % [float(r["t"]), float(r["t_gira"])]])
	_tabla.append(["(A) corriente máx molino / ω máx", "%.2f u/s / %.2f rad/s" % [float(r["cmax"]), float(r["wmax"])]])
	# Y se camina: de la orilla sur a la norte por la pasarela.
	colocar_jugador(_cv(ORILLA_S))
	await avanzar(5)
	var llego: bool = await mover_hacia(_cv(ORILLA_N), 10.0, 0.6)
	_ok("3 la jugadora cruza a pie por la pasarela hasta la orilla norte", llego, "celda %s" % str(celda_jugador()))


## 5 · un golpe de Agua al molino, sin tierra: la rueda se mueve, pero `hechizo=no` => no cuenta para `girando` y la pasarela NO se tiende.
func _caso_agua() -> void:
	print("== CASO 5 · golpe de AGUA al molino (hechizo=no) ==")
	await _cargar_mapa()
	await avanzar_s(30.0)
	_estado("antes del golpe")
	var gira_antes: bool = mol.activo
	var tendida_antes: bool = bool(pas.get("tendido"))   # (el arranque de la simulación, con la galería llenándose, ya puede haberla tendido: se compara con el estado previo al golpe)
	var r: Dictionary = {"gira": false, "tendida": false, "vmax": 0.0, "senal": false}
	mol.girando.connect(func(si: bool) -> void:
		if si:
			r["senal"] = true)
	mol.on_spell_hit(Puzle3D.runa(["agua", "humedo"]), Vector3(0.0, 0.0, -1.0))
	await avanzar_vigilando(10.0, 0.1, func(_t: float) -> void:
		r["vmax"] = maxf(float(r["vmax"]), absf(mol.velocidad))
		if mol.activo:
			r["gira"] = true
		if bool(pas.get("tendido")) and not tendida_antes:
			r["tendida"] = true)
	_estado("tras el golpe")
	_ok("5 el golpe de Agua mueve la rueda (|ω| máx %.2f ≠ 0)" % float(r["vmax"]), float(r["vmax"]) > 0.1)
	_ok("5 … pero NO emite `girando` (antes %s) ni activa el molino, y la pasarela NO se tiende por el golpe (ya tendida antes: %s)" % [str(gira_antes), str(tendida_antes)], not bool(r["gira"]) and not bool(r["senal"]) and not bool(r["tendida"]))
	_tabla.append(["golpe de Agua: |ω| máx / girando / pasarela", "%.2f / %s / %s" % [float(r["vmax"]), str(bool(r["gira"])), "TENDIDA" if bool(r["tendida"]) else "plegada"]])


func _hasta(cond: Callable, max_s: float) -> float:
	var t: float = 0.0
	while t < max_s:
		if bool(cond.call()):
			return t
		t += await avanzar_s(0.25)
	return -1.0


func _imprimir_tabla() -> void:
	print("\n== TABLA FINAL ==")
	for fila in _tabla:
		print("  %-52s %s" % [fila[0], fila[1]])


func _limpiar() -> void:
	for ruta in [Exportador.ruta_mapa(NOMBRE), Exportador.ruta_escena(NOMBRE)]:
		if FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
