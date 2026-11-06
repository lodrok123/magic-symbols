extends "res://herramientas/escenario_base.gd"
## F4 del laboratorio de hechizos INSPECCIONA los toys del juego (6/11): abre LabHechizos3D (que cuelga de la maqueta, que conecta VfxToyJuego), pasa a F4 y comprueba que
## el ajuste procedural arranca en true, que existen las filas magma / naturaleza / hielo, que lanzar la celda base de cada elemento crea toys por el camino real
## (`VfxToyJuego.creados`), que V apaga y enciende, que F pasa un elemento de toy a pieza antigua, que las aprobaciones viejas conservan su clave y que al salir de F4
## el ajuste vuelve a como estaba.
##   & "E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe" --headless --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/prueba_lab_vfx_toys.gd

const RUTA_LAB: String = "res://laboratorios/LabHechizos3D.tscn"
var lab: Node = null


func _tecla_lab(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	lab._unhandled_input(ev)


func _fila(id: String) -> int:
	for i in range(LabVfx3D.ESTADOS.size()):
		if String(LabVfx3D.ESTADOS[i][0]) == id:
			return i
	return -1


func _escenario() -> void:
	LabHechizos3D.cargar_al_abrir = false
	CapaBases.limpiar()
	var antes_proc: bool = ProjectSettings.has_setting(VfxToyJuego.AJUSTE)
	var antes_val: Variant = ProjectSettings.get_setting(VfxToyJuego.AJUSTE) if antes_proc else null
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio está montado", lab != null and lab.get("f4") is LabVfx3D)
	if lab == null or not (lab.get("f4") is LabVfx3D):
		return
	var vfx: LabVfx3D = lab.get("f4") as LabVfx3D
	vfx.guardar_al_marcar = false
	var marcas_user: Dictionary = vfx.marcas.duplicate(true)
	var ruta_json: String = "user://prueba_lab_vfx_toys.json"
	var enganche: VfxToyJuego = maqueta.get_node_or_null("VfxToyJuego") as VfxToyJuego
	_ok("0 la maqueta ha conectado VfxToyJuego (el enganche ya está)", enganche != null)
	_ok("0 fuera de F4 el ajuste procedural no se ha tocado", VfxToyJuego.activo() == (bool(antes_val) if antes_proc else false))

	# --- F4 abre y enciende
	_tecla_lab(KEY_F4)
	_ok("1 F4 abre la pestaña VFX", lab.pestana == LabHechizos3D.Pestana.VFX)
	_ok("1 …y el ajuste procedural arranca en true", VfxToyJuego.activo())
	var hud: String = lab.texto_hud()
	_ok("1 el HUD dice «PROCEDURAL: sí» y lista los toys", hud.contains("PROCEDURAL: sí") and hud.contains("toys: "), hud.substr(0, 200))
	var m: int = _fila("magma")
	var n: int = _fila("naturaleza")
	var h: int = _fila("hielo")
	_ok("2 hay filas magma, naturaleza y hielo (al final: no mueven las claves viejas)", m == 6 and n == 7 and h == 8, "%d %d %d" % [m, n, h])
	_ok("2 las claves de los seis estados de siempre no cambian", LabVfx3D.clave_de(0, 0, 0, 0) == "solido|esfera|ninguna|suelo" and LabVfx3D.clave_de(5, 3, 4, 3) == "campo|Z3|solidez|objeto")
	_ok("2 el criterio sigue siendo de 24 celdas y la matriz de 720", LabVfx3D.celdas_base().size() == 24 and LabVfx3D.total_celdas() == 720)
	var ok_el: bool = true
	for par in [["magma", "magma"], ["naturaleza", "naturaleza"], ["hielo", "hielo"]]:
		ok_el = ok_el and vfx.hechizo([_fila(par[0]), 0, 0, 0]).elemento == par[1]
	_ok("2 el hechizo de cada fila derivada sale de su runa (elemento magma / naturaleza / hielo)", ok_el)

	# --- viejas aprobaciones
	vfx.marcas = {"liquido|esfera|ninguna|suelo": {"estado": "aprobado", "nota": "", "luces": 0, "particulas": 10}}
	vfx.poner(m, 0, 0, 0)
	vfx.marcas[vfx.clave()] = {"estado": "rechazado", "nota": "color", "luces": 1, "particulas": 5}
	_ok("3 guardar escribe el json", vfx.guardar(ruta_json))
	var jv: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta_json))
	var celdas: Dictionary = (jv as Dictionary).get("celdas", {}) if jv is Dictionary else {}
	_ok("3 el json conserva la clave vieja y añade la nueva de magma", celdas.has("liquido|esfera|ninguna|suelo") and celdas.has("magma|esfera|ninguna|suelo"))
	_ok("3 …y la cuenta de celdas es 720", jv is Dictionary and int(jv["cuentas"]["celdas"]) == 720)
	vfx.marcas.clear()
	_ok("3 cargar devuelve las dos", vfx.cargar(ruta_json) and vfx.valor_marca("liquido|esfera|ninguna|suelo") == "aprobado" and vfx.valor_marca("magma|esfera|ninguna|suelo") == "rechazado")
	DirAccess.remove_absolute(ruta_json)
	vfx.marcas.clear()

	# --- lanzar la celda base de cada elemento nuevo y de los de siempre: crea toys por el camino real
	var sabe: PackedStringArray = VfxToyJuego.ELEMENTOS
	for id in ["plasma", "liquido", "energia", "magma", "gas", "solido"]:
		var fila: int = _fila(id)
		var el: String = String(vfx.hechizo([fila, 0, 0, 0]).elemento)
		if not sabe.has(el):
			print("  AVISO  «%s» (%s) aún no está en VfxToyJuego.ELEMENTOS: no se comprueba" % [id, el])
			continue
		vfx.poner(fila, 0, 0, 0)
		var cre0: int = int(enganche.creados[el])
		var n_cas: int = vfx.lanzar()
		await avanzar_s(0.5)
		var cre1: int = int(enganche.creados[el])
		_ok("4 lanzar la base de «%s» (elemento %s) crea toys: %d → %d, casillas %d, vivos %d" % [id, el, cre0, cre1, n_cas, enganche.vivos()], cre1 > cre0)
		_ok("4 …y el HUD lo cuenta", lab.texto_hud().contains("toys creados") and vfx.toys_del_ultimo().get(el, 0) == cre1 - cre0, str(vfx.toys_del_ultimo()))
		await avanzar_s(LabVfx3D.VENTANA_MEDIDA_S)
		var med: Dictionary = vfx.marcas.get(vfx.clave(), {})
		_ok("4 …y mide luces (%s) y partículas (%s)" % [str(med.get("luces")), str(med.get("particulas"))], med.has("luces") and med.has("particulas"))
		lab.limpiar_sala()

	# --- V apaga y enciende
	_tecla_lab(KEY_V)
	_ok("5 V apaga el procedural", not VfxToyJuego.activo() and lab.texto_hud().contains("PROCEDURAL: no"))
	vfx.poner(_fila("plasma"), 0, 0, 0)
	var f0: int = int(enganche.creados["fuego"])
	vfx.lanzar()
	await avanzar_s(0.5)
	_ok("5 …y con él apagado no se crean toys (se dibuja la pieza de siempre)", int(enganche.creados["fuego"]) == f0)
	lab.limpiar_sala()
	_tecla_lab(KEY_V)
	_ok("5 V lo enciende otra vez", VfxToyJuego.activo())
	vfx.lanzar()
	await avanzar_s(0.5)
	_ok("5 …y vuelven los toys", int(enganche.creados["fuego"]) > f0)
	lab.limpiar_sala()

	# --- F cambia el elemento de la fila entre toy y pieza
	vfx.poner(_fila("plasma"), 0, 0, 0)
	_ok("6 fuego está en la lista de toys", VfxToyJuego.usa_toy("fuego"))
	_tecla_lab(KEY_F)
	_ok("6 F quita el fuego de la lista (pieza de siempre)", not VfxToyJuego.usa_toy("fuego") and lab.texto_hud().contains("pieza de siempre"))
	var f1: int = int(enganche.creados["fuego"])
	vfx.lanzar()
	await avanzar_s(0.5)
	_ok("6 …y no se crea ningún toy de fuego", int(enganche.creados["fuego"]) == f1)
	lab.limpiar_sala()
	_tecla_lab(KEY_F)
	_ok("6 F lo devuelve a toy", VfxToyJuego.usa_toy("fuego"))

	# --- al salir de F4 el ajuste vuelve a como estaba
	_tecla_lab(KEY_F1)
	_ok("7 al salir de F4 el ajuste procedural vuelve a como estaba", VfxToyJuego.activo() == (bool(antes_val) if antes_proc else false))
	_tecla_lab(KEY_F4)
	_ok("7 F4 otra vez lo enciende", VfxToyJuego.activo())
	vfx.marcas = marcas_user
	vfx.guardar_al_marcar = true
	lab.queue_free()
	await avanzar(2)
	_ok("7 al cerrar el lab el ajuste está como al principio", VfxToyJuego.activo() == (bool(antes_val) if antes_proc else false))
