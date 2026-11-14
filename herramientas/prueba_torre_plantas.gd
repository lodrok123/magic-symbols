extends SceneTree
## Prueba de las CINCO PLANTAS de la Torre Verde (14/11/2026), sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_torre_plantas.gd
## 1. La sala arranca en la planta baja y las cinco plantas se montan sin quedarse vacías.
## 2. Las dos casillas de la escalera (SUBE al norte, BAJA al sur) se pisan en todas las plantas: no son muro ni están bloqueadas.
## 3. El umbral de la puerta está libre en la planta baja, es muro en las altas y vuelve a quedar LIBRE al bajar (si no, Mid se queda
##    encerrada en la torre, que es lo que pasaría si la sala no liberase sus casillas al reconstruirse).
## 4. Subir y bajar no acumula nodos: volver a la planta baja deja la sala igual que al empezar.
## 5. Marimanta, el cofre del uniforme, el legendario y el cofre mágico se ven SOLO en la planta baja (las cinco plantas ocupan las mismas
##    casillas del mundo, así que arriba no deben estar ni visibles ni al alcance).
## 6. puede_subir/puede_bajar cierran arriba y abajo, y `llegada` devuelve la casilla del otro extremo de la escalera.

const SalaTorre = preload("res://escenas/interior_torre.gd")
const Visita = preload("res://escenas/monte_sumicio_visita.gd")

var _fallos := 0
var _f := 0
var _paso := 0
var _sala: Node3D
var _hijos_baja := 0


func _initialize() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	change_scene_to_file("res://escenas/PruebaMonteSumicio.tscn")


func _ok(cond: bool, texto: String) -> void:
	print(("OK    " if cond else "FALLO ") + texto)
	if not cond:
		_fallos += 1


func _process(_d: float) -> bool:
	_f += 1
	if _f < 90:
		return false
	_f = 0
	match _paso:
		0:
			_buscar_sala()
		1:
			_recorrer_plantas()
		2:
			_volver_abajo()
		3:
			print("\n%d fallo(s)" % _fallos)
			quit(1 if _fallos > 0 else 0)
			return true
	_paso += 1
	return false


func _buscar_sala() -> void:
	_sala = current_scene.get_node_or_null("Interiores/TorreVerde") as Node3D
	_ok(_sala != null, "la sala de la Torre Verde está en Interiores/TorreVerde")
	if _sala == null:
		_paso = 2
		return
	_ok(int(_sala.planta) == 0, "la torre arranca en la planta baja")
	_ok(SalaTorre.PLANTAS.size() == 5, "hay cinco plantas definidas (%d)" % SalaTorre.PLANTAS.size())
	_hijos_baja = _sala.get_child_count()
	_ok(not _sala.puede_bajar(), "en la planta baja no se puede bajar")
	_ok(_sala.puede_subir(), "en la planta baja se puede subir")
	_ok(_sala.llegada(1) == SalaTorre.BAJA, "subiendo se llega al pie de la escalera que baja")
	_ok(_sala.llegada(-1) == SalaTorre.SUBE, "bajando se llega al pie de la escalera que sube")
	# 7. La escalera se usa SOLO desde su casilla: con un radio mayor, estar delante del cofre del uniforme (la casilla de al lado)
	#    contaría como estar en la escalera y [E] subiría en vez de abrir el cofre.
	_ok(Visita.RADIO_ESCALERA <= Terreno3D.casilla * 0.5,
		"la escalera solo alcanza su casilla (radio %.2f, media casilla %.2f)" % [Visita.RADIO_ESCALERA, Terreno3D.casilla * 0.5])
	_umbral_libre(true, "planta baja")


## Monta las cinco plantas y comprueba cada una.
func _recorrer_plantas() -> void:
	if _sala == null:
		return
	var vistos: Array[int] = []
	for n in range(SalaTorre.PLANTAS.size()):
		_sala.ir_a_planta(n)
		_ok(int(_sala.planta) == n, "planta %d montada" % n)
		var hijos := _sala.get_child_count()
		vistos.append(hijos)
		_ok(hijos > 40, "planta %d tiene sala y mobiliario (%d nodos)" % [n, hijos])
		# Las dos casillas de la escalera se pisan.
		for celda in [SalaTorre.SUBE, SalaTorre.BAJA]:
			_ok(not SalaTorre.es_muro(celda), "planta %d: la casilla %s de la escalera no es muro" % [n, celda])
			_ok(not Terreno3D.bloqueada(_sala.centro + celda), "planta %d: la casilla %s de la escalera no está bloqueada" % [n, celda])
		# El umbral de la puerta: libre abajo, muro arriba.
		_umbral_libre(n == 0, "planta %d" % n)
		# Lo que cuelga la visita de la sala (Marimanta, los cofres) solo se ve en la planta baja.
		var ajenos := 0
		var visibles := 0
		for h in _sala.get_children():
			if h.has_meta("_planta") or h == _sala.get_node_or_null("Camara"):
				continue
			ajenos += 1
			if (h as Node3D) != null and (h as Node3D).visible:
				visibles += 1
		if ajenos > 0:
			_ok(visibles == (ajenos if n == 0 else 0),
				"planta %d: de %d nodos de la visita (Marimanta, cofres) se ven %d" % [n, ajenos, visibles])
	_ok(not _sala.puede_subir(), "en la planta alta no se puede subir más")
	_ok(_sala.puede_bajar(), "en la planta alta se puede bajar")
	# Las plantas no son todas iguales: el mobiliario cambia.
	var distintas := {}
	for v in vistos:
		distintas[v] = true
	_ok(distintas.size() >= 3, "el mobiliario cambia entre plantas (%d recuentos distintos de nodos)" % distintas.size())


## Vuelve a la planta baja y comprueba que no se ha acumulado nada y que se puede salir por la puerta.
func _volver_abajo() -> void:
	if _sala == null:
		return
	for n in [3, 2, 1, 0]:
		_sala.ir_a_planta(n)
	_ok(int(_sala.planta) == 0, "se vuelve a la planta baja")
	_ok(_sala.get_child_count() == _hijos_baja,
		"bajar y subir no acumula nodos (%d al empezar, %d ahora)" % [_hijos_baja, _sala.get_child_count()])
	_umbral_libre(true, "de vuelta en la planta baja")
	# El paso del hueco central a la puerta, libre (es por donde se sale).
	for z in [1, 2, 3]:
		_ok(not Terreno3D.bloqueada(_sala.centro + Vector2i(0, z)),
			"de vuelta abajo: la casilla (0,%d) del paso a la puerta está libre" % z)


func _umbral_libre(libre: bool, donde: String) -> void:
	var c: Vector2i = _sala.centro + SalaTorre.SALIDA_PUERTA
	var bloqueada := Terreno3D.bloqueada(c)
	_ok(bloqueada != libre, "%s: el umbral de la puerta %s" % [donde, "está libre" if libre else "es muro"])
