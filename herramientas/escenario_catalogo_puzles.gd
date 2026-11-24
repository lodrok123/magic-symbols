extends "res://herramientas/escenario_base.gd"
## LAS PLANTILLAS NUEVAS DEL CATÁLOGO, RESUELTAS EN EL JUEGO (24/11/2026). Para cada una: genera un mapa de salas con la plantilla puesta a
## mano, lo exporta, lo carga y la resuelve como lo haría la jugadora, con fuego o agua de verdad (`Mundo3D.aplicar_accion`) donde se
## puede, o con la acción de la pieza (`romper`, `pulsar`) donde el golpe sería de un hechizo. Mira lo que tiene que pasar después.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_catalogo_puzles.gd

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const NOMBRE: String = "ZzCatPuzles"

var _pz: Puzle3D = null


func _escenario() -> void:
	for cid in ["rele_braseros", "contrafuego", "escondite_muro", "puente_cuerda", "puente_cuerda_fuego", "riega_pulsador", "piedra_premio"]:
		var plantilla: String = "puente_cuerda" if cid == "puente_cuerda_fuego" else cid
		if not await _cargar_con(plantilla):
			continue
		match cid:
			"rele_braseros":
				await _rele()
			"contrafuego":
				await _contrafuego()
			"escondite_muro":
				_hacer("muro", "romper")
				await avanzar_s(0.5)
				_ok("escondite: el muro roto deja el cofre a la vista", _si("muro", "roto") and _si("cofre", "cerrado"))
			"puente_cuerda":
				await _elemento("agua", "placa")
				var tendido: bool = await _espera("puente", "tendido", 4.0)
				_ok("puente: el agua en la placa tiende el puente", tendido, "placa activa: %s" % _si("placa", "activo"))
			"puente_cuerda_fuego":
				await _elemento("fuego", "cuerda")
				var tendido2: bool = await _espera("puente", "tendido", 6.0)
				_ok("puente: el fuego en la cuerda tiende el puente", tendido2)
				_ok("puente: y es la cuerda (quemada) la que lo ha soltado, no la placa", await _espera("cuerda", "rota", 3.0) and not _si("placa", "activo"))
			"riega_pulsador":
				await _elemento("agua", "placa")
				_ok("riega: el agua baja la placa", await _espera("placa", "activo", 4.0))
			"piedra_premio":
				_hacer("placa", "pulsar")
				_ok("piedra: con la placa bajada aparece el cofre", await _espera("cofre", "cerrado", 3.0))
	_borrar()


## Genera, exporta y carga un mapa de salas con la plantilla `cid` a mano. Deja en `_pre` el prefijo de su instancia.
var _pre: String = ""

func _cargar_con(cid: String) -> bool:
	Flags.nuevo()
	Estado.nuevo()
	var par: Dictionary = {"algoritmo": "salas", "semilla": 3, "nombre": NOMBRE, "enemigos": 0.0, "puzles": 0, "barreras": 0, "salas_cerradas": 0}
	var a_mano: Dictionary = {}
	for sala in Generador.new().generar(par)["salas"]:
		if String(sala["rol"]) != "inicio":
			var prueba: Dictionary = Generador.new().generar(par, {}, {}, {int(sala["id"]): cid})
			if (prueba["puzles"] as Dictionary).get(int(sala["id"]), "") == cid:
				a_mano = {int(sala["id"]): cid}
				break
	_ok("0 «%s» cabe en una sala" % cid, not a_mano.is_empty())
	if a_mano.is_empty():
		return false
	var m: Dictionary = Generador.new().generar(par, {}, {}, a_mano)
	_pre = "cat1_"
	_ok("0 «%s» se exporta" % cid, bool(Exportador.exportar(m)["ok"]))
	await cargar(Exportador.ruta_escena(NOMBRE), true)
	if maqueta == null:
		return false
	_pz = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("0 «%s»: Puzle3D sin avisos" % cid, _pz != null and _pz.avisos.is_empty(), str(_pz.avisos) if _pz != null else "")
	await avanzar_s(0.5)
	return _pz != null


func _hacer(local: String, accion: String) -> void:
	_pz.call("_ejecutar", {"id": _pre + local, "accion": accion, "args": []})


func _si(local: String, cond: String) -> bool:
	return bool(_pz.call("_cumple", _pre + local, cond))


func _espera(local: String, cond: String, segundos: float) -> bool:
	var t: float = 0.0
	while t < segundos:
		if _si(local, cond):
			return true
		await avanzar_s(0.1)
		t += 0.1
	return _si(local, cond)


## Lanza una FLECHA de `elemento` de verdad a la pieza `local` (como la jugadora): se pone a 2-3 casillas en línea, con el camino libre.
func _elemento(elemento: String, local: String) -> void:
	var pz = _pz.pieza(_pre + local)
	if pz == null:
		_ok("existe la pieza %s" % local, false)
		return
	await _disparar_a(elemento, pz.celda)


func _disparar_a(elemento: String, c: Vector2i) -> void:
	# La casilla libre más cercana a 2-4 casillas con la línea despejada (muestreada) y sin otra pieza del puzle encima.
	var desde: Vector2i = Vector2i(-1, -1)
	var mejor: float = INF
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var s: Vector2i = c + Vector2i(dx, dy)
			var dist: float = Vector2(dx, dy).length()
			if dist < 2.0 or dist > 4.0 or dist >= mejor or _pz.pieza_en(s) != null:
				continue
			var libre: bool = Terreno3D.pisable(s, 0, true, 1, false) and not Terreno3D.celda_solida(s, 0)
			for i in range(1, 12):
				var q: Vector2i = Vector2i((Vector2(c) + Vector2(s - c) * (float(i) / 12.0)).round())
				if q != c and q != s and Terreno3D.celda_solida(q, 0):
					libre = false
			if libre:
				desde = s
				mejor = dist
	_ok("hay sitio para disparar a %s" % str(c), desde.x >= 0)
	if desde.x < 0:
		return
	colocar_jugador(desde)
	await avanzar_s(0.6)
	var dir: Vector3 = Terreno3D.centro_de(c, 0.0) - (jugador as Node3D).position
	dir.y = 0.0
	_ok("sale la flecha de %s hacia %s desde %s" % [elemento, str(c), str(desde)], lanzar(elemento, ["flecha", "flecha"], dir))     # dos ᛇ: 3 casillas de alcance
	await avanzar_s(1.5)


func _rele() -> void:
	_hacer("a", "encender")
	var visto: bool = false
	var t: float = 0.0
	var b_encendido: bool = false
	while t < 9.0:
		await avanzar_s(0.1)
		t += 0.1
		b_encendido = b_encendido or _si("b", "encendido")
		if _si("luces", "todos"):
			visto = true
			break
	_ok("relé: el primero enciende el siguiente", b_encendido)
	_ok("relé: el primero y el último llegan a arder a la vez (señal del contador)", visto, "a los %.1f s" % t)


func _contrafuego() -> void:
	# Fuego al primer seto: la llama corre por la fila y prende el barril.
	var barril = _pz.pieza(_pre + "barril")
	var seto0: Vector2i = barril.celda + Vector2i(-4, 0)
	await _disparar_a("fuego", seto0)
	var abre: bool = await _espera("puerta", "abierta", 25.0)
	_ok("contrafuego: el fuego del primer seto llega al barril y la explosión abre la puerta", abre)
	await avanzar_s(0.5)
	_ok("contrafuego: aparece el cofre de la trastienda", _si("cofre", "cerrado"))


func _borrar() -> void:
	for r in [Exportador.ruta_mapa(NOMBRE), Exportador.ruta_escena(NOMBRE)]:
		if FileAccess.file_exists(r):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(r))
