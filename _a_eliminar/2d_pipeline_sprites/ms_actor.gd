class_name MsActor
extends Sprite2D

## UN PERSONAJE DEL PIPELINE EN EL MUNDO: un Sprite2D que reproduce atlas de 8
## direcciones (ver MsAtlas).
##
## Se usa de dos maneras:
##   - Como nodo nuevo:        MsActor.new().setup("goblin_warrior")
##   - SOBRE UN SPRITE2D YA EXISTENTE (el arquero, el guerrero): set_script() y
##     setup(). Así enemy.gd y archer.gd siguen hablando con "su" $Sprite2D (el
##     arquero lo tiñe al apuntar) sin saber que ahora es otro dibujo.
##
## MODOS. Lo único que cambia entre actores es qué mira para decidir qué animación
## toca; se elige con `modo`:
##   "fijo" ....... la que se le diga con jugar() / mirar_a()
##   "guerrero" ... patrulla (enemy.gd): anda, ataca al golpear, se electrifica aturdido
##   "arquero" .... apunta al jugador, dispara (archer.gd), se electrifica aturdido

const DIRS: Array = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

## La vertical se ve aplastada ~2:1 (IsoGrid.STEP.x / STEP.y); hay que deshacerlo
## antes de medir un ángulo, o los personajes miran mal en las diagonales.
const DESAPLASTAR: float = 2.109

var id: String = ""
var modo: String = "fijo"
var animacion_actual: String = "idle"
var fila: String = "S"          ## fila del atlas que se está dibujando
var _t: float = 0.0
var _una_vez: bool = false
var _volver: String = "idle"
var _mapa: Dictionary = {}
var _rest_previo: float = 0.0
var _quedarse: bool = false     ## acabó una animación con `quedarse`: congelado en el último fotograma

## Clips que se reproducen SOLO en un tramo: [primer fotograma, último, fps]. El golpe recibido
## entero (hit_reaction, 12 fotogramas a 12 fps) dura un segundo y se mueve casi nada (71-76 px de
## alto en el goblin): el tramo central a 20 fps dura 0,2 s y se lee como un golpe. Es el mismo
## recorte que MsAtlas.frames_heroe() le hace al héroe. Si llega un clip de golpe bueno (4-6
## fotogramas), se quita de aquí.
const RECORTES: Dictionary = {
	"hit_reaction": [2, 5, 20.0],
}


func setup(p_id: String, mirando: String = "S", p_modo: String = "fijo") -> MsActor:
	id = p_id
	modo = p_modo
	var m: Dictionary = MsAtlas.meta(id)
	if m.is_empty():
		return self

	_mapa = m["mapeo_direcciones_godot"]
	var off: Array = m["offset_visual_px"]
	position = Vector2.ZERO
	centered = true
	offset = Vector2(off[0], off[1])
	scale = Vector2.ONE * MsAtlas.escala(id)
	mirar_dir(mirando)
	_pintar()
	return self


## Hacia dónde mira, dada la dirección REAL en pantalla ("E", "SE"...).
func mirar_dir(direccion: String) -> void:
	fila = String(_mapa.get(direccion, direccion))


## Hacia dónde mira, dado un vector de pantalla (la vertical está aplastada).
func mirar_a(v: Vector2) -> void:
	if v.length() < 0.001:
		return
	var u := Vector2(v.x, v.y * DESAPLASTAR)
	var i: int = posmod(int(roundf(rad_to_deg(u.angle()) / 45.0)), 8)
	mirar_dir(DIRS[i])


## Pone una animación. `una_vez` la reproduce entera y vuelve a `volver`.
## `quedarse` (solo con `una_vez`): al acabar se QUEDA en el último fotograma y el actor deja
## de obedecer a jugar() y a su guion. Es para la muerte: sin esto, el guion del modo "ia"
## ve `moviendo = 0` y pone `idle` nada más acabar la caída, y el cadáver se levanta.
## Parámetro opcional al final: las llamadas de antes siguen valiendo igual.
func jugar(nombre: String, una_vez: bool = false, volver: String = "idle", quedarse: bool = false) -> void:
	if _quedarse:
		return
	if not MsAtlas.tiene(id, nombre):
		return
	if nombre == animacion_actual and not una_vez:
		return
	animacion_actual = nombre
	_una_vez = una_vez
	_volver = volver
	_quedarse = quedarse and una_vez
	_t = 0.0


func _process(delta: float) -> void:
	if id == "":
		return

	if not _quedarse:
		match modo:
			"guerrero":
				_guion_guerrero()
			"arquero":
				_guion_arquero()
			"ia":
				_guion_ia()

	var frames: Array = MsAtlas.animacion(id, animacion_actual).get(fila, [])
	if frames.is_empty():
		return

	# Tramo del clip que se reproduce y a qué velocidad. Normalmente todo el clip y los fps del
	# meta; RECORTES quita lo que no se lee (ver su comentario).
	var desde: int = 0
	var hasta: int = frames.size() - 1
	var vel: float = MsAtlas.fps(id, animacion_actual)
	if RECORTES.has(animacion_actual):
		var r: Array = RECORTES[animacion_actual]
		desde = mini(int(r[0]), hasta)
		hasta = mini(int(r[1]), hasta)
		vel = float(r[2])
	var n: int = hasta - desde + 1

	_t += delta * vel
	if _una_vez and int(_t) >= n:
		if _quedarse:
			texture = frames[hasta]
			_t = float(n)
			return
		animacion_actual = _volver
		_una_vez = false
		_t = 0.0
		frames = MsAtlas.animacion(id, animacion_actual).get(fila, [])
		if frames.is_empty():
			return
		desde = 0
		n = frames.size()

	var idx: int = (int(_t) % n) if (MsAtlas.en_bucle(id, animacion_actual) or not _una_vez) else mini(int(_t), n - 1)
	texture = frames[desde + idx]
	_rest_previo = _leer_rest()


func _pintar() -> void:
	var frames: Array = MsAtlas.animacion(id, animacion_actual).get(fila, [])
	if not frames.is_empty():
		texture = frames[0]


func _leer_rest() -> float:
	var p: Node = get_parent()
	if p == null:
		return 0.0
	if modo == "guerrero":
		return float(p.get("strike_rest"))
	if modo == "arquero":
		return float(p.get("rest_timer"))
	return 0.0


## enemy.gd patrulla en X de pantalla: `direction` es +1 o -1. strike_rest salta a
## 1.5 cuando acaba de golpear. Aturdido = electrocutado.
func _guion_guerrero() -> void:
	var p: Node = get_parent()
	if p == null:
		return
	var direccion: float = float(p.get("direction"))
	mirar_a(Vector2(direccion, 0.0))

	if float(p.get("stun_timer")) > 0.0:
		jugar("electrocution_reaction")
		return
	if float(p.get("strike_rest")) > _rest_previo + 0.5:
		jugar("left_slash", true, "walk")
		return
	if not _una_vez:
		jugar("walk")


## archer.gd: `target` es el jugador mientras lo ve; `rest_timer` salta a 2.4 al
## disparar.
func _guion_arquero() -> void:
	var p: Node = get_parent()
	if p == null:
		return
	var objetivo: Variant = p.get("target")
	if objetivo != null and is_instance_valid(objetivo):
		mirar_a((objetivo as Node2D).global_position - (p as Node2D).global_position)

	if float(p.get("stun_timer")) > 0.0:
		jugar("electrocution_reaction")
		return
	if float(p.get("rest_timer")) > _rest_previo + 1.0:
		jugar("archery_shot_001", true, "idle")
		return
	if not _una_vez:
		jugar("idle")


## Modo "ia": el goblin con IA (goblin_guerrero.gd / goblin_arquero.gd) le dice qué hace
## con tres variables suyas: `mirada` (hacia dónde mira), `moviendo` (0 quieto, 1 anda,
## 2 corre) y `anim_orden` (una animación puntual: un ataque, un golpe recibido, un tiro).
func _guion_ia() -> void:
	var p: Node = get_parent()
	if p == null:
		return
	var m: Variant = p.get("mirada")
	if m is Vector2 and (m as Vector2).length() > 1.0:
		mirar_a(m)

	var orden: String = String(p.get("anim_orden"))
	if orden != "":
		p.set("anim_orden", "")
		var nombre: String = orden
		var morir: bool = false
		match orden:
			# "death": el clip de caída del modelo (el del guerrero es shot_and_fall_backward) y
			# se queda tumbado. Si el modelo no tiene ninguno, no hace nada y el Juego decide.
			"death":
				morir = true
				for c in ["death", "shot_and_fall_backward", "shot_in_the_back_and_fall"]:
					if MsAtlas.tiene(id, String(c)):
						nombre = String(c)
						break
			"hit":
				nombre = "hit_reaction" if MsAtlas.tiene(id, "hit_reaction") else "face_punch_reaction"
			"shoot":
				nombre = "archery_shot_002" if (randf() < 0.4 and MsAtlas.tiene(id, "archery_shot_002")) else "archery_shot_001"
		if MsAtlas.tiene(id, nombre):
			jugar(nombre, true, "idle", morir)
			return

	if float(p.get("stun_timer")) > 0.0:
		jugar("electrocution_reaction")
		return
	if _una_vez:
		return
	var mov: int = int(p.get("moviendo"))
	jugar("run" if mov >= 2 else ("walk" if mov == 1 else "idle"))
