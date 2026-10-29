class_name Sensacion3D
extends RefCounted

## GAMEFEEL, LOTE 1 (28/10, Pablo: «mejorar el gamefeel lanzando los hechizos, también contra los enemigos»). Dueño: Juego.
##
## Lo que hace que lanzar y golpear se SIENTA, en un solo sitio y con cada número a mano (`static var`, como las de `Combate3D`: un laboratorio o el playtest las cambia en vivo):
##   · al DISPARAR (`disparo`, lo llama `Lanzador3D._disparar`): la jugadora retrocede un poco, la cámara da un golpe de zoom corto, la mano destella del color del elemento y suena
##     la salida común (`lanzar_salida`) bajo el sonido del elemento;
##   · al NO PODER lanzar (`no_puedes`, lo llama `Lanzador3D` en cada negativa): un golpe seco, la página tiembla en roja en el HUD y el cursor parpadea en rojo;
##   · el HITSTOP de un golpe a un enemigo, proporcional al daño (`hitstop_de`) y COMPARTIDO: la jugadora se congela también una fracción (`Jugador3D.hitstop`);
##   · al RECIBIR daño la jugadora (`dano_recibido`): viñeta roja, temblor y un hitstop corto.
## LOTE 2 (29/10, Pablo: «implementa lote 2»):
##   · ARRANQUE del proyectil (`factor_arranque`, lo usa `HechizoVivo._physics_process`): sale rápido y frena hasta su velocidad; al acabar el arranque ha recorrido lo MISMO que
##     sin él (la curva suma cero), así que alcance, trayectoria y llegada a lo lejos no cambian. El dibujo se estira en la dirección del vuelo mientras va rápido (`estiron`)
##     y suelta una estela corta de su color (`VfxElemento3D.Proyectil`);
##   · POLVO al ser empujado y al caer (`polvo`): goblins empujados y su caída del vuelo, el limo al aterrizar, la jugadora empujada o al caer de alto;
##   · ESQUIVA PERFECTA vistosa (`esquiva_perfecta`, la llama `Jugador3D._esquiva_con_premio`): la pantalla se desatura y se tiñe de violeta mientras dura el tiempo bruja,
##     ella deja una estela de copias violetas y suena un «tic» de reloj (y un «toc» al acabar);
##   · MUERTE con peso (`muerte`, la llama `_morir` de cada enemigo): temblor; si era el último de la sala, cámara lenta y golpe de zoom. El oro salta al caer y se imanta
##     hacia ella (`Combate3D.Botin3D`);
##   · REACCIONES grandes con su momento (`reaccion_grande`): vapor, descarga, congelado sobre mojado, hundido, el limo que crece, el núcleo del gólem, el gólem que
##     resbala: hitstop del MUNDO (todos los enemigos y ella), rótulo grande, temblor y sonido propio.
## LOTE 4 (29/10, Pablo: «sí, lote 4», tras docs/PROMPT_RESUMEN_GAMEFEEL.md §5):
##   · el CUERPO que encaja un golpe suena (`golpe_enemigo`, desde `Combate3D._impacto_visual`; `snd_golpe` por familia: carne, piedra, limo) y el limo tiene su muerte;
##   · la JUGADORA suena al encajar un golpe (`dano_recibido`) y, con la vida baja, le late el corazón (`DirectorSensacion`, bucle `latido` que sube con lo que falta);
##   · la VOLTERETA levanta polvo y suena (`voltereta`), y cuando vuelve a estar lista (ella o una página) suena un clic y la página destella (`recarga_lista`);
##   · la CÁMARA se ADELANTA hacia donde va y hacia donde apunta (`adelanto_actual`, lo calcula el director y lo suma la maqueta al foco);
##   · ANDAR arranca y frena en un suspiro (`velocidad_suelo`: aceleración y frenada, lo usa `Jugador3D._process` fuera del hielo);
##   · un proyectil que se PARA CONTRA EL MUNDO (pared, bloque, barrera; el suelo, a medias) se nota (`impacto_mundo`, desde `HechizoVivo._terminar`);
##   · mientras se MANTIENE 1/2/3 (o se apunta) un aro del color del elemento se cierra en la mano y un zumbido sube de tono (`carga` / `carga_fin`, desde `Lanzador3D`).
## Nada de esto cambia reglas (daño, empuje del juego, tiempos de recarga): solo cómo se ve, se oye y se nota. `ACTIVA` = false lo apaga todo.

static var ACTIVA: bool = true
# --- al disparar ---
static var RETROCESO_V0: float = 1.1           ## u/s hacia atrás al soltar (el empuje decae ×7/s: recorre ~0,16 u)
static var ZOOM_GOLPE: float = 0.025           ## la cámara se acerca un 2,5 %…
static var T_ZOOM: float = 0.12                ## …y vuelve en este tiempo
static var DESTELLO_MANO: float = 0.55         ## tamaño de la estrella de la mano (× la de impacto)
static var T_DESTELLO_MANO: float = 0.08
# --- al no poder ---
static var T_TEMBLOR_PAGINA: float = 0.3
static var T_CURSOR_NO: float = 0.25
# --- golpes a enemigos ---
static var DANO_HITSTOP_MAX: float = 40.0      ## con este daño (o más) el hitstop es el máximo (Combate3D.HITSTOP_DEBIL); con 0, el mínimo (Combate3D.HITSTOP)
static var HITSTOP_COMPARTIDO: float = 0.6     ## la jugadora se congela esta fracción del hitstop del enemigo
# --- daño recibido ---
static var T_VINETA: float = 0.22
static var ALFA_VINETA: float = 0.5
static var TEMBLOR_DANO: float = 0.35          ## intensidad de `Vfx3D.temblor` (0..1)
static var HITSTOP_DANO: float = 0.05          ## s que se congela ella al recibir un golpe

# --- LOTE 2 · arranque del proyectil ---
static var ARRANQUE: float = 0.7               ## sale a (1 + ARRANQUE) × su velocidad, aguanta rápido ~0,1 s, frena a ~0,65× y vuelve a la suya…
static var T_ARRANQUE: float = 0.4             ## …en este tiempo (s de juego); 0 = sin arranque
static var ESTIRON: float = 0.5                ## en la salida el dibujo mide (1 + ESTIRON) en la dirección del vuelo (y adelgaza); al frenar, un poco achatado
static var T_ESTELA: float = 0.025             ## s entre bola y bola de la estela (solo mientras va más rápido que su velocidad)
static var T_ESTELA_VIVE: float = 0.16
# --- LOTE 2 · polvo ---
static var POLVO_EMPUJE: float = 0.45          ## radio (u) del polvo a los pies al salir empujado
static var POLVO_CAIDA: float = 0.75           ## radio al caer del vuelo del empujón / al aterrizar el limo
static var EMPUJE_POLVO_JUGADORA: float = 2.0  ## u/s de empujón a la jugadora a partir de los que levanta polvo
static var VY_POLVO_CAIDA: float = 4.5         ## u/s de caída a partir de los que levanta polvo al tocar suelo
# --- LOTE 2 · esquiva perfecta ---
static var COLOR_BRUJA: Color = Color(0.62, 0.42, 1.0)
static var FUERZA_BRUJA: float = 0.8           ## cuánto desatura y tiñe la pantalla (0..1)
static var T_ENTRA_BRUJA: float = 0.08         ## s reales que tarda en entrar el filtro (y en irse al acabar)
static var T_COPIAS: float = 0.1               ## s reales entre copia y copia de la estela (29/10: eran 0,06 × 5 y se apilaban encima de ella en el primer 0,3 s)
static var N_COPIAS: int = 16                  ## como mucho, durante todo el tiempo bruja
static var MUEVE_COPIA: float = 0.25           ## u que tiene que haberse movido desde la última copia (quieta no deja copias apiladas)
static var T_COPIA_VIVE: float = 0.5           ## s reales que tarda una copia en desvanecerse
static var ALFA_COPIA: float = 0.6
static var T_TIC: float = 0.5                  ## s reales entre «tic» y «tic» mientras dura
# --- LOTE 2 · muerte ---
static var TEMBLOR_MUERTE: float = 0.22
## 29/10 (Pablo, sala del gólem): el mazazo del gólem levanta polvo bajo cada puño y uno mayor en el centro, y la cámara tiembla suave.
static var POLVO_GOLEM: float = 0.9             ## radio del polvo de cada puño (el del centro, ×1,6)
static var TEMBLOR_GOLEM: float = 0.3           ## temblor del mazazo (sin Sensacion: 0,35 fijo, como antes)
static var RADIO_SALA: float = 16.0            ## u: los enemigos vivos a menos de esto de la jugadora son «de la sala»
static var CAMARA_LENTA: float = 0.3           ## Engine.time_scale al caer el último…
static var T_CAMARA_LENTA: float = 0.45        ## …durante estos s reales…
static var T_VUELTA_LENTA: float = 0.25        ## …y vuelve a 1 en estos
static var ZOOM_ULTIMO: float = 0.06
# --- LOTE 2 · reacciones grandes ---
static var HITSTOP_MUNDO: float = 0.12         ## s que se congelan todos (enemigos y ella) con una reacción grande
static var ESCALA_ROTULO: float = 1.8
static var TEMBLOR_REACCION: float = 0.4
static var ZOOM_REACCION: float = 0.04
## Lote 3 (29/10). Respingo: el MODELO del enemigo da un tirón hacia donde va el golpe y vuelve (el destello blanco y el aplastamiento ya estaban).
static var RESPINGO: float = 0.16               ## u del tirón (el elemental, el 60 %)
static var T_RESPINGO: float = 0.16             ## s: un cuarto en ir, el resto en volver con rebote
## Avisos fuera de pantalla: una flecha en el borde hacia el enemigo que marca un ataque y no se ve.
static var MARGEN_FLECHA: float = 34.0          ## px desde el borde de la pantalla
static var TAM_FLECHA: float = 20.0             ## px; crece hasta ×1,5 en la ventana de la esquiva
static var RADIO_FLECHA: float = 16.0           ## u: avisos de enemigos más lejos de ella no se señalan
## Música de combate: una capa de percusión y bajo que entra cuando algún enemigo la persigue cerca y sale al acabar; si acaba porque han caído todos, «sala_limpia».
static var DB_MUSICA: float = -17.0
static var T_SUBE_MUSICA: float = 1.2           ## s reales en entrar
static var T_BAJA_MUSICA: float = 2.5           ## s reales en salir
static var T_SIGUE_COMBATE: float = 2.5         ## s reales sin nadie persiguiéndola antes de dar el combate por acabado

# --- LOTE 4 · sonido del cuerpo golpeado y de la jugadora ---
static var SONAR_GOLPES: bool = true           ## el cuerpo del enemigo suena al encajar un hechizo (su `snd_golpe`); el golpe F ya sonaba (`dano`)
static var VIDA_LATIDO: float = 0.34           ## fracción de vida por debajo de la cual late el corazón…
static var DB_LATIDO: float = -8.0             ## …a este volumen con la vida casi a cero (sube desde −18 dB al entrar)
static var T_LATIDO_ENTRA: float = 0.6         ## s reales que tarda en entrar y en irse
# --- LOTE 4 · voltereta y recargas ---
static var POLVO_VOLTERETA: float = 0.3        ## radio (u) del polvo a los pies al empezar a rodar (0 = sin polvo)
static var AVISAR_RECARGAS: bool = true        ## clic suave (y destello de la página) cuando una página o la voltereta vuelven a estar listas
# --- LOTE 4 · cámara con adelanto ---
static var ADELANTO_MOV: float = 0.25          ## u que el foco se adelanta hacia donde CORRE (andando, nada: es un juego de leer el suelo); crece con la velocidad real
static var ADELANTO_APUNTA: float = 0.8        ## u hacia donde mira mientras apunta (1/2/3 mantenida o arrastre): el alcance cae en el borde de una cámara de tamaño 6
static var ADELANTO_SUAVE: float = 3.5         ## /s: el adelanto se acerca a su meta con lerp(1 − e^(−k·dt)) (bajo = perezoso, alto = nervioso)
static var ADELANTO_MAX: float = 1.0           ## u: tope del adelanto (a tamaño 6; la maqueta lo escala con el zoom)
static var ZOOM_APUNTA: float = 0.0            ## alternativa a ADELANTO_APUNTA: alejar la cámara esta fracción (0,06–0,08) mientras se apunta, con ella en el centro. 0 = apagado
static var adelanto_actual: Vector3 = Vector3.ZERO   ## lo que la maqueta suma al foco de la cámara (lo calcula el director cada fotograma)
# --- LOTE 4 · andar con arranque y frenada ---
static var ACEL_SUELO: float = 12.0            ## u/s² al arrancar (andar 1,6 u/s: 0,13 s; correr 3: 0,25 s). 0 = instantáneo, como antes. Con 25 (4 fotogramas) no se notaba
static var FRENO_SUELO: float = 30.0           ## u/s² al soltar las teclas (de 1,6 u/s se para en 0,053 s y 0,04 u)
# --- LOTE 4 · el proyectil contra el mundo ---
static var TEMBLOR_MUNDO: float = 0.12         ## temblor al parar contra pared, bloque o barrera (× el tamaño del hechizo; el suelo, la mitad)
static var ESTRELLA_MUNDO: float = 0.8         ## tamaño de la estrella de impacto (× la de golpe)
# --- LOTE 4 · carga en la mano ---
static var T_CARGA: float = 0.55               ## s reales en que el aro se cierra del radio inicial al final; después late
static var RADIO_CARGA: Vector2 = Vector2(0.3, 0.12)    ## u: radio del aro al empezar y al cerrarse (0,45 tapaba el torso al empezar)
static var TONO_CARGA: Vector2 = Vector2(0.8, 1.25)     ## tono del zumbido al empezar y al cerrarse

## Para las pruebas: cuántas veces se pidió cada cosa.
static var cuenta: Dictionary = {"disparo": 0, "no_puedes": 0, "dano": 0, "zoom": 0, "polvo": 0, "estela": 0, "esquiva": 0, "muerte": 0, "ultimo": 0, "reaccion": 0, "copias": 0, "tic": 0, "respingo": 0, "flecha": 0, "combate": 0, "sala_limpia": 0,
	"golpe_son": 0, "dano_son": 0, "latido": 0, "voltereta": 0, "recarga_lista": 0, "impacto_mundo": 0, "carga": 0}

const CODIGO_VINETA: String = """
shader_type canvas_item;
uniform float fuerza = 0.0;
uniform vec4 color : source_color = vec4(0.85, 0.05, 0.05, 1.0);
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q * vec2(1.0, 0.8));
	float borde = smoothstep(0.55, 1.25, r);
	COLOR = vec4(color.rgb, borde * fuerza);
}
"""
static var _sh_vineta: Shader = null


## Hitstop (s) de un golpe de `dano` a un enemigo: de Combate3D.HITSTOP (flojo) a Combate3D.HITSTOP_DEBIL (con DANO_HITSTOP_MAX o más); si es su debilidad, el máximo.
static func hitstop_de(dano: float, debil: bool) -> float:
	if debil:
		return Combate3D.HITSTOP_DEBIL
	var k: float = clampf(dano / maxf(DANO_HITSTOP_MAX, 0.01), 0.0, 1.0)
	return lerpf(Combate3D.HITSTOP, Combate3D.HITSTOP_DEBIL, k)


## Al salir el hechizo. `dir` = hacia dónde va; `mano` = dónde nace (el destello). `retroceso` false = el hechizo no sale de la mano sino que nace donde se apunta
## (la barrera): entonces no hay empujón hacia atrás, solo el zoom, el destello y el sonido.
static func disparo(lanz: Lanzador3D, elemento: String, dir: Vector3, mano: Vector3, retroceso: bool = true) -> void:
	if not ACTIVA or lanz == null or not lanz.is_inside_tree():
		return
	cuenta["disparo"] = int(cuenta["disparo"]) + 1
	var d := Vector3(dir.x, 0.0, dir.z)
	if retroceso and lanz.jugador != null and d.length() > 0.01 and lanz.jugador.has_method("push"):
		lanz.jugador.call("push", -d.normalized(), RETROCESO_V0)
	golpe_zoom(lanz.get_viewport(), ZOOM_GOLPE, T_ZOOM)
	var fx: Variant = lanz.get("fx")
	if fx is Vfx3D and is_instance_valid(fx):
		(fx as Vfx3D).golpe_estrella(mano, elemento, DESTELLO_MANO, T_DESTELLO_MANO)
	Sfx.play(lanz, "lanzar_salida")


## Golpe de zoom de la cámara activa: se acerca `k` (fracción) y vuelve en `t` s. Ortográfica: `size`; en perspectiva: `fov`. Como el temblor de Vfx3D, un golpe nuevo
## parte del valor ORIGINAL (no del que dejó uno a medias), así varios seguidos no la van acercando.
static func golpe_zoom(vp: Viewport, k: float, t: float) -> void:
	if vp == null or k <= 0.0:
		return
	var cam: Camera3D = vp.get_camera_3d()
	if cam == null:
		return
	var prop: String = "size" if cam.projection == Camera3D.PROJECTION_ORTHOGONAL else "fov"
	if cam.has_meta("zoom_base"):
		var viejo: Variant = cam.get_meta("zoom_tween")
		if viejo is Tween and (viejo as Tween).is_valid():
			(viejo as Tween).kill()
			cam.set(prop, float(cam.get_meta("zoom_base")))
	var base: float = float(cam.get(prop))
	cam.set_meta("zoom_base", base)
	cam.set(prop, base * (1.0 - k))
	var tw: Tween = cam.create_tween()
	cam.set_meta("zoom_tween", tw)
	tw.tween_property(cam, prop, base, maxf(t, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: cam.remove_meta("zoom_base"))
	cuenta["zoom"] = int(cuenta["zoom"]) + 1


## No se puede lanzar (recarga, tinta, ahora no…): golpe seco, la página `indice` tiembla en rojo en el HUD (si se sabe cuál) y el cursor parpadea en rojo.
static func no_puedes(lanz: Lanzador3D, indice: int = -1) -> void:
	if lanz == null:
		return
	cuenta["no_puedes"] = int(cuenta["no_puedes"]) + 1
	if not ACTIVA:
		return
	Sfx.play(lanz, "no_puedes")
	var hud: Variant = lanz.get("_page_hud")
	if indice >= 0 and hud is Control and is_instance_valid(hud) and (hud as Control).has_method("temblar"):
		(hud as Control).call("temblar", indice, T_TEMBLOR_PAGINA)
	if lanz.is_inside_tree():
		var img: Image = Apuntado3D.imagen_cursor(Apuntado3D.COLOR_NO, true)
		var tex := ImageTexture.create_from_image(img)
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(Apuntado3D.TAM_CURSOR, Apuntado3D.TAM_CURSOR) * 0.5)
		lanz.get_tree().create_timer(T_CURSOR_NO, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(lanz) and not lanz.modo_lanzar:
				Input.set_custom_mouse_cursor(null))


## La jugadora recibe `cantidad` de daño: viñeta roja, temblor y un hitstop corto. `j` es el Jugador3D.
static func dano_recibido(j: Node3D, cantidad: float) -> void:
	if not ACTIVA or j == null or not j.is_inside_tree():
		return
	cuenta["dano"] = int(cuenta["dano"]) + 1
	var fuerza: float = clampf(0.6 + cantidad / 40.0, 0.6, 1.0)
	_vineta(j, fuerza)
	var mundo: Variant = j.get("mundo")
	var fx: Variant = (mundo as Object).get("_fx") if mundo is Object else null
	if fx is Vfx3D and is_instance_valid(fx):
		(fx as Vfx3D).temblor(TEMBLOR_DANO * fuerza)
	if j.has_method("hitstop"):
		j.call("hitstop", HITSTOP_DANO)
	cuenta["dano_son"] = int(cuenta["dano_son"]) + 1
	Sfx.play(j, "dano_jugadora", clampf(1.1 - cantidad / 80.0, 0.75, 1.1) * randf_range(0.94, 1.06))      # lote 4: más grave cuanto mayor el golpe (y nunca dos iguales)


## La viñeta roja: un CanvasLayer que se crea una vez por jugadora y se reutiliza.
static func _vineta(j: Node3D, fuerza: float) -> void:
	var capa: CanvasLayer = j.get_meta("vineta_dano") if j.has_meta("vineta_dano") else null
	if capa == null or not is_instance_valid(capa):
		if _sh_vineta == null:
			_sh_vineta = Shader.new()
			_sh_vineta.code = CODIGO_VINETA
		capa = CanvasLayer.new()
		capa.layer = 50
		capa.name = "VinetaDano"
		var r := ColorRect.new()
		r.name = "R"
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		var m := ShaderMaterial.new()
		m.shader = _sh_vineta
		r.material = m
		capa.add_child(r)
		j.add_child(capa)
		j.set_meta("vineta_dano", capa)
	var rect: ColorRect = capa.get_node("R") as ColorRect
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if capa.has_meta("tw"):
		var viejo: Variant = capa.get_meta("tw")
		if viejo is Tween and (viejo as Tween).is_valid():
			(viejo as Tween).kill()
	mat.set_shader_parameter("fuerza", ALFA_VINETA * fuerza)
	var tw: Tween = capa.create_tween()
	capa.set_meta("tw", tw)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fuerza", v), ALFA_VINETA * fuerza, 0.0, T_VINETA).set_ease(Tween.EASE_IN)


## =====================================================================================================
##  LOTE 2
## =====================================================================================================

## Arranque: el factor de velocidad del proyectil a los `t` s de salir. 1 + ARRANQUE·g(u), u = t / T_ARRANQUE, con g(u) = (1 − u)²·(1 + 2u − 15u²): vale 1 al salir, se
## mantiene alto el primer quinto, baja a ≈ −½ (frena) y llega a 0 sin saltos (g(1) = g'(1) = 0). Su integral en [0, 1] es 0 (⅓ + 2/12 − 15/30): al acabar el arranque
## el proyectil ha recorrido lo mismo que sin él.
static func factor_arranque(t: float) -> float:
	if not ACTIVA or ARRANQUE <= 0.0 or T_ARRANQUE <= 0.0 or t < 0.0 or t >= T_ARRANQUE:
		return 1.0
	var u: float = t / T_ARRANQUE
	return 1.0 + ARRANQUE * (1.0 - u) * (1.0 - u) * (1.0 + 2.0 * u - 15.0 * u * u)


## Cuánto se estira el dibujo con ese factor de arranque: 1 + ESTIRON en la salida, algo menos de 1 (achatado) al frenar, 1 a su velocidad.
static func estiron(factor: float) -> float:
	if ARRANQUE <= 0.0:
		return 1.0
	return maxf(0.5, 1.0 + ESTIRON * (factor - 1.0) / ARRANQUE)


## La base que estira `s` veces en la dirección `d` y adelgaza 1/√s en las otras dos (el volumen no cambia), por `escala` uniforme.
static func base_estirada(d: Vector3, s: float, escala: float) -> Basis:
	if d.length() < 0.001 or absf(s - 1.0) < 0.001:
		return Basis.IDENTITY.scaled(Vector3.ONE * escala)
	var n: Vector3 = d.normalized()
	var lado: float = 1.0 / sqrt(s)
	var cols: Array = []
	for e in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		cols.append(((e as Vector3) * lado + n * (s - lado) * n.dot(e as Vector3)) * escala)
	return Basis(cols[0], cols[1], cols[2])


## Polvo a ras de suelo en `pos` (los pies) de radio `radio`. No en el agua (ahí no hay polvo: salpica otra cosa).
static func polvo(en: Node, pos: Vector3, radio: float) -> void:
	if not ACTIVA or radio <= 0.0 or not (en is Node3D) or not en.is_inside_tree():
		return
	var c: Vector2i = Terreno3D.celda_de(pos)
	if Terreno3D.en_mapa(c) and Terreno3D.se_nada(c):
		return
	cuenta["polvo"] = int(cuenta["polvo"]) + 1
	VfxPuzle3D.polvo(en as Node3D, pos + Vector3(0.0, 0.05, 0.0), radio)


## El mazazo del gólem llega al suelo en `centro` (dirección del golpe `dir`): polvo bajo los dos puños y en medio, y temblor suave. Devuelve false si está apagado.
static func mazazo(en: Node3D, centro: Vector3, dir: Vector3) -> bool:
	if not ACTIVA or en == null or not en.is_inside_tree():
		return false
	var lado := Vector3(-dir.z, 0.0, dir.x).normalized() * 0.5
	polvo(en, centro, POLVO_GOLEM * 1.6)
	polvo(en, centro + lado, POLVO_GOLEM)
	polvo(en, centro - lado, POLVO_GOLEM)
	var mundo: Variant = en.get("mundo")
	var fx: Variant = (mundo as Object).get("_fx") if mundo is Object else null
	if fx is Vfx3D and is_instance_valid(fx):
		(fx as Vfx3D).temblor(TEMBLOR_GOLEM)
	return true


## Esquiva perfecta: filtro violeta y desaturado de pantalla, estela de copias y tic-tac mientras dure el tiempo bruja. `j` es el Jugador3D (su `pj` es el modelo).
static func esquiva_perfecta(j: Node3D) -> void:
	if not ACTIVA or j == null or not j.is_inside_tree():
		return
	cuenta["esquiva"] = int(cuenta["esquiva"]) + 1
	var viejo: Node = j.get_node_or_null("EfectoBruja")
	if viejo != null:
		viejo.name = "EfectoBrujaViejo"
		viejo.queue_free()
	var ef := EfectoBruja.new()
	ef.name = "EfectoBruja"
	ef.jugadora = j
	j.add_child(ef)


## Un enemigo cae. Temblor siempre; si no queda ningún enemigo vivo «de la sala» (a menos de RADIO_SALA de la jugadora), además cámara lenta y golpe de zoom.
## Devuelve true si era el último.
static func muerte(e: Node3D) -> bool:
	if not ACTIVA or e == null or not e.is_inside_tree():
		return false
	cuenta["muerte"] = int(cuenta["muerte"]) + 1
	var mundo: Variant = e.get("mundo")
	var fx: Variant = (mundo as Object).get("_fx") if mundo is Object else null
	if fx is Vfx3D and is_instance_valid(fx):
		(fx as Vfx3D).temblor(TEMBLOR_MUERTE)
	var j: Variant = e.get("jugador")
	if not (j is Node3D) or not is_instance_valid(j):
		return false
	var pj_pos: Vector3 = (j as Node3D).global_position
	if pj_pos.distance_to(e.global_position) > RADIO_SALA:
		return false                       # cayó lejos de ella (otra sala, un charco que lo ahogó solo): no es «su» último
	for n in e.get_tree().get_nodes_in_group("combate3d"):
		if n == e or not is_instance_valid(n) or bool((n as Object).get("muerto")):
			continue
		if (n as Node3D).global_position.distance_to(pj_pos) <= RADIO_SALA:
			return false
	cuenta["ultimo"] = int(cuenta["ultimo"]) + 1
	camara_lenta(e)
	golpe_zoom(e.get_viewport(), ZOOM_ULTIMO, T_CAMARA_LENTA + T_VUELTA_LENTA)
	return true


## Cámara lenta del final: pone Engine.time_scale a CAMARA_LENTA solo si estaba a 1 (el libro, el lanzamiento rápido o el tiempo bruja mandan sobre ella) y lo devuelve a 1
## solo si nadie lo ha tocado mientras.
static func camara_lenta(en: Node) -> void:
	if en == null or not en.is_inside_tree() or not is_equal_approx(Engine.time_scale, 1.0):
		return
	var cl := CamaraLenta.new()
	cl.name = "CamaraLenta"
	en.get_tree().root.add_child(cl)


## Una reacción grande en `e` (vapor, descarga, congelado, hundido…): rótulo grande `texto` en `pos`, hitstop del mundo, temblor, zoom y su sonido.
## Devuelve false si está apagado (quien llama pone entonces su texto pequeño de siempre).
static func reaccion_grande(e: Node3D, texto: String, color: Color, pos: Vector3) -> bool:
	if not ACTIVA or e == null or not e.is_inside_tree():
		return false
	cuenta["reaccion"] = int(cuenta["reaccion"]) + 1
	var mundo: Variant = e.get("mundo")
	var en: Node = mundo as Node if mundo is Node else e.get_parent()
	Combate3D.flotante(en, pos, texto, color, ESCALA_ROTULO)
	Sfx.play(e, "reaccion_grande")
	for n in e.get_tree().get_nodes_in_group("combate3d"):
		if is_instance_valid(n) and not bool((n as Object).get("muerto")) and (n as Object).has_method("_iniciar_hitstop"):
			(n as Object).call("_iniciar_hitstop", HITSTOP_MUNDO)
	var j: Variant = e.get("jugador")
	if j is Node3D and is_instance_valid(j) and (j as Object).has_method("hitstop"):
		(j as Object).call("hitstop", HITSTOP_MUNDO)
	var fx: Variant = (mundo as Object).get("_fx") if mundo is Object else null
	if fx is Vfx3D and is_instance_valid(fx):
		(fx as Vfx3D).temblor(TEMBLOR_REACCION)
	golpe_zoom(e.get_viewport(), ZOOM_REACCION, 0.18)
	return true


## s reales de un fotograma de `delta` (el _process va escalado por Engine.time_scale).
static func delta_real(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.01)


## Lote 3: monta (una vez) el director de la jugadora `j`: flechas de los avisos fuera de pantalla y música de combate. Lo llama `Jugador3D._process`.
static func director(j: Node3D) -> Node:
	if j == null or not j.is_inside_tree():
		return null
	var d: Node = j.get_node_or_null("DirectorSensacion")
	if d == null:
		d = DirectorSensacion.new()
		d.name = "DirectorSensacion"
		d.set("jugadora", j)
		j.add_child(d)
	return d


## Los enemigos vivos que la persiguen (tienen objetivo) a menos de RADIO_SALA. El Gatopedro no cuenta: no ataca, huye.
static func enemigos_en_combate(j: Node3D) -> Array:
	var r: Array = []
	if j == null or not j.is_inside_tree():
		return r
	for n in j.get_tree().get_nodes_in_group("combate3d"):
		var e: Combate3D = n as Combate3D
		if e == null or not is_instance_valid(e) or e.muerto or e.quieto or e is Gatopedro3D or e.objetivo == null:
			continue
		if e.global_position.distance_to(j.global_position) <= RADIO_SALA:
			r.append(e)
	return r


## Flechas y música (lote 3). Vive colgado de la jugadora; no se pausa con el libro.
class DirectorSensacion extends Node:
	var jugadora: Node3D = null
	var en_combate: bool = false
	var volumen: float = 0.0                 ## 0..1 de la música
	var flechas: int = 0                     ## cuántas flechas dibujó la última pasada (pruebas)
	var _t_sin: float = 0.0
	var _vistos: Array = []                  ## enemigos que han estado en este combate
	var _musica: AudioStreamPlayer = null
	var _capa: CanvasLayer = null
	var _lienzo: Control = null
	var _t: float = 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_capa = CanvasLayer.new()
		_capa.layer = 4
		_capa.name = "FlechasAviso"
		_lienzo = Control.new()
		_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
		_lienzo.draw.connect(_dibujar)
		_capa.add_child(_lienzo)
		add_child(_capa)

	var _latido: Node = null                 ## lote 4: el bucle del corazón mientras la vida va baja
	var vol_latido: float = 0.0              ## 0..1
	var _k_latido: float = 0.0               ## la última fuerza del latido en vida (al morir se funde desde ahí, sin salto)
	var _cl_antes: Array = []                ## lote 4: `cooldown_left` del fotograma anterior (para avisar solo de recargas que se agotaron solas)
	var _zoom_apunta_puesto: bool = false
	var _roll_listo_antes: bool = true       ## lote 4: para avisar cuando la voltereta vuelve
	var _paginas_listas: Array = []          ## lote 4: por página, si estaba lista el fotograma anterior

	func _process(delta: float) -> void:
		var dr: float = Sensacion3D.delta_real(delta)
		_t += dr
		if _lienzo != null:
			_lienzo.queue_redraw()
		_musica_paso(dr)
		_latido_paso(dr)
		_recargas_paso()
		_adelanto_paso(dr)

	# --- lote 4 · latido con la vida baja ---
	func _latido_paso(dr: float) -> void:
		var viva: bool = Sensacion3D.ACTIVA and jugadora != null and is_instance_valid(jugadora) and not bool(jugadora.get("muerto"))
		var fr: float = 1.0
		if viva:
			fr = float(jugadora.get("vida")) / maxf(Estado.i().vida_max, 1.0)
			_k_latido = 1.0 - clampf(fr / maxf(Sensacion3D.VIDA_LATIDO, 0.01), 0.0, 1.0)
		var meta: float = 1.0 if (viva and fr < Sensacion3D.VIDA_LATIDO) else 0.0
		vol_latido = move_toward(vol_latido, meta, dr / maxf(Sensacion3D.T_LATIDO_ENTRA, 0.01))
		if vol_latido > 0.0 and _latido == null and jugadora != null and jugadora.is_inside_tree():
			_latido = Sfx.bucle(jugadora, "latido", 1.0)
			if _latido != null:
				_latido.name = "Latido"
				Sensacion3D.cuenta["latido"] = int(Sensacion3D.cuenta["latido"]) + 1
		if _latido != null and is_instance_valid(_latido):
			# Más fuerte y más rápido cuanto menos vida queda (con VIDA_LATIDO de vida, suave y a 1 por segundo; a cero, DB_LATIDO y 1,35 por segundo). Muerta, se funde desde donde iba.
			var k: float = _k_latido
			_latido.set("volume_db", lerpf(-18.0, Sensacion3D.DB_LATIDO, k) + linear_to_db(maxf(vol_latido, 0.0001)))
			_latido.set("pitch_scale", lerpf(1.0, 1.35, k))
			_latido.set("global_position", jugadora.global_position)
			if vol_latido <= 0.0:
				_latido.queue_free()
				_latido = null
		elif _latido != null:
			_latido = null

	# --- lote 4 · «ya puedes otra vez»: clic cuando la voltereta o una página vuelven a estar listas ---
	## Solo avisa de recargas que se AGOTARON SOLAS (el valor anterior era ya pequeño): si una prueba, un laboratorio o el reinicio las ponen a cero de golpe, calla. Muerta, calla.
	func _recargas_paso() -> void:
		if jugadora == null or not is_instance_valid(jugadora):
			return
		var muerta: bool = bool(jugadora.get("muerto"))
		var cd: float = float(jugadora.call("roll_cd")) if jugadora.has_method("roll_cd") else 0.0
		var listo: bool = cd <= 0.0
		if listo and not _roll_listo_antes and not muerta:
			Sensacion3D.recarga_lista(jugadora, -1)
		_roll_listo_antes = listo
		var lanz: Variant = jugadora.get("lanz")
		if not (lanz is Lanzador3D) or not is_instance_valid(lanz):
			return
		var cl: Array = (lanz as Lanzador3D).cooldown_left
		if _cl_antes.size() != cl.size():
			_cl_antes = cl.duplicate()
			return
		for i in range(cl.size()):
			var antes: float = float(_cl_antes[i])
			var ahora: float = float(cl[i])
			if ahora <= 0.0 and antes > 0.0 and antes <= 0.25 and not muerta and float((lanz as Lanzador3D).cooldown_total[i]) > 0.0:
				Sensacion3D.recarga_lista(jugadora, i)
			_cl_antes[i] = ahora

	# --- lote 4 · adelanto de la cámara ---
	func _adelanto_paso(dr: float) -> void:
		var meta: Vector3 = Vector3.ZERO
		var apunta: bool = false
		if Sensacion3D.ACTIVA and jugadora != null and is_instance_valid(jugadora) and not bool(jugadora.get("muerto")):
			apunta = Sensacion3D.apuntando(jugadora)
			var mirada: Vector3 = jugadora.call("mirada") if jugadora.has_method("mirada") else Vector3.ZERO
			meta = Sensacion3D.meta_adelanto(jugadora.get("vel_suelo") as Vector3, mirada, apunta, bool(jugadora.get("corriendo")))
		Sensacion3D.adelanto_actual = Sensacion3D.adelanto_actual.lerp(meta, 1.0 - exp(-Sensacion3D.ADELANTO_SUAVE * dr))
		# La alternativa «cámara fija»: alejar un poco mientras apunta (ZOOM_APUNTA > 0), con ella en el centro. Se mete y se quita con el golpe de zoom (signo contrario).
		var quiere_zoom: bool = apunta and Sensacion3D.ZOOM_APUNTA > 0.0
		if quiere_zoom != _zoom_apunta_puesto and jugadora != null and is_instance_valid(jugadora) and jugadora.is_inside_tree():
			_zoom_apunta_puesto = quiere_zoom
			var cam: Camera3D = jugadora.get_viewport().get_camera_3d()
			if cam != null:
				var prop: String = "size" if cam.projection == Camera3D.PROJECTION_ORTHOGONAL else "fov"
				var base: float = float(cam.get_meta("zoom_apunta_base")) if cam.has_meta("zoom_apunta_base") else float(cam.get(prop))
				cam.set_meta("zoom_apunta_base", base)
				var tw: Tween = cam.create_tween()
				tw.tween_property(cam, prop, base * (1.0 + Sensacion3D.ZOOM_APUNTA) if quiere_zoom else base, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				if not quiere_zoom:
					tw.tween_callback(func() -> void: cam.remove_meta("zoom_apunta_base"))

	# --- música ---
	func _musica_paso(dr: float) -> void:
		var ahora: Array = Sensacion3D.enemigos_en_combate(jugadora) if Sensacion3D.ACTIVA else []
		if not ahora.is_empty():
			_t_sin = 0.0
			for e in ahora:
				if not _vistos.has(e):
					_vistos.append(e)
			if not en_combate:
				en_combate = true
				Sensacion3D.cuenta["combate"] = int(Sensacion3D.cuenta["combate"]) + 1
				PlayLog.event("combate_empieza", {"enemigos": ahora.size()})
		elif en_combate:
			_t_sin += dr
			var todos_caidos: bool = _vistos.all(func(e): return not is_instance_valid(e) or (e as Combate3D).muerto)
			if todos_caidos or _t_sin >= Sensacion3D.T_SIGUE_COMBATE:
				en_combate = false
				if todos_caidos and not _vistos.is_empty():
					Sensacion3D.cuenta["sala_limpia"] = int(Sensacion3D.cuenta["sala_limpia"]) + 1
					Sfx.play(jugadora, "sala_limpia")
				PlayLog.event("combate_acaba", {"limpia": todos_caidos})
				_vistos.clear()
		var meta: float = 1.0 if en_combate else 0.0
		var t: float = Sensacion3D.T_SUBE_MUSICA if en_combate else Sensacion3D.T_BAJA_MUSICA
		volumen = move_toward(volumen, meta, dr / maxf(t, 0.01))
		if volumen > 0.0 and _musica == null:
			var flujo: AudioStream = Sfx.flujo_en_bucle("combate_loop")
			if flujo == null:
				return
			_musica = AudioStreamPlayer.new()
			_musica.name = "MusicaCombate"
			_musica.stream = flujo
			_musica.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_musica)
			_musica.play()
		if _musica != null:
			_musica.volume_db = Sensacion3D.DB_MUSICA + linear_to_db(maxf(volumen, 0.0001))
			if volumen <= 0.0:
				_musica.queue_free()
				_musica = null

	# --- flechas ---
	func _dibujar() -> void:
		flechas = 0
		if not Sensacion3D.ACTIVA or jugadora == null or not is_instance_valid(jugadora) or not jugadora.is_inside_tree():
			return
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null:
			return
		var tam: Vector2 = _lienzo.size
		var m: float = Sensacion3D.MARGEN_FLECHA
		var dentro := Rect2(Vector2(m, m), tam - Vector2(m, m) * 2.0)
		for n in get_tree().get_nodes_in_group(AvisoAtaque3D.GRUPO):
			var a: AvisoAtaque3D = n as AvisoAtaque3D
			if a == null or not is_instance_valid(a) or a.cancelado or a.t >= a.t_impacto:
				continue
			var punta: Variant = Sensacion3D.punta_flecha(cam, tam, dentro, a, jugadora.global_position)
			if punta == null:
				continue
			var p: Vector2 = punta
			var dir: Vector2 = (p - tam * 0.5).normalized()
			var en_ventana: bool = a.queda() <= AvisoAtaque3D.VENTANA_ESQUIVA
			var f: float = Sensacion3D.TAM_FLECHA * (1.5 if en_ventana else 1.0 + 0.5 * clampf(a.t / maxf(a.t_impacto, 0.01), 0.0, 1.0))
			var col: Color = AvisoAtaque3D.COLOR
			if en_ventana:
				col = col.lerp(AvisoAtaque3D.COLOR_VENTANA, 0.6 + 0.4 * sin(_t * 40.0))
			var lado := Vector2(-dir.y, dir.x)
			var base: Vector2 = p - dir * f * 1.3
			_lienzo.draw_colored_polygon(PackedVector2Array([p + dir * 3.0, base + lado * (f + 3.0), base - lado * (f + 3.0)]), Color(0, 0, 0, 0.55))
			_lienzo.draw_colored_polygon(PackedVector2Array([p, base + lado * f, base - lado * f]), col)
			flechas += 1
			Sensacion3D.cuenta["flecha"] = int(Sensacion3D.cuenta["flecha"]) + 1

	func _exit_tree() -> void:
		if _musica != null and is_instance_valid(_musica):
			_musica.stop()
		if _latido != null and is_instance_valid(_latido):
			_latido.queue_free()
		Sensacion3D.adelanto_actual = Vector3.ZERO


## =====================================================================================================
##  LOTE 4
## =====================================================================================================

## El cuerpo de `e` (Combate3D) encaja un hechizo del elemento `el`: suena su `snd_golpe` (carne, piedra, limo…), un poco más grave si es su debilidad (el golpe pesa más).
## Lo llama `Combate3D._impacto_visual` solo con elemento: el golpe F ya suena en `GolpeCuerpo` y el «Piedra» del gólem en `_piedra`.
static func golpe_enemigo(e: Node3D, el: String, debil: bool) -> void:
	if not ACTIVA or not SONAR_GOLPES or e == null or not e.is_inside_tree() or el == "":
		return
	var snd: String = String(e.get("snd_golpe")) if e.get("snd_golpe") != null else "golpe_carne"
	if snd == "" or not Sfx3D.CATALOGO.has(snd):
		return
	cuenta["golpe_son"] = int(cuenta["golpe_son"]) + 1
	Sfx3D.play(e, snd, 0.0, 0.85 if debil else 1.0)      # Sfx3D: con distancia y veda por emisor (tres golpeados a la vez suenan tres veces)


## La jugadora empieza una voltereta: polvo a los pies (en suelo, no en el agua) y el roce de la tela.
static func voltereta(j: Node3D) -> void:
	if not ACTIVA or j == null or not j.is_inside_tree():
		return
	cuenta["voltereta"] = int(cuenta["voltereta"]) + 1
	Sfx.play(j, "voltereta")
	if bool(j.get("en_suelo")) and not bool(j.get("nadando")):
		polvo(j.get("mundo") as Node, j.position, POLVO_VOLTERETA)


## La voltereta (`pagina` = −1) o la página `pagina` vuelven a estar listas: clic suave y, si es una página, destella en el HUD.
static func recarga_lista(j: Node3D, pagina: int) -> void:
	if not ACTIVA or not AVISAR_RECARGAS or j == null or not j.is_inside_tree():
		return
	cuenta["recarga_lista"] = int(cuenta["recarga_lista"]) + 1
	Sfx.play(j, "recarga_lista", 1.0 if pagina < 0 else 1.12)
	if pagina >= 0:
		var lanz: Variant = j.get("lanz")
		var hud: Variant = (lanz as Object).get("_page_hud") if lanz is Object else null
		if hud is Control and is_instance_valid(hud) and (hud as Control).has_method("destello"):
			(hud as Control).call("destello", pagina, 0.2)


## La velocidad de andar tras `delta`: se acerca a `objetivo` (lo que piden las teclas) con ACEL_SUELO si hay teclas o FRENO_SUELO si no. Apagada (o con
## ACEL_SUELO = 0), devuelve `objetivo` tal cual: instantáneo, como antes. Estática para medirla sin escena (como `Jugador3D.velocidad_hielo`).
static func velocidad_suelo(v: Vector3, objetivo: Vector3, delta: float) -> Vector3:
	if not ACTIVA or ACEL_SUELO <= 0.0:
		return objetivo
	var tasa: float = ACEL_SUELO if objetivo != Vector3.ZERO else maxf(FRENO_SUELO, 0.01)
	return v.move_toward(objetivo, tasa * delta)


## ¿Está apuntando (1/2/3 mantenida o el arrastre)? Lee el Lanzador de la jugadora.
static func apuntando(j: Node3D) -> bool:
	var lanz: Variant = j.get("lanz")
	return lanz is Lanzador3D and is_instance_valid(lanz) and (lanz as Lanzador3D).modo_lanzar


## La meta del adelanto de la cámara: hacia donde CORRE (`vel_suelo`, ADELANTO_MOV, proporcional a la velocidad; andando no) y, apuntando, hacia donde mira (ADELANTO_APUNTA);
## con tope ADELANTO_MAX. Decisión 29/10 (Pablo): cámara móvil «como ahora», con el adelanto casi todo en el apuntado y casi nada en el andar: es un juego de leer el suelo.
## Pura, para probarla sin escena.
static func meta_adelanto(vel_suelo: Vector3, mirada: Vector3, apunta: bool, corre: bool) -> Vector3:
	var m := Vector3.ZERO
	var v := Vector3(vel_suelo.x, 0.0, vel_suelo.z)
	if corre and v.length() > 0.05:
		m += v.normalized() * ADELANTO_MOV * clampf(v.length() / 3.0, 0.0, 1.0)      # crece con la velocidad real: acompaña al arranque y se recoge al frenar
	if apunta:
		var d := Vector3(mirada.x, 0.0, mirada.z)
		if d.length() > 0.01:
			m += d.normalized() * ADELANTO_APUNTA
	if m.length() > ADELANTO_MAX:
		m = m.normalized() * ADELANTO_MAX
	return m


## Un proyectil se para contra el mundo en `p` yendo hacia `dir`: `causa` «muro» (pared, bloque, barrera, lo que bloquea) o «suelo» (el arco que cae). Estrella del color del
## elemento, chorro de piezas hacia donde iba, temblor según el tamaño (`radio_u`, u) y un toc sordo; el suelo, sin sonido y la mitad de temblor. `lanz` presta el mundo.
static func impacto_mundo(lanz: Lanzador3D, p: Vector3, dir: Vector3, elemento: String, radio_u: float, causa: String) -> void:
	if not ACTIVA or lanz == null or not lanz.is_inside_tree():
		return
	cuenta["impacto_mundo"] = int(cuenta["impacto_mundo"]) + 1
	var suelo: bool = causa == "suelo"
	var tam: float = clampf(radio_u / 0.25, 0.5, 2.5)          # la flecha de base (0,115 u) ≈ 0,5; una bola grande, hasta 2,5
	var fx: Variant = lanz.get("fx")
	if fx is Vfx3D and is_instance_valid(fx):
		var v: Vfx3D = fx as Vfx3D
		v.golpe_estrella(p, elemento, ESTRELLA_MUNDO * tam, 0.09)
		if not suelo:
			v.golpe_direccional(p, -dir, elemento, 0.8 * tam)       # las piezas rebotan hacia atrás: vienen de la pared
		v.temblor(TEMBLOR_MUNDO * tam * (0.5 if suelo else 1.0))
	if not suelo:
		Sfx.play_en(lanz, "golpe_mundo", p, clampf(1.2 - 0.25 * tam, 0.6, 1.2))     # EN el impacto, no en ella


## Empieza la carga: un aro del color del elemento se cierra en la mano del Lanzador mientras dura el modo de lanzar y un zumbido sube de tono. Lo llama
## `Lanzador3D._entrar_modo_lanzar`; `carga_fin` lo quita (`_salir_modo`). Un aro nuevo sustituye al que hubiera.
static func carga(lanz: Lanzador3D, elemento: String) -> void:
	carga_fin(lanz)
	if not ACTIVA or lanz == null or not lanz.is_inside_tree():
		return
	cuenta["carga"] = int(cuenta["carga"]) + 1
	var a := AroCarga.new()
	a.name = "AroCarga"
	a.lanz = lanz
	a.color = Vfx3D.COLOR.get(elemento, Color.WHITE)
	lanz.add_child(a)


static func carga_fin(lanz: Lanzador3D) -> void:
	if lanz == null:
		return
	var a: Node = lanz.get_node_or_null("AroCarga")
	if a != null:
		a.name = "AroCargaViejo"
		(a as AroCarga).apagar()


## El aro de carga (lote 4): un toro plano a la altura de la mano que se cierra en T_CARGA y luego late; el zumbido `carga_bucle` sube de tono con él.
class AroCarga extends MeshInstance3D:
	var lanz: Lanzador3D = null
	var color: Color = Color.WHITE
	var t: float = 0.0
	var _zumbido: Node = null
	var _apagando: bool = false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		top_level = true
		var m := TorusMesh.new()
		m.inner_radius = 0.9
		m.outer_radius = 1.0
		m.rings = 24
		m.ring_segments = 8
		mesh = m
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color.lerp(Color.WHITE, 0.25)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material_override = mat
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_zumbido = Sfx.bucle(lanz, "carga_bucle", Sensacion3D.TONO_CARGA.x)
		_colocar()

	func _colocar() -> void:
		if lanz == null or not is_instance_valid(lanz) or not lanz.is_inside_tree():
			return
		global_position = lanz.pos_mano()
		var k: float = clampf(t / maxf(Sensacion3D.T_CARGA, 0.01), 0.0, 1.0)
		var r: float = lerpf(Sensacion3D.RADIO_CARGA.x, Sensacion3D.RADIO_CARGA.y, 1.0 - (1.0 - k) * (1.0 - k))
		if k >= 1.0:
			r *= 1.0 + 0.1 * sin((t - Sensacion3D.T_CARGA) * 14.0)       # cerrado: late
		scale = Vector3.ONE * r
		var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam != null:
			var hacia: Vector3 = (cam.global_position - global_position).normalized()
			if hacia.length() > 0.01:
				look_at(global_position + hacia, Vector3.UP)
				rotate_object_local(Vector3.RIGHT, PI * 0.5)
		var mat: StandardMaterial3D = material_override as StandardMaterial3D
		if mat != null and not _apagando:
			mat.albedo_color.a = 0.35 + 0.55 * k
		if _zumbido != null and is_instance_valid(_zumbido):
			_zumbido.set("pitch_scale", lerpf(Sensacion3D.TONO_CARGA.x, Sensacion3D.TONO_CARGA.y, k))
			_zumbido.set("global_position", global_position)

	func _process(delta: float) -> void:
		if _apagando:
			return
		if lanz == null or not is_instance_valid(lanz) or not lanz.modo_lanzar:
			apagar()
			return
		t += Sensacion3D.delta_real(delta)
		_colocar()

	## Se va: el zumbido se funde y el aro se abre y se apaga en 0,12 s.
	func apagar() -> void:
		if _apagando:
			return
		_apagando = true
		Sfx.parar(_zumbido, 0.1)
		_zumbido = null
		if not is_inside_tree():
			queue_free()
			return
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "scale", scale * 1.8, 0.12).set_ease(Tween.EASE_OUT)
		var mat: StandardMaterial3D = material_override as StandardMaterial3D
		if mat != null:
			tw.tween_property(mat, "albedo_color:a", 0.0, 0.12)
		tw.chain().tween_callback(queue_free)

	func _exit_tree() -> void:
		Sfx.parar(_zumbido, 0.0)
		_zumbido = null


## Dónde va la punta de la flecha del aviso `a` en una pantalla de `tam` (dentro del rectángulo `dentro`), o null si no lleva flecha: su enemigo se
## ve, o está a más de RADIO_FLECHA de ella (`desde`). Se apunta al ENEMIGO (el dueño), no al centro del aviso: es él quien no se ve.
static func punta_flecha(cam: Camera3D, tam: Vector2, dentro: Rect2, a: AvisoAtaque3D, desde: Vector3) -> Variant:
	var p: Vector3 = (a.dueno as Node3D).global_position if a.dueno is Node3D and is_instance_valid(a.dueno) else a.centro
	if p.distance_to(desde) > RADIO_FLECHA:
		return null
	var detras: bool = cam.is_position_behind(p)
	var s: Vector2 = cam.unproject_position(p)
	if not detras and Rect2(Vector2.ZERO, tam).has_point(s):
		return null                          # se ve: basta el aviso del suelo
	var c: Vector2 = tam * 0.5
	var dir: Vector2 = (s - c) * (-1.0 if detras else 1.0)
	if dir.length() < 0.001:
		return null
	dir = dir.normalized()
	var k: float = INF
	if absf(dir.x) > 0.0001:
		k = minf(k, ((dentro.end.x if dir.x > 0.0 else dentro.position.x) - c.x) / dir.x)
	if absf(dir.y) > 0.0001:
		k = minf(k, ((dentro.end.y if dir.y > 0.0 else dentro.position.y) - c.y) / dir.y)
	return c + dir * k


## La cámara lenta del último enemigo: un nodo que vive lo que dura y se va.
class CamaraLenta extends Node:
	var _t: float = 0.0
	var _puesto: float = 1.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_puesto = Sensacion3D.CAMARA_LENTA
		Engine.time_scale = _puesto

	func _process(delta: float) -> void:
		if not is_equal_approx(Engine.time_scale, _puesto):
			_puesto = 1.0
			queue_free()                   # otro (el libro, el tiempo bruja) ha tomado el tiempo: es suyo, no se toca
			return
		_t += Sensacion3D.delta_real(delta)
		var fin: float = Sensacion3D.T_CAMARA_LENTA + Sensacion3D.T_VUELTA_LENTA
		if _t >= fin:
			Engine.time_scale = 1.0
			_puesto = 1.0
			queue_free()
			return
		var k: float = clampf((_t - Sensacion3D.T_CAMARA_LENTA) / maxf(Sensacion3D.T_VUELTA_LENTA, 0.01), 0.0, 1.0)
		_puesto = lerpf(Sensacion3D.CAMARA_LENTA, 1.0, k * k)
		Engine.time_scale = _puesto

	func _exit_tree() -> void:
		if _puesto < 1.0 and is_equal_approx(Engine.time_scale, _puesto):
			Engine.time_scale = 1.0


## El momento de la esquiva perfecta: filtro de pantalla, copias y tic-tac. Cuelga de la jugadora y se borra al acabar el tiempo bruja (con su salida).
class EfectoBruja extends Node:
	const CODIGO: String = """
shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float fuerza = 0.0;
uniform vec4 tinte : source_color = vec4(0.62, 0.42, 1.0, 1.0);
void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(c, vec3(l), 0.85 * fuerza);
	g = mix(g, g * tinte.rgb * 1.5, 0.5 * fuerza);
	vec2 q = SCREEN_UV * 2.0 - 1.0;
	float borde = smoothstep(0.6, 1.4, length(q));
	g = mix(g, tinte.rgb * 0.35, borde * 0.6 * fuerza);
	COLOR = vec4(g, 1.0);
}
"""
	static var _sh: Shader = null

	var jugadora: Node3D = null
	var copias: int = 0
	var tics: int = 0
	var fuerza: float = 0.0
	var _t_copia: float = 0.0
	var _pos_copia: Vector3 = Vector3.INF
	var _t_tic: float = 0.0
	var _saliendo: bool = false
	var _mat: ShaderMaterial = null
	var _capa: CanvasLayer = null

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		if _sh == null:
			_sh = Shader.new()
			_sh.code = CODIGO
		_capa = CanvasLayer.new()
		_capa.layer = -5                   # por debajo del HUD: el libro y la vida no se tiñen
		_capa.name = "FiltroBruja"
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		_mat = ShaderMaterial.new()
		_mat.shader = _sh
		_mat.set_shader_parameter("tinte", Sensacion3D.COLOR_BRUJA)
		_mat.set_shader_parameter("fuerza", 0.0)
		r.material = _mat
		_capa.add_child(r)
		add_child(_capa)
		_tic(1.0)
		_copia()

	func _process(delta: float) -> void:
		var dr: float = Sensacion3D.delta_real(delta)
		if not TiempoBruja.activa() and not _saliendo:
			_saliendo = true
			_tic(0.75)                       # «toc»: más grave, el tiempo vuelve
		var entra: float = maxf(Sensacion3D.T_ENTRA_BRUJA, 0.01)
		if _saliendo:
			fuerza = maxf(0.0, fuerza - dr / entra)
		else:
			fuerza = minf(1.0, fuerza + dr / entra)
		_mat.set_shader_parameter("fuerza", fuerza * Sensacion3D.FUERZA_BRUJA)
		if not _saliendo:
			_t_copia += dr
			if _t_copia >= Sensacion3D.T_COPIAS and copias < Sensacion3D.N_COPIAS and jugadora != null and is_instance_valid(jugadora) 					and jugadora.global_position.distance_to(_pos_copia) >= Sensacion3D.MUEVE_COPIA:
				_t_copia = 0.0
				_copia()
			_t_tic += dr
			if _t_tic >= Sensacion3D.T_TIC:
				_t_tic = 0.0
				_tic(1.0)
		elif fuerza <= 0.0:
			queue_free()

	func _tic(tono: float) -> void:
		tics += 1
		Sensacion3D.cuenta["tic"] = int(Sensacion3D.cuenta["tic"]) + 1
		if jugadora != null and is_instance_valid(jugadora):
			Sfx.play(jugadora, "tiempo_tic", tono)

	## Una copia violeta de la pose de ahora: cada malla con esqueleto del modelo se «hornea» en su pose y se deja quieta, desvaneciéndose.
	func _copia() -> void:
		if jugadora == null or not is_instance_valid(jugadora) or not jugadora.is_inside_tree():
			return
		var modelo: Variant = jugadora.get("pj")
		var raiz: Node3D = modelo as Node3D if modelo is Node3D else jugadora
		var padre: Node = jugadora.get_parent()
		if padre == null:
			return
		copias += 1
		_pos_copia = jugadora.global_position
		Sensacion3D.cuenta["copias"] = int(Sensacion3D.cuenta["copias"]) + 1
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.albedo_color = Color(Sensacion3D.COLOR_BRUJA, Sensacion3D.ALFA_COPIA)
		var copia := Node3D.new()
		copia.name = "CopiaBruja"
		padre.add_child(copia)
		for mi in raiz.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			if m == null or not m.is_visible_in_tree() or m.mesh == null:
				continue
			if m.mesh is PlaneMesh or m.mesh is QuadMesh or m.mesh.get_aabb().size.y * m.global_transform.basis.get_scale().y < 0.02:
				continue                     # planos del suelo (sombra, anillo): en violeta salen como un cuadrado
			var malla: Mesh = m.mesh
			if m.skin != null and m.get_skin_reference() != null and m.get_skin_reference().get_skeleton().is_valid():
				var horneada: ArrayMesh = m.bake_mesh_from_current_skeleton_pose()
				if horneada != null:
					malla = horneada
			var c := MeshInstance3D.new()
			c.mesh = malla
			c.material_override = mat
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			copia.add_child(c)
			c.global_transform = m.global_transform
		var tw: Tween = copia.create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_property(mat, "albedo_color:a", 0.0, Sensacion3D.T_COPIA_VIVE)
		tw.tween_callback(copia.queue_free)

	func _exit_tree() -> void:
		if _capa != null and is_instance_valid(_capa):
			_capa.queue_free()
