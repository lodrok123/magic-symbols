class_name Equipo3D
extends RefCounted

## ARMAS Y ESCUDOS de quita y pon para los personajes Mixamo (Pj3D): se cuelgan de un hueso de la mano
## con un BoneAttachment3D y siguen todas las animaciones.
##
## Mientras no haya modelos de Meshy (ver meshy/PROMPTS_EQUIPO.md), las piezas se hacen aquí con formas
## sencillas en la paleta pastel. Cuando lleguen, basta con dejar el GLB en poc_25d/equipo/<id>.glb:
## `pieza()` lo usa en lugar de la versión hecha por código.
##
## Medidas en unidades del modelo (el goblin chibi mide 1,7).

const CARPETA: String = "res://arte/equipo/"
## Piezas de equipo que viven junto al personaje en arte/modelos (baston_marimanta.glb): `pieza()` las busca aquí si no están en CARPETA.
const CARPETA_MODELOS: String = "res://arte/modelos/"

## Bastón de Marimanta (baston_marimanta.glb, Tripo: 0,98 de alto con el pie en el origen y la punta curva hacia +Y). Marimanta mide 1,7 como viene y 0,8 en el juego:
## con BASTON_ESCALA 1,3 mide 1,27 (0,60 u en el juego, hasta el hombro de ella; más largo se le cruza por la cara al andar). Posición y giro, en el espacio del hueso de la mano derecha (en unidades del modelo),
## calculados en idle para que el bastón quede VERTICAL con el pie en el suelo y la palma de ella (a 6 cm de la muñeca hacia los dedos, a ~0,88 del suelo) sobre el palo.
const BASTON_ESCALA: float = 1.3
const BASTON_POS: Vector3 = Vector3(-0.457, 0.615, -0.428)
const BASTON_GIRO: Vector3 = Vector3(-46.3, 25.0, -163.8)
## Modo «apoyada en el suelo y vertical» (PiezaApoyada3D): el bastón no cuelga rígido de la mano, se planta en el suelo bajo la palma y sigue su proyección horizontal.
## agarre_y: altura de la palma sobre el pie en unidades de la pieza (0,88 del modelo / 1,3 de escala); dist_min_cuerpo: u de juego que se separa del eje del cuerpo (para no
## atravesar la túnica al andar); desplaz_adelante: u de juego extra hacia delante; lado: la mano derecha de un modelo que mira a +Z está en -X; giro: grados sobre su eje.
## 5/11 (Pablo: «el bastón en la mano, esa misma posición pero desplazado un poco hacia mi derecha» = hacia el cuerpo): con Marimanta a 0,8 de alto su mano derecha queda a
## 0,125 u del eje del cuerpo y dist_min_cuerpo 0,15 empujaba el pie del bastón 0,025 más afuera que la mano (el palo pasaba por fuera de la mano). Ahora 0,12: el pie bajo la mano.
## 5/11 (2ª, Pablo: «gira el bastón con la punta hacia el norte; está cosido en el nudillo, que los dedos rodeen el bastón»): el GLB tiene el palo a −0,06 del origen (eje_malla: se
## planta el PALO, no el origen) y el rizo hacia +X; con giro_mundo y giro 90 el rizo mira al norte del mundo (−Z) mire a donde mire ella. Medido el puño en idle a 0,8 de alto: nudillos
## en z 0,09–0,12 y yemas en z 0,10–0,13; la muñeca (el agarre) en z 0,087. 5/11 (3ª, Pablo: «sigue cosido al canto de la mano, el bastón "desaparece" donde se sujeta»): medido el
## puño por la MALLA skinneada (vértices con peso en los dedos): centro (−0,123, 0,40, 0,111); el palo va ahí: desplaz_lateral 0,01 y desplaz_adelante 0,02 mueven el punto de agarre
## (ya no solo el pie, que la inclinación hacia la mano lo devolvía a la muñeca), y z_max 0,14.
## 5/11 (4ª, Pablo, con captura y línea roja: «vamos a hacer que el bastón esté delante de la mano»), ya con la mano girada (Pj3D.CORRECCION_POSTURA marimanta): el puño queda en
## (−0,157, 0,43, 0,116) con las yemas hasta z 0,137; el palo va DELANTE del puño, a z ≈ 0,16 y a la x del puño: desplaz_adelante 0,08, desplaz_lateral −0,02 (hacia fuera), z_max 0,20.
## 5/11 (5ª, Pablo: «retrásalo un poco hacia la mano»): desplaz_adelante 0,08 → 0,06, el palo en las yemas (z ≈ 0,14).
const BASTON_APOYO: Dictionary = {"agarre_y": 0.677, "giro": 90.0, "giro_mundo": true, "eje_malla": true, "dist_min_cuerpo": 0.12, "desplaz_adelante": 0.06, "desplaz_lateral": -0.02, "lado": -1.0, "z_min": 0.0, "z_max": 0.20}

## Bastón del chamán goblin (28/10): baston_chaman_equipo.glb = baston_chaman.glb (Meshy, 1,0 de alto, origen en el centro) con el ORBE aparte (tools/separar_orbe_baston.py), envuelto por BastonChaman3D con la
## PUNTA en el origen y el palo hacia +Y. Mide 0,84 en las unidades del modelo (0,95 de alto): 0,75 u en el juego, hasta el pecho del chamán de pie y alcanza el suelo delante de él. Va en la mano DERECHA (la de arriba).
## Posición y giro en el espacio del hueso `RightHand` (medido con el reposo del rig, Mixamo: +Y hacia los dedos, +Z hacia el pulgar, la palma mira a -X en la derecha): el palo discurre por el eje +Z de la mano
## (su +Y = +Z del hueso; giro X 90°) y pasa por el centro de la palma, a 0,035 de la muñeca hacia los dedos y 0,012 hacia el lado al que mira la palma (-X); `BASTON_CHAMAN_AGARRE` = a qué altura sobre la punta
## está la mano (en unidades del modelo). Agarrado (PiezaApoyada3D.agarrar) la punta cae a esa distancia de la palma a lo largo del palo; plantado (idle y andar) sigue a la mano como el bastón de Marimanta.
const BASTON_CHAMAN_ID: String = "baston_chaman_equipo"
const BASTON_CHAMAN_ESCALA: float = 0.84
const BASTON_CHAMAN_AGARRE: float = 0.60
const BASTON_CHAMAN_POS: Vector3 = Vector3(-0.012, 0.035, -BASTON_CHAMAN_AGARRE)
const BASTON_CHAMAN_GIRO: Vector3 = Vector3(90.0, 0.0, 0.0)
const BASTON_CHAMAN_APOYO: Dictionary = {"agarre_y": BASTON_CHAMAN_AGARRE / BASTON_CHAMAN_ESCALA, "giro": 0.0, "dist_min_cuerpo": 0.10, "desplaz_adelante": 0.0, "lado": -1.0, "z_min": 0.0, "z_max": 0.08}

## Grimorio de la elfa: equipo/grimorio_<nivel>.glb (Meshy, horneados con meshy en el marco del de código).
## 1 botánico (marrón y verde) · 2 rúnico (azul y gris) · 3 legendario (rojo y oro). Cada uno trae su pluma.
const NIVELES_GRIMORIO: Array = ["", "botánico", "rúnico", "legendario"]
static var nivel_grimorio: int = 2          ## 12/11: el azul (rúnico) es el libro de partida; también manda sobre la lámina del libro abierto (Spellbook, Laminas.POR_NIVEL)

## Dagas del goblin asesino (daga_goblin.glb: 0,5 de largo con el centro de la empuñadura en el origen y la hoja hacia +Y; hoja = 0,265). El asesino mide 0,977 y
## en el juego 0,85, o sea ×0,87: con DAGA_ESCALA 1,3 la hoja mide ~0,30 u en el juego. Posición en el espacio del hueso de la mano (+Y hacia los dedos), giro en grados.
## La izquierda va reflejada (escala X negativa).
const DAGA_ESCALA: float = 1.3
## Los giros salen de pedir que en cada corte del ataque doble (AtaqueDoble.CORTES) la hoja apunte hacia delante (a lo largo del brazo) con el filo curvo hacia el lado
## al que barre (derecha en el primer corte, izquierda en el segundo): giro_mano_en_el_corte⁻¹ · giro(+90° en X). El hueso de la mano de Mixamo no apunta igual en las dos.
const DAGA_POS_DERECHA: Vector3 = Vector3(0.0, 0.045, 0.0)
const DAGA_GIRO_DERECHA: Vector3 = Vector3(0.5, -31.7, -3.0)
const DAGA_POS_IZQUIERDA: Vector3 = Vector3(0.0, 0.045, 0.0)
const DAGA_GIRO_IZQUIERDA: Vector3 = Vector3(0.5, -108.9, 3.0)

## Núcleo del gólem de piedra (nucleo_golem.glb, 0,259 de alto con su jaula, centrado en su centro) en el hueco del pecho del cuerpo (golem_piedra_rig.glb, 0,704 de alto). Medido en el cuerpo
## centrado: centro del hueco (-0,006, 0,429, 0,09), radio de la abertura 0,053; escala = 0,85 × diámetro de la abertura / 0,259 (un poco hundido). Colgado de Spine2, cuyo reposo
## gira 37,6° sobre X: posición y giro = reposo⁻¹ × (centro del hueco). Se calcula con herramientas/captura_rig_golem.gd (misma cuenta).
const NUCLEO_GOLEM_ESCALA: float = 0.3479
const NUCLEO_GOLEM_POS: Vector3 = Vector3(-0.006, 0.034, 0.1145)
const NUCLEO_GOLEM_GIRO: Vector3 = Vector3(-37.6, 0.0, 0.0)

## Grimorio de la jugadora nueva, en el espacio del hueso Hips (unidades del modelo, 1,7 de alto): +Y arriba (inclinado 7,5° hacia atrás), +Z delante.
const GRIMORIO_JUGADORA_POS: Vector3 = Vector3(0.0, -0.08, -0.21)
const GRIMORIO_JUGADORA_GIRO: Vector3 = Vector3(24.5, 180.0, 0.0)

## Por personaje: [id de la pieza, hueso (final del nombre), posición, giro en grados, (opcional) multiplicador de escala por eje] en el espacio del hueso.
## Los huesos de mano de Mixamo apuntan con +Y hacia los dedos.
## Santa Compaña (9/11). Las dos piezas salen de separar_piezas.py con el origen en el centro de la planta y la base en Y = 0, y su
## eje largo en +Y. La cruz mide 0,454 de alto en el GLB y la palmatoria 0,197.
## Los giros NO son a ojo: con el modelo en reposo, el +Y del hueso RightHand apunta en el mundo a (−0,76, −0,63, +0,12) y el de
## LeftHand a (+0,74, −0,66, +0,11), o sea hacia abajo y hacia fuera. Estos son los giros que llevan el +Y de la pieza a la vertical
## del mundo con los brazos caídos (medidos con el script de manos; ver DIARIO). Como van colgados del hueso, siguen a la mano.
## El centro del puño (media de los cuatro nudillos, herramientas/medidas_mano_equipo.gd) cae a (−0,006, +0,050, −0,002) en el
## espacio de RightHand y a (−0,006, +0,052, −0,001) en el de LeftHand. A eso se le suma bajar la pieza por su propio eje para que
## el puño quede sobre el MANGO y no en su extremo: en el espacio del hueso, «abajo del mundo» es (−0,32, +0,64, +0,70) por la
## derecha y (−0,04, +0,66, −0,75) por la izquierda.
## La cruz fue a 0,8 («demasiado alargado», Pablo), luego a 0,55 y ahora a 0,75: aquello se midió sobre el modelo de brazos largos,
## que ya no se usa; sobre el encapuchado de brazos cortos, más compacto, la cruz aguanta más tamaño sin comerse la silueta. A 0,75
## mide 0,34 de alto en un personaje de 0,95.
## El puño del esqueleto nuevo cae en (−0,007, +0,058, −0,002) en el espacio de RightHand (medidas_mano_equipo.gd), y a eso se le
## suma bajar la pieza por su propio eje para que el puño quede sobre el MANGO: «abajo del mundo» es ahí (−0,32, +0,64, +0,70).
## 9/11 (Pablo: «haz que la cruz sea como un bastón»): a 1,45 mide 0,66 de alto, dos tercios del personaje, y el mango llega casi al
## suelo como una cruz procesional. El agarre sube al 0,30 de la pieza (antes 0,08): el puño va en MITAD del mango, no en su punta,
## que es como se lleva un bastón.
## El GLB de la cruz salía de Meshy con el MANGO a 38° de la vertical dentro del propio archivo. Colgada de la mano no se nota,
## pero plantada en el suelo con PiezaApoyada3D, que pone la pieza recta, lo que se veía torcido era el palo. Enderezada con
## tools/enderezar_pieza.py queda a 1,3° y mide 0,514 de alto (antes 0,454, porque el palo ya no va en diagonal).
const CRUZ_ESCALA: float = 1.73                             # 0,514 × 1,73 = 0,89: del suelo a por encima de la capucha
const CRUZ_POS: Vector3 = Vector3(-0.007, 0.058, -0.002)    # el puño; de bajarla hasta el agarre se encarga PiezaVertical3D
## La cruz se SOSTIENE como el bastón de Marimanta y el del chamán: PiezaApoyada3D, que la planta en el suelo, la deja vertical y
## solo la hace seguir a la mano. Es lo que hacía falta aquí: engancharse a `skeleton_updated` (o sea, colocar la pieza DESPUÉS de
## que el esqueleto termine la pose) es justo lo que no conseguía hacer bien a mano.
## `agarre_y` es la altura de la palma sobre el pie EN UNIDADES DE LA PIEZA: la mano cae a unos 0,35 del suelo y la escala es 1,95,
## así que 0,35/1,95 = 0,179. Con esa escala la cruz mide 0,89, del suelo a por encima de la capucha, como una cruz procesional.
const CRUZ_APOYO: Dictionary = {
	# `dist_min_cuerpo` separa el PIE del eje del cuerpo. Puesto corto (0,11) el pie se planta pegado al personaje mientras la mano
	# va 0,30 afuera, y el palo se inclina casi 30° para unirlos: a 0,30 el pie cae BAJO la mano y la cruz queda recta.
	# 9/11 (Pablo, con una línea roja sobre la captura): con el brazo ya en su sitio, la cruz se plantaba por DELANTE de la mano
	# y el palo pasaba rozando los dedos en vez de entre ellos. `desplaz_adelante` la lleva hacia el frente del personaje hasta
	# el puño, y `z_max` tiene que dar margen para eso (a 0,20 topaba antes de llegar).
	# 10/11 (Pablo: «la cruz queda por detrás de la mano, cose la cruz delante de la palma»). Aquel desplazamiento de 0,22 tapaba el
	# problema a medias: el punto de agarre salía de la postura ANTIGUA de la muñeca, y medido con herramientas/medidas_palma_pieza.gd el
	# palo quedaba 2 cm por el dorso de la mano en reposo y suelto al andar. Ahora el agarre es la PALMA del esqueleto (`palma`): el eje
	# del palo va a 0,022 por delante de ella (el radio del mango más un pelo), sin desplazamientos a mano. `z_min` deja que el pie
	# siga a la mano cuando va un poco atrás al andar.
	# `eje_malla`: el MANGO no pasa por el origen del GLB (se ve desde arriba), así que lo que se pone ante la palma es el eje medido
	# en la malla. Sin esto, la primera versión de `palma` dejaba el origen clavado a 0,022 de la palma y el mango, desplazado, seguía
	# quedando por DETRÁS de la mano; y mi medida, hecha sobre el origen, decía que estaba bien.
	# 11/11 (Pablo: «sí, afina el mango»): el mango se afinó a la mitad en la malla (tools/afinar_mango.py: de 0,038 a 0,019 de radio en el
	# juego) porque los dedos, de 0,05, solo abarcaban un cuarto de su contorno. `palma` = el radio nuevo y medio dedo; el palo va casi en
	# los nudillos (`palma_hacia_dedos` 0,85) para que los dedos lo rodeen desde ahí, y Pj3D.MANO_RELAJADA los cierra siguiendo su curva.
	"agarre_y": 0.202, "giro": 0.0, "dist_min_cuerpo": 0.12, "palma": 0.023, "palma_hacia_dedos": 0.85, "eje_malla": true, "empunar": true, "empunar_palma_hacia": Vector3(0.0, 0.0, 1.0),
	"lado": -1.0, "z_min": -0.12, "z_max": 0.40}
## La palmatoria NO se apoya en el suelo: se lleva en la mano, solo que siempre de pie para que no se vuelque la vela.
const VELA_VERTICAL: Dictionary = {"vertical": true, "agarre_y": 0.03, "desplaz": Vector3(-0.02, 0.0, 0.04)}
const CRUZ_GIRO: Vector3 = Vector3(-44.6, 119.4, -153.1)
## La palmatoria va también en la mano DERECHA (cada miembro de la procesión porta una sola cosa), así que usa el giro de esa mano,
## el mismo que la cruz. Mide 0,398 de ancho con el asa: a 0,8 tapaba medio cuerpo.
const VELA_ESCALA: float = 0.55
const VELA_POS_DERECHA: Vector3 = Vector3(-0.012, 0.068, 0.010)   # puño + 1,7 cm hacia abajo: el platillo justo bajo la mano
const VELA_GIRO_DERECHA: Vector3 = Vector3(-44.6, 119.4, -153.1)

const EQUIPO: Dictionary = {
	# Marimanta (anciana duende, NPC): el bastón (arte/modelos/baston_marimanta.glb) en la mano DERECHA, vertical y apoyado en el suelo. Medidas en BASTON_*.
	"marimanta": [
		["baston_marimanta", "RightHand", BASTON_POS, BASTON_GIRO, Vector3(BASTON_ESCALA, BASTON_ESCALA, BASTON_ESCALA), BASTON_APOYO],
	],
	# Chamán goblin (28/10): el bastón con el orbe aparte (BastonChaman3D) en la mano DERECHA, plantado y vertical al andar y quieto; en el ataque se agarra (Pj3D.agarrar_baston). Medidas en BASTON_CHAMAN_*.
	"goblin_chaman": [
		[BASTON_CHAMAN_ID, "RightHand", BASTON_CHAMAN_POS, BASTON_CHAMAN_GIRO, Vector3(BASTON_CHAMAN_ESCALA, BASTON_CHAMAN_ESCALA, BASTON_CHAMAN_ESCALA), BASTON_CHAMAN_APOYO],
	],
	# Gólem de piedra (28/10): el núcleo (nucleo_golem.glb, pieza aparte para que brille o se apague) en el hueco del pecho, colgado de Spine2. Medidas en NUCLEO_GOLEM_*.
	"golem_piedra": [
		["nucleo_golem", "Spine2", NUCLEO_GOLEM_POS, NUCLEO_GOLEM_GIRO, Vector3(NUCLEO_GOLEM_ESCALA, NUCLEO_GOLEM_ESCALA, NUCLEO_GOLEM_ESCALA)],
	],
	# Goblin asesino: la misma daga (arte/equipo/daga_goblin.glb) en las DOS manos, la izquierda reflejada. Medidas en DAGA_* (más abajo).
	"goblin_asesino": [
		["daga_goblin", "RightHand", DAGA_POS_DERECHA, DAGA_GIRO_DERECHA, Vector3(DAGA_ESCALA, DAGA_ESCALA, DAGA_ESCALA)],
		["daga_goblin", "LeftHand", DAGA_POS_IZQUIERDA, DAGA_GIRO_IZQUIERDA, Vector3(-DAGA_ESCALA, DAGA_ESCALA, DAGA_ESCALA)],
	],
	"goblin_warrior_chibi": [
		["garrote", "RightHand", Vector3(0.0, 0.07, 0.03), Vector3(0.0, 0.0, 90.0)],
		["escudo", "LeftForeArm", Vector3(0.0, 0.12, -0.07), Vector3(90.0, 0.0, 0.0)],
	],
	# Espadachín: el mismo goblin (Pj3D.MODELO_DE) con la espada de armas_goblin.glb en vez de la porra.
	"goblin_espadachin": [
		["espada_goblin", "RightHand", Vector3(0.0, 0.07, 0.03), Vector3(0.0, 0.0, 90.0)],
		["escudo", "LeftForeArm", Vector3(0.0, 0.12, -0.07), Vector3(90.0, 0.0, 0.0)],
	],
	# La elfa: el grimorio colgado a la espalda, a la altura de la cadera y centrado (con la pluma metida en el
	# lomo). Antes iba en la cadera izquierda; atrás se ve más desde la cámara y tapa el solape del vestido con
	# los brazos. En el espacio de Hips de Mixamo: +Y arriba, +Z delante, +X izquierda del personaje.
	"chibi_elf": [
		["grimorio", "Hips", Vector3(0.0, 0.06, -0.20), Vector3(6.0, 180.0, 0.0)],
	],
	# La elfa jugadora (woodland_wanderer): mismo punto que la chibi_elf; su esqueleto Mixamo tiene el mismo espacio de Hips.
	"woodland_wanderer": [
		["grimorio", "Hips", Vector3(0.0, 0.06, -0.20), Vector3(6.0, 180.0, 0.0)],
	],
	# La jugadora nueva (jugadora_base, 24/10): el mismo sitio del mundo que en la elfa vieja (cadera, a la espalda). Su Hips no está inclinado como el de la elfa (eje Y a 7,5° del
	# vertical contra 26°), así que el punto y el giro salen de pasar a su espacio la posición y la orientación que tenía el libro en el de la elfa (medido con
	# herramientas/medidas_jugadora_integrada.gd; ver GRIMORIO_JUGADORA_*).
	"jugadora_base": [
		["grimorio", "Hips", GRIMORIO_JUGADORA_POS, GRIMORIO_JUGADORA_GIRO],
	],
	"chibi_test": [
		["grimorio", "Hips", Vector3(0.36, 0.02, -0.06), Vector3(0.0, 90.0, -8.0)],
	],
	# Arquero: el arco de Meshy (equipo/arco.glb) en la mano IZQUIERDA (la del brazo estirado al apuntar; madera hacia delante, cuerda hacia el arquero).
	"goblin_archer_chibi": [
		# 5/11 (Pablo: «el goblin no sujeta el arco, está todo mal»; antes (0, 0.07, 0.47) y (90, 0, 180), cruzado). arco.glb va a lo largo de +Y (−0,39..0,39), curva en +X
		# (0..0,5: empuñadura en ~0,28, puntas y CUERDA en 0,5), grosor en Z. +Y del arco = el eje del PUÑO de LeftHand: la media del arriba del mundo en la mano en
		# ArcheryShot 2,5–4,0 s y Mixamo_TensarArco, (0,29, 0,05, 0,95) ≈ +Z de la mano (alineado solo al arriba de 3,0 s salía a 45° en otras poses, Pablo 5/11: «el mástil
		# sujetado con la mano»; con +Z puro apuntaba a 30°, así queda a ~13°, como un arquero que inclina el arco). +X = hacia el arquero (−tiro de 3,0 s) para que la
		# cuerda mire al cuerpo; posición = −giro·(empuñadura 0,28·1,2, 0, 0): la empuñadura en la palma.
		["arco", "LeftHand", Vector3(-0.125, 0.311, 0.022), Vector3(21.9, -71.8, -86.9), Vector3(1.2, 1.2, 2.2)],   # 6.13: +20 % de largo (Y) y de curva (X), y más grueso (Z ×2,2)
		# 5/11 (Pablo, con un clip 2D de referencia: «fíjate en la posición del arco y las manos»): flecha en la mano DERECHA con la nocla en la palma y la punta hacia la mano
		# del arco (medido en ArcheryShot a 3 s: dirección mano derecha → izquierda en el espacio de RightHand (−0,93, 1,69, 0,54)); Pj3D.EQUIPO_SOLO_EN la enseña solo al disparar.
		["flecha", "RightHand", Vector3(-0.13, 0.24, 0.07), Vector3(32.3, -53.5, 3.6)],
		# Carcaj a la espalda, colgado de Spine2 (su +Y ≈ arriba y su +Z ≈ el frente del personaje en todos los clips medidos): detrás (−Z), un poco bajo, inclinado 25° con la
		# boca hacia el hombro derecho (el de la mano que saca la flecha).
		["carcaj", "Spine2", Vector3(0.0, -0.06, -0.27), Vector3(0.0, 0.0, 25.0)],   # −0,27: por fuera de la capa (a −0,20 la capa lo tapaba casi entero)
	],
	"goblin_warrior": [
		["garrote", "RightHand", Vector3(0.0, 0.07, 0.03), Vector3(0.0, 0.0, 90.0)],
		["escudo", "LeftForeArm", Vector3(0.0, 0.12, -0.07), Vector3(90.0, 0.0, 0.0)],
	],
	# Santa Compaña (9/11): la cruz de campanillas en la mano DERECHA y la palmatoria con la vela en la IZQUIERDA. Las dos salen de
	# arte/modelos/reliquias.glb (lámina de cuatro objetos de Meshy) partida con tools/separar_piezas.py; las otras dos piezas (el
	# brocal del pozo y la losa con musgo) son de escenario y están en arte/modelos. Medidas en CRUZ_* y VELA_*.
	# 9/11 (Pablo): la procesión son VARIOS iguales seguidos y cada uno porta UNA sola cosa. Por eso no hay un «santa_compana_rig»
	# que lleve las dos: son dos variantes del mismo GLB (Pj3D.MODELO_DE), y cada una equipa su pieza en la mano DERECHA.
	"santa_compana_cruz": [
		["cruz_santa", "RightHand", CRUZ_POS, CRUZ_GIRO, Vector3(CRUZ_ESCALA, CRUZ_ESCALA, CRUZ_ESCALA), CRUZ_APOYO],
	],
	"santa_compana_vela": [
		["vela_santa", "RightHand", VELA_POS_DERECHA, VELA_GIRO_DERECHA, Vector3(VELA_ESCALA, VELA_ESCALA, VELA_ESCALA), VELA_VERTICAL],
	],
}

const MADERA: Color = Color(0.62, 0.42, 0.26)
const MADERA_CLARA: Color = Color(0.78, 0.58, 0.36)
const HIERRO: Color = Color(0.62, 0.64, 0.70)
const CUERDA: Color = Color(0.85, 0.76, 0.56)
const TAPA: Color = Color(0.22, 0.47, 0.47)        ## verde azulado, como el vestido de la elfa
const ORO: Color = Color(0.86, 0.70, 0.40)
const PAPEL: Color = Color(0.96, 0.92, 0.83)
const CUERO: Color = Color(0.45, 0.30, 0.20)


## Cuelga del esqueleto de `modelo` las piezas que tenga `id` en EQUIPO. Devuelve las piezas puestas.
static func equipar(id: String, modelo: Node3D) -> Array[Node3D]:
	var puestas: Array[Node3D] = []
	if not EQUIPO.has(id):
		return puestas
	var sks: Array[Node] = modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return puestas
	var sk: Skeleton3D = sks[0] as Skeleton3D
	# Escala del esqueleto respecto al modelo (para que las piezas midan lo mismo en cualquier rig).
	var escala: float = 1.0
	var n: Node = sk
	while n != null and n != modelo:
		if n is Node3D:
			escala *= (n as Node3D).scale.y
		n = n.get_parent()
	for e in EQUIPO[id]:
		var datos: Array = e
		var hueso: int = _hueso(sk, String(datos[1]))
		if hueso < 0:
			continue
		var at := BoneAttachment3D.new()
		at.bone_name = sk.get_bone_name(hueso)
		sk.add_child(at)
		var p: Node3D = pieza(String(datos[0]))
		p.position = (datos[2] as Vector3) / maxf(escala, 0.0001)
		p.rotation_degrees = datos[3] as Vector3
		p.scale = Vector3.ONE / maxf(escala, 0.0001)
		if datos.size() > 4:
			p.scale *= datos[4] as Vector3    # quinto dato opcional: multiplicador de escala por eje de la pieza
		p.set_meta("equipo_id", String(datos[0]))     # para que quien lo necesite lo encuentre (Pj3D.poner_equipo_visible)
		at.add_child(p)
		if datos.size() > 5 and datos[5] is Dictionary:
			var extra: Dictionary = datos[5] as Dictionary
			if extra.get("vertical", false):
				# Pieza que se lleva SIEMPRE DE PIE aunque la mano gire (PiezaVertical3D). Hace falta en la cruz-bastón de la
				# Santa Compaña: su andar es el de quien porta una lanza, y colgada del hueso sin más salía horizontal.
				# Se SACA del BoneAttachment3D y se cuelga del modelo: si siguiera siendo hija del hueso, al actualizarse este
				# la pieza heredaría su giro otra vez y volvería a torcerse, por mucho que se le fije la transformación global.
				at.remove_child(p)
				modelo.add_child(p)
				var vert := PiezaVertical3D.new()
				vert.name = "Vertical"
				modelo.add_child(vert)
				vert.preparar(p, modelo, sk, hueso, extra)
			else:
				# Sexto dato opcional: pieza APOYADA en el suelo y vertical, que solo sigue a la mano (PiezaApoyada3D).
				var apoyo := PiezaApoyada3D.new()
				apoyo.name = "Apoyo"
				at.add_child(apoyo)
				apoyo.preparar(p, modelo, sk, hueso, extra)
				# `empunar`: la muñeca se pone atravesada al palo para que los dedos puedan rodearlo (ManoEmpuna3D). Es un
				# modificador del esqueleto: se añade DESPUÉS de los que ya tenga (ProporcionChibi), así que actúa sobre su resultado.
				if bool(extra.get("empunar", false)):
					var mano := ManoEmpuna3D.new()
					mano.name = "ManoEmpuna"
					sk.add_child(mano)
					mano.palma_hacia = extra.get("empunar_palma_hacia", Vector3.ZERO)
					mano.preparar(sk, hueso, float(extra.get(PiezaApoyada3D.K_LADO, -1.0)), apoyo, modelo)
		puestas.append(p)
	return puestas


static func _hueso(sk: Skeleton3D, fin: String) -> int:
	for i in range(sk.get_bone_count()):
		var nombre: String = sk.get_bone_name(i)
		if nombre == fin or nombre.ends_with(":" + fin) or nombre.ends_with("_" + fin):
			return i
	return -1


## La pieza `id`, por este orden:
##   1. poc_25d/equipo/<id>.glb, si existe (ya orientado: mango en el origen hacia +Y; escudo con la cara a +Y).
##      garrote.glb, escudo.glb y daga.glb salen de armas_goblin.glb con el mismo giro y medida que _orientar,
##      horneados en la malla y con la textura a 1024 (las armas se ven pequeñas).
##   2. la pieza <id> de una biblioteca de equipo (armas_goblin.glb), que se orienta y escala aquí (MEDIDA_PIEZA)
##   3. la versión sencilla hecha por código
static func pieza(id: String) -> Node3D:
	if id == "grimorio" and ResourceLoader.exists(CARPETA + "grimorio_%d.glb" % nivel_grimorio):
		var g: Node3D = (load(CARPETA + "grimorio_%d.glb" % nivel_grimorio) as PackedScene).instantiate() as Node3D
		g.name = "grimorio"
		return g
	if id == BASTON_CHAMAN_ID:
		return BastonChaman3D.crear()
	var ruta: String = CARPETA + id + ".glb"
	if not ResourceLoader.exists(ruta):
		ruta = CARPETA_MODELOS + id + ".glb"
	if ResourceLoader.exists(ruta):
		var ps: PackedScene = load(ruta) as PackedScene
		if ps != null:
			return ps.instantiate() as Node3D
	var de_biblioteca: Node3D = _de_biblioteca(id)
	if de_biblioteca != null:
		return de_biblioteca
	match id:
		"garrote":
			return _garrote()
		"escudo":
			return _escudo()
		"grimorio":
			return _grimorio()
		"pluma":
			return _pluma()
		"carcaj":
			return _carcaj()
	return Node3D.new()


## Bibliotecas de equipo (un GLB con una pieza por nodo, separadas con meshy/agrupar_3d.py).
const BIBLIOTECAS_EQUIPO: Array = ["res://arte/equipo/armas_goblin.glb", "res://arte/meshy/magia.glb"]
## Medida de cada pieza de biblioteca, en unidades del goblin (mide 1,7): largo de las armas, diámetro del escudo.
## `pocion` (6.12c, de meshy/magia.glb): 0,38 de alto = la mitad de la que se ve en el suelo respecto al goblin; Pj3D.equipar la reescala al personaje.
const MEDIDA_PIEZA: Dictionary = {"garrote": 0.62, "espada_goblin": 0.58, "daga": 0.5, "escudo": 0.5, "pocion": 0.38}
## Dónde se agarra un arma, en fracción de su largo desde abajo.
const AGARRE: float = 0.14

static func _de_biblioteca(id: String) -> Node3D:
	for r in BIBLIOTECAS_EQUIPO:
		if not ResourceLoader.exists(String(r)):
			continue
		var lib: Node = (load(String(r)) as PackedScene).instantiate()
		var n: Node = lib.find_child(id, true, false)
		var res: Node3D = null
		if n is Node3D:
			var copia: Node3D = (n as Node3D).duplicate() as Node3D
			copia.transform = Transform3D.IDENTITY
			res = _orientar(copia, id)
		lib.free()
		if res != null:
			return res
	return null


## Meshy las deja de pie y de frente: armas con la hoja/cabeza hacia +Y y escudo con la cara hacia +Z.
## Aquí: armas con el agarre en el origen; escudo centrado y con la cara hacia +Y (como las de código).
static func _orientar(modelo: Node3D, id: String) -> Node3D:
	var caja: AABB = _caja_de(modelo, Transform3D.IDENTITY)
	var raiz := Node3D.new()
	raiz.name = id
	var giro := Node3D.new()
	raiz.add_child(giro)
	giro.add_child(modelo)
	var medida: float = float(MEDIDA_PIEZA.get(id, 0.5))
	if id == "pocion":
		# Un frasco: centrado en su caja y de pie (+Y arriba); la mano lo agarra por el medio.
		var fp: float = medida / maxf(caja.size.y, 0.0001)
		modelo.scale = Vector3.ONE * fp
		modelo.position = -caja.get_center() * fp
	elif id == "escudo":
		var f: float = medida / maxf(caja.size.x, caja.size.y)
		modelo.scale = Vector3.ONE * f
		modelo.position = -caja.get_center() * f
		giro.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	else:
		var f2: float = medida / maxf(caja.size.y, 0.0001)
		modelo.scale = Vector3.ONE * f2
		var agarre := Vector3(caja.get_center().x, caja.position.y + caja.size.y * AGARRE, caja.get_center().z)
		modelo.position = -agarre * f2
	return raiz


static func _caja_de(n: Node, acum: Transform3D) -> AABB:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	var res := AABB()
	var vacia: bool = true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		res = t * (n as MeshInstance3D).mesh.get_aabb()
		vacia = false
	for h in n.get_children():
		var sub: AABB = _caja_de(h, t)
		if sub.size != Vector3.ZERO:
			res = sub if vacia else res.merge(sub)
			vacia = false
	return res


## Garrote de madera con dos tachuelas y una venda de cuerda en el mango. Mango en el origen, a lo largo de +Y.
static func _garrote() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "garrote"
	_parte(raiz, _cilindro(0.022, 0.028, 0.26), MADERA, Vector3(0.0, 0.0, 0.0))
	_parte(raiz, _cilindro(0.032, 0.032, 0.06), CUERDA, Vector3(0.0, -0.02, 0.0))
	_parte(raiz, _cilindro(0.07, 0.04, 0.26), MADERA_CLARA, Vector3(0.0, 0.24, 0.0))
	_parte(raiz, _esfera(0.07), MADERA_CLARA, Vector3(0.0, 0.37, 0.0))
	for i in range(3):
		var ang: float = float(i) / 3.0 * TAU
		var cono := _parte(raiz, _cilindro(0.0, 0.022, 0.06), HIERRO,
			Vector3(cos(ang) * 0.07, 0.29 + float(i) * 0.03, sin(ang) * 0.07))
		cono.rotation = Vector3(sin(ang) * PI * 0.5, 0.0, -cos(ang) * PI * 0.5)
	return raiz


## Escudo redondo de tablas con aro de hierro y bollón. La cara mira a +Y; la correa, en el origen.
static func _escudo() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "escudo"
	_parte(raiz, _cilindro(0.2, 0.2, 0.035), MADERA, Vector3(0.0, 0.0, 0.0))
	for i in range(3):
		var tabla := _parte(raiz, _caja(Vector3(0.012, 0.004, 0.36)), MADERA_CLARA.darkened(0.15),
			Vector3(-0.1 + float(i) * 0.1, 0.019, 0.0))
		tabla.scale = Vector3(1.0, 1.0, 1.0 - absf(float(i) - 1.0) * 0.18)
	var aro := TorusMesh.new()
	aro.inner_radius = 0.185
	aro.outer_radius = 0.215
	aro.rings = 24
	aro.ring_segments = 8
	_parte(raiz, aro, HIERRO, Vector3(0.0, 0.0, 0.0))
	_parte(raiz, _esfera(0.05), HIERRO, Vector3(0.0, 0.02, 0.0)).scale = Vector3(1.0, 0.6, 1.0)
	return raiz


## Grimorio cerrado, de pie (alto +Y, lomo hacia -X, tapa hacia +Z): tapas verde azulado con esquinas y
## medallón de hoja dorados, el canto de papel, una correa de cuero y la pluma metida junto al lomo.
static func _grimorio() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "grimorio"
	var alto: float = 0.30
	var ancho: float = 0.22
	var grueso: float = 0.08
	_parte(raiz, _caja(Vector3(ancho - 0.012, alto - 0.014, grueso - 0.012)), PAPEL, Vector3(0.006, 0.0, 0.0))
	for z: float in [-1.0, 1.0]:
		_parte(raiz, _caja(Vector3(ancho, alto, 0.008)), TAPA, Vector3(0.0, 0.0, z * (grueso * 0.5 - 0.004)))
		_parte(raiz, _esfera(0.026), ORO, Vector3(0.008, 0.0, z * grueso * 0.5)).scale = Vector3(1.0, 1.0, 0.25)
		for e: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
			_parte(raiz, _caja(Vector3(0.024, 0.024, 0.01)), ORO,
				Vector3(e.x * (ancho * 0.5 - 0.012), e.y * (alto * 0.5 - 0.012), z * (grueso * 0.5 - 0.002)))
	_parte(raiz, _caja(Vector3(0.012, alto, grueso)), TAPA.darkened(0.2), Vector3(-ancho * 0.5, 0.0, 0.0))
	_parte(raiz, _caja(Vector3(0.022, 0.03, grueso + 0.006)), CUERO, Vector3(ancho * 0.5 - 0.004, 0.0, 0.0))
	var p := _pluma()
	p.position = Vector3(-ancho * 0.5 + 0.01, alto * 0.35, 0.0)
	p.rotation_degrees = Vector3(0.0, 0.0, 12.0)
	raiz.add_child(p)
	return raiz


## Pluma de escribir: cañón dorado y pluma crema con la punta verde azulada. Base en el origen, hacia +Y.
static func _pluma() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "pluma"
	_parte(raiz, _cilindro(0.004, 0.002, 0.05), ORO, Vector3(0.0, 0.025, 0.0))
	var aleta := _parte(raiz, _esfera(0.03), PAPEL, Vector3(0.0, 0.11, 0.0))
	aleta.scale = Vector3(0.75, 2.4, 0.12)
	var punta := _parte(raiz, _esfera(0.018), TAPA, Vector3(0.0, 0.17, 0.0))
	punta.scale = Vector3(0.8, 1.6, 0.12)
	return raiz


## Carcaj del arquero (5/11): tubo de cuero a lo largo de +Y (0,42 de alto, centrado) con tres flechas de equipo/flecha.glb (0,6 de largo, punta hacia +Y) metidas del
## revés: las plumas asoman 0,2 por la boca. Pablo lo pidió con un clip 2D de referencia (el goblin saca la flecha del carcaj por encima del hombro).
static func _carcaj() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "carcaj"
	_parte(raiz, _cilindro(0.055, 0.045, 0.42), CUERO, Vector3.ZERO)
	_parte(raiz, _cilindro(0.062, 0.062, 0.04), CUERO.darkened(0.25), Vector3(0.0, 0.19, 0.0))
	_parte(raiz, _cilindro(0.058, 0.058, 0.03), CUERDA, Vector3(0.0, -0.12, 0.0))
	var ruta: String = CARPETA + "flecha.glb"
	if ResourceLoader.exists(ruta):
		var ps: PackedScene = load(ruta) as PackedScene
		for i in range(3):
			var ang: float = float(i) / 3.0 * TAU
			var f: Node3D = ps.instantiate() as Node3D
			f.position = Vector3(cos(ang) * 0.022, 0.21 - 0.3 + 0.2, sin(ang) * 0.022)
			f.rotation_degrees = Vector3(180.0 + (3.0 if i == 1 else -3.0), 0.0, 4.0 * cos(ang))
			raiz.add_child(f)
	return raiz


static func _parte(padre: Node3D, malla: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.metallic_specular = 0.2
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = m
	mi.position = pos
	padre.add_child(mi)
	return mi


static func _cilindro(arriba: float, abajo: float, alto: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = arriba
	c.bottom_radius = abajo
	c.height = alto
	c.radial_segments = 10
	c.rings = 1
	return c


static func _esfera(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	return s


static func _caja(t: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = t
	return b
