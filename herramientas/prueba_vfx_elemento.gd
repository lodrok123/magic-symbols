extends SceneTree

## PRUEBA (Pipeline, 20/10, entrada 203): VfxElemento3D, el efecto por ELEMENTO de cada hechizo. Con un Lanzador de mentira que emite `hechizo_v2` y un
## HechizoVivo de mentira (como en prueba_vfx_v2) comprueba, MIDIENDO el árbol:
##   1. que cada elemento (fuego, agua, tierra, viento y los tres genéricos) × forma (esfera, pulso = `crece`, barrera = `solidez`) monta un dibujo que
##      CUELGA del HechizoVivo que lo lanzó (nace con él), y que un proyectil (velocidad > 0, sin `hechizo_v2`) lo recibe también colgado de su nodo;
##   2. que la variación sale del Hechizo y de `props` (pulso/barrera/esfera) y no de nombres de forma: cada forma dibuja algo distinto;
##   3. tierra = terrones (BoxMesh) y viento = anillos (TorusMesh), que son lo nuevo;
##   4. presupuesto: ≤ 2 luces y ≤ 400 partículas por hechizo;
##   5. con `encendido = false` no monta nada, y con `VfxEstado3D.encendido = false` este no dibuja volúmenes ni proyectiles;
##   6. que `VfxKit3D.elemento` se restituye (es global: otros efectos cuentan con el suyo);
##   7. que si el HechizoVivo se libera, el dibujo se SUELTA al mundo (no se corta) y a los 6 s no queda nada vivo.
##   godot --headless --path . --script res://herramientas/prueba_vfx_elemento.gd
class FalsoLanzador:
	extends Node
	signal hechizo_v2(estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary)
	signal vfx_hechizo(nombre: String, posicion: Vector3, elemento: String)
	var fx: Vfx3D = null

const ELEMENTOS: Array = [["plasma", "fuego"], ["liquido", "agua"], ["solido", "tierra"], ["gas", "viento"], ["energia", "rayo"], ["solido", "hielo"]]
const FORMAS: Dictionary = {"esfera": {}, "pulso": {"crece": 0.5}, "barrera": {"solidez": 1.0}}
const ESPERA_FINAL: float = 6.0

var _fallos: int = 0


func _initialize() -> void:
	_correr()


func _ok(cond: bool, texto: String) -> void:
	if cond:
		print("  OK   ", texto)
	else:
		print("  MAL  ", texto)
		_fallos += 1


func _correr() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var l := FalsoLanzador.new()
	mundo.add_child(l)
	l.fx = Vfx3D.new()
	mundo.add_child(l.fx)
	var estado: VfxEstado3D = VfxEstado3D.conectar(l, mundo)
	estado.encendido = false
	var vfx: VfxElemento3D = VfxElemento3D.conectar(l, mundo)
	await process_frame
	var antes_kit: String = VfxKit3D.elemento
	var vivos: Array = []
	var x: float = 0.0
	print("--- 1/2/3. un dibujo colgado del HechizoVivo por elemento × forma")
	for par in ELEMENTOS:
		var huellas: Dictionary = {}
		for forma in FORMAS:
			var hv: HechizoVivo = _hechizo(l, par[0], par[1], 0.0, Vector3(x, 0.0, 0.0))
			var n0: int = vfx.volumenes()
			_emitir(l, par[0], par[1], Vector3(x, 0.0, 0.0), FORMAS[forma] as Dictionary)
			await process_frame
			var colgado: Node = hv.get_node_or_null("VfxElemento")
			_ok(vfx.volumenes() == n0 + 1 and colgado != null, "%s/%s: monta un dibujo colgado del HechizoVivo" % [par[1], forma])
			if colgado != null:
				huellas[forma] = _huella(colgado)
				var med: Array = _medir(colgado)
				_ok(int(med[0]) <= 2 and int(med[1]) <= 400, "%s/%s: %d luces, %d partículas (≤ 2 y ≤ 400)" % [par[1], forma, int(med[0]), int(med[1])])
				if par[1] == "tierra":
					_ok(_contar(colgado, "BoxMesh") >= 8, "tierra/%s: terrones (BoxMesh) que caen" % forma)
				if par[1] == "viento":
					_ok(_contar(colgado, "TorusMesh") >= 4, "viento/%s: anillos (TorusMesh)" % forma)
			if colgado != null:
				colgado.queue_free()            # se libera ya: VfxElemento3D tiene un tope de dibujos a la vez (MAX_VIVOS) y la prueba lanza más
			hv.queue_free()
			await process_frame
			x += 30.0
		_ok(huellas.size() == 3 and (par[1] == "tierra" or par[1] == "viento" or (huellas["esfera"] != huellas["pulso"] and huellas["esfera"] != huellas["barrera"] and huellas["pulso"] != huellas["barrera"])),
			"%s: esfera, pulso y barrera dibujan cosas distintas" % par[1])
	print("--- proyectiles (velocidad > 0: no emiten hechizo_v2)")
	for par in ELEMENTOS:
		var p: HechizoVivo = _hechizo(l, par[0], par[1], 8.0, Vector3(x, 0.0, 0.0))
		var np: int = vfx.proyectiles()
		await process_frame
		await process_frame
		_ok(vfx.proyectiles() == np + 1 and p.get_node_or_null("VfxElementoProyectil") != null, "%s: el proyectil lleva su dibujo colgado" % par[1])
		var seg: Node3D = p.get_node_or_null("VfxElementoProyectil") as Node3D
		if seg != null:
			p.global_position = Vector3(x + 5.0, 0.0, 0.0)
			_ok(absf(seg.global_position.x - (x + 5.0)) < 0.01, "%s: el dibujo se mueve con el proyectil" % par[1])
			var med2: Array = _medir(seg)
			_ok(int(med2[0]) <= 2 and int(med2[1]) <= 400, "%s proyectil: %d luces, %d partículas" % [par[1], int(med2[0]), int(med2[1])])
		p.queue_free()
		await process_frame
		x += 30.0
	print("--- 5. banderas")
	var n_antes: int = vfx.volumenes()
	vfx.encendido = false
	var hv5: HechizoVivo = _hechizo(l, "plasma", "fuego", 0.0, Vector3(x, 0.0, 0.0))
	_emitir(l, "plasma", "fuego", Vector3(x, 0.0, 0.0), {})
	await process_frame
	_ok(vfx.volumenes() == n_antes and hv5.get_node_or_null("VfxElemento") == null, "VfxElemento3D.encendido = false: no monta nada")
	vfx.encendido = true
	var a0: int = estado.activos()
	var hv6: HechizoVivo = _hechizo(l, "plasma", "fuego", 0.0, Vector3(x + 30.0, 0.0, 0.0))
	_emitir(l, "plasma", "fuego", Vector3(x + 30.0, 0.0, 0.0), {})
	_hechizo(l, "plasma", "fuego", 8.0, Vector3(x + 60.0, 0.0, 0.0))
	await process_frame
	await process_frame
	_ok(estado.activos() == a0 and estado.proyectiles() == 0, "VfxEstado3D.encendido = false: ni volúmenes ni proyectiles por estado")
	estado.encendido = true
	_emitir(l, "plasma", "fuego", Vector3(x + 90.0, 0.0, 0.0), {})
	await process_frame
	_ok(estado.activos() > a0, "VfxEstado3D.encendido = true: vuelve a dibujar")
	_ok(VfxKit3D.elemento == antes_kit, "VfxKit3D.elemento se restituye (era «%s», es «%s»)" % [antes_kit, VfxKit3D.elemento])
	print("--- 7. el HechizoVivo se libera: el dibujo se suelta y no se corta")
	var hv7: HechizoVivo = _hechizo(l, "plasma", "fuego", 0.0, Vector3(x + 120.0, 0.0, 0.0))
	_emitir(l, "plasma", "fuego", Vector3(x + 120.0, 0.0, 0.0), {})
	await process_frame
	var dib: Node = hv7.get_node_or_null("VfxElemento")
	hv7.queue_free()
	await process_frame
	await process_frame
	_ok(dib != null and is_instance_valid(dib) and dib.get_parent() == mundo, "al liberarse el HechizoVivo el dibujo pasa a colgar del mundo y sigue vivo")
	for h in vivos:
		if is_instance_valid(h):
			h.queue_free()
	await create_timer(ESPERA_FINAL, false).timeout
	_ok(vfx.vivos() == 0, "a los %.0f s no queda ningún dibujo vivo (contador: %d)" % [ESPERA_FINAL, vfx.vivos()])
	var restos: int = 0
	for c in mundo.get_children():
		if c.name.begins_with("VfxElemento") and c != vfx:
			restos += 1
	_ok(restos == 0, "ni nodos «VfxElemento» colgando del mundo (%d)" % restos)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Un HechizoVivo de mentira, como el de prueba_vfx_v2: se añade al lanzador ANTES de emitir (el orden real de HechizoVivo.crear).
func _hechizo(l: FalsoLanzador, estado: String, elemento: String, velocidad: float, pos: Vector3) -> HechizoVivo:
	var hv := HechizoVivo.new()
	hv.set_physics_process(false)
	hv.h = Hechizo.new()
	hv.h.velocidad = velocidad
	hv.estado = estado
	hv.elemento = elemento
	hv.activo = velocidad > 0.0
	hv.proyectil = velocidad > 0.0
	hv.v = Vector3(velocidad, 0.0, 0.0)
	l.add_child(hv)
	hv.global_position = pos
	return hv


func _emitir(l: FalsoLanzador, estado: String, elemento: String, pos: Vector3, props: Dictionary) -> void:
	var g: Dictionary = {"x": 0.25, "y": 0.25, "z": 0.25, "celdas": [Vector2i(0, 0)], "niveles": 1, "persiste": 2.0, "suelo": pos.y, "t_caida": 0.4,
		"eventos": [{"t": 0.0, "pos": Vector2(pos.x, pos.z), "dir": Vector2(1.0, 0.0)}], "viaja": false, "vida_total": 2.0}
	l.hechizo_v2.emit(estado, elemento, g, pos, Vector3.RIGHT, props)


## [luces, partículas] de un subárbol (las instancias de MultiMesh cuentan como partículas).
func _medir(raiz: Node) -> Array:
	var luces: int = 0
	var part: int = 0
	var pila: Array = [raiz]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		if n is Light3D and (n as Light3D).visible:
			luces += 1
		if n is GPUParticles3D:
			part += (n as GPUParticles3D).amount
		if n is MultiMeshInstance3D:
			part += (n as MultiMeshInstance3D).multimesh.instance_count
		pila.append_array(n.get_children())
	return [luces, part]


func _contar(raiz: Node, clase_malla: String) -> int:
	var c: int = 0
	var pila: Array = [raiz]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).mesh.get_class() == clase_malla:
			c += 1
		pila.append_array(n.get_children())
	return c


## Una firma de lo dibujado (nº de nodos por clase) para saber si dos formas dibujan lo mismo.
func _huella(raiz: Node) -> String:
	var cuenta: Dictionary = {}
	var pila: Array = [raiz]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		cuenta[n.get_class()] = int(cuenta.get(n.get_class(), 0)) + 1
		pila.append_array(n.get_children())
	var claves: Array = cuenta.keys()
	claves.sort()
	var t: String = ""
	for k in claves:
		t += "%s=%d;" % [k, cuenta[k]]
	return t
