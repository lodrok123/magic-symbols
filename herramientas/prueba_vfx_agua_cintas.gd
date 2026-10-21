extends SceneTree
## PRUEBA (Pipeline, 21/10, «VFX agua: tiene líneas»): las cintas de la burbuja de agua siguen a su vuelo EN ARCO. MEDIDO, no supuesto:
##   Causa: la bola de agua monta 3 cintas/conos hacia atrás de la dirección de SALIDA (`VfxAgua.bola`). Desde que el agua sale en arco (`impulso_salida`, 2cc7e84)
##   esa dirección era +42° hacia arriba y la velocidad gira hasta −27°; las cintas, clavadas, quedaban 61–82° desviadas de la estela a media caída: rayas sueltas.
##   El fuego no tiene gravedad: su dirección no cambia y sus conos siempre estuvieron a ≤ 10° de la cola.
##   1. AGUA: en cada cuadro del vuelo cada cinta apunta a ≤ 15° de −velocidad (antes del arreglo llegaba a ~82°).
##   2. AGUA: no hay geometría de más: 2 esferas (piel y brillo), 3 cintas finas más cortas que el diámetro de la bola ×1,5, 1 emisor de gotas sin `align_y` (nada
##      de chispas alargadas) y ningún ImmediateMesh.
##   3. FUEGO: no cambia (su dibujo no recibe giro de cintas y la transformación de sus conos es la misma durante todo el vuelo).
##   4. Parado (llegó): las cintas se apagan como siempre y ya no giran.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_vfx_agua_cintas.gd

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass

const LADO: int = 20
const SALIDA: Vector2i = Vector2i(5, 8)
const DT: float = 1.0 / 30.0
## Una cinta nace abierta ≤ 0,22 rad × … (≈ 12,4° medidos en el agua) respecto a la cola; 15° es ese abanico más un margen.
const MAX_DESVIO_GRADOS: float = 15.0

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _vfx: VfxElemento3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	var filas: PackedStringArray = []
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			f += "#" if (x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1) else "."
		filas.append(f)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(LADO):
		for x in range(LADO):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_l = Lanzador3D.new()
	_l.mundo = _m
	root.add_child(_l)
	_vfx = VfxElemento3D.conectar(_l, _m)
	var es: VfxEstado3D = VfxEstado3D.conectar(_l, _m)
	es.encendido = false
	await _agua()
	await _fuego()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _lanzar(el: String) -> Array:
	var r: RuneData = load("res://nucleo/%s_rune.tres" % el) as RuneData
	var h: Hechizo = Hechizo.construir(r, {"flecha": 1})
	var o: Vector3 = Lanzador3D.centro_de(SALIDA, Terreno3D.y_pies(SALIDA) + 0.8)
	var v: HechizoVivo = HechizoVivo.crear(h, o, Vector3.RIGHT, _l, null, {}, true)
	await process_frame
	await process_frame
	var seg: VfxElemento3D.Proyectil = v.get_node_or_null("VfxElementoProyectil") as VfxElemento3D.Proyectil
	return [v, seg]


func _conos(seg: Node3D) -> Array:
	var l: Array = []
	for n in seg.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).mesh is CylinderMesh:
			l.append(n)
	return l


func _agua() -> void:
	print("--- 1/2/4. agua (arco): cintas siguen a la velocidad")
	var par: Array = await _lanzar("water")
	var v: HechizoVivo = par[0]
	var seg: VfxElemento3D.Proyectil = par[1]
	_ok("agua: el proyectil tiene seguidor", seg != null)
	if seg == null:
		return
	_ok("agua: sale en arco (v.y %.2f > 0, gravedad %.2f)" % [v.v.y, v.h.gravedad], v.v.y > 0.0 and v.h.gravedad > 0.0)
	seg._process(VfxElemento3D.PROYECTIL_CRECE_S + 0.1)
	var conos: Array = _conos(seg)
	_ok("agua: 3 cintas (conos)", conos.size() == 3, "(%d)" % conos.size())
	var esferas: int = 0
	var inmediatas: int = 0
	var gp_n: int = 0
	var gp_alineado: int = 0
	var diametro: float = 0.0
	for n in seg.find_children("*", "", true, false):
		if n is MeshInstance3D:
			var mesh: Mesh = (n as MeshInstance3D).mesh
			if mesh is SphereMesh:
				esferas += 1
				diametro = maxf(diametro, mesh.get_aabb().size.x * (n as Node3D).global_transform.basis.get_scale().x)
			if mesh is ImmediateMesh:
				inmediatas += 1
		elif n is GPUParticles3D:
			gp_n += 1
			if ((n as GPUParticles3D).process_material as ParticleProcessMaterial).particle_flag_align_y:
				gp_alineado += 1
	_ok("agua: 2 esferas (piel y brillo), 1 emisor de gotas, 0 ImmediateMesh", esferas == 2 and gp_n == 1 and inmediatas == 0, "(esferas %d, emisores %d, inmediatas %d)" % [esferas, gp_n, inmediatas])
	_ok("agua: el emisor de gotas no está alineado a la velocidad (nada de chispas alargadas)", gp_alineado == 0)
	var largo_max: float = 0.0
	for c in conos:
		largo_max = maxf(largo_max, (c as MeshInstance3D).mesh.get_aabb().size.y * (c as Node3D).global_transform.basis.get_scale().y)
	_ok("agua: las cintas (%.2f u) no pasan de 1,5 veces el diámetro de la bola (%.2f u)" % [largo_max, diametro], largo_max <= 1.5 * diametro)
	var peor: float = 0.0
	var cuadros: int = 0
	var v_y_min: float = 1.0e9
	var v_y_max: float = -1.0e9
	while v.activo and cuadros < 120:
		var dirv: Vector3 = v.v.normalized()
		v_y_min = minf(v_y_min, dirv.y)
		v_y_max = maxf(v_y_max, dirv.y)
		for c in conos:
			var eje: Vector3 = ((c as Node3D).global_transform.basis * Vector3.UP).normalized()
			peor = maxf(peor, rad_to_deg(eje.angle_to(-dirv)))
		v.paso(DT)
		seg._process(DT)
		cuadros += 1
	_ok("agua: durante %d cuadros la dirección de vuelo cambió (y de %.2f a %.2f)" % [cuadros, v_y_max, v_y_min], v_y_max - v_y_min > 0.5)
	_ok("agua: cada cinta apunta a ≤ %.0f° de la estela en todo el vuelo (peor %.1f°)" % [MAX_DESVIO_GRADOS, peor], peor <= MAX_DESVIO_GRADOS)
	# parado: las cintas se apagan y dejan de girar
	for i in range(10):
		seg._process(DT)
	_ok("agua: al llegar el seguidor está parado y las cintas ocultas", seg.parado() and conos.all(func(c: Node) -> bool: return not (c as Node3D).visible))
	var igual: bool = true
	var t_antes: Array = conos.map(func(c: Node) -> Transform3D: return (c as Node3D).transform)
	v.v = Vector3(0.0, 4.0, 0.0)          # aunque la velocidad cambie, parado no se reorienta nada
	seg._process(DT)
	for i in range(conos.size()):
		igual = igual and (conos[i] as Node3D).transform.is_equal_approx(t_antes[i] as Transform3D)
	_ok("agua parada: el seguidor no vuelve a orientar las cintas", igual)
	v.queue_free()
	await process_frame
	# CONTROL de la prueba: sin el giro (dir_cintas = 0, como estaba antes del arreglo) el mismo vuelo SÍ deja las cintas desviadas: la medida distingue
	var par2: Array = await _lanzar("water")
	var v2: HechizoVivo = par2[0]
	var seg2: VfxElemento3D.Proyectil = par2[1]
	seg2.dir_cintas = Vector3.ZERO
	seg2._process(VfxElemento3D.PROYECTIL_CRECE_S + 0.1)
	var conos2: Array = _conos(seg2)
	var peor2: float = 0.0
	var n2: int = 0
	while v2.activo and n2 < 120:
		for c in conos2:
			var eje2: Vector3 = ((c as Node3D).global_transform.basis * Vector3.UP).normalized()
			peor2 = maxf(peor2, rad_to_deg(eje2.angle_to(-v2.v.normalized())))
		v2.paso(DT)
		seg2._process(DT)
		n2 += 1
	_ok("CONTROL agua sin giro (estado de antes del arreglo): las cintas se desvían %.1f° (> 45°)" % peor2, peor2 > 45.0)
	v2.queue_free()
	await process_frame


func _fuego() -> void:
	print("--- 3. fuego: igual que antes")
	var par: Array = await _lanzar("fire")
	var v: HechizoVivo = par[0]
	var seg: VfxElemento3D.Proyectil = par[1]
	_ok("fuego: tiene seguidor", seg != null)
	if seg == null:
		return
	_ok("fuego: sin gravedad → no gira cintas (dir_cintas = 0)", v.h.gravedad == 0.0 and seg.dir_cintas == Vector3.ZERO)
	seg._process(VfxElemento3D.PROYECTIL_CRECE_S + 0.1)
	var conos: Array = _conos(seg)
	_ok("fuego: 3 conos de cola", conos.size() == 3, "(%d)" % conos.size())
	var t0: Array = conos.map(func(c: Node) -> Transform3D: return (c as Node3D).transform)
	var cuadros: int = 0
	var peor: float = 0.0
	var igual: bool = true
	while v.activo and cuadros < 120:
		for i in range(conos.size()):
			var c: Node3D = conos[i]
			igual = igual and c.transform.is_equal_approx(t0[i] as Transform3D)
			var eje: Vector3 = (c.global_transform.basis * Vector3.UP).normalized()
			peor = maxf(peor, rad_to_deg(eje.angle_to(-v.v.normalized())))
		v.paso(DT)
		seg._process(DT)
		cuadros += 1
	_ok("fuego: la transformación de sus conos no cambia en %d cuadros" % cuadros, igual)
	_ok("fuego: sus conos siguen a ≤ 10,1° de la cola (peor %.1f°)" % peor, peor <= 10.1)
	v.queue_free()
	await process_frame
