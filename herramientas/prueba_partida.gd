extends SceneTree
## F2 de PLAN_BASE_DATOS (29/10, Juego): `Partida`, una partida en un archivo. Comprueba (a) guardar → reiniciar los singletons → cargar devuelve
## oro, bolsa, mejoras, tinta, flags con cadena y con entero, misiones, sellos/glifos/páginas, recetas y el sitio; (b) el JSON tiene las MISMAS
## claves que `nucleo/datos/partida_ejemplo.json` (primer y segundo nivel; las secciones cuyo contenido es un diccionario libre —items, mejoras,
## estados, flags, mundo, misiones.misiones— solo se miran en el primero); (c) un `flags.json` + `misiones.json` de la versión 1 migran a la
## ranura v2 y quedan como `.v1.bak`; (d) un archivo roto o de otra versión no rompe ni toca nada; (e) `existe` / `borrar`.
## NUNCA toca `user://partidas/`, `user://flags.json` ni `user://misiones.json`: todo va a una carpeta de prueba que se borra al acabar.
## Sin ventana ni escena.
##   godot --headless --path . --script res://herramientas/prueba_partida.gd
## o, desde la raíz del repo:  tools\prueba_una.cmd prueba_partida

const CARPETA: String = "user://prueba_partida/"
const EJEMPLO: String = "res://nucleo/datos/partida_ejemplo.json"
## Secciones cuyo segundo nivel son ids libres (no tiene sentido compararlo con el ejemplo).
const LIBRES: Array = ["mejoras", "estados", "flags", "mundo"]

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_apuntar()
	_ida_y_vuelta()
	_claves_como_el_ejemplo()
	_migracion()
	_archivo_roto()
	_existe_y_borrar()
	_limpiar()
	_restaurar()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Todo a la carpeta de prueba (también los archivos de la versión 1) y singletons de partida nueva.
func _apuntar() -> void:
	_limpiar()
	Partida.carpeta = CARPETA
	Partida.ruta_flags_v1 = CARPETA + "flags.json"
	Partida.ruta_misiones_v1 = CARPETA + "misiones.json"
	Partida.ranura_actual = 1
	Partida.continuar = false
	_vaciar_singletons()


func _vaciar_singletons() -> void:
	Estado.nuevo()
	Flags.nuevo()
	Misiones.nuevo()
	Repertoire.reset_to_p0()
	Repertoire.paginas = []
	Partida.tinta = Tinta.new()
	Partida.recetas_conocidas = []
	Partida.mundo = {}
	Partida.tinta_pendiente = {}


func _restaurar() -> void:
	Partida.carpeta = Partida.CARPETA_DEFECTO
	Partida.ruta_flags_v1 = Partida.RUTA_FLAGS_V1
	Partida.ruta_misiones_v1 = Partida.RUTA_MISIONES_V1
	Partida.tinta = null
	Repertoire.reset_to_p0()
	Repertoire.paginas = []
	Estado.nuevo()
	Flags.nuevo()
	Misiones.nuevo()


func _limpiar() -> void:
	var dir_abs: String = ProjectSettings.globalize_path(CARPETA)
	if DirAccess.dir_exists_absolute(dir_abs):
		for f in DirAccess.get_files_at(dir_abs):
			DirAccess.remove_absolute(dir_abs.path_join(f))
		DirAccess.remove_absolute(dir_abs)


## Una partida con de todo (para guardar y comparar).
func _montar() -> Dictionary:
	var e: Estado = Estado.i()
	e.oro = 143
	e.capacidad = 12
	e.items = {"pocion": 2, "baya": 7, "capa": 1, "llave": 1}
	e.mejoras = {"vida_max": 1, "tinta_secreto": 2}
	e.consumible_equipado = "pocion"
	e.asistencia = 0.8
	e.trazo_recto = false
	e.lanzamiento_inteligente = true
	var t: Tinta = Partida.tinta
	t.maxima = t.maxima_calculada()
	t.actual = 62.0
	t.frascos = 2
	t.activar_pigmento("resina_carmesi")
	t.actualizar(1.5, false)                       # el pigmento gasta tiempo: queda un número raro
	var f: Flags = Flags.i()
	f.poner("bosque1.s1.cofre_01", "abierto")
	f.poner("bosque1.s3.jefe_01", "derrotado")
	f.poner("bosque1.s3.antorchas", 3)
	f.poner("bosque1.rotulo.claro_visto")
	Misiones.i().definir({"id": "guardabosques_goblins", "titulo": "Goblins", "tipo": "principal", "objetivos": ["Derrota a 3 goblins", "Vuelve con el guardabosques"]})
	Misiones.i().activar("guardabosques_goblins")
	Misiones.i().objetivo_hecho("guardabosques_goblins", 0)
	Repertoire.set_active(GestureLibrary.ELEMENTS.slice(0, 3), GestureLibrary.SIGILS.slice(0, 3))
	Partida.recetas_conocidas = ["pocion", "infusion_brezo"]
	return {
		"mapa_actual": "Bosque_01", "entrada": "fogata_s2", "posicion": Vector3(12.5, 0.25, 34.0), "vida": 85.0,
		"ropa_puesta": ["capa", "tunica"], "punto": "bosque1.s2.fogata",
		"paginas": [{"elemento": "fuego", "glifos": ["flecha"]}, {"elemento": "agua", "glifos": ["barrera", "linea"]}, {"elemento": "", "glifos": []}],
	}


func _ida_y_vuelta() -> void:
	var extra: Dictionary = _montar()
	var elementos_antes: Array = Array(Repertoire.active_elements())
	var glifos_antes: Array = Array(Repertoire.active_sigils())
	var pigmento_s: float = Partida.tinta._t_pigmento
	var barra: float = Partida.tinta.actual
	var misiones_antes: Dictionary = Misiones.i().a_dic()
	_ok("1 guardar escribe la ranura", Partida.guardar(1, extra) and Partida.existe(1) and FileAccess.file_exists(CARPETA + "ranura_1.json"))
	_ok("1 no deja el temporal", not FileAccess.file_exists(CARPETA + "ranura_1.json.tmp"))
	# Otra partida: todo a cero.
	_vaciar_singletons()
	_ok("1 tras el reinicio no queda nada", Estado.i().oro == 0 and Flags.i().nombres().is_empty() and Misiones.i().ids().is_empty() and Partida.tinta.actual != 62.0)
	var d: Dictionary = Partida.cargar(1)
	var e: Estado = Estado.i()
	_ok("1 cargar devuelve la partida (versión 2)", int(d.get("version", 0)) == 2)
	_ok("1 oro, capacidad y bolsa (con sus enteros)", e.oro == 143 and e.capacidad == 12 and e.items == {"pocion": 2, "baya": 7, "capa": 1, "llave": 1} and e.items["baya"] is int, str(e.items))
	_ok("1 mejoras", e.mejoras == {"vida_max": 1, "tinta_secreto": 2} and e.nivel("tinta_secreto") == 2, str(e.mejoras))
	_ok("1 consumible y opciones", e.consumible_equipado == "pocion" and is_equal_approx(e.asistencia, 0.8) and e.trazo_recto == false and e.lanzamiento_inteligente == true)
	var t: Tinta = Partida.tinta
	_ok("1 tinta: barra, frascos y pigmento con su tiempo", is_equal_approx(t.actual, barra) and barra > 60.0 and t.frascos == 2 and t.pigmento == "resina_carmesi" and absf(t._t_pigmento - pigmento_s) < 0.001, str(t.a_dic()))
	_ok("1 los frascos quedan también en Estado (los lee una Tinta nueva)", e.frascos_tinta == 2 and Tinta.new().frascos == 2)
	var f: Flags = Flags.i()
	_ok("1 flags: cadenas", f.valor("bosque1.s1.cofre_01") == "abierto" and f.valor("bosque1.s3.jefe_01") == "derrotado")
	_ok("1 flags: entero y true", f.valor("bosque1.s3.antorchas") is int and f.valor("bosque1.s3.antorchas") == 3 and f.valor("bosque1.rotulo.claro_visto") == true)
	_ok("1 misiones iguales", Misiones.i().a_dic() == misiones_antes and Misiones.i().estado("guardabosques_goblins") == "activa" and Misiones.i().progreso("guardabosques_goblins") == Vector2i(1, 2), str(Misiones.i().a_dic()))
	_ok("1 sellos y glifos", Array(Repertoire.active_elements()) == elementos_antes and Array(Repertoire.active_sigils()) == glifos_antes, "%s %s" % [str(Repertoire.active_elements()), str(Repertoire.active_sigils())])
	_ok("1 páginas", Repertoire.paginas.size() == 3 and Repertoire.paginas[1] == {"elemento": "agua", "glifos": ["barrera", "linea"]}, str(Repertoire.paginas))
	_ok("1 recetas conocidas", Partida.recetas_conocidas == ["pocion", "infusion_brezo"])
	var j: Dictionary = d["jugadora"]
	_ok("1 el sitio: mapa, entrada y posición", j["mapa_actual"] == "Bosque_01" and j["entrada"] == "fogata_s2" and j["posicion"] == [12.5, 0.25, 34.0], str(j))
	_ok("1 vida, ropa y aguante por defecto", is_equal_approx(float(j["vida"]), 85.0) and j["ropa_puesta"] == ["capa", "tunica"] and is_equal_approx(float(j["aguante"]), 100.0))
	_ok("1 el punto de guardado y la ranura en meta", d["meta"]["punto"] == "bosque1.s2.fogata" and int(d["meta"]["ranura"]) == 1 and String(d["meta"]["guardado_en"]).length() >= 19)
	# Claves ausentes: valores por defecto, sin romper.
	Estado.i().desde_dic({})
	_ok("2 Estado.desde_dic({}) vuelve a los valores de partida nueva", Estado.i().oro == 0 and Estado.i().capacidad == Estado.CAPACIDAD_INICIAL and Estado.i().items.is_empty() and Estado.i().asistencia == 0.5)
	Partida.tinta.desde_dic({})
	_ok("2 Tinta.desde_dic({}) = barra llena, frascos de partida, pigmento base", is_equal_approx(Partida.tinta.actual, Partida.tinta.maxima) and Partida.tinta.frascos == Tinta.FRASCOS_INICIALES and Partida.tinta.pigmento == Tinta.PIGMENTO_BASE)
	var sellos: Array = Array(Repertoire.active_elements())
	Repertoire.desde_dic({})
	_ok("2 Repertoire.desde_dic({}) no toca lo que hay", Array(Repertoire.active_elements()) == sellos)
	# Estado emite `cambiado` al cargar.
	var avisos: Array = [0]
	Estado.i().cambiado.connect(func() -> void: avisos[0] += 1)
	Estado.i().desde_dic({"bolsa": {"oro": 5}})
	_ok("2 Estado.desde_dic emite cambiado", avisos[0] == 1 and Estado.i().oro == 5)


## Los dos primeros niveles de claves son los del prototipo de Pablo.
func _claves_como_el_ejemplo() -> void:
	_vaciar_singletons()
	_montar()
	var extra: Dictionary = {"mapa_actual": "Bosque_01", "posicion": Vector3.ZERO}
	Partida.guardar(2, extra)
	var fa := FileAccess.open(CARPETA + "ranura_2.json", FileAccess.READ)
	var mio: Variant = JSON.parse_string(fa.get_as_text())
	fa.close()
	var fe := FileAccess.open(EJEMPLO, FileAccess.READ)
	var ej: Variant = JSON.parse_string(fe.get_as_text())
	fe.close()
	_ok("3 el ejemplo y el archivo son diccionarios", mio is Dictionary and ej is Dictionary)
	if not (mio is Dictionary and ej is Dictionary):
		return
	_ok("3 mismas claves de primer nivel", _claves(mio) == _claves(ej), "%s | %s" % [str(_claves(mio)), str(_claves(ej))])
	for k in _claves(ej):
		if LIBRES.has(k):
			continue
		if ej[k] is Dictionary:
			_ok("3 mismas claves de segundo nivel en «%s»" % k, mio.has(k) and mio[k] is Dictionary and _claves(mio[k]) == _claves(ej[k]), "%s | %s" % [str(_claves(mio.get(k, {}))), str(_claves(ej[k]))])
	_ok("3 las opciones de la jugadora (tercer nivel) también", _claves(mio["jugadora"]["opciones"]) == _claves(ej["jugadora"]["opciones"]))
	_ok("3 cada página lleva elemento y glifos", (mio["grimorio"]["paginas"] as Array).is_empty() or _claves(mio["grimorio"]["paginas"][0]) == _claves(ej["grimorio"]["paginas"][0]))
	_ok("3 las cadenas van en estados y los números en flags", mio["estados"].has("bosque1.s1.cofre_01") and mio["flags"].has("bosque1.s3.antorchas") and not mio["flags"].has("bosque1.s1.cofre_01"))
	_ok("3 posición de tres números y tipos del ejemplo", (mio["jugadora"]["posicion"] as Array).size() == 3 and mio["tinta"]["pigmento"] is String and mio["bolsa"]["items"] is Dictionary)
	Partida.borrar(2)


func _claves(d: Dictionary) -> Array:
	var k: Array = d.keys()
	k.sort()
	return k


## Dos archivos sueltos de la versión 1 → una ranura v2; los viejos se renombran, no se borran.
func _migracion() -> void:
	_vaciar_singletons()
	Partida.borrar(1)
	var f1: Flags = Flags.nuevo()
	f1.poner("bosque1.s1.cofre", true)
	f1.poner("bosque1.s3.antorchas", 2)
	var fa := FileAccess.open(Partida.ruta_flags_v1, FileAccess.WRITE)
	fa.store_string(JSON.stringify({"version": 1, "flags": {"bosque1.s1.cofre": true, "bosque1.s3.antorchas": 2}}))
	fa.close()
	var m1: Misiones = Misiones.nuevo()
	m1.definir({"id": "vieja", "titulo": "Vieja", "tipo": "principal", "objetivos": ["uno"]})
	m1.activar("vieja")
	var ma := FileAccess.open(Partida.ruta_misiones_v1, FileAccess.WRITE)
	ma.store_string(JSON.stringify(m1.a_dic()))
	ma.close()
	Flags.nuevo()
	Misiones.nuevo()
	_ok("4 partida: no hay ranura 1, sí los dos archivos viejos", not Partida.existe(1) and FileAccess.file_exists(Partida.ruta_flags_v1) and FileAccess.file_exists(Partida.ruta_misiones_v1))
	var d: Dictionary = Partida.cargar(1)
	_ok("4 cargar migra y devuelve una partida v2", int(d.get("version", 0)) == 2 and Partida.existe(1))
	_ok("4 las flags y las misiones viejas están cargadas", Flags.i().tiene("bosque1.s1.cofre") and Flags.i().valor("bosque1.s3.antorchas") == 2 and Misiones.i().estado("vieja") == "activa", str(Flags.i().nombres()))
	_ok("4 la ranura nueva las lleva en sus secciones", d["flags"].has("bosque1.s3.antorchas") and (d["misiones"]["misiones"] as Dictionary).has("vieja"))
	_ok("4 los viejos quedan como .v1.bak y ya no están con su nombre", FileAccess.file_exists(Partida.ruta_flags_v1 + ".v1.bak") and FileAccess.file_exists(Partida.ruta_misiones_v1 + ".v1.bak") and not FileAccess.file_exists(Partida.ruta_flags_v1) and not FileAccess.file_exists(Partida.ruta_misiones_v1))
	# Segunda vez: ya no migra, lee la ranura.
	Flags.nuevo()
	var d2: Dictionary = Partida.cargar(1)
	_ok("4 la segunda vez lee la ranura (sin archivos viejos)", int(d2.get("version", 0)) == 2 and Flags.i().tiene("bosque1.s1.cofre"))
	_ok("4 sin ranura ni archivos viejos, cargar devuelve {}", Partida.cargar(3).is_empty())


func _archivo_roto() -> void:
	_vaciar_singletons()
	Estado.i().oro = 77
	Flags.i().poner("bosque1.s1.x", "abierto")
	var antes_estado: Dictionary = Estado.i().a_dic()
	var antes_flags: Dictionary = Flags.i().a_dic()
	var antes_tinta: Dictionary = Partida.tinta.a_dic()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	for caso in [["{esto no es json", "JSON roto"], ["[1, 2, 3]", "no es un diccionario"], ["{\"version\": 99, \"bolsa\": {\"oro\": 5}}", "versión desconocida"], ["", "vacío"]]:
		var fa := FileAccess.open(CARPETA + "ranura_4.json", FileAccess.WRITE)
		fa.store_string(caso[0])
		fa.close()
		var r: Dictionary = Partida.cargar(4)
		_ok("5 %s: cargar devuelve {}" % caso[1], r.is_empty())
	_ok("5 los singletons siguen intactos", Estado.i().a_dic() == antes_estado and Flags.i().a_dic() == antes_flags and Partida.tinta.a_dic() == antes_tinta and Estado.i().oro == 77)
	Partida.borrar(4)


func _existe_y_borrar() -> void:
	Partida.borrar(5)
	_ok("6 existe es false antes de guardar", not Partida.existe(5))
	_ok("6 guardar crea la carpeta y la ranura", Partida.guardar(5, {}) and Partida.existe(5) and not Partida.existe(6))
	_ok("6 la ruta usa el número de ranura", Partida.ruta(5).ends_with("ranura_5.json") and Partida.RUTA % 1 == "user://partidas/ranura_1.json")
	_ok("6 borrar quita el archivo y devuelve true", Partida.borrar(5) and not Partida.existe(5))
	_ok("6 borrar lo que no existe devuelve false", not Partida.borrar(5))
