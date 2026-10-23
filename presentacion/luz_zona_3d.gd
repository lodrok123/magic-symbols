class_name LuzZona3D
extends RefCounted
## LUZ POR ZONA (F1 y F3 de PLAN_EOW, Pipeline, 21/10). Qué luz tiene cada zona del juego y cómo se aplica.
##
## POR QUÉ. En Echoes of Wisdom (ANALISIS_EOW §5) cada mazmorra se tiñe con UNA sola luz direccional casi cenital cuyo COLOR da el tono de la
## zona, más un ambiente de DOS colores (el cielo arriba, el rebote del suelo abajo). Así el bosque, las ruinas y la cueva se leen distintos
## sin tocar ni un material. Antes la maqueta tenía el sol fijo y el ambiente de un solo color, y cambiar el tono de una zona era tocar el
## código de la escena. Ahora es una fila de `ZONAS`.
##
## QUÉ HAY AQUÍ.
##   · `ZONAS`: nombre → sol (color, energía, inclinación, giro) y ambiente (color de arriba, color de abajo, energía).
##   · `aplicar(env, sol, zona)`: pone todo eso en un Environment y un DirectionalLight3D que ya existen. Devuelve false si la zona no existe
##     (y no toca nada: la escena sigue como estaba).
##   · `sonda_reflejos(...)`: el ReflectionProbe de la sala (F3), para que el agua y el hielo reflejen LO QUE HAY ALREDEDOR en lugar de un color plano.
##
## AMBIENTE DE DOS COLORES. Godot no tiene «ambiente hemisférico» directo. Se consigue con un Sky procedural (arriba, horizonte, abajo) y
## `AMBIENT_SOURCE_SKY`; el FONDO sigue siendo un color liso (`BG_COLOR`), así que lo que ve la cámara no cambia: el Sky solo alumbra. Si los
## dos colores son iguales (la zona `clasico`), el resultado es idéntico al ambiente plano de antes: medido en la prueba.
##
## SOBRE EL ÁNGULO DEL SOL (V2 de PLAN_EOW_VISUAL, 21/10). EoW usa una luz casi cenital (15-20° respecto a la vertical). La maqueta tenía -55° (35°
## de la vertical): sombras largas hacia el fondo. Ahora la zona por defecto («bosque») usa `SOL_INCLINACION` (-70° = 20° de la vertical), con sombras
## cortas bajo los objetos. Se ajusta con esa constante; y «clasico» conserva la luz de antes (-55°, ambiente liso, sombra en cascadas) para comparar.
##
## SOMBRA. El sol proyecta con UNA sola caja ortogonal (`SOMBRA_MODO`) en vez de las 4 cascadas por defecto: la cámara es ortogonal y fija, así que
## las cascadas solo repartían resolución para una perspectiva que aquí no existe, y dejaban costuras entre cortes. `SOMBRA_DISTANCIA` es lo que
## cubre desde la cámara y `SOMBRA_BLUR` suaviza el borde (PCSS barato). Cada zona puede sobrescribir los tres con `sombra_modo`, `sombra_distancia`, `sombra_blur`.

## Inclinación del sol de las zonas nuevas (grados; negativo = mira hacia abajo). -90 = vertical. Como antes: -55.
const SOL_INCLINACION: float = -70.0
## Sombra del sol. Como antes: PARALLEL_4_SPLITS, 30 u, blur 1,0.
const SOMBRA_MODO: int = DirectionalLight3D.SHADOW_ORTHOGONAL
const SOMBRA_DISTANCIA: float = 35.0
const SOMBRA_BLUR: float = 1.6
const ZONAS: Dictionary = {
	# V2: sol cálido casi cenital y AMBIENTE DE DOS COLORES de verdad: el cielo (azul lila claro) alumbra lo que mira arriba y el rebote del
	# suelo (verde seco cálido) lo que mira abajo y los costados. Antes los dos eran iguales y el ambiente era un color plano.
	"bosque": {
		"sol_color": Color(1.0, 0.96, 0.88), "sol_energia": 1.0, "sol_pitch": SOL_INCLINACION, "sol_yaw": 25.0,
		"ambiente_arriba": Color(0.88, 0.92, 1.0), "ambiente_abajo": Color(0.80, 0.78, 0.58), "ambiente_energia": 0.6,
	},
	# Lo que había ANTES de V2 en la maqueta, tal cual: sol cálido a -55°, ambiente lila claro liso a 0,6 y sombra en 4 cascadas. Sirve para comparar.
	"clasico": {
		"sol_color": Color(1.0, 0.96, 0.88), "sol_energia": 1.0, "sol_pitch": -55.0, "sol_yaw": 25.0,
		"ambiente_arriba": Color(0.95, 0.94, 1.0), "ambiente_abajo": Color(0.95, 0.94, 1.0), "ambiente_energia": 0.6,
		"sombra_modo": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "sombra_distancia": 30.0, "sombra_blur": 1.0,
	},
	# Zona de AGUA (ejemplo de V2): luz fría azulada, rebote del suelo azul profundo. Pensada para la sala del estanque.
	"agua": {
		"sol_color": Color(0.72, 0.87, 1.0), "sol_energia": 0.95, "sol_pitch": SOL_INCLINACION, "sol_yaw": 10.0,
		"ambiente_arriba": Color(0.66, 0.82, 1.0), "ambiente_abajo": Color(0.40, 0.58, 0.78), "ambiente_energia": 0.65,
	},
	# Zona de FUEGO (ejemplo de V2): luz cálida anaranjada, rebote del suelo rojizo oscuro. Pensada para la sala de los braseros.
	"fuego": {
		"sol_color": Color(1.0, 0.72, 0.45), "sol_energia": 1.0, "sol_pitch": SOL_INCLINACION, "sol_yaw": 35.0,
		"ambiente_arriba": Color(0.96, 0.80, 0.66), "ambiente_abajo": Color(0.62, 0.36, 0.26), "ambiente_energia": 0.55,
	},	# Final de tarde: sol naranja y bajo; el cielo azulado y el rebote del suelo cálido.
	"atardecer": {
		"sol_color": Color(1.0, 0.78, 0.55), "sol_energia": 1.05, "sol_pitch": -38.0, "sol_yaw": 40.0,
		"ambiente_arriba": Color(0.70, 0.76, 0.98), "ambiente_abajo": Color(0.88, 0.70, 0.55), "ambiente_energia": 0.55,
	},
	# Ruinas húmedas: luz fría verdosa, rebote musgoso.
	"ruinas": {
		"sol_color": Color(0.82, 0.95, 0.92), "sol_energia": 0.9, "sol_pitch": -62.0, "sol_yaw": 15.0,
		"ambiente_arriba": Color(0.78, 0.90, 0.95), "ambiente_abajo": Color(0.60, 0.72, 0.58), "ambiente_energia": 0.6,
	},
	# Cueva (23/10, docs/PLAN_BOSQUE_EOW.md §6): casi a oscuras. Un sol frío y débil (la luz que entra por arriba) y un ambiente bajo y azulado;
	# lo que de verdad alumbra son los braseros y los cristales, que con este fondo se notan.
	"cueva": {
		"sol_color": Color(0.62, 0.70, 0.86), "sol_energia": 0.35, "sol_pitch": -78.0, "sol_yaw": 10.0,
		"ambiente_arriba": Color(0.42, 0.48, 0.60), "ambiente_abajo": Color(0.26, 0.26, 0.30), "ambiente_energia": 0.45,
	},
	# Santuario (23/10, docs/PLAN_BOSQUE_EOW.md §3 sala 7): verdoso oscuro, para el elemental. Sol bajo y verde apagado, ambiente de musgo y sombra.
	"santuario": {
		"sol_color": Color(0.62, 0.86, 0.66), "sol_energia": 0.6, "sol_pitch": -66.0, "sol_yaw": 20.0,
		"ambiente_arriba": Color(0.48, 0.66, 0.54), "ambiente_abajo": Color(0.22, 0.34, 0.26), "ambiente_energia": 0.5,
	},
	# Cueva / hielo: luz azul pálida, ambiente oscuro con rebote azul.
	"hielo": {
		"sol_color": Color(0.80, 0.90, 1.0), "sol_energia": 0.85, "sol_pitch": -70.0, "sol_yaw": 0.0,
		"ambiente_arriba": Color(0.72, 0.84, 1.0), "ambiente_abajo": Color(0.55, 0.66, 0.85), "ambiente_energia": 0.65,
	},
}

## Orden fijo para recorrerlas con una tecla.
const ORDEN: Array = ["bosque", "clasico", "atardecer", "ruinas", "hielo", "agua", "fuego", "cueva", "santuario"]


static func nombres() -> Array:
	return ORDEN.duplicate()


## La siguiente zona de la lista (vuelve al principio). Si `actual` no existe, devuelve la primera.
static func siguiente(actual: String) -> String:
	var i: int = ORDEN.find(actual)
	return String(ORDEN[(i + 1) % ORDEN.size()])


## Pone la zona en el entorno y el sol. No crea nodos: modifica los que le pasan. Devuelve false (sin tocar nada) si la zona no existe.
static func aplicar(env: Environment, sol: DirectionalLight3D, zona: String) -> bool:
	if not ZONAS.has(zona):
		return false
	var z: Dictionary = ZONAS[zona]
	if sol != null:
		sol.light_color = z["sol_color"]
		sol.light_energy = float(z["sol_energia"])
		sol.rotation_degrees = Vector3(float(z["sol_pitch"]), float(z["sol_yaw"]), 0.0)
		sol.directional_shadow_mode = int(z.get("sombra_modo", SOMBRA_MODO)) as DirectionalLight3D.ShadowMode
		sol.directional_shadow_max_distance = float(z.get("sombra_distancia", SOMBRA_DISTANCIA))
		sol.shadow_blur = float(z.get("sombra_blur", SOMBRA_BLUR))
	if env != null:
		ambiente_dos_colores(env, z["ambiente_arriba"], z["ambiente_abajo"], float(z["ambiente_energia"]))
	return true


## --- Bloque 3 EoW (23/10): PASAR DE UNA ZONA A OTRA sin salto (Zonas3D). ---
## Los números de una zona que se pueden interpolar (los de la sombra no: se ponen al final del cambio). {} si la zona no existe.
static func valores(zona: String) -> Dictionary:
	if not ZONAS.has(zona):
		return {}
	var z: Dictionary = ZONAS[zona]
	return {"sol_color": z["sol_color"], "sol_energia": float(z["sol_energia"]), "sol_pitch": float(z["sol_pitch"]), "sol_yaw": float(z["sol_yaw"]),
		"ambiente_arriba": z["ambiente_arriba"], "ambiente_abajo": z["ambiente_abajo"], "ambiente_energia": float(z["ambiente_energia"])}


## Mezcla de dos juegos de `valores` (`t` 0 = a, 1 = b).
static func mezclar(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var r: Dictionary = {}
	for k in b:
		if not a.has(k):
			r[k] = b[k]
		elif b[k] is Color:
			r[k] = (a[k] as Color).lerp(b[k] as Color, t)
		elif k == "sol_yaw":
			r[k] = rad_to_deg(lerp_angle(deg_to_rad(float(a[k])), deg_to_rad(float(b[k])), t))
		else:
			r[k] = lerpf(float(a[k]), float(b[k]), t)
	return r


## Pone unos `valores` (los de `valores()` o una mezcla) en el sol y el ambiente. Si el Environment ya tiene el cielo de dos colores, cambia sus
## colores en el sitio (un Sky nuevo por fotograma volvería a calcular la radiancia cada vez).
static func aplicar_valores(env: Environment, sol: DirectionalLight3D, v: Dictionary) -> void:
	if v.is_empty():
		return
	if sol != null:
		sol.light_color = v["sol_color"]
		sol.light_energy = float(v["sol_energia"])
		sol.rotation_degrees = Vector3(float(v["sol_pitch"]), float(v["sol_yaw"]), 0.0)
	if env == null:
		return
	var mat: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	if mat == null:
		ambiente_dos_colores(env, v["ambiente_arriba"], v["ambiente_abajo"], float(v["ambiente_energia"]))
		return
	var arriba: Color = v["ambiente_arriba"]
	var abajo: Color = v["ambiente_abajo"]
	var medio: Color = arriba.lerp(abajo, 0.5)
	mat.sky_top_color = arriba
	mat.sky_horizon_color = medio
	mat.ground_horizon_color = medio
	mat.ground_bottom_color = abajo
	env.ambient_light_energy = float(v["ambiente_energia"])


## La sombra de una zona (lo que no se interpola): al terminar el cambio.
static func aplicar_sombra(sol: DirectionalLight3D, zona: String) -> void:
	if sol == null or not ZONAS.has(zona):
		return
	var z: Dictionary = ZONAS[zona]
	sol.directional_shadow_mode = int(z.get("sombra_modo", SOMBRA_MODO)) as DirectionalLight3D.ShadowMode
	sol.directional_shadow_max_distance = float(z.get("sombra_distancia", SOMBRA_DISTANCIA))
	sol.shadow_blur = float(z.get("sombra_blur", SOMBRA_BLUR))


## Ambiente de dos colores: `arriba` alumbra lo que mira al cielo y `abajo` lo que mira al suelo. El fondo del Environment NO cambia.
static func ambiente_dos_colores(env: Environment, arriba: Color, abajo: Color, energia: float) -> void:
	var mat := ProceduralSkyMaterial.new()
	# El horizonte es la media: sin esto se ve una costura dura entre los dos colores en el reflejo de superficies pulidas.
	var medio: Color = arriba.lerp(abajo, 0.5)
	mat.sky_top_color = arriba
	mat.sky_horizon_color = medio
	mat.ground_horizon_color = medio
	mat.ground_bottom_color = abajo
	mat.sky_curve = 0.15
	mat.ground_curve = 0.15
	mat.sun_angle_max = 0.0              # sin disco de sol pintado en el cielo: el sol real es la DirectionalLight3D
	var cielo := Sky.new()
	cielo.sky_material = mat
	cielo.radiance_size = Sky.RADIANCE_SIZE_32   # el ambiente es difuso: 32 px bastan y cuesta casi nada
	env.sky = cielo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = energia


## --- Agua EoW (22/10, PLAN_EOW_VISUAL §1.6): UNA SONDA POR SALA. ---
## Qué es una «sala»: en los DATOS no hay una definición general (el `sala=` de un cerrojo de Puzle3D es el rectángulo que cierra las puertas, no una región del mapa, y un
## nivel como el Bosque 01 no tiene salas). Lo único que hay son los laboratorios (LabPlaytestEoW3D, LabPuzlesAgua3D, LabPuzlesFuego3D), cuyas constantes `SALAS` traen cada una su
## `rect` en casillas; ahora los tres lo ofrecen con `salas_rects()`. Si el nivel no tiene ese método (el Bosque 01, el Test 2…) se parte el mapa en bloques de `SONDA_BLOQUE`
## × `SONDA_BLOQUE` casillas. En los dos casos solo se pone sonda donde la región contiene agua o hielo (el hielo es siempre agua helada: una casilla con agua).
## Tamaño (en casillas) de los bloques cuando el nivel no tiene salas. Un río de 52 × 44 casillas da unas 6–8 sondas.
const SONDA_BLOQUE: int = 12
## Casillas que se añaden alrededor del agua (hasta el borde del mapa) para que la caja alcance orillas, árboles y rocas que se reflejan.
const SONDA_MARGEN: int = 2
## Alto (u) de la caja de cada sonda y altura (u) del punto desde el que se hornea.
const SONDA_ALTO: float = 10.0
const SONDA_Y: float = 3.0


## Las cajas de las sondas, en casillas: una por región que contenga agua. `hay_agua(Vector2i) -> bool` dice si una casilla es agua; `regiones` son las salas
## (Array de Rect2i) o vacío para usar bloques de `bloque` × `bloque`. Cada caja es el rectángulo mínimo que envuelve el agua de la región, ensanchado `margen` casillas y recortado al mapa
## (`ancho` × `alto`). Devuelve Array de Rect2i; regiones sin agua no devuelven nada.
static func cajas_sondas(hay_agua: Callable, ancho: int, alto: int, regiones: Array, bloque: int = SONDA_BLOQUE, margen: int = SONDA_MARGEN) -> Array:
	var cajas: Array = []
	var zonas: Array = []
	var limites: Array = []        # hasta dónde puede llegar la caja de cada zona: una sala, su rectángulo; un bloque, el bloque con el margen (el agua del borde conserva su entorno)
	if regiones.is_empty():
		var b: int = maxi(bloque, 1)
		for y0 in range(0, alto, b):
			for x0 in range(0, ancho, b):
				var rb := Rect2i(x0, y0, mini(b, ancho - x0), mini(b, alto - y0))
				zonas.append(rb)
				limites.append(rb.grow(margen))
	else:
		zonas = regiones
		limites = regiones
	for i in range(zonas.size()):
		var r: Rect2i = zonas[i]
		var lim: Rect2i = (limites[i] as Rect2i).intersection(Rect2i(0, 0, ancho, alto))
		var minx: int = 1 << 30
		var miny: int = 1 << 30
		var maxx: int = -1
		var maxy: int = -1
		for y in range(maxi(r.position.y, 0), mini(r.end.y, alto)):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, ancho)):
				if bool(hay_agua.call(Vector2i(x, y))):
					minx = mini(minx, x)
					miny = mini(miny, y)
					maxx = maxi(maxx, x)
					maxy = maxi(maxy, y)
		if maxx < 0:
			continue
		var x0c: int = maxi(minx - margen, lim.position.x)
		var y0c: int = maxi(miny - margen, lim.position.y)
		var x1c: int = mini(maxx + margen + 1, lim.end.x)
		var y1c: int = mini(maxy + margen + 1, lim.end.y)
		cajas.append(Rect2i(x0c, y0c, x1c - x0c, y1c - y0c))
	return cajas


## Crea las sondas de `cajas` (casillas de lado `casilla` u), una por caja, horneadas una vez. Devuelve las sondas.
static func sondas_por_cajas(padre: Node, cajas: Array, casilla: float, intensidad: float = 0.8) -> Array:
	var sondas: Array = []
	var n: int = 0
	for c in cajas:
		var r: Rect2i = c
		var centro := Vector3((float(r.position.x) + float(r.size.x) * 0.5) * casilla, SONDA_Y, (float(r.position.y) + float(r.size.y) * 0.5) * casilla)
		var s: ReflectionProbe = sonda_reflejos(padre, centro, Vector3(float(r.size.x) * casilla, SONDA_ALTO, float(r.size.y) * casilla), intensidad)
		n += 1
		s.name = "SondaReflejos_%d" % n
		sondas.append(s)
	return sondas


## F3: UNA sonda de reflejos para la sala (el agua y el hielo ya fijan ROUGHNESS y SPECULAR, así que la leen sin cambiar su shader).
## `UPDATE_ONCE`: se hornea al entrar y no vuelve a costar nada. `centro` y `tam` son del volumen que cubre (la sala entera, un poco más alta
## que lo más alto). La resolución NO es propiedad de la sonda: es el ajuste de proyecto `rendering/reflections/reflection_atlas/reflection_size`.
static func sonda_reflejos(padre: Node, centro: Vector3, tam: Vector3, intensidad: float = 0.8) -> ReflectionProbe:
	var s := ReflectionProbe.new()
	s.name = "SondaReflejos"
	s.update_mode = ReflectionProbe.UPDATE_ONCE
	s.size = tam
	s.intensity = intensidad
	s.box_projection = true               # los reflejos se proyectan sobre la caja de la sala, no al infinito: el agua refleja LOS ÁRBOLES, no «el cielo»
	s.interior = false
	s.max_distance = maxf(tam.x, tam.z) * 1.5
	s.ambient_mode = ReflectionProbe.AMBIENT_DISABLED   # el ambiente ya lo pone el Environment; así la sonda solo aporta reflejos
	padre.add_child(s)
	s.global_position = centro
	return s
