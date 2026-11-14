extends "res://escenas/interior_palloza.gd"
## LA TORRE VERDE POR DENTRO (14/11/2026, Pablo: «añade en la torre también una escena; planeo mejorarla y añadir varios pisos»).
## CINCO PLANTAS (DISENO_INTERIORES_SUMICIO.md, orden del PPTX): 0 aula · 1 estudio · 2 biblioteca · 3 celdas · 4 despacho.
## Todas son la MISMA sala circular de 7 × 7 casillas (granito con musgo), con el hueco central y su barandilla, la escalera de madera
## pegada al muro del este y una ventana-balcón al norte. Cambiar de planta NO mueve a Mid de casilla: se reconstruye el mobiliario de la
## sala con un fundido corto (monte_sumicio_visita.gd), como se cruzan las puertas.
##
## POR QUÉ UNA SOLA SALA: las casillas del interior están pintadas en el GridMap del nivel (x 27..33, z 52..58, junto a los interiores de
## las pallozas). Cinco salas serían cuatro bloques de 7 × 7 más que pintar a mano en Nivel_MonteSumicio.tscn; una sola sala que se
## reconstruye no toca el nivel y deja el mobiliario en un único sitio parametrizable.
##
## CONSECUENCIA a tener en cuenta: como todas las plantas ocupan las mismas casillas del mundo, lo que se mide por distancia (Marimanta,
## los cofres, el cofre mágico) está físicamente al alcance en cualquier planta. La visita lo filtra con `planta == 0` (`_en_planta_baja`).
##
## Se entra por la puerta animada de la torre (monte_sumicio_visita.gd), y se entra al AULA (planta baja). La Maestre despacha ARRIBA:
## Marimanta, el cofre del uniforme y el cofre legendario del encargo están en el DESPACHO (planta 4), así que la audiencia es subiendo
## las cuatro plantas (decisión de Pablo del 14/11). El cofre mágico se queda en el aula: es un servicio, no se sube cuatro plantas.
##
## Para AJUSTAR: los puntos de interés están en PUNTOS y el mobiliario de cada planta, en su propia función `_planta_*`, con las medidas
## en constantes al principio de cada una. Las formas simples están en su sitio y escala para cambiarlas por el .glb sin mover nada.

const RADIO := 3
const PUNTOS: Dictionary = {
	# 14/11: (±2, −2) caía en el muro redondo y los cofres quedaban dentro de la pared: van a los lados de Marimanta.
	"marimanta": Vector2i(0, -2),
	"cofre_uniforme": Vector2i(1, -2),
	"cofre_agua": Vector2i(-1, -2),
	"cofre_magico": Vector2i(-2, 1),
}
## 14/11 (decisión de Pablo): LA AUDIENCIA SUBE AL DESPACHO. Marimanta y sus dos cofres viven en la planta 4; el cofre mágico se queda
## en el aula, que es un servicio y no tiene sentido subirlo cuatro plantas. La casilla de cada uno no cambia (PUNTOS): cambia la planta.
## El mobiliario de esas dos plantas deja libres las casillas de sus puntos (`_planta_aula` y `_planta_despacho`).
const PLANTA_DE: Dictionary = {
	"marimanta": 4,
	"cofre_uniforme": 4,
	"cofre_agua": 4,
	"cofre_magico": 0,
}
const GRANITO := Color("#6f6f63")
const MUSGO := Color("#5d7346")
const SUELO_LOSA := Color("#7d766a")
const MADERA := Color("#76543a")
const MADERA_CLARA := Color("#9c7347")
const PERGAMINO := Color("#cfbb8e")
const PIEDRA_CELDA := Color("#7a7569")
const PANO_ROJO := Color("#93394a")
const CERA := Color("#e8dcb4")
const LLAMA := Color("#e8a33c")
const HIEDRA := Color("#4f6b38")

## Las cinco plantas, de abajo arriba. `rotulo` es lo que se lee dentro; `nombre`, lo que enseña el HUD de la visita.
const PLANTAS: Array = [
	{"nombre": "Torre Verde · el aula", "rotulo": "Planta baja · sala de lectura"},
	{"nombre": "Torre Verde · sala de estudio", "rotulo": "Planta 1 · sala de estudio"},
	{"nombre": "Torre Verde · biblioteca", "rotulo": "Planta 2 · la biblioteca"},
	{"nombre": "Torre Verde · celdas", "rotulo": "Planta 3 · celdas de aprendices"},
	{"nombre": "Torre Verde · despacho de la Maestre", "rotulo": "Planta 4 · despacho de Marimanta"},
]

## Casillas (desde `centro`) donde se usa la escalera: se sube por el norte y se baja por el sur (plano de DISENO_INTERIORES_SUMICIO.md).
## Son las casillas de AL LADO de la escalera, no la escalera: sus peldaños son sólidos y no se pisan.
const SUBE := Vector2i(1, -1)
const BAJA := Vector2i(1, 1)
## El umbral de la puerta, solo en la planta baja (arriba el sur es muro: no se puede salir desde un piso alto).
const SALIDA_PUERTA := Vector2i(0, 3)
const SIN_SALIDA := Vector2i(0, 99)

var planta := 0
var _planta_anterior := -1
## Lo que la visita coloca en la sala y no monta esta escena (Marimanta, el cofre del uniforme, el legendario, el cofre mágico):
## [nodo, planta en la que vive, si se veía por sí mismo]. Se registran con `registrar`, porque algunos (el cofre del uniforme) no son
## hijos de la sala y la sala no puede encontrarlos de otro modo.
var _invitados: Array = []


func montar() -> void:
	torre = true
	entrada = Vector2i(0, 2)
	position = Terreno3D.centro_de(centro, Terreno3D.alto_suelo)
	_construir()
	camara.look_at(global_position + Vector3.UP * 0.35)
	get_viewport().size_changed.connect(_encuadrar)
	_encuadrar()


## Cambia de planta y vuelve a montar la sala. Lo llama la visita entre los dos tramos del fundido.
func ir_a_planta(n: int) -> void:
	planta = clampi(n, 0, PLANTAS.size() - 1)
	_construir()


## En qué planta vive un punto de interés (`PUNTOS`).
func planta_de(sitio: String) -> int:
	return int(PLANTA_DE.get(sitio, 0))


## Apunta un nodo que la visita coloca en la sala, para esconderlo cuando no estemos en su planta.
func registrar(n: Node3D, sitio: String) -> void:
	if n == null:
		return
	_invitados.append([n, planta_de(sitio), n.visible])
	_aplicar_invitados()


func puede_subir() -> bool:
	return planta < PLANTAS.size() - 1


func puede_bajar() -> bool:
	return planta > 0


## La casilla (desde `centro`) donde aparece Mid al cambiar de planta: subiendo sale al pie de la escalera que baja, y al revés.
func llegada(delta: int) -> Vector2i:
	return BAJA if delta > 0 else SUBE


func nombre_planta() -> String:
	return String(PLANTAS[planta]["nombre"])


## ---- La sala ----

## Rehace la sala con el mobiliario de `planta`. Solo toca lo que montó esta función (marcado con `_planta`): Marimanta, los cofres y lo
## que la visita cuelga de la sala se quedan donde están, y se esconden mientras no estemos en la planta baja.
func _construir() -> void:
	for h in get_children():
		if h.has_meta("_planta"):
			remove_child(h)
			h.queue_free()
	var previos := get_children()
	salida = SALIDA_PUERTA if planta == 0 else SIN_SALIDA
	_suelo_y_muros()
	_hueco_central()
	_escalera()
	_ventana_balcon()
	match planta:
		0: _planta_aula()
		1: _planta_estudio()
		2: _planta_biblioteca()
		3: _planta_celdas()
		4: _planta_despacho()
	_rotulo(String(PLANTAS[planta]["rotulo"]), Vector3(0, 2.2, -RADIO * Terreno3D.casilla + 0.6))
	if planta == 0:
		_rotulo("Salida", Vector3(0, 0.65, (RADIO + 0.4) * Terreno3D.casilla))
	_rotulo("Escalera", Vector3(2.0 * Terreno3D.casilla, 1.75, 0))
	for h in get_children():
		if not previos.has(h):
			h.set_meta("_planta", true)
	_aplicar_invitados()


## Enseña a Marimanta y a los cofres solo en su planta. Al salir de su planta se apunta si se veían por sí mismos (el cofre legendario
## está oculto hasta que Marimanta recibe el trabajo) para no «encenderlos» al volver.
func _aplicar_invitados() -> void:
	for inv in _invitados:
		var n: Node3D = inv[0]
		if not is_instance_valid(n):
			continue
		var suya := int(inv[1])
		if _planta_anterior == suya and _planta_anterior != planta:
			inv[2] = n.visible
		n.visible = planta == suya and bool(inv[2])
	_planta_anterior = planta


func _suelo_y_muros() -> void:
	var s := Terreno3D.casilla
	for z in range(-RADIO, RADIO + 1):
		for x in range(-RADIO, RADIO + 1):
			var c := centro + Vector2i(x, z)
			# Se libera antes de volver a bloquear: el umbral de la puerta solo está libre en la planta baja, y si no se libera al
			# bajar del piso 1 la casilla seguiría bloqueada y Mid no podría salir de la torre.
			Terreno3D.liberar_celda(c)
			var p := Vector3(x * s, 0.0, z * s)
			var d := Vector2(x, z).length()
			var fuera := d > RADIO + 0.45
			var borde := not fuera and (absi(x) == RADIO or absi(z) == RADIO or d > RADIO - 0.35)
			var umbral := Vector2i(x, z) == salida
			if fuera:
				Terreno3D.bloquear_celda_completa(c)
				continue
			# Las losas van un dedo por encima del suelo del GridMap (que es tierra) para que se vean.
			var losa := SUELO_LOSA if planta < 3 else PIEDRA_CELDA          # las celdas y el despacho, de piedra más fría
			_caja(p + Vector3.UP * 0.015, Vector3(s * 0.98, 0.03, s * 0.98), losa if (x + z) % 2 == 0 else losa.darkened(0.08))
			if borde and not umbral:
				Terreno3D.bloquear_celda_completa(c)
				var alto := 0.45 if z == RADIO else 1.7          # el muro del sur, bajo: la cámara mira desde ahí
				_caja(p + Vector3.UP * alto * 0.5, Vector3(s, alto, s), GRANITO)
				_caja(p + Vector3.UP * (alto + 0.04), Vector3(s * 0.9, 0.08, s * 0.9), MUSGO)


## El hueco central con su barandilla (no se pisa). Desde las plantas altas se ve la de abajo en penumbra.
func _hueco_central() -> void:
	var s := Terreno3D.casilla
	# 14/11: choca con la barandilla (su caja), no con la casilla entera.
	_solido_caja(Vector3(0, 0.5, 0), Vector3(s * 0.84 + 0.08, 1.0, s * 0.84 + 0.08))
	var fondo := Color("#2a2620") if planta == 0 else Color("#15130f")      # arriba el hueco es más profundo: más oscuro
	_caja(Vector3(0, -0.05, 0), Vector3(s * 0.8, 0.1, s * 0.8), fondo)
	for v in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var b := _caja(v * s * 0.42 + Vector3.UP * 0.45, Vector3(s * 0.84 if v.z != 0 else 0.08, 0.08, s * 0.84 if v.x != 0 else 0.08), MADERA)
		b.position.y = 0.45
		# Los balaustres, para que la barandilla no sea una tabla flotando.
		for t in [-0.3, 0.0, 0.3]:
			var lado := Vector3(t * s * 0.84, 0.0, 0.0) if v.z != 0 else Vector3(0.0, 0.0, t * s * 0.84)
			_caja(v * s * 0.42 + lado + Vector3.UP * 0.22, Vector3(0.06, 0.44, 0.06), MADERA)


## La escalera de madera pegada al muro del este: sube hacia el norte, baja hacia el sur.
func _escalera() -> void:
	var s := Terreno3D.casilla
	for i in range(6):
		_caja(Vector3(2.0 * s, 0.12 + i * 0.22, (1.0 - i * 0.45) * s * 0.55), Vector3(s * 0.7, 0.1, s * 0.28), MADERA.lightened(0.08))
	# 14/11: la escalera choca con lo que ocupan sus peldaños (antes, solo su casilla: los de los extremos se atravesaban).
	_solido_caja(Vector3(2.0 * s, 0.7, -0.07 * s), Vector3(s * 0.7, 1.4, s * 1.52))


## La ventana-balcón del norte, por donde entra la luz y cuelgan hiedra y helecho.
func _ventana_balcon() -> void:
	var s := Terreno3D.casilla
	var z := -(RADIO - 0.5) * s
	_caja(Vector3(-0.9 * s, 1.15, z), Vector3(s * 0.95, 1.05, 0.12), Color("#cdd6cf"))      # el hueco claro del vano
	_caja(Vector3(-0.9 * s, 0.6, z + 0.1), Vector3(s * 0.95, 0.1, 0.4), MADERA_CLARA)       # el antepecho de roble
	for i in range(5):
		var x := -1.35 * s + i * 0.24
		_caja(Vector3(x, 1.45 - (i % 3) * 0.12, z + 0.16), Vector3(0.05, 0.5 + (i % 2) * 0.22, 0.05), HIEDRA)


## ---- Planta 0 · el aula (sala de lectura) ----
## Mesas largas con pergaminos y pupitres pequeños, y la ventana a la montaña (el vano del norte).
##
## EL AULA DEJA LIBRES TODAS LAS CASILLAS DE `PUNTOS`, aunque sus dueños vivan arriba. Motivo: los autoguardados de la admisión, el
## uniforme y el cofre pasan en el DESPACHO, y al cargar la partida la sala se monta en la planta baja con Mid donde la dejó: si el aula
## tuviera un mueble en la casilla de Marimanta, Mid reaparecería dentro de la mesa. Libres también el paso de la puerta (la columna
## x = 0, del umbral al hueco) y las dos casillas de la escalera.

func _planta_aula() -> void:
	var s := Terreno3D.casilla
	# La mesa larga del norte, sin llegar a la fila de Marimanta y los cofres (z = −2): ocupa (−1,−1) y (0,−1).
	_mesa_larga(Vector3(-0.5 * s, 0.0, -0.8 * s), false)
	_caja(Vector3(-0.95 * s, 0.68, -0.85 * s), Vector3(0.42, 0.02, 0.3), PERGAMINO)
	_caja(Vector3(-0.1 * s, 0.68, -0.76 * s), Vector3(0.36, 0.03, 0.28), PERGAMINO.darkened(0.1))
	# La mesa larga del oeste, de norte a sur: ocupa (−2,−1) y (−2,0) y no llega a la casilla del cofre mágico (−2,1).
	_mesa_larga(Vector3(-1.9 * s, 0.0, -0.5 * s), true)
	_caja(Vector3(-1.9 * s, 0.68, -0.75 * s), Vector3(0.3, 0.02, 0.42), PERGAMINO)
	# Dos pupitres bajos mirando a la mesa del norte.
	_pupitre(Vector3(-0.95 * s, 0.0, 0.1 * s), 0.0, false)
	_pupitre(Vector3(-0.95 * s, 0.0, 1.05 * s), 0.0, false)


## Una mesa larga de castaño con sus cuatro patas; `en_z`, a lo largo del eje Z (si no, a lo largo de X).
func _mesa_larga(pos: Vector3, en_z: bool) -> void:
	var s := Terreno3D.casilla
	var largo := s * 1.55
	var ancho := s * 0.5
	var tam := Vector3(ancho, 0.08, largo) if en_z else Vector3(largo, 0.08, ancho)
	_caja(pos + Vector3(0, 0.62, 0), tam, MADERA_CLARA)
	_solido_caja(pos + Vector3(0, 0.4, 0), Vector3(tam.x + 0.1, 0.8, tam.z + 0.1))
	for a in [-0.42, 0.42]:
		for b in [-0.3, 0.3]:
			var d := Vector3(b * ancho, 0.3, a * largo) if en_z else Vector3(a * largo, 0.3, b * ancho)
			_caja(pos + d, Vector3(0.1, 0.6, 0.1), MADERA)


## ---- Planta 1 · sala de estudio ----
## Pupitres y atriles de castaño a escala sumiciu, una vela en cada pupitre, aprendices de rojo copiando.

const ESTUDIO_PUPITRES: Array = [
	[Vector2(-1.95, -0.5), PI * 0.5], [Vector2(-1.95, 0.5), PI * 0.5],
	[Vector2(-0.95, -1.75), 0.0], [Vector2(0.95, -1.75), 0.0],
	[Vector2(-0.95, 1.75), PI],
]


func _planta_estudio() -> void:
	var s := Terreno3D.casilla
	for datos in ESTUDIO_PUPITRES:
		var c: Vector2 = datos[0]
		_pupitre(Vector3(c.x * s, 0.0, c.y * s), float(datos[1]), true)
	# El atril del maestro, frente al vano del norte.
	_atril(Vector3(0.95 * s, 0.0, -1.85 * s), 0.25)
	# Dos aprendices de rojo copiando (formas simples hasta que haya modelo).
	_figura_simple(Vector3(-1.45 * s, 0.0, -0.5 * s), PANO_ROJO)
	_figura_simple(Vector3(-0.95 * s, 0.0, -1.25 * s), PANO_ROJO.darkened(0.12))


## Un pupitre bajo con su banqueta; con `vela`, la vela encendida encima.
func _pupitre(pos: Vector3, giro: float, vela: bool) -> void:
	var tablero := _caja(pos + Vector3(0, 0.52, 0), Vector3(0.95, 0.07, 0.6), MADERA_CLARA)
	tablero.rotation.y = giro
	_solido_caja(pos + Vector3(0, 0.3, 0), Vector3(0.95 if absf(sin(giro)) < 0.5 else 0.6, 0.6, 0.6 if absf(sin(giro)) < 0.5 else 0.95))
	for lado in [-0.35, 0.35]:
		var pata := _caja(pos + Vector3(lado * cos(giro), 0.26, lado * -sin(giro)), Vector3(0.09, 0.52, 0.09), MADERA)
		pata.rotation.y = giro
	var banqueta := _caja(pos + Vector3(sin(giro) * 0.62, 0.28, cos(giro) * 0.62), Vector3(0.5, 0.08, 0.34), MADERA)
	banqueta.rotation.y = giro
	if vela:
		_vela(pos + Vector3(0.28 * cos(giro), 0.56, -0.28 * sin(giro)))


func _atril(pos: Vector3, giro: float) -> void:
	_caja(pos + Vector3(0, 0.45, 0), Vector3(0.14, 0.9, 0.14), MADERA)
	var tabla := _caja(pos + Vector3(0, 0.98, 0), Vector3(0.7, 0.06, 0.5), MADERA_CLARA)
	tabla.rotation = Vector3(-0.35, giro, 0.0)
	var libro := _caja(pos + Vector3(0, 1.05, 0.02), Vector3(0.5, 0.05, 0.34), PERGAMINO)
	libro.rotation = Vector3(-0.35, giro, 0.0)
	_solido_caja(pos + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5))


func _vela(pos: Vector3) -> void:
	_caja(pos + Vector3(0, 0.02, 0), Vector3(0.12, 0.03, 0.12), Color("#8d8d84"))      # el platillo
	_caja(pos + Vector3(0, 0.11, 0), Vector3(0.05, 0.16, 0.05), CERA)
	_caja(pos + Vector3(0, 0.22, 0), Vector3(0.035, 0.07, 0.035), LLAMA)


## ---- Planta 2 · la biblioteca ----
## Anaqueles curvos que siguen el muro rodeando el hueco, y el archivo de mapas CERRADO (bloqueado hasta el Nivel I).

const ANAQUEL_ALTO := 1.45
const ANAQUEL_FONDO := 0.5


func _planta_biblioteca() -> void:
	var s := Terreno3D.casilla
	var r := (RADIO - 0.75) * s
	# Los anaqueles siguen el muro en dos arcos (norte-oeste y norte-este), dejando libres el vano, la escalera y el paso de la puerta.
	for arco in [[PI * 0.62, PI * 1.28], [PI * 1.52, PI * 1.92]]:
		var a: float = arco[0]
		while a < float(arco[1]):
			var d := Vector3(sin(a), 0.0, -cos(a))
			var mueble := _caja(d * r + Vector3.UP * ANAQUEL_ALTO * 0.5, Vector3(0.78, ANAQUEL_ALTO, ANAQUEL_FONDO), MADERA)
			mueble.rotation.y = -a
			# Los estantes con libros de colores apagados.
			for e in range(3):
				var libros := _caja(d * (r - 0.02) + Vector3.UP * (0.35 + e * 0.42),
					Vector3(0.66, 0.26, ANAQUEL_FONDO * 0.7), Color("#6a4a3c").lerp(Color("#4c5a46"), fmod(a, 1.0)))
				libros.rotation.y = -a
			var cs_pos := d * r
			_solido_caja(Vector3(cs_pos.x, ANAQUEL_ALTO * 0.5, cs_pos.z), Vector3(0.85, ANAQUEL_ALTO, 0.85))
			a += 0.33
	# El archivo de mapas: un armario cerrado con su candado, al oeste.
	_caja(Vector3(-1.95 * s, 0.85, 0.0), Vector3(s * 0.5, 1.7, s * 0.9), MADERA.darkened(0.15))
	_caja(Vector3(-1.95 * s + s * 0.26, 0.9, 0.0), Vector3(0.05, 1.5, s * 0.8), MADERA_CLARA.darkened(0.2))
	_caja(Vector3(-1.95 * s + s * 0.3, 0.95, 0.0), Vector3(0.12, 0.18, 0.12), Color("#8a8370"))      # el candado
	_solido_caja(Vector3(-1.95 * s, 0.85, 0.0), Vector3(s * 0.6, 1.7, s * 0.95))
	_rotulo("Archivo de mapas · cerrado", Vector3(-1.95 * s, 2.0, 0.0))
	# La mesa de lectura del sur, con dos pergaminos abiertos.
	_caja(Vector3(-0.95 * s, 0.62, 1.55 * s), Vector3(s * 0.85, 0.08, s * 0.5), MADERA_CLARA)
	_solido_caja(Vector3(-0.95 * s, 0.4, 1.55 * s), Vector3(s * 0.9, 0.8, s * 0.55))
	_caja(Vector3(-1.1 * s, 0.68, 1.55 * s), Vector3(0.44, 0.02, 0.32), PERGAMINO)
	_caja(Vector3(-0.75 * s, 0.68, 1.5 * s), Vector3(0.38, 0.02, 0.28), PERGAMINO.darkened(0.08))
	_vela(Vector3(-0.95 * s, 0.66, 1.9 * s))


## ---- Planta 3 · celdas de aprendices ----
## Celdas pequeñas de piedra: cama baja, arcón y ventana estrecha. Una es la de Mid.

const CELDAS: Array = [
	{"x": -1.95, "z": -0.9, "mid": false},
	{"x": -1.95, "z": 0.9, "mid": true},
	{"x": 0.95, "z": -1.85, "mid": false},
]


func _planta_celdas() -> void:
	var s := Terreno3D.casilla
	for celda in CELDAS:
		var p := Vector3(float(celda["x"]) * s, 0.0, float(celda["z"]) * s)
		var mirando_x: bool = absf(float(celda["x"])) > absf(float(celda["z"]))
		# El tabique que cierra la celda, con el hueco de entrada hacia el centro de la sala.
		var grosor := Vector3(0.16, 1.5, s * 0.9) if mirando_x else Vector3(s * 0.9, 1.5, 0.16)
		var desvio := Vector3(sign(float(celda["x"])) * 0.52 * s, 0.0, 0.0) if mirando_x else Vector3(0.0, 0.0, sign(float(celda["z"])) * 0.52 * s)
		_caja(p - desvio * 0.0 + Vector3(0, 0.75, 0) + (Vector3(0, 0, s * 0.52) if mirando_x else Vector3(s * 0.52, 0, 0)), grosor, PIEDRA_CELDA.darkened(0.12))
		_solido_caja(p + Vector3(0, 0.75, 0) + (Vector3(0, 0, s * 0.52) if mirando_x else Vector3(s * 0.52, 0, 0)), grosor)
		# La cama baja contra el muro, con su manta.
		_caja(p + Vector3(0, 0.18, 0), Vector3(s * 0.45, 0.36, s * 0.75), MADERA)
		_caja(p + Vector3(0, 0.38, 0), Vector3(s * 0.42, 0.08, s * 0.72), PANO_ROJO.darkened(0.25) if not bool(celda["mid"]) else PANO_ROJO)
		_solido_caja(p + Vector3(0, 0.2, 0), Vector3(s * 0.5, 0.4, s * 0.8))
		# El arcón a los pies.
		var pie := p + (Vector3(0, 0, -s * 0.52) if mirando_x else Vector3(-s * 0.52, 0, 0))
		_caja(pie + Vector3(0, 0.2, 0), Vector3(0.62, 0.4, 0.42), MADERA.lightened(0.05))
		_solido_caja(pie + Vector3(0, 0.22, 0), Vector3(0.66, 0.44, 0.46))
		# La ventana estrecha de la celda.
		var hacia := Vector3(sign(float(celda["x"])), 0.0, 0.0) if mirando_x else Vector3(0.0, 0.0, sign(float(celda["z"])))
		_caja(p + hacia * s * 0.55 + Vector3.UP * 1.2, Vector3(0.28, 0.6, 0.28), Color("#cdd6cf"))
		if bool(celda["mid"]):
			_rotulo("Celda de Mid", p + Vector3(0, 1.75, 0))
			_vela(p + Vector3(0.0, 0.4, s * 0.3))


## ---- Planta 4 · despacho de Marimanta ----
## Mesa, sillón, su bastón y velas. Aquí es la AUDIENCIA y la entrega de encargos (decisión de Pablo del 14/11).
## Las tres casillas del norte son de Marimanta y sus dos cofres (PUNTOS): el mobiliario va al oeste y no las toca.

func _planta_despacho() -> void:
	var s := Terreno3D.casilla
	# La mesa de trabajo contra el muro del oeste, de norte a sur: ocupa (−2,−1) y (−2,0).
	_caja(Vector3(-1.9 * s, 0.74, -0.5 * s), Vector3(s * 0.5, 0.1, s * 1.05), MADERA_CLARA.darkened(0.1))
	_solido_caja(Vector3(-1.9 * s, 0.45, -0.5 * s), Vector3(s * 0.56, 0.9, s * 1.1))
	for a in [-0.42, 0.42]:
		_caja(Vector3(-1.9 * s, 0.36, -0.5 * s + a * s * 1.05), Vector3(s * 0.4, 0.72, 0.14), MADERA)
	_caja(Vector3(-1.9 * s, 0.81, -0.85 * s), Vector3(0.34, 0.04, 0.46), PERGAMINO)
	_caja(Vector3(-1.9 * s, 0.84, -0.2 * s), Vector3(0.24, 0.12, 0.3), Color("#4c5a46"))      # un libro cerrado
	_vela(Vector3(-1.9 * s, 0.79, -0.95 * s))
	_vela(Vector3(-1.9 * s, 0.79, 0.0))
	# El sillón de respaldo alto, al lado de la mesa y mirando a ella.
	_caja(Vector3(-0.95 * s, 0.3, -1.0 * s), Vector3(0.66, 0.12, 0.78), PANO_ROJO)
	_caja(Vector3(-0.72 * s, 0.72, -1.0 * s), Vector3(0.14, 0.96, 0.78), MADERA)
	_solido_caja(Vector3(-0.9 * s, 0.5, -1.0 * s), Vector3(0.6, 1.0, 0.84))
	# Su bastón apoyado en el muro del oeste (arte/modelos/baston_marimanta.glb cuando se enganche).
	var baston := _caja(Vector3(-2.3 * s, 0.85, -1.45 * s), Vector3(0.08, 1.7, 0.08), MADERA.darkened(0.1))
	baston.rotation.z = 0.12
	_caja(Vector3(-2.3 * s - 0.2, 1.72, -1.45 * s), Vector3(0.18, 0.18, 0.18), Color("#6f8a5c"))
	# La estantería del suroeste y un velador junto al hueco.
	_caja(Vector3(-1.95 * s, 0.8, 0.95 * s), Vector3(s * 0.45, 1.6, s * 0.75), MADERA)
	_solido_caja(Vector3(-1.95 * s, 0.8, 0.95 * s), Vector3(s * 0.5, 1.6, s * 0.8))
	for e in range(3):
		_caja(Vector3(-1.9 * s, 0.45 + e * 0.45, 0.95 * s), Vector3(s * 0.38, 0.22, s * 0.6), Color("#6a4a3c"))
	_caja(Vector3(-0.95 * s, 0.55, 1.35 * s), Vector3(0.52, 0.08, 0.52), MADERA_CLARA)
	_caja(Vector3(-0.95 * s, 0.28, 1.35 * s), Vector3(0.12, 0.56, 0.12), MADERA)
	_vela(Vector3(-0.95 * s, 0.59, 1.35 * s))
	_rotulo("Despacho de la Maestre", Vector3(0, 2.0, -2.7 * s))


## Una figura simple (un aprendiz): cuerpo, túnica y cabeza. Hasta que haya modelo con clips.
func _figura_simple(pos: Vector3, ropa: Color) -> void:
	_caja(pos + Vector3(0, 0.38, 0), Vector3(0.34, 0.76, 0.26), ropa)
	_caja(pos + Vector3(0, 0.84, 0), Vector3(0.24, 0.24, 0.24), Color("#c7a98b"))
	_solido_caja(pos + Vector3(0, 0.45, 0), Vector3(0.4, 0.9, 0.34))


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
