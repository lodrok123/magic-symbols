extends "res://escenas/interior_palloza.gd"
## LA TORRE VERDE POR DENTRO (14/11/2026, Pablo: «añade en la torre también una escena; planeo mejorarla y añadir varios pisos»).
## De momento, la PLANTA BAJA: sala circular de 7 × 7 casillas (granito con musgo), el hueco central con su barandilla y la escalera de madera
## pegada al muro (decorado: sube a las plantas que vendrán). Aquí despacha la Maestre: Marimanta, el cofre del uniforme, el cofre legendario
## del encargo y un cofre mágico. Se entra por la puerta animada de la torre (monte_sumicio_visita.gd), como las pallozas.
## Las casillas de la sala están pintadas en el GridMap del nivel (x 27..33, y 52..58), junto a los interiores de las pallozas.
##
## Para AMPLIAR con más plantas: los puntos de interés están en PUNTOS (casillas desde `centro`); la visita los lee de aquí.

const RADIO := 3
const PUNTOS: Dictionary = {
	# 14/11: (±2, −2) caía en el muro redondo y los cofres quedaban dentro de la pared: van a los lados de Marimanta.
	"marimanta": Vector2i(0, -2),
	"cofre_uniforme": Vector2i(1, -2),
	"cofre_agua": Vector2i(-1, -2),
	"cofre_magico": Vector2i(-2, 1),
}
const GRANITO := Color("#6f6f63")
const MUSGO := Color("#5d7346")
const SUELO_LOSA := Color("#7d766a")
const MADERA := Color("#76543a")


func montar() -> void:
	torre = true
	entrada = Vector2i(0, 2)
	salida = Vector2i(0, 3)
	position = Terreno3D.centro_de(centro, Terreno3D.alto_suelo)
	var s := Terreno3D.casilla
	for z in range(-RADIO, RADIO + 1):
		for x in range(-RADIO, RADIO + 1):
			var c := centro + Vector2i(x, z)
			var p := Vector3(x * s, 0.0, z * s)
			var d := Vector2(x, z).length()
			var fuera := d > RADIO + 0.45
			var borde := not fuera and (absi(x) == RADIO or absi(z) == RADIO or d > RADIO - 0.35)
			var umbral := Vector2i(x, z) == salida
			if fuera:
				Terreno3D.bloquear_celda_completa(c)
				continue
			# Las losas van un dedo por encima del suelo del GridMap (que es tierra) para que se vean.
			_caja(p + Vector3.UP * 0.015, Vector3(s * 0.98, 0.03, s * 0.98), SUELO_LOSA if (x + z) % 2 == 0 else SUELO_LOSA.darkened(0.08))
			if borde and not umbral:
				Terreno3D.bloquear_celda_completa(c)
				var alto := 0.45 if z == RADIO else 1.7          # el muro del sur, bajo: la cámara mira desde ahí
				_caja(p + Vector3.UP * alto * 0.5, Vector3(s, alto, s), GRANITO)
				_caja(p + Vector3.UP * (alto + 0.04), Vector3(s * 0.9, 0.08, s * 0.9), MUSGO)
	# El hueco central de la torre con su barandilla (no se pisa).
	Terreno3D.bloquear_celda_completa(centro)
	_caja(Vector3(0, -0.05, 0), Vector3(s * 0.8, 0.1, s * 0.8), Color("#2a2620"))
	for v in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var b := _caja(v * s * 0.42 + Vector3.UP * 0.45, Vector3(s * 0.84 if v.z != 0 else 0.08, 0.08, s * 0.84 if v.x != 0 else 0.08), MADERA)
		b.position.y = 0.45
	# La escalera de madera pegada al muro del este: peldaños que suben hacia la planta de arriba (aún sin hacer).
	for i in range(6):
		var peldano := _caja(Vector3(2.0 * s, 0.12 + i * 0.22, (1.0 - i * 0.45) * s * 0.55), Vector3(s * 0.7, 0.1, s * 0.28), MADERA.lightened(0.08))
		peldano.rotation.y = 0.0
	Terreno3D.bloquear_celda_completa(centro + Vector2i(2, 0))
	_rotulo("Torre Verde · planta baja", Vector3(0, 2.2, -RADIO * s + 0.6))
	_rotulo("Escalera (próximas plantas)", Vector3(2.0 * s, 1.75, 0))
	_rotulo("Salida", Vector3(0, 0.65, (RADIO + 0.4) * s))
	camara.look_at(global_position + Vector3.UP * 0.35)
	get_viewport().size_changed.connect(_encuadrar)
	_encuadrar()


func _encuadrar() -> void:
	var ventana := get_viewport().get_visible_rect().size
	var aspecto := ventana.x / maxf(ventana.y, 1.0)
	camara.size = maxf(Terreno3D.casilla * 7.4 / maxf(aspecto, 0.01), Terreno3D.casilla * 5.4)


func contiene(c: Vector2i) -> bool:
	return Rect2i(centro - Vector2i(RADIO, RADIO), Vector2i(RADIO * 2 + 1, RADIO * 2 + 1)).has_point(c)


## ¿La casilla (desde `centro`) es muro o queda fuera de la sala? (lo usa la prueba para que nada se ponga dentro de la pared)
static func es_muro(v: Vector2i) -> bool:
	var d := Vector2(v.x, v.y).length()
	return d > RADIO + 0.45 or absi(v.x) == RADIO or absi(v.y) == RADIO or d > RADIO - 0.35


## El punto del mundo de un sitio de la sala (`PUNTOS`).
func punto(sitio: String) -> Vector3:
	var c: Vector2i = centro + (PUNTOS[sitio] as Vector2i)
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))
