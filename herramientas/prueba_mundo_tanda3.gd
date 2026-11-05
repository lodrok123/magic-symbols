extends "res://herramientas/escenario_base.gd"
## GAMEFEEL TERCERA TANDA, LOTE 3 · MUNDO (2/11; docs/REVISION_GAMEFEEL_30-10.md §9): C1 marcador de misión en el mundo, C3 ambiente sonoro por zona, N ciclo día y noche.
## Primero lo que no necesita nivel (con un mapa falso: un Node3D con sol y entorno, cámara y jugador de mentira); al final, sobre las escenas reales (Bosque 01 v01 y la Cueva).
##   1 MARCADOR  misión con punto fuera de pantalla → flecha con distancia y en el borde; a menos de 5 u → oculta; objetivo en pantalla → rombo; sin punto → nada; punto por grupo; punto por objetivo
##               (el primer pendiente manda); completar → desaparece; MARCADOR_MISION_ACTIVO = false → nada; Sensacion3D.ACTIVA = false → se ve igual (es información)
##   2 AMBIENTE  bosque → bucle en el bus «Mundo» a −18 dB; a la cueva → fundido cruzado de 2 s (los dos suenan en medio, luego solo uno); pájaros a INTERVALO_PAJAROS forzado a 1-2 s; de noche callan
##               y entran los grillos; Sfx.AJUSTES manda; AMBIENTE_ACTIVO = false → silencio; sala → zumbido
##   3 DÍA/NOCHE avanza 24 h en DURACION_DIA_S; a las 13 la luz tiene la elevación máxima y ≥ 0,9 de la energía del día; a las 2 energía ≤ 0,15 y azulada; el color de la zona sigue MULTIPLICADO;
##               sin saltos de color entre horas consecutivas (> 0,2); es_noche(); DURACION = 0 → parado; niebla y luna; la cueva no lo monta; sin sol no se monta
##   4 ESCENAS   Bosque 01 v01: monta ciclo + ambiente + marcador, los puntos de la misión, el sol manda el ciclo sobre Zonas3D; Cueva: ambiente de cueva y sin ciclo
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_mundo_tanda3.gd

const RUTA_V01: String = "res://escenas/PruebaBosque01_v01.tscn"
const RUTA_CUEVA: String = "res://escenas/PruebaCueva.tscn"


## Un mapa de mentira con lo que CicloDia3D y AmbienteZona le piden a la maqueta.
class FalsaMaqueta extends Node3D:
	var zona_luz: String = "bosque"
	var nivel: String = "Bosque_prueba"
	var estilo: String = ""
	var _sol: DirectionalLight3D = null
	var _env: Environment = null


func _mapa(nivel: String = "Bosque_prueba", zona: String = "bosque", con_sol: bool = true, estilo: String = "") -> FalsaMaqueta:
	var fm := FalsaMaqueta.new()
	fm.nivel = nivel
	fm.zona_luz = zona
	fm.estilo = estilo
	if con_sol:
		fm._sol = DirectionalLight3D.new()
		fm.add_child(fm._sol)
		fm._env = Environment.new()
		LuzZona3D.aplicar(fm._env, fm._sol, zona)
	root.add_child(fm)
	return fm


func _cerca(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _color_cerca(a: Color, b: Color, tol: float = 0.01) -> bool:
	return _cerca(a.r, b.r, tol) and _cerca(a.g, b.g, tol) and _cerca(a.b, b.b, tol)


func _escenario() -> void:
	var guarda: Dictionary = {"hora": CicloDia3D.HORA, "dur": CicloDia3D.DURACION_DIA_S, "sens": Sensacion3D.ACTIVA, "marc": MarcadorMision.MARCADOR_MISION_ACTIVO,
		"amb": AmbienteZona.AMBIENTE_ACTIVO, "int": AmbienteZona.INTERVALO_PAJAROS, "luna": CicloDia3D.LUNA_ACTIVA}
	Sfx.REGISTRAR = true
	Sfx.vaciar_registro()
	Sensacion3D.ACTIVA = true
	await _marcador()
	await _ambiente()
	_dia_noche()
	await _escenas_reales()
	CicloDia3D.HORA = float(guarda["hora"])
	CicloDia3D.DURACION_DIA_S = float(guarda["dur"])
	Sensacion3D.ACTIVA = bool(guarda["sens"])
	MarcadorMision.MARCADOR_MISION_ACTIVO = bool(guarda["marc"])
	AmbienteZona.AMBIENTE_ACTIVO = bool(guarda["amb"])
	AmbienteZona.INTERVALO_PAJAROS = guarda["int"]
	CicloDia3D.LUNA_ACTIVA = bool(guarda["luna"])
	Sfx.AJUSTES.erase("amb_bosque")
	Sfx.REGISTRAR = false
	print("COMPROBACIONES: %d" % _comprobaciones)


var _comprobaciones: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	_comprobaciones += 1
	super._ok(nombre, bien, info)


# ---------------------------------------------------------------------------------------------------------------------
#  1 · Marcador de misión
# ---------------------------------------------------------------------------------------------------------------------
func _marcador() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 12.0, 12.0)
	root.add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.current = true
	var jug := Node3D.new()
	root.add_child(jug)
	var tam := Vector2(1152.0, 648.0)
	var mk := MarcadorMision.new()
	root.add_child(mk)
	mk.jugador = jug
	mk.camara = cam
	mk.tamano = tam
	mk.set_process(false)
	MarcadorMision.MARCADOR_MISION_ACTIVO = true
	Sensacion3D.ACTIVA = true

	var M: Misiones = Misiones.nuevo()
	M.definir({"id": "lejos", "titulo": "Lejos", "tipo": "principal", "objetivos": ["Ir"], "punto_objetivo": Vector3(120.0, 0.0, 0.0)})
	M.activar("lejos")
	mk.actualizar()
	_ok("1 misión con punto fuera de pantalla → flecha", mk.estado == "flecha", mk.estado)
	var esperado: int = int(round(120.0 / Terreno3D.casilla))
	_ok("1 la flecha lleva la distancia en metros (1 casilla = 1 m): %d" % esperado, mk.metros == esperado, str(mk.metros))
	var m: float = MarcadorMision.MARGEN_MARCADOR
	_ok("1 la punta está en el borde de la pantalla (a la derecha, dentro del margen)", _cerca(mk.punta.x, tam.x - m, 1.0) and mk.punta.y > m - 1.0 and mk.punta.y < tam.y - m + 1.0, str(mk.punta))
	_ok("1 el objetivo resuelto es el punto de la misión", mk.objetivo is Vector3 and (mk.objetivo as Vector3).is_equal_approx(Vector3(120.0, 0.0, 0.0)))

	jug.global_position = Vector3(118.0, 0.0, 0.0)            # a 2 u del punto
	mk.actualizar()
	_ok("1 a menos de DIST_OCULTAR_MARCADOR (%.0f u) → oculta" % MarcadorMision.DIST_OCULTAR_MARCADOR, mk.estado == "oculto", "%s a %.1f u" % [mk.estado, mk.distancia_u])
	jug.global_position = Vector3(114.0, 0.0, 0.0)            # a 6 u: ya no se oculta (y se ve en pantalla: rombo o, si no, flecha)
	mk.actualizar()
	_ok("1 a 6 u del punto vuelve a aparecer", mk.estado != "oculto", "%s a %.1f u" % [mk.estado, mk.distancia_u])
	jug.global_position = Vector3.ZERO

	M.definir({"id": "visible", "titulo": "Visible", "tipo": "principal", "objetivos": ["Ver"], "punto_objetivo": Vector3(7.0, 0.0, 0.0)})
	M.activar("visible")
	M.seguir("visible")
	mk.actualizar()
	_ok("1 objetivo EN pantalla (a 7 u) → rombo sobre él", mk.estado == "rombo", "%s punta %s" % [mk.estado, mk.punta])
	_ok("1 el rombo está dentro de la pantalla", Rect2(Vector2.ZERO, tam).has_point(mk.punta), str(mk.punta))

	M.definir({"id": "sinpunto", "titulo": "Sin punto", "tipo": "principal", "objetivos": ["Nada"]})
	M.activar("sinpunto")
	M.seguir("sinpunto")
	mk.actualizar()
	_ok("1 misión sin punto → nada", mk.estado == "oculto" and mk.objetivo == null, mk.estado)

	# Un nodo de un grupo como punto.
	var npc := Node3D.new()
	npc.add_to_group("npc_prueba_marcador")
	root.add_child(npc)
	npc.global_position = Vector3(-90.0, 0.0, 0.0)
	M.definir({"id": "grupo", "titulo": "Por grupo", "tipo": "principal", "objetivos": ["Hablar"], "punto_objetivo": "npc_prueba_marcador"})
	M.activar("grupo")
	M.seguir("grupo")
	mk.actualizar()
	_ok("1 un punto por grupo apunta al nodo (flecha a la izquierda)", mk.estado == "flecha" and _cerca(mk.punta.x, m, 1.0), "%s %s" % [mk.estado, mk.punta])
	npc.global_position = Vector3(-130.0, 0.0, 0.0)
	mk.actualizar()
	_ok("1 y sigue al nodo si se mueve", mk.objetivo is Vector3 and _cerca((mk.objetivo as Vector3).x, -130.0))

	# El primer objetivo pendiente manda.
	M.definir({"id": "dos", "titulo": "Dos pasos", "tipo": "principal", "objetivos": ["Primero", "Segundo", "Tercero"]})
	M.fijar_punto("dos", Vector3(100.0, 0.0, 0.0), 0)
	M.fijar_punto("dos", Vector3(-100.0, 0.0, 0.0), 1)
	M.activar("dos")
	M.seguir("dos")
	mk.actualizar()
	_ok("1 por objetivo: el primero pendiente manda (a la derecha)", mk.estado == "flecha" and _cerca(mk.punta.x, tam.x - m, 1.0), "%s %s" % [mk.estado, mk.punta])
	M.objetivo_hecho("dos", 0)
	mk.actualizar()
	_ok("1 al hacerlo, pasa al siguiente (a la izquierda)", mk.estado == "flecha" and _cerca(mk.punta.x, m, 1.0), "%s %s" % [mk.estado, mk.punta])
	M.objetivo_hecho("dos", 1)
	mk.actualizar()
	_ok("1 un objetivo pendiente sin punto → nada (sin punto no hay flecha)", mk.estado == "oculto", mk.estado)

	# Al completar la seguida, la siguiente misión activa pasa a seguirse sola (con SU punto): para ver que desaparece, ésta es la única.
	M = Misiones.nuevo()
	M.definir({"id": "fin", "titulo": "Fin", "tipo": "principal", "objetivos": ["Uno"], "punto_objetivo": Vector3(0.0, 0.0, -200.0)})
	M.activar("fin")
	M.seguir("fin")
	mk.actualizar()
	var antes: String = mk.estado
	M.completar("fin")
	mk.actualizar()
	_ok("1 completar la misión → el marcador desaparece", antes != "oculto" and mk.estado == "oculto", "%s → %s" % [antes, mk.estado])
	_ok("1 y Misiones ya no da punto para una misión completa", M.punto_objetivo("fin") == null)

	M.definir({"id": "info", "titulo": "Información", "tipo": "principal", "objetivos": ["Uno"], "punto_objetivo": Vector3(120.0, 0.0, 0.0)})
	M.activar("info")
	M.seguir("info")
	_ok("1 (la misión «info» es ahora la seguida)", M.seguida_id() == "info")
	Sensacion3D.ACTIVA = false
	mk.actualizar()
	_ok("1 Sensacion3D.ACTIVA = false → se ve igual (es información)", mk.estado == "flecha", mk.estado)
	Sensacion3D.ACTIVA = true
	MarcadorMision.MARCADOR_MISION_ACTIVO = false
	mk.actualizar()
	_ok("1 MARCADOR_MISION_ACTIVO = false → nada", mk.estado == "oculto", mk.estado)
	MarcadorMision.MARCADOR_MISION_ACTIVO = true
	M.limpiar_puntos()
	mk.actualizar()
	_ok("1 limpiar_puntos (un nivel nuevo) quita todos los puntos", mk.estado == "oculto", mk.estado)

	mk.free()
	cam.free()
	jug.free()
	npc.free()
	Misiones.nuevo()


# ---------------------------------------------------------------------------------------------------------------------
#  2 · Ambiente sonoro por zona
# ---------------------------------------------------------------------------------------------------------------------
func _ambiente() -> void:
	AmbienteZona.AMBIENTE_ACTIVO = true
	AmbienteZona.INTERVALO_PAJAROS = Vector2(1.0, 2.0)
	CicloDia3D.HORA = 12.0
	CicloDia3D.DURACION_DIA_S = 0.0
	_ok("2 las luces de la cueva y el bosque se clasifican (cueva_lava = cueva, santuario = sala, ruinas = bosque)",
		AmbienteZona.tipo_de_luz("bosque") == "bosque" and AmbienteZona.tipo_de_luz("cueva_lava") == "cueva" and AmbienteZona.tipo_de_luz("santuario") == "sala" and AmbienteZona.tipo_de_luz("ruinas") == "bosque")
	_ok("2 los sonidos del ambiente están en el catálogo a −18 dB", Sfx.db_de("amb_bosque") == -18.0 and Sfx.db_de("amb_cueva") == -18.0 and Sfx.db_de("amb_sala") == -18.0 and Sfx.db_de("amb_grillos") == -18.0 and Sfx.db_de("amb_pajaros") == -18.0)

	var fm: FalsaMaqueta = _mapa("Bosque_prueba", "bosque", false)
	var amb: AmbienteZona = AmbienteZona.montar(fm)
	amb.set_process(false)
	Sfx.vaciar_registro()
	for _i in range(5):
		amb.paso(0.1)
	_ok("2 en zona de bosque suena la capa «bosque»", amb.tipo_actual == "bosque" and amb.capas_sonando().has("bosque"), str(amb.capas_sonando()))
	var p: AudioStreamPlayer = amb.reproductor("bosque")
	_ok("2 es un AudioStreamPlayer plano (no posicional) en el bus «Mundo»", p != null and String(p.bus) == "Mundo" and p.playing, str(p.bus) if p != null else "sin reproductor (¿wav sin importar?)")
	for _i in range(20):
		amb.paso(0.1)
	_ok("2 con el fundido hecho suena a −18 dB", p != null and _cerca(p.volume_db, -18.0, 0.3), str(p.volume_db) if p != null else "")
	_ok("2 la capa arrancó una vez (Sfx.CONTEO)", Sfx.veces("amb_bosque") == 1, str(Sfx.veces("amb_bosque")))
	Sfx.AJUSTES["amb_bosque"] = -30.0
	amb.paso(0.1)
	_ok("2 Sfx.AJUSTES manda sobre el catálogo (−30 dB)", p != null and _cerca(p.volume_db, -30.0, 0.3), str(p.volume_db) if p != null else "")
	Sfx.AJUSTES.erase("amb_bosque")

	# Pájaros (de día).
	var disp0: int = amb.pajaros_disparados
	for _i in range(150):                                       # 15 s
		amb.paso(0.1)
	_ok("2 los pájaros cantan al menos una vez en 15 s con INTERVALO_PAJAROS = 1-2 s (%d)" % (amb.pajaros_disparados - disp0), amb.pajaros_disparados - disp0 >= 1)
	_ok("2 y entre 6 y 15 trinos (intervalo 1-2 s)", amb.pajaros_disparados - disp0 >= 6 and amb.pajaros_disparados - disp0 <= 15, str(amb.pajaros_disparados - disp0))
	_ok("2 cada trino cuenta en Sfx.CONTEO", Sfx.veces("amb_pajaros") == amb.pajaros_disparados, "%d de %d" % [Sfx.veces("amb_pajaros"), amb.pajaros_disparados])
	_ok("2 sin grillos de día", not amb.capas_sonando().has("grillos"))

	# De noche: callan los pájaros y entran los grillos.
	CicloDia3D.HORA = 23.0
	var disp1: int = amb.pajaros_disparados
	for _i in range(100):                                       # 10 s
		amb.paso(0.1)
	_ok("2 de noche los pájaros callan", amb.pajaros_disparados == disp1, str(amb.pajaros_disparados - disp1))
	_ok("2 de noche entran los grillos (y sigue el viento)", amb.capas_sonando().has("grillos") and amb.capas_sonando().has("bosque"), str(amb.capas_sonando()))
	CicloDia3D.HORA = 12.0
	for _i in range(30):
		amb.paso(0.1)
	_ok("2 de día otra vez, los grillos se van", not amb.capas_sonando().has("grillos"), str(amb.capas_sonando()))

	# Fundido cruzado a la cueva.
	fm.zona_luz = "cueva"
	for _i in range(10):                                        # 1 s
		amb.paso(0.1)
	var cruce: Dictionary = amb.capas_sonando()
	_ok("2 a mitad del fundido (1 s) suenan las dos capas, bosque y cueva", cruce.has("bosque") and cruce.has("cueva"), str(cruce))
	_ok("2 la que sale baja y la que entra sube", cruce.has("bosque") and cruce.has("cueva") and float(cruce["bosque"]) < 0.7 and float(cruce["cueva"]) > 0.3 and float(cruce["cueva"]) < 0.7, str(cruce))
	for _i in range(11):                                        # 2,1 s en total
		amb.paso(0.1)
	_ok("2 pasados los 2 s, solo suena la cueva", amb.capas_sonando().size() == 1 and amb.capas_sonando().has("cueva"), str(amb.capas_sonando()))
	_ok("2 el reproductor del bosque ya no existe", amb.reproductor("bosque") == null)
	_ok("2 la cueva suena en «Mundo» a −18 dB", amb.reproductor("cueva") != null and String(amb.reproductor("cueva").bus) == "Mundo" and _cerca(amb.reproductor("cueva").volume_db, -18.0, 0.3))
	var disp2: int = amb.pajaros_disparados
	for _i in range(100):
		amb.paso(0.1)
	_ok("2 en la cueva no hay pájaros", amb.pajaros_disparados == disp2)

	fm.zona_luz = "santuario"
	for _i in range(25):
		amb.paso(0.1)
	_ok("2 en una sala suena solo el zumbido", amb.capas_sonando().size() == 1 and amb.capas_sonando().has("sala"), str(amb.capas_sonando()))

	# Silencio.
	AmbienteZona.AMBIENTE_ACTIVO = false
	amb.paso(0.1)
	_ok("2 AMBIENTE_ACTIVO = false → silencio al momento", amb.capas_sonando().is_empty() and amb.reproductor("sala") == null, str(amb.capas_sonando()))
	fm.zona_luz = "bosque"
	var disp3: int = amb.pajaros_disparados
	for _i in range(100):
		amb.paso(0.1)
	_ok("2 y siguen callados (ni capas ni pájaros)", amb.capas_sonando().is_empty() and amb.pajaros_disparados == disp3)
	AmbienteZona.AMBIENTE_ACTIVO = true
	AmbienteZona.INTERVALO_PAJAROS = Vector2(6.0, 14.0)
	_ok("2 INTERVALO_PAJAROS por defecto 6-14 s", AmbienteZona.INTERVALO_PAJAROS == Vector2(6.0, 14.0))
	fm.free()


# ---------------------------------------------------------------------------------------------------------------------
#  3 · Ciclo día y noche
# ---------------------------------------------------------------------------------------------------------------------
func _dia_noche() -> void:
	var dia: Dictionary = LuzZona3D.valores("bosque")
	var e_dia: float = float(dia["sol_energia"])

	# Puro (transformar): continuidad, elevación, energía.
	var max_dc: float = 0.0
	var max_de: float = 0.0
	var peor: float = 0.0
	for k in range(0, 48):
		var h0: float = float(k) * 0.5
		var a: Dictionary = CicloDia3D.transformar(dia, h0)
		var b: Dictionary = CicloDia3D.transformar(dia, h0 + 1.0)       # dos horas consecutivas (la 23,5 con la 0,5 del día siguiente: envuelve)
		var ca: Color = a["sol_color"]
		var cb: Color = b["sol_color"]
		var dc: float = maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
		max_dc = maxf(max_dc, dc)
		max_de = maxf(max_de, absf(float(a["sol_energia"]) - float(b["sol_energia"])))
		for clave in ["ambiente_arriba", "ambiente_abajo"]:
			var xa: Color = a[clave]
			var xb: Color = b[clave]
			peor = maxf(peor, maxf(absf(xa.r - xb.r), maxf(absf(xa.g - xb.g), absf(xa.b - xb.b))))
	_ok("3 el color del sol no salta entre dos horas consecutivas (máximo %.3f ≤ 0,2)" % max_dc, max_dc <= 0.2, str(max_dc))
	_ok("3 el color del ambiente tampoco (máximo %.3f ≤ 0,2)" % peor, peor <= 0.2, str(peor))
	_ok("3 la energía del sol cambia sin saltos (máximo %.3f por hora ≤ 0,25)" % max_de, max_de <= 0.25, str(max_de))
	var t13: Dictionary = CicloDia3D.transformar(dia, 13.0)
	var elev13: float = -float(t13["sol_pitch"])
	var maxima: bool = true
	for k in range(0, 48):
		if -float(CicloDia3D.transformar(dia, float(k) * 0.5)["sol_pitch"]) > elev13 + 0.0001:
			maxima = false
	_ok("3 a las 13 la elevación del sol es la máxima del día (%.1f°)" % elev13, maxima and _cerca(elev13, absf(float(dia["sol_pitch"])), 0.01), str(elev13))
	_ok("3 a las 13 la energía es ≥ 0,9 de la del día", float(t13["sol_energia"]) >= 0.9 * e_dia, str(t13["sol_energia"]))
	var t2: Dictionary = CicloDia3D.transformar(dia, 2.0)
	var c2: Color = t2["sol_color"]
	_ok("3 a las 2 la energía es ≤ 0,15", float(t2["sol_energia"]) <= 0.15, str(t2["sol_energia"]))
	_ok("3 a las 2 el color es azulado (b > r)", c2.b > c2.r + 0.2, str(c2))
	var t7: Color = CicloDia3D.transformar(dia, 7.0)["sol_color"]
	var t19: Color = CicloDia3D.transformar(dia, 19.5)["sol_color"]
	_ok("3 amanecer y atardecer son anaranjados/rojizos (r > b)", t7.r > t7.b + 0.2 and t19.r > t19.b + 0.3, "%s %s" % [t7, t19])
	CicloDia3D.HORA = 23.0
	_ok("3 es_noche() a las 23", CicloDia3D.es_noche())
	CicloDia3D.HORA = 12.0
	_ok("3 no es noche a las 12", not CicloDia3D.es_noche())
	CicloDia3D.HORA = 5.9
	var n59: bool = CicloDia3D.es_noche()
	CicloDia3D.HORA = 6.0
	_ok("3 el sol sale a las 6 y se pone a las 20", n59 and not CicloDia3D.es_noche())
	CicloDia3D.HORA = 20.0
	_ok("3 a las 20 es noche", CicloDia3D.es_noche())

	# Con nodos: un mapa falso con sol y entorno.
	CicloDia3D.HORA = 13.0
	CicloDia3D.DURACION_DIA_S = 0.0
	CicloDia3D.LUNA_ACTIVA = true
	var fm: FalsaMaqueta = _mapa("Bosque_prueba", "bosque")
	fm._env.fog_enabled = true
	fm._env.fog_density = 0.02
	fm._env.fog_light_color = Color(0.8, 0.85, 0.9)
	var ciclo: CicloDia3D = CicloDia3D.montar(fm)
	_ok("3 un mapa exterior con sol monta el ciclo", ciclo != null and fm.get_node_or_null("CicloDia3D") == ciclo)
	_ok("3 montar dos veces devuelve el mismo", CicloDia3D.montar(fm) == ciclo)
	ciclo.set_process(false)
	ciclo.aplicar()
	_ok("3 a las 13 el sol del mapa tiene la elevación máxima y la energía del día", _cerca(-fm._sol.rotation_degrees.x, 70.0, 0.05) and _cerca(fm._sol.light_energy, e_dia, 0.01),
		"elev %.2f energía %.2f" % [-fm._sol.rotation_degrees.x, fm._sol.light_energy])
	_ok("3 a las 13 el color de la zona queda tal cual (tinte blanco)", _color_cerca(fm._sol.light_color, dia["sol_color"] as Color))
	_ok("3 sin luna de día", fm.get_node("Luna") is DirectionalLight3D and not (fm.get_node("Luna") as DirectionalLight3D).visible)
	_ok("3 la niebla de día es la del mapa", _cerca(fm._env.fog_density, 0.02, 0.0001))
	var e12: float = 0.0
	CicloDia3D.HORA = 12.0
	ciclo.aplicar()
	e12 = -fm._sol.rotation_degrees.x
	_ok("3 a las 12 el sol está más bajo que a las 13", e12 < 70.0 - 0.1, str(e12))
	CicloDia3D.HORA = 2.0
	ciclo.aplicar()
	_ok("3 a las 2 el sol del mapa: energía ≤ 0,15 y color azulado", fm._sol.light_energy <= 0.15 and fm._sol.light_color.b > fm._sol.light_color.r + 0.2, "%.3f %s" % [fm._sol.light_energy, fm._sol.light_color])
	_ok("3 a las 2 el sol sigue apuntando hacia abajo (luz de luna, no desde el suelo)", fm._sol.rotation_degrees.x < -5.0, str(fm._sol.rotation_degrees.x))
	_ok("3 a las 2 el ambiente es más tenue y azul que de día", fm._env.ambient_light_energy < float(dia["ambiente_energia"]) * 0.5, str(fm._env.ambient_light_energy))
	_ok("3 a las 2 la niebla es más densa y azulada", fm._env.fog_density > 0.02 * 1.5 and fm._env.fog_light_color.b > fm._env.fog_light_color.r, "%.4f %s" % [fm._env.fog_density, fm._env.fog_light_color])
	var luna: DirectionalLight3D = fm.get_node("Luna") as DirectionalLight3D
	_ok("3 a las 2 sale la luna, tenue", luna.visible and luna.light_energy > 0.0 and luna.light_energy <= 0.15, "%s %.3f" % [luna.visible, luna.light_energy])
	CicloDia3D.HORA = 13.0
	ciclo.aplicar()
	_ok("3 de día la niebla vuelve exactamente a la del mapa", _cerca(fm._env.fog_density, 0.02, 0.0001), str(fm._env.fog_density))

	# El color por zona sigue MULTIPLICADO: otra zona de luz, otro color, a la misma hora.
	fm.zona_luz = "atardecer"
	CicloDia3D.HORA = 12.0
	ciclo.aplicar()
	var col_atardecer: Color = fm._sol.light_color
	_ok("3 el color de la zona manda a mediodía (atardecer ≠ bosque)", _color_cerca(col_atardecer, LuzZona3D.ZONAS["atardecer"]["sol_color"] as Color) and not _color_cerca(col_atardecer, dia["sol_color"] as Color, 0.02), str(col_atardecer))
	CicloDia3D.HORA = 19.5
	ciclo.aplicar()
	var esperado: Color = (LuzZona3D.ZONAS["atardecer"]["sol_color"] as Color)
	var tinte: Color = CicloDia3D._fila(CicloDia3D.TABLA_SOL, 19.5)[0]
	_ok("3 a las 19:30 el color es el de la zona × el tinte de la hora", _color_cerca(fm._sol.light_color, Color(esperado.r * tinte.r, esperado.g * tinte.g, esperado.b * tinte.b)), str(fm._sol.light_color))
	fm.zona_luz = "bosque"

	# El tiempo.
	CicloDia3D.HORA = 0.0
	CicloDia3D.DURACION_DIA_S = 10.0
	ciclo.horas_avanzadas = 0.0
	for _i in range(300):                                       # 10 s a 30 fps
		ciclo._process(1.0 / 30.0)
	_ok("3 con DURACION_DIA_S = 10 la hora avanza 24 en 10 s (%.2f)" % ciclo.horas_avanzadas, _cerca(ciclo.horas_avanzadas, 24.0, 0.05), str(ciclo.horas_avanzadas))
	CicloDia3D.HORA = 0.0
	for _i in range(150):
		ciclo._process(1.0 / 30.0)
	_ok("3 y a los 5 s van por las 12 (%.2f)" % CicloDia3D.HORA, _cerca(CicloDia3D.HORA, 12.0, 0.05), str(CicloDia3D.HORA))
	CicloDia3D.HORA = 7.5
	CicloDia3D.DURACION_DIA_S = 0.0
	for _i in range(100):
		ciclo._process(1.0 / 30.0)
	_ok("3 con DURACION_DIA_S = 0 la hora no cambia", CicloDia3D.HORA == 7.5, str(CicloDia3D.HORA))
	fm.free()

	# Dónde se monta.
	var cueva: FalsaMaqueta = _mapa("Cueva", "cueva", true, "cueva")
	_ok("3 la cueva no monta el ciclo", CicloDia3D.montar(cueva) == null and cueva.get_node_or_null("CicloDia3D") == null)
	_ok("3 pero con `forzar` (el laboratorio) sí", CicloDia3D.montar(cueva, true) != null)
	cueva.free()
	var sala: FalsaMaqueta = _mapa("SalaEmpuje", "cueva", true)
	_ok("3 una sala (nivel que no es Bosque*) no lo monta", CicloDia3D.montar(sala) == null)
	sala.free()
	var sin_sol: FalsaMaqueta = _mapa("Bosque_sin_sol", "bosque", false)
	_ok("3 un mapa sin DirectionalLight3D no lo monta (lo dice por consola una vez)", CicloDia3D.montar(sin_sol) == null)
	sin_sol.free()
	CicloDia3D.CICLO_ACTIVO = false
	var apagado: FalsaMaqueta = _mapa("Bosque_apagado", "bosque")
	_ok("3 CICLO_ACTIVO = false → ningún mapa lo monta", CicloDia3D.montar(apagado) == null)
	apagado.free()
	CicloDia3D.CICLO_ACTIVO = true


# ---------------------------------------------------------------------------------------------------------------------
#  4 · Escenas reales
# ---------------------------------------------------------------------------------------------------------------------
func _escenas_reales() -> void:
	CicloDia3D.HORA = 13.0
	CicloDia3D.DURACION_DIA_S = 0.0
	AmbienteZona.AMBIENTE_ACTIVO = true
	Misiones.nuevo()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_V01, false)
	if maqueta == null or jugador == null:
		return
	await avanzar(40)
	var ciclo: CicloDia3D = maqueta.get_node_or_null("CicloDia3D") as CicloDia3D
	var amb: AmbienteZona = maqueta.get_node_or_null("AmbienteZona") as AmbienteZona
	_ok("4 Bosque 01 v01 monta el ciclo de día y noche", ciclo != null)
	_ok("4 Bosque 01 v01 monta el ambiente sonoro (tipo bosque)", amb != null and amb.tipo_actual == "bosque", amb.tipo_actual if amb != null else "")
	var sol: DirectionalLight3D = maqueta.get("_sol") as DirectionalLight3D
	var env: Environment = maqueta.get("_env") as Environment
	# «bosque = antes»: las energías exactas del sol (1,0 a las 13 h; ≤ 0,15 a las 2 h) se miden SIN la capa 1 de contraste (sol ×1,3). Se restaura tras las comprobaciones.
	var contraste_antes: bool = ContrasteLuz3D.ACTIVO
	ContrasteLuz3D.poner(false, maqueta)
	await avanzar(3)
	_ok("4 a las 13 el sol del bosque tiene la luz de la zona sin teñir", sol != null and _color_cerca(sol.light_color, LuzZona3D.ZONAS["bosque"]["sol_color"] as Color, 0.02) and _cerca(sol.light_energy, 1.0, 0.02),
		"%s %.2f" % [sol.light_color, sol.light_energy])
	CicloDia3D.HORA = 2.0
	await avanzar(3)
	_ok("4 a las 2 el sol es azul y tenue (el ciclo manda sobre Zonas3D)", sol.light_energy <= 0.15 and sol.light_color.b > sol.light_color.r + 0.2, "%.2f %s" % [sol.light_energy, sol.light_color])
	_ok("4 y el ambiente del entorno baja", env.ambient_light_energy < 0.6 * 0.5, str(env.ambient_light_energy))
	ContrasteLuz3D.poner(contraste_antes, maqueta)
	CicloDia3D.HORA = 13.0
	await avanzar(3)

	var marc: MarcadorMision = null
	for n in maqueta.find_children("MarcadorMision", "Control", true, false):
		marc = n as MarcadorMision
	_ok("4 el Lanzador3D monta el marcador de misión en la interfaz", marc != null)
	var mi: Misiones = Misiones.i()
	var id: String = mi.seguida_id()
	var punto: Variant = mi.punto_objetivo(id)
	_ok("4 la misión seguida de Bosque 01 v01 («%s») da un punto de objetivo" % id, id != "" and punto is Vector3, str(punto))
	if marc != null and punto is Vector3:
		await avanzar(3)
		var dist: float = Vector2((punto as Vector3).x - jugador.global_position.x, (punto as Vector3).z - jugador.global_position.z).length()
		var coherente: bool = (marc.estado == "oculto") if dist < MarcadorMision.DIST_OCULTAR_MARCADOR else (marc.estado == "flecha" or marc.estado == "rombo")
		_ok("4 el marcador es coherente con la distancia (%.1f u → %s)" % [dist, marc.estado], coherente)
		# Lejos del punto, fuera de pantalla → flecha con metros.
		colocar_jugador(Vector2i(1, 1) if Terreno3D.celda_de(punto as Vector3) != Vector2i(1, 1) else Vector2i(20, 20))
		await avanzar(40)
		marc.actualizar()
		_ok("4 con el jugador lejos hay marcador (flecha o rombo) y distancia > 0", marc.estado != "oculto" and marc.metros > 0, "%s %d m" % [marc.estado, marc.metros])
		mi.completar(id)
		await avanzar(3)
		marc.actualizar()
		_ok("4 completar la misión quita el marcador", marc.estado == "oculto", marc.estado)

	maqueta.free()
	maqueta = null
	lanzador = null
	jugador = null
	await avanzar(5)

	# La cueva: ambiente de cueva, sin ciclo.
	Misiones.nuevo()
	await cargar(RUTA_CUEVA, false)
	if maqueta == null:
		return
	await avanzar(40)
	var amb2: AmbienteZona = maqueta.get_node_or_null("AmbienteZona") as AmbienteZona
	_ok("4 la Cueva NO monta el ciclo de día y noche", maqueta.get_node_or_null("CicloDia3D") == null)
	_ok("4 la Cueva monta el ambiente sonoro y es de tipo cueva", amb2 != null and amb2.tipo_actual == "cueva", amb2.tipo_actual if amb2 != null else "")
	_ok("4 en la Cueva suena la capa «cueva» (y no la del bosque)", amb2 != null and amb2.capas_sonando().has("cueva") and not amb2.capas_sonando().has("bosque"), str(amb2.capas_sonando()) if amb2 != null else "")
	maqueta.free()
	maqueta = null
