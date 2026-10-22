extends SceneTree
## PRUEBA del «material de juguete» de los personajes (docs/PLAN_EOW_VISUAL.md §1 punto 5). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_personaje_juguete.gd
## Estructura (shader en las superficies opacas, tinte de Combate3D llegando al shader, rim/silueta encadenados, modo_luz 0, interruptor).
## Cómo se VE se mira en docs/capturas/personaje_juguete/ (herramientas/captura_personaje_juguete.gd).
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
	print("RESULTADO personaje_juguete · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _pj(id: String) -> Pj3D:
	var p := Pj3D.new()
	_mundo.add_child(p)
	p.cargar(id)
	p.set_alto(1.2)
	return p


## [superficies con ShaderMaterial de juguete, superficies opacas con StandardMaterial3D, superficies con alfa].
func _cuenta(p: Pj3D) -> Array:
	var sh: int = 0
	var std_opaca: int = 0
	var alfa: int = 0
	for n in p._modelo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		for s in range(mi.mesh.get_surface_count()):
			var o: Material = mi.get_surface_override_material(s)
			if o is ShaderMaterial and (o as ShaderMaterial).shader.code.contains("diffuse_lambert"):
				sh += 1
			elif o is StandardMaterial3D:
				if (o as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
					std_opaca += 1
				else:
					alfa += 1
	return [sh, std_opaca, alfa]


func _rim_en_shader(p: Pj3D) -> bool:
	for e in p._juguete:
		var sm: ShaderMaterial = e[1]
		if p._rim_mat != null and sm.next_pass != p._rim_mat:
			return false
	return not p._juguete.is_empty()


func _correr() -> void:
	Pj3D.material_juguete = true
	# 1 · jugadora, NPC y goblin: todas las superficies opacas con el shader de juguete
	var jug: Pj3D = _pj("woodland_wanderer")
	var c: Array = _cuenta(jug)
	_ok(c[0] > 0 and c[1] == 0, "jugadora: %d superficies de juguete, 0 opacas con PBR (alfa: %d)" % [c[0], c[2]])
	_ok(c[0] == jug._juguete.size(), "jugadora: una entrada de sincronización por superficie de juguete")
	_ok(_rim_en_shader(jug), "jugadora: el rim está encadenado al shader de juguete")
	_ok(jug._rim_mat != null and jug._rim_mat.next_pass is ShaderMaterial and \
		(jug._rim_mat.next_pass as ShaderMaterial).shader.code == MaterialPersonaje3D.CODIGO_SILUETA, "jugadora: la silueta sigue tras el rim")
	_ok(jug._sombra != null and jug._sombra.visible, "jugadora: sombra de contacto")
	var sh0: ShaderMaterial = jug._juguete[0][1]
	_ok(sh0.get_shader_parameter("matcap") is ImageTexture, "el shader lleva la textura matcap procedural")
	_ok(float(sh0.get_shader_parameter("matcap_intensidad")) == MaterialPersonaje3D.MATCAP_INTENSIDAD, "matcap a la intensidad de la constante")
	_ok(jug.is_processing(), "Pj3D procesa cada fotograma (sincroniza el tinte)")

	var npc: Pj3D = _pj("bookseller_chibi")
	var cn: Array = _cuenta(npc)
	_ok(cn[0] > 0 and cn[1] == 0, "NPC (librera): %d superficies de juguete, 0 opacas con PBR" % cn[0])
	_ok(npc._rim_mat != null and npc._rim_mat.next_pass == null, "NPC: rim sin silueta")

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
	var cg: Array = _cuenta(modelo)
	_ok(cg[0] > 0 and cg[1] == 0, "goblin: %d superficies de juguete, 0 opacas con PBR" % cg[0])
	_ok(modelo.rol_visual == "enemigo" and _rim_en_shader(modelo), "goblin: rol enemigo y rim encadenado")

	# 2 · el tinte de Combate3D llega al shader (quemado, congelado, destello, vuelta a base)
	var s0: ShaderMaterial = modelo._juguete[0][1]
	var base: Color = g._bases[0]
	var esperado0: Color = Color(base.r * g.tinte.r, base.g * g.tinte.g, base.b * g.tinte.b, base.a)
	g._dibujar_estado(0.016)
	modelo.sincronizar_juguete()
	_ok((s0.get_shader_parameter("albedo_color") as Color).is_equal_approx(esperado0), "sin estados el albedo del shader es base × tinte")
	g.quemando = 2.0
	g._dibujar_estado(0.016)
	modelo.sincronizar_juguete()
	var q: Color = s0.get_shader_parameter("albedo_color")
	_ok(not q.is_equal_approx(esperado0) and q.r > q.b, "quemado: el albedo del shader vira (cálido)")
	g.quemando = 0.0
	g.congelado = 2.0
	g._dibujar_estado(0.016)
	modelo.sincronizar_juguete()
	var f: Color = s0.get_shader_parameter("albedo_color")
	_ok(f.b / maxf(f.r, 0.001) > esperado0.b / maxf(esperado0.r, 0.001), "congelado: el albedo del shader vira al azul")
	g.congelado = 0.0
	g._destello = 0.2
	g._dibujar_estado(0.016)
	modelo.sincronizar_juguete()
	_ok((s0.get_shader_parameter("albedo_color") as Color).is_equal_approx(Color.BLACK) and float(s0.get_shader_parameter("emision_energia")) > 0.0,
		"destello: albedo negro + emisión en el shader")
	g._destello = 0.0
	g._dibujar_estado(0.016)
	modelo.sincronizar_juguete()
	_ok((s0.get_shader_parameter("albedo_color") as Color).is_equal_approx(esperado0) and float(s0.get_shader_parameter("emision_energia")) == 0.0,
		"tras el destello vuelve a base y la emisión se apaga")
	# y por el _process real, sin llamar a sincronizar a mano
	g.quemando = 2.0
	g._dibujar_estado(0.016)
	await process_frame
	await process_frame
	_ok(not (s0.get_shader_parameter("albedo_color") as Color).is_equal_approx(esperado0), "el _process de Pj3D lleva el tinte al shader sin ayuda")
	g.quemando = 0.0
	g._dibujar_estado(0.016)

	# 3 · modo_luz 0 = plano
	modelo.set_modo_luz(0)
	_ok(float(s0.get_shader_parameter("plano")) == 1.0 and float(s0.get_shader_parameter("emision_energia")) == 0.0, "modo_luz 0: shader en modo plano")
	_ok(float(modelo._rim_mat.get_shader_parameter("intensidad")) == 0.0, "modo_luz 0 apaga el rim")
	modelo.set_modo_luz(1)
	_ok(float(s0.get_shader_parameter("plano")) == 0.0, "modo_luz 1 vuelve a la luz con rampa")

	# 4 · sombra tintada configurable
	jug.set_sombra_juguete(Color(0.9, 0.7, 0.6))
	var sc: Vector3 = (jug._juguete[0][1] as ShaderMaterial).get_shader_parameter("sombra_color")
	_ok(sc.x > sc.z, "set_sombra_juguete cambia el color de la sombra")

	# 5 · interruptor
	Pj3D.material_juguete = false
	var viejo: Pj3D = _pj("woodland_wanderer")
	var cv: Array = _cuenta(viejo)
	_ok(cv[0] == 0 and viejo._juguete.is_empty(), "material_juguete = false: todo StandardMaterial3D como antes (%d opacas)" % cv[1])
	_ok(absf(viejo._materiales[0].roughness - Pj3D.ROUGHNESS_JUGUETE) < 0.001, "…con la rugosidad de V5")
	Pj3D.material_juguete = true
