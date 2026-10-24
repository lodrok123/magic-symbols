class_name Rompible3D
extends Area3D

## ROMPIBLE (jarrón y caja; mapas abiertos al estilo EoW, 23/10, docs/PLAN_BOSQUE_EOW.md §8). Un objeto pequeño que tapa su casilla, se ROMPE con cualquier
## golpe y suelta su BOTÍN según la zona donde está (como el `RegionItemDrop` de EoW: el mismo jarrón da algo distinto en el bosque, en las ruinas o en la cueva).
##
## QUÉ LO ROMPE (todo lo que ya existe en el juego, sin tocarlo):
##   · un hechizo cualquiera (`on_spell_hit`: de daño, de agua, de fuego… el contrato del Lanzador3D no distingue «golpe»);
##   · un empujón (`push`: el viento y la atracción llaman a esto antes de `on_spell_hit`);
##   · una explosión (`recibir_explosion`: Barril3D busca el grupo `explosionable`);
##   · un golpe cuerpo a cuerpo de la jugadora: hoy NO existe, pero queda `golpear()` (público) para cuando lo haya.
##
## QUÉ PASA AL ROMPERSE: polvo y sonido, el modelo desaparece, saltan trozos que se quedan en el suelo como RESTOS, se libera la casilla y sale el botín (abajo).
## NO REAPARECE: se apunta una flag `<nivel>.rompible.<id>` (Flags), que sobrevive a cambiar de nivel (la Cueva ↔ el Bosque recargan la escena) y a guardar.
## Con la flag ya puesta nace ROTO: solo los restos, sin polvo ni botín.
##
## BOTÍN. `botin=oro|pocion|nada|<objeto>`; qué sale de cada uno lo dice la ZONA (`BOTIN_ZONA`, nombre de zona → cifras; la zona la da Zonas3D con su `nombre=` o, si no
## lo tiene, el nombre de su luz: bosque, ruinas, cueva…). Fuera de toda zona vale la zona de la escena; una zona sin fila usa `BOTIN_DEFECTO`.
##   oro      monedas (Combate3D.Botin3D, las de los goblins): una cantidad al azar entre las dos cifras de la zona (`cantidad=<n>` la fija)
##   pocion   `pocion` en el suelo, la cantidad de la zona (`cantidad=<n>` la fija)
##   <objeto> cualquier id de `Objetos.DATOS` (esquirla_cristal, seta…): 1 unidad (`cantidad=<n>`)
##   nada     un jarrón vacío (sirve de adorno, de gancho de puzle o de sorpresa mala)
## Además, en las zonas con `mineral` > 0, un jarrón da con esa probabilidad el material que dice `Objetos.mineral_de("jarron", "romper")` (la esquirla de la Cueva).
## Lo que cae al suelo se coge pasando cerca (el oro y el objeto), con el aviso de calidad de siempre.
##
## Se coloca desde un mapa con `; pieza <id> jarron|caja <x> <y> [botin=…] [cantidad=<n>] [alto=si] [pequena=si]` (escenas/puzle.gd), o con `preparar` desde código.

signal roto

## Zona → cifras del botín. `oro`: [mínimo, máximo] de monedas · `pocion`: cuántas · `mineral`: probabilidad de material extra en un jarrón.
const BOTIN_ZONA: Dictionary = {
	"bosque": {"oro": [3, 8], "pocion": 1, "mineral": 0.0},
	"clasico": {"oro": [3, 8], "pocion": 1, "mineral": 0.0},
	"atardecer": {"oro": [4, 9], "pocion": 1, "mineral": 0.0},
	"agua": {"oro": [4, 10], "pocion": 1, "mineral": 0.0},
	"fuego": {"oro": [5, 11], "pocion": 1, "mineral": 0.0},
	"ruinas": {"oro": [6, 14], "pocion": 1, "mineral": 0.15},
	"hielo": {"oro": [5, 12], "pocion": 1, "mineral": 0.0},
	"cueva": {"oro": [5, 12], "pocion": 1, "mineral": 0.35},
	"santuario": {"oro": [8, 16], "pocion": 2, "mineral": 0.0},
	"campamento": {"oro": [6, 12], "pocion": 1, "mineral": 0.0, "perfil": {"nada": 0.4, "oro": 0.45, "pocion": 0.15}},
}
const BOTIN_DEFECTO: Dictionary = {"oro": [2, 5], "pocion": 1, "mineral": 0.0}
const ZONA_DEFECTO: String = "bosque"
const BOTIN_ORO: String = "oro"
const BOTIN_POCION: String = "pocion"
const BOTIN_NADA: String = "nada"
const BOTIN_PERFIL: String = "zona"
## Probabilidades de `botin=zona` (nada, oro, poción; suman 1). En EoW casi todo jarrón sale vacío (P(nada) de 0,5 a 0,94 según la región).
const PERFIL_DEFECTO: Dictionary = {"nada": 0.5, "oro": 0.4, "pocion": 0.1}

## Modelo de cada tipo: pieza normal y pieza alternativa (`alto=si` en el jarrón, `pequena=si` en la caja), y de qué color son los trozos.
const MODELOS: Dictionary = {
	"jarron": {"normal": "jarron", "otra": "jarron_alto", "trozo": Color(0.62, 0.38, 0.24), "alto_hit": 0.9, "alto_otra": 1.3, "restos": "jarron_roto"},
	"caja": {"normal": "caja", "otra": "caja_pequena", "trozo": Color(0.55, 0.40, 0.22), "alto_hit": 0.8, "alto_otra": 0.6},
}
const RADIO_HIT: float = 0.5
const N_TROZOS: int = 8                     ## trozos que saltan y se quedan de restos
const TROZO_MIN: float = 0.07
const TROZO_MAX: float = 0.2
const ALCANCE_TROZOS: float = 0.9           ## u: hasta dónde llegan
const T_TROZOS: float = 0.45                ## s de vuelo
const ALTO_SALTO: float = 0.7               ## u
const TONO_ROMPE: float = 1.6               ## pitch del «derrumbe», más agudo (cerámica, no piedra)
const POLVO_RADIO: float = 0.8
const FLAG_TROZO: String = "rompible"       ## el trozo de en medio de `<nivel>.rompible.<id>`
const PROB_FORZADA_NINGUNA: float = -1.0

## Solo para las pruebas: >= 0 sustituye al azar en la tirada del mineral extra. -1 = al azar.
static var tirada_forzada: float = PROB_FORZADA_NINGUNA
## Lo mismo para la tirada de `botin=zona` (nada / oro / poción).
static var tirada_perfil: float = PROB_FORZADA_NINGUNA

var celda: Vector2i = Vector2i.ZERO
var tipo: String = "jarron"
var botin: String = BOTIN_ORO
var cantidad: int = 0                       ## 0 = la de la zona
var alternativo: bool = false               ## alto=si / pequena=si
var nivel: String = ""
var roto_ya: bool = false
var soltado: Array = []                     ## lo que soltó al romperse: [{"que": "oro"|id, "n": int}] (las pruebas lo leen)
var zona: String = ""                       ## la zona donde se rompió (la que decidió el botín)
var botin_efectivo: String = ""             ## lo que tocó de verdad (con `botin=zona`, lo que salió de la tirada)
var _mundo: Node = null
var _modelo: Node3D = null
var _restos: Node3D = null


## `p_mundo` = la maqueta (da el modelo con su escala de `Pieza3D.MEDIDA` y la zona de la casilla).
func preparar(p_celda: Vector2i, p_tipo: String, p_botin: String, p_cantidad: int, p_alternativo: bool, p_nivel: String, p_mundo: Node = null) -> void:
	celda = p_celda
	tipo = p_tipo if MODELOS.has(p_tipo) else "jarron"
	botin = p_botin
	cantidad = maxi(p_cantidad, 0)
	alternativo = p_alternativo
	nivel = p_nivel
	_mundo = p_mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	var alto: float = _alto()
	cil.radius = RADIO_HIT
	cil.height = alto
	forma.shape = cil
	forma.position = Vector3(0.0, alto * 0.5, 0.0)
	add_child(forma)
	add_to_group("rompible")
	add_to_group("explosionable")
	if nivel != "" and Flags.i().tiene(flag()):
		_nacer_roto()
		return
	Terreno3D.bloquear_celda(celda)
	_poner_modelo()


## Nombre de la flag que recuerda que se rompió: `<nivel>.rompible.<id>`, en minúsculas y con «_» donde no valga otra cosa.
static func flag_de(p_nivel: String, id: String) -> String:
	return "%s.%s.%s" % [_limpio(p_nivel), FLAG_TROZO, _limpio(id)]


static func _limpio(t: String) -> String:
	var r: String = ""
	for ch in t.to_lower():
		r += ch if ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_") else "_"
	return r if r != "" else "x"


func flag() -> String:
	return flag_de(nivel, String(name))


func _alto() -> float:
	var m: Dictionary = MODELOS[tipo]
	return float(m["alto_otra"] if alternativo else m["alto_hit"])


func _id_modelo() -> String:
	var m: Dictionary = MODELOS[tipo]
	return String(m["otra"] if alternativo else m["normal"])


## El modelo de la pieza (la maqueta lo escala a su medida), o una caja del color de los trozos si no hay ninguno.
func _poner_modelo() -> void:
	var id: String = _id_modelo()
	var n: Node3D = null
	if _mundo != null and is_instance_valid(_mundo) and _mundo.has_method("_pieza"):
		n = _mundo.call("_pieza", id) as Node3D
	if n == null and ResourceLoader.exists("res://arte/piezas/%s.tscn" % id):
		n = (load("res://arte/piezas/%s.tscn" % id) as PackedScene).instantiate() as Node3D
	if n == null:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.7, _alto(), 0.7)
		m.mesh = b
		m.position = Vector3(0.0, _alto() * 0.5, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = MODELOS[tipo]["trozo"]
		m.material_override = mat
		var raiz := Node3D.new()
		raiz.add_child(m)
		n = raiz
	n.name = "modelo"
	add_child(n)
	_modelo = n


## --- Contrato con los hechizos: cualquier golpe lo rompe ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if rune_data != null:
		romper()


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	return rune_data != null and not roto_ya


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


## El viento y la atracción empujan antes de golpear: un empujón basta.
func push(_direccion: Vector3, _fuerza: float) -> void:
	romper()


## Barril3D: una explosión al alcance lo rompe.
func recibir_explosion(_punto: Vector3) -> void:
	romper()


## Golpe cuerpo a cuerpo de la jugadora (hoy no hay: se llamará desde su ataque cuando exista) y atajo de las pruebas.
func golpear(_desde: Vector3 = Vector3.ZERO) -> void:
	romper()


## Un daño cualquiera (la misma firma que Combate3D.receive_damage): también lo rompe.
func receive_damage(_cantidad: float = 1.0) -> void:
	romper()


## --- Romperse ---

func romper() -> void:
	if roto_ya:
		return
	roto_ya = true
	collision_layer = 0                      # el nodo se queda (los puzles lo consultan), pero ya no se golpea
	remove_from_group("explosionable")
	Terreno3D.liberar_celda(celda)
	if nivel != "":
		Flags.i().poner(flag())
	zona = zona_de(_mundo, celda)
	Sfx.play(self, "derrumbe", TONO_ROMPE)
	if _modelo != null:
		_modelo.visible = false
	var punto: Vector3 = global_position if is_inside_tree() else position
	var padre: Node3D = get_parent() as Node3D
	if padre != null:
		VfxPuzle3D.polvo(padre, punto + Vector3(0.0, 0.2, 0.0), POLVO_RADIO)
	_trozos(true)
	_soltar_botin(punto)
	# `zona_botin` y no `zona`: el campo `zona` de TODO evento es donde está la jugadora (PlayLog.zona), y aquí ese dato pisaría el suyo.
	PlayLog.event("rompible_roto", {"id": String(name), "tipo": tipo, "zona_botin": zona, "botin": botin_efectivo, "soltado": soltado})
	roto.emit()


## Nace ya roto (la flag está puesta): solo restos, sin efectos ni botín.
func _nacer_roto() -> void:
	roto_ya = true
	collision_layer = 0
	remove_from_group("explosionable")
	_trozos(false)


# ---------------------------------------------------------------------------------------------------------------------
#  Restos
# ---------------------------------------------------------------------------------------------------------------------

## Trozos del color del tipo: saltan en parábola (si `volar`) y se quedan en el suelo. Si hay una pieza `<id>_roto` en el decorado se podría usar aquí; hoy no la hay.
func _trozos(volar: bool) -> void:
	_restos = Node3D.new()
	_restos.name = "restos"
	add_child(_restos)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s%d%d" % [String(name), celda.x, celda.y])      # los mismos restos cada vez que nace roto
	var color: Color = MODELOS[tipo]["trozo"]
	# 24/10 (tercera tanda): los restos del jarrón son una pieza (`jarron_roto`: la base y los cascos en el suelo), además de los trozos que saltan. Cuelga de este nodo y no de `_restos`
	# (`n_restos` cuenta solo los trozos). Un tipo sin pieza de restos (la caja) sigue como siempre.
	var id_restos: String = String((MODELOS[tipo] as Dictionary).get("restos", ""))
	if id_restos != "":
		var pieza: Node3D = null
		if _mundo != null and is_instance_valid(_mundo) and _mundo.has_method("_pieza"):
			pieza = _mundo.call("_pieza", id_restos) as Node3D
		if pieza == null and ResourceLoader.exists("res://arte/piezas/%s.tscn" % id_restos):
			pieza = (load("res://arte/piezas/%s.tscn" % id_restos) as PackedScene).instantiate() as Node3D
		if pieza != null:
			pieza.name = "restos_modelo"
			pieza.rotation.y = rng.randf() * TAU
			add_child(pieza)
	for i in range(N_TROZOS):
		var t := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(TROZO_MIN, TROZO_MAX), rng.randf_range(TROZO_MIN, TROZO_MAX) * 0.5, rng.randf_range(TROZO_MIN, TROZO_MAX))
		t.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.darkened(rng.randf_range(0.0, 0.3))
		mat.roughness = 0.9
		t.material_override = mat
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(0.15, ALCANCE_TROZOS)
		var fin := Vector3(cos(ang) * dist, b.size.y * 0.5, sin(ang) * dist)
		t.rotation = Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)
		t.name = "trozo_%d" % i
		_restos.add_child(t)
		if not volar:
			t.position = fin
			continue
		var ini := Vector3(0.0, _alto() * 0.5, 0.0)
		t.position = ini
		var tw: Tween = t.create_tween()
		tw.tween_method(func(k: float) -> void:
			t.position = ini.lerp(fin, k) + Vector3(0.0, ALTO_SALTO * 4.0 * k * (1.0 - k), 0.0),
			0.0, 1.0, T_TROZOS).set_trans(Tween.TRANS_LINEAR)


## Cuántos trozos hay en el suelo ahora (las pruebas y las capturas).
func n_restos() -> int:
	return _restos.get_child_count() if _restos != null else 0


# ---------------------------------------------------------------------------------------------------------------------
#  Botín por zona
# ---------------------------------------------------------------------------------------------------------------------

## La zona que manda en una casilla: la de `Zonas3D` (su `nombre=` o el de su luz), o la `zona_luz` de la escena, o `ZONA_DEFECTO`.
static func zona_de(mundo: Node, c: Vector2i) -> String:
	if mundo != null and is_instance_valid(mundo):
		var z: Node = mundo.get_node_or_null("Zonas3D")
		if z != null and z.has_method("nombre_en"):
			return String(z.call("nombre_en", c))
		var luz: Variant = mundo.get("zona_luz")
		if luz != null and String(luz) != "":
			return String(luz)
	return ZONA_DEFECTO


## La fila del botín de una zona: la que pida su `botin=` si existe; si no, la de su nombre; si no tiene (una zona con `nombre=` propio), la de su luz; si tampoco, `BOTIN_DEFECTO`.
static func fila_de(p_zona: String, p_luz: String = "", p_botin: String = "") -> Dictionary:
	if BOTIN_ZONA.has(p_botin):
		return BOTIN_ZONA[p_botin]                  # la zona dice qué fila usar (`botin=campamento` en su línea `; zona`)
	if BOTIN_ZONA.has(p_zona):
		return BOTIN_ZONA[p_zona]
	return BOTIN_ZONA.get(p_luz, BOTIN_DEFECTO)


## Cuánto oro da una zona con esta tirada (0..1 reparte el rango entero). Pura: se mide sin azar.
static func oro_de(p_zona: String, tirada: float, p_luz: String = "", p_botin: String = "") -> int:
	var r: Array = fila_de(p_zona, p_luz, p_botin)["oro"]
	var lo: int = int(r[0])
	var hi: int = int(r[1])
	return clampi(lo + int(floor(clampf(tirada, 0.0, 0.9999) * float(hi - lo + 1))), lo, hi)


## ¿Es un valor válido de `botin=`? (oro, pocion, nada o un objeto de Objetos.DATOS).
static func botin_valido(t: String) -> bool:
	return t == BOTIN_ORO or t == BOTIN_POCION or t == BOTIN_NADA or t == BOTIN_PERFIL or Objetos.existe(t)


## `botin=zona`: el jarrón no tiene botín fijo, sale el que reparte el PERFIL de su zona (`BOTIN_ZONA[zona]["perfil"]`: probabilidades de nada, oro y poción), tirada al romperse.
static func botin_de_perfil(p_zona: String, tirada: float, p_luz: String = "", p_botin: String = "") -> String:
	var perfil: Dictionary = fila_de(p_zona, p_luz, p_botin).get("perfil", PERFIL_DEFECTO)
	var acumulado: float = 0.0
	for k in [BOTIN_NADA, BOTIN_ORO, BOTIN_POCION]:
		acumulado += float(perfil.get(k, 0.0))
		if tirada < acumulado:
			return k
	return BOTIN_NADA


func _soltar_botin(punto: Vector3) -> void:
	soltado = []
	var luz_zona: String = ""
	var zn: Node = _mundo.get_node_or_null("Zonas3D") if _mundo != null and is_instance_valid(_mundo) else null
	if zn != null and zn.has_method("luz_en"):
		luz_zona = String(zn.call("luz_en", celda))
	var perfil_zona: String = String(zn.call("botin_en", celda)) if zn != null and zn.has_method("botin_en") else ""
	var fila: Dictionary = fila_de(zona, luz_zona, perfil_zona)
	var raiz: Node3D = (_mundo as Node3D) if _mundo is Node3D else (get_parent() as Node3D)
	var jug: Jugador3D = _jugador()
	var que: String = botin
	if que == BOTIN_PERFIL:
		que = botin_de_perfil(zona, randf() if tirada_perfil < 0.0 else tirada_perfil, luz_zona, perfil_zona)
	botin_efectivo = que
	match que:
		BOTIN_NADA:
			pass
		BOTIN_ORO:
			var n: int = cantidad if cantidad > 0 else oro_de(zona, randf(), luz_zona, perfil_zona)
			soltado.append({"que": BOTIN_ORO, "n": n})
			if raiz != null:
				Combate3D.Botin3D.soltar(raiz, jug, n, punto)
		BOTIN_POCION:
			var n2: int = cantidad if cantidad > 0 else int(fila["pocion"])
			soltado.append({"que": BOTIN_POCION, "n": n2})
			BotinObjeto3D.soltar(raiz, jug, BOTIN_POCION, n2, punto)
		_:
			var n3: int = maxi(cantidad, 1)
			soltado.append({"que": que, "n": n3})
			BotinObjeto3D.soltar(raiz, jug, que, n3, punto)
	# El material extra del jarrón (la esquirla de la Cueva): solo si la zona lo da y el botín no es «nada».
	var prob: float = float(fila.get("mineral", 0.0))
	if tipo == "jarron" and que != BOTIN_NADA and prob > 0.0:
		var mineral: String = Objetos.mineral_de("jarron", "romper")
		var tirada: float = randf() if tirada_forzada < 0.0 else tirada_forzada
		if mineral != "" and tirada < prob:
			soltado.append({"que": mineral, "n": 1})
			BotinObjeto3D.soltar(raiz, jug, mineral, 1, punto + Vector3(0.0, 0.0, -0.5))


func _jugador() -> Jugador3D:
	if not is_inside_tree():
		return null
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster")
	return (lanz.get("jugador") as Jugador3D) if lanz != null and lanz.get("jugador") is Jugador3D else null


## Objeto suelto en el suelo (la poción o el material de un rompible): flota y gira; al pasar cerca se mete en la mochila con el aviso de calidad de siempre.
## Si la mochila está llena se queda ahí (y avisa) hasta que haya sitio.
class BotinObjeto3D extends MeshInstance3D:
	const ALCANCE: float = 1.1
	const ALTURA: float = 0.35
	const TAMANO: float = 0.2
	var jugador: Jugador3D = null
	var objeto: String = ""
	var cantidad: int = 1
	var recogido: bool = false
	var _t: float = 0.0
	var _base_y: float = 0.0
	var _t_aviso: float = 0.0

	static func soltar(p_mundo: Node3D, p_jugador: Jugador3D, id: String, n: int, pos: Vector3) -> BotinObjeto3D:
		if p_mundo == null:
			return null
		var b := BotinObjeto3D.new()
		b.jugador = p_jugador
		b.objeto = id
		b.cantidad = n
		var caja := BoxMesh.new()
		caja.size = Vector3.ONE * TAMANO
		var m := StandardMaterial3D.new()
		m.albedo_color = Objetos.color(id)
		m.emission_enabled = true
		m.emission = Objetos.color(id)
		m.emission_energy_multiplier = 0.5
		m.roughness = 0.4
		caja.material = m
		b.mesh = caja
		b.name = "Botin_" + id
		b.position = pos + Vector3(randf_range(-0.4, 0.4), ALTURA, randf_range(0.2, 0.6))
		b._base_y = b.position.y
		p_mundo.add_child(b)
		return b

	func _process(delta: float) -> void:
		if recogido:
			return
		_t += delta
		_t_aviso -= delta
		position.y = _base_y + sin(_t * 3.0) * 0.06
		rotate_y(delta * 2.0)
		if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
			return
		var d: float = Vector2(jugador.position.x - position.x, jugador.position.z - position.z).length()
		if d < ALCANCE and absf(jugador.position.y - (_base_y - ALTURA)) < 1.4:
			recoger()

	## Lo mete en la mochila. Devuelve false si no cabe.
	func recoger() -> bool:
		if recogido:
			return false
		var lanz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
		if Estado.i().agregar(objeto, cantidad) <= 0:
			if _t_aviso <= 0.0 and lanz != null and lanz.has_method("avisar"):
				lanz.call("avisar", "Mochila llena")
				_t_aviso = 2.0
			return false
		recogido = true
		AvisoObjeto.mostrar(lanz, objeto, cantidad)
		PlayLog.event("objeto_suelo", {"objeto": objeto, "n": cantidad})
		queue_free()
		return true
