class_name Golem3D
extends Combate3D

## E3 · GÓLEM DE PIEDRA (docs/PROPUESTA_COMBATE.md §4 y §7; diseño de Opus del 28/10). Dueño: Juego.
##
## Pregunta que plantea: «¿qué uso del escenario?». Un enemigo al que no se le gana a flechazos:
##   · CUERPO DE PIEDRA. De pie y armado NADA le hace daño (hechizos de cualquier elemento, flechas, golpe F, quemadura, rayo, pulsos de zona): rótulo gris «Piedra» y un golpe seco.
##     Tampoco arde, ni se moja, ni se congela, ni se electrocuta, ni se aturde (`decidir_golpe` ignora todos los estados). `decidir_golpe` lo dice con mult 0, así que la previsión
##     del indicador (A2/A3) pone «Piedra» antes de lanzar.
##   · NO SE MUEVE POR EMPUJE (viento, golpes, golpe F: `empujable_golpe = false`, `push` ignorado)… SALVO SOBRE HIELO: si pisa una casilla helada (`Terreno3D.helada`: agua congelada o
##     escarcha) y le llega viento (el `push` del Lanzador3D o de un gas), RESBALA: se desliza a VEL_RESBALE u/s en la cardinal del viento mientras la casilla siguiente sea hielo libre
##     (pisable, sin otro enemigo ni la jugadora). Se para pegado a una pared, un bloque, otro cuerpo o un suelo que no sea hielo. Si la siguiente casilla es agua honda o lava, CAE DENTRO:
##     agua → se hunde y muere (`Combate3D._hundirse`: sin botín, reacción «hundido», +20 de tinta por C2); lava → muere abrasado (`_caer_en_lava`: sin botín ni tinta, ver abajo).
##     Al pararse en suelo cae de espaldas (clip `resbalar`) y queda TUMBADO T_TUMBADO s (vulnerable, como el núcleo expuesto) antes de levantarse (clip `levantarse`).
##     Sin hielo, el viento: «Ni se inmuta».
##   · ATAQUE AVISADO (C3). Persigue lento (VEL). A RANGO empieza el clip `attack` (mazazo con los dos puños, 2,7 s; el golpe cae a AnimacionesGolem.INSTANTE_GOLPE = 1,43 s): el aviso
##     (`AvisoAtaque3D.rectangulo`) sale al empezar y se llena hasta el impacto. La zona es el rectángulo DELANTE de donde empezó el golpe: de ZONA_DESDE a ZONA_DESDE + ZONA_LARGO u y
##     ZONA_ANCHO u de ancho; es la misma que comprueba el daño (DANO y empuje EMPUJE_GOLPE a la jugadora) y cubre dónde caen los puños (1,43 u) y el cuerpo ya avanzado. El clip trae
##     el avance de la raíz DENTRO (la cadera adelanta el modelo `AVANCE_GOLPE` = 1,15 u hasta el impacto): el enemigo mueve su NODO lo mismo (`avance_golpe_en`) y le resta ese avance al
##     modelo (`_physics_process`), así nodo, colisión y modelo van juntos y no hay salto al cambiar de clip. Sin atravesar paredes. Rodar en la ventana final del aviso da el tiempo bruja (C4).
##   · NÚCLEO EXPUESTO = PUNTO DÉBIL. Tras el golpe pasa al clip `expuesto` (de rodillas, el pecho adelantado): entre T_EXPUESTO_ABAJO y T_EXPUESTO_ARRIBA del clip (2,5 s) todo le hace daño
##     × MULT_NUCLEO (sin debilidades ni resistencias; el golpe F también, sin moverlo). Igual tumbado tras resbalar. El núcleo (pieza `nucleo_golem` de Equipo3D) sube su emisión mientras
##     tanto y se apaga al morir. Rótulo «¡Núcleo!» la primera vez que se le da en cada ventana.
## LAVA: ni `Combate3D` ni `Lava3D` tenían muerte por lava. Cae → `_morir(true)` con `_en_lava`: se hunde en la casilla como en el agua, con «¡Lava!», una llamarada y la reacción «prendido»;
## sin `hundido` (no burbujea) y SIN tinta: C2 premia «hundido», «electrocutado», «congelado», «mano_quemada» y «apagado», y ninguna encaja.
## Hecho como un `Combate3D` (vida, barra, previsión, vigía, hundirse… se heredan) con modelo Pj3D `golem_piedra`. Se pone desde un mapa con la pieza `golem` de Puzle3D o con `Golem3D.invocar_golem`.

signal expuesto(estaba_tumbado: bool)         ## el núcleo queda a la vista (tras su golpe o al caer tumbado)
signal resbalo(celdas: int)                   ## se ha parado tras resbalar (sin caer al agua ni a la lava)

const ID: String = "golem_piedra"
const VIDA: float = 70.0                    ## 29/10 (DANO_Y_TINTA): 120 → 70
const ORO_GOLEM: int = 40
const VEL: float = 0.9                        ## u/s al perseguir (un goblin 2,4)
const RANGO: float = 1.9                      ## u, centro a centro: a esto empieza el golpe
const DANO: float = 30.0
const EMPUJE_GOLPE: float = 8.0               ## u/s iniciales de `Jugador3D.push` a la jugadora (un goblin 4,5; el limo 3)
const ZONA_DESDE: float = 0.5                 ## u por delante de donde empieza el golpe en que arranca la zona...
const ZONA_LARGO: float = 2.3                 ## ...y cuánto dura hacia delante
const ZONA_ANCHO: float = 1.6                 ## u de lado a lado
const DESCANSO_TRAS_EXPONERSE: float = 1.0    ## s que espera de pie, armado, antes de poder volver a pegar
const MULT_NUCLEO: float = 1.5                ## ×daño al núcleo expuesto (o tumbado)
const VEL_RESBALE: float = 4.5                ## u/s sobre el hielo
const T_TUMBADO: float = 3.0                  ## s tumbado (vulnerable) tras resbalar
const RADIO_TOPE: float = 0.55                ## u: lo que el cuerpo se queda separado del borde de la casilla cuando para contra algo
const PASO_PREVISION: float = 0.1             ## u: paso con que la previsión simula el resbalón
const PAUSA_TEXTO: float = 0.6                ## s entre dos rótulos «Piedra» / «Ni se inmuta» (el daño continuo no los llena)
const COLOR_PIEDRA: Color = Color(0.72, 0.72, 0.76)
const COLOR_NUCLEO: Color = Color(1.0, 0.62, 0.22)
const BRILLO_REPOSO: float = 0.45             ## emisión del núcleo armado
const BRILLO_EXPUESTO: float = 3.2            ## ...y expuesto o tumbado (más un latido de ± BRILLO_LATIDO)
const BRILLO_LATIDO: float = 0.7
const RADIO_CAPSULA: float = 0.6              ## u: el cuerpo contra el que chocan las flechas (el de un goblin, 0,32, se quedaba corto)

var g_estado: String = "armado"               ## armado · atacando · expuesto · resbalando · tumbado · levantando (muerto: `muerto`)
var ataques: int = 0                          ## golpes empezados (pruebas)
var golpes_dados: int = 0                     ## golpes que le dieron a la jugadora (pruebas)
var resbalones: int = 0                       ## resbalones empezados (pruebas)
var exposiciones: int = 0                     ## veces que quedó con el núcleo a la vista (pruebas)
var murio_en_lava: bool = false
var inmune_hielo: bool = true                 ## `Lanzador3D.atrapar`: el hielo que se forma bajo él no lo deja preso (es de piedra)
var _t_estado: float = 0.0                    ## s en el estado actual (en `expuesto` coincide con el segundo del clip)
var _dir_ataque: Vector3 = Vector3(0, 0, 1)
var _pos_ataque0: Vector3 = Vector3.ZERO      ## dónde estaba al empezar el golpe: la zona se mide desde aquí
var _t_atq: float = 0.0                       ## s de golpe (= segundo del clip `attack`)
var _adv_hecho: float = 0.0                   ## u que ha avanzado el nodo en este golpe
var _hips_adv: float = 0.0                    ## u que el clip adelanta ahora el modelo (se le resta para que modelo y nodo coincidan)
var _res_dir: Vector3 = Vector3.ZERO
var _res_celdas: int = 0
var _nucleo_avisado: bool = false
var _t_texto: float = 0.0
var _en_lava: bool = false
var _nucleo_mats: Array = []
var _brillo: float = BRILLO_REPOSO
var _luz: OmniLight3D = null
var _t_reloj: float = 0.0


## Crea un gólem de piedra en `pos` (un modelo Pj3D `golem_piedra` + su combate) y lo cuelga del mundo. `p_jugador` / `p_lanz` son opcionales: si faltan los busca él (grupos
## «spellcaster» y «player»). Devuelve null si falta el modelo.
static func invocar_golem(p_mundo: Node3D, pos: Vector3, p_jugador: Jugador3D = null, p_lanz: Lanzador3D = null) -> Golem3D:
	var modelo: Pj3D = p_mundo.call("_personaje", [ID], pos)
	if modelo == null:
		return null
	var lista: Variant = p_mundo.get("_goblins")
	if lista is Array:
		(lista as Array).append(modelo)
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	var g := Golem3D.new()
	g.name = "Golem_" + str(modelo.get_instance_id())
	g.pj = modelo
	g.mundo = p_mundo
	g.jugador = p_jugador
	g.lanz = p_lanz
	g.position = pos
	g.casa = pos
	g.altura = modelo.alto_modelo() * modelo.scale.y
	p_mundo.add_child(g, true)
	return g


func _ready() -> void:
	nombre = "Gólem de piedra"
	vida_max = VIDA
	defensa = Dano.DEF_GOLEM                  # 29/10 (DANO_Y_TINTA): 10 — solo los hechizos potentes lo hieren de verdad
	oro = ORO_GOLEM
	debil = ""
	resiste = ""
	tinte = Color.WHITE
	snd_alerta = ""
	snd_muere = "derrumbe"
	empujable_golpe = false
	botin_goblin = false
	if jugador == null or lanz == null:
		_buscar_jugador()
	super()
	if _col != null and _col.shape is CapsuleShape3D:
		var f: CapsuleShape3D = _col.shape
		f.radius = RADIO_CAPSULA
		f.height = maxf(altura, 0.7)
		_col.position = Vector3(0, f.height * 0.5, 0)
	if _marca_debil != null:
		_marca_debil.visible = false              # no tiene debilidad de elemento: su punto débil es el núcleo
	_preparar_nucleo()


func _buscar_jugador() -> void:
	if not is_inside_tree():
		return
	for grupo in ["spellcaster", "player"]:
		var l: Node = get_tree().get_first_node_in_group(grupo)
		if l != null and l.get("jugador") is Jugador3D:
			jugador = l.get("jugador") as Jugador3D
			lanz = l as Lanzador3D if l is Lanzador3D else jugador.lanz
			return


## =====================================================================================================
##  El núcleo: la pieza `nucleo_golem` del pecho, que brilla más cuando está a la vista
## =====================================================================================================

func _preparar_nucleo() -> void:
	var piezas: Variant = pj.get("_equipo") if pj != null else null
	if piezas is Array:
		for p in (piezas as Array):
			if not (p is Node3D) or String((p as Node3D).get_meta("equipo_id", "")) != "nucleo_golem":
				continue
			for n in (p as Node3D).find_children("*", "MeshInstance3D", true, false):
				var mi: MeshInstance3D = n as MeshInstance3D
				if mi.mesh == null:
					continue
				for s in range(mi.mesh.get_surface_count()):
					var base: Material = mi.get_active_material(s)
					if not (base is StandardMaterial3D):
						continue
					var m: StandardMaterial3D = (base as StandardMaterial3D).duplicate()
					m.emission_enabled = true
					m.emission = COLOR_NUCLEO
					if m.albedo_texture != null:
						m.emission_texture = m.albedo_texture
					m.emission_energy_multiplier = BRILLO_REPOSO
					mi.set_surface_override_material(s, m)
					_nucleo_mats.append(m)
	_luz = OmniLight3D.new()
	_luz.name = "LuzNucleo"
	_luz.light_color = COLOR_NUCLEO
	_luz.omni_range = 3.2
	_luz.light_energy = 0.0
	_luz.position = Vector3(0.0, altura * 0.55, 0.35)
	add_child(_luz)


## ¿El núcleo está a la vista y el daño le llega ×MULT_NUCLEO? De rodillas entre T_EXPUESTO_ABAJO y T_EXPUESTO_ARRIBA del clip, o tumbado.
func vulnerable() -> bool:
	if muerto:
		return false
	match g_estado:
		"expuesto":
			return _t_estado >= AnimacionesGolem.T_EXPUESTO_ABAJO and _t_estado < AnimacionesGolem.T_EXPUESTO_ARRIBA
		"tumbado":
			return true
	return false


## La emisión que lleva ahora el núcleo (pruebas y captura).
func brillo_nucleo() -> float:
	return _brillo


func _actualizar_nucleo(delta: float) -> void:
	_t_reloj += delta
	var objetivo: float = BRILLO_EXPUESTO + BRILLO_LATIDO * sin(_t_reloj * 6.0) if vulnerable() else BRILLO_REPOSO
	_brillo = move_toward(_brillo, objetivo, delta * 12.0)
	_poner_brillo(_brillo)


func _poner_brillo(e: float) -> void:
	for m in _nucleo_mats:
		if is_instance_valid(m):
			(m as StandardMaterial3D).emission_energy_multiplier = e
	if _luz != null and is_instance_valid(_luz):
		_luz.light_energy = maxf(0.0, e - BRILLO_REPOSO) * 0.5


## =====================================================================================================
##  Daño: piedra de pie, ×MULT_NUCLEO con el núcleo a la vista
## =====================================================================================================

## A2: la decisión del golpe. Sin estados (ni arde, ni se moja, ni se congela…); de pie y armado mult 0; con el núcleo a la vista mult MULT_NUCLEO (1 si el hechizo no hace daño: el
## viento) y SIN debilidades ni resistencias: el daño es el del hechizo × 1,5.
func decidir_golpe(hechizo: Hechizo) -> Dictionary:
	var r: Dictionary = super(hechizo)
	r["curado"] = false
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
	r["base"] = hechizo.dano * hechizo.potencia
	if vulnerable() and hechizo.dano > 0.0:
		r["mult"] = MULT_NUCLEO
		r["bruto"] = Dano.bruto(hechizo.dano, hechizo.potencia, 1.0, MULT_NUCLEO)
		r["dano"] = Dano.aplicar(hechizo.dano, hechizo.potencia, 1.0, MULT_NUCLEO, defensa)       # 29/10: R = MULT_NUCLEO y la defensa (10)
	elif vulnerable():
		r["mult"] = 1.0
		r["bruto"] = 0.0
		r["dano"] = 0.0
	else:
		r["mult"] = 0.0
		r["bruto"] = 0.0
		r["dano"] = 0.0
	return r


func golpe(hechizo: Hechizo, direccion: Vector3) -> void:
	if muerto or hechizo == null:
		return
	var dec: Dictionary = decidir_golpe(hechizo)
	var d := Vector3(direccion.x, 0.0, direccion.z)
	var dano: float = float(dec["dano"])
	if dano > 0.0:
		_nucleo_golpeado()
		_num_golpe = true
		_num_elemento = hechizo.elemento
		_num_debil = true
		_aplicar_dano(dano)
		_num_golpe = false
		var hs: float = Sensacion3D.hitstop_de(dano, true)
		_hitstop_compartido(hs)
		if not muerto:
			_iniciar_hitstop(hs)
		_destello = maxf(_destello, DESTELLO_GOLPE)
		_impacto_visual(hechizo.elemento, true, d)
	elif not vulnerable() and hechizo.elemento != "viento":
		_piedra(d)                                   # el viento ya habló en `push` («Ni se inmuta» o resbala)
	if objetivo == null and jugador != null and not muerto and _ve(RADIO_SOLTAR):
		objetivo = jugador
	PlayLog.event("golpe_goblin", {"elemento": hechizo.elemento, "dano": snappedf(dano, 0.1), "vida": snappedf(health, 0.1), "mult": float(dec["mult"]), "golem": g_estado})


## El daño que no pasa por `golpe` (pulsos de zona, estalagmitas, geodas, el golpe F): de pie no pasa; con el núcleo a la vista, ×MULT_NUCLEO.
func receive_damage(cantidad: float, _desde_nivel: int = 0) -> void:
	if muerto or health <= 0.0 or cantidad <= 0.0:
		return
	if not vulnerable():
		_piedra()
		return
	_nucleo_golpeado()
	_aplicar_dano(cantidad * MULT_NUCLEO)


## El daño ya calculado: como `Combate3D.receive_damage` pero sin el clip `hit` ni la interrupción (de rodillas no se sacude).
func _aplicar_dano(cantidad: float) -> void:
	if health <= 0.0 or cantidad <= 0.0:
		return
	health -= cantidad
	_barra_t = TIEMPO_BARRA
	_destello = maxf(_destello, DESTELLO_DANO)
	_barra_destello = DESTELLO_BARRA
	_perdida_espera = RETARDO_PERDIDA
	_numero(cantidad)
	if health <= 0.0:
		_morir()


## C1: el golpe F. De pie, «Piedra»; con el núcleo a la vista, daño × MULT_NUCLEO. Nunca lo mueve ni le corta el golpe (a diferencia de los demás enemigos).
func recibir_golpe_cuerpo(dir: Vector3, dano: float, _fuerza: float, _factor_escudo: float = 0.5) -> Dictionary:
	var r: Dictionary = {"escudo": false, "dano": 0.0, "v0": 0.0}
	if muerto:
		return r
	var d := Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() if d.length() > 0.01 else Vector3.ZERO
	if vulnerable() and dano > 0.0:
		var real: float = Dano.tras_defensa(dano * MULT_NUCLEO, defensa)     # 29/10: el golpe F también pasa por la defensa (5 × 1,5 − 10 → suelo 1,5)
		r["dano"] = real
		_nucleo_golpeado()
		_num_golpe = true
		_num_elemento = ""
		_num_debil = true
		_aplicar_dano(real)
		_num_golpe = false
		var hs: float = Sensacion3D.hitstop_de(real, false)
		_hitstop_compartido(hs)
		if not muerto:
			_iniciar_hitstop(hs)
		_destello = maxf(_destello, DESTELLO_GOLPE)
		_impacto_visual("", false, d)
	else:
		_piedra(d)
	if objetivo == null and jugador != null and not muerto and _ve(RADIO_SOLTAR):
		objetivo = jugador
	PlayLog.event("golpe_cuerpo_recibido", {"nombre": nombre, "dano": snappedf(float(r["dano"]), 0.1), "vida": snappedf(health, 0.1), "escudo": false, "v0": 0.0})
	return r


## «Piedra»: el golpe no hace nada. Como mucho un rótulo y un golpe seco cada PAUSA_TEXTO s.
func _piedra(dir: Vector3 = Vector3.ZERO) -> void:
	if _t_texto > 0.0:
		return
	_t_texto = PAUSA_TEXTO
	texto("Piedra", COLOR_PIEDRA, 0.28)
	Sfx3D.play(self, "escudo_golpe")
	if dir.length() > 0.01:
		_impacto_visual("", false, dir)


func _ni_se_inmuta() -> void:
	if _t_texto > 0.0:
		return
	_t_texto = PAUSA_TEXTO
	texto("Ni se inmuta", COLOR_PIEDRA, 0.28)


## «¡Núcleo!» la primera vez que se le da en cada ventana.
func _nucleo_golpeado() -> void:
	if _nucleo_avisado:
		return
	_nucleo_avisado = true
	texto_grande("¡Núcleo!", COLOR_NUCLEO, 0.28)


## Ni arde, ni se aturde, ni se asusta del aturdimiento de las vetas.
func _aturdir(_segundos: float) -> void:
	pass


## Lo que arde y lo toca no lo prende.
func puede_prender() -> bool:
	return false


func reacciones_soportadas() -> PackedStringArray:
	return PackedStringArray(["empujado", "cae_al_agua"])      # solo resbalando sobre hielo; las demás no le pasan


func v0_de_empuje(_fuerza: float, _suelo: bool = false) -> float:
	return 0.0


## =====================================================================================================
##  Previsión (A2/A3): «Piedra», «Núcleo ×1,5», «Resbala», «Se hunde», «¡Lava!», «Ni se inmuta»
## =====================================================================================================

## Lo de `Combate3D.prever_golpe` más `reacciones_propias` (las que pinta el indicador, en el orden de `PrevisionHechizo.PRIORIDAD_ENEMIGO`) y, si resbala, el recorrido en `empuje`.
func prever_golpe(hechizo: Hechizo, dir: Vector3, empuje_previo: Dictionary = {}) -> Dictionary:
	var r: Dictionary = super(hechizo, dir, {})
	r["reacciones_propias"] = []
	r["cae_en_lava"] = false
	if muerto or hechizo == null:
		return r
	var props: Array = []
	var viento: bool = not empuje_previo.is_empty()
	if viento:
		if puede_resbalar():
			var s: Dictionary = simular_resbalon(cardinal(empuje_previo["dir"]))
			props.append("resbala")
			if String(s["fin"]) == "agua":
				props.append("hunde")
			elif String(s["fin"]) == "lava":
				props.append("lava")
			r["empuje"] = {"destino": s["destino"], "recorrido": s["recorrido"], "hundira": String(s["fin"]) == "agua", "celda_agua": s["celda"]}
			r["cae_al_agua"] = String(s["fin"]) == "agua"
			r["cae_en_lava"] = String(s["fin"]) == "lava"
		elif g_estado == "armado" or g_estado == "atacando" or g_estado == "expuesto":
			props.append("inmune")
	if vulnerable():
		if float(r["dano"]) > 0.0:
			props.append("nucleo")
	elif not viento:
		props.append("piedra")
	r["reacciones_propias"] = props
	return r


## =====================================================================================================
##  El hielo: viento sobre una casilla helada lo hace resbalar
## =====================================================================================================

## Viento y atracción llegan aquí por `Lanzador3D._golpear` y los gases por `HechizoVivo`. Los empujes de `golpe` (hechizos con fuerza_golpe) y del golpe F no pasan por aquí: sus overrides no llaman a `push`.
func push(direccion: Vector3, fuerza: float, _suelo: bool = false) -> void:
	if muerto or fuerza <= 0.0 or Vector2(direccion.x, direccion.z).length() < 0.01:
		return
	if puede_resbalar():
		_empezar_resbalar(direccion)
	elif g_estado == "armado" or g_estado == "atacando" or g_estado == "expuesto":
		_ni_se_inmuta()


## ¿Puede ponerse a resbalar ahora? Sobre hielo y de pie (armado, golpeando o de rodillas); tumbado, levantándose o resbalando ya no.
func puede_resbalar() -> bool:
	if muerto or not (g_estado == "armado" or g_estado == "atacando" or g_estado == "expuesto"):
		return false
	return Terreno3D.helada(Terreno3D.celda_de(position))


## La cardinal más cercana a `d` (el hielo se desliza casilla a casilla).
static func cardinal(d: Vector3) -> Vector3:
	if absf(d.x) >= absf(d.z):
		return Vector3(signf(d.x) if d.x != 0.0 else 1.0, 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(d.z))


func _empezar_resbalar(direccion: Vector3) -> void:
	if g_estado == "atacando":
		_cortar_golpe()
	_res_dir = cardinal(direccion)
	_res_celdas = 0
	g_estado = "resbalando"
	_t_estado = 0.0
	moviendo = 0
	resbalones += 1
	texto_grande("¡Resbala!", Color(0.55, 0.95, 1.0), 0.28)
	_poner_clip("idle", false)
	PlayLog.event("golem_resbala", {"dir": [_res_dir.x, _res_dir.z], "celda": [Terreno3D.celda_de(position).x, Terreno3D.celda_de(position).y]})


## Un paso del resbalón de `paso` u desde `pos` en la cardinal `d`. Devuelve {pos, fin}: fin «» (sigue), «para» (contra algo: se queda a RADIO_TOPE del borde de la casilla), «agua» o «lava»
## (el centro ya entró en esa casilla). Es la MISMA cuenta para el resbalón real y para la previsión.
func _paso_resbalon(pos: Vector3, d: Vector3, paso: float) -> Dictionary:
	var c: Vector2i = Terreno3D.celda_de(pos)
	var cs: Vector2i = c + Vector2i(roundi(d.x), roundi(d.z))
	var nueva: Vector3 = pos + d * paso
	match _tipo_casilla(cs, pos):
		"tope":
			var limite: Vector3 = Terreno3D.centro_de(c) + d * (Terreno3D.casilla * 0.5 - RADIO_TOPE)
			var pasado: float = (nueva - limite).dot(d)
			if pasado >= 0.0:
				var antes: float = (pos - limite).dot(d)
				if antes >= 0.0:
					return {"pos": pos, "fin": "para"}
				return {"pos": nueva - d * pasado, "fin": "para"}
		"agua":
			if Terreno3D.celda_de(nueva) == cs:
				return {"pos": nueva, "fin": "agua"}
		"lava":
			if Terreno3D.celda_de(nueva) == cs:
				return {"pos": nueva, "fin": "lava"}
	return {"pos": nueva, "fin": ""}


## Qué es la casilla `cs` para un cuerpo que resbala desde `pos`: «lava», «agua» (honda, sin hielo), «hielo» (helada, pisable y libre) o «tope» (cualquier otra cosa).
func _tipo_casilla(cs: Vector2i, pos: Vector3) -> String:
	if _es_lava(cs):
		return "lava"
	if _es_agua_honda(cs):
		return "agua"
	if Terreno3D.helada(cs) and _puede_estar_desde(pos, Terreno3D.centro_de(cs, Terreno3D.y_pies(cs)), true, false) and not _ocupada(cs):
		return "hielo"
	return "tope"


func _es_lava(c: Vector2i) -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("lava3d"):
		if is_instance_valid(n) and n is Lava3D and (n as Lava3D).es_lava(c):
			return true
	return false


## ¿Hay otro cuerpo (enemigo vivo o la jugadora) en la casilla `c`?
func _ocupada(c: Vector2i) -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("combate3d"):
		if n != self and is_instance_valid(n) and n is Combate3D and not (n as Combate3D).muerto and Terreno3D.celda_de((n as Combate3D).position) == c:
			return true
	return jugador != null and is_instance_valid(jugador) and not jugador.muerto and Terreno3D.celda_de(jugador.position) == c


## Adónde llegaría resbalando en la cardinal `d` desde donde está, sin moverlo: {destino, recorrido (u), fin («para»|«agua»|«lava»|«»), celda (la del agua o la lava)}.
func simular_resbalon(d: Vector3) -> Dictionary:
	var pos: Vector3 = position
	var rec: float = 0.0
	var fin: String = ""
	var celda := Vector2i(-9999, -9999)
	for i in range(600):
		var r: Dictionary = _paso_resbalon(pos, d, PASO_PREVISION)
		var np: Vector3 = r["pos"]
		rec += Vector2(np.x - pos.x, np.z - pos.z).length()
		pos = np
		fin = String(r["fin"])
		if fin != "":
			if fin != "para":
				celda = Terreno3D.celda_de(pos)
			break
	return {"destino": pos, "recorrido": rec, "fin": fin, "celda": celda}


func _ia_resbalar(delta: float) -> void:
	var c0: Vector2i = Terreno3D.celda_de(position)
	var r: Dictionary = _paso_resbalon(position, _res_dir, VEL_RESBALE * delta)
	var np: Vector3 = r["pos"]
	position.x = np.x
	position.z = np.z
	if Terreno3D.celda_de(position) != c0:
		_res_celdas += 1
	match String(r["fin"]):
		"para":
			_parar_resbalon()
		"lava":
			_caer_en_lava(Terreno3D.celda_de(position))
		# «agua»: `_ajustar_al_suelo` (justo después de `_ia`) lo hunde en este mismo fotograma


## Se queda sobre el hielo: cae de espaldas (clip `resbalar`) y queda tumbado, con el núcleo a la vista.
func _parar_resbalon() -> void:
	g_estado = "tumbado"
	_t_estado = 0.0
	_nucleo_avisado = false
	exposiciones += 1
	_poner_clip("resbalar", true)
	PlayLog.event("golem_tumbado", {"celdas": _res_celdas})
	resbalo.emit(_res_celdas)
	expuesto.emit(true)


func _levantarse() -> void:
	g_estado = "levantando"
	_t_estado = 0.0
	_poner_clip("levantarse", true)


## Cae a la lava: muere abrasado (ver la cabecera). Como ahogarse, pero con otras reacciones.
func _caer_en_lava(c: Vector2i) -> void:
	if muerto:
		return
	_en_lava = true
	murio_en_lava = true
	_punto_hundido = Vector3(position.x, Terreno3D.y_pies(c), position.z)
	_empuje = Vector3.ZERO
	_morir(true)


func _hundir_modelo(duracion: float) -> void:
	if not _en_lava:
		super(duracion)
		return
	texto("¡Lava!", COLORES["fuego"], 0.1)
	duracion_hundimiento = maxf(duracion, 0.1)
	if Mundo3D.actual != null:
		Mundo3D.actual.avisar_impacto(_punto_hundido, "fuego", maxf(_radio_cuerpo(), 0.4) * 1.5)
	_reaccionar("prendido", _punto_hundido)
	if pj == null or not is_instance_valid(pj):
		queue_free()
		return
	var y_ini: float = pj.position.y
	var y_fin: float = minf(_punto_hundido.y, y_ini) - altura - PROFUNDIDAD_EXTRA_HUNDIDO
	var modelo: Pj3D = pj
	var tw: Tween = create_tween()
	tw.tween_method(func(p: float) -> void:
		if is_instance_valid(modelo):
			modelo.position.y = lerpf(y_ini, y_fin, perfil_hundimiento(p)),
		0.0, 1.0, maxf(duracion, 0.1))
	tw.tween_callback(func() -> void:
		if is_instance_valid(pj):
			pj.queue_free()
		queue_free())


func _morir(ahogado: bool = false) -> void:
	if muerto:
		return
	_hips_adv = 0.0
	_poner_brillo(0.0)                                       # el núcleo se apaga
	_nucleo_mats.clear()
	g_estado = "muerto"
	super(ahogado)


## =====================================================================================================
##  Fotograma e IA: persigue, golpea, queda expuesto
## =====================================================================================================

func _physics_process(delta: float) -> void:
	super(delta)
	if muerto or pj == null or not is_instance_valid(pj):
		return
	_actualizar_nucleo(delta)
	if _hips_adv > 0.0:
		# el clip `attack` adelanta el modelo con la cadera: como el NODO ya avanzó lo mismo, se le resta para que modelo, colisión y aviso estén en el mismo sitio
		pj.position -= Vector3(sin(pj.rotation.y), 0.0, cos(pj.rotation.y)) * _hips_adv


func _ia(delta: float) -> void:
	_t_estado += delta
	_t_texto = maxf(0.0, _t_texto - delta)
	match g_estado:
		"armado":
			_ia_armado(delta)
		"atacando":
			_ia_golpe(delta)
		"expuesto":
			moviendo = 0
			if _t_estado >= AnimacionesGolem.DUR_EXPUESTO:
				_volver_armado()
		"resbalando":
			_ia_resbalar(delta)
		"tumbado":
			if _t_estado >= T_TUMBADO:
				_levantarse()
		"levantando":
			if _t_estado >= AnimacionesGolem.DUR_LEVANTARSE:
				_volver_armado()


func _ia_armado(delta: float) -> void:
	if quieto or jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		objetivo = null
		moviendo = 0
		return
	var ve: bool = _ve(RADIO_DETECCION if objetivo == null else RADIO_SOLTAR)
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
	if objetivo == null:
		moviendo = 0
		return
	var meta: Vector3 = jugador.position if ve else ultima_pos
	var d: Vector3 = meta - position
	d.y = 0.0
	if d.length() > 0.05:
		mirada = d.normalized()
	if ve and d.length() <= RANGO:
		moviendo = 0
		if _descanso <= 0.0 and absf(jugador.position.y - position.y) < Terreno3D.ALTO_NIVEL * 0.9:
			_empezar_golpe()
		return
	if d.length() > 0.3:
		moviendo = 1
		_mover_paso(_dir_hacia(meta, delta) * VEL * delta, false, true)
	else:
		moviendo = 0


func _volver_armado() -> void:
	g_estado = "armado"
	_t_estado = 0.0
	_descanso = DESCANSO_TRAS_EXPONERSE
	moviendo = 0
	_nucleo_avisado = false
	pj.animacion_actual = ""                                 # `_animar` pondrá idle / walk


## Pone el clip `rol` desde el principio (una vez, o en bucle).
func _poner_clip(rol: String, una_vez: bool) -> void:
	if pj == null or not is_instance_valid(pj):
		return
	pj.set_velocidad_animacion(1.0)
	pj.animacion_actual = ""
	pj.jugar(rol, una_vez)


func _animar() -> void:
	if g_estado != "armado":
		return                                               # los demás estados ponen su clip al entrar en ellos
	pj.set_velocidad_animacion(1.0)
	pj.jugar("walk" if moviendo == 1 else "idle")
	if mirada.length() > 0.01 and (moviendo > 0 or objetivo != null):
		pj.mirar(mirada, 0.05)


## --- El golpe ---

func _empezar_golpe() -> void:
	var d: Vector3 = jugador.position - position
	d.y = 0.0
	_dir_ataque = d.normalized() if d.length() > 0.05 else mirada.normalized()
	mirada = _dir_ataque
	pj.mirar(_dir_ataque, 1.0)                               # de cara a ella de golpe: el avance del clip va por donde mira
	_pos_ataque0 = position
	_t_atq = 0.0
	_adv_hecho = 0.0
	_hips_adv = 0.0
	g_estado = "atacando"
	_t_estado = 0.0
	ataques += 1
	_quitar_aviso()
	if AVISAR_ATAQUES and mundo != null:
		_aviso = AvisoAtaque3D.rectangulo(mundo, _pos_ataque0 + _dir_ataque * ZONA_DESDE, _dir_ataque, ZONA_LARGO, ZONA_ANCHO * 0.5, AnimacionesGolem.INSTANTE_GOLPE, self, 0.0)
		avisos_dados += 1
	_poner_clip("attack", true)
	PlayLog.event("golem_ataca", {"efecto_en": AnimacionesGolem.INSTANTE_GOLPE})


func _ia_golpe(delta: float) -> void:
	moviendo = 0
	_t_atq += delta
	var t: float = minf(_t_atq, AnimacionesGolem.INSTANTE_GOLPE)
	var a: float = AnimacionesGolem.avance_golpe_en(t)
	_hips_adv = a
	var paso: float = a - _adv_hecho
	if paso > 0.0:
		var destino: Vector3 = position + _dir_ataque * paso
		if _puede_estar(destino):
			position.x = destino.x
			position.z = destino.z
			_adv_hecho = a
	if _t_atq >= AnimacionesGolem.INSTANTE_GOLPE:
		_impacto_golpe()


## ¿Cae `p` dentro de la zona del golpe? La misma que dibuja el aviso.
func en_zona_golpe(p: Vector3) -> bool:
	var rel := Vector3(p.x - _pos_ataque0.x, 0.0, p.z - _pos_ataque0.z)
	var delante: float = rel.dot(_dir_ataque)
	var lado: float = absf(rel.dot(Vector3(-_dir_ataque.z, 0.0, _dir_ataque.x)))
	return delante >= ZONA_DESDE and delante <= ZONA_DESDE + ZONA_LARGO and lado <= ZONA_ANCHO * 0.5


## Los puños llegan al suelo: daño y empuje a quien esté en la zona, y queda de rodillas con el núcleo a la vista.
func _impacto_golpe() -> void:
	_aviso = null                                            # el aviso acaba solo en este instante
	var dentro: bool = false
	if jugador != null and is_instance_valid(jugador) and not jugador.muerto:
		dentro = en_zona_golpe(jugador.position) and absf(jugador.position.y - position.y) < Terreno3D.ALTO_NIVEL * 0.9
		if dentro:
			var antes: float = jugador.vida
			jugador.recibir_dano(DANO)
			if jugador.vida < antes:
				var fuera: Vector3 = jugador.position - position
				fuera.y = 0.0
				jugador.push(fuera.normalized() if fuera.length() > 0.05 else _dir_ataque, EMPUJE_GOLPE)
				golpes_dados += 1
	Sfx3D.play(self, "derrumbe")
	var suelo := Vector3(_pos_ataque0.x, position.y, _pos_ataque0.z) + _dir_ataque * (ZONA_DESDE + ZONA_LARGO * 0.4)
	if not Sensacion3D.mazazo(self, suelo, _dir_ataque):    # gamefeel: polvo bajo los puños y temblor suave
		var fx: Variant = mundo.get("_fx") if mundo != null else null
		if fx is Vfx3D:
			(fx as Vfx3D).temblor(0.35)
	PlayLog.event("golem_golpe", {"acierta": dentro, "dano": DANO if dentro else 0.0})
	_exponer()


func _exponer() -> void:
	_hips_adv = 0.0
	g_estado = "expuesto"
	_t_estado = 0.0
	_nucleo_avisado = false
	exposiciones += 1
	_poner_clip("expuesto", true)
	expuesto.emit(false)


## Resbalar (o morir) a medio golpe: el aviso se quita y el modelo vuelve a su sitio.
func _cortar_golpe() -> void:
	_quitar_aviso()
	_hips_adv = 0.0
