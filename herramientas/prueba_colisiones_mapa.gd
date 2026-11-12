extends "res://herramientas/escenario_base.gd"
## COHERENCIA DE COLISIONES DE UN MAPA ENTERO (12/11, Pablo: «las colisiones MUY próximas al tamaño del asset; ni muros invisibles ni colisiones que no
## se sientan coherentes» y «un test para mapas, que no haya que revisarlo playtesteando»). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_colisiones_mapa.gd                 (todos los de MAPAS)
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_colisiones_mapa.gd -- PruebaBosque02 PruebaCueva
##   tools\prueba_una.cmd prueba_colisiones_mapa
##
## Qué hace. Carga la ESCENA de verdad de cada mapa (con su Nivel_*.tscn, tus ediciones incluidas) y recorre todo el suelo con una rejilla de PASO (0,15 u).
## En cada punto compara dos cosas que se calculan por caminos distintos:
##   · «choca»: ¿puede estar ahí la jugadora? La MISMA pregunta que hace `Jugador3D._puede_estar` (Terreno3D.es_parcial / choca_huella / bloqueada).
##   · «se ve»: ¿hay modelo ahí? La planta de TODO lo que se dibuja a la altura del cuerpo (de 0,12 a 1,6 u sobre el suelo): las piezas del nivel (lotes),
##     los objetos reactivos, los NPC y cualquier otra malla visible. Lo que queda por encima (copas, dinteles) o a ras de suelo (losas, césped) no cuenta.
## Y falla en dos casos:
##   1. MURO INVISIBLE: un punto donde se choca y el modelo más cercano está a más de RADIO + HOLGURA (0,25 del cuerpo + 0,15). Dice cuánto sobra.
##   2. SE ATRAVIESA: un punto bien DENTRO (≥ 0,2 u) de un modelo que es sólido según `ColisionPieza.MODO` y en el que no se choca.
## Los fallos salen agrupados por causa (forma de una pieza / casilla entera / muro) y por el asset más cercano, con las casillas donde pasa.
## Además guarda un plano de cada mapa (PNG, 1 píxel = PASO) en user://colisiones_mapa/: gris = modelo, naranja = choca junto a un modelo (bien),
## ROJO = muro invisible, AZUL = se atraviesa, morado = pared de terreno `#` sin modelo cerca. La ruta sale en la consola.
##
## PAREDES DE TERRENO (letra `#` de los mapas de letras: la roca de la cueva, el borde del pantano): bloquean su casilla entera por diseño (detrás no hay nivel) y su
## modelo no siempre la llena. Se miden y se enseñan aparte como AVISO (no suman fallos) mientras PAREDES_FALLAN sea false: ajustarlas es trabajo de arte (que la pieza
## de pared llene su casilla), no de colisión.
##
## FRANJAS ANTI-COLARSE (decisión de Pablo, 12/11: se mantienen): entre un objeto y una casilla vecina bloqueada no se pasa aunque el modelo no llene su casilla
## (`Terreno3D.FuenteSolidez._sellado`: si no, la jugadora se colaría junto a un bloque en un pasillo). Esos puntos chocan sin modelo cerca A PROPÓSITO: se cuentan y
## se enseñan aparte como AVISO (rosa en el plano), no como fallo. Si una franja molesta, se arregla agrandando el asset o moviéndolo, no la colisión.
##
## Qué NO mira: agua, vacío y escalones de terreno (se ven; los decide `Terreno3D.pisable`), ni hechizos/flechas/goblins (van por casillas).

const MAPAS: PackedStringArray = ["PruebaBosque01", "PruebaBosque02", "PruebaCueva", "PruebaCuevaAgua", "PruebaCuevaResonante", "PruebaGrutaBatida",
	"PruebaPantano", "PruebaPatioChaman", "PruebaSalaChaman", "PruebaSalaEmpuje", "PruebaSalaGolem", "PruebaSalaLimo"]

const PASO: float = 0.15                 ## rejilla de muestreo del suelo (u)
const CELDA: float = 0.10                ## casilla fina de la planta de lo que se ve (u)
const RADIO: float = 0.25                ## Terreno3D.FuenteNodos.RADIO_CUERPO: el cuerpo de la jugadora
const HOLGURA: float = 0.15              ## lo que se tolera de más entre el borde del modelo y el punto donde se choca
const DENTRO_CELDAS: int = 2             ## un punto está «bien dentro» de un modelo si lo están todas las casillas finas a 2 de distancia (0,2 u)
const BANDA_MIN: float = 0.12
const BANDA_MAX: float = 1.6
const LADO_MAX_MALLA: float = 16.0       ## una malla suelta más ancha que esto es terreno, agua o cielo: no es un objeto
const GRUPOS_MAX: int = 30               ## líneas FALLO por mapa y tipo; el resto se resume
## 12/11 (Pablo): los arbustos pueden atravesarse (son hojas: se apartan al pasar). No cuentan para SE ATRAVIESA; donde el nivel los marca sólidos siguen chocando con su contorno.
const TRASPASABLES: Array = ["arbusto", "arbusto_flores", "arbusto_otono", "arbusto_bayas", "seto_seco"]
const PUNTOS_MIN: int = 4                ## un grupo con menos puntos que esto (< 0,1 u²: un pico del casco convexo, el redondeo de la rejilla) sale como AVISO, no como FALLO
const PAREDES_FALLAN: bool = false       ## true = el aire entre la cara de una pared `#` y el borde de su casilla también es FALLO
const BUSCAR_MAX: float = 0.8            ## hasta dónde se busca el modelo más cercano para decir cuánto sobra

var _vis: Dictionary = {}                ## Vector2i (casilla fina del mundo) -> true: ahí se ve modelo a la altura del cuerpo
var _macizo: Dictionary = {}             ## Vector2i -> id: bien dentro de un modelo sólido
var _inst: Dictionary = {}               ## Vector2i (casilla del juego) -> Array de [rótulo, Vector3]: para decir «cerca de qué»
var _cache: Dictionary = {}
var _tris_id: Dictionary = {}


func _escenario() -> void:
	var lista: PackedStringArray = OS.get_cmdline_user_args()
	if lista.is_empty():
		lista = MAPAS
	for nombre in lista:
		var ruta: String = "res://escenas/%s.tscn" % String(nombre).trim_suffix(".tscn")
		if not ResourceLoader.exists(ruta):
			_ok("existe %s" % ruta, false)
			continue
		await _mapa(ruta)


func _mapa(ruta: String) -> void:
	print("")
	print("##### %s" % ruta.get_file())
	_vis.clear()
	_macizo.clear()
	_inst.clear()
	_cache.clear()
	await cargar(ruta, true)
	if maqueta == null or jugador == null:
		return
	var n_esp: int = 0
	while n_esp < 120 and not (Terreno3D.fuente is Terreno3D.FuenteNodos):
		await process_frame
		n_esp += 1
	var por_nodos: bool = Terreno3D.fuente is Terreno3D.FuenteNodos
	print("      solidez: %s" % ("por colisión real (FuenteNodos)" if por_nodos else "por casillas + círculos (FuenteCasillas)"))
	var ms: int = Time.get_ticks_msec()
	_planta_lotes()
	var n_mallas: int = _planta_mallas(maqueta)
	print("      planta de lo que se ve: %d casillas finas (%d mallas sueltas) en %d ms" % [_vis.size(), n_mallas, Time.get_ticks_msec() - ms])
	_muestrear(String(maqueta.get("nivel")))
	maqueta.queue_free()
	maqueta = null
	await avanzar(6)


# ---------------------------------------------------------------------------------------------------------------------
#  Lo que se ve
# ---------------------------------------------------------------------------------------------------------------------

## Las piezas del nivel (lotes de la maqueta: id -> transformaciones).
func _planta_lotes() -> void:
	var lotes: Variant = maqueta.get("_lotes")
	if not (lotes is Dictionary):
		return
	for id in (lotes as Dictionary):
		var sid: String = String(id)
		if not _tris_id.has(sid):
			var tris := PackedVector3Array()
			for parte in (maqueta.call("_plantilla", sid) as Array):
				var m: Mesh = (parte as Array)[0] as Mesh
				if m == null:
					continue
				var tp: Transform3D = (parte as Array)[1]
				for v in m.get_faces():
					tris.append(tp * v)
			_tris_id[sid] = tris
		var base: PackedVector3Array = _tris_id[sid]
		if base.is_empty():
			continue
		var modo: String = ColisionPieza.modo(sid)
		for t in ((lotes as Dictionary)[id] as Array):
			var tr: Transform3D = t
			var esc: float = snappedf(tr.basis.get_scale().x, 0.02)
			var c: Vector2i = Terreno3D.celda_de(tr.origin)
			var dy: float = snappedf(tr.origin.y - Terreno3D.y_pies(c), 0.1) if Terreno3D.en_mapa(c) else 0.0
			var clave: String = "%s|%.2f|%.1f" % [sid, esc, dy]
			if not _cache.has(clave):
				_cache[clave] = _huella_pieza(base, esc, dy, modo, sid)
			var h: Dictionary = _cache[clave]
			var giro: Basis = tr.basis.orthonormalized()
			for k in (h["vis"] as Array):
				var p: Vector3 = tr.origin + giro * Vector3(((k as Vector2i).x + 0.5) * CELDA, 0.0, ((k as Vector2i).y + 0.5) * CELDA)
				_vis[_fina(p)] = true
			for k in (h["macizo"] as Array):
				var p2: Vector3 = tr.origin + giro * Vector3(((k as Vector2i).x + 0.5) * CELDA, 0.0, ((k as Vector2i).y + 0.5) * CELDA)
				_macizo[_fina(p2)] = sid
			_apuntar(sid, tr.origin)


## Planta de una pieza a escala `esc` y con la base a `dy` del suelo: {"vis": casillas con modelo en la franja del cuerpo, "macizo": las de bien dentro si es sólida}.
func _huella_pieza(base: PackedVector3Array, esc: float, dy: float, modo: String, sid: String = "") -> Dictionary:
	var tris := PackedVector3Array()
	var ymax: float = -INF
	for v in base:
		tris.append(v * esc)
		ymax = maxf(ymax, v.y)                     # el alto SIN la escala de la instancia: es el que decide si la pieza lleva cuerpo (ColisionPieza.cascos)
	var vis: Dictionary = _rellenar(_cubiertas(tris, BANDA_MIN - dy, BANDA_MAX - dy))
	var macizo: Array = []
	if modo != "ninguna" and not TRASPASABLES.has(sid) and ymax > ColisionPieza.ALTO_MIN_SOLIDO + ColisionPieza.ALTO_TOLERANCIA and absf(dy) < 0.3:
		var cuerpo: Dictionary = vis
		if modo == "tronco" or modo == "tronco_bajo":
			# los árboles solo son sólidos por el tronco: la franja que elige ColisionPieza (la de planta central más estrecha)
			var mejor: int = 1 << 30
			cuerpo = {}
			for banda in (ColisionPieza.TRONCO_BANDAS_BAJO if modo == "tronco_bajo" else ColisionPieza.TRONCO_BANDAS):
				var cub: Dictionary = _cubiertas(tris, float(banda[0]) * esc, float(banda[1]) * esc)
				var eje: Array = ColisionPieza._solo_eje(ColisionPieza._componentes(cub))
				if eje.is_empty():
					continue
				var solo: Dictionary = {}
				for k in (eje[0] as Array):
					solo[k] = true
				solo = _rellenar(solo)
				if solo.size() >= 2 and solo.size() < mejor:
					mejor = solo.size()
					cuerpo = solo
		for k in cuerpo:
			var dentro: bool = true
			for dz in range(-DENTRO_CELDAS, DENTRO_CELDAS + 1):
				for dx in range(-DENTRO_CELDAS, DENTRO_CELDAS + 1):
					if not cuerpo.has((k as Vector2i) + Vector2i(dx, dz)):
						dentro = false
						break
				if not dentro:
					break
			if dentro:
				macizo.append(k)
	return {"vis": vis.keys(), "macizo": macizo}


## Todo lo demás que se dibuja como malla suelta (reactivos, NPC, puertas, cofres, terreno elevado…). Devuelve cuántas cuentan.
func _planta_mallas(n: Node) -> int:
	if n == jugador or n == jugador.get("pj"):
		return 0
	if n is Pj3D and not (maqueta.get("_npcs_contorno") as Array).has(n):
		return 0                                   # enemigos y mascotas: se mueven, no son decorado
	var cuenta: int = 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).is_visible_in_tree():
		var mi: MeshInstance3D = n as MeshInstance3D
		var gt: Transform3D = mi.global_transform
		var caja: AABB = gt * mi.mesh.get_aabb()
		var c: Vector2i = Terreno3D.celda_de(caja.get_center())
		if Terreno3D.en_mapa(c) and caja.size.x <= LADO_MAX_MALLA and caja.size.z <= LADO_MAX_MALLA:
			# en una casilla bloqueada que el terreno eleva (la terraza de una cascada: `y_pies` es su tapa) el cuerpo de quien choca está abajo, a ras del suelo normal
			var suelo: float = minf(Terreno3D.y_pies(c), Terreno3D.alto_suelo) if Terreno3D.bloqueada(c) else Terreno3D.y_pies(c)
			if caja.position.y + caja.size.y > suelo + BANDA_MIN and caja.position.y < suelo + BANDA_MAX:
				var tris := PackedVector3Array()
				for v in mi.mesh.get_faces():
					tris.append(gt * v)
				var h: Dictionary = _rellenar(_cubiertas(tris, suelo + BANDA_MIN, suelo + BANDA_MAX))
				for k in h:
					_vis[k] = true
				if not h.is_empty():
					cuenta += 1
					var rotulo: String = String(mi.name)
					var padre: Node = mi.get_parent()
					while padre != null and padre != maqueta:
						if padre is Reactivo3D:
							rotulo = "reactivo:" + String((padre as Reactivo3D).tipo)
							break
						if padre.get_script() != null and (padre.get_script() as Script).get_global_name() != &"":
							rotulo = String((padre.get_script() as Script).get_global_name())
						padre = padre.get_parent()
					_apuntar(rotulo, caja.get_center())
	for h2 in n.get_children():
		cuenta += _planta_mallas(h2)
	return cuenta


func _apuntar(rotulo: String, p: Vector3) -> void:
	var c: Vector2i = Terreno3D.celda_de(p)
	if not _inst.has(c):
		_inst[c] = []
	(_inst[c] as Array).append([rotulo, p])


func _fina(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CELDA)), int(floor(p.z / CELDA)))


## Casillas finas que cubren los triángulos recortados a y ∈ [y0, y1] (en el espacio en que vengan los triángulos).
func _cubiertas(tris: PackedVector3Array, y0: float, y1: float) -> Dictionary:
	var res: Dictionary = {}
	var rec: PackedVector3Array = ColisionPieza._recortar(tris, y0, y1)
	var i: int = 0
	while i + 2 < rec.size():
		var a: Vector3 = rec[i]
		var b: Vector3 = rec[i + 1]
		var c: Vector3 = rec[i + 2]
		i += 3
		var lado: float = maxf(maxf(Vector2(a.x - b.x, a.z - b.z).length(), Vector2(b.x - c.x, b.z - c.z).length()), Vector2(c.x - a.x, c.z - a.z).length())
		var n: int = clampi(int(ceil(lado / (CELDA * 0.5))), 1, 80)
		for u in range(n + 1):
			for v in range(n + 1 - u):
				res[_fina(a + (b - a) * (float(u) / n) + (c - a) * (float(v) / n))] = true
	return res


## Añade el interior: las mallas son cáscaras (un tronco es un anillo en la planta). Interior = lo que no se alcanza desde fuera sin cruzar la cáscara
## (engordada una casilla, para que un poro de la malla no cuente como entrada). El hueco de un arco o de una U SÍ se alcanza desde fuera: queda libre.
func _rellenar(cub: Dictionary) -> Dictionary:
	if cub.is_empty():
		return cub
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for k in cub:
		lo = lo.min(k)
		hi = hi.max(k)
	lo -= Vector2i(3, 3)
	hi += Vector2i(3, 3)
	var gorda: Dictionary = {}
	for k in cub:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				gorda[(k as Vector2i) + Vector2i(dx, dz)] = true
	var fuera: Dictionary = {lo: true}
	var pila: Array = [lo]
	while not pila.is_empty():
		var c: Vector2i = pila.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + d
			if v.x < lo.x or v.y < lo.y or v.x > hi.x or v.y > hi.y or fuera.has(v) or gorda.has(v):
				continue
			fuera[v] = true
			pila.append(v)
	var res: Dictionary = cub.duplicate()
	for z in range(lo.y + 1, hi.y):
		for x in range(lo.x + 1, hi.x):
			var k2 := Vector2i(x, z)
			if res.has(k2) or fuera.has(k2):
				continue
			# dentro de la cáscara engordada: es interior si ninguna vecina es «fuera» (deshace el engorde por el lado de fuera)
			var borde: bool = false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if fuera.has(k2 + Vector2i(dx, dz)):
						borde = true
			if not borde:
				res[k2] = true
	return res


# ---------------------------------------------------------------------------------------------------------------------
#  Dónde se choca
# ---------------------------------------------------------------------------------------------------------------------

## 0 = se puede estar; 1 = choca con una FORMA (casilla parcial); 2 = casilla bloqueada ENTERA. Lo mismo que decide Jugador3D._puede_estar.
func _choca(p: Vector3, c: Vector2i) -> int:
	if Terreno3D.es_parcial(c, true):
		return 1 if Terreno3D.choca_huella(c, p) else 0
	return 2 if Terreno3D.bloqueada(c) else 0


## Distancia (u) del punto al modelo más cercano, buscando hasta `tope`. INF si no hay ninguno.
func _dist_modelo(p: Vector3, tope: float, basta: float) -> float:
	var k0: Vector2i = _fina(p)
	var r: int = int(ceil(tope / CELDA))
	var mejor: float = INF
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var k := k0 + Vector2i(dx, dz)
			if _vis.has(k):
				var d: float = Vector2((k.x + 0.5) * CELDA - p.x, (k.y + 0.5) * CELDA - p.z).length()
				if d < mejor:
					mejor = d
					if mejor <= basta:
						return mejor
	return mejor


func _cerca_de(p: Vector3) -> String:
	var c: Vector2i = Terreno3D.celda_de(p)
	var mejor: String = "nada"
	var d_mejor: float = Terreno3D.casilla * 1.5
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for e in (_inst.get(c + Vector2i(dx, dz), []) as Array):
				var o: Vector3 = (e as Array)[1]
				var d: float = Vector2(o.x - p.x, o.z - p.z).length()
				if d < d_mejor:
					d_mejor = d
					mejor = String((e as Array)[0])
	return mejor


func _muestrear(nivel: String) -> void:
	var lim: Rect2i = maqueta.call("limites")
	var cas: float = Terreno3D.casilla
	var nx: int = int(ceil(lim.size.x * cas / PASO))
	var nz: int = int(ceil(lim.size.y * cas / PASO))
	var img: Image = Image.create(nx, nz, false, Image.FORMAT_RGB8)
	var muros: Dictionary = maqueta.get("_celdas_muro")
	var grupos_inv: Dictionary = {}
	var fallos_antes: int = _fallos
	var lava: Dictionary = {}
	for n in get_nodes_in_group("lava3d"):
		for cl in (n.get("celdas") as Array):
			if bool(n.call("es_lava", cl)):
				lava[cl] = true
	var grupos_hue: Dictionary = {}
	var grupos_pared: Dictionary = {}
	var grupos_franja: Dictionary = {}
	var n_franja: int = 0
	var n_pared: int = 0
	var n_suelo: int = 0
	var n_choca: int = 0
	var n_inv: int = 0
	var n_hue: int = 0
	var ms: int = Time.get_ticks_msec()
	for iz in range(nz):
		for ix in range(nx):
			var p := Vector3((ix + 0.5) * PASO, 0.0, (iz + 0.5) * PASO)
			var c: Vector2i = Terreno3D.celda_de(p) + lim.position
			if not Terreno3D.en_mapa(c) or Terreno3D.es_vacio(c):
				img.set_pixel(ix, iz, Color(0.0, 0.0, 0.0))
				continue
			if Terreno3D.letra_de(c) == "~" and not Terreno3D.hielo_fisico(c):
				img.set_pixel(ix, iz, Color(0.08, 0.14, 0.25))
				continue
			if lava.has(c):
				img.set_pixel(ix, iz, Color(0.35, 0.1, 0.02))      # lava: se ve (una lámina a ras de suelo) y no se pisa, como el agua
				continue
			n_suelo += 1
			var hay: bool = _vis.has(_fina(p))
			var st: int = _choca(p, c)
			if st == 0:
				if _macizo.has(_fina(p)):
					n_hue += 1
					img.set_pixel(ix, iz, Color(0.1, 0.35, 1.0))
					_sumar(grupos_hue, "%s" % String(_macizo[_fina(p)]), c, 0.0)
				else:
					img.set_pixel(ix, iz, Color(0.55, 0.55, 0.55) if hay else Color(0.2, 0.24, 0.2))
				continue
			n_choca += 1
			var d: float = _dist_modelo(p, RADIO + HOLGURA, RADIO + HOLGURA)
			if d <= RADIO + HOLGURA:
				img.set_pixel(ix, iz, Color(0.75, 0.75, 0.75) if hay else Color(0.95, 0.6, 0.15))
				continue
			d = _dist_modelo(p, BUSCAR_MAX, RADIO + HOLGURA)
			if st == 2 and Terreno3D.letra_de(c) == "#" and not PAREDES_FALLAN:
				n_pared += 1
				img.set_pixel(ix, iz, Color(0.6, 0.1, 0.45))
				_sumar(grupos_pared, _cerca_de(p), c, (minf(d, BUSCAR_MAX) - RADIO))
				continue
			if st == 1 and Terreno3D.fuente != null and Terreno3D.fuente.solo_sellado(c, p):
				n_franja += 1
				img.set_pixel(ix, iz, Color(1.0, 0.55, 0.75))
				_sumar(grupos_franja, _cerca_de(p), c, (minf(d, BUSCAR_MAX) - RADIO))
				continue
			n_inv += 1
			img.set_pixel(ix, iz, Color(1.0, 0.05, 0.05))
			var causa: String = "forma"
			if st == 2:
				causa = "muro (casilla entera)" if muros.has(c) else "casilla entera «%s»" % Terreno3D.letra_de(c)
			_sumar(grupos_inv, "%s · junto a %s" % [causa, _cerca_de(p)], c, (minf(d, BUSCAR_MAX) - RADIO))
	print("      %d puntos de suelo · %d chocan · %d muro invisible · %d se atraviesa  (%d ms)" % [n_suelo, n_choca, n_inv, n_hue, Time.get_ticks_msec() - ms])
	_volcar(nivel, "MURO INVISIBLE", grupos_inv, "sobra hasta")
	if n_franja > 0:
		var cf: Array = grupos_franja.keys()
		cf.sort_custom(func(a, b): return int(grupos_franja[a]["n"]) > int(grupos_franja[b]["n"]))
		var tf: String = ""
		for i in range(mini(6, cf.size())):
			tf += "%s %d · " % [cf[i], int(grupos_franja[cf[i]]["n"])]
		_aviso("%s FRANJAS ANTI-COLARSE: %d puntos (%.1f u²) junto a objetos pegados a algo bloqueado (rosa en el plano)" % [nivel, n_franja, n_franja * PASO * PASO], tf)
	if n_pared > 0:
		var claves: Array = grupos_pared.keys()
		claves.sort_custom(func(a, b): return int(grupos_pared[a]["n"]) > int(grupos_pared[b]["n"]))
		var texto: String = ""
		for i in range(mini(5, claves.size())):
			texto += "%s %d (hasta %.2f u) · " % [claves[i], int(grupos_pared[claves[i]]["n"]), float(grupos_pared[claves[i]]["sobra"])]
		_aviso("%s PAREDES `#`: %d puntos (%.1f u²) de casilla de pared sin modelo cerca (morado en el plano)" % [nivel, n_pared, n_pared * PASO * PASO], texto)
	_volcar(nivel, "SE ATRAVIESA", grupos_hue, "")
	if _fallos == fallos_antes:
		_ok("%s: se choca donde hay modelo y solo ahí (%d puntos que chocan)" % [nivel, n_choca], true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://colisiones_mapa"))
	var ruta_png: String = "user://colisiones_mapa/%s.png" % nivel
	img.save_png(ruta_png)
	print("      plano: %s" % ProjectSettings.globalize_path(ruta_png))


func _sumar(grupos: Dictionary, clave: String, c: Vector2i, sobra: float) -> void:
	if not grupos.has(clave):
		grupos[clave] = {"n": 0, "sobra": 0.0, "celdas": {}}
	var g: Dictionary = grupos[clave]
	g["n"] = int(g["n"]) + 1
	g["sobra"] = maxf(float(g["sobra"]), sobra)
	(g["celdas"] as Dictionary)[c] = int((g["celdas"] as Dictionary).get(c, 0)) + 1


func _volcar(nivel: String, tipo: String, grupos: Dictionary, texto_sobra: String) -> void:
	var claves: Array = grupos.keys()
	claves.sort_custom(func(a, b): return int(grupos[a]["n"]) > int(grupos[b]["n"]))
	var resto: int = 0
	for i in range(claves.size()):
		var g: Dictionary = grupos[claves[i]]
		if i >= GRUPOS_MAX:
			resto += int(g["n"])
			continue
		var celdas: Array = (g["celdas"] as Dictionary).keys()
		celdas.sort_custom(func(a, b): return int(g["celdas"][a]) > int(g["celdas"][b]))
		var donde: String = ""
		for j in range(mini(6, celdas.size())):
			donde += "(%d,%d) " % [(celdas[j] as Vector2i).x, (celdas[j] as Vector2i).y]
		if celdas.size() > 6:
			donde += "… y %d casillas más" % (celdas.size() - 6)
		var sobra: String = (" · %s %.2f u del modelo" % [texto_sobra, float(g["sobra"])]) if texto_sobra != "" else ""
		var linea: String = "%s %s: %s · %d puntos (%.2f u²)%s · casillas %s" % [nivel, tipo, claves[i], int(g["n"]), int(g["n"]) * PASO * PASO, sobra, donde]
		if int(g["n"]) < PUNTOS_MIN:
			_aviso(linea)
		else:
			_ok(linea, false)
	if resto > 0:
		_ok("%s %s: y %d puntos más en otros %d grupos" % [nivel, tipo, resto, claves.size() - GRUPOS_MAX], false)
