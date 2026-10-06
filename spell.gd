extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0

## Cuánto dura un hechizo "quieto" (pilar, barrera, nube de vapor)
## antes de desaparecer solo, ya que a diferencia de una flecha nunca
## sale de la pantalla por sí mismo. Lo pone SpellFactory.cast() ANTES
## de meter el hechizo en la escena, porque _ready() ya lo necesita.
var stationary_lifetime: float = 0.6
var _recorrido: float = 0.0

# En vez de guardar solo un color y un daño sueltos, el hechizo
# lleva la ficha completa del elemento (RuneData). Así, cuando
# choque con algo, puede pasarle TODAS sus propiedades de golpe,
# no solo el daño.
var rune_data: RuneData = null

## Multiplicador de potencia que le pone la receta (el sello de
## aumento). Escala lo que se ve; el daño ya viene multiplicado en el
## RuneData duplicado, porque tocarlo aquí no serviría: quien lo lee es
## el objeto golpeado, no el hechizo.
## Es una propiedad con setter y no una variable a secas por la misma
## razón que ya nos mordió con `direction`: la receta pone la potencia
## DESPUÉS de crear el hechizo, así que calcular el tamaño en cualquier
## otro sitio llegaría tarde. Aquí, se aplique cuando se aplique, el
## tamaño va detrás. La raíz cuadrada es para que doblar la potencia no
## cuadruplique el área que ocupa en pantalla.
var power: float = 1.0:
	set(value):
		power = value
		scale = Vector2.ONE * sqrt(maxf(power, 0.01))
		# Y la hoja de la intensidad, por la MISMA razón que el tamaño:
		# set_rune_data() ya eligió una cuando aún no se sabía la
		# potencia, así que hay que volver a preguntar ahora que sí.
		_refresh_vfx()

var is_stationary: bool = false

## --- Lo que permanece, atraviesa ---
## Un hechizo normal muere contra lo primero que reacciona. Uno que
## lleva levitación no: un tornado no se deshace contra el primer
## arbusto, lo arrastra y sigue. No es una regla nueva, es leer el
## parámetro de permanencia que ya pone la receta.
var piercing: bool = false

## Si ya recogió un elemento por el camino (ver _try_carry).
var carried: bool = false

## Quién lo lanzó (el Spellcaster). El viento no empuja a su propio lanzador:
## el hechizo nace encima de él y, sin esto, lo lanzaba hacia atrás al soltarlo.
var lanzador: Node = null

## --- LA BARRERA QUE AVANZA ---
## Barrera + flecha: una barrera (un hechizo QUIETO, sin dirección de vuelo) con
## velocidad. Sus hitboxes se desplazan juntos y aplican su elemento a lo que
## cruzan. Lo pone la receta (ver SpellRecipe._manifest).
##   velocidad    cuánto y hacia dónde se desplaza (ZERO = barrera quieta)
##   vida_maxima  segundos que vive en vuelo antes de desaparecer (0 = sin tope);
##                lo usa una flecha de trazo flojo, que llega menos lejos
var velocidad: Vector2 = Vector2.ZERO
var vida_maxima: float = 0.0

## Niveles a los que está (levitación). Un proyectil más alto que la barrera pasa por encima.
var altura: int = 0

## --- REBOTE, REFLEJO y ATRACCIÓN (ver Sigils.FORM) ---
##   rebotes   cuántas veces rebota un proyectil (en barreras y en lo que golpea)
##   refleja   una barrera que devuelve los proyectiles en vez de pararlos
##   atrae     lo que toca es TIRADO hacia un punto (ver _centro_atraccion)
var rebotes: int = 0
var refleja: bool = false
var atrae: bool = false
const REBOTE_PAUSA: float = 0.15
var _ultimo_rebote: float = -1.0

## Lo que levita te sigue: a quién y a qué distancia de él (levitación sola).
var sigue: Node2D = null
var sigue_offset: Vector2 = Vector2.ZERO

## --- LAS BARRERAS BLOQUEAN PROYECTILES ---
## Un hechizo con `bloquea` lleva una ZONA de bloqueo más ancha que su hitbox
## (una flecha cabría entre dos hitboxes separados una casilla). Los proyectiles
## (las flechas del arquero, los hechizos que vuelan, los haces) miran esa capa y
## paran contra ella.
const BLOQUEO_CAPA: int = 128
const BLOQUEO_RADIO: float = 38.0
var bloquea: bool = false

## Cuánto empuja el viento. Es fuerza, no distancia: quien la recibe la
## va gastando, así que empujar a alguien que anda contra el viento
## cuesta más que empujar a alguien parado.
const PUSH_FORCE: float = 320.0

## Velocidad de reproducción del efecto visual. Las tiras se muestrearon
## desde animaciones de 28 FPS quedándonos con ~18 fotogramas, así que a
## 24 FPS se ven a un ritmo parecido al original.
const VFX_FPS: float = 24.0
var vfx_time: float = 0.0

## --- LO QUE DICE EL SELLO (y no el elemento) ---
##
## Dos canales que no se pisan. El ELEMENTO pone el material: color, hoja
## de animación, luz. El SELLO pone la forma, y la dibuja SpellForm.
##   - Lo que VIAJA lleva una cola: un hechizo que vuela acompaña a su forma.
##   - Lo que se QUEDA no dibuja nada por sí mismo: su forma es UN campo
##     para todo el grupo, que crea SpellRecipe. Una barrera son varios
##     hechizos (cada uno con su hitbox) pero tiene que verse como una
##     cosa, y eso no se puede decidir desde dentro de uno de ellos.
var _age: float = 0.0
var _form: SpellForm = null

## --- EL RAYO ES UN HAZ ---
## Un elemento con `beam` no viaja: existe de golpe entre quien lo lanza y lo
## primero que golpea (ver SpellBeam). El sello sigue mandando: si el hechizo
## es quieto (barrera, pilar) el rayo se queda como campo, como cualquiera.
const BEAM_RANGE: float = 480.0
## Sube de 16 a 48: el suelo ya no corta el haz pero SÍ cuenta como golpe, y
## un haz largo cruza muchas losas antes de llegar a un objetivo.
const BEAM_MAX_HITS: int = 48
var _beam: bool = false

## Su aspecto lo dibuja el campo de la barrera (SpellForm + SpellMaterial): un
## hechizo cubierto es solo un hitbox, sin sprite. Es lo que evita "seis fuegos".
var campo: SpellForm = null   ## el campo de barrera del que este hechizo es hitbox (si lo es)

var cubierto: bool = false:
	set(value):
		cubierto = value
		if value:
			var vfx := get_node_or_null("Vfx")
			if vfx:
				vfx.hide()
			var fondo := get_node_or_null("ColorRect")
			if fondo:
				fondo.hide()


const IMPACTO := preload("res://spell_impact.gd")


func _ready() -> void:
	area_entered.connect(_on_area_entered)

	# El viento tiene que poder empujar CUERPOS (el jugador, un enemigo),
	# no solo áreas. Es la única razón por la que un hechizo mira los
	# cuerpos: para todo lo demás sigue hablando solo con áreas y su
	# contrato on_spell_hit.
	body_entered.connect(_on_body_entered)

	# Se decide UNA vez, al nacer, y se guarda. Antes esto se consultaba
	# leyendo `direction` en cada sitio, lo cual era frágil: bastaba con
	# que alguien asignase la dirección un instante tarde para que el
	# hechizo se creyera quieto siendo una flecha.
	is_stationary = direction == Vector2.ZERO

	# Lo que vuela ve también la capa de las barreras.
	if not is_stationary:
		collision_mask |= BLOQUEO_CAPA

	if is_stationary:
		_pop_in()
		# Un Area2D solo avisa con "area_entered" cuando algo ENTRA de
		# nuevo en su zona. Si el pilar/barrera/vapor nace ya solapado
		# con un bloque, ese aviso nunca llegaría, así que lo miramos a
		# mano en cuanto la física haya procesado un ciclo.
		_check_initial_overlaps()
		get_tree().create_timer(stationary_lifetime).timeout.connect(queue_free)
	elif piercing:
		# Los que vuelan normalmente mueren al chocar o al salirse de la
		# pantalla. Uno que atraviesa no hace ninguna de las dos cosas a
		# tiempo, así que necesita su propio plazo o se queda dando
		# vueltas por el mundo para siempre.
		get_tree().create_timer(stationary_lifetime).timeout.connect(queue_free)


## Movimiento del hechizo (una flecha). Si es quieto, no se mueve, pero
## su efecto visual sigue animándose igualmente.
func _process(delta: float) -> void:
	if _beam:
		return
	_animate_vfx(delta)
	_age += delta

	if vida_maxima > 0.0 and not is_stationary and _age >= vida_maxima:
		queue_free()
		return

	if is_stationary:
		# Una barrera con velocidad se desplaza; una quieta, no.
		if velocidad != Vector2.ZERO:
			position += velocidad * delta
		if is_instance_valid(sigue):
			global_position = Sigils.flotar(global_position, sigue.global_position + sigue_offset, delta)
		# Lo quieto se apaga avisando: el último tramo de su vida se
		# desvanece, así que se ve venir que se acaba.
		if stationary_lifetime > 0.0:
			modulate.a = 1.0 - smoothstep(0.7, 1.0, _age / stationary_lifetime)
		return

	position += direction * speed * delta

	# Si se aleja mucho, se destruye para no acumular basura. Se mide lo RECORRIDO, no la
	# distancia al origen de la escena: en los mapas grandes (Mundo, Test 2) media mitad del
	# mapa queda a más de 2000 px del origen y los hechizos morían nada más salir.
	_recorrido += speed * delta
	if _recorrido > 2000.0:
		queue_free()


## Asigna el elemento de este hechizo y con él su aspecto. Fíjate en que
## este código no sabe qué elemento es: solo pregunta a la ficha si trae
## animación. El día que añadas un elemento nuevo con su tira, se verá
## animado aquí sin tocar esta función.
func set_rune_data(data: RuneData) -> void:
	rune_data = data

	# El elemento se configura a sí mismo en el sprite (ver
	# RuneData.setup_sprite) y nos dice si tenía animación o no.
	# El sonido del elemento sale de aquí y no de la receta: así suena
	# igual lo lance el jugador, lo propague el viento o lo escupa una
	# charca electrificada. El antirráfaga de Sfx se encarga de que un
	# corro de 24 manifestaciones suene UNA vez.
	Sfx.for_element(self, data)

	# Un haz no lleva sprite ni cola: lo dibuja SpellBeam. Se dispara diferido
	# porque la receta pone `power` y `piercing` DESPUÉS de crear el hechizo.
	if data.beam and direction != Vector2.ZERO:
		_beam = true
		$Vfx.hide()
		$ColorRect.hide()
		call_deferred("_fire_beam")
		return

	# MODO SILUETA: solo queda la forma del sello. Sin sprite y sin luz, para
	# poder juzgar la silueta sin que el material la ayude. El sonido se
	# queda: no es visual.
	if SpellForm.silhouette:
		$Vfx.hide()
		$ColorRect.hide()
		_build_form_vfx()
		return

	# CADA HECHIZO LLEVA SU LUZ, y el color lo pone el propio elemento
	# (RuneData.color), no una tabla aparte: un elemento nuevo alumbrará
	# del color que le toca sin que nadie lo apunte en ningún sitio.
	#
	# A oscuras esto deja de ser un adorno: una bola de fuego cruzando
	# una cueva es, literalmente, por dónde ves.
	Glow.attach(self, data.color, 110.0, 0.9)

	if data.setup_sprite($Vfx, power):
		$Vfx.show()
		$ColorRect.hide()
	else:
		# Elementos sin animación propia (el vapor) siguen usando el
		# cuadrado de color, que al menos transmite de qué elemento son.
		$ColorRect.color = data.color

	# Un proyectil apunta hacia donde va. La llama es la de siempre, girada:
	# "arriba" de la hoja queda detrás del hechizo (ver RuneData).
	if data.orient_to_travel and direction != Vector2.ZERO:
		$Vfx.rotation = direction.angle() - PI * 0.5
	else:
		$Vfx.rotation = 0.0

	_build_form_vfx()

	if cubierto:
		$Vfx.hide()
		$ColorRect.hide()


## La flecha que acompaña a lo que vuela. Se reconstruye el color cuando
## cambia el elemento (el viento que se lleva fuego cambia a mitad de
## camino) pero el nodo es el mismo, para no perder la cola ya dibujada.
func _build_form_vfx() -> void:
	if rune_data == null or is_stationary:
		return   # lo quieto lo dibuja el campo de SpellRecipe

	if is_instance_valid(_form):
		_form.color = rune_data.color
		_form._perfil = SpellMaterial.perfil_de(rune_data)
		return

	_form = SpellForm.arrow(self, direction, rune_data.color)
	_form._perfil = SpellMaterial.perfil_de(rune_data)


## Lo quieto brota, no aparece. Es la mitad de la diferencia entre "se ha
## puesto aquí" y "ha estado siempre".
func _pop_in() -> void:
	var vfx := $Vfx as Sprite2D
	var base: Vector2 = vfx.scale
	vfx.scale = base * 0.3
	create_tween().tween_property(vfx, "scale", base, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Vuelve a elegir la hoja ahora que se sabe la potencia.
##
## Se protege con get_node_or_null porque el orden en que llegan el
## elemento y la potencia no está garantizado: si alguien pusiera la
## potencia antes de meter el hechizo en el árbol, $Vfx todavía no
## existiría. Callar aquí es correcto — set_rune_data vendrá después y
## hará el trabajo con la potencia ya puesta.
func _refresh_vfx() -> void:
	if rune_data == null or SpellForm.silhouette or _beam or cubierto:
		return
	var vfx := get_node_or_null("Vfx") as Sprite2D
	if vfx == null:
		return
	if rune_data.setup_sprite(vfx, power):
		vfx.show()
		var fondo := get_node_or_null("ColorRect")
		if fondo:
			fondo.hide()


func _animate_vfx(delta: float) -> void:
	if not $Vfx.visible or rune_data == null:
		return

	# Los fotogramas son los de LA HOJA QUE TOCA, no los de la normal: el
	# remolino del fuego amplificado podría tener otra cuenta, y usar la
	# de la hoja base dejaría celdas sin recorrer o recorrería celdas
	# vacías, que se ven como un parpadeo.
	var cuantos: int = rune_data.frames_for(power)
	if cuantos <= 0:
		return

	vfx_time += delta
	# El módulo se hace sobre los fotogramas REALES, no sobre las celdas
	# de la rejilla: la última fila puede tener celdas vacías y saltarían
	# como parpadeos si las recorriéramos.
	$Vfx.frame = int(vfx_time * VFX_FPS) % cuantos


## `await get_tree().physics_frame` espera a que termine el siguiente
## ciclo de física, que es cuando Godot ya sabe qué áreas se solapan
## con esta. Antes de eso, get_overlapping_areas() devolvería vacío.
func _check_initial_overlaps() -> void:
	await get_tree().physics_frame

	if not is_inside_tree():
		return

	for area in get_overlapping_areas():
		_hit(area)


## Cuando el hechizo toca cualquier Area2D del mundo (enemigo, agua,
## una puerta...), le avisamos usando un "contrato" común: si ese
## objeto sabe reaccionar a un hechizo (tiene la función on_spell_hit),
## se lo pasamos junto con la dirección del hechizo (útil para el
## viento, que empuja/propaga cosas en esa dirección) y dejamos que
## decida qué hacer. El hechizo no necesita saber si era un enemigo o
## un bloque de agua.
func _on_area_entered(area: Area2D) -> void:
	if _beam:
		return   # el haz ya resolvió sus golpes con un rayo de física

	# Una barrera para a quien vuela contra ella.
	if area.has_method("bloquea_proyectiles") and area.bloquea_proyectiles(self):
		if not is_stationary:
			var rebotado: bool = false
			if area.has_method("refleja_a") and area.refleja_a(self):
				rebotado = _rebotar(area, false)   # una barrera que refleja
			elif rebotes > 0:
				rebotado = _rebotar(area, true)    # un proyectil que rebota
			if not rebotado:
				_impact_vfx()
				queue_free()
		return

	var antes: bool = carried
	var reacted: bool = _hit(area)

	# Un muro de FUEGO que cruza agua se apaga entero: el agua gana. Es lo que
	# impide cruzar un canal con un muro de llamas.
	if SpellFactory.agua_apaga_muros and velocidad != Vector2.ZERO \
			and rune_data != null and rune_data.tags.has("fuego") \
			and area.is_in_group("water_blocks"):
		if is_instance_valid(campo):
			campo.apagar()
		else:
			queue_free()
		return
	# El suelo reacciona pero no detiene: ni mata a la flecha ni suelta
	# chispazo de impacto. Sin esto, con el suelo hecho de bloques, una flecha
	# moría contra la losa donde nació.
	if reacted and _passes_through(area):
		reacted = false
	# Recoger algo por el camino no es chocar: el viento que cruza una llama se
	# lleva la llama y SIGUE (ver _try_carry). Sin esto moría contra la propia
	# fuente y el fuego nunca llegaba a ningún sitio.
	var recogio: bool = carried and not antes

	# El chispazo de impacto es de quien VUELA, no de quien se queda. Un
	# pilar o una barrera ya tienen su propio remolino animado sin parar;
	# ponerles además un estallido cada vez que algo los toca sería ruido
	# encima de ruido. Una flecha, en cambio, solo golpea una vez (o unas
	# pocas si atraviesa), así que ahí sí se nota y se lee como impacto.
	if reacted and not is_stationary and not recogio:
		_impact_vfx()

	# Una flecha desaparece al golpear algo QUE REACCIONA, no contra
	# cualquier área que se cruce. La diferencia importa: el jugador
	# lleva un Area2D en los pies (para saber sobre qué está subido) y el
	# hechizo nace justo encima de ella. Con la regla ingenua, toda
	# flecha se autodestruía contra los pies de quien la lanzaba antes de
	# recorrer un solo píxel.
	#
	# Un pilar, una barrera o una nube de vapor no desaparecen al primer
	# impacto: se quedan su tiempo y pueden afectar a varias cosas.
	if reacted and not is_stationary and not piercing and not recogio:
		if rebotes > 0 and _rebotar(area, true):
			return
		queue_free()


## REBOTAR: el proyectil sale reflejado contra la normal del sitio donde chocó (el
## vector que va del centro de lo que golpeó hasta él). Devuelve true si rebotó (o si
## ya estaba rebotando: un corro son varias zonas solapadas y avisan a la vez), y
## false si no hay nada que reflejar (ya se alejaba), para que muera como siempre.
func _rebotar(area: Node2D, gasta: bool) -> bool:
	if _age - _ultimo_rebote < REBOTE_PAUSA:
		return true

	var normal: Vector2 = global_position - area.global_position
	normal = normal.normalized() if normal.length() > 1.0 else -direction
	if direction.dot(normal) >= 0.0:
		return false

	_ultimo_rebote = _age
	if gasta:
		rebotes -= 1
	direction = direction.bounce(normal).normalized()
	position += direction * 6.0

	# El aspecto sigue a la nueva dirección.
	if is_instance_valid(_form):
		_form._dir = direction
	if rune_data != null and rune_data.orient_to_travel and has_node("Vfx"):
		$Vfx.rotation = direction.angle() - PI * 0.5
	_impact_vfx()
	return true


## EL HAZ: un rayo de física del lanzador hacia delante, que recorre hasta
## BEAM_RANGE y golpea lo primero que REACCIONA (o todo, si atraviesa). Lo que
## no reacciona (los pies del propio jugador, por ejemplo) se ignora, igual
## que hace una flecha.
func _fire_beam() -> void:
	if not is_inside_tree() or rune_data == null:
		return


	var origen: Vector2 = global_position
	var dir: Vector2 = direction.normalized()
	var fin: Vector2 = origen + dir * BEAM_RANGE
	var espacio := get_world_2d().direct_space_state
	var excluir: Array[RID] = [get_rid()]
	var golpeo: bool = false

	for i in range(BEAM_MAX_HITS):
		var q := PhysicsRayQueryParameters2D.create(origen, origen + dir * BEAM_RANGE, collision_mask)
		q.collide_with_areas = true
		q.collide_with_bodies = false
		q.hit_from_inside = true
		q.exclude = excluir
		var r: Dictionary = espacio.intersect_ray(q)
		if r.is_empty():
			break

		var area := r.get("collider") as Area2D
		excluir.append(r["rid"])

		# Una barrera corta el haz: acaba ahí.
		if area != null and area.has_method("bloquea_proyectiles") \
				and area.bloquea_proyectiles(self):
			fin = r["position"]
			golpeo = true
			break

		if area == null or not area.has_method("on_spell_hit"):
			continue

		global_position = r["position"]   # el punto de contacto, para quien lo lea
		_hit(area)
		# El suelo reacciona (moja, prende el charco) pero no corta el haz.
		if _passes_through(area):
			continue
		golpeo = true
		fin = r["position"]
		if not piercing:
			break

	SpellBeam.fire(get_tree().current_scene, origen, fin, rune_data, sqrt(maxf(power, 0.01)))
	if golpeo:
		global_position = fin
		_impact_vfx()
	queue_free()


## Chispas del color del elemento + un fogonazo de luz a juego, en el
## sitio exacto donde el hechizo estaba cuando golpeó. Usa Glow.flash(),
## que ya existía pensado para justo esto pero nadie lo llamaba todavía.
func _impact_vfx() -> void:
	if rune_data == null or SpellForm.silhouette:
		return
	BlockFx.spell_impact(self, rune_data.color)
	Glow.flash(self, rune_data.color, 90.0, 1.5, 0.3)
	var imp = IMPACTO.new()
	imp.iniciar(rune_data, direction)
	get_tree().current_scene.add_child(imp)
	imp.global_position = global_position


## EL VIENTO EMPUJA.
##
## Y ahí está lo que lo hace un arma: no hace falta que el viento haga
## daño si puede tirarte por un borde. El empujón es la mitad del
## hechizo; la otra mitad la pone el nivel.
##
## Se pregunta por el método, no por el tipo: cualquier cosa que sepa
## recibir un empujón lo recibirá, sin que el viento tenga una lista de
## qué cosas existen. Es el mismo trato que on_spell_hit.
func _on_body_entered(body: Node) -> void:
	_try_push(body)


## Se llama desde los DOS caminos —cuerpos y áreas— porque el mundo tiene
## las dos cosas: el jugador es un CharacterBody2D pero el arquero es un
## Area2D. Preguntar por el método y no por el tipo hace que dé igual.
func _try_push(nodo: Node) -> void:
	if rune_data == null:
		return
	var es_viento: bool = rune_data.tags.has("viento")
	if not es_viento and not atrae:
		return
	if not nodo.has_method("push"):
		return
	if _es_lanzador(nodo):
		return

	# ATRACCIÓN: tira en vez de apartar. Con viento es tan fuerte como el empujón;
	# con otro elemento, algo menos (lo suyo es el elemento, no el tirón).
	if atrae:
		var tirar: Vector2 = (_centro_atraccion() - nodo.global_position).normalized()
		if tirar != Vector2.ZERO:
			nodo.push(tirar, PUSH_FORCE * power * (1.0 if es_viento else 0.7))
		return

	var empuje: Vector2 = _dir_efecto()
	if empuje == Vector2.ZERO:
		# Un remolino quieto tira de lo que tiene cerca hacia fuera: no
		# tiene dirección propia, así que usa la que va de él al objeto.
		empuje = (nodo.global_position - global_position).normalized()

	nodo.push(empuje, PUSH_FORCE * power)


## Hacia dónde tira la atracción: lo que VIAJA (una flecha, una barrera que avanza)
## tira hacia quien lo lanzó, como un gancho; lo que se QUEDA tira hacia el centro de
## su propia forma, como un vórtice.
func _centro_atraccion() -> Vector2:
	if (not is_stationary or velocidad != Vector2.ZERO) and is_instance_valid(lanzador):
		return lanzador.global_position
	if is_instance_valid(campo):
		return campo.global_position
	return global_position


## LO QUE PUEDE LLEVARSE EL VIENTO DE AQUÍ. Un hechizo quieto (una barrera de
## fuego, de agua, de rayo) ofrece su elemento igual que lo ofrece un bloque en
## llamas: el viento que la cruza se tiñe de él. El viento no ofrece nada (no
## se tiñe de sí mismo).
func carried_element() -> RuneData:
	if not is_stationary or rune_data == null or rune_data.tags.has("viento"):
		return null
	return rune_data


## Hacia dónde empuja o propaga lo que toca este hechizo: su dirección de vuelo, o
## la de su avance si es una barrera que se desplaza. Quieta, ninguna.
func _dir_efecto() -> Vector2:
	if direction != Vector2.ZERO:
		return direction
	return velocidad.normalized()


## Lo llama la receta en lo que es una barrera: crea su zona de bloqueo.
func hacer_barrera() -> void:
	bloquea = true
	var zona := ZonaBloqueo.new()
	zona.dueno = self
	zona.collision_layer = BLOQUEO_CAPA
	zona.collision_mask = 0
	zona.monitoring = false
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = BLOQUEO_RADIO
	forma.shape = circulo
	zona.add_child(forma)
	add_child(zona)


## ¿Para esta barrera a ESTE proyectil? Hoy para a todos. Es el único sitio
## donde escribir una excepción (un elemento que atraviesa, los proyectiles del
## propio lanzador, un glifo que la deja pasar...).
func bloquea_a(proyectil: Node) -> bool:
	# Lo que levita pasa por encima de una barrera más baja que ello. Una flecha
	# enemiga no tiene altura, así que se detiene como siempre.
	if proyectil != null and "altura" in proyectil and int(proyectil.altura) > altura:
		return false
	return bloquea


## ¿Esta barrera DEVUELVE al proyectil en vez de pararlo? (glifo rebote)
func refleja_a(proyectil: Node) -> bool:
	return refleja and bloquea_a(proyectil)


## La zona de bloqueo de una barrera: un Area2D en su propia capa, que solo ven los
## proyectiles. Responde por su dueño.
class ZonaBloqueo extends Area2D:
	var dueno = null

	func refleja_a(proyectil: Node = null) -> bool:
		return is_instance_valid(dueno) and dueno.refleja_a(proyectil)

	func bloquea_proyectiles(proyectil: Node = null) -> bool:
		return is_instance_valid(dueno) and dueno.bloquea_a(proyectil)


## El lanzador es el propio Spellcaster o el cuerpo del que cuelga (el jugador).
func _es_lanzador(nodo: Node) -> bool:
	if lanzador == null or not is_instance_valid(lanzador):
		return false
	return nodo == lanzador or nodo == lanzador.get_parent()


## ¿Deja este objeto pasar a un hechizo que vuela? Por contrato, igual que
## on_spell_hit: quien sea una superficie (suelo, placa) declara
## spell_passes_through() y ya. Lo que no lo declara es un objetivo y
## detiene al hechizo, que es el comportamiento de siempre.
func _passes_through(area: Area2D) -> bool:
	if area.has_method("spell_passes_through") and area.spell_passes_through():
		return true
	# Contrato aparte para lo que deja pasar solo a ALGUNOS hechizos (el agua
	# deja volar por encima al viento y a lo que el viento lleva).
	return area.has_method("spell_flies_over") and area.spell_flies_over(rune_data, carried)


## Devuelve si el área golpeada sabía reaccionar a un hechizo.
func _hit(area: Area2D) -> bool:
	# Un muro aplica su elemento UNA vez a cada cosa que cruza, aunque lo toquen
	# varios de sus hitboxes a la vez: si no, un enemigo recibiría el daño triple.
	if velocidad != Vector2.ZERO and is_instance_valid(campo):
		var id: int = area.get_instance_id()
		if campo.golpeados.has(id):
			return false
		campo.golpeados[id] = true

	_try_carry(area)
	_try_push(area)

	if not area.has_method("on_spell_hit"):
		return false

	# ¿Esto provoca una reacción DE VERDAD? Si el objeto lo sabe decir
	# (spell_reacts), se le cree: un fuego que toca otro fuego ya encendido, o un
	# viento que toca un tocón apagado, no cambian nada, y lo que no cambia nada se
	# ignora: el hechizo sigue su camino en vez de morir ahí. Quien no lo declara
	# reacciona siempre, como hasta ahora.
	var reacciona: bool = true
	if area.has_method("spell_reacts"):
		reacciona = bool(area.spell_reacts(rune_data, _dir_efecto()))

	SpellFactory.ultimo_impacto = global_position
	area.on_spell_hit(rune_data, _dir_efecto())
	SpellFactory.ultimo_impacto = Vector2.INF
	return reacciona


## EL VIENTO SE LLEVA LO QUE TOCA.
##
## Un hechizo de viento que cruza fuego deja de ser viento a secas: pasa
## a ser viento CARGADO de fuego, con su color, su daño y sus etiquetas.
## Sigue volando, pero ahora prende lo que encuentra más allá.
##
## No es un caso especial del viento contra el fuego: el viento pregunta
## "¿llevas algo que se pueda arrastrar?" y el bloque responde. Un
## bloque futuro que devuelva veneno hará viento venenoso sin que ni el
## viento ni el veneno se enteren el uno del otro.
##
## Solo se carga UNA vez. Si no, al cruzar una hoguera larga iría
## cambiando de elemento casilla a casilla y no se leería nada.
func _try_carry(area: Area2D) -> void:
	if rune_data == null or carried:
		return
	if not rune_data.tags.has("viento"):
		return
	if not area.has_method("carried_element"):
		return

	var cargado: RuneData = area.carried_element()
	if cargado == null:
		return

	carried = true
	set_rune_data(cargado)
	# Una barrera de viento que toca fuego es UNA barrera teñida de fuego, no
	# un hitbox suelto: el campo avisa a los demás y cambia su aspecto.
	if is_stationary and is_instance_valid(campo):
		campo.tomar(cargado, self)
	print("El viento arrastra ", cargado.display_name)
