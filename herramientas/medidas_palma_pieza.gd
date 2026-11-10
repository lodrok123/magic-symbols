extends SceneTree
## ¿Dónde queda una pieza larga (la cruz, un bastón) respecto a la PALMA de la mano derecha que la sostiene?
##   godot --headless --fixed-fps 60 --path . --script res://herramientas/medidas_palma_pieza.gd -- <id> [rol...]
## La palma se saca del esqueleto, no a ojo: su centro es el punto medio entre la muñeca y el nudillo del dedo corazón, y hacia
## dónde mira es (índice − muñeca) × (meñique − muñeca), que en una mano DERECHA sale de la palma (comprobado con la mano plana,
## palma abajo: da hacia abajo). El palo se mide a la altura de la palma.
## Lo que importa es `delante`: la distancia del eje del palo al plano de la palma, en positivo hacia donde mira la palma.
##   delante > 0  el palo está del lado de la palma: los dedos pueden cerrarse sobre él
##   delante < 0  el palo está por el DORSO de la mano: se ve detrás de la mano, que es lo que no vale
## `lateral` es lo que se desvía del centro de la palma a lo ancho (hacia el índice en positivo).
## Todo en unidades de mundo con el personaje a ALTO; x,z en el espacio del personaje (+z = delante).

const ALTO: float = 0.85
const MUESTRAS: int = 8


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var args: Array = Array(OS.get_cmdline_user_args())
	var id: String = String(args[0]) if args.size() > 0 else "santa_compana_cruz"
	var roles: Array = args.slice(1) if args.size() > 1 else ["idle", "walk"]
	var p := Pj3D.new()
	root.add_child(p)
	p.cargar(id)
	p.set_alto(ALTO)
	await process_frame
	var sk: Skeleton3D = (p.find_children("*", "Skeleton3D", true, false)[0]) as Skeleton3D
	var ap: AnimationPlayer = p._ap
	var pieza: Node3D = null
	for n in p.find_children("*", "Node3D", true, false):
		if (n as Node3D).has_meta("equipo_id"):
			pieza = n as Node3D
	if pieza == null:
		push_error("sin pieza")
		quit(1)
		return
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	var h: Dictionary = {}
	for n in ["Hand", "HandMiddle1", "HandIndex1", "HandPinky1"]:
		h[n] = sk.find_bone("mixamorig_Right" + n)
	# EL EJE DEL MANGO, medido en la malla y NO el origen del GLB: el mango de la cruz no pasa por el origen, y midiendo sobre el
	# origen esta herramienta decía «+0,022 por delante de la palma» mientras en la foto el palo estaba detrás de la mano.
	var eje: Vector3 = _eje_mango(pieza)
	print("%s · pieza %s · el mango pasa a (%+.3f, %+.3f) del origen de la pieza (unidades de la pieza)" % [id, pieza.get_meta("equipo_id"), eje.x, eje.z])
	for rol in roles:
		var clip: String = p.clip_de(String(rol))
		if clip == "":
			continue
		var largo: float = ap.get_animation(clip).length
		print("  %s (%s)   t      palma (x, y, z)        mira a (x, z)     palo (x, z)       delante   lateral" % [rol, clip])
		var s_del: float = 0.0
		var s_lat: float = 0.0
		for k in range(MUESTRAS):
			ap.play(clip)
			ap.seek(largo * float(k) / float(MUESTRAS), true)
			# las piezas apoyadas se colocan con `skeleton_updated`, y además suavizan: varios fotogramas para que asienten
			for i in 30:
				await process_frame
			var w: Vector3 = _g(sk, int(h["Hand"]))
			var m: Vector3 = _g(sk, int(h["HandMiddle1"]))
			var a: Vector3 = _g(sk, int(h["HandIndex1"])) - w
			var b: Vector3 = _g(sk, int(h["HandPinky1"])) - w
			var normal: Vector3 = a.cross(b).normalized()
			var centro: Vector3 = (w + m) * 0.5
			# el eje del palo: pasa por el origen de la pieza con su vertical
			var arriba: Vector3 = pieza.global_basis.y.normalized()
			var o: Vector3 = pieza.global_transform * eje
			var t: float = (centro.y - o.y) / maxf(arriba.y, 0.001)
			var palo: Vector3 = o + arriba * t                 # el punto del eje a la altura de la palma
			var d: Vector3 = palo - centro
			var delante: float = d.dot(normal)
			var ancho: Vector3 = (a - b).normalized()          # del meñique al índice
			var lateral: float = d.dot(ancho)
			s_del += delante
			s_lat += lateral
			var c: Vector3 = p.to_local(centro) * p.scale
			var pl: Vector3 = p.to_local(palo) * p.scale
			var nl: Vector3 = p.global_basis.orthonormalized().inverse() * normal
			print("                 %.2f   (%+.3f, %.3f, %+.3f)   (%+.2f, %+.2f)    (%+.3f, %+.3f)    %+.3f    %+.3f" % [
				largo * float(k) / float(MUESTRAS), c.x, c.y, c.z, nl.x, nl.z, pl.x, pl.z, delante, lateral])
		print("                 media: delante %+.3f, lateral %+.3f" % [s_del / float(MUESTRAS), s_lat / float(MUESTRAS)])
	quit(0)


## Centro XZ, en el espacio de la pieza, de los vértices del TERCIO DE ABAJO de sus mallas: por ahí pasa el mango (arriba están los
## brazos de la cruz y las campanillas, que lo descentrarían). Medido aquí aparte, sin fiarse de PiezaApoyada3D, que es lo que se comprueba.
static func _eje_mango(pieza: Node3D) -> Vector3:
	var pts: Array[Vector3] = []
	var inv: Transform3D = pieza.global_transform.affine_inverse()
	for n in pieza.find_children("*", "MeshInstance3D", true, false) + ([pieza] if pieza is MeshInstance3D else []):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				pts.append(inv * (mi.global_transform * v))
	if pts.is_empty():
		return Vector3.ZERO
	var y0: float = INF
	var y1: float = -INF
	for q in pts:
		y0 = minf(y0, q.y)
		y1 = maxf(y1, q.y)
	var suma := Vector3.ZERO
	var n_abajo: int = 0
	for q in pts:
		if q.y <= y0 + (y1 - y0) / 3.0:
			suma += q
			n_abajo += 1
	return Vector3(suma.x / float(n_abajo), 0.0, suma.z / float(n_abajo))


func _g(sk: Skeleton3D, b: int) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(b).origin
