class_name Vfx3D
extends Node3D

## EFECTOS DE ELEMENTO en 3D con los sprites pastel de poc_25d/vfx/ (fuego, agua, tierra, viento, rayo,
## hielo). Cada hechizo = carga en el lanzador (círculo rúnico) + proyectil con estela + impacto
## (estallido de partículas, destello de luz, marca en el suelo). Todo se borra solo al terminar.
##
##   var fx := Vfx3D.new()
##   add_child(fx)
##   fx.lanzar("fuego", Vector3(0, 0.6, 0), Vector3(4, 0.6, 0))
##   fx.lanzar_forma("columna", "hielo", pie_lanzador, pie_destino)   # 6 elementos x 4 formas
##
## `escala` agranda o encoge todos los efectos; `velocidad` cambia lo que tarda el proyectil.

signal impacto(elemento: String, punto: Vector3)

const VFX: String = "res://poc_25d/vfx/"
const ELEMENTOS: Array = ["fuego", "agua", "tierra", "viento", "rayo", "hielo"]
## Formas de un hechizo (la matriz receta -> forma de DISENO_FUTURO §3 reducida a lo que necesita el Test 3).
## proyectil = vuela hasta el punto · corro = anillo de manifestaciones alrededor del punto ·
## columna = una sola, alta y sólida, en el punto · muro = una fila que avanza desde el punto hacia donde se apunta.
const FORMAS: Array = ["proyectil", "corro", "columna", "muro"]
const COLOR: Dictionary = {
	"fuego": Color(1.0, 0.55, 0.25), "agua": Color(0.45, 0.75, 1.0), "tierra": Color(0.85, 0.66, 0.40),
	"viento": Color(0.75, 0.97, 0.85), "rayo": Color(1.0, 0.93, 0.40), "hielo": Color(0.72, 0.92, 1.0),
}

@export var escala: float = 1.0
@export var velocidad: float = 7.0       ## unidades por segundo del proyectil
@export var con_luces: bool = true

var _texturas: Dictionary = {}
var _materiales: Dictionary = {}      ## los StandardMaterial3D se reutilizan (no se tocan después de crearlos)


## Carga todas las texturas de vfx/ y lanza cada elemento una vez de `origen` a `destino`: Godot compila
## así los shaders de materiales y partículas de golpe (sin esto, el primer hechizo de cada uno da un tirón).
## `con_formas` lanza además una columna de cada elemento (los sprites altos y los chorros de partículas).
func precalentar(origen: Vector3, destino: Vector3, con_formas: bool = false) -> void:
	for f in DirAccess.get_files_at(VFX):
		var nombre: String = String(f).trim_suffix(".import").trim_suffix(".remap")
		if nombre.get_extension().to_lower() == "png":
			_tex(nombre.get_basename())
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
	var f := _particulas("llama_tira8", int(5.0 + 7.0 * esc), 0.8, 0.5, 0.55 * esc, true, Color(1, 1, 1, 0.85),
		Vector3(0.0, 0.5, 0.0), 8)
	_caja_emision(f, radio, Vector3(0.0, 0.25 * esc, 0.0))
	raiz.add_child(f)
	f.emitting = true
	if esc > 0.7:
		var b := _particulas("brasa", 4, 1.4, 0.8, 0.12, true, COLOR["fuego"], Vector3(0.0, -0.3, 0.0))
		_caja_emision(b, radio, Vector3(0.0, 0.3, 0.0))
		raiz.add_child(b)
		b.emitting = true
		var h := _particulas("humo", 4, 3.0, 0.5, 0.8, false, Color(1, 1, 1, 0.4), Vector3(0.0, 0.4, 0.0))
		_caja_emision(h, radio * 0.5, Vector3(0.0, 0.8, 0.0))
		raiz.add_child(h)
		h.emitting = true
		if con_luces:
			var l := OmniLight3D.new()
			l.light_color = COLOR["fuego"]
			l.light_energy = 0.7
			l.omni_range = 2.6 * escala
			l.position = Vector3(0.0, 0.8, 0.0)
			raiz.add_child(l)
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
			# Llamas que ascienden (la misma tira de 8 fotogramas que la hierba ardiendo), brasas y humo.
			_chorro(suelo, "llama_tira8", int((5.0 + 7.0 * alto) * k), 0.8, 0.7 + alto * 1.5, 0.34 + 0.2 * alto,
				false, Color(1, 1, 1, 0.9), Vector3(0.0, 0.8 + alto * 1.2, 0.0), w * 0.5, retraso, dura, 8)
			_chorro(suelo, "brasa", int((4.0 + 3.0 * alto) * k), 1.3, 0.8 + alto * 0.5, 0.12, true, c,
				Vector3(0.0, -0.2, 0.0), w * 0.5, retraso, dura)
			if not ligero:
				_chorro(suelo + Vector3(0.0, h * 0.7, 0.0), "humo", 4, 2.6, 0.4, 0.8, false, Color(1, 1, 1, 0.4),
					Vector3(0.0, 0.4, 0.0), w * 0.4, retraso, dura)
		"agua":
			# Chorro: salpicadura alta que se encoge y gotas que suben y caen.
			_tallo("salpicadura", suelo, w * 1.1, h * 0.85, Color(1, 1, 1, 0.92), false, retraso, dura)
			_chorro(suelo, "gota", int((8.0 + 6.0 * alto) * k), 1.1, 2.0 + alto * 1.6, 0.18, false, Color.WHITE,
				Vector3(0.0, -7.0, 0.0), w * 0.35, retraso, dura * 0.8)
			_despues(retraso, _onda.bind(suelo, "ondas", 0.3 * ancho, 1.5 * ancho, 0.8, Color(1, 1, 1, 0.8)))
		"tierra":
			# Púa de roca que sale del suelo con polvo y piedrecitas.
			_tallo("pua_tierra", suelo, w * 1.15, h, Color.WHITE, false, retraso, dura)
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


## Un sprite de pie (`ancho` x `alto`) que crece desde el suelo tras `retraso`, se queda `dura` s y se desvanece.
func _tallo(nombre: String, suelo: Vector3, ancho: float, alto: float, color: Color, aditivo: bool,
		retraso: float, dura: float) -> MeshInstance3D:
	var m := _plano_de_pie(nombre, suelo, alto, color, aditivo)
	var sx: float = ancho / maxf(alto, 0.01)
	m.scale = Vector3(sx, 0.05, 1.0)
	m.visible = false
	var tw := m.create_tween()
	tw.tween_interval(retraso)
	tw.tween_callback(m.set.bind("visible", true))
	tw.tween_property(m, "scale", Vector3(sx, 1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dura, 0.0))
	tw.tween_property(m, "transparency", 1.0, 0.35)
	tw.tween_callback(m.queue_free)
	return m


## Hace parpadear un sprite (el rayo) mientras dura.
func _parpadear(m: MeshInstance3D, retraso: float, dura: float) -> void:
	var tw := m.create_tween()
	tw.tween_interval(retraso + 0.16)
	for i in range(maxi(1, int(dura / 0.16))):
		tw.tween_property(m, "transparency", 0.0, 0.04)
		tw.tween_property(m, "transparency", 0.55, 0.12)


## Un disco de remolino que gira en el sitio (billboard) y se desvanece.
func _remolino(p: Vector3, tam: float, retraso: float, dura: float, sentido: float) -> void:
	var r := _sprite("remolino_viento", self, tam, false, Color(1, 1, 1, 0.8))
	r.position = p
	r.visible = false
	var tw := r.create_tween()
	tw.tween_interval(retraso)
	tw.tween_callback(r.set.bind("visible", true))
	tw.set_parallel(true)
	tw.tween_property(r, "rotation:z", sentido * TAU * maxf(dura, 0.5) * 1.2, dura + 0.35).as_relative()
	tw.tween_property(r, "transparency", 1.0, 0.35).set_delay(dura)
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
			gp = _particulas("brasa", 6, 0.7, 0.25, 0.07, true, c, Vector3(0.0, 0.5, 0.0))
		"agua":
			gp = _particulas("gota", 6, 0.8, 0.2, 0.07, false, Color.WHITE, Vector3(0.0, -0.5, 0.0))
		"tierra":
			gp = _particulas("piedrecitas", 5, 0.8, 0.2, 0.07, false, Color.WHITE, Vector3(0.0, -0.6, 0.0))
		"viento":
			gp = _particulas("hoja", 5, 1.0, 0.3, 0.09, false, Color.WHITE, Vector3(0.0, 0.1, 0.0))
		"rayo":
			gp = _particulas("chispa_electrica", 5, 0.4, 0.3, 0.14, true, Color.WHITE, Vector3.ZERO)
		_:
			gp = _particulas("copo", 6, 1.0, 0.2, 0.08, true, c, Vector3(0.0, -0.2, 0.0))
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
	_estallido(p + Vector3(0.0, 0.3, 0.0), "humo", 6, 1.6, 0.6, 0.7, false, Color(0.4, 0.38, 0.36, 0.6),
		Vector3(0.0, 0.5, 0.0))
	_estallido(p + Vector3(0.0, 0.2, 0.0), "polvo", 6, 1.2, 1.0, 0.5, false, Color(0.5, 0.47, 0.44, 0.6),
		Vector3(0.0, 0.2, 0.0))


## Destello breve del color de un elemento (un tótem que se activa, una llama que prende, el puente que se tiende).
func chispazo(p: Vector3, elemento: String) -> void:
	var c: Color = COLOR.get(elemento, Color.WHITE)
	_estallido(p, "destello", 8, 0.6, 2.0, 0.35, true, c, Vector3.ZERO)
	_luz(p, c, 1.6, 3.0, 0.4)


## Bocanada de vapor (el fuego sobre un charco, el agua sobre brasas): 2,5 s.
func vapor(p: Vector3) -> void:
	_estallido(p + Vector3(0.0, 0.3, 0.0), "humo", 9, 2.5, 0.8, 1.0, false, Color(1, 1, 1, 0.5), Vector3(0, 0.7, 0))


## --- Fases ---

## Círculo rúnico del color del elemento bajo los pies del lanzador.
func _carga(elemento: String, pie: Vector3) -> void:
	var c: Color = COLOR[elemento]
	var d := _plano("circulo_runico", pie + Vector3(0.0, 0.03, 0.0), 1.3 * escala, true, c)
	var tw := d.create_tween()
	tw.set_parallel(true)
	d.scale = Vector3.ONE * 0.3
	tw.tween_property(d, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "rotation:y", PI * 0.6, 0.7)
	tw.chain().tween_property(d, "transparency", 1.0, 0.3)
	tw.chain().tween_callback(d.queue_free)
	_luz(pie + Vector3(0.0, 0.5, 0.0), c, 1.2, 2.5, 0.6)


func _proyectil(elemento: String, origen: Vector3, destino: Vector3, y_suelo: float) -> void:
	var cabeza := Node3D.new()
	add_child(cabeza)
	cabeza.position = origen
	var c: Color = COLOR[elemento]
	match elemento:
		"fuego":
			_sprite("llama", cabeza, 0.55 * escala, false, Color.WHITE)
			_estela(cabeza, "brasa", 30, 0.5, 0.18, true, c)
			_estela(cabeza, "humo", 10, 0.7, 0.35, false, Color(1, 1, 1, 0.4))
		"agua":
			_sprite("gota", cabeza, 0.4 * escala, false, Color.WHITE)
			_estela(cabeza, "gota", 26, 0.35, 0.16, false, Color(1, 1, 1, 0.8))
			_estela(cabeza, "burbuja", 8, 0.6, 0.14, false, Color(1, 1, 1, 0.7))
		"viento":
			var r := _sprite("remolino_viento", cabeza, 0.7 * escala, false, Color(1, 1, 1, 0.9))
			var tw := r.create_tween().set_loops()
			tw.tween_property(r, "rotation:z", TAU, 0.45).as_relative()
			_estela(cabeza, "hoja", 14, 0.6, 0.18, false, Color.WHITE)
		"hielo":
			_sprite("cristal_hielo", cabeza, 0.5 * escala, false, Color.WHITE)
			_estela(cabeza, "copo", 24, 0.5, 0.14, true, c)
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
	_estallido(p, "llama_tira8", 14, 0.7, 2.2, 0.75, false, Color.WHITE, Vector3(0, 1.2, 0), 8)
	_estallido(p, "brasa", 24, 1.2, 3.5, 0.16, true, c, Vector3(0, -2.0, 0))
	_estallido(p + Vector3(0, 0.3, 0), "humo", 8, 1.8, 0.8, 0.9, false, Color(1, 1, 1, 0.55), Vector3(0, 0.8, 0))
	_marca("grieta", Vector3(p.x, y_suelo, p.z), 1.1, Color(0.35, 0.22, 0.15, 0.8), 2.5)
	_luz(p, c, 2.0, 4.0, 0.6)
	impacto.emit("fuego", p)


func _impacto_agua(p: Vector3, y_suelo: float) -> void:
	_estallido(p, "gota", 22, 0.8, 3.2, 0.2, false, Color.WHITE, Vector3(0, -6.0, 0))
	_estallido(p, "burbuja", 8, 1.4, 0.9, 0.22, false, Color(1, 1, 1, 0.8), Vector3(0, 0.6, 0))
	var s := _plano_de_pie("salpicadura", Vector3(p.x, y_suelo, p.z), 1.2 * escala, Color.WHITE)
	_crecer_y_borrar(s, 0.2, 0.5)
	_onda(Vector3(p.x, y_suelo, p.z), "ondas", 0.4, 2.0, 0.9, Color(1, 1, 1, 0.9))
	_luz(p, COLOR["agua"], 1.4, 3.0, 0.4)
	impacto.emit("agua", p)


func _impacto_tierra(suelo: Vector3) -> void:
	var c: Color = COLOR["tierra"]
	_marca("grieta", suelo, 1.6, Color.WHITE, 3.0)
	# Púas que salen del suelo, en corro.
	for i in range(5):
		var ang: float = float(i) / 5.0 * TAU + 0.3
		var r: float = 0.0 if i == 0 else 0.45 * escala
		var pos: Vector3 = suelo + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var pua := _plano_de_pie("pua_tierra", pos, (1.1 if i == 0 else 0.7) * escala, Color.WHITE)
		pua.scale = Vector3(1.0, 0.05, 1.0)
		var tw := pua.create_tween()
		tw.tween_interval(float(i) * 0.04)
		tw.tween_property(pua, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.0)
		tw.tween_property(pua, "scale", Vector3(1.0, 0.0, 1.0), 0.3)
		tw.tween_callback(pua.queue_free)
	_estallido(suelo + Vector3(0, 0.2, 0), "piedrecitas", 16, 1.0, 3.0, 0.22, false, Color.WHITE, Vector3(0, -7.0, 0))
	_estallido(suelo + Vector3(0, 0.2, 0), "polvo", 10, 1.4, 1.2, 0.8, false, Color(1, 1, 1, 0.7), Vector3(0, 0.3, 0))
	_onda(suelo, "anillo_polvo", 0.5, 2.6, 0.8, Color(1, 1, 1, 0.85))
	_temblor(0.12)
	_luz(suelo + Vector3(0, 0.4, 0), c, 0.8, 3.0, 0.3)
	impacto.emit("tierra", suelo)


func _impacto_viento(p: Vector3, y_suelo: float) -> void:
	var r := _sprite("remolino_viento", self, 1.4 * escala, false, Color(1, 1, 1, 0.85))
	r.position = p
	var tw := r.create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "rotation:z", TAU * 1.5, 0.8).as_relative()
	tw.tween_property(r, "scale", Vector3.ONE * 1.6, 0.8)
	tw.tween_property(r, "transparency", 1.0, 0.8)
	tw.chain().tween_callback(r.queue_free)
	_estallido(p, "hoja", 16, 1.4, 2.5, 0.22, false, Color.WHITE, Vector3(0, -0.5, 0), 1, true)
	_onda(Vector3(p.x, y_suelo, p.z), "anillo_polvo", 0.4, 2.2, 0.6, Color(1, 1, 1, 0.5))
	impacto.emit("viento", p)


func _impacto_rayo(suelo: Vector3) -> void:
	var c: Color = COLOR["rayo"]
	# El rayo baja del cielo: un sprite alto que parpadea.
	var alto: float = 4.0 * escala
	var rayo := _plano_de_pie("rayo", suelo, alto, Color.WHITE, true)
	rayo.scale = Vector3(0.6, 1.0, 1.0)
	var tw := rayo.create_tween()
	for i in range(3):
		tw.tween_property(rayo, "transparency", 0.0, 0.03)
		tw.tween_property(rayo, "transparency", 0.7, 0.05)
	tw.tween_property(rayo, "transparency", 1.0, 0.15)
	tw.tween_callback(rayo.queue_free)
	_estallido(suelo + Vector3(0, 0.3, 0), "chispa_electrica", 10, 0.5, 2.5, 0.45, true, Color.WHITE, Vector3.ZERO)
	var d := _sprite("destello", self, 1.6 * escala, true, Color(1, 1, 0.8, 1))
	d.position = suelo + Vector3(0, 0.5, 0)
	_crecer_y_borrar(d, 0.05, 0.3)
	_marca("grieta", suelo, 0.9, Color(0.25, 0.22, 0.3, 0.7), 1.5)
	_luz(suelo + Vector3(0, 1.0, 0), c, 3.5, 5.0, 0.35)
	_temblor(0.08)
	impacto.emit("rayo", suelo)


func _impacto_hielo(p: Vector3, y_suelo: float) -> void:
	var suelo := Vector3(p.x, y_suelo, p.z)
	for i in range(6):
		var ang: float = float(i) / 6.0 * TAU
		var pos: Vector3 = suelo + Vector3(cos(ang), 0.0, sin(ang)) * 0.4 * escala
		var cr := _plano_de_pie("cristal_hielo", pos, (0.5 + float(i % 3) * 0.12) * escala, Color.WHITE)
		cr.scale = Vector3(0.2, 0.2, 0.2)
		var tw := cr.create_tween()
		tw.tween_interval(float(i) * 0.03)
		tw.tween_property(cr, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.4)
		tw.tween_property(cr, "transparency", 1.0, 0.4)
		tw.tween_callback(cr.queue_free)
	_estallido(p, "copo", 18, 1.4, 1.6, 0.2, true, COLOR["hielo"], Vector3(0, -0.6, 0))
	_marca("circulo_runico", suelo, 1.4, Color(0.75, 0.95, 1.0, 0.6), 2.0)
	_luz(p, COLOR["hielo"], 2.0, 3.5, 0.5)
	impacto.emit("hielo", p)


## --- Piezas ---

func _tex(nombre: String) -> Texture2D:
	if not _texturas.has(nombre):
		var ruta: String = VFX + nombre + ".png"
		_texturas[nombre] = load(ruta) if ResourceLoader.exists(ruta) else null
	return _texturas[nombre]


func _material(nombre: String, aditivo: bool, color: Color, billboard: BaseMaterial3D.BillboardMode,
		frames: int = 1) -> StandardMaterial3D:
	var clave: String = "%s|%s|%s|%d|%d" % [nombre, aditivo, color.to_html(), billboard, frames]
	if _materiales.has(clave):
		return _materiales[clave]
	var m := StandardMaterial3D.new()
	_materiales[clave] = m
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _tex(nombre)
	m.albedo_color = color
	m.billboard_mode = billboard
	m.vertex_color_use_as_albedo = billboard == BaseMaterial3D.BILLBOARD_PARTICLES
	if billboard == BaseMaterial3D.BILLBOARD_PARTICLES and frames > 1:
		m.particles_anim_h_frames = frames
		m.particles_anim_v_frames = 1
		m.particles_anim_loop = false
	if aditivo:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


## Un sprite que mira a la cámara, hijo de `padre`.
func _sprite(nombre: String, padre: Node3D, tam: float, aditivo: bool, color: Color) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	q.material = _material(nombre, aditivo, color, BaseMaterial3D.BILLBOARD_ENABLED)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


## Un sprite de pie (gira solo en vertical hacia la cámara), con la base en `pie`.
func _plano_de_pie(nombre: String, pie: Vector3, tam: float, color: Color, aditivo: bool = false) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	q.center_offset = Vector3(0.0, tam * 0.5, 0.0)
	q.material = _material(nombre, aditivo, color, BaseMaterial3D.BILLBOARD_FIXED_Y)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pie
	add_child(mi)
	return mi


## Un sprite tumbado en el suelo.
func _plano(nombre: String, p: Vector3, tam: float, aditivo: bool, color: Color) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	q.orientation = PlaneMesh.FACE_Y
	q.material = _material(nombre, aditivo, color, BaseMaterial3D.BILLBOARD_DISABLED)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p
	add_child(mi)
	return mi


## Marca en el suelo que se queda un rato y se desvanece.
func _marca(nombre: String, suelo: Vector3, tam: float, color: Color, dura: float) -> void:
	var m := _plano(nombre, suelo + Vector3(0.0, 0.02, 0.0), tam * escala, false, color)
	m.rotation.y = randf() * TAU
	var tw := m.create_tween()
	tw.tween_interval(dura)
	tw.tween_property(m, "transparency", 1.0, 0.6)
	tw.tween_callback(m.queue_free)


## Anillo en el suelo que se abre y se apaga.
func _onda(suelo: Vector3, nombre: String, desde: float, hasta: float, dura: float, color: Color) -> void:
	var o := _plano(nombre, suelo + Vector3(0.0, 0.04, 0.0), 1.0, false, color)
	o.scale = Vector3.ONE * desde * escala
	var tw := o.create_tween()
	tw.set_parallel(true)
	tw.tween_property(o, "scale", Vector3.ONE * hasta * escala, dura).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(o, "transparency", 1.0, dura).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(o.queue_free)


func _crecer_y_borrar(n: MeshInstance3D, sube: float, baja: float) -> void:
	var final_: Vector3 = n.scale
	n.scale = final_ * 0.3
	var tw := n.create_tween()
	tw.tween_property(n, "scale", final_, sube).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "transparency", 1.0, baja)
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
		pm.angular_velocity_min = -360.0
		pm.angular_velocity_max = 360.0
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


func _particulas(nombre: String, n: int, vida: float, vel: float, tam: float, aditivo: bool, color: Color,
		gravedad: Vector3, frames: int = 1) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.initial_velocity_min = vel * 0.5 * escala
	pm.initial_velocity_max = vel * escala
	pm.gravity = gravedad * escala
	pm.damping_min = vel * 0.6
	pm.damping_max = vel * 0.9
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	var curva := Curve.new()
	curva.max_value = 2.0
	curva.add_point(Vector2(0.0, 0.4))
	curva.add_point(Vector2(0.2, 1.0))
	curva.add_point(Vector2(1.0, 0.3))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.1, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	if frames > 1:
		pm.anim_speed_min = 1.0
		pm.anim_speed_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam) * escala
	q.material = _material(nombre, aditivo, Color.WHITE, BaseMaterial3D.BILLBOARD_PARTICLES, frames)
	var gp := GPUParticles3D.new()
	gp.amount = n
	gp.lifetime = vida
	gp.process_material = pm
	gp.draw_pass_1 = q
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
