extends SceneTree

## PRUEBA del agua «toy», FASE 1 (bola, casteo y salpicadura; 3/11/2026). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_agua_toy.gd
## Comprueba, con AguaToy e ImpactoAguaToy:
##   1. BOLA: figura BOLA con esfera y 3 cintas envolventes + 3 de estela, sin luces, sin GPUParticles3D y sin materiales aditivos; los shaders del agua son blend_mix y sin emisión
##   2. CARGA: nace pequeña, crece sin bajar y llega al tamaño final; las gotitas CONVERGEN (van hacia la mano, el radio baja con la edad) y hay más cuanto más avanza la carga
##   3. SOLTAR: el MISMO nodo, pasa a proyectil, sin saltos de tamaño (también soltando a medio crecer)
##   4. IMPACTOS: GOLPE contra pared y suelo, FIN y REBOTE se crean y se liberan solos; las gotas salen en el hemisferio de la normal (nunca bajo la superficie), se alejan y CAEN (velocidad vertical menor)
##   5. AguaToy: impactar_en libera la bola y deja un impacto; rebotar la deja viva y devuelve la dirección reflejada; terminar_sin_choque y finalizar la liberan
##   6. PRESUPUESTO en todo el ciclo: 0 luces, 0 GPUParticles3D, ≤ 300 partículas (instancias de MultiMesh), 0 aditivos
##   7. LAB: Z alterna el elemento y G / B / N crean agua o fuego según el elemento
##   8. PILAR / GÉISER (fase 3): cortina + núcleo + corona de lenguas de alturas distintas + espuma + charco; alto = semieje y; brota con pico y se asienta; las gotas SUBEN y CAEN (la misma gota entre
##      dos instantes: hueco y edad); morir lo desploma y deja el charco, y se libera solo
##   9. EXPLOSIÓN DE ÁREA (fase 3, ImpactoAguaToy.Variante.AREA): las cuatro fases en el tiempo (estallido, columnas, curvarse y caer, charco grande con gotas hacia fuera), escala con el radio, se libera sola;
##      AguaToy.explotar_area / area_al_impactar; tecla P del lab
## NO comprueba (necesita ventana y GPU): el aspecto ni que los shaders compilen (se ve en las capturas). Imprime FALLOS: n.

const AguaMallas = preload("res://presentacion/vfx/toy/agua_mallas.gd")
const AguaPaleta = preload("res://presentacion/vfx/toy/agua_paleta.gd")
const MAX_PARTICULAS: int = 300
const SHADERS: PackedStringArray = ["agua_toy.gdshaderinc", "agua_esfera.gdshader", "agua_esfera_atras.gdshader", "agua_cinta.gdshader", "agua_gota.gdshader", "agua_onda.gdshader",
	"agua_haz.gdshader", "agua_haz_cinta.gdshader", "agua_mancha.gdshader", "agua_pilar.gdshader", "agua_lamina.gdshader", "agua_espuma.gdshader", "agua_franja.gdshader", "agua_ola.gdshader", "agua_ola_lamina.gdshader"]

var _fallos: int = 0
var _raiz: Node3D = null
var _max_luces: int = 0
var _max_gpu: int = 0
var _max_part: int = 0
var _aditivos: int = 0


func _initialize() -> void:
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
	_estilo()
	await _bola()
	await _carga()
	await _soltar()
	await _impactos()
	await _gotas_fisica()
	await _agua_toy_api()
	await _haz()
	await _paleta()
	await _pilar()
	await _lenguas()
	await _ola()
	await _area()
	await _lab()
	print("máximo visto en todo el ciclo: %d luces, %d GPUParticles3D, %d partículas (MultiMesh), %d materiales aditivos" % [_max_luces, _max_gpu, _max_part, _aditivos])
	_ok("presupuesto: 0 luces, 0 GPUParticles3D, ≤ %d partículas, 0 aditivos" % MAX_PARTICULAS, _max_luces == 0 and _max_gpu == 0 and _max_part <= MAX_PARTICULAS and _aditivos == 0)
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _esperar(seg: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < seg:
		await process_frame
		_medir()


func _medir() -> void:
	var luces: int = 0
	var gpu: int = 0
	var part: int = 0
	var adit: int = 0
	for n in _raiz.find_children("*", "", true, false):
		if n is Light3D and (n as Light3D).is_visible_in_tree():
			luces += 1
		elif n is GPUParticles3D:
			gpu += (n as GPUParticles3D).amount
		elif n is MultiMeshInstance3D:
			part += (n as MultiMeshInstance3D).multimesh.instance_count
		if n is GeometryInstance3D:
			var m: ShaderMaterial = (n as GeometryInstance3D).material_override as ShaderMaterial
			while m != null:
				if m.shader != null and m.shader.code.find("blend_add") >= 0:
					adit += 1
				m = m.next_pass as ShaderMaterial
	_max_luces = maxi(_max_luces, luces)
	_max_gpu = maxi(_max_gpu, gpu)
	_max_part = maxi(_max_part, part)
	_aditivos = maxi(_aditivos, adit)


func _nueva() -> AguaToy:
	var e: AguaToy = AguaToy.new()
	_raiz.add_child(e)
	return e


func _escala(e: AguaToy) -> float:
	return (e.get_node("Cuerpo") as Node3D).scale.x


# ------------------------------------------------------------------ estilo (por el código) ------------------------------------------------------------------

func _estilo() -> void:
	print("== shaders")
	for s in SHADERS:
		var txt: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/" + s)
		var cuerpo: PackedStringArray = PackedStringArray()
		for l in txt.split("\n"):
			if not l.strip_edges().begins_with("//"):
				cuerpo.append(l)
		var codigo: String = "\n".join(cuerpo)
		_ok(s + ": sin blend_add, sin EMISSION", codigo.find("blend_add") < 0 and codigo.find("EMISSION") < 0)
		if s.ends_with(".gdshader"):
			_ok(s + ": blend_mix y unshaded (sin luz)", codigo.find("blend_mix") >= 0 and codigo.find("unshaded") >= 0)


# ------------------------------------------------------------------ 1. bola ------------------------------------------------------------------

func _bola() -> void:
	print("== bola")
	var e: AguaToy = _nueva()
	await process_frame
	_ok("figura BOLA y sin proyectil", e.figura == AguaToy.Figura.BOLA and not e.proyectil)
	_ok("tiene la esfera", e.find_child("Esfera", true, false) is MeshInstance3D)
	_ok("2 cintas envolventes (finas) y 2 de estela", e.find_children("Env*", "MeshInstance3D", true, false).size() == 2 and e.find_children("Est*", "MeshInstance3D", true, false).size() == 2)
	# las cintas envolventes no tapan la esfera: su área (suma de triángulos) no pasa del 30 % de la superficie de la esfera
	var area_c: float = 0.0
	for m in e.find_children("Env*", "MeshInstance3D", true, false):
		var caras: PackedVector3Array = (m as MeshInstance3D).mesh.get_faces()
		for k in range(0, caras.size(), 3):
			area_c += (caras[k + 1] - caras[k]).cross(caras[k + 2] - caras[k]).length() * 0.5
	var cobertura: float = area_c / (4.0 * PI * 0.4 * 0.4)
	_ok("las cintas cubren %.0f %% de la esfera (≤ 30 %%)" % (cobertura * 100.0), cobertura > 0.02 and cobertura <= 0.30)
	var est0: Node3D = e.find_child("Estela", true, false) as Node3D
	var gira: bool = false
	var n_ant: Node = est0
	while n_ant != null and n_ant != e:
		if n_ant.name == "Cintas":
			gira = true
		n_ant = n_ant.get_parent()
	_ok("la estela NO cuelga de las cintas que giran (no es una hélice regular)", not gira)
	_ok("sin luces ni GPUParticles3D", e.find_children("*", "Light3D", true, false).is_empty() and e.find_children("*", "GPUParticles3D", true, false).is_empty())
	var estela: Node3D = e.find_child("Estela", true, false) as Node3D
	_ok("la estela solo se ve en vuelo", not estela.visible)
	e.definir(AguaToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	await process_frame
	_ok("en vuelo (viaja) la estela se ve", (e.find_child("Estela", true, false) as Node3D).visible and e.proyectil)
	# la cabeza es más grande que la estela: el radio máximo de las mallas de la estela < el radio de la esfera
	var r_cab: float = 0.4
	var r_est: float = 0.0
	for m in e.find_children("Est*", "MeshInstance3D", true, false):
		var aabb: AABB = (m as MeshInstance3D).mesh.get_aabb()
		r_est = maxf(r_est, maxf(aabb.size.x, aabb.size.y) * 0.5)
	_ok("la cabeza (r %.2f) es más grande que la estela (r máx %.2f)" % [r_cab, r_est], r_est < r_cab)
	# otras figuras: marcador provisional
	e.definir(AguaToy.Figura.BARRERA, 1.5, 1.5, 1.5, false)
	await process_frame
	_ok("BARRERA: marcador provisional (no revienta; es la fase 5)", e.find_child("Marcador", true, false) != null)
	_ok("BARRERA: sin reserva de gotas", e.find_child("Gotas", true, false) == null)
	e.queue_free()
	await process_frame


# ------------------------------------------------------------------ 2. carga ------------------------------------------------------------------

func _carga() -> void:
	print("== carga")
	var e: AguaToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 1, 0)
	e.empezar_carga(0.8, 0.4)
	var s0: float = _escala(e)
	_ok("nace pequeña: escala %.3f ≈ carga_tam_inicial %.2f" % [s0, e.carga_tam_inicial], absf(s0 - e.carga_tam_inicial) < 0.06)
	_ok("esta_cargando() y progreso empieza en ≈ 0", e.esta_cargando() and e.progreso_carga() < 0.15)
	var conv: Node = e.find_child("Convergencia", true, false)
	_ok("hay gotitas, remolino y ondas bajo los pies", conv != null and conv.find_child("Gotitas", true, false) != null and conv.find_child("Remolino", true, false) != null and conv.find_child("Onda0", true, false) != null)
	var prev: float = s0
	var baja: bool = false
	var n_ini: int = int(conv.call("n_visibles"))
	var conv_ok: int = 0
	var conv_tot: int = 0
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < 700.0:
		await process_frame
		_medir()
		var s: float = _escala(e)
		if s < prev - 0.002:
			baja = true
		prev = s
		for g in conv.call("estado_gotas"):
			var gd: Dictionary = g
			var p: Vector3 = gd["pos"]
			var d: Vector3 = gd["mov"]
			conv_tot += 1
			if float(gd["u"]) > 0.1 and float(gd["u"]) < 0.9 and p.length() > 0.001:
				conv_tot += 0
			# converge: la gotita avanza hacia dentro (componente radial de su movimiento negativa) y su radio es menor que el de nacimiento
			if float(gd["rad"]) <= float(gd["r0"]) + 0.0001 and d.dot(p.normalized()) < 0.2:
				conv_ok += 1
	_ok("crece sin bajar (escala %.2f)" % prev, not baja and prev > 0.7)
	_ok("las gotitas convergen (%d de %d hacia dentro y por debajo del radio de nacimiento)" % [conv_ok, conv_tot], conv_tot > 0 and float(conv_ok) / float(conv_tot) > 0.97)
	var n_fin: int = int(conv.call("n_visibles"))
	_ok("hay más gotitas cuanto más avanza la carga (%d → %d)" % [n_ini, n_fin], n_fin > n_ini)
	_ok("progreso_carga llega a 1", e.progreso_carga() > 0.85)
	# distancia de las gotitas a la mano: la media del radio actual baja con la edad
	var u_bajo: float = 0.0
	var u_alto: float = 0.0
	var nb: int = 0
	var na: int = 0
	for g in conv.call("estado_gotas"):
		var gd2: Dictionary = g
		if float(gd2["u"]) < 0.3:
			u_bajo += float(gd2["rad"]) / float(gd2["r0"])
			nb += 1
		elif float(gd2["u"]) > 0.7:
			u_alto += float(gd2["rad"]) / float(gd2["r0"])
			na += 1
	_ok("el radio relativo baja con la edad (joven %.2f > vieja %.2f)" % [u_bajo / maxf(nb, 1), u_alto / maxf(na, 1)], nb > 0 and na > 0 and u_bajo / nb > u_alto / na)
	e.cancelar_carga()
	await _esperar(0.45)
	_ok("cancelar_carga la libera sola", not is_instance_valid(e))


# ------------------------------------------------------------------ 3. soltar ------------------------------------------------------------------

func _soltar() -> void:
	print("== soltar")
	for etapa in ["llena", "a medias"]:
		var e: AguaToy = _nueva()
		await process_frame
		e.global_position = Vector3(0, 1, 0)
		e.empezar_carga(0.6, 0.4)
		await _esperar(0.7 if etapa == "llena" else 0.25)
		var id: int = e.get_instance_id()
		var antes: float = _escala(e)
		e.soltar(Vector3(0, 0, -1))
		_ok("[%s] soltar: mismo nodo, proyectil y estela visible" % etapa, e.get_instance_id() == id and e.proyectil and (e.find_child("Estela", true, false) as Node3D).visible)
		var salto: float = 0.0
		var prev: float = antes
		var t0: int = Time.get_ticks_msec()
		while float(Time.get_ticks_msec() - t0) < 400.0:
			await process_frame
			_medir()
			salto = maxf(salto, absf(_escala(e) - prev))
			prev = _escala(e)
		_ok("[%s] sin salto de tamaño al soltar (máx %.3f por fotograma, de %.2f a %.2f)" % [etapa, salto, antes, prev], salto < 0.12 and absf(prev - 1.0) < 0.02)
		e.queue_free()
		await process_frame


# ------------------------------------------------------------------ 4. impactos ------------------------------------------------------------------

func _impactos() -> void:
	print("== impactos")
	var casos: Array = [["GOLPE pared", ImpactoAguaToy.Variante.GOLPE, Vector3(0, 0, 1)], ["GOLPE suelo", ImpactoAguaToy.Variante.GOLPE, Vector3.UP],
		["GOLPE techo", ImpactoAguaToy.Variante.GOLPE, Vector3.DOWN], ["FIN", ImpactoAguaToy.Variante.FIN, Vector3.UP], ["REBOTE pared", ImpactoAguaToy.Variante.REBOTE, Vector3(1, 0, 0)]]
	for c in casos:
		var imp: ImpactoAguaToy = ImpactoAguaToy.crear(c[1], c[2], 0.4)
		_raiz.add_child(imp)
		imp.global_position = Vector3(0, 1, 0)
		await process_frame
		var n: Vector3 = (c[2] as Vector3)
		var bajo: int = 0
		var vivas: int = 0
		var lejos0: float = 0.0
		var lejos1: float = 0.0
		var cuenta: int = 0
		var cae: int = 0
		var cae_tot: int = 0
		var g_ini: Array = imp.gotas_estado(0.1)
		var g_fin: Array = imp.gotas_estado(0.3)
		for t in [0.05, 0.1, 0.2, 0.3, 0.45]:
			for g in imp.gotas_estado(t):
				var gd: Dictionary = g
				if bool(gd["vivo"]):
					vivas += 1
					if c[1] != ImpactoAguaToy.Variante.FIN and float(gd["altura"]) < -0.006:
						bajo += 1
		if c[1] != ImpactoAguaToy.Variante.FIN:
			for i in g_ini.size():
				var a: Dictionary = g_ini[i]
				var b: Dictionary = g_fin[i]
				if bool(a["vivo"]) and bool(b["vivo"]) and not bool(a["burbuja"]):
					cuenta += 1
					lejos0 += float(a["dist"])
					lejos1 += float(b["dist"])
					cae_tot += 1
					if float(b["vy"]) < float(a["vy"]) - 0.5:
						cae += 1
		var rc: Array = imp.recuento_gotas()
		_ok("[%s] genera %d gotas y %d burbujas, hay gotas vivas" % [c[0], rc[0], rc[1]], int(rc[0]) >= 4 and vivas > 0)
		var suelo_h: bool = n.dot(Vector3.UP) >= 0.7 and c[1] != ImpactoAguaToy.Variante.FIN
		if c[1] != ImpactoAguaToy.Variante.FIN:
			if suelo_h:
				_ok("[%s] suelo: HAY anillo de ondas y no hay mancha de pared" % c[0], imp.find_child("Anillo", true, false) != null and imp.find_child("Mancha", true, false) == null)
			else:
				_ok("[%s] pared/techo: NINGÚN anillo vertical; hay mancha húmeda" % c[0], imp.find_child("Anillo", true, false) == null and imp.find_child("Mancha", true, false) != null)
		if c[1] == ImpactoAguaToy.Variante.GOLPE and absf(n.y) < 0.7:
			var ch: Node3D = imp.find_child("Charquito", true, false) as Node3D
			imp.avanzar_a(0.1)
			var ve_pronto: bool = ch != null and ch.visible
			imp.avanzar_a(0.6)
			_ok("[%s] charquito en el suelo: aparece tras las gotas (no a los 0,1 s), pequeño y horizontal" % c[0], ch != null and not ve_pronto and ch.visible and ch.scale.x < 1.2 and ch.position.y < -0.3)
			_ok("[%s] más de 30 gotas de salpicadura" % c[0], int(rc[0]) >= 30)
		if c[1] != ImpactoAguaToy.Variante.FIN:
			_ok("[%s] ninguna gota por debajo de la superficie (en el hemisferio de la normal)" % c[0], bajo == 0)
			_ok("[%s] las gotas se alejan (%.2f → %.2f m de media)" % [c[0], lejos0 / maxf(cuenta, 1), lejos1 / maxf(cuenta, 1)], cuenta > 0 and lejos1 > lejos0)
			_ok("[%s] CAEN: la velocidad vertical baja con la gravedad (%d de %d)" % [c[0], cae, cae_tot], cae_tot > 0 and cae == cae_tot)
		else:
			var cae2: int = 0
			var tot2: int = 0
			for i in imp.gotas_estado(0.1).size():
				var a2: Dictionary = imp.gotas_estado(0.1)[i]
				var b2: Dictionary = imp.gotas_estado(0.4)[i]
				if bool(a2["vivo"]) and bool(b2["vivo"]) and not bool(a2["burbuja"]):
					tot2 += 1
					if float(b2["vy"]) < float(a2["vy"]) - 2.0:
						cae2 += 1
			_ok("[FIN] las gotas caen (%d de %d)" % [cae2, tot2], tot2 > 0 and cae2 == tot2)
			_ok("[FIN] sin lámina ni anillo", imp.find_child("Lamina", true, false) == null and imp.find_child("Anillo", true, false) == null)
		var t0: int = Time.get_ticks_msec()
		while is_instance_valid(imp) and float(Time.get_ticks_msec() - t0) < 2500.0:
			await process_frame
			_medir()
		_ok("[%s] se libera solo" % c[0], not is_instance_valid(imp))
	# tamaño: la corona sigue al radio
	var pequeno: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.GOLPE, Vector3.UP, 0.2)
	var grande: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.GOLPE, Vector3.UP, 0.8)
	_raiz.add_child(pequeno)
	_raiz.add_child(grande)
	await process_frame
	var dmax_p: float = 0.0
	var dmax_g: float = 0.0
	for g in pequeno.gotas_estado(0.2):
		dmax_p = maxf(dmax_p, float((g as Dictionary)["dist"]))
	for g in grande.gotas_estado(0.2):
		dmax_g = maxf(dmax_g, float((g as Dictionary)["dist"]))
	_ok("la salpicadura escala con el radio (%.2f m con r 0,2 · %.2f m con r 0,8)" % [dmax_p, dmax_g], dmax_g > dmax_p * 1.5)
	pequeno.queue_free()
	grande.queue_free()
	await process_frame


## La reserva de gotas de la bola (AguaGotas): caen con gravedad en el mundo y desaparecen bajo el suelo.
func _gotas_fisica() -> void:
	print("== reserva de gotas")
	var AguaGotas = load("res://presentacion/vfx/toy/agua_gotas.gd")
	var g: Node3D = AguaGotas.new()
	_raiz.add_child(g)
	g.call("montar", 8)
	g.call("emitir", Vector3(0, 2, 0), Vector3(1, 0, 0), 1.0, 0.05, 0, 0.9, 0.5, 1.0)
	var y0: float = ((g.call("estados") as Array)[0] as Dictionary)["pos"].y
	var vy0: float = ((g.call("estados") as Array)[0] as Dictionary)["vel"].y
	for i in 20:
		g.call("avanzar", 0.02)
	var e1: Dictionary = (g.call("estados") as Array)[0]
	_ok("la gota cae con gravedad (y %.2f → %.2f, vy %.2f → %.2f)" % [y0, e1["pos"].y, vy0, e1["vel"].y], e1["pos"].y < y0 and e1["vel"].y < vy0 - 3.0 and e1["pos"].x > 0.2)
	g.set("suelo_y", 0.0)
	for i in 100:
		g.call("avanzar", 0.02)
	_ok("desaparece al bajar del suelo o de su vida (vivas %d)" % int(g.call("vivas")), int(g.call("vivas")) == 0)
	g.queue_free()
	await process_frame


# ------------------------------------------------------------------ 5. API de AguaToy ------------------------------------------------------------------

func _hay_impacto() -> bool:
	for h in _raiz.get_children():
		if h is ImpactoAguaToy:
			return true
	return false


func _limpiar_impactos() -> void:
	for h in _raiz.get_children():
		if h is ImpactoAguaToy:
			h.free()


func _agua_toy_api() -> void:
	print("== AguaToy: impactar_en / rebotar / terminar_sin_choque / finalizar")
	var e: AguaToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 1, 0)
	e.definir(AguaToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	await _esperar(0.3)
	e.impactar_en(Vector3(0, 1, -2), Vector3(0, 0, 1))
	_ok("impactar_en deja un impacto", _hay_impacto())
	await _esperar(0.6)
	_ok("impactar_en libera la bola", not is_instance_valid(e))
	_limpiar_impactos()
	await process_frame

	var r: AguaToy = _nueva()
	await process_frame
	r.global_position = Vector3(0, 1, 0)
	r.look_at(Vector3(0, 1, -5), Vector3.UP)
	r.definir(AguaToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	await process_frame
	var nd: Vector3 = r.rebotar(Vector3(0, 1, -2), Vector3(0, 0, 1))
	_ok("rebotar: la bola sigue viva, hay impacto y devuelve la dirección reflejada (%s)" % str(nd), is_instance_valid(r) and _hay_impacto() and nd.distance_to(Vector3(0, 0, 1)) < 0.01)
	_ok("rebotar: la bola mira hacia la dirección reflejada", (-r.global_transform.basis.z).distance_to(nd) < 0.01)
	await _esperar(0.7)
	_limpiar_impactos()
	r.queue_free()
	await process_frame

	var f: AguaToy = _nueva()
	await process_frame
	f.global_position = Vector3(0, 1, 0)
	f.empezar_carga(0.1, 0.4)
	await _esperar(0.2)
	f.soltar(Vector3(0, 0, -1))
	await _esperar(0.2)
	f.terminar_sin_choque()
	_ok("terminar_sin_choque deja un impacto FIN", _hay_impacto())
	await _esperar(1.7)
	_ok("terminar_sin_choque libera la bola tras apagarse", not is_instance_valid(f))
	_limpiar_impactos()

	var h: AguaToy = _nueva()
	await process_frame
	h.global_position = Vector3(0, 1, 0)
	h.finalizar("suelo", Vector3(0, 0, 0), Vector3.UP)
	_ok("finalizar('suelo') = impacto", _hay_impacto())
	await _esperar(0.6)
	_ok("finalizar('suelo') libera la bola", not is_instance_valid(h))
	_limpiar_impactos()
	var h2: AguaToy = _nueva()
	await process_frame
	h2.finalizar("alcance")
	_ok("finalizar('alcance') = fin sin choque", _hay_impacto())
	await _esperar(1.7)
	_ok("finalizar('alcance') libera la bola", not is_instance_valid(h2))
	_limpiar_impactos()
	# describir: la misma regla que el fuego (el elemento no cambia la figura ni el tamaño)
	var hz: Hechizo = Hechizo.new()
	hz.semieje_x = 0.3
	hz.semieje_y = 0.3
	hz.semieje_z = 0.3
	hz.velocidad = 8.0
	var da: Dictionary = AguaToy.describir(hz)
	var df: Dictionary = FuegoToy.describir(hz)
	_ok("describir(h) es igual que el del fuego", int(da["figura"]) == int(df["figura"]) and is_equal_approx(float(da["x"]), float(df["x"])) and bool(da["viaja"]) == bool(df["viaja"]))
	var d: AguaToy = _nueva()
	await process_frame
	d.desde_hechizo(hz)
	await process_frame
	_ok("desde_hechizo: BOLA en vuelo con el tamaño del hechizo", d.figura == AguaToy.Figura.BOLA and d.viaja and is_equal_approx(d.semieje_x, float(df["x"])))
	d.queue_free()
	await process_frame


# ------------------------------------------------------------------ 6. haz ------------------------------------------------------------------

func _param_haz(e: AguaToy, nombre: String, param: String) -> float:
	var mi: MeshInstance3D = e.find_child(nombre, true, false) as MeshInstance3D
	return float((mi.material_override as ShaderMaterial).get_shader_parameter(param))


func _haz() -> void:
	print("== haz")
	var e: AguaToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 0.0, 0)
	e.definir(AguaToy.Figura.HAZ, 1.5, 0.5, 0.15, false)
	await process_frame
	_ok("HAZ: tubo, núcleo, 2 cintas enrolladas y punta (abanico + espuma)", e.find_child("Chorro", true, false) is MeshInstance3D and e.find_child("Nucleo", true, false) is MeshInstance3D
		and e.find_children("Cinta*", "MeshInstance3D", true, false).size() == 2 and e.find_child("Abanico", true, false) != null and e.find_children("Espuma*", "MeshInstance3D", true, false).size() == 3)
	_ok("HAZ: sin luces, sin GPUParticles3D y con reserva de gotas de %d huecos" % AguaToy.GOTAS_RESERVA_HAZ, e.find_children("*", "Light3D", true, false).is_empty()
		and e.find_children("*", "GPUParticles3D", true, false).is_empty() and e.find_child("Gotas", true, false) != null)
	# NACE DE UN PUNTO: la malla del tubo tiene en el origen un ancho ~0 y en la punta el radio abierto (y es la geometría de FuegoToyMallas)
	var malla: ArrayMesh = (e.find_child("Chorro", true, false) as MeshInstance3D).mesh as ArrayMesh
	var v: PackedVector3Array = malla.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var x0: float = 0.0
	var x1: float = 0.0
	for p in v:
		if absf(p.z) < 0.001:
			x0 = maxf(x0, absf(p.x))
		if p.z < -2.9:
			x1 = maxf(x1, absf(p.x))
	_ok("el chorro nace de un punto: semianchura en el origen %.3f m (≤ 0,02) y en la punta %.2f m" % [x0, x1], x0 <= 0.02 and x1 > 0.25)
	_ok("misma geometría que el haz de fuego (haz_cono)", v.size() == FuegoToyMallas.haz_cono(3.0, FuegoToy.HAZ_R_ORIGEN, 0.36).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
	# animación de nacer: crece 0 → 1
	e.crece = 0.0
	_ok("crece = 0 llega a los shaders (tubo y cintas)", _param_haz(e, "Chorro", "crece") == 0.0 and _param_haz(e, "Nucleo", "crece") == 0.0 and _param_haz(e, "Cinta0", "crece") == 0.0)
	e.lanzar(-1.0)
	var c_ini: float = e.crece
	var prev: float = c_ini
	var baja: bool = false
	var c_med: float = -1.0
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < 700.0:
		await process_frame
		_medir()
		if e.crece < prev - 0.001:
			baja = true
		prev = e.crece
		if c_med < 0.0 and Time.get_ticks_msec() - t0 > 150:
			c_med = e.crece
	_ok("nacer: crece empieza en %.2f, a los 0,15 s va por %.2f y acaba en %.2f sin bajar" % [c_ini, c_med, prev], c_ini < 0.1 and c_med > 0.1 and c_med < 0.95 and prev > 0.99 and not baja)
	_ok("el shader recibe el mismo crece (%.2f)" % _param_haz(e, "Chorro", "crece"), absf(_param_haz(e, "Chorro", "crece") - e.crece) < 0.001)
	# gotas a lo largo + abanico: la reserva se llena y las gotas CAEN
	await _esperar(0.5)
	var gotas: Node = e.find_child("Gotas", true, false)
	var est: Array = gotas.call("estados")
	_ok("el haz suelta gotas que se desprenden (%d vivas) y el abanico las lanza hacia delante" % est.size(), est.size() >= 6)
	# la MISMA gota (mismo hueco y edad que sigue creciendo: no reutilizado) en dos instantes; solo gotas (tipo 0), las burbujas suben a propósito
	var antes: Dictionary = {}
	for g in est:
		if int((g as Dictionary)["tipo"]) == 0:
			antes[int(g["hueco"])] = g
	await _esperar(0.12)
	var est2: Array = gotas.call("estados")
	var n_cmp: int = 0
	var suma0: float = 0.0
	var suma1: float = 0.0
	for g2 in est2:
		var h: int = int((g2 as Dictionary)["hueco"])
		if antes.has(h) and float(g2["edad"]) > float(antes[h]["edad"]):
			suma0 += float(antes[h]["vel"].y)
			suma1 += float(g2["vel"].y)
			n_cmp += 1
	_ok("las gotas CAEN: la velocidad vertical media baja (%.2f → %.2f)" % [suma0 / maxf(n_cmp, 1), suma1 / maxf(n_cmp, 1)], n_cmp > 0 and suma1 < suma0)
	# corte: se suelta, avanza y se rompe en gotas
	var id: int = e.get_instance_id()
	e.morir()
	await _esperar(0.4)
	var corte_med: float = e.corte
	var rompe: int = int((gotas.call("estados") as Array).size())
	_ok("corte: a los 0,4 s del morir corte = %.2f (> 0,2) y el shader lo recibe (%.2f); sigue habiendo %d gotas" % [corte_med, _param_haz(e, "Chorro", "corte"), rompe],
		corte_med > 0.2 and absf(_param_haz(e, "Chorro", "corte") - corte_med) < 0.001 and rompe > 0)
	_ok("corte: la punta avanza (%.2f m más allá del largo)" % absf(e._haz_z_punta() + 3.0 * 0.97), e.corte * 0.6 * 3.0 * 0.97 > 0.3)
	await _esperar(0.9)
	_ok("corte: acaba y se libera solo", not is_instance_valid(e) or e.get_instance_id() != id)
	await process_frame


# ------------------------------------------------------------------ 8. pilar ------------------------------------------------------------------

func _dibujos(n: Node) -> int:
	var k: int = 0
	for h in n.find_children("*", "GeometryInstance3D", true, false):
		if (h as GeometryInstance3D).is_visible_in_tree():
			k += 1
	return k


func _alturas_corona(alto: float) -> Array:
	var r: Array = []
	for l in AguaMallas.lenguas_corona(0.5, 0.5, alto):
		r.append(float((l as Dictionary)["h"]))
	return r


func _pilar() -> void:
	print("== pilar / géiser")
	var e: AguaToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 0, 0)
	e.definir(AguaToy.Figura.PILAR, 0.5, 4.0, 0.5, false)
	await process_frame
	_ok("PILAR: cortina + núcleo (tubos), corona (MultiMesh de lenguas), espuma (MultiMesh), charco y reserva de %d gotas" % AguaToy.GOTAS_RESERVA_PILAR,
		e.find_child("Cortina", true, false) is MeshInstance3D and e.find_child("Nucleo", true, false) is MeshInstance3D and e.find_child("Corona", true, false) is MultiMeshInstance3D
		and e.find_child("Espuma", true, false) is MultiMeshInstance3D and e.find_child("Charco", true, false) is MeshInstance3D and e.find_child("Gotas", true, false) != null
		and e.find_child("Marcador", true, false) == null)
	_ok("PILAR: sin luces ni GPUParticles3D", e.find_children("*", "Light3D", true, false).is_empty() and e.find_children("*", "GPUParticles3D", true, false).is_empty())
	var alt: Array = _alturas_corona(4.0)
	var distintas: Dictionary = {}
	var hmin: float = 99.0
	var hmax: float = 0.0
	for h in alt:
		distintas[int(round(float(h) * 5.0))] = true
		hmin = minf(hmin, float(h))
		hmax = maxf(hmax, float(h))
	var corona: MultiMeshInstance3D = e.find_child("Corona", true, false) as MultiMeshInstance3D
	_ok("CORONA: %d lenguas (MultiMesh de %d) de alturas distintas (%d valores, de %.2f a %.2f m)" % [alt.size(), corona.multimesh.instance_count, distintas.size(), hmin, hmax],
		alt.size() >= 10 and corona.multimesh.instance_count == alt.size() and distintas.size() >= 5 and hmax - hmin > 0.8)
	var alt_bajo: Array = _alturas_corona(1.5)
	var hmax2: float = 0.0
	for h2 in alt_bajo:
		hmax2 = maxf(hmax2, float(h2))
	_ok("las lenguas escalan con el alto del pilar (máx %.2f m con alto 1,5 · %.2f m con alto 4)" % [hmax2, hmax], hmax > hmax2 * 1.4)
	# el alto sale del semieje y
	var e2: AguaToy = _nueva()
	await process_frame
	e2.definir(AguaToy.Figura.PILAR, 0.5, 2.0, 0.5, false)
	await process_frame
	_ok("el alto de la cresta sigue al semieje y (%.2f m con y = 4 · %.2f m con y = 2)" % [e.pilar_cresta(), e2.pilar_cresta()], absf(e.pilar_cresta() - 4.0) < 0.01 and absf(e2.pilar_cresta() - 2.0) < 0.01)
	e2.queue_free()
	var m_cortina: ShaderMaterial = (e.find_child("Cortina", true, false) as MeshInstance3D).material_override as ShaderMaterial
	_ok("la cortina recibe el alto y los radios (%.1f, %.2f, %.2f)" % [float(m_cortina.get_shader_parameter("alto")), float(m_cortina.get_shader_parameter("rx")), float(m_cortina.get_shader_parameter("rz"))],
		float(m_cortina.get_shader_parameter("alto")) == 4.0 and float(m_cortina.get_shader_parameter("rx")) == 0.5)
	# NACER: brota rápido con un pico de altura y se asienta; las gotas suben y caen
	e.crece = 0.0
	e.lanzar(-1.0)
	var gotas: Node = e.find_child("Gotas", true, false)
	var cres0: float = e.pilar_cresta()
	var pico: float = 0.0
	var t_pico: float = 0.0
	var cres_a_0_2: float = -1.0
	var sube_vy: Dictionary = {}                   # hueco -> edad de la primera medida con vy > 0
	var sube_cae: int = 0                          # gotas que subían y después van hacia abajo (la MISMA gota: mismo hueco y mayor edad)
	var y_max: float = 0.0
	var dib_max: int = 0
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < 1000.0:
		await process_frame
		_medir()
		dib_max = maxi(dib_max, _dibujos(e))
		var t_s: float = float(Time.get_ticks_msec() - t0) / 1000.0
		var c: float = e.pilar_cresta()
		if c > pico:
			pico = c
			t_pico = t_s
		if cres_a_0_2 < 0.0 and t_s > 0.2:
			cres_a_0_2 = c
		for g in gotas.call("estados"):
			var gd: Dictionary = g
			if int(gd["tipo"]) != 0:
				continue
			var h: int = int(gd["hueco"])
			y_max = maxf(y_max, float((gd["pos"] as Vector3).y))
			if float((gd["vel"] as Vector3).y) > 0.5 and not sube_vy.has(h):
				sube_vy[h] = float(gd["edad"])
			elif sube_vy.has(h) and float(gd["edad"]) > float(sube_vy[h]) and float((gd["vel"] as Vector3).y) < -0.5:
				sube_cae += 1
				sube_vy.erase(h)
	_ok("NACER: empieza a ras de suelo (%.2f m), brota rápido (%.2f m a los 0,2 s) con un pico de altura (%.2f m a los %.2f s, > alto) y se asienta en %.2f m" % [cres0, cres_a_0_2, pico, t_pico, e.pilar_cresta()],
		cres0 < 0.2 and cres_a_0_2 > 2.0 and pico > 4.0 * 1.05 and absf(e.pilar_cresta() - 4.0) < 0.05)
	_ok("las gotas SUBEN desde la cresta (y máx %.2f m) y CAEN (la misma gota pasa de vy > 0,5 a vy < -0,5: %d)" % [y_max, sube_cae], y_max > 3.0 and sube_cae >= 2)
	var corona_mat: ShaderMaterial = (e.find_child("Corona", true, false) as MultiMeshInstance3D).material_override as ShaderMaterial
	_ok("la corona está subida (subida %.2f) y algo curvada (curva %.2f)" % [float(corona_mat.get_shader_parameter("subida")), float(corona_mat.get_shader_parameter("curva"))],
		float(corona_mat.get_shader_parameter("subida")) > 0.95 and float(corona_mat.get_shader_parameter("curva")) > 0.1)
	var esp: Array = e._pil_esp_datos
	var base_v: int = 0
	var cresta_v: int = 0
	for i in esp.size():
		if float((esp[i] as Dictionary)["alfa"]) > 0.1:
			if i < AguaToy.N_ESPUMA_BASE:
				base_v += 1
			else:
				cresta_v += 1
	_ok("espuma blanca en la base (%d bocanadas) y en la cresta (%d)" % [base_v, cresta_v], base_v >= 6 and cresta_v >= 2)
	# la espuma de la cresta sube con la cresta
	var yc: float = float((esp[AguaToy.N_ESPUMA_BASE] as Dictionary)["pos"].y)
	_ok("la espuma de la cresta está arriba (%.2f m) y la de la base abajo (%.2f m)" % [yc, float((esp[0] as Dictionary)["pos"].y)], yc > 3.5 and float((esp[0] as Dictionary)["pos"].y) < 0.6)
	# MORIR: se desploma y deja el charco, que se desvanece; se libera solo
	var id: int = e.get_instance_id()
	e.morir()
	t0 = Time.get_ticks_msec()
	var prev: float = e.pilar_cresta()
	var sube: bool = false
	var charco_al_caer: float = -1.0
	var cresta_700: float = -1.0
	var u_charco_max: float = 0.0
	var gotas_caida: int = 0
	while is_instance_valid(e) and e.get_instance_id() == id and float(Time.get_ticks_msec() - t0) < 2500.0:
		await process_frame
		_medir()
		if not is_instance_valid(e):
			break
		var c2: float = e.pilar_cresta()
		if c2 > prev + 0.02:
			sube = true
		prev = c2
		var t_m: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if cresta_700 < 0.0 and t_m > 0.7:
			cresta_700 = c2
		u_charco_max = maxf(u_charco_max, e._pil_charco_u)
		if charco_al_caer < 0.0 and c2 < 0.6:
			var u: float = e._pil_charco_u
			charco_al_caer = smoothstep(0.0, 0.05, u) * (1.0 - smoothstep(0.78, 1.0, u))        # la misma fórmula de agua_onda.gdshader con se_va = 0,78
		gotas_caida = maxi(gotas_caida, (gotas.call("estados") as Array).size() if is_instance_valid(gotas) else 0)
	_ok("MORIR: la columna cae sin volver a subir y a los 0,7 s mide %.2f m (< 1,2 m de 4)" % cresta_700, not sube and cresta_700 >= 0.0 and cresta_700 < 1.2)
	_ok("MORIR deja un charco que se ensancha (u hasta %.2f) y que sigue visible cuando la columna ya ha caído (opacidad %.2f)" % [u_charco_max, charco_al_caer], u_charco_max > 0.7 and charco_al_caer > 0.3)
	_ok("MORIR: al desplomarse se sueltan gotas (%d a la vez)" % gotas_caida, gotas_caida >= 4)
	_ok("PILAR: se libera solo al acabar de morir", not is_instance_valid(e) or e.get_instance_id() != id)
	print("   PILAR: %d dibujos visibles a la vez (cortina, núcleo, charco, corona, espuma, gotas)" % dib_max)
	_ok("PILAR: ≤ 7 dibujos", dib_max <= 7)
	await process_frame


# ------------------------------------------------------------------ paleta central ------------------------------------------------------------------

func _vec3_de(txt: String, nombre: String) -> Color:
	var rx: RegEx = RegEx.new()
	rx.compile("uniform vec3 " + nombre + "\\b[^=]*=\\s*vec3\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*\\)")
	var r: RegExMatch = rx.search(txt)
	if r == null:
		return Color(-1, -1, -1)
	return Color(float(r.get_string(1)), float(r.get_string(2)), float(r.get_string(3)))


func _colores_iguales(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.0015 and absf(a.g - b.g) < 0.0015 and absf(a.b - b.b) < 0.0015


func _sombreados(n: Node) -> Array:
	var r: Array = []
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		var m: ShaderMaterial = (g as GeometryInstance3D).material_override as ShaderMaterial
		while m != null:
			r.append(m)
			m = m.next_pass as ShaderMaterial
	return r


## REGLA DE PABLO: el agua de hechizo toma los colores del agua del mundo. La paleta vive en agua_paleta.gd; los shaders llevan los mismos valores por defecto y todos los materiales los reciben.
func _paleta() -> void:
	print("== paleta (agua del mundo)")
	var mundo: String = FileAccess.get_file_as_string("res://presentacion/agua_render_3d.gd")
	_ok("paleta: los valores son los del agua del mundo (somero, hondo, espuma, cáusticas, lecho, tinte de fresnel)",
		_colores_iguales(_vec3_de(mundo, "color_somero_est"), AguaPaleta.SOMERO) and _colores_iguales(_vec3_de(mundo, "color_hondo_est"), AguaPaleta.HONDO)
		and _colores_iguales(_vec3_de(mundo, "color_espuma"), AguaPaleta.ESPUMA) and _colores_iguales(_vec3_de(mundo, "color_causticas"), AguaPaleta.CAUSTICAS)
		and _colores_iguales(_vec3_de(mundo, "color_lecho"), AguaPaleta.LECHO) and mundo.contains("vec3(0.88, 0.94, 1.0)") and _colores_iguales(Color(0.88, 0.94, 1.0), AguaPaleta.FRESNEL))
	var inc: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/agua_toy.gdshaderinc")
	var gota: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/agua_gota.gdshader")
	_ok("paleta: los defaults de agua_toy.gdshaderinc son los de la paleta central",
		_colores_iguales(_vec3_de(inc, "tono_a"), AguaPaleta.HONDO) and _colores_iguales(_vec3_de(inc, "tono_b"), AguaPaleta.SOMERO) and _colores_iguales(_vec3_de(inc, "tono_c"), AguaPaleta.ESPUMA)
		and _colores_iguales(_vec3_de(inc, "color_causticas"), AguaPaleta.CAUSTICAS) and _colores_iguales(_vec3_de(inc, "color_lecho"), AguaPaleta.LECHO) and _colores_iguales(_vec3_de(inc, "tinte_fresnel"), AguaPaleta.FRESNEL))
	_ok("paleta: los defaults de agua_gota.gdshader (no incluye el .gdshaderinc) son los de la paleta central",
		_colores_iguales(_vec3_de(gota, "tono_a"), AguaPaleta.HONDO) and _colores_iguales(_vec3_de(gota, "tono_b"), AguaPaleta.SOMERO) and _colores_iguales(_vec3_de(gota, "tono_c"), AguaPaleta.ESPUMA))
	# ningún shader de agua lleva un azul propio: todos los vec3 con color son los de la paleta (la lista de shaders de cuerpo no tiene vec3(r, g, b) sueltos)
	var sueltos: int = 0
	for s in SHADERS:
		var txt: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/" + s)
		if s != "agua_toy.gdshaderinc" and s != "agua_gota.gdshader":
			var rx: RegEx = RegEx.new()
			rx.compile("vec3\\(\\s*[0-9.]+\\s*,\\s*[0-9.]+\\s*,\\s*[0-9.]+\\s*\\)")
			for r in rx.search_all(txt):
				var v: String = (r as RegExMatch).get_string()
				if v != "vec3(0.0, 0.0, 1.0)" and v != "vec3(0.0, 1.0, 0.0)" and v != "vec3(0.0, 0.0, 0.0)" and v != "vec3(1.0, 0.0, 0.0)":
					sueltos += 1
	_ok("paleta: ningún shader de cuerpo lleva colores vec3(r, g, b) propios (%d)" % sueltos, sueltos == 0)
	# todos los materiales de todas las figuras
	var figs: Array = [[AguaToy.Figura.BOLA, 0.4, 0.4, 0.4, true], [AguaToy.Figura.HAZ, 1.5, 0.5, 0.15, false], [AguaToy.Figura.PILAR, 0.5, 4.0, 0.5, false], [AguaToy.Figura.MURO, 3.45, 1.5, 0.3, false]]
	var mats: int = 0
	var malos: Array = []
	var sprites: int = 0
	var rampas_ok: bool = true
	for f in figs:
		var e: AguaToy = _nueva()
		await process_frame
		e.definir(int(f[0]), f[1], f[2], f[3], bool(f[4]))
		await process_frame
		await process_frame
		var lista: Array = _sombreados(e)
		var gt: Node = e.find_child("Gotas", true, false)
		if gt != null:
			lista.append_array(_sombreados(gt))
		for m in lista:
			var sm: ShaderMaterial = m
			if sm.shader == null:
				continue
			var nombres: Array = []
			for u in sm.shader.get_shader_uniform_list():
				nombres.append(String((u as Dictionary)["name"]))
			if nombres.has("tono_a"):
				mats += 1
				for par in AguaPaleta.uniforms():
					if nombres.has(String(par)):
						var val = sm.get_shader_parameter(par)
						var ref = AguaPaleta.uniforms()[par]
						var igual: bool = (val is Color and _colores_iguales(val, ref)) or (val is float and absf(val - float(ref)) < 0.001)
						if not igual and not (val == null and par in ["tono_a", "tono_b", "tono_c"] and gt != null):
							malos.append("%s:%s" % [sm.shader.resource_path.get_file(), par])
			var rp = sm.get_shader_parameter("rampa")
			if rp is GradientTexture1D:
				sprites += 1
				var gr: Gradient = (rp as GradientTexture1D).gradient
				if not (_colores_iguales(gr.get_color(0), AguaPaleta.HONDO) and _colores_iguales(gr.get_color(gr.get_point_count() - 1), AguaPaleta.ESPUMA)):
					rampas_ok = false
		e.queue_free()
		await process_frame
	var imp: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.AREA, Vector3.UP, 1.8)
	_raiz.add_child(imp)
	await process_frame
	var lista_i: Array = _sombreados(imp)
	lista_i.append_array(_sombreados(imp.find_child("Gotas", true, false)))
	for m2 in lista_i:
		var sm2: ShaderMaterial = m2
		if sm2.shader != null and (sm2.shader.get_shader_uniform_list().any(func(u): return String((u as Dictionary)["name"]) == "tono_a")):
			mats += 1
			var v2 = sm2.get_shader_parameter("tono_a")
			if not (v2 is Color and _colores_iguales(v2, AguaPaleta.HONDO)):
				malos.append("impacto:" + sm2.shader.resource_path.get_file())
		var rp2 = sm2.get_shader_parameter("rampa")
		if rp2 is GradientTexture1D:
			sprites += 1
	imp.queue_free()
	await process_frame
	var cg: Node3D = AguaGotas_crear_mm()
	_ok("paleta: %d materiales de agua (esfera, cintas, ondas, haz, pilar, láminas, espuma, franjas, ola, gotas, impacto) con los tonos de la paleta; discrepancias: %s" % [mats, str(malos)], mats >= 25 and malos.is_empty())
	_ok("paleta: %d sprites recoloreados (lámina, abanico, vaho) con la rampa hondo → espuma de la paleta" % sprites, sprites >= 2 and rampas_ok)
	_ok("paleta: AguaMallas.rampa_sprites() va de hondo a espuma", _colores_iguales(AguaMallas.rampa_sprites().gradient.get_color(0), AguaPaleta.HONDO) and _colores_iguales(AguaMallas.rampa_sprites().gradient.get_color(3), AguaPaleta.ESPUMA))
	if cg != null:
		cg.queue_free()


func AguaGotas_crear_mm() -> Node3D:
	var g = load("res://presentacion/vfx/toy/agua_gotas.gd")
	var mi: MultiMeshInstance3D = g.crear_mm("Prueba", 4)
	var m: ShaderMaterial = mi.material_override as ShaderMaterial
	_ok("paleta: las gotas (AguaGotas.crear_mm) reciben tono_a / tono_b / tono_c de la paleta", _colores_iguales(m.get_shader_parameter("tono_a"), AguaPaleta.HONDO) and _colores_iguales(m.get_shader_parameter("tono_b"), AguaPaleta.SOMERO) and _colores_iguales(m.get_shader_parameter("tono_c"), AguaPaleta.ESPUMA))
	return mi


# ------------------------------------------------------------------ lenguas con curva propia ------------------------------------------------------------------

func _lenguas() -> void:
	print("== lenguas (corona del géiser y explosión de área)")
	var lista: Array = AguaMallas.lenguas_corona(0.5, 0.5, 4.0)
	var k1s: Dictionary = {}
	var k2s: Dictionary = {}
	for l in lista:
		var sem: float = float((l as Dictionary)["sem"])
		k1s[int(floor(fposmod(sem * 1.7, 1.0) * 5.0))] = true
		k2s[int(floor(fposmod(sem * 2.9, 1.0) * 5.0))] = true
	_ok("lenguas: la corona tiene %d lenguas con curvas propias distintas (%d valores de curva hacia fuera, %d de caída de la punta)" % [lista.size(), k1s.size(), k2s.size()], lista.size() >= 10 and k1s.size() >= 4 and k2s.size() >= 4)
	var sh: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/agua_lamina.gdshader")
	_ok("lenguas: el vertex shader curva y deja caer cada punta con factores de SU semilla, con la punta doblada hacia fuera", sh.contains("fract(v_sem * 1.7)") and sh.contains("fract(v_sem * 2.9)") and sh.contains("hacia * (vy * vy * vy") and sh.contains("pos.y -= vy * vy * vy"))
	_ok("lenguas: hombro grueso, punta redondeada y espuma en el borde (franja `borde` que llega al tono de espuma)", sh.contains("hw = max(hw, 0.075") and sh.contains("0.62 * borde * forma") and sh.contains("pow(vy, 1.45 + 0.9 * k1)"))
	var corona: MultiMeshInstance3D = AguaMallas.lenguas_mm("Prueba", lista)
	var filas_malla: int = corona.multimesh.mesh.get_surface_count()
	_ok("lenguas: la malla de cada lengua tiene filas para doblarse (>= 14 divisiones: %d vértices por lengua)" % (corona.multimesh.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), filas_malla == 1 and (corona.multimesh.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() >= 5 * 15)
	corona.queue_free()
	# la espuma de la base del géiser son FRANJAS (quads tumbados y alargados), no bolas
	var e: AguaToy = _nueva()
	await process_frame
	e.definir(AguaToy.Figura.PILAR, 0.5, 4.0, 0.5, false)
	await process_frame
	await process_frame
	var fra: MultiMeshInstance3D = e.find_child("Franjas", true, false) as MultiMeshInstance3D
	var esp: MultiMeshInstance3D = e.find_child("Espuma", true, false) as MultiMeshInstance3D
	_ok("géiser: la base lleva %d franjas de espuma (agua_franja) y la cresta solo %d bocanadas (antes 10 bolas en la base)" % [fra.multimesh.instance_count if fra != null else 0, esp.multimesh.instance_count],
		fra != null and fra.multimesh.instance_count == AguaToy.N_ESPUMA_BASE and esp.multimesh.instance_count == AguaToy.N_ESPUMA_CRESTA
		and (fra.material_override as ShaderMaterial).shader.resource_path.ends_with("agua_franja.gdshader"))
	await create_timer(1.0).timeout
	var largas: int = 0
	for d in e._pil_esp_datos.slice(0, AguaToy.N_ESPUMA_BASE):
		var largo: float = float((d as Dictionary)["tam"])
		if largo > 0.3 and float((d as Dictionary)["alfa"]) > 0.1:
			largas += 1
	_ok("géiser: las %d franjas de la base son largas (> 0,3 m) y visibles" % largas, largas >= 8)
	_ok("géiser: las franjas son quads tumbados (FACE_Y)", (fra.multimesh.mesh as QuadMesh).orientation == PlaneMesh.FACE_Y)
	e.queue_free()
	await process_frame


# ------------------------------------------------------------------ OLA (fase 4) ------------------------------------------------------------------

func _ola() -> void:
	print("== ola (figura MURO)")
	var e: AguaToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 0, 0)
	e.definir(AguaToy.Figura.MURO, 3.45, 1.5, 0.3, false)
	await process_frame
	await process_frame
	_ok("OLA: 3 cortinas, masa y cresta (MultiMesh de láminas Y-billboard), franjas, charco y reserva de %d gotas; ya no es el marcador" % AguaToy.GOTAS_RESERVA_OLA,
		e.find_children("Ola*", "MeshInstance3D", true, false).size() == 3 and e.find_child("Masa", true, false) is MultiMeshInstance3D and e.find_child("Cresta", true, false) is MultiMeshInstance3D
		and e.find_child("Franjas", true, false) is MultiMeshInstance3D and e.find_child("Charco", true, false) is MeshInstance3D and e.find_child("Gotas", true, false) != null and e.find_child("Marcador", true, false) == null)
	_ok("OLA: sin luces ni GPUParticles3D", e.find_children("*", "Light3D", true, false).is_empty() and e.find_children("*", "GPUParticles3D", true, false).is_empty())
	var ad: int = 0
	for m in _sombreados(e):
		if (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.code.contains("blend_add"):
			ad += 1
	_ok("OLA: 0 materiales aditivos (todo blend_mix)", ad == 0)
	# varias filas de profundidad (de canto no es una raya)
	var lam: Array = AguaMallas.ola_laminas(3.45, 0.3, 1.5, true)
	var zs: Dictionary = {}
	for l in lam:
		zs[snappedf(float((l as Dictionary)["z"]), 0.01)] = true
	var cre: Array = AguaMallas.ola_laminas(3.45, 0.3, 1.5, false)
	var zc: Dictionary = {}
	for l in cre:
		zc[snappedf(float((l as Dictionary)["z"]), 0.01)] = true
	var zmin: float = 99.0
	var zmax: float = -99.0
	for z in zs:
		zmin = minf(zmin, float(z))
		zmax = maxf(zmax, float(z))
	_ok("OLA: el cuerpo (%d láminas) está en %d filas de profundidad (z de %.2f a %.2f m) y la cresta (%d láminas) en %d" % [lam.size(), zs.size(), zmin, zmax, cre.size(), zc.size()], zs.size() >= 4 and zc.size() >= 3 and zmax - zmin > 0.8 and lam.size() >= 30)
	_ok("OLA: ancho x = 3,45 (las láminas llegan a x = ±%.2f), alto y = 1,5, fondo z" % (lam.map(func(l): return absf(float((l as Dictionary)["x"]))).max()), lam.map(func(l): return absf(float((l as Dictionary)["x"]))).max() > 3.0)
	# NACER: sube desde el suelo
	e.crece = 0.0
	e.corte = 0.0
	e.lanzar(-1.0)
	var gotas: Node = e.find_child("Gotas", true, false)
	var h0: float = e.ola_altura()
	var h_03: float = -1.0
	var sube_siempre: bool = true
	var prev: float = h0
	var dib_max: int = 0
	var sube_vy: Dictionary = {}
	var sube_cae: int = 0
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < 1100.0:
		await process_frame
		_medir()
		dib_max = maxi(dib_max, _dibujos(e))
		var t_s: float = float(Time.get_ticks_msec() - t0) / 1000.0
		var h: float = e.ola_altura()
		if h < prev - 0.001 and t_s < 0.75:
			sube_siempre = false
		prev = h
		if h_03 < 0.0 and t_s > 0.3:
			h_03 = h
		for g in gotas.call("estados"):
			var gd: Dictionary = g
			var hu: int = int(gd["hueco"])
			if float((gd["vel"] as Vector3).y) > 0.5 and not sube_vy.has(hu):
				sube_vy[hu] = float(gd["edad"])
			elif sube_vy.has(hu) and float(gd["edad"]) > float(sube_vy[hu]) and float((gd["vel"] as Vector3).y) < -0.5:
				sube_cae += 1
				sube_vy.erase(hu)
	_ok("OLA NACER: empieza a ras de suelo (%.2f m), sube sin bajar (%s), a los 0,3 s mide %.2f m y se asienta en %.2f m (alto 1,5)" % [h0, str(sube_siempre), h_03, e.ola_altura()],
		h0 < 0.05 and sube_siempre and h_03 > 0.2 and h_03 < 1.3 and absf(e.ola_altura() - 1.5) < 0.05)
	_ok("OLA: de la cresta saltan gotas que CAEN (la misma gota pasa de vy > 0,5 a vy < -0,5: %d)" % sube_cae, sube_cae >= 2)
	# VIVIR: avanza un poco y se mantiene a su altura
	var av0: float = e.ola_avance()
	var hv_min: float = 99.0
	var hv_max: float = 0.0
	t0 = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < 1400.0:
		await process_frame
		_medir()
		hv_min = minf(hv_min, e.ola_altura())
		hv_max = maxf(hv_max, e.ola_altura())
	var av1: float = e.ola_avance()
	_ok("OLA VIVIR: avanza un poco (%.2f → %.2f m, nunca más de 0,6 m) y mantiene su altura (%.2f - %.2f m)" % [av0, av1, hv_min, hv_max], av1 > av0 + 0.03 and av1 < 0.6 and hv_min > 1.45 and hv_max < 1.55)
	var m_ola: ShaderMaterial = (e.find_child("Ola1", true, false) as MeshInstance3D).material_override as ShaderMaterial
	_ok("OLA: la cortina recibe a, b, alto y el avance (%.2f, %.2f, %.2f, %.2f)" % [float(m_ola.get_shader_parameter("a")), float(m_ola.get_shader_parameter("b")), float(m_ola.get_shader_parameter("alto")), float(m_ola.get_shader_parameter("avance"))],
		float(m_ola.get_shader_parameter("a")) == 3.45 and float(m_ola.get_shader_parameter("alto")) == 1.5 and float(m_ola.get_shader_parameter("avance")) > 0.05)
	var cuerpo_mat: ShaderMaterial = (e.find_child("Masa", true, false) as MultiMeshInstance3D).material_override as ShaderMaterial
	_ok("OLA: las láminas llevan el avance y su estado (crece %.2f, avance %.2f)" % [float(cuerpo_mat.get_shader_parameter("crece")), float(cuerpo_mat.get_shader_parameter("avance"))], float(cuerpo_mat.get_shader_parameter("crece")) == 1.0 and float(cuerpo_mat.get_shader_parameter("avance")) > 0.05)
	var fr: Array = e._ola_franjas_datos
	var fr_v: int = 0
	for d in fr:
		if float((d as Dictionary)["alfa"]) > 0.3:
			fr_v += 1
	_ok("OLA: espuma en franjas en el pie (%d visibles)" % fr_v, fr_v >= 8)
	# MORIR: cae hacia delante y deja un charco ancho que se desvanece
	var id: int = e.get_instance_id()
	e.morir()
	t0 = Time.get_ticks_msec()
	prev = e.ola_altura()
	var sube: bool = false
	var incl_max: float = 0.0
	var u_max: float = 0.0
	var charco_vis_baja: float = -1.0
	var h_07: float = -1.0
	var gotas_cae: int = 0
	var u_fin: float = 0.0
	while is_instance_valid(e) and e.get_instance_id() == id and float(Time.get_ticks_msec() - t0) < 3000.0:
		await process_frame
		_medir()
		if not is_instance_valid(e):
			break
		var t_m: float = float(Time.get_ticks_msec() - t0) / 1000.0
		var h2: float = e.ola_altura()
		if h2 > prev + 0.02:
			sube = true
		prev = h2
		incl_max = maxf(incl_max, e.ola_inclinacion())
		u_max = maxf(u_max, e.ola_charco_u())
		u_fin = e.ola_charco_u()
		if h_07 < 0.0 and t_m > 1.1:
			h_07 = h2
		if charco_vis_baja < 0.0 and h2 < 0.5:
			var u: float = e.ola_charco_u()
			charco_vis_baja = smoothstep(0.0, 0.05, u) * (1.0 - smoothstep(0.9, 1.0, u))      # la misma fórmula de agua_onda.gdshader con se_va = 0,9
		gotas_cae = maxi(gotas_cae, (gotas.call("estados") as Array).size() if is_instance_valid(gotas) else 0)
	_ok("OLA MORIR: cae sin volver a subir (%s), a los 1,1 s mide %.2f m (< 1 m de 1,5)" % [str(not sube), h_07], not sube and h_07 >= 0.0 and h_07 < 1.0)
	_ok("OLA MORIR: cae HACIA DELANTE (la cabeza se adelanta %.2f m respecto al pie; > 0,25 m)" % incl_max, incl_max > 0.25)
	_ok("OLA MORIR: deja un charco ancho (u hasta %.2f; semiancho %.1f m) visible cuando la ola ya ha caído a < 0,5 m (opacidad %.2f) y que se desvanece al final (opacidad %.2f)" % [u_max, 3.45 + 0.7, charco_vis_baja, smoothstep(0.0, 0.05, u_fin) * (1.0 - smoothstep(0.9, 1.0, u_fin))], u_max > 0.8 and charco_vis_baja > 0.5 and smoothstep(0.0, 0.05, u_fin) * (1.0 - smoothstep(0.9, 1.0, u_fin)) < 0.3)
	_ok("OLA MORIR: al caer salpica (%d gotas a la vez)" % gotas_cae, gotas_cae >= 6)
	_ok("OLA: se libera sola al acabar de morir", not is_instance_valid(e) or e.get_instance_id() != id)
	print("   OLA: %d dibujos visibles a la vez (3 cortinas, cuerpo, cresta, franjas, charco, gotas)" % dib_max)
	_ok("OLA: ≤ 10 dibujos", dib_max <= 10)
	await process_frame

# ------------------------------------------------------------------ 9. explosión de área ------------------------------------------------------------------

func _area() -> void:
	print("== explosión de área")
	var imp: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.AREA, Vector3.UP, 1.8)
	_raiz.add_child(imp)
	imp.global_position = Vector3(0, 0, 0)
	await process_frame
	var lam: Node = imp.find_child("Lenguas", true, false)
	_ok("AREA: estallido (Lamina), lenguas (MultiMesh), espuma (MultiMesh), 5 charquitos, charco grande y gotas", imp.find_child("Lamina", true, false) != null and lam is MultiMeshInstance3D
		and imp.find_child("Espuma", true, false) is MultiMeshInstance3D and imp.find_children("Charquito*", "MeshInstance3D", true, false).size() == 5 and imp.find_child("Charco", true, false) != null
		and imp.find_child("Gotas", true, false) != null)
	_ok("AREA: sin luces ni GPUParticles3D", imp.find_children("*", "Light3D", true, false).is_empty() and imp.find_children("*", "GPUParticles3D", true, false).is_empty())
	var n_l: int = imp.lenguas_area().size()
	var hmax: float = 0.0
	for l in imp.lenguas_area():
		hmax = maxf(hmax, float((l as Dictionary)["h"]))
	_ok("AREA: %d lenguas en 5 columnas, la más alta de %.2f m (≈ radio 1,8)" % [n_l, hmax], n_l >= 18 and hmax > 1.5 and hmax < 2.6 and (lam as MultiMeshInstance3D).multimesh.instance_count == n_l)
	var rc: Array = imp.recuento_gotas()
	_ok("AREA: %d gotas y %d burbujas" % [rc[0], rc[1]], int(rc[0]) >= 50)
	# (a) estallido 0-0,3 s
	var lamina: MeshInstance3D = imp.find_child("Lamina", true, false) as MeshInstance3D
	imp.avanzar_a(0.1)
	var vida_a: float = float(SpriteToy_mat(lamina).get_shader_parameter("vida"))
	var tam_a: float = lamina.scale.x
	imp.avanzar_a(0.3)
	var vida_b: float = float(SpriteToy_mat(lamina).get_shader_parameter("vida"))
	_ok("FASE A (0 - 0,3 s): el estallido blanco-celeste está a los 0,1 s (opacidad %.2f, %.2f m) y ya no a los 0,3 s (%.2f; más pequeño y corto que antes: agua y espuma, no estrella)" % [vida_a, tam_a, vida_b], vida_a > 0.3 and tam_a > 0.8 and tam_a < 4.0 and vida_b < 0.02)
	# (b) columnas que suben 0,1-0,55 s
	var a05: float = imp.area_alto_lenguas(0.05)
	var a20: float = imp.area_alto_lenguas(0.2)
	var a35: float = imp.area_alto_lenguas(0.35)
	var a60: float = imp.area_alto_lenguas(0.6)
	_ok("FASE B (0,1 - 0,55 s): las lenguas SUBEN (alto %.2f → %.2f → %.2f → %.2f m a 0,05 / 0,2 / 0,35 / 0,6 s)" % [a05, a20, a35, a60], a05 < 0.1 and a20 > a05 and a35 > a20 and a60 > a35 and a60 > 1.5)
	# (c) se curvan hacia fuera 0,45-0,95 s y caen 0,8-1,45 s
	var c30: float = imp.area_curva_fuera(0.3)
	var c70: float = imp.area_curva_fuera(0.7)
	var c110: float = imp.area_curva_fuera(1.1)
	var a100: float = imp.area_alto_lenguas(1.0)
	var a150: float = imp.area_alto_lenguas(1.5)
	_ok("FASE C (0,45 - 0,95 s): las puntas se curvan hacia fuera (%.2f → %.2f → %.2f m) y después CAEN (alto %.2f m a 1,0 s y %.2f m a 1,5 s)" % [c30, c70, c110, a100, a150],
		c30 < 0.15 and c70 > c30 + 0.15 and c110 > c70 and a100 < a60 and a150 < 0.2 * a60)
	var u05: float = ImpactoAguaToy.area_u_charco(0.5)
	var u10: float = ImpactoAguaToy.area_u_charco(1.0)
	imp.avanzar_a(1.0)
	var pool_u: float = float(((imp.find_child("Charco", true, false) as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("u"))
	_ok("FASE D (0,6 - 1,7 s): el charco grande no existe a los 0,5 s (u %.2f), se ensancha (u %.2f a 1,0 s) y el shader lo recibe (%.2f)" % [u05, u10, pool_u], u05 < 0.01 and u10 > 0.3 and absf(pool_u - u10) < 0.001)
	# gotas: tandas (a) hacia arriba al principio y (c) hacia fuera hacia los 0,8 s; todas caen
	var g02: Array = imp.gotas_estado(0.2)
	var g12: Array = imp.gotas_estado(1.2)
	var sube_ini: int = 0
	var lejos_fin: int = 0
	var viva_02: int = 0
	var viva_12: int = 0
	for g in g02:
		if bool((g as Dictionary)["vivo"]) and not bool((g as Dictionary)["burbuja"]):
			viva_02 += 1
			if float((g as Dictionary)["altura"]) > 0.4:
				sube_ini += 1
	for g in g12:
		if bool((g as Dictionary)["vivo"]) and not bool((g as Dictionary)["burbuja"]):
			viva_12 += 1
			var p: Vector3 = (g as Dictionary)["pos"]
			if Vector2(p.x, p.z).length() > 0.9:
				lejos_fin += 1
	_ok("gotas: a los 0,2 s hay %d vivas y %d ya a más de 0,4 m de altura (estallido); a los 1,2 s hay %d y %d a más de 0,9 m del centro (corona hacia fuera)" % [viva_02, sube_ini, viva_12, lejos_fin],
		viva_02 >= 15 and sube_ini >= 8 and viva_12 >= 8 and lejos_fin >= 6)
	var cae: int = 0
	var cae_t: int = 0
	var ga: Array = imp.gotas_estado(1.0)
	var gb: Array = imp.gotas_estado(1.2)
	for i in ga.size():
		if bool((ga[i] as Dictionary)["vivo"]) and bool((gb[i] as Dictionary)["vivo"]) and not bool((ga[i] as Dictionary)["burbuja"]):
			cae_t += 1
			if float((gb[i] as Dictionary)["vy"]) < float((ga[i] as Dictionary)["vy"]) - 0.5:
				cae += 1
	_ok("las gotas CAEN con la gravedad (%d de %d bajan su velocidad vertical)" % [cae, cae_t], cae_t > 5 and cae == cae_t)
	var bajo: int = 0
	for t in [0.05, 0.3, 0.6, 1.0, 1.4]:
		for g in imp.gotas_estado(t):
			if bool((g as Dictionary)["vivo"]) and float((g as Dictionary)["altura"]) < -0.006:
				bajo += 1
	_ok("ninguna gota por debajo del suelo", bajo == 0)
	# espuma
	imp.avanzar_a(0.15)
	var esp_a: int = 0
	for d in imp.espuma_area_datos():
		if float((d as Dictionary)["alfa"]) > 0.1:
			esp_a += 1
	_ok("espuma del estallido a los 0,15 s (%d bocanadas)" % esp_a, esp_a >= 5)
	var dib: int = _dibujos(imp)
	print("   AREA: %d dibujos visibles a la vez (estallido, lenguas, espuma, 5 charquitos, charco, gotas)" % dib)
	_ok("AREA: ≤ 12 dibujos", dib <= 12)
	# escala con el radio
	var p_chico: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.AREA, Vector3.UP, 0.9)
	var p_grande: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.AREA, Vector3.UP, 2.7)
	_raiz.add_child(p_chico)
	_raiz.add_child(p_grande)
	await process_frame
	var h_c: float = p_chico.area_alto_lenguas(0.6)
	var h_g: float = p_grande.area_alto_lenguas(0.6)
	var d_c: float = 0.0
	var d_g: float = 0.0
	for g in p_chico.gotas_estado(1.1):
		if bool((g as Dictionary)["vivo"]):
			d_c = maxf(d_c, Vector2((g["pos"] as Vector3).x, (g["pos"] as Vector3).z).length())
	for g in p_grande.gotas_estado(1.1):
		if bool((g as Dictionary)["vivo"]):
			d_g = maxf(d_g, Vector2((g["pos"] as Vector3).x, (g["pos"] as Vector3).z).length())
	var esc_charco: float = (p_grande.find_child("Charco", true, false) as MeshInstance3D).scale.x / (p_chico.find_child("Charco", true, false) as MeshInstance3D).scale.x
	_ok("escala con el radio: lenguas %.2f → %.2f m (×%.1f), alcance de las gotas %.2f → %.2f m, charco ×%.1f (radio ×3)" % [h_c, h_g, h_g / maxf(h_c, 0.001), d_c, d_g, esc_charco],
		h_g > h_c * 2.6 and h_g < h_c * 3.4 and d_g > d_c * 1.6 and absf(esc_charco - 3.0) < 0.05)
	p_chico.queue_free()
	p_grande.queue_free()
	# se libera sola
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(imp) and float(Time.get_ticks_msec() - t0) < 3200.0:
		await process_frame
		_medir()
	_ok("AREA: se libera sola (dura %.1f s)" % imp.duracion() if is_instance_valid(imp) else "AREA: se libera sola", not is_instance_valid(imp))
	# AguaToy: explotar_area, area_al_impactar y desde_hechizo
	var e: AguaToy = _nueva()
	await process_frame
	var a: Node3D = e.explotar_area(Vector3(0, 0, -3), 1.5)
	_ok("AguaToy.explotar_area(pos, radio) crea la variante AREA con ese radio", a is ImpactoAguaToy and (a as ImpactoAguaToy).variante == ImpactoAguaToy.Variante.AREA and is_equal_approx((a as ImpactoAguaToy).radio, 1.5))
	_limpiar_impactos()
	e.area_al_impactar = true
	var a2: Node3D = e.impactar_en(Vector3(0, 0, -3), Vector3.UP, 1.2)
	_ok("con area_al_impactar, impactar_en explota en AREA", a2 is ImpactoAguaToy and (a2 as ImpactoAguaToy).variante == ImpactoAguaToy.Variante.AREA)
	await _esperar(0.3)
	_limpiar_impactos()
	var zona: Hechizo = Hechizo.new()
	zona.semieje_x = 0.4
	zona.semieje_y = 0.4
	zona.semieje_z = 0.4
	var ez: AguaToy = _nueva()
	await process_frame
	ez.desde_hechizo(zona)
	var proy: Hechizo = Hechizo.new()
	proy.semieje_x = 0.3
	proy.semieje_y = 0.3
	proy.semieje_z = 0.3
	proy.velocidad = 8.0
	var ep: AguaToy = _nueva()
	await process_frame
	ep.desde_hechizo(proy)
	_ok("desde_hechizo: una zona esférica (no viaja) explota en área; un proyectil, no", ez.area_al_impactar and not ep.area_al_impactar)
	ez.queue_free()
	ep.queue_free()
	await process_frame


func SpriteToy_mat(mi: MeshInstance3D) -> ShaderMaterial:
	return mi.material_override as ShaderMaterial


# ------------------------------------------------------------------ 7. lab ------------------------------------------------------------------

func _lab() -> void:
	print("== lab: Z alterna el elemento")
	var src: String = FileAccess.get_file_as_string("res://laboratorios/lab_vfx_comparativa_3d.gd")
	_ok("el lab tiene la tecla Z", src.find("KEY_Z: alternar_elemento()") >= 0)
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	_ok("el lab empieza en fuego", String(lab.get("elemento")) == "fuego")
	lab.call("alternar_elemento")
	_ok("Z → agua", String(lab.get("elemento")) == "agua")
	var e: Node3D = lab.call("carga_completa")
	_ok("G con agua crea un AguaToy", e is AguaToy)
	var ip: Node3D = lab.call("impacto_pared")
	var isu: Node3D = lab.call("impacto_suelo")
	_ok("B y N con agua crean ImpactoAguaToy", ip is ImpactoAguaToy and isu is ImpactoAguaToy)
	var m: Node3D = lab.call("lanzar_proyectil", "fin")
	var rb: Node3D = lab.call("lanzar_proyectil", "rebote")
	_ok("M y R con agua crean AguaToy", m is AguaToy and rb is AguaToy)
	var fp: Node3D = lab.call("fuego_param", 0)
	_ok("F7 con agua crea un AguaToy BOLA", fp is AguaToy and int(fp.get("figura")) == 0)
	lab.call("eje_param", 0, 1)
	await process_frame
	_ok("el eje U cambia el semieje del AguaToy", float(fp.get("semieje_x")) > 0.45)
	lab.call("limpiar")
	lab.call("alternar_elemento")
	_ok("Z → fuego otra vez", String(lab.get("elemento")) == "fuego")
	var ef: Node3D = lab.call("carga_completa")
	var ifu: Node3D = lab.call("impacto_pared")
	_ok("con fuego, G y B siguen creando FuegoToy / ImpactoFuegoToy", ef is FuegoToy and ifu is ImpactoFuegoToy)
	var txt: String = String(lab.call("_texto_carga"))
	_ok("la línea de ayuda muestra el elemento", txt.find("ELEMENTO: FUEGO") >= 0)
	lab.queue_free()
	await process_frame
