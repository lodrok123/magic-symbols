extends Area3D
## Caldera dañable y barril de apertura. El barril de pólvora usa Barril3D.
signal cambiado
signal apertura_cambiada(valor: bool)
signal danada
const ESTADOS = preload("res://presentacion/estados_blender_3d.gd")
var tipo: String = "caldera"
var celda := Vector2i.ZERO
var flag: String = ""
var abollada := false
var abierto := false
var calor := 0.0
var visual: Node3D
var _bisagra: Node3D
var _tween: Tween
var _hierro: Array[StandardMaterial3D] = []

func preparar(c: Vector2i, clase: String, clave: String) -> void:
	celda=c; tipo=clase; flag=clave
	position=Terreno3D.centro_de(c,Terreno3D.y_pies(c))

func _ready() -> void:
	collision_mask=0; monitoring=false
	collision_layer=Lanzador3D.CAPA_REACTIVO if tipo=="caldera" else 0
	Terreno3D.bloquear_celda(celda)
	abollada=tipo=="caldera" and flag!="" and Flags.i().tiene(flag)
	abierto=tipo=="barril_almacen" and flag!="" and Flags.i().tiene(flag)
	_montar()
	var forma:=CollisionShape3D.new()
	var caja:=BoxShape3D.new()
	var medida: AABB=Pieza3D._caja(visual,Transform3D.IDENTITY)
	caja.size=medida.size; forma.shape=caja; forma.position=medida.get_center()
	add_child(forma)
	if tipo=="caldera": add_to_group("explosionable")
	else:
		add_to_group("barril_abrible")
		# La pista común también avisa a CargarObjeto3D de que E tiene
		# una interacción prioritaria; evita coger un objeto cercano.
		add_to_group(PistaProximidad.GRUPO)
		PistaProximidad.asegurar(get_tree())
	set_process(false)
	set_process_unhandled_input(tipo=="barril_almacen")

func _montar() -> void:
	if is_instance_valid(visual):
		remove_child(visual); visual.queue_free()
	_hierro.clear()
	visual=ESTADOS.cargar("barril_articulado" if tipo=="barril_almacen" else "caldera_abollada") if tipo=="barril_almacen" or abollada else PiezaFuego3D.crear("caldera_cuerpo")
	if visual==null: visual=Node3D.new()
	visual.name="visual"
	add_child(visual)
	if tipo=="barril_almacen":
		_bisagra=visual.find_child("bisagra_tapa",true,false)
		if _bisagra!=null: _bisagra.rotation.x=-deg_to_rad(105) if abierto else 0.0
	else:
		for m: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
			for s in m.mesh.get_surface_count():
				var mat: Material=m.get_active_material(s)
				if mat is StandardMaterial3D:
					var copia:=mat.duplicate() as StandardMaterial3D
					m.set_surface_override_material(s,copia); _hierro.append(copia)
			m.material_override=null
		poner_calor(calor)

func poner_calor(valor: float) -> void:
	calor=clampf(valor,0,1)
	for m in _hierro:
		m.emission_enabled=calor>0.02
		m.emission=Color(1,0.13,0.025)
		m.emission_energy_multiplier=calor*calor*0.55

func abollar() -> void:
	if tipo!="caldera" or abollada: return
	abollada=true
	if flag!="": Flags.i().poner(flag)
	_montar()
	preload("res://presentacion/feedback_objeto_3d.gd").sacudir(visual,0.05)
	Sfx.play(self,"tierra")
	cambiado.emit()
	danada.emit()

func on_spell_hit(runa: RuneData, _dir: Vector3=Vector3.ZERO, hechizo: Hechizo=null) -> void:
	if tipo!="caldera" or runa==null: return
	var materia: Dictionary=Materia.de(hechizo if hechizo!=null else runa)
	var via: String=Materia.via(materia)
	if via=="fuego": poner_calor(1)
	elif via in ["agua","hielo"]: poner_calor(0)
	elif Materia.golpea(materia): abollar()

func spell_reacts(runa: RuneData, _dir: Vector3=Vector3.ZERO, hechizo: Hechizo=null) -> bool:
	if tipo!="caldera" or runa==null: return false
	var materia: Dictionary=Materia.de(hechizo if hechizo!=null else runa)
	return Materia.via(materia) in ["fuego","agua","hielo"] or (not abollada and Materia.golpea(materia))
func recibir_explosion(_punto: Vector3) -> void: abollar()
func nivel_altura() -> int: return 1
func carried_element() -> RuneData: return null

func poner_abierto(valor: bool, animar: bool=true) -> void:
	if tipo!="barril_almacen" or abierto==valor: return
	abierto=valor
	if flag!="": Flags.i().poner(flag,valor)
	if _tween!=null and _tween.is_valid(): _tween.kill()
	if _bisagra!=null:
		var destino: float=-deg_to_rad(105) if abierto else 0.0
		if animar:
			_tween=create_tween()
			_tween.tween_property(_bisagra,"rotation:x",destino,0.55).set_trans(Tween.TRANS_SINE)
		else: _bisagra.rotation.x=destino
	cambiado.emit()
	apertura_cambiada.emit(abierto)

func abrir() -> void: poner_abierto(true)
func cerrar() -> void: poner_abierto(false)

func _jugador() -> Node3D:
	var lanz:=get_tree().get_first_node_in_group("spellcaster")
	return lanz.get("jugador") as Node3D if lanz!=null else null
func accion_pista() -> String:
	if tipo!="barril_almacen": return ""
	var pj:=_jugador()
	if pj==null or pj.global_position.distance_to(global_position)>2.4: return ""
	if pj is Jugador3D and pj.lleva_carga(): return ""
	return "Cerrar" if abierto else "Abrir"
func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("interactuar",false): return
	if accion_pista()=="": return
	var pj:=_jugador()
	if pj==null or pj.global_position.distance_to(global_position)>2.4: return
	for otro in get_tree().get_nodes_in_group("barril_abrible"):
		if otro!=self and pj.global_position.distance_to(otro.global_position)<pj.global_position.distance_to(global_position): return
	poner_abierto(not abierto)
	get_viewport().set_input_as_handled()
