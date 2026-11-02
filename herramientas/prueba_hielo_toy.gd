extends SceneTree

## PRUEBA del hielo «toy» (B1, 2/11/2026; a imagen de prueba_agua_toy.gd). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_hielo_toy.gd
## Comprueba, con HieloToy, ImpactoHieloToy y la paleta:
##   1. ESTILO: los shaders del hielo son blend_mix y unshaded, sin blend_add ni EMISSION
##   2. PALETA: hielo_paleta.gd == los defaults de hielo_toy.gdshaderinc == lo que HieloMallas.material() pasa a los shaders (el hielo del mundo: costra_hielo_3d.gd, vfx_3d.gd, vfx_estado_3d.gd)
##   3. FIGURAS: BOLA, MURO, PILAR, BARRERA y HAZ con los tamaños de la prueba 3: lo que dibujan cabe en los semiejes (alto del pilar, ancho del muro, radio de la barrera, largo del haz), escarcha en la base
##   4. CRECER POR ETAPAS: tres escalones con meseta (0,34 · 0,67 · 1) y la animación «nacer» los recorre sin bajar
##   5. ROMPERSE: con `corte` se agrieta, los cristales estallan a su hora, las esquirlas giran, CAEN, rebotan y se quedan; la figura se libera sola al morir
##   6. CARGA: nace pequeña, crece sin bajar, las esquirlas CONVERGEN y hay más cuanto más avanza la carga; soltar sin saltos; cancelar la libera
##   7. IMPACTOS (ImpactoHieloToy GOLPE, FIN, REBOTE, AREA): esquirlas en el hemisferio de la normal, se alejan y caen; cristales que brotan y se rompen; se liberan solos; escalan con el radio
##   8. API de HieloToy: impactar_en / rebotar / terminar_sin_choque / finalizar; describir y desde_hechizo = los del fuego (misma casilla y misma escala)
##   9. PRESUPUESTO en todo el ciclo y en los tamaños extremos: 0 luces, 0 GPUParticles3D, ≤ 300 partículas (instancias de MultiMesh), 0 aditivos
##  10. LAB: Z cicla fuego → agua → hielo → rayo y G / B / N / F7 crean hielo cuando el elemento es hielo; VfxToyJuego crea HieloToy
## NO comprueba (necesita ventana y GPU): el aspecto ni que los shaders compilen (se ve en la lámina de docs/capturas/comparativa_vfx/godot_toy/hielo_rayo/). Imprime FALLOS: n.

const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const HieloPaleta = preload("res://presentacion/vfx/toy/hielo_paleta.gd")
const HieloEsquirlas = preload("res://presentacion/vfx/toy/hielo_esquirlas.gd")
const MAX_PARTICULAS: int = 300
const SHADERS: PackedStringArray = ["hielo_toy.gdshaderinc", "hielo_cristal.gdshader", "hielo_escarcha.gdshader", "hielo_destello.gdshader"]
const FIGURAS: Array = [["BOLA", 0, Vector3(0.4, 0.4, 0.4)], ["MURO", 1, Vector3(3.45, 1.5, 0.3)], ["PILAR", 2, Vector3(0.5, 4.0, 0.5)], ["BARRERA", 3, Vector3(1.5, 1.5, 1.5)], ["HAZ", 4, Vector3(1.5, 0.5, 0.15)]]

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
	_paleta()
	await _figuras()
	await _etapas()
	await _romperse()
	await _carga()
	await _soltar()
	await _impactos()
	await _api()
	await _extremos()
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


## Mide luces, partículas (GPU y MultiMesh) y materiales aditivos de todo lo que cuelga de _raiz.
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


func _nueva() -> HieloToy:
	var e: HieloToy = HieloToy.new()
	_raiz.add_child(e)
	return e


func _escala(e: HieloToy) -> float:
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
		_ok(s + ": sin blend_add, sin EMISSION", codigo.find("blend_add") < 0 and codigo.find("EMISSION") < 0)
		if s.ends_with(".gdshader"):
			_ok(s + ": blend_mix y unshaded (sin luz)", codigo.find("blend_mix") >= 0 and codigo.find("unshaded") >= 0)


# ------------------------------------------------------------------ 2. paleta ------------------------------------------------------------------

## Lee `uniform vec3 NOMBRE : source_color = vec3(a, b, c);` de un .gdshaderinc.
func _vec3_de(txt: String, nombre: String) -> Color:
	var rx: RegEx = RegEx.new()
	rx.compile("uniform vec3 " + nombre + "\\s*:\\s*source_color\\s*=\\s*vec3\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*\\)")
	var m: RegExMatch = rx.search(txt)
	if m == null:
		return Color(-1, -1, -1)
	return Color(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3)))


func _paleta() -> void:
	print("== paleta")
	var txt: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/hielo_toy.gdshaderinc")
	var pal: Dictionary = HieloPaleta.uniforms()
	var todos: bool = true
	var detalle: String = ""
	for k in ["tono_a", "tono_b", "tono_c", "color_nucleo", "color_borde", "color_grieta"]:
		var c: Color = _vec3_de(txt, k)
		var p: Color = pal[k]
		if absf(c.r - p.r) > 0.001 or absf(c.g - p.g) > 0.001 or absf(c.b - p.b) > 0.001:
			todos = false
			detalle += " %s: inc %s vs paleta %s;" % [k, str(c), str(p)]
	_ok("hielo_toy.gdshaderinc lleva los mismos colores que hielo_paleta.gd", todos, detalle)
	_ok("las bandas del .gdshaderinc son las de la paleta (%d)" % int(HieloPaleta.BANDAS), txt.find("bandas : hint_range(1.0, 8.0) = %.1f" % HieloPaleta.BANDAS) >= 0)
	var m: ShaderMaterial = HieloMallas.material(HieloMallas.SH_CRISTAL)
	var ok_mat: bool = true
	for k in pal:
		if m.get_shader_parameter(k) != pal[k]:
			ok_mat = false
	_ok("HieloMallas.material() pasa la paleta a los shaders", ok_mat)
	# procedencia: el hielo del mundo (la costra helada del agua) y el perfil «hielo» del juego
	var costra: String = FileAccess.get_file_as_string("res://presentacion/costra_hielo_3d.gd")
	_ok("CLARO / HONDO / GRIETA == costra_hielo_3d.gd (color_claro, color_hondo, color_grieta)", _vec3_de(costra, "color_claro").is_equal_approx(HieloPaleta.CLARO) and _vec3_de(costra, "color_hondo").is_equal_approx(HieloPaleta.HONDO)
		and _vec3_de(costra, "color_grieta").is_equal_approx(HieloPaleta.GRIETA))
	var v3d: String = FileAccess.get_file_as_string("res://presentacion/vfx_3d.gd")
	_ok("NUCLEO y BORDE == el perfil «hielo» de vfx_3d.gd (0,6·0,88·1 / 0,92·1·1)", v3d.find("\"hielo\": {\"nucleo\": Color(0.6, 0.88, 1.0, 0.42), \"borde\": Color(0.92, 1.0, 1.0)") >= 0
		and HieloPaleta.NUCLEO.is_equal_approx(Color(0.6, 0.88, 1.0)) and HieloPaleta.BORDE.is_equal_approx(Color(0.92, 1.0, 1.0)))
	var ve: String = FileAccess.get_file_as_string("res://presentacion/vfx_estado_3d.gd")
	_ok("ESCARCHA == la mota del perfil «hielo» de vfx_estado_3d.gd (0,86·0,93·0,99)", ve.find("\"mota\": Color(0.86, 0.93, 0.99)") >= 0 and HieloPaleta.ESCARCHA.is_equal_approx(Color(0.86, 0.93, 0.99)))
	# el hielo es azul claro (no gris ni verdoso): b > g > r en los tres tonos de la rampa
	var azul: bool = true
	for c2 in [HieloPaleta.HONDO, HieloPaleta.CLARO, HieloPaleta.ESCARCHA]:
		var cc: Color = c2
		azul = azul and cc.b > cc.g and cc.g > cc.r
	_ok("hondo / claro / escarcha son azules (b > g > r) y cada uno más claro que el anterior", azul and HieloPaleta.HONDO.get_luminance() < HieloPaleta.CLARO.get_luminance() and HieloPaleta.CLARO.get_luminance() < HieloPaleta.ESCARCHA.get_luminance())


# ------------------------------------------------------------------ 3. figuras ------------------------------------------------------------------

## Caja (m) que ocupan los cristales de una figura: [x_min, x_max, y_max, z_min, z_max] con el alto completo de cada cristal.
func _caja(e: HieloToy) -> Dictionary:
	var xmin: float = 1.0e9
	var xmax: float = -1.0e9
	var ymax: float = 0.0
	var zmin: float = 1.0e9
	var zmax: float = -1.0e9
	for c in e._cris:
		var pos: Vector3 = c["pos"]
		var rot: Basis = c["rot"]
		var punta: Vector3 = pos + rot * Vector3(0, float(c["h"]), 0)
		for p in [pos, punta]:
			var q: Vector3 = p
			xmin = minf(xmin, q.x)
			xmax = maxf(xmax, q.x)
			ymax = maxf(ymax, q.y)
			zmin = minf(zmin, q.z)
			zmax = maxf(zmax, q.z)
	return {"xmin": xmin, "xmax": xmax, "ymax": ymax, "zmin": zmin, "zmax": zmax}


func _figuras() -> void:
	print("== figuras (tamaños de la prueba 3)")
	for f in FIGURAS:
		var e: HieloToy = _nueva()
		await process_frame
		var s: Vector3 = f[2]
		e.definir(int(f[1]), s.x, s.y, s.z, false)
		await process_frame
		e.lanzar(-1.0)
		await _esperar(1.1)
		_ok("[%s] sin luces ni GPUParticles3D" % f[0], e.find_children("*", "Light3D", true, false).is_empty() and e.find_children("*", "GPUParticles3D", true, false).is_empty())
		var c: Dictionary = _caja(e) if int(f[1]) != 0 else {}
		match int(f[1]):
			0:
				_ok("[BOLA] bloque (Esfera) con púas y estela de cristales; la estela solo en vuelo", e.find_child("Esfera", true, false) is MeshInstance3D and e.find_child("Puas", true, false) is MultiMeshInstance3D
					and e.find_child("Estela", true, false) is MultiMeshInstance3D and not (e.find_child("Estela", true, false) as Node3D).visible)
				e.definir(0, 0.4, 0.4, 0.4, true)
				await process_frame
				_ok("[BOLA] en vuelo la estela se ve y hay esquirlas que caen", (e.find_child("Estela", true, false) as Node3D).visible and e.proyectil)
				await _esperar(0.6)
				var reserva: Node = e.find_child("Esquirlas", true, false)
				_ok("[BOLA] suelta esquirlas en vuelo (%d vivas)" % (reserva.call("estados") as Array).size(), (reserva.call("estados") as Array).size() >= 2)
			1:
				_ok("[MURO] %d cristales en dos filas; ancho %.2f de ±%.2f m, alto máx %.2f de %.2f m" % [e._cris.size(), float(c["xmax"]) - float(c["xmin"]), s.x, c["ymax"], s.y],
					e._cris.size() >= 20 and float(c["xmax"]) <= s.x * 1.02 and float(c["xmin"]) >= -s.x * 1.02 and float(c["ymax"]) <= s.y * 1.05 and float(c["ymax"]) >= s.y * 0.7)
			2:
				_ok("[PILAR] espiga central de alto %.2f (semieje y %.2f), %d cristales" % [c["ymax"], s.y, e._cris.size()], absf(float(c["ymax"]) - s.y) < s.y * 0.05 and e._cris.size() >= 8)
			3:
				var r: float = maxf(absf(float(c["xmin"])), float(c["xmax"]))
				_ok("[BARRERA] jaula de %d cristales dentro del radio (%.2f de %.2f) y cúpula tenue" % [e._cris.size(), r, s.x], r <= s.x * 1.01 and e._cris.size() >= 10 and e.find_child("Cupula", true, false) != null)
			4:
				_ok("[HAZ] lanza + púas: largo %.2f de %.2f m, sale del origen y mira a -Z; destello en la punta" % [-float(c["zmin"]), s.x * 2.0], absf(-float(c["zmin"]) - s.x * 2.0) < 0.35 and float(c["zmax"]) <= 0.3 and e.find_child("Punta", true, false) != null)
		if int(f[1]) >= 1 and int(f[1]) <= 3:
			var suelo: MeshInstance3D = e.find_child("Escarcha", true, false) as MeshInstance3D
			_ok("[%s] escarcha en la base más ancha que la figura (%.2f m)" % [f[0], suelo.scale.x if suelo != null else 0.0], suelo != null and suelo.scale.x >= s.x * 1.5)
		e.queue_free()
		await process_frame


# ------------------------------------------------------------------ 4. crecer por etapas ------------------------------------------------------------------

func _etapas() -> void:
	print("== crecer por etapas")
	var a: float = HieloToy.escalon(0.2)
	var b: float = HieloToy.escalon(0.55)
	var c: float = HieloToy.escalon(0.95)
	_ok("tres mesetas: escalon(0,2) = %.2f · escalon(0,55) = %.2f · escalon(0,95) = %.2f" % [a, b, c], absf(a - 0.34) < 0.01 and absf(b - 0.67) < 0.01 and absf(c - 1.0) < 0.01)
	_ok("meseta: entre 0,15 y 0,3 no cambia (%.3f → %.3f)" % [HieloToy.escalon(0.15), HieloToy.escalon(0.3)], absf(HieloToy.escalon(0.15) - HieloToy.escalon(0.3)) < 0.005)
	# en un pilar de verdad: la espiga central (retraso 0) pasa por 0,34 · 0,67 · 1 de su altura
	var e: HieloToy = _nueva()
	await process_frame
	e.definir(HieloToy.Figura.PILAR, 0.5, 4.0, 0.5, false)
	await process_frame
	var alturas: Array = []
	for cr in [0.0, 0.2, 0.55, 0.95]:
		e.crece = cr
		e._avanzar_cristales(0.0)
		alturas.append(e.alturas_actuales()[0])
	_ok("la espiga del pilar mide %.2f · %.2f · %.2f · %.2f m con crece 0 / 0,2 / 0,55 / 0,95 (de 4 m: 0, 34, 67 y 100 %%)" % [alturas[0], alturas[1], alturas[2], alturas[3]],
		absf(alturas[0]) < 0.001 and absf(alturas[1] - 1.36) < 0.08 and absf(alturas[2] - 2.68) < 0.08 and absf(alturas[3] - 4.0) < 0.08)
	var visibles: int = 0
	e.crece = 0.2
	e._avanzar_cristales(0.0)
	for h in e.alturas_actuales():
		if float(h) > 0.01:
			visibles += 1
	_ok("al principio no están todos: %d de %d cristales ya crecidos con crece = 0,2 (cada uno con su retraso)" % [visibles, e._cris.size()], visibles > 0 and visibles <= e._cris.size())
	var esc_ini: float = (e.find_child("Escarcha", true, false) as MeshInstance3D).scale.x
	e.crece = 1.0
	e._avanzar_cristales(0.0)
	_ok("la escarcha de la base se extiende con los escalones (%.2f → %.2f m)" % [esc_ini, (e.find_child("Escarcha", true, false) as MeshInstance3D).scale.x], (e.find_child("Escarcha", true, false) as MeshInstance3D).scale.x > esc_ini * 1.5)
	e.queue_free()
	await process_frame
	# la animación «nacer» recorre los escalones sin bajar
	var n: HieloToy = _nueva()
	await process_frame
	n.definir(HieloToy.Figura.PILAR, 0.5, 4.0, 0.5, false)
	await process_frame
	n.crece = 0.0
	n.lanzar(-1.0)
	var prev: float = -1.0
	var baja: bool = false
	var mesetas: int = 0
	var t0: int = Time.get_ticks_msec()
	var ult: float = -1.0
	var quieto: int = 0
	while float(Time.get_ticks_msec() - t0) < 1300.0:
		await process_frame
		_medir()
		var h0: float = float(n.alturas_actuales()[0])
		if h0 < prev - 0.001:
			baja = true
		if absf(h0 - ult) < 0.002 and h0 > 0.5 and h0 < 3.9:
			quieto += 1
			if quieto == 6:
				mesetas += 1
		else:
			quieto = 0
		ult = h0
		prev = h0
	_ok("nacer: la espiga crece sin bajar hasta %.2f m y se queda quieta en %d meseta(s) intermedia(s) (≥ 6 fotogramas seguidos)" % [prev, mesetas], not baja and absf(prev - 4.0) < 0.1 and mesetas >= 1)
	n.queue_free()
	await process_frame


# ------------------------------------------------------------------ 5. romperse ------------------------------------------------------------------

func _romperse() -> void:
	print("== romperse")
	var e: HieloToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 0, 0)
	e.definir(HieloToy.Figura.MURO, 3.45, 1.5, 0.3, false)
	await process_frame
	e.crece = 1.0
	e._avanzar_cristales(0.0)
	var n: int = e._cris.size()
	_ok("antes de romper no hay ninguno roto ni esquirlas", e.rotos() == 0 and (e.find_child("Esquirlas", true, false).call("vivas") as int) == 0)
	e.corte = 0.2
	e._avanzar_cristales(0.0)
	var ms: ShaderMaterial = (e.find_child("Cristales", true, false) as MultiMeshInstance3D).material_override as ShaderMaterial
	var grieta: float = float(ms.get_shader_parameter("grieta"))
	var r1: int = e.rotos()
	e.corte = 0.5
	e._avanzar_cristales(0.0)
	var r2: int = e.rotos()
	e.corte = 0.9
	e._avanzar_cristales(0.0)
	var r3: int = e.rotos()
	_ok("con corte 0,2 hay grietas (%.2f) y %d rotos; con 0,5 → %d; con 0,9 → %d de %d (cada cristal a su hora)" % [grieta, r1, r2, r3, n], grieta > 0.3 and r1 < r2 and r2 < r3 and r3 == n and r1 >= 0)
	var reserva: Node = e.find_child("Esquirlas", true, false)
	var est: Array = reserva.call("estados")
	_ok("al estallar suelta esquirlas (%d vivas)" % est.size(), est.size() >= 20)
	# la misma esquirla en dos instantes: gira (no se comprueba), cae (su vy baja) y rebota/queda en el suelo
	var antes: Dictionary = {}
	for s in est:
		antes[int((s as Dictionary)["hueco"])] = s
	reserva.call("avanzar", 0.12)
	var cae: int = 0
	var tot: int = 0
	for s2 in reserva.call("estados"):
		var d: Dictionary = s2
		var a: Dictionary = antes.get(int(d["hueco"]), {})
		if a.is_empty() or float(d["edad"]) <= float(a["edad"]) or bool(a["quieta"]) or bool(d["quieta"]):
			continue
		tot += 1
		if (d["vel"] as Vector3).y < (a["vel"] as Vector3).y - 0.5:
			cae += 1
	_ok("las esquirlas CAEN con la gravedad (%d de %d bajan su velocidad vertical)" % [cae, tot], tot > 0 and cae == tot)
	var quietas: int = 0
	var bajo: int = 0
	var rebotadas: int = 0
	for k in 40:
		reserva.call("avanzar", 0.03)
		var q: int = 0
		for s3 in reserva.call("estados"):
			var d3: Dictionary = s3
			if bool(d3["quieta"]):
				q += 1
			if int(d3["rebotes"]) > 0:
				rebotadas += 1
			if (d3["pos"] as Vector3).y < -0.021:
				bajo += 1
		quietas = maxi(quietas, q)
	_ok("al llegar al suelo rebotan una vez (%d tomas) y se quedan (hasta %d quietas a la vez) sin atravesarlo (%d por debajo)" % [rebotadas, quietas, bajo], rebotadas > 0 and quietas > 0 and bajo == 0)
	# morir: la figura se rompe por sí sola y se libera
	var fig: HieloToy = _nueva()
	await process_frame
	fig.definir(HieloToy.Figura.PILAR, 0.5, 4.0, 0.5, false)
	await process_frame
	fig.lanzar(-1.0)
	await _esperar(1.0)
	fig.morir()
	var rotos_max: int = 0
	var hubo_esq: bool = false
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(fig) and float(Time.get_ticks_msec() - t0) < 2500.0:
		await process_frame
		_medir()
		if is_instance_valid(fig):
			rotos_max = maxi(rotos_max, fig.rotos())
			var r: Node = fig.find_child("Esquirlas", true, false)
			if r != null and (r.call("vivas") as int) > 0:
				hubo_esq = true
	_ok("morir: se rompen (hasta %d cristales a la vez), suelta esquirlas y se libera sola (%s)" % [rotos_max, "sí" if not is_instance_valid(fig) else "no"], hubo_esq and not is_instance_valid(fig))
	# el nodo desaparece, pero las esquirlas que caían se quedan en el padre un par de segundos
	var huerfanas: int = 0
	for h in _raiz.get_children():
		if h is HieloEsquirlas or (h.get_script() != null and String(h.get_script().resource_path).ends_with("hielo_esquirlas.gd")):
			huerfanas += 1
	_ok("las esquirlas sobreviven al nodo un momento (%d reservas sueltas) y se liberan después" % huerfanas, huerfanas >= 1)
	e.queue_free()
	await _esperar(2.3)
	var quedan: int = 0
	for h2 in _raiz.get_children():
		if h2.get_script() != null and String(h2.get_script().resource_path).ends_with("hielo_esquirlas.gd"):
			quedan += 1
	_ok("…y se liberan solas (quedan %d)" % quedan, quedan == 0)


# ------------------------------------------------------------------ 6. carga ------------------------------------------------------------------

func _carga() -> void:
	print("== carga")
	var e: HieloToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 1, 0)
	e.empezar_carga(0.8, 0.4)
	var s0: float = _escala(e)
	_ok("nace pequeño: escala %.3f ≈ carga_tam_inicial %.2f" % [s0, e.carga_tam_inicial], absf(s0 - e.carga_tam_inicial) < 0.06)
	_ok("esta_cargando() y progreso empieza en ≈ 0", e.esta_cargando() and e.progreso_carga() < 0.15)
	var conv: Node = e.find_child("Convergencia", true, false)
	_ok("hay esquirlas, órbitas y escarcha bajo los pies", conv != null and conv.find_child("Esquirlas", true, false) != null and conv.find_child("Orbitas", true, false) != null and conv.find_child("Escarcha", true, false) != null)
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
			if float(gd["rad"]) <= float(gd["r0"]) + 0.0001 and d.dot(p.normalized()) < 0.2:
				conv_ok += 1
	_ok("crece sin bajar (escala %.2f)" % prev, not baja and prev > 0.7)
	_ok("las esquirlas convergen (%d de %d hacia dentro y por debajo del radio de nacimiento)" % [conv_ok, conv_tot], conv_tot > 0 and float(conv_ok) / float(conv_tot) > 0.97)
	var n_fin: int = int(conv.call("n_visibles"))
	_ok("hay más esquirlas cuanto más avanza la carga (%d → %d)" % [n_ini, n_fin], n_fin > n_ini)
	_ok("progreso_carga llega a 1", e.progreso_carga() > 0.85)
	var u_bajo: float = 0.0
	var u_alto: float = 0.0
	var nb: int = 0
	var na: int = 0
	for g2 in conv.call("estado_gotas"):
		var gd2: Dictionary = g2
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


func _soltar() -> void:
	print("== soltar")
	for etapa in ["llena", "a medias"]:
		var e: HieloToy = _nueva()
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


# ------------------------------------------------------------------ 7. impactos ------------------------------------------------------------------

func _impactos() -> void:
	print("== impactos")
	var casos: Array = [["GOLPE pared", ImpactoHieloToy.Variante.GOLPE, Vector3(0, 0, 1)], ["GOLPE suelo", ImpactoHieloToy.Variante.GOLPE, Vector3.UP], ["GOLPE techo", ImpactoHieloToy.Variante.GOLPE, Vector3.DOWN],
		["FIN", ImpactoHieloToy.Variante.FIN, Vector3.UP], ["REBOTE pared", ImpactoHieloToy.Variante.REBOTE, Vector3(1, 0, 0)], ["AREA", ImpactoHieloToy.Variante.AREA, Vector3.UP]]
	for c in casos:
		var radio: float = 1.8 if c[1] == ImpactoHieloToy.Variante.AREA else 0.4
		var imp: ImpactoHieloToy = ImpactoHieloToy.crear(c[1], c[2], radio)
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
		var g_ini: Array = imp.esquirlas_estado(0.1)
		var g_fin: Array = imp.esquirlas_estado(0.3)
		for t in [0.05, 0.1, 0.2, 0.3, 0.45]:
			for g in imp.esquirlas_estado(t):
				var gd: Dictionary = g
				if bool(gd["vivo"]):
					vivas += 1
					if c[1] != ImpactoHieloToy.Variante.FIN and float(gd["altura"]) < -0.006:
						bajo += 1
		if c[1] != ImpactoHieloToy.Variante.FIN:
			for i in g_ini.size():
				var a: Dictionary = g_ini[i]
				var b: Dictionary = g_fin[i]
				if bool(a["vivo"]) and bool(b["vivo"]) and float(a["retraso"]) == 0.0:
					cuenta += 1
					lejos0 += float(a["dist"])
					lejos1 += float(b["dist"])
					if float(b["vy"]) < float(a["vy"]) - 0.5 or float(b["vy"]) == 0.0:
						cae += 1
					cae_tot += 1
		var rc: Array = imp.recuento()
		_ok("[%s] %d esquirlas y %d cristales, hay esquirlas vivas" % [c[0], rc[0], rc[1]], int(rc[0]) >= 10 and vivas > 0)
		if c[1] == ImpactoHieloToy.Variante.FIN:
			_ok("[FIN] sin cristales ni escarcha ni destello", int(rc[1]) == 0 and imp.find_child("Escarcha", true, false) == null and imp.find_child("Destello", true, false) == null)
		else:
			_ok("[%s] hay cristales que brotan, escarcha y destello" % c[0], int(rc[1]) >= 2 and imp.find_child("Escarcha", true, false) != null and imp.find_child("Destello", true, false) != null)
			_ok("[%s] ninguna esquirla por debajo de la superficie (en el hemisferio de la normal)" % c[0], bajo == 0)
			_ok("[%s] las esquirlas se alejan (%.2f → %.2f m de media)" % [c[0], lejos0 / maxf(cuenta, 1), lejos1 / maxf(cuenta, 1)], cuenta > 0 and lejos1 > lejos0)
			_ok("[%s] CAEN: la velocidad vertical baja con la gravedad o están en la superficie (%d de %d)" % [c[0], cae, cae_tot], cae_tot > 0 and cae == cae_tot)
			# los cristales brotan y se rompen: a los 0,2 s hay (alto > 0) y a los 0,9 s ya no
			imp.avanzar_a(0.2)
			var mc: MultiMeshInstance3D = imp.find_child("Cristales", true, false) as MultiMeshInstance3D
			_ok("[%s] los cristales existen como MultiMesh (≤ 12)" % c[0], mc != null and mc.multimesh.instance_count <= 12)
		var t1: int = Time.get_ticks_msec()
		while is_instance_valid(imp) and float(Time.get_ticks_msec() - t1) < 2500.0:
			await process_frame
			_medir()
		_ok("[%s] se libera solo" % c[0], not is_instance_valid(imp))
	var pequeno: ImpactoHieloToy = ImpactoHieloToy.crear(ImpactoHieloToy.Variante.GOLPE, Vector3.UP, 0.2)
	var grande: ImpactoHieloToy = ImpactoHieloToy.crear(ImpactoHieloToy.Variante.GOLPE, Vector3.UP, 0.8)
	_raiz.add_child(pequeno)
	_raiz.add_child(grande)
	await process_frame
	var dmax_p: float = 0.0
	var dmax_g: float = 0.0
	for g in pequeno.esquirlas_estado(0.2):
		dmax_p = maxf(dmax_p, float((g as Dictionary)["dist"]))
	for g in grande.esquirlas_estado(0.2):
		dmax_g = maxf(dmax_g, float((g as Dictionary)["dist"]))
	_ok("el golpe escala con el radio (%.2f m con r 0,2 · %.2f m con r 0,8)" % [dmax_p, dmax_g], dmax_g > dmax_p * 1.5)
	pequeno.queue_free()
	grande.queue_free()
	await process_frame


# ------------------------------------------------------------------ 8. API de HieloToy ------------------------------------------------------------------

func _hay_impacto() -> bool:
	for h in _raiz.get_children():
		if h is ImpactoHieloToy:
			return true
	return false


func _limpiar_impactos() -> void:
	for h in _raiz.get_children():
		if h is ImpactoHieloToy:
			h.free()


func _api() -> void:
	print("== HieloToy: impactar_en / rebotar / terminar_sin_choque / finalizar")
	var e: HieloToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 1, 0)
	e.definir(HieloToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	await _esperar(0.3)
	e.impactar_en(Vector3(0, 1, -2), Vector3(0, 0, 1))
	_ok("impactar_en deja un impacto", _hay_impacto())
	await _esperar(0.6)
	_ok("impactar_en libera la bola", not is_instance_valid(e))
	_limpiar_impactos()
	await process_frame
	var r: HieloToy = _nueva()
	await process_frame
	r.global_position = Vector3(0, 1, 0)
	r.look_at(Vector3(0, 1, -5), Vector3.UP)
	r.definir(HieloToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	await process_frame
	var nd: Vector3 = r.rebotar(Vector3(0, 1, -2), Vector3(0, 0, 1))
	_ok("rebotar: la bola sigue viva, hay impacto y devuelve la dirección reflejada (%s)" % str(nd), is_instance_valid(r) and _hay_impacto() and nd.distance_to(Vector3(0, 0, 1)) < 0.01)
	_ok("rebotar: la bola mira hacia la dirección reflejada", (-r.global_transform.basis.z).distance_to(nd) < 0.01)
	await _esperar(0.9)
	_limpiar_impactos()
	r.queue_free()
	await process_frame
	var f: HieloToy = _nueva()
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
	var h: HieloToy = _nueva()
	await process_frame
	h.global_position = Vector3(0, 1, 0)
	h.finalizar("suelo", Vector3(0, 0, 0), Vector3.UP)
	_ok("finalizar('suelo') = impacto", _hay_impacto())
	await _esperar(0.6)
	_ok("finalizar('suelo') libera la bola", not is_instance_valid(h))
	_limpiar_impactos()
	var h2: HieloToy = _nueva()
	await process_frame
	h2.finalizar("alcance")
	_ok("finalizar('alcance') = fin sin choque", _hay_impacto())
	await _esperar(1.7)
	_ok("finalizar('alcance') libera la bola", not is_instance_valid(h2))
	_limpiar_impactos()
	# una bola que muere sin impacto se rompe en esquirlas
	var m: HieloToy = _nueva()
	await process_frame
	m.global_position = Vector3(0, 1, 0)
	await process_frame
	m.morir()
	var rs: Node = m.find_child("Esquirlas", true, false)
	_ok("una bola que muere sin impacto suelta esquirlas (%d)" % (rs.call("vivas") as int), (rs.call("vivas") as int) >= 10)
	await _esperar(0.8)
	# describir: la misma regla y la misma casilla que el fuego (el elemento no cambia la figura ni el tamaño)
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
		var da: Dictionary = HieloToy.describir(hh)
		var df: Dictionary = FuegoToy.describir(hh)
		iguales = iguales and int(da["figura"]) == int(df["figura"]) and is_equal_approx(float(da["x"]), float(df["x"])) and is_equal_approx(float(da["y"]), float(df["y"])) and is_equal_approx(float(da["z"]), float(df["z"])) and bool(da["viaja"]) == bool(df["viaja"])
	_ok("describir(h) es igual que el del fuego en bola, muro, pilar y barrera", iguales)
	var casilla_ok: bool = true
	for hh2 in hechizos:
		var d: HieloToy = _nueva()
		await process_frame
		var d_f: Dictionary = FuegoToy.describir(hh2, d.casilla)
		d.desde_hechizo(hh2)
		await process_frame
		casilla_ok = casilla_ok and int(d.figura) == int(d_f["figura"]) and is_equal_approx(d.semieje_x, float(d_f["x"])) and is_equal_approx(d.semieje_y, float(d_f["y"])) and d.viaja == bool(d_f["viaja"])
		d.queue_free()
	_ok("desde_hechizo: figura, semiejes y vuelo del fuego, con la misma casilla de %.1f m" % HieloToy.new().casilla, casilla_ok)
	await process_frame


# ------------------------------------------------------------------ 9. tamaños extremos (presupuesto) ------------------------------------------------------------------

func _extremos() -> void:
	print("== presupuesto en tamaños extremos")
	for ex in [["muro 8 · 4,6 · 3", 1, Vector3(8.0, 4.6, 3.0)], ["pilar 1,2 · 4,6", 2, Vector3(1.2, 4.6, 1.2)], ["barrera 6,9 · 4,6 · 6,9", 3, Vector3(6.9, 4.6, 6.9)], ["haz 3,45 · 0,9 · 0,4", 4, Vector3(3.45, 0.9, 0.4)], ["bola 1,2", 0, Vector3(1.2, 1.2, 1.2)]]:
		var e: HieloToy = _nueva()
		await process_frame
		e.definir(int(ex[1]), (ex[2] as Vector3).x, (ex[2] as Vector3).y, (ex[2] as Vector3).z, int(ex[1]) == 0)
		await process_frame
		e.lanzar(-1.0)
		await _esperar(1.0)
		e.morir()
		await _esperar(0.5)
		var cuenta: int = 0
		if is_instance_valid(e):
			for mm in e.find_children("*", "MultiMeshInstance3D", true, false):
				cuenta += (mm as MultiMeshInstance3D).multimesh.instance_count
		_ok("[%s] %d instancias de MultiMesh (≤ %d)" % [ex[0], cuenta, MAX_PARTICULAS], cuenta <= MAX_PARTICULAS)
		await _esperar(1.0)
		if is_instance_valid(e):
			e.queue_free()
		await process_frame


# ------------------------------------------------------------------ 10. lab y juego ------------------------------------------------------------------

func _lab() -> void:
	print("== lab: Z cicla fuego → agua → hielo → rayo")
	var src: String = FileAccess.get_file_as_string("res://laboratorios/lab_vfx_comparativa_3d.gd")
	_ok("el lab tiene la tecla Z", src.find("KEY_Z: alternar_elemento()") >= 0)
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	_ok("el lab empieza en fuego", String(lab.get("elemento")) == "fuego")
	var orden: Array = []
	for i in 4:
		lab.call("alternar_elemento")
		orden.append(String(lab.get("elemento")))
	_ok("Z cicla agua → hielo → rayo → fuego (%s)" % str(orden), orden == ["agua", "hielo", "rayo", "fuego"])
	lab.call("poner_elemento", "hielo")
	var e: Node3D = lab.call("carga_completa")
	_ok("G con hielo crea un HieloToy", e is HieloToy)
	var ip: Node3D = lab.call("impacto_pared")
	var isu: Node3D = lab.call("impacto_suelo")
	_ok("B y N con hielo crean ImpactoHieloToy", ip is ImpactoHieloToy and isu is ImpactoHieloToy)
	var m: Node3D = lab.call("lanzar_proyectil", "fin")
	var rb: Node3D = lab.call("lanzar_proyectil", "rebote")
	_ok("M y R con hielo crean HieloToy", m is HieloToy and rb is HieloToy)
	var pa: Node3D = lab.call("explosion_area")
	_ok("P con hielo crea un ImpactoHieloToy AREA", pa is ImpactoHieloToy and int(pa.get("variante")) == ImpactoHieloToy.Variante.AREA)
	var fp: Node3D = lab.call("fuego_param", 2)
	_ok("F7 con hielo crea un HieloToy PILAR", fp is HieloToy and int(fp.get("figura")) == 2)
	lab.call("eje_param", 1, 1)
	await process_frame
	_ok("el eje I cambia el semieje y del HieloToy", float(fp.get("semieje_y")) > 4.5)
	var hz: Node3D = lab.call("fuego_hechizo", 0)
	_ok("F9 con hielo crea un HieloToy desde un hechizo", hz is HieloToy)
	var txt: String = String(lab.call("_texto_carga"))
	_ok("la línea de ayuda muestra el elemento", txt.find("ELEMENTO: HIELO") >= 0)
	var rotulo: String = String(lab.call("_texto_param"))
	_ok("el rótulo del efecto paramétrico dice HIELO", rotulo.find("HIELO PARAMETRICO") >= 0, rotulo)
	lab.queue_free()
	await process_frame
	# el juego: VfxToyJuego crea HieloToy para el hielo
	var vj: VfxToyJuego = VfxToyJuego.new()
	vj.set("_mundo", _raiz)
	var t: Node3D = vj.call("_nuevo", "hielo")
	_ok("VfxToyJuego._nuevo(«hielo») crea un HieloToy y cuenta uno", t is HieloToy and int(vj.creados["hielo"]) == 1)
	t.free()
	_ok("VfxToyJuego.reemplaza(«hielo») depende del selector (%s)" % str(VfxToyJuego.ELEMENTOS), VfxToyJuego.ELEMENTOS.has("hielo") and VfxToyJuego.ELEMENTOS.has("rayo") and VfxToyJuego.reemplaza("hielo") == VfxToyJuego.activo())
	vj.free()
