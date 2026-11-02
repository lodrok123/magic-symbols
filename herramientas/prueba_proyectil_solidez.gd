extends SceneTree
## PROYECTIL Y SOLIDEZ (A2 · «Sello se ejecuta», 2/11), sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_proyectil_solidez.gd
## Un muro con `solidez` (barrera) levantado en el camino de una flecha PARA a la flecha, igual que a `Lanzador3D.trazar`: la flecha no pasa de la casilla del muro, acaba con motivo «muro» y sin él
## (control: misma flecha, misma salida, sin muro) llega a su alcance. Se mide por los seis elementos, con la flecha de ×1 a ×3 (más impulso, más alcance) y con la consulta del Lanzador (`_barrera_en`).
## Además: el muro de OTRO elemento también para (la solidez no depende de quién la lanza), una barrera con rebote refleja, y la flecha NO choca con el muro de su propio lanzamiento (barrera + flecha).

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var marcas: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(elemento: String, punto: Vector3) -> void:
		marcas.append([elemento, Terreno3D.celda_de(punto)])

const ELEMENTOS: Array = ["fire", "water", "earth", "ice", "lightning", "wind"]
const LADO: int = 20
const ORIGEN_C: Vector2i = Vector2i(6, 10)
const DT: float = 1.0 / 60.0
const MAX_PASOS: int = 3000

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: Jugador3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _montar() -> void:
	for n in [_l, _m, _jug]:
		if n != null and is_instance_valid(n):
			n.free()
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	var filas: PackedStringArray = []
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			f += "#" if (x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1) else "."
		filas.append(f)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(LADO):
		for x in range(LADO):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_jug = Jugador3D.new()
	root.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(Vector2i(2, 2), 1.0)
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	Lanzador3D.montar_agua_sim()


func _contadores(combo: Array) -> Dictionary:
	var c: Dictionary = {}
	for n in combo:
		c[n] = int(c.get(n, 0)) + 1
	return c


func _vivos() -> Array:
	var r: Array = []
	for n in _l.get_children():
		if n is HechizoVivo:
			r.append(n)
	return r


## Levanta un muro (barrera) del elemento `el_muro` en la casilla `c` y devuelve cuántas solideces hay.
func _muro(runes: Dictionary, el_muro: String, c: Vector2i, extra: Array = []) -> int:
	var combo: Array = ["barrera"]
	combo.append_array(extra)
	var hm: Hechizo = Hechizo.construir(runes[el_muro], _contadores(combo), 1.0)
	HechizoVivo.crear(hm, Lanzador3D.centro_de(c, 0.0), Vector3.RIGHT, _l, null, {}, true)
	return _l._solideces_v2.size()


## Lanza una flecha a mano hacia +X y la avanza hasta que acaba. Devuelve {v, x_max, rec (casillas), motivo}.
func _flecha(runes: Dictionary, el: String, n_flechas: int, cambios: Dictionary = {}) -> Dictionary:
	var h: Hechizo = Hechizo.construir(runes[el], {"flecha": n_flechas}, 1.0).con(cambios)
	var fv: HechizoVivo = HechizoVivo.crear(h, Lanzador3D.centro_de(ORIGEN_C, 0.0), Vector3.RIGHT, _l, null, {}, true)
	var x0: float = fv.p.x
	var x_max: float = x0
	var pasos: int = 0
	while fv.activo and pasos < MAX_PASOS:
		fv.paso(DT)
		x_max = maxf(x_max, fv.p.x)
		pasos += 1
	return {"v": fv, "x_max": x_max, "rec": (x_max - x0) / Terreno3D.casilla, "motivo": fv.motivo_fin, "h": h}


func _limpiar() -> void:
	for v in _vivos():
		if is_instance_valid(v):
			(v as Node).queue_free()
	await process_frame


func _initialize() -> void:
	await process_frame
	var runes: Dictionary = {}
	for e in ELEMENTOS:
		runes[e] = load("res://nucleo/%s_rune.tres" % e)
	var cas: float = Terreno3D.casilla
	var muro_c: Vector2i = ORIGEN_C + Vector2i(2, 0)
	var borde_muro: float = float(muro_c.x) * cas                    # borde izquierdo de la casilla del muro (u)

	# 1. Sin muro la flecha llega a su alcance (control) y con muro se para en él: seis elementos × flecha ×1..×3
	for el in ELEMENTOS:
		for n in [1, 2, 3]:
			_montar()
			var libre: Dictionary = _flecha(runes, el, n)
			var alcance: float = (libre["h"] as Hechizo).distancia_max
			var llega: bool = float(libre["rec"]) >= 0.8 * alcance or libre["motivo"] == "alcance"
			await _limpiar()
			_montar()
			var cuantas: int = _muro(runes, "fire", muro_c)
			var r: Dictionary = _flecha(runes, el, n)
			_ok("%s flecha×%d: sin muro llega (%.2f de %.0f casillas, «%s»); con un muro de fuego en la casilla %d se PARA (motivo «%s», x máx %.2f u, borde del muro %.2f u)" % [el, n, float(libre["rec"]), alcance, libre["motivo"], muro_c.x, r["motivo"], float(r["x_max"]), borde_muro],
				cuantas == 1 and llega and r["motivo"] == "muro" and float(r["x_max"]) < borde_muro + cas * 0.5 and float(r["rec"]) < alcance)
			await _limpiar()

	# 2. La solidez no depende de quién la lanza: muros de los seis elementos paran la misma flecha
	for el_muro in ELEMENTOS:
		_montar()
		var cuantas: int = _muro(runes, el_muro, muro_c)
		var r: Dictionary = _flecha(runes, "fire", 1, {"gravedad": 0.0})
		_ok("muro de %s: %d solidez(es) y la flecha de fuego se para en él (motivo «%s», x máx %.2f u de %.2f)" % [el_muro, cuantas, r["motivo"], float(r["x_max"]), borde_muro + cas], cuantas >= 1 and r["motivo"] == "muro" and float(r["x_max"]) < borde_muro + cas * 0.5)
		await _limpiar()

	# 3. La consulta que usa `trazar` (`_barrera_en`) y el proyectil son la MISMA: donde el Lanzador dice «hay barrera», la flecha se para
	_montar()
	_muro(runes, "earth", muro_c)
	var dentro: Vector3 = Lanzador3D.centro_de(muro_c, 0.3)
	var fuera: Vector3 = Lanzador3D.centro_de(ORIGEN_C + Vector2i(1, 0), 0.3)
	_ok("la consulta del Lanzador ve la barrera en la casilla del muro (%s) y no en la anterior" % str(muro_c), _l._barrera_en(dentro, 0) and not _l._barrera_en(fuera, 0))
	await _limpiar()

	# 4. Barrera con rebote: el muro refleja una vez (vx < 0) y la flecha no se queda atravesándolo
	_montar()
	_muro(runes, "fire", muro_c, ["rebote"])
	var rr: Dictionary = _flecha(runes, "fire", 1, {"gravedad": 0.0})
	var vr: HechizoVivo = rr["v"]
	_ok("muro con rebote: la flecha vuelve (x máx %.2f u, no pasa del borde %.2f; vx %.2f, motivo «%s»)" % [float(rr["x_max"]), borde_muro + cas, vr.v.x, rr["motivo"]], float(rr["x_max"]) < borde_muro + cas * 0.5 and (vr.v.x < 0.0 or rr["motivo"] != "alcance"))
	await _limpiar()

	# 5. Una flecha con permanencia (que no es solidez) NO la para: un muro de solidez 0 no existe → no hay nada que consultar
	_montar()
	var rp: Dictionary = _flecha(runes, "fire", 1, {"gravedad": 0.0})
	_ok("control sin ninguna solidez en el mundo: la flecha no acaba en «muro» (motivo «%s»)" % rp["motivo"], _l._solideces_v2.is_empty() and rp["motivo"] != "muro")
	await _limpiar()

	# 6. La flecha no choca con el muro de su PROPIO lanzamiento (barrera + flecha + ᚠ): sus dos copias llegan al alcance
	_montar()
	var bf: Hechizo = Hechizo.construir(runes["fire"], {"barrera": 1, "flecha": 1, "repeticion": 1}, 1.0).con({"gravedad": 0.0, "dispersion": 0.0, "separacion": 0.0})
	HechizoVivo.crear(bf, Lanzador3D.centro_de(muro_c, 0.0), Vector3.RIGHT, _l, null, {}, true)
	var hs: Array = _vivos()
	var pasos: int = 0
	while pasos < MAX_PASOS:
		var alguno: bool = false
		for hv in hs:
			if is_instance_valid(hv) and (hv as HechizoVivo).activo:
				(hv as HechizoVivo).paso(DT)
				alguno = true
		if not alguno:
			break
		pasos += 1
	var motivos: Array = hs.map(func(x: Variant) -> String: return (x as HechizoVivo).motivo_fin)
	_ok("barrera + flecha + ᚠ: %d copias, todas acaban por «alcance» y no por «muro» (%s)" % [hs.size(), str(motivos)], hs.size() == 2 and motivos.all(func(m: Variant) -> bool: return m == "alcance"))
	await _limpiar()

	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
