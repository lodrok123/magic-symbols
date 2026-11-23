extends "res://herramientas/escenario_base.gd"
## C25 de PLAN_COMBATE (22/11): mide el clip de ataque del guerrero goblin (LeftSlash) para el golpe seco, sobre sus PISTAS de rotación (sin esqueleto): la velocidad angular de los
## huesos de los brazos y el tronco en cada 0,01 del clip. El brazo casi quieto justo antes del golpe = la CARGA (arma atrás); el pico de velocidad = el CONTACTO.
##   godot --headless --path . --script res://herramientas/medir_clip_guerrero.gd

const HUESOS: Array = ["RightArm", "RightForeArm", "LeftArm", "LeftForeArm", "Spine1", "Spine2"]

func _escenario() -> void:
	await cargar("res://escenas/PruebaArenaCombate.tscn", true)
	var c := Vector2i(11, 10)
	var r: Dictionary = {"clase": "combate", "id": "goblin_warrior_chibi", "casa": Terreno3D.centro_de(c, Terreno3D.y_pies(c)), "nombre_nodo": "Medida", "nombre": "g",
		"debil": "", "resiste": "", "fijo": false, "quieto": true, "premia_tinta": true, "suelta_recogibles": false, "puestos_disparo": [], "puesto_cubierto": Vector3.ZERO, "escudo": false, "coraza": ""}
	var g: Combate3D = Combate3D.recrear(r, maqueta as Node3D, jugador as Jugador3D, lanzador)
	await avanzar(5)
	var pj: Pj3D = g.pj
	var clip: String = pj.clip_de("attack")
	var anim: Animation = pj._ap.get_animation(clip)
	print("   clip %s · %.2f s · momento de golpe %.2f · %d pistas" % [clip, anim.length, Combate3D.MOMENTO_GOLPE_GUERRERO, anim.get_track_count()])
	var pistas: Dictionary = {}
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var ruta: String = str(anim.track_get_path(t))
		for h in HUESOS:
			if ruta.ends_with(":mixamorig_" + h) or ruta.ends_with(":" + h) or ruta.ends_with("_" + h):
				pistas[h] = t
	print("   pistas: ", pistas.keys())
	var paso: float = 0.01
	var fr: float = paso
	var cab: String = "   frac  " + "  ".join(pistas.keys().map(func(h: String) -> String: return h.rpad(12)))
	print(cab)
	while fr <= 0.40 + 0.0001:
		var linea: String = "   %.2f  " % fr
		var suma: float = 0.0
		for h in pistas:
			var t: int = int(pistas[h])
			var q0: Quaternion = anim.rotation_track_interpolate(t, (fr - paso) * anim.length)
			var q1: Quaternion = anim.rotation_track_interpolate(t, fr * anim.length)
			var w: float = rad_to_deg(q0.angle_to(q1)) / (paso * anim.length)       # °/s
			suma += w
			linea += ("%.0f" % w).rpad(14)
		print(linea + "  total %.0f" % suma)
		fr += paso
