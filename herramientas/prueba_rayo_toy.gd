extends SceneTree

## PRUEBA del rayo «toy» (B1, 2/11/2026; a imagen de prueba_agua_toy.gd y prueba_hielo_toy.gd). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_rayo_toy.gd
## Comprueba, con RayoToy, ImpactoRayoToy y la paleta:
##   1. ESTILO: los shaders de trazo (hilo y halo) y de destello son blend_add y unshaded (el rayo es luz), sin EMISSION; el CUERPO amarillo del trazo es la única capa en blend_mix (sumar amarillo a un suelo claro da blanco)
##   2. PALETA: rayo_paleta.gd == los defaults de rayo_toy.gdshaderinc == lo que RayoTrazos.material() pasa a los shaders; cada valor == el del juego (vfx_3d.gd, vfx_estado_3d.gd, emisor_rayo_3d.gd);
##      amarillo en el cuerpo, azul en el halo
##   3. FIGURAS: BOLA, MURO, PILAR, BARRERA y HAZ con los tamaños de la prueba 3: lo que dibujan cabe en los semiejes (alto de la columna, ancho de la valla, radio del aro, largo del arco)
##   4. DURA MUY POCO: nace en < 0,15 s (la animación dura 0,06 s; el resto es el reparto en fotogramas), MUERE en < 0,25 s y se libera sola; `dura_morir` < 0,2 s
##   5. PARPADEA: la línea quebrada se REDIBUJA cada ~0,05 s con otros puntos y otra intensidad (de 0,2 a 1)
##   6. LUZ: UNA sola luz, que sigue la intensidad del parpadeo y se apaga al morir; el mando `luz` la apaga
##   7. CARGA y SOLTAR: nace pequeña, crece sin bajar, las chispas CONVERGEN y hay más cuanto más avanza la carga; soltar sin saltos; cancelar la libera
##   8. IMPACTOS (ImpactoRayoToy GOLPE, FIN, REBOTE, AREA): chispas en el hemisferio de la normal, se alejan y caen; descargas que se redibujan; el AREA son cinco rayos verticales escalonados; duran < 1 s y se liberan solos
##   9. API de RayoToy: impactar_en / rebotar / terminar_sin_choque / finalizar; describir y desde_hechizo = los del fuego (misma casilla y misma escala)
##  10. PRESUPUESTO en todo el ciclo y en los tamaños extremos: ≤ 1 luz (la del rayo, justificada: el destello que ilumina el suelo), 0 GPUParticles3D, ≤ 300 partículas (instancias de MultiMesh)
##  11. LAB: Z llega al rayo y G / B / N / M / R / P / F7 / F9 crean rayo; VfxToyJuego crea RayoToy y `_sin_luz` apaga su luz
## NO comprueba (necesita ventana y GPU): el aspecto ni que los shaders compilen (se ve en la lámina de docs/capturas/comparativa_vfx/godot_toy/hielo_rayo/). Imprime FALLOS: n.

const RayoTrazos = preload("res://presentacion/vfx/toy/rayo_trazos.gd")
const RayoPaleta = preload("res://presentacion/vfx/toy/rayo_paleta.gd")
const MAX_PARTICULAS: int = 300
const SHADERS: PackedStringArray = ["rayo_toy.gdshaderinc", "rayo_trazo.gdshaderinc", "rayo_trazo.gdshader", "rayo_trazo_cuerpo.gdshader", "rayo_destello.gdshader"]
const FIGURAS: Array = [["BOLA", 0, Vector3(0.4, 0.4, 0.4)], ["MURO", 1, Vector3(3.45, 1.5, 0.3)], ["PILAR", 2, Vector3(0.5, 4.0, 0.5)], ["BARRERA", 3, Vector3(1.5, 1.5, 1.5)], ["HAZ", 4, Vector3(1.5, 0.5, 0.15)]]

var _fallos: int = 0
var _raiz: Node3D = null
var _max_luces: int = 0
var _max_gpu: int = 0
var _max_part: int = 0
var _adit: int = 0
var _no_adit: int = 0
var _cuerpo: int = 0


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
	_paleta()
	await _figuras()
	await _corto()
	await _parpadeo()
	await _luz()
	await _carga()
	await _soltar()
	await _impactos()
	await _api()
	await _extremos()
	await _lab()
	print("máximo visto en todo el ciclo: %d luces, %d GPUParticles3D, %d partículas (MultiMesh), %d materiales aditivos, %d de cuerpo (mezcla), %d otros" % [_max_luces, _max_gpu, _max_part, _adit, _cuerpo, _no_adit])
	_ok("presupuesto: ≤ 1 luz, 0 GPUParticles3D, ≤ %d partículas, todo aditivo salvo la capa del cuerpo amarillo" % MAX_PARTICULAS, _max_luces <= 1 and _max_gpu == 0 and _max_part <= MAX_PARTICULAS and _adit > 0 and _cuerpo > 0 and _no_adit == 0)
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
	var noadit: int = 0
	var cuerpo: int = 0
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
				elif m.shader != null and m.shader.resource_path.ends_with("rayo_trazo_cuerpo.gdshader"):
					cuerpo += 1                                  # la única capa que no es aditiva: el cuerpo amarillo
				else:
					noadit += 1
				m = m.next_pass as ShaderMaterial
	_max_luces = maxi(_max_luces, luces)
	_max_gpu = maxi(_max_gpu, gpu)
	_max_part = maxi(_max_part, part)
	_adit = maxi(_adit, adit)
	_no_adit = maxi(_no_adit, noadit)
	_cuerpo = maxi(_cuerpo, cuerpo)


func _nueva() -> RayoToy:
	var e: RayoToy = RayoToy.new()
	_raiz.add_child(e)
	return e


func _escala(e: RayoToy) -> float:
	return (e.get_node("Cuerpo") as Node3D).scale.x


# ------------------------------------------------------------------ 1. estilo ------------------------------------------------------------------

func _estilo() -> void:
	print("== shaders")
	for s in SHADERS:
		var txt: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/" + s)
		var cuerpo: PackedStringArray = PackedStringArray()
		for l in txt.split("\n"):
			if not l.strip_edges().begins_with("//"):
				cuerpo.append(l)
		var codigo: String = "\n".join(cuerpo)
		_ok(s + ": sin EMISSION", codigo.find("EMISSION") < 0)
		if s == "rayo_trazo_cuerpo.gdshader":
			_ok(s + ": el CUERPO amarillo va en blend_mix y unshaded (sumar amarillo a un suelo claro da blanco), sin escribir profundidad", codigo.find("blend_mix") >= 0 and codigo.find("blend_add") < 0 and codigo.find("unshaded") >= 0 and codigo.find("depth_draw_never") >= 0)
		elif s.ends_with(".gdshader"):
			_ok(s + ": blend_add y unshaded (es luz), sin escribir profundidad", codigo.find("blend_add") >= 0 and codigo.find("unshaded") >= 0 and codigo.find("depth_draw_never") >= 0)


# ------------------------------------------------------------------ 2. paleta ------------------------------------------------------------------

func _vec3_de(txt: String, nombre: String) -> Color:
	var rx: RegEx = RegEx.new()
	rx.compile("uniform vec3 " + nombre + "\\s*:\\s*source_color\\s*=\\s*vec3\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*\\)")
	var m: RegExMatch = rx.search(txt)
	if m == null:
		return Color(-1, -1, -1)
	return Color(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3)))


func _cerca(a: Color, b: Color, tol: float = 0.011) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol


func _paleta() -> void:
	print("== paleta")
	var txt: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/rayo_toy.gdshaderinc")
	var pal: Dictionary = RayoPaleta.uniforms()
	var todos: bool = true
	var detalle: String = ""
	for k in pal:
		var c: Color = _vec3_de(txt, k)
		if not _cerca(c, pal[k], 0.001):
			todos = false
			detalle += " %s: inc %s vs paleta %s;" % [k, str(c), str(pal[k])]
	_ok("rayo_toy.gdshaderinc lleva los mismos colores que rayo_paleta.gd", todos, detalle)
	var m: ShaderMaterial = RayoTrazos.material(RayoTrazos.SH_TRAZO)
	var ok_mat: bool = true
	for k in pal:
		if m.get_shader_parameter(k) != pal[k]:
			ok_mat = false
	_ok("RayoTrazos.material() pasa la paleta a los shaders", ok_mat)
	var v3d: String = FileAccess.get_file_as_string("res://presentacion/vfx_3d.gd")
	_ok("CUERPO == el COLOR «rayo» de vfx_3d.gd (1·0,93·0,40)", v3d.find("\"rayo\": Color(1.0, 0.93, 0.40)") >= 0 and _cerca(RayoPaleta.CUERPO, Color(1.0, 0.93, 0.40)))
	_ok("HALO_HONDO y HALO_BORDE == el perfil «rayo» de vfx_3d.gd (0,2·0,45·0,95 / 0,5·0,82·1)", v3d.find("\"rayo\": {\"nucleo\": Color(0.2, 0.45, 0.95, 0.30), \"borde\": Color(0.5, 0.82, 1.0)") >= 0
		and _cerca(RayoPaleta.HALO_HONDO, Color(0.2, 0.45, 0.95)) and _cerca(RayoPaleta.HALO_BORDE, Color(0.5, 0.82, 1.0)))
	var ve: String = FileAccess.get_file_as_string("res://presentacion/vfx_estado_3d.gd")
	_ok("HALO y NUCLEO == el perfil «rayo» de vfx_estado_3d.gd (c 0,35·0,62·1 / mota 1·1·0,9)", ve.find("\"rayo\": {\"c\": Color(0.35, 0.62, 1.0), \"mota\": Color(1.0, 1.0, 0.90), \"hondo\": Color(1.0, 0.93, 0.40)}") >= 0
		and _cerca(RayoPaleta.HALO, Color(0.35, 0.62, 1.0)) and _cerca(RayoPaleta.NUCLEO, Color(1.0, 1.0, 0.90)))
	var em: String = FileAccess.get_file_as_string("res://objetos/emisor_rayo_3d.gd")
	_ok("CUERPO ≈ el COLOR del emisor de rayo de los puzles (1·0,92·0,4)", em.find("const COLOR: Color = Color(1.0, 0.92, 0.4)") >= 0 and _cerca(RayoPaleta.CUERPO, Color(1.0, 0.92, 0.4)))
	_ok("el cuerpo es amarillo (matiz %.2f entre 0,10 y 0,18) y el halo azul (matiz %.2f entre 0,55 y 0,68)" % [RayoPaleta.CUERPO.h, RayoPaleta.HALO.h],
		RayoPaleta.CUERPO.h > 0.10 and RayoPaleta.CUERPO.h < 0.18 and RayoPaleta.HALO.h > 0.55 and RayoPaleta.HALO.h < 0.68)


# ------------------------------------------------------------------ 3. figuras ------------------------------------------------------------------

## Caja (m) de los puntos de los tramos: [xmin, xmax, ymin, ymax, zmin, zmax].
func _caja(e: RayoToy) -> Array:
	var c: Array = [1.0e9, -1.0e9, 1.0e9, -1.0e9, 1.0e9, -1.0e9]
	for s in e.trazos_actuales():
		for p in [s["a"], s["b"]]:
			var q: Vector3 = p
			c[0] = minf(c[0], q.x)
			c[1] = maxf(c[1], q.x)
			c[2] = minf(c[2], q.y)
			c[3] = maxf(c[3], q.y)
			c[4] = minf(c[4], q.z)
			c[5] = maxf(c[5], q.z)
	return c


func _figuras() -> void:
	print("== figuras (tamaños de la prueba 3)")
	for f in FIGURAS:
		var e: RayoToy = _nueva()
		await process_frame
		var s: Vector3 = f[2]
		e.definir(int(f[1]), s.x, s.y, s.z, false)
		await process_frame
		e.lanzar(-1.0)
		await _esperar(0.5)
		var n_tr: int = e.trazos_actuales().size()
		var c: Array = _caja(e)
		_ok("[%s] dibuja %d tramos (caben en el MultiMesh: %d)" % [f[0], n_tr, (e.find_child("Trazos", true, false) as MultiMeshInstance3D).multimesh.instance_count],
			n_tr >= 8 and n_tr <= (e.find_child("Trazos", true, false) as MultiMeshInstance3D).multimesh.instance_count)
		_ok("[%s] sin GPUParticles3D; una sola luz" % f[0], e.find_children("*", "GPUParticles3D", true, false).is_empty() and e.find_children("*", "Light3D", true, false).size() == 1)
		match int(f[1]):
			0:
				var rmax: float = 0.0
				for sg in e.trazos_actuales():
					rmax = maxf(rmax, maxf((sg["a"] as Vector3).length(), (sg["b"] as Vector3).length()))
				_ok("[BOLA] núcleo + seis descargas cortas: alcance máx %.2f m (≤ 2,5 radios = %.2f)" % [rmax, 2.5 * s.x], rmax <= 2.5 * s.x and rmax >= 1.0 * s.x)
				e.definir(0, 0.4, 0.4, 0.4, true)
				await _esperar(0.5)
				var zmax: float = 0.0
				for sg2 in e.trazos_actuales():
					zmax = maxf(zmax, maxf((sg2["a"] as Vector3).z, (sg2["b"] as Vector3).z))
				_ok("[BOLA] en vuelo sale un zigzag detrás (+Z hasta %.2f m, ≥ 3 radios)" % zmax, zmax >= 3.0 * s.x)
			1:
				_ok("[MURO] valla entre postes: ancho %.2f de ±%.2f m, alto máx %.2f de %.2f m" % [float(c[1]) - float(c[0]), s.x, c[3], s.y],
					float(c[0]) >= -s.x * 1.03 and float(c[1]) <= s.x * 1.03 and float(c[1]) - float(c[0]) >= s.x * 1.8 and float(c[3]) <= s.y * 1.25 and float(c[3]) >= s.y * 0.8 and float(c[2]) > -0.001)
			2:
				_ok("[PILAR] columna de descarga: de y = %.2f a %.2f m (alto %.2f), radio ≤ %.2f" % [c[2], c[3], s.y, maxf(float(c[1]), -float(c[0]))],
					absf(float(c[3]) - s.y) < 0.1 and float(c[2]) < 0.3 and maxf(float(c[1]), -float(c[0])) < 1.8)
			3:
				var rm: float = 0.0
				for sg3 in e.trazos_actuales():
					rm = maxf(rm, maxf(Vector2((sg3["a"] as Vector3).x, (sg3["a"] as Vector3).z).length(), Vector2((sg3["b"] as Vector3).x, (sg3["b"] as Vector3).z).length()))
				_ok("[BARRERA] aro chispeante: radio máx %.2f de %.2f m, alto máx %.2f de %.2f m" % [rm, s.x, c[3], 1.2 * s.y], rm <= s.x * 1.06 and rm >= s.x * 0.6 and float(c[3]) <= 1.45 * s.y and float(c[3]) >= 1.0 * s.y)
			4:
				_ok("[HAZ] arco entre la mano y el objetivo: de z = %.2f a %.2f (largo %.2f m), a la altura del eje %.2f" % [c[5], c[4], s.x * 2.0, maxf(s.y, 0.4)],
					absf(float(c[4]) + s.x * 2.0) < 0.2 and float(c[5]) < 0.6)
		e.queue_free()
		await process_frame


# ------------------------------------------------------------------ 4. dura muy poco ------------------------------------------------------------------

func _corto() -> void:
	print("== dura muy poco")
	for f in FIGURAS:
		var e: RayoToy = _nueva()
		await process_frame
		var s: Vector3 = f[2]
		e.definir(int(f[1]), s.x, s.y, s.z, false)
		await process_frame
		if int(f[1]) == 0:
			e.aparicion = 0.0
		else:
			e.crece = 0.0
		var t0: int = Time.get_ticks_msec()
		e.lanzar(-1.0)
		var t_nace: float = -1.0
		while float(Time.get_ticks_msec() - t0) < 600.0:
			await process_frame
			_medir()
			var v: float = e.aparicion if int(f[1]) == 0 else e.crece
			if v >= 0.999 and t_nace < 0.0:
				t_nace = float(Time.get_ticks_msec() - t0) / 1000.0
		_ok("[%s] NACE en %.3f s (< 0,15)" % [f[0], t_nace], t_nace > 0.0 and t_nace < 0.15)
		await _esperar(0.3)
		_ok("[%s] dura_morir = %.2f s (< 0,2)" % [f[0], e.dura_morir], e.dura_morir < 0.2)
		var t1: int = Time.get_ticks_msec()
		e.morir()
		while is_instance_valid(e) and float(Time.get_ticks_msec() - t1) < 600.0:
			await process_frame
			_medir()
		var t_muere: float = float(Time.get_ticks_msec() - t1) / 1000.0
		_ok("[%s] MUERE y se libera sola en %.3f s (< 0,25)" % [f[0], t_muere], not is_instance_valid(e) and t_muere < 0.25)


# ------------------------------------------------------------------ 5. parpadea ------------------------------------------------------------------

func _parpadeo() -> void:
	print("== parpadea")
	var e: RayoToy = _nueva()
	await process_frame
	e.definir(RayoToy.Figura.PILAR, 0.5, 4.0, 0.5, false)
	await process_frame
	e.lanzar(-1.0)
	await _esperar(0.3)
	var n0: int = e.redibujos()
	var t0: int = Time.get_ticks_msec()
	var distintos: int = 0
	var iguales: int = 0
	var intens: Array = []
	var ult_n: int = n0
	var ult_a: Vector3 = Vector3.INF
	var dts: Array = []
	var t_ult: int = t0
	while float(Time.get_ticks_msec() - t0) < 1500.0:
		await process_frame
		_medir()
		if e.redibujos() != ult_n:
			ult_n = e.redibujos()
			var s0: Dictionary = e.trazos_actuales()[1]
			var a: Vector3 = s0["b"]
			if ult_a != Vector3.INF:
				if a.distance_to(ult_a) > 0.001:
					distintos += 1
				else:
					iguales += 1
			ult_a = a
			intens.append(e.intensidad_actual())
			dts.append(float(Time.get_ticks_msec() - t_ult) / 1000.0)
			t_ult = Time.get_ticks_msec()
	var dt_medio: float = 0.0
	for d in dts:
		dt_medio += float(d)
	dt_medio /= maxf(dts.size(), 1.0)
	var imin: float = 1.0
	var imax: float = 0.0
	for v in intens:
		imin = minf(imin, float(v))
		imax = maxf(imax, float(v))
	_ok("se redibuja %d veces en 1,5 s, cada %.3f s de media (≈ 0,05)" % [e.redibujos() - n0, dt_medio], e.redibujos() - n0 >= 15 and e.redibujos() - n0 <= 40 and dt_medio < 0.09 and dt_medio > 0.03)
	_ok("cada redibujo es OTRA línea (%d distintos, %d iguales)" % [distintos, iguales], distintos >= 12 and iguales == 0)
	_ok("la intensidad cambia de un redibujo a otro (de %.2f a %.2f) y baja a 0,2 alguna vez" % [imin, imax], imax > 0.85 and imin < 0.7 and imin >= 0.19)
	e.queue_free()
	await process_frame


# ------------------------------------------------------------------ 6. luz ------------------------------------------------------------------

func _luz() -> void:
	print("== luz")
	var e: RayoToy = _nueva()
	await process_frame
	e.definir(RayoToy.Figura.PILAR, 0.5, 4.0, 0.5, false)
	await process_frame
	e.lanzar(-1.0)
	await _esperar(0.4)
	var luces: Array = e.find_children("*", "Light3D", true, false)
	var l: OmniLight3D = luces[0] as OmniLight3D if luces.size() > 0 else null
	_ok("una sola luz (OmniLight3D «Luz»), sin sombra, de color %s" % [str(RayoPaleta.LUZ)], luces.size() == 1 and l != null and l.name == "Luz" and not l.shadow_enabled and l.light_color == RayoPaleta.LUZ)
	var sigue: int = 0
	var tot: int = 0
	for k in 25:
		await process_frame
		tot += 1
		if absf(l.light_energy - RayoToy.LUZ_ENERGIA * e.luz * e.intensidad_actual()) < 0.02:
			sigue += 1
	_ok("la energía de la luz sigue la intensidad del parpadeo (%d de %d fotogramas)" % [sigue, tot], sigue == tot and l.light_energy > 0.2)
	e.luz = 0.0
	await process_frame
	await process_frame
	_ok("el mando `luz` = 0 la apaga", l.light_energy < 0.001)
	e.luz = 1.0
	e.morir()
	await _esperar(0.12)
	var al_morir: float = l.light_energy if is_instance_valid(l) else 0.0
	_ok("al morir la luz baja (energía %.2f de %.2f)" % [al_morir, RayoToy.LUZ_ENERGIA], al_morir < RayoToy.LUZ_ENERGIA * 0.7)
	await _esperar(0.3)


# ------------------------------------------------------------------ 7. carga y soltar ------------------------------------------------------------------

func _carga() -> void:
	print("== carga")
	var e: RayoToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 1, 0)
	e.empezar_carga(0.8, 0.4)
	var s0: float = _escala(e)
	_ok("nace pequeño: escala %.3f ≈ carga_tam_inicial %.2f" % [s0, e.carga_tam_inicial], absf(s0 - e.carga_tam_inicial) < 0.06)
	_ok("esta_cargando() y progreso empieza en ≈ 0", e.esta_cargando() and e.progreso_carga() < 0.15)
	var conv: Node = e.find_child("Convergencia", true, false)
	_ok("hay chispas, arcos y halo en el suelo", conv != null and conv.find_child("Chispas", true, false) != null and conv.find_child("Arcos", true, false) != null)
	var prev: float = s0
	var baja: bool = false
	var n_ini: int = int(conv.call("n_visibles"))
	var conv_ok: int = 0
	var conv_tot: int = 0
	var arcos_vistos: int = 0
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < 700.0:
		await process_frame
		_medir()
		var s: float = _escala(e)
		if s < prev - 0.002:
			baja = true
		prev = s
		arcos_vistos = maxi(arcos_vistos, (conv.call("arcos_actuales") as Array).size())
		for g in conv.call("estado_gotas"):
			var gd: Dictionary = g
			var p: Vector3 = gd["pos"]
			var d: Vector3 = gd["mov"]
			conv_tot += 1
			if float(gd["rad"]) <= float(gd["r0"]) + 0.0001 and d.dot(p.normalized()) < 0.2:
				conv_ok += 1
	_ok("crece sin bajar (escala %.2f)" % prev, not baja and prev > 0.7)
	_ok("las chispas convergen (%d de %d hacia dentro y por debajo del radio de nacimiento)" % [conv_ok, conv_tot], conv_tot > 0 and float(conv_ok) / float(conv_tot) > 0.97)
	var n_fin: int = int(conv.call("n_visibles"))
	_ok("hay más chispas cuanto más avanza la carga (%d → %d)" % [n_ini, n_fin], n_fin > n_ini)
	_ok("saltan arcos cortos alrededor de la mano (hasta %d tramos a la vez)" % arcos_vistos, arcos_vistos >= 4)
	_ok("progreso_carga llega a 1", e.progreso_carga() > 0.85)
	e.cancelar_carga()
	await _esperar(0.45)
	_ok("cancelar_carga la libera sola", not is_instance_valid(e))


func _soltar() -> void:
	print("== soltar")
	for etapa in ["llena", "a medias"]:
		var e: RayoToy = _nueva()
		await process_frame
		e.global_position = Vector3(0, 1, 0)
		e.empezar_carga(0.6, 0.4)
		await _esperar(0.7 if etapa == "llena" else 0.25)
		var id: int = e.get_instance_id()
		var antes: float = _escala(e)
		e.soltar(Vector3(0, 0, -1))
		_ok("[%s] soltar: mismo nodo y proyectil" % etapa, e.get_instance_id() == id and e.proyectil)
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


# ------------------------------------------------------------------ 8. impactos ------------------------------------------------------------------

func _impactos() -> void:
	print("== impactos")
	var casos: Array = [["GOLPE pared", ImpactoRayoToy.Variante.GOLPE, Vector3(0, 0, 1)], ["GOLPE suelo", ImpactoRayoToy.Variante.GOLPE, Vector3.UP], ["GOLPE techo", ImpactoRayoToy.Variante.GOLPE, Vector3.DOWN],
		["FIN", ImpactoRayoToy.Variante.FIN, Vector3.UP], ["REBOTE pared", ImpactoRayoToy.Variante.REBOTE, Vector3(1, 0, 0)], ["AREA", ImpactoRayoToy.Variante.AREA, Vector3.UP]]
	for c in casos:
		var radio: float = 1.8 if c[1] == ImpactoRayoToy.Variante.AREA else 0.4
		var imp: ImpactoRayoToy = ImpactoRayoToy.crear(c[1], c[2], radio)
		_raiz.add_child(imp)
		imp.global_position = Vector3(0, 1, 0)
		await process_frame
		var bajo: int = 0
		var vivas: int = 0
		var lejos0: float = 0.0
		var lejos1: float = 0.0
		var cuenta: int = 0
		var cae: int = 0
		var g_ini: Array = imp.chispas_estado(0.1)
		var g_fin: Array = imp.chispas_estado(0.2)
		for t in [0.05, 0.1, 0.15, 0.2, 0.3]:
			for g in imp.chispas_estado(t):
				var gd: Dictionary = g
				if bool(gd["vivo"]):
					vivas += 1
					if c[1] != ImpactoRayoToy.Variante.FIN and float(gd["altura"]) < -0.006:
						bajo += 1
		if c[1] != ImpactoRayoToy.Variante.FIN and c[1] != ImpactoRayoToy.Variante.AREA:
			for i in g_ini.size():
				var a: Dictionary = g_ini[i]
				var b: Dictionary = g_fin[i]
				if bool(a["vivo"]) and bool(b["vivo"]):
					cuenta += 1
					lejos0 += float(a["dist"])
					lejos1 += float(b["dist"])
					if float(b["vy"]) < float(a["vy"]) - 0.3:
						cae += 1
		var rc: Array = imp.recuento()
		_ok("[%s] %d chispas y %d descargas, hay chispas vivas" % [c[0], rc[0], rc[1]], int(rc[0]) >= 8 and vivas > 0 and int(rc[1]) >= 3)
		if c[1] != ImpactoRayoToy.Variante.FIN:
			_ok("[%s] ninguna chispa por debajo de la superficie (en el hemisferio de la normal)" % c[0], bajo == 0)
		if c[1] != ImpactoRayoToy.Variante.FIN and c[1] != ImpactoRayoToy.Variante.AREA:
			_ok("[%s] las chispas se alejan (%.2f → %.2f m de media)" % [c[0], lejos0 / maxf(cuenta, 1), lejos1 / maxf(cuenta, 1)], cuenta > 0 and lejos1 > lejos0)
			_ok("[%s] CAEN: la velocidad vertical baja con la gravedad (%d de %d)" % [c[0], cae, cuenta], cuenta > 0 and cae >= cuenta * 0.9)
		# las descargas: hay tramos al principio y se redibujan (otros puntos cada 0,05 s)
		imp.avanzar_a(0.12)
		var l1: Array = (imp.tramos_actuales() as Array).duplicate()
		imp.avanzar_a(0.2)
		var l2: Array = imp.tramos_actuales()
		var difieren: bool = l1.size() > 0 and l2.size() > 0 and (l1[0]["b"] as Vector3).distance_to(l2[0]["b"]) > 0.001
		if c[1] == ImpactoRayoToy.Variante.AREA:
			imp.avanzar_a(0.2)
			var altos: int = 0
			for sg in imp.tramos_actuales():
				altos += 1 if maxf((sg["a"] as Vector3).y, (sg["b"] as Vector3).y) > 3.0 * radio * 0.85 else 0
			imp.avanzar_a(0.02)
			var n_a: int = imp.tramos_actuales().size()
			imp.avanzar_a(0.3)
			var n_b: int = imp.tramos_actuales().size()
			_ok("[AREA] cinco rayos verticales que caen del cielo (altura %.1f m) uno tras otro cada %.2f s: %d tramos a los 0,02 s, %d a los 0,3 s" % [3.2 * radio, ImpactoRayoToy.T_ESCALONADO, n_a, n_b], altos >= 2 and n_b > n_a)
		_ok("[%s] las descargas se redibujan (tramos distintos a los 0,12 y a los 0,2 s)" % c[0], difieren or c[1] == ImpactoRayoToy.Variante.AREA)
		_ok("[%s] dura poco: %.2f s (< 1)" % [c[0], imp.duracion()], imp.duracion() < 1.0)
		var t1: int = Time.get_ticks_msec()
		while is_instance_valid(imp) and float(Time.get_ticks_msec() - t1) < 2500.0:
			await process_frame
			_medir()
		_ok("[%s] se libera solo" % c[0], not is_instance_valid(imp))
	var pequeno: ImpactoRayoToy = ImpactoRayoToy.crear(ImpactoRayoToy.Variante.GOLPE, Vector3.UP, 0.2)
	var grande: ImpactoRayoToy = ImpactoRayoToy.crear(ImpactoRayoToy.Variante.GOLPE, Vector3.UP, 0.8)
	_raiz.add_child(pequeno)
	_raiz.add_child(grande)
	await process_frame
	var dmax_p: float = 0.0
	var dmax_g: float = 0.0
	for g in pequeno.chispas_estado(0.15):
		dmax_p = maxf(dmax_p, float((g as Dictionary)["dist"]))
	for g in grande.chispas_estado(0.15):
		dmax_g = maxf(dmax_g, float((g as Dictionary)["dist"]))
	_ok("el golpe escala con el radio (%.2f m con r 0,2 · %.2f m con r 0,8)" % [dmax_p, dmax_g], dmax_g > dmax_p * 1.5)
	pequeno.queue_free()
	grande.queue_free()
	await process_frame


# ------------------------------------------------------------------ 9. API de RayoToy ------------------------------------------------------------------

func _hay_impacto() -> bool:
	for h in _raiz.get_children():
		if h is ImpactoRayoToy:
			return true
	return false


func _limpiar_impactos() -> void:
	for h in _raiz.get_children():
		if h is ImpactoRayoToy:
			h.free()


func _api() -> void:
	print("== RayoToy: impactar_en / rebotar / terminar_sin_choque / finalizar")
	var e: RayoToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 1, 0)
	e.definir(RayoToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	await _esperar(0.3)
	e.impactar_en(Vector3(0, 1, -2), Vector3(0, 0, 1))
	_ok("impactar_en deja un impacto", _hay_impacto())
	await _esperar(0.4)
	_ok("impactar_en libera la bola", not is_instance_valid(e))
	_limpiar_impactos()
	await process_frame
	var r: RayoToy = _nueva()
	await process_frame
	r.global_position = Vector3(0, 1, 0)
	r.look_at(Vector3(0, 1, -5), Vector3.UP)
	r.definir(RayoToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	await process_frame
	var nd: Vector3 = r.rebotar(Vector3(0, 1, -2), Vector3(0, 0, 1))
	_ok("rebotar: la bola sigue viva, hay impacto y devuelve la dirección reflejada (%s)" % str(nd), is_instance_valid(r) and _hay_impacto() and nd.distance_to(Vector3(0, 0, 1)) < 0.01)
	_ok("rebotar: la bola mira hacia la dirección reflejada", (-r.global_transform.basis.z).distance_to(nd) < 0.01)
	await _esperar(0.6)
	_limpiar_impactos()
	r.queue_free()
	await process_frame
	var f: RayoToy = _nueva()
	await process_frame
	f.global_position = Vector3(0, 1, 0)
	f.empezar_carga(0.1, 0.4)
	await _esperar(0.2)
	f.soltar(Vector3(0, 0, -1))
	await _esperar(0.2)
	f.terminar_sin_choque()
	_ok("terminar_sin_choque deja un impacto FIN", _hay_impacto())
	await _esperar(1.0)
	_ok("terminar_sin_choque libera la bola tras apagarse", not is_instance_valid(f))
	_limpiar_impactos()
	var h: RayoToy = _nueva()
	await process_frame
	h.global_position = Vector3(0, 1, 0)
	h.finalizar("suelo", Vector3(0, 0, 0), Vector3.UP)
	_ok("finalizar('suelo') = impacto", _hay_impacto())
	await _esperar(0.4)
	_ok("finalizar('suelo') libera la bola", not is_instance_valid(h))
	_limpiar_impactos()
	var h2: RayoToy = _nueva()
	await process_frame
	h2.finalizar("alcance")
	_ok("finalizar('alcance') = fin sin choque", _hay_impacto())
	await _esperar(1.0)
	_ok("finalizar('alcance') libera la bola", not is_instance_valid(h2))
	_limpiar_impactos()
	# una zona (bola quieta) cae en área
	var z: RayoToy = _nueva()
	await process_frame
	var hz0: Hechizo = Hechizo.new()
	hz0.semieje_x = 0.3
	hz0.semieje_y = 0.3
	hz0.semieje_z = 0.3
	z.desde_hechizo(hz0)
	_ok("una zona (bola que no viaja) estalla en área al acabar", z.area_al_impactar)
	z.impactar_en(Vector3(0, 0, 0))
	var hay_area: bool = false
	for im in _raiz.get_children():
		if im is ImpactoRayoToy and int(im.variante) == ImpactoRayoToy.Variante.AREA:
			hay_area = true
	_ok("…y deja un ImpactoRayoToy AREA", hay_area)
	_limpiar_impactos()
	await process_frame
	var hechizos: Array = []
	var hz: Hechizo = Hechizo.new()
	hz.semieje_x = 0.3
	hz.semieje_y = 0.3
	hz.semieje_z = 0.3
	hz.velocidad = 8.0
	hechizos.append(hz)
	var hm: Hechizo = Hechizo.new()
	hm.semieje_x = 1.5
	hm.semieje_y = 0.3
	hm.semieje_z = 0.13
	hechizos.append(hm)
	var hp: Hechizo = Hechizo.new()
	hp.semieje_x = 0.2
	hp.semieje_y = 1.7
	hp.semieje_z = 0.2
	hechizos.append(hp)
	var hb: Hechizo = Hechizo.new()
	hb.semieje_x = 0.65
	hb.semieje_y = 0.65
	hb.semieje_z = 0.65
	hb.solidez = 1.5
	hechizos.append(hb)
	var iguales: bool = true
	for hh in hechizos:
		var da: Dictionary = RayoToy.describir(hh)
		var df: Dictionary = FuegoToy.describir(hh)
		iguales = iguales and int(da["figura"]) == int(df["figura"]) and is_equal_approx(float(da["x"]), float(df["x"])) and is_equal_approx(float(da["y"]), float(df["y"])) and is_equal_approx(float(da["z"]), float(df["z"])) and bool(da["viaja"]) == bool(df["viaja"])
	_ok("describir(h) es igual que el del fuego en bola, muro, pilar y barrera", iguales)
	var casilla_ok: bool = true
	for hh2 in hechizos:
		var d: RayoToy = _nueva()
		await process_frame
		var d_f: Dictionary = FuegoToy.describir(hh2, d.casilla)
		d.desde_hechizo(hh2)
		await process_frame
		casilla_ok = casilla_ok and int(d.figura) == int(d_f["figura"]) and is_equal_approx(d.semieje_x, float(d_f["x"])) and is_equal_approx(d.semieje_y, float(d_f["y"])) and d.viaja == bool(d_f["viaja"])
		d.queue_free()
	_ok("desde_hechizo: figura, semiejes y vuelo del fuego, con la misma casilla de %.1f m" % RayoToy.new().casilla, casilla_ok)
	await process_frame


# ------------------------------------------------------------------ 10. tamaños extremos (presupuesto) ------------------------------------------------------------------

func _extremos() -> void:
	print("== presupuesto en tamaños extremos")
	for ex in [["muro 8 · 4,6 · 3", 1, Vector3(8.0, 4.6, 3.0)], ["pilar 1,2 · 4,6", 2, Vector3(1.2, 4.6, 1.2)], ["barrera 6,9 · 4,6 · 6,9", 3, Vector3(6.9, 4.6, 6.9)], ["haz 3,45 · 0,9 · 0,4", 4, Vector3(3.45, 0.9, 0.4)], ["bola 1,2", 0, Vector3(1.2, 1.2, 1.2)]]:
		var e: RayoToy = _nueva()
		await process_frame
		e.definir(int(ex[1]), (ex[2] as Vector3).x, (ex[2] as Vector3).y, (ex[2] as Vector3).z, int(ex[1]) == 0)
		await process_frame
		e.lanzar(-1.0)
		await _esperar(0.4)
		var cuenta: int = 0
		var llenos: String = ""
		for mm in e.find_children("*", "MultiMeshInstance3D", true, false):
			cuenta += (mm as MultiMeshInstance3D).multimesh.instance_count
		var tramos: int = e.trazos_actuales().size()
		var cap: int = (e.find_child("Trazos", true, false) as MultiMeshInstance3D).multimesh.instance_count
		if tramos > cap:
			llenos = " (¡se cortan: %d > %d!)" % [tramos, cap]
		_ok("[%s] %d instancias de MultiMesh (≤ %d); %d tramos de %d%s" % [ex[0], cuenta, MAX_PARTICULAS, tramos, cap, llenos], cuenta <= MAX_PARTICULAS and tramos <= cap)
		e.queue_free()
		await process_frame


# ------------------------------------------------------------------ 11. lab y juego ------------------------------------------------------------------

func _lab() -> void:
	print("== lab: Z llega al rayo")
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	var orden: Array = []
	for i in 3:
		lab.call("alternar_elemento")
		orden.append(String(lab.get("elemento")))
	_ok("Z: fuego → agua → hielo → rayo (%s)" % str(orden), orden == ["agua", "hielo", "rayo"])
	var e: Node3D = lab.call("carga_completa")
	_ok("G con rayo crea un RayoToy", e is RayoToy)
	var ip: Node3D = lab.call("impacto_pared")
	var isu: Node3D = lab.call("impacto_suelo")
	_ok("B y N con rayo crean ImpactoRayoToy", ip is ImpactoRayoToy and isu is ImpactoRayoToy)
	var m: Node3D = lab.call("lanzar_proyectil", "fin")
	var rb: Node3D = lab.call("lanzar_proyectil", "rebote")
	_ok("M y R con rayo crean RayoToy", m is RayoToy and rb is RayoToy)
	var pa: Node3D = lab.call("explosion_area")
	_ok("P con rayo crea un ImpactoRayoToy AREA", pa is ImpactoRayoToy and int(pa.get("variante")) == ImpactoRayoToy.Variante.AREA)
	var fp: Node3D = lab.call("fuego_param", 1)
	_ok("F7 con rayo crea un RayoToy MURO", fp is RayoToy and int(fp.get("figura")) == 1)
	lab.call("eje_param", 0, 1)
	await process_frame
	_ok("el eje U cambia el semieje x del RayoToy", float(fp.get("semieje_x")) > 4.0)
	var hz: Node3D = lab.call("fuego_hechizo", 0)
	_ok("F9 con rayo crea un RayoToy desde un hechizo", hz is RayoToy)
	_ok("la línea de ayuda y el rótulo muestran el elemento", String(lab.call("_texto_carga")).find("ELEMENTO: RAYO") >= 0 and String(lab.call("_texto_param")).find("RAYO PARAMETRICO") >= 0)
	lab.call("alternar_elemento")
	_ok("Z desde el rayo vuelve al fuego", String(lab.get("elemento")) == "fuego")
	lab.queue_free()
	await process_frame
	var vj: VfxToyJuego = VfxToyJuego.new()
	var t: Node3D = vj.call("_nuevo", "rayo")
	_ok("VfxToyJuego._nuevo(«rayo») crea un RayoToy y cuenta uno", t is RayoToy and int(vj.creados["rayo"]) == 1)
	_raiz.add_child(t)
	await process_frame
	await process_frame
	var luz: OmniLight3D = t.find_child("Luz", true, false) as OmniLight3D
	_ok("el rayo lleva una luz que VfxToyJuego puede apagar (`_sin_luz`)", luz != null and luz.light_energy > 0.0)
	vj.call("_sin_luz", t)
	await process_frame
	await process_frame
	_ok("tras `_sin_luz` la luz queda a 0 y no vuelve", luz.light_energy < 0.001 and not luz.visible)
	t.queue_free()
	vj.free()
