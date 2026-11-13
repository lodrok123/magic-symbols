class_name Limo3D
extends Combate3D

## E1 · LIMO ELEMENTAL (docs/PROPUESTA_COMBATE.md §4 y §7; reglas de Pablo del 28/10). Dueño: Juego.
##
## Pregunta que plantea: «¿con qué le doy?». Las reglas:
##   · PERSIGUE a la jugadora a brincos y, cerca, se agacha y le salta encima (la ACOMETIDA): 15 de daño y un retroceso leve. Antes de saltar marca en el suelo dónde va a caer
##     (C3, `AvisoAtaque3D`), y rodar en la ventana de ese aviso da el tiempo bruja (C4).
##   · Sin elemento, SE TIÑE del primero que le llega: un hechizo, o una casilla con elemento por la que pasa (la llama o el agua de un hechizo que sigue en el suelo, la casilla
##     mojada, helada o electrificada, un brasero o una fogata que tocan). Teñirse lo absorbe: ese golpe no le hace daño.
##   · Teñido, si le llega OTRA VEZ su elemento pasa a GRANDE: salta un 30 % más (alcance y altura) y hace el doble de daño (30).
##   · Grande, su elemento ya SOLO LO CURA (lo que le iba a hacer de daño, como mínimo CURA_MIN; quieto sobre su elemento, CURA_SUELO por segundo).
##   · Los demás elementos le hacen lo de siempre (la tabla de `Combate3D`: daño, estados, empuje); el golpe cuerpo a cuerpo (F) y el agua honda también.
##   · D3 (6/11/2026, decidido el 27/10): el FUEGO lo DIVIDE (teñido de otro elemento: normal → dos pequeños, grande → dos normales, cada uno con la mitad de la vida y el mismo elemento;
##     un pequeño con fuego MUERE; si no hay dos casillas libres alrededor no se divide y el golpe es el de siempre). El HIELO lo vuelve un BLOQUE EMPUJABLE T_BLOQUE s (teñido de otro
##     elemento): se empuja con viento o con F, resbala, pisa placas y, si cae al agua honda, se hunde; al acabar el tiempo vuelve a ser limo con la vida que tuviera.
##     Su acometida lleva su elemento a la jugadora (`_elemento_a_la_jugadora`).
##
## Cómo está hecho: es un `Combate3D` (vida, barra, estados, empujes, hundirse, tinta por reacción, previsión A2/A3, el vigía de los puzles: todo eso se hereda) SIN modelo Pj3D: su
## cuerpo es un `LimoVisual3D` (la gelatina hecha por código), hermano suyo en el mundo. Se sustituyen la IA, la decisión del golpe para su elemento (`decidir_golpe`, así la previsión
## del indicador dice «Tiñe», «¡Crece!» o «Cura» antes de lanzar) y la muerte. Se pone desde un mapa con la pieza `limo` de Puzle3D o con `Limo3D.crear`.

signal tenido(elemento: String)
signal crecio(tamano: float)
signal curado(cantidad: float)
signal dividido(hijos: Array)                 ## D3: se partió; los limos que dejó

const ELEMENTOS: PackedStringArray = ["fuego", "agua", "hielo", "rayo", "tierra", "viento"]
const VIDA: float = 30.0                    ## 29/10 (DANO_Y_TINTA): 60 → 30
const DANO: float = 15.0
const MULT_DANO_GRANDE: float = 2.0
const MULT_SALTO_GRANDE: float = 1.3          ## el grande salta un 30 % más lejos y más alto (brinco y acometida)
const RADIO_VER: float = 6.9                  ## u (3 casillas): la ve si está a esto y con línea libre
const RADIO_PERDER: float = 11.5              ## u: ya persiguiendo, la pierde más allá
const BRINCO_CASILLAS: float = 0.8            ## lo que avanza cada brinco al perseguir
const PAUSA_BRINCO: float = 0.25              ## s quieto entre dos brincos
const ACOMETIDA_CASILLAS: float = 1.4         ## hasta dónde llega la acometida
const T_AVISO_ACOMETIDA: float = 0.6          ## s agachado antes de la acometida: es su aviso (C3). El golpe cae al aterrizar: + LimoVisual3D.T_AIRE
const DESCANSO_ACOMETIDA: float = 1.3         ## s tras la acometida antes de volver a moverse
const RADIO_GOLPE: float = 0.85               ## u alrededor de donde aterriza (× el tamaño: el grande cubre más)
const EMPUJE_GOLPE: float = 3.0               ## el retroceso leve (u/s iniciales de `Jugador3D.push`; un goblin la empuja con 4,5)
const CURA_MIN: float = 15.0
const CURA_SUELO: float = 6.0                 ## vida/s quieto sobre su elemento, ya grande
const INTERVALO_SUELO: float = 0.25           ## s entre dos miradas a la casilla
const GRACIA_SUELO: float = 1.0               ## s tras absorber en que el suelo no lo hace crecer: la llama que deja la misma flecha al pararse es la MISMA aplicación, no otra
const ORO_LIMO: int = 5
## --- D3 (6/11/2026): dividirse con fuego, bloque con hielo, el elemento en el ataque ---
const DIVIDE_CON: String = "fuego"            ## el elemento que lo parte en dos (si no es el suyo)
const BLOQUE_CON: String = "hielo"            ## el elemento que lo congela en un bloque empujable (si no es el suyo)
const ESCALA_PEQUENO: float = 0.6             ## escala del limo pequeño (= LimoVisual3D.TAMANO_PEQUENO)
const FRACCION_VIDA_HIJO: float = 0.5         ## cada hijo nace con esta fracción de la vida (máxima y actual) del que se divide
const MULT_DANO_PEQUENO: float = 0.5          ## el pequeño pega la mitad (dos pequeños no deben pegar el doble que uno normal)
const MASA_PEQUENO: float = 0.3
const N_HIJOS: int = 2
const T_BLOQUE: float = 8.0                   ## s que dura congelado en bloque antes de volver a ser limo
const T_ESPERA_BLOQUE_MAX: float = 3.0        ## s extra que se espera a que un bloque aún en marcha se pare para deshacerlo (así reaparece en el centro de una casilla)
const ESTADO_ATAQUE_S: float = 3.0            ## s del estado que su acometida aplica si la jugadora admite estados (`aplicar_estado`)

var elemento: String = ""                     ## con qué está teñido («» = sin teñir)
var grande: bool = false
var pequeno: bool = false                     ## D3: nacido de una división (escala 0,6)
var en_bloque: bool = false                   ## D3: congelado en un `BloqueLimo` (T_BLOQUE s)
var bloque: BloqueLimo = null
var t_bloque: float = 0.0                     ## s que le quedan de bloque
var divisiones: int = 0                       ## veces que se ha dividido (pruebas)
var se_dividio: bool = false                  ## desapareció al dividirse (no murió: sin botín ni «enemigo muerto»)
var hijos: Array = []                         ## los limos que dejó al dividirse
var efecto_ataque: String = ""                ## cómo llevó su elemento a la jugadora la última vez: «estado» | «suelo» | «» (pruebas)
var cuerpo: LimoVisual3D = null
var golpes_dados: int = 0                     ## acometidas que le dieron (pruebas)
var acometidas: int = 0                       ## acometidas empezadas (pruebas)
var absorciones: Array = []                   ## [{accion: tine|crece|cura, elemento, origen: hechizo|suelo|pulso, cura}] (pruebas y diario)
var muerte_el: String = ""                    ## tarea E3: el elemento del golpe que lo mató, si fue uno de VARIANTES_MUERTE (pruebas)
var muerte_tinte: Color = Color(0, 0, 0, 0)   ## ... y el tinte que se le puso al cuerpo (alfa 0 = ninguno)
var _accion: String = ""                      ## "" | "brinco" | "acometida"
var _t_accion: float = 0.0
var _golpe_hecho: bool = false
var _punto_golpe: Vector3 = Vector3.ZERO
var _t_suelo: float = 0.0
var _en_su_elemento: bool = false            ## la última mirada a la casilla la encontró de SU elemento (crecer pide salir y volver a entrar)
var _cura_suelo_acum: float = 0.0
var _t_gracia: float = 0.0


## Crea un limo en `pos` y lo cuelga de `p_mundo`. `p_elemento` = ya teñido; `p_grande` = ya grande (solo si está teñido).
static func crear(p_mundo: Node3D, pos: Vector3, p_elemento: String = "", p_grande: bool = false, p_pequeno: bool = false) -> Limo3D:
	var l := Limo3D.new()
	l.mundo = p_mundo
	l.position = pos
	l.casa = pos
	l.elemento = p_elemento if ELEMENTOS.has(p_elemento) else ""
	l.grande = p_grande and l.elemento != ""
	l.pequeno = p_pequeno and not l.grande
	p_mundo.add_child(l, true)
	return l


func _init() -> void:
	inmune_estados = ["veneno"]               # F4: no tiene carne que envenenar


func _ready() -> void:
	add_to_group("combate3d")
	add_to_group("goblins")
	collision_layer = Lanzador3D.CAPA_REACTIVO
	collision_mask = 0
	monitoring = false
	monitorable = true
	debil = ""
	resiste = ""
	oro = ORO_LIMO
	tabla_botin = "limo"
	vida_max = VIDA
	masa = 1.2 if grande else (MASA_PEQUENO if pequeno else 0.6)             # tarea P: ligero; el grande pesa el doble
	defensa = Dano.DEF_LIMO                  # 29/10 (DANO_Y_TINTA): 0
	health = VIDA
	tinte = Color.WHITE
	snd_alerta = ""
	snd_muere = "limo_muere"                 # 29/10 (gamefeel lote 4): chapoteo largo al reventar; antes no sonaba
	snd_golpe = "limo_golpe"
	snd_paso = ""                            # 2/11 (tarea R): el limo repta, sin pisadas
	cuerpo = LimoVisual3D.new()
	cuerpo.name = String(name) + "_cuerpo"
	mundo.add_child(cuerpo)
	cuerpo.position = position
	if elemento != "":
		cuerpo.cargar(elemento)
	if grande or pequeno:
		cuerpo.tamano = _tam()
	altura = _alto()
	var forma := CapsuleShape3D.new()
	forma.radius = _radio_limo()
	forma.height = maxf(altura, 0.7)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.position = Vector3(0, forma.height * 0.5, 0)
	add_child(cs)
	_col = cs
	_vida_mostrada = 1.0
	_ultima_celda_ok()
	_buscar_jugador()
	_construir_barra()
	_rotular()


func _exit_tree() -> void:
	# Lo quitan de la escena sin morir (el vigía de una sala ya limpia, cambio de nivel): el cuerpo se va con él. Muriendo, el cuerpo acaba su animación y se borra solo.
	if bloque != null and is_instance_valid(bloque):
		bloque.deshacer()                                    # D3: su bloque no se queda solo en el mundo
	if not muerto and cuerpo != null and is_instance_valid(cuerpo):
		cuerpo.queue_free()


func _buscar_jugador() -> void:
	if not is_inside_tree():
		return
	for grupo in ["spellcaster", "player"]:
		var l: Node = get_tree().get_first_node_in_group(grupo)
		if l != null and l.get("jugador") is Jugador3D:
			jugador = l.get("jugador") as Jugador3D
			lanz = l as Lanzador3D if l is Lanzador3D else jugador.lanz
			return


## La escala de su cuerpo: pequeño 0,6 · normal 1 · grande 1,6.
func _tam() -> float:
	return LimoVisual3D.TAMANO_GRANDE if grande else (ESCALA_PEQUENO if pequeno else LimoVisual3D.TAMANO_NORMAL)


func _alto() -> float:
	return LimoVisual3D.ALTO * _tam()


func _radio_limo() -> float:
	return 0.45 * _tam()


func _mult_salto() -> float:
	return MULT_SALTO_GRANDE if grande else 1.0


## El daño de su acometida: 15, el doble de grande, la mitad de pequeño.
func dano_golpe() -> float:
	return DANO * (MULT_DANO_GRANDE if grande else (MULT_DANO_PEQUENO if pequeno else 1.0))


## u de su acometida (el grande, un 30 % más).
func alcance_acometida() -> float:
	return ACOMETIDA_CASILLAS * Terreno3D.casilla * _mult_salto()


func radio_golpe() -> float:
	return RADIO_GOLPE * (LimoVisual3D.TAMANO_GRANDE if grande else LimoVisual3D.TAMANO_NORMAL)    # el pequeño cubre como el normal: su tamaño no encoge el aviso


## =====================================================================================================
##  El elemento: teñirse, crecer, curarse
## =====================================================================================================

## Qué le hace a ESTE limo que le llegue `el`: «tine» (sin teñir), «crece» (su elemento, aún pequeño o normal), «cura» (su elemento, ya grande), D3: «divide» (fuego y no es de fuego, con
## sitio alrededor), «muere» (fuego sobre un pequeño que no es de fuego: no puede partirse más), «bloque» (hielo y no es de hielo) o «» (lo de siempre: la tabla de `Combate3D`).
## Fallo que evita lo de «sin sitio»: dividirse sin casillas libres dejaría a los hijos dentro de una pared; entonces el fuego le hace su daño normal.
func accion_elemento(el: String) -> String:
	if not ELEMENTOS.has(el) or en_bloque:
		return ""
	if elemento == "":
		return "tine"
	if el != elemento:
		if el == DIVIDE_CON:
			if pequeno:
				return "muere"
			return "divide" if _celdas_para_hijos().size() >= N_HIJOS else ""
		if el == BLOQUE_CON and _puede_ser_bloque():
			return "bloque"
		return ""
	return "cura" if grande else "crece"


## A2: con su elemento (o sin teñir) no hay daño, ni estado, ni empuje: se absorbe. `absorbe` dice cómo (la previsión lo pinta). El resto, la tabla de siempre.
## D3: «divide» y «bloque» tampoco hacen daño (la transformación ES el golpe); «muere» le quita toda la vida.
func decidir_golpe(hechizo: Hechizo) -> Dictionary:
	var r: Dictionary = super(hechizo)
	var acc: String = accion_elemento(hechizo.elemento)
	if acc == "":
		return r
	if acc == "muere":
		r["dano"] = maxf(float(r["dano"]), health)
		return r
	r["curado"] = true
	if acc == "tine" or acc == "crece" or acc == "cura":
		r["absorbe"] = acc
	r["mult"] = 1.0
	r["base"] = 0.0
	r["dano"] = 0.0
	r["mojado"] = mojado
	r["quemando"] = quemando
	r["congelado"] = congelado
	r["lento"] = -1.0
	r["interrumpe"] = -1.0
	r["vapor"] = false
	r["arco"] = false
	r["avisos"] = []
	r["aturde"] = false
	r["veneno"] = false
	return r


func golpe(hechizo: Hechizo, direccion: Vector3) -> void:
	if muerto or hechizo == null or en_bloque:
		return
	var acc: String = accion_elemento(hechizo.elemento)
	match acc:
		"":
			super(hechizo, direccion)
		"divide":
			dividirse("hechizo")
		"bloque":
			congelar_en_bloque()
		"muere":
			_num_golpe = true                                   # que la muerte sepa que fue el fuego (carbón y sonido, `_elemento_letal`)
			_num_elemento = hechizo.elemento
			receive_damage(health + 1.0)
			_num_golpe = false
			PlayLog.event("limo_muere_fuego", {"pequeno": pequeno, "elemento": elemento})
		_:
			absorber(hechizo.elemento, acc, maxf(hechizo.dano, CURA_MIN), "hechizo")


## D3: la previsión (A2/A3) pinta «Se divide», «¡Bloque!» o «Muere» por `reacciones_propias`, como el gólem; `PrevisionHechizo` no cambia. Los demás (tine, crece, cura) siguen por `absorbe`.
func prever_golpe(hechizo: Hechizo, dir: Vector3, empuje_previo: Dictionary = {}) -> Dictionary:
	var r: Dictionary = super(hechizo, dir, empuje_previo)
	r["reacciones_propias"] = []
	if muerto or hechizo == null:
		return r
	match accion_elemento(hechizo.elemento):
		"divide":
			r["reacciones_propias"] = ["divide"]
		"bloque":
			r["reacciones_propias"] = ["bloque"]
		"muere":
			r["reacciones_propias"] = ["muere"]
	return r


## Aplica una absorción. `cura` = la vida que da si `acc` es «cura».
func absorber(el: String, acc: String, cura: float = CURA_MIN, origen: String = "hechizo") -> void:
	if muerto:
		return
	var col: Color = Pulso3D.color_de(el)
	var curada: float = 0.0
	match acc:
		"tine":
			elemento = el
			cuerpo.cargar(el)
			texto("¡Absorbe!", col, 0.1)
			_en_su_elemento = _elemento_del_suelo() == el      # teñirse sobre su elemento no lo hace crecer en el acto: tiene que salir y volver a entrar
			tenido.emit(el)
		"crece":
			if pequeno:
				pequeno = false                                 # D3: un pequeño que recibe su elemento sube un escalón (pequeño → normal)
				masa = 0.6
			else:
				grande = true
				masa = 1.2                                      # tarea P: crece, pesa el doble
			cuerpo.cargar(el)                                   # el mismo elemento otra vez: LimoVisual3D crece un escalón
			_al_crecer()
			texto_grande("¡Crece!", col, 0.25)
			crecio.emit(cuerpo.tamano)
		"cura":
			var antes: float = health
			health = minf(vida_max, health + cura)
			curada = health - antes
			cuerpo.cargar(el)                                   # ya grande: solo palpita
			if curada >= 1.0:
				texto("+%d" % int(round(curada)), Color(0.45, 1.0, 0.5))
			curado.emit(curada)
		_:
			return
	# Su elemento no le deja el estado: ni arde teñido de fuego, ni se moja de agua, ni se congela de hielo.
	match el:
		"fuego":
			quemando = 0.0
		"agua":
			mojado = 0.0
		"hielo":
			congelado = 0.0
	iniciar_destello(el, false, true)
	_t_gracia = GRACIA_SUELO
	_rotular()
	if origen == "hechizo":
		Sensacion3D.golpe_enemigo(self, el, false)         # gamefeel lote 4: absorber también es encajar un golpe, y el cuerpo suena
	absorciones.append({"accion": acc, "elemento": el, "origen": origen, "cura": curada})
	PlayLog.event("limo_absorbe", {"accion": acc, "elemento": el, "origen": origen, "grande": grande, "vida": snappedf(health, 0.1)})


## Lo que le hace el pulso periódico de una zona de su elemento (`HechizoVivo.pulso_plasma`): no le duele; si ya es grande, lo cura. Devuelve si lo absorbió (entonces no hay daño).
func absorbe_pulso(el: String, cantidad: float) -> bool:
	if muerto or elemento == "" or el != elemento:
		return false
	if grande and cantidad > 0.0:
		_curar_poco(cantidad)
	return true


## Cura en pedacitos (el suelo, los pulsos) sin llenar el aire de números: el rótulo sale cada 5 de vida.
func _curar_poco(cantidad: float) -> void:
	var antes: float = health
	health = minf(vida_max, health + cantidad)
	_cura_suelo_acum += health - antes
	if _cura_suelo_acum >= 5.0:
		texto("+%d" % int(round(_cura_suelo_acum)), Color(0.45, 1.0, 0.5))
		curado.emit(_cura_suelo_acum)
		_cura_suelo_acum = 0.0


func _al_crecer() -> void:
	altura = _alto()
	if _col != null and _col.shape is CapsuleShape3D:
		var f: CapsuleShape3D = _col.shape
		f.radius = _radio_limo()
		f.height = maxf(altura, 0.7)
		_col.position = Vector3(0, f.height * 0.5, 0)
	var alto: float = altura + ALTO_BARRA_EXTRA
	for n in [_barra_fondo, _barra_perdida, _barra_vida]:
		if n != null:
			(n as Node3D).position.y = alto
	if _marca_debil != null:
		_marca_debil.position.y = alto
	if _nombre_etiqueta != null:
		_nombre_etiqueta.position.y = alto + 0.14


## Nombre y rombo de la barra: del color de su elemento (sin teñir, blanco).
func _rotular() -> void:
	nombre = "Limo" + (" grande" if grande else (" pequeño" if pequeno else "")) + ((" de " + elemento) if elemento != "" else "")
	if _nombre_etiqueta != null:
		_nombre_etiqueta.text = nombre
	if _marca_debil != null:
		_marca_debil.modulate = Pulso3D.color_de(elemento) if elemento != "" else Color.WHITE


## =====================================================================================================
##  D3: dividirse con fuego
## =====================================================================================================

## ¿Se puede poner un limo en esa casilla? La misma regla de «casilla pisable» con la que brinca (`_puede_estar_desde`), y además sin otro enemigo, bloque ni la jugadora encima.
func _casilla_apta(c: Vector2i) -> bool:
	if not Terreno3D.en_mapa(c) or Terreno3D.bloqueada(c) or Terreno3D.es_agua(c):
		return false
	if not _puede_estar_desde(position, Terreno3D.centro_de(c, Terreno3D.y_pies(c)), false, false):
		return false
	if BloqueEmpujable3D.en(c) != null:
		return false
	if not is_inside_tree():
		return true
	for n in get_tree().get_nodes_in_group("combate3d"):
		if n != self and is_instance_valid(n) and n is Combate3D and not (n as Combate3D).muerto and Terreno3D.celda_de((n as Node3D).position) == c:
			return false
	if jugador != null and is_instance_valid(jugador) and Terreno3D.celda_de(jugador.position) == c:
		return false
	return true


## Hasta N_HIJOS casillas libres alrededor (primero las cuatro de al lado, luego las diagonales), donde se pondrían los hijos.
func _celdas_para_hijos() -> Array:
	var r: Array = []
	var yo: Vector2i = Terreno3D.celda_de(position)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if r.size() >= N_HIJOS:
			break
		if _casilla_apta(yo + (d as Vector2i)):
			r.append(yo + (d as Vector2i))
	return r


## Se parte en N_HIJOS limos de un escalón menos (grande → normales, normal → pequeños), con el mismo elemento y la mitad de la vida cada uno. No muere: no suelta botín ni cuenta como
## «enemigo muerto»; sus hijos heredan la casilla de partida (así el vigía de la sala los cuenta). false si no había sitio.
func dividirse(origen: String = "hechizo") -> bool:
	if muerto or en_bloque or pequeno:
		return false
	var celdas: Array = _celdas_para_hijos()
	if celdas.size() < N_HIJOS:
		return false
	var col: Color = Pulso3D.color_de(elemento) if elemento != "" else Color.WHITE
	hijos = []
	for c in celdas:
		var h: Limo3D = Limo3D.crear(mundo, Terreno3D.centro_de(c as Vector2i, Terreno3D.y_pies(c as Vector2i)), elemento, false, not grande)
		h.casa = casa
		h.quieto = quieto
		h.vida_max = vida_max * FRACCION_VIDA_HIJO
		h.health = health * FRACCION_VIDA_HIJO
		h._rotular()
		hijos.append(h)
	divisiones += 1
	texto_grande("¡Se divide!", col, 0.25)
	Sfx3D.play(self, "limo_divide")     # 13/11 (inventario SFX): antes no sonaba
	Sensacion3D.polvo(mundo, _pos_mundo(), Sensacion3D.POLVO_CAIDA)
	PlayLog.event("limo_divide", {"origen": origen, "grande": grande, "elemento": elemento, "hijos": hijos.size(), "vida_hijo": snappedf(vida_max * FRACCION_VIDA_HIJO, 0.1)})
	_desvanecer()
	dividido.emit(hijos)
	return true


## Desaparece sin morir (se ha partido): sin botín, sin aviso de muerte; el cuerpo se aplasta y se va.
func _desvanecer() -> void:
	_quitar_aviso()
	muerto = true
	se_dividio = true
	_accion = ""
	collision_layer = 0
	monitorable = false
	remove_from_group("combate3d")
	remove_from_group("goblins")
	for n in [_barra_fondo, _barra_perdida, _barra_vida, _marca_debil, _nombre_etiqueta]:
		if n != null:
			(n as Node3D).visible = false
	var c: LimoVisual3D = cuerpo
	if c != null and is_instance_valid(c):
		c.cancelar_salto()
		var tw: Tween = c.create_tween()
		tw.tween_property(c, "scale", Vector3(1.5, 0.05, 1.5), 0.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(c.queue_free)
		tw.tween_callback(func() -> void:
			if is_instance_valid(self):
				queue_free())
	else:
		queue_free()


## =====================================================================================================
##  D3: el hielo lo vuelve un bloque empujable
## =====================================================================================================

func _puede_ser_bloque() -> bool:
	var c: Vector2i = Terreno3D.celda_de(position)
	return is_inside_tree() and BloqueEmpujable3D.en(c) == null and not Terreno3D.bloqueada(c) and not Terreno3D.es_agua(c)


## Se congela en un `BloqueLimo` (un `BloqueEmpujable3D` de hielo) en su casilla durante T_BLOQUE s: él se queda quieto y fuera de los grupos de enemigos (el golpe F y los hechizos
## encuentran al bloque, no a él) y su cuerpo, hecho cubo de hielo, va con el bloque. La vida y el elemento que tuviera se quedan como estaban.
func congelar_en_bloque() -> bool:
	if muerto or en_bloque or not _puede_ser_bloque():
		return false
	_cortar_accion()
	_quitar_aviso()
	en_bloque = true
	t_bloque = T_BLOQUE
	objetivo = null
	var c: Vector2i = Terreno3D.celda_de(position)
	bloque = BloqueLimo.new()
	bloque.name = String(name) + "_bloque"
	bloque.limo = self
	bloque.preparar(c, "hielo", mundo)
	mundo.add_child(bloque)
	position.x = bloque.position.x
	position.z = bloque.position.z
	collision_layer = 0
	remove_from_group("combate3d")
	for n in [_barra_fondo, _barra_perdida, _barra_vida, _marca_debil, _nombre_etiqueta]:
		if n != null:
			(n as Node3D).visible = false
	if cuerpo != null and is_instance_valid(cuerpo):
		cuerpo.cancelar_salto()
		cuerpo.congelar(true)
		cuerpo.position = position
	texto_grande("¡Bloque!", Pulso3D.color_de("hielo"), 0.25)
	PlayLog.event("limo_bloque", {"elemento": elemento, "vida": snappedf(health, 0.1), "celda": [c.x, c.y]})
	return true


## Cada fotograma de bloque: el limo y su cuerpo siguen al bloque; al acabar T_BLOQUE (y parado) vuelve a ser limo.
func _vigilar_bloque(delta: float) -> void:
	if bloque == null or not is_instance_valid(bloque):
		_volver_de_bloque()                                  # lo quitaron de la escena (cambio de nivel): vuelve donde estaba
		return
	if not bloque.hundido:
		position.x = bloque.position.x
		position.z = bloque.position.z
		position.y = bloque.position.y
	if cuerpo != null and is_instance_valid(cuerpo):
		cuerpo.position = position
	t_bloque -= delta
	if t_bloque <= -T_ESPERA_BLOQUE_MAX or (t_bloque <= 0.0 and not bloque.moviendo):
		_volver_de_bloque()


## El bloque se hundió en agua honda: el limo muere ahogado en esa casilla (`_hundirse` avisa «hundido», la tinta por reacción y el resto).
func al_hundirse_bloque() -> void:
	if muerto or not en_bloque:
		return
	en_bloque = false
	var b: BloqueLimo = bloque
	bloque = null
	position.x = b.position.x
	position.z = b.position.z
	add_to_group("combate3d")
	if cuerpo != null and is_instance_valid(cuerpo):
		cuerpo.congelar(false)
		cuerpo.position = position
	_hundirse(Terreno3D.celda_de(position))


## Vuelve a ser limo en la casilla donde quedó el bloque, con la vida que tuviera.
func _volver_de_bloque() -> void:
	if not en_bloque:
		return
	en_bloque = false
	if bloque != null and is_instance_valid(bloque):
		var c: Vector2i = bloque.celda
		position = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
		bloque.deshacer()
	bloque = null
	t_bloque = 0.0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	add_to_group("combate3d")
	for n in [_barra_fondo, _barra_perdida, _barra_vida, _marca_debil, _nombre_etiqueta]:
		if n != null:
			(n as Node3D).visible = true
	if cuerpo != null and is_instance_valid(cuerpo):
		cuerpo.congelar(false)
		cuerpo.position = position
	_empuje = Vector3.ZERO
	_descanso = PAUSA_BRINCO
	Sensacion3D.polvo(mundo, _pos_mundo(), Sensacion3D.POLVO_CAIDA)
	PlayLog.event("limo_vuelve", {"vida": snappedf(health, 0.1)})


## El bloque de hielo del limo: un `BloqueEmpujable3D` (se empuja con viento o con F, resbala, pisa placas) que además se HUNDE en el agua honda (el de verdad se para en la orilla) y
## le dice al limo cuándo. Su cubo de hielo no se ve: lo que se ve es el cuerpo del limo, congelado.
class BloqueLimo extends BloqueEmpujable3D:
	var limo: Limo3D = null
	var hundido: bool = false

	func _ready() -> void:
		super()
		if _cuerpo != null:
			_cuerpo.visible = false

	## Como `_casilla_libre` del bloque, pero el agua honda también se puede pisar (y entonces se hunde). Fallo que evita: el bloque de hielo se quedaba en la orilla y el limo nunca se ahogaba.
	func _casilla_libre(c: Vector2i, ref: Vector2i) -> bool:
		if Terreno3D.en_mapa(c) and _agua_honda(c):
			return Terreno3D.altura_en(c) == Terreno3D.altura_en(ref) and not (_ocupadas.has(c) and _ocupadas[c] != self) and not _hay_enemigo(c) and not _jugadora_en(c)
		return super(c, ref)

	func puede_moverse(dir: Vector2i) -> bool:
		return not hundido and super(dir)

	func _agua_honda(c: Vector2i) -> bool:
		if Terreno3D.letra_de(c) == "b" or not Terreno3D.se_nada(c):
			return false
		return Terreno3D.agua_sim == null or Terreno3D.agua_sim.se_nada_en(c)

	func _acabar_casilla() -> void:
		super()
		if not hundido and _agua_honda(celda):
			hundido = true
			call_deferred("_hundir")

	func _hundir() -> void:
		Terreno3D.liberar_celda(celda)
		_olvidar(celda)
		if limo != null and is_instance_valid(limo):
			limo.al_hundirse_bloque()
		queue_free()

	## El limo vuelve a ser limo: el bloque se va y deja libre su casilla.
	func deshacer() -> void:
		if moviendo and _destino != celda:
			Terreno3D.liberar_celda(_destino)               # en marcha ya había reservado la casilla de delante
			_olvidar(_destino)
		Terreno3D.liberar_celda(celda)
		_olvidar(celda)
		limo = null
		queue_free()


## F4: el limo de FUEGO tampoco sufre el calor (los de calor se curan en el volcán); el resto, lo de siempre.
func inmune_a(estado: String) -> bool:
	return super(estado) or (estado == "calor" and elemento == "fuego")


## ¿Qué elemento hay en su casilla? (las zonas de hechizos que siguen en el suelo, la casilla helada/electrificada/mojada, o algo que arde y lo toca). «» = ninguno.
func _elemento_del_suelo() -> String:
	if not is_inside_tree():
		return ""
	var c: Vector2i = Terreno3D.celda_de(position)
	if lanz != null and is_instance_valid(lanz):
		for z in lanz._zonas_v2:
			if is_instance_valid(z) and (z as Lanzador3D.ZonaV2).celdas.has(c) and ELEMENTOS.has((z as Lanzador3D.ZonaV2).elemento):
				return (z as Lanzador3D.ZonaV2).elemento
	var e: EstadosSuelo3D = Terreno3D.estados
	if e.tiene(c, EstadosSuelo3D.HELADA):
		return "hielo"
	if e.tiene(c, EstadosSuelo3D.ELECTRIFICADA):
		return "rayo"
	if e.tiene(c, EstadosSuelo3D.MOJADA):
		return "agua"
	var p: Vector3 = _pos_mundo()
	var r: float = _radio_cuerpo()
	for n in get_tree().get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		if is_instance_valid(n) and n is Reactivo3D and (n as Reactivo3D).emite_fuego_por_contacto() and (n as Reactivo3D).toca_punto(p, r):
			return "fuego"
	return ""


## Cada INTERVALO_SUELO s, si está en el suelo (no en el aire de un salto): se tiñe de lo que pisa; si pisa su elemento, entrar lo hace crecer y quedarse (ya grande) lo cura.
func _suelo_elemental(delta: float) -> void:
	_t_suelo -= delta
	_t_gracia = maxf(0.0, _t_gracia - delta)
	if _t_suelo > 0.0:
		return
	_t_suelo = INTERVALO_SUELO
	if cuerpo != null and cuerpo.en_salto and cuerpo.position.y > position.y + 0.12:
		return                                               # en el aire no toca nada
	var el: String = _elemento_del_suelo()
	var antes: bool = _en_su_elemento
	_en_su_elemento = el != "" and el == elemento
	if el == "":
		return
	match accion_elemento(el):
		"tine":
			absorber(el, "tine", 0.0, "suelo")
		"crece":
			if not antes and _t_gracia <= 0.0:
				absorber(el, "crece", 0.0, "suelo")
		"cura":
			_curar_poco(CURA_SUELO * INTERVALO_SUELO)


## Sin teñir, lo que arde lo TIÑE de fuego en vez de prenderlo (`_suelo_elemental`); teñido de fuego, no arde.
func puede_prender() -> bool:
	return super() and elemento != "" and elemento != "fuego"


## =====================================================================================================
##  Fotograma e IA: brincos y acometida
## =====================================================================================================

func _physics_process(delta: float) -> void:
	if muerto:
		return
	if en_bloque:
		_vigilar_bloque(delta)                      # D3: congelado en bloque no piensa ni se cura: solo espera (sus estados y su vida se quedan como estaban)
		return
	if jugador == null or not is_instance_valid(jugador):
		_buscar_jugador()
	if _hitstop > 0.0:
		_hitstop -= delta
		_destello = maxf(0.0, _destello - delta)
		_dibujar_estado(delta)
		if _hitstop <= 0.0:
			_hitstop = 0.0
		return
	_efectos(delta)
	if muerto:
		return
	_suelo_elemental(delta)
	_ia_limo(delta)
	_ajustar_al_suelo(delta)
	if muerto:
		return
	_sincronizar_cuerpo()
	_dibujar_estado(delta)


func _sincronizar_cuerpo() -> void:
	if cuerpo == null or not is_instance_valid(cuerpo):
		return
	cuerpo.congelar(congelado > 0.0)
	if not cuerpo.en_salto:
		cuerpo.position = position
	if mirada.length() > 0.01:
		cuerpo.rotation.y = lerp_angle(cuerpo.rotation.y, atan2(mirada.x, mirada.z), 0.2)


func _ia_limo(delta: float) -> void:
	if _empuje.length() > 0.1:
		_mover_paso(_empuje * delta, true)          # empujado: sí puede acabar en el agua honda (y hundirse)
		_empuje = _empuje.lerp(Vector3.ZERO, clampf(DECAIMIENTO_EMPUJE * delta, 0.0, 1.0))
	if stun_timer > 0.0:
		stun_timer -= delta
		_cortar_accion()
		return
	if congelado > 0.0:
		_cortar_accion()
		return
	if interrupcion > 0.0:
		interrupcion -= delta
		_cortar_accion()
		return
	if _accion != "":
		_seguir_accion(delta)
		return
	if quieto or jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		objetivo = null
		return
	var ve: bool = _ve(RADIO_VER if objetivo == null else RADIO_PERDER)
	if ve:
		if objetivo == null:
			flotante(mundo, position + Vector3(0, altura + ALTO_BARRA_EXTRA, 0), "!", Color(1, 0.85, 0.2))
			PlayLog.event("goblin_ve_al_jugador", {"distancia": snappedf(position.distance_to(jugador.position), 0.1), "nombre": nombre})
		objetivo = jugador
		vista_perdida = 0.0
		ultima_pos = jugador.position
	elif objetivo != null:
		vista_perdida += delta
		if vista_perdida > TIEMPO_PERDER:
			objetivo = null
	if objetivo == null or _descanso > 0.0:
		return
	var meta: Vector3 = jugador.position if ve else ultima_pos
	var d: Vector3 = meta - position
	d.y = 0.0
	if d.length() > 0.05:
		mirada = d.normalized()
	if ve and d.length() <= alcance_acometida() + radio_golpe() * 0.5 and absf(jugador.position.y - position.y) < Terreno3D.ALTO_NIVEL * 0.9:
		_empezar_acometida()
		return
	if d.length() < 0.3:
		return
	_empezar_brinco(_dir_hacia(meta, delta))


## u que puede avanzar en `dir` sin chocar (hasta `maximo`), probando a pasos de 0,1 u con la regla de andar de siempre.
func _distancia_libre(dir: Vector3, maximo: float) -> float:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		return 0.0
	d = d.normalized()
	var prev: Vector3 = position
	var hecho: float = 0.0
	var paso: float = 0.1
	while hecho + paso <= maximo + 0.0001:
		var p: Vector3 = prev + d * paso
		if not _puede_estar_desde(prev, p, false, false):
			break
		prev = p
		hecho += paso
	return hecho


func _empezar_brinco(dir: Vector3) -> void:
	var dist: float = _distancia_libre(dir, BRINCO_CASILLAS * Terreno3D.casilla * _mult_salto())
	if dist < 0.25:
		_descanso = PAUSA_BRINCO
		return
	_accion = "brinco"
	_t_accion = 0.0
	cuerpo.position = position
	cuerpo.saltar(dir, dist, _mult_salto())


## Se agacha T_AVISO_ACOMETIDA s y salta hacia donde está ella (hasta `alcance_acometida`); el aviso marca el sitio donde caerá.
func _empezar_acometida() -> void:
	var d: Vector3 = jugador.position - position
	d.y = 0.0
	var dir: Vector3 = d.normalized() if d.length() > 0.05 else mirada
	var dist: float = _distancia_libre(dir, minf(d.length(), alcance_acometida()))
	_punto_golpe = position + dir * dist
	_quitar_aviso()
	if AVISAR_ATAQUES and mundo != null:
		_aviso = AvisoAtaque3D.circulo(mundo, _punto_golpe, radio_golpe(), T_AVISO_ACOMETIDA + LimoVisual3D.T_AIRE, self)
		avisos_dados += 1
	_accion = "acometida"
	_t_accion = 0.0
	_golpe_hecho = false
	acometidas += 1
	cuerpo.position = position
	cuerpo.saltar(dir, dist, _mult_salto(), T_AVISO_ACOMETIDA)
	PlayLog.event("limo_acomete", {"dist": snappedf(dist, 0.01), "grande": grande, "elemento": elemento})


func _seguir_accion(delta: float) -> void:
	_t_accion += delta
	position.x = cuerpo.position.x                          # mientras salta (y en el fotograma en que acaba) manda el cuerpo: ya se comprobó que el camino es libre
	position.z = cuerpo.position.z
	if _accion == "acometida" and not _golpe_hecho and _t_accion >= T_AVISO_ACOMETIDA + LimoVisual3D.T_AIRE:
		_golpe_hecho = true
		_aviso = null                                       # el aviso acaba solo en este instante
		position.x = _punto_golpe.x
		position.z = _punto_golpe.z
		_aterrizar_golpe()
	if not cuerpo.en_salto:
		_descanso = DESCANSO_ACOMETIDA if _accion == "acometida" else PAUSA_BRINCO
		_accion = ""


## Cae: si ella está dentro del círculo del aviso, 15 (30 de grande) y el retroceso leve hacia fuera.
func _aterrizar_golpe() -> void:
	Sfx3D.play(self, "limo_golpe")     # 13/11 (inventario SFX): antes no sonaba
	Sensacion3D.polvo(mundo, _punto_golpe, Sensacion3D.POLVO_CAIDA * (1.3 if grande else 1.0))     # gamefeel lote 2: el golpe contra el suelo levanta polvo
	if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		return
	var rel: Vector3 = jugador.position - _punto_golpe
	rel.y = 0.0
	var dentro: bool = rel.length() <= radio_golpe() and absf(jugador.position.y - position.y) < Terreno3D.ALTO_NIVEL * 0.9
	if dentro:
		var antes: float = jugador.vida
		jugador.recibir_dano(dano_golpe())                  # sin `desde`: el empujón de 4,5 de los goblins no; el suyo es más suave
		if jugador.vida < antes:
			var fuera: Vector3 = rel.normalized() if rel.length() > 0.05 else mirada
			jugador.push(fuera, EMPUJE_GOLPE)
			golpes_dados += 1
			efecto_ataque = _elemento_a_la_jugadora()
	PlayLog.event("limo_golpe", {"acierta": dentro, "dano": dano_golpe() if dentro else 0.0})


## D3: su acometida lleva su elemento a la jugadora. `Jugador3D` solo tiene el veneno como estado propio (sin `aplicar_estado`; mojada/quemada/etc. son del SUELO que pisa), así que:
##   · si algún día tiene `aplicar_estado(elemento, segundos)`, se usa ese (devuelve «estado»);
##   · si no, el estado se pone en la casilla donde está ella (`EstadosSuelo3D`): agua → mojada (esa sí la nota: aguante, calor), hielo → helada, fuego → quemada, rayo → electrificada
##     (devuelve «suelo»). Tierra y viento no dejan nada. PENDIENTE por conflicto (`jugador_3d.gd`): un estado de personaje (ralentizada, quemada con tics, aturdida) para que lo del suelo
##     no sea lo único que ella nota.
func _elemento_a_la_jugadora() -> String:
	if elemento == "" or jugador == null or not is_instance_valid(jugador):
		return ""
	if jugador.has_method("aplicar_estado"):
		jugador.call("aplicar_estado", elemento, ESTADO_ATAQUE_S)
		return "estado"
	var c: Vector2i = Terreno3D.celda_de(jugador.position)
	match elemento:
		"agua":
			Terreno3D.estados.aplicar(c, "agua")
		"hielo":
			Terreno3D.estados.aplicar(c, "frio")
		"fuego":
			Terreno3D.estados.poner(c, EstadosSuelo3D.QUEMADA, true)
		"rayo":
			Terreno3D.estados.poner(c, EstadosSuelo3D.ELECTRIFICADA, true)
		_:
			return ""
	return "suelo"


## Golpeado, congelado, aturdido o empujado: el brinco o la acometida se cortan (y su aviso, si aún no había caído).
func _cortar_accion() -> void:
	if _accion != "":
		if cuerpo != null and is_instance_valid(cuerpo) and cuerpo.en_salto:
			position.x = cuerpo.position.x
			position.z = cuerpo.position.z
			cuerpo.cancelar_salto()
		_accion = ""
	if not _golpe_hecho:
		_quitar_aviso()


func push(direccion: Vector3, fuerza: float, suelo: bool = false, dano: float = -1.0, debil: bool = false) -> void:
	_cortar_accion()
	super(direccion, fuerza, suelo, dano, debil)


func _reaccion_visual(el: String) -> void:
	if cuerpo != null and is_instance_valid(cuerpo) and not cuerpo.en_salto:
		# tarea H: el destello del limo lleva el color del elemento (con la sensación apagada o DESTELLO_GOLPE = 0, sin destello: el limo no tenía)
		var col: Color = (COLORES[el] as Color).lerp(Color.WHITE, 0.35) if COLORES.has(el) else Color.WHITE
		cuerpo.golpe(col, 1.0 if Sensacion3D.ACTIVA and DESTELLO_GOLPE > 0.0 else 0.0)


## =====================================================================================================
##  Morir: se deshace en un charco, o se hunde
## =====================================================================================================

func _morir(ahogado: bool = false) -> void:
	if muerto:
		return
	_quitar_aviso()
	muerto = true
	se_hundio = ahogado
	quemando = 0.0
	_accion = ""
	collision_layer = 0
	monitorable = false
	remove_from_group("combate3d")
	for n in [_barra_fondo, _barra_perdida, _barra_vida, _marca_debil, _nombre_etiqueta]:
		if n != null:
			(n as Node3D).visible = false
	PlayLog.event("goblin_muere", {"nombre": nombre, "celda": [Terreno3D.celda_de(position).x, Terreno3D.celda_de(position).y], "ahogado": ahogado})
	Estado.i().enemigo_muerto.emit(Vector2(position.x, position.z), nombre)
	Sensacion3D.muerte(self)                                 # gamefeel lote 2
	if snd_muere != "" and Sfx3D.CATALOGO.has(snd_muere):
		Sfx3D.play(self, snd_muere)                          # gamefeel lote 4 (el `_morir` de Combate3D no corre aquí: el limo tiene el suyo)
	var c: LimoVisual3D = cuerpo
	# Tarea E3 (1/11): la muerte por elemento del limo es solo el remate sonoro, el tinte (carbón, azul) y las partículas: ni desmoronamiento ni trozos (se deshace en un charco).
	var el_muerte: String = "" if ahogado else _elemento_letal()
	if VARIANTES_MUERTE.has(el_muerte):
		muerte_el = el_muerte
		Sfx.play(self, String(SONIDO_MUERTE[el_muerte]))
		if Sensacion3D.ACTIVA:
			if c != null and is_instance_valid(c) and (el_muerte == "fuego" or el_muerte == "hielo"):
				muerte_tinte = TINTE_CARBON if el_muerte == "fuego" else Color(0.55, 0.85, 1.0)
				c.tenir_muerte(muerte_tinte)
			if _cupo_muerte_vfx():
				Sensacion3D.cuenta["muerte_vfx"] = int(Sensacion3D.cuenta["muerte_vfx"]) + 1
				_particulas_muerte(el_muerte, false)
	if c != null and is_instance_valid(c):
		c.cancelar_salto()
		var tw: Tween = c.create_tween()
		if ahogado:
			tw.tween_property(c, "position:y", c.position.y - 1.2, 1.4).set_ease(Tween.EASE_IN)
		else:
			tw.tween_property(c, "scale", Vector3(1.6, 0.05, 1.6), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_interval(0.6)
		tw.tween_callback(c.queue_free)
	if ahogado:
		_hundir_modelo(1.4)                                  # aviso, reacción «hundido» (tinta C2) y la señal; sin modelo Pj3D se borra en el acto
		return
	_soltar_botin()                                          # F1: la tabla `limo` (oro siempre + baba 70 %)
	queue_free()
