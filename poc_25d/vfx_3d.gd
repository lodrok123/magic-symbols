class_name Vfx3D
extends Node3D

## EFECTOS DE ELEMENTO en 3D con PIEZAS 3D de baja poligonización (fuego, agua, tierra, viento, rayo, hielo). Cada hechizo =
## carga en el lanzador (círculo rúnico plano) + proyectil con estela + impacto (estallido de partículas, destello de luz, marca
## en el suelo). Todo se borra solo al terminar.
##
## 6/10 (Pipeline, a petición de Pablo): se acabaron los sprites planos. Las partículas son mallas con volumen (Formas3D: facetas
## planas en tres tonos con contorno grueso, estilo Link's Awakening) dibujadas con GPUParticles3D; los proyectiles, cristales,
## remolinos y rayos son piezas 3D sueltas; la tierra es un bloque de verdad. Lo que se queda en el mundo (marcas, cristales)
## dura bastante y se va deshaciendo poco a poco: `MAX_RESTOS` limita cuántas piezas viven a la vez (se borra la más vieja).
##
##   var fx := Vfx3D.new()
##   add_child(fx)
##   fx.lanzar("fuego", Vector3(0, 0.6, 0), Vector3(4, 0.6, 0))
##   fx.lanzar_forma("columna", "hielo", pie_lanzador, pie_destino)   # 6 elementos x 4 formas
##
## `escala` agranda o encoge todos los efectos; `velocidad` cambia lo que tarda el proyectil.

signal impacto(elemento: String, punto: Vector3)

const SUELO_TIERRA: String = "res://poc_25d/suelo_meshy/dirt_arriba.png"
const ELEMENTOS: Array = ["fuego", "agua", "tierra", "viento", "rayo", "hielo"]
## Formas de un hechizo (la matriz receta -> forma de DISENO_FUTURO §3 reducida a lo que necesita el Test 3).
## proyectil = vuela hasta el punto · corro = anillo de manifestaciones alrededor del punto ·
## columna = una sola, alta y sólida, en el punto · muro = una fila que avanza desde el punto hacia donde se apunta.
const FORMAS: Array = ["proyectil", "corro", "columna", "muro"]
const COLOR: Dictionary = {
	"fuego": Color(1.0, 0.55, 0.25), "agua": Color(0.45, 0.75, 1.0), "tierra": Color(0.85, 0.66, 0.40),
	"viento": Color(0.75, 0.97, 0.85), "rayo": Color(1.0, 0.93, 0.40), "hielo": Color(0.72, 0.92, 1.0),
}
## Nombre histórico de cada pieza (los de los antiguos sprites de vfx/) -> forma 3D de Formas3D.
const FORMA_DE: Dictionary = {
	"llama": "llama", "llama_pequena": "llama", "brasa": "ascua", "esporas": "ascua", "humo": "nube", "polvo": "nube",
	"burbuja": "burbuja", "gota": "gota", "chispa_electrica": "chispa", "destello": "estrella", "copo": "copo",
	"hoja": "hoja", "petalo": "hoja", "piedrecitas": "piedra", "terrones": "piedra", "salpicadura": "corona",
	"pua_tierra": "pua", "cristal_hielo": "cristal", "rayo": "rayo", "remolino_viento": "remolino",
	"circulo_runico": "runa", "ondas": "anillo", "anillo_polvo": "anillo", "grieta": "grieta", "quemado": "disco",
}
## Color de cada pieza cuando quien la pide no le da uno (blanco). Lo que sí llega con color (el del elemento) manda.
const COLOR_DE: Dictionary = {
	"llama": Color(1.0, 1.0, 1.0), "ascua": Color(1.0, 0.55, 0.2), "nube": Color(0.88, 0.87, 0.92),
	"burbuja": Color(0.72, 0.92, 1.0), "gota": Color(0.45, 0.75, 1.0), "chispa": Color(1.0, 0.93, 0.4),
	"estrella": Color(1.0, 0.95, 0.55), "copo": Color(0.72, 0.92, 1.0), "hoja": Color(0.62, 0.88, 0.5),
	"piedra": Color(0.72, 0.58, 0.42), "cristal": Color(0.72, 0.92, 1.0), "pua": Color(0.78, 0.6, 0.4),
	"corona": Color(0.5, 0.78, 1.0), "rayo": Color(1.0, 0.93, 0.4), "remolino": Color(0.78, 0.97, 0.85),
	"anillo": Color(0.85, 0.74, 0.56), "runa": Color(0.7, 0.9, 1.0), "grieta": Color(0.3, 0.22, 0.26),
	"disco": Color(0.27, 0.19, 0.16),
}
## Las llamas pasan por tres tonos planos a lo largo de su vida (amarillo, naranja, rojo), sin degradado: como en el dibujo animado.
const TONOS_LLAMA: Array = [Color(1.0, 0.93, 0.5), Color(1.0, 0.62, 0.22), Color(0.95, 0.4, 0.16)]
## Presupuesto de las llamas de la hierba (una GPU integrada no aguanta un emisor completo por casilla cuando arde medio mapa):
## las primeras MAX_LLAMAS_COMPLETAS llevan llamas, brasas y humo; las siguientes, solo una llama pequeña; y luz, solo MAX_LUCES_LLAMA.
const MAX_LLAMAS_COMPLETAS: int = 10
const MAX_LUCES_LLAMA: int = 3
const MAX_RESTOS: int = 40               ## piezas que se quedan en el mundo (marcas, cristales...) a la vez; al pasarse se borra la más vieja

@export var escala: float = 1.0
@export var velocidad: float = 7.0       ## unidades por segundo del proyectil
@export var con_luces: bool = true

var _llamas_activas: int = 0
var _luces_activas: int = 0
var _restos: Array = []                ## lo que se queda un rato en el mundo, de más viejo a más nuevo (MAX_RESTOS)
var _mat_tierra: StandardMaterial3D = null


## Construye todas las mallas y materiales y lanza cada elemento una vez de `origen` a `destino`: Godot compila así los
## shaders de materiales y partículas de golpe (sin esto, el primer hechizo de cada uno da un tirón).
## `con_formas` lanza además una columna de cada elemento (las piezas altas y los chorros de partículas).
func precalentar(origen: Vector3, destino: Vector3, con_formas: bool = false) -> void:
	for n in Formas3D.NOMBRES:
		Formas3D.malla(String(n))
	_material_tierra()
	for e in ELEMENTOS:
		lanzar(String(e), origen, destino)
		if con_formas:
			lanzar_forma("columna", String(e), origen, destino, {"dura": 0.4})


## Lanza un hechizo de `elemento` desde los pies del lanzador hasta los pies del objetivo.
func lanzar(elemento: String, pie_origen: Vector3, pie_destino: Vector3) -> void:
	var alto := Vector3(0.0, 0.6 * escala, 0.0)
	_carga(elemento, pie_origen)
	match elemento:
		"tierra":
			# La tierra no vuela: brota del suelo bajo el objetivo tras la carga.
			_despues(0.25, _impacto_tierra.bind(pie_destino))
		"rayo":
			_despues(0.2, _impacto_rayo.bind(pie_destino))
		_:
			_proyectil(elemento, pie_origen + alto, pie_destino + alto, pie_destino.y)


## Llamas que siguen ardiendo hasta que se llama a `apagar(nodo)`: la hierba que arde en la maqueta.
## `esc` 0,5 = llamita (prendiendo), 1 = ardiendo; `radio` = media anchura de la zona que arde.
func llamas(suelo: Vector3, esc: float, radio: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = suelo
	add_child(raiz)
	var completa: bool = _llamas_activas < MAX_LLAMAS_COMPLETAS
	_llamas_activas += 1
	raiz.tree_exited.connect(func() -> void: _llamas_activas -= 1)
	# Lenguas lisas con el shader del fuego (ondulan solas, sin partículas): 1 si el presupuesto está agotado, 2-3 si no.
	var n: int = 1 if not completa else (3 if esc > 0.7 else 2)
	_lenguas(raiz, n, radio, 0.5 * esc, 0.72 * esc, 0.22, int(suelo.x * 7.0 + suelo.z * 13.0))
	if esc > 0.7 and completa:
		var b := _particulas("brasa", 4, 1.4, 0.8, 0.1, true, COLOR["fuego"], Vector3(0.0, -0.3, 0.0))
		_caja_emision(b, radio, Vector3(0.0, 0.3, 0.0))
		raiz.add_child(b)
		b.emitting = true
		if con_luces and _luces_activas < MAX_LUCES_LLAMA:
			_luces_activas += 1
			var l := OmniLight3D.new()
			l.light_color = COLOR["fuego"]
			l.light_energy = 0.7
			l.omni_range = 2.6 * escala
			l.position = Vector3(0.0, 0.8, 0.0)
			raiz.add_child(l)
			l.tree_exited.connect(func() -> void: _luces_activas -= 1)
	return raiz


## `n` lenguas de fuego (mallas lisas con el shader de Formas3D) repartidas a lo ancho de [-ancho, ancho] con alturas entre
## esc_min y esc_max (1 = la malla entera, 1,6 u). `lean` = cuánto se inclinan hacia +X. Las pares son más altas que las impares:
## así el muro de lenguas del Link's Awakening no queda a ras. Cuelgan de `raiz`.
func _lenguas(raiz: Node3D, n: int, ancho: float, esc_min: float, esc_max: float, lean: float, semilla: int) -> void:
	for i in range(n):
		var h1: float = float(((i + 1) * 7919 + semilla * 104729) % 1000) / 999.0
		var h2: float = float(((i + 1) * 15485 + semilla * 32749) % 1000) / 999.0
		var m: MeshInstance3D = Formas3D.instancia("llama", Color.WHITE)
		var alta: float = esc_max if i % 2 == 0 else lerpf(esc_min, esc_max, 0.35 + 0.4 * h1)
		var sy: float = alta
		var sx: float = 0.95 * alta + 0.12
		var fx: float = 0.0 if n == 1 else (float(i) + 0.5) / float(n) * 2.0 - 1.0
		m.position = Vector3(fx * ancho, 0.0, (h2 - 0.5) * ancho * 0.5)
		m.scale = Vector3(sx, sy, sx)
		m.rotation.y = h2 * TAU
		var mat: ShaderMaterial = (m.get_surface_override_material(0) as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter("lean", lean * (0.7 + 0.6 * h1))
		m.set_surface_override_material(0, mat)
		raiz.add_child(m)


## Esporas flotando (las plantas reactivas): motas 3D verdosas.
func esporas(p: Vector3) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = p
	add_child(raiz)
	var e := _particulas("ascua", 4, 3.5, 0.15, 0.16, false, Color(0.82, 1.0, 0.68), Vector3.ZERO)
	_caja_emision(e, 0.4, Vector3.ZERO)
	(e.process_material as ParticleProcessMaterial).spread = 40.0
	raiz.add_child(e)
	e.emitting = true
	return raiz


## Destellos de un portal: estrellitas 3D que saltan en todas direcciones.
func destellos(p: Vector3, color: Color) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = p
	add_child(raiz)
	var e := _particulas("estrella", 10, 1.6, 0.2, 0.2, false, color, Vector3.ZERO)
	_caja_emision(e, 0.6, Vector3.ZERO)
	(e.process_material as ParticleProcessMaterial).spread = 180.0
	raiz.add_child(e)
	e.emitting = true
	return raiz


## Fuego que no se apaga (antorchas, fuentes, barreras): llamas en 3D, brasas y humo. `barrera` = muro de llamas que
## ocupa la casilla; `esc` agranda o encoge. `p` = base del fuego. Devuelve la raíz (hija de este nodo) por si hay que quitarla.
func fuego_fijo(p: Vector3, barrera: bool, esc: float = 1.0) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "fuego_fijo"
	raiz.position = p
	add_child(raiz)
	var ancho: float = 0.97 if barrera else 0.12 * esc
	if barrera:
		# Muro de lenguas altas y estrechas que ondulan, como el de Link's Awakening.
		_lenguas(raiz, 6, ancho, 1.05, 1.65, 0.07, int(p.x * 3.0 + p.z * 5.0))
	else:
		# Una lengua principal que se inclina hacia un lado (la «lengua prominente») y dos pequeñas a su costado.
		_lenguas(raiz, 1, 0.0, 0.7 * esc, 0.78 * esc, 0.42, int(p.x * 3.0 + p.z * 5.0))
		var chica: Node3D = Node3D.new()
		chica.position = Vector3(0.1 * esc, 0.0, 0.06 * esc)
		raiz.add_child(chica)
		_lenguas(chica, 2, 0.2 * esc, 0.34 * esc, 0.46 * esc, 0.3, int(p.x * 5.0 + p.z * 3.0) + 1)
	var b := _particulas("brasa", 10 if barrera else 5, 1.4, 1.3, 0.12 * esc, true, COLOR["fuego"], Vector3(0.0, -0.3, 0.0))
	_caja_emision(b, ancho, Vector3(0.0, 0.0, 0.0))
	(b.process_material as ParticleProcessMaterial).spread = 25.0
	raiz.add_child(b)
	b.emitting = true
	return raiz


func _caja_emision(gp: GPUParticles3D, radio: float, desplazado: Vector3) -> void:
	var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radio, 0.04, radio)
	pm.direction = Vector3.UP
	pm.spread = 14.0
	gp.position = desplazado


## Deja de emitir y borra las llamas cuando se apagan las partículas.
func apagar(n: Node3D) -> void:
	if n == null or not is_instance_valid(n):
		return
	_soltar(n)


## Lanza un hechizo de `elemento` con la `forma` dada (FORMAS). `pie_origen` = pies del lanzador; `pie_destino` = el
## punto señalado (pies). Opciones: "radio" (corro: radio del anillo; muro: semiancho; 1,2 por defecto) y "dura"
## (segundos que se ve cada manifestación; por defecto 2,0 el corro, 3,0 la columna y 0,9 el muro). Una forma
## desconocida cae al proyectil, que es la forma por defecto de cada elemento. Solo es la parte visual: las
## manifestaciones con colisión son cosa del Lanzador.
func lanzar_forma(forma: String, elemento: String, pie_origen: Vector3, pie_destino: Vector3,
		opciones: Dictionary = {}) -> void:
	if not COLOR.has(elemento):
		push_warning("Vfx3D: elemento desconocido '%s'" % elemento)
		return
	var radio: float = float(opciones.get("radio", 1.2))
	match forma:
		"corro":
			_corro(elemento, pie_origen, pie_destino, radio, float(opciones.get("dura", 2.0)))
		"columna":
			_columna(elemento, pie_origen, pie_destino, float(opciones.get("dura", 3.0)))
		"muro":
			_muro(elemento, pie_origen, pie_destino, radio, float(opciones.get("dura", 0.9)))
		_:
			if forma != "proyectil" and forma != "":
				push_warning("Vfx3D: forma desconocida '%s'; se usa proyectil" % forma)
			lanzar(elemento, pie_origen, pie_destino)


## --- Formas ---

## Anillo de ocho manifestaciones bajas alrededor del punto, con un círculo rúnico en el suelo.
func _corro(elemento: String, pie_origen: Vector3, centro: Vector3, radio: float, dura: float) -> void:
	_carga(elemento, pie_origen)
	var c: Color = COLOR[elemento]
	var marca := Color(c.r, c.g, c.b, 0.55)
	_despues(0.25, _marca.bind("circulo_runico", centro, radio * 2.5 / escala, marca, dura))
	for i in range(8):
		var ang: float = float(i) / 8.0 * TAU
		var p: Vector3 = centro + Vector3(cos(ang), 0.0, sin(ang)) * radio
		_brote(elemento, p, 0.6, 0.95, 0.25 + float(i) * 0.04, dura, true)
	_despues(0.25, _luz.bind(centro + Vector3(0.0, 0.6, 0.0), c, 1.4, 3.0 + radio, 0.5))


## Una sola manifestación alta (dos niveles de bloque) en el punto.
func _columna(elemento: String, pie_origen: Vector3, destino: Vector3, dura: float) -> void:
	_carga(elemento, pie_origen)
	var c: Color = COLOR[elemento]
	_despues(0.25, _marca.bind("circulo_runico", destino, 1.7 / escala, Color(c.r, c.g, c.b, 0.6), dura))
	_brote(elemento, destino, 1.1, 2.1, 0.25, dura, false)
	_despues(0.25, _luz.bind(destino + Vector3(0.0, 1.0, 0.0), c, 1.8, 4.0, minf(dura, 1.2)))
	if elemento == "tierra":
		_despues(0.3, _temblor.bind(0.08))


## Una fila de manifestaciones que avanza desde el punto hacia donde se apunta (origen -> destino): cuatro filas
## separadas 0,75 u y cinco manifestaciones por fila, cada una un momento después de la anterior.
func _muro(elemento: String, pie_origen: Vector3, inicio: Vector3, semiancho: float, dura: float) -> void:
	_carga(elemento, pie_origen)
	var c: Color = COLOR[elemento]
	var dir := Vector3(inicio.x - pie_origen.x, 0.0, inicio.z - pie_origen.z)
	if dir.length() < 0.01:
		dir = Vector3(0.0, 0.0, 1.0)
	dir = dir.normalized()
	var lado := Vector3(-dir.z, 0.0, dir.x)
	for fila in range(4):
		var t0: float = 0.25 + float(fila) * 0.22
		var centro: Vector3 = inicio + dir * (0.75 * escala * float(fila))
		for j in range(5):
			var f: float = float(j) / 4.0 * 2.0 - 1.0
			_brote(elemento, centro + lado * (semiancho * f), 0.62, 1.15, t0, dura, true)
		_despues(t0, _luz.bind(centro + Vector3(0.0, 0.6, 0.0), c, 1.0, 2.6, 0.45))


## Una manifestación del elemento que brota en `suelo` tras `retraso` s y dura `dura` s: `ancho` x `alto` en
## unidades (se multiplican por `escala`). `ligero` = menos partículas (corros y muros juntan muchas).
## Cada elemento la dibuja a su manera con las piezas de vfx/.
func _brote(elemento: String, suelo: Vector3, ancho: float, alto: float, retraso: float, dura: float,
		ligero: bool) -> void:
	var c: Color = COLOR[elemento]
	var k: float = 0.55 if ligero else 1.0
	var w: float = ancho * escala
	var h: float = alto * escala
	match elemento:
		"fuego":
			# Llamas 3D que ascienden (las mismas que la hierba ardiendo), brasas y humo.
			_chorro(suelo, "llama", int((5.0 + 7.0 * alto) * k), 0.8, 0.7 + alto * 1.5, 0.28 + 0.16 * alto,
				false, Color.WHITE, Vector3(0.0, 0.8 + alto * 1.2, 0.0), w * 0.5, retraso, dura)
			_chorro(suelo, "brasa", int((4.0 + 3.0 * alto) * k), 1.3, 0.8 + alto * 0.5, 0.12, true, c,
				Vector3(0.0, -0.2, 0.0), w * 0.5, retraso, dura)
			if not ligero:
				_chorro(suelo + Vector3(0.0, h * 0.7, 0.0), "humo", 4, 2.6, 0.4, 0.7, false, Color.WHITE,
					Vector3(0.0, 0.4, 0.0), w * 0.4, retraso, dura)
		"agua":
			# Chorro: salpicadura alta que se encoge y gotas que suben y caen.
			_tallo("salpicadura", suelo, w * 1.1, h * 0.85, Color(1, 1, 1, 0.92), false, retraso, dura)
			_chorro(suelo, "gota", int((8.0 + 6.0 * alto) * k), 1.1, 2.0 + alto * 1.6, 0.18, false, Color.WHITE,
				Vector3(0.0, -7.0, 0.0), w * 0.35, retraso, dura * 0.8)
			_despues(retraso, _onda.bind(suelo, "ondas", 0.3 * ancho, 1.5 * ancho, 0.8, Color(1, 1, 1, 0.8)))
		"tierra":
			# Un BLOQUE de tierra que sube del suelo (con polvo y piedrecitas): la tierra no es una pieza especial, es un bloque.
			_bloque_tierra(suelo, w * 1.05, h, retraso, dura)
			_despues(retraso, _estallido.bind(suelo + Vector3(0, 0.2, 0), "piedrecitas", int(10.0 * k), 0.9, 2.6,
				0.2, false, Color.WHITE, Vector3(0, -7.0, 0)))
			_despues(retraso, _estallido.bind(suelo + Vector3(0, 0.15, 0), "polvo", int(6.0 * k), 1.2, 1.0, 0.7,
				false, Color(1, 1, 1, 0.65), Vector3(0, 0.3, 0)))
		"viento":
			# Torbellino: discos de remolino apilados que giran y hojas que suben en espiral.
			var pisos: int = 2 if ligero else 4
			for i in range(pisos):
				_remolino(suelo + Vector3(0.0, h * (0.15 + 0.7 * float(i) / float(maxi(pisos - 1, 1))), 0.0),
					w * (0.8 + 0.25 * float(i)), retraso + 0.03 * float(i), dura, 1.0 if i % 2 == 0 else -1.0)
			_chorro(suelo, "hoja", int((8.0 + 4.0 * alto) * k), 1.4, 1.2 + alto * 0.5, 0.2, false, Color.WHITE,
				Vector3(0.0, 0.2, 0.0), w * 0.5, retraso, dura * 0.8)
		"rayo":
			# Haz que baja del cielo y parpadea mientras dura; chispas en la base.
			var r := _tallo("rayo", suelo, w * 0.8, h * (1.0 if ligero else 1.5), Color(1, 1, 1, 0.9), false, retraso, dura)
			_parpadear(r, retraso, dura)
			_chorro(suelo, "chispa_electrica", int(8.0 * k), 0.5, 2.0, 0.4, true, Color.WHITE, Vector3.ZERO,
				w * 0.4, retraso, dura)
		"hielo":
			# Cristal que crece del suelo con copos que flotan alrededor.
			_tallo("cristal_hielo", suelo, w * 1.1, h, Color.WHITE, false, retraso, dura)
			_chorro(suelo, "copo", int((6.0 + 4.0 * alto) * k), 1.3, 0.8 + alto * 0.4, 0.17, true, c,
				Vector3(0.0, -0.4, 0.0), w * 0.6, retraso, dura)


## Una pieza 3D de pie (`ancho` x `alto`, la base en `suelo`) que crece desde el suelo tras `retraso`, se queda `dura` s y se
## deshace. `nombre` es el de la pieza (ver FORMA_DE); sin color propio (blanco) usa el suyo de COLOR_DE.
func _tallo(nombre: String, suelo: Vector3, ancho: float, alto: float, color: Color, _aditivo: bool,
		retraso: float, dura: float) -> Node3D:
	var m: MeshInstance3D = _pieza_de_pie(nombre, suelo, 1.0, color)
	var lleno := Vector3(ancho, alto, ancho)
	m.scale = Vector3(lleno.x, lleno.y * 0.05, lleno.z)
	m.visible = false
	var tw := m.create_tween()
	tw.tween_interval(retraso)
	tw.tween_callback(m.set.bind("visible", true))
	tw.tween_property(m, "scale", lleno, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dura, 0.0))
	tw.tween_property(m, "scale", Vector3(lleno.x * 0.2, 0.0, lleno.z * 0.2), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(m.queue_free)
	return m


## Un BLOQUE de tierra de verdad (caja con la textura de tierra del suelo y contorno) que sube del suelo tras `retraso`, se
## queda `dura` s y se hunde. Es solo la imagen: el que bloquea y pesa es el del Lanzador.
func _bloque_tierra(suelo: Vector3, ancho: float, alto: float, retraso: float, dura: float) -> Node3D:
	var pivote := Node3D.new()
	pivote.position = suelo
	add_child(pivote)
	var caja := BoxMesh.new()
	caja.material = _material_tierra()
	var cuerpo := MeshInstance3D.new()
	cuerpo.mesh = caja
	cuerpo.position = Vector3(0.0, 0.5, 0.0)
	cuerpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivote.add_child(cuerpo)
	var borde := MeshInstance3D.new()
	var caja_borde := BoxMesh.new()
	caja_borde.size = Vector3.ONE * 1.08
	caja_borde.material = _material_contorno_bloque()
	borde.mesh = caja_borde
	borde.position = Vector3(0.0, 0.5, 0.0)
	borde.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivote.add_child(borde)
	var lleno := Vector3(ancho, alto, ancho)
	pivote.scale = Vector3(lleno.x, 0.01, lleno.z)
	pivote.visible = false
	var tw := pivote.create_tween()
	tw.tween_interval(retraso)
	tw.tween_callback(pivote.set.bind("visible", true))
	tw.tween_property(pivote, "scale", lleno, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dura, 0.0))
	tw.tween_property(pivote, "scale", Vector3(lleno.x, 0.01, lleno.z), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(pivote.queue_free)
	return pivote


## Hace parpadear una pieza (el rayo) mientras dura.
func _parpadear(m: Node3D, retraso: float, dura: float) -> void:
	var tw := m.create_tween()
	tw.tween_interval(retraso + 0.16)
	for i in range(maxi(1, int(dura / 0.16))):
		tw.tween_callback(m.set.bind("visible", true))
		tw.tween_interval(0.05)
		tw.tween_callback(m.set.bind("visible", false))
		tw.tween_interval(0.09)
	tw.tween_callback(m.set.bind("visible", true))


## Un torbellino (anillos que se abren hacia arriba) que gira en el sitio y se deshace.
func _remolino(p: Vector3, tam: float, retraso: float, dura: float, sentido: float) -> void:
	var r: MeshInstance3D = _pieza_de_pie("remolino_viento", p - Vector3(0.0, tam * 0.5, 0.0), tam, Color.WHITE)
	var lleno: Vector3 = r.scale
	r.scale = lleno * 0.2
	r.visible = false
	var tw := r.create_tween()
	tw.tween_interval(retraso)
	tw.tween_callback(r.set.bind("visible", true))
	tw.set_parallel(true)
	tw.tween_property(r, "scale", lleno, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "rotation:y", sentido * TAU * maxf(dura, 0.5) * 1.2, dura + 0.3).as_relative()
	tw.chain().tween_property(r, "scale", Vector3(lleno.x * 0.3, 0.0, lleno.z * 0.3), 0.3).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(r.queue_free)


## Emisor que echa partículas hacia arriba desde `suelo` durante `dura` s, tras `retraso` s.
func _chorro(suelo: Vector3, nombre: String, n: int, vida: float, vel: float, tam: float, aditivo: bool,
		color: Color, gravedad: Vector3, radio: float, retraso: float, dura: float, frames: int = 1) -> void:
	var gp := _particulas(nombre, maxi(n, 1), vida, vel, tam, aditivo, color, gravedad, frames)
	_caja_emision(gp, radio, Vector3(0.0, 0.05, 0.0))
	var raiz := Node3D.new()
	raiz.position = suelo
	add_child(raiz)
	raiz.add_child(gp)
	gp.emitting = false
	_despues(retraso, gp.set.bind("emitting", true))
	_despues(retraso + dura, _soltar.bind(raiz))


## Partículas sutiles para la mano que lanza (Pj3D.lanzar): un puñado de motas del elemento que flotan alrededor.
## `esc` = tamaño relativo (1 = personaje de una unidad de alto). Devuelve el emisor, ya emitiendo; lo cuelga quien llama.
func chispas_mano(elemento: String, esc: float = 1.0) -> GPUParticles3D:
	var c: Color = COLOR.get(elemento, Color.WHITE)
	var antes: float = escala
	escala = esc
	var gp: GPUParticles3D
	match elemento:
		"fuego":
			gp = _particulas("brasa", 6, 0.7, 0.25, 0.06, true, c, Vector3(0.0, 0.5, 0.0))
		"agua":
			gp = _particulas("gota", 6, 0.8, 0.2, 0.06, false, Color.WHITE, Vector3(0.0, -0.5, 0.0))
		"tierra":
			gp = _particulas("piedrecitas", 5, 0.8, 0.2, 0.06, false, Color.WHITE, Vector3(0.0, -0.6, 0.0))
		"viento":
			gp = _particulas("hoja", 5, 1.0, 0.3, 0.08, false, Color.WHITE, Vector3(0.0, 0.1, 0.0))
		"rayo":
			gp = _particulas("chispa_electrica", 5, 0.4, 0.3, 0.12, true, Color.WHITE, Vector3.ZERO)
		_:
			gp = _particulas("copo", 6, 1.0, 0.2, 0.07, true, c, Vector3(0.0, -0.2, 0.0))
	escala = antes
	var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	pm.spread = 180.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06 * esc
	gp.local_coords = false
	gp.emitting = true
	return gp


## Nube gris de ceniza y polvo (un objeto que se consume o una fuente que se apaga).
func ceniza(p: Vector3) -> void:
	_estallido(p + Vector3(0.0, 0.3, 0.0), "humo", 6, 1.6, 0.6, 0.6, false, Color(0.55, 0.53, 0.58),
		Vector3(0.0, 0.5, 0.0))
	_estallido(p + Vector3(0.0, 0.2, 0.0), "polvo", 6, 1.2, 1.0, 0.45, false, Color(0.62, 0.58, 0.55),
		Vector3(0.0, 0.2, 0.0))


## Destello breve del color de un elemento (un tótem que se activa, una llama que prende, el puente que se tiende).
func chispazo(p: Vector3, elemento: String) -> void:
	var c: Color = COLOR.get(elemento, Color.WHITE)
	_estallido(p, "destello", 8, 0.6, 2.0, 0.3, true, c, Vector3.ZERO)
	_luz(p, c, 1.6, 3.0, 0.4)


## Bocanada de vapor (el fuego sobre un charco, el agua sobre brasas): 2,5 s.
func vapor(p: Vector3) -> void:
	_estallido(p + Vector3(0.0, 0.3, 0.0), "humo", 9, 2.5, 0.8, 0.8, false, Color(0.95, 0.95, 1.0), Vector3(0, 0.7, 0))


## --- Fases ---

## Círculo rúnico (plano, en 3D) del color del elemento bajo los pies del lanzador.
func _carga(elemento: String, pie: Vector3) -> void:
	var c: Color = COLOR[elemento]
	var d: MeshInstance3D = _plano("circulo_runico", pie + Vector3(0.0, 0.03, 0.0), 1.3 * escala, false, c)
	var lleno: Vector3 = d.scale
	var tw := d.create_tween()
	tw.set_parallel(true)
	d.scale = lleno * 0.3
	tw.tween_property(d, "scale", lleno, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "rotation:y", PI * 0.6, 0.7)
	tw.chain().tween_property(d, "scale", lleno * 0.05, 0.3).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(d.queue_free)
	_luz(pie + Vector3(0.0, 0.5, 0.0), c, 1.2, 2.5, 0.6)


func _proyectil(elemento: String, origen: Vector3, destino: Vector3, y_suelo: float) -> void:
	var cabeza := Node3D.new()
	add_child(cabeza)
	cabeza.position = origen
	var c: Color = COLOR[elemento]
	match elemento:
		"fuego":
			var llama: MeshInstance3D = _pieza("llama", cabeza, 0.55 * escala, Color.WHITE)
			llama.position.y = -0.3 * 0.55 * escala
			_girar(llama, 0.35)
			_estela(cabeza, "brasa", 30, 0.5, 0.14, true, c)
			_estela(cabeza, "humo", 10, 0.7, 0.3, false, Color.WHITE)
		"agua":
			var gota: MeshInstance3D = _pieza("gota", cabeza, 0.42 * escala, Color.WHITE)
			_girar(gota, 0.6)
			_estela(cabeza, "gota", 26, 0.35, 0.14, false, Color.WHITE)
			_estela(cabeza, "burbuja", 8, 0.6, 0.12, false, Color.WHITE)
		"viento":
			var r: MeshInstance3D = _pieza("remolino_viento", cabeza, 0.7 * escala, Color.WHITE)
			r.position.y = -0.35 * escala
			_girar(r, 0.3)
			_estela(cabeza, "hoja", 14, 0.6, 0.16, false, Color.WHITE)
		"hielo":
			var cr: MeshInstance3D = _pieza("cristal_hielo", cabeza, 0.55 * escala, Color.WHITE)
			cr.position.y = -0.25 * escala
			_girar(cr, 0.8)
			_estela(cabeza, "copo", 24, 0.5, 0.12, true, c)
	if con_luces:
		var l := OmniLight3D.new()
		l.light_color = c
		l.light_energy = 1.0
		l.omni_range = 2.5 * escala
		cabeza.add_child(l)
	var t: float = maxf(0.15, origen.distance_to(destino) / maxf(velocidad, 0.1))
	var tw2 := cabeza.create_tween()
	tw2.tween_method(_mover_proyectil.bind(cabeza, origen, destino), 0.0, 1.0, t)
	tw2.tween_callback(_llegar.bind(elemento, cabeza, y_suelo))


## Arco suave: sube un poco a mitad de camino.
func _mover_proyectil(f: float, cabeza: Node3D, origen: Vector3, destino: Vector3) -> void:
	cabeza.position = origen.lerp(destino, f) + Vector3(0.0, sin(f * PI) * 0.35 * escala, 0.0)


func _llegar(elemento: String, cabeza: Node3D, y_suelo: float) -> void:
	var p: Vector3 = cabeza.position
	match elemento:
		"fuego":
			_impacto_fuego(p, y_suelo)
		"agua":
			_impacto_agua(p, y_suelo)
		"viento":
			_impacto_viento(p, y_suelo)
		"hielo":
			_impacto_hielo(p, y_suelo)
	_soltar(cabeza)


## --- Impactos ---

func _impacto_fuego(p: Vector3, y_suelo: float) -> void:
	var c: Color = COLOR["fuego"]
	_estallido(p, "llama", 14, 0.7, 2.2, 0.55, false, Color.WHITE, Vector3(0, 1.2, 0))
	_estallido(p, "brasa", 24, 1.2, 3.5, 0.13, true, c, Vector3(0, -2.0, 0))
	_estallido(p + Vector3(0, 0.3, 0), "humo", 8, 1.8, 0.8, 0.7, false, Color.WHITE, Vector3(0, 0.8, 0))
	_marca("quemado", Vector3(p.x, y_suelo, p.z), 0.9, Color(0.33, 0.24, 0.2), 10.0)      # el chamusco se queda un buen rato
	_luz(p, c, 2.0, 4.0, 0.6)
	impacto.emit("fuego", p)


func _impacto_agua(p: Vector3, y_suelo: float) -> void:
	_estallido(p, "gota", 22, 0.8, 3.2, 0.17, false, Color.WHITE, Vector3(0, -6.0, 0))
	_estallido(p, "burbuja", 8, 1.4, 0.9, 0.18, false, Color.WHITE, Vector3(0, 0.6, 0))
	var s: MeshInstance3D = _pieza_de_pie("salpicadura", Vector3(p.x, y_suelo, p.z), 1.0 * escala, Color.WHITE)
	_crecer_y_borrar(s, 0.2, 0.5)
	_onda(Vector3(p.x, y_suelo, p.z), "ondas", 0.4, 2.0, 0.9, Color(0.8, 0.93, 1.0))
	_luz(p, COLOR["agua"], 1.4, 3.0, 0.4)
	impacto.emit("agua", p)


## La tierra: polvo, trozos de roca que saltan y una grieta. El bloque que se queda lo pone el Lanzador (`construir_tierra`).
func _impacto_tierra(suelo: Vector3) -> void:
	var c: Color = COLOR["tierra"]
	_marca("grieta", suelo, 1.6, Color(0.3, 0.2, 0.15), 10.0)
	_estallido(suelo + Vector3(0, 0.2, 0), "piedrecitas", 14, 1.0, 3.0, 0.2, false, Color.WHITE, Vector3(0, -7.0, 0), 1, true)
	_estallido(suelo + Vector3(0, 0.2, 0), "polvo", 9, 1.4, 1.2, 0.65, false, Color(0.82, 0.68, 0.5), Vector3(0, 0.3, 0))
	_onda(suelo, "anillo_polvo", 0.5, 2.6, 0.8, Color(0.85, 0.72, 0.55))
	_temblor(0.12)
	_luz(suelo + Vector3(0, 0.4, 0), c, 0.8, 3.0, 0.3)
	impacto.emit("tierra", suelo)


func _impacto_viento(p: Vector3, y_suelo: float) -> void:
	var r: MeshInstance3D = _pieza_de_pie("remolino_viento", p - Vector3(0.0, 0.7 * escala, 0.0), 1.4 * escala, Color.WHITE)
	var lleno: Vector3 = r.scale
	r.scale = lleno * 0.4
	var tw := r.create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "rotation:y", TAU * 1.5, 0.8).as_relative()
	tw.tween_property(r, "scale", lleno * 1.5, 0.8)
	tw.chain().tween_property(r, "scale", Vector3(lleno.x * 0.3, 0.0, lleno.z * 0.3), 0.2).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(r.queue_free)
	_estallido(p, "hoja", 16, 1.4, 2.5, 0.2, false, Color.WHITE, Vector3(0, -0.5, 0), 1, true)
	_onda(Vector3(p.x, y_suelo, p.z), "anillo_polvo", 0.4, 2.2, 0.6, Color(0.8, 0.95, 0.88))
	impacto.emit("viento", p)


func _impacto_rayo(suelo: Vector3) -> void:
	var c: Color = COLOR["rayo"]
	# El rayo baja del cielo: una pieza alta en zigzag que parpadea y se apaga.
	var alto: float = 4.0 * escala
	var rayo: MeshInstance3D = _pieza_de_pie("rayo", suelo, 1.0, Color.WHITE)
	rayo.scale = Vector3(1.4, alto, 1.4)
	var tw := rayo.create_tween()
	for i in range(3):
		tw.tween_callback(rayo.set.bind("visible", true))
		tw.tween_interval(0.05)
		tw.tween_callback(rayo.set.bind("visible", false))
		tw.tween_interval(0.04)
	tw.tween_callback(rayo.set.bind("visible", true))
	tw.tween_interval(0.12)
	tw.tween_callback(rayo.queue_free)
	_estallido(suelo + Vector3(0, 0.3, 0), "chispa_electrica", 10, 0.5, 2.5, 0.35, true, Color.WHITE, Vector3.ZERO, 1, true)
	var d: MeshInstance3D = _pieza("destello", self, 1.6 * escala, Color(1.0, 1.0, 0.7))
	d.position = suelo + Vector3(0, 0.5, 0)
	_crecer_y_borrar(d, 0.05, 0.3)
	_marca("grieta", suelo, 0.9, Color(0.22, 0.2, 0.28), 8.0)
	_luz(suelo + Vector3(0, 1.0, 0), c, 3.5, 5.0, 0.35)
	_temblor(0.08)
	impacto.emit("rayo", suelo)


func _impacto_hielo(p: Vector3, y_suelo: float) -> void:
	var suelo := Vector3(p.x, y_suelo, p.z)
	for i in range(6):
		var ang: float = float(i) / 6.0 * TAU
		var pos: Vector3 = suelo + Vector3(cos(ang), 0.0, sin(ang)) * 0.4 * escala
		var alto: float = (0.5 + float(i % 3) * 0.12) * escala
		var cr: MeshInstance3D = _pieza_de_pie("cristal_hielo", pos, alto, Color.WHITE)
		cr.rotation.y = float(i) * 1.1
		var lleno: Vector3 = cr.scale
		cr.scale = lleno * 0.2
		_registrar(cr)
		var tw := cr.create_tween()
		tw.tween_interval(float(i) * 0.03)
		tw.tween_property(cr, "scale", lleno, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(7.0)                       # los cristales se quedan; se funden poco a poco
		tw.tween_property(cr, "scale", lleno * 0.01, 1.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(_olvidar.bind(cr))
	_estallido(p, "copo", 18, 1.4, 1.6, 0.17, true, COLOR["hielo"], Vector3(0, -0.6, 0), 1, true)
	_marca("circulo_runico", suelo, 1.4, Color(0.75, 0.95, 1.0), 6.0)
	_luz(p, COLOR["hielo"], 2.0, 3.5, 0.5)
	impacto.emit("hielo", p)


## --- Piezas ---

## Qué forma de Formas3D es una pieza pedida por su nombre histórico (o por el de la propia forma).
func _forma_de(nombre: String) -> String:
	var n: String = nombre.trim_suffix("_tira8")
	if FORMA_DE.has(n):
		return String(FORMA_DE[n])
	return n if Formas3D.NOMBRES.has(n) else "nube"


## El color de una pieza: el que se pide, o el suyo si se pide blanco.
func _tinte(forma: String, color: Color) -> Color:
	if color.r > 0.97 and color.g > 0.97 and color.b > 0.97:
		return COLOR_DE.get(forma, Color.WHITE)
	return Color(color, 1.0)


## Una pieza 3D, hija de `padre`, de `tam` unidades de alto (de ancho si es plana).
func _pieza(nombre: String, padre: Node3D, tam: float, color: Color) -> MeshInstance3D:
	var f: String = _forma_de(nombre)
	var mi: MeshInstance3D = Formas3D.instancia(f, _tinte(f, color), tam)
	padre.add_child(mi)
	return mi


## Una pieza 3D de pie con la base en `pie` (la que mira siempre igual: ya no gira hacia la cámara, tiene volumen).
func _pieza_de_pie(nombre: String, pie: Vector3, tam: float, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = _pieza(nombre, self, tam, color)
	mi.position = pie
	return mi


## Un decal 3D tumbado en el suelo (aro, círculo rúnico, grieta, mancha) de `tam` unidades de ancho.
func _plano(nombre: String, p: Vector3, tam: float, _aditivo: bool, color: Color) -> MeshInstance3D:
	var f: String = _forma_de(nombre)
	var mi: MeshInstance3D = Formas3D.instancia(f, _tinte(f, color), 1.0)
	mi.scale = Vector3(tam, 1.0, tam)
	mi.position = p
	add_child(mi)
	return mi


## Hace girar una pieza sin parar (la cabeza de un proyectil): una vuelta cada `periodo` s.
func _girar(n: Node3D, periodo: float) -> void:
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "rotation:y", TAU, periodo).as_relative()


## Material de la caja de tierra: la textura de tierra del suelo (la misma de los empujables), con luz.
func _material_tierra() -> StandardMaterial3D:
	if _mat_tierra == null:
		_mat_tierra = StandardMaterial3D.new()
		_mat_tierra.roughness = 1.0
		_mat_tierra.albedo_color = Color(0.78, 0.74, 0.7)
		if ResourceLoader.exists(SUELO_TIERRA):
			_mat_tierra.albedo_texture = load(SUELO_TIERRA) as Texture2D
		else:
			_mat_tierra.albedo_color = Color(0.5, 0.37, 0.24)
		_mat_tierra.uv1_triplanar = true
		_mat_tierra.uv1_scale = Vector3.ONE * 0.9
	return _mat_tierra


func _material_contorno_bloque() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Formas3D.COLOR_CONTORNO
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	return m


## Lo que se queda en el mundo un rato: se apunta, y si hay más de MAX_RESTOS se borra la más vieja (memoria).
func _registrar(n: Node3D) -> void:
	_restos.append(n)
	while _restos.size() > MAX_RESTOS:
		var viejo: Node3D = _restos.pop_front()
		if is_instance_valid(viejo):
			var tw := viejo.create_tween()
			tw.tween_property(viejo, "scale", viejo.scale * 0.01, 0.3)
			tw.tween_callback(viejo.queue_free)


func _olvidar(n: Node3D) -> void:
	_restos.erase(n)
	if is_instance_valid(n):
		n.queue_free()


## Marca en el suelo que se queda `dura` s y se encoge hasta desaparecer.
func _marca(nombre: String, suelo: Vector3, tam: float, color: Color, dura: float) -> void:
	var m: MeshInstance3D = _plano(nombre, suelo + Vector3(0.0, 0.02, 0.0), tam * escala, false, color)
	m.rotation.y = randf() * TAU
	_registrar(m)
	var tw := m.create_tween()
	tw.tween_interval(dura)
	tw.tween_property(m, "scale", m.scale * 0.02, 0.8).set_ease(Tween.EASE_IN)
	tw.tween_callback(_olvidar.bind(m))


## Anillo en el suelo que se abre y se apaga.
func _onda(suelo: Vector3, nombre: String, desde: float, hasta: float, dura: float, color: Color) -> void:
	var o: MeshInstance3D = _plano(nombre, suelo + Vector3(0.0, 0.04, 0.0), 1.0, false, color)
	o.scale = Vector3(desde, 1.0, desde) * escala
	var tw := o.create_tween()
	tw.tween_property(o, "scale", Vector3(hasta, 1.0, hasta) * escala, dura).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(o, "scale", Vector3(hasta, 1.0, hasta) * escala * 0.02, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(o.queue_free)


func _crecer_y_borrar(n: MeshInstance3D, sube: float, baja: float) -> void:
	var final_: Vector3 = n.scale
	n.scale = final_ * 0.3
	var tw := n.create_tween()
	tw.tween_property(n, "scale", final_, sube).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", final_ * 0.02, baja).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


## Estallido de una sola vez: `n` partículas que salen en todas direcciones desde `p`.
func _estallido(p: Vector3, nombre: String, n: int, vida: float, vel: float, tam: float, aditivo: bool,
		color: Color, gravedad: Vector3, frames: int = 1, girar: bool = false) -> void:
	var gp := _particulas(nombre, n, vida, vel, tam, aditivo, color, gravedad, frames)
	gp.one_shot = true
	gp.explosiveness = 0.92
	var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	pm.spread = 180.0
	pm.direction = Vector3.UP
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15 * escala
	if girar:
		pm.angular_velocity_min = -540.0
		pm.angular_velocity_max = 540.0
	gp.position = p
	add_child(gp)
	gp.emitting = true
	_despues(vida + 0.3, gp.queue_free)


## Estela que va soltando partículas mientras su padre se mueve (en coordenadas del mundo).
func _estela(padre: Node3D, nombre: String, n: int, vida: float, tam: float, aditivo: bool, color: Color) -> void:
	var gp := _particulas(nombre, n, vida, 0.3, tam, aditivo, color, Vector3.ZERO)
	gp.local_coords = false
	var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	pm.spread = 180.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08 * escala
	padre.add_child(gp)
	gp.emitting = true


## Emisor de partículas 3D: cada una es una malla de Formas3D (`nombre` = el histórico del sprite que sustituye; ver FORMA_DE).
## `tam` = tamaño de la pieza en unidades. `aditivo` y `frames` ya no hacen nada (sin brillo aditivo ni tiras de fotogramas):
## se conservan para no cambiar quién llama. Las llamas pasan por tres tonos planos; el resto, por un tono del color pedido.
## Al acabar la vida la pieza se encoge hasta desaparecer (no hay fundido de transparencia: las piezas son opacas).
func _particulas(nombre: String, n: int, vida: float, vel: float, tam: float, _aditivo: bool, color: Color,
		gravedad: Vector3, _frames: int = 1) -> GPUParticles3D:
	var forma: String = _forma_de(nombre)
	var pm := ParticleProcessMaterial.new()
	pm.initial_velocity_min = vel * 0.5 * escala
	pm.initial_velocity_max = vel * escala
	pm.gravity = gravedad * escala
	pm.damping_min = vel * 0.6
	pm.damping_max = vel * 0.9
	pm.scale_min = tam * 0.7 * escala
	pm.scale_max = tam * 1.3 * escala
	pm.particle_flag_rotate_y = true          # el giro (ángulo y velocidad angular) es alrededor de Y: las piezas no se tumban
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	var curva := Curve.new()
	curva.max_value = 2.0
	curva.add_point(Vector2(0.0, 0.4))
	curva.add_point(Vector2(0.18, 1.0))
	curva.add_point(Vector2(0.75, 0.9))
	curva.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var grad := Gradient.new()
	if forma == "llama":
		# El color de la llama lo da el degradado de su malla (base → punta); en el tiempo solo se apaga suave.
		grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 0.92, 0.8, 1.0), Color(1.0, 0.7, 0.6, 0.0)])
	elif Formas3D.EFECTO_ADITIVO.has(forma) or Formas3D.EFECTO_SUAVE.has(forma):
		var te: Color = _tinte(forma, color)
		grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		grad.colors = PackedColorArray([te, te, Color(te, 0.0)])
	else:
		var tinte: Color = _tinte(forma, color)
		grad.offsets = PackedFloat32Array([0.0, 1.0])
		grad.colors = PackedColorArray([tinte, tinte])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	var gp := GPUParticles3D.new()
	gp.amount = n
	gp.lifetime = vida
	gp.process_material = pm
	gp.draw_pass_1 = Formas3D.malla(forma)
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-5, -3, -5), Vector3(10, 10, 10))
	return gp


func _luz(p: Vector3, color: Color, energia: float, rango: float, dura: float) -> void:
	if not con_luces:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energia
	l.omni_range = rango * escala
	l.position = p
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dura).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## Sacude la cámara activa un instante.
func _temblor(fuerza: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var h: float = cam.h_offset
	var v: float = cam.v_offset
	var tw := cam.create_tween()
	for i in range(5):
		tw.tween_property(cam, "h_offset", h + randf_range(-fuerza, fuerza), 0.03)
		tw.tween_property(cam, "v_offset", v + randf_range(-fuerza, fuerza), 0.03)
	tw.tween_property(cam, "h_offset", h, 0.03)
	tw.tween_property(cam, "v_offset", v, 0.03)


## Deja de emitir y borra el nodo cuando sus partículas se han apagado.
func _soltar(n: Variant) -> void:
	if n == null or not is_instance_valid(n):
		return
	for h in n.get_children():
		if h is GPUParticles3D:
			(h as GPUParticles3D).emitting = false
		elif h is MeshInstance3D or h is OmniLight3D:
			(h as Node3D).visible = false
	_despues(1.0, n.queue_free)


func _despues(t: float, f: Callable) -> void:
	get_tree().create_timer(t, false).timeout.connect(f)
