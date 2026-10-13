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
const FORMAS: Array = ["proyectil", "corro", "columna", "muro", "bola", "pilar", "onda", "chorro", "acompanante", "tormenta", "cupula"]
## Nombres de la fase 5 (formas v2 de DISENO_FUTURO §3): bola = proyectil · pilar = columna · onda = pulso que se abre desde el
## punto · chorro = lanzallamas: un chorro continuo del elemento del origen hacia el destino · acompanante = una manifestación
## que flota junto al jugador. Las dos primeras son alias: se pueden usar los nombres viejos o los nuevos.
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
	"burbuja": Color(1.0, 1.0, 1.0), "gota": Color(1.0, 1.0, 1.0), "chispa": Color(1.0, 0.93, 0.4),
	"estrella": Color(1.0, 0.95, 0.55), "copo": Color(1.0, 1.0, 1.0), "hoja": Color(0.62, 0.88, 0.5),
	"piedra": Color(0.72, 0.58, 0.42), "cristal": Color(1.0, 1.0, 1.0), "pua": Color(0.78, 0.6, 0.4),
	"corona": Color(1.0, 1.0, 1.0), "rayo": Color(1.0, 1.0, 1.0), "remolino": Color(1.0, 1.0, 1.0),
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
## 9/10: estilo del FUEGO. false = el facetado de tres tonos con contorno (6/10); true = el fuego luminoso aditivo de `VfxKit3D`
## (vfx_kit_3d.gd; cada elemento en vfx_elementos/). Solo afecta al elemento fuego y a las formas proyectil (bola), chorro (haz), cupula y muro, y a la pared larga
## `fuego_pared`. El Lab lo alterna con Y.
@export var estilo_fuego_nuevo: bool = false


## 9/10 11:40: ¿este elemento va con el kit luminoso (VfxKit3D)? Sí si el estilo nuevo está activo y el kit tiene rampa para él (hoy
## fuego y agua; el nombre `estilo_fuego_nuevo` se queda por compatibilidad). Deja `VfxKit3D.elemento` puesto para la llamada que sigue.
func _estilo_nuevo(elemento: String) -> bool:
	if not estilo_fuego_nuevo or not VfxKit3D.tiene(elemento):
		return false
	VfxKit3D.elemento = elemento
	return true

var _llamas_activas: int = 0
var _paredes: Dictionary = {}          ## 7.11: casilla (Vector2i) -> pared de fuego larga que la cubre
var _luces_activas: int = 0
var _restos: Array = []                ## lo que se queda un rato en el mundo, de más viejo a más nuevo (MAX_RESTOS)
var _mat_tierra: StandardMaterial3D = null


## Construye todas las mallas y materiales y lanza cada elemento una vez de `origen` a `destino`: Godot compila así los
## shaders de materiales y partículas de golpe (sin esto, el primer hechizo de cada uno da un tirón).
## `con_formas` lanza además una columna de cada elemento (las piezas altas y los chorros de partículas).
func precalentar(origen: Vector3, destino: Vector3, con_formas: bool = false) -> void:
	if estilo_fuego_nuevo:
		VfxKit3D.precalentar(self)
	for n in Formas3D.NOMBRES:
		Formas3D.malla(String(n))
	_material_tierra()
	for e in ELEMENTOS:
		lanzar(String(e), origen, destino)
		if con_formas:
			lanzar_forma("columna", String(e), origen, destino, {"dura": 0.4})


## Lanza un hechizo de `elemento` desde los pies del lanzador hasta los pies del objetivo.
## La BOLA de `elemento` (6.18): un proyectil PEQUEÑO y reconocible que vuela de `pie_origen` a `pie_destino` y hace su impacto allí.
## fuego = bola de fuego con estela · rayo = bola eléctrica · agua = gota · viento = remolino · hielo = carámbano · tierra = piedra.
## `radio` (m) = tamaño de la bola (0,22 por defecto; el Juego lo pasa por `{"radio"}`, 6.5).
func lanzar(elemento: String, pie_origen: Vector3, pie_destino: Vector3, radio: float = 0.22) -> void:
	var alto := Vector3(0.0, 0.6 * escala, 0.0)
	_carga(elemento, pie_origen)
	if _estilo_nuevo(elemento):
		# Fuego luminoso: primero una llamita en la mano (~0,15 s) y luego sale la bola.
		VfxKit3D.llamita(self, pie_origen + alto, escala, 0.15)
		_despues(0.15, _proyectil.bind(elemento, pie_origen + alto, pie_destino + alto, pie_destino.y, radio / 0.22))
		return
	_proyectil(elemento, pie_origen + alto, pie_destino + alto, pie_destino.y, radio / 0.22)


## Llamas que siguen ardiendo hasta que se llama a `apagar(nodo)`: la hierba que arde en la maqueta.
## `esc` 0,5 = llamita (prendiendo), 1 = ardiendo; `radio` = media anchura de la zona que arde.
func llamas(suelo: Vector3, esc: float, radio: float, lenguas: int = 0) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = suelo
	add_child(raiz)
	var completa: bool = _llamas_activas < MAX_LLAMAS_COMPLETAS
	_llamas_activas += 1
	raiz.tree_exited.connect(func() -> void: _llamas_activas -= 1)
	# Lenguas lisas con el shader del fuego (ondulan solas, sin partículas): 1 si el presupuesto está agotado, 2-3 si no.
	var n: int = 1 if not completa else (3 if esc > 0.7 else 2)
	if lenguas > 0:
		n = lenguas      # 6.15: un fuego sencillo (hoguera, antorcha, brasero) lleva UNA lengua (`lenguas` = 1)
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
const GRIETAS_TEX: String = "res://poc_25d/vfx/grietas_impacto.png"


## Grietas en el suelo donde cae el puñetazo del elemental de bosque: una imagen plana (círculo de tierra agrietada con
## matojos y piedrecitas, sacada de la lámina de Pablo con la perspectiva deshecha para que no se aplaste dos veces) pegada
## al suelo. Entra con un golpe de escala (0,12 s), se queda y se desvanece en el último 40 % de `dura`. Se borra sola.
## `radio` = media anchura en el mundo. Plana y no 3D a propósito: es una marca en el suelo, no un volumen.
func grietas(suelo: Vector3, radio: float, dura: float = 2.2) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = suelo + Vector3(0.0, 0.025, 0.0)
	raiz.rotation.y = float(int(suelo.x * 37.0 + suelo.z * 11.0) % 628) * 0.01      # giro distinto en cada golpe
	add_child(raiz)
	var tex: Texture2D = load(GRIETAS_TEX) as Texture2D
	if tex == null:
		get_tree().create_timer(dura).timeout.connect(raiz.queue_free)
		return raiz
	var pm := PlaneMesh.new()
	pm.size = Vector2(radio * 2.0, radio * 2.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.roughness = 1.0
	pm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(mi)
	raiz.scale = Vector3(0.55, 1.0, 0.55)
	var tw := raiz.create_tween()
	tw.tween_property(raiz, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dura * 0.6 - 0.12, 0.0))
	tw.tween_property(m, "albedo_color:a", 0.0, dura * 0.4)
	tw.tween_callback(raiz.queue_free)
	return raiz


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
func fuego_fijo(p: Vector3, barrera: bool, esc: float = 1.0, eje: Vector3 = Vector3.RIGHT, largo: float = 2.3) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "fuego_fijo"
	raiz.position = p
	add_child(raiz)
	var ancho: float = largo * 0.5 if barrera else 0.12 * esc
	if barrera:
		# PARED continua de fuego (referencia de Pablo, fire_ring): una sola malla facetada de `largo` de ancho a lo largo de `eje`.
		# Es hija directa de la raíz para que `apagar` (_soltar) la oculte. Casillas vecinas con el mismo eje forman una pared seguida.
		var m: MeshInstance3D = Formas3D.instancia("pared_fuego", Color.WHITE)
		var lleno := Vector3(largo * 1.01, 1.45, 0.95)
		m.scale = lleno
		m.rotation.y = atan2(-eje.z, eje.x)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(m)
		var fase: float = float(int(p.x * 3.0 + p.z * 5.0) % 7) * 0.13
		var tw := m.create_tween().set_loops()
		tw.tween_interval(fase)
		tw.tween_property(m, "scale", Vector3(lleno.x, lleno.y * 1.07, lleno.z), 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(m, "scale", Vector3(lleno.x, lleno.y * 0.93, lleno.z), 0.28).set_trans(Tween.TRANS_SINE)
	else:
		# 6.15: UNA sola lengua (la «prominente», inclinada hacia un lado). Antes llevaba además dos pequeñas a su costado.
		_lenguas(raiz, 1, 0.0, 0.7 * esc, 0.78 * esc, 0.42, int(p.x * 3.0 + p.z * 5.0))
	var b := _particulas("brasa", 10 if barrera else 5, 1.4, 1.3, 0.12 * esc, true, COLOR["fuego"], Vector3(0.0, -0.3, 0.0))
	_caja_emision(b, ancho, Vector3(0.0, 0.0, 0.0))
	(b.process_material as ParticleProcessMaterial).spread = 25.0
	if barrera:
		(b.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(ancho if absf(eje.x) > 0.5 else 0.25, 0.04, ancho if absf(eje.z) > 0.5 else 0.25)
	raiz.add_child(b)
	b.emitting = true
	return raiz


## 7.11 · PARED DE FUEGO LARGA: una barrera de varias casillas como UN solo objeto (en vez de un `fuego_fijo` por casilla).
## `celdas` = las casillas que cubre, EN ORDEN a lo largo de `eje` (Vector2i); `centros` = el centro de cada una a ras de suelo
## (misma longitud); `casilla` = lado de la casilla. Devuelve la pared (hija de este nodo). Lleva una losa de pared por casilla
## (igual que antes, así se ve igual), UN emisor de brasas a lo largo de toda ella y una luz cada 2 casillas.
##
## Para apagar una casilla: `apagar_tramo(pared, casilla)`: quita esa casilla y deja una pared a cada lado (o una más corta si
## era la punta). Compatibilidad con el Lanzador de hoy: por cada casilla de una pared de 2 o más se deja además un nodo
## «fuego_fijo_tramo» en su centro, que es lo que `BarreraFuego` encuentra como `llama`; apagarlo (`apagar`) apaga ese tramo.
func fuego_pared(celdas: Array, centros: Array, eje: Vector3, casilla: float = 2.3, con_tramos: bool = true) -> Node3D:
	var n: int = celdas.size()
	if n == 0 or centros.size() != n:
		return null
	var raiz := Node3D.new()
	raiz.name = "pared_fuego_larga"
	var ini: Vector3 = centros[0]
	var fin: Vector3 = centros[n - 1]
	raiz.position = (ini + fin) * 0.5 + Vector3(0.0, 0.06, 0.0)   # 6 cm más alta: no se confunde con un tramo
	raiz.set_meta("celdas", celdas.duplicate())
	raiz.set_meta("centros", centros.duplicate())
	raiz.set_meta("eje", eje)
	raiz.set_meta("casilla", casilla)
	var ang: float = atan2(-eje.z, eje.x)
	var lateral: Vector3 = Vector3(-eje.z, 0.0, eje.x).normalized()
	for i in range(n):
		var local: Vector3 = (centros[i] as Vector3) - raiz.position + Vector3(0.0, 0.0, 0.0)
		local.y = 0.0
		var c: Vector3 = centros[i]
		var fase: float = float(int(c.x * 3.0 + c.z * 5.0) % 7) * 0.13
		if estilo_fuego_nuevo:
			VfxKit3D.elemento = "fuego"         # la pared es siempre de fuego (no heredar el elemento del último hechizo)
			# Fuego luminoso: una tira de llamas por casilla (mismo reparto de tramos). Se solapan un 12 % y el ruido va desfasado
			# en cada una, para que no se vean las juntas.
			VfxKit3D.tira(raiz, local, eje, casilla * 1.12, 1.45, fase * 3.0 + float(i) * 0.37, true)
		else:
			var m: MeshInstance3D = Formas3D.instancia("pared_fuego", Color.WHITE)
			var lleno := Vector3(casilla * 1.01, 1.45, 0.95)
			m.scale = lleno
			m.rotation.y = ang
			m.position = local
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			raiz.add_child(m)
			var tw := m.create_tween().set_loops()
			tw.tween_interval(fase)
			tw.tween_property(m, "scale", Vector3(lleno.x, lleno.y * 1.07, lleno.z), 0.22).set_trans(Tween.TRANS_SINE)
			tw.tween_property(m, "scale", Vector3(lleno.x, lleno.y * 0.93, lleno.z), 0.28).set_trans(Tween.TRANS_SINE)
		if i % 2 == 0:
			var luz := OmniLight3D.new()
			luz.position = local + lateral * 0.3 + Vector3(0.0, 0.8, 0.0)    # al lado del centro: no la confunde la búsqueda por casilla
			luz.light_color = Color(1.0, 0.6, 0.3)
			luz.light_energy = 1.6
			luz.omni_range = 4.0
			luz.shadow_enabled = false
			raiz.add_child(luz)
	var b := _particulas("brasa", 10 * n, 1.4, 1.3, 0.12, true, COLOR["fuego"], Vector3(0.0, -0.3, 0.0))
	_caja_emision(b, casilla * 0.5, Vector3.ZERO)
	var pm: ParticleProcessMaterial = b.process_material as ParticleProcessMaterial
	pm.spread = 25.0
	pm.emission_box_extents = Vector3(casilla * 0.5 * float(n), 0.04, 0.25)
	b.rotation.y = ang
	raiz.add_child(b)
	b.emitting = true
	add_child(raiz)
	if n >= 2 and con_tramos:
		for i in range(n):
			var tramo := Node3D.new()           # el «llama» de cada casilla para el Lanzador de hoy
			tramo.name = "fuego_fijo_tramo"
			tramo.position = centros[i]
			tramo.set_meta("tramo_celda", celdas[i])
			add_child(tramo)
			move_child(tramo, 0)                # antes que la pared: la búsqueda por posición encuentra primero el tramo
	for ce in celdas:
		_paredes[ce] = raiz
	return raiz


## Quita la casilla `casilla` de la pared de fuego `muro` y deja el resto. Si `muro` ya no es válido (se partió antes) se busca la
## pared que cubre hoy esa casilla. No hace nada si esa casilla no tiene pared.
func apagar_tramo(muro: Node3D, casilla: Vector2i) -> void:
	var w: Node3D = null
	if muro != null and is_instance_valid(muro) and muro.has_meta("celdas") and (muro.get_meta("celdas") as Array).has(casilla):
		w = muro
	elif _paredes.has(casilla) and is_instance_valid(_paredes[casilla]):
		w = _paredes[casilla]
	if w == null:
		_paredes.erase(casilla)
		return
	var celdas: Array = w.get_meta("celdas")
	var centros: Array = w.get_meta("centros")
	var eje: Vector3 = w.get_meta("eje")
	var lado: float = float(w.get_meta("casilla"))
	var i: int = celdas.find(casilla)
	for ce in celdas:
		_paredes.erase(ce)
	# El tramo de compatibilidad de ESTA casilla se va; los de las demás se quedan (el Lanzador los guarda como `llama`).
	for h in get_children():
		if h.has_meta("tramo_celda") and h.get_meta("tramo_celda") == casilla:
			h.queue_free()
	_soltar(w)
	var izq_c: Array = celdas.slice(0, i)
	var izq_p: Array = centros.slice(0, i)
	var der_c: Array = celdas.slice(i + 1)
	var der_p: Array = centros.slice(i + 1)
	if not izq_c.is_empty():
		fuego_pared(izq_c, izq_p, eje, lado, false)
	if not der_c.is_empty():
		fuego_pared(der_c, der_p, eje, lado, false)


func _caja_emision(gp: GPUParticles3D, radio: float, desplazado: Vector3) -> void:
	var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radio, 0.04, radio)
	pm.direction = Vector3.UP
	pm.spread = 14.0
	gp.position = desplazado


## Deja de emitir y borra las llamas cuando se apagan las partículas.
func apagar(n: Node3D, opciones: Dictionary = {}) -> void:
	if n == null or not is_instance_valid(n):
		return
	if bool(opciones.get("rompe", false)):
		_romper(n)
		return
	_soltar(n)


## 6.17 Los SÓLIDOS SE ROMPEN: cada pieza del nodo cae hacia fuera girando, se encoge al tocar el suelo y se borra con el nodo.
## (`apagar(nodo, {"rompe": true})`; los fluidos siguen apagándose con `apagar(nodo)`.)
func _romper(n: Node3D) -> void:
	var piezas: Array = n.find_children("*", "MeshInstance3D", true, false)
	for h in n.get_children():
		if h is GPUParticles3D:
			(h as GPUParticles3D).emitting = false
	var centro: Vector3 = n.global_position
	for q in piezas:
		var mi: MeshInstance3D = q as MeshInstance3D
		var fuera: Vector3 = mi.global_position - centro
		fuera.y = 0.0
		fuera = fuera.normalized() * randf_range(0.2, 0.5) if fuera.length() > 0.05 else Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "position", mi.position + fuera + Vector3(0.0, -maxf(mi.global_position.y - centro.y, 0.25), 0.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(mi, "rotation", mi.rotation + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)), 0.45)
		tw.chain().tween_property(mi, "scale", Vector3.ZERO, 0.25)
		_estallido(mi.global_position, "piedrecitas", 3, 0.6, 1.6, 0.15, false, Color.WHITE, Vector3(0, -7, 0))
	_despues(0.8, n.queue_free)


## Lanza un hechizo de `elemento` con la `forma` dada (FORMAS). `pie_origen` = pies del lanzador; `pie_destino` = el
## punto señalado (pies). Opciones: "radio" (corro: radio del anillo; muro: semiancho; 1,2 por defecto) y "dura"
## (segundos que se ve cada manifestación; por defecto 2,0 el corro, 3,0 la columna/pilar, 0,9 el muro, 0,7 la onda, 1,6 el chorro y 6,0
## el acompañante); "largo" (chorro: hasta dónde llega, 4,0 por defecto). Una forma
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
			if bool(opciones.get("crece", false)):
				_pulso_crece(elemento, pie_origen, pie_destino, radio, float(opciones.get("dura", 1.6)), bool(opciones.get("rompe", true)))
			else:
				_corro(elemento, pie_origen, pie_destino, radio, float(opciones.get("dura", 2.0)))
		"columna":
			_columna(elemento, pie_origen, pie_destino, float(opciones.get("dura", 3.0)))
		"muro":
			_muro(elemento, pie_origen, pie_destino, radio, float(opciones.get("dura", 0.9)))
		"bola":
			lanzar(elemento, pie_origen, pie_destino, float(opciones.get("radio", 0.22)))
		"pilar":
			if _estilo_nuevo(elemento):
				# 9/10 (prueba de Pablo): el muro con ancho y alto cambiados; mismos valores que `_muro` con su semiancho por defecto.
				VfxKit3D.pilar(self, pie_origen, pie_destino, 1.7 * escala, (radio * 2.0 + 0.6) * escala, float(opciones.get("dura", 3.0)), escala)
			else:
				_columna(elemento, pie_origen, pie_destino, float(opciones.get("dura", 3.0)))
		"onda":
			# 6.17: el pulso es un aro que CRECE desde el jugador (opciones "crece": false vuelve al pulso antiguo de ondas).
			if bool(opciones.get("crece", true)):
				_pulso_crece(elemento, pie_origen, pie_destino, maxf(radio, 1.8) if not opciones.has("radio") else radio, float(opciones.get("dura", 1.6)), bool(opciones.get("rompe", true)))
			else:
				_onda_forma(elemento, pie_origen, pie_destino, maxf(radio, 1.8) if not opciones.has("radio") else radio, float(opciones.get("dura", 0.7)))
		"chorro":
			_chorro_forma(elemento, pie_origen, pie_destino, float(opciones.get("largo", 4.0)), float(opciones.get("dura", 1.6)))
		"acompanante":
			_acompanante(elemento, pie_origen, pie_destino, float(opciones.get("dura", 6.0)))
		"cupula":
			_cupula(elemento, pie_origen, pie_destino, radio if opciones.has("radio") else 1.4, float(opciones.get("dura", 4.0)))
		"tormenta":
			_tormenta(pie_destino, radio if opciones.has("radio") else 2.2, float(opciones.get("dura", 6.0)))
		_:
			if forma != "proyectil" and forma != "":
				push_warning("Vfx3D: forma desconocida '%s'; se usa proyectil" % forma)
			lanzar(elemento, pie_origen, pie_destino)


## --- Formas ---

## CORRO = un ANILLO CERRADO de pared del elemento alrededor del punto (la referencia fire_ring): tramos de pared
## colocados sobre la circunferencia de `radio` (en el suelo), cada uno tangente, que aparecen en cadena y se hunden a la
## vez. Se ve solo el anillo (nada de círculo plano en el suelo); el interior queda libre. Cada elemento lo dibuja a su
## manera, igual que el muro (`_pared`).
func _corro(elemento: String, pie_origen: Vector3, centro: Vector3, radio: float, dura: float) -> void:
	_carga(elemento, pie_origen)
	var c: Color = COLOR[elemento]
	var r: float = maxf(radio, 0.6) * escala
	if elemento == "tierra" and _cargar_piedra():
		# El anillo de rocas entero (stone_ring), con su radio medio sobre la circunferencia pedida.
		var k: float = r / R_PIEDRA
		var giro: float = float(int(centro.x * 7.0 + centro.z * 13.0) % 360) * PI / 180.0
		_despues(0.25, _roca.bind(_p_anillo, centro, giro, Vector3(k, minf(k, 3.4 * escala) * 1.0, k), 0.0, dura))
		for i in range(4):
			var ang: float = float(i) / 4.0 * TAU + giro
			var p: Vector3 = centro + Vector3(cos(ang), 0.0, sin(ang)) * r
			_despues(0.25, _estallido.bind(p + Vector3(0, 0.2, 0), "piedrecitas", 8, 0.9, 2.6, 0.2, false, Color.WHITE,
				Vector3(0, -7.0, 0)))
		_despues(0.25, _temblor.bind(0.08))
		_despues(0.25, _luz.bind(centro + Vector3(0.0, 0.6, 0.0), c, 1.0, 3.0 + radio, 0.5))
		return
	if elemento == "rayo" and _cargar_energia():
		# La cúpula de energía entera sobre el área; sube desde el suelo como en el vídeo.
		var k: float = r / R_ENERGIA
		var giro_e: float = float(int(centro.x * 7.0 + centro.z * 13.0) % 360) * PI / 180.0
		_despues(0.25, _roca.bind(_e_domo, centro, giro_e, Vector3(k, k * 0.85, k), 0.0, dura))
		for i in range(3):
			var ang: float = float(i) / 3.0 * TAU + giro_e
			_despues(0.3 + 0.1 * float(i), _estallido.bind(centro + Vector3(cos(ang), 0.1, sin(ang)) * r, "chispa_electrica", 8, 0.5, 2.0, 0.4, true,
				Color.WHITE, Vector3.ZERO))
		_despues(0.25, _luz.bind(centro + Vector3(0.0, 0.8, 0.0), Color(0.4, 0.7, 1.0), 2.0, 3.5 + radio, minf(dura, 1.5)))
		return
	var n: int = clampi(int(ceil(TAU * r / 1.1)), 8, 18)
	var cuerda: float = 2.0 * r * sin(PI / float(n))
	var ang0: float = atan2(centro.z - pie_origen.z, centro.x - pie_origen.x)
	for i in range(n):
		var ang: float = ang0 + float(i) / float(n) * TAU
		var radial := Vector3(cos(ang), 0.0, sin(ang))
		var lado := Vector3(-radial.z, 0.0, radial.x)
		_pared(elemento, centro + radial * r, lado, cuerda * 1.12 / escala, 1.3, 0.25 + 0.03 * float(i), dura, i % 4 == 0)
	_despues(0.25, _luz.bind(centro + Vector3(0.0, 0.6, 0.0), c, 1.4, 3.0 + radio, 0.5))


## --- Formas v2 (fase 5) ---

## ONDA: un pulso que se abre desde `centro` (pie_destino; pasad los pies del jugador en los dos si empuja desde él) hasta `radio`.
## Dos aros que se abren seguidos, un estallido de piezas del elemento y una luz; la tierra además tiembla.
func _onda_forma(elemento: String, pie_origen: Vector3, centro: Vector3, radio: float, dura: float) -> void:
	_carga(elemento, pie_origen)
	var c: Color = COLOR[elemento]
	var r: float = maxf(radio, 0.8)
	var aro: Color = Color(c.r, c.g, c.b, 0.85)
	if elemento == "fuego":
		aro = Color(1.0, 0.7, 0.25, 0.85)
	_despues(0.2, _onda.bind(centro, "ondas", 0.4, r * 2.0, dura, aro))
	_despues(0.32, _onda.bind(centro, "ondas", 0.3, r * 1.5, dura, Color(1, 1, 1, 0.6)))
	var p: Vector3 = centro + Vector3(0.0, 0.25, 0.0)
	match elemento:
		"fuego":
			_despues(0.2, _estallido.bind(p, "llama", 14, 0.7, r * 2.2, 0.45, false, Color.WHITE, Vector3(0, 1.2, 0)))
			_despues(0.2, _estallido.bind(p, "brasa", 18, 1.0, r * 2.4, 0.12, true, c, Vector3(0, -0.4, 0)))
		"agua":
			_despues(0.2, _estallido.bind(p, "gota", 22, 0.9, r * 2.4, 0.2, false, Color.WHITE, Vector3(0, -7.0, 0)))
			_despues(0.2, _estallido.bind(p, "salpicadura", 6, 0.6, r * 1.6, 0.45, false, Color(1, 1, 1, 0.8), Vector3.ZERO))
		"tierra":
			_despues(0.2, _estallido.bind(p, "piedrecitas", 16, 0.9, r * 2.2, 0.22, false, Color.WHITE, Vector3(0, -7.0, 0)))
			_despues(0.2, _estallido.bind(p, "polvo", 10, 1.1, r * 1.8, 0.7, false, Color(1, 1, 1, 0.6), Vector3(0, 0.3, 0)))
			_despues(0.22, _temblor.bind(0.09))
		"viento":
			_despues(0.2, _estallido.bind(p, "hoja", 22, 1.2, r * 2.6, 0.3, false, Color.WHITE, Vector3(0, 0.2, 0), 1, true))
			_despues(0.2, _remolino.bind(centro + Vector3(0.0, 0.4, 0.0), r * 1.1, 0.0, dura, 1.0))
		"rayo":
			_despues(0.2, _estallido.bind(p, "chispa_electrica", 24, 0.5, r * 2.8, 0.4, true, Color.WHITE, Vector3.ZERO))
			_despues(0.2, _chispazo_aro.bind(centro, r))
		"hielo":
			_despues(0.2, _estallido.bind(p, "copo", 22, 1.2, r * 2.0, 0.2, true, c, Vector3(0, -0.5, 0)))
			_despues(0.2, _estallido.bind(p, "cristal_hielo", 6, 0.8, r * 1.5, 0.35, false, Color.WHITE, Vector3(0, -5.0, 0)))
	_despues(0.2, _luz.bind(p + Vector3(0.0, 0.4, 0.0), c, 1.6, 3.0 + r, 0.6))


## Unos rayitos repartidos por la circunferencia (onda de rayo).
func _chispazo_aro(centro: Vector3, r: float) -> void:
	for i in range(6):
		var ang: float = float(i) / 6.0 * TAU + randf() * 0.5
		var q: Vector3 = centro + Vector3(cos(ang), 0.0, sin(ang)) * r * 0.8
		var m: MeshInstance3D = _pieza_de_pie("rayo", q, 1.1 * escala, Color(1, 1, 1, 0.95))
		_crecer_y_borrar(m, 0.08, 0.2)
		_parpadear(m, 0.0, 0.3)


## CHORRO (lanzallamas): un flujo continuo de piezas del elemento que sale de la mano (a ~0,9 de altura sobre `pie_origen`) hacia
## `pie_destino`, de `largo` unidades y `dura` segundos. El agua cae en arco, la tierra escupe piedras, el viento lleva hojas,
## el rayo chispas y el hielo copos. Lleva una luz que acompaña el chorro.
func _chorro_forma(elemento: String, pie_origen: Vector3, pie_destino: Vector3, largo: float, dura: float) -> void:
	var dir := Vector3(pie_destino.x - pie_origen.x, 0.0, pie_destino.z - pie_origen.z)
	if dir.length() < 0.01:
		dir = Vector3(0.0, 0.0, 1.0)
	dir = dir.normalized()
	if _estilo_nuevo(elemento):
		# Haz continuo de la mano al suelo, a `largo` de distancia; en el extremo arde el impacto mientras dure.
		_carga(elemento, pie_origen)
		var mano: Vector3 = pie_origen + Vector3(0.0, 0.9 * escala, 0.0) + dir * 0.4 * escala
		var punta: Vector3 = pie_origen + dir * maxf(largo, 1.0) * escala + Vector3(0.0, 0.1, 0.0)
		VfxKit3D.haz(self, mano, punta, dura, escala, pie_destino.y)
		return
	var c: Color = COLOR[elemento]
	var L: float = maxf(largo, 1.0) * escala
	var vida: float = 0.55
	var vel: float = L / vida
	var base: Vector3 = pie_origen + Vector3(0.0, 0.9 * escala, 0.0) + dir * 0.5 * escala
	_carga(elemento, pie_origen)
	var raiz := Node3D.new()
	raiz.position = base
	add_child(raiz)
	var capas: Array = []     # [pieza, n, tamaño, aditivo, color, gravedad, abanico]
	match elemento:
		"fuego":
			capas = [["llama", 26, 0.55, false, Color.WHITE, Vector3(0, 1.5, 0), 11.0], ["brasa", 18, 0.13, true, c, Vector3(0, -0.5, 0), 18.0]]
		"agua":
			capas = [["gota", 40, 0.2, false, Color.WHITE, Vector3(0, -6.0, 0), 7.0], ["salpicadura", 6, 0.35, false, Color(1, 1, 1, 0.7), Vector3(0, -5.0, 0), 8.0]]
		"tierra":
			capas = [["piedrecitas", 30, 0.26, false, Color.WHITE, Vector3(0, -8.0, 0), 12.0], ["polvo", 8, 0.7, false, Color(1, 1, 1, 0.55), Vector3(0, 0.3, 0), 14.0]]
		"viento":
			capas = [["hoja", 34, 0.3, false, Color.WHITE, Vector3(0, 0.3, 0), 14.0]]
		"rayo":
			capas = [["chispa_electrica", 36, 0.4, true, Color.WHITE, Vector3.ZERO, 16.0], ["destello", 8, 0.3, true, Color(1.0, 0.95, 0.5), Vector3.ZERO, 8.0]]
		"hielo":
			capas = [["copo", 34, 0.2, true, c, Vector3(0, -0.6, 0), 12.0], ["cristal_hielo", 6, 0.3, false, Color.WHITE, Vector3(0, -4.0, 0), 9.0]]
	for cp in capas:
		var gp := _particulas(String(cp[0]), int(cp[1]), vida, vel / escala, float(cp[2]), bool(cp[3]), cp[4] as Color, cp[5] as Vector3)
		var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
		pm.damping_min = 0.0
		pm.damping_max = 0.0
		pm.direction = dir
		pm.spread = float(cp[6])
		pm.initial_velocity_min = vel * 0.7
		pm.initial_velocity_max = vel * 1.0
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.1 * escala
		gp.local_coords = false
		gp.explosiveness = 0.0
		gp.emitting = false
		raiz.add_child(gp)
		_despues(0.25, gp.set.bind("emitting", true))
	# La luz recorre el chorro.
	if con_luces:
		var l := OmniLight3D.new()
		l.light_color = c
		l.light_energy = 1.5
		l.omni_range = 3.2 * escala
		l.position = Vector3(0.0, 0.1, 0.0) + dir * L * 0.35
		raiz.add_child(l)
		var tl := l.create_tween()
		tl.tween_interval(0.25 + maxf(dura, 0.2))
		tl.tween_property(l, "light_energy", 0.0, 0.25)
	_despues(0.25 + maxf(dura, 0.2), _soltar_chorro.bind(raiz))


func _soltar_chorro(raiz: Node3D) -> void:
	if raiz == null or not is_instance_valid(raiz):
		return
	for h in raiz.get_children():
		if h is GPUParticles3D:
			(h as GPUParticles3D).emitting = false
	_despues(1.2, raiz.queue_free)


## ACOMPAÑANTE: una manifestación pequeña del elemento que flota junto al jugador (en `pie_destino`) `dura` s: llama, burbuja,
## piedras que giran, remolino, orbe de chispas o cristal. Sube y baja suave y gira; aparece creciendo y se apaga encogiendo.
func _acompanante(elemento: String, pie_origen: Vector3, pie_destino: Vector3, dura: float) -> void:
	_carga(elemento, pie_origen)
	var c: Color = COLOR[elemento]
	var raiz := Node3D.new()
	raiz.position = pie_destino + Vector3(0.0, 1.15 * escala, 0.0)
	raiz.scale = Vector3.ONE * 0.05
	add_child(raiz)
	var cuerpo := Node3D.new()
	raiz.add_child(cuerpo)
	match elemento:
		"fuego":
			_pieza("llama", cuerpo, 0.7 * escala, Color.WHITE).position = Vector3(0.0, -0.3 * escala, 0.0)
			var gp := _particulas("brasa", 8, 0.9, 0.5, 0.08, true, c, Vector3(0, 0.6, 0))
			cuerpo.add_child(gp)
		"agua":
			_pieza("burbuja", cuerpo, 0.55 * escala, Color(1, 1, 1, 0.9))
			var g := _pieza("gota", cuerpo, 0.3 * escala, Color.WHITE)
			g.position = Vector3(0.0, -0.12 * escala, 0.0)
		"tierra":
			for i in range(3):
				var r := Node3D.new()
				cuerpo.add_child(r)
				var pr: MeshInstance3D = _pieza("piedra", r, (0.26 + 0.06 * float(i)) * escala, Color.WHITE)
				pr.position = Vector3(0.28 * escala, 0.1 * escala * float(i - 1), 0.0)
				r.rotation.y = float(i) / 3.0 * TAU
				var tw_r := r.create_tween().set_loops()
				tw_r.tween_property(r, "rotation:y", TAU, 2.4 + 0.5 * float(i)).as_relative()
		"viento":
			_pieza("remolino_viento", cuerpo, 0.65 * escala, Color.WHITE)
			_girar(cuerpo, 1.1)
		"rayo":
			var e: MeshInstance3D = _pieza("estrella", cuerpo, 0.5 * escala, Color(1.0, 0.95, 0.5))
			var z: MeshInstance3D = _pieza("rayo", cuerpo, 0.7 * escala, Color(1, 1, 1, 0.95))
			z.position = Vector3(0.0, -0.3 * escala, 0.0)
			_parpadear(z, 0.0, dura)
			var tw_e := e.create_tween().set_loops()
			tw_e.tween_property(e, "scale", Vector3.ONE * 1.35, 0.12)
			tw_e.tween_property(e, "scale", Vector3.ONE * 0.8, 0.16)
		"hielo":
			_pieza("cristal_hielo", cuerpo, 0.6 * escala, Color.WHITE).position = Vector3(0.0, -0.3 * escala, 0.0)
			var gc := _particulas("copo", 8, 1.1, 0.4, 0.1, true, c, Vector3(0, -0.4, 0))
			cuerpo.add_child(gc)
			_girar(cuerpo, 3.0)
	if con_luces:
		var l := OmniLight3D.new()
		l.light_color = c
		l.light_energy = 0.9
		l.omni_range = 2.4 * escala
		raiz.add_child(l)
	var y0: float = raiz.position.y
	var tw := raiz.create_tween()
	tw.tween_property(raiz, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bob := raiz.create_tween().set_loops()
	bob.tween_property(raiz, "position:y", y0 + 0.12 * escala, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(raiz, "position:y", y0 - 0.06 * escala, 0.9).set_trans(Tween.TRANS_SINE)
	var fin := raiz.create_tween()
	fin.tween_interval(0.3 + maxf(dura, 0.5))
	fin.tween_property(raiz, "scale", Vector3.ONE * 0.02, 0.35).set_ease(Tween.EASE_IN)
	fin.tween_callback(raiz.queue_free)


## --- 6.17 PULSO QUE CRECE (los cuatro fotogramas del playtest: puntos → anillo bajo → anillo lleno → ceniza) ---
## `lanzar_forma("onda" o "corro", elemento, pie_origen, centro, {"crece": true, "radio": r, "dura": 1.6, "rompe": true})`.
## Un aro nace pequeño y bajo en `centro` (el jugador), crece hasta `radio` y se completa (65 % de `dura`), se queda un momento y se
## apaga (fluido: se hunde y se hace ceniza) o se ROMPE (`rompe`, solo tierra y hielo: caen los fragmentos). Es solo la imagen.
const ANILLO_FUEGO: String = "res://poc_25d/vfx/anillo_fuego.glb"
static var _f_malla: Mesh = null
static var _f_radio: float = 1.0
static var _f_alto: float = 0.5
static var _f_probado: bool = false
const CENIZA: Color = Color(0.62, 0.55, 0.5)


func _cargar_fuego() -> bool:
	if _f_probado:
		return _f_malla != null
	_f_probado = true
	if not ResourceLoader.exists(ANILLO_FUEGO):
		return false
	var ps: PackedScene = load(ANILLO_FUEGO) as PackedScene
	if ps == null:
		return false
	var raiz: Node = ps.instantiate()
	var l: Array = raiz.find_children("*", "MeshInstance3D", true, false)
	var mi: MeshInstance3D = raiz as MeshInstance3D if raiz is MeshInstance3D else (l[0] as MeshInstance3D if not l.is_empty() else null)
	if mi != null and mi.mesh != null:
		# El GLB trae un montoncito blanco en el centro del aro: se quitan los triángulos bajos (< 0,3) a menos de 0,36 del centro.
		_f_malla = _sin_centro(mi.mesh, 0.36)
		var c: AABB = mi.mesh.get_aabb()
		_f_radio = maxf(c.size.x, c.size.z) * 0.5
		_f_alto = c.size.y
	raiz.free()
	return _f_malla != null


## ETAPAS del aro de fuego (modelos de Pablo, 7/10): cuatro aros del mismo radio (0,5) y alto creciente: chispas sueltas
## (0,29) → llamas sueltas (0,37) → aro de llamas (0,50) → aro alto (0,62). El pulso que crece pasa de una a otra mientras se
## abre, así el fuego "prende" en vez de estirarse. Las texturas de Tripo salen pálidas y rosadas, así que el color lo pone
## un shader por ALTURA (amarillo claro abajo → naranja → rojo en las puntas, la paleta de `pared_fuego`) y la textura solo
## aporta el sombreado. Si falta alguno de los .glb se usa `anillo_fuego.glb` como antes.
const FUEGO_ETAPAS: Array = ["res://poc_25d/vfx/fuego_1.glb", "res://poc_25d/vfx/fuego_2.glb",
	"res://poc_25d/vfx/fuego_3.glb", "res://poc_25d/vfx/fuego_4.glb"]
const ALTO_ETAPA_MAX: float = 0.62
const CODIGO_FUEGO_ETAPAS: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform float alto = 0.62;
uniform float alfa = 1.0;
uniform float ceniza = 0.0;
varying float vy;

void vertex() {
	vy = VERTEX.y;
}

void fragment() {
	float t = clamp(vy / alto, 0.0, 1.0);
	vec3 base = vec3(1.0, 0.93, 0.62);
	vec3 medio = vec3(1.0, 0.6, 0.2);
	vec3 punta = vec3(0.93, 0.3, 0.12);
	vec3 col = t < 0.5 ? mix(base, medio, t * 2.0) : mix(medio, punta, (t - 0.5) * 2.0);
	float lum = dot(texture(textura, UV).rgb, vec3(0.3, 0.59, 0.11));
	col *= 0.7 + 0.4 * lum;
	col = mix(col, vec3(0.62, 0.55, 0.5), ceniza);
	ALBEDO = col;
	ALPHA = alfa;
}
"""
static var _f_etapas: Array = []          ## Array[Mesh], de menos a más fuego
static var _f_etapa_tex: Texture2D = null
static var _f_etapas_radio: float = 0.5
static var _f_etapas_probado: bool = false


func _cargar_etapas_fuego() -> bool:
	if _f_etapas_probado:
		return not _f_etapas.is_empty()
	_f_etapas_probado = true
	var mallas: Array = []
	for ruta in FUEGO_ETAPAS:
		if not ResourceLoader.exists(String(ruta)):
			return false
		var ps: PackedScene = load(String(ruta)) as PackedScene
		if ps == null:
			return false
		var raiz: Node = ps.instantiate()
		var mi: MeshInstance3D = raiz as MeshInstance3D
		if mi == null:
			var l: Array = raiz.find_children("*", "MeshInstance3D", true, false)
			mi = l[0] as MeshInstance3D if not l.is_empty() else null
		if mi != null and mi.mesh != null:
			mallas.append(mi.mesh)
			var m0: Material = mi.mesh.surface_get_material(0)
			if _f_etapa_tex == null and m0 is BaseMaterial3D:
				_f_etapa_tex = (m0 as BaseMaterial3D).albedo_texture
		raiz.free()
	if mallas.size() != FUEGO_ETAPAS.size():
		return false
	var c: AABB = (mallas[mallas.size() - 1] as Mesh).get_aabb()
	_f_etapas_radio = maxf(c.size.x, c.size.z) * 0.5
	_f_etapas = mallas
	return true


## Material del aro por etapas (uno por pulso: su `alfa` y su `ceniza` se animan al apagarse).
func _material_etapas() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = CODIGO_FUEGO_ETAPAS
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("alto", ALTO_ETAPA_MAX)
	if _f_etapa_tex != null:
		mat.set_shader_parameter("textura", _f_etapa_tex)
	return mat


## Copia de `malla` sin los triángulos bajos cuyo centro está a menos de `r_min` del eje Y (conserva UV y material).
func _sin_centro(malla: Mesh, r_min: float) -> Mesh:
	var res := ArrayMesh.new()
	for si in range(malla.get_surface_count()):
		var arr: Array = malla.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var nuevo := PackedInt32Array()
		var t: int = 0
		while t + 2 < idx.size():
			var m: Vector3 = (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
			# Fuera lo que está dentro del hueco del aro y bajo (el montón blanco del GLB): radio < r_min y altura < 0,3.
			if not (Vector2(m.x, m.z).length() < r_min and m.y < 0.3):
				nuevo.append(idx[t])
				nuevo.append(idx[t + 1])
				nuevo.append(idx[t + 2])
			t += 3
		arr[Mesh.ARRAY_INDEX] = nuevo
		res.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		res.surface_set_material(res.get_surface_count() - 1, malla.surface_get_material(si))
	return res


func _pulso_crece(elemento: String, pie_origen: Vector3, centro: Vector3, radio: float, dura: float, rompe: bool) -> void:
	_carga(elemento, pie_origen)
	if _estilo_nuevo(elemento):
		# Onda de fuego luminoso: aro de llamas con ruido que se abre (VfxKit3D.onda).
		VfxKit3D.onda(self, centro, maxf(radio, 0.8) * escala, dura, escala)
		return
	var c: Color = COLOR[elemento]
	var r: float = maxf(radio, 0.8) * escala
	var t_total: float = maxf(dura, 0.8)
	var t_crece: float = t_total * 0.5
	var t_quieto: float = t_total * 0.2
	var solido: bool = rompe and (elemento == "tierra" or elemento == "hielo")
	var malla: Mesh = null
	var r_mod: float = 1.0
	var h_mod: float = 1.0
	var etapas: Array = []
	if elemento == "fuego" and _cargar_etapas_fuego():
		etapas = _f_etapas
		malla = etapas[0] as Mesh
		r_mod = _f_etapas_radio
		h_mod = ALTO_ETAPA_MAX
	elif elemento == "fuego" and _cargar_fuego():
		malla = _f_malla
		r_mod = _f_radio
		h_mod = _f_alto
	elif elemento == "tierra" and _cargar_piedra():
		malla = _p_anillo
		r_mod = R_PIEDRA
		h_mod = ALTO_PIEDRA
	elif elemento == "rayo" and _cargar_energia():
		malla = _e_domo
		r_mod = R_ENERGIA
		h_mod = ALTO_ENERGIA
	# --- El aro: una malla del elemento (si hay modelo) o una corona de piezas ---
	var aro := Node3D.new()
	aro.position = centro
	add_child(aro)
	var piezas: Array = []
	var angulos: Array = []
	var hijo: MeshInstance3D = null
	var mat: Material = null
	var tam_pieza: float = 0.0
	if malla != null:
		hijo = MeshInstance3D.new()
		hijo.mesh = malla
		hijo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not etapas.is_empty():
			var me: ShaderMaterial = _material_etapas()
			hijo.material_override = me
			mat = me
		elif elemento == "fuego" and malla.get_surface_count() > 0 and malla.surface_get_material(0) is BaseMaterial3D:
			var md: BaseMaterial3D = (malla.surface_get_material(0) as BaseMaterial3D).duplicate() as BaseMaterial3D
			md.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			hijo.material_override = md
			mat = md
		aro.add_child(hijo)
	else:
		var nombre: String = {"fuego": "llama", "agua": "salpicadura", "tierra": "pua", "viento": "remolino_viento", "rayo": "rayo",
			"hielo": "cristal_hielo"}[elemento]
		tam_pieza = {"fuego": 0.55, "agua": 0.5, "tierra": 0.45, "viento": 0.55, "rayo": 0.6, "hielo": 0.55}[elemento] * escala
		var n: int = clampi(int(ceil(TAU * r / 0.42)), 12, 30)
		for i in range(n):
			var pz: MeshInstance3D = _pieza(nombre, aro, tam_pieza * randf_range(0.8, 1.25), Color.WHITE)
			var a: float = float(i) / float(n) * TAU + randf() * 0.15
			pz.rotation.y = -a
			piezas.append(pz)
			angulos.append(a)
	var k_xz: float = r / r_mod
	var k_y: float = clampf(r / r_mod, 0.7, 1.7)
	var _poner := func(p: float) -> void:
		var e: float = 1.0 - pow(1.0 - p, 2.0)                   # el radio sale rápido y frena
		var rr: float = lerpf(0.12, 1.0, e)
		var alto: float = lerpf(0.08, 1.0, smoothstep(0.0, 1.0, p))
		if hijo != null and not etapas.is_empty():
			# Con etapas el alto lo da el modelo de cada etapa: chispas → llamas sueltas → aro → aro alto.
			hijo.mesh = etapas[mini(int(p * float(etapas.size())), etapas.size() - 1)] as Mesh
			hijo.scale = Vector3(k_xz * rr, k_y * lerpf(0.6, 1.0, alto), k_xz * rr)
		elif hijo != null:
			hijo.scale = Vector3(k_xz * rr, k_y * alto, k_xz * rr)
		for i in range(piezas.size()):
			var a2: float = float(angulos[i])
			(piezas[i] as MeshInstance3D).position = Vector3(cos(a2), 0.0, sin(a2)) * r * rr
			(piezas[i] as MeshInstance3D).scale = Vector3.ONE * lerpf(0.25, 1.0, alto)
	_poner.call(0.0)
	var tw := aro.create_tween()
	tw.tween_method(_poner, 0.0, 1.0, t_crece)
	tw.tween_interval(t_quieto)
	# Luz y chispas mientras crece
	_luz(centro + Vector3(0.0, 0.5, 0.0), c, 1.6, 3.0 + radio, t_total * 0.8)
	if elemento == "tierra":
		_despues(t_crece, _temblor.bind(0.06))
	# --- Fin: fragmentos que caen (sólidos) o ceniza / se hunde (fluidos) ---
	var fin_t: float = t_total - t_crece - t_quieto
	if solido:
		tw.tween_callback(_fragmentos.bind(centro, r, "tierra" if elemento == "tierra" else "hielo", aro))
		tw.tween_interval(0.9)
		tw.tween_callback(aro.queue_free)
	else:
		tw.tween_callback(_ceniza_aro.bind(centro, r, elemento))
		tw.tween_method(func(q: float) -> void:
			if mat is ShaderMaterial:
				(mat as ShaderMaterial).set_shader_parameter("ceniza", minf(q * 2.0, 1.0))
				(mat as ShaderMaterial).set_shader_parameter("alfa", 1.0 - maxf(q - 0.4, 0.0) / 0.6)
			elif mat != null and mat is BaseMaterial3D:
				(mat as BaseMaterial3D).albedo_color = Color.WHITE.lerp(CENIZA, minf(q * 2.0, 1.0)) * Color(1, 1, 1, 1.0 - maxf(q - 0.4, 0.0) / 0.6)
			if hijo != null:
				hijo.scale = Vector3(k_xz * (1.0 + 0.04 * q), k_y * (1.0 - 0.85 * q), k_xz * (1.0 + 0.04 * q))
			for pz in piezas:
				(pz as MeshInstance3D).scale = Vector3.ONE * (1.0 - q), 0.0, 1.0, fin_t)
		tw.tween_callback(aro.queue_free)


## Ceniza que cae del aro de fluido: motas beis alrededor de la circunferencia.
func _ceniza_aro(centro: Vector3, r: float, elemento: String) -> void:
	for i in range(8):
		var a: float = float(i) / 8.0 * TAU
		var pt: Vector3 = centro + Vector3(cos(a), 0.0, sin(a)) * r + Vector3(0.0, 0.3 * escala, 0.0)
		_estallido(pt, "humo", 3, 0.9, 0.5, 0.28, false, CENIZA, Vector3(0, -1.2, 0))


## Fragmentos que caen del aro sólido (tierra: piedras; hielo: cristales) y el aro desaparece.
func _fragmentos(centro: Vector3, r: float, tipo: String, aro: Node3D) -> void:
	for h in aro.get_children():
		(h as Node3D).visible = false
	var n: int = clampi(int(ceil(TAU * r / 0.5)), 10, 26)
	var nombre: String = "piedra" if tipo == "tierra" else "cristal_hielo"
	var color: Color = Color.WHITE
	for i in range(n):
		var a: float = float(i) / float(n) * TAU + randf() * 0.2
		var radial := Vector3(cos(a), 0.0, sin(a))
		var f: MeshInstance3D = _pieza(nombre, self, randf_range(0.22, 0.4) * escala, color)
		f.position = centro + radial * r + Vector3(0.0, randf_range(0.25, 0.6) * escala, 0.0)
		var tw := f.create_tween().set_parallel(true)
		tw.tween_property(f, "position", centro + radial * (r + randf_range(0.1, 0.45)) + Vector3(0.0, 0.05, 0.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(f, "rotation", Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3)), 0.5)
		tw.chain().tween_property(f, "scale", Vector3.ZERO, 0.3)
		tw.chain().tween_callback(f.queue_free)
		if i % 3 == 0:
			_despues(0.45, _estallido.bind(centro + radial * r + Vector3(0, 0.1, 0), "piedrecitas" if tipo == "tierra" else "copo", 5, 0.6, 1.8, 0.18, false, Color.WHITE, Vector3(0, -6, 0)))
	_temblor(0.05)


## --- CÚPULA (barrera de referencia: vídeos de tools/) y PERFILES de elemento ---
## Idea de diseño (Pablo, 6/10): forma = geometría + movimiento; elemento = DATOS. Un perfil es una fila de esta tabla; una
## combinación nueva (vapor, tormenta, lo que decida el Juego) es una fila nueva, no código nuevo en cada forma. Los casos
## especiales (el modelo de energía del rayo, la piedra de la tierra) se afinan después sobre los perfiles.
## Campos: nucleo = color del interior (alfa = opacidad) · borde = color del borde brillante · flujo = hacia dónde corre el
## ruido (en unidades de modelo por segundo) · escala = tamaño del ruido · venas = 0..1 relámpagos sobre la superficie ·
## facetas = 0 (suave) o nº de niveles (aspecto cristal) · llamas = 0..1 más densidad abajo · particula = pieza que flota dentro.
const PERFIL: Dictionary = {
	"fuego": {"nucleo": Color(1.0, 0.5, 0.08, 0.34), "borde": Color(1.0, 0.82, 0.25), "flujo": Vector3(0.0, -0.9, 0.0),
		"escala": 2.6, "venas": 0.0, "facetas": 0, "llamas": 1.0, "particula": "brasa", "luz": Color(1.0, 0.6, 0.25)},
	"agua": {"nucleo": Color(0.3, 0.62, 1.0, 0.30), "borde": Color(0.65, 0.9, 1.0), "flujo": Vector3(0.0, -0.18, 0.1),
		"escala": 1.6, "venas": 0.0, "facetas": 0, "llamas": 0.0, "particula": "burbuja", "luz": Color(0.45, 0.75, 1.0)},
	"tierra": {"nucleo": Color(0.52, 0.38, 0.22, 0.38), "borde": Color(0.85, 0.66, 0.4), "flujo": Vector3(0.0, 0.0, 0.0),
		"escala": 3.2, "venas": 0.0, "facetas": 5, "llamas": 0.0, "particula": "piedrecitas", "luz": Color(0.85, 0.66, 0.4)},
	"viento": {"nucleo": Color(0.55, 0.95, 0.8, 0.34), "borde": Color(0.9, 1.0, 0.95), "flujo": Vector3(1.4, 0.0, 0.0),
		"escala": 1.4, "venas": 0.0, "facetas": 0, "llamas": 0.0, "particula": "hoja", "luz": Color(0.75, 0.97, 0.85)},
	"rayo": {"nucleo": Color(0.2, 0.45, 0.95, 0.30), "borde": Color(0.5, 0.82, 1.0), "flujo": Vector3(0.2, -0.3, 0.0),
		"escala": 1.9, "venas": 1.0, "facetas": 0, "llamas": 0.0, "particula": "chispa_electrica", "luz": Color(0.45, 0.75, 1.0)},
	"hielo": {"nucleo": Color(0.6, 0.88, 1.0, 0.42), "borde": Color(0.92, 1.0, 1.0), "flujo": Vector3(0.0, 0.0, 0.0),
		"escala": 3.0, "venas": 0.0, "facetas": 4, "llamas": 0.0, "particula": "copo", "luz": Color(0.72, 0.92, 1.0)},
}
const CODIGO_CUPULA: String = """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
uniform vec4 nucleo : source_color;
uniform vec4 borde : source_color;
uniform vec3 flujo;
uniform float escala = 2.0;
uniform float venas = 0.0;
uniform float facetas = 0.0;
uniform float llamas = 0.0;
uniform float aparece = 1.0;   // 0..1 crece desde el suelo, y se apaga al final
varying vec3 p_mod;
float h31(vec3 p) { p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3)); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float ruido(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1,0,0)), f.x), mix(h31(i + vec3(0,1,0)), h31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h31(i + vec3(0,0,1)), h31(i + vec3(1,0,1)), f.x), mix(h31(i + vec3(0,1,1)), h31(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 x) { float a = 0.5; float r = 0.0; for (int k = 0; k < 3; k++) { r += a * ruido(x); x *= 2.03; a *= 0.5; } return r; }
void vertex() { p_mod = VERTEX; }
void fragment() {
	vec3 q = p_mod * escala + flujo * TIME;
	q.y *= mix(1.0, 0.35, llamas);
	float n = smoothstep(0.25, 0.8, fbm(q));
	if (facetas > 0.5) { n = floor(n * facetas) / facetas; }
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	float alt = clamp(p_mod.y * 1.0 + 0.5, 0.0, 1.0);        // 0 abajo, 1 arriba (modelo de radio 0,5)
	float base = mix(1.0, 1.0 - alt, llamas);                  // las llamas se concentran abajo
	float cuerpo = nucleo.a * (0.35 + 1.6 * n) * (0.45 + 0.55 * base);
	float vena = 0.0;
	if (venas > 0.0) {
		float t = floor(TIME * 9.0);
		float m = fbm(p_mod * escala * 1.6 + vec3(t * 0.37, t * 0.11, 0.0));
		vena = (1.0 - smoothstep(0.0, 0.035, abs(m - 0.5))) * step(0.55, h31(vec3(t, floor(p_mod.y * 3.0), 1.0)) ) * venas;
	}
	float corte = smoothstep(aparece - 0.04, aparece, alt);   // la cúpula sube del suelo hacia arriba
	vec3 col = mix(nucleo.rgb, borde.rgb, clamp(fres * 1.2 + n * 0.25 * llamas + vena, 0.0, 1.0));
	ALBEDO = col + vena * vec3(1.0);
	ALPHA = clamp(cuerpo + fres * 0.7 + vena * 0.9, 0.0, 0.92) * (1.0 - corte);
}
"""
var _sh_cupula: Shader = null


## 6.19 CÚPULA DE TIERRA: una esfera (hemisferio) de rocas alrededor del punto. Las rocas brotan del suelo de abajo arriba, se
## quedan `dura` s y al acabar CAYERON hacia fuera y se rompen (el aire entre rocas deja ver al jugador). Solo la imagen.
func _cupula_roca(centro: Vector3, r: float, dura: float) -> void:
	var raiz := Node3D.new()
	raiz.position = centro
	add_child(raiz)
	var n: int = clampi(int(round(r * r * 9.0)), 14, 30)
	var dorada: float = PI * (3.0 - sqrt(5.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(centro.x * 31.0 + centro.z * 17.0) + 3
	var piezas: Array = []
	for i in range(n):
		var yn: float = (float(i) + 0.5) / float(n)               # 0 = base, 1 = coronilla
		var altura: float = lerpf(0.02, 0.98, yn)
		var rad_h: float = sqrt(maxf(1.0 - altura * altura, 0.0))
		var a: float = float(i) * dorada
		var pos := Vector3(cos(a) * rad_h, altura, sin(a) * rad_h) * r
		var tam: float = (0.4 + 0.14 * rng.randf()) * escala * clampf(r / 1.4, 0.8, 1.4)
		var pz: MeshInstance3D = _pieza("piedra", raiz, tam, Color.WHITE)
		pz.position = pos + Vector3(0.0, -0.3 * escala, 0.0)
		pz.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		pz.scale = Vector3.ONE * 0.05
		pz.visible = false
		piezas.append([pz, pos, yn])
		var tw := pz.create_tween()
		tw.tween_interval(0.05 + 0.5 * yn)
		tw.tween_callback(pz.set.bind("visible", true))
		tw.tween_property(pz, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(pz, "position", pos, 0.2).set_ease(Tween.EASE_OUT)
		if i % 6 == 0:
			_despues(0.05 + 0.5 * yn, _estallido.bind(centro + pos, "piedrecitas", 5, 0.5, 1.6, 0.14, false, Color.WHITE, Vector3(0, -6, 0)))
	_despues(0.3, _temblor.bind(0.07))
	_luz(centro + Vector3(0.0, r * 0.4, 0.0), COLOR["tierra"], 1.0, 3.0 + r, minf(dura, 1.0))
	var fin := raiz.create_tween()
	fin.tween_interval(0.7 + maxf(dura - 0.7, 0.3))
	fin.tween_callback(_romper.bind(raiz))
	fin.tween_callback(_temblor.bind(0.05))


## Cúpula esférica del elemento sobre el punto (la barrera de los vídeos de referencia): sube del suelo, flota con el ruido del
## elemento y se hunde al final. Solo dibuja. `radio` en unidades de mundo.
func _cupula(elemento: String, pie_origen: Vector3, centro: Vector3, radio: float, dura: float) -> void:
	_carga(elemento, pie_origen)
	if elemento == "tierra":
		_cupula_roca(centro, maxf(radio, 0.8) * escala, dura)
		return
	if _estilo_nuevo(elemento):
		# Cintas que giran y convergen en un aro + media esfera luminosa. La raíz nace en `centro`, como la de la cúpula de siempre.
		VfxKit3D.cupula(self, centro, maxf(radio, 0.6) * escala, dura, escala)
		return
	var perfil: Dictionary = PERFIL.get(elemento, PERFIL["fuego"])
	if _sh_cupula == null:
		_sh_cupula = Shader.new()
		_sh_cupula.code = CODIGO_CUPULA
	var r: float = maxf(radio, 0.6) * escala
	var raiz := Node3D.new()
	raiz.position = centro
	add_child(raiz)
	var malla := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 28
	sm.rings = 14
	malla.mesh = sm
	var mat := ShaderMaterial.new()
	mat.shader = _sh_cupula
	for k in ["nucleo", "borde", "flujo", "escala", "venas", "facetas", "llamas"]:
		var v: Variant = perfil[k]
		mat.set_shader_parameter(k, float(v) if v is int else v)
	mat.set_shader_parameter("aparece", 0.0)
	malla.material_override = mat
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	malla.scale = Vector3.ONE * (2.0 * r)
	malla.position = Vector3(0.0, r * 0.6, 0.0)      # esfera casi entera sobre el suelo (como en la referencia)
	raiz.add_child(malla)
	var gp: GPUParticles3D = _particulas(String(perfil["particula"]), 14, 1.4, 0.4, 0.12, true, COLOR[elemento], Vector3(0, 0.3, 0))
	(gp.process_material as ParticleProcessMaterial).emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	(gp.process_material as ParticleProcessMaterial).emission_sphere_radius = r * 0.8
	gp.position = Vector3(0.0, r * 0.6, 0.0)
	raiz.add_child(gp)
	_luz(centro + Vector3(0.0, r * 0.6, 0.0), perfil["luz"], 1.4, 3.0 + radio, minf(dura, 1.2))
	var tw := raiz.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("aparece", v), 0.0, 1.05, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dura - 0.9, 0.2))
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("aparece", v), 1.05, 0.0, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(gp.set.bind("emitting", false))
	tw.tween_interval(1.0)
	tw.tween_callback(raiz.queue_free)


## TORMENTA (5.11): nubes oscuras estáticas sobre el área (`radio`, centro = pie_destino) que sueltan un rayo cada
## ~0,8 s sobre una casilla de debajo. Solo dibuja; el daño del rayo (y su `impacto`) son cosa del Lanzador, que puede
## llamar a `lanzar_forma("columna", "rayo", ...)` cuando quiera dañar. El elemento es siempre rayo+viento.
func _tormenta(centro: Vector3, radio: float, dura: float) -> void:
	var r: float = radio * escala
	var raiz := Node3D.new()
	raiz.position = centro + Vector3(0.0, 3.3 * escala, 0.0)
	raiz.scale = Vector3.ONE * 0.05
	add_child(raiz)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.38, 0.46)
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var rng := RandomNumberGenerator.new()
	rng.seed = int(centro.x * 73.0 + centro.z * 131.0) + 7
	var n_nubes: int = clampi(int(ceil(r / 0.9)) + 2, 3, 6)
	var nubes: Array = []
	for i in range(n_nubes):
		var a: float = TAU * float(i) / float(n_nubes) + rng.randf() * 0.5
		var d: float = r * (0.25 + 0.55 * rng.randf()) * (0.0 if i == 0 else 1.0)
		var nube := Node3D.new()
		nube.position = Vector3(cos(a) * d, rng.randf_range(-0.15, 0.15) * escala, sin(a) * d)
		raiz.add_child(nube)
		nubes.append(nube)
		for j in range(4):
			var esf := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 10
			sm.rings = 5
			esf.mesh = sm
			var mi: StandardMaterial3D = mat.duplicate()
			mi.albedo_color = mat.albedo_color.lightened(rng.randf_range(-0.05, 0.12))
			esf.material_override = mi
			esf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var t: float = float(j) - 1.5
			esf.position = Vector3(t * 0.42, rng.randf_range(-0.05, 0.1), rng.randf_range(-0.2, 0.2)) * escala
			esf.scale = Vector3(1.0, 0.6, 0.85) * rng.randf_range(0.8, 1.25) * escala
			nube.add_child(esf)
		var deriva := nube.create_tween().set_loops()
		var x0: float = nube.position.x
		deriva.tween_property(nube, "position:x", x0 + 0.25 * escala, 2.0 + 0.3 * float(i)).set_trans(Tween.TRANS_SINE)
		deriva.tween_property(nube, "position:x", x0 - 0.25 * escala, 2.0 + 0.3 * float(i)).set_trans(Tween.TRANS_SINE)
	var tw := raiz.create_tween()
	tw.tween_property(raiz, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var t_fin: float = maxf(dura, 1.5)
	var n_rayos: int = int(t_fin / 0.8)
	for k in range(n_rayos):
		var cuando: float = 0.7 + 0.8 * float(k) + rng.randf() * 0.3
		var a2: float = rng.randf() * TAU
		var d2: float = r * sqrt(rng.randf())
		var suelo: Vector3 = centro + Vector3(cos(a2) * d2, 0.0, sin(a2) * d2)
		_despues(cuando, _rayo_de_nube.bind(suelo, raiz))
	var fin := raiz.create_tween()
	fin.tween_interval(t_fin)
	fin.tween_property(raiz, "scale", Vector3.ONE * 0.02, 0.6).set_ease(Tween.EASE_IN)
	fin.tween_callback(raiz.queue_free)


## Un rayo de la tormenta: bajada parpadeante + destello + chispas. Sin marca, sin temblor y sin señal `impacto`.
func _rayo_de_nube(suelo: Vector3, raiz: Node3D) -> void:
	if not is_instance_valid(raiz):
		return
	var alto: float = 3.3 * escala
	var rayo: MeshInstance3D = _pieza_de_pie("rayo", suelo, 1.0, Color.WHITE)
	rayo.scale = Vector3(1.2, alto, 1.2)
	var tw := rayo.create_tween()
	for i in range(2):
		tw.tween_callback(rayo.set.bind("visible", true))
		tw.tween_interval(0.05)
		tw.tween_callback(rayo.set.bind("visible", false))
		tw.tween_interval(0.04)
	tw.tween_callback(rayo.set.bind("visible", true))
	tw.tween_interval(0.1)
	tw.tween_callback(rayo.queue_free)
	_estallido(suelo + Vector3(0, 0.3, 0), "chispa_electrica", 8, 0.45, 2.2, 0.3, true, Color.WHITE, Vector3.ZERO, 1, true)
	_luz(suelo + Vector3(0, 1.4, 0), COLOR["rayo"], 3.0, 5.0, 0.3)


## Una sola manifestación alta (dos niveles de bloque) en el punto.
func _columna(elemento: String, pie_origen: Vector3, destino: Vector3, dura: float) -> void:
	_carga(elemento, pie_origen)
	var c: Color = COLOR[elemento]
	_despues(0.25, _marca.bind("circulo_runico", destino, 1.7 / escala, Color(c.r, c.g, c.b, 0.6), dura))
	_brote(elemento, destino, 1.1, 2.1, 0.25, dura, false)
	_despues(0.25, _luz.bind(destino + Vector3(0.0, 1.0, 0.0), c, 1.8, 4.0, minf(dura, 1.2)))
	if elemento == "tierra":
		_despues(0.3, _temblor.bind(0.08))


## MURO = una PARED continua del elemento (no una cuadrícula de brotes): `semiancho` * 2 + 0,6 de largo, perpendicular a
## origen -> destino y con su centro un poco por delante de `inicio`. Cada elemento la dibuja a su manera (`_pared`).
func _muro(elemento: String, pie_origen: Vector3, inicio: Vector3, semiancho: float, dura: float) -> void:
	_carga(elemento, pie_origen)
	var dir := Vector3(inicio.x - pie_origen.x, 0.0, inicio.z - pie_origen.z)
	if dir.length() < 0.01:
		dir = Vector3(0.0, 0.0, 1.0)
	dir = dir.normalized()
	var lado := Vector3(-dir.z, 0.0, dir.x)
	if _estilo_nuevo(elemento):
		VfxKit3D.muro(self, pie_origen, inicio + dir * 0.2 * escala, lado, (semiancho * 2.0 + 0.6) * escala, 1.7 * escala, dura, escala)
		return
	_pared(elemento, inicio + dir * 0.2 * escala, lado, semiancho * 2.0 + 0.6, 1.7, 0.25, dura)


## Una PARED continua de `elemento`: `largo` x `alto` (unidades; se multiplican por `escala`), centrada en `centro` (en el suelo)
## y extendida a lo largo de `lado`. Aparece tras `retraso` s, dura `dura` s y se hunde.
##   fuego: facetas amarillo → naranja con puntas (la referencia fire_ring) · agua: cortina con cresta ondulada ·
##   tierra: hilera de bloques de tierra pegados, de alturas distintas · viento: lámina ondulada de aire con hojas ·
##   rayo: plasma en zigzag que parpadea · hielo: cristales fundidos en una pared de puntas.
## `extras` = false (los tramos del corro, salvo uno de cada cuatro) omite luz, partículas, temblor y polvo: un anillo junta
## 8-18 tramos y no hace falta una luz y un emisor por cada uno.
func _pared(elemento: String, centro: Vector3, lado: Vector3, largo: float, alto: float, retraso: float, dura: float,
		extras: bool = true) -> void:
	var rot: float = atan2(-lado.z, lado.x)
	var w: float = largo * escala
	var h: float = alto * escala
	var c: Color = COLOR[elemento]
	if elemento == "rayo" and _cargar_energia():
		var s_e: float = h / ALTO_ENERGIA / 1.0
		var ne: int = maxi(1, int(round(w / (_e_ancho * s_e))))
		for i in range(ne):
			var f: float = (float(i) + 0.5) / float(ne) - 0.5
			var lleno_e := Vector3(w / float(ne) / _e_ancho, s_e, s_e)
			var giro_e: float = rot + (PI if i % 2 == 1 else 0.0)
			_roca(_e_tramos[i % 2] as Mesh, centro + lado * (f * w), giro_e, lleno_e, retraso + 0.04 * absf(f) * float(ne), dura)
		if extras:
			_despues(retraso, _estallido.bind(centro + Vector3(0, 0.5, 0), "chispa_electrica", 10, 0.5, 2.0, 0.4, true, Color.WHITE, Vector3.ZERO))
			_despues(retraso, _luz.bind(centro + Vector3(0.0, h * 0.6, 0.0), Color(0.4, 0.7, 1.0), 1.6, 3.0 + w * 0.4, minf(dura, 1.2)))
		return
	if elemento == "tierra" and _cargar_piedra():
		# Hilera de tramos de roca pegados: cada uno estirado para que quepan justos, de alturas distintas.
		var s_u: float = 3.2 * escala      # la misma escala que el anillo del corro: las rocas se ven igual de grandes
		var nt: int = maxi(1, int(round(w / (_p_ancho * s_u))))
		for i in range(nt):
			var f: float = (float(i) + 0.5) / float(nt) - 0.5
			var var_h: float = 0.85 + 0.3 * float(((i + 1) * 7919) % 100) / 99.0
			var lleno := Vector3(w / float(nt) / _p_ancho, s_u * var_h * (h / (1.7 * escala)), s_u)
			var giro: float = rot + (PI if i % 2 == 1 else 0.0)
			_roca(_p_tramos[i % 2] as Mesh, centro + lado * (f * w), giro, lleno, retraso + 0.05 * absf(f) * float(nt), dura)
		if extras:
			_despues(retraso, _estallido.bind(centro + Vector3(0, 0.2, 0), "piedrecitas", 12, 0.9, 2.6, 0.2, false, Color.WHITE,
				Vector3(0, -7.0, 0)))
			_despues(retraso, _luz.bind(centro + Vector3(0.0, h * 0.5, 0.0), c, 0.8, 3.0, 0.4))
			_despues(retraso, _temblor.bind(0.06))
		return
	if elemento == "tierra":
		var n: int = maxi(2, int(ceil(w / 0.7)))
		for i in range(n):
			var f: float = (float(i) + 0.5) / float(n) - 0.5
			var altura: float = h * (0.78 + 0.22 * float(((i + 1) * 7919) % 100) / 99.0)
			var b: Node3D = _bloque_tierra(centro + lado * (f * w), w / float(n) * 1.04, altura / escala * escala,
				retraso + 0.05 * absf(f) * float(n), dura)
			b.rotation.y = rot
		if extras:
			_despues(retraso, _estallido.bind(centro + Vector3(0, 0.2, 0), "piedrecitas", 12, 0.9, 2.6, 0.2, false, Color.WHITE,
				Vector3(0, -7.0, 0)))
			_despues(retraso, _luz.bind(centro + Vector3(0.0, h * 0.5, 0.0), c, 0.8, 3.0, 0.4))
			_despues(retraso, _temblor.bind(0.06))
		return
	var raiz := Node3D.new()
	raiz.position = centro
	add_child(raiz)
	var m: MeshInstance3D = Formas3D.instancia("pared_" + elemento, Color.WHITE)
	m.rotation.y = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lleno := Vector3(w, h, 1.1 * escala)
	m.scale = Vector3(lleno.x, lleno.y * 0.05, lleno.z)
	m.visible = false
	raiz.add_child(m)
	var tw := m.create_tween()
	tw.tween_interval(retraso)
	tw.tween_callback(m.set.bind("visible", true))
	tw.tween_property(m, "scale", lleno, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if elemento == "fuego" or elemento == "agua":
		# ondula sin parar mientras dura
		var onda := m.create_tween().set_loops()
		onda.tween_interval(retraso + 0.22)
		onda.tween_property(m, "scale", Vector3(lleno.x, lleno.y * 1.07, lleno.z), 0.22).set_trans(Tween.TRANS_SINE)
		onda.tween_property(m, "scale", Vector3(lleno.x, lleno.y * 0.93, lleno.z), 0.28).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(maxf(dura, 0.0))
	tw.tween_property(m, "scale", Vector3(lleno.x, 0.0, lleno.z), 0.3).set_ease(Tween.EASE_IN)
	if elemento == "rayo":
		_parpadear(m, retraso, dura)
	# Partículas a lo largo de la pared (hijas de la raíz: giran con ella).
	var gp: GPUParticles3D = null
	match elemento if extras else "":
		"fuego":
			gp = _particulas("brasa", 16, 1.3, 1.3, 0.12, true, c, Vector3(0.0, -0.3, 0.0))
		"agua":
			gp = _particulas("gota", 16, 1.0, 2.2, 0.17, false, Color.WHITE, Vector3(0.0, -7.0, 0.0))
		"viento":
			gp = _particulas("hoja", 14, 1.4, 1.1, 0.2, false, Color.WHITE, Vector3(0.0, 0.2, 0.0))
		"rayo":
			gp = _particulas("chispa_electrica", 12, 0.5, 2.0, 0.35, true, Color.WHITE, Vector3.ZERO)
		"hielo":
			gp = _particulas("copo", 12, 1.3, 0.8, 0.17, true, c, Vector3(0.0, -0.4, 0.0))
	if gp != null:
		var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(w * 0.5, 0.04, 0.2 * escala)
		pm.direction = Vector3.UP
		pm.spread = 20.0
		gp.position = Vector3(0.0, 0.1, 0.0)
		gp.rotation.y = rot
		gp.emitting = false
		raiz.add_child(gp)
		_despues(retraso, gp.set.bind("emitting", true))
	if extras:
		_despues(retraso, _luz.bind(centro + Vector3(0.0, h * 0.6, 0.0), c, 1.6, 3.0 + w * 0.4, minf(dura, 1.2)))
	_despues(retraso + dura + 0.3, _soltar.bind(raiz))


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
			_despues(retraso, _onda.bind(suelo, "ondas", 0.3 * ancho, 1.5 * ancho, 0.8, Color(0.7, 0.9, 1.0, 0.8)))
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
			var r := _tallo("rayo", suelo, w * 0.8, h * (1.0 if ligero else 1.5), Color(1, 1, 1, 0.95), false, retraso, dura)
			_parpadear(r, retraso, dura)
			# Halo: el mismo rayo más ancho y muy translúcido (el resplandor que lo rodea).
			var halo := _tallo("rayo", suelo, w * 1.9, h * (1.0 if ligero else 1.5), Color(1.0, 0.9, 0.4, 0.28), false, retraso, dura)
			_parpadear(halo, retraso, dura)
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


## --- Tierra de piedra: la variante `stone_ring` (vfx/anillo_piedra.glb) ---
## Un anillo de rocas de 1 x 0,41 x 1 (radio medio 0,38, base en y = 0). El CORRO de tierra es el anillo entero; el MURO de
## tierra son tramos de ese mismo anillo DESENROLLADOS (un sector del círculo estirado en recta), así las dos formas llevan las
## mismas rocas. Si falta el .glb se usan los bloques de tierra de siempre.
const ANILLO_PIEDRA: String = "res://poc_25d/vfx/anillo_piedra.glb"
const R_PIEDRA: float = 0.38
const ALTO_PIEDRA: float = 0.41
static var _p_anillo: Mesh = null
static var _p_tramos: Array = []     ## Array[Mesh]: tramos rectos; su ancho en `_p_ancho`
static var _p_ancho: float = 1.0
static var _p_probado: bool = false


func _cargar_piedra() -> bool:
	if _p_probado:
		return _p_anillo != null
	_p_probado = true
	if not ResourceLoader.exists(ANILLO_PIEDRA):
		return false
	var ps: PackedScene = load(ANILLO_PIEDRA) as PackedScene
	if ps == null:
		return false
	var raiz: Node = ps.instantiate()
	var mi: MeshInstance3D = raiz as MeshInstance3D
	if mi == null:
		var l: Array = raiz.find_children("*", "MeshInstance3D", true, false)
		mi = l[0] as MeshInstance3D if not l.is_empty() else null
	if mi != null and mi.mesh != null:
		_p_anillo = mi.mesh
		var theta: float = deg_to_rad(42.0)
		_p_tramos = [_tramo_piedra(_p_anillo, 0.0, theta), _tramo_piedra(_p_anillo, PI, theta)]
		_p_ancho = 2.0 * theta * R_PIEDRA
	raiz.free()
	return _p_anillo != null


## Un tramo RECTO: los triángulos del anillo cuyo centro cae en el sector `centro` ± `theta`, desenrollados (x = arco, z = hacia
## dentro) y centrados en el origen. Conserva UV y material; las normales se giran con la roca.
func _tramo_piedra(malla: Mesh, centro: float, theta: float, radio_ref: float = R_PIEDRA, aplanar: float = 1.0,
		r_min: float = 0.16) -> Mesh:
	var res := ArrayMesh.new()
	for si in range(malla.get_surface_count()):
		var arr: Array = malla.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var nuevo := PackedInt32Array()
		var t: int = 0
		while t + 2 < idx.size():
			var m: Vector3 = (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
			var d: float = wrapf(atan2(m.z, m.x) - centro + PI, 0.0, TAU) - PI
			var r: float = Vector2(m.x, m.z).length()
			var cerca: bool = absf(d) <= theta and r > r_min
			for k in range(3):
				var qk: Vector3 = v[idx[t + k]]
				if absf(wrapf(atan2(qk.z, qk.x) - centro + PI, 0.0, TAU) - PI) > theta * 1.12:
					cerca = false      # un triángulo que se estira por el borde del sector saldría como una espina
			if cerca:
				nuevo.append(idx[t])
				nuevo.append(idx[t + 1])
				nuevo.append(idx[t + 2])
			t += 3
		var v2 := PackedVector3Array()
		v2.resize(v.size())
		var n2 := PackedVector3Array()
		n2.resize(v.size())
		for i in range(v.size()):
			var q: Vector3 = v[i]
			var phi: float = wrapf(atan2(q.z, q.x) - centro + PI, 0.0, TAU) - PI
			var rr: float = Vector2(q.x, q.z).length()
			var ang: float = phi + centro
			var e_t := Vector3(-sin(ang), 0.0, cos(ang))
			var e_r := Vector3(cos(ang), 0.0, sin(ang))
			v2[i] = Vector3(radio_ref * phi, q.y, (radio_ref - rr) * aplanar)
			if i < nn.size():
				var nv: Vector3 = nn[i]
				n2[i] = Vector3(nv.dot(e_t), nv.y, -nv.dot(e_r)).normalized()
		arr[Mesh.ARRAY_VERTEX] = v2
		if nn.size() == v.size():
			arr[Mesh.ARRAY_NORMAL] = n2
		arr[Mesh.ARRAY_TANGENT] = null
		arr[Mesh.ARRAY_INDEX] = nuevo
		res.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		res.surface_set_material(res.get_surface_count() - 1, malla.surface_get_material(si))
	return res


## Una malla de piedra de pie en `suelo`: crece, se queda `dura` s y se hunde.
func _roca(malla: Mesh, suelo: Vector3, giro: float, lleno: Vector3, retraso: float, dura: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = malla
	m.position = suelo
	m.rotation.y = giro
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.scale = Vector3(lleno.x, lleno.y * 0.05, lleno.z)
	m.visible = false
	add_child(m)
	var tw := m.create_tween()
	tw.tween_interval(retraso)
	tw.tween_callback(m.set.bind("visible", true))
	tw.tween_property(m, "scale", lleno, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dura, 0.0))
	tw.tween_property(m, "scale", Vector3(lleno.x, 0.0, lleno.z), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(m.queue_free)
	return m


## --- Rayo: la barrera de energía `energy_ring` (vfx/anillo_energia.glb) + el relampagueo del vídeo de Pablo ---
## Una cúpula de 1 x 0,78 x 1 (radio 0,49, base en y = 0) con ramas de rayo en relieve. El CORRO de rayo es la cúpula entera sobre
## el área; el MURO son dos tramos de esa cúpula aplanados en un panel. El material es un shader propio (sin luz, translúcido):
## borde azul brillante por fresnel, bruma azul que se mueve por dentro y tramos que se encienden de golpe en blanco.
const ENERGIA: String = "res://poc_25d/vfx/anillo_energia.glb"
const R_ENERGIA: float = 0.49
const ALTO_ENERGIA: float = 0.78
const CODIGO_ENERGIA: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform float brillo = 1.0;
varying vec3 vpos;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vpos = VERTEX;
}

void fragment() {
	float t = TIME;
	float fr = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float nb = vn(vpos.xz * 5.0 + vpos.y * 3.0 + vec2(t * 0.35, -t * 0.2)) * 0.6 + vn(vpos.xz * 11.0 - vec2(t * 0.5, 0.0)) * 0.4;
	vec3 nucleo = vec3(0.10, 0.28, 0.70) * (0.6 + 0.9 * nb);
	vec3 borde = vec3(0.32, 0.74, 1.0);
	vec3 col = mix(nucleo, borde, fr);
	float a = mix(0.22 + 0.22 * nb, 0.95, fr);
	float tramo = floor(t * 14.0);
	float zona = vn(vpos.xy * 7.0 + vec2(vpos.z * 5.0, tramo * 3.17));
	float chispa = smoothstep(0.74, 0.88, zona) * step(0.4, h(vec2(tramo, 3.0)));
	col += vec3(0.9, 0.95, 1.0) * chispa * 1.5;
	a = clamp(a + chispa * 0.7, 0.0, 1.0);
	float destello = step(0.94, h(vec2(floor(t * 9.0), 7.0)));
	col += vec3(0.5, 0.75, 1.0) * destello * 0.4;
	ALBEDO = col * brillo;
	ALPHA = a;
}
"""
static var _e_domo: Mesh = null
static var _e_tramos: Array = []
static var _e_ancho: float = 1.0
static var _e_probado: bool = false


func _cargar_energia() -> bool:
	if _e_probado:
		return _e_domo != null
	_e_probado = true
	if not ResourceLoader.exists(ENERGIA):
		return false
	var ps: PackedScene = load(ENERGIA) as PackedScene
	if ps == null:
		return false
	var raiz: Node = ps.instantiate()
	var mi: MeshInstance3D = raiz as MeshInstance3D
	if mi == null:
		var l: Array = raiz.find_children("*", "MeshInstance3D", true, false)
		mi = l[0] as MeshInstance3D if not l.is_empty() else null
	if mi != null and mi.mesh != null:
		var sh := Shader.new()
		sh.code = CODIGO_ENERGIA
		var mat := ShaderMaterial.new()
		mat.shader = sh
		var m: Mesh = mi.mesh.duplicate() as Mesh
		for i in range(m.get_surface_count()):
			m.surface_set_material(i, mat)
		_e_domo = m
		var theta: float = deg_to_rad(40.0)
		_e_tramos = [_tramo_piedra(m, 0.0, theta, R_ENERGIA, 0.3, 0.1), _tramo_piedra(m, PI, theta, R_ENERGIA, 0.3, 0.1)]
		_e_ancho = 2.0 * theta * R_ENERGIA
	raiz.free()
	return _e_domo != null


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


## 13/10 · Agua electrificada: chispas azules del rayo (los colores del hechizo de rayo, ESTILO["rayo"].borde), pocas,
## pequeñas y apagadas: se ve que hay corriente sin tapar el agua. Devuelve el emisor ya emitiendo; lo cuelga quien llama.
const COLOR_CHISPA_AGUA: Color = Color(0.5, 0.82, 1.0)
const BRILLO_CHISPA_AGUA: float = 0.55          ## 1 = como las chispas de la mano; menos = más apagadas


func chispas_agua(n: int = 4) -> GPUParticles3D:
	var gp: GPUParticles3D = _particulas("chispa_electrica", n, 0.35, 0.25, 0.07, true, COLOR_CHISPA_AGUA, Vector3.ZERO)
	var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	pm.spread = 180.0
	gp.local_coords = false
	atenuar(gp, BRILLO_CHISPA_AGUA)
	gp.emitting = true
	return gp


## Un chispazo pequeño y azul (el agua electrificada, de vez en cuando): menos piezas, más lento y con una luz corta y floja.
func chispazo_suave(p: Vector3, color: Color = COLOR_CHISPA_AGUA) -> void:
	_estallido(p, "destello", 3, 0.35, 0.9, 0.14, true, color * BRILLO_CHISPA_AGUA, Vector3.ZERO)
	_luz(p, color, 0.45, 1.6, 0.25)


## Baja el brillo de unas partículas (0..1): multiplica el color de su rampa. Para que un efecto sea más sutil sin cambiarlo.
static func atenuar(gp: GPUParticles3D, k: float) -> void:
	var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	if pm == null or pm.color_ramp == null:
		return
	var gt: GradientTexture1D = (pm.color_ramp as GradientTexture1D).duplicate() as GradientTexture1D
	var g: Gradient = gt.gradient.duplicate() as Gradient
	var cols: PackedColorArray = g.colors
	for i in range(cols.size()):
		var c: Color = cols[i]
		cols[i] = Color(c.r * k, c.g * k, c.b * k, c.a)
	g.colors = cols
	gt.gradient = g
	pm.color_ramp = gt


## Bocanada de vapor (el fuego sobre un charco, el agua sobre brasas): 2,5 s.
func vapor(p: Vector3) -> void:
	_estallido(p + Vector3(0.0, 0.3, 0.0), "humo", 9, 2.5, 0.8, 0.8, false, Color(0.95, 0.95, 1.0), Vector3(0, 0.7, 0))


## SALPICADURA en el agua (algo que emerge o cae a la superficie, p. ej. las losas del puente reactivo). Tres capas:
##   · dos anillos de onda que se abren y se desvanecen (lo que más comunica «toca agua»), el segundo algo después
##   · un chorro de gotas hacia arriba (partículas, una sola ráfaga)
##   · una bruma blanca que sube y se va
## `p` = punto sobre la superficie del agua; `tam` escala todo.
const CODIGO_ONDA_AGUA: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float avance : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.88, 0.96, 1.0, 1.0);
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float radio = mix(0.12, 0.95, 1.0 - pow(1.0 - avance, 2.0));
	float grosor = mix(0.12, 0.05, avance);
	float aro = smoothstep(grosor, 0.0, abs(d - radio));
	ALBEDO = color.rgb;
	ALPHA = aro * smoothstep(1.0, 0.8, d) * (1.0 - avance) * color.a;
}
"""
var _sombreado_onda: Shader = null


func salpicadura(p: Vector3, tam: float = 1.0) -> void:
	if _sombreado_onda == null:
		_sombreado_onda = Shader.new()
		_sombreado_onda.code = CODIGO_ONDA_AGUA
	for k in range(2):
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE * 3.4 * tam * escala
		var mat := ShaderMaterial.new()
		mat.shader = _sombreado_onda
		pm.material = mat
		mi.mesh = pm
		mi.position = p + Vector3(0.0, 0.04 + 0.003 * float(k), 0.0)
		mi.visible = false
		add_child(mi)
		var tw := mi.create_tween()
		tw.tween_interval(0.16 * float(k))
		tw.tween_callback(mi.set.bind("visible", true))
		tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("avance", v), 0.0, 1.0, 0.85)
		tw.tween_callback(mi.queue_free)
	var gp := _particulas("gota", 18, 0.9, 3.2 * tam, 0.14, false, Color(0.88, 0.96, 1.0), Vector3(0.0, -9.0, 0.0))
	gp.one_shot = true
	gp.explosiveness = 0.95
	var pr: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	pr.direction = Vector3.UP
	pr.spread = 38.0
	pr.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pr.emission_sphere_radius = 0.35 * tam * escala
	gp.position = p + Vector3(0.0, 0.05, 0.0)
	add_child(gp)
	gp.emitting = true
	_despues(1.3, gp.queue_free)
	_estallido(p + Vector3(0.0, 0.15, 0.0), "humo", 4, 0.9, 0.5 * tam, 0.45 * tam, false, Color(1.0, 1.0, 1.0, 0.55), Vector3(0.0, 0.3, 0.0))


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


func _proyectil(elemento: String, origen: Vector3, destino: Vector3, y_suelo: float, f: float = 1.0) -> void:
	var cabeza := Node3D.new()
	add_child(cabeza)
	cabeza.position = origen
	var c: Color = COLOR[elemento]
	# La pieza (llama, gota, cristal, remolino) es larga en +Y: se tumba 90° para que su punta mire hacia donde va el hechizo
	# (giro de la flecha + elemento). Su giro propio (`_girar`) pasa a ser alrededor del eje de avance.
	var avance: Vector3 = (destino - origen).normalized()
	if avance.length() < 0.01:
		avance = Vector3.FORWARD
	var lat: Vector3 = Vector3.UP.cross(avance)
	if lat.length() < 0.01:
		lat = Vector3.RIGHT
	lat = lat.normalized()
	var pivote := Node3D.new()
	pivote.basis = Basis(lat, avance, lat.cross(avance).normalized())
	cabeza.add_child(pivote)
	match elemento:
		"fuego":
			if estilo_fuego_nuevo:
				# Bola luminosa con cola de cometa (VfxKit3D): se estira con la velocidad.
				VfxKit3D.bola(cabeza, avance, f, escala, velocidad)
			else:
				# Bola de fuego: núcleo amarillo opaco + envoltura naranja de llamas (shader de cúpula) + estela de brasas y humo.
				_esfera_perfil(cabeza, "fuego", 0.2 * f * escala)
				_esfera_plana(cabeza, 0.11 * f * escala, Color(1.0, 0.95, 0.55))
				_estela(cabeza, "brasa", 24, 0.45, 0.1 * f, true, c)
				_estela(cabeza, "llama", 10, 0.35, 0.22 * f, false, Color.WHITE)
				_estela(cabeza, "humo", 8, 0.6, 0.22 * f, false, Color.WHITE)
		"rayo":
			# Bola eléctrica: núcleo blanco y envoltura azul con relámpagos que saltan por la superficie + chispas.
			_esfera_perfil(cabeza, "rayo", 0.2 * f * escala)
			_esfera_plana(cabeza, 0.1 * f * escala, Color(0.92, 0.97, 1.0))
			_estela(cabeza, "chispa_electrica", 18, 0.3, 0.14 * f, true, Color.WHITE)
		"tierra":
			var pe: MeshInstance3D = _pieza("piedra", pivote, 0.34 * f * escala, Color.WHITE)
			_girar(pe, 0.5)
			_estela(cabeza, "piedrecitas", 10, 0.4, 0.1 * f, false, Color.WHITE)
			_estela(cabeza, "polvo", 6, 0.5, 0.2 * f, false, Color.WHITE)
		"agua":
			if _estilo_nuevo("agua"):
				# Kit luminoso con la rampa del agua: bola con cola, como la de fuego.
				VfxKit3D.bola(cabeza, avance, f, escala, velocidad)
			else:
				var gota: MeshInstance3D = _pieza("gota", pivote, 0.34 * f * escala, Color.WHITE)
				_girar(gota, 0.6)
				_estela(cabeza, "gota", 20, 0.35, 0.11 * f, false, Color.WHITE)
				_estela(cabeza, "burbuja", 6, 0.6, 0.1 * f, false, Color.WHITE)
		"viento":
			var r: MeshInstance3D = _pieza("remolino_viento", pivote, 0.65 * f * escala, Color.WHITE)
			r.position.y = -0.32 * f * escala
			_girar(r, 0.3)
			_estela(cabeza, "hoja", 10, 0.6, 0.13 * f, false, Color.WHITE)
		"hielo":
			# Carámbano: el cristal, alargado en el eje de avance.
			var cr: MeshInstance3D = _pieza("cristal_hielo", pivote, 0.36 * f * escala, Color.WHITE)
			cr.position.y = -0.16 * f * escala
			cr.scale = Vector3(0.8, 1.5, 0.8)
			_girar(cr, 0.8)
			_estela(cabeza, "copo", 18, 0.5, 0.1 * f, true, c)
	if con_luces:
		var l := OmniLight3D.new()
		l.light_color = c
		l.light_energy = 1.0
		l.omni_range = 2.5 * escala
		cabeza.add_child(l)
		if elemento == "fuego" and _estilo_nuevo(elemento):
			l.light_energy = 1.8
			VfxKit3D.parpadeo(l)
	var t: float = maxf(0.15, origen.distance_to(destino) / maxf(velocidad, 0.1))
	var tw2 := cabeza.create_tween()
	tw2.tween_method(_mover_proyectil.bind(cabeza, origen, destino), 0.0, 1.0, t)
	tw2.tween_callback(_llegar.bind(elemento, cabeza, y_suelo))


## Esfera de baja poligonización con el shader de cúpula y el PERFIL del elemento (envoltura de llamas, de relámpagos...).
func _esfera_perfil(padre: Node3D, elemento: String, radio: float) -> MeshInstance3D:
	if _sh_cupula == null:
		_sh_cupula = Shader.new()
		_sh_cupula.code = CODIGO_CUPULA
	var perfil: Dictionary = PERFIL[elemento]
	var mat := ShaderMaterial.new()
	mat.shader = _sh_cupula
	for k in ["nucleo", "borde", "flujo", "escala", "venas", "facetas", "llamas"]:
		var v: Variant = perfil[k]
		mat.set_shader_parameter(k, float(v) if v is int else v)
	mat.set_shader_parameter("aparece", 1.1)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 14
	sm.rings = 7
	mi.mesh = sm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * (2.0 * radio)
	padre.add_child(mi)
	return mi


## Esfera plana sin luz (el núcleo de las bolas).
func _esfera_plana(padre: Node3D, radio: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * (2.0 * radio)
	padre.add_child(mi)
	return mi


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
		"tierra":
			_impacto_tierra(Vector3(p.x, y_suelo, p.z))
		"rayo":
			_impacto_rayo(Vector3(p.x, y_suelo, p.z))
	_soltar(cabeza)


## --- Impactos ---

func _impacto_fuego(p: Vector3, y_suelo: float) -> void:
	if estilo_fuego_nuevo:
		VfxKit3D.impacto(self, p, y_suelo, escala)
		impacto.emit("fuego", p)
		return
	var c: Color = COLOR["fuego"]
	_estallido(p, "llama", 14, 0.7, 2.2, 0.55, false, Color.WHITE, Vector3(0, 1.2, 0))
	_estallido(p, "brasa", 24, 1.2, 3.5, 0.13, true, c, Vector3(0, -2.0, 0))
	_estallido(p + Vector3(0, 0.3, 0), "humo", 8, 1.8, 0.8, 0.7, false, Color.WHITE, Vector3(0, 0.8, 0))
	_marca("quemado", Vector3(p.x, y_suelo, p.z), 0.9, Color(0.33, 0.24, 0.2), 10.0)      # el chamusco se queda un buen rato
	_luz(p, c, 2.0, 4.0, 0.6)
	impacto.emit("fuego", p)


func _impacto_agua(p: Vector3, y_suelo: float) -> void:
	if _estilo_nuevo("agua"):
		VfxKit3D.impacto(self, p, y_suelo, escala)
		impacto.emit("agua", p)
		return
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
	return color if forma == "rayo" else Color(color, 1.0)       # el halo del rayo pide alfa propio


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
	if (n as Node).has_meta("tramo_celda"):      # un tramo de pared de fuego larga: apaga SOLO esa casilla (7.11)
		var ce: Vector2i = (n as Node).get_meta("tramo_celda")
		(n as Node).queue_free()
		apagar_tramo(null, ce)
		return
	for h in n.get_children():
		if h is GPUParticles3D:
			(h as GPUParticles3D).emitting = false
		elif h is MeshInstance3D or h is OmniLight3D:
			(h as Node3D).visible = false
	_despues(1.0, n.queue_free)


func _despues(t: float, f: Callable) -> void:
	get_tree().create_timer(t, false).timeout.connect(f)
