extends SceneTree
## ¿Cuánto tarda en cargar un personaje y en reproducir cada uno de sus clips? Para cazar bloqueos del laboratorio.
##   godot --headless --path . --script res://herramientas/medidas_carga_pj.gd -- <id> [id...]
## Imprime el tiempo de Pj3D.cargar y, por clip, el de ponerlo a andar unos fotogramas. Va imprimiendo ANTES de cada paso,
## así que si se cuelga, la última línea dice dónde.

func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = ["fantasma_elfo_rig"]
	for id in ids:
		print("== ", id, ": cargando…")
		var t0: int = Time.get_ticks_msec()
		var p := Pj3D.new()
		root.add_child(p)
		var ok: bool = p.cargar(String(id))
		print("   cargar -> %s en %d ms" % [ok, Time.get_ticks_msec() - t0])
		if not ok:
			continue
		p.set_alto(0.9)
		await process_frame
		print("   clips: ", p.lista_clips().size(), "  tiene fuente: ", ClipsFamilia.tiene_fuente(String(id)), "  tipo: ", Pj3D.tipo_de(String(id)))
		for rol in ["idle", "walk", "run", "cast", "hit", "death"]:
			var t1: int = Time.get_ticks_msec()
			print("   rol %s -> «%s»…" % [rol, p.clip_de(rol)])
			p.jugar(rol)
			for i in 5:
				await process_frame
			print("      %d ms" % (Time.get_ticks_msec() - t1))
		p.queue_free()
		await process_frame
	print("FIN")
	quit(0)
