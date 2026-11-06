extends SceneTree

## PRUEBA del magma «toy» (6/11/2026; a imagen de prueba_rayo_toy.gd). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_magma_toy.gd
## Comprueba, con MagmaToy e ImpactoMagmaToy:
##   1. RECURSOS: las piedras de magma cargan (malla de verdad, no la esfera de relleno), las texturas existen y el material de roca lleva albedo + grietas emisivas
##   2. FIGURAS: BOLA, MURO, PILAR, BARRERA y HAZ se construyen sin fallar; la bola es una roca (MeshInstance con magma_roca.gdshader) del tamaño de los semiejes; las de volumen llevan un FuegoToy
##      hijo del mismo tamaño y piedras en la base (salvo el haz); `desde_hechizo` da la misma figura que el fuego
##   3. CARGA: nace pequeña y GRIS (calor 0), el calor SUBE con la carga hasta 1 y la escala crece sin bajar; `soltar` la deja a calor 1 y en vuelo; cancelar la libera
##   4. RUEDA: al desplazarse en vuelo, el pivote de la roca gira (giro acumulado = distancia / radio) y deja brasas que caen
##   5. IMPACTOS: GOLPE crea 6-10 esquirlas con calor que baja a 0 en ~1 s, se alejan del punto y caen; cráter (grietas) cuyo calor pasa de 1 a 0 en 2 s y se desvanece a los 3 s; pétalos;
##      REBOTE sin cráter y la bola sigue; FIN: la roca se enfría a gris y cae; AREA: cráter grande. Todo se libera solo
##   6. API: impactar_en / rebotar / terminar_sin_choque / finalizar / impactar; describir = el del fuego
##   7. LAB: Z llega al magma y G / B / N / M / R / P / F7 / F9 crean MagmaToy / ImpactoMagmaToy
##   8. Sin errores del motor en todo el ciclo (Logger)
## Imprime FALLOS: n.

const RUTAS: PackedStringArray = ["res://presentacion/vfx/toy/magma_roca.gdshader", "res://presentacion/vfx/toy/grietas_magma.gdshader",
	"res://arte/meshy/piezas/tex_rocas_est/rocas_magma_albedo.png", "res://arte/meshy/piezas/tex_rocas_est/rocas_magma_emisivo.png"]
const FIGURAS: Array = [["BOLA", 0, Vector3(0.4, 0.4, 0.4)], ["MURO", 1, Vector3(3.45, 1.5, 0.3)], ["PILAR", 2, Vector3(0.5, 4.0, 0.5)], ["BARRERA", 3, Vector3(1.5, 1.5, 1.5)], ["HAZ", 4, Vector3(1.5, 0.5, 0.15)]]

var _fallos: int = 0
var _raiz: Node3D = null
var _errores: int = 0


class Contador extends Logger:
	var n: int = 0
	var textos: PackedStringArray = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		n += 1
		if textos.size() < 8:
			textos.append(code + " | " + rationale)


var _log: Contador = Contador.new()


func _initialize() -> void:
	OS.add_logger(_log)
	_correr()


func _ok(nombre: String, cond: bool, detalle: String = "") -> void:
	if cond:
		print("  OK   " + nombre)
	else:
		_fallos += 1
		print("  FALLO " + nombre + ("  (" + detalle + ")" if detalle != "" else ""))


func _correr() -> void:
	await process_frame
	_raiz = Node3D.new()
	root.add_child(_raiz)
	_recursos()
	await _figuras()
	await _carga()
	await _rueda()
	await _impactos()
	await _api()
	await _lab()
	await _esperar(0.2)
	_ok("sin errores del motor en todo el ciclo (%d)" % _log.n, _log.n == 0, str(_log.textos))
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _esperar(seg: float) -> void:
	var n: int = int(ceil(seg * 30.0))
	for i in n:
		await process_frame


func _nueva() -> MagmaToy:
	var e: MagmaToy = MagmaToy.new()
	_raiz.add_child(e)
	return e


func _escala(e: MagmaToy) -> float:
	return (e.get_node("Cuerpo") as Node3D).scale.x


func _recursos() -> void:
	print("== recursos")
	for r in RUTAS:
		_ok("existe " + r, ResourceLoader.exists(r))
	var m: Mesh = ImpactoMagmaToy.malla_piedra(2)
	_ok("piedra_est_magma_2 (esquirlas y pétalos) carga como malla de verdad (no la esfera de relleno)", m != null and not (m is SphereMesh) and m.get_aabb().size.length() > 0.5)
	var mb: ArrayMesh = ImpactoMagmaToy.malla_bola()
	_ok("la bola es la esfera facetada (caras planas, sin índices, UV en el atlas)", mb.get_surface_count() == 1 and mb.surface_get_array_len(0) >= 300 and mb.surface_get_array_index_len(0) == 0 and absf(mb.get_aabb().size.x - 1.0) < 0.25)
	var mat: ShaderMaterial = ImpactoMagmaToy.material_roca(false)
	_ok("el material de roca lleva albedo y grietas emisivas y el shader magma_roca", mat.get_shader_parameter("albedo_tex") is Texture2D and mat.get_shader_parameter("emisivo_tex") is Texture2D and mat.shader.resource_path.ends_with("magma_roca.gdshader"))
	_ok("el shader de la roca es con sombreado (una roca, no una llama aditiva) y usa `calor`", mat.shader.code.find("blend_add") < 0 and mat.shader.code.find("uniform float calor") >= 0)


func _figuras() -> void:
	print("== figuras")
	for f in FIGURAS:
		var e: MagmaToy = _nueva()
		var s: Vector3 = f[2]
		e.definir(int(f[1]), s.x, s.y, s.z, false)
		await process_frame
		await process_frame
		var roca: MeshInstance3D = e.get_node_or_null("Cuerpo/Giro/Roca") as MeshInstance3D
		var fuego: FuegoToy = e.get_node_or_null("Cuerpo/Fuego") as FuegoToy
		var piedras: int = 0
		for h in (e.get_node("Cuerpo") as Node3D).get_children():
			if String(h.name).begins_with("Piedra"):
				piedras += 1
		if int(f[1]) == 0:
			_ok("%s: una roca con magma_roca.gdshader y sin FuegoToy" % f[0], roca != null and (roca.material_override as ShaderMaterial).shader.resource_path.ends_with("magma_roca.gdshader") and fuego == null)
			if roca != null:
				var aabb: AABB = roca.mesh.get_aabb()
				var ancho: float = maxf(aabb.size.x * roca.scale.x, aabb.size.z * roca.scale.z)
				_ok("%s: la roca mide el diámetro de los semiejes (%.2f ≈ 0,8)" % [f[0], ancho], absf(ancho - 0.8) < 0.05)
			_ok("%s: lleva una luz tenue de color magma" % f[0], e.get_node_or_null("Luz") is OmniLight3D and (e.get_node("Luz") as OmniLight3D).light_energy <= 1.0)
		else:
			_ok("%s: un FuegoToy hijo de la misma figura y tamaño" % f[0], fuego != null and int(fuego.figura) == int(f[1]) and absf(fuego.semieje_x - s.x) < 0.001 and absf(fuego.semieje_y - s.y) < 0.001)
			_ok("%s: piedras de magma en la base (%d)" % [f[0], piedras], (piedras >= 3) if int(f[1]) != 4 else piedras == 0)
			_ok("%s: sin luz propia (la del FuegoToy)" % f[0], e.get_node_or_null("Luz") == null)
		_ok("%s: extensión = la del fuego" % f[0], absf(e.extension() - FuegoToy._extension(int(f[1]) as FuegoToy.Figura, s.x, s.y, s.z)) < 0.001)
		e.lanzar(0.6)
		await _esperar(0.3)
		_ok("%s: nace (aparicion > 0,9 a los 0,3 s)" % f[0], e.aparicion > 0.9, "%.2f" % e.aparicion)
		await _esperar(0.8)
		_ok("%s: con vida 0,6 s se libera sola" % f[0], not is_instance_valid(e))
	# desde_hechizo = el del fuego
	var h: Hechizo = Hechizo.new()
	h.semieje_x = 1.5
	h.semieje_y = 0.3
	h.semieje_z = 0.13
	var e2: MagmaToy = _nueva()
	e2.desde_hechizo(h)
	await process_frame
	var d: Dictionary = FuegoToy.describir(h)
	_ok("desde_hechizo: figura y ejes = FuegoToy.describir (muro)", int(e2.figura) == int(d["figura"]) and absf(e2.semieje_x - float(d["x"])) < 0.001 and int(e2.figura) == 1)
	var h2: Hechizo = Hechizo.new()
	h2.semieje_x = 0.3
	h2.semieje_y = 0.3
	h2.semieje_z = 0.3
	h2.velocidad = 8.0
	var e3: MagmaToy = _nueva()
	e3.desde_hechizo(h2)
	await process_frame
	_ok("desde_hechizo: la flecha es BOLA que viaja y no estalla en área", int(e3.figura) == 0 and e3.viaja and not e3.area_al_impactar)
	var e4: MagmaToy = _nueva()
	e4.desde_hechizo(h)
	h.semieje_x = 0.3
	h.semieje_z = 0.3
	e4.desde_hechizo(h)
	await process_frame
	_ok("desde_hechizo: la zona (bola quieta) estalla en área", e4.area_al_impactar)
	for n in [e2, e3, e4]:
		n.queue_free()
	await process_frame


func _carga() -> void:
	print("== carga y soltar")
	var e: MagmaToy = _nueva()
	await process_frame
	e.empezar_carga(1.0, 0.4)
	await process_frame
	_ok("al empezar la carga la roca es pequeña (escala %.2f ≤ 0,3) y GRIS (calor %.2f < 0,1; ya ha pasado un fotograma)" % [_escala(e), e.calor], _escala(e) <= 0.3 and e.calor < 0.1)
	var esc_ant: float = _escala(e)
	var cal_ant: float = e.calor
	var sube: bool = true
	var calienta: bool = true
	for i in 27:                                  # 0,9 s de la carga de 1 s: antes de que respire
		await process_frame
		var s: float = _escala(e)
		if s < esc_ant - 0.001:
			sube = false
		if e.calor < cal_ant - 0.001:
			calienta = false
		esc_ant = s
		cal_ant = e.calor
	_ok("durante la carga la escala no baja y el calor no baja (a 0,93 s: escala %.2f, calor %.2f, progreso %.2f)" % [_escala(e), e.calor, e.progreso_carga()], sube and calienta and e.progreso_carga() >= 0.85 and e.calor > 0.8)
	await _esperar(0.3)
	_ok("al llenarse el calor llega a 1 (%.2f)" % e.calor, e.calor > 0.95)
	_ok("la bola se ve durante la carga (carga_bola_visible por defecto)", (e.get_node("Cuerpo") as Node3D).visible)
	e.soltar(Vector3(0, 0, -1))
	await process_frame
	_ok("tras soltar: en vuelo, calor 1", e.viaja and e.proyectil and e.calor > 0.99)
	await _esperar(0.3)
	_ok("tras soltar la escala se asienta en 1 (%.2f)" % _escala(e), absf(_escala(e) - 1.0) < 0.02)
	e.queue_free()
	var c: MagmaToy = _nueva()
	await process_frame
	c.empezar_carga(1.0, 0.4)
	await _esperar(0.3)
	c.cancelar_carga()
	await _esperar(0.5)
	_ok("cancelar la carga la libera", not is_instance_valid(c))


func _rueda() -> void:
	print("== rueda y estela")
	var e: MagmaToy = _nueva()
	await process_frame
	e.definir(0, 0.4, 0.4, 0.4, true)
	await process_frame
	await process_frame
	var piv: Node3D = e.get_node("Cuerpo/Giro") as Node3D
	var q0: Quaternion = piv.quaternion
	for i in 30:
		e.global_position += Vector3(0, 0, -8.0 / 30.0)
		await process_frame
	var ang: float = q0.angle_to(piv.quaternion)
	_ok("al avanzar 8 m la roca ha rodado (giro acumulado %.1f rad ≈ 8 / 0,4 = 20; el pivote ha girado %.2f rad)" % [e.giro_rodado(), ang], absf(e.giro_rodado() - 20.0) < 1.5 and ang > 0.1)
	var eje: Vector3 = Vector3.UP.cross(Vector3(0, 0, -1))
	var q: Quaternion = piv.quaternion
	var eje_q: Vector3 = q.get_axis().normalized() if q.get_angle() > 0.01 else Vector3.ZERO
	_ok("el eje de giro es ⟂ a la velocidad (|eje·x| %.2f)" % absf(eje_q.dot(eje)), absf(eje_q.dot(eje)) > 0.9 or absf(eje_q.dot(eje)) < 0.001)
	var b: Array = e.brasas_vuelo()
	_ok("en vuelo deja brasas (%d vivas) que se quedan atrás y caen" % b.size(), b.size() >= 5)
	if b.size() > 0:
		var atras: bool = true
		var caen: bool = false
		for c in b:
			if (c["p"] as Vector3).z < e.global_position.z - 0.3:
				atras = false
			if (c["v"] as Vector3).y < 0.0:
				caen = true
		_ok("las brasas quedan detrás de la bola y alguna ya cae", atras and caen)
	e.queue_free()
	await process_frame


func _impactos() -> void:
	print("== impactos")
	var g: ImpactoMagmaToy = ImpactoMagmaToy.crear(ImpactoMagmaToy.Variante.GOLPE, Vector3.UP, 0.4)
	_raiz.add_child(g)
	g.global_position = Vector3(0, 0, 0)
	await process_frame
	var rec: Array = g.recuento()
	_ok("GOLPE: de 6 a 10 esquirlas (%d) y brasas (%d)" % [rec[0], rec[1]], rec[0] >= 6 and rec[0] <= 10 and rec[1] > 0)
	_ok("GOLPE: cráter (grietas_magma) y pétalos (%d)" % g.petalos(), g.crater() != null and (g.crater().material_override as ShaderMaterial).shader.resource_path.ends_with("grietas_magma.gdshader") and g.petalos() >= 4)
	var esq_mm: MultiMeshInstance3D = g.get_node("Plano/Esquirlas") as MultiMeshInstance3D
	_ok("GOLPE: las esquirlas llevan el MISMO shader que la bola, con el calor por instancia", (esq_mm.material_override as ShaderMaterial).shader.resource_path.ends_with("magma_roca.gdshader") and bool((esq_mm.material_override as ShaderMaterial).get_shader_parameter("por_instancia")))
	_ok("GOLPE: 0 GPUParticles3D", g.find_children("*", "GPUParticles3D", true, false).is_empty())
	await _esperar(0.25)
	var e0: Array = g.esquirlas_estado()
	var lejos: bool = true
	var calientes: bool = true
	for s in e0:
		if (s["pos"] as Vector3).length() < 0.15:
			lejos = false
		if float(s["calor"]) < 0.5:
			calientes = false
	_ok("a 0,25 s las esquirlas se han alejado del punto y siguen calientes (> 0,5)", lejos and calientes)
	_ok("a 0,25 s el cráter está entre amarillo y rojo (calor %.2f)" % ImpactoMagmaToy.calor_crater(g.tiempo()), ImpactoMagmaToy.calor_crater(g.tiempo()) > 0.8)
	await _esperar(0.9)
	var e1: Array = g.esquirlas_estado()
	var frias: bool = true
	var en_suelo: int = 0
	for s in e1:
		if float(s["calor"]) > 0.05:
			frias = false
		if float(s["altura"]) < 0.3:
			en_suelo += 1
	_ok("a 1,15 s las esquirlas están frías (calor 0) y la mayoría ya en el suelo (%d / %d)" % [en_suelo, e1.size()], frias and en_suelo >= e1.size() / 2)
	await _esperar(1.0)
	var cc: float = float((g.crater().material_override as ShaderMaterial).get_shader_parameter("calor"))
	_ok("a 2,15 s el cráter está gris (calor %.2f)" % cc, cc < 0.1)
	await _esperar(1.0)
	var vida: float = float((g.crater().material_override as ShaderMaterial).get_shader_parameter("vida")) if is_instance_valid(g) and g.crater() != null else 0.0
	_ok("a 3,15 s el cráter se ha desvanecido (vida %.2f)" % vida, vida < 0.05)
	await _esperar(0.3)
	_ok("GOLPE: se libera solo", not is_instance_valid(g))
	# pared
	var p: ImpactoMagmaToy = ImpactoMagmaToy.crear(ImpactoMagmaToy.Variante.GOLPE, Vector3(1, 0, 0), 0.4)
	_raiz.add_child(p)
	await _esperar(0.2)
	var fuera: bool = true
	for s in p.esquirlas_estado():
		if (s["pos"] as Vector3).x < 0.0:
			fuera = false
	_ok("GOLPE en una pared (normal +X): las esquirlas salen hacia fuera de la pared y hay cráter", fuera and p.crater() != null)
	p.queue_free()
	var r: ImpactoMagmaToy = ImpactoMagmaToy.crear(ImpactoMagmaToy.Variante.REBOTE, Vector3.UP, 0.4)
	_raiz.add_child(r)
	await process_frame
	_ok("REBOTE: esquirlas (%d) y sin cráter" % r.recuento()[0], r.recuento()[0] >= 3 and r.crater() == null)
	var a: ImpactoMagmaToy = ImpactoMagmaToy.crear(ImpactoMagmaToy.Variante.AREA, Vector3.UP, 1.8)
	_raiz.add_child(a)
	await process_frame
	_ok("AREA: cráter grande (lado %.2f ≥ 3,5 m) y más esquirlas (%d)" % [(a.crater().mesh as PlaneMesh).size.x, a.recuento()[0]], (a.crater().mesh as PlaneMesh).size.x >= 3.5 and a.recuento()[0] >= 10)
	var f: ImpactoMagmaToy = ImpactoMagmaToy.crear(ImpactoMagmaToy.Variante.FIN, Vector3.UP, 0.4)
	_raiz.add_child(f)
	await process_frame
	_ok("FIN: sin cráter, con brasas", f.crater() == null and f.recuento()[1] > 0)
	await _esperar(3.8)
	_ok("REBOTE, AREA y FIN se liberan solos", not is_instance_valid(r) and not is_instance_valid(a) and not is_instance_valid(f))


func _api() -> void:
	print("== API de MagmaToy")
	var e: MagmaToy = _nueva()
	await process_frame
	e.definir(0, 0.4, 0.4, 0.4, true)
	e.global_position = Vector3(0, 0.7, 0)
	await process_frame
	var imp: Node3D = e.impactar_en(Vector3(0, 0, -3), Vector3.UP)
	_ok("impactar_en crea un ImpactoMagmaToy GOLPE en el punto", imp is ImpactoMagmaToy and int(imp.get("variante")) == ImpactoMagmaToy.Variante.GOLPE and (imp.global_position - Vector3(0, 0, -3)).length() < 0.01)
	await _esperar(0.4)
	_ok("tras impactar la bola se libera (0,12 s)", not is_instance_valid(e))
	var rb: MagmaToy = _nueva()
	await process_frame
	rb.definir(0, 0.4, 0.4, 0.4, true)
	rb.global_position = Vector3(0, 0.7, 0)
	rb.look_at(Vector3(0, 0.7, -1), Vector3.UP)
	await process_frame
	var nd: Vector3 = rb.rebotar(Vector3(0, 0.7, -2), Vector3(0, 0, 1))
	_ok("rebotar devuelve la dirección reflejada (%s) y la bola sigue" % str(nd), nd.distance_to(Vector3(0, 0, 1)) < 0.01 and is_instance_valid(rb) and rb.get_parent().find_children("*", "ImpactoMagmaToy", false, false).size() >= 1)
	await process_frame
	_ok("tras rebotar la bola mira a la nueva dirección", (-rb.global_transform.basis.z).distance_to(nd) < 0.01)
	rb.queue_free()
	var fin: MagmaToy = _nueva()
	await process_frame
	fin.definir(0, 0.4, 0.4, 0.4, true)
	fin.global_position = Vector3(0, 0.7, 0)
	await process_frame
	var y0: float = fin.global_position.y
	fin.terminar_sin_choque()
	await _esperar(0.3)
	_ok("terminar_sin_choque: la roca se enfría (calor %.2f < 0,6) y cae (y %.2f < %.2f)" % [fin.calor, fin.global_position.y, y0], fin.calor < 0.6 and fin.global_position.y < y0 - 0.05)
	await _esperar(0.5)
	_ok("... y acaba gris (calor %.2f) parada en el suelo (y %.2f ≈ 0,2)" % [fin.calor, fin.global_position.y], fin.calor < 0.01 and absf(fin.global_position.y - 0.2) < 0.1)
	await _esperar(0.8)
	_ok("... y se libera sola", not is_instance_valid(fin))
	var fz: MagmaToy = _nueva()
	await process_frame
	fz.definir(0, 0.4, 0.4, 0.4, true)
	fz.global_position = Vector3(0, 0.7, 0)
	await process_frame
	fz.finalizar("muro", Vector3(0, 0.7, -2), Vector3(0, 0, 1))
	var imps: Array = _raiz.find_children("*", "ImpactoMagmaToy", false, false)
	_ok("finalizar(«muro») impacta", imps.size() >= 1)
	await _esperar(0.3)
	var im: MagmaToy = _nueva()
	await process_frame
	im.definir(0, 0.4, 0.4, 0.4, true)
	im.global_position = Vector3(0, 0.7, 0)
	await process_frame
	im.impactar()
	_ok("impactar() (contrato EfectoVfx3D) funciona", _raiz.find_children("*", "ImpactoMagmaToy", false, false).size() >= 1)
	await _esperar(0.3)
	var pr: MagmaToy = _nueva()
	await process_frame
	pr.preparar({"x": 0.3, "y": 0.3, "z": 0.3}, Vector3(0, 0, -1), "magma")
	await process_frame
	_ok("preparar escala los semiejes por la casilla (%.2f ≈ 0,69)" % pr.semieje_x, absf(pr.semieje_x - 0.69) < 0.01)
	pr.queue_free()
	await _esperar(3.5)


func _lab() -> void:
	print("== lab: Z llega al magma")
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	var orden: Array = []
	for i in 4:
		lab.call("alternar_elemento")
		orden.append(String(lab.get("elemento")))
	_ok("Z: fuego → agua → hielo → rayo → magma (%s)" % str(orden), orden == ["agua", "hielo", "rayo", "magma"])
	var e: Node3D = lab.call("carga_completa")
	_ok("G con magma crea un MagmaToy", e is MagmaToy)
	var ip: Node3D = lab.call("impacto_pared")
	var isu: Node3D = lab.call("impacto_suelo")
	_ok("B y N con magma crean ImpactoMagmaToy", ip is ImpactoMagmaToy and isu is ImpactoMagmaToy)
	var m: Node3D = lab.call("lanzar_proyectil", "fin")
	var rb: Node3D = lab.call("lanzar_proyectil", "rebote")
	_ok("M y R con magma crean MagmaToy", m is MagmaToy and rb is MagmaToy)
	var pa: Node3D = lab.call("explosion_area")
	_ok("P con magma crea un ImpactoMagmaToy AREA", pa is ImpactoMagmaToy and int(pa.get("variante")) == ImpactoMagmaToy.Variante.AREA)
	var fp: Node3D = lab.call("fuego_param", 1)
	_ok("F7 con magma crea un MagmaToy MURO", fp is MagmaToy and int(fp.get("figura")) == 1)
	var hz: Node3D = lab.call("fuego_hechizo", 0)
	_ok("F9 con magma crea un MagmaToy desde un hechizo", hz is MagmaToy)
	_ok("la línea de ayuda y el rótulo muestran el elemento", String(lab.call("_texto_carga")).find("ELEMENTO: MAGMA") >= 0 and String(lab.call("_texto_param")).find("MAGMA PARAMETRICO") >= 0)
	lab.call("alternar_elemento")
	_ok("Z desde el magma pasa al viento (6/11: VientoToy)", String(lab.get("elemento")) == "viento")
	lab.call("alternar_elemento")
	lab.call("alternar_elemento")
	_ok("Z desde la tierra vuelve al fuego", String(lab.get("elemento")) == "fuego")
	await _esperar(4.5)                   # la carga de G se suelta, vuela e impacta: que todo el ciclo pase sin errores
	lab.queue_free()
	await process_frame
