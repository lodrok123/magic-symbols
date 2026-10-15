class_name NivelAgua3D
extends Node3D

## DETECTOR DE NIVEL (Fase 13.8 · laboratorio de puzles de agua, 15/10, Juego). La CONDICIÓN de un puzle de agua
## (escenas/puzle.gd, 12.3): mira la profundidad de UNA casilla (AguaSim3D.profundidad_casilla) y avisa con `nivel_alcanzado(true)`
## cuando se cumple lo pedido, y con `nivel_alcanzado(false)` cuando deja de cumplirse. Tres formas de pedirlo:
##   · `objetivo` solo:            se cumple con profundidad ≥ objetivo («llena la cuenca hasta la marca»).
##   · `invertido = true`:         se cumple con profundidad ≤ objetivo («vacía el vado», «la presa ha cortado el agua»).
##   · `banda > 0`:                se cumple con |profundidad − objetivo| ≤ banda («el nivel justo»: ni de más ni de menos).
## Con HISTÉRESIS (`histeresis` u): una vez cumplido hace falta salirse ese margen de más para que deje de estarlo. Sin ella, las
## olas de un trocito a otro (sub 3) abrirían y cerrarían la puerta diez veces por segundo.
## Lee cada CADA s, no cada fotograma: es lo que cuesta nada y lo que hace repetible la prueba sin ventana.
## Se dibuja solo: un poste con una marca a la altura del objetivo y una bola que se enciende al cumplirse.

signal nivel_alcanzado(si: bool)

const CADA: float = 0.1
const COLOR_APAGADA: Color = Color(0.35, 0.35, 0.4)
const COLOR_ENCENDIDA: Color = Color(0.3, 1.0, 0.45)

var celda: Vector2i = Vector2i.ZERO
var objetivo: float = 0.45
var banda: float = 0.0
var invertido: bool = false
var histeresis: float = 0.05
var alcanzado: bool = false
var profundidad: float = 0.0               ## la última leída
var _t: float = 0.0
var _bola_mat: StandardMaterial3D = null


func preparar(p_celda: Vector2i, p_objetivo: float, p_banda: float = 0.0, p_invertido: bool = false) -> void:
	celda = p_celda
	objetivo = p_objetivo
	banda = p_banda
	invertido = p_invertido
	# El poste va en la esquina de la casilla para no tapar el agua.
	position = Terreno3D.centro_de(celda, Terreno3D.alto_suelo) + Vector3(Terreno3D.casilla * 0.38, 0.0, Terreno3D.casilla * 0.38)


func _ready() -> void:
	_dibujar()
	set_physics_process(true)


func _dibujar() -> void:
	var poste := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.05
	cil.bottom_radius = 0.05
	cil.height = 1.6 + Terreno3D.LECHO_AGUA
	poste.mesh = cil
	poste.position = Vector3(0.0, 0.8 - Terreno3D.LECHO_AGUA * 0.5, 0.0)
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.3, 0.25, 0.2)
	poste.material_override = mp
	add_child(poste)
	# La marca: un anillo a la altura del objetivo sobre el suelo de la casilla (el lecho si es cauce).
	var marca := MeshInstance3D.new()
	var anillo := TorusMesh.new()
	anillo.inner_radius = 0.07
	anillo.outer_radius = 0.16
	marca.mesh = anillo
	marca.position = Vector3(0.0, _y_suelo_casilla() - Terreno3D.alto_suelo + objetivo, 0.0)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.85, 0.3) if not invertido else Color(1.0, 0.5, 0.3)
	marca.material_override = mm
	add_child(marca)
	var bola := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.16
	esf.height = 0.32
	bola.mesh = esf
	bola.position = Vector3(0.0, 1.7, 0.0)
	_bola_mat = StandardMaterial3D.new()
	_bola_mat.albedo_color = COLOR_APAGADA
	bola.material_override = _bola_mat
	add_child(bola)


## Suelo de la casilla para la simulación (el lecho bajo un cauce, el suelo normal en lo demás).
func _y_suelo_casilla() -> float:
	if Terreno3D.es_canal_ruinas(celda):
		return Terreno3D.alto_suelo + Terreno3D.FONDO_CANAL
	if Terreno3D.letra_de(celda) == "~" or Terreno3D.es_cauce_seco(celda):
		return Terreno3D.alto_agua - Terreno3D.LECHO_AGUA
	return Terreno3D.alto_suelo + float(Terreno3D.altura_en(celda)) * Terreno3D.ALTO_NIVEL


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = CADA
	leer()


## Lee la casilla y emite si cambia. Devuelve si está cumplido. Se puede llamar a mano (las pruebas).
func leer() -> bool:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return alcanzado
	profundidad = sim.profundidad_casilla(celda)
	var ahora: bool = _cumple(profundidad, alcanzado)
	if ahora != alcanzado:
		alcanzado = ahora
		if _bola_mat != null:
			_bola_mat.albedo_color = COLOR_ENCENDIDA if alcanzado else COLOR_APAGADA
			_bola_mat.emission_enabled = alcanzado
			_bola_mat.emission = COLOR_ENCENDIDA
		nivel_alcanzado.emit(alcanzado)
	return alcanzado


## ¿Se cumple con esta profundidad? `ya` = estaba cumplido (entonces hay que salirse `histeresis` de más para dejar de estarlo).
func _cumple(p: float, ya: bool) -> bool:
	var h: float = histeresis if ya else 0.0
	if banda > 0.0:
		return absf(p - objetivo) <= banda + h
	if invertido:
		return p <= objetivo + h
	return p >= objetivo - h
