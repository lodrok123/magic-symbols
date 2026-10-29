extends SceneTree
## CAMPOS EJECUTADOS (24/10, lote 1 de la auditoría de Hechizo; 05_auditoria_hechizo.md §C-4 y propuesta 5), sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_campos_ejecutados.gd
## Para CADA campo de `Hechizo.CAMPOS` (los tres semiejes por separado): `con({campo: valor ≠ defecto})` tiene que producir una DIFERENCIA OBSERVABLE al ejecutarlo — en `HechizoVivo`
## (casillas, tandas, radio de acierto, hora de llegada, zonas, solideces, pulsos, eventos, lo que llega al VFX por `hechizo_v2` y `vfx_hechizo`…) o en `Combate3D.golpe` (daño, estados, empuje,
## veneno) — o el campo está en `CAMPOS_SOLO_DATO` con el motivo. Así ningún campo queda muerto sin que se diga, y la deuda queda escrita en un sitio.
## Las dos direcciones se comprueban: un campo con fila en `FILAS` que NO produce diferencia es un FALLO (se anunció que se lee y no se lee), y un campo de `CAMPOS_SOLO_DATO` que SÍ
## produce alguna diferencia en cualquiera de los escenarios genéricos también (la lista miente: hay que sacarlo). Un campo nuevo de `Hechizo.CAMPOS` que no esté en ninguna de las dos
## tablas es un FALLO: obliga a decidir.
## La «huella» de una ejecución es una cadena con todo lo que se puede medir de ella; dos huellas distintas = el campo se notó.

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var marcas: Array = []                       ## [elemento, celda] de cada _al_impactar (el estado de suelo que deja un hechizo)
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(elemento: String, punto: Vector3) -> void:
		marcas.append([elemento, Terreno3D.celda_de(punto)])

class JugadorFalso extends Jugador3D:
	var recibido: float = 0.0
	func recibir_dano(cantidad: float, _desde: Vector3 = Vector3.ZERO) -> void:
		recibido += cantidad

const LADO: int = 20
const SALIDA: Vector2i = Vector2i(5, 8)
const DT: float = 1.0 / 60.0
const MAX_PASOS: int = 1500
const V_LENTA: float = 2.0                      ## m/s de las flechas de estas pruebas (la de verdad es 1,74): da tiempo a ver el efecto de cada campo

## 29/10 (DANO_Y_TINTA): `potencia` ya NO está aquí: es la G de `Dano` y `Combate3D.decidir_golpe` la multiplica (con 1,0 hoy, pero cambiarla cambia el daño).
## Campos que NO producen ninguna diferencia observable en HechizoVivo ni en Combate3D, con el motivo (la auditoría los llama «solo dato» y «sombra del RuneData»). La prueba comprueba
## que de verdad no se notan: si alguno empieza a leerse, tiene que SALIR de esta lista. El valor de `CAMBIO_SOLO_DATO` es el que se prueba.
const CAMPOS_SOLO_DATO: Dictionary = {
	"intensidad_estado": "SOLO DATO: ESPEC §1.5 «× todas las duraciones de estado»; ninguna duración la multiplica",
	"elasticidad": "SOLO DATO: el rebote invierte la velocidad entera (HechizoVivo._avanzar); no conserva una fracción",
	"ralentiza_fuerza": "SOLO DATO: Combate3D.vel_mult usa un 0,6 fijo (casualmente 1 − 0,4 de la tierra); el campo no se lee",
	"densidad": "SOLO DATO: ESPEC §1.4 lo permite («solo se rellena»); de aquí saldrán las reacciones en la fase de cálculo",
	"temperatura": "SOLO DATO: ESPEC §1.4 («solo se rellena»)",
	"humedad": "SOLO DATO: ESPEC §1.4 («solo se rellena»)",
	"conductividad": "SOLO DATO: ESPEC §1.4 («solo se rellena»); la conducción la decide Terreno3D.conduce, no el hechizo",
	"empuje": "SOMBRA DEL RuneData: la zona de gas lee `z.rune.empuje` (HechizoVivo.pulso_gas), no `Hechizo.empuje`",
	"deja": "SOMBRA DEL RuneData: el estado de suelo sale de `rune.deja` (HechizoVivo._materia_*), no de `Hechizo.deja`",
	"pisable": "SOMBRA DEL RuneData: el bloque de tierra se decide con `rune.pisable` (HechizoVivo._materia_solido), no con `Hechizo.pisable`",
	"color": "SOMBRA DEL RuneData: el VFX elige el color por el nombre del elemento; HechizoVivo no lo lee (el Pipeline podría)",
}
## El valor ≠ defecto con que se prueba cada campo de arriba.
const CAMBIO_SOLO_DATO: Dictionary = {
	"intensidad_estado": 3.0, "elasticidad": 0.9, "ralentiza_fuerza": 0.9, "densidad": 4.0, "temperatura": 1.0, "humedad": 1.0, "conductividad": 1.0,
	"empuje": 0.9, "deja": "helado", "pisable": false, "color": Color(0.1, 0.9, 0.3),
}

## Un campo → cómo se prueba: esc = escenario («vol» quieto · «proy» flecha · «golpe» directo al enemigo), elem = el .tres, glifos = lo que pone la receta, base = cambios comunes,
## val = EL cambio que se mide, mundo = {enemigo/enemigo2/pared/jugador/desplaza_mano/mojado}: dónde están las cosas (en casillas desde SALIDA). Velocidades en m/s, longitudes en m.
const FILAS: Dictionary = {
	"semiejes.x": {"esc": "vol", "elem": "fire", "val": {"semiejes.x": 1.5}},
	"semiejes.y": {"esc": "vol", "elem": "fire", "val": {"semiejes.y": 0.7}},
	"semiejes.z": {"esc": "vol", "elem": "fire", "val": {"semiejes.z": 1.5}},
	"grosor_min": {"esc": "vol", "elem": "fire", "val": {"grosor_min": 0.4}},
	"copias": {"esc": "vol", "elem": "fire", "val": {"copias": 3}},
	"separacion": {"esc": "vol", "elem": "fire", "base": {"copias": 3}, "val": {"separacion": 3.0}},
	"dispersion": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 3.0, "gravedad": 0.0, "copias": 3}, "val": {"dispersion": 45.0}},
	"crece": {"esc": "vol", "elem": "fire", "base": {"semiejes.x": 2.5}, "val": {"crece": 0.5}},
	"escala_nace": {"esc": "vol", "elem": "fire", "base": {"semiejes.x": 2.5, "crece": 0.5}, "val": {"escala_nace": 0.9}},
	"solidez": {"esc": "vol", "elem": "fire", "val": {"solidez": 2.0}},
	"resuena": {"esc": "vol", "elem": "fire", "glifos": {"raido": 1}, "val": {"resuena": 8.0}},
	"velocidad": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 3.0, "gravedad": 0.0}, "val": {"velocidad": 4.0}},
	"aceleracion": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 3.0, "gravedad": 0.0}, "val": {"aceleracion": 1.0}},
	"gravedad": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 5.0, "gravedad": 0.0}, "val": {"gravedad": 1.0}},
	"distancia_max": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 3.0, "gravedad": 0.0}, "val": {"distancia_max": 5.0}},
	"elevacion": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 3.0, "gravedad": 0.0}, "val": {"elevacion": 1.0}},
	"persiste": {"esc": "vol", "elem": "fire", "val": {"persiste": 9.0}},
	"permanencia": {"esc": "vol", "elem": "fire", "val": {"permanencia": 4.0}},
	"retardo": {"esc": "vol", "elem": "fire", "val": {"retardo": 0.5}},
	"intervalo": {"esc": "vol", "elem": "fire", "val": {"intervalo": 0.5}},
	"altura_salida": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 3.0, "gravedad": 0.0}, "val": {"altura_salida": 1.0}},
	"impulso_salida": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 5.0, "gravedad": 1.0}, "val": {"impulso_salida": 2.5}},
	"rebotes": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 6.0, "gravedad": 0.0}, "val": {"rebotes": 1}, "mundo": {"pared": Vector2i(3, 0)}},
	"retorna": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 3.0, "gravedad": 0.0}, "val": {"retorna": true}},
	"busca": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 5.0, "gravedad": 0.0}, "val": {"busca": 1.0}, "mundo": {"enemigo": Vector2i(3, 1)}},
	"en_punto": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 3.0, "gravedad": 0.0}, "val": {"en_punto": true}, "mundo": {"desplaza_mano": Vector3(1.0, 0.0, 1.0)}},
	"dano": {"esc": "golpe", "elem": "fire", "val": {"dano": 77.0}},
	"potencia": {"esc": "golpe", "elem": "fire", "val": {"potencia": 3.0}},       # 29/10: G de `Dano` (daño × potencia); antes era solo dato
	"dano_periodico": {"esc": "vol", "elem": "fire", "val": {"dano_periodico": 30.0}, "mundo": {"enemigo": Vector2i(0, 0)}},
	"fuerza_golpe": {"esc": "golpe", "elem": "fire", "val": {"fuerza_golpe": 1500.0}},
	"perfora": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 5.0, "gravedad": 0.0}, "val": {"perfora": 1}, "mundo": {"enemigo": Vector2i(2, 0), "enemigo2": Vector2i(3, 0)}},
	"radio_explosion": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 5.0, "gravedad": 0.0}, "val": {"radio_explosion": 1.5}, "mundo": {"enemigo": Vector2i(2, 0), "enemigo2": Vector2i(2, 1)}},
	"golpea_lanzador": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 5.0, "gravedad": 0.0}, "val": {"golpea_lanzador": true}, "mundo": {"jugador": Vector2i(3, 0)}},
	"quema": {"esc": "golpe", "elem": "fire", "val": {"quema": 9.0}},
	"moja": {"esc": "golpe", "elem": "water", "val": {"moja": 9.0}},
	"congela": {"esc": "golpe", "elem": "ice", "val": {"congela": 9.0}},
	"congela_mojado": {"esc": "golpe", "elem": "ice", "val": {"congela_mojado": 9.0}, "mundo": {"mojado": 3.0}},
	"aturde": {"esc": "golpe", "elem": "lightning", "val": {"aturde": 5.0}},
	"ralentiza": {"esc": "golpe", "elem": "earth", "val": {"ralentiza": 9.0}},
	"interrumpe": {"esc": "golpe", "elem": "wind", "val": {"interrumpe": 3.0}},
	"veneno": {"esc": "golpe", "elem": "fire", "val": {"veneno": 6.0}},
	"veneno_dps": {"esc": "golpe", "elem": "fire", "base": {"veneno": 6.0}, "val": {"veneno_dps": 20.0}},
	"estado_materia": {"esc": "vol", "elem": "fire", "val": {"estado_materia": "campo"}},
	"choca_con": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 5.0, "gravedad": 0.0}, "val": {"choca_con": 1}, "mundo": {"enemigo": Vector2i(2, 0)}},
	"estela": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 3.0, "gravedad": 0.0}, "val": {"estela": "chispa"}},
	"efecto_impacto": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 5.0, "gravedad": 0.0}, "val": {"efecto_impacto": "chispa"}, "mundo": {"enemigo": Vector2i(2, 0)}},
	"eventos": {"esc": "proy", "elem": "fire", "base": {"velocidad": V_LENTA, "distancia_max": 3.0, "gravedad": 0.0}, "val": {"eventos": {"al_nacer": [{"accion": "vfx", "nombre": "x"}]}}},
}

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: JugadorFalso = null
var _vfx: Array = []                              ## [nombre, elemento] de la señal vfx_hechizo
var _senales: Array = []


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	# --- 0 · todos los campos de Hechizo.CAMPOS están en una de las dos tablas ---
	var todos: Array = []
	for par in Hechizo.CAMPOS:
		var campo: String = String(par[0])
		if campo == "semiejes":
			todos.append_array(["semiejes.x", "semiejes.y", "semiejes.z"])
		else:
			todos.append(campo)
	var sin_cubrir: Array = []
	for campo in todos:
		if not FILAS.has(campo) and not CAMPOS_SOLO_DATO.has(campo):
			sin_cubrir.append(campo)
	_ok("0 los %d campos de Hechizo.CAMPOS tienen su prueba (%d) o su motivo en CAMPOS_SOLO_DATO (%d)" % [todos.size(), FILAS.size(), CAMPOS_SOLO_DATO.size()], sin_cubrir.is_empty(), "sin cubrir: %s" % str(sin_cubrir))
	var sobran: Array = []
	for campo in FILAS:
		if not todos.has(campo):
			sobran.append(campo)
	for campo in CAMPOS_SOLO_DATO:
		if not todos.has(campo) or FILAS.has(campo) or not CAMBIO_SOLO_DATO.has(campo):
			sobran.append(campo)
	_ok("0 ninguna fila inventada, ninguna repetida entre las dos tablas y todo solo-dato trae su valor de prueba", sobran.is_empty(), "sobran: %s" % str(sobran))
	# --- 1 · cada campo con fila se NOTA ---
	var se_leen: int = 0
	for campo in FILAS:
		var fila: Dictionary = FILAS[campo]
		var base: String = _huella(fila, {})
		var con: String = _huella(fila, fila["val"] as Dictionary)
		var difiere: bool = base != con
		if difiere:
			se_leen += 1
		# control: la misma ejecución dos veces da la MISMA huella; si no, «difiere» no probaría nada (la huella llevaría ruido)
		var repetida: bool = _huella(fila, {}) == base
		_ok("1 %s: con(%s) cambia lo que se ejecuta (%s)%s" % [campo, str(fila["val"]), String(fila["esc"]), "" if repetida else " · HUELLA NO REPRODUCIBLE"], difiere and repetida, "" if difiere else "IGUAL: %s" % base.left(300))
	# --- 2 · cada campo solo-dato NO se nota en ningún escenario genérico ---
	for campo in CAMPOS_SOLO_DATO:
		var notado: Array = []
		for esc in _escenarios_genericos():
			var fila2: Dictionary = (esc as Dictionary).duplicate()
			var val: Dictionary = {campo: CAMBIO_SOLO_DATO[campo]}
			if _huella(fila2, {}) != _huella(fila2, val):
				notado.append("%s/%s" % [fila2["esc"], fila2["elem"]])
		_ok("2 %s está en CAMPOS_SOLO_DATO y de verdad no se nota en ningún escenario (%s)" % [campo, String(CAMPOS_SOLO_DATO[campo]).left(60)], notado.is_empty(), "SE NOTA en %s: sácalo de la lista" % str(notado))
	print("RESULTADO campos: %d de %d campos se ejecutan, %d son solo dato (la deuda)" % [se_leen, todos.size(), CAMPOS_SOLO_DATO.size()])
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Los escenarios con los que se comprueba que un campo «solo dato» no se nota: un volumen quieto con enemigo dentro de cada materia, una flecha que golpea y rebota, y el golpe directo de cada elemento.
func _escenarios_genericos() -> Array:
	var r: Array = []
	for e in ["fire", "water", "earth", "ice", "lightning", "wind"]:
		r.append({"esc": "vol", "elem": e, "mundo": {"enemigo": Vector2i(0, 0)}})
		r.append({"esc": "golpe", "elem": e, "mundo": {"mojado": 3.0}})
		r.append({"esc": "golpe", "elem": e})
	for e in ["fire", "ice", "earth"]:
		r.append({"esc": "proy", "elem": e, "base": {"velocidad": V_LENTA, "distancia_max": 5.0, "gravedad": 0.0, "rebotes": 1}, "mundo": {"enemigo": Vector2i(2, 0), "pared": Vector2i(4, 1)}})
		r.append({"esc": "proy", "elem": e, "base": {"velocidad": V_LENTA, "distancia_max": 6.0, "gravedad": 0.0, "rebotes": 1}, "mundo": {"pared": Vector2i(3, 0)}})
	return r


# =====================================================================================================
#  Mundo, enemigos y huella
# =====================================================================================================

func _montar() -> void:
	for n in [_l, _m, _jug]:
		if n != null and is_instance_valid(n):
			n.free()
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	var filas: PackedStringArray = []
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			f += "#" if (x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1) else "."
		filas.append(f)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(LADO):
		for x in range(LADO):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_jug = JugadorFalso.new()
	root.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(Vector2i(2, 2), Terreno3D.y_pies(Vector2i(2, 2)))
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	Lanzador3D.montar_agua_sim()
	_vfx.clear()
	_senales.clear()
	_l.vfx_hechizo.connect(func(nombre: String, _pos: Vector3, el: String) -> void: _vfx.append([nombre, el]))
	_l.hechizo_v2.connect(func(estado: String, el: String, g: Dictionary, o: Vector3, d: Vector3, props: Dictionary) -> void: _senales.append([estado, el, g, o, d, props]))


func _enemigo(c: Vector2i) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.position = Lanzador3D.centro_de(c, Terreno3D.y_pies(c))
	_m.add_child(modelo)
	var e: Combate3D = Combate3D.equipar(modelo, _m, _jug, _l)
	e.set_physics_process(false)
	e.altura = 0.85
	return e


func _celda(rel: Vector2i) -> Vector2i:
	return SALIDA + rel


func _correr(v: HechizoVivo) -> int:
	var n: int = 0
	while v.activo and n < MAX_PASOS:
		v.paso(DT)
		n += 1
	return n


func _s(x: float) -> float:
	return snappedf(x, 0.001)


## La huella de un enemigo: todo lo que un golpe le puede haber hecho.
func _huella_enemigo(e: Combate3D) -> Array:
	return [_s(e.health), _s(e.mojado), _s(e.quemando), _s(e.congelado), _s(e.lento), _s(e.interrupcion), _s(e.stun_timer), _s(e._empuje.length()), _s(e.envenenado), _s(e._dps_veneno), e.muerto, _s(e.vel_mult())]


## Ejecuta la fila con `val` encima de su `base` y devuelve la huella (una cadena). `val` vacío = la ejecución de referencia.
func _huella(fila: Dictionary, val: Dictionary) -> String:
	_montar()
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % String(fila["elem"]))
	var h: Hechizo = Hechizo.construir(rune, fila.get("glifos", {}) as Dictionary, 1.0)
	h.con((fila.get("base", {}) as Dictionary).duplicate(true))
	h.con(val.duplicate(true))
	var mundo: Dictionary = fila.get("mundo", {}) as Dictionary
	var enemigos: Array = []
	for clave in ["enemigo", "enemigo2"]:
		if mundo.has(clave):
			enemigos.append(_enemigo(_celda(mundo[clave] as Vector2i)))
	if mundo.has("pared"):
		Lanzador3D.bloquear_celda(_celda(mundo["pared"] as Vector2i))
	if mundo.has("jugador"):
		_jug.position = Lanzador3D.centro_de(_celda(mundo["jugador"] as Vector2i), Terreno3D.y_pies(_celda(mundo["jugador"] as Vector2i)))
	var huella: Array = []
	var origen: Vector3 = Lanzador3D.centro_de(SALIDA, Terreno3D.y_pies(SALIDA))
	match String(fila["esc"]):
		"golpe":
			var e: Combate3D = _enemigo(SALIDA + Vector2i(3, 0))
			if mundo.has("mojado"):
				e.mojado = float(mundo["mojado"])
			e.on_spell_hit(rune, Vector3.RIGHT, h)
			huella.append(_huella_enemigo(e))
		"vol":
			var v: HechizoVivo = HechizoVivo.crear(h, origen, Vector3.RIGHT, _l, null, {}, true)
			huella.append(_huella_volumen(v))
		"proy":
			if mundo.has("desplaza_mano"):
				_l.desplaza_mano = mundo["desplaza_mano"] as Vector3
			var vivos: Array = []
			var primero: HechizoVivo = HechizoVivo.crear(h, origen, Vector3.RIGHT, _l, null, {}, true)
			_l.desplaza_mano = Vector3.ZERO
			for n in _l.get_children():
				if n is HechizoVivo:
					vivos.append(n)
			for v in vivos:
				var inicial: Vector3 = (v as HechizoVivo).p
				var pasos: int = _correr(v as HechizoVivo)
				var hv: HechizoVivo = v
				huella.append([_s(inicial.x), _s(inicial.y), _s(inicial.z), hv.motivo_fin, _s(hv.recorrido), _s(hv.p.x), _s(hv.p.y), _s(hv.p.z), pasos, hv.rebotes_usados, hv.golpes_dados,
					_s(hv._radio_u), hv.eventos_vistos, _s(hv.v.length())])
			huella.append(primero.casillas)
	# lo común a todo: enemigos, jugador, zonas, solideces, señales y marcas
	for e in enemigos:
		huella.append(_huella_enemigo(e as Combate3D))
	huella.append(["jugador", _s(_jug.recibido)])
	huella.append(["vfx", _vfx.duplicate()])
	huella.append(["marcas", _m.marcas.duplicate()])
	huella.append(["alturas", str(Terreno3D.alturas)])
	var zonas: Array = []
	for z in _l._zonas_v2:
		var zz: Lanzador3D.ZonaV2 = z
		zonas.append([_s(zz.vida), _s(zz.intervalo), _s(zz.dano_periodico), zz.metodo_pulso, zz.celdas.size()])
	huella.append(["zonas", zonas])
	var sol: Array = []
	for s in _l._solideces_v2:
		var ss: Lanzador3D.SolidezV2 = s
		sol.append([_s(ss.aguante), _s(ss.vida), ss.refleja, ss.celdas.size(), ss.niveles])
	huella.append(["solideces", sol])
	return var_to_str(huella)


## Lo que se mide de un volumen que acaba de nacer.
func _huella_volumen(v: HechizoVivo) -> Array:
	var r: Array = [v.casillas, _s(v.tiempo_crecimiento), v._celdas_volumen.size(), v.eventos_vistos.duplicate()]
	var pulsos: Array = []
	for p in v.pulsos_soltados:
		pulsos.append(int((p as Pulso3D).alcance))
	r.append(["pulsos", pulsos])
	if not _senales.is_empty():
		var g: Dictionary = _senales[0][2]
		var campos: Array = []
		for k in ["x", "y", "z", "persiste", "vida_total", "permanencia", "elevacion", "separacion", "dispersion", "gravedad", "velocidad", "niveles", "suelo"]:
			campos.append(_s(float(g.get(k, 0.0))))
		r.append(["volumen", campos, (g.get("celdas", []) as Array).size()])
		var tandas: Array = []
		for ev in (g.get("eventos", []) as Array):
			tandas.append([_s(float((ev as Dictionary)["t"])), str((ev as Dictionary)["pos"]), str((ev as Dictionary)["dir"])])
		r.append(["tandas", tandas])
		r.append(["estado", _senales[0][0]])
	return r
