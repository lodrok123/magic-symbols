extends "res://herramientas/escenario_base.gd"
## PRUEBA DE LA CASCADA Y LOS BORDES DEL AGUA (24/10, estilo Zelda: Echoes of Wisdom).
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_agua_cascada_eow.gd
## Sin ventana no hay GPU: mide el cableado (constantes → uniformes, pies de caída detectados en la simulación, láminas de cortina, gotas con tope, nada donde no hay caída),
## NO cómo se ve (eso lo dicen las capturas: herramientas/captura_agua_cascada_eow.gd, con ventana).
##   · A  el sombreado y las constantes (tamaño de `pies[]`, crestas por pie, uniformes de la cascada y de los bordes).
##   · B  el banco de la cascada (un salto de agua normal: terraza con agua arriba que cae a una charca, sin piezas especiales): pies, lámina, gotas, interruptores.
##   · C  una charca sin salto: ni pies ni lámina ni gotas.
##   · D  el Bosque 01 (sin cascadas): lo mismo que C, con la simulación de verdad.

const BANCO: GDScript = preload("res://herramientas/banco_cascada_eow.gd")
const RUTA_B01: String = "res://escenas/PruebaBosque01.tscn"
const SEGUNDOS_BANCO: float = 8.0


func _escenario() -> void:
	reloj = Reloj.new()
	root.add_child(reloj)
	_sombreado()
	await _banco()
	await _sin_caida()
	await cargar(RUTA_B01, true)
	_bosque()


func _param(r: AguaRender3D, nombre: String) -> Variant:
	return r.material_agua().get_shader_parameter(nombre)


# ---------------------------------------------------------------------------------------------------------------------
#  A · sombreado y constantes
# ---------------------------------------------------------------------------------------------------------------------

func _sombreado() -> void:
	print("== A · sombreado ==")
	var cod: String = AguaRender3D.CODIGO
	_ok("A1 el sombreado declara pies[%d] y pies_dir[%d] (= PIES_MAX)" % [AguaRender3D.PIES_MAX, AguaRender3D.PIES_MAX],
			cod.contains("uniform vec4 pies[%d];" % AguaRender3D.PIES_MAX) and cod.contains("uniform vec4 pies_dir[%d];" % AguaRender3D.PIES_MAX))
	_ok("A2 las crestas por pie del sombreado son ONDAS_PIE_N (%d)" % AguaRender3D.ONDAS_PIE_N, cod.contains("const int ONDAS_PIE_N = %d;" % AguaRender3D.ONDAS_PIE_N))
	_ok("A3 el sombreado tiene la tercera capa de vetas, la espuma por celdas del pie, las ondas, la línea ondulada y las manchas orgánicas",
			cod.contains("veta3") and cod.contains("efectos_pie") and cod.contains("ondas_m") and cod.contains("ondula_linea") and cod.contains("mancha_o"))
	_ok("A4 la lámina de cortina tiene tres capas y labio", AguaRender3D.CODIGO_CORTINA.contains("v3") and AguaRender3D.CODIGO_CORTINA.contains("labio"))
	_ok("A5 topes con nombre: gotas ≤ 64 (%d), pies ≤ 32 (%d)" % [AguaRender3D.GOTAS_MAX, AguaRender3D.PIES_MAX], AguaRender3D.GOTAS_MAX > 0 and AguaRender3D.GOTAS_MAX <= 64 and AguaRender3D.PIES_MAX <= 32)
	_ok("A6 tres capas de vetas a velocidades distintas (VEL_CAIDA %.1f, ×%.1f, ×%.1f)" % [AguaRender3D.VEL_CAIDA, AguaRender3D.CAIDA_VETA2_VEL, AguaRender3D.CAIDA_VETA3_VEL],
			not is_equal_approx(AguaRender3D.CAIDA_VETA2_VEL, AguaRender3D.CAIDA_VETA3_VEL) and not is_equal_approx(AguaRender3D.CAIDA_VETA3_VEL, 1.0))


# ---------------------------------------------------------------------------------------------------------------------
#  B · banco de la cascada
# ---------------------------------------------------------------------------------------------------------------------

func _banco() -> void:
	print("== B · banco de la cascada ==")
	var b: Node3D = BANCO.new()
	root.add_child(b)
	b.call("montar", 2.0)
	await avanzar_s(SEGUNDOS_BANCO)
	var r: AguaRender3D = b.get("render")
	var n: int = int(_param(r, "pies_n"))
	_ok("B1 hay pies de caída (%d) y no pasan de PIES_MAX" % n, n > 0 and n <= AguaRender3D.PIES_MAX)
	var pies: PackedVector4Array = _param(r, "pies")
	var dirs: PackedVector4Array = _param(r, "pies_dir")
	_ok("B2 los arrays del sombreado miden PIES_MAX", pies.size() == AguaRender3D.PIES_MAX and dirs.size() == AguaRender3D.PIES_MAX)
	var pie: Vector3 = b.call("pie_caida")
	var cerca: bool = n > 0
	var dir_ok: bool = n > 0
	for i in range(mini(n, pies.size())):
		cerca = cerca and absf(pies[i].y - pie.z) < 1.2 and pies[i].x > 1.5 * BANCO.S and pies[i].x < 5.5 * BANCO.S
		dir_ok = dir_ok and dirs[i].y > 0.9 and dirs[i].z > 0.0 and dirs[i].z <= 1.0       # la caída mira al sur: la charca queda hacia +z
	_ok("B3 los pies están en el borde de la caída (z ≈ %.1f, entre las columnas 2 y 5)" % pie.z, cerca)
	_ok("B4 su dirección apunta a la charca (+z) y su fuerza está entre 0 y 1", dir_ok)
	_ok("B5 el sombreado sabe que hay lámina de cortina", is_equal_approx(float(_param(r, "cortina_geom")), 1.0))
	var cortinas: MeshInstance3D = r.get("_cortinas")
	_ok("B6 hay una lámina de cortina por pie (%d vértices = 4 × %d)" % [cortinas.mesh.surface_get_array_len(0) if cortinas != null and cortinas.mesh != null else -1, n],
			cortinas != null and cortinas.visible and cortinas.mesh != null and cortinas.mesh.surface_get_array_len(0) == 4 * n)
	var gotas: GPUParticles3D = r.get("_gotas")
	_ok("B7 un único emisor de gotas con tope GOTAS_MAX (%d) que emite desde los pies" % AguaRender3D.GOTAS_MAX,
			gotas != null and gotas.amount == AguaRender3D.GOTAS_MAX and gotas.emitting and (gotas.process_material as ParticleProcessMaterial).emission_point_count == n)
	_ok("B8 los uniformes de la cascada llegan con el valor de la constante",
			is_equal_approx(float(_param(r, "caida_veta3")), AguaRender3D.CAIDA_VETA3) and is_equal_approx(float(_param(r, "cortina_opacidad")), AguaRender3D.CORTINA_OPACIDAD)
			and is_equal_approx(float(_param(r, "pie_espuma_radio")), AguaRender3D.PIE_ESPUMA_RADIO) and is_equal_approx(float(_param(r, "onda_pie_rmax")), AguaRender3D.ONDA_PIE_RMAX))
	_ok("B9 los uniformes de los bordes llegan (línea %.2f, manchas %.2f)" % [AguaRender3D.ORILLA_LINEA_RUIDO, AguaRender3D.SOMBRA_ORG_FUERZA],
			is_equal_approx(float(_param(r, "orilla_linea_ruido")), AguaRender3D.ORILLA_LINEA_RUIDO) and is_equal_approx(float(_param(r, "sombra_org_fuerza")), AguaRender3D.SOMBRA_ORG_FUERZA))
	var mat_c: ShaderMaterial = r.get("_mat_cortina")
	_ok("B10 la lámina lleva las tres velocidades de vetas",
			mat_c != null and is_equal_approx(float(mat_c.get_shader_parameter("veta2_vel")), AguaRender3D.CAIDA_VETA2_VEL) and is_equal_approx(float(mat_c.get_shader_parameter("veta3_vel")), AguaRender3D.CAIDA_VETA3_VEL))
	# Interruptores: sin gotas no emite; con el agua estilizada no hay lámina.
	r.gotas_caida = false
	r.set("_gotas_firma", 0)
	r.call("_buscar_caidas")
	_ok("B11 con `gotas_caida` apagado el emisor se para", not gotas.emitting)
	r.gotas_caida = true
	r.agua_filtro = false
	r.set("_gotas_firma", 0)
	r.call("_buscar_caidas")
	_ok("B12 con el agua estilizada no hay lámina de cortina", not cortinas.visible and is_equal_approx(float(_param(r, "cortina_geom")), 0.0))
	# Si la caída desaparece (se corta el manantial y se vacía la meseta) los pies se van.
	r.agua_filtro = true
	var agua: AguaSim3D = b.get("agua")
	for c in [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]:
		agua.apagar_fuente(c)
	await avanzar_s(20.0)
	r.set("_gotas_firma", 0)
	r.call("_buscar_caidas")
	_ok("B13 sin manantial la meseta se seca y los pies desaparecen (%d)" % int(_param(r, "pies_n")), int(_param(r, "pies_n")) < n)
	b.queue_free()
	await avanzar(5)


# ---------------------------------------------------------------------------------------------------------------------
#  C · charca sin salto
# ---------------------------------------------------------------------------------------------------------------------

func _sin_caida() -> void:
	print("== C · sin caída ==")
	var b: Node3D = BANCO.new()
	root.add_child(b)
	b.call("montar", 2.0)
	var agua: AguaSim3D = b.get("agua")
	for c in [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]:
		agua.apagar_fuente(c)                              # la meseta no vierte nada: solo queda la charca llena
	await avanzar_s(25.0)
	var r: AguaRender3D = b.get("render")
	r.set("_gotas_firma", 0)
	r.call("_buscar_caidas")
	_ok("C1 sin caída no hay pies (%d), ni lámina, ni gotas" % int(_param(r, "pies_n")),
			int(_param(r, "pies_n")) == 0 and (r.get("_cortinas") == null or not (r.get("_cortinas") as MeshInstance3D).visible) and (r.get("_gotas") == null or not (r.get("_gotas") as GPUParticles3D).emitting))
	b.queue_free()
	await avanzar(5)


# ---------------------------------------------------------------------------------------------------------------------
#  D · Bosque 01
# ---------------------------------------------------------------------------------------------------------------------

func _bosque() -> void:
	print("== D · Bosque 01 ==")
	var r: AguaRender3D = maqueta.get("_agua_render") as AguaRender3D
	_ok("D0 el Bosque 01 tiene su dibujo del agua", r != null)
	if r == null:
		return
	_ok("D1 el Bosque 01 (sin cascadas) no tiene pies de caída ni gotas", int(_param(r, "pies_n")) == 0 and (r.get("_gotas") == null or not (r.get("_gotas") as GPUParticles3D).emitting))
	_ok("D2 los uniformes de bordes llegan al agua del Bosque", is_equal_approx(float(_param(r, "sombra_org_escala")), AguaRender3D.SOMBRA_ORG_ESCALA) and is_equal_approx(float(_param(r, "orilla_linea_escala")), AguaRender3D.ORILLA_LINEA_ESCALA))
