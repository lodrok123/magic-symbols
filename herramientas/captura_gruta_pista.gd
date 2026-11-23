extends "res://herramientas/escenario_base.gd"
## FOTO DE LA PISTA DE USO INMEDIATO EN LA GRUTA BATIDA (23/11, sesión HECHIZOS; PLAN_HECHIZOS §4.5 H6). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_gruta_pista.gd -- <carpeta>
## La jugadora lleva FUEGO + FLECHA en la página 1 (kit `gruta`). Abre el cofre del santuario (ᛜ): al cerrarse la ceremonia ᛜ queda escrito en esa página y sale la pista del HUD
## («Pulsa 1 · …») y el marcador del suelo en la casilla desde la que se levanta la barrera (9,13). Fotos: `pista_hud` (con el marcador a la vista) y `pista_marcador` (más cerca).
## Solo mira; los contratos los comprueban `prueba_glifo_equipado.gd` y `escenario_gruta_batida.gd`.

const RUTA: String = "res://escenas/PruebaGrutaBatida.tscn"
var _dir: String = "res://docs/capturas/fichas_glifo_2026-11-23/v2"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(30)
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var tesoro: Puzle3D.CofrePuzle = z.nodo("tesoro") as Puzle3D.CofrePuzle
	var lz: Grimorio = get_first_node_in_group("spellcaster") as Grimorio
	Repertoire.max_pages = 2                        # partida de 2 páginas (la 2.ª vacía): el glifo nuevo estrena la 2.ª
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	Input.parse_input_event(f1)                     # esconde la paleta de pruebas
	await avanzar(5)
	lz.select_page(0)
	lz.place_element("fuego")
	lz.place_sigil("flecha")
	print("página 1 antes: ", lz.nombre_pagina(0))
	colocar_jugador(Vector2i(12, 12))
	await avanzar_s(1.0)
	Engine.time_scale = 2.0
	tesoro.abrir()
	var seq: SecuenciaCofreLegendario3D = tesoro.secuencia
	var guardia: int = 0
	while seq != null and not seq.hecha and guardia < 3000:
		if seq.esperando_input:
			seq.continuar()
		await process_frame
		guardia += 1
	Engine.time_scale = 1.0
	print("página 1 después: ", lz.nombre_pagina(0), " · pista: ", seq.pista != null, " · página equipada: ", seq.pagina_equipada)
	var pg: PistaGlifo = seq.pista
	if pg != null and pg.marcador != null:
		print("marcador en ", pg.marcador.global_position, " visible ", pg.marcador.is_visible_in_tree(), " jugador ", jugador.global_position)
	colocar_jugador(Vector2i(10, 13))
	await avanzar_s(2.2)
	await _foto("gruta_pista_hud")
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	maqueta.set("_tam_camara", 5.5)
	if cam != null:
		cam.size = 5.5
	await avanzar_s(1.5)
	await _foto("gruta_pista_marcador")


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join("%s.png" % nombre))
	print("foto ", nombre)
