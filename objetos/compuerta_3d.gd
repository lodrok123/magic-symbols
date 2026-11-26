class_name Compuerta3D
extends Area3D

## COMPUERTA (Fase 13.8 · laboratorio de puzles de agua, 15/10, Juego). Una PARED que se abre y se cierra en una casilla de cauce
## (`c`): cerrada, la casilla es sólida para el agua (AguaSim3D.solidificar_casilla); abierta, es una casilla más del cauce
## (Terreno3D.cauces_abiertos + la casilla abierta). Es el «interruptor» de los vasos comunicantes: dos cuencas unidas por
## una compuerta se igualan al abrirla (medido con el gemelo: 0,64 u → 0,36/0,36).
##
## Cómo se abre: por código (`abrir`, `cerrar`, `alternar`: lo llama un Pulsador3D o el puzle) o con un hechizo si se le dice
## con qué: `abre_con` / `cierra_con` ∈ "fuego" | "agua" | "hielo" | "rayo" | "explosion" | "". Una compuerta de HIELO es
## `abre_con = "fuego"` (se derrite); una de TIERRA que el hielo tapona es `cierra_con = "hielo"`; una ROCA que solo abre un barril
## (Barril3D) es `abre_con = "explosion"` (se dibuja como pedrusco y no reacciona a ningún hechizo). Lo demás no le hace nada.
##
## Qué pasa con el agua al cerrar: la que había en la casilla se reparte entre las vecinas abiertas (lo hace `_poner_cerrado`).
## Qué NO hace: no es una puerta para el jugador (la casilla de cauce no se pisa). Se dibuja sola: una losa que baja al abrirse.

signal cambio(abierta: bool)

const ETIQUETA: Dictionary = {"fuego": "calor", "agua": "agua", "hielo": "frio", "rayo": "rayo"}
const COLOR_CERRADA: Color = Color(0.55, 0.5, 0.45)
const COLOR_HIELO: Color = Color(0.8, 0.92, 1.0, 0.85)
const COLOR_ROCA: Color = Color(0.42, 0.4, 0.38)
const ALTO: float = 1.3
const GROSOR: float = 0.3
const T_MOVER: float = 0.6

var celda: Vector2i = Vector2i.ZERO
var abierta: bool = false
var abre_con: String = ""
var cierra_con: String = ""
var vertical: bool = true                  ## la losa cruza la casilla de norte a sur (true) o de este a oeste
var estrecha: bool = true                  ## abierta, deja pasar el agua solo por el trocito central (AguaSim3D.abrir_solo): el trasvase es
                                           ## 3 veces más lento que con la casilla entera (15/10, Pablo: «el llenado tiene que ser más progresivo»)
var _losa: MeshInstance3D = null
var _y_cerrada: float = 0.0
## 26/11 (Pablo: «una pared que bloquea una masa de agua; al explotar un barril la pared se destruye y deja pasar el agua»): `modelo = "muro"`
## dibuja el muro de sillares del muro agrietado (MuroAgrietado3D.MODELO_MURO) en vez de la losa o el pedrusco; al abrirse se hace añicos
## (fragmentos, polvo, derrumbe) y no vuelve: un muro roto no se cierra a la vista (cerrar sigue tapando el agua, por código).
var modelo: String = ""
var _muro: Node3D = null


func preparar(p_celda: Vector2i, p_abierta: bool = false, p_abre_con: String = "", p_cierra_con: String = "", p_vertical: bool = true) -> void:
	celda = p_celda
	abierta = p_abierta
	abre_con = p_abre_con
	cierra_con = p_cierra_con
	vertical = p_vertical
	position = Terreno3D.centro_de(celda, Terreno3D.alto_suelo)
	Terreno3D.cauces_a_ras[celda] = true      # cauce hondo: la casilla de una compuerta no es foso (cerrada es un dique a ras)


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	var por_hechizo: bool = (abre_con != "" and abre_con != "explosion") or (cierra_con != "" and cierra_con != "explosion")
	collision_layer = Lanzador3D.CAPA_REACTIVO if por_hechizo else 0
	if abre_con == "explosion" or cierra_con == "explosion":
		add_to_group("explosionable")
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(Terreno3D.casilla * 0.9, ALTO, Terreno3D.casilla * 0.9)
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO * 0.5, 0.0)
	add_child(forma)
	_dibujar()
	_aplicar(false)


func _dibujar() -> void:
	if modelo == "muro" and _poner_muro():
		return
	_losa = MeshInstance3D.new()
	var b := BoxMesh.new()
	var ancho: float = Terreno3D.casilla * 0.96
	b.size = Vector3(GROSOR, ALTO + Terreno3D.LECHO_AGUA, ancho) if vertical else Vector3(ancho, ALTO + Terreno3D.LECHO_AGUA, GROSOR)
	_losa.mesh = b
	var mat := StandardMaterial3D.new()
	if abre_con == "explosion":
		# Una roca: un pedrusco que tapa la casilla entera (al «abrirse» se hunde, como si se desmoronara).
		var roca := SphereMesh.new()
		roca.radius = Terreno3D.casilla * 0.48
		roca.height = ALTO + Terreno3D.LECHO_AGUA
		roca.radial_segments = 7
		roca.rings = 4
		_losa.mesh = roca
		mat.albedo_color = COLOR_ROCA
		mat.roughness = 1.0
	elif abre_con == "fuego":
		mat.albedo_color = COLOR_HIELO
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.15
	else:
		mat.albedo_color = COLOR_CERRADA
		mat.roughness = 0.9
	_losa.material_override = mat
	_y_cerrada = ALTO * 0.5 - Terreno3D.LECHO_AGUA * 0.5
	_losa.position = Vector3(0.0, _y_cerrada, 0.0)
	add_child(_losa)


## El muro de sillares (la pieza del muro agrietado, con el material común para que se vea a través al tapar a la jugadora). false sin modelo.
func _poner_muro() -> bool:
	var ruta: String = "res://arte/piezas/%s.tscn" % MuroAgrietado3D.MODELO_MURO
	if not ResourceLoader.exists(ruta):
		return false
	var n: Node3D = (load(ruta) as PackedScene).instantiate() as Node3D
	if n == null:
		return false
	for col in n.find_children("*", "CollisionObject3D", true, false):
		col.free()
	n.name = "muro"
	add_child(n)
	Ocluso3D.convertir_nodo(n)
	_muro = n
	return true


## El muro salta en pedazos (lo de MuroAgrietado3D.romper con la roca: fragmentos que vuelan, polvo y derrumbe).
func _romper_muro(animar: bool) -> void:
	if _muro == null or not _muro.visible:
		return
	_muro.visible = false
	if not animar or not is_inside_tree() or not (get_parent() is Node3D):
		return
	preload("res://presentacion/estados_blender_3d.gd").fragmentos(get_parent() as Node3D, global_transform, true)
	VfxPuzle3D.polvo(get_parent() as Node3D, global_position + Vector3(0.0, 0.1, 0.0), 1.1)
	Sfx.play(self, "derrumbe")


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	if rune_data == null:
		return
	var m: Dictionary = Materia.de(hechizo if hechizo != null else rune_data)
	if not abierta and abre_con != "" and Materia.cumple(m, ETIQUETA.get(abre_con, "?")):
		abrir()
	elif abierta and cierra_con != "" and Materia.cumple(m, ETIQUETA.get(cierra_con, "?")):
		cerrar()


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> bool:
	if rune_data == null:
		return false
	var m: Dictionary = Materia.de(hechizo if hechizo != null else rune_data)
	if not abierta:
		return abre_con != "" and Materia.cumple(m, ETIQUETA.get(abre_con, "?"))
	return cierra_con != "" and Materia.cumple(m, ETIQUETA.get(cierra_con, "?"))


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, ALTO * 0.6, 0.0))


## Un Barril3D ha explotado a `_punto`: la roca se desmorona (o, si `cierra_con` es explosión, el derrumbe tapona el paso).
func recibir_explosion(_punto: Vector3) -> void:
	if not abierta and abre_con == "explosion":
		abrir()
	elif abierta and cierra_con == "explosion":
		cerrar()


## --- Abrir y cerrar ---
## (El muro, `modelo=muro`, se rompe al abrir: suena el derrumbe en `_romper_muro`, no el chasquido de la losa.)

func abrir() -> void:
	if abierta:
		return
	abierta = true
	_aplicar(true)
	Sfx.play(self, "compuerta_baja")     # 13/11 (inventario SFX): antes no sonaba
	cambio.emit(true)


func cerrar() -> void:
	if not abierta:
		return
	abierta = false
	_aplicar(true)
	Sfx.play(self, "compuerta_baja")     # 13/11 (inventario SFX): antes no sonaba
	cambio.emit(false)


func alternar() -> void:
	if abierta:
		cerrar()
	else:
		abrir()


## Lleva el estado al mundo (simulación + cauces abiertos) y a la losa.
func _aplicar(animar: bool) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if abierta:
		Terreno3D.cauces_abiertos[celda] = true
		if sim != null:
			if estrecha:
				# El hueco de la compuerta: el agua cruza la losa de un lado al otro (perpendicular a ella), por el trocito central.
				var lados: Array = [Vector2i(1, 0), Vector2i(-1, 0)] if vertical else [Vector2i(0, 1), Vector2i(0, -1)]
				sim.abrir_solo(celda, lados)
			else:
				sim.solidificar_casilla(celda, false)
	else:
		Terreno3D.cauces_abiertos.erase(celda)
		if sim != null:
			sim.quitar_estrecho(celda)                   # vuelve a leer la casilla: sin cauce abierto es pared otra vez
			sim.solidificar_casilla(celda, true)
	if _muro != null:
		if abierta:
			_romper_muro(animar)
		return
	if _losa == null:
		return
	var y_obj: float = _y_cerrada - (ALTO + Terreno3D.LECHO_AGUA) * 0.92 if abierta else _y_cerrada
	if animar and is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(_losa, "position:y", y_obj, T_MOVER).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			Sfx.play(self,"boton_clic",0.7)
			preload("res://presentacion/feedback_objeto_3d.gd").sacudir(_losa,0.015)
			if get_parent() is Node3D:
				preload("res://presentacion/feedback_objeto_3d.gd").rafaga(get_parent(),global_position,"polvo",Color(0.55,0.52,0.46),5))
	else:
		_losa.position.y = y_obj
