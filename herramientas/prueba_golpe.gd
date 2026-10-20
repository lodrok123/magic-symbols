extends SceneTree
## Prueba del GOLPE de un hechizo a un enemigo (HC3, 18/10; docs/HECHIZO_CLASE.md §3): lo que `Combate3D` hace con cada elemento sale de los campos del `Hechizo`
## (daño, empuje, quema, moja, congela, aturde, ralentiza, interrumpe), no de tablas escritas a mano. Sin ventana: `--headless --fixed-fps 60`.
## `ANTES` es la tabla MEDIDA con el código previo a HC3 (el golpe por `on_spell_hit(rune, dir)`, que es el contrato y no cambia): tres montajes por elemento
## (goblin normal, goblin ya mojado, elemental). La prueba exige los mismos números después del cambio.
class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _goblins: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

const ELEMENTOS: Dictionary = {"fuego": "fire", "agua": "water", "tierra": "earth", "hielo": "ice", "rayo": "lightning", "viento": "wind"}   # 20/10: sin «tiempo» (cinemática)
const MONTAJES: Array = ["normal", "mojado", "elemental"]
const CAMPOS: Array = ["dano", "mojado", "quemando", "congelado", "lento", "interrupcion", "stun", "empuje"]

var _fallos: int = 0
var _mundo: MundoFalso = null

func _ok(c: bool, m: String) -> void:
	if not c:
		_fallos += 1
		print("FALLO: ", m)

func _mapa() -> void:
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	_mundo = MundoFalso.new()
	_mundo._mapa = filas
	root.add_child(_mundo)
	Lanzador3D.configurar(_mundo)
	for y in range(20):
		for x in range(20):
			if filas[y][x] == "#":
				_mundo._bloqueadas[Vector2i(x, y)] = true

func _nuevo(montaje: String) -> Combate3D:
	var j := Jugador3D.new()
	j.position = Vector3(18 * 2.3, 1.0, 18 * 2.3)
	var modelo := Pj3D.new()
	modelo.position = Vector3(10 * 2.3, 2.3 * 0.45, 10 * 2.3)
	_mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, j, null)
	g.set_physics_process(false)
	g.altura = 0.85
	if montaje == "mojado":
		g.mojado = 3.0
	elif montaje == "elemental":
		g.elemental = true
	return g

## Un golpe por el contrato (`on_spell_hit`) y lo que dejó en el enemigo.
func _medir(fichero: String, montaje: String) -> Dictionary:
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % fichero)
	var g: Combate3D = _nuevo(montaje)
	var v0: float = g.health
	g.on_spell_hit(rune, Vector3(1, 0, 0))
	var r: Dictionary = {"dano": snappedf(v0 - g.health, 0.01), "mojado": snappedf(g.mojado, 0.01), "quemando": snappedf(g.quemando, 0.01),
		"congelado": snappedf(g.congelado, 0.01), "lento": snappedf(g.lento, 0.01), "interrupcion": snappedf(g.interrupcion, 0.01),
		"stun": snappedf(g.stun_timer, 0.01), "empuje": snappedf(g._empuje.length(), 0.1)}
	g.queue_free()
	return r

func _initialize() -> void:
	await process_frame
	_mapa()
	var tabla: Dictionary = {}
	for el in ELEMENTOS:
		for m in MONTAJES:
			var clave: String = "%s/%s" % [el, m]
			var r: Dictionary = _medir(ELEMENTOS[el], m)
			tabla[clave] = r
			if OS.get_cmdline_user_args().has("--tabla"):
				print("\t\"%s\": %s," % [clave, str(r)])
	if not OS.get_cmdline_user_args().has("--tabla"):
		for clave in ANTES:
			var medido: Dictionary = tabla.get(clave, {})
			for campo in CAMPOS:
				var e: float = float((ANTES[clave] as Dictionary)[campo])
				var v: float = float(medido.get(campo, -999.0))
				_ok(absf(e - v) < 0.06, "%s: %s = %.2f, antes %.2f" % [clave, campo, v, e])
		_ok(tabla.size() == ANTES.size(), "faltan montajes en la tabla (%d de %d)" % [tabla.size(), ANTES.size()])
	print("RESULTADO golpe: %d montajes · FALLOS: %d" % [tabla.size(), _fallos])
	quit(1 if _fallos > 0 else 0)

## Medida con el código ANTERIOR a HC3 (18/10).
const ANTES: Dictionary = {
	"fuego/normal": { "dano": 25.0, "mojado": 0.0, "quemando": 3.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 5.6 },
	"fuego/mojado": { "dano": 25.0, "mojado": 0.0, "quemando": 0.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 5.6 },
	"fuego/elemental": { "dano": 25.0, "mojado": 0.0, "quemando": 5.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 1.7 },
	"agua/normal": { "dano": 80.0, "mojado": 6.0, "quemando": 0.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 5.6 },
	"agua/mojado": { "dano": 80.0, "mojado": 6.0, "quemando": 0.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 5.6 },
	"agua/elemental": { "dano": 0.0, "mojado": 0.0, "quemando": 0.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.0, "stun": 0.0, "empuje": 0.0 },
	"tierra/normal": { "dano": 18.0, "mojado": 0.0, "quemando": 0.0, "congelado": 0.0, "lento": 3.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 15.8 },
	"tierra/mojado": { "dano": 18.0, "mojado": 3.0, "quemando": 0.0, "congelado": 0.0, "lento": 3.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 15.8 },
	"tierra/elemental": { "dano": 18.0, "mojado": 0.0, "quemando": 0.0, "congelado": 0.0, "lento": 3.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 4.7 },
	"hielo/normal": { "dano": 20.0, "mojado": 0.0, "quemando": 0.0, "congelado": 1.5, "lento": 0.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 5.6 },
	"hielo/mojado": { "dano": 35.0, "mojado": 3.0, "quemando": 0.0, "congelado": 2.5, "lento": 0.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 5.6 },
	"hielo/elemental": { "dano": 20.0, "mojado": 0.0, "quemando": 0.0, "congelado": 1.5, "lento": 0.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 1.7 },
	"rayo/normal": { "dano": 55.0, "mojado": 0.0, "quemando": 0.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.6, "stun": 1.2, "empuje": 5.6 },
	"rayo/mojado": { "dano": 82.5, "mojado": 3.0, "quemando": 0.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.6, "stun": 1.2, "empuje": 5.6 },
	"rayo/elemental": { "dano": 55.0, "mojado": 0.0, "quemando": 0.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.6, "stun": 0.0, "empuje": 1.7 },
	"viento/normal": { "dano": 0.0, "mojado": 0.0, "quemando": 0.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.7, "stun": 0.0, "empuje": 0.0 },
	"viento/mojado": { "dano": 0.0, "mojado": 3.0, "quemando": 0.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.7, "stun": 0.0, "empuje": 0.0 },
	"viento/elemental": { "dano": 0.0, "mojado": 0.0, "quemando": 0.0, "congelado": 0.0, "lento": 0.0, "interrupcion": 0.0, "stun": 0.0, "empuje": 0.0 },
}
