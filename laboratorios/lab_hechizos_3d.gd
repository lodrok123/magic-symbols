class_name LabHechizos3D
extends LabRecetas3D

## LABORATORIO DE HECHIZOS (H1, 18/10, Juego). Es el laboratorio de recetas (LabRecetas3D, que sigue siendo su base: HUD, panel de glifos, alambre,
## barrido, tiempo) MÁS lo que pide docs/PLAN_TRES_FRENTES.md §0: pestañas, el modo de conjuro completo y un goblin que ataca. Hereda en vez de
## copiar para no tener dos laboratorios que se desincronicen: lo de R4 (154) sigue igual y aquí solo se añade.
## Escena: laboratorios/LabHechizos3D.tscn (LabRecetas3D.tscn queda como alias que la instancia). Mapa: mapas/LabHechizos.txt.
##
## PESTAÑAS (F1–F3; el lab se las queda: las F1–F6 de la maqueta —modo de luz, rugosidad, cabeza— no llegan a ella mientras está abierto):
##   F1 Receta  · lo de hoy (panel de glifos, alambre, casillas, barrido) + (HC5) la TABLA DEL HECHIZO a la derecha: cada campo con su valor, su defecto y de dónde viene
##        (elemento / glifo / calidad / derivado / lab); lo que difiere del defecto, resaltado. ↑/↓ elige fila, ←/→ cambia el valor (Mayús ×10), Retroceso restaura la fila
##        (Mayús+Retroceso todas): el SIGUIENTE lanzamiento usa lo tocado. G lo guarda, P lo imprime como modificadores listos para pegar en Sigils.GLIFOS o un .tres.
##   F2 Cast point · lab_cast_point_3d.gd (LabCastPoint3D, T-CP1): clip recortado, instante, origen desplazable, una mano.
##   F3 Impacto · las constantes `static` de Combate3D EN VIVO (empuje, suelo, hit-stop, destello, aplastamiento, salto, interrupción):
##        ↑/↓ elige, ←/→ cambia (Mayús ×10), G guarda en user://lab_hechizos.json, P imprime la tabla para volcarla a combate_3d.gd.
## COMUNES: G guarda · P imprime · Numpad / cámara lateral ↔ de juego · L / . / , tiempo (TiempoLab3D).
##
## MODO CONJURO COMPLETO (C): lanza por el CAMINO REAL, `Lanzador3D.lanzar_ahora(datos, origen, dir, true)`: las fases runa → voluta → forma → (clip) →
## disparo, con la receta del panel. Es lo que ve el jugador; el modo RÁPIDO (de hoy, `lanzar_receta`) sale en el mismo fotograma y mide solo la
## materialización. Por defecto TINTA INFINITA y RECARGA APAGADA (se rellenan en cada lanzamiento) para poder repetir; con los interruptores
## (Numpad + y −, o los botones) se miden de verdad: sin tinta no lanza («sin_tinta») y con recarga espera a `cooldown_left`.
## En el modo completo la vigilancia del barrido empieza al DISPARAR (no al soltar): si no, la ventana de 0,8 s se cerraría antes de que salga nada.
## GOBLIN QUE ATACA: el cuarto goblin (celda GOBLIN_ATACANTE) no es diana quieta: Numpad × lo enciende (Combate3D.quieto = false). Mientras ataca,
## el lab cura al jugador cada fotograma (así un barrido largo no acaba en la pantalla de muerte).
## BARRIDO LIMPIO: antes de cada ronda `limpiar_sala()` deshace los bloques de tierra, quita zonas y solideces, devuelve el agua a lo que había,
## derrite el hielo y borra los estados de suelo; sin eso los resultados se contaminan y salen falsos «sin_efecto_visible».
##
## TECLAS (en F2 mandan las de F2; B es el barrido solo fuera de F2):
##   F1/F2/F3 pestaña · C modo completo ↔ rápido (en F2 la C es de «fuente de clip») · Numpad + tinta infinita · Numpad − recarga · Numpad × goblin que ataca
##   Numpad / cámara lateral · Espacio lanza · B barrido · Tab elemento · Numpad 1–8 glifos · Numpad 0 limpia · R recarga · L . , tiempo · G guarda · P imprime
##   F4 interfaz completa ↔ compacta (la compacta es la de F1 por defecto; ver la sección «Interfaz COMPACTA» del final)

const NIVEL_HECHIZOS: String = "LabHechizos"
const FILAS_TABLA: int = 34                      ## filas de la tabla de F1 que caben a la vez (el resto se desplaza con la selección)
const COLOR_ORIGEN: Dictionary = {"elemento": "#ffb070", "glifo": "#8fd6ff", "calidad": "#c9a0ff", "lab": "#ffe45e", "derivado": "#8a8a8a", "defecto": "#707070"}
const GOBLIN_ATACANTE: Vector2i = Vector2i(23, 12)
const RUTA_GUARDADO: String = "user://lab_hechizos.json"
const FASES_CONJURO: Array = ["runa", "voluta", "forma", "disparo"]
const CAMARA_LATERAL_TAM: float = 7.0

## Constantes de Combate3D que enseña F3: nombre, paso de cada pulsación, mínimo, máximo. (SQUASH_ESCALA y SALTO_ELEMENTOS no son de un solo número:
## el aplastamiento se toca por la X/Z y la Y por separado abajo, y los elementos del salto no se editan aquí.)
const IMPACTO: Array = [
	{"n": "MULT_EMPUJE", "paso": 0.25, "min": 0.0, "max": 10.0},
	{"n": "EMPUJE_MIN_CASILLAS", "paso": 0.05, "min": 0.0, "max": 3.0},
	{"n": "MULT_EMPUJE_ELEMENTAL", "paso": 0.05, "min": 0.0, "max": 3.0},
	{"n": "DECAIMIENTO_EMPUJE", "paso": 0.5, "min": 1.0, "max": 30.0},
	{"n": "HITSTOP", "paso": 0.01, "min": 0.0, "max": 0.5},
	{"n": "HITSTOP_DEBIL", "paso": 0.01, "min": 0.0, "max": 0.5},
	{"n": "DESTELLO_GOLPE", "paso": 0.02, "min": 0.0, "max": 1.0},
	{"n": "SQUASH_XZ", "paso": 0.05, "min": 0.5, "max": 2.0},
	{"n": "SQUASH_Y", "paso": 0.05, "min": 0.3, "max": 2.0},
	{"n": "SQUASH_TIEMPO", "paso": 0.01, "min": 0.02, "max": 1.0},
	{"n": "SALTO_ALTO", "paso": 0.05, "min": 0.0, "max": 2.0},
	{"n": "SALTO_TIEMPO", "paso": 0.02, "min": 0.05, "max": 1.0},
	{"n": "INTERRUPCION_GOLPE", "paso": 0.05, "min": 0.0, "max": 3.0},
	{"n": "INTERRUPCION_DANO", "paso": 0.05, "min": 0.0, "max": 3.0},
]

enum Pestana { RECETA, CAST_POINT, IMPACTO }

var pestana: int = Pestana.RECETA
var modo_completo: bool = false
var tinta_infinita: bool = true
var recarga_activa: bool = false
var atacar_goblin: bool = false
var atacante: Combate3D = null
var camara_lateral: bool = false
var impacto_sel: int = 0
var cambios_hechizo: Dictionary = {}           ## HC5: lo que has tocado en la tabla de F1 (campo -> valor); el Lanzador3D lo aplica al siguiente hechizo
var tabla_sel: int = 0                         ## fila elegida de la tabla de F1
var _tabla_label: RichTextLabel = null
var impacto_inicial: Dictionary = {}           ## los valores de Combate3D al abrir el lab (para «restaurar» y para saber qué has tocado)
var fases_vistas: Array = []                   ## [{fase, t_ms}] del último conjuro completo, en el orden en que salieron
var conjuros: int = 0                          ## lanzamientos por el camino real
var f2: Variant = null                         ## LabCastPoint3D si existe (T-CP1); null si no
var limpiezas: int = 0

var _cam_lat: Camera3D = null
var _cam_juego: Camera3D = null
var _t_conjuro_ini: float = 0.0               ## segundos DE JUEGO (la suma de deltas, con time_scale: lo mismo que cuentan los temporizadores del conjuro)
var _t_juego: float = 0.0
var _t_disparo_us: int = 0
var _agua_base: Dictionary = {}                ## Vector2i -> profundidad que tenía la casilla al abrir el lab
var _fuentes_base: Dictionary = {}             ## Vector2i -> caudal que tenía (los manantiales del mapa se respetan; los de los hechizos se apagan)
var _panel_extra: Dictionary = {}              ## nombre -> Button / Label del panel de modos
var _impacto_nodos: Dictionary = {}


func nivel_mapa() -> String:
	return NIVEL_HECHIZOS


func iniciar(mundo: Variant) -> void:
	super.iniciar(mundo)
	if _jug == null or _l == null:
		return
	_cam_juego = get_viewport().get_camera_3d()
	_l.conjuro_fase.connect(_al_conjuro_fase)
	_l.lanzado.connect(_al_lanzado)
	for e in IMPACTO:
		impacto_inicial[String(e["n"])] = impacto_valor(String(e["n"]))
	_registrar_agua()
	_l.cambios_hechizo = cambios_hechizo           # el mismo diccionario: lo que se toque aquí lo ve el lanzador al instante
	_montar_panel_modos()
	_montar_f2()
	_montar_tabla()
	_quitar_paleta()
	_montar_ui_compacta()
	poner_atacar(false)
	_refrescar_hud()
	_aplicar_ui()


## Cuarto goblin: el que está en GOBLIN_ATACANTE queda libre (según `atacar_goblin`); los demás, quietos. Devuelve cuántos quedaron quietos.
func quietar_goblins() -> int:
	var n: int = 0
	atacante = null
	var mejor: float = INF
	var centro: Vector3 = Terreno3D.centro_de(GOBLIN_ATACANTE, 0.0)
	for c in get_tree().get_nodes_in_group("combate3d"):
		if c is Combate3D:
			var d: float = Vector2((c as Combate3D).position.x - centro.x, (c as Combate3D).position.z - centro.z).length()
			if d < mejor:
				mejor = d
				atacante = c as Combate3D
	for c in get_tree().get_nodes_in_group("combate3d"):
		if c is Combate3D and c != atacante:
			(c as Combate3D).quieto = true
			n += 1
	return n


func poner_atacar(si: bool) -> void:
	atacar_goblin = si
	if atacante != null and is_instance_valid(atacante):
		atacante.quieto = not si
	_actualizar_panel_modos()


# ---------------------------------------------------------------------------------------------------------------------
#  Modo conjuro completo
# ---------------------------------------------------------------------------------------------------------------------

func poner_modo_completo(si: bool) -> void:
	modo_completo = si
	_actualizar_panel_modos()


## ¿Ya está en marcha un conjuro? (el camino real no deja lanzar dos a la vez: `conjurando`).
func conjurando() -> bool:
	return _l != null and _l.conjurando


func _lanzar(r: Lanzador3D.Receta3D, cont: Dictionary, elem: String, dir: Vector3) -> Dictionary:
	if not modo_completo:
		return super._lanzar(r, cont, elem, dir)
	return _lanzar_completo(r, cont, elem, dir)


## Lanza por el camino real. Devuelve la ficha (también en `ultimo`); `ultimo["rechazo"]` dice por qué no se lanzó, si no se lanzó. La ficha se
## completa sola al disparar (`_al_lanzado`): `n`, `ms` y el orden de las fases en `fases_vistas`.
func _lanzar_completo(r: Lanzador3D.Receta3D, cont: Dictionary, elem: String, dir: Vector3) -> Dictionary:
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % elem) as RuneData
	var g: Dictionary = r.geo()
	var coste: float = Tinta.coste_receta(r.coste_v2())
	var aviso: String = Lanzador3D.GeometriaV2.aviso_materia(g, rune)
	var ficha: Dictionary = {"glifos": cont.duplicate(), "elemento": elem, "dir": dir, "n": 0, "ms": 0.0, "estado": rune.estado, "celdas": 0,
		"nodos_pico": 0, "motivos": [], "aviso": aviso, "nombre": String(g["nombre"]), "coste": r.coste_v2(), "completo": true, "rechazo": ""}
	ultimo = ficha
	if _l.conjurando:
		ficha["rechazo"] = "conjurando"
		return ficha
	if tinta_infinita:
		if _l.tinta != null:
			_l.tinta.actual = _l.tinta.maxima
	elif _l.tinta != null and not _l.tinta.puede_pagar(r.forma(), coste):
		ficha["rechazo"] = "sin_tinta"
		PlayLog.event("receta_rara", {"glifos": cont, "elemento": elem, "estado": rune.estado, "nombre": ficha["nombre"], "motivos": ["sin_tinta"],
			"ms": 0.0, "casillas": 0, "nodos_pico": 0, "coste": snappedf(r.coste_v2(), 0.01), "semilla": semilla if barrido else 0, "ronda": rondas,
			"frame_max_ms": 0.0})
		return ficha
	if not recarga_activa:
		_l.cooldown_left[0] = 0.0
	elif float(_l.cooldown_left[0]) > 0.0:
		ficha["rechazo"] = "recarga"
		return ficha
	if aviso != "":
		ficha["rechazo"] = "rechazada"
		return ficha
	var glifos_n: Array = []
	for nombre in Sigils.GLIFOS_V2:
		for _i in range(int(cont.get(nombre, 0))):
			glifos_n.append(String(nombre))
	var datos: Dictionary = {"indice": 0, "receta": r, "rune": rune, "calidad": 1.0, "glifos": glifos_n, "elemento_nombre": String(NOMBRE_ELEMENTO.get(elem, elem))}
	fases_vistas.clear()
	_t_conjuro_ini = _t_juego
	_t_disparo_us = 0
	_lanzado_celdas = []
	var nodos0: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	conjuros += 1
	lanzadas += 1
	var origen: Vector3 = _jug.position
	_l.lanzar_ahora(datos, origen, dir, true)
	if not recarga_activa:
		_l.cooldown_left[0] = 0.0
	# La ventana de vigilancia empieza al disparar: «t» arranca en -(lo que dura el conjuro) para que solo cuente lo que pasa después.
	_obs = {"ficha": ficha, "nodos0": nodos0, "t": -_l.retardo_total(Objetos.elemento_de(rune)) - 0.1, "ultimo_us": Time.get_ticks_usec(), "frame_max_ms": 0.0}
	return ficha


func _al_conjuro_fase(fase: String, _el: String, _pos: Vector3) -> void:
	fases_vistas.append({"fase": fase, "t_ms": int(round((_t_juego - _t_conjuro_ini) * 1000.0))})
	if fase == "disparo":
		_t_disparo_us = Time.get_ticks_usec()


## Termina el disparo del camino real: aquí se sabe cuántas casillas salieron y lo que costó materializarlas.
func _al_lanzado(_elemento: String, _forma: String, n: int) -> void:
	if _t_disparo_us == 0 or ultimo.is_empty() or not bool(ultimo.get("completo", false)):
		return
	ultimo["n"] = n
	ultimo["ms"] = float(Time.get_ticks_usec() - _t_disparo_us) / 1000.0
	ultimo["celdas"] = _lanzado_celdas.size()
	_t_disparo_us = 0


## En el modo completo no se anota `rechazada`/`sin_casillas` dos veces: lo que no se lanzó ya está en `ultimo["rechazo"]`; aquí solo se evita vigilar nada.
func _process(delta: float) -> void:
	super._process(delta)
	_t_juego += delta
	if _t_aviso > 0.0:
		_t_aviso -= delta
		if _t_aviso <= 0.0 and _lbl_aviso != null:
			_lbl_aviso.text = ""
	if atacar_goblin and _jug != null:
		_jug.vida = 100.0
		_jug.muerto = false
	if camara_lateral and _cam_lat != null and _jug != null:
		_cam_lat.position = _jug.position + Vector3(0.0, 1.2, 14.0)


# ---------------------------------------------------------------------------------------------------------------------
#  Barrido limpio
# ---------------------------------------------------------------------------------------------------------------------

func _ronda_barrido() -> void:
	limpiar_sala()
	super._ronda_barrido()


## Guarda cómo está el agua al abrir el lab, para devolverla a ese estado.
func _registrar_agua() -> void:
	_agua_base.clear()
	_fuentes_base.clear()
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return
	for y in range(Terreno3D.mapa.size()):
		for x in range(Terreno3D.mapa[y].length()):
			_agua_base[Vector2i(x, y)] = sim.profundidad_casilla(Vector2i(x, y))
			if sim.caudal_en(Vector2i(x, y)) > 0.0:
				_fuentes_base[Vector2i(x, y)] = sim.caudal_en(Vector2i(x, y))


## Deja la sala como estaba al abrir el lab (lo que un hechizo puede haber dejado): bloques de tierra, zonas y solideces V2, hielo, agua y
## estados de suelo. NO toca a los enemigos ni al jugador. Devuelve cuánto limpió de cada cosa (para la prueba y el HUD).
func limpiar_sala() -> Dictionary:
	var r: Dictionary = {"bloques": 0, "zonas": 0, "solideces": 0, "estados": 0, "agua": 0.0}
	for b in _l._bloques.duplicate():           # TODOS los bloques, también los de volumen V2 (bloques_de_tierra() solo cuenta los antiguos)
		_l._deshacer_bloque(b)
		r["bloques"] += 1
	for z in _l._zonas_v2.duplicate():
		if is_instance_valid(z):
			(z as Node).queue_free()
			r["zonas"] += 1
	_l._zonas_v2.clear()
	for s in _l._solideces_v2.duplicate():
		if is_instance_valid(s):
			(s as Node).queue_free()
			r["solideces"] += 1
	_l._solideces_v2.clear()
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim != null:
		# Hielo y agua. `quitar` solo alcanza los trocitos de un círculo de media casilla y el agua se reparte al moverse, así que se repite
		# hasta que no quede diferencia (como mucho 5 pasadas).
		var cas: float = Terreno3D.casilla
		for _pasada in range(5):
			var movido: bool = false
			for y in range(Terreno3D.mapa.size()):
				for x in range(Terreno3D.mapa[y].length()):
					var c: Vector2i = Vector2i(x, y)
					if sim.caudal_en(c) > 0.0 and not _fuentes_base.has(c):
						sim.apagar_fuente(c)          # el manantial que dejó un hechizo de agua (sigue echando hasta llenar su parte)
					if sim.casilla_helada(c):
						sim.derretir(Terreno3D.centro_de(c, 0.0), cas * 0.5)
					var dif: float = sim.profundidad_casilla(c) - float(_agua_base.get(c, 0.0))
					if absf(dif) < 0.0008:
						continue
					movido = true
					var p: Vector3 = Terreno3D.centro_de(c, 0.0)
					if dif > 0.0:
						r["agua"] += sim.quitar(p, dif * cas * cas, cas * 0.75)
					else:
						sim.anadir(p, -dif * cas * cas, cas * 0.5)
						r["agua"] -= -dif * cas * cas
			if not movido:
				break
	var est: EstadosSuelo3D = Terreno3D.estados
	for e in EstadosSuelo3D.TODOS:
		for c in est.celdas(String(e)):
			if est.poner(c as Vector2i, String(e), false):
				r["estados"] += 1
	limpiezas += 1
	return r


# ---------------------------------------------------------------------------------------------------------------------
#  F3 · Impacto: las constantes de Combate3D en vivo
# ---------------------------------------------------------------------------------------------------------------------

## Valor actual de una entrada de IMPACTO. SQUASH_XZ / SQUASH_Y son las componentes de SQUASH_ESCALA.
static func impacto_valor(nombre: String) -> float:
	match nombre:
		"SQUASH_XZ":
			return Combate3D.SQUASH_ESCALA.x
		"SQUASH_Y":
			return Combate3D.SQUASH_ESCALA.y
	return float((Combate3D as GDScript).get(nombre))


static func impacto_poner(nombre: String, v: float) -> void:
	match nombre:
		"SQUASH_XZ":
			Combate3D.SQUASH_ESCALA = Vector3(v, Combate3D.SQUASH_ESCALA.y, v)
		"SQUASH_Y":
			Combate3D.SQUASH_ESCALA = Vector3(Combate3D.SQUASH_ESCALA.x, v, Combate3D.SQUASH_ESCALA.z)
		_:
			(Combate3D as GDScript).set(nombre, v)


## Cambia la entrada `i` de IMPACTO `pasos` veces su paso (con tope en su mínimo y máximo). Devuelve el valor nuevo.
func impacto_cambiar(i: int, pasos: int) -> float:
	var e: Dictionary = IMPACTO[clampi(i, 0, IMPACTO.size() - 1)]
	var v: float = clampf(impacto_valor(String(e["n"])) + float(pasos) * float(e["paso"]), float(e["min"]), float(e["max"]))
	v = snappedf(v, float(e["paso"]) * 0.1)
	impacto_poner(String(e["n"]), v)
	return v


func impacto_restaurar() -> void:
	for n in impacto_inicial:
		impacto_poner(String(n), float(impacto_inicial[n]))


func impacto_tabla() -> Dictionary:
	var d: Dictionary = {}
	for e in IMPACTO:
		d[String(e["n"])] = snappedf(impacto_valor(String(e["n"])), 0.0001)
	return d


# ---------------------------------------------------------------------------------------------------------------------
#  HC5: la tabla del hechizo (F1)
# ---------------------------------------------------------------------------------------------------------------------

## El hechizo que saldría ahora con los glifos del panel y el elemento elegido, SIN lo que has tocado en la tabla.
func hechizo_base() -> Hechizo:
	return receta().hechizo(runa())


## El mismo con lo tocado encima: es lo que enseña la tabla y lo que lanzará el siguiente Espacio.
func hechizo_actual() -> Hechizo:
	var h: Hechizo = hechizo_base()
	return h.con(cambios_hechizo) if not cambios_hechizo.is_empty() else h


func tabla_filas() -> Array:
	return hechizo_actual().tabla()


func tabla_mover(pasos: int) -> void:
	var n: int = tabla_filas().size()
	tabla_sel = posmod(tabla_sel + pasos, maxi(n, 1))


## Cambia la fila elegida `pasos` veces su paso (los bool se alternan, las listas avanzan). Si el valor vuelve al que tenía el hechizo sin tocar, la sobrescritura se quita.
## Devuelve el valor nuevo, o null si la fila no se toca.
func tabla_cambiar(pasos: int) -> Variant:
	var filas: Array = tabla_filas()
	var fila: Dictionary = filas[clampi(tabla_sel, 0, filas.size() - 1)]
	var campo: String = String(fila["campo"])
	if not Hechizo.EDITABLES.has(campo):
		return null
	var e: Dictionary = Hechizo.EDITABLES[campo]
	var actual: Variant = fila["valor"]
	var nuevo: Variant
	match String(e.get("tipo", "numero")):
		"bool":
			nuevo = not bool(actual)
		"lista":
			var vals: Array = e["valores"]
			nuevo = vals[posmod(vals.find(String(actual)) + (1 if pasos > 0 else -1), vals.size())]
		_:
			var v: float = clampf(float(actual) + float(pasos) * float(e["paso"]), float(e["min"]), float(e["max"]))
			nuevo = snappedf(v, float(e["paso"]) * 0.1)
			if actual is int:
				nuevo = int(roundf(float(nuevo)))
	var base: Variant = hechizo_base()._leer(campo)
	if (nuevo is float and base is float and is_equal_approx(float(nuevo), float(base))) or nuevo == base:
		cambios_hechizo.erase(campo)
	else:
		cambios_hechizo[campo] = nuevo
	_refrescar_hud()
	return nuevo


func tabla_restaurar(todas: bool = false) -> void:
	if todas:
		cambios_hechizo.clear()
	else:
		var filas: Array = tabla_filas()
		cambios_hechizo.erase(String(filas[clampi(tabla_sel, 0, filas.size() - 1)]["campo"]))
	_refrescar_hud()


func _montar_tabla() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	_tabla_label = RichTextLabel.new()
	_tabla_label.bbcode_enabled = true
	_tabla_label.scroll_active = false
	_tabla_label.fit_content = false
	_tabla_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabla_label.anchor_left = 1.0
	_tabla_label.anchor_right = 1.0
	_tabla_label.offset_left = -600.0
	_tabla_label.offset_right = -8.0
	_tabla_label.offset_top = 8.0
	_tabla_label.offset_bottom = 640.0
	_tabla_label.add_theme_font_size_override("normal_font_size", 13)
	_tabla_label.add_theme_font_size_override("bold_font_size", 13)
	_tabla_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_tabla_label.add_theme_constant_override("outline_size", 5)
	capa.add_child(_tabla_label)


## El texto de la tabla (BBCode) de las filas visibles, en una tabla de 4 columnas (campo, valor, defecto, origen) para que alinee con cualquier tipografía. ► = la fila elegida;
## lo que difiere del defecto va en negrita y en el color de su origen (elemento, glifo, calidad, lab); lo que no difiere, en gris; los derivados, en gris oscuro.
func texto_tabla() -> String:
	var filas: Array = tabla_filas()
	var desde: int = clampi(tabla_sel - FILAS_TABLA / 2, 0, maxi(filas.size() - FILAS_TABLA, 0))
	var t: PackedStringArray = []
	t.append("[b]HECHIZO[/b] · ↑↓ fila · ←→ cambia (Mayús ×10) · Retroceso restaura (Mayús: todas) · G guarda · P imprime%s" % [
		"   [color=#ffe45e]%d tocado(s)[/color]" % cambios_hechizo.size() if not cambios_hechizo.is_empty() else ""])
	t.append("[table=4]")
	for cab in ["campo", "valor", "defecto", "origen"]:
		t.append("[cell][color=#909090]%s[/color]   [/cell]" % cab)
	var grupo: String = ""
	for i in range(desde, mini(desde + FILAS_TABLA, filas.size())):
		var f: Dictionary = filas[i]
		if String(f["grupo"]) != grupo:
			grupo = String(f["grupo"])
			t.append("[cell][color=#606060]— %s —[/color][/cell][cell][/cell][cell][/cell][cell][/cell]" % grupo)
		var col: String = String(COLOR_ORIGEN.get(String(f["tipo_origen"]), "#ffffff")) if bool(f["difiere"]) or String(f["tipo_origen"]) == "derivado" else "#9a9a9a"
		var negrita: bool = bool(f["difiere"])
		var celdas: Array = [("► " if i == tabla_sel else "   ") + String(f["campo"]), _fmt(f["valor"]), _fmt(f["defecto"]), String(f["origen"])]
		for c in celdas:
			var txt: String = String(c).replace("[", "(")
			t.append("[cell][color=%s]%s[/color]   [/cell]" % [col, ("[b]%s[/b]" % txt) if negrita else txt])
	t.append("[/table]")
	return "\n".join(t)


func _fmt(v: Variant) -> String:
	if v is float:
		return str(snappedf(float(v), 0.001))
	if v is Color:
		return (v as Color).to_html(false)
	return str(v)


# ---------------------------------------------------------------------------------------------------------------------
#  Guardar / imprimir (comunes a todas las pestañas)
# ---------------------------------------------------------------------------------------------------------------------

func datos_guardado() -> Dictionary:
	var d: Dictionary = {"impacto": impacto_tabla(), "modo_completo": modo_completo, "tinta_infinita": tinta_infinita, "recarga_activa": recarga_activa,
		"hechizo": cambios_hechizo.duplicate()}
	if f2 != null and f2.has_method("datos"):
		d["cast_point"] = f2.call("datos")
	return d


func guardar() -> bool:
	var f := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(datos_guardado(), "\t"))
	return true


## La tabla lista para pegar en el código (la imprime P). Devuelve el texto.
func tabla_texto() -> String:
	var t: PackedStringArray = []
	t.append("# F3 Impacto · constantes de enemigos/combate_3d.gd")
	for e in IMPACTO:
		var n: String = String(e["n"])
		var base: float = float(impacto_inicial.get(n, 0.0))
		var ahora: float = impacto_valor(n)
		t.append("%s = %s%s" % [n, str(snappedf(ahora, 0.0001)), ("   # (antes %s)" % str(snappedf(base, 0.0001))) if not is_equal_approx(base, ahora) else ""])
	t.append("")
	t.append("# F1 Hechizo · lo que has tocado en la tabla (modificadores listos para pegar)")
	t.append(Hechizo.texto_modificadores(cambios_hechizo))
	if f2 != null and f2.has_method("tabla_texto"):
		t.append("")
		t.append(String(f2.call("tabla_texto")))
	return "\n".join(t)


# ---------------------------------------------------------------------------------------------------------------------
#  Cámara
# ---------------------------------------------------------------------------------------------------------------------

func poner_camara_lateral(si: bool) -> void:
	camara_lateral = si
	if si:
		if _cam_lat == null:
			_cam_lat = Camera3D.new()
			_cam_lat.name = "CamaraLateral"
			_cam_lat.projection = Camera3D.PROJECTION_ORTHOGONAL
			_cam_lat.size = CAMARA_LATERAL_TAM
			_cam_lat.near = 0.1
			_cam_lat.far = 80.0
			(m as Node).add_child(_cam_lat)
			_cam_lat.look_at_from_position(Vector3.ZERO, Vector3(0.0, 0.0, -1.0), Vector3.UP)
		_cam_lat.position = _jug.position + Vector3(0.0, 1.2, 14.0)
		_cam_lat.make_current()
	elif _cam_juego != null and is_instance_valid(_cam_juego):
		_cam_juego.make_current()
	_actualizar_panel_modos()


# ---------------------------------------------------------------------------------------------------------------------
#  Teclas
# ---------------------------------------------------------------------------------------------------------------------

func poner_pestana(p: int) -> void:
	pestana = clampi(p, Pestana.RECETA, Pestana.IMPACTO)
	_actualizar_panel_modos()
	_refrescar_hud()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed:
		return
	var atendida: bool = true
	# Con F2 abierta, sus teclas mandan (también las repeticiones: las flechas y Q/A se dejan pulsadas).
	if pestana == Pestana.CAST_POINT and f2 != null and f2.has_method("tecla") and not _es_comun(k):
		if bool(f2.call("tecla", k)):
			get_viewport().set_input_as_handled()
			return
	if k.echo and not ((pestana == Pestana.IMPACTO or pestana == Pestana.RECETA) and (k.keycode == KEY_LEFT or k.keycode == KEY_RIGHT)):
		return
	var paso: int = 10 if k.shift_pressed else 1
	if k.keycode == KEY_F1:
		poner_pestana(Pestana.RECETA)
	elif k.keycode == KEY_F2:
		poner_pestana(Pestana.CAST_POINT)
	elif k.keycode == KEY_F3:
		poner_pestana(Pestana.IMPACTO)
	elif k.keycode == KEY_C and pestana != Pestana.CAST_POINT:
		poner_modo_completo(not modo_completo)
	elif k.keycode == KEY_KP_ADD:
		tinta_infinita = not tinta_infinita
		_actualizar_panel_modos()
	elif k.keycode == KEY_KP_SUBTRACT:
		recarga_activa = not recarga_activa
		_actualizar_panel_modos()
	elif k.keycode == KEY_KP_MULTIPLY:
		poner_atacar(not atacar_goblin)
	elif k.keycode == KEY_KP_DIVIDE:
		poner_camara_lateral(not camara_lateral)
	elif k.keycode == KEY_F4:
		ui_compacta = not ui_compacta
		_aplicar_ui()
	elif k.keycode == KEY_G:
		guardar()
	elif k.keycode == KEY_P:
		print(tabla_texto())
	elif pestana == Pestana.RECETA and k.keycode == KEY_UP:
		tabla_mover(-1)
	elif pestana == Pestana.RECETA and k.keycode == KEY_DOWN:
		tabla_mover(1)
	elif pestana == Pestana.RECETA and k.keycode == KEY_LEFT:
		tabla_cambiar(-paso)
	elif pestana == Pestana.RECETA and k.keycode == KEY_RIGHT:
		tabla_cambiar(paso)
	elif pestana == Pestana.RECETA and k.keycode == KEY_BACKSPACE:
		tabla_restaurar(k.shift_pressed)
	elif pestana == Pestana.IMPACTO and k.keycode == KEY_UP:
		impacto_sel = (impacto_sel - 1 + IMPACTO.size()) % IMPACTO.size()
	elif pestana == Pestana.IMPACTO and k.keycode == KEY_DOWN:
		impacto_sel = (impacto_sel + 1) % IMPACTO.size()
	elif pestana == Pestana.IMPACTO and k.keycode == KEY_LEFT:
		impacto_cambiar(impacto_sel, -paso)
	elif pestana == Pestana.IMPACTO and k.keycode == KEY_RIGHT:
		impacto_cambiar(impacto_sel, paso)
	elif pestana == Pestana.IMPACTO and k.keycode == KEY_BACKSPACE:
		impacto_restaurar()
	else:
		atendida = false
	if atendida:
		get_viewport().set_input_as_handled()
		_refrescar_hud()
		return
	# Lo demás (Espacio, B, Tab, Numpad, R…) es del lab de recetas, que filtra por sí mismo.
	super._unhandled_input(ev)


## Teclas que valen en cualquier pestaña y que F2 NO puede quitarse: las de cambiar de pestaña, el tiempo y los interruptores del Numpad.
func _es_comun(k: InputEventKey) -> bool:
	return [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_KP_ADD, KEY_KP_SUBTRACT, KEY_KP_MULTIPLY, KEY_KP_DIVIDE].has(k.keycode)


# ---------------------------------------------------------------------------------------------------------------------
#  F2 (lo monta lab_cast_point_3d.gd si existe)
# ---------------------------------------------------------------------------------------------------------------------

func _montar_f2() -> void:
	var ruta: String = "res://laboratorios/lab_cast_point_3d.gd"
	if not ResourceLoader.exists(ruta):
		return
	var sc: GDScript = load(ruta) as GDScript
	if sc == null:
		return
	f2 = sc.new()
	f2.call("iniciar", self)


# ---------------------------------------------------------------------------------------------------------------------
#  Panel de modos y HUD
# ---------------------------------------------------------------------------------------------------------------------

func _montar_panel_modos() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	var caja := PanelContainer.new()
	caja.anchor_left = 1.0
	caja.anchor_right = 1.0
	caja.anchor_top = 1.0
	caja.anchor_bottom = 1.0
	caja.offset_left = -270.0
	caja.offset_right = -10.0
	caja.offset_bottom = -10.0
	caja.grow_vertical = Control.GROW_DIRECTION_BEGIN
	capa.add_child(caja)
	_caja_modos = caja
	var v := VBoxContainer.new()
	caja.add_child(v)
	var fila := HBoxContainer.new()
	v.add_child(fila)
	for i in range(3):
		var nombre: String = ["F1 Receta", "F2 Cast point", "F3 Impacto"][i]
		var b: Button = _boton(nombre, func() -> void: poner_pestana(i))
		fila.add_child(b)
		_panel_extra["pestana%d" % i] = b
	_panel_extra["modo"] = _boton("", func() -> void: poner_modo_completo(not modo_completo))
	v.add_child(_panel_extra["modo"])
	_panel_extra["tinta"] = _boton("", func() -> void:
		tinta_infinita = not tinta_infinita
		_actualizar_panel_modos())
	v.add_child(_panel_extra["tinta"])
	_panel_extra["recarga"] = _boton("", func() -> void:
		recarga_activa = not recarga_activa
		_actualizar_panel_modos())
	v.add_child(_panel_extra["recarga"])
	_panel_extra["goblin"] = _boton("", func() -> void: poner_atacar(not atacar_goblin))
	v.add_child(_panel_extra["goblin"])
	_panel_extra["camara"] = _boton("", func() -> void: poner_camara_lateral(not camara_lateral))
	v.add_child(_panel_extra["camara"])
	_actualizar_panel_modos()


func _actualizar_panel_modos() -> void:
	if _panel_extra.is_empty():
		return
	for i in range(3):
		(_panel_extra["pestana%d" % i] as Button).disabled = (pestana == i)
	(_panel_extra["modo"] as Button).text = "Modo: CONJURO COMPLETO (C)" if modo_completo else "Modo: rápido (C)"
	(_panel_extra["tinta"] as Button).text = "Tinta: infinita (Num +)" if tinta_infinita else "Tinta: real (Num +)"
	(_panel_extra["recarga"] as Button).text = "Recarga: real (Num −)" if recarga_activa else "Recarga: apagada (Num −)"
	(_panel_extra["goblin"] as Button).text = "Goblin: ATACA (Num ×)" if atacar_goblin else "Goblin: quieto (Num ×)"
	(_panel_extra["camara"] as Button).text = "Cámara: lateral (Num /)" if camara_lateral else "Cámara: de juego (Num /)"
	_aplicar_ui()


func _refrescar_hud() -> void:
	super._refrescar_hud()
	if _tabla_label != null:
		_tabla_label.visible = pestana == Pestana.RECETA and not _compacta_activa()
		if _tabla_label.visible:
			_tabla_label.text = texto_tabla()
	_refrescar_ui_compacta()


func texto_hud() -> String:
	var lineas: PackedStringArray = []
	lineas.append("[%s]  F1 Receta · F2 Cast point · F3 Impacto        MODO: %s        tinta %s · recarga %s · goblin %s" % [
		["F1 RECETA", "F2 CAST POINT", "F3 IMPACTO"][pestana], "CONJURO COMPLETO" if modo_completo else "rápido",
		"infinita" if tinta_infinita else "real", "real" if recarga_activa else "apagada", "ATACA" if atacar_goblin else "quieto"])
	match pestana:
		Pestana.RECETA:
			lineas.append(super.texto_hud())
		Pestana.CAST_POINT:
			lineas.append(String(f2.call("texto")) if f2 != null and f2.has_method("texto") else "(F2: el laboratorio de cast points no está cargado)")
		Pestana.IMPACTO:
			lineas.append(_texto_impacto())
	lineas.append(_texto_conjuro())
	return "\n".join(lineas)


func _texto_conjuro() -> String:
	var t: PackedStringArray = []
	if _l != null:
		var tin: String = "%.0f/%.0f" % [_l.tinta.actual, _l.tinta.maxima] if _l.tinta != null else "sin tinta"
		t.append("Tinta %s · recarga restante %.1f s · conjurando: %s · conjuros %d" % [tin, float(_l.cooldown_left[0]), "sí" if _l.conjurando else "no", conjuros])
	if not fases_vistas.is_empty():
		var partes: PackedStringArray = []
		for f in fases_vistas:
			partes.append("%s %d ms" % [String(f["fase"]), int(f["t_ms"])])
		t.append("Fases del último conjuro: " + " → ".join(partes))
	if not ultimo.is_empty() and String(ultimo.get("rechazo", "")) != "":
		t.append("Último lanzamiento NO salió: %s" % String(ultimo["rechazo"]))
	return "\n".join(t)


func _texto_impacto() -> String:
	var t: PackedStringArray = []
	t.append("IMPACTO · constantes de Combate3D EN VIVO (↑↓ elige · ←→ cambia, Mayús ×10 · Retroceso restaura · G guarda · P imprime)")
	for i in range(IMPACTO.size()):
		var n: String = String(IMPACTO[i]["n"])
		var v: float = impacto_valor(n)
		var base: float = float(impacto_inicial.get(n, v))
		t.append("%s %-24s %8.3f%s" % ["►" if i == impacto_sel else " ", n, v, ("   (era %.3f)" % base) if not is_equal_approx(v, base) else ""])
	t.append("Lanza con Espacio sobre los goblins quietos para ver el empuje, la pausa, el destello y el aplastamiento.")
	return "\n".join(t)


# ---------------------------------------------------------------------------------------------------------------------
#  Interfaz COMPACTA de F1 (18/10, pedido de Pablo: «solo lo imprescindible para pruebas»)
# ---------------------------------------------------------------------------------------------------------------------
## Sustituye a la vista (no a la lógica) de F1: el jugador en el centro, abajo a la IZQUIERDA el registro de la receta (sello + glifos) y a la DERECHA, en columna, la caja de los
## semiejes X, Y, Z (siempre; con el desplegable de todo lo demás, el elemento y Lanzar/Limpiar) y, DEBAJO, la caja de las variables ACTIVAS: hasta MAX_ACTIVAS filas, cada una con
## el cambio ADITIVO (− + : el paso de la variable, como los ejes) y el MULTIPLICATIVO (÷ ×: valor × FACTOR_MULT^n, lo que haría un glifo de modo «multiplica») y × para quitarla.
## «Activa» = una variable que has fijado desde el desplegable (se queda aunque valga 0, para poder subirla), un glifo con contador > 0 o un campo del Hechizo que has
## tocado (cambios_hechizo). Quitarla (×) la devuelve a su valor: borra la sobrescritura o pone el glifo a 0. Los paneles viejos (glifos, tabla, modos, HUD largo) siguen
## ahí y vuelven con F4; las teclas no cambian. En F2 y F3 se ve la interfaz completa: esas pestañas la necesitan.

const MAX_ACTIVAS: int = 6
const COLOR_ROTULO: Color = Color(1.0, 0.9, 0.35)
const FACTOR_MULT: float = 1.5                  ## lo que multiplica una pulsación de «×» (el por_glifo de los glifos de modo «multiplica»: barrera ×1,5)
const ANCHO_COLUMNA: float = 340.0
const LINEAS_REGISTRO: int = 7                  ## el sello (el elemento) + 6 glifos
const EJES_UI: Array = [["X", "semiejes.x"], ["Y", "semiejes.y"], ["Z", "semiejes.z"]]
const COLOR_TOCADO: Color = Color("#ffe45e")

var ui_compacta: bool = true
var activas: Array = []                        ## claves fijadas desde el desplegable, en orden: «campo:velocidad» o «glifo:barrera»
var _capa_compacta: CanvasLayer = null
var _caja_modos: Control = null                ## el panel de modos de siempre (pestañas, tinta, recarga, goblin, cámara)
var _filas_activas: Array = []
var _filas_ejes: Array = []
var _lbl_mas: Label = null
var _lbl_aviso: Label = null
var _t_aviso: float = 0.0
var _lbl_registro: Label = null
var _rotulo: Label3D = null                    ## el tamaño del hechizo escrito junto a la previsualización (aros amarillos)
var _caja_variables: PanelContainer = null
var _desplegable: OptionButton = null
var _selector_compacto: OptionButton = null


## La paleta de pruebas de glifos (rune_palette.gd) la monta el Lanzador3D en todos los niveles y se escondía/mostraba con F1, que aquí es la pestaña. En el lab se QUITA
## (no se esconde: F1 la volvería a mostrar): los glifos se ponen con el panel, el Numpad o el desplegable. Solo se libera la copia de este lab.
func _quitar_paleta() -> int:
	var n: int = 0
	if _l == null:
		return n
	for c in _l.find_children("*", "PanelContainer", true, false):
		var sc: Script = (c as Node).get_script() as Script
		if sc != null and sc.resource_path.ends_with("rune_palette.gd"):
			(c as Node).queue_free()
			n += 1
	return n


## El registro de la receta: línea 1 el SELLO (el elemento) y hasta 6 líneas con los glifos puestos y su contador. Siempre LINEAS_REGISTRO líneas (las que sobran, vacías).
func registro_lineas() -> PackedStringArray:
	var l: PackedStringArray = []
	l.append("Sello: %s" % (NOMBRE_PRUEBA if VfxEstado3D.plano else NOMBRE_ELEMENTO.get(elemento, elemento)))
	var glifos: PackedStringArray = []
	for nombre in Sigils.GLIFOS_V2:
		if int(contadores.get(nombre, 0)) > 0:
			glifos.append("%s ×%d" % [nombre, int(contadores[nombre])])
	if glifos.is_empty():
		l.append("(sin glifos: esfera base)")
	for i in range(mini(glifos.size(), LINEAS_REGISTRO - 1)):
		l.append(glifos[i])
	if glifos.size() > LINEAS_REGISTRO - 1:
		l[LINEAS_REGISTRO - 1] = "+%d glifos más…" % (glifos.size() - LINEAS_REGISTRO + 2)
	while l.size() < LINEAS_REGISTRO:
		l.append("")
	return l


## Las variables del hechizo que NO valen cero (las que de verdad están en marcha), una por línea: «campo = valor (origen)». Salen del `Hechizo` real (hechizo_actual: elemento +
## glifos + lo tocado), o sea lo que lanzaría Espacio; el origen dice de dónde viene («lab» = lo has tocado tú). Criterio de Juego (diario 177): número ≠ 0, bool verdadero, texto
## no vacío; sin color, eventos ni derivados (se calculan) y sin los semiejes (están a la derecha, siempre). Pablo las usa para pedir «sube esta, baja aquella»: por eso lleva el
## nombre exacto del campo. Con el elemento solo ya salen `copias`, `fuerza_golpe`, `veneno_dps` y `estado_materia`: son sus valores de partida, no ruido de la lista.
func variables_no_cero_lineas() -> PackedStringArray:
	var l: PackedStringArray = []
	for f in tabla_filas():
		var campo: String = String(f["campo"])
		if String(f["grupo"]) == "derivado" or campo == "color" or campo == "eventos" or campo.begins_with("semiejes."):
			continue
		var v: Variant = f["valor"]
		var activo: bool = false
		if v is bool:
			activo = bool(v)
		elif v is int or v is float:
			activo = not is_zero_approx(float(v))
		elif v is String or v is StringName:
			activo = String(v) != ""
		if activo:
			l.append("%s = %s   (%s)" % [campo, ("sí" if bool(v) else "no") if v is bool else _fmt(v), String(f.get("origen", "defecto"))])
	return l


## ELEMENTO DE PRUEBA «agua sin VFX» (Pablo: «no distingo nada en el fuego»): para el juego es AGUA (mismo Hechizo, glifos y reglas: la gota de agua de base) pero el volumen se
## dibuja solo como un elipsoide translúcido, sin llamas, motas ni luces (VfxEstado3D.plano). No es un elemento nuevo de verdad: no toca Sigils ni Hechizo; es un modo de dibujo.
## Cambiar a cualquier elemento real (selector, Tab…) lo apaga. Al cerrar el lab hay que dejarlo en false: es estático y lo vería el resto del juego.
const NOMBRE_PRUEBA: String = "prueba (agua sin VFX)"


func _poner_plano(si: bool) -> void:
	VfxEstado3D.plano = si
	_refrescar_hud()


func poner_elemento(e: String) -> void:
	VfxEstado3D.plano = false
	super.poner_elemento(e)


func _exit_tree() -> void:
	VfxEstado3D.plano = false


func _compacta_activa() -> bool:
	return ui_compacta and pestana == Pestana.RECETA


## Enseña la interfaz que toca: la compacta en F1 (salvo F4) o los paneles de siempre.
func _aplicar_ui() -> void:
	var c: bool = _compacta_activa()
	if _capa_compacta != null:
		_capa_compacta.visible = c
	if _hud != null:
		_hud.visible = not c
	if _caja_glifos != null:
		_caja_glifos.visible = not c
	if _caja_modos != null:
		_caja_modos.visible = not c
	if _tabla_label != null:
		_tabla_label.visible = pestana == Pestana.RECETA and not c
	_refrescar_ui_compacta()


## Las variables que se enseñan a la izquierda, en orden: las fijadas, luego los glifos con contador y luego lo tocado en la tabla (los semiejes, a la derecha, no).
func activas_lista() -> Array:
	var r: Array = activas.duplicate()
	for nombre in Sigils.GLIFOS_V2:
		var clave: String = "glifo:%s" % nombre
		if int(contadores.get(nombre, 0)) > 0 and not r.has(clave):
			r.append(clave)
	for campo in cambios_hechizo:
		var clave2: String = "campo:%s" % campo
		if not String(campo).begins_with("semiejes.") and not r.has(clave2):
			r.append(clave2)
	return r


## Fija una variable en un hueco. Devuelve false (y avisa) si ya están los seis ocupados.
func activar(clave: String) -> bool:
	if activas_lista().has(clave):
		return true
	if activas_lista().size() >= MAX_ACTIVAS:
		_aviso_ui("Sin huecos (%d activas): quita una con ×" % MAX_ACTIVAS)
		return false
	activas.append(clave)
	_refrescar_hud()
	return true


## Quita una variable de los huecos y la devuelve a su valor: sin sobrescritura (campo) o con el contador a 0 (glifo).
func desactivar(clave: String) -> void:
	activas.erase(clave)
	var nombre: String = clave.get_slice(":", 1)
	if clave.begins_with("glifo:"):
		contadores.erase(nombre)
		_refrescar(true)
	else:
		cambios_hechizo.erase(nombre)
	_refrescar_hud()


func _cambiar_clave(clave: String, pasos: int) -> void:
	var nombre: String = clave.get_slice(":", 1)
	if clave.begins_with("glifo:"):
		sumar(nombre, pasos)
	else:
		_cambiar_campo(nombre, pasos)


## Cambia un campo del Hechizo por la misma vía que la tabla de siempre (con su paso, sus topes y el «vuelve a lo que era → quita la sobrescritura»).
func _cambiar_campo(campo: String, pasos: int) -> void:
	var filas: Array = tabla_filas()
	for i in range(filas.size()):
		if String(filas[i]["campo"]) == campo:
			tabla_sel = i
			tabla_cambiar(pasos)
			return


## [nombre, valor en texto, ¿tocado?] de una clave activa.
func _info_clave(clave: String) -> Array:
	var nombre: String = clave.get_slice(":", 1)
	if clave.begins_with("glifo:"):
		return [nombre, "×%d" % int(contadores.get(nombre, 0)), false]
	for f in tabla_filas():
		if String(f["campo"]) == nombre:
			var v: Variant = f["valor"]
			return [nombre, ("sí" if bool(v) else "no") if v is bool else _fmt(v), cambios_hechizo.has(nombre)]
	return [nombre, "?", false]


## ¿Tiene «×» esta variable? Los campos numéricos sí; los glifos, los bool y las listas no.
func _es_multiplicable(clave: String) -> bool:
	if not clave.begins_with("campo:"):
		return false
	var e: Dictionary = Hechizo.EDITABLES.get(clave.get_slice(":", 1), {})
	return not e.is_empty() and not e.has("tipo")


func _aviso_ui(texto: String) -> void:
	if _lbl_aviso != null:
		_lbl_aviso.text = texto
		_t_aviso = 3.0
		if _caja_variables != null:
			_caja_variables.visible = true


func _paso_ui() -> int:
	return 10 if Input.is_key_pressed(KEY_SHIFT) else 1


func _etiqueta_ui(ancho: float) -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(ancho, 0.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _boton_mini(texto: String, accion: Callable) -> Button:
	var b: Button = _boton(texto, accion)
	b.custom_minimum_size = Vector2(22.0, 22.0)
	b.add_theme_font_size_override("font_size", 13)
	return b


## Una fila «nombre  −  valor  +  [÷1,5] [×1,5]  ×». `al_cambiar(pasos: int)` es el cambio ADITIVO (el paso de la variable); `al_mult(n: int)` el MULTIPLICATIVO
## (n = +1 / −1: valor × FACTOR_MULT^n, lo que haría un glifo de modo «multiplica»); sin `al_mult` esos dos botones quedan, transparentes e inertes, para que las columnas alineen.
## Sin `al_quitar` no lleva ×.
func _fila_ui(ancho: float, al_cambiar: Callable, al_quitar: Callable = Callable(), al_mult: Callable = Callable(), con_mult: bool = false) -> Dictionary:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 3)
	var nombre: Label = _etiqueta_ui(ancho)
	caja.add_child(nombre)
	caja.add_child(_boton_mini("−", func() -> void: al_cambiar.call(-_paso_ui())))
	var valor: Label = _etiqueta_ui(54.0)
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(valor)
	caja.add_child(_boton_mini("+", func() -> void: al_cambiar.call(_paso_ui())))
	var mult: Array = []
	if con_mult:
		for par in [["÷%s" % _fmt(FACTOR_MULT), -1], ["×%s" % _fmt(FACTOR_MULT), 1]]:
			var n: int = int(par[1])
			var b: Button = _boton_mini(String(par[0]), func() -> void: al_mult.call(n))
			b.custom_minimum_size = Vector2(40.0, 22.0)
			b.tooltip_text = "Multiplicativo (como un glifo): el valor × %s elevado a %d" % [_fmt(FACTOR_MULT), n]
			caja.add_child(b)
			mult.append(b)
	if al_quitar.is_valid():
		var q: Button = _boton_mini("×", al_quitar)
		q.tooltip_text = "Quitar y devolver a su valor"
		caja.add_child(q)
	return {"caja": caja, "nombre": nombre, "valor": valor, "mult": mult}


func _montar_ui_compacta() -> void:
	_capa_compacta = CanvasLayer.new()
	_capa_compacta.layer = 7
	add_child(_capa_compacta)
	var ayuda: Label = _etiqueta_ui(0.0)
	ayuda.text = "Espacio lanza · Tab elemento · F4 interfaz completa"
	ayuda.modulate = Color(0.85, 0.85, 0.85, 0.8)
	ayuda.anchor_top = 1.0
	ayuda.anchor_bottom = 1.0
	ayuda.offset_left = 10.0
	ayuda.offset_top = -26.0
	_capa_compacta.add_child(ayuda)
	# --- abajo a la izquierda, donde estaba la paleta de pruebas: el registro de la receta (sello + glifos). Siempre 7 líneas: no salta.
	_lbl_registro = _etiqueta_ui(0.0)
	_lbl_registro.anchor_top = 1.0
	_lbl_registro.anchor_bottom = 1.0
	_lbl_registro.offset_left = 10.0
	_lbl_registro.offset_bottom = -32.0
	_lbl_registro.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_capa_compacta.add_child(_lbl_registro)
	# --- derecha, en columna: la caja de los ejes (X, Y, Z siempre + desplegable, elemento, Lanzar) y, DEBAJO, la de las variables añadidas
	var col := VBoxContainer.new()
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.offset_left = -ANCHO_COLUMNA - 10.0
	col.offset_right = -10.0
	col.offset_top = 10.0
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_compacta.add_child(col)
	var der: PanelContainer = _caja_ui()
	col.add_child(der)
	var v := VBoxContainer.new()
	der.add_child(v)
	var titulo: Label = _etiqueta_ui(0.0)
	titulo.text = "semiejes (casillas) · − + paso · ÷ × glifo"
	titulo.modulate = Color(0.85, 0.85, 0.85)
	v.add_child(titulo)
	for e in EJES_UI:
		var campo: String = String(e[1])
		var fe: Dictionary = _fila_ui(60.0, func(p: int) -> void: _cambiar_campo(campo, p), Callable(), func(n: int) -> void: _multiplicar_campo(campo, n), true)
		(fe["nombre"] as Label).text = String(e[0])
		v.add_child(fe["caja"])
		_filas_ejes.append(fe)
	_desplegable = OptionButton.new()
	_desplegable.focus_mode = Control.FOCUS_NONE
	_desplegable.add_theme_font_size_override("font_size", 13)
	_desplegable.add_item("Más variables…")
	_desplegable.add_separator("Glifos")
	for nombre in Sigils.GLIFOS_V2:
		_desplegable.add_item(String(nombre))
		_desplegable.set_item_metadata(_desplegable.item_count - 1, "glifo:%s" % nombre)
	var grupo: String = ""
	for fila in hechizo_base().tabla():
		var campo2: String = String(fila["campo"])
		if not bool(fila["editable"]) or campo2.begins_with("semiejes."):
			continue
		if String(fila["grupo"]) != grupo:
			grupo = String(fila["grupo"])
			_desplegable.add_separator(grupo.capitalize())
		_desplegable.add_item(campo2)
		_desplegable.set_item_metadata(_desplegable.item_count - 1, "campo:%s" % campo2)
	_desplegable.item_selected.connect(_al_elegir_variable)
	v.add_child(_desplegable)
	_selector_compacto = OptionButton.new()
	_selector_compacto.focus_mode = Control.FOCUS_NONE
	_selector_compacto.add_theme_font_size_override("font_size", 13)
	for e in ELEMENTOS:
		_selector_compacto.add_item(String(NOMBRE_ELEMENTO[e]))
	_selector_compacto.add_item(NOMBRE_PRUEBA)          # el último: el elemento de prueba
	_selector_compacto.item_selected.connect(func(i: int) -> void:
		if i < ELEMENTOS.size():
			poner_elemento(String(ELEMENTOS[i]))
		else:
			poner_elemento("water")
			_poner_plano(true))
	v.add_child(_selector_compacto)
	var acciones := HBoxContainer.new()
	v.add_child(acciones)
	acciones.add_child(_boton("Lanzar", func() -> void: lanzar()))
	acciones.add_child(_boton("Limpiar", func() -> void: limpiar_todo()))
	# --- la caja de las variables añadidas: una fila por variable (hasta MAX_ACTIVAS), con el cambio aditivo y el multiplicativo. Solo se ve si hay alguna o un aviso.
	_caja_variables = _caja_ui()
	_caja_variables.visible = false
	col.add_child(_caja_variables)
	var vv := VBoxContainer.new()
	_caja_variables.add_child(vv)
	var tit2: Label = _etiqueta_ui(0.0)
	tit2.text = "variables activas · − + paso · ÷ × glifo"
	tit2.modulate = Color(0.85, 0.85, 0.85)
	vv.add_child(tit2)
	for i in range(MAX_ACTIVAS):
		var f: Dictionary = _fila_ui(96.0, func(p: int) -> void: _cambiar_hueco(i, p), func() -> void: _quitar_hueco(i), func(n: int) -> void: _multiplicar_hueco(i, n), true)
		vv.add_child(f["caja"])
		(f["caja"] as Control).visible = false
		_filas_activas.append(f)
	_lbl_mas = _etiqueta_ui(0.0)
	_lbl_mas.modulate = Color(0.8, 0.8, 0.8)
	vv.add_child(_lbl_mas)
	_lbl_aviso = _etiqueta_ui(0.0)
	_lbl_aviso.add_theme_color_override("font_color", COLOR_TOCADO)
	vv.add_child(_lbl_aviso)


## Una caja translúcida de la columna derecha.
func _caja_ui() -> PanelContainer:
	var p := PanelContainer.new()
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	fondo.set_corner_radius_all(4)
	fondo.set_content_margin_all(6.0)
	p.add_theme_stylebox_override("panel", fondo)
	return p


## Limpiar de la interfaz compacta: glifos, lo tocado en la tabla y lo fijado (la vista vuelve a la esfera base).
func limpiar_todo() -> void:
	activas.clear()
	cambios_hechizo.clear()
	limpiar()
	_refrescar_hud()


func _al_elegir_variable(i: int) -> void:
	var clave: Variant = _desplegable.get_item_metadata(i)
	if clave is String:
		activar(String(clave))
	_desplegable.select(0)


## Multiplicativo: el valor × FACTOR_MULT^n (n < 0 divide), con los topes y el paso de la variable, por la misma vía de sobrescritura que el aditivo (y quitándola si vuelve
## a lo que era). Desde 0 no se puede multiplicar: la primera «×» pone un paso. Los bool y las listas no se multiplican; un glifo no tiene «×» (su contador ya es el factor).
func _multiplicar_campo(campo: String, n: int) -> void:
	var e: Dictionary = Hechizo.EDITABLES.get(campo, {})
	if e.is_empty() or e.has("tipo"):
		return
	var actual: Variant = null
	for f in tabla_filas():
		if String(f["campo"]) == campo:
			actual = f["valor"]
	if actual == null:
		return
	var v: float = float(actual)
	var nuevo: float = float(e["paso"]) if (is_zero_approx(v) and n > 0) else v * pow(FACTOR_MULT, float(n))
	nuevo = snappedf(clampf(nuevo, float(e["min"]), float(e["max"])), float(e["paso"]) * 0.1)
	var valor: Variant = int(roundf(nuevo)) if actual is int else nuevo
	var base: Variant = hechizo_base()._leer(campo)
	if (valor is float and base is float and is_equal_approx(float(valor), float(base))) or valor == base:
		cambios_hechizo.erase(campo)
	else:
		cambios_hechizo[campo] = valor
	_refrescar_hud()


func _multiplicar_hueco(i: int, n: int) -> void:
	var l: Array = activas_lista()
	if i < l.size() and String(l[i]).begins_with("campo:"):
		_multiplicar_campo(String(l[i]).get_slice(":", 1), n)


func _cambiar_hueco(i: int, pasos: int) -> void:
	var l: Array = activas_lista()
	if i < l.size():
		_cambiar_clave(String(l[i]), pasos)


func _quitar_hueco(i: int) -> void:
	var l: Array = activas_lista()
	if i < l.size():
		desactivar(String(l[i]))


func _refrescar_ui_compacta() -> void:
	if _capa_compacta == null or not _capa_compacta.visible:
		return
	var lista: Array = activas_lista()
	for i in range(MAX_ACTIVAS):
		var f: Dictionary = _filas_activas[i]
		(f["caja"] as Control).visible = i < lista.size()
		if i < lista.size():
			var info: Array = _info_clave(String(lista[i]))
			(f["nombre"] as Label).text = String(info[0])
			(f["nombre"] as Label).add_theme_color_override("font_color", COLOR_TOCADO if bool(info[2]) else Color.WHITE)
			(f["valor"] as Label).text = String(info[1])
			var multiplicable: bool = _es_multiplicable(String(lista[i]))
			for b in (f["mult"] as Array):
				(b as Button).disabled = not multiplicable
				(b as Button).modulate = Color(1.0, 1.0, 1.0, 1.0 if multiplicable else 0.0)
	if _caja_variables != null:
		_caja_variables.visible = not lista.is_empty() or _lbl_aviso.text != ""
	_lbl_mas.text = "+%d más: quita alguna con ×" % (lista.size() - MAX_ACTIVAS) if lista.size() > MAX_ACTIVAS else ""
	var semi: Vector3 = hechizo_actual().semiejes
	for i in range(3):
		var fe: Dictionary = _filas_ejes[i]
		(fe["valor"] as Label).text = "%.2f" % [semi.x, semi.y, semi.z][i]
		(fe["nombre"] as Label).add_theme_color_override("font_color", COLOR_TOCADO if cambios_hechizo.has(String(EJES_UI[i][1])) else Color.WHITE)
	if _selector_compacto != null and ELEMENTOS.has(elemento):
		_selector_compacto.select(ELEMENTOS.size() if VfxEstado3D.plano else ELEMENTOS.find(elemento))
	if _lbl_registro != null:
		var vars_: PackedStringArray = variables_no_cero_lineas()
		var txt: PackedStringArray = registro_lineas()
		txt.append("")
		txt.append("Variables ≠ 0:" if not vars_.is_empty() else "Variables ≠ 0: ninguna")
		txt.append_array(vars_)
		_lbl_registro.text = "\n".join(txt)


# ---------------------------------------------------------------------------------------------------------------------
#  Previsualización: lo que se dibuja (aros y casillas) es el hechizo REAL, con lo tocado en la tabla, y lleva su tamaño escrito
# ---------------------------------------------------------------------------------------------------------------------

## Antes los aros salían de la receta (los glifos) y no enseñaban lo tocado en los ejes o en la tabla; ahora salen del `Hechizo` que lanzaría Espacio (`hechizo_actual`), el mismo
## que ve `lanzar_hechizo`: semiejes (también los puestos a mano), barrera (centrado en el jugador) y casillas coinciden con lo que luego sale.
func _geo_previa() -> Dictionary:
	return hechizo_actual().geo()


func _firma_extra() -> String:
	return str(cambios_hechizo)


func _pintar_elipsoide(g: Dictionary, d: Vector3) -> void:
	super._pintar_elipsoide(g, d)
	if _marcas == null or _jug == null:
		return
	if _rotulo == null:
		_rotulo = Label3D.new()
		_rotulo.name = "TamanoHechizo"
		_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_rotulo.no_depth_test = true
		_rotulo.render_priority = 11
		_rotulo.font_size = 28
		_rotulo.outline_size = 8
		_rotulo.pixel_size = 0.012
		_rotulo.modulate = COLOR_ROTULO
		_marcas.add_child(_rotulo)
	var cas: float = Terreno3D.casilla
	var niveles: int = Lanzador3D.GeometriaV2.niveles(g)
	var n_cas: int = Lanzador3D.GeometriaV2.celdas(g, Vector2(_jug.position.x, _jug.position.z), Vector2(d.x, d.z), cas).size()
	var alto: float = float(niveles) * Terreno3D.ALTO_NIVEL
	_rotulo.text = "x %.2f · y %.2f · z %.2f casillas\n%.1f × %.1f × %.1f u · %d nivel(es) · %d casillas" % [
		float(g["x"]), float(g["y"]), float(g["z"]), 2.0 * float(g["x"]) * cas, 2.0 * float(g["z"]) * cas, alto, niveles, n_cas]
	_rotulo.position = _jug.position + Vector3(0.0, alto + 1.4, 0.0)
