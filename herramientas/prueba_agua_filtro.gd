extends "res://herramientas/escenario_base.gd"
## PRUEBA DEL AGUA FILTRO (Pipeline, 22/10): el agua como filtro turquesa casi transparente sobre un lecho REAL (cantos + cáusticas), con interruptor `agua_filtro`.
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_agua_filtro.gd
## Sin ventana no hay GPU: mide el cableado (interruptor, uniformes, lecho falso apagado, material y textura del lecho, guijarros con la escala nueva, caída sin assets),
## NO cómo se ve ni que el shader compile en GPU (eso lo dicen las capturas: herramientas/captura_agua_filtro.gd).

const RUTA_LAB: String = "res://laboratorios/LabPlaytestEoW.tscn"
const RUTA_B01: String = "res://escenas/PruebaBosque01.tscn"


func _escenario() -> void:
	_estatico()
	await cargar(RUTA_LAB)
	await _escena("B")
	maqueta.queue_free()
	await avanzar(20)
	await cargar(RUTA_B01, true)
	await _escena("C")


# ---------------------------------------------------------------------------------------------------------------------
#  A · piezas sueltas (LechoRio3D)
# ---------------------------------------------------------------------------------------------------------------------

func _estatico() -> void:
	print("== A · LechoRio3D ==")
	_ok("A1 la ruta de la textura de Meshy está preparada: res://arte/suelo_meshy/lecho_rio.png", LechoRio3D.RUTA_TEXTURA == "res://arte/suelo_meshy/lecho_rio.png")
	var tex: Texture2D = LechoRio3D.textura()
	_ok("A2 hay textura de lecho (%s)" % ("la de Meshy" if LechoRio3D.hay_textura_archivo() else "procedural"), tex != null and tex.get_width() > 0)
	if not LechoRio3D.hay_textura_archivo():
		var p: ImageTexture = LechoRio3D.textura_procedural()
		_ok("A3 la procedural es de %dx%d y siempre el mismo objeto (caché)" % [p.get_width(), p.get_height()], p.get_width() == LechoRio3D.PROC_PX and p == LechoRio3D.textura_procedural())
		var img: Image = p.get_image()
		img.decompress() if img.is_compressed() else null
		var suma: float = 0.0
		var suma2: float = 0.0
		var n: int = 0
		var maxsat: float = 0.0
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var c: Color = img.get_pixel(x, y)
				var l: float = c.get_luminance()
				suma += l
				suma2 += l * l
				n += 1
				maxsat = maxf(maxsat, c.s)
		var media: float = suma / n
		var desv: float = sqrt(maxf(suma2 / n - media * media, 0.0))
		_ok("A4 BAJO contraste: desviación de luminancia %.3f (< 0.07)" % desv, desv < 0.07 and desv > 0.005)
		_ok("A5 tono de piedra/tierra: luminancia media %.2f entre 0.25 y 0.6, saturación máx %.2f (< 0.65)" % [media, maxsat], media > 0.25 and media < 0.6 and maxsat < 0.65)
		# Mosaico sin costuras: la columna 0 y la última se parecen como dos vecinas cualesquiera.
		var costura: float = 0.0
		var normal: float = 0.0
		for y in range(img.get_height()):
			costura += absf(img.get_pixel(0, y).get_luminance() - img.get_pixel(img.get_width() - 1, y).get_luminance())
			normal += absf(img.get_pixel(40, y).get_luminance() - img.get_pixel(41, y).get_luminance())
		_ok("A6 el mosaico repite sin costura (salto en el borde %.3f ≈ salto entre vecinos %.3f)" % [costura, normal], costura < normal * 2.0 + 0.02 * img.get_height())
	var m: ShaderMaterial = LechoRio3D.crear_material(0.78)
	_ok("A7 el material del lecho lleva textura, cáusticas y su shader", m.get_shader_parameter("t_lecho") != null and m.shader.code.contains("EMISSION") and float(m.get_shader_parameter("causticas")) > 0.0)
	_ok("A8 constantes: guijarro ×%.2f, densidad %.2f, color propio %.2f; algas %d ids, rocas %d ids" % [LechoRio3D.GUIJARRO_ESCALA, LechoRio3D.GUIJARRO_DENSIDAD, LechoRio3D.GUIJARRO_COLOR_PROPIO,
		LechoRio3D.IDS_ALGAS.size(), LechoRio3D.IDS_ROCAS.size()], LechoRio3D.GUIJARRO_ESCALA < 1.0 and LechoRio3D.IDS_ALGAS.size() == 4 and LechoRio3D.IDS_ROCAS.size() == 3
		and LechoRio3D.IDS_ALGAS[0] == "alga_0" and LechoRio3D.IDS_ROCAS[2] == "roca_rio_2")
	var viva: Color = Paleta3D.PIEDRA.lerp(Paleta3D.TIERRA, 0.5)
	var gris: Color = LechoRio3D.color_guijarro(viva)
	_ok("A9 el guijarro sale más desaturado y no más claro que la paleta (sat %.2f → %.2f)" % [viva.s, gris.s], gris.s < viva.s and gris.get_luminance() <= viva.get_luminance() + 0.001)
	# Caída sin assets.
	var disp: Array[String] = LechoRio3D.modelos_disponibles()
	var casillas: Array = []
	for i in range(30):
		casillas.append({"c": Vector2i(i, 3), "centro": Vector3(float(i) * 2.3, 0.0, 6.9), "profunda": true})
	var hash_fn := func(x: int, y: int, sal: int) -> int: return (x * 73856093) ^ (y * 19349663) ^ (sal * 83492791)
	var adornos: Node3D = LechoRio3D.construir_adornos(casillas, 2.3, hash_fn)
	if disp.is_empty():
		_ok("A10 sin modelos de algas ni de rocas no se crea nada (modelos_disponibles vacío, adornos null)", adornos == null)
	else:
		_ok("A10 hay modelos (%s): los adornos se esparcen (%d instancias)" % [disp, int(adornos.get_meta("instancias", 0)) if adornos != null else 0], adornos != null and int(adornos.get_meta("instancias", 0)) > 0)
		if adornos != null:
			adornos.free()
	_ok("A11 las rutas se buscan en arte/meshy/piezas/ y arte/suelo_meshy/", LechoRio3D.CARPETAS_ASSETS.has("res://arte/meshy/piezas/") and LechoRio3D.CARPETAS_ASSETS.has("res://arte/suelo_meshy/"))
	var vacias: Array = []
	for i in range(30):
		vacias.append({"c": Vector2i(i, 3), "centro": Vector3.ZERO, "profunda": false})
	var sin_prof: Node3D = LechoRio3D.construir_adornos(vacias, 2.3, hash_fn)
	_ok("A12 casillas de orilla (no profundas) no llevan adornos", sin_prof == null)


# ---------------------------------------------------------------------------------------------------------------------
#  B / C · en una escena con agua física
# ---------------------------------------------------------------------------------------------------------------------

func _render() -> AguaRender3D:
	return maqueta.get("_agua_render") as AguaRender3D


func _guijarros() -> MultiMeshInstance3D:
	return maqueta.get_node_or_null("lecho_rio") as MultiMeshInstance3D


## (instancias, diámetro máximo de los que no son el canto grande, saturación media) del último `_construir_lecho_rio` (el MultiMesh no se puede leer sin GPU).
func _medida_guijarros() -> Array:
	var d: Dictionary = maqueta.get("_lecho_rio_medida")
	return [int(d.get("n", 0)), float(d.get("diam_max", 0.0)), float(d.get("sat", 0.0))]


func _escena(et: String) -> void:
	print("== %s · %s ==" % [et, "laboratorio" if et == "B" else "Bosque 01"])
	var r: AguaRender3D = _render()
	_ok("%s1 hay AguaRender3D con material" % et, r != null and r.material_agua() != null)
	if r == null or r.material_agua() == null:
		return
	var m: ShaderMaterial = r.material_agua()
	await avanzar(15)
	_ok("%s2 agua_filtro encendido de serie, en la maqueta y en el render" % et, maqueta.get("agua_filtro") == true and r.agua_filtro == true and is_equal_approx(float(m.get_shader_parameter("filtro")), 1.0))
	_ok("%s3 las constantes FILTRO_* llegan al shader (absorción %s, densidad %.1f, prof máx %.1f, opacidad hondo %.2f)" % [et, AguaRender3D.FILTRO_ABSORCION, AguaRender3D.FILTRO_DENSIDAD, AguaRender3D.FILTRO_PROF_MAX, AguaRender3D.FILTRO_OPACIDAD_HONDO],
		(m.get_shader_parameter("filtro_k") as Vector3).is_equal_approx(AguaRender3D.FILTRO_ABSORCION) and is_equal_approx(float(m.get_shader_parameter("filtro_dens")), AguaRender3D.FILTRO_DENSIDAD)
		and is_equal_approx(float(m.get_shader_parameter("filtro_prof_max")), AguaRender3D.FILTRO_PROF_MAX) and is_equal_approx(float(m.get_shader_parameter("filtro_opacidad")), AguaRender3D.FILTRO_OPACIDAD_HONDO)
		and (m.get_shader_parameter("filtro_hondo") as Color).is_equal_approx(AguaRender3D.FILTRO_COLOR_HONDO))
	var k: Vector3 = AguaRender3D.FILTRO_ABSORCION
	_ok("%s4 la absorción da turquesa: el rojo se absorbe más que el verde y que el azul (k %s)" % [et, k], k.x > k.y and k.y >= k.z and k.z > 0.0)
	var t09: Vector3 = Vector3(exp(-k.x * 0.9 * AguaRender3D.FILTRO_DENSIDAD), exp(-k.y * 0.9 * AguaRender3D.FILTRO_DENSIDAD), exp(-k.z * 0.9 * AguaRender3D.FILTRO_DENSIDAD))
	var t03: Vector3 = Vector3(exp(-k.x * 0.3 * AguaRender3D.FILTRO_DENSIDAD), exp(-k.y * 0.3 * AguaRender3D.FILTRO_DENSIDAD), exp(-k.z * 0.3 * AguaRender3D.FILTRO_DENSIDAD))
	_ok("%s5 transmitancia a 0,9 u = (%.2f, %.2f, %.2f): verde y azul pasan, y a poco fondo casi todo pasa (0,3 u: %.2f %.2f %.2f)" % [et, t09.x, t09.y, t09.z, t03.x, t03.y, t03.z],
		t09.z > 0.5 and t09.y > 0.5 and t09.x < 0.35 and t03.x > 0.5 and t03.z > 0.85)
	_ok("%s6 el color de lo hondo es un turquesa oscuro (no blanco lechoso) y la opacidad del hondo es moderada (%.2f)" % [et, AguaRender3D.FILTRO_OPACIDAD_HONDO],
		AguaRender3D.FILTRO_COLOR_HONDO.get_luminance() < 0.4 and AguaRender3D.FILTRO_COLOR_HONDO.g > AguaRender3D.FILTRO_COLOR_HONDO.r and AguaRender3D.FILTRO_OPACIDAD_HONDO <= 0.6)
	_ok("%s7 superficie limpia: contraste de facetas %.2f y olas de la 3.ª escala %.2f (< %.2f de antes)" % [et, AguaRender3D.FILTRO_CONTRASTE_FACETA, float(m.get_shader_parameter("ola3_altura")), AguaRender3D.OLA3_ALTURA],
		AguaRender3D.FILTRO_CONTRASTE_FACETA <= 0.05 and is_equal_approx(float(m.get_shader_parameter("ola3_altura")), AguaRender3D.FILTRO_OLA3_ALTURA) and AguaRender3D.FILTRO_OLA3_ALTURA < AguaRender3D.OLA3_ALTURA)
	_ok("%s8 el lecho FALSO (red de Voronoi en la superficie) está apagado: uniform lecho = %.2f" % [et, float(m.get_shader_parameter("lecho"))], is_equal_approx(float(m.get_shader_parameter("lecho")), 0.0))
	_ok("%s9 espuma del centro reducida (×%.2f) y el agua pasa la primera (lee la pantalla)" % [et, AguaRender3D.FILTRO_MANCHAS], AguaRender3D.FILTRO_MANCHAS < 0.5 and m.render_priority == AguaRender3D.AGUA_PRIORIDAD)
	var cod: String = m.shader.code
	_ok("%s10 el shader lleva la absorción de Beer y la guarda del lecho falso" % et, cod.contains("exp(-filtro_k * filtro_dens * pf)") and cod.contains("filtro < 0.5") and cod.contains("normal_suave"))
	# El lecho de verdad.
	var malla: ArrayMesh = maqueta.get("_malla_lecho_agua") as ArrayMesh
	var mat_lecho: ShaderMaterial = maqueta.get("_mat_lecho_agua") as ShaderMaterial
	_ok("%s11 el bloque del lecho lleva el material de cantos (LechoRio3D), no el del suelo" % et, malla != null and mat_lecho != null and malla.surface_get_material(0) == mat_lecho)
	if mat_lecho != null:
		var tex: Texture2D = mat_lecho.get_shader_parameter("t_lecho") as Texture2D
		_ok("%s12 la textura de lecho está conectada (%s)" % [et, "res://arte/suelo_meshy/lecho_rio.png" if LechoRio3D.hay_textura_archivo() else "procedural"], tex != null and tex == LechoRio3D.textura())
		_ok("%s13 las cáusticas leen la profundidad de la simulación (datos puesto, usa_datos 1)" % et, mat_lecho.get_shader_parameter("datos") != null and is_equal_approx(float(mat_lecho.get_shader_parameter("usa_datos")), 1.0))
	var med_f: Array = _medida_guijarros()
	_ok("%s14 hay guijarros (%d) y los pequeños no pasan de %.2f u" % [et, int(med_f[0]), LechoRio3D.GUIJARRO_ESCALA * 0.34 + 0.001], int(med_f[0]) > 0 and float(med_f[1]) <= LechoRio3D.GUIJARRO_ESCALA * 0.34 + 0.001)
	_ok("%s15 sin assets de algas/rocas no hay adornos (%s)" % [et, LechoRio3D.modelos_disponibles()], not LechoRio3D.modelos_disponibles().is_empty() or maqueta.get("_adornos_lecho") == null)
	# Interruptor: apagado = lo de antes.
	maqueta.set("agua_filtro", false)
	await avanzar(5)
	m = r.material_agua()
	_ok("%s20 agua_filtro = false: uniform filtro 0, lecho falso 0,5, olas de siempre y refracción tal cual" % et,
		is_equal_approx(float(m.get_shader_parameter("filtro")), 0.0) and is_equal_approx(float(m.get_shader_parameter("lecho")), AguaRender3D.LECHO_FALSO)
		and is_equal_approx(float(m.get_shader_parameter("ola3_altura")), AguaRender3D.OLA3_ALTURA) and is_equal_approx(float(m.get_shader_parameter("refraccion")), 1.0))
	_ok("%s21 …el bloque del lecho vuelve al material del suelo" % et, malla != null and malla.surface_get_material(0) == maqueta.get("_mat_suelo_lecho") and malla.surface_get_material(0) != mat_lecho)
	var med_a: Array = _medida_guijarros()
	_ok("%s22 …y los guijarros vuelven a los de antes (%d instancias, máx %.2f u; con filtro eran %d, máx %.2f u)" % [et, int(med_a[0]), float(med_a[1]), int(med_f[0]), float(med_f[1])],
		int(med_a[0]) > int(med_f[0]) and float(med_a[1]) > float(med_f[1]) and float(med_a[2]) > float(med_f[2]))
	_ok("%s23 …y con el filtro apagado la prioridad sigue siendo la de la refracción" % et, m.render_priority == AguaRender3D.AGUA_PRIORIDAD)
	r.agua_refraccion = false
	await avanzar(2)
	_ok("%s24 filtro y refracción apagados: el agua de siempre, prioridad 0" % et, m.render_priority == 0 and is_equal_approx(float(m.get_shader_parameter("filtro")), 0.0))
	r.agua_refraccion = true
	maqueta.set("agua_filtro", true)
	await avanzar(5)
	_ok("%s25 …se vuelve a encender el filtro: material de cantos, guijarros pequeños, lecho falso 0" % et,
		malla != null and malla.surface_get_material(0) == mat_lecho and is_equal_approx(float(m.get_shader_parameter("lecho")), 0.0) and int(_medida_guijarros()[0]) == int(med_f[0]))
	r.agua_filtro = false
	_ok("%s26 AguaRender3D.agua_filtro = false por sí solo también apaga el filtro del shader" % et, is_equal_approx(float(m.get_shader_parameter("filtro")), 0.0))
	r.agua_filtro = true
	_ok("%s27 …y lo enciende" % et, is_equal_approx(float(m.get_shader_parameter("filtro")), 1.0))
	var pared: ShaderMaterial = r.get("_mat_pared") as ShaderMaterial
	_ok("%s28 las paredes laterales también van con filtro (casi transparentes)" % et, pared != null and is_equal_approx(float(pared.get_shader_parameter("filtro")), 1.0))
	await avanzar(10)
