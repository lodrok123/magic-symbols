extends "res://herramientas/escenario_base.gd"
## PANEL DE LUZ DEL MAPA (F3, 2/11): PanelLuz3D en el Bosque 01 v01. Oculto al montar; alternar; HORA/SOMBRAS/SOMBRA_OPACIDAD/SOL_INCLINACION_EXTRA/NOCHE_SOL_ENERGIA escriben donde toca;
## cambiar respeta min/max; restaurar lo devuelve todo; texto_valores una línea por fila; con los valores por defecto el ciclo da lo de siempre.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_panel_luz.gd

const RUTA_V01: String = "res://escenas/PruebaBosque01_v01.tscn"


func _cerca(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _escenario() -> void:
	var guarda_dur: float = CicloDia3D.DURACION_DIA_S
	var guarda_hora: float = CicloDia3D.HORA
	await cargar(RUTA_V01)
	var panel: PanelLuz3D = maqueta.get_node_or_null("PanelLuz3D") as PanelLuz3D
	_ok("1 la maqueta tiene PanelLuz3D", panel != null)
	if panel == null:
		return
	_ok("1 el panel nace oculto", not panel.visible)
	panel.alternar()
	_ok("1 alternar lo muestra", panel.visible)
	panel.alternar()
	_ok("1 alternar otra vez lo oculta", not panel.visible)
	var sol: DirectionalLight3D = maqueta.get("_sol") as DirectionalLight3D
	_ok("1 hay sol y ciclo", sol != null and maqueta.get_node_or_null("CicloDia3D") != null)

	# Capa 1 de contraste (ContrasteLuz3D): al cargar el Bosque está ENCENDIDA de serie y los seis valores son los del preset.
	var env0: Environment = maqueta.get("_env") as Environment
	_ok("1b CAPA1_CONTRASTE es la primera fila", String(PanelLuz3D.FILAS[0][0]) == "CAPA1_CONTRASTE" and panel.es_booleana("CAPA1_CONTRASTE"))
	_ok("1b al cargar: ContrasteLuz3D.ACTIVO true y la fila vale sí", ContrasteLuz3D.ACTIVO and panel.valor("CAPA1_CONTRASTE") >= 0.5)
	_ok("1b al cargar: AMBIENTE_FACTOR 0,5 · SOL_FACTOR 1,3 · SOMBRA_BLUR 0,5", _cerca(LuzZona3D.AMBIENTE_FACTOR, 0.5, 0.0001) and _cerca(LuzZona3D.SOL_FACTOR, 1.3, 0.0001) and _cerca(LuzZona3D.SOMBRA_BLUR, 0.5, 0.0001))
	_ok("1b al cargar: Hierba3D.RECIBE_SOMBRA true", Hierba3D.RECIBE_SOMBRA)
	_ok("1b al cargar: Posproceso3D SSAO 2,0 / 1,4", _cerca(Posproceso3D.SSAO_INTENSIDAD, 2.0, 0.0001) and _cerca(Posproceso3D.SSAO_RADIO, 1.4, 0.0001))
	if env0 != null and env0.ssao_enabled:
		_ok("1b al cargar: env.ssao_intensity 2,0 y ssao_radius 1,4", _cerca(env0.ssao_intensity, 2.0, 0.0001) and _cerca(env0.ssao_radius, 1.4, 0.0001), "%.2f %.2f" % [env0.ssao_intensity, env0.ssao_radius])
	else:
		print("  (sin SSAO en este renderer: solo se comprueban las static vars de Posproceso3D)")

	# Estado de partida (con el reloj parado para que las comparaciones sean exactas).
	CicloDia3D.DURACION_DIA_S = 0.0
	panel.poner("DURACION_DIA_S", 0.0)
	var panel2: PanelLuz3D = panel
	# Los «originales» del panel son los del montaje; los reponemos tal cual para la prueba de restaurar.
	_ok("2 valor(HORA) == CicloDia3D.HORA", _cerca(panel.valor("HORA"), CicloDia3D.HORA, 0.0001))
	panel.poner("HORA", 22.0)
	_ok("2 poner(HORA, 22) -> CicloDia3D.HORA 22", _cerca(CicloDia3D.HORA, 22.0, 0.0001), str(CicloDia3D.HORA))
	await avanzar(2)
	_ok("2 con DURACION_DIA_S = 0 la hora sigue en 22", _cerca(CicloDia3D.HORA, 22.0, 0.0001), str(CicloDia3D.HORA))

	panel.poner("SOMBRAS", 0.0)
	_ok("3 SOMBRAS 0 -> shadow_enabled false", not sol.shadow_enabled)
	panel.poner("SOMBRAS", 1.0)
	_ok("3 SOMBRAS 1 -> shadow_enabled true", sol.shadow_enabled)

	panel.poner("SOMBRA_OPACIDAD", 0.5)
	await avanzar(2)
	_ok("4 SOMBRA_OPACIDAD 0,5 -> sol.shadow_opacity ≈ 0,5", _cerca(sol.shadow_opacity, 0.5), str(sol.shadow_opacity))

	panel.poner("HORA", 10.0)
	await avanzar(2)
	var pitch0: float = sol.rotation_degrees.x
	panel.poner("SOL_INCLINACION_EXTRA", -10.0)
	await avanzar(2)
	var pitch1: float = sol.rotation_degrees.x
	_ok("5 SOL_INCLINACION_EXTRA -10 baja el pitch 10°", _cerca(pitch0 - pitch1, 10.0, 0.05), "%.2f -> %.2f" % [pitch0, pitch1])

	panel.poner("HORA", 2.0)
	panel.poner("NOCHE_SOL_ENERGIA", 0.3)
	var e_noche: float = float(CicloDia3D.transformar(LuzZona3D.valores("bosque"), 2.0)["sol_energia"])
	_ok("6 NOCHE_SOL_ENERGIA 0,3 -> transformar a las 2 h ≈ 0,3", _cerca(e_noche, 0.3), str(e_noche))

	# cambiar con Shift (×10 pasos) respeta min y max
	panel.poner("SOMBRA_OPACIDAD", 0.9)
	var i_op: int = _indice("SOMBRA_OPACIDAD")
	panel.cambiar(i_op, 10)
	_ok("7 cambiar ×10 respeta el máximo", _cerca(panel.valor("SOMBRA_OPACIDAD"), 1.0, 0.0001), str(panel.valor("SOMBRA_OPACIDAD")))
	panel.cambiar(i_op, -100)
	_ok("7 cambiar ×-100 respeta el mínimo", _cerca(panel.valor("SOMBRA_OPACIDAD"), 0.0, 0.0001), str(panel.valor("SOMBRA_OPACIDAD")))
	panel.poner("SOMBRA_DISTANCIA", 5.0)
	_ok("7 SOMBRA_DISTANCIA no baja de 10", _cerca(panel.valor("SOMBRA_DISTANCIA"), 10.0, 0.0001))
	panel.poner("CICLO_ACTIVO", 0.4)
	_ok("7 bool: 0,4 -> no", panel.valor("CICLO_ACTIVO") < 0.5)
	panel.poner("CICLO_ACTIVO", 0.6)
	_ok("7 bool: 0,6 -> sí", panel.valor("CICLO_ACTIVO") >= 0.5)

	# texto_valores: una línea por fila
	var lineas: PackedStringArray = panel.texto_valores().split("\n", false)
	_ok("8 texto_valores tiene una línea por fila", lineas.size() == PanelLuz3D.FILAS.size(), "%d vs %d" % [lineas.size(), PanelLuz3D.FILAS.size()])

	# restaurar: vuelve a lo del montaje
	panel.restaurar()
	await avanzar(2)
	_ok("9 restaurar: HORA", _cerca(CicloDia3D.HORA, guarda_hora, 0.2), "%.2f vs %.2f" % [CicloDia3D.HORA, guarda_hora])
	_ok("9 restaurar: SOMBRA_OPACIDAD 1", _cerca(LuzZona3D.SOMBRA_OPACIDAD, 1.0, 0.0001) and _cerca(sol.shadow_opacity, 1.0))
	_ok("9 restaurar: SOL_INCLINACION_EXTRA 0", _cerca(LuzZona3D.SOL_INCLINACION_EXTRA, 0.0, 0.0001))
	_ok("9 restaurar: NOCHE_SOL_ENERGIA 0,12", _cerca(CicloDia3D.NOCHE_SOL_ENERGIA, 0.12, 0.0001))
	_ok("9 restaurar: DURACION_DIA_S del montaje", _cerca(CicloDia3D.DURACION_DIA_S, guarda_dur, 0.0001), str(CicloDia3D.DURACION_DIA_S))
	_ok("9 restaurar: sombras encendidas", sol.shadow_enabled)

	# valores por defecto: el ciclo da lo de siempre
	var base: Dictionary = LuzZona3D.valores("bosque")
	var e13: float = float(CicloDia3D.transformar(base, 13.0)["sol_energia"])
	var e2: float = float(CicloDia3D.transformar(base, 2.0)["sol_energia"])
	_ok("10 por defecto: a las 13 h energía 1,0", _cerca(e13, 1.0), str(e13))
	_ok("10 por defecto: a las 2 h energía 0,12", _cerca(e2, 0.12), str(e2))
	_ok("10 por defecto: noche_k(2) = 1 y noche_k(13) = 0", _cerca(CicloDia3D.noche_k(2.0), 1.0) and _cerca(CicloDia3D.noche_k(13.0), 0.0))

	# Contraste de sombra: factores de sol y ambiente y la hierba con sombra (todo por defecto = como siempre)
	# CAMBIO DE CONTRATO A PROPÓSITO (5/11): «por defecto = sol 1,0 y ambiente 0,6» es la luz de ANTES; con la capa 1 encendida (ya es el valor de serie) es otra.
	# Por eso estas comprobaciones se hacen con el preset APAGADO (se vuelve a encender más abajo). Los umbrales no se tocan.
	panel.poner("CAPA1_CONTRASTE", 0.0)
	var env: Environment = maqueta.get("_env") as Environment
	_ok("11 hay Environment", env != null)
	_ok("11 por defecto: SOL_FACTOR y AMBIENTE_FACTOR 1 y la hierba sin sombra", _cerca(LuzZona3D.SOL_FACTOR, 1.0, 0.0001) and _cerca(LuzZona3D.AMBIENTE_FACTOR, 1.0, 0.0001) and not Hierba3D.RECIBE_SOMBRA)
	panel.poner("DURACION_DIA_S", 0.0)
	panel.poner("HORA", 13.0)
	await avanzar(2)
	var e_sol0: float = sol.light_energy
	var e_amb0: float = env.ambient_light_energy
	var e_esp: float = float(CicloDia3D.transformar(LuzZona3D.valores(String(maqueta.get("zona_luz"))), 13.0)["sol_energia"])
	_ok("11 por defecto: sol.light_energy es la energía del ciclo a las 13 h", _cerca(e_sol0, e_esp, 0.02), "%.3f vs %.3f" % [e_sol0, e_esp])
	_ok("11 por defecto: hay luz de sol y de ambiente", e_sol0 > 0.1 and e_amb0 > 0.1, "%.3f %.3f" % [e_sol0, e_amb0])
	panel.poner("SOL_FACTOR", 1.5)
	await avanzar(2)
	_ok("12 SOL_FACTOR 1,5 -> sol.light_energy ≈ 1,5 × la de antes", _cerca(sol.light_energy, 1.5 * e_sol0, 0.01), "%.3f vs %.3f" % [sol.light_energy, 1.5 * e_sol0])
	_ok("12 SOL_FACTOR no toca el ambiente", _cerca(env.ambient_light_energy, e_amb0, 0.001))
	panel.poner("AMBIENTE_FACTOR", 0.5)
	await avanzar(2)
	_ok("13 AMBIENTE_FACTOR 0,5 -> env.ambient_light_energy ≈ 0,5 × el de antes", _cerca(env.ambient_light_energy, 0.5 * e_amb0, 0.01), "%.3f vs %.3f" % [env.ambient_light_energy, 0.5 * e_amb0])
	var hierba: Variant = maqueta.get("_hierba")
	var mat_m: ShaderMaterial = (hierba as Hierba3D).get("_mat_matojo") as ShaderMaterial if hierba is Hierba3D else null
	if mat_m != null:
		_ok("14 antes: el shader del matojo tiene shadows_disabled", mat_m.shader.code.contains("shadows_disabled"))
	panel.poner("HIERBA_SOMBRA", 1.0)
	_ok("14 HIERBA_SOMBRA 1 -> Hierba3D.RECIBE_SOMBRA true", Hierba3D.RECIBE_SOMBRA)
	_ok("14 HIERBA_SOMBRA es booleana y vale 1", panel.es_booleana("HIERBA_SOMBRA") and panel.valor("HIERBA_SOMBRA") >= 0.5)
	if mat_m != null:
		_ok("14 el shader del matojo ya NO contiene shadows_disabled", not mat_m.shader.code.contains("shadows_disabled"))
		var mat_t: ShaderMaterial = (hierba as Hierba3D).get("_mat_tarjeta") as ShaderMaterial
		var mat_f: ShaderMaterial = (hierba as Hierba3D).get("_mat_flor") as ShaderMaterial
		_ok("14 tarjetas y flores igual", (mat_t == null or not mat_t.shader.code.contains("shadows_disabled")) and mat_f != null and not mat_f.shader.code.contains("shadows_disabled"))
	panel.poner("HIERBA_SOMBRA", 0.0)
	_ok("15 HIERBA_SOMBRA 0 -> RECIBE_SOMBRA false", not Hierba3D.RECIBE_SOMBRA)
	if mat_m != null:
		_ok("15 el shader del matojo vuelve a contener shadows_disabled", mat_m.shader.code.contains("shadows_disabled"))
	_ok("15 texto_valores sigue con una línea por fila", panel.texto_valores().split("\n", false).size() == PanelLuz3D.FILAS.size())
	panel.poner("HIERBA_SOMBRA", 1.0)
	panel.restaurar()
	await avanzar(2)
	# Los «originales» del panel ya son los de la capa 1 (se aplica antes de montarlo), así que restaurar devuelve el preset encendido.
	_ok("16 restaurar: vuelve la capa 1 (sol 1,3 · ambiente 0,5 · hierba con sombra)", _cerca(LuzZona3D.SOL_FACTOR, 1.3, 0.0001) and _cerca(LuzZona3D.AMBIENTE_FACTOR, 0.5, 0.0001) and Hierba3D.RECIBE_SOMBRA)
	if mat_m != null:
		_ok("16 restaurar: el shader de la hierba no tiene shadows_disabled", not mat_m.shader.code.contains("shadows_disabled"))

	# Preset de contraste: apagado -> la luz de antes; encendido -> la capa 1; las filas sueltas mandan por encima; restaurar devuelve ACTIVO.
	panel.restaurar()
	panel.poner("CAPA1_CONTRASTE", 1.0)
	panel.poner("DURACION_DIA_S", 0.0)
	panel.poner("HORA", 13.0)
	await avanzar(2)
	var e_c1: float = sol.light_energy
	panel.poner("CAPA1_CONTRASTE", 0.0)
	await avanzar(2)
	var e_ant: float = sol.light_energy
	_ok("17 CAPA1_CONTRASTE 0 -> ACTIVO false y la fila vale no", not ContrasteLuz3D.ACTIVO and panel.valor("CAPA1_CONTRASTE") < 0.5)
	_ok("17 apagado: 1,0 / 1,0 / false / 1,6", _cerca(LuzZona3D.AMBIENTE_FACTOR, 1.0, 0.0001) and _cerca(LuzZona3D.SOL_FACTOR, 1.0, 0.0001) and not Hierba3D.RECIBE_SOMBRA and _cerca(LuzZona3D.SOMBRA_BLUR, 1.6, 0.0001))
	_ok("17 apagado: SSAO 1,2 / 1,0 (static vars)", _cerca(Posproceso3D.SSAO_INTENSIDAD, 1.2, 0.0001) and _cerca(Posproceso3D.SSAO_RADIO, 1.0, 0.0001))
	if env.ssao_enabled:
		_ok("17 apagado: env.ssao_intensity 1,2 y ssao_radius 1,0", _cerca(env.ssao_intensity, 1.2, 0.0001) and _cerca(env.ssao_radius, 1.0, 0.0001))
	_ok("17 apagado: sol.light_energy baja en proporción (÷1,3)", e_ant > 0.1 and _cerca(e_c1 / e_ant, 1.3, 0.02), "%.3f / %.3f" % [e_c1, e_ant])
	panel.poner("CAPA1_CONTRASTE", 1.0)
	await avanzar(2)
	_ok("18 encendido: vuelven 0,5 / 1,3 / true / 0,5", ContrasteLuz3D.ACTIVO and _cerca(LuzZona3D.AMBIENTE_FACTOR, 0.5, 0.0001) and _cerca(LuzZona3D.SOL_FACTOR, 1.3, 0.0001) and Hierba3D.RECIBE_SOMBRA and _cerca(LuzZona3D.SOMBRA_BLUR, 0.5, 0.0001))
	_ok("18 encendido: SSAO 2,0 / 1,4 y el sol vuelve a su energía", _cerca(Posproceso3D.SSAO_INTENSIDAD, 2.0, 0.0001) and _cerca(Posproceso3D.SSAO_RADIO, 1.4, 0.0001) and _cerca(sol.light_energy, e_c1, 0.01))
	if env.ssao_enabled:
		_ok("18 encendido: env.ssao 2,0 / 1,4", _cerca(env.ssao_intensity, 2.0, 0.0001) and _cerca(env.ssao_radius, 1.4, 0.0001))
	panel.poner("SOL_FACTOR", 2.0)
	_ok("19 una fila suelta no cambia ACTIVO", ContrasteLuz3D.ACTIVO and _cerca(LuzZona3D.SOL_FACTOR, 2.0, 0.0001))
	panel.poner("SSAO_INTENSIDAD", 3.0)
	_ok("19 SSAO_INTENSIDAD 3,0 -> static var 3,0", _cerca(Posproceso3D.SSAO_INTENSIDAD, 3.0, 0.0001) and _cerca(panel.valor("SSAO_INTENSIDAD"), 3.0, 0.0001))
	if env.ssao_enabled:
		_ok("19 SSAO_INTENSIDAD 3,0 -> env.ssao_intensity 3,0", _cerca(env.ssao_intensity, 3.0, 0.0001))
	panel.poner("CAPA1_CONTRASTE", 0.0)
	panel.restaurar()
	await avanzar(2)
	_ok("20 restaurar: ACTIVO true, sol 1,3, SSAO 2,0 / 1,4", ContrasteLuz3D.ACTIVO and _cerca(LuzZona3D.SOL_FACTOR, 1.3, 0.0001) and _cerca(Posproceso3D.SSAO_INTENSIDAD, 2.0, 0.0001) and _cerca(Posproceso3D.SSAO_RADIO, 1.4, 0.0001) and Hierba3D.RECIBE_SOMBRA)

	# Dejarlo todo como estaba
	panel2.restaurar()
	CicloDia3D.reiniciar()
	CicloDia3D.DURACION_DIA_S = 600.0
	print("FIN (guarda dur %.0f)" % guarda_dur)


func _indice(nombre: String) -> int:
	for i in range(PanelLuz3D.FILAS.size()):
		if String(PanelLuz3D.FILAS[i][0]) == nombre:
			return i
	return -1
