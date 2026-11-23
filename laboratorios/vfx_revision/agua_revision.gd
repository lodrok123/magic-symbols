extends AguaToy

## Experimental: solo lo instancia LabVfxRevision3D.
var _membrana: MeshInstance3D
var _borde: MultiMeshInstance3D
var _caida: MeshInstance3D
var _golpe_edad: float = 10.0
var _contacto: Vector3 = Vector3.RIGHT
var _ola_reloj: float = 0.0
var _ola_preludio: MeshInstance3D
## Separada de crece: la señal del suelo puede aparecer sin levantar aún la ola.
@export_range(0.0, 1.0) var anticipacion_ola: float = 1.0

func _marcador_provisional(c: Node3D) -> void:
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	esfera.radial_segments = 64
	esfera.rings = 32
	var mat := AguaMallas.material("res://laboratorios/vfx_revision/agua_barrera.gdshader", {"ejes": semiejes()}, 0)
	_membrana = _mi_agua(c, "Membrana", esfera, mat)
	_membrana.custom_aabb = AABB(-semiejes() * 1.2, semiejes() * 2.4)
	_borde = AguaMallas.franjas_mm("EspumaInferior", 20)
	c.add_child(_borde)
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2.ONE
	_caida = _mi_agua(c, "CaidaMembrana", q, AguaMallas.material(AguaMallas.SH_SUELO, {"radial": 1.0}, 0))
	_caida.position.y = 0.025
	_caida.scale = Vector3(semieje_x * 2.3, 1, semieje_z * 2.3)
	_caida.visible = false

func _anim_si_hace_falta() -> void:
	super._anim_si_hace_falta()
	if figura == Figura.MURO:
		var nacer := (get_node("Anim") as AnimationPlayer).get_animation("nacer")
		nacer.clear()
		nacer.length = 1.65
		var pista: int = nacer.add_track(Animation.TYPE_VALUE)
		nacer.track_set_path(pista, NodePath(".:crece"))
		for clave in [Vector2(0, 0), Vector2(0.3, 0), Vector2(0.55, 0.1), Vector2(0.95, 0.45), Vector2(1.4, 0.88), Vector2(1.65, 1)]:
			nacer.track_insert_key(pista, clave.x, clave.y)
		pista = nacer.add_track(Animation.TYPE_VALUE)
		nacer.track_set_path(pista, NodePath(".:anticipacion_ola"))
		nacer.track_insert_key(pista, 0.0, 0.0)
		nacer.track_insert_key(pista, 0.3, 1.0)
		nacer.track_insert_key(pista, 1.65, 1.0)
		var morir_an := (get_node("Anim") as AnimationPlayer).get_animation("morir")
		morir_an.clear()
		morir_an.length = 2.2
		pista = morir_an.add_track(Animation.TYPE_VALUE)
		morir_an.track_set_path(pista, NodePath(".:corte"))
		morir_an.track_insert_key(pista, 0.0, 0.0)
		morir_an.track_insert_key(pista, 2.2, 1.0)
		dura_morir = 2.2
		return
	if figura != Figura.BARRERA:
		return
	var ap := get_node("Anim") as AnimationPlayer
	for nombre in ["nacer", "vivir", "morir"]:
		var an := ap.get_animation(nombre)
		an.clear()
		an.length = 1.2 if nombre == "morir" else 0.7
		var pista: int = an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(pista, NodePath(".:corte" if nombre == "morir" else ".:crece"))
		an.track_insert_key(pista, 0.0, 1.0 if nombre == "vivir" else 0.0)
		an.track_insert_key(pista, an.length, 1.0)
	dura_morir = 1.2

func lanzar(v: float = -1.0) -> void:
	if figura == Figura.MURO:
		anticipacion_ola = 0.0
		crece = 0.0
		corte = 0.0
	super.lanzar(v)

## Recibe un contacto en mundo; nunca inventa el punto a partir del origen del atacante.
func golpe_en(punto: Vector3) -> void:
	if figura != Figura.BARRERA:
		return
	var p: Vector3 = to_local(punto) / semiejes()
	_contacto = p.normalized()
	_golpe_edad = 0.0

func _pilar(c: Node3D) -> void:
	super._pilar(c)
	if semieje_y / maxf(semieje_x, semieje_z) < 2.0:
		_pil_charco.scale *= Vector3(0.65, 1, 0.65)
		_pil_falda.scale = Vector3(0.72, 1, 0.72)
		for mat in _pil_mats:
			mat.set_shader_parameter("opacidad", 0.72)

func _avanzar_pilar(delta: float) -> void:
	super._avanzar_pilar(delta)
	if figura == Figura.PILAR and semieje_y / maxf(semieje_x, semieje_z) < 2.0:
		_pil_fra.visible = corte > 0.05 or crece < 0.85

func _ola(c: Node3D) -> void:
	super._ola(c)
	_ola_reloj = 0.0
	for hoja in _ola_hojas:
		var mat := (hoja as MeshInstance3D).material_override as ShaderMaterial
		mat.shader = preload("res://laboratorios/vfx_revision/agua_ola_revision.gdshader")
	for laminas in [_ola_cuerpo, _ola_cresta]:
		(laminas.material_override as ShaderMaterial).shader = preload("res://laboratorios/vfx_revision/agua_ola_lamina_revision.gdshader")
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	_ola_preludio = _mi_agua(c, "NacimientoOla", q, AguaMallas.material(AguaMallas.SH_ONDA,
		{"anillos": 2.0, "charco": 0.45, "u": 0.0, "vida": 0.0, "suave_prof": 0.0}, 0))
	_ola_preludio.position.y = 0.025
	_ola_preludio.scale = Vector3(semieje_x * 2.1, 1, semieje_z * 2.0 + 1.0)
	var reverso := _ola_charco.duplicate() as MeshInstance3D
	reverso.name = "RastroTrasero"
	reverso.material_override = _ola_charco.material_override
	reverso.position.z = -_ola_charco.position.z
	reverso.rotation.y = PI
	c.add_child(reverso)
	_ola_charco.set_meta("reverso", reverso)

func _avanzar_ola(delta: float) -> void:
	super._avanzar_ola(delta)
	if figura == Figura.MURO and is_instance_valid(_ola_charco):
		_ola_reloj += delta * velocidad
		for hoja in _ola_hojas + [_ola_cuerpo, _ola_cresta]:
			(hoja.material_override as ShaderMaterial).set_shader_parameter("tiempo_ola", _ola_reloj)
			(hoja.material_override as ShaderMaterial).set_shader_parameter("alcance_colapso", _ola_lam_dim.y)
		var aterriza: float = smoothstep(0.5, 0.98, corte)
		var impacto: float = clampf(-ola_cabeza_colapso().z / maxf(_ola_lam_dim.y, 0.1), 0.0, 0.9)
		var frente: float = lerpf(impacto, 1.0, 1.0 - pow(1.0 - aterriza, 2.0))
		var suelo := _ola_charco.material_override as ShaderMaterial
		suelo.set_shader_parameter("frente", frente)
		suelo.set_shader_parameter("alfa", smoothstep(0.5, 0.62, corte) * (1.0 - smoothstep(0.9, 1.0, corte)))
		_ola_charco.visible = corte > 0.5 and corte < 1.0
		if corte > 0.0:
			for i in _ola_franjas_datos.size():
				var dato: Dictionary = _ola_franjas_datos[i]
				var p: Vector3 = dato["pos"]
				var z_pie: float = -_ola_avance - semieje_z * 0.9 - 0.25 * semieje_y - 0.12
				var z_frente: float = 0.1 - _ola_lam_dim.y * frente * (1.0 - 0.28 * pow(p.x / semieje_x, 2.0)) - 0.03
				p.z = lerpf(z_pie, z_frente, smoothstep(0.5, 0.62, corte))
				AguaMallas.franja_poner(_ola_fra.multimesh, i, p, dato["largo"], 0.28,
					dato["alfa"], 0.7, 0.0, float(i))
				dato["pos"] = p
		_ola_preludio.visible = crece < 0.8 and corte <= 0.0
		var preludio := _ola_preludio.material_override as ShaderMaterial
		var senal: float = smoothstep(0.0, 1.0, anticipacion_ola)
		preludio.set_shader_parameter("u", clampf(lerpf(0.03, 0.48, senal) + crece * 0.4, 0.0, 0.95))
		preludio.set_shader_parameter("vida", smoothstep(0.0, 0.2, senal) * (1.0 - smoothstep(0.2, 0.65, crece)))
		_ola_preludio.scale = Vector3(semieje_x * 2.1 * lerpf(0.3, 1.0, senal), 1, semieje_z * 2.0 + 1.0)
		var reverso: MeshInstance3D = _ola_charco.get_meta("reverso", null)
		if is_instance_valid(reverso):
			reverso.visible = false
			reverso.material_override = _ola_charco.material_override

func ola_cabeza_colapso() -> Vector3:
	var h: float = semieje_y * smoothstep(0.0, 1.0, crece)
	var frente: float = smoothstep(0.38, 0.78, 0.42)
	var vuelca: float = smoothstep(0.0, 0.48, corte)
	var arrastra: float = smoothstep(0.23, 0.88, corte)
	var viaje: float = minf(h, maxf(_ola_lam_dim.y - 1.1, 0.2) / 2.0)
	var z: float = -_ola_avance - viaje * (vuelca * (1.15 + 0.75 * frente) + 0.75 * arrastra)
	var cae: float = smoothstep(0.16, 0.68, corte + 0.09 * frente)
	var y: float = maxf(0.0, h * (1.0 - cae * cae) * (1.0 - 0.8 * arrastra) - h * 0.08 * frente * sin(vuelca * PI))
	return Vector3(0, y, z)

func _emitir_ola(delta: float) -> void:
	if corte <= 0.0:
		super._emitir_ola(delta)
		return
	if not is_instance_valid(_gotas):
		return
	_gotas.set("suelo_y", global_position.y - 0.02)
	var cabeza: Vector3 = ola_cabeza_colapso()
	var contacto: float = smoothstep(0.5, 0.6, corte) * (1.0 - smoothstep(0.73, 0.9, corte))
	_ola_acc += delta * (8.0 * (1.0 - smoothstep(0.45, 0.65, corte)) + 38.0 * contacto) * (semieje_x / 3.45) * chispas
	while _ola_acc >= 1.0:
		_ola_acc -= 1.0
		var x: float = randf_range(-0.9, 0.9) * semieje_x
		var pos := Vector3(x, maxf(cabeza.y, 0.08), cabeza.z)
		var vel := Vector3(randf_range(-0.7, 0.7), randf_range(0.8, 2.4), -randf_range(1.0, 2.7))
		_gotas.call("emitir", global_transform * pos, global_basis * vel, randf_range(0.5, 0.85), randf_range(0.05, 0.11), 0, 0.9, 1.0, 1.0)

func _process(delta: float) -> void:
	super._process(delta)
	if figura != Figura.BARRERA or not is_instance_valid(_membrana):
		return
	_golpe_edad += delta
	_cuerpo.scale = Vector3.ONE
	var mat := _membrana.material_override as ShaderMaterial
	mat.set_shader_parameter("crece", crece)
	mat.set_shader_parameter("corte", corte)
	mat.set_shader_parameter("contacto", _contacto)
	mat.set_shader_parameter("edad_golpe", _golpe_edad)
	for i in 20:
		var ang: float = TAU * float(i) / 20.0
		var pos := Vector3(cos(ang) * semieje_x, 0.03, sin(ang) * semieje_z)
		AguaMallas.franja_poner(_borde.multimesh, i, pos, 0.5 * maxf(semieje_x, semieje_z), 0.16, crece * (1.0 - corte), 0.8, -ang - PI * 0.5, float(i))
	_caida.visible = corte > 0.05 and corte < 1.0
	var suelo := _caida.material_override as ShaderMaterial
	suelo.set_shader_parameter("frente", lerpf(0.82, 1.0, corte))
	suelo.set_shader_parameter("cola", 0.65 * (1.0 - corte))
	suelo.set_shader_parameter("alfa", sin(corte * PI))
