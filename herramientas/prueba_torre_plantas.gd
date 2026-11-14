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
	# Los cuatro puntos de interés existen y se sabe en qué planta viven (si no, las comprobaciones de abajo no probarían nada).
	for sitio in SalaTorre.PUNTOS:
		_ok(SalaTorre.PLANTA_DE.has(sitio), "«%s» tiene planta asignada" % sitio)
		_ok(_nodo_de(sitio) != null, "«%s» está puesto en la sala (planta %d)" % [sitio, _sala.planta_de(sitio)])
	_ok(_sala.planta_de("marimanta") == 4 and _sala.planta_de("cofre_uniforme") == 4,
		"la audiencia y el cofre del uniforme están en el despacho (planta 4)")
	_ok(_sala.planta_de("cofre_magico") == 0, "el cofre mágico se queda en el aula (planta baja)")
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
		# Marimanta y los cofres se ven SOLO en su planta (14/11: la audiencia subió al despacho).
		for sitio in SalaTorre.PUNTOS:
			var nodo: Node3D = _nodo_de(sitio)
			if nodo == null:
				continue
			if _sala.planta_de(sitio) != n:
				_ok(not nodo.is_visible_in_tree(), "planta %d: «%s» no se ve (vive en la %d)" % [n, sitio, _sala.planta_de(sitio)])
			# La casilla del punto tiene que estar libre de mobiliario en SU planta (si no, Marimanta sale dentro de la mesa) y también
			# en la PLANTA BAJA: los autoguardados pasan en el despacho y, al cargar, la sala se monta abajo con Mid donde la dejó.
			if _sala.planta_de(sitio) == n or n == 0:
				_libre_de_solidos(SalaTorre.PUNTOS[sitio], "planta %d, «%s»" % [n, sitio])
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


## El nodo que la visita puso en cada punto de interés, buscado por la posición del punto (no hace falta saber de quién es hijo).
func _nodo_de(sitio: String) -> Node3D:
	var p: Vector3 = _sala.punto(sitio)
	var mejor: Node3D = null
	var dist := 1.2
	for n in current_scene.find_children("*", "Node3D", true, false):
		var nodo := n as Node3D
		if nodo == _sala or nodo.get_parent() == null or nodo is MeshInstance3D or nodo is CollisionShape3D:
			continue
		if nodo.has_meta("_planta"):
			continue
		var d := Vector2(nodo.global_position.x - p.x, nodo.global_position.z - p.z).length()
		if d < dist:
			dist = d
			mejor = nodo
	return mejor


## ¿Cabe Mid de pie en el centro de `celda`, o hay mobiliario de la planta encima?
func _libre_de_solidos(celda: Vector2i, que: String) -> void:
	const MEDIO_MID := 0.45
	var s := Terreno3D.casilla
	var p := Vector2(celda.x * s, celda.y * s)
	var choca: Array = []
	for h in _sala.get_children():
		if not (h is StaticBody3D):
			continue
		var cuerpo := h as StaticBody3D
		for c in cuerpo.get_children():
			var cs := c as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D):
				continue
			var caja := cs.shape as BoxShape3D
			var pos := Vector2(cuerpo.position.x + cs.position.x, cuerpo.position.z + cs.position.z)
			if absf(pos.x - p.x) < caja.size.x * 0.5 + MEDIO_MID and absf(pos.y - p.y) < caja.size.z * 0.5 + MEDIO_MID:
				choca.append(String(cuerpo.name))
	_ok(choca.is_empty(), "%s: la casilla %s está libre de mobiliario %s" % [que, celda, str(choca.slice(0, 3))])


func _umbral_libre(libre: bool, donde: String) -> void:
	var c: Vector2i = _sala.centro + SalaTorre.SALIDA_PUERTA
	var bloqueada := Terreno3D.bloqueada(c)
	_ok(bloqueada != libre, "%s: el umbral de la puerta %s" % [donde, "está libre" if libre else "es muro"])
