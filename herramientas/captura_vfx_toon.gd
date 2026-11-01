extends SceneTree

## CAPTURA DE LA PRUEBA 2 (1/11, Dirección, docs/PRUEBA2_VFX_TOON_2026-11-01.md §1): saca PNG del muro de fuego toon en el LabVfxComparativa3D con los
## mismos nombres que la prueba 1 (muro_cerca, muro_lejos, juego_muro, diez_muros con el fps en el panel). Para MIRARLO, no es una prueba. Necesita ventana
## (sin --headless) pero no espera clics:
##   godot --path . --script res://herramientas/captura_vfx_toon.gd -- docs/capturas/comparativa_vfx/godot_toon
## Modo secuencia (3 s del muro a 2 m, 24 fotogramas por segundo, para ver que el movimiento va a 12): con Movie Maker, que avanza el tiempo fijo por fotograma:
##   godot --path . --write-movie E:/tmp/prueba2_godot/sec/f.png --fixed-fps 24 --script res://herramientas/captura_vfx_toon.gd -- sec
## Con «columna» o «bola» como argumento extra saca también esos efectos si existen (no existen todavía).

const TAM: Vector2i = Vector2i(1600, 1000)
const ESPERA_NACER: int = 50          ## fotogramas tras lanzar antes de la primera captura (~0,8 s a 60 fps)
const FOTOS_SECUENCIA: int = 100      ## 3 s a 24 fps (más 0,3 s de nacer que se descartan al montar el GIF)

var _dir: String = "docs/capturas/comparativa_vfx/godot_toon"
var _lab: Node3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var secuencia: bool = a.size() > 0 and a[0] == "sec"
	if a.size() > 0 and not secuencia:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	await _esperar(20)
	_lab.call("efecto", "muro_toon")
	if secuencia:
		_lab.call("poner_camara", 1)
		_lab.set("_panel_visible", false)
		await _esperar(FOTOS_SECUENCIA)
		quit()
		return
	await _esperar(ESPERA_NACER)
	_lab.call("poner_camara", 1)
	await _esperar(3)
	_guardar("muro_cerca.png")
	_lab.call("poner_camara", 2)
	await _esperar(3)
	_guardar("muro_lejos.png")
	_lab.call("poner_camara", 0)
	await _esperar(3)
	_guardar("juego_muro.png")
	# Solo la llama sobre negro (sin suelo, cubos, jugadora ni cielo ni panel): de aquí cuenta colores prueba_vfx_toon.gd.
	await _solo_llama()
	# Con el sol apagado la llama no debe cambiar (unshaded); se guarda para mirarlo.
	_lab.call("poner_camara", 1)
	var sol: Node = _lab.get_node_or_null("Sol")
	if sol != null:
		sol.set("visible", false)
		await _esperar(3)
		_guardar("muro_cerca_sin_sol.png")
		sol.set("visible", true)
	_lab.call("limpiar")
	await _esperar(10)
	# Columna (1 × 4 m), como en la prueba 1.
	_lab.call("efecto", "columna_toon")
	await _esperar(ESPERA_NACER)
	_lab.call("poner_camara", 1)
	await _esperar(3)
	_guardar("columna_cerca.png")
	_lab.call("poner_camara", 2)
	await _esperar(3)
	_guardar("columna_lejos.png")
	_lab.call("limpiar")
	await _esperar(10)
	# Bola: en vuelo y el impacto (cae a los 6 m: 0,75 s).
	_lab.call("poner_camara", 1)
	_lab.call("efecto", "bola_toon")
	await _esperar(18)
	_guardar("bola_vuelo_cerca.png")
	await _esperar(40)
	_guardar("bola_impacto_cerca.png")
	_lab.call("poner_camara", 2)
	await _esperar(3)
	_guardar("bola_impacto_lejos.png")
	_lab.call("limpiar")
	await _esperar(10)
	_lab.call("poner_camara", 2)
	_lab.call("diez_muros", true)
	await _esperar(90)
	_guardar("diez_muros.png")
	print("CAPTURAS en " + _dir)
	quit()


## Oculta todo menos los efectos, fondo negro, sin panel; guarda muro_cerca_solo_llama.png y lo deja todo como estaba.
func _solo_llama() -> void:
	_lab.call("poner_camara", 1)
	var ocultos: Array = []
	for h in _lab.get_children():
		if h.name == "Suelo" or h.name.begins_with("Cubo") or h.name == "Jugadora":
			ocultos.append(h)
			h.set("visible", false)
	var we: WorldEnvironment = _lab.get_node_or_null("Ambiente") as WorldEnvironment
	var modo: int = we.environment.background_mode
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color.BLACK
	var brillo_activo: bool = we.environment.glow_enabled
	we.environment.glow_enabled = false          # el resplandor del lab (bloom) mezclaría colores alrededor de lo claro: aquí se mide la paleta de la llama
	_lab.set("_panel_visible", false)
	await _esperar(3)
	_guardar("muro_cerca_solo_llama.png")
	we.environment.glow_enabled = brillo_activo
	for h in ocultos:
		h.set("visible", true)
	we.environment.background_mode = modo as Environment.BGMode
	_lab.set("_panel_visible", true)


func _esperar(n: int) -> void:
	for k in range(n):
		await process_frame


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
	print("captura " + nombre)
