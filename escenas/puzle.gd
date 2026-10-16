class_name Puzle3D
extends Node

## PUZLES DECLARADOS EN EL MAPA (Fase 12.3, 16/10, Juego). Un nivel describe sus puzles en las líneas «;» de su `mapas/<Nivel>.txt`,
## sin código: `HorneadorNivel.leer_mapa` ya las ignora (solo lee `azar_suelo` y `giro`), igual que `TerraFina3D.leer_alturas` relee las suyas.
##
## CÓMO SE ENGANCHA: como nodo hijo de la escena del nivel (nombre «Reglas», como TerraFina3D) o, si el nivel ya tiene sus reglas,
## como segundo hijo («Puzles»). `_ready` espera un fotograma (la maqueta ya está montada: simulación de agua, tinaja, jugador) y
## llama a `iniciar(get_parent())`. Un nodo de reglas propio (el laboratorio) puede crearlo con `Puzle3D.new()` y llamar él a `iniciar`.
## Lee el nivel de `mundo.nivel`; si no lo tiene, `iniciar(mundo, "NombreDelMapa")`.
##
## ---------------------------------------------------------------------------------------------------------------------
##  GRAMÁTICA  (una instrucción por línea; las que no empiezan por «pieza» ni «puzle» son comentarios)
## ---------------------------------------------------------------------------------------------------------------------
##   ; pieza <id> <tipo> <x> <y> [clave=valor …]
##   ; puzle <nombre> cuando=<id>[.<señal>] [si=<id>.<cond>] hace=<id>.<acción>[(args)] [y=<id>.<acción>[(args)] …]
##
## <id> y <nombre>: letras, cifras y «_» (sin espacios ni puntos), únicos en el archivo. <x> <y>: casilla del mapa (columna, fila).
## Los valores no llevan espacios. Lista de casillas: `x,y` o un rectángulo `x0,y0..x1,y1`, y varios unidos con `+`
## (`celdas=4,10..4,12+1,12..2,12`). Booleanos: si | no (también true/false, 1/0).
##
## PIEZAS (tipo → claves, entre paréntesis el valor por defecto) y qué clase de `objetos/` es:
##   pulsador   modo=magia|agua|presencia (magia)  rearme=<s> (0)                     Pulsador3D: botón, pulsador de agua o placa
##   compuerta  abierta (no)  abre_con=fuego|agua|hielo|rayo|explosion  cierra_con=…  estrecha (si)  vertical (si)   Compuerta3D
##   nivel      objetivo=<u> (0.45)  banda=<u> (0)  invertido (no)                    NivelAgua3D: lee la profundidad de su casilla
##   molino     umbral=<u/s> (0.3)  vertical (si)                                     Molino3D
##   barril                                                                          Barril3D
##   nexo                                                                            NexoRayo3D (pila que conduce mojada)
##   puerta                                                                          losa que bloquea su casilla hasta abrirse (PuertaPuzle)
##   emisor                                                                          EmisorRayo3D: la fuente eléctrica (letra «e»)
##   cuenca     celdas=<lista> (la propia x,y)  nivel=<u> (no llena)  fijo=<u>|si     abre casillas c o canal al agua; `nivel` las llena a esa
##                                                                                   profundidad; `fijo=<u>` mantiene ese nivel (un desagüe);
##                                                                                   `fijo=si` lo mantiene en `nivel`
##   manantial  caudal=<u³/s> (0.5)  volumen=<u³> (0 = infinito)  rampa (si)  inicia (si)  celdas=<lista>
##              En x,y echa agua. `rampa=si`: arranque suave de ReaccionesAgua3D.ARRANQUE_CAUCE (abre también las `celdas`; x,y va la primera);
##              `rampa=no`: echa el caudal de golpe. `inicia=no`: espera a la acción `abrir_cauce`.
##   tinaja     canal=<lista>                                                         la tinaja de la MAQUETA (letra «u»), solo se enlaza por casilla;
##                                                                                   `canal` es el cauce que llena (la primera casilla recibe el agua)
##   totem                                                                           el tótem de la MAQUETA (letra «i»), enlazado por casilla
##   brasero    rele=<id> espera=<s> (1.5) dura=<s> (6)                              el brasero de la MAQUETA (letra «T»), enlazado por casilla. Sin claves es
##                                                                                   el de siempre. Con `rele` (el id de OTRO brasero), al encenderse enciende a ése
##                                                                                   `espera` s después y él se apaga a los `dura` s; `dura` sin `rele` = se apaga solo
##   seto       mojable (no)                                                         el seto de la MAQUETA (letra «z»), enlazado por casilla. `mojable=si`: el agua lo
##                                                                                   moja y no prende en Reactivo3D.T_MOJADO s (el cortafuegos)
##   contador   de=<lista de casillas>  minimo=<n> (todos)                           ContadorReactivos3D: cuenta lo que arde (`is_lit`) en esas casillas (braseros,
##                                                                                   fogatas, setos…); rótulo «ENCENDIDAS n/m» sobre su casilla
##   cuerda     sostiene=<id>                                                        Cuerda3D: arde 1 s y se rompe; lo que sostiene (una compuerta o un puente) cae
##
## SEÑALES (`cuando=<id>.<señal>`; sin señal vale la primera de cada fila):
##   pulsador   pulsado | soltado           compuerta  abierta | cerrada          nivel   alcanzado | perdido
##   molino     girando | parado            nexo       conduce | corta            barril  explota
##   puerta     abierta | cerrada           totem      activado                   tinaja  agua_llega
##   emisor     descarga
##   brasero    encendido | apagado          contador   todos | no_todos            cuerda  rota
##   seto       consumido
## CONDICIONES (`si=<id>.<cond>`: la regla solo actúa si en ese momento se cumple):
##   compuerta/puerta  abierta | cerrada    nivel  alcanzado | perdido     nexo    conduce | corta    molino  girando | parado
##   barril  explotado | encendido | entero    pulsador  activo | libre
##   brasero apagado | encendido   contador  todos | no_todos   cuerda  rota | entera   seto  ardiendo
## ACCIONES (`hace=<id>.<acción>`, con argumentos entre paréntesis separados por comas si los admite):
##   compuerta, puerta   abrir | cerrar | alternar          pulsador   pulsar
##   barril              encender | apagar                    nexo       mojar | secar
##   tinaja              mojar | abrir_cauce(caudal,volumen) | apagar_fuente
##   manantial           abrir_cauce(caudal,volumen) | apagar_fuente | helar(s)
##   cuenca              helar(s)        (hiela sus casillas `s` segundos; sin argumento, AguaSim3D.DURA_HIELO)
##   brasero             encender | apagar        seto    encender (lo prende)        cuerda  quemar
## `abrir_cauce` sin argumentos usa los de la pieza (manantial) o Surtidor3D.CAUDAL_TINAJA / VOL_TINAJA (tinaja).
##
## EJEMPLO (una sala: cada pulsador abre la compuerta y, cuando el agua llega a 0,35, se abre la puerta):
##   ; pieza k    compuerta 4 3 abre_con=fuego
##   ; pieza n    nivel     6 3 objetivo=0.35
##   ; pieza p    puerta    1 6
##   ; pieza b    pulsador  2 6 modo=magia
##   ; puzle boton cuando=b.pulsado hace=k.abrir
##   ; puzle abre  cuando=n.alcanzado hace=p.abrir
##   ; puzle cierra cuando=n.perdido hace=p.cerrar
##
## ERRORES: una línea mal escrita, un id repetido o una referencia a algo que no existe NO tumban el nivel: esa línea se ignora,
## sale `push_warning("Puzle3D: línea N: …")` con el texto de la línea, queda en `avisos` y se pinta un rótulo AVISO en el HUD.
## Para las pruebas: `pieza(id)` (la ficha, con `.nodo`), `nodo(id)`, `puzle(nombre)` (la regla, con `veces`), `parsear(texto)` sin mundo.
##
## DEPENDENCIA CON LA MAQUETA: las piezas se cuelgan de `mundo._props` (el contenedor del decorado; si no existe, del propio mundo) y el
## emisor eléctrico recibe el mundo. La tinaja y el tótem se buscan en el grupo `reactivo3d`. Nada más.

signal aviso_nuevo(texto: String)

const SENAL_DEFECTO: Dictionary = {
	"pulsador": "pulsado", "compuerta": "abierta", "nivel": "alcanzado", "molino": "girando", "nexo": "conduce", "barril": "explota",
	"puerta": "abierta", "totem": "activado", "tinaja": "agua_llega", "emisor": "descarga",
	"brasero": "encendido", "contador": "todos", "cuerda": "rota", "seto": "consumido",
}
## Señal de usuario → [señal de Godot, cuántos argumentos trae, filtro]: un filtro `true`/`false` deja pasar solo ese valor del primer argumento.
const SENALES: Dictionary = {
	"pulsador": {"pulsado": ["pulsado", 1, null], "soltado": ["soltado", 0, null]},
	"compuerta": {"abierta": ["cambio", 1, true], "cerrada": ["cambio", 1, false]},
	"nivel": {"alcanzado": ["nivel_alcanzado", 1, true], "perdido": ["nivel_alcanzado", 1, false]},
	"molino": {"girando": ["girando", 1, true], "parado": ["girando", 1, false]},
	"nexo": {"conduce": ["cambio", 1, true], "corta": ["cambio", 1, false]},
	"barril": {"explota": ["explota", 2, null]},
	"puerta": {"abierta": ["cambio", 1, true], "cerrada": ["cambio", 1, false]},
	"totem": {"activado": ["activado", 2, null]},
	"tinaja": {"agua_llega": ["agua_llega", 0, null]},
	"emisor": {"descarga": ["descarga", 1, null]},
	"brasero": {"encendido": ["llama", 1, true], "apagado": ["llama", 1, false]},
	"contador": {"todos": ["todos", 1, true], "no_todos": ["todos", 1, false]},
	"cuerda": {"rota": ["rota", 0, null]},
	"seto": {"consumido": ["consumido", 1, null]},
}
const CONDICIONES: Dictionary = {
	"compuerta": {"abierta": ["abierta", true], "cerrada": ["abierta", false]},
	"puerta": {"abierta": ["abierta", true], "cerrada": ["abierta", false]},
	"nivel": {"alcanzado": ["alcanzado", true], "perdido": ["alcanzado", false]},
	"nexo": {"conduce": ["conduce", true], "corta": ["conduce", false]},
	"molino": {"girando": ["activo", true], "parado": ["activo", false]},
	"barril": {"explotado": ["explotado", true], "encendido": ["encendido", true], "entero": ["explotado", false]},
	"pulsador": {"activo": ["activo", true], "libre": ["activo", false]},
	"brasero": {"encendido": ["is_lit", true], "apagado": ["is_lit", false]},
	"contador": {"todos": ["completo", true], "no_todos": ["completo", false]},
	"cuerda": {"rota": ["rota_ya", true], "entera": ["rota_ya", false]},
	"seto": {"ardiendo": ["is_lit", true]},
}
## Acción → cuántos argumentos admite como máximo.
const ACCIONES: Dictionary = {
	"pulsador": {"pulsar": 0},
	"compuerta": {"abrir": 0, "cerrar": 0, "alternar": 0},
	"puerta": {"abrir": 0, "cerrar": 0, "alternar": 0},
	"barril": {"encender": 0, "apagar": 0},
	"nexo": {"mojar": 0, "secar": 0},
	"tinaja": {"mojar": 0, "abrir_cauce": 2, "apagar_fuente": 0},
	"manantial": {"abrir_cauce": 2, "apagar_fuente": 0, "helar": 1},
	"cuenca": {"helar": 1},
	"brasero": {"encender": 0, "apagar": 0},
	"seto": {"encender": 0},
	"cuerda": {"quemar": 0},
}
## Claves de cada tipo de pieza y qué valor admiten: «f» número, «b» sí/no, «celdas» lista de casillas, «fijo» número o sí, «s:a|b» una de esas palabras.
const CLAVES: Dictionary = {
	"pulsador": {"modo": "s:magia|agua|presencia", "rearme": "f"},
	"compuerta": {"abierta": "b", "abre_con": "s:fuego|agua|hielo|rayo|explosion", "cierra_con": "s:fuego|agua|hielo|rayo", "estrecha": "b", "vertical": "b"},
	"nivel": {"objetivo": "f", "banda": "f", "invertido": "b"},
	"molino": {"umbral": "f", "vertical": "b"},
	"barril": {},
	"nexo": {},
	"puerta": {},
	"emisor": {},
	"cuenca": {"celdas": "celdas", "nivel": "f", "fijo": "fijo"},
	"manantial": {"caudal": "f", "volumen": "f", "rampa": "b", "inicia": "b", "celdas": "celdas"},
	"tinaja": {"canal": "celdas"},
	"totem": {},
	"brasero": {"rele": "id", "espera": "f", "dura": "f"},
	"seto": {"mojable": "b"},
	"contador": {"de": "celdas", "minimo": "f"},
	"cuerda": {"sostiene": "id"},
}
## Piezas que ya pone la maqueta por letra: la casilla de la pieza tiene que llevar esa letra.
const LETRA_MAQUETA: Dictionary = {"tinaja": "u", "totem": "i", "emisor": "e", "brasero": "T", "seto": "z"}
## Piezas que necesitan la simulación de agua (`agua_fisica = true` en la escena).
const NECESITAN_AGUA: Array = ["cuenca", "manantial", "nivel", "compuerta", "molino"]
const NECESITAN_CAUCE: Array = ["cuenca", "manantial", "nivel", "compuerta", "molino"]


## Una pieza declarada: su ficha (y su nodo, si es de las que lo tienen; `cuenca` y `manantial` son solo datos).
class Pieza extends RefCounted:
	var id: String = ""
	var tipo: String = ""
	var celda: Vector2i = Vector2i.ZERO
	var p: Dictionary = {}                       ## las claves que escribió Pablo (ya convertidas)
	var nodo: Node = null
	var n: int = 0                               ## línea del .txt
	var activa: bool = false                     ## manantial: ya está echando agua


## Losa que bloquea su casilla hasta que el puzle se cumple (y vuelve a cerrarse si deja de cumplirse). Antes vivía en el laboratorio.
class PuertaPuzle extends Node3D:
	signal cambio(abierta: bool)
	var celda: Vector2i = Vector2i.ZERO
	var abierta: bool = false
	var _losa: MeshInstance3D = null
	var _rotulo: Label3D = null
	var _y0: float = 0.0

	func preparar(c: Vector2i) -> void:
		celda = c
		position = Terreno3D.centro_de(c, Terreno3D.alto_suelo)
		Terreno3D.bloquear_celda(c)
		_losa = MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(Terreno3D.casilla * 0.9, 2.2, 0.3)
		_losa.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.36, 0.22)
		_losa.material_override = mat
		_y0 = 1.1
		_losa.position = Vector3(0.0, _y0, 0.0)
		add_child(_losa)
		_rotulo = Label3D.new()
		_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_rotulo.font_size = 30
		_rotulo.outline_size = 8
		_rotulo.pixel_size = 0.005
		_rotulo.position = Vector3(0.0, 2.9, 0.0)
		add_child(_rotulo)
		_pintar_rotulo()

	func _pintar_rotulo() -> void:
		_rotulo.text = "PUERTA ABIERTA" if abierta else "PUERTA CERRADA"
		_rotulo.modulate = Color(0.5, 1.0, 0.55) if abierta else Color(1.0, 0.6, 0.5)

	func poner(si: bool) -> void:
		if si == abierta:
			return
		abierta = si
		_pintar_rotulo()
		if si:
			Terreno3D.liberar_celda(celda)
		else:
			Terreno3D.bloquear_celda(celda)
		var tw: Tween = create_tween()
		tw.tween_property(_losa, "position:y", _y0 - 2.1 if si else _y0, 0.8).set_trans(Tween.TRANS_SINE)
		cambio.emit(si)

	func abrir() -> void:
		poner(true)

	func cerrar() -> void:
		poner(false)

	func alternar() -> void:
		poner(not abierta)


var mundo: Variant = null                        ## la maqueta ya montada
var nivel: String = ""
var avisos: Array = []                           ## String: lo que no se pudo leer o montar, con su línea
var _piezas: Dictionary = {}                     ## id -> Pieza
var _orden: Array = []                           ## las piezas en el orden del .txt
var _reglas: Array = []                          ## Dictionary: {nombre, cuando_id, senal, si_id, si_cond, acciones, n, veces, ignoradas}
var _hielos: Dictionary = {}                     ## Vector2i -> s que le quedan a un hielo puesto por una regla
var _iniciado: bool = false
var _hud: Label = null


func _ready() -> void:
	call_deferred("_arrancar")


func _arrancar() -> void:
	if not _iniciado and get_parent() != null:
		iniciar(get_parent())


## Entrada pública. `p_nivel`: nombre del mapa («PuzlesAgua»); vacío = `mundo.nivel`. `p_texto`: el contenido del .txt (para las pruebas;
## vacío = se lee `mapas/<nivel>.txt`).
func iniciar(p_mundo: Variant, p_nivel: String = "", p_texto: String = "") -> void:
	if _iniciado:
		return
	_iniciado = true
	mundo = p_mundo
	nivel = p_nivel
	if nivel == "" and mundo is Object:
		var nv: Variant = (mundo as Object).get("nivel")          # null si el mundo no tiene «nivel» (un mundo falso de prueba)
		if nv != null:
			nivel = String(nv)
	var texto: String = p_texto
	if texto == "":
		texto = _leer_archivo(nivel)
	var r: Dictionary = parsear(texto)
	for a in (r["avisos"] as Array):
		_avisar(String(a))
	for pz in (r["piezas"] as Array):
		_orden.append(pz)
		_piezas[(pz as Pieza).id] = pz
	_reglas = r["reglas"]
	for pz in _orden:
		_crear(pz as Pieza)
	for pz in _orden:
		_enlazar(pz as Pieza)             # lo que apunta a otra pieza (`rele=`, `sostiene=`) se enlaza cuando ya están todas
	_conectar()
	set_process(true)


func _leer_archivo(p_nivel: String) -> String:
	var ruta: String = HorneadorNivel.ruta_mapa(p_nivel)
	if ruta == "":
		_avisar("no hay mapa «%s» (mundo/datos_nivel/mapas/%s.txt)" % [p_nivel, p_nivel])
		return ""
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		_avisar("no se puede leer %s" % ruta)
		return ""
	return f.get_as_text()


# ---------------------------------------------------------------------------------------------------------------------
#  Lo que se puede preguntar (las pruebas, el HUD del laboratorio)
# ---------------------------------------------------------------------------------------------------------------------

func pieza(id: String) -> Pieza:
	return _piezas.get(id, null)


func nodo(id: String) -> Node:
	var pz: Pieza = pieza(id)
	return pz.nodo if pz != null and is_instance_valid(pz.nodo) else null


func piezas() -> Array:
	return _orden.duplicate()


## La pieza de un tipo en una casilla (el primer pulsador de (10,2), …). `tipo` vacío = cualquiera.
func pieza_en(c: Vector2i, tipo: String = "") -> Pieza:
	for pz in _orden:
		if (pz as Pieza).celda == c and (tipo == "" or (pz as Pieza).tipo == tipo):
			return pz
	return null


func puzle(nombre: String) -> Dictionary:
	for r in _reglas:
		if String((r as Dictionary)["nombre"]) == nombre:
			return r
	return {}


func reglas() -> Array:
	return _reglas.duplicate()


static func runa(etiquetas: Array) -> RuneData:
	var r := RuneData.new()
	var t: Array[String] = []
	for e in etiquetas:
		t.append(String(e))
	r.tags = t
	return r


# ---------------------------------------------------------------------------------------------------------------------
#  Leer la gramática (sin mundo: se prueba con texto)
# ---------------------------------------------------------------------------------------------------------------------

## Devuelve {"piezas": Array[Pieza], "reglas": Array[Dictionary], "avisos": Array[String]}. Solo valen las líneas correctas.
static func parsear(texto: String) -> Dictionary:
	var piezas: Array = []
	var crudas: Array = []
	var avisos: Array = []
	var por_id: Dictionary = {}
	var n: int = 0
	for linea in texto.split("\n"):
		n += 1
		var l: String = String(linea).replace("\r", "").replace("\t", " ")
		if not l.begins_with(";"):
			continue
		var p: PackedStringArray = l.substr(1).strip_edges().split(" ", false)
		if p.is_empty():
			continue
		if p[0] == "pieza":
			var pz: Pieza = _leer_pieza(p, n, l, por_id, avisos)
			if pz != null:
				piezas.append(pz)
				por_id[pz.id] = pz
		elif p[0] == "puzle":
			var r: Dictionary = _leer_regla(p, n, l, avisos)
			if not r.is_empty():
				crudas.append(r)
	# Las claves «id» (rele=, sostiene=) apuntan a otra pieza: ya están todas leídas, se comprueba aquí. Si no existe, se quita la clave
	# (la pieza sigue, sin esa relación) y sale el aviso.
	for pz in piezas:
		var claves_pz: Dictionary = CLAVES[(pz as Pieza).tipo]
		for k in claves_pz:
			if String(claves_pz[k]) == "id" and (pz as Pieza).p.has(k) and not por_id.has((pz as Pieza).p[k]):
				_aviso_linea(avisos, (pz as Pieza).n, "pieza %s %s" % [(pz as Pieza).id, (pz as Pieza).tipo], "%s=%s: no hay ninguna pieza «%s»" % [k, (pz as Pieza).p[k], (pz as Pieza).p[k]])
				(pz as Pieza).p.erase(k)
	var reglas: Array = []
	var nombres: Dictionary = {}
	for r in crudas:
		var rr: Dictionary = r
		if nombres.has(rr["nombre"]):
			_aviso_linea(avisos, int(rr["n"]), String(rr["linea"]), "nombre de puzle repetido «%s» (ya está en la línea %d)" % [rr["nombre"], nombres[rr["nombre"]]])
			continue
		if _resolver(rr, por_id, avisos):
			nombres[rr["nombre"]] = int(rr["n"])
			reglas.append(rr)
	return {"piezas": piezas, "reglas": reglas, "avisos": avisos}


static func _aviso_linea(avisos: Array, n: int, linea: String, msg: String) -> void:
	avisos.append("línea %d: %s  [%s]" % [n, msg, linea.strip_edges()])


static func _id_valido(s: String) -> bool:
	if s == "":
		return false
	for i in range(s.length()):
		var ch: String = s[i]
		var ok: bool = (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_"
		if not ok:
			return false
	return true


static func _leer_pieza(p: PackedStringArray, n: int, l: String, por_id: Dictionary, avisos: Array) -> Pieza:
	if p.size() < 5:
		_aviso_linea(avisos, n, l, "pieza incompleta: se escribe «pieza <id> <tipo> <x> <y> [clave=valor …]»")
		return null
	var id: String = p[1]
	var tipo: String = p[2]
	if not _id_valido(id):
		_aviso_linea(avisos, n, l, "id no válido «%s» (letras, cifras y «_»)" % id)
		return null
	if por_id.has(id):
		_aviso_linea(avisos, n, l, "id repetido «%s» (ya está en la línea %d)" % [id, (por_id[id] as Pieza).n])
		return null
	if not CLAVES.has(tipo):
		_aviso_linea(avisos, n, l, "tipo desconocido «%s» (valen: %s)" % [tipo, ", ".join(CLAVES.keys())])
		return null
	if not p[3].is_valid_int() or not p[4].is_valid_int():
		_aviso_linea(avisos, n, l, "la casilla tiene que ser dos enteros (x y): «%s %s»" % [p[3], p[4]])
		return null
	var pz := Pieza.new()
	pz.id = id
	pz.tipo = tipo
	pz.celda = Vector2i(int(p[3]), int(p[4]))
	pz.n = n
	var claves: Dictionary = CLAVES[tipo]
	var bien: bool = true
	for i in range(5, p.size()):
		var kv: PackedStringArray = p[i].split("=", true, 1)
		if kv.size() != 2 or kv[0] == "":
			_aviso_linea(avisos, n, l, "«%s» no es clave=valor" % p[i])
			bien = false
			continue
		if not claves.has(kv[0]):
			_aviso_linea(avisos, n, l, "la pieza «%s» no tiene la clave «%s» (valen: %s)" % [tipo, kv[0], ", ".join(claves.keys()) if not claves.is_empty() else "ninguna"])
			bien = false
			continue
		var v: Array = _valor(String(claves[kv[0]]), kv[1])
		if not bool(v[0]):
			_aviso_linea(avisos, n, l, "%s=%s: %s" % [kv[0], kv[1], v[2]])
			bien = false
			continue
		pz.p[kv[0]] = v[1]
	return pz if bien else null


## Convierte el texto de una clave según su tipo. Devuelve [ok, valor, error].
static func _valor(tipo: String, t: String) -> Array:
	if tipo == "f":
		if not t.is_valid_float():
			return [false, null, "tiene que ser un número"]
		return [true, float(t), ""]
	if tipo == "b":
		var m: String = t.to_lower()
		if m in ["si", "sí", "true", "1"]:
			return [true, true, ""]
		if m in ["no", "false", "0"]:
			return [true, false, ""]
		return [false, null, "tiene que ser si o no"]
	if tipo == "fijo":
		var m2: String = t.to_lower()
		if m2 in ["si", "sí", "true"]:
			return [true, true, ""]
		if not t.is_valid_float():
			return [false, null, "tiene que ser un número o si"]
		return [true, float(t), ""]
	if tipo == "celdas":
		return _lista_celdas(t)
	if tipo == "id":
		if not _id_valido(t):
			return [false, null, "tiene que ser el id de otra pieza (letras, cifras y «_»)"]
		return [true, t, ""]
	if tipo.begins_with("s:"):
		var vale: PackedStringArray = tipo.substr(2).split("|")
		if not (t in vale):
			return [false, null, "tiene que ser uno de: %s" % ", ".join(vale)]
		return [true, t, ""]
	return [false, null, "tipo de valor desconocido"]


## «x,y» o «x0,y0..x1,y1», unidos con «+». Devuelve [ok, Array[Vector2i], error].
static func _lista_celdas(t: String) -> Array:
	var res: Array = []
	for trozo in t.split("+", false):
		var ext: PackedStringArray = String(trozo).split("..")
		if ext.size() > 2:
			return [false, null, "«%s» no es x,y ni x0,y0..x1,y1" % trozo]
		var a: Variant = _punto(ext[0])
		var b: Variant = a if ext.size() == 1 else _punto(ext[1])
		if a == null or b == null:
			return [false, null, "«%s» no es x,y ni x0,y0..x1,y1" % trozo]
		var pa: Vector2i = a
		var pb: Vector2i = b
		for y in range(mini(pa.y, pb.y), maxi(pa.y, pb.y) + 1):
			for x in range(mini(pa.x, pb.x), maxi(pa.x, pb.x) + 1):
				res.append(Vector2i(x, y))
	if res.is_empty():
		return [false, null, "lista vacía"]
	return [true, res, ""]


static func _punto(t: String) -> Variant:
	var xy: PackedStringArray = t.split(",")
	if xy.size() != 2 or not xy[0].is_valid_int() or not xy[1].is_valid_int():
		return null
	return Vector2i(int(xy[0]), int(xy[1]))


static func _leer_regla(p: PackedStringArray, n: int, l: String, avisos: Array) -> Dictionary:
	var nombre: String = ""
	var cuando: String = ""
	var si: String = ""
	var hace: Array = []
	var bien: bool = true
	for i in range(1, p.size()):
		var t: String = p[i]
		var kv: PackedStringArray = t.split("=", true, 1)
		if kv.size() == 1:
			if nombre == "":
				nombre = t
			else:
				_aviso_linea(avisos, n, l, "sobra «%s»" % t)
				bien = false
			continue
		match kv[0]:
			"cuando":
				if cuando != "":
					_aviso_linea(avisos, n, l, "dos «cuando=»: un puzle tiene un solo disparador")
					bien = false
				cuando = kv[1]
			"si":
				if si != "":
					_aviso_linea(avisos, n, l, "dos «si=»")
					bien = false
				si = kv[1]
			"hace", "y":
				hace.append(kv[1])
			_:
				_aviso_linea(avisos, n, l, "clave desconocida «%s» (valen: cuando, si, hace, y)" % kv[0])
				bien = false
	if nombre == "" or not _id_valido(nombre):
		_aviso_linea(avisos, n, l, "falta el nombre del puzle (o no es válido): «puzle <nombre> cuando=… hace=…»")
		bien = false
	if cuando == "":
		_aviso_linea(avisos, n, l, "falta «cuando=<id>[.<señal>]»")
		bien = false
	if hace.is_empty():
		_aviso_linea(avisos, n, l, "falta «hace=<id>.<acción>»")
		bien = false
	if not bien:
		return {}
	return {"nombre": nombre, "cuando": cuando, "si": si, "hace": hace, "n": n, "linea": l, "veces": 0, "ignoradas": 0}


## Comprueba que cada referencia de la regla existe y es válida; si sí, la deja lista (ids, señal, acciones con argumentos).
static func _resolver(r: Dictionary, por_id: Dictionary, avisos: Array) -> bool:
	var n: int = int(r["n"])
	var l: String = String(r["linea"])
	# cuando
	var cw: PackedStringArray = String(r["cuando"]).split(".")
	if cw.size() > 2 or not por_id.has(cw[0]):
		_aviso_linea(avisos, n, l, "cuando=%s: no hay ninguna pieza «%s»" % [r["cuando"], cw[0]])
		return false
	var fuente: Pieza = por_id[cw[0]]
	if not SENALES.has(fuente.tipo):
		_aviso_linea(avisos, n, l, "cuando=%s: una pieza «%s» no emite señales" % [r["cuando"], fuente.tipo])
		return false
	var senal: String = cw[1] if cw.size() == 2 else String(SENAL_DEFECTO[fuente.tipo])
	if not (SENALES[fuente.tipo] as Dictionary).has(senal):
		_aviso_linea(avisos, n, l, "cuando=%s: «%s» no emite «%s» (emite: %s)" % [r["cuando"], fuente.tipo, senal, ", ".join((SENALES[fuente.tipo] as Dictionary).keys())])
		return false
	r["cuando_id"] = fuente.id
	r["senal"] = senal
	# si
	r["si_id"] = ""
	r["si_cond"] = ""
	if String(r["si"]) != "":
		var sw: PackedStringArray = String(r["si"]).split(".")
		if sw.size() != 2 or not por_id.has(sw[0]):
			_aviso_linea(avisos, n, l, "si=%s: tiene que ser <id>.<condición> de una pieza que existe" % r["si"])
			return false
		var pc: Pieza = por_id[sw[0]]
		if not CONDICIONES.has(pc.tipo) or not (CONDICIONES[pc.tipo] as Dictionary).has(sw[1]):
			_aviso_linea(avisos, n, l, "si=%s: una pieza «%s» no tiene la condición «%s»%s" % [r["si"], pc.tipo, sw[1], (" (tiene: %s)" % ", ".join((CONDICIONES[pc.tipo] as Dictionary).keys())) if CONDICIONES.has(pc.tipo) else ""])
			return false
		r["si_id"] = pc.id
		r["si_cond"] = sw[1]
	# hace / y
	var acciones: Array = []
	for txt in (r["hace"] as Array):
		var a: Dictionary = _leer_accion(String(txt), por_id, n, l, avisos)
		if a.is_empty():
			return false
		acciones.append(a)
	r["acciones"] = acciones
	return true


static func _leer_accion(t: String, por_id: Dictionary, n: int, l: String, avisos: Array) -> Dictionary:
	var ref: String = t
	var args: Array = []
	var ip: int = t.find("(")
	if ip >= 0:
		if not t.ends_with(")"):
			_aviso_linea(avisos, n, l, "hace=%s: falta el «)»" % t)
			return {}
		ref = t.substr(0, ip)
		var dentro: String = t.substr(ip + 1, t.length() - ip - 2)
		for a in dentro.split(",", false):
			var s: String = String(a).strip_edges()
			if not s.is_valid_float():
				_aviso_linea(avisos, n, l, "hace=%s: el argumento «%s» no es un número" % [t, s])
				return {}
			args.append(float(s))
	var w: PackedStringArray = ref.split(".")
	if w.size() != 2 or not por_id.has(w[0]):
		_aviso_linea(avisos, n, l, "hace=%s: no hay ninguna pieza «%s» (se escribe <id>.<acción>)" % [t, w[0]])
		return {}
	var pz: Pieza = por_id[w[0]]
	if not ACCIONES.has(pz.tipo) or not (ACCIONES[pz.tipo] as Dictionary).has(w[1]):
		_aviso_linea(avisos, n, l, "hace=%s: una pieza «%s» no sabe «%s»%s" % [t, pz.tipo, w[1], (" (sabe: %s)" % ", ".join((ACCIONES[pz.tipo] as Dictionary).keys())) if ACCIONES.has(pz.tipo) else " (no tiene acciones)"])
		return {}
	var maximo: int = int((ACCIONES[pz.tipo] as Dictionary)[w[1]])
	if args.size() > maximo:
		_aviso_linea(avisos, n, l, "hace=%s: «%s» admite como mucho %d argumento(s)" % [t, w[1], maximo])
		return {}
	return {"id": pz.id, "accion": w[1], "args": args}


# ---------------------------------------------------------------------------------------------------------------------
#  Montar las piezas
# ---------------------------------------------------------------------------------------------------------------------

func _avisar(texto: String) -> void:
	avisos.append(texto)
	push_warning("Puzle3D: " + texto)
	aviso_nuevo.emit(texto)
	_pintar_avisos()


func _avisar_pieza(pz: Pieza, msg: String) -> void:
	_avisar("línea %d: pieza «%s» (%s): %s" % [pz.n, pz.id, pz.tipo, msg])


func _pintar_avisos() -> void:
	if not is_inside_tree():
		return
	if _hud == null:
		var capa := CanvasLayer.new()
		capa.layer = 7
		add_child(capa)
		_hud = Label.new()
		capa.add_child(_hud)
		_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_hud.offset_left = 12.0
		_hud.offset_bottom = -12.0
		_hud.add_theme_font_size_override("font_size", 14)
		_hud.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
		_hud.add_theme_color_override("font_outline_color", Color.BLACK)
		_hud.add_theme_constant_override("outline_size", 6)
	var t: String = ""
	for a in avisos:
		t += "AVISO Puzle3D · %s\n" % String(a)
	_hud.text = t


func _contenedor() -> Node:
	if mundo is Object:
		var pr: Variant = (mundo as Object).get("_props")
		if pr is Node:
			return pr
	return mundo as Node


func _hay_agua() -> bool:
	return Terreno3D.agua_sim != null


## ¿La casilla de la pieza es válida? (dentro del mapa, no un muro, con la letra que la maqueta espera, y una casilla de agua si es una
## pieza de agua). Sin mapa montado no se puede mirar y se da por buena.
func _casilla_valida(pz: Pieza, c: Vector2i) -> bool:
	if not Terreno3D.hay_mundo():
		return true
	if not Terreno3D.en_mapa(c):
		_avisar_pieza(pz, "la casilla %s está fuera del mapa" % c)
		return false
	var letra: String = Terreno3D.letra_de(c)
	if letra == "#" or letra == " ":
		_avisar_pieza(pz, "la casilla %s es un muro" % c)
		return false
	var esperada: String = String(LETRA_MAQUETA.get(pz.tipo, ""))
	if esperada != "" and letra != esperada:
		_avisar_pieza(pz, "en %s esperaba la letra «%s» (la maqueta pone ahí la pieza) y hay «%s»" % [c, esperada, letra])
		return false
	if pz.tipo in NECESITAN_CAUCE and not (letra == "c" or letra == "~" or Terreno3D.es_canal(c)):
		_avisar_pieza(pz, "la casilla %s es «%s»: una pieza de agua va sobre un cauce «c», un canal «-»/«L» o un río «~»" % [c, letra])
		return false
	return true


func _crear(pz: Pieza) -> void:
	if pz.tipo in NECESITAN_AGUA and not _hay_agua():
		_avisar_pieza(pz, "no hay simulación de agua: la escena necesita agua_fisica = true")
		return
	var cont: Node = _contenedor()
	if cont == null:
		_avisar_pieza(pz, "no hay dónde colgar la pieza (el mundo no tiene `_props`)")
		return
	var celdas: Array = []
	if pz.p.has("celdas"):
		celdas = pz.p["celdas"]
	elif pz.tipo == "cuenca" or pz.tipo == "manantial":
		celdas = [pz.celda]
	var a_mirar: Array = [pz.celda]
	a_mirar.append_array(celdas)
	for c in a_mirar:
		if not _casilla_valida(pz, c as Vector2i):
			return
	match pz.tipo:
		"pulsador":
			var b := Pulsador3D.new()
			b.name = pz.id
			b.preparar(pz.celda, String(pz.p.get("modo", "magia")), float(pz.p.get("rearme", 0.0)))
			cont.add_child(b)
			pz.nodo = b
		"compuerta":
			var k := Compuerta3D.new()
			k.name = pz.id
			k.estrecha = bool(pz.p.get("estrecha", true))
			k.preparar(pz.celda, bool(pz.p.get("abierta", false)), String(pz.p.get("abre_con", "")), String(pz.p.get("cierra_con", "")), bool(pz.p.get("vertical", true)))
			cont.add_child(k)
			pz.nodo = k
		"nivel":
			var d := NivelAgua3D.new()
			d.name = pz.id
			d.preparar(pz.celda, float(pz.p.get("objetivo", 0.45)), float(pz.p.get("banda", 0.0)), bool(pz.p.get("invertido", false)))
			cont.add_child(d)
			pz.nodo = d
		"molino":
			var mo := Molino3D.new()
			mo.name = pz.id
			mo.preparar(pz.celda, float(pz.p.get("umbral", 0.3)), bool(pz.p.get("vertical", true)))
			cont.add_child(mo)
			pz.nodo = mo
		"barril":
			var ba := Barril3D.new()
			ba.name = pz.id
			ba.preparar(pz.celda)
			cont.add_child(ba)
			pz.nodo = ba
		"nexo":
			var nx := NexoRayo3D.new()
			nx.name = pz.id
			nx.preparar(pz.celda)
			cont.add_child(nx)
			pz.nodo = nx
		"puerta":
			var pu := PuertaPuzle.new()
			pu.name = pz.id
			pu.preparar(pz.celda)
			cont.add_child(pu)
			pz.nodo = pu
		"emisor":
			var em := EmisorRayo3D.new()
			em.name = pz.id
			cont.add_child(em)
			em.preparar(mundo, pz.celda)
			pz.nodo = em
		"cuenca":
			_abrir_celdas(celdas)
			var nivel_llenado: float = float(pz.p.get("nivel", -1.0))
			if nivel_llenado >= 0.0:
				for c in celdas:
					Terreno3D.agua_sim.llenar_casilla(c as Vector2i, _fondo(c as Vector2i) + nivel_llenado)
			if pz.p.has("fijo"):
				var f: Variant = pz.p["fijo"]
				var prof: float = nivel_llenado if f is bool else float(f)
				if prof < 0.0:
					_avisar_pieza(pz, "«fijo=si» necesita «nivel=<u>»")
				else:
					for c in celdas:
						Terreno3D.agua_sim.fijar_nivel(c as Vector2i, _fondo(c as Vector2i) + prof)
		"manantial":
			if bool(pz.p.get("inicia", true)):
				_abrir_cauce(pz, [])
		"tinaja":
			var t: Reactivo3D = _reactivo("surtidor", pz.celda)
			if t == null:
				_avisar_pieza(pz, "no hay tinaja de la maqueta en %s (letra «u»)" % pz.celda)
				return
			t.sin_arroyo()           # la maqueta no le da su arroyo propio: el cauce lo abre una regla (`abrir_cauce`)
			pz.nodo = t
		"totem":
			var to: Reactivo3D = _reactivo("totem", pz.celda)
			if to == null:
				_avisar_pieza(pz, "no hay tótem de la maqueta en %s (letra «i»)" % pz.celda)
				return
			pz.nodo = to
		"brasero":
			var br: Reactivo3D = _reactivo("brasero", pz.celda)
			if br == null:
				_avisar_pieza(pz, "no hay brasero de la maqueta en %s (letra «T»)" % pz.celda)
				return
			pz.nodo = br
		"seto":
			var se: Reactivo3D = _reactivo("seto", pz.celda)
			if se == null:
				_avisar_pieza(pz, "no hay seto de la maqueta en %s (letra «z»)" % pz.celda)
				return
			se.mojable = bool(pz.p.get("mojable", false))
			pz.nodo = se
		"contador":
			if not pz.p.has("de"):
				_avisar_pieza(pz, "el contador necesita «de=<casillas>» (lo que cuenta)")
				return
			var lista: Array = []
			for c in (pz.p["de"] as Array):
				var o: Node = _encendible_en(c as Vector2i)
				if o == null:
					_avisar_pieza(pz, "no hay nada que arda en %s (brasero, fogata, seto…)" % (c as Vector2i))
				else:
					lista.append(o)
			if lista.is_empty():
				return
			var ct := ContadorReactivos3D.new()
			ct.name = pz.id
			ct.preparar(lista, int(pz.p.get("minimo", 0)), pz.celda)
			cont.add_child(ct)
			pz.nodo = ct
		"cuerda":
			var cu := Cuerda3D.new()
			cu.name = pz.id
			cu.preparar(pz.celda, null)
			cont.add_child(cu)
			pz.nodo = cu


## Lo que arde (o puede arder) en una casilla y tiene `is_lit`: un brasero, una fogata, un seto, una cuerda… `null` si no hay nada.
func _encendible_en(c: Vector2i) -> Node:
	for grupo in [Reactivo3D.GRUPO_REACTIVO, Reactivo3D.GRUPO_ARDE]:
		for n in get_tree().get_nodes_in_group(String(grupo)):
			if is_instance_valid(n) and n.get("celda") == c and n.get("is_lit") != null:
				return n
	return null


## Segunda pasada: enlaza lo que apunta a otra pieza. Un enlace que no se puede hacer es un aviso, no un fallo.
func _enlazar(pz: Pieza) -> void:
	if not is_instance_valid(pz.nodo):
		return
	match pz.tipo:
		"brasero":
			if not (pz.p.has("rele") or pz.p.has("dura") or pz.p.has("espera")):
				return
			var siguiente: Reactivo3D = null
			if pz.p.has("rele"):
				var ps: Pieza = _piezas.get(pz.p["rele"], null)
				if ps == null or ps.tipo != "brasero" or not is_instance_valid(ps.nodo):
					_avisar_pieza(pz, "rele=%s: no es un brasero que se haya montado" % pz.p["rele"])
				else:
					siguiente = ps.nodo as Reactivo3D
			(pz.nodo as Reactivo3D).configurar_rele(siguiente, float(pz.p.get("espera", Reactivo3D.T_RELE_ESPERA)), float(pz.p.get("dura", Reactivo3D.T_RELE_DURA)))
		"cuerda":
			if not pz.p.has("sostiene"):
				return
			var po: Pieza = _piezas.get(pz.p["sostiene"], null)
			if po == null or not is_instance_valid(po.nodo) or not (po.nodo.has_method("tender") or po.nodo.has_method("cerrar")):
				_avisar_pieza(pz, "sostiene=%s: tiene que ser una compuerta o un puente que se haya montado" % pz.p["sostiene"])
			else:
				(pz.nodo as Cuerda3D).sostiene = po.nodo


func _reactivo(tipo: String, c: Vector2i) -> Reactivo3D:
	for r in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		if is_instance_valid(r) and String(r.get("tipo")) == tipo and r.get("celda") == c:
			return r
	return null


## Profundidad 0 de una casilla de agua: el fondo del cajón de un canal de ruinas, o el lecho de un cauce «c».
func _fondo(c: Vector2i) -> float:
	if Terreno3D.es_canal_ruinas(c):
		return Terreno3D.alto_suelo + Terreno3D.FONDO_CANAL
	return Terreno3D.alto_agua - Terreno3D.LECHO_AGUA


func _abrir_celdas(celdas: Array) -> void:
	for c in celdas:
		Terreno3D.cauces_abiertos[c] = true
		Terreno3D.agua_sim.solidificar_casilla(c as Vector2i, false)


## Pone a echar agua un manantial o una tinaja. `args` = [caudal, volumen] (lo que falte sale de la pieza o de Surtidor3D).
func _abrir_cauce(pz: Pieza, args: Array) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return
	var caudal: float
	var volumen: float
	var cauce: Array
	var rampa: bool = true
	if pz.tipo == "tinaja":
		caudal = float(args[0]) if args.size() > 0 else Surtidor3D.CAUDAL_TINAJA
		volumen = float(args[1]) if args.size() > 1 else Surtidor3D.VOL_TINAJA
		cauce = pz.p.get("canal", [])
		if cauce.is_empty():
			_avisar_pieza(pz, "abrir_cauce necesita «canal=<lista>»")
			return
	else:
		caudal = float(args[0]) if args.size() > 0 else float(pz.p.get("caudal", 0.5))
		volumen = float(args[1]) if args.size() > 1 else float(pz.p.get("volumen", 0.0))
		rampa = bool(pz.p.get("rampa", true))
		cauce = [pz.celda]
		for c in (pz.p.get("celdas", []) as Array):
			if c != pz.celda:
				cauce.append(c)                         # la primera casilla es la del manantial
	if rampa:
		Mundo3D.abrir_cauce(cauce, caudal, volumen)
	else:
		_abrir_celdas(cauce)
		sim.fuente_en(pz.celda, caudal)
		if volumen > 0.0:
			sim.limitar_fuente(pz.celda, volumen)
	pz.activa = true


func _apagar_fuente(pz: Pieza) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return
	var c: Vector2i = pz.celda
	if pz.tipo == "tinaja":
		var canal: Array = pz.p.get("canal", [])
		if canal.is_empty():
			_avisar_pieza(pz, "apagar_fuente necesita «canal=<lista>»")
			return
		c = canal[0]
	sim.apagar_fuente(c)
	pz.activa = false


func _helar(pz: Pieza, segundos: float) -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return
	var celdas: Array = pz.p.get("celdas", [pz.celda])
	for c in celdas:
		sim.helar_casilla(c as Vector2i, true)
		Terreno3D.poner_helada(c as Vector2i, true)
		_hielos[c] = segundos


# ---------------------------------------------------------------------------------------------------------------------
#  Conectar las reglas
# ---------------------------------------------------------------------------------------------------------------------

func _conectar() -> void:
	for r in _reglas:
		var rr: Dictionary = r
		var fuente: Pieza = _piezas.get(rr["cuando_id"], null)
		if fuente == null or not is_instance_valid(fuente.nodo):
			_avisar("línea %d: puzle «%s»: la pieza «%s» no se pudo montar, la regla no actúa" % [rr["n"], rr["nombre"], rr["cuando_id"]])
			continue
		var info: Array = (SENALES[fuente.tipo] as Dictionary)[rr["senal"]]
		fuente.nodo.connect(String(info[0]), _callable_de(rr, int(info[1]), info[2]))


## El Callable de una regla: una lambda PROPIA por regla. No vale `Callable(self, "_disparar").bind(regla)`: Godot compara las conexiones por el
## Callable BASE y se queda con la primera (medido 16/10: «alcanzado→abrir» y «perdido→cerrar» de un mismo nivel, la segunda no se conectaba y la
## puerta no se cerraba nunca). Una lambda es única, y su aridad es la de la señal (`nargs`); `filtro` (true/false) deja pasar solo ese valor
## del primer argumento (`cambio(abierta)`, `nivel_alcanzado(si)`, `girando(si)`); null = pasa todo.
func _callable_de(regla: Dictionary, nargs: int, filtro: Variant) -> Callable:
	if filtro != null:
		var esperado: bool = bool(filtro)
		return func(valor: bool) -> void:
			if valor == esperado:
				_disparar(regla)
	match nargs:
		0:
			return func() -> void: _disparar(regla)
		1:
			return func(_a: Variant) -> void: _disparar(regla)
		_:
			return func(_a: Variant, _b: Variant) -> void: _disparar(regla)


func _disparar(regla: Dictionary) -> void:
	if String(regla["si_id"]) != "" and not _cumple(String(regla["si_id"]), String(regla["si_cond"])):
		regla["ignoradas"] = int(regla["ignoradas"]) + 1
		return
	regla["veces"] = int(regla["veces"]) + 1
	for a in (regla["acciones"] as Array):
		_ejecutar(a as Dictionary)


func _cumple(id: String, cond: String) -> bool:
	var pz: Pieza = _piezas.get(id, null)
	if pz == null or not is_instance_valid(pz.nodo):
		return false
	var c: Array = (CONDICIONES[pz.tipo] as Dictionary)[cond]
	return bool(pz.nodo.get(String(c[0]))) == bool(c[1])


func _ejecutar(a: Dictionary) -> void:
	var pz: Pieza = _piezas.get(a["id"], null)
	if pz == null:
		return
	var args: Array = a["args"]
	var nd: Node = pz.nodo if is_instance_valid(pz.nodo) else null
	match String(a["accion"]):
		"pulsar":
			if nd != null:
				nd.call("pulsar")
		"abrir":
			if nd != null:
				nd.call("abrir")
		"cerrar":
			if nd != null:
				nd.call("cerrar")
		"alternar":
			if nd != null:
				nd.call("alternar")
		"encender":
			if nd != null:
				if pz.tipo == "brasero":
					nd.call("encender_llama")
				elif pz.tipo == "seto":
					nd.call("ignite")
				else:
					nd.call("encender")
		"apagar":
			if nd != null:
				nd.call("apagar_llama" if pz.tipo == "brasero" else "apagar")
		"quemar":
			if nd != null:
				nd.call("quemar")
		"mojar":
			if nd == null:
				return
			if pz.tipo == "tinaja":
				nd.call("on_spell_hit", runa(["agua", "humedo"]), Vector3.ZERO)
			else:
				nd.call("mojar")
		"secar":
			if nd != null:
				nd.call("secar")
		"abrir_cauce":
			_abrir_cauce(pz, args)
		"apagar_fuente":
			_apagar_fuente(pz)
		"helar":
			_helar(pz, float(args[0]) if args.size() > 0 else AguaSim3D.DURA_HIELO)


func _process(delta: float) -> void:
	# Hielos puestos por una regla: caducan como los del hechizo (con el reloj de este nodo: va con la simulación y con las pruebas sin ventana).
	for c in _hielos.keys():
		_hielos[c] = float(_hielos[c]) - delta
		if float(_hielos[c]) <= 0.0:
			_hielos.erase(c)
			if Terreno3D.agua_sim != null:
				Terreno3D.agua_sim.helar_casilla(c, false)
			Terreno3D.poner_helada(c, false)
