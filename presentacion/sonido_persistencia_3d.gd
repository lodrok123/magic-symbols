class_name SonidoPersistencia3D
extends Node3D
## Una voz de carga sostenida por elemento/linaje, mientras quede una manifestación.
static var _grupos: Dictionary = {}
var _clave: String = ""
var _elemento: String = ""
var _duenos: Array = []
var _audio: AudioStreamPlayer3D = null
var _final_emitido: bool = false

static func registrar(dueno: Node3D, elemento: String, linaje: Object = null, posicion: Callable = Callable()) -> SonidoPersistencia3D:
	if dueno == null or not dueno.is_inside_tree() or dueno.is_queued_for_deletion() or not Sfx.CATALOGO.has(elemento + "_carga_bucle"):
		return null
	var id: int = linaje.get_instance_id() if is_instance_valid(linaje) else dueno.get_instance_id()
	var clave: String = "%d:%s" % [id, elemento]
	var ref: WeakRef = _grupos.get(clave) as WeakRef
	var sonido: SonidoPersistencia3D = ref.get_ref() as SonidoPersistencia3D if ref != null else null
	if sonido == null or sonido.is_queued_for_deletion():
		sonido = SonidoPersistencia3D.new()
		sonido._clave = clave
		sonido._elemento = elemento
		dueno.get_tree().root.add_child(sonido)
		_grupos[clave] = weakref(sonido)
	for reg in sonido._duenos:
		if (reg["dueno"] as WeakRef).get_ref() == dueno:
			return sonido
	sonido._duenos.append({"dueno": weakref(dueno), "posicion": posicion})
	dueno.tree_exiting.connect(sonido._dueno_sale.bind(weakref(dueno)), CONNECT_ONE_SHOT)
	sonido._actualizar()
	return sonido

func _dueno_sale(ref: WeakRef) -> void:
	for i in range(_duenos.size() - 1, -1, -1):
		if (_duenos[i]["dueno"] as WeakRef).get_ref() == ref.get_ref():
			_duenos.remove_at(i)
	_actualizar()

static func retirar(dueno: Node3D, con_final: bool = false) -> void:
	for ref in _grupos.values():
		var sonido: SonidoPersistencia3D = (ref as WeakRef).get_ref() as SonidoPersistencia3D
		if sonido == null or sonido.is_queued_for_deletion():
			continue
		var retirado: bool = false
		for i in range(sonido._duenos.size() - 1, -1, -1):
			if (sonido._duenos[i]["dueno"] as WeakRef).get_ref() == dueno:
				sonido._duenos.remove_at(i)
				retirado = true
		if retirado:
			sonido._actualizar(con_final)

static func registrar_despues(dueno: Node3D, elemento: String, linaje: Object, demora: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(demora, 0.001)
	dueno.add_child(timer)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(dueno) and not dueno.is_queued_for_deletion():
			registrar(dueno, elemento, linaje)
		timer.queue_free())
	timer.start()

static func temporal(padre: Node3D, elemento: String, posicion: Vector3, vida: float, linaje: Object) -> void:
	if vida <= 0.0:
		return
	var dueno := Node3D.new()
	padre.add_child(dueno)
	dueno.global_position = posicion
	registrar(dueno, elemento, linaje)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = vida
	dueno.add_child(timer)
	timer.timeout.connect(func() -> void:
		retirar(dueno, true)
		dueno.queue_free())
	timer.start()

func _actualizar(con_final: bool = false) -> void:
	var centro := Vector3.ZERO
	for i in range(_duenos.size() - 1, -1, -1):
		var reg: Dictionary = _duenos[i]
		var dueno: Node3D = (reg["dueno"] as WeakRef).get_ref() as Node3D
		if dueno == null or not dueno.is_inside_tree() or dueno.is_queued_for_deletion():
			_duenos.remove_at(i)
			continue
		if ("reventada" in dueno and dueno.get("reventada") == true) or ("celdas" in dueno and (dueno.get("celdas") as Dictionary).is_empty()):
			_duenos.remove_at(i)
			con_final = true
			continue
		var obtener: Callable = reg["posicion"]
		var p: Vector3 = dueno.global_position
		if obtener.is_valid():
			p = obtener.call()
		elif "celdas" in dueno:
			var celdas: Dictionary = dueno.get("celdas")
			if not celdas.is_empty():
				p = Vector3.ZERO
				for c in celdas:
					p += Terreno3D.centro_de(c as Vector2i)
				p /= float(celdas.size())
		centro += p
	if _duenos.is_empty():
		if is_instance_valid(_audio):
			_audio.stop()
		if con_final and not _final_emitido and is_inside_tree():
			_final_emitido = true
			Sfx3D.play(self, _elemento + "_fin")
		queue_free()
		return
	global_position = centro / float(_duenos.size())
	if not is_instance_valid(_audio):
		_audio = Sfx.bucle(self, _elemento + "_carga_bucle", 1.0) as AudioStreamPlayer3D
		if _audio != null:
			_audio.reparent(self, false)
			_audio.position = Vector3.ZERO
			_audio.unit_size = 2.0
			_audio.max_distance = 16.0
			_audio.bus = Sfx3D.bus_para(_audio)

func _process(_delta: float) -> void:
	_actualizar()

func _exit_tree() -> void:
	if is_instance_valid(_audio):
		_audio.stop()
	var ref: WeakRef = _grupos.get(_clave) as WeakRef
	if ref != null and ref.get_ref() == self:
		_grupos.erase(_clave)
