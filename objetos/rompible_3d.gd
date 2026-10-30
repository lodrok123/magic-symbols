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
## BOTÍN (F1 de docs/PLAN_BASE_DATOS.md, 29/10: ya no hay cifras aquí). El botín sale de la TABLA `jarron_<zona>` de `nucleo/datos/botin_tablas.tsv` (`Botin.tabla_de_zona`): la zona la da
## Zonas3D con su `botin=` o su `nombre=` o, si no, el nombre de su luz (bosque, ruinas, cueva…); fuera de toda zona vale la zona de la escena; una zona sin tabla usa `jarron_bosque`.
## `botin=` dice QUÉ se tira:
##   zona     (lo normal) UNA tirada de la tabla de la zona (`Botin.tirar`): casi siempre nada, a veces oro, poción o, en la cueva, esquirla de cristal
##   oro      monedas: una cantidad al azar entre las dos cifras de la fila `oro` de la tabla de la zona (`cantidad=<n>` la fija)
##   pocion   `pocion` en el suelo, la cantidad de la fila `pocion` de la zona (`cantidad=<n>` la fija)
##   <objeto> cualquier id de `Objetos.DATOS` (esquirla_cristal, seta…): 1 unidad (`cantidad=<n>`)
##   nada     un jarrón vacío (sirve de adorno, de gancho de puzle o de sorpresa mala)
## Todo cae al suelo como `BotinObjeto3D` (o la moneda de siempre, el oro) y se coge pasando cerca, con el aviso de calidad de siempre; si la bolsa está llena se queda ahí.
##
## Se coloca desde un mapa con `; pieza <id> jarron|caja <x> <y> [botin=…] [cantidad=<n>] [alto=si] [pequena=si]` (escenas/puzle.gd), o con `preparar` desde código.

signal roto

const ZONA_DEFECTO: String = "bosque"      ## la zona de un jarrón fuera de toda zona (y su tabla `jarron_bosque`)
const BASE_TABLA: String = "jarron"         ## las tablas de botín de un jarrón o una caja son `jarron_<zona>`
const BOTIN_ORO: String = "oro"
const BOTIN_POCION: String = "pocion"
const BOTIN_NADA: String = "nada"
const BOTIN_PERFIL: String = "zona"

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

## Para las pruebas de la tirada: `Botin.tirada_forzada` (ya no hay una propia de los rompibles).

var celda: Vector2i = Vector2i.ZERO
var tipo: String = "jarron"
var botin: String = BOTIN_ORO
var cantidad: int = 0                       ## 0 = la de la zona
var alternativo: bool = false               ## alto=si / pequena=si
var nivel: String = ""
var roto_ya: bool = false
var soltado: Array = []                     ## lo que soltó al romperse: [{"que": "oro"|id, "n": int}] (las pruebas lo leen)
var zona: String = ""                       ## la zona donde se rompió (la que decidió el botín)
var tabla_usada: String = ""                ## la tabla de botín que se usó (`jarron_cueva`…)
var botin_efectivo: String = ""             ## lo que tocó de verdad (con `botin=zona`, lo primero que salió de la tirada; "nada" si no salió nada)
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


## ¿Es un valor válido de `botin=`? (oro, pocion, nada, zona o un objeto de Objetos.DATOS).
static func botin_valido(t: String) -> bool:
	return t == BOTIN_ORO or t == BOTIN_POCION or t == BOTIN_NADA or t == BOTIN_PERFIL or Objetos.existe(t)


func _soltar_botin(punto: Vector3) -> void:
	soltado = []
	var luz_zona: String = ""
	var zn: Node = _mundo.get_node_or_null("Zonas3D") if _mundo != null and is_instance_valid(_mundo) else null
	if zn != null and zn.has_method("luz_en"):
		luz_zona = String(zn.call("luz_en", celda))
	var perfil_zona: String = String(zn.call("botin_en", celda)) if zn != null and zn.has_method("botin_en") else ""
	tabla_usada = Botin.tabla_de_zona(BASE_TABLA, zona, luz_zona, perfil_zona)
	var raiz: Node3D = (_mundo as Node3D) if _mundo is Node3D else (get_parent() as Node3D)
	var lista: Array = []
	match botin:
		BOTIN_NADA:
			pass
		BOTIN_PERFIL:
			lista = Botin.tirar(tabla_usada)
		BOTIN_ORO:
			var n: int = cantidad if cantidad > 0 else Botin.entre(Botin.rango(tabla_usada, BOTIN_ORO))
			lista.append({"que": BOTIN_ORO, "n": n})
		BOTIN_POCION:
			var n2: int = cantidad if cantidad > 0 else maxi(Botin.rango(tabla_usada, BOTIN_POCION).x, 1)
			lista.append({"que": BOTIN_POCION, "n": n2})
		_:
			lista.append({"que": botin, "n": maxi(cantidad, 1)})
	botin_efectivo = String((lista[0] as Dictionary)["que"]) if not lista.is_empty() else BOTIN_NADA
	soltado = lista
	Botin.soltar(raiz, punto, lista)


func _jugador() -> Jugador3D:
	if not is_inside_tree():
		return null
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster")
	return (lanz.get("jugador") as Jugador3D) if lanz != null and lanz.get("jugador") is Jugador3D else null
