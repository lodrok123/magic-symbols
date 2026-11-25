extends Node3D
## Presentación de reacciones; no decide ingredientes, recolección ni colisiones.
const HUMO = preload("res://presentacion/vfx/toy/humo_toy.gd")
var tipo: String = ""
var luminosa: bool = false
var materiales: Array[ShaderMaterial] = []
var puntos: Array[Vector3] = []
var particulas: Array[MeshInstance3D] = []
var _origenes: Array[Vector3] = []
var _caja: AABB
var _t: float = 0.0
var _direccion := Vector3(0.6,0.2,0.1)
var _nube: Node3D

func montar(visual: Node3D) -> void:
	Ocluso3D.preparar()
	_caja = Pieza3D._caja(visual,Transform3D.IDENTITY)
	for mi in visual.find_children("*","MeshInstance3D",true,false):
		if mi.mesh == null: continue
		var activos: Array[Material] = []
		for s in mi.mesh.get_surface_count(): activos.append(mi.get_active_material(s))
		mi.material_override = null
		var tf: Transform3D = global_transform.affine_inverse()*mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat: Material = activos[s]
			if mat != null: mat = mat.duplicate()
			mat = Ocluso3D.convertir(mat)
			mi.set_surface_override_material(s,mat)
			if mat is ShaderMaterial and Ocluso3D.es_comun(mat):
				Ocluso3D.poner_caja(mat,mi.mesh)
				materiales.append(mat)
			var a: Array = mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			for i in range(0,vs.size(),maxi(1,vs.size()/128)):
				var p: Vector3 = tf*vs[i]
				if p.y > _caja.position.y+_caja.size.y*0.5 and (tf.basis.inverse().transposed()*ns[i]).normalized().y > 0.45:
					puntos.append(p)
	if puntos.is_empty(): puntos.append(_caja.get_center()+Vector3.UP*_caja.size.y*0.3)
	for nombre in ["seta_contraccion","seta_hielo","seta_agua","seta_resonante"]: _poner(nombre,0.0)
	set_process(false)

func _poner(nombre: String, valor: float) -> void:
	for m in materiales: m.set_shader_parameter(nombre,valor)

func marcar_resonante() -> void:
	_poner("seta_resonante",1.0)

func aplicar(via: String, es_luminosa: bool, direccion: Vector3 = Vector3.ZERO) -> void:
	tipo = via
	luminosa = es_luminosa
	_t = 0.0
	if direccion.length_squared() > 0.001:
		_direccion = global_basis.inverse()*direccion.normalized()*0.55+Vector3.UP*0.12
	if luminosa: marcar_resonante()
	if via == "viento":
		var tw := create_tween()
		tw.tween_method(func(v: float):_poner("seta_contraccion",v),0.0,1.0,0.12)
		tw.tween_method(func(v: float):_poner("seta_contraccion",v),1.0,0.0,0.38).set_trans(Tween.TRANS_SINE)
		_nube = HUMO.new()
		add_child(_nube)
		_nube.montar(10,{"mundo":false,"claro":Color(0.35,0.85,0.95) if luminosa else Color(0.78,0.82,0.36),"sombra":Color(0.26,0.43,0.23),"viejo":Color(0.30,0.38,0.24),"tam_ini":0.045,"tam_fin":0.16,"vida":1.5,"opacidad":0.6,"deriva":Vector3(0.15,0.08,0)})
		for i in 10: _nube.emitir(puntos[i*puntos.size()/10],_direccion*(0.3+float(i%3)*0.15),1.0,1.0)
	elif via == "hielo":
		var tw := create_tween()
		tw.tween_method(func(v: float):_poner("seta_hielo",v),0.0,1.0,0.28)
	elif via == "agua":
		_poner("seta_agua",1.0)
	for i in (12 if via == "viento" else 9):
		var mi := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		if via == "hielo":
			var cristal := CylinderMesh.new()
			cristal.top_radius = 0.0
			cristal.bottom_radius = 0.009 if not luminosa else 0.012
			cristal.height = 0.035 if not luminosa else 0.055
			cristal.radial_segments = 5
			mi.mesh = cristal
			mat.albedo_color = Color(0.55,0.82,0.96)
			mat.roughness = 0.25
		else:
			var esfera := SphereMesh.new()
			esfera.radius = 0.009 if via == "viento" else 0.008
			esfera.height = esfera.radius*2.0
			esfera.radial_segments = 8
			esfera.rings = 4
			mi.mesh = esfera
			mat.albedo_color = (Color(0.35,0.9,1.0) if luminosa else Color(0.75,0.85,0.38)) if via == "viento" else Color(0.35,0.66,0.88)
			mat.roughness = 0.12 if via == "agua" else 0.6
		if luminosa:
			mat.emission_enabled = true
			mat.emission = Color(0.2,0.65,0.85)
			mat.emission_energy_multiplier = 0.5
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.position = puntos[i*puntos.size()/(12 if via == "viento" else 9)]+Vector3.UP*0.008
		_origenes.append(mi.position)
		particulas.append(mi)
	set_process(via != "hielo")

func _process(delta: float) -> void:
	_t += delta
	for i in particulas.size():
		if tipo == "viento":
			particulas[i].position = _origenes[i]+_direccion*_t*(0.35+float(i%4)*0.12)+Vector3(0,sin(_t*3+i)*0.02,0)
		else:
			var t: float = maxf(0.0,_t-float(i)*0.07)
			particulas[i].position.y = maxf(_caja.position.y+0.004,_origenes[i].y-t*t*0.35)
		particulas[i].scale = Vector3.ONE*maxf(0.001,1.0-smoothstep(1.0,1.8,_t))
	if _t >= 1.8:
		for p in particulas: p.queue_free()
		particulas.clear()
		if _nube != null: _nube.queue_free()
		set_process(false)
