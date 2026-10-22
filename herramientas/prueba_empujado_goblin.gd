extends SceneTree
## 22/10 · SER EMPUJADO Y LEVANTARSE de los goblins (clips «BeHit_FlyUp» y «Stand_Up1», ver Pj3D._preparar_empujado). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_empujado_goblin.gd
## Lo que comprueba, para el guerrero Y el arquero:
##   1. Los dos clips están en su librería, no pisan al `hit`, y duran lo esperado (1,5 s y ~1,2 s); el Drowning sigue ahí.
##   2. En el propio clip: la cadera sube ≈ lo escalado, x/z quedan fijas (sin deriva horizontal) y el final tumbado no queda hundido.
##   3. Un empujón fuerte lo dispara (fase VOLANDO, estado «empujado»), uno suave no; vuela de verdad (cadera en el mundo), sin deriva horizontal respecto
##      a su nodo; durante todo el empujado + levantarse no anda ni ataca (aunque la jugadora esté al lado).
##   4. Vivo, vuelve a Idle y de pie (cadera a la altura de la de pie). Muerto en mitad del vuelo: no se levanta, queda en «muerto».
##   5. El escudo del guerrero viaja con el cuerpo mientras vuela.

const DT: float = 1.0 / 30.0
const S: float = 2.3
const LADO: int = 14
const IDS: Array = ["goblin_warrior_chibi", "goblin_archer_chibi", "goblin_asesino"]     # el asesino (otro esqueleto): sus dos clips se traducen con ClipsFamilia

var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar()
	for id in IDS:
		_clips(id)
		_vuelo(id)
		_muerte_en_vuelo(id)
	_suave()
	_escudo()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			if x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1:
				f += "#"
				bloq[Vector2i(x, y)] = true
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_jugador = Jugador3D.new()
	_jugador.position = Vector3(3.5 * S, Terreno3D.alto_suelo, 6.5 * S)
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)


func _nuevo(id: String, p: Vector3, quieto: bool = false) -> Combate3D:
	var modelo := Pj3D.new()
	_mundo.add_child(modelo)
	modelo.cargar(id)
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.altura = 0.85
	g.quieto = quieto
	g.position = p
	g.casa = p
	return g


func _suelo(cx: float, cz: float) -> Vector3:
	return Vector3((cx + 0.5) * S, Terreno3D.y_pies(Vector2i(int(cx), int(cz))), (cz + 0.5) * S)


## Un fotograma de 1/30 s: la IA/animación del goblin y el árbol de animación a mano (sin esperar fotogramas del motor).
func _paso(g: Combate3D) -> void:
	g._physics_process(DT)
	if g.pj != null and is_instance_valid(g.pj):
		g.pj.arbol().avanzar(DT)


func _quitar(g: Combate3D) -> void:
	if is_instance_valid(g):
		if is_instance_valid(g.pj):
			g.pj.free()
		g.free()


## Altura de la cadera sobre el suelo del nodo, en alturas de modelo SIN escalar (÷ escala del pj), y su desplazamiento horizontal respecto al nodo.
func _cadera(g: Combate3D) -> Vector3:
	var cd: Array = g.pj.cadera_mundo()
	if cd.size() != 2:
		return Vector3(NAN, NAN, NAN)
	var o: Vector3 = (cd[0] as Transform3D).origin - g.pj.global_position
	var s: float = g.pj.scale.y
	return Vector3(o.x / s, o.y / s, o.z / s)


func _pista_cadera(an: Animation) -> int:
	for i in range(an.get_track_count()):
		if an.track_get_type(i) == Animation.TYPE_POSITION_3D and String(an.track_get_path(i)).to_lower().ends_with("hips"):
			return i
	return -1


func _clips(id: String) -> void:
	var g := _nuevo(id, _suelo(2, 2), true)
	var pj: Pj3D = g.pj
	_ok("%s · trae los clips de empujado y levantarse" % id, pj.tiene_empujado())
	var ap: AnimationPlayer = pj._ap
	_ok("%s · Empujado y Levantarse en su librería, sin duplicar GLB" % id, ap.has_animation("Empujado") and ap.has_animation("Levantarse"))
	_ok("%s · empujado dura 1,5 s" % id, absf(pj.duracion("empujado") - 1.5) < 0.05, "%.3f" % pj.duracion("empujado"))
	var esperado: float = (Pj3D.LEVANTARSE_HASTA - Pj3D.LEVANTARSE_DESDE) / Pj3D.LEVANTARSE_VEL
	_ok("%s · levantarse dura lo recortado (%.2f s, entre 1,0 y 1,5)" % [id, esperado], absf(pj.duracion("levantarse") - esperado) < 0.05 \
		and pj.duracion("levantarse") >= 1.0 and pj.duracion("levantarse") <= 1.5, "%.3f" % pj.duracion("levantarse"))
	_ok("%s · el rol hit sigue siendo su clip de golpe (no el empujado)" % id, pj.clip_de("hit") != "Empujado" and pj.clip_de("hit") != "" , pj.clip_de("hit"))
	_ok("%s · Drowning sigue" % id, pj.duracion("drown") > 3.0, "%.2f" % pj.duracion("drown"))
	# El propio clip: sin deriva horizontal; la cadera sube lo escalado; el final no queda por debajo del suelo.
	var an: Animation = ap.get_animation("Empujado")
	var t: int = _pista_cadera(an)
	var ymin: float = 1e9
	var ymax: float = -1e9
	var xmin: float = 1e9
	var xmax: float = -1e9
	var zmin: float = 1e9
	var zmax: float = -1e9
	for k in range(an.track_get_key_count(t)):
		var v: Vector3 = an.track_get_key_value(t, k)
		ymin = minf(ymin, v.y)
		ymax = maxf(ymax, v.y)
		xmin = minf(xmin, v.x)
		xmax = maxf(xmax, v.x)
		zmin = minf(zmin, v.z)
		zmax = maxf(zmax, v.z)
	var y0: float = (an.track_get_key_value(t, 0) as Vector3).y
	var yf: float = (an.track_get_key_value(t, an.track_get_key_count(t) - 1) as Vector3).y
	var subida: float = ymax - y0
	print("      %s · cadera del clip: y0 %.3f, máx %.3f (sube %.3f), final %.3f, x [%.4f, %.4f] z [%.4f, %.4f]" % [id, y0, ymax, subida, yf, xmin, xmax, zmin, zmax])
	# 1,267 es lo que sube en un goblin de 1,7 de alto; en el asesino (0,977) sube lo mismo EN PROPORCIÓN (× su alto / 1,7).
	var k_alto: float = pj.alto_modelo() / Pj3D.ALTO_MODELO_GOBLIN_FUENTE
	_ok("%s · la cadera sube ≈ 1,27 × EMPUJADO_ESCALA_VUELO (× alto/1,7 = %.2f)" % [id, k_alto], absf(subida - 1.267 * Pj3D.EMPUJADO_ESCALA_VUELO * k_alto) < 0.12 * k_alto)
	_ok("%s · sin deriva horizontal en el clip" % id, xmax - xmin < 0.0001 and zmax - zmin < 0.0001)
	_ok("%s · el final tumbado no se hunde (cadera ≥ −0,15 y sobre el suelo de su muerte)" % id, yf > -0.15 and yf < 0.35, "%.3f" % yf)
	var an2: Animation = ap.get_animation("Levantarse")
	var t2: int = _pista_cadera(an2)
	var n2: int = an2.track_get_key_count(t2)
	var u0: float = (an2.track_get_key_value(t2, 0) as Vector3).y
	var u1: float = (an2.track_get_key_value(t2, n2 - 1) as Vector3).y
	_ok("%s · levantarse empieza donde acaba el empujado (misma y de cadera)" % id, absf(u0 - yf) < 0.02, "%.3f vs %.3f" % [u0, yf])
	var pie: float = (pj._cadera_de_pie as Transform3D).origin.y
	_ok("%s · levantarse acaba con la cadera a la altura de pie" % id, absf(u1 - pie) < 0.03, "%.3f vs %.3f" % [u1, pie])
	var dx: float = absf((an2.track_get_key_value(t2, 0) as Vector3).x - (an2.track_get_key_value(t2, n2 - 1) as Vector3).x)
	var dz: float = absf((an2.track_get_key_value(t2, 0) as Vector3).z - (an2.track_get_key_value(t2, n2 - 1) as Vector3).z)
	_ok("%s · levantarse sin deriva horizontal" % id, dx < 0.0001 and dz < 0.0001)
	# Salto entre la última pose del empujado y la primera del levantarse (grados máx. en un hueso).
	var mx: float = 0.0
	for i in range(an.get_track_count()):
		if an.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var p: NodePath = an.track_get_path(i)
		var j: int = an2.find_track(p, Animation.TYPE_ROTATION_3D)
		if j < 0:
			continue
		var qa: Quaternion = an.rotation_track_interpolate(i, an.length)
		var qb: Quaternion = an2.rotation_track_interpolate(j, 0.0)
		mx = maxf(mx, rad_to_deg(qa.angle_to(qb)))
	print("      %s · mayor giro de un hueso entre el último fotograma de empujado y el primero de levantarse: %.1f°" % [id, mx])
	_quitar(g)


func _vuelo(id: String) -> void:
	# Con la jugadora al lado (3 u): si no estuviera volando, un goblin que ve al jugador ataca.
	var g := _nuevo(id, _suelo(3, 6), false)
	_jugador.position = g.position + Vector3(0.9, 0.0, 0.0)
	var pie: Vector3 = _cadera(g)
	for _i in range(3):
		_paso(g)
	pie = _cadera(g)
	g.push(Vector3(-1, 0, 0), 1500.0, true)
	_ok("%s · el empujón fuerte lo lanza" % id, g.fase_empuje() == Combate3D.FASE_VOLANDO)
	var max_y: float = 0.0
	var max_drift: float = 0.0
	var ataco: bool = false
	var anda: bool = false
	var estado_ok: bool = true
	var ticks: int = 0
	var t_vuelo: int = 0
	while g.en_empujado() and ticks < 200:
		_paso(g)
		ticks += 1
		if g.fase_empuje() == Combate3D.FASE_VOLANDO:
			t_vuelo = ticks
			estado_ok = estado_ok and g.pj.estado_anim() == "empujado"
		var c: Vector3 = _cadera(g)
		max_y = maxf(max_y, c.y - pie.y)
		max_drift = maxf(max_drift, Vector2(c.x - pie.x, c.z - pie.z).length())
		if g.en_empujado():
			ataco = ataco or g._ataque > 0.0
			anda = anda or g.moviendo != 0
	print("      %s · vuela %.2f s (%d fotogramas), +%.3f de cadera (por unidad de modelo; ×%.2f escala = %.2f u en el juego), deriva horizontal máx %.3f, tardó %d fotogramas en total" % [
		id, t_vuelo * DT, t_vuelo, max_y, g.pj.scale.y, max_y * g.pj.scale.y, max_drift, ticks])
	var k_alto_v: float = g.pj.alto_modelo() / Pj3D.ALTO_MODELO_GOBLIN_FUENTE
	_ok("%s · la cadera sube de verdad en el mundo (≈ lo escalado)" % id, absf(max_y - 1.267 * Pj3D.EMPUJADO_ESCALA_VUELO * k_alto_v) < 0.2 * k_alto_v)
	_ok("%s · sin deriva horizontal respecto a su nodo" % id, max_drift < 0.12)
	_ok("%s · durante el vuelo el estado es «empujado»" % id, estado_ok)
	_ok("%s · no ataca ni camina mientras vuela y se levanta" % id, not ataco and not anda)
	_ok("%s · la duración total es empujado + levantarse (±4 fotogramas)" % id, absi(ticks - int(round((1.5 + g.pj.duracion("levantarse")) * 30.0))) <= 4, "%d" % ticks)
	_ok("%s · ya no está empujado" % id, not g.en_empujado())
	g.quieto = true                      # (si no, se iría a por la jugadora, que está al lado)
	for _i in range(6):
		_paso(g)
	var c2: Vector3 = _cadera(g)
	_ok("%s · vuelve a Idle" % id, g.pj.estado_anim() == "idle", g.pj.estado_anim())
	_ok("%s · y de pie (cadera a la altura de pie ± 0,06)" % id, absf(c2.y - pie.y) < 0.06, "%.3f vs %.3f" % [c2.y, pie.y])
	_quitar(g)


func _muerte_en_vuelo(id: String) -> void:
	var g := _nuevo(id, _suelo(5, 5), true)
	g.push(Vector3(1, 0, 0), 1500.0, true)
	for _i in range(12):
		_paso(g)
	_ok("%s · en pleno vuelo" % id, g.fase_empuje() == Combate3D.FASE_VOLANDO)
	g.receive_damage(99999.0)
	_ok("%s · muere en el aire y deja de estar empujado" % id, g.muerto and not g.en_empujado())
	for _i in range(90):
		if is_instance_valid(g) and not g.muerto:
			break
		if is_instance_valid(g.pj):
			g.pj.arbol().avanzar(DT)
	if is_instance_valid(g.pj):
		_ok("%s · queda en «muerto», no se levanta" % id, g.pj.estado_anim() == "muerto", g.pj.estado_anim())
	_quitar(g)


func _suave() -> void:
	var g := _nuevo("goblin_warrior_chibi", _suelo(8, 8), true)
	g.push(Vector3(1, 0, 0), 10.0)
	_ok("un soplo suave (fuerza 10) no lo lanza", not g.en_empujado())
	Combate3D.EMPUJADO_ACTIVO = false
	g.push(Vector3(1, 0, 0), 1500.0, true)
	_ok("con EMPUJADO_ACTIVO = false no se lanza", not g.en_empujado())
	Combate3D.EMPUJADO_ACTIVO = true
	_quitar(g)


func _escudo() -> void:
	var g := _nuevo("goblin_warrior_chibi", _suelo(9, 9), true)
	var e: Escudo3D = Escudo3D.equipar(g)
	g.mirada = Vector3(-1, 0, 0)
	for _i in range(3):
		_paso(g)
	e._colocar()
	var y_pie: float = e.global_position.y
	g.push(Vector3(-1, 0, 0), 1500.0, true)
	var y_max: float = y_pie
	var lejos: float = 0.0
	for _i in range(60):
		_paso(g)
		e._colocar()
		y_max = maxf(y_max, e.global_position.y)
		var c: Array = g.pj.cadera_mundo()
		if c.size() == 2:
			lejos = maxf(lejos, e.global_position.distance_to((c[0] as Transform3D).origin))
	print("      escudo: y de pie %.3f, máx en vuelo %.3f, mayor distancia a la cadera %.3f (altura del goblin 0,85)" % [y_pie, y_max, lejos])
	_ok("el escudo sube con el cuerpo", y_max > y_pie + 0.25)
	_ok("el escudo no se separa del cuerpo (< 0,8 de la cadera)", lejos < 0.8)
	_quitar(g)
