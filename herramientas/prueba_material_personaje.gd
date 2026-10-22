extends SceneTree
## PRUEBA DE V5 «personajes juguete» (docs/PLAN_EOW_VISUAL.md): rim de color, silueta a través de paredes y sombra de contacto en `Pj3D`. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_material_personaje.gd
## Lo que NO se puede comprobar sin ventana es cómo se VE (el fresnel y el descarte por profundidad de la silueta necesitan GPU): eso se mira en
## docs/capturas/v5/ con herramientas/captura_personajes_v5.gd. Aquí se comprueba la estructura y que no se rompe nada de lo de siempre.
class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _goblins: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

var _fallos: int = 0
var _mundo: MundoFalso = null


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK    ", m)
	else:
		_fallos += 1
		print("FALLO ", m)


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	_mundo = MundoFalso.new()
	_mundo._mapa = filas
	root.add_child(_mundo)
	Lanzador3D.configurar(_mundo)
	for y in range(20):
		for x in range(20):
			if filas[y][x] == "#":
				_mundo._bloqueadas[Vector2i(x, y)] = true
	await _correr()
	print("RESULTADO material_personaje · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _pj(id: String) -> Pj3D:
	var p := Pj3D.new()
	_mundo.add_child(p)
	p.cargar(id)
	p.set_alto(1.2)
	return p


## Cuántas superficies tienen el rim encadenado y si la silueta cuelga del rim.
func _rim_en(p: Pj3D) -> Array:
	var con: int = 0
	var total: int = 0
	for m in p._materiales:
		total += 1
		if m.next_pass is ShaderMaterial and (m.next_pass as ShaderMaterial).shader.code == MaterialPersonaje3D.CODIGO_RIM:
			con += 1
	return [con, total]


func _tiene_silueta(p: Pj3D) -> bool:
	return p._rim_mat != null and p._rim_mat.next_pass is ShaderMaterial and \
		(p._rim_mat.next_pass as ShaderMaterial).shader.code == MaterialPersonaje3D.CODIGO_SILUETA


func _correr() -> void:
	# 0 · el rim es una ARISTA, no un velo (22/10: con potencia 3,0 cubría casi media superficie y dejaba pálida a la jugadora en zonas oscuras).
	# Con cámara ortogonal N·V es uniforme en el hemisferio visto: la fracción de superficie con rim visible es 1 − umbral^(1/potencia)... (c < 1 − (u/i)^(1/p)).
	var u: float = Pj3D.RIM_UMBRAL_VISIBLE / Pj3D.RIM_INTENSIDAD
	var cobertura: float = 1.0 - pow(u, 1.0 / Pj3D.RIM_POTENCIA)
	_ok(cobertura <= Pj3D.RIM_COBERTURA_MAX, "el rim visible cubre ≤ %.0f %% de la superficie (cubre %.0f %%)" % [Pj3D.RIM_COBERTURA_MAX * 100.0, cobertura * 100.0])
	# 1 · la jugadora: rim cálido, silueta, sombra
	var jug: Pj3D = _pj("woodland_wanderer")
	var r: Array = _rim_en(jug)
	_ok(jug.rol_visual == "jugadora", "la elfa tiene rol «jugadora»")
	_ok(r[1] > 0 and r[0] == r[1], "todas las superficies opacas de la elfa tienen rim (%d de %d)" % [r[0], r[1]])
	_ok(_tiene_silueta(jug), "la elfa lleva la silueta encadenada tras el rim")
	_ok(jug._sombra != null and jug._sombra.name == "sombra_contacto" and jug._sombra.visible, "la elfa tiene sombra de contacto visible")
	var c: Vector3 = jug._rim_mat.get_shader_parameter("color")
	_ok(c.x > c.z, "el rim de la elfa es cálido (rojo > azul)")
	_ok(jug._materiales[0].metallic == 0.0 and absf(jug._materiales[0].roughness - Pj3D.ROUGHNESS_JUGUETE) < 0.001, "metalness 0 y rugosidad media-alta")
	_ok(float(jug._sil_mat.get_shader_parameter("sesgo")) > 0.1, "el sesgo de la silueta sigue a la altura (%.2f)" % float(jug._sil_mat.get_shader_parameter("sesgo")))

	# 2 · NPC: rim, sin silueta
	var npc: Pj3D = _pj("bookseller_chibi")
	if npc._modelo != null:
		var rn: Array = _rim_en(npc)
		_ok(npc.rol_visual == "npc" and rn[0] == rn[1] and rn[1] > 0, "el NPC tiene rol «npc» y rim en todas sus superficies")
		_ok(not _tiene_silueta(npc), "el NPC no lleva silueta")
		_ok(npc._sombra != null, "el NPC tiene sombra de contacto")

	# 3 · enemigos: rol «enemigo», rim del color de su debilidad, sombra que se apaga al morir
	var j := Jugador3D.new()
	j.position = Vector3(18 * 2.3, 1.0, 18 * 2.3)
	var modelo: Pj3D = Pj3D.new()
	modelo.position = Vector3(10 * 2.3, 2.3 * 0.45, 10 * 2.3)
	_mundo.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.set_alto(0.85)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, j, null)
	g.set_physics_process(false)
	g.altura = 0.85
	g.oro = 0
	await process_frame
	var re: Array = _rim_en(modelo)
	_ok(modelo.rol_visual == "enemigo", "el goblin pasa a rol «enemigo» al equiparse")
	_ok(re[1] > 0 and re[0] == re[1], "el goblin tiene rim en todas sus superficies (%d de %d)" % [re[0], re[1]])
	_ok(not _tiene_silueta(modelo), "el goblin NO lleva silueta (constante silueta_enemigos apagada)")
	var ce: Vector3 = modelo._rim_mat.get_shader_parameter("color")
	_ok(ce.z > ce.x, "el rim del goblin (debilidad: agua) es frío (azul > rojo)")
	_ok(modelo._sombra != null and modelo._sombra.visible, "el goblin tiene sombra de contacto visible")

	# 4 · tinte de estado: quemado y congelado siguen cambiando el albedo; el rim sigue puesto
	var base: Color = g._bases[0]
	g.quemando = 2.0
	g._dibujar_estado(0.016)
	var mat0: StandardMaterial3D = g._materiales[0]
	_ok(not mat0.albedo_color.is_equal_approx(base), "quemando cambia el albedo del material")
	_ok(mat0.next_pass == modelo._rim_mat, "…y el rim sigue encadenado")
	g.quemando = 0.0
	g.congelado = 2.0
	g._dibujar_estado(0.016)
	_ok(mat0.albedo_color.b / maxf(mat0.albedo_color.r, 0.001) > base.b / maxf(base.r, 0.001), "congelado vira el albedo hacia el azul")
	g.congelado = 0.0
	g._dibujar_estado(0.016)
	var esperado: Color = Color(base.r * g.tinte.r, base.g * g.tinte.g, base.b * g.tinte.b, base.a)   # el tinte propio del enemigo (p. ej. el goblin verdoso)
	_ok(mat0.albedo_color.is_equal_approx(esperado), "sin estados el albedo vuelve a base × tinte del enemigo")
	g._destello = 0.2
	g._dibujar_estado(0.016)
	_ok(mat0.albedo_color.is_equal_approx(Color.BLACK) and mat0.emission_enabled, "el destello de golpe (albedo negro + emisión) sigue funcionando")
	g._destello = 0.0
	g._dibujar_estado(0.016)

	# 5 · modo de luz plana: UNSHADED sigue igual y el rim se apaga
	modelo.set_modo_luz(0)
	_ok(mat0.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "modo_luz 0 sigue siendo UNSHADED")
	_ok(float(modelo._rim_mat.get_shader_parameter("intensidad")) == 0.0, "modo_luz 0 apaga el rim")
	modelo.set_modo_luz(1)
	# 21/10 (Pablo): el rim solo lo lleva la jugadora; el goblin vuelve a luz por píxel con el rim a 0 (y con el interruptor apagado, lo recupera).
	_ok(mat0.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and float(modelo._rim_mat.get_shader_parameter("intensidad")) == 0.0,
		"modo_luz 1 vuelve a luz por píxel; el goblin sin rim (rim_solo_jugadora)")
	Pj3D.rim_solo_jugadora = false
	modelo.set_modo_luz(1)
	_ok(float(modelo._rim_mat.get_shader_parameter("intensidad")) > 0.0, "con rim_solo_jugadora = false el goblin recupera el rim")
	Pj3D.rim_solo_jugadora = true
	modelo.set_modo_luz(1)

	# 6 · muerte: la sombra desaparece
	g._morir()
	_ok(not modelo._sombra.visible, "al morir la sombra de contacto se apaga")
	var g2: Combate3D = null
	var m2: Pj3D = Pj3D.new()
	m2.position = Vector3(12 * 2.3, 1.0, 12 * 2.3)
	_mundo.add_child(m2)
	m2.cargar("goblin_archer_chibi")
	g2 = Combate3D.equipar(m2, _mundo, j, null)
	g2.set_physics_process(false)
	g2.oro = 0
	await process_frame
	g2._morir(true)
	_ok(not m2._sombra.visible, "al hundirse (ahogado) la sombra también se apaga")

	# 7 · cada cosa se apaga con su interruptor
	Pj3D.rim_activo = false
	Pj3D.sombra_contacto_activa = false
	Pj3D.silueta_activa = false
	Pj3D.pbr_juguete_activo = false
	var vacio: Pj3D = _pj("woodland_wanderer")
	_ok(vacio._rim_mat == null and _rim_en(vacio)[0] == 0, "rim_activo = false: sin rim en ninguna superficie")
	_ok(vacio._sombra == null, "sombra_contacto_activa = false: sin sombra")
	_ok(absf(vacio._materiales[0].roughness - 1.0) < 0.001, "pbr_juguete_activo = false: rugosidad 1,0 como antes")
	Pj3D.rim_activo = true
	var sin_sil: Pj3D = _pj("woodland_wanderer")
	_ok(not _tiene_silueta(sin_sil) and _rim_en(sin_sil)[0] > 0, "silueta_activa = false: rim sí, silueta no")
	Pj3D.sombra_contacto_activa = true
	Pj3D.silueta_activa = true
	Pj3D.pbr_juguete_activo = true

