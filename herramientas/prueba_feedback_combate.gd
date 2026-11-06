extends "res://herramientas/prueba_prevision_hechizo.gd"
## BLOQUE E «FEEDBACK» (6/11/2026; docs/PROPUESTAS_COMBATE_2026-11-06.md §2 bloque E). Sobre la ESCENA REAL (PruebaBosque), como `prueba_prevision_reaccion`, de la que hereda el montaje.
##   E1  juice del hechizo por potencia (`Sensacion3D.juice_hechizo`): ligera 0 / media 0,06 s + 0,10 / alta 0,12 s + 0,20, el retroceso del haz, y que salir e impactar lo piden de verdad.
##   E2  feedback propio de la reacción (`FeedbackReaccion3D`): oye `Mundo3D.reaccion`, elige el color de `PrevisionReaccion3D.ESTILO`, suena con tono propio y sólo vale para enemigos.
##   E3  golpe recibido escalado (`Sensacion3D.dano_recibido`) y aviso de vida baja del HUD (`HudEoW.aviso_vida_baja`): se enciende por debajo del 25 % y se apaga al curar.
##   E4  el rótulo «tinta N · recarga X s» del indicador (`PrevisionReaccion3D.rotulo_tinta`), en rojo sin tinta.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_feedback_combate.gd


## Un jugador de mentira con lo que lee `HudEoW` (como en prueba_hud_eow).
class JugadorFalso extends Node:
	var vida: float = 100.0
	var muerto: bool = false
	var bloqueado: bool = false
	var tinta: Tinta = null
	var mundo: Node = null
	var lanz: Node = null


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(30)
	await _e1()
	await _e2()
	await _e3()
	await _e4()
	print("COMPROBACIONES: %d" % _comprobaciones)


# --- E1 ----------------------------------------------------------------------------------------------------------------

func _e1() -> void:
	print("== E1 juice por potencia")
	_ok("E1.0 las constantes: ligera 0, media 0,06 s + 0,10, alta 0,12 s + 0,20",
		Array(Sensacion3D.HITSTOP_HECHIZO) == [0.0, 0.06, 0.12] and Array(Sensacion3D.TEMBLOR_HECHIZO) == [0.0, 0.10, 0.20])
	var esperados: Array = [[0, 0.0, 0.0], [1, 0.06, 0.10], [2, 0.12, 0.20]]
	for e in esperados:
		for impacto in [false, true]:
			jugador._t_hitstop = 0.0
			Sensacion3D.ultimo_juice = {}
			Sensacion3D.juice_hechizo(int(e[0]), impacto, lanzador)
			var u: Dictionary = Sensacion3D.ultimo_juice
			_ok("E1.1 nivel %d %s: hitstop %.2f y temblor %.2f" % [e[0], "impacto" if impacto else "salida", e[1], e[2]],
				is_equal_approx(float(u.get("hitstop", -1.0)), float(e[1])) and is_equal_approx(float(u.get("temblor", -1.0)), float(e[2])) and bool(u.get("impacto")) == impacto, str(u))
			_ok("E1.2 nivel %d: la jugadora %s" % [e[0], "no se congela" if float(e[1]) == 0.0 else "se congela %.2f s" % e[1]],
				is_equal_approx(float(jugador._t_hitstop), float(e[1])), "t=%.3f" % float(jugador._t_hitstop))
	await avanzar(2)
	Sensacion3D.juice_hechizo(9, false, lanzador)
	_ok("E1.3 un nivel fuera de rango se queda en el mayor (alta)", int(Sensacion3D.ultimo_juice["nivel"]) == 2)
	# el haz empuja a la jugadora hacia atrás; un proyectil no
	Sensacion3D.juice_hechizo(1, false, lanzador, Vector3(-1, 0, 0), true)
	_ok("E1.4 un haz al salir pide retroceso (RETROCESO_HAZ %.1f)" % Sensacion3D.RETROCESO_HAZ, bool(Sensacion3D.ultimo_juice["retroceso"]))
	Sensacion3D.juice_hechizo(1, false, lanzador, Vector3(-1, 0, 0), false)
	_ok("E1.5 un proyectil no", not bool(Sensacion3D.ultimo_juice["retroceso"]))
	Sensacion3D.juice_hechizo(1, true, lanzador, Vector3(-1, 0, 0), true)
	_ok("E1.6 el impacto de un haz tampoco empuja", not bool(Sensacion3D.ultimo_juice["retroceso"]))
	# de verdad, desde HechizoVivo: salir y chocar con un goblin
	var g: Combate3D = _goblin(Vector2i(9, 31), "", "")
	_creados.append(g)
	var datos: Dictionary = _preparar(Vector2i(11, 31), "fuego", ["flecha"])
	var nivel: int = (datos["hechizo"] as Hechizo).nivel_potencia
	Sensacion3D.ultimo_juice = {}
	_lanzar_real(datos, Vector3(-1, 0, 0))
	_ok("E1.7 al SALIR el hechizo real pide el juice de su nivel (%d)" % nivel, not Sensacion3D.ultimo_juice.is_empty() and int(Sensacion3D.ultimo_juice["nivel"]) == nivel and not bool(Sensacion3D.ultimo_juice["impacto"]), str(Sensacion3D.ultimo_juice))
	await avanzar_s(2.0)
	_ok("E1.8 al IMPACTAR en el goblin lo pide otra vez, ya como impacto", bool(Sensacion3D.ultimo_juice.get("impacto", false)) and int(Sensacion3D.ultimo_juice["nivel"]) == nivel, str(Sensacion3D.ultimo_juice))
	_limpiar()


# --- E2 ----------------------------------------------------------------------------------------------------------------

func _e2() -> void:
	print("== E2 feedback propio de la reacción")
	for aviso in FeedbackReaccion3D.FAMILIAS:
		var clave: String = String((FeedbackReaccion3D.FAMILIAS[aviso] as Array)[0])
		_ok("E2.0 «%s» usa el estilo «%s», que existe en PrevisionReaccion3D.ESTILO" % [aviso, clave], PrevisionReaccion3D.ESTILO.has(clave))
	for aviso in Mundo3D.REACCIONES:
		if aviso != Mundo3D.R_BLOQUEADO and aviso != Mundo3D.R_APAGADO_VIENTO:
			_ok("E2.0b la reacción «%s» del catálogo tiene familia" % aviso, FeedbackReaccion3D.FAMILIAS.has(aviso))
	_ok("E2.1 el oyente está enganchado a Mundo3D.reaccion (se engancha con ReaccionesVfx3D.conectar)", ReaccionesVfx3D.conectar(Mundo3D.actual, maqueta) and Mundo3D.actual.reaccion.is_connected(Callable(FeedbackReaccion3D, "_al_reaccionar")))
	Sfx.REGISTRAR = true
	Sfx.ULTIMOS.clear()
	var g: Combate3D = _goblin(Vector2i(9, 31), "", "")
	_creados.append(g)
	await avanzar(2)
	var antes: int = FeedbackReaccion3D.cuenta
	var mallas_antes: int = _mallas_hijas(FeedbackReaccion3D._fx)
	Mundo3D.avisar_reaccion("congelado", g.global_position, g)
	var u: Dictionary = FeedbackReaccion3D.ultimo
	_ok("E2.2 una reacción sobre un enemigo llega al oyente", FeedbackReaccion3D.cuenta == antes + 1 and String(u.get("aviso", "")) == "congelado", str(u))
	var col_estilo: Color = (PrevisionReaccion3D.ESTILO["congela"] as Array)[1]
	_ok("E2.3 el color es el de la previsión (ESTILO[congela])", (u["color"] as Color).is_equal_approx(col_estilo) and FeedbackReaccion3D.color_de("congelado").is_equal_approx(col_estilo))
	var sono: bool = false
	for s in Sfx.ULTIMOS:
		if String(s["nombre"]) == FeedbackReaccion3D.SONIDO and is_equal_approx(float(s["tono"]), 1.55):
			sono = true
	_ok("E2.4 suena el tintineo con el tono de la familia (1,55)", sono, str(Sfx.ULTIMOS.slice(-3)))
	_ok("E2.5 dibuja un anillo y un destello: 2 mallas nuevas colgando del padre de efectos", _mallas_hijas(FeedbackReaccion3D._fx) - mallas_antes == 2, "antes %d, ahora %d" % [mallas_antes, _mallas_hijas(FeedbackReaccion3D._fx)])
	var tonos: Dictionary = {}
	for aviso in ["prendido", "congelado", "electrocutado", "hundido", "aturdido"]:
		tonos[float((FeedbackReaccion3D.FAMILIAS[aviso] as Array)[2])] = true
	_ok("E2.6 cada familia fuerte tiene su tono (5 distintos)", tonos.size() == 5)
	_ok("E2.7 una reacción suave (mojado) dibuja pero no suena (tono 0)", float((FeedbackReaccion3D.FAMILIAS["mojado"] as Array)[2]) == 0.0)
	var objeto := Node3D.new()
	maqueta.add_child(objeto)
	_creados.append(objeto)
	_ok("E2.8 sobre algo que no es un enemigo no hace nada", FeedbackReaccion3D.reaccion("congelado", Vector3.ZERO, objeto).is_empty())
	FeedbackReaccion3D.ACTIVO = false
	_ok("E2.9 con ACTIVO = false tampoco", FeedbackReaccion3D.reaccion("congelado", Vector3.ZERO, g).is_empty())
	FeedbackReaccion3D.ACTIVO = true
	_limpiar()


## Cuántos MeshInstance3D cuelgan directamente de `n` (el anillo y el destello de la reacción lo hacen).
func _mallas_hijas(n: Node) -> int:
	var c: int = 0
	if n != null:
		for h in n.get_children():
			# solo las del feedback: el anillo (TorusMesh) y el disco plano (cilindro de 0,02); el efecto de la reacción (ReaccionesVfx3D) cuelga del mismo padre y no cuenta
			if h is MeshInstance3D and ((h as MeshInstance3D).mesh is TorusMesh or ((h as MeshInstance3D).mesh is CylinderMesh and is_equal_approx(((h as MeshInstance3D).mesh as CylinderMesh).height, 0.02))):
				c += 1
	return c


# --- E3 ----------------------------------------------------------------------------------------------------------------

func _e3() -> void:
	print("== E3 golpe recibido escalado y vida baja")
	var vmax: float = Estado.i().vida_max
	jugador.vida = vmax
	jugador._t_hitstop = 0.0
	Sensacion3D.dano_recibido(jugador, 5.0)
	var pequeno: Dictionary = Sensacion3D.ultimo_golpe.duplicate()
	jugador.vida = vmax * 0.6
	Sensacion3D.dano_recibido(jugador, vmax * 0.4)
	var grande: Dictionary = Sensacion3D.ultimo_golpe.duplicate()
	_ok("E3.1 un golpe leve tiembla poco (cerca de TEMBLOR_GOLPE_MIN %.2f)" % Sensacion3D.TEMBLOR_GOLPE_MIN, float(pequeno["temblor"]) >= Sensacion3D.TEMBLOR_GOLPE_MIN and float(pequeno["temblor"]) < 0.3, str(pequeno))
	_ok("E3.2 un golpe del %d %% de la vida llega a TEMBLOR_GOLPE_MAX %.2f" % [int(Sensacion3D.FRACCION_GOLPE_GRANDE * 100.0), Sensacion3D.TEMBLOR_GOLPE_MAX], is_equal_approx(float(grande["temblor"]), Sensacion3D.TEMBLOR_GOLPE_MAX), str(grande))
	_ok("E3.3 el grande tiembla más que el pequeño", float(grande["temblor"]) > float(pequeno["temblor"]))
	_ok("E3.4 ninguno de los dos deja la vida baja: hitstop normal %.2f" % Sensacion3D.HITSTOP_DANO, is_equal_approx(float(pequeno["hitstop"]), Sensacion3D.HITSTOP_DANO) and is_equal_approx(float(grande["hitstop"]), Sensacion3D.HITSTOP_DANO) and not bool(grande["vida_baja"]))
	jugador.vida = vmax * 0.2                                   # el golpe YA descontó: queda al 20 %
	jugador._t_hitstop = 0.0
	Sensacion3D.dano_recibido(jugador, 10.0)
	var baja: Dictionary = Sensacion3D.ultimo_golpe
	_ok("E3.5 el golpe que deja la vida por debajo del %d %% congela %.2f s" % [int(Sensacion3D.VIDA_BAJA * 100.0), Sensacion3D.HITSTOP_DANO_VIDA_BAJA], bool(baja["vida_baja"]) and is_equal_approx(float(baja["hitstop"]), Sensacion3D.HITSTOP_DANO_VIDA_BAJA) and is_equal_approx(float(jugador._t_hitstop), Sensacion3D.HITSTOP_DANO_VIDA_BAJA), str(baja))
	jugador.vida = vmax * 0.6
	Sensacion3D.dano_recibido(jugador, 10.0)
	var normal_v: float = float(Sensacion3D.ultimo_golpe["vineta"])
	jugador.vida = vmax * 0.2
	Sensacion3D.dano_recibido(jugador, 10.0)
	_ok("E3.6 la viñeta es más opaca en el golpe que deja la vida baja", float(Sensacion3D.ultimo_golpe["vineta"]) > normal_v, "%.2f vs %.2f" % [float(Sensacion3D.ultimo_golpe["vineta"]), normal_v])
	jugador.vida = vmax

	# el HUD, con un jugador de mentira
	var j := JugadorFalso.new()
	root.add_child(j)
	j.tinta = Tinta.new()
	j.tinta.partida = Estado.new()
	var hud := HudEoW.new()
	hud.jugador = j
	root.add_child(hud)
	await process_frame
	j.vida = vmax
	hud.actualizar()
	_ok("E3.7 con la vida llena no hay aviso ni borde", not hud.aviso_vida_baja and not hud._borde_vida.visible)
	j.vida = vmax * 0.26
	hud.actualizar()
	_ok("E3.8 justo por encima del 25 %: sin aviso", not hud.aviso_vida_baja)
	j.vida = vmax * 0.24
	hud.actualizar()
	_ok("E3.9 por debajo del 25 %: aviso y borde rojo", hud.aviso_vida_baja and hud._borde_vida.visible)
	var fuerzas: Array = []
	for i in range(40):                                          # 40 × 0,05 s = 2 s: más de un latido (1,2 s)
		hud._latido_vida_baja(0.05)
		fuerzas.append(float((hud._borde_vida.material as ShaderMaterial).get_shader_parameter("fuerza")))
	var mx: float = fuerzas.max()
	var mn: float = fuerzas.min()
	_ok("E3.10 el borde late: sube y baja entre %.2f y %.2f (tope ALFA_BORDE %.2f)" % [mn, mx, HudEoW.ALFA_BORDE_VIDA_BAJA], mx > mn + 0.05 and mx <= HudEoW.ALFA_BORDE_VIDA_BAJA + 0.001 and mn > 0.0, "%.3f %.3f" % [mn, mx])
	j.vida = vmax * 0.8                                          # cura
	hud.actualizar()
	_ok("E3.11 al curar se apaga", not hud.aviso_vida_baja and not hud._borde_vida.visible)
	j.vida = 0.0
	j.muerto = true
	hud.actualizar()
	_ok("E3.12 muerta tampoco hay aviso", not hud.aviso_vida_baja)
	hud.queue_free()
	j.queue_free()


# --- E4 ----------------------------------------------------------------------------------------------------------------

func _e4() -> void:
	print("== E4 tinta y recarga en el indicador")
	_ok("E4.0 el texto: «tinta 18 · recarga 2,0 s»", PrevisionReaccion3D.texto_tinta(17.2, 2.0) == "tinta 18 · recarga 2,0 s", PrevisionReaccion3D.texto_tinta(17.2, 2.0))
	var datos: Dictionary = _preparar(Vector2i(11, 31), "fuego", ["flecha"])
	lanzador._punto_vivo = jugador.position + Vector3(-1, 0, 0) * 2.0 * Terreno3D.casilla
	lanzador._calcular_origen_vivo()
	await avanzar(4)
	var v: PrevisionReaccion3D = lanzador._vista_reaccion
	_ok("E4.1 mientras se apunta hay rótulo de tinta visible", v != null and v.rotulo_tinta != null and v.rotulo_tinta.visible)
	if v == null or v.rotulo_tinta == null:
		return
	var h: Hechizo = datos["hechizo"]
	var coste: float = Lanzador3D.tinta_prevista(h, datos["rune"] as RuneData, lanzador.tinta)
	_ok("E4.2 dice la tinta y la recarga de la página preparada: «%s»" % PrevisionReaccion3D.texto_tinta(coste, h.recarga), v.rotulo_tinta.text == PrevisionReaccion3D.texto_tinta(coste, h.recarga), v.rotulo_tinta.text)
	_ok("E4.3 con tinta suficiente no va en rojo", v.rotulo_tinta.modulate.is_equal_approx(PrevisionReaccion3D.COLOR_TINTA), str(v.rotulo_tinta.modulate))
	lanzador.tinta.actual = 0.0
	lanzador.tinta.frascos = 0
	await avanzar(3)
	_ok("E4.4 sin tinta va en rojo", v.rotulo_tinta.modulate.is_equal_approx(PrevisionReaccion3D.COLOR_TINTA_FALTA), str(v.rotulo_tinta.modulate))
	lanzador.tinta.rellenar_barra()
	lanzador._cancelar_modo()
	await avanzar(3)
	_ok("E4.5 al salir del modo de apuntar el rótulo se va", not is_instance_valid(v) or v.rotulo_tinta == null or not v.rotulo_tinta.visible or not v.is_inside_tree())
