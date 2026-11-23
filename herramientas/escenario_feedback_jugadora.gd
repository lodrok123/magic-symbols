extends "res://herramientas/escenario_base.gd"
## G7 (22/11): FEEDBACK DE LA JUGADORA AL RECIBIR UN GOLPE. Sala del Gólem (gólem quieto y lejos), golpes por código con `recibir_dano` como los de un enemigo:
##   1 nunca desaparece: durante toda la invulnerabilidad (0,6 s) el modelo se ve, y en su lugar parpadea el brillo; al acabar, la emisión vuelve a la de antes;
##   2 tres tamaños: 12 pequeño, 20 medio, 45 grande (hitstop, viñeta, temblor, tambaleo y número);
##   3 viñeta con dirección: un golpe desde la derecha de la pantalla marca la derecha;
##   4 el golpe parado por el bálsamo se ve («Bloqueado»), sin quitar vida;
##   5 el daño ambiental destella en el cuerpo, sin hitstop;
##   6 la invulnerabilidad sin golpe (al reaparecer) también parpadea;
##   7 el golpe que mata cuenta como grande.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_feedback_jugadora.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaGolem.tscn"


func _listo(j: Jugador3D) -> void:
	j.vida = Estado.i().vida_max
	j._t_inv = 0.0
	j._t_hitstop = 0.0
	j._t_golpe = 0.0
	j._empuje = Vector3.ZERO
	j._fin_destello_color()


func _emision_media(j: Jugador3D) -> float:
	var s: float = 0.0
	var n: int = 0
	for m in j.pj._materiales:
		if is_instance_valid(m):
			s += (m as StandardMaterial3D).emission_energy_multiplier if (m as StandardMaterial3D).emission_enabled else 0.0
			n += 1
	return s / maxf(float(n), 1.0)


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if maqueta == null or jugador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var g: Node3D = z.nodo("golem_a") as Node3D if z != null else null
	if g != null:
		g.set("quieto", true)
		g.position = Terreno3D.centro_de(Vector2i(14, 1), Terreno3D.y_pies(Vector2i(14, 1)))
	colocar_jugador(Vector2i(6, 6))
	await avanzar_s(1.0)
	var j: Jugador3D = jugador as Jugador3D
	var vmax: float = Estado.i().vida_max
	_ok("0 la vida máxima es 100 (los tamaños se miden en fracción)", is_equal_approx(vmax, 100.0), str(vmax))
	var emision_antes: float = _emision_media(j)

	# --- 1 · nunca desaparece; parpadea el brillo ---
	_listo(j)
	j.recibir_dano(12.0, j.position + Vector3(-3, 0, 0))
	_ok("1 la invulnerabilidad dura %.1f s" % Jugador3D.INVULNERABLE, is_equal_approx(j._t_inv, Jugador3D.INVULNERABLE))
	var oculta: bool = false
	var con_brillo: int = 0
	var sin_brillo: int = 0
	var blanco_al_empezar: bool = false
	var t: float = 0.0
	while t < Jugador3D.INVULNERABLE:
		if not j.pj.visible:
			oculta = true
		var e: float = _emision_media(j)
		if t < 0.04 and e > 1.0:
			blanco_al_empezar = true
		if t > Jugador3D.DESTELLO_BLANCO_S + Jugador3D.DESTELLO_ROJO_S + 0.02:
			if e > 0.3:
				con_brillo += 1
			else:
				sin_brillo += 1
		t += await avanzar_s(1.0 / 30.0)
	_ok("1 el modelo NO se oculta en ningún fotograma de la invulnerabilidad", not oculta)
	_ok("1 al recibir, el cuerpo destella (emisión fuerte)", blanco_al_empezar)
	_ok("1 después parpadea el brillo (fotogramas con y sin brillo: %d / %d)" % [con_brillo, sin_brillo], con_brillo > 0 and sin_brillo > 0)
	await avanzar_s(0.5)
	_ok("1 al acabar, la emisión vuelve a la de antes (%.2f → %.2f)" % [emision_antes, _emision_media(j)], absf(_emision_media(j) - emision_antes) < 0.01 and not j._parpadeo_activo)

	# --- 2 · tres tamaños ---
	var res: Array = []
	for c in [12.0, 20.0, 45.0]:
		_listo(j)
		j.recibir_dano(c, j.position + Vector3(-3, 0, 0))
		res.append({"cant": c, "g": Sensacion3D.ultimo_golpe.duplicate(), "t_golpe": j._t_golpe})
		await avanzar_s(1.0)
	var p: Dictionary = res[0]["g"]
	var m: Dictionary = res[1]["g"]
	var gr: Dictionary = res[2]["g"]
	_ok("2 12 es pequeño, 20 medio y 45 grande", int(p["tamano"]) == 0 and int(m["tamano"]) == 1 and int(gr["tamano"]) == 2, "%d %d %d" % [int(p["tamano"]), int(m["tamano"]), int(gr["tamano"])])
	_ok("2 hitstop 0,05 / 0,08 / 0,15", is_equal_approx(float(p["hitstop"]), 0.05) and is_equal_approx(float(m["hitstop"]), 0.08) and is_equal_approx(float(gr["hitstop"]), 0.15),
		"%.2f %.2f %.2f" % [float(p["hitstop"]), float(m["hitstop"]), float(gr["hitstop"])])
	_ok("2 la viñeta del grande dura más (%.2f s frente a %.2f)" % [float(gr["t_vineta"]), float(p["t_vineta"])], float(gr["t_vineta"]) > float(p["t_vineta"]))
	_ok("2 el grande tiembla al máximo", is_equal_approx(float(gr["temblor"]), Sensacion3D.TEMBLOR_GOLPE_MAX))
	_ok("2 el grande tambalea más rato (bloqueo %.2f s frente a %.2f)" % [float(res[2]["t_golpe"]), float(res[0]["t_golpe"])], float(res[2]["t_golpe"]) > float(res[0]["t_golpe"]))

	# --- 3 · dirección ---
	_listo(j)
	var cam: Camera3D = get_root().get_viewport().get_camera_3d()
	var der: Vector3 = Vector3.RIGHT
	if cam != null:
		der = cam.global_transform.basis.x
		der.y = 0.0
		der = der.normalized()
	j.recibir_dano(12.0, j.position + der * 3.0)
	var dir: Vector2 = Sensacion3D.ultimo_golpe.get("dir", Vector2.ZERO)
	_ok("3 un golpe desde la derecha de la pantalla marca la derecha (dir %s)" % str(dir), dir.x > 0.8)
	var capa: CanvasLayer = j.get_meta("vineta_dano") if j.has_meta("vineta_dano") else null
	var mat: ShaderMaterial = (capa.get_node("R") as ColorRect).material as ShaderMaterial if capa != null else null
	_ok("3 la viñeta recibe la dirección y su peso", mat != null and (mat.get_shader_parameter("dir") as Vector2).x > 0.8 and float(mat.get_shader_parameter("peso_dir")) > 0.0)
	await avanzar_s(1.0)

	# --- 4 · golpe parado por el bálsamo ---
	_listo(j)
	var cons: Variant = j.hud_eow.consumibles if j.hud_eow != null else null
	if cons != null:
		cons.escudo_t = 10.0
		var b0: int = int(Sensacion3D.cuenta.get("bloqueado", 0))
		j.recibir_dano(20.0, j.position + Vector3(-3, 0, 0))
		_ok("4 el bálsamo para el golpe: no quita vida", is_equal_approx(j.vida, vmax))
		_ok("4 y se ve como golpe bloqueado", int(Sensacion3D.cuenta.get("bloqueado", 0)) == b0 + 1)
		_ok("4 sin hitstop", j._t_hitstop <= 0.0)
	else:
		_aviso("4 sin HUD en esta escena: no se prueba el bálsamo")
	await avanzar_s(0.5)

	# --- 5 · daño ambiental ---
	_listo(j)
	var q: float = j.dano_ambiental(4.0, "fuego")
	_ok("5 el daño ambiental quita vida (%.0f)" % q, q > 0.0)
	_ok("5 y destella en el cuerpo", _emision_media(j) > 0.3)
	_ok("5 sin hitstop", j._t_hitstop <= 0.0)
	await avanzar_s(0.5)

	# --- 6 · invulnerabilidad sin golpe (como al reaparecer) ---
	_listo(j)
	j._t_inv = 1.2
	await avanzar(2)
	_ok("6 la invulnerabilidad sin golpe arranca el parpadeo", j._parpadeo_activo)
	_ok("6 y no la oculta", j.pj.visible)
	await avanzar_s(1.5)

	# --- 7 · golpe que mata ---
	_listo(j)
	j.vida = 5.0
	j.recibir_dano(10.0, j.position + Vector3(-3, 0, 0))
	_ok("7 el golpe que mata cuenta como grande", j.muerto and int(Sensacion3D.ultimo_golpe["tamano"]) == 2)
