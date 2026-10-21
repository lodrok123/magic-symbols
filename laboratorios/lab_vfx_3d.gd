class_name LabVfx3D
extends RefCounted
## Pestaña F4 del laboratorio de hechizos (PLAN_TRES_FRENTES §2/§3, LAB_HECHIZOS_SIGUIENTE #11): la MATRIZ DE APROBACIÓN DE VFX (19/10, Juego).
## Pablo mira cada combinación lanzada en la sala y la marca aprobada / rechazada / con nota. Lo marcado se guarda en `user://vfx_aprobados.json`:
## esa lista es el trabajo pendiente del Pipeline (lo rechazado y lo que lleva nota).
##
## La matriz son cuatro ejes:   estado (6) × volumen (4) × propiedad (5) × impacto (4) = 480 celdas.
##   estado     sólido · líquido · plasma · energía · gas · campo   (cada uno con su elemento: tierra, agua, fuego, rayo, viento, tiempo)
##   volumen    esfera · X×3 · Y×2 · Z×3                           (N × el diámetro de la esfera base; se da por los semiejes del Hechizo)
##   propiedad  ninguna · viaja · copias · crece · solidez
##   impacto    suelo · goblin · agua · objeto                     (sobre qué cae o contra qué choca)
## CRITERIO de la fase (PLAN_TRES_FRENTES §2): las 24 celdas BASE (volumen esfera, propiedad ninguna) aprobadas, o sea los 4 impactos en los 6 estados.
## PRESUPUESTO por hechizo (§2): ≤ MAX_LUCES luces y ≤ MAX_PARTICULAS partículas. Se MIDE en la sala al lanzar (pico de la ventana de medida menos lo que ya
## había) y se guarda con la marca; una celda por encima del presupuesto no se puede aprobar (se anota y se rechaza a mano).
##
## Por qué los volúmenes se dan por semiejes y no con los glifos: los glifos topan en 3 m de semieje horizontal y 1 m de vertical (ESPEC_HECHIZO §2) y la
## matriz del Pipeline pide 3,0 y 2,0; así se compara lo que el juego puede dar de verdad. Cada celda parte de `Hechizo.construir(runa, {}, 1.0)` SIN lo
## que haya tocado el lab en F1 (se aparta `cambios_hechizo` mientras se lanza), para que la matriz no dependa de la sesión de diseño.
##
## Lo monta `LabHechizos3D._montar_f4` y le pasa las teclas mientras F4 está abierta; `paso(delta)` lo llama el `_process` del lab.
## Teclas:  ↑ ↓ eje · ← → valor · Espacio lanza la celda · A aprueba · R rechaza · N nota rápida (rota) · Supr borra la marca ·
##          Tab salta a la siguiente celda base sin marcar · G (la del lab) guarda también todo lo demás.

const RUTA: String = "user://vfx_aprobados.json"
const MAX_LUCES: int = 2
const MAX_PARTICULAS: int = 400
const VENTANA_MEDIDA_S: float = 1.2         ## s de juego tras lanzar durante los que se vigila el pico de luces y partículas
const PERIODO_MEDIDA_S: float = 0.05
const DISTANCIA_VIAJE: float = 3.0          ## casillas que recorre la propiedad «viaja» (= lo que separa al jugador de su objetivo)
const COPIAS: int = 3
const CRECE: float = 1.0                    ## m/s de radio
const SOLIDEZ: float = 1.0

## [id, elemento (.tres), nombre]
const ESTADOS: Array = [["solido", "earth", "sólido"], ["liquido", "water", "líquido"], ["plasma", "fire", "plasma"],
	["energia", "lightning", "energía"], ["gas", "wind", "gas"], ["campo", "time", "campo"]]
## [id, múltiplo del diámetro en X, en Y, en Z]
const VOLUMENES: Array = [["esfera", 1.0, 1.0, 1.0], ["X3", 3.0, 1.0, 1.0], ["Y2", 1.0, 2.0, 1.0], ["Z3", 1.0, 1.0, 3.0]]
const PROPIEDADES: Array = ["ninguna", "viaja", "copias", "crece", "solidez"]
## id -> {objetivo: casilla del lab donde cae/choca, desde: donde se pone el jugador}. Siempre a DISTANCIA_VIAJE casillas en línea recta de X creciente o Z creciente.
const IMPACTOS: Array = [
	{"id": "suelo", "objetivo": Vector2i(8, 8), "desde": Vector2i(5, 8)},         # suelo libre, entre el jugador y la primera diana
	{"id": "goblin", "objetivo": Vector2i(19, 6), "desde": Vector2i(16, 6)},      # goblin quieto
	{"id": "agua", "objetivo": Vector2i(6, 14), "desde": Vector2i(6, 11)},        # el estanque
	{"id": "objeto", "objetivo": Vector2i(21, 13), "desde": Vector2i(18, 13)},    # el barril
]
const EJES: PackedStringArray = ["estado", "volumen", "propiedad", "impacto"]
const NOTAS_RAPIDAS: PackedStringArray = ["", "demasiado pequeño", "demasiado grande", "color", "forma", "dura poco", "dura mucho", "no se ve el impacto", "demasiado caro"]
const APROBADO: String = "aprobado"
const RECHAZADO: String = "rechazado"

var lab: Variant = null                     ## LabHechizos3D
var sel: Array = [0, 0, 0, 0]               ## índice elegido en cada eje
var eje: int = 0
var marcas: Dictionary = {}                 ## clave -> {estado: "aprobado"|"rechazado"|"", nota: String, luces: int, particulas: int}
var ultimo_mensaje: String = ""
var lanzamientos: int = 0
var guardar_al_marcar: bool = true          ## las pruebas lo apagan para no escribir en user://

var _medida: Dictionary = {}                ## medida en curso: {clave, t, prox, base_luces, base_part, luces, part}
var _ultima_medida: Dictionary = {}         ## la última terminada: {clave, luces, particulas}


func iniciar(l: Variant) -> void:
	lab = l
	cargar()


# ---------------------------------------------------------------------------------------------------------------------
#  La matriz
# ---------------------------------------------------------------------------------------------------------------------

static func total_celdas() -> int:
	return ESTADOS.size() * VOLUMENES.size() * PROPIEDADES.size() * IMPACTOS.size()


static func clave_de(e: int, v: int, p: int, i: int) -> String:
	return "%s|%s|%s|%s" % [ESTADOS[e][0], VOLUMENES[v][0], PROPIEDADES[p], IMPACTOS[i]["id"]]


func clave() -> String:
	return clave_de(int(sel[0]), int(sel[1]), int(sel[2]), int(sel[3]))


static func es_base(e: int, v: int, p: int, _i: int) -> bool:
	return v == 0 and p == 0


## Las 24 celdas del criterio: [[e, v, p, i], …] en orden estado → impacto.
static func celdas_base() -> Array:
	var r: Array = []
	for e in range(ESTADOS.size()):
		for i in range(IMPACTOS.size()):
			r.append([e, 0, 0, i])
	return r


func valor_marca(k: String) -> String:
	return String((marcas.get(k, {}) as Dictionary).get("estado", ""))


func mover_eje(d: int) -> void:
	eje = posmod(eje + d, EJES.size())


func cambiar_valor(d: int) -> void:
	sel[eje] = posmod(int(sel[eje]) + d, _cuantos(eje))


func _cuantos(e: int) -> int:
	return [ESTADOS.size(), VOLUMENES.size(), PROPIEDADES.size(), IMPACTOS.size()][e]


func poner(e: int, v: int, p: int, i: int) -> void:
	sel = [clampi(e, 0, ESTADOS.size() - 1), clampi(v, 0, VOLUMENES.size() - 1), clampi(p, 0, PROPIEDADES.size() - 1), clampi(i, 0, IMPACTOS.size() - 1)]


## El hechizo de la celda elegida (o de la que se pida): el elemento solo, sin glifos, con el volumen y la propiedad puestos por los campos.
func hechizo(s: Array = []) -> Hechizo:
	var q: Array = sel if s.is_empty() else s
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % String(ESTADOS[int(q[0])][1])) as RuneData
	var h: Hechizo = Hechizo.construir(rune, {}, 1.0, rune.cinematico)       # 20/10 (entrada 211): la celda «campo» es la runa del tiempo, cinemática: se pide con permiso expreso
	var vol: Array = VOLUMENES[int(q[1])]
	var base: float = Sigils.RADIO_BASE_V2
	var cambios: Dictionary = {"semiejes.x": base * float(vol[1]), "semiejes.y": base * float(vol[2]), "semiejes.z": base * float(vol[3]),
		"velocidad": 0.0, "distancia_max": 0.0, "persiste": maxf(h.persiste, 1.0)}            # quieto y con vida: se queda a la vista mientras se mide
	match String(PROPIEDADES[int(q[2])]):
		"viaja":
			cambios["distancia_max"] = DISTANCIA_VIAJE
		"copias":
			cambios["copias"] = COPIAS
		"crece":
			cambios["crece"] = CRECE
		"solidez":
			cambios["solidez"] = SOLIDEZ
	return h.con(cambios)


## Dónde nace y hacia dónde va (mundo). «viaja» sale del jugador y llega al objetivo; lo demás nace en la casilla de delante del objetivo (pegado a él).
func salida(s: Array = []) -> Dictionary:
	var q: Array = sel if s.is_empty() else s
	var imp: Dictionary = IMPACTOS[int(q[3])]
	var desde: Vector2i = imp["desde"]
	var obj: Vector2i = imp["objetivo"]
	var dir: Vector3 = Terreno3D.centro_de(obj, 0.0) - Terreno3D.centro_de(desde, 0.0)
	dir.y = 0.0
	dir = dir.normalized()
	var origen: Vector3 = Terreno3D.centro_de(desde, Terreno3D.y_pies(desde))
	if int(q[2]) != 1:
		# Lo que no viaja nace JUNTO al objetivo (una casilla antes): sobre el agua o el barril un sólido o un líquido no se puede colocar (el lanzador lo rechaza)
		var antes: Vector2i = obj - Vector2i(roundi(dir.x), roundi(dir.z))
		origen = Terreno3D.centro_de(antes, Terreno3D.y_pies(antes))
	return {"desde": desde, "origen": origen, "dir": dir}


## Lanza la celda elegida en la sala: limpia lo que dejó la anterior, pone al jugador, lanza y empieza a medir. Devuelve las casillas que ocupó (0 = no salió).
func lanzar() -> int:
	if lab == null or lab._l == null:
		return 0
	lab.limpiar_sala()
	var antes: Array = _luces_y_particulas()            # lo que ya había en la sala (luces de los braseros, restos de VFX anterior): se resta del pico
	var sa: Dictionary = salida()
	lab.colocar_jugador(sa["desde"])
	lab._jug.mirar_hacia(sa["dir"])
	var guardados: Dictionary = (lab.cambios_hechizo as Dictionary).duplicate(true)
	lab.cambios_hechizo.clear()                          # el mismo diccionario que ve el lanzador: aparte lo de F1 mientras sale
	var previos: Array = _dibujo_por_estado(true)
	var n: int = lab._l.lanzar_hechizo(hechizo(), sa["origen"], sa["dir"])
	_dibujo_por_estado(false, previos)
	lab.cambios_hechizo.merge(guardados)
	lanzamientos += 1
	_medida = {"clave": clave(), "t": 0.0, "prox": 0.0, "base_luces": int(antes[0]), "base_part": int(antes[1]), "luces": 0, "part": 0}
	ultimo_mensaje = "lanzado %s (%d casillas)" % [clave(), n]
	return n


## 20/10 (Pipeline, entrada 203): esta matriz aprueba el dibujo POR ESTADO (VfxEstado3D), que en la maqueta está apagado de serie porque manda el de ELEMENTO
## (VfxElemento3D). Mientras se lanza la celda se enciende el de estado y se apaga el de elemento, para que se mida y se vea solo aquel; después se restituye.
## Los receptores deciden al RECIBIR la señal (síncrona dentro de `lanzar_hechizo`), así que basta con rodear esa llamada. Devuelve las banderas de antes.
func _dibujo_por_estado(entrar: bool, previos: Array = []) -> Array:
	var raiz: Node = (lab as Node).get_tree().root
	var ve: VfxEstado3D = raiz.find_child("VfxEstado3D", true, false) as VfxEstado3D
	var vl: VfxElemento3D = raiz.find_child("VfxElemento3D", true, false) as VfxElemento3D
	if entrar:
		var antes: Array = [ve.encendido if ve != null else true, vl.encendido if vl != null else true]
		if ve != null:
			ve.encendido = true
		if vl != null:
			vl.encendido = false
		return antes
	if previos.size() == 2:
		if ve != null:
			ve.encendido = bool(previos[0])
		if vl != null:
			vl.encendido = bool(previos[1])
	return previos


## Cuenta las luces y las partículas VISIBLES del árbol. Devuelve [luces, partículas].
func _luces_y_particulas() -> Array:
	var luces: int = 0
	var part: int = 0
	if lab == null:
		return [0, 0]
	var pila: Array = [(lab as Node).get_tree().root]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		if n is Light3D:
			var l3: Light3D = n as Light3D
			if l3.is_visible_in_tree() and l3.light_energy > 0.0 and not (l3 is DirectionalLight3D):
				luces += 1
		elif n is GPUParticles3D:
			var g: GPUParticles3D = n as GPUParticles3D
			if g.emitting and g.is_visible_in_tree():
				part += g.amount
		elif n is CPUParticles3D:
			var c: CPUParticles3D = n as CPUParticles3D
			if c.emitting and c.is_visible_in_tree():
				part += c.amount
		for h in n.get_children():
			pila.append(h)
	return [luces, part]


func paso(delta: float) -> void:
	if _medida.is_empty():
		return
	_medida["t"] = float(_medida["t"]) + delta
	if float(_medida["t"]) >= float(_medida["prox"]):
		_medida["prox"] = float(_medida["t"]) + PERIODO_MEDIDA_S
		var m: Array = _luces_y_particulas()
		_medida["luces"] = maxi(int(_medida["luces"]), int(m[0]) - int(_medida["base_luces"]))
		_medida["part"] = maxi(int(_medida["part"]), int(m[1]) - int(_medida["base_part"]))
	if float(_medida["t"]) >= VENTANA_MEDIDA_S:
		_ultima_medida = {"clave": _medida["clave"], "luces": int(_medida["luces"]), "particulas": int(_medida["part"])}
		var k: String = String(_medida["clave"])
		var ficha: Dictionary = marcas.get(k, {"estado": "", "nota": ""})
		ficha["luces"] = int(_medida["luces"])
		ficha["particulas"] = int(_medida["part"])
		marcas[k] = ficha
		_medida = {}
		ultimo_mensaje = "medido %s: %d luces, %d partículas" % [k, int(ficha["luces"]), int(ficha["particulas"])]


func midiendo() -> bool:
	return not _medida.is_empty()


## ¿La celda cabe en el presupuesto? Sin medida todavía, no se sabe: false.
func en_presupuesto(k: String) -> bool:
	var f: Dictionary = marcas.get(k, {})
	return f.has("luces") and int(f["luces"]) <= MAX_LUCES and int(f["particulas"]) <= MAX_PARTICULAS


# ---------------------------------------------------------------------------------------------------------------------
#  Marcar
# ---------------------------------------------------------------------------------------------------------------------

func _ficha(k: String) -> Dictionary:
	if not marcas.has(k):
		marcas[k] = {"estado": "", "nota": ""}
	return marcas[k]


## Aprueba la celda elegida. Si la medida dice que se pasa del presupuesto (o no se ha medido), NO la aprueba y lo dice. Devuelve si quedó aprobada.
func aprobar() -> bool:
	var k: String = clave()
	var f: Dictionary = _ficha(k)
	if not f.has("luces"):
		ultimo_mensaje = "no se aprueba: lánzala antes (Espacio) para medir luces y partículas"
		return false
	if not en_presupuesto(k):
		ultimo_mensaje = "no se aprueba: se pasa del presupuesto (%d luces ≤ %d, %d partículas ≤ %d)" % [int(f["luces"]), MAX_LUCES, int(f["particulas"]), MAX_PARTICULAS]
		return false
	f["estado"] = APROBADO
	ultimo_mensaje = "aprobada %s" % k
	_guardar_auto()
	return true


func rechazar() -> void:
	var f: Dictionary = _ficha(clave())
	f["estado"] = RECHAZADO
	ultimo_mensaje = "rechazada %s" % clave()
	_guardar_auto()


## Rota la nota rápida de la celda elegida (vacía → … → vacía). Una nota no cambia aprobado/rechazado: va aparte.
func rotar_nota() -> String:
	var f: Dictionary = _ficha(clave())
	var i: int = NOTAS_RAPIDAS.find(String(f.get("nota", "")))
	f["nota"] = String(NOTAS_RAPIDAS[(i + 1) % NOTAS_RAPIDAS.size()])
	ultimo_mensaje = "nota de %s: %s" % [clave(), String(f["nota"]) if String(f["nota"]) != "" else "(ninguna)"]
	_guardar_auto()
	return String(f["nota"])


func poner_nota(texto: String) -> void:
	_ficha(clave())["nota"] = texto
	_guardar_auto()


## Quita la marca (y la nota) pero deja la medida.
func borrar_marca() -> void:
	var f: Dictionary = _ficha(clave())
	f["estado"] = ""
	f["nota"] = ""
	ultimo_mensaje = "marca borrada de %s" % clave()
	_guardar_auto()


## Salta a la primera celda BASE sin aprobar ni rechazar (después de la actual, dando la vuelta). Devuelve false si ya no quedan.
func siguiente_base_pendiente() -> bool:
	var base: Array = celdas_base()
	var actual: int = -1
	for j in range(base.size()):
		if clave_de(base[j][0], base[j][1], base[j][2], base[j][3]) == clave():
			actual = j
			break
	for d in range(1, base.size() + 1):
		var c: Array = base[posmod(actual + d, base.size())]
		if valor_marca(clave_de(c[0], c[1], c[2], c[3])) == "":
			poner(c[0], c[1], c[2], c[3])
			return true
	return false


# ---------------------------------------------------------------------------------------------------------------------
#  Cuentas
# ---------------------------------------------------------------------------------------------------------------------

func contar(estado: String) -> int:
	var n: int = 0
	for k in marcas:
		if String((marcas[k] as Dictionary).get("estado", "")) == estado:
			n += 1
	return n


## Cuántas de las 24 celdas base están aprobadas (en total y por estado).
func base_aprobadas() -> int:
	var n: int = 0
	for c in celdas_base():
		if valor_marca(clave_de(c[0], c[1], c[2], c[3])) == APROBADO:
			n += 1
	return n


func base_aprobadas_de(e: int) -> int:
	var n: int = 0
	for i in range(IMPACTOS.size()):
		if valor_marca(clave_de(e, 0, 0, i)) == APROBADO:
			n += 1
	return n


## ¿Se cumple el criterio de la fase? Las 24 celdas base aprobadas.
func criterio_cumplido() -> bool:
	return base_aprobadas() == celdas_base().size()


# ---------------------------------------------------------------------------------------------------------------------
#  Guardar / cargar
# ---------------------------------------------------------------------------------------------------------------------

## Lo que se guarda: solo las celdas con marca o nota (la medida sola no es trabajo para el Pipeline) más las cuentas.
func datos() -> Dictionary:
	var celdas: Dictionary = {}
	for k in marcas:
		var f: Dictionary = marcas[k]
		if String(f.get("estado", "")) != "" or String(f.get("nota", "")) != "":
			celdas[k] = f.duplicate()
	return {"version": 1, "presupuesto": {"luces": MAX_LUCES, "particulas": MAX_PARTICULAS},
		"cuentas": {"celdas": total_celdas(), "aprobadas": contar(APROBADO), "rechazadas": contar(RECHAZADO),
			"base_aprobadas": base_aprobadas(), "base_total": celdas_base().size(), "criterio_cumplido": criterio_cumplido()},
		"celdas": celdas}


func guardar(ruta: String = RUTA) -> bool:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(datos(), "\t"))
	return true


func cargar(ruta: String = RUTA) -> bool:
	if not FileAccess.file_exists(ruta):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if not (d is Dictionary) or not (d as Dictionary).has("celdas"):
		return false
	marcas.clear()
	var celdas: Dictionary = (d as Dictionary)["celdas"]
	for k in celdas:
		if celdas[k] is Dictionary:
			marcas[String(k)] = (celdas[k] as Dictionary).duplicate()
	return true


func _guardar_auto() -> void:
	if guardar_al_marcar:
		guardar()


# ---------------------------------------------------------------------------------------------------------------------
#  Teclas y texto
# ---------------------------------------------------------------------------------------------------------------------

## Devuelve true si la tecla era de F4 (el lab no la procesa más). G, P, F1–F4 y el Numpad se dejan al lab.
func tecla(k: InputEventKey) -> bool:
	var arrastre: bool = k.keycode == KEY_LEFT or k.keycode == KEY_RIGHT or k.keycode == KEY_UP or k.keycode == KEY_DOWN
	if k.echo and not arrastre:
		return false
	match k.keycode:
		KEY_UP:
			mover_eje(-1)
		KEY_DOWN:
			mover_eje(1)
		KEY_LEFT:
			cambiar_valor(-1)
		KEY_RIGHT:
			cambiar_valor(1)
		KEY_SPACE:
			lanzar()
		KEY_A:
			aprobar()
		KEY_R:
			rechazar()
		KEY_N:
			rotar_nota()
		KEY_DELETE:
			borrar_marca()
		KEY_TAB:
			if not siguiente_base_pendiente():
				ultimo_mensaje = "las 24 celdas base ya tienen marca"
		_:
			return false
	return true


func texto() -> String:
	var t: PackedStringArray = []
	var k: String = clave()
	var f: Dictionary = marcas.get(k, {})
	var partes: PackedStringArray = []
	for e in range(EJES.size()):
		var nombre: String = [String(ESTADOS[int(sel[0])][2]), String(VOLUMENES[int(sel[1])][0]), String(PROPIEDADES[int(sel[2])]), String(IMPACTOS[int(sel[3])]["id"])][e]
		partes.append(("▶ %s: %s ◀" if e == eje else "%s: %s") % [EJES[e], nombre])
	t.append("F4 VFX · " + "   ".join(partes))
	var marca: String = String(f.get("estado", ""))
	var medida: String = "sin medir"
	if f.has("luces"):
		var ok: bool = en_presupuesto(k)
		medida = "%d luces (≤ %d) · %d partículas (≤ %d)%s" % [int(f["luces"]), MAX_LUCES, int(f["particulas"]), MAX_PARTICULAS, "" if ok else "   ¡SE PASA!"]
	if midiendo():
		medida = "midiendo… %.1f/%.1f s" % [float(_medida["t"]), VENTANA_MEDIDA_S]
	t.append("Celda %s%s · marca: %s%s · %s" % [k, " (BASE)" if es_base(int(sel[0]), int(sel[1]), int(sel[2]), int(sel[3])) else "",
		marca if marca != "" else "sin marcar", (" · nota: " + String(f.get("nota", ""))) if String(f.get("nota", "")) != "" else "", medida])
	var por_estado: PackedStringArray = []
	for e in range(ESTADOS.size()):
		por_estado.append("%s %d/%d" % [String(ESTADOS[e][2]), base_aprobadas_de(e), IMPACTOS.size()])
	t.append("Criterio (base: esfera · ninguna · 4 impactos): %d/%d → %s        Todas: %d aprobadas · %d rechazadas de %d" % [
		base_aprobadas(), celdas_base().size(), "CUMPLIDO" if criterio_cumplido() else "pendiente", contar(APROBADO), contar(RECHAZADO), total_celdas()])
	t.append("Por estado: " + " · ".join(por_estado))
	t.append("↑↓ eje · ←→ valor · Espacio lanza · A aprueba · R rechaza · N nota · Supr borra · Tab siguiente base sin marcar · se guarda solo en %s" % RUTA)
	if ultimo_mensaje != "":
		t.append(ultimo_mensaje)
	return "\n".join(t)
