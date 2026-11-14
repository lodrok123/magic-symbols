extends Node3D

const MEDIA_ALTURA := 0.32
const ENTRADA := Vector2i(0, 1)
const SALIDA := Vector2i(0, 2)
const VECINO := Vector2i(-1, -1)
const COFRE := Vector2i(1, 1)
const MESA := Vector2i(1, -1)

@export var centro := Vector2i.ZERO
@export var tienda := false
@export var casa_brais := false
## 14/11: dónde se entra y por dónde se sale (casillas desde `centro`). Variables para que la Torre Verde (interior_torre.gd) pueda tener otras.
var entrada := ENTRADA
var salida := SALIDA
var torre := false
@onready var camara: Camera3D = $Camara
var _tapa: MeshInstance3D


func montar() -> void:
	position = Terreno3D.centro_de(centro, Terreno3D.alto_suelo)
	var s := Terreno3D.casilla
	for z in range(-2, 3):
		for x in range(-2, 3):
			var c := centro + Vector2i(x, z)
			var borde := absi(x) == 2 or absi(z) == 2
			var umbral := Vector2i(x, z) == SALIDA
			var alto := MEDIA_ALTURA if z < 0 else 0.0
			if alto > 0.0:
				Terreno3D.realces_terreno[c] = alto
			var p := Vector3(x * s, alto, z * s)
			var tierra := Color("#74604a") if z < 0 else Color("#584838")
			_caja(p - Vector3.UP * 0.067, Vector3(s, 0.16, s), tierra)
			if borde and not umbral:
				Terreno3D.bloquear_celda_completa(c)
				var pared := 0.38 if z == 2 else 1.25
				_caja(p + Vector3.UP * pared * 0.5, Vector3(s, pared, s), Color("#686158"))
	# Las piezas reutilizan sus materiales y proporciones. Se distribuyen a la escala de la sala.
	var muebles := {
		"Hogar": Vector3(-1.68, MEDIA_ALTURA, -2.75),
		"VaraAhumado": Vector3(-1.68, MEDIA_ALTURA, -2.75),
		"Banco": Vector3(-1.7, MEDIA_ALTURA, -2.1),
		"Arcon": Vector3(1.65, MEDIA_ALTURA, -2.3),
		"Pesebre": Vector3(2.55, 0.0, 1.10),
		"Tabique": Vector3(2.55, 0.0, 0.35),
	}
	for nombre in muebles:
		var pieza := $Mobiliario.get_node(nombre) as Node3D
		if tienda:
			pieza.hide()
			continue
		pieza.position = muebles[nombre]
		if casa_brais and nombre == "Banco":
			pieza.position = Vector3(-2.65, MEDIA_ALTURA, -0.35)
		pieza.scale = Vector3.ONE * 1.55
		if nombre in ["Banco", "Arcon", "Pesebre", "Tabique"]:
			var celda := Terreno3D.celda_de(pieza.global_position)
			Terreno3D.bloquear_contorno(celda, pieza)
	if tienda:
		_caja(Vector3(-2.3, 0.70, -1.65), Vector3(1.65, 0.76, 0.60), Color("#674630"))
		_caja(Vector3(-2.3, 1.10, -1.65), Vector3(1.77, 0.10, 0.72), Color("#ad794e"))
		for x in [1.8, 2.8]:
			_caja(Vector3(x, 0.64, -2.80), Vector3(0.11, 0.64, 0.62), Color("#75563a"))
		_caja(Vector3(2.3, 0.98, -2.80), Vector3(1.35, 0.13, 0.85), Color("#514c58"))
		_caja(Vector3(2.55, 1.11, -2.85), Vector3(0.29, 0.14, 0.26), Color("#768769"))
		_caja(Vector3(2.10, 1.12, -2.74), Vector3(0.12, 0.17, 0.12), Color("#b47753"))
		_rotulo("Mostrador", Vector3(-2.3, 1.8, -2.3))
		_rotulo("Síntesis", Vector3(2.3, 1.65, -2.3))
	else:
		_caja(Vector3(2.3, 0.25, 2.3), Vector3(0.85, 0.5, 0.55), Color("#775132"))
		_tapa = _caja(Vector3(2.3, 0.52, 2.3), Vector3(0.90, 0.12, 0.59), Color("#9d7449"))
		if casa_brais:
			for i in range(5):
				var paja := _caja(Vector3(2.45 + (i % 3) * 0.17, 0.035, 1.45 + i * 0.15),
					Vector3(0.18, 0.03, 0.26), Color("#ad8e55"))
				paja.rotation.y = i * 0.6
		_rotulo("Ástrago", Vector3(-1.6, 0.65, -3.1))
		_rotulo("Travariza", Vector3(1.65, 0.7, 2.65))
		# 14/11: los animales de la Travariza (lámina 11: «las vacas y, en un reservado aparte, algún cerdo»), vivos (AnimalVivo).
		# La vaca dormita al oeste del umbral con la cabeza hacia el Ástrago; el cerdo hocica a su lado, junto al muro sur.
		AnimalVivo.poner(self, "vaca", Vector3(-2.5, 0.0, 1.5), -PI * 0.5)
		AnimalVivo.poner(self, "cerdo", Vector3(-1.2, 0.0, 3.0), 0.35)
		for celda in [Vector2i(-1, 1), Vector2i(-1, 0)]:
			Terreno3D.bloquear_celda_completa(centro + celda)
	_rotulo("Salida", Vector3(0, 0.65, 4.55))
	camara.look_at(global_position + Vector3.UP * 0.35)
	get_viewport().size_changed.connect(_encuadrar)
	_encuadrar()


func _encuadrar() -> void:
	var ventana := get_viewport().get_visible_rect().size
	var aspecto := ventana.x / maxf(ventana.y, 1.0)
	# En la referencia los cinco módulos ocupan el ancho y el suelo entre muros, tres quintos.
	var ancho_palloza := Terreno3D.casilla * 5.0
	# En panorámico se puede recortar el exterior, con margen vertical para la salida.
	var alto_minimo := Terreno3D.casilla * 3.85
	camara.size = maxf(ancho_palloza / maxf(aspecto, 0.01), alto_minimo)


func contiene(c: Vector2i) -> bool:
	return Rect2i(centro - Vector2i(2, 2), Vector2i(5, 5)).has_point(c)


func mostrar_cofre(abierto: bool) -> void:
	if _tapa != null:
		_tapa.position = Vector3(2.3, 0.73, 2.03) if abierto else Vector3(2.3, 0.52, 2.3)
		_tapa.rotation.x = -1.15 if abierto else 0.0


func _caja(p: Vector3, tam: Vector3, color: Color) -> MeshInstance3D:
	var caja := BoxMesh.new()
	caja.size = tam
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	var pieza := MeshInstance3D.new()
	pieza.mesh = caja
	pieza.material_override = material
	add_child(pieza)
	pieza.position = p
	return pieza


func _rotulo(texto: String, p: Vector3) -> void:
	var rotulo := Label3D.new()
	rotulo.text = texto
	rotulo.position = p
	rotulo.pixel_size = 0.012
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(rotulo)
