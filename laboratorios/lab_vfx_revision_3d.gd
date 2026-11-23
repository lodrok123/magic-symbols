extends "res://laboratorios/lab_vfx_comparativa_3d.gd"

## Secuencia reproducible; los efectos de producción se conservan en el laboratorio original.
const RECETAS_REVISION: Array = [
	["Barrera agua pequeña", "agua", 3, Vector3(0.85, 1.1, 0.85)],
	["Barrera agua grande", "agua", 3, Vector3(2.4, 1.8, 2.4)],
	["Muro agua largo", "agua", 1, Vector3(3.45, 1.5, 0.3)],
	["Muro agua alto", "agua", 1, Vector3(1.6, 2.4, 0.3)],
	["Géiser alto", "agua", 2, Vector3(0.5, 4, 0.5)],
	["Géiser bajo y ancho", "agua", 2, Vector3(1.3, 1.6, 1.3)],
	["Muro magma", "magma", 1, Vector3(3.45, 1.5, 0.3)],
	["Pilar magma", "magma", 2, Vector3(0.5, 4, 0.5)],
	["Barrera magma", "magma", 3, Vector3(1.5, 1.5, 1.5)],
	["Viento alto", "viento", 2, Vector3(0.5, 4, 0.5)],
	["Viento bajo y ancho", "viento", 2, Vector3(1.3, 1.6, 1.3)]]
var receta_revision: int = 0
var mejoras: bool = true
var fondo_oscuro: bool = false
var referencia_fuego: bool = false

func _ready() -> void:
	super._ready()
	mostrar_revision()

func _nuevo_toy() -> Node3D:
	if mejoras:
		match elemento:
			"agua": return preload("res://laboratorios/vfx_revision/agua_revision.gd").new()
			"magma": return preload("res://laboratorios/vfx_revision/magma_revision.gd").new()
			"viento": return preload("res://laboratorios/vfx_revision/viento_revision.gd").new()
	return super._nuevo_toy()

func mostrar_revision(conservar: bool = false) -> void:
	var receta: Array = RECETAS_REVISION[receta_revision]
	var tam: Vector3 = receta[3]
	var fig: int = receta[2]
	var el: String = receta[1]
	if conservar and is_instance_valid(_param):
		tam = _param.semiejes()
		fig = int(_param.figura)
		el = elemento
	if receta[1] == "magma":
		el = "fuego" if referencia_fuego else "magma"
	limpiar()
	elemento = el
	var e = _nuevo_toy()
	e.definir(fig, tam.x, tam.y, tam.z)
	_param_i = fig
	_toy = true
	_poner_param(e, 0)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.is_pressed() and not ev.is_echo():
		match ev.keycode:
			KEY_BRACKETRIGHT, KEY_F7:
				referencia_fuego = false
				receta_revision = (receta_revision + 1) % RECETAS_REVISION.size()
				mostrar_revision()
				return
			KEY_BRACKETLEFT, KEY_F6:
				referencia_fuego = false
				receta_revision = posmod(receta_revision - 1, RECETAS_REVISION.size())
				mostrar_revision()
				return
			KEY_F1:
				mejoras = not mejoras
				mostrar_revision(true)
				return
			KEY_F2:
				mostrar_revision(true)
				return
			KEY_F3:
				if is_instance_valid(_param) and _param.has_method("golpe_en"):
					# Contacto conocido sobre la piel: solo demostración, no señal de combate.
					_param.golpe_en(_param.to_global(Vector3(_param.semieje_x * 0.866, _param.semieje_y * 0.5, 0)))
				return
			KEY_F4:
				if is_instance_valid(_param): _param.morir()
				return
			KEY_F5:
				fondo_oscuro = not fondo_oscuro
				var suelo := get_node("Suelo") as MeshInstance3D
				(suelo.material_override as StandardMaterial3D).albedo_color = Color(0.025, 0.03, 0.04) if fondo_oscuro else Color(0.42, 0.44, 0.4)
				return
			KEY_F8:
				if RECETAS_REVISION[receta_revision][1] == "magma":
					referencia_fuego = not referencia_fuego
					mostrar_revision(true)
				return
	super._unhandled_input(ev)

func _process(delta: float) -> void:
	super._process(delta)
	if _panel_visible:
		_panel.text = "REVISIÓN VFX 19/11 | %s | %s\nF6 / F7 receta anterior / siguiente · F1 antes/después · F2 repetir\nF3 golpe de muestra (agua) · F4 expirar · F5 fondo oscuro · F8 comparar magma/fuego\nC cámara · Tab gesto · Mayús+Tab cámara lenta · H panel\nU/J ancho · I/K alto · O/L fondo · cámara libre: botón derecho gira, rueda acerca, central desplaza\n%d fps | %s" % [RECETAS_REVISION[receta_revision][0], "FUEGO DE REFERENCIA" if referencia_fuego else ("MEJORAS" if mejoras else "ORIGINAL"), int(Engine.get_frames_per_second()), _texto_param()]

