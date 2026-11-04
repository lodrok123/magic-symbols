extends SceneTree
## 5/11 (Pablo, playtest del Bosque 02: «hay muros no lógicos: el muro goblin con dirección este cuando debería ir al norte, estando la colisión bien»). Sin ventana:
##   godot --headless --path . -s res://herramientas/prueba_muros_alineacion.gd
## Para las piezas ALARGADAS (huella del modelo con eje largo ≥ 1,5 × el corto) comprueba que el MODELO dibujado y su COLISIÓN apuntan al mismo lado:
##   A · en cada pieza de la tabla `ColisionPieza.MODO` (marco local, sin colocar): el eje largo del modelo y el de su casco coinciden (si no, falta/sobra giro en `Pieza3D.GIRO_MODELO`).
##   B · en cada instancia del Bosque 02 (Nivel_Bosque_02.tscn: piezas y marcadores reactivos como la puerta y la torre goblin), ya con su giro puesto: lo mismo, en el mundo.
##   C · los TRAMOS DE MURO (empalizada, puerta goblin y vallas: instancias vecinas, a una casilla de distancia): el eje largo del modelo va en la línea del tramo (norte-sur si
##       las vecinas están al norte y al sur; este-oeste si están a los lados). Una empalizada de través sale a rayas perpendiculares al muro, con huecos.
##   D · el arco de la boca de la Cueva: sus pilares quedan a norte y sur del camino (su eje largo, el del vano, va de norte a sur: se cruza de oeste a este).
## Los números salen en grados del eje largo respecto a +X (0 = este-oeste, 90 = norte-sur).

const NIVEL: String = "res://mundo/datos_nivel/Nivel_Bosque_02.tscn"
const ASPECTO_MIN: float = 1.5            ## eje largo / eje corto de la huella para llamarla «alargada»
const TOL_GRADOS: float = 20.0            ## cuánto se puede desviar el eje largo del modelo del de su colisión
const DIST_VECINA: float = 3.0            ## u entre centros para llamar «vecina» a otra pieza de muro (la casilla mide 2,25)
const MUROS: Array = ["empalizada_goblin", "puerta_goblin", "valla", "valla_lianas", "muro_ruina"]

var fallos: int = 0


func _ok(cond: bool, texto: String) -> void:
	if cond:
		print("  ok   ", texto)
	else:
		fallos += 1
		print("  FALLO ", texto)


func _init() -> void:
	_parte_a()
	_parte_bcd()
	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)


## Huella (ancho X, fondo Z) del modelo y de su colisión en el marco local de la pieza. {} si no hay modelo.
func _huellas(id: String) -> Dictionary:
	var vis: Node3D = Pieza3D.crear_visual(id)
	if vis == null:
		return {}
	var tris: PackedVector3Array = ColisionPieza._triangulos(vis, Transform3D.IDENTITY)
	vis.free()
	if tris.is_empty():
		return {}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in tris:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	var lista: Array = Pieza3D.cascos_colision(id)
	var klo := Vector2(INF, INF)
	var khi := Vector2(-INF, -INF)
	for nube in lista:
		for p in (nube as PackedVector3Array):
			klo = klo.min(Vector2(p.x, p.z))
			khi = khi.max(Vector2(p.x, p.z))
	var k: Vector2 = Vector2.ZERO if lista.is_empty() else khi - klo
	return {"v": hi - lo, "k": k}


## Ángulo (grados, 0..180) del eje largo de una huella (x, z): 0 si va por X, 90 si va por Z.
func _eje(huella: Vector2) -> float:
	return 0.0 if huella.x >= huella.y else 90.0


func _aspecto(h: Vector2) -> float:
	return maxf(h.x, h.y) / maxf(minf(h.x, h.y), 0.01)


func _dif_eje(a: float, b: float) -> float:
	var d: float = fposmod(a - b, 180.0)
	return minf(d, 180.0 - d)


## A · marco local.
func _parte_a() -> void:
	print("# A · eje largo del modelo frente al de su colisión (marco local)")
	var ids: Array = ColisionPieza.MODO.keys()
	ids.sort()
	var n: int = 0
	for id in ids:
		var h: Dictionary = _huellas(String(id))
		if h.is_empty() or (h["k"] as Vector2) == Vector2.ZERO:
			continue
		var v: Vector2 = h["v"]
		var k: Vector2 = h["k"]
		if _aspecto(v) < ASPECTO_MIN or _aspecto(k) < ASPECTO_MIN:
			continue
		n += 1
		_ok(_dif_eje(_eje(v), _eje(k)) < TOL_GRADOS, "%-20s modelo %.2f x %.2f (eje %.0f°) · colisión %.2f x %.2f (eje %.0f°)" % [id, v.x, v.y, _eje(v), k.x, k.y, _eje(k)])
	_ok(n >= 3, "hay piezas alargadas que comprobar (%d)" % n)


## B, C y D · instancias del Bosque 02.
func _parte_bcd() -> void:
	print("# B/C/D · las instancias del Bosque 02 ya colocadas")
	var raiz: Node = (load(NIVEL) as PackedScene).instantiate()
	var inst: Array = []        # [id, nombre, Vector2 posición xz, eje largo del modelo en el mundo, eje largo de la colisión en el mundo]
	var cache: Dictionary = {}
	for n in raiz.find_children("*", "Node3D", true, false):
		var id: String = ""
		if n.has_meta("id"):
			id = String(n.get_meta("id"))
		elif n.get("tipo") != null and String(n.get("tipo")) != "":
			id = String(n.get("tipo"))
		if id == "":
			continue
		if not cache.has(id):
			cache[id] = _huellas(id)
		var h: Dictionary = cache[id]
		if h.is_empty():
			continue
		var v: Vector2 = h["v"]
		var k: Vector2 = h["k"]
		var alargada: bool = _aspecto(v) >= ASPECTO_MIN or MUROS.has(id)
		if not alargada:
			continue
		var yaw: float = rad_to_deg((n as Node3D).transform.basis.orthonormalized().get_euler().y)
		var giro90: bool = _dif_eje(yaw, 90.0) < 45.0           # el giro lleva X a Z (90° o 270°)
		var eje_v: float = _eje(v) + (90.0 if giro90 else 0.0)
		var eje_k: float = _eje(k) + (90.0 if giro90 else 0.0)
		var p: Vector3 = (n as Node3D).position
		inst.append([id, String(n.name), Vector2(p.x, p.z), fposmod(eje_v, 180.0), fposmod(eje_k, 180.0), k != Vector2.ZERO and _aspecto(k) >= ASPECTO_MIN])
	print("  %d instancias alargadas o de muro" % inst.size())
	_ok(inst.size() >= 8, "el Bosque 02 trae piezas alargadas o de muro (%d)" % inst.size())
	# B
	for f in inst:
		if bool(f[5]):
			_ok(_dif_eje(float(f[3]), float(f[4])) < TOL_GRADOS, "B %-20s %-28s modelo %.0f° · colisión %.0f° (mundo)" % [f[0], f[1], f[3], f[4]])
	# C
	var tramos: int = 0
	for f in inst:
		if not MUROS.has(String(f[0])):
			continue
		var vecinas: Array = []
		for g in inst:
			if g != f and MUROS.has(String(g[0])) and (f[2] as Vector2).distance_to(g[2] as Vector2) < DIST_VECINA:
				vecinas.append(g)
		if vecinas.is_empty():
			continue
		var por_x: bool = false
		var por_z: bool = false
		for g in vecinas:
			var d: Vector2 = (g[2] as Vector2) - (f[2] as Vector2)
			if absf(d.x) > absf(d.y):
				por_x = true
			else:
				por_z = true
		if por_x == por_z:
			continue                  # una esquina (vecinas por los dos lados): no hay línea que seguir
		var linea: float = 0.0 if por_x else 90.0
		tramos += 1
		_ok(_dif_eje(float(f[3]), linea) < TOL_GRADOS, "C %-20s %-28s tramo %s: modelo %.0f° (línea del muro %.0f°)" % [f[0], f[1], "este-oeste" if por_x else "norte-sur", f[3], linea])
	_ok(tramos >= 5, "hay tramos de muro que comprobar (%d)" % tramos)
	# D · el arco de la boca de la Cueva (35,24): el vano debe mirar al camino (se cruza de oeste a este) → eje largo de norte a sur
	var arcos: int = 0
	for f in inst:
		if String(f[0]) == "arco_ruina":
			arcos += 1
			_ok(_dif_eje(float(f[3]), 90.0) < TOL_GRADOS, "D %-20s %-28s eje largo %.0f° (debe ir de norte a sur: pilares a los lados del camino)" % [f[0], f[1], f[3]])
	_ok(arcos >= 1, "el Bosque 02 trae el arco de la boca (%d)" % arcos)
	raiz.free()
