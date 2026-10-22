extends "res://herramientas/escenario_base.gd"
## PRUEBA DEL AGUA EoW (Pipeline, 22/10; docs/PLAN_EOW_VISUAL.md §1.6 y §2 fila «Agua»): REFRACCIÓN, TERCERA ESCALA DE OLAS y SONDAS DE REFLEJOS POR SALA.
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_agua_eow.gd
## Sin ventana no hay GPU: mide los números y el cableado (uniformes, interruptores, cajas y número de sondas, que las ondas de impacto y el flow map siguen llegando al sombreado),
## NO cómo se ve. Para eso están las capturas (herramientas/captura_agua_eow.gd, con ventana).
##   · A  `LuzZona3D.cajas_sondas` con mapas inventados: una caja por región con agua, ninguna donde no hay, la caja envuelve el agua + margen y no se sale de la región/mapa.
##   · B  el laboratorio de 7 salas: sombreado (uniformes, interruptores, prioridad), sondas por sala (solo las salas con agua, dentro de su sala), sonda única si se apaga, impacto.
##   · C  el Bosque 01: lo mismo con bloques de LuzZona3D.SONDA_BLOQUE, el flow map vivo y todo el agua cubierta por alguna sonda.

const RUTA_LAB: String = "res://laboratorios/LabPlaytestEoW.tscn"
const RUTA_B01: String = "res://escenas/PruebaBosque01.tscn"


func _escenario() -> void:
	_estatico()
	await cargar(RUTA_LAB)
	await _lab()
	maqueta.queue_free()
	await avanzar(20)
	await cargar(RUTA_B01, true)
	await _bosque()


# ---------------------------------------------------------------------------------------------------------------------
#  A · cajas de sondas con mapas inventados
# ---------------------------------------------------------------------------------------------------------------------

func _estatico() -> void:
	var agua: Dictionary = {}
	for y in range(3, 7):
		for x in range(4, 9):
			agua[Vector2i(x, y)] = true                    # un lago en el bloque (0,0)
	for x in range(30, 34):
		agua[Vector2i(x, 30)] = true                        # y un arroyo en el bloque (2,2)
	var hay := func(c: Vector2i) -> bool: return agua.has(c)
	var cajas: Array = LuzZona3D.cajas_sondas(hay, 40, 40, [], 12, 2)
	_ok("A1 dos regiones con agua dan dos cajas (no una por bloque)", cajas.size() == 2, "cajas %s" % [cajas])
	_ok("A2 la caja del lago envuelve el agua más el margen", (cajas[0] as Rect2i) == Rect2i(2, 1, 9, 8), "%s" % [cajas[0]])
	var todas_dentro: bool = true
	for c in agua.keys():
		var dentro: bool = false
		for r in cajas:
			if (r as Rect2i).has_point(c):
				dentro = true
		todas_dentro = todas_dentro and dentro
	_ok("A3 toda casilla de agua cae dentro de alguna caja", todas_dentro)
	for r in cajas:
		_ok("A4 la caja %s está dentro del mapa" % [r], Rect2i(0, 0, 40, 40).encloses(r as Rect2i))
	_ok("A5 sin agua no hay sondas", LuzZona3D.cajas_sondas(func(_c: Vector2i) -> bool: return false, 40, 40, []).is_empty())
	# Con salas: solo las que tienen agua, y la caja no se sale de su sala.
	var salas: Array = [Rect2i(0, 0, 10, 10), Rect2i(10, 0, 10, 10), Rect2i(20, 0, 10, 10)]
	var agua2: Dictionary = {Vector2i(1, 1): true, Vector2i(9, 9): true, Vector2i(25, 5): true}
	var cs: Array = LuzZona3D.cajas_sondas(func(c: Vector2i) -> bool: return agua2.has(c), 30, 10, salas, 12, 3)
	_ok("A6 con salas: dos con agua = dos cajas (la del medio, vacía, no lleva)", cs.size() == 2, "%s" % [cs])
	_ok("A7 la caja de una sala no se sale de su sala", (salas[0] as Rect2i).encloses(cs[0] as Rect2i) and (salas[2] as Rect2i).encloses(cs[1] as Rect2i), "%s" % [cs])
	_ok("A8 la caja envuelve TODA el agua de su sala", (cs[0] as Rect2i).has_point(Vector2i(1, 1)) and (cs[0] as Rect2i).has_point(Vector2i(9, 9)))
	# Los bloques que se salen del mapa se recortan.
	var cb: Array = LuzZona3D.cajas_sondas(func(c: Vector2i) -> bool: return c == Vector2i(37, 37), 38, 38, [], 12, 2)
	_ok("A9 el último bloque (parcial) también vale y se recorta al mapa", cb.size() == 1 and Rect2i(0, 0, 38, 38).encloses(cb[0] as Rect2i), "%s" % [cb])
	_ok("A10 constantes con nombre: bloque %d, margen %d, alto %.0f" % [LuzZona3D.SONDA_BLOQUE, LuzZona3D.SONDA_MARGEN, LuzZona3D.SONDA_ALTO],
		LuzZona3D.SONDA_BLOQUE >= 4 and LuzZona3D.SONDA_MARGEN >= 0 and LuzZona3D.SONDA_ALTO > 0.0)


# ---------------------------------------------------------------------------------------------------------------------
#  Comunes
# ---------------------------------------------------------------------------------------------------------------------

func _render() -> AguaRender3D:
	return maqueta.get("_agua_render") as AguaRender3D


func _sombreado(et: String) -> void:
	var r: AguaRender3D = _render()
	_ok("%s1 hay AguaRender3D con material" % et, r != null and r.material_agua() != null)
	if r == null or r.material_agua() == null:
		return
	var m: ShaderMaterial = r.material_agua()
	r.agua_filtro = false      # 22/10 (agua filtro): el filtro (por defecto encendido) tiene su prueba (prueba_agua_filtro.gd); aquí se mide la refracción y las olas como eran
	var cod: String = m.shader.code
	_ok("%s2 el shader lee la pantalla y la profundidad de la escena" % et, cod.contains("hint_screen_texture") and cod.contains("hint_depth_texture"))
	_ok("%s3 el shader declara la tercera escala (ola3_altura, ola3_k, ola3_vel, ola3_dir, ola3_dir2)" % et,
		cod.contains("uniform float ola3_altura") and cod.contains("uniform float ola3_k") and cod.contains("uniform float ola3_vel") and cod.contains("uniform vec2 ola3_dir"))
	_ok("%s4 refracción encendida de serie: uniform = 1 y el agua pasa primera (prioridad %d)" % [et, AguaRender3D.AGUA_PRIORIDAD],
		is_equal_approx(float(m.get_shader_parameter("refraccion")), 1.0) and m.render_priority == AguaRender3D.AGUA_PRIORIDAD)
	_ok("%s5 las constantes llegan al shader" % et,
		is_equal_approx(float(m.get_shader_parameter("refr_fuerza")), AguaRender3D.REFR_FUERZA)
		and is_equal_approx(float(m.get_shader_parameter("refr_prof_tope")), AguaRender3D.REFR_PROF_TOPE)
		and is_equal_approx(float(m.get_shader_parameter("refr_orilla")), AguaRender3D.REFR_ORILLA)
		and is_equal_approx(float(m.get_shader_parameter("refr_margen")), AguaRender3D.REFR_MARGEN)
		and is_equal_approx(float(m.get_shader_parameter("refr_borde")), AguaRender3D.REFR_BORDE))
	_ok("%s6 tercera escala: altura %.2f, longitud %.1f u, velocidad %.2f, dos rumbos distintos" % [et, AguaRender3D.OLA3_ALTURA, AguaRender3D.OLA3_LONGITUD, AguaRender3D.OLA3_VEL],
		is_equal_approx(float(m.get_shader_parameter("ola3_altura")), AguaRender3D.OLA3_ALTURA)
		and is_equal_approx(float(m.get_shader_parameter("ola3_k")), TAU / AguaRender3D.OLA3_LONGITUD)
		and is_equal_approx(float(m.get_shader_parameter("ola3_vel")), AguaRender3D.OLA3_VEL)
		and not (m.get_shader_parameter("ola3_dir") as Vector2).is_equal_approx(m.get_shader_parameter("ola3_dir2") as Vector2))
	var pared: ShaderMaterial = r.get("_mat_pared") as ShaderMaterial
	_ok("%s7 las paredes van justo detrás del agua (prioridad %d)" % [et, AguaRender3D.PARED_PRIORIDAD], pared != null and pared.render_priority == AguaRender3D.PARED_PRIORIDAD)
	# Interruptores.
	r.agua_refraccion = false
	_ok("%s8 agua_refraccion = false: uniform 0 y prioridad de siempre (0)" % et, is_equal_approx(float(m.get_shader_parameter("refraccion")), 0.0) and m.render_priority == 0
		and (pared == null or pared.render_priority == 0))
	r.agua_refraccion = true
	_ok("%s9 …y vuelve a encenderse" % et, is_equal_approx(float(m.get_shader_parameter("refraccion")), 1.0) and m.render_priority == AguaRender3D.AGUA_PRIORIDAD)
	r.olas_tercera_escala = false
	_ok("%s10 olas_tercera_escala = false: amplitud 0 (las olas de antes) y la refracción sigue" % et, is_equal_approx(float(m.get_shader_parameter("ola3_altura")), 0.0)
		and is_equal_approx(float(m.get_shader_parameter("refraccion")), 1.0))
	r.olas_tercera_escala = true
	_ok("%s11 …y vuelve" % et, is_equal_approx(float(m.get_shader_parameter("ola3_altura")), AguaRender3D.OLA3_ALTURA))
	_ok("%s12 la maqueta lleva los interruptores agua_refraccion / agua_olas_tercera / sondas_por_sala" % et,
		maqueta.get("agua_refraccion") == true and maqueta.get("agua_olas_tercera") == true and maqueta.get("sondas_por_sala") == true)
	r.agua_filtro = true


func _impacto(et: String) -> void:
	var r: AguaRender3D = _render()
	var m: ShaderMaterial = r.material_agua()
	var mapa: PackedStringArray = maqueta.get("_mapa")
	var celda := Vector2i(-1, -1)
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			if mapa[y][x] == "~" and (celda.x < 0 or Vector2(x, y).distance_to(Vector2(Terreno3D.celda_de(jugador.position))) < Vector2(celda).distance_to(Vector2(Terreno3D.celda_de(jugador.position)))):
				celda = Vector2i(x, y)   # la más cercana al jugador: la zona de ondas lo sigue
	_ok("%s1 hay una casilla de agua donde dar un impacto" % et, celda.x >= 0)
	if celda.x < 0:
		return
	var o: AguaOndas3D = maqueta.call("_asegurar_ondas") as AguaOndas3D
	_ok("%s2 las ondas de AguaOndas3D están montadas" % et, o != null)
	if o == null:
		return
	var pos: Vector3 = Terreno3D.centro_de(celda, 0.5)
	o.impulso(pos, 0.05, 0.6)
	var en_cola: int = (o.get("_cola") as Array).size()
	await avanzar(20)
	_ok("%s2b el impacto entra en la cola de AguaOndas3D (%d) y se consume en los pasos (%d)" % [et, en_cola, (o.get("_cola") as Array).size()], en_cola >= 1 and (o.get("_cola") as Array).is_empty())
	_ok("%s3 el impacto llega al shader (ondas_fuerza %.2f, textura de ondas puesta)" % [et, float(m.get_shader_parameter("ondas_fuerza"))],
		float(m.get_shader_parameter("ondas_fuerza")) > 0.0 and m.get_shader_parameter("ondas") == o.textura() and m.get_shader_parameter("ondas") != null)



# ---------------------------------------------------------------------------------------------------------------------
#  B · laboratorio de 7 salas
# ---------------------------------------------------------------------------------------------------------------------

func _tiene_agua(r: Rect2i) -> bool:
	var mapa: PackedStringArray = maqueta.get("_mapa")
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if y < mapa.size() and x < mapa[y].length() and (mapa[y][x] == "~" or mapa[y][x] == "b" or mapa[y][x] == "c"):
				return true
	return false


func _lab() -> void:
	print("== B · laboratorio de 7 salas ==")
	_sombreado("B")
	var lab: Node = maqueta.get_node_or_null("Reglas")
	var salas: Array = lab.call("salas_rects") if lab != null and lab.has_method("salas_rects") else []
	_ok("B20 el laboratorio ofrece sus 7 salas (salas_rects)", salas.size() == 7, "%d" % salas.size())
	var con_agua: Array = []
	var sin_agua: Array = []
	for r in salas:
		(con_agua if _tiene_agua(r as Rect2i) else sin_agua).append(r)
	var sondas: Array = maqueta.call("sondas_montadas")
	_ok("B21 una sonda por sala CON agua (%d de %d salas), ni una más" % [con_agua.size(), salas.size()], sondas.size() == con_agua.size() and con_agua.size() > 0,
		"sondas %d · salas con agua %d · sin agua %d" % [sondas.size(), con_agua.size(), sin_agua.size()])
	var cada_una: bool = true
	var todas_ok: bool = true
	for s in sondas:
		var p: ReflectionProbe = s
		todas_ok = todas_ok and p.update_mode == ReflectionProbe.UPDATE_ONCE and p.box_projection and p.ambient_mode == ReflectionProbe.AMBIENT_DISABLED and p.is_inside_tree()
		var cx: float = p.global_position.x / 2.3
		var cz: float = p.global_position.z / 2.3
		var en_sala: bool = false
		for r in con_agua:
			var rr: Rect2i = r
			if rr.has_point(Vector2i(int(floor(cx)), int(floor(cz)))) and p.size.x <= float(rr.size.x) * 2.3 + 0.01 and p.size.z <= float(rr.size.y) * 2.3 + 0.01:
				en_sala = true
		cada_una = cada_una and en_sala
	_ok("B22 cada sonda está dentro de una sala con agua y su caja no es mayor que la sala", cada_una)
	_ok("B23 todas: se hornean una vez, proyectan sobre su caja y solo aportan reflejos", todas_ok)
	var ningun: bool = true
	for r in sin_agua:
		for s in sondas:
			var p: ReflectionProbe = s
			var rr: Rect2i = r
			var caja := Rect2(Vector2(p.global_position.x - p.size.x * 0.5, p.global_position.z - p.size.z * 0.5), Vector2(p.size.x, p.size.z))
			if caja.intersects(Rect2(Vector2(rr.position) * 2.3, Vector2(rr.size) * 2.3)):
				ningun = false
	_ok("B24 ninguna caja entra en una sala SIN agua ni hielo (%d salas)" % sin_agua.size(), ningun)
	var cajas: Array = maqueta.call("cajas_sondas")
	_ok("B25 cajas_sondas() de la maqueta coincide con las sondas montadas", cajas.size() == sondas.size())
	# Hielo: la sala 2 tiene franja helada al empezar (agua helada = agua): su sonda existe.
	var s2: Rect2i = salas[1]
	var hay2: bool = false
	for s in sondas:
		var p2: ReflectionProbe = s
		if s2.has_point(Vector2i(int(floor(p2.global_position.x / 2.3)), int(floor(p2.global_position.z / 2.3)))):
			hay2 = true
	_ok("B26 la sala 2 (charca con la franja helada) tiene su sonda", hay2)
	# Interruptores de la sonda.
	maqueta.set("sondas_por_sala", false)
	maqueta.call("_montar_sonda")
	await avanzar(3)
	var una: Array = maqueta.call("sondas_montadas")
	var lado: int = int(maqueta.get("_lado"))
	_ok("B27 sondas_por_sala = false: una sonda para todo el mapa, como antes", una.size() == 1 and absf((una[0] as ReflectionProbe).size.x - float(lado) * 2.3) < 0.01)
	maqueta.set("sondas_por_sala", true)
	maqueta.set("sonda_reflejos", false)
	maqueta.call("_montar_sonda")
	await avanzar(3)
	_ok("B28 sonda_reflejos = false: ninguna sonda", (maqueta.call("sondas_montadas") as Array).is_empty())
	maqueta.set("sonda_reflejos", true)
	maqueta.call("_montar_sonda")
	await avanzar(3)
	_ok("B29 …y al volver a encenderla, otra vez una por sala con agua", (maqueta.call("sondas_montadas") as Array).size() == con_agua.size())
	await _impacto("B3")


# ---------------------------------------------------------------------------------------------------------------------
#  C · Bosque 01
# ---------------------------------------------------------------------------------------------------------------------

func _bosque() -> void:
	print("== C · Bosque 01 ==")
	_sombreado("C")
	var sondas: Array = maqueta.call("sondas_montadas")
	var cajas: Array = maqueta.call("cajas_sondas")
	_ok("C20 el Bosque no tiene salas: sondas por bloques de %d casillas, solo con agua (%d)" % [LuzZona3D.SONDA_BLOQUE, sondas.size()], sondas.size() > 1 and sondas.size() == cajas.size(),
		"%d sondas" % sondas.size())
	var mapa: PackedStringArray = maqueta.get("_mapa")
	var sin_cubrir: int = 0
	var total: int = 0
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			if mapa[y][x] == "~" or mapa[y][x] == "b" or mapa[y][x] == "c":
				total += 1
				var c := Vector2i(x, y)
				var cubierta: bool = false
				for r in cajas:
					if (r as Rect2i).has_point(c):
						cubierta = true
				if not cubierta:
					sin_cubrir += 1
	_ok("C21 todo el agua del mapa (%d casillas) queda dentro de alguna caja" % total, total > 0 and sin_cubrir == 0, "sin cubrir %d" % sin_cubrir)
	var todas_con_agua: bool = true
	for r in cajas:
		var tiene: bool = false
		for y in range((r as Rect2i).position.y, (r as Rect2i).end.y):
			for x in range((r as Rect2i).position.x, (r as Rect2i).end.x):
				if y < mapa.size() and x < mapa[y].length() and (mapa[y][x] == "~" or mapa[y][x] == "b" or mapa[y][x] == "c"):
					tiene = true
		todas_con_agua = todas_con_agua and tiene
	_ok("C22 ninguna caja está vacía de agua", todas_con_agua)
	var area_cajas: float = 0.0
	for r in cajas:
		area_cajas += float((r as Rect2i).size.x * (r as Rect2i).size.y)
	var lado: int = int(maqueta.get("_lado"))
	_ok("C23 las cajas suman %.0f casillas de las %d del mapa (ajustadas al agua)" % [area_cajas, lado * lado], area_cajas < 0.9 * float(lado * lado))
	var r: AguaRender3D = _render()
	var m: ShaderMaterial = r.material_agua()
	await avanzar(10)
	_ok("C24 el flow map sigue vivo con la tercera escala (flujo_activo %.0f, textura de flujo puesta)" % float(m.get_shader_parameter("flujo_activo")),
		float(m.get_shader_parameter("flujo_activo")) > 0.5 and m.get_shader_parameter("flujo") != null)
	await _impacto("C3")
