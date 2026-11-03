extends "res://herramientas/captura_vfx_en_juego.gd"
## CAPTURAS DE LAS CINCO REGLAS GENERALES DE COMBINAR GLIFOS EN EL JUEGO (3/11/2026, R1…R5). NECESITA VENTANA. Amplía `captura_vfx_en_juego.gd` (el mismo Bosque 01 v01, la cámara DEL JUEGO y el mismo claro),
## con los seis hechizos de las reglas, cada uno en una secuencia de fotogramas (los toys de fuego y agua de serie; el rayo, con su dibujo de siempre):
##   fuego: muro que avanza (ᛜ ᛁ ᛏ ᛏ ᛇ: 1,5 m de alto, que la hierba no lo tape) · muro que va y vuelve (… + ᛃ) · orbes (ᚠ ᚠ ᛃ)      agua: pilar ascendente (ᛏ ᛏ ᛏ ᚷ) · explosión (ᚷ ᚷ ⧖)      rayo: hacia delante (ᛁ ᛁ ᛁ)
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_reglas_glifos.gd -- [carpeta] [solo_hechizo|*]
## Por defecto escribe en res://docs/capturas/vfx_en_juego/reglas_glifos/: <hechizo>_<t>.png y, de cada fotograma, la altura de la jugadora en el registro (`ALTURA`). La hoja resumen la monta
## `herramientas/hoja_reglas_glifos.ps1` (PowerShell + System.Drawing). Se miran a ojo (no hay `_ok`).

const REGLAS: Array = [
	["r1_muro_fuego", "R1 · fuego · ᛜ ᛁ ᛏ ᛏ ᛇ: el muro AVANZA", ["barrera", "linea_x", "altura", "altura", "flecha"], {"el": "fuego", "tiempos": [0.15, 0.55, 1.0, 1.5, 2.2], "sin_desplazo": true}],
	["r2_muro_va_y_vuelve", "R2 · fuego · ᛜ ᛁ ᛏ ᛏ ᛇ ᛃ: va y VUELVE", ["barrera", "linea_x", "altura", "altura", "flecha", "retorno"], {"el": "fuego", "tiempos": [0.15, 0.7, 1.3, 1.9, 2.6, 3.2], "sin_desplazo": true}],
	["r3_orbes_fuego", "R3 · fuego · ᚠ ᚠ ᛃ: tres ORBES", ["repeticion", "repeticion", "retorno"], {"el": "fuego", "tiempos": [0.2, 0.6, 1.0, 1.5, 2.2], "sin_desplazo": true}],
	["r4_pilar_agua", "R4 · agua · ᛏ ᛏ ᛏ ᚷ: pilar que SUBE", ["altura", "altura", "altura", "pulso"], {"el": "agua", "tiempos": [0.2, 0.6, 1.0, 1.5, 2.2], "sin_desplazo": true}],
	["r5_explosion_agua", "R5 · agua · ᚷ ᚷ ⧖: EXPLOSIÓN", ["pulso", "pulso", "retardo"], {"el": "agua", "tiempos": [0.5, 1.2, 1.8, 2.05, 2.4, 3.0], "sin_desplazo": true}],
	["rayo_adelante", "Rayo · ᛁ ᛁ ᛁ: hacia delante (no se toca)", ["linea_x", "linea_x", "linea_x"], {"el": "rayo", "tiempos": [0.1, 0.3, 0.6, 1.0], "sin_desplazo": true}],
]


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	_dir = "res://docs/capturas/vfx_en_juego/reglas_glifos"
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1] != "*":
		_solo_h = a[1]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Misiones.nuevo()
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	lanzador.tinta = null
	lanzador.libro = null          # el libro del Bosque solo deja 3 huecos de glifo abiertos: aquí se componen hasta 6, como un libro completo
	_ocultar_ui(root)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	var c: Vector2i = _buscar_claro()
	_ok("0 hay un claro de 9 × 5 casillas llano para las capturas (%s)" % str(c), c != Vector2i(-1, -1))
	if c == Vector2i(-1, -1):
		return
	colocar_jugador(c)
	await avanzar_s(2.0)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, true)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, VfxToyJuego.ELEMENTOS_DEFECTO)      # lo de serie: fuego y agua con el toy; el rayo, con su dibujo
	for hz in REGLAS:
		if _solo_h != "" and _solo_h != String(hz[0]):
			continue
		colocar_jugador(c)
		await avanzar_s(0.4)
		await _una_regla(hz)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)
	var f: FileAccess = FileAccess.open(_dir.path_join("celdas.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_json, "  "))
	f.close()
	print("escrito ", _dir)


func _una_regla(hz: Array) -> void:
	var id: String = String(hz[0])
	var opc: Dictionary = hz[3] as Dictionary
	var el: String = String(opc["el"])
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(el)
	for g in (hz[2] as Array):
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	var origen: Vector3 = jugador.position
	var salio: bool = lanzador.lanzar_pagina_ya(0, origen, DIR, false)
	_ok("1 %s: sale el hechizo" % id, salio)
	var vivo: HechizoVivo = null
	for n in lanzador.get_children():
		if n is HechizoVivo:
			vivo = n as HechizoVivo
	var t_ant: float = 0.0
	for t in (opc["tiempos"] as Array):
		await avanzar_s(float(t) - t_ant)
		t_ant = float(t)
		_ocultar_ui(root)
		var nombre: String = "%s_%03d" % [id, int(round(float(t) * 100.0))]
		root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
		print("ALTURA %s t=%.2f: jugadora y=%.2f (suelo %.2f) vy=%.2f en_suelo=%s nadando=%s · hechizo vivo %s%s" % [id, float(t), jugador.position.y, Terreno3D.y_pies(Terreno3D.celda_de(jugador.position)), float(jugador.vy), str(jugador.en_suelo), str(jugador.nadando), str(is_instance_valid(vivo)), (" · elevados %d t_nacido %.2f columna %d alto %.2f" % [vivo.elevados, vivo._t_nacido, vivo.columna.size(), vivo.altura_columna_u()]) if is_instance_valid(vivo) else ""])
		var toys: Array = []
		for n in maqueta.get_children():
			if n is FuegoToy or n is AguaToy:
				toys.append("%s fig=%s pos=%s esc=%s vis=%s" % [n.get_class(), str(n.get("figura")), str((n as Node3D).global_position), str((n as Node3D).scale), str((n as Node3D).is_visible_in_tree())])
		print("TOYS %s t=%.2f jugadora en %s: %s" % [id, float(t), str(jugador.position), str(toys)])
		_json.append({"id": nombre, "hechizo": id, "titulo": String(hz[1]), "t": float(t)})
	await avanzar_s(3.0)             # que se apague todo antes del siguiente
