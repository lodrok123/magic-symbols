extends MagmaToy

var _bloques: Array[MeshInstance3D] = []
var _juntas: Array[FuegoToy] = []

func _volumen(c: Node3D) -> void:
	_bloques.clear()
	_juntas.clear()
	if figura == Figura.HAZ:
		super._volumen(c)
		return
	_mat_base = ImpactoMagmaToy.material_roca(false)
	var sitios: Array[Vector3] = []
	var tamanos: Array[Vector3] = []
	if figura == Figura.MURO:
		var n: int = clampi(ceili(semieje_x * 2.0 / 0.65), 3, 24)
		for i in n:
			sitios.append(Vector3(lerpf(-semieje_x, semieje_x, (float(i) + 0.5) / n), 0, 0))
			tamanos.append(Vector3(2.0 * semieje_x / n, semieje_y * (0.9 + 0.1 * sin(i * 2.3)), 2.0 * semieje_z))
	elif figura == Figura.PILAR:
		for i in 5:
			var alto_bloque: float = semieje_y * 0.28
			sitios.append(Vector3(0, (semieje_y - alto_bloque) * float(i) / 4.0, 0))
			tamanos.append(Vector3(semieje_x * 2.0, alto_bloque, semieje_z * 2.0))
	else:
		var n: int = clampi(ceili(TAU * maxf(semieje_x, semieje_z) / 0.55), 10, 40)
		for i in n:
			var ang: float = TAU * float(i) / n
			sitios.append(Vector3(cos(ang) * semieje_x * 0.91, 0, sin(ang) * semieje_z * 0.91))
			# Perímetro bajo: permite ver y jugar dentro.
			tamanos.append(Vector3(0.38, minf(semieje_y, 0.9) * (0.8 + 0.2 * sin(i * 1.7)), 0.38))
	for i in sitios.size():
		var mi := MeshInstance3D.new()
		mi.name = "Basalto%d" % i
		mi.mesh = ImpactoMagmaToy.malla_piedra(i % 5)
		mi.material_override = _mat_base
		var caja: AABB = mi.mesh.get_aabb()
		mi.scale = tamanos[i] / caja.size
		mi.position = sitios[i] - Vector3(caja.get_center().x, caja.position.y, caja.get_center().z) * mi.scale
		mi.set_meta("pos_final", mi.position)
		mi.set_meta("tam_final", mi.scale)
		c.add_child(mi)
		_bloques.append(mi)
		if i % 3 == 0:
			var llama := FuegoToy.new()
			llama.definir(FuegoToy.Figura.PILAR, 0.055, 0.22, 0.055)
			llama.position = sitios[i] + Vector3(0, tamanos[i].y * 0.8, 0)
			llama.luz = 0.0
			llama.halo = 0.0
			llama.chispas = 0.15
			c.add_child(llama)
			_juntas.append(llama)

func _anim_si_hace_falta() -> void:
	super._anim_si_hace_falta()
	if figura == Figura.BOLA or figura == Figura.HAZ:
		return
	var ap := get_node("Anim") as AnimationPlayer
	for nombre in ["nacer", "morir"]:
		var an := ap.get_animation(nombre)
		var valor: float = 1.0 if nombre == "nacer" else 0.0
		an.length = 1.1 if nombre == "nacer" else 1.8
		an.track_remove_key(0, 1)
		an.track_insert_key(0, an.length, valor)
	dura_morir = 1.8

func _process(delta: float) -> void:
	super._process(delta)
	if figura == Figura.BOLA or figura == Figura.HAZ:
		return
	var muriendo: bool = _ap != null and _ap.current_animation == "morir"
	if _mat_base != null:
		_mat_base.set_shader_parameter("calor", calor * (aparicion * aparicion if muriendo else 0.85))
	for i in _bloques.size():
		var mi: MeshInstance3D = _bloques[i]
		var p: Vector3 = mi.get_meta("pos_final")
		var tam: Vector3 = mi.get_meta("tam_final")
		var sube: float = smoothstep(float(i % 5) * 0.06, 1.0, aparicion)
		mi.scale = tam * Vector3(1, maxf(sube, 0.001), 1)
		mi.position = p + Vector3(0, -0.35 * (1.0 - sube), 0)
	for llama in _juntas:
		llama.aparicion = aparicion * aparicion
		llama.visible = aparicion > 0.12
