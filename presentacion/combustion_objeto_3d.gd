class_name CombustionObjeto3D
extends Node3D
## Solo presentación. El dueño conserva sus relojes, colisión, contagio y botín.
## Los puntos se guardan en el espacio del dueño: mover/girar una pieza no deja fuego atrás.
const HUMO = preload("res://presentacion/vfx/toy/humo_toy.gd")
const SH_LLAMA = preload("res://presentacion/llama_superficie.gdshader")
var tela: bool = false
var restos_madera: bool = false
var escala_llamas: float = 1.0
var cantidad_focos: int = 8
var copiar_materiales: bool = false
var solo_fibra: bool = false
var progreso: float = 0.0
var calor: float = 0.0
var humedad: float = 0.0
var ardiendo: bool = false
var origen: Vector3
var radio: float = 1.0
var materiales: Array[ShaderMaterial] = []
var puntos: Array[Vector3] = []
var focos: Array[Node3D] = []
var _inicio: float = 0.0
var _tiempo: float = 0.0
var _humo_reloj: float = 0.0
var _humo: Node3D
var _luz: OmniLight3D
var _caja: AABB

func montar(visual: Node3D, es_tela: bool, es_madera: bool = false) -> void:
	tela = es_tela
	restos_madera = es_madera
	Ocluso3D.preparar()
	var vertices: Array[Vector3] = []
	for n in visual.find_children("*","MeshInstance3D",true,false):
		if n is MeshInstance3D: _recoger(n,vertices)
	if visual is MeshInstance3D: _recoger(visual,vertices)
	if vertices.is_empty(): return
	_caja = AABB(vertices[0],Vector3.ZERO)
	for v in vertices: _caja = _caja.expand(v)
	# Distribución determinista sobre geometría real; elegir luego los más próximos al frente.
	for i in 48: puntos.append(vertices[mini(vertices.size()-1,int(float(i)*vertices.size()/48.0))])
	set_process(false)

func _montar_efectos() -> void:
	# Las piezas sanas no reservan quads, humo ni luces. Se crean al primer fuego.
	if _luz != null: return
	for i in cantidad_focos:
		var foco := Node3D.new()
		add_child(foco)
		for giro in [0.0,PI*0.5]:
			var mi := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE
			mi.mesh = quad
			mi.position.y = 0.5
			mi.rotation.y = giro
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mat := ShaderMaterial.new()
			mat.shader = SH_LLAMA
			mat.set_shader_parameter("semilla",float(i)*2.37)
			mi.material_override = mat
			foco.add_child(mi)
		foco.visible = false
		focos.append(foco)
	_humo = HUMO.new()
	add_child(_humo)
	_humo.montar(14,{"mundo":false,"claro":Color(0.30,0.29,0.28),"sombra":Color(0.14,0.13,0.13),"viejo":Color(0.28,0.27,0.26),"tam_ini":0.09,"tam_fin":0.30,"vida":1.2,"deriva":Vector3(0.10,0.6,0),"opacidad":0.45})
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0,0.33,0.065)
	_luz.omni_range = maxf(1.2,_caja.size.length()*1.8)
	_luz.shadow_enabled = false
	_luz.light_energy = 0.0
	add_child(_luz)
	set_process(true)

func _recoger(mi: MeshInstance3D, vertices: Array[Vector3]) -> void:
	if mi.mesh == null: return
	# La telaraña antigua tenía dos mallas alternativas: ahora se quema solo la sana.
	if tela and mi.name == "ardiendo":
		mi.visible = false
		return
	var tf: Transform3D = global_transform.affine_inverse() * mi.global_transform
	var caras: PackedVector3Array = mi.mesh.get_faces()
	for i in range(0,caras.size(),maxi(1,caras.size()/192)): vertices.append(tf*caras[i])
	var originales: Array[Material] = []
	for s in mi.mesh.get_surface_count(): originales.append(mi.get_active_material(s))
	# material_override tiene prioridad sobre TODAS las superficies. Si se deja,
	# el frente se actualiza pero Godot sigue dibujando el material anterior.
	mi.material_override = null
	for s in mi.mesh.get_surface_count():
		var original: Material = originales[s]
		if original is StandardMaterial3D:
			var copia: StandardMaterial3D = original.duplicate()
			if copia.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
				copia.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				copia.alpha_scissor_threshold = 0.25
			original = Ocluso3D.convertir(copia)
		if not Ocluso3D.es_comun(original):
			mi.set_surface_override_material(s,original)
			continue
		# Reactivo3D ya creó una copia propia. Conservarla permite que su disolución
		# final siga actuando en el mismo material que está dibujando la pieza.
		var mat: ShaderMaterial = original
		# Fuera de Reactivo3D (cuerda/colmena) también pueden llegar materiales
		# comunes compartidos. Cada componente necesita su propia carbonización.
		if copiar_materiales: mat = mat.duplicate()
		mi.set_surface_override_material(s,mat)
		materiales.append(mat)

func prender(desde: Vector3 = Vector3.INF) -> void:
	if puntos.is_empty(): return
	_montar_efectos()
	set_process(true)
	ardiendo = true
	_inicio = progreso
	if progreso <= 0.0:
		origen = to_local(desde) if desde.is_finite() else _caja.get_center() - Vector3(0,_caja.size.y*0.25,0)
		# Un impacto ligeramente fuera de la malla no debe retrasar toda la combustión.
		origen = origen.clamp(_caja.position,_caja.end)
		radio = 0.01
		for p in puntos: radio = maxf(radio,p.distance_to(origen))
	calor = 1.0
	humedad = 0.0
	actualizar(0.0)

func punto_frontal() -> Vector3:
	return to_global(_caja.get_center()+Vector3(0,0,_caja.size.z*0.5))

func carbonizar() -> void:
	progreso = 1.0
	calor = 0.0
	_aplicar()

func estado_carbonizacion() -> Dictionary:
	return {"version":1,"progreso":progreso,"origen":[origen.x,origen.y,origen.z],"radio":radio}

func restaurar_carbonizacion(datos: Dictionary) -> bool:
	var centro: Variant=datos.get("origen",null)
	var version: Variant=datos.get("version",0)
	if not (version is int or version is float) or int(version)!=1: return false
	if not centro is Array or centro.size()!=3: return false
	for valor in centro:
		if not (valor is float or valor is int) or not is_finite(float(valor)): return false
	var p: Variant=datos.get("progreso",null)
	var r: Variant=datos.get("radio",null)
	if not (p is float or p is int) or not (r is float or r is int): return false
	if not is_finite(float(p)) or not is_finite(float(r)) or float(r)<=0.0: return false
	progreso=clampf(float(p),0.0,1.0)
	origen=Vector3(float(centro[0]),float(centro[1]),float(centro[2]))
	radio=float(r)
	_inicio=progreso
	ardiendo=false; calor=0.0; humedad=0.0
	_aplicar()
	return true

func actualizar(fraccion: float) -> void:
	progreso = maxf(progreso,lerpf(_inicio,1.0,clampf(fraccion,0.0,1.0)))
	_aplicar()

func apagar() -> void:
	ardiendo = false
	humedad = 1.0
	calor = 0.0
	_aplicar()
	for f in focos: f.visible = false
	if _humo != null:
		for i in 5: _humo.emitir(origen+Vector3.UP*0.12,Vector3((i-2)*0.06,0.5,0),0.8,1.3)

func consumir() -> void:
	ardiendo = false
	calor = 0.0
	progreso = 1.0
	_aplicar()
	for f in focos: f.visible = false
	if restos_madera: _dejar_tablas()
	if is_instance_valid(_humo):
		# El dueño desaparece al acabar su disolución; el humo tiene su propia cola.
		var cola: Node3D = _humo
		cola.reparent(get_tree().root,true)
		get_tree().create_timer(1.4).timeout.connect(cola.queue_free)
		_humo = null

func _dejar_tablas() -> void:
	var restos := Node3D.new()
	restos.name = "RestosCombustion"
	get_tree().root.add_child(restos)
	restos.global_transform = global_transform
	var ceniza: Node3D = preload("res://presentacion/estados_blender_3d.gd").cargar("ceniza_restos")
	if ceniza != null:
		restos.add_child(ceniza)
		ceniza.position = _caja.get_center()*Vector3(1,0,1)
		ceniza.position.y=0.08
		ceniza.create_tween().tween_property(ceniza,"position:y",0.0,0.45)
		ceniza.scale *= maxf(1.0,_caja.size.x)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.065,0.045,0.032)
	mat.roughness = 1.0
	for i in 6:
		var tabla := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(maxf(0.035,_caja.size.x*(0.10+0.025*(i%3))),0.035,maxf(0.12,_caja.size.y*(0.48+0.08*(i%4))))
		tabla.mesh = caja
		tabla.material_override = mat
		restos.add_child(tabla)
		var angulo: float = float(i)*2.399963
		tabla.position = Vector3(sin(angulo)*0.15,0.2,cos(angulo)*0.15)+_caja.get_center()*Vector3(1,0,1)
		tabla.rotation = Vector3(0.7,angulo,0.25)
		var destino: Vector3 = tabla.position+Vector3(sin(angulo)*0.18,-0.17,cos(angulo)*0.18)
		var tw := tabla.create_tween().set_parallel(true)
		tw.tween_property(tabla,"position",destino,0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(tabla,"rotation",Vector3(0,angulo+float(i)*0.83,0),0.45)
	var fin := restos.create_tween()
	fin.tween_interval(3.0)
	fin.tween_property(restos,"scale",Vector3.ONE*0.001,0.7)
	fin.tween_callback(restos.queue_free)

func _aplicar() -> void:
	for mat in materiales:
		mat.set_shader_parameter("combustion_activa",1.0)
		mat.set_shader_parameter("combustion_origen",origen)
		mat.set_shader_parameter("combustion_espacio",global_transform.affine_inverse())
		mat.set_shader_parameter("combustion_radio",radio)
		mat.set_shader_parameter("combustion_progreso",progreso)
		mat.set_shader_parameter("combustion_calor",calor)
		mat.set_shader_parameter("combustion_tela",1.0 if tela else 0.0)
		mat.set_shader_parameter("combustion_fibra",1.0 if solo_fibra else 0.0)
		mat.set_shader_parameter("combustion_humedad",humedad)

func _process(delta: float) -> void:
	_tiempo += delta
	if _luz == null: return
	_luz.light_energy = (0.28 if tela else 0.65)*calor*(0.88+0.12*sin(_tiempo*15.0))
	_luz.position = origen+Vector3.UP*0.20
	if not ardiendo:
		humedad = maxf(0.0,humedad-delta/8.0)
		_aplicar()
		return
	_aplicar()
	var ordenados: Array[Vector3] = puntos.duplicate()
	var distancia: float = progreso*1.14*radio
	ordenados.sort_custom(func(a: Vector3,b: Vector3) -> bool: return absf(a.distance_to(origen)-distancia)<absf(b.distance_to(origen)-distancia))
	for i in focos.size():
		var p: Vector3 = ordenados[mini(i*2,ordenados.size()-1)]
		var frente: float = p.distance_to(origen)/radio
		var fuerza: float = 1.0-smoothstep(0.06,0.27,absf(frente-progreso*1.14))
		if not tela: fuerza = maxf(fuerza,0.28 if frente < progreso else 0.0)
		var tam: float = (0.18 if tela else 0.42)*escala_llamas*(0.75+0.25*sin(_tiempo*12.0+i))*fuerza
		focos[i].visible = tam>0.02
		focos[i].position = p
		focos[i].scale = Vector3(tam*0.65,tam, tam*0.65)
	_humo_reloj -= delta
	if _humo_reloj <= 0.0:
		_humo_reloj = 0.32 if tela else 0.16
		_humo.emitir(ordenados[0]+Vector3.UP*0.10,Vector3(0.04,0.35,0),1.0,0.65 if tela else 1.0)
