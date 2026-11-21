class_name TierraToy
extends EfectoToy

## TIERRA «TOY» (6/11/2026; docs/PLAN_VFX_ELEMENTOS.md §2.5, referencia Zelda: Echoes of Wisdom). Clase HERMANA de FuegoToy, AguaToy, HieloToy, RayoToy y VientoToy: misma API, mismas cinco
## figuras (BOLA, MURO, PILAR, BARRERA, HAZ), mismos ejes (semieje_x / y / z en m), misma escala (`describir` / `desde_hechizo` son los de FuegoToy) y los mismos diez mandos de EfectoToy
## (valen `altura`, `ancho`, `velocidad`, `brillo` y `chispas` = cuántos terrones y cuánto polvo; luz, halo, tono y blandura no hacen nada: la tierra no brilla). Máquina de carga e impacto copiada
## de HieloToy, no compartida.
## CARÁCTER (2.ª versión, 6/11 tarde: LA PIEDRA DEL MUNDO): las figuras están hechas de las ROCAS ESTILIZADAS DEL MAPA (arte/meshy/piezas/roca_est_0..4 grandes y piedra_est_0..4
## pequeñas, las mismas que ArteEntorno3D, Pieza3D y los bloques empujables) con SU textura gris (tex_rocas_est/rocas_albedo.png) y la LUZ DE LA ESCENA (tierra_roca.gdshader: mate, sin
## especular, con un velo ligero de Vfx3D.COLOR["piedra"] y la base manchada de tierra), así casan con los pedruscos grises que ya dibuja el juego. Las mallas se cargan del GLB una vez
## (`malla_roca`, como ImpactoMagmaToy.malla_piedra). Y con PESO: los bloques SUBEN DEL SUELO con ANTICIPACIÓN (0,1 s de temblor y polvo en la base), SOBREPASO y ASENTAMIENTO (polvo radial
## bajo + 2-3 fragmentos que ruedan) y al morir se HUNDEN en el suelo con polvo (no se desvanecen). El polvo es humo toon PARDO de dos tonos (humo_toy.gd), al tono de la tierra del suelo del
## bosque. Sin luz, sin aditivos, sin GPUParticles3D: MultiMesh movidos por la CPU (uno por tipo de roca que use la figura, ≤ 5; ≤ MAX_BLOQUES rocas por figura).
## FIGURAS: BOLA = una piedra_est_0 (la más redonda) que gira al volar y suelta terrones (piedra_est_1) y polvo. MURO = hilera de roca_est_1 / 2 / 0 escaladas al ancho y alto de los
## semiejes, a trompicones, con piedras pequeñas al pie. PILAR = una roca_est_4 alta con cuatro roca_est_1 / 0 más bajas alrededor y piedras al pie. BARRERA = corona de rocas inclinadas hacia
## dentro sobre la elipse del suelo, CERRADA ARRIBA con 2-3 losas (cúpula) y un destello de polvo al cerrarse. HAZ = PÚAS que brotan en secuencia (abajo).
## La línea usa tres rocas estilizadas del pack de LeLu como púas. Cada púa brota inclinada desde el terreno con sus lajas, polvo y cascotes.
## Las púas crecen y se retiran en secuencia del origen hacia la punta. ≤ MAX_BLOQUES instancias en ≤ 5 MultiMesh.
##   CARGA: además de la convergencia, un ANILLO DE AVISO de N_AVISO piedrecitas que gira a ras de suelo bajo los pies (`pies`) mientras se carga.
##   El empuje lo hace la lógica (`fuerza_golpe` de la runa): el toy solo lo representa.
## Ciclo de vida de un proyectil de tierra, sobre UN SOLO nodo (igual que las hermanas):
##   empezar_carga(duracion, tam_final)  piedrecitas que CONVERGEN en la mano mientras la roca crece en ella. NO hace falta `lanzar()`.
##   progreso_carga() -> float · soltar(dir) · cancelar_carga() · impactar_en(pos, normal, escala) (ImpactoTierraToy GOLPE: piedrecitas con gravedad + nube de polvo pardo a ras de suelo)
##   rebotar(pos, normal) -> Vector3 · terminar_sin_choque() (la roca se deshace en terrones que caen, FIN) · finalizar(motivo, pos, normal)

enum Figura { BOLA, MURO, PILAR, BARRERA, HAZ }
enum EstadoCarga { NINGUNA, CARGANDO, SOLTANDO, APAGANDO, CANCELANDO }

const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")
const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const SH_ROCA: String = "res://presentacion/vfx/toy/tierra_roca.gdshader"
const RUTA_ROCA: String = "res://arte/meshy/piezas/%s.glb"                                   ## piedra_est_0..4 (pequeñas, 0,4-0,8 m) y roca_est_0..4 (grandes, 0,8-1,3 m), base en y = 0
const TEX_ALBEDO: String = "res://arte/meshy/piezas/tex_rocas_est/rocas_albedo.png"
const MALLA_BOLA: String = "piedra_est_0"          ## la más redonda (0,82 × 0,80 × 0,74 m)
const MALLA_TERRON: String = "piedra_est_1"        ## terrones, piedrecitas y fragmentos (0,69 m, 426 vértices)
const MALLA_LOSA: String = "roca_est_2"            ## losa facetada compartida por el muro y la plataforma
const MALLAS_MURO: Array = ["roca_est_1", MALLA_LOSA, "roca_est_1", "roca_est_0", MALLA_LOSA, "roca_est_0"]   ## bloque, losa, bloque, redonda, losa, redonda (la alta roca_est_4 salía como una púa en el muro: solo en el pilar)
const MALLAS_PIE: Array = ["piedra_est_1", "piedra_est_3"]           ## dos tipos: con los 3 del muro / pilar hacen los 5 MultiMesh de tope
const MAX_TIPOS: int = 5                                              ## MultiMesh (tipos de roca) por figura como mucho
const MALLAS_PUA: Array = ["pua_0", "pua_1", "pua_2"]                ## púas con la forma de las rocas de LeLu (malla_pua), color plano pardo
const RUTA_ROCAS_LELU: String = "res://arte/rocas_lelu/sm_rocks_objects.glb"
const PUAS_LELU: Array = ["stone5", "stone6", "stone4"]                 ## roca del pack de cada variante de púa (cono, cuña, esquirla)
const MALLAS_LAJA: Array = ["laja_0", "laja_1"]                      ## lajas de losa facetadas propias (malla_laja)
const SH_GRIETAS: String = "res://presentacion/vfx/toy/tierra_grietas.gdshader"
const SH_DECAL: String = "res://presentacion/vfx/toy/decal_suelo.gdshader"      ## 7/11: decal de suelo (se pega al relieve), referencia de LeLu que paso Pablo
const COLOR_PUA: Color = Color(0.56, 0.38, 0.24)                     ## pardo tierra del suelo del bosque, subido el 7/11 (en el juego la pua quedaba muy oscura contra la hierba)
const COLOR_LAJA: Color = Color(0.56, 0.38, 0.24)               ## 7/11: igual que la púa (antes más oscura: las lajas inclinadas enseñaban su cara en sombra como un trazo negro)
## 17/11 (Pablo: «para la tierra utiliza el shader y textura de la tierra como línea»): TODA la tierra del toy (bola, muro, pilar, barrera, terrones y fragmentos) lleva el material de las
## púas de la línea (modo `plano` de tierra_roca.gdshader: estratos pardos, de la raíz oscura a la punta ocre, `ACLARA_PUA`) en vez de la textura gris de las rocas del mapa. Las mallas no
## cambian. A false, la roca gris de antes.
const TODO_COMO_LINEA: bool = true
## 18/11 (Pablo: «haz el inicio y final del pilar de tierra: crea una columna tipo la de Zhongli en Genshin Impact, pero respeta las texturas, con forma final de pico»): el PILAR es
## UNA COLUMNA PRISMÁTICA de piedra (malla propia `columna_0`: prisma de `COLUMNA_LADOS` caras, algo más estrecho en el hombro, rematado en PICO), con el material de estratos de la
## línea, y esquirlas de la misma malla alrededor de la base. Sale de golpe de una marca de tierra partida y al morir se hunde en ella. A false, las rocas del mapa de antes.
const PILAR_COLUMNA: bool = true
const MALLA_COLUMNA: String = "columna_0"
const COLUMNA_LADOS: int = 6
const COLUMNA_HOMBRO_Y: float = 0.74                                  ## altura (0-1) a la que acaba el fuste y empieza el pico
const COLUMNA_HOMBRO_R: float = 0.88                                  ## radio del hombro, en veces el de la base
const COLUMNA_PICO_DESVIO: float = 0.12                               ## cuánto se sale la punta del eje (en radios de base): un pico tallado, no un lápiz
const COLUMNA_SOBREPASO: float = 0.16                                 ## la columna se pasa esto de su sitio al salir y cae (el resto de bloques, SOBREPASO)
const PILAR_MARCA_TAM: float = 5.5                                    ## diámetro de la marca de tierra partida, en veces el semieje
const PILAR_MARCA_ALTO: float = 0.3                                   ## alto de la caja del decal (m): lo que puede subir o bajar el suelo dentro de la marca (con 0,8 la marca pintaba también 40 cm del pie de la columna: rayas negras)
const TEX_MARCA_SUELO: String = "res://assets/vfx/lelu_noise/T_Groundmark19.png"      ## la misma marca de suelo del golpe de tierra (pack de LeLu)
## 18/11 (Pablo: «haz el inicio y final del muro de tierra. Como idea crea una grieta que va expandiendo y con humo arenoso alrededor, crea un inicio lento. Deshaz las rocas en pequeñas
## rocas como si estallaran»). A false, el muro de antes (sale en 0,55 s y se hunde).
##   INICIO LENTO (`T_NACER_MURO`): en la primera parte (`MURO_GRIETA_FRAC`) solo hay una GRIETA que se abre del centro hacia los dos extremos, con polvo arenoso en sus dos frentes;
##   después las rocas salen de ella, del centro a los extremos.
##   FINAL (`T_MORIR_MURO`): las rocas tiemblan y ESTALLAN, cada una en `MURO_TROZOS` piedras pequeñas que saltan y caen, con polvo; no se hunden.
const MURO_INICIO_FINAL: bool = true
const T_NACER_MURO: float = 1.3
const T_MORIR_MURO: float = 0.75
const MURO_GRIETA_FRAC: float = 0.5                                   ## fracción del nacer en la que la grieta llega a los extremos (antes de que salga ninguna roca)
const MURO_SALE_FRAC: float = 0.22                                    ## lo que tarda en salir cada roca (fracción del nacer)
const MURO_ESCALON_FRAC: float = 0.24                                 ## retraso de las rocas de los extremos respecto a las del centro (fracción del nacer)
const MURO_ESTALLA_DESDE: float = 0.5                                 ## fracción del morir a la que estalla la primera roca (antes, tiemblan)
const MURO_ESTALLA_TRAMO: float = 0.3                                 ## …y en esta fracción estallan todas, del centro a los extremos
const MURO_TROZOS: int = 4                                            ## piedras pequeñas por roca
const PIEDRAS_MURO: int = 72                                          ## reserva de terrones del muro (sus rocas × MURO_TROZOS y los del asentamiento)
const MURO_POLVO_GRIETA: float = 30.0                                 ## bocanadas de polvo por segundo en los frentes de la grieta
## 21/11 (Pablo: faltan el inicio y el final de la bola, la barrera y la línea; el muro de arriba es el modelo). Cada uno con su interruptor; a false, lo de antes. Pablo: el arte de las púas
## activas y el muro quedan como están: aquí solo cambia CÓMO APARECEN Y SE VAN.
##   BOLA — INICIO (si nace sin carga, por `lanzar`): terrones y polvo que vuelan de alrededor y se COMPACTAN en la roca, que crece de aplastada a redonda (con carga, ya se hacía con el anillo
##   de piedras). FINAL (impacto o muerte en el aire): la roca desaparece y se PARTE en `BOLA_FIN_CASCOTES` cascotes grandes que saltan con polvo, además de lo de antes.
##   BARRERA — INICIO LENTO: una grieta en ANILLO corre por el suelo (`BARRERA_GRIETAS` tramos tangentes) y sobre ella las rocas brotan EN OLA alrededor, cada una con su polvo y cascotes; luego
##   las losas del techo cierran la cúpula. FINAL: primero se desploma el techo y las rocas se hunden por tramos, en ola, desmoronándose con polvo y cascotes; queda la marca de tierra partida
##   (la del pilar) y se borra.
##   HAZ — INICIO: una GRIETA corre por el suelo delante de las púas (`HAZ_GRIETA_S` s antes de la primera) con polvo en su frente, y cada púa brota tras ella (ya brotaban en orden). FINAL: las
##   púas tiemblan, se resquebrajan (cascotes y polvo) y se hunden en orden, de la mano a la punta, y la grieta se borra al final. Respeta `haz_tope`.
const BOLA_INICIO_FINAL: bool = true
const BARRERA_INICIO_FINAL: bool = true
const HAZ_INICIO_FINAL: bool = true
static var prueba_apagar: bool = false                                ## (pruebas) fuerza los tres interruptores a false sin tocar el fichero
const T_NACER_BOLA_INI: float = 0.5                                   ## s que tarda la bola sin carga en juntarse y compactarse
const BOLA_INI_TASA: float = 70.0                                     ## terrones por segundo que acuden a la roca
const BOLA_INI_RADIO: float = 2.6                                     ## de dónde parten, en veces el radio de la bola
const BOLA_INI_SUBIDA_S: float = 0.3                                  ## s que tarda cada terrón en llegar a la roca
const BOLA_FIN_CASCOTES: int = 10                                     ## cascotes grandes en que se parte la roca
const PIEDRAS_BOLA_NUEVA: int = 44                                    ## reserva de terrones de la bola con el final nuevo (los de vuelo, los de la rotura y los cascotes)
const T_NACER_BARRERA: float = 1.5
const T_MORIR_BARRERA: float = 1.1
const BARRERA_GRIETAS: int = 8                                        ## tramos de la grieta en anillo
const BARRERA_GRIETA_FRAC: float = 0.5                                ## fracción del nacer en que la grieta ha dado la vuelta entera
const BARRERA_OLA_DESDE: float = 0.12                                 ## fracción del nacer en que sale la primera roca…
const BARRERA_OLA_TRAMO: float = 0.4                                  ## …y en esta fracción salen las demás, en ola alrededor
const BARRERA_SALE_FRAC: float = 0.2                                  ## lo que tarda en salir cada roca (fracción del nacer)
const BARRERA_TECHO_DESDE: float = 0.66                               ## cuando salen las losas del techo (fracción del nacer) y el paso entre ellas
const BARRERA_TECHO_PASO: float = 0.04
const BARRERA_HUNDE_DESDE: float = 0.15                               ## fracción del morir a la que empieza a hundirse la primera roca (el techo, a 0)…
const BARRERA_HUNDE_TRAMO: float = 0.4                                ## …y en esta fracción las demás, en ola
const BARRERA_POLVO_GRIETA: float = 40.0                              ## bocanadas por segundo en el frente de la grieta de la barrera
const BARRERA_MARCA_TAM: float = 2.7                                  ## lado de la marca de tierra partida, en veces el mayor semieje
const HAZ_GRIETA_S: float = 0.3                                       ## s en que solo corre la grieta, antes de que brote la primera púa
const HAZ_T_MORIR: float = 1.0
const HAZ_POLVO_GRIETA: float = 36.0                                  ## bocanadas por segundo en el frente de la grieta del haz
const HAZ_TIEMBLA: float = 0.10                                       ## fracción del morir que tiembla cada púa antes de hundirse
const PUAS_MAX: int = 14                                              ## púas de una línea (el resto hasta MAX_BLOQUES, lajas)
const ACLARA_PUA: float = 1.15                                        ## x el albedo de la pua y la laja (7/11: en el Bosque salian casi negras contra la hierba)
const NORMAL_ARRIBA_JUEGO: float = 0.45                               ## 12/11: en el juego la normal de púas y lajas se dobla esto hacia arriba (`normal_arriba` del shader de roca: el sol casi vertical del Bosque les daba de canto)
const ANCHO_PUA: float = 0.42                                       ## ancho de la pua = este x su alto (7/11, video de tierra: roca estirada, no lamina)
const PUA_ANCHO_MAX_R: float = 2.6                                    ## x el radio del haz: tope de ese ancho (que no se salga del corredor mas de la cuenta)
const PUA_ALTO_MAX: float = 1.3                                        ## m de alto de una pua (antes salia de la altura de la mano: casi 2 m de aguja)
const PASO_PUA_S: float = 0.05                                        ## s entre el brote de una púa y la siguiente
const SUBE_PUA_S: float = 0.14                                        ## s que tarda cada púa en salir (con su sobrepaso)
const N_AVISO: int = 8                                                ## piedrecitas del anillo de aviso de la carga
## 18/11 (Pablo, con una captura del lab y flechas del anillo del suelo a la roca: «en vez de aglutinarse piedras, que las piedras que conformen la piedra grande se creen de las piedras
## que se han creado debajo»): las piedrecitas de la carga ya no nacen en el aire alrededor de la mano: SALEN de las piedras del anillo de aviso del suelo y suben a la roca.
## A false, la convergencia de antes (desde una esfera alrededor de la mano).
const CARGA_DESDE_ANILLO: bool = true
const CARGA_SUBIDA_S: float = 0.45                                    ## s que tarda cada piedrecita en subir del anillo a la roca
const GIRO_AVISO: float = 2.6                                         ## rad/s del anillo de aviso
## Velo de Vfx3D.COLOR["piedra"] (0,72·0,58·0,42) sobre la textura, MUY ligero (un 10 %): la textura rocas_albedo ya es parda y con más velo salía rosada frente a los bloques grises del mapa.
const TINTE_PIEDRA: Color = Color(0.98, 0.96, 0.93)

const REF_BOLA: Vector3 = Vector3(0.4, 0.4, 0.4)
const REF_MURO: Vector3 = Vector3(3.45, 1.5, 0.3)
const REF_PILAR: Vector3 = Vector3(0.5, 4.0, 0.5)
const REF_BARRERA: Vector3 = Vector3(1.5, 1.5, 1.5)
const REF_HAZ: Vector3 = Vector3(1.5, 0.70, 0.15)
const ENTIERRO_LINEA: float = 0.09

## Polvo pardo: dos tonos al color de la tierra del suelo del bosque (arte/suelo_meshy, en juego ≈ 0,62·0,40·0,22; docs/capturas/hierba_bloques/llanura_despues.png): claro = esa tierra
## aclarada por el polvo en el aire; sombra = la tierra húmeda; viejo = más apagado y gris. Menos naranja que la 1.ª versión (0,82·0,70·0,52).
const POLVO_CLARO: Color = Color(0.76, 0.58, 0.40)
const POLVO_SOMBRA: Color = Color(0.52, 0.36, 0.22)
const POLVO_VIEJO: Color = Color(0.47, 0.37, 0.28)

const T_SOLTAR: float = 0.14
const T_APAGAR: float = 0.4
const T_CANCELAR: float = 0.2
const RESPIRO_HZ: float = 1.4
const GIRO_QUIETA: float = 0.5
const GIRO_VUELO: float = 5.0
const T_NACER: float = 0.55             ## muro, pilar, barrera: 0,1 s de anticipación + subida con sobrepaso + asentamiento
const T_NACER_HAZ: float = 0.5
const T_NACER_BOLA: float = 0.3
const T_MORIR: float = 0.6              ## se hunde
const T_MORIR_BOLA: float = 0.4
const ANTICIPO: float = 0.1 / T_NACER   ## fracción de `sube` que dura el temblor previo
const SOBREPASO: float = 0.1            ## cuánto se pasa de su sitio antes de asentarse (fracción del alto)
const MAX_BLOQUES: int = 24
const POLVO_FIG: int = 18
const POLVO_FIG_HAZ: int = 72                                         ## el haz suelta ~5 bocanadas por púa y hasta 14 púas: reserva mayor para que no se recicle la nube de las primeras
const PIEDRAS_FIG: int = 24


# ================================================================== LAS ROCAS DEL MAPA ==================================================================
static var _mallas: Dictionary = {}        ## id ("roca_est_1") → Mesh, cargadas del GLB una vez (compartidas por todas las figuras y los impactos)


## La malla de la roca estilizada `id` (piedra_est_N / roca_est_N), cargada del GLB una vez (el mismo acceso que ImpactoMagmaToy.malla_piedra). Si faltara, una esfera de pocos lados.
## Las ids `pua_N` y `laja_N` son las mallas PROPIAS low-poly del haz (malla_pua / malla_laja), generadas una vez.
static func malla_roca(id: String) -> Mesh:
	if _mallas.has(id):
		return _mallas[id]
	var m: Mesh = null
	if id.begins_with("pua_"):
		m = malla_pua(int(id.substr(4)))
		_mallas[id] = m
		return m
	if id.begins_with("columna_"):
		m = malla_columna(int(id.substr(8)))
		_mallas[id] = m
		return m
	if id.begins_with("laja_"):
		m = malla_laja(int(id.substr(5)))
		_mallas[id] = m
		return m
	var ps: PackedScene = load(RUTA_ROCA % id) as PackedScene
	if ps != null:
		var n: Node = ps.instantiate()
		var l: Array = n.find_children("*", "MeshInstance3D", true, false)
		var mi: MeshInstance3D = n if n is MeshInstance3D else (l[0] if not l.is_empty() else null)
		if mi != null:
			m = mi.mesh
		n.free()
	if m == null:
		var s: SphereMesh = SphereMesh.new()
		s.radius = 0.35
		s.height = 0.7
		s.radial_segments = 8
		s.rings = 4
		m = s
	_mallas[id] = m
	return m


## ¿Es una pieza propia del haz (púa o laja: color plano)?
static func es_plana(id: String) -> bool:
	return id.begins_with("pua_") or id.begins_with("laja_") or id.begins_with("columna_")


## Triángulo con normal PLANA (vértices sin compartir: cada cara es una faceta), con la normal HACIA FUERA de `centro` y el orden de los vértices de cara (horario visto desde fuera, como pide
## Godot). 7/11: antes la normal salía de la regla de la mano derecha sin mirar el lado: la tapa de las lajas llevaba la normal hacia ABAJO y el sol la dejaba negra (los «trazos negros» del haz).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centro: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length() < 1.0e-9:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - centro) > 0.0:
		var x: Vector3 = b                                              # la mano derecha da antihorario desde fuera: se cambia el orden
		b = c
		c = x
	else:
		n = -n
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(v)


## PÚA: la forma de una roca del pack de LeLu (`arte/rocas_lelu/sm_rocks_objects.glb`; variante 0 -> stone5, 1 -> stone6, 2 -> stone4, la variante sin sufijo de cada una), NORMALIZADA como
## el antiguo cono: base en y = 0, centrada en x/z, alto 1 y radio de base <= 0,5 (se escala con `asentar`). Solo se toma la FORMA: se quitan los materiales (manda el `material_override`
## del MultiMesh, color plano pardo) y se conservan posiciones, normales y UV. Se calcula una vez (malla_roca la cachea).
static func malla_pua(variante: int) -> ArrayMesh:
	var nombre: String = PUAS_LELU[variante % PUAS_LELU.size()]
	var origen: Mesh = null
	var ps: PackedScene = load(RUTA_ROCAS_LELU) as PackedScene
	if ps != null:
		var n: Node = ps.instantiate()
		for mi in n.find_children(nombre, "MeshInstance3D", true, false):
			origen = (mi as MeshInstance3D).mesh
			break
		n.free()
	var res: ArrayMesh = ArrayMesh.new()
	if origen == null:
		push_warning("TierraToy: no encuentro %s en %s" % [nombre, RUTA_ROCAS_LELU])
		return res
	var caja: AABB = origen.get_aabb()
	var sy: float = 1.0 / maxf(caja.size.y, 0.001)                          # alto -> 1
	var sxz: float = minf(sy, 1.0 / maxf(maxf(caja.size.x, caja.size.z), 0.001))   # nunca mas de 1 de ancho (radio 0,5): se estrecha X/Z, no el alto
	var centro: Vector3 = caja.get_center()
	for s in range(origen.get_surface_count()):
		var arr: Array = origen.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for k in range(vs.size()):
			var p: Vector3 = vs[k]
			vs[k] = Vector3((p.x - centro.x) * sxz, (p.y - caja.position.y) * sy, (p.z - centro.z) * sxz)
			if k < ns.size():
				ns[k] = Vector3(ns[k].x / sxz, ns[k].y / sy, ns[k].z / sxz).normalized()    # normal de una escala no uniforme
		var datos: Array = []
		datos.resize(Mesh.ARRAY_MAX)
		datos[Mesh.ARRAY_VERTEX] = vs
		if ns.size() == vs.size():
			datos[Mesh.ARRAY_NORMAL] = ns
		datos[Mesh.ARRAY_TEX_UV] = arr[Mesh.ARRAY_TEX_UV]
		datos[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
		res.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)
	return res

## COLUMNA del pilar: prisma de COLUMNA_LADOS caras planas, base en y = 0, alto 1, radio de base ≤ 0,5; el fuste se estrecha un poco hasta el hombro y de ahí sale un PICO de caras
## planas con la punta algo fuera del eje. Facetas de normal plana (`_tri`). Se escala con `asentar`; las bandas de estratos van por su altura (0-1).
static func malla_columna(variante: int) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 331 + variante * 7
	var abajo: Array = []
	var hombro: Array = []
	var giro: float = rng.randf() * TAU
	for i in COLUMNA_LADOS:
		var a: float = giro + TAU * float(i) / float(COLUMNA_LADOS) + rng.randf_range(-0.07, 0.07)
		var r: float = 0.5 * rng.randf_range(0.93, 1.0)
		abajo.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
		hombro.append(Vector3(cos(a) * r * COLUMNA_HOMBRO_R, COLUMNA_HOMBRO_Y + rng.randf_range(-0.05, 0.05), sin(a) * r * COLUMNA_HOMBRO_R))
	var ap: float = rng.randf() * TAU
	var pico: Vector3 = Vector3(cos(ap) * 0.5 * COLUMNA_PICO_DESVIO, 1.0, sin(ap) * 0.5 * COLUMNA_PICO_DESVIO)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cf: Vector3 = Vector3(0.0, COLUMNA_HOMBRO_Y * 0.5, 0.0)
	var cp: Vector3 = Vector3(0.0, COLUMNA_HOMBRO_Y, 0.0)
	for i in COLUMNA_LADOS:
		var j: int = (i + 1) % COLUMNA_LADOS
		_tri(st, abajo[i], hombro[i], abajo[j], cf)                # fuste
		_tri(st, abajo[j], hombro[i], hombro[j], cf)
		_tri(st, hombro[i], pico, hombro[j], cp)                   # pico
	return st.commit()


## LAJA de losa facetada: polígono irregular de 5-6 lados extruido fino (alto 0,12 del lado), base en y = 0, lado ≈ 1.
static func malla_laja(variante: int) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 211 + variante * 5
	var lados: int = 5 + variante % 2
	var grueso: float = 0.12
	var abajo: Array = []
	var arriba: Array = []
	for i in lados:
		var a: float = TAU * float(i) / float(lados) + rng.randf_range(-0.2, 0.2)
		var r: float = rng.randf_range(0.38, 0.5)
		var p: Vector3 = Vector3(cos(a) * r, 0.0, sin(a) * r)
		abajo.append(p)
		arriba.append(p + Vector3(rng.randf_range(-0.03, 0.03), grueso + rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03)))
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ca: Vector3 = Vector3(0.0, grueso, 0.0)
	var cl: Vector3 = Vector3(0.0, grueso * 0.5, 0.0)                    # centro de la losa: hacia fuera de aquí van las normales
	for i in lados:
		var j: int = (i + 1) % lados
		_tri(st, ca, arriba[i], arriba[j], cl)                  # tapa
		_tri(st, abajo[i], arriba[i], abajo[j], cl)             # lados
		_tri(st, abajo[j], arriba[i], arriba[j], cl)
	return st.commit()


## Lado mayor (x/z) de la huella de una malla, sin escalar.
static func lado_malla(m: Mesh) -> float:
	var s: Vector3 = m.get_aabb().size
	return maxf(maxf(s.x, s.z), 0.001)


## Transformación que pone la malla (base en y = 0, no del todo centrada en x/z) con su CENTRO en `pos` y la base `b` (giro × escala): para piedras que giran en el aire.
static func centrar(m: Mesh, b: Basis, pos: Vector3) -> Transform3D:
	var a: AABB = m.get_aabb()
	return Transform3D(b, pos - b * (a.position + a.size * 0.5))


## Transformación que pone la malla con la BASE en `pos`, girada `rot`, escalada para que ocupe exactamente `wx` × `h` × `wz` m (la roca se ajusta al hueco que le toca).
static func asentar(m: Mesh, rot: Basis, wx: float, h: float, wz: float, pos: Vector3) -> Transform3D:
	var a: AABB = m.get_aabb()
	var esc: Vector3 = Vector3(wx / maxf(a.size.x, 0.001), h / maxf(a.size.y, 0.001), wz / maxf(a.size.z, 0.001))
	var b: Basis = rot * Basis.from_scale(esc)
	return Transform3D(b, pos - b * Vector3(a.position.x + a.size.x * 0.5, 0.0, a.position.z + a.size.z * 0.5))


# ================================================================== PIEDRAS POR CPU ==================================================================
## Terrones, piedrecitas y fragmentos: un MultiMesh de piedra_est_1 (tierra_roca.gdshader) que caen con gravedad, giran, rebotan una vez y se quedan en el suelo hasta encogerse. `mundo` = top_level.
## `tam` = RADIO aparente (m), como antes con la icosfera: la malla se escala a 2·tam de lado.
class Piedras extends Node3D:
	var gravedad: float = 9.8
	var suelo_y: float = -1.0e9
	var _mi: MultiMeshInstance3D = null
	var _s: Array = []
	var _cursor: int = 0

	static func malla_piedra() -> Mesh:
		return TierraToy.malla_roca(TierraToy.MALLA_TERRON)

	func montar(n: int, mundo: bool) -> void:
		top_level = mundo
		if mundo:
			transform = Transform3D.IDENTITY
		_mi = TierraToy.crear_mm("Piedras", n, malla_piedra(), 0.3)
		add_child(_mi)
		_s.clear()
		for i in n:
			_s.append({"vivo": false})

	func capacidad() -> int:
		return _s.size()

	func vivas() -> int:
		var k: int = 0
		for d in _s:
			if bool(d["vivo"]):
				k += 1
		return k

	func emitir(pos: Vector3, vel: Vector3, vida: float, tam: float, giro: Vector3 = Vector3.ZERO, piso: float = NAN) -> int:
		if _s.is_empty():
			return -1
		var hueco: int = -1
		for k in _s.size():
			var j: int = (_cursor + k) % _s.size()
			if not bool((_s[j] as Dictionary)["vivo"]):
				hueco = j
				break
		if hueco < 0:
			return -1
		_cursor = (hueco + 1) % _s.size()
		var g: Vector3 = giro if giro.length() > 0.01 else Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		_s[hueco] = {"vivo": true, "pos": pos, "vel": vel, "edad": 0.0, "vida": maxf(vida, 0.05), "tam": tam, "giro": g, "tono": randf(),
			"rot": Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)), "rebotes": 0, "quieta": false, "piso": piso}
		return hueco

	func vaciar() -> void:
		for i in _s.size():
			_s[i] = {"vivo": false}
			if _mi != null:
				HieloMallas.ocultar(_mi.multimesh, i)

	func _process(delta: float) -> void:
		avanzar(delta)

	func avanzar(delta: float) -> void:
		if _mi == null:
			return
		var mm: MultiMesh = _mi.multimesh
		for i in _s.size():
			var d: Dictionary = _s[i]
			if not bool(d["vivo"]):
				continue
			d["edad"] = float(d["edad"]) + delta
			var u: float = float(d["edad"]) / float(d["vida"])
			if u >= 1.0:
				d["vivo"] = false
				HieloMallas.ocultar(mm, i)
				continue
			if not bool(d["quieta"]):
				var v: Vector3 = d["vel"]
				v.y -= gravedad * delta
				var p: Vector3 = (d["pos"] as Vector3) + v * delta
				var piso: float = float(d["piso"])
				if is_nan(piso):
					piso = suelo_y
				if p.y < piso:
					p.y = piso
					if int(d["rebotes"]) < 1 and v.y < -1.0:
						v.y = -v.y * 0.22
						v.x *= 0.45
						v.z *= 0.45
						d["rebotes"] = int(d["rebotes"]) + 1
						d["giro"] = (d["giro"] as Vector3) * 0.4
					else:
						v = Vector3.ZERO
						d["quieta"] = true
				d["vel"] = v
				d["pos"] = p
				var g: Vector3 = d["giro"]
				if g.length() > 0.001:
					d["rot"] = (Basis(g.normalized(), g.length() * delta) * (d["rot"] as Basis)).orthonormalized()
			var s: float = float(d["tam"]) * (1.0 - smoothstep(0.75, 1.0, u)) * 2.0 / TierraToy.lado_malla(mm.mesh)   # al final se hunde (encoge), no se desvanece
			mm.set_instance_transform(i, TierraToy.centrar(mm.mesh, (d["rot"] as Basis) * Basis.from_scale(Vector3.ONE * s), d["pos"]))
			mm.set_instance_custom_data(i, Color(float(d["tono"]), 1.0, 0.0, 0.0))

	func estados() -> Array:
		var r: Array = []
		for i in _s.size():
			var d: Dictionary = _s[i]
			if bool(d["vivo"]):
				r.append({"hueco": i, "pos": d["pos"], "vel": d["vel"], "u": float(d["edad"]) / float(d["vida"]), "edad": float(d["edad"]), "quieta": bool(d["quieta"]), "rebotes": int(d["rebotes"])})
		return r


## ShaderMaterial de la roca (opaco, con la luz de la escena, la textura gris de las rocas del mapa y el velo de piedra) con `p` encima.
static func material_roca(p: Dictionary = {}) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_ROCA)
	m.set_shader_parameter("albedo_tex", load(TEX_ALBEDO))
	m.set_shader_parameter("tinte", TINTE_PIEDRA)
	for k in p:
		m.set_shader_parameter(k, p[k])
	if TODO_COMO_LINEA and float(p.get("plano", 0.0)) < 0.5:
		m.set_shader_parameter("plano", 1.0)
		m.set_shader_parameter("color_plano", COLOR_PUA)
		m.set_shader_parameter("aclara_pua", ACLARA_PUA)
	return m


## MultiMesh de `n` rocas (`malla`) con el material de la roca para instancias. `base_tierra` = 1: la base manchada de tierra (bloques que salen del suelo).
## `plano`: color plano (púas y lajas) en vez de la textura; `color_plano` el pardo que toque.
static func crear_mm(nombre: String, n: int, malla: Mesh, oscurecer: float = 0.0, base_tierra: float = 0.0, plano: float = 0.0, color_plano: Color = COLOR_PUA) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = malla
	mm.instance_count = maxi(n, 1)
	for i in mm.instance_count:
		HieloMallas.ocultar(mm, i)
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = material_roca({"instancias": 1.0, "oscurecer": oscurecer, "base_tierra": base_tierra, "plano": plano, "color_plano": color_plano})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
	return mi


## 7/11/2026 (Pablo pasó la referencia de LeLu, CC0): DECAL DE SUELO. Una caja de `ancho` × `alto` × `largo` centrada en `centro` que pinta su máscara sobre lo que haya dentro, siga el
## relieve que siga. Es lo que un quad tumbado no sabe hacer: en una cuesta o un escalón el quad flota o se mete en la tierra, y el decal se pega. Mismos nombres de parámetro que los
## quads (`avance`, `vida`), así que lo anima el mismo código. El alto es lo que puede subir o bajar el suelo dentro de la marca: más alto, más cuesta aguanta, y más caja que descartar.
static func crear_decal_suelo(nombre: String, ancho: float, largo: float, alto: float, params: Dictionary, centro: Vector3, prioridad: int = -2) -> MeshInstance3D:
	# la caja es de 1×1×1 y el tamaño va en la ESCALA del nodo, no en `BoxMesh.size`: el shader prueba «¿está dentro?» contra ±`media_caja` en coordenadas LOCALES, y eso solo vale si
	# la malla mide 1 (7/11: con `size` el test recortaba la caja a un metro central y el suelo quedaba fuera; las rocas, que caían dentro, sí se pintaban). `INV_MODEL_MATRIX` ya lleva
	# la escala, también la que tenga el padre.
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3.ONE
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = bm
	mi.scale = Vector3(ancho, alto, largo)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_DECAL)
	m.render_priority = prioridad
	m.set_shader_parameter("media_caja", 0.5)
	for k in params:
		m.set_shader_parameter(k, params[k])
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = centro
	return mi


## Quad tumbado en el suelo (PlaneMesh `ancho` × `largo`, centrado en `centro`) con un shader sin luz (grietas, anillo). `prioridad` de dibujo (-2: bajo el polvo y las rocas).
static func crear_quad_suelo(nombre: String, ancho: float, largo: float, sh: String, params: Dictionary, centro: Vector3, prioridad: int = -2) -> MeshInstance3D:
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(ancho, largo)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = pm
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(sh)
	m.render_priority = prioridad
	for k in params:
		m.set_shader_parameter(k, params[k])
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = centro
	return mi


## Parámetros del polvo pardo (humo toon de dos tonos tierra).
static func polvo_params(tam_ini: float, tam_fin: float, vida: float, deriva: Vector3, mundo: bool) -> Dictionary:
	return {"claro": POLVO_CLARO, "sombra": POLVO_SOMBRA, "viejo": POLVO_VIEJO, "tam_ini": tam_ini, "tam_fin": tam_fin, "vida": vida, "deriva": deriva, "erosion": 0.9, "estirado": 1.0,
		"umbral": 0.42, "ruido_borde": 0.22, "mundo": mundo, "giro_vel": 0.4, "curva": 0.5, "friccion": 1.6}


## Los tres interruptores de 21/11 (con el forzado de las pruebas).
static func bola_nueva() -> bool:
	return BOLA_INICIO_FINAL and not prueba_apagar


static func barrera_nueva() -> bool:
	return BARRERA_INICIO_FINAL and not prueba_apagar


static func haz_nuevo_global() -> bool:
	return HAZ_INICIO_FINAL and not prueba_apagar


@export_group("Figura y ejes (m)")
@export var figura: Figura = Figura.BOLA: set = _set_figura
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_x: float = 0.4: set = _set_x
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_y: float = 0.4: set = _set_y
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_z: float = 0.4: set = _set_z
@export var viaja: bool = false: set = _set_viaja
## Los bloques SUBEN con `sube` (0 → 1: anticipación, subida con sobrepaso y asentamiento; lo anima «nacer») y se HUNDEN con `hunde` (0 → 1; lo anima «morir»).
@export_range(0.0, 1.0, 0.01) var sube: float = 1.0
@export_range(0.0, 1.0, 0.01) var hunde: float = 0.0
@export_group("Carga del hechizo")
@export_range(0.03, 0.6, 0.01) var carga_tam_inicial: float = 0.12
@export_range(0.3, 3.0, 0.05) var carga_curva: float = 0.8
@export_range(0, 36, 1) var carga_chispas: int = 28                                 ## piedrecitas que convergen (tasa)
@export_range(0.0, 3.0, 0.05) var carga_destello: float = 1.0                       ## sin uso
@export_range(0.0, 0.2, 0.005) var carga_respiro: float = 0.05
@export_range(0.0, 3.0, 0.05) var carga_brillo: float = 1.0                         ## sin uso
@export_range(0.5, 2.0, 0.05) var carga_radio: float = 1.0
@export var carga_bola_visible: bool = true: set = _set_carga_bola_visible
@export_group("Impacto")
@export var area_al_impactar: bool = false
@export_group("Mundo")
@export var pies: Vector3 = Vector3(0, -0.7, 0.5)
@export var altura_suelo: float = 0.7

var _construido: bool = false
var _pendiente: bool = false
var _figura_anim: int = -1
var _silencio: bool = false
var _est: int = EstadoCarga.NINGUNA
var _c_t: float = 0.0
var _c_dur: float = 1.0
var _c_r: float = 0.4
var _c_prog: float = 0.0
var _c_escala: float = 1.0
var _c_desde: float = 1.0
var _c_nodo: Node3D = null
var _c_piedras: Node3D = null
var _c_acc: float = 0.0
var _pop: bool = false
var _roca: MeshInstance3D = null        ## BOLA
var _inclinable: Node3D = null
var _bloques: Array = []                ## figuras de volumen: [{pos, rot, wx, h, wz, retraso, tono, malla (id), mm (índice en _bloques_mms), idx (instancia)}]
var _bloques_mms: Array = []            ## Array[MultiMeshInstance3D]: uno por tipo de roca que use la figura (el primero se llama «Bloques»)
var _polvo: Node3D = null               ## HumoToy pardo (mundo)
var _piedras: Node3D = null             ## Piedras (mundo)
var _asentado: bool = false             ## ¿ya soltó el polvo y los fragmentos del asentamiento?
var _hundiendo: bool = false
var _acc: float = 0.0
var _acc_p: float = 0.0
var _ult_pos: Vector3 = Vector3.ZERO
var _tiene_ult: bool = false
var _vel_mundo: Vector3 = Vector3.ZERO
var _giro_bola: float = 0.0
var _bola_rota: bool = false
var _haz_largo: float = 3.0
var _haz_alt: float = 0.5
var _haz_r: float = 0.36
var _haz_n: int = 0                     ## púas del haz (fija cuánto dura «nacer»: anticipación + n × PASO_PUA_S + SUBE_PUA_S)
var _t_nacer_act: float = -1.0          ## duración de «nacer» con la que se montó la animación (para rehacerla si cambia)
var _grietas: MeshInstance3D = null     ## HAZ: quad de grietas en el suelo
var linea_ignea: bool = false      ## Variante ígnea de MagmaToy.
var normal_arriba: float = 0.0: set = _set_normal_arriba     ## 12/11: `normal_arriba` del shader en púas y lajas (0 = lab, tal cual; VfxToyJuego pone NORMAL_ARRIBA_JUEGO)
var _brillo: MeshInstance3D = null      ## BARRERA: disco pardo-naranja tenue dentro de la cúpula que se apaga al cerrarse
var _t_cerrada: float = -1.0            ## BARRERA: instante (s de vida) en que se cerró la cúpula
var _c_aviso: MultiMeshInstance3D = null  ## CARGA: anillo de piedrecitas que gira a ras de suelo bajo los pies
var _aviso_ang: float = 0.0
var _grietas_muro: Array = []                ## MURO: las dos medias grietas del suelo (centro → extremos)
var _acc_g: float = 0.0
## HAZ (línea de púas), 19/11: algo la PARA antes de su largo. `haz_tope` = m del origen a la cara de lo que toca (≤ 0: nada). Como en HieloToy: ponerlo ANTES de construir.
var haz_tope: float = -1.0
var _marca_pilar: MeshInstance3D = null    ## PILAR: decal de tierra partida bajo la columna
var _ini_t: float = -1.0                ## BOLA sin carga: s desde que empezó a compactarse (-1: no)
var _ini_piedras: Node3D = null         ## BOLA: terrones que acuden a la roca (sin gravedad, locales)
var _ini_n: int = 0                     ## (pruebas) terrones emitidos en el inicio
var _ini_acc: float = 0.0
var _n_cascotes_final: int = 0          ## (pruebas) cascotes grandes de la última rotura de la bola
var _grietas_barrera: Array = []        ## BARRERA: tramos de la grieta en anillo
var _barrera_dir: Array = []            ## BARRERA: [centro, dirección] de cada tramo (en local)
var _acc_gb: float = 0.0
var _y_act: Array = []                  ## (pruebas) desplazamiento vertical actual de cada bloque (m; < 0 = aún bajo tierra)


func _ready() -> void:
	_construir()
	super._ready()
	_construido = true
	_set_proyectil(viaja)
	_montar_reservas()
	_avanzar_bloques(0.0)


# ------------------------------------------------------------------ interfaz ------------------------------------------------------------------

func _set_figura(v: Figura) -> void:
	figura = v
	_pedir()


func _set_x(v: float) -> void:
	semieje_x = maxf(v, 0.05)
	_pedir()


func _set_y(v: float) -> void:
	semieje_y = maxf(v, 0.05)
	_pedir()


func _set_z(v: float) -> void:
	semieje_z = maxf(v, 0.05)
	_pedir()


func _set_viaja(v: bool) -> void:
	viaja = v
	_pedir()


func _set_normal_arriba(v: float) -> void:
	normal_arriba = clampf(v, 0.0, 1.0)
	for mi in _bloques_mms:                                                  # ya montadas: solo las de color plano (púas y lajas) con el material de roca de tierra
		var m: ShaderMaterial = (mi as MultiMeshInstance3D).material_override as ShaderMaterial
		if m != null and float(m.get_shader_parameter("plano")) > 0.5 and m.shader != null and m.shader.resource_path.ends_with("tierra_roca.gdshader"):
			m.set_shader_parameter("normal_arriba", normal_arriba)


func definir(fig: int, x: float, y: float, z: float, vuela: bool = false) -> void:
	_silencio = true
	figura = fig as Figura
	semieje_x = maxf(x, 0.05)
	semieje_y = maxf(y, 0.05)
	semieje_z = maxf(z, 0.05)
	viaja = vuela
	_silencio = false
	if _construido:
		reconstruir()


func _pedir() -> void:
	if _silencio:
		return
	if _construido and is_inside_tree() and not _pendiente:
		_pendiente = true
		call_deferred("reconstruir")


func reconstruir() -> void:
	_pendiente = false
	if not is_inside_tree() or not _construido:
		return
	_listo = false
	_construir()
	proyectil = viaja
	_recoger()
	_set_proyectil(viaja)
	_montar_reservas()
	_avanzar_bloques(0.0)


func semiejes() -> Vector3:
	return Vector3(semieje_x, semieje_y, semieje_z)


func esta_cargando() -> bool:
	return _est == EstadoCarga.CARGANDO


func progreso_carga() -> float:
	return _c_prog


func escala_carga() -> float:
	return _c_escala


# ------------------------------------------------------------------ carga, suelta e impacto ------------------------------------------------------------------

func empezar_carga(duracion: float, tam_final: Variant = null) -> void:
	var r: float = maxf(semieje_x, semieje_z)
	if tam_final is Vector3:
		r = maxf((tam_final as Vector3).x, (tam_final as Vector3).z)
	elif tam_final is float or tam_final is int:
		r = float(tam_final)
	r = maxf(r, 0.05)
	_c_r = r
	definir(Figura.BOLA, r, r, r, false)
	proyectil = false
	aparicion = 1.0
	if _ap != null:
		_ap.stop()
	_c_dur = maxf(duracion, 0.05)
	_c_t = 0.0
	_c_prog = 0.0
	_c_escala = carga_tam_inicial
	_est = EstadoCarga.CARGANDO
	_pop = false
	_bola_rota = false
	if _cuerpo != null:
		_cuerpo.visible = carga_bola_visible
	_montar_carga()
	_aplicar_escala_carga()


func soltar(dir: Vector3 = Vector3.ZERO) -> void:
	if dir.length() > 0.001 and is_inside_tree():
		var d: Vector3 = dir.normalized()
		look_at(global_position + d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
	_silencio = true
	viaja = true
	_silencio = false
	proyectil = true
	if _cuerpo != null and not _cuerpo.visible:
		_cuerpo.visible = true
		_pop = true
		_c_desde = 0.5
		_c_escala = 0.5
		_aplicar_escala_carga()
	else:
		_pop = false
		_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.SOLTANDO
	_quitar_visual_carga()


func cancelar_carga() -> void:
	if _est == EstadoCarga.CANCELANDO:
		return
	_quitar_visual_carga()
	_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.CANCELANDO


func _set_carga_bola_visible(v: bool) -> void:
	carga_bola_visible = v
	if _est == EstadoCarga.CARGANDO and _cuerpo != null:
		_cuerpo.visible = v


func _quitar_visual_carga() -> void:
	if _c_nodo != null and is_instance_valid(_c_nodo):
		var n: Node3D = _c_nodo
		_c_nodo = null
		_c_piedras = null
		if _c_aviso != null and is_instance_valid(_c_aviso):
			_c_aviso.visible = false           # el aviso se va con la suelta; las piedrecitas que convergen apuran su vida
		_c_aviso = null
		if is_inside_tree():
			get_tree().create_timer(0.6).timeout.connect(n.queue_free)
		else:
			n.queue_free()


func _escala_de_carga(p: float) -> float:
	var g: float = smoothstep(0.0, 1.0, pow(clampf(p, 0.0, 1.0), carga_curva))
	return lerpf(carga_tam_inicial, 1.0, g)


func _aplicar_escala_carga() -> void:
	if _cuerpo != null:
		var v: float = aparicion
		_cuerpo.scale = Vector3(lerpf(0.65, 1.0, v), lerpf(0.15, 1.0, v), lerpf(0.65, 1.0, v)) * _c_escala


func _avanzar_carga(delta: float) -> void:
	match _est:
		EstadoCarga.CARGANDO:
			_c_t += delta
			var p: float = clampf(_c_t / _c_dur, 0.0, 1.0)
			_c_prog = p
			var g: float = _escala_de_carga(p)
			var env: float = smoothstep(0.55, 1.0, p)
			var resp: float = sin(_c_t * TAU * RESPIRO_HZ)
			_c_escala = g * (1.0 + carga_respiro * env * resp)
			_aplicar_escala_carga()
			_emitir_carga(delta, p)
			_avanzar_aviso(delta)
		EstadoCarga.SOLTANDO:
			_c_t += delta
			var u: float = clampf(_c_t / T_SOLTAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 1.0, smoothstep(0.0, 1.0, u)) + (0.07 * sin(u * PI) if _pop else 0.0)
			_aplicar_escala_carga()
			if u >= 1.0:
				_est = EstadoCarga.NINGUNA
				_c_escala = 1.0
				_aplicar_escala_carga()
		EstadoCarga.CANCELANDO:
			_c_t += delta
			var u2: float = clampf(_c_t / T_CANCELAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 0.0, u2 * u2)
			_aplicar_escala_carga()
			if u2 >= 1.0:
				_est = EstadoCarga.NINGUNA
				queue_free()
		EstadoCarga.APAGANDO:
			_c_t += delta
			var u3: float = clampf(_c_t / T_APAGAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 0.0, u3 * u3)
			_aplicar_escala_carga()
			if u3 >= 1.0:
				_est = EstadoCarga.NINGUNA
				_c_escala = 0.001
				_aplicar_escala_carga()
				get_tree().create_timer(0.85).timeout.connect(queue_free)


## Piedrecitas que convergen en la mano (nodo «Carga», que no escala con la roca).
func _montar_carga() -> void:
	var viejo: Node = get_node_or_null("Carga")
	if viejo != null:
		remove_child(viejo)
		viejo.free()
	_c_nodo = Node3D.new()
	_c_nodo.name = "Carga"
	add_child(_c_nodo)
	_c_piedras = Piedras.new()
	_c_piedras.name = "Convergencia"
	_c_piedras.gravedad = 0.0
	_c_nodo.add_child(_c_piedras)
	_c_piedras.call("montar", 24, false)
	_c_acc = 0.0
	# anillo de AVISO: N_AVISO piedrecitas a ras de suelo bajo los pies, girando (la tierra se prepara)
	_c_aviso = crear_mm("Aviso", N_AVISO, malla_roca("piedra_est_3"), 0.25)
	_c_nodo.add_child(_c_aviso)
	_aviso_ang = 0.0
	_avanzar_aviso(0.0)


## Gira el anillo de aviso: cada piedrecita en la elipse de radio `carga_radio × _c_r × 2` bajo los pies, tumbada, creciendo con el progreso de la carga.
func _avanzar_aviso(delta: float) -> void:
	if _c_aviso == null or not is_instance_valid(_c_aviso):
		return
	_aviso_ang += GIRO_AVISO * delta
	var mm: MultiMesh = _c_aviso.multimesh
	var r: float = maxf(_c_r, 0.1) * 2.2 * carga_radio
	var crece: float = smoothstep(0.0, 0.25, _c_prog) if _est == EstadoCarga.CARGANDO else 0.0
	var tam: float = maxf(_c_r, 0.1) * 0.22 * crece
	for i in N_AVISO:
		if tam < 0.001:
			HieloMallas.ocultar(mm, i)
			continue
		var a: float = _aviso_ang + TAU * float(i) / float(N_AVISO)
		var p: Vector3 = pies + Vector3(cos(a) * r, 0.02, sin(a) * r)
		mm.set_instance_transform(i, asentar(mm.mesh, Basis(Vector3.UP, -a + float(i)), tam * 2.0, tam * 1.1, tam * 2.0, p))
		mm.set_instance_custom_data(i, Color(float(i) / float(N_AVISO), 1.0, 0.0, 0.0))


## (pruebas) ángulo acumulado del anillo de aviso y su radio.
func estado_aviso() -> Dictionary:
	return {"ang": _aviso_ang, "radio": maxf(_c_r, 0.1) * 2.2 * carga_radio, "vivo": _c_aviso != null and is_instance_valid(_c_aviso), "n": N_AVISO}


## Estado de la convergencia para las pruebas: piedrecitas vivas (local a la mano).
func estado_carga() -> Array:
	if _c_piedras == null or not is_instance_valid(_c_piedras):
		return []
	return _c_piedras.call("estados")


func _emitir_carga(delta: float, p: float) -> void:
	if _c_piedras == null or not is_instance_valid(_c_piedras):
		return
	var r0: float = _c_r * lerpf(3.0, 2.0, p) * carga_radio
	_c_acc += float(carga_chispas) * lerpf(0.4, 1.2, p) * delta
	var r_bola: float = _c_r * clampf(_c_escala, 0.05, 1.3) * 0.8
	while _c_acc >= 1.0:
		_c_acc -= 1.0
		if CARGA_DESDE_ANILLO and _c_aviso != null and is_instance_valid(_c_aviso) and _c_prog > 0.08:
			# desde una de las piedras del anillo (en su sitio de ahora, que gira) en línea recta hasta la superficie de la roca
			var a: float = _aviso_ang + TAU * float(randi() % N_AVISO) / float(N_AVISO)
			var ra: float = maxf(_c_r, 0.1) * 2.2 * carga_radio
			var ini: Vector3 = pies + Vector3(cos(a) * ra, 0.06, sin(a) * ra)
			var largo: float = ini.length()
			if largo > r_bola + 0.01:
				_c_piedras.call("emitir", ini, -ini / largo * (largo - r_bola) / CARGA_SUBIDA_S, CARGA_SUBIDA_S, _c_r * randf_range(0.12, 0.2), Vector3.ZERO)
			continue
		var d: Vector3 = Vector3(randf_range(-1, 1), randf_range(-0.8, 0.6), randf_range(-1, 1)).normalized()
		var rr: float = r0 * randf_range(0.8, 1.2)
		_c_piedras.call("emitir", d * rr, -d * (rr - r_bola) / 0.4, 0.4, _c_r * randf_range(0.12, 0.2), Vector3.ZERO)


func _radio_impacto(escala: float) -> float:
	return escala if escala > 0.0 else maxf(semieje_x, semieje_z)


func _crear_impacto(variante: ImpactoTierraToy.Variante, normal: Vector3, escala: float, pos: Vector3) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var imp: ImpactoTierraToy = ImpactoTierraToy.crear(variante, normal, _radio_impacto(escala))
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


## Los terrones y el polvo sueltos siguen cayendo aunque la roca desaparezca: pasan al padre y se liberan solos.
func _soltar_reservas() -> void:
	if get_parent() == null or not is_inside_tree():
		return
	var padre: Node = get_parent()
	for n in [_piedras, _polvo]:
		if n != null and is_instance_valid(n):
			n.get_parent().remove_child(n)
			padre.add_child(n)
			n.top_level = true
			n.transform = Transform3D.IDENTITY
			get_tree().create_timer(2.0).timeout.connect(n.queue_free)
	_piedras = null
	_polvo = null


func explotar_area(pos: Vector3, radio: float = -1.0) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var r: float = radio if radio > 0.0 else maxf(maxf(semieje_x, semieje_z), 0.3)
	var imp: ImpactoTierraToy = ImpactoTierraToy.crear(ImpactoTierraToy.Variante.AREA, Vector3.UP, r)
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


func impactar_en(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Node3D:
	var imp: Node3D
	if area_al_impactar:
		imp = explotar_area(pos, escala)
	else:
		imp = _crear_impacto(ImpactoTierraToy.Variante.GOLPE, normal, escala, pos)
	_est = EstadoCarga.NINGUNA
	_bola_rota = true
	_quitar_visual_carga()
	if bola_nueva() and figura == Figura.BOLA:
		_cascotes_bola_final(normal)                                                # 21/11: la roca se parte en cascotes grandes además del impacto
	_soltar_reservas()
	if _ap != null and _ap.has_animation("morir"):
		_ap.speed_scale = 4.0
	morir()
	return imp


func rebotar(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Vector3:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var d: Vector3 = -global_transform.basis.z if is_inside_tree() else Vector3.FORWARD
	var nd: Vector3 = (d - 2.0 * d.dot(n) * n).normalized()
	_crear_impacto(ImpactoTierraToy.Variante.REBOTE, n, escala, pos)
	if is_inside_tree():
		global_position = pos
		look_at(pos + nd, Vector3.UP if absf(nd.y) < 0.99 else Vector3.FORWARD)
		_ult_pos = pos
	return nd


func terminar_sin_choque() -> void:
	if _est == EstadoCarga.APAGANDO or _est == EstadoCarga.CANCELANDO:
		return
	_crear_impacto(ImpactoTierraToy.Variante.FIN, Vector3.UP, -1.0, global_position)
	_bola_rota = true
	_quitar_visual_carga()
	_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.APAGANDO


func finalizar(motivo: String, pos: Vector3 = Vector3.INF, normal: Vector3 = Vector3.UP) -> void:
	var p: Vector3 = global_position if pos == Vector3.INF else pos
	match motivo:
		"golpe", "muro", "suelo":
			impactar_en(p, normal)
		"retorno":
			cancelar_carga()
		_:
			terminar_sin_choque()


func impactar() -> void:
	var n: Vector3 = global_transform.basis.z.normalized() if proyectil else Vector3.UP
	if global_position.y < 0.3:
		n = Vector3.UP
	impactar_en(global_position, n)


## Las figuras de volumen nacen BAJO TIERRA: `sube` empieza en 0 (si no, el primer fotograma las vería ya asentadas y soltaría el polvo antes de tiempo).
func lanzar(v: float = -1.0) -> void:
	if figura != Figura.BOLA:
		sube = 0.0
		hunde = 0.0
		_asentado = false
		_t_cerrada = -1.0
		for b in _bloques:
			(b as Dictionary)["soltado"] = false
			(b as Dictionary)["polvo_ya"] = false
			(b as Dictionary)["estallado"] = false
			(b as Dictionary)["hundido_ya"] = false
		_avanzar_bloques(0.0)
		if not _barrera_ok() and not _haz_nuevo():                                  # la barrera y la línea nuevas empiezan por la grieta, no por un brote de polvo en cada roca
			_brote_anticipo()
	elif bola_nueva() and _est == EstadoCarga.NINGUNA:
		_empezar_inicio_bola()
	super.lanzar(v)


## Brote inicial de polvo de la base de cada bloque al ordenar la subida (la anticipación se ve aunque el fotograma sea largo).
func _brote_anticipo() -> void:
	if _polvo == null or not is_instance_valid(_polvo) or _bloques.is_empty() or not is_inside_tree():
		return
	var tr: Transform3D = global_transform
	var n: int = mini(_bloques.size() * 2, 12)
	for i in n:
		var b: Dictionary = _bloques[i % _bloques.size()]
		var loc: Vector3 = (b["pos"] as Vector3) + Vector3(randf_range(-0.5, 0.5) * float(b["wx"]) * ancho, 0.04, randf_range(-0.5, 0.5) * float(b["wz"]) * ancho)
		_polvo.call("emitir", tr * loc, tr.basis * Vector3(randf_range(-0.5, 0.5), 0.6, randf_range(-0.5, 0.5)), 0.8, 0.7)


## Una bola que muere sin impacto se deshace en terrones. Las demás figuras se hunden con `hunde`.
func morir() -> void:
	if figura == Figura.BOLA and not _bola_rota and _piedras != null and is_instance_valid(_piedras) and is_inside_tree():
		_bola_rota = true
		_romper_bola()
		if bola_nueva() and _ap != null:
			_ap.speed_scale = 3.5                                                   # la roca se parte: desaparece enseguida, no se encoge despacio
	super.morir()


func preparar(volumen: Dictionary, dir: Vector3, _elemento: String = "tierra") -> void:
	semieje_x = maxf(float(volumen.get("x", 0.5)) * casilla, 0.05)
	semieje_y = maxf(float(volumen.get("y", 0.5)) * casilla, 0.05)
	semieje_z = maxf(float(volumen.get("z", 0.5)) * casilla, 0.05)
	var plano: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if plano.length() > 0.01 and is_inside_tree():
		look_at(global_position + plano, Vector3.UP)
	if _construido:
		reconstruir()


func desde_hechizo(h: Hechizo) -> void:
	var d: Dictionary = describir(h, casilla)
	definir(int(d["figura"]), d["x"], d["y"], d["z"], d["viaja"])
	rotation.y = float(d["giro_y"])
	area_al_impactar = int(d["figura"]) == Figura.BOLA and not bool(d["viaja"])


static func describir(h: Hechizo, casilla_m: float = 2.3) -> Dictionary:
	return FuegoToy.describir(h, casilla_m)


func extension() -> float:
	return FuegoToy._extension(int(figura) as FuegoToy.Figura, semieje_x, semieje_y, semieje_z)


static func _extension_ref(fig: int) -> float:
	return FuegoToy._extension_ref(fig as FuegoToy.Figura)


# ------------------------------------------------------------------ construcción ------------------------------------------------------------------

func _construir() -> void:
	var cuerpo: Node3D = get_node_or_null("Cuerpo") as Node3D
	if cuerpo == null:
		cuerpo = Node3D.new()
		cuerpo.name = "Cuerpo"
		add_child(cuerpo)
	for h in cuerpo.get_children():
		cuerpo.remove_child(h)
		h.free()
	_roca = null
	_inclinable = null
	_bloques = []
	_bloques_mms = []
	_grietas = null
	_brillo = null
	_marca_pilar = null
	_grietas_muro = []
	_grietas_barrera = []
	_barrera_dir = []
	_acc_gb = 0.0
	_acc_g = 0.0
	_t_cerrada = -1.0
	_asentado = false
	_hundiendo = false
	_acc = 0.0
	_acc_p = 0.0
	tam_referencia = Vector3(semieje_x, semieje_y, semieje_z) * 2.0
	_avance_cabeza = 0.0
	match figura:
		Figura.BOLA:
			_bola(cuerpo)
		Figura.HAZ:
			_haz(cuerpo)
		Figura.PILAR:
			_pilar(cuerpo)
		Figura.MURO:
			_muro(cuerpo)
		_:
			_barrera(cuerpo)
	_anim_si_hace_falta()


## ¿La línea de tierra (no la ígnea, que ya tiene su grieta) lleva el inicio y el final nuevos?
func _haz_nuevo() -> bool:
	return figura == Figura.HAZ and haz_nuevo_global() and not linea_ignea


## ¿La barrera lleva el inicio y el final nuevos?
func _barrera_ok() -> bool:
	return figura == Figura.BARRERA and barrera_nueva()


## Un bloque de la figura: roca `malla` (id) con la base en `pos`, giro `rot`, que ocupa `wx` × `h` × `wz` m, sale tras `retraso` (0..0,6 de la subida) y con su tono.
## Claves opcionales: `dur` (fracción de `sube` que tarda en salir desde su retraso; -1 = lo que quede, como las rocas), `ret_hunde` (fracción de `hunde` a la que empieza a hundirse;
## -1 = todas a la vez), `soltado` (ya soltó su polvo y su cascote al asentarse: púas), `techo` (BARRERA: losa de la cúpula, con pos.y > 0).
static func _b(malla: String, pos: Vector3, rot: Basis, wx: float, h: float, wz: float, retraso: float, rng: RandomNumberGenerator) -> Dictionary:
	return {"malla": malla, "pos": pos, "rot": rot, "wx": wx, "h": h, "wz": wz, "retraso": retraso, "tono": rng.randf(), "mm": 0, "idx": 0, "dur": -1.0, "ret_hunde": -1.0, "soltado": false, "techo": false}


## Giro de una roca de la figura: media vuelta o no (la cara de atrás es otra roca) más un desvío `desvio` rad, y una pizca de inclinación `inclina` hacia un lado al azar.
static func _giro_roca(rng: RandomNumberGenerator, desvio: float, inclina: float = 0.0) -> Basis:
	var b: Basis = Basis(Vector3.UP, (PI if rng.randf() < 0.5 else 0.0) + rng.randf_range(-desvio, desvio))
	if inclina > 0.0001:
		var a: float = rng.randf() * TAU
		b = Basis(Vector3(cos(a), 0.0, sin(a)), rng.randf_range(-inclina, inclina)) * b
	return b


## Monta las rocas de `capa` (≤ MAX_BLOQUES): un MultiMesh por tipo de roca (el primero, «Bloques»; los demás, «Bloques_<id>»), todas bajo tierra hasta `_avanzar_bloques`.
func _montar_bloques(c: Node3D, capa: Array) -> void:
	if capa.size() > MAX_BLOQUES:
		capa = capa.slice(0, MAX_BLOQUES)
	_bloques = capa
	_bloques_mms = []
	var grupos: Dictionary = {}
	for b in _bloques:
		var id: String = b["malla"]
		if not grupos.has(id):
			if grupos.size() >= MAX_TIPOS:                                                  # más tipos de los que caben: esta roca se hace con uno de los que ya hay
				id = grupos.keys()[grupos.size() - 1]
				b["malla"] = id
			else:
				grupos[id] = []
		(grupos[id] as Array).append(b)
	for id in grupos:
		var lista: Array = grupos[id]
		var k: int = _bloques_mms.size()
		var plano: bool = es_plana(String(id))
		var mi: MultiMeshInstance3D = crear_mm("Bloques" if k == 0 else "Bloques_" + String(id), lista.size(), malla_roca(id), 0.0, 0.0 if plano else 1.0, 1.0 if plano else 0.0,
			COLOR_LAJA if String(id).begins_with("laja_") else COLOR_PUA)
		if plano:
			# 7/11 (vídeo de tierra): la púa ya no corta a ras de suelo —su base tira al color de la tierra, como el resto de bloques— y lleva suelo de luz para no irse a negro en el Bosque
			(mi.material_override as ShaderMaterial).set_shader_parameter("base_tierra", 1.0)
			(mi.material_override as ShaderMaterial).set_shader_parameter("aclara_pua", ACLARA_PUA)
			(mi.material_override as ShaderMaterial).set_shader_parameter("normal_arriba", normal_arriba)
		c.add_child(mi)
		_bloques_mms.append(mi)
		for j in lista.size():
			(lista[j] as Dictionary)["mm"] = k
			(lista[j] as Dictionary)["idx"] = j


## Piedras pequeñas al pie de una figura (rellenan hasta `tope` huecos): tumbadas junto a `pos`, mirando hacia fuera `d`, de 0,25-0,45 del alto `h` y con más retraso (salen con el asentamiento).
static func _pie(capa: Array, pos: Vector3, d: Vector3, w: float, h: float, retraso: float, rng: RandomNumberGenerator, tope: int) -> void:
	if capa.size() >= tope:
		return
	var id: String = MALLAS_PIE[rng.randi() % MALLAS_PIE.size()]
	var t: float = w * rng.randf_range(0.32, 0.5)
	var ht: float = minf(h * rng.randf_range(0.25, 0.42), t * 0.9)
	var p: Vector3 = pos + d * (w * 0.5 + t * 0.35)
	capa.append(_b(id, p, Basis(Vector3.UP, rng.randf() * TAU), t, ht, t * rng.randf_range(0.8, 1.1), retraso, rng))


## BOLA: una piedra_est_0 (la más redonda del mapa) ajustada a los semiejes, que gira (quieta despacio, en vuelo deprisa sobre el eje del vuelo).
func _bola(c: Node3D) -> void:
	var r: float = maxf(semieje_x, semieje_z)
	_inclinable = Node3D.new()
	_inclinable.name = "Inclinable"
	c.add_child(_inclinable)
	_roca = MeshInstance3D.new()
	_roca.name = "Roca"
	var m: Mesh = malla_roca(MALLA_BOLA)
	_roca.mesh = m
	_roca.material_override = material_roca()
	_roca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var a: AABB = m.get_aabb()
	var esc: Vector3 = Vector3(2.0 * r / maxf(a.size.x, 0.001), 2.0 * semieje_y / maxf(a.size.y, 0.001), 2.0 * r / maxf(a.size.z, 0.001))
	_roca.transform = centrar(m, Basis.from_scale(esc), Vector3.ZERO)
	_inclinable.add_child(_roca)


## MURO: hilera de rocas grandes a lo largo de x (más altas hacia el centro, de anchos desiguales y solapadas para que no se vea el fondo entre ellas, cada una con su retraso al subir)
## y piedras pequeñas al pie, a un lado y a otro.
func _muro(c: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 23 + int(semieje_x * 100.0)
	var n: int = clampi(int(round(2.0 * semieje_x / 0.62)), 3, MAX_BLOQUES)
	var w: float = 2.0 * semieje_x / float(n)
	var fondo: float = maxf(2.0 * semieje_z, 0.3)
	var capa: Array = []
	var pies: Array = []
	for i in n:
		var x: float = -semieje_x + w * (float(i) + 0.5)
		var env: float = 1.0 - 0.28 * pow(absf(x) / maxf(semieje_x, 0.01), 2.5)
		var hh: float = semieje_y * rng.randf_range(0.8, 1.0) * env
		var id: String = MALLAS_MURO[(i * 5 + int(rng.randi() % 3)) % MALLAS_MURO.size()]
		var pos: Vector3 = Vector3(x, 0.0, rng.randf_range(-0.12, 0.12) * fondo)
		capa.append(_b(id, pos, _giro_roca(rng, 0.14, 0.04), w * rng.randf_range(1.12, 1.3), hh, fondo * rng.randf_range(0.9, 1.15), absf(x) / maxf(semieje_x, 0.01) * 0.25, rng))
		if i % 2 == 0:
			pies.append([pos, Vector3(0.0, 0.0, 1.0 if (i / 2) % 2 == 0 else -1.0), fondo, hh, 0.3 + absf(x) / maxf(semieje_x, 0.01) * 0.25])
	for p in pies:
		_pie(capa, p[0], p[1], p[2], p[3], p[4], rng, MAX_BLOQUES)
	if MURO_INICIO_FINAL:
		for bq in capa:
			var lejos: float = clampf(absf((bq["pos"] as Vector3).x) / maxf(semieje_x, 0.01), 0.0, 1.0)
			var es_pie: bool = String(bq["malla"]).begins_with("piedra_est_")
			bq["retraso"] = MURO_GRIETA_FRAC + MURO_ESCALON_FRAC * lejos + (0.05 if es_pie else 0.0)
			bq["dur"] = MURO_SALE_FRAC
			bq["t_estalla"] = MURO_ESTALLA_DESDE + MURO_ESTALLA_TRAMO * lejos + rng.randf_range(0.0, 0.06)
	_montar_bloques(c, capa)
	_grietas_muro = []
	if MURO_INICIO_FINAL:
		for lado in [-1.0, 1.0]:                                                       # dos medias grietas: cada una avanza del centro a su extremo
			var largo_g: float = semieje_x * 1.12
			var g: MeshInstance3D = crear_quad_suelo("Grieta" + ("A" if lado < 0.0 else "B"), maxf(fondo * 3.2, 0.9), largo_g, SH_GRIETAS,
				{"avance": 0.0, "vida": 0.0, "semilla": 0.37 + 0.2 * lado, "grosor": 0.03}, Vector3.ZERO)
			var giro: float = -PI * 0.5 * lado                                             # lleva el −Z del quad (por donde avanza la grieta del haz) al ±X del muro
			g.rotation.y = PI + giro
			g.position = Basis(Vector3.UP, giro) * Vector3(0, 0.02, -largo_g * 0.5)
			c.add_child(g)
			_grietas_muro.append(g)


## PILAR: una roca alta (roca_est_4) en el centro y cuatro más bajas pegadas, ligeramente inclinadas hacia fuera, con piedras al pie.
func _pilar(c: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 37
	var capa: Array = []
	if PILAR_COLUMNA:
		var col: Dictionary = _b(MALLA_COLUMNA, Vector3.ZERO, Basis(Vector3.UP, rng.randf() * TAU), semieje_x * 2.0, semieje_y, semieje_z * 2.0, 0.0, rng)
		col["sobre"] = COLUMNA_SOBREPASO
		capa.append(col)
		for k in 4:                                                                    # esquirlas de la misma piedra, inclinadas hacia fuera, que saltan cuando la columna ya asoma
			var ae: float = TAU * float(k) / 4.0 + rng.randf_range(-0.35, 0.35)
			var de: Vector3 = Vector3(cos(ae), 0.0, sin(ae))
			var pe: Vector3 = Vector3(de.x * semieje_x * 1.05, 0.0, de.z * semieje_z * 1.05)
			capa.append(_b(MALLA_COLUMNA, pe, HieloMallas._inclinar(de, rng.randf_range(0.28, 0.46), ae + rng.randf_range(-0.4, 0.4)), semieje_x * 0.8, semieje_y * rng.randf_range(0.18, 0.34),
				semieje_z * 0.8, 0.3 + 0.06 * float(k), rng))
			_pie(capa, pe, de, semieje_x * 1.1, semieje_y * 0.4, 0.45 + 0.05 * float(k), rng, MAX_BLOQUES)
		_montar_bloques(c, capa)
		var dm: float = PILAR_MARCA_TAM * maxf(semieje_x, semieje_z)
		_marca_pilar = crear_decal_suelo("Marca", dm, dm, PILAR_MARCA_ALTO, {"mascara": load(TEX_MARCA_SUELO), "vida": 0.0, "fuerza": 1.0}, Vector3.ZERO, -3)
		_marca_pilar.rotation.y = rng.randf() * TAU
		_marca_pilar.set_meta("lado", dm)
		c.add_child(_marca_pilar)
		return
	capa.append(_b("roca_est_4", Vector3.ZERO, Basis(Vector3.UP, rng.randf() * TAU), semieje_x * 1.5, semieje_y, semieje_z * 1.5, 0.0, rng))
	for k in 4:
		var a: float = TAU * float(k) / 4.0 + rng.randf_range(-0.3, 0.3)
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var id: String = "roca_est_1" if k % 2 == 0 else "roca_est_0"
		var pos: Vector3 = Vector3(d.x * semieje_x * 1.15, 0.0, d.z * semieje_z * 1.15)
		capa.append(_b(id, pos, HieloMallas._inclinar(d, rng.randf_range(0.08, 0.18), a + rng.randf_range(-0.4, 0.4)), semieje_x * 1.1, semieje_y * rng.randf_range(0.28, 0.5), semieje_z * 1.1, 0.12 + 0.05 * float(k), rng))
		_pie(capa, pos, d, semieje_x * 1.1, semieje_y * 0.4, 0.35 + 0.05 * float(k), rng, MAX_BLOQUES)
	_montar_bloques(c, capa)


## BARRERA: corona de rocas grandes (bloques, losas y alguna redonda) inclinadas hacia dentro sobre la elipse del suelo, CERRADA ARRIBA con tres losas (`techo`) que suben las últimas y
## se encuentran sobre el centro: una CÚPULA. Dentro, un disco pardo-naranja muy tenue (`Brillo`) que se apaga en 0,4 s al cerrarse (sin luz).
func _barrera(c: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41
	var perim: float = FuegoToyMallas.perimetro_elipse(semieje_x, semieje_z)
	var n: int = clampi(int(round(perim / 0.7)), 6, MAX_BLOQUES - 3)
	var capa: Array = []
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var w: float = perim / float(n) * rng.randf_range(1.0, 1.15)
		var id: String = MALLAS_MURO[(i * 3 + int(rng.randi() % 2)) % 5]                   # sin la alta (roca_est_4): la corona es baja y ancha
		capa.append(_b(id, Vector3(d.x * semieje_x * 0.92, 0.0, d.z * semieje_z * 0.92), HieloMallas._inclinar(-d, rng.randf_range(0.25, 0.42), atan2(-d.x, -d.z) + (PI if rng.randf() < 0.5 else 0.0)), w, semieje_y * rng.randf_range(0.75, 1.0), w * 0.6, rng.randf_range(0.0, 0.2), rng))
	# el techo: tres losas (roca_est_2) sobre la corona, cada una sobre un tercio, inclinadas hacia el centro, solapadas: cierran la cúpula
	var r_t: float = maxf(semieje_x, semieje_z)
	for k in 3:
		var a2: float = TAU * float(k) / 3.0 + 0.4
		var d2: Vector3 = Vector3(cos(a2), 0.0, sin(a2))
		var w2: float = r_t * rng.randf_range(0.85, 1.0)
		var b: Dictionary = _b("roca_est_2", Vector3(d2.x * semieje_x * 0.3, semieje_y * 0.8, d2.z * semieje_z * 0.3), HieloMallas._inclinar(-d2, rng.randf_range(0.65, 0.85), atan2(-d2.x, -d2.z)), w2, semieje_y * 0.28, w2 * 0.75, 0.3 + 0.06 * float(k), rng)
		b["techo"] = true
		capa.append(b)
	var nueva: bool = barrera_nueva()
	if nueva:
		# 21/11: las rocas brotan EN OLA alrededor (por ángulo) sobre la grieta en anillo; el techo después; al morir, el techo primero y las rocas por tramos en la misma ola
		for i in n:
			var bq: Dictionary = capa[i]
			var fr: float = float(i) / float(n)
			bq["retraso"] = BARRERA_OLA_DESDE + BARRERA_OLA_TRAMO * fr
			bq["dur"] = BARRERA_SALE_FRAC
			bq["ret_hunde"] = BARRERA_HUNDE_DESDE + BARRERA_HUNDE_TRAMO * fr
		for k in 3:
			var bt: Dictionary = capa[n + k]
			bt["retraso"] = BARRERA_TECHO_DESDE + BARRERA_TECHO_PASO * float(k)
			bt["dur"] = BARRERA_SALE_FRAC + 0.02
			bt["ret_hunde"] = 0.0
	_montar_bloques(c, capa)
	if nueva:
		var perim_g: float = perim / float(BARRERA_GRIETAS)
		for k in BARRERA_GRIETAS:
			var ag: float = TAU * (float(k) + 0.5) / float(BARRERA_GRIETAS)
			var pg: Vector3 = Vector3(cos(ag) * semieje_x * 0.92, 0.02, sin(ag) * semieje_z * 0.92)
			var tg: Vector3 = Vector3(-sin(ag) * semieje_x, 0.0, cos(ag) * semieje_z).normalized()      # tangente, en el sentido en que crece el ángulo
			var g: MeshInstance3D = crear_quad_suelo("GrietaAnillo%d" % k, 0.9, perim_g * 1.25, SH_GRIETAS, {"avance": 0.0, "vida": 0.0, "semilla": 0.21 + 0.17 * float(k), "grosor": 0.03}, pg)
			g.rotation.y = atan2(tg.x, tg.z)                                                         # el +Z del quad (por donde avanza la grieta) a lo largo de la tangente
			c.add_child(g)
			_grietas_barrera.append(g)
			_barrera_dir.append([pg, tg, perim_g * 1.25])
		var dm: float = BARRERA_MARCA_TAM * maxf(semieje_x, semieje_z)
		_marca_pilar = crear_decal_suelo("Marca", dm, dm, PILAR_MARCA_ALTO, {"mascara": load(TEX_MARCA_SUELO), "vida": 0.0, "fuerza": 1.0}, Vector3.ZERO, -3)
		_marca_pilar.rotation.y = rng.randf() * TAU
		_marca_pilar.set_meta("lado", dm)
		c.add_child(_marca_pilar)
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2.ONE * minf(semieje_x, semieje_z) * 1.3
	_brillo = MeshInstance3D.new()
	_brillo.name = "Brillo"
	_brillo.mesh = pm
	_brillo.position = Vector3(0, 0.03, 0)
	_brillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm: StandardMaterial3D = StandardMaterial3D.new()                                          # plano, sin luz, sin aditivo: un disco tenue que se apaga
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	sm.albedo_color = Color(0.80, 0.50, 0.26, 0.0)
	sm.render_priority = -1
	_brillo.material_override = sm
	c.add_child(_brillo)


## Línea de púas: cada roca brota en su sitio con sus lajas y polvo, en orden hacia -Z.
## En tierra, la retirada también avanza del inicio a la punta.
func _haz(c: Node3D) -> void:
	_haz_largo = semieje_x * 2.0
	if haz_tope > 0.0:
		_haz_largo = minf(_haz_largo, haz_tope)                                # las púas no brotan más allá de lo que toca
	_haz_r = semieje_z * FuegoToy.HAZ_ABRE
	_haz_alt = maxf(semieje_y, 0.4)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 53
	var n: int = clampi(int(round(_haz_largo / 0.32)), 4, PUAS_MAX)
	_haz_n = n
	var t_nacer: float = _t_nacer_haz()
	var dur_f: float = SUBE_PUA_S / t_nacer
	var capa: Array = []
	var lajas: Array = []
	var n_lajas: int = mini(MAX_BLOQUES - n, n * 2)
	for i in n:
		var f: float = (float(i) + 0.5) / float(n)
		var crece: float = 0.45 + 0.75 * f                                                          # de menor (mano) a mayor (punta)
		# 7/11 (vídeo de tierra): la púa es una ROCA estirada, no una lámina. Antes el ancho salía del semieje Z del haz (0,17 m en el juego) y el alto de la mano (≈ 1,8 m): 1 a 20, una
		# cuchilla. Ahora el ancho sale del ALTO (`ANCHO_PUA`), que es lo que hace que se lea como piedra, y el corredor del haz solo le pone un tope (`_haz_r × PUA_ANCHO_MAX_R`).
		var alto: float = clampf(_haz_alt * 2.0 * rng.randf_range(0.96, 1.04) * crece, 0.2, PUA_ALTO_MAX)
		var w: float = clampf(alto * ANCHO_PUA * rng.randf_range(0.85, 1.15), 0.12, maxf(_haz_r * PUA_ANCHO_MAX_R, 0.3))
		var lado: float = rng.randf_range(-0.55, 0.55) * _haz_r
		var id: String = MALLAS_PUA[i % MALLAS_PUA.size()]
		var ret: float = (0.05 + _haz_adelanto() + PASO_PUA_S * float(i)) / t_nacer
		var pos: Vector3 = Vector3(lado, 0.0, -f * _haz_largo)
		var inclinacion: float = rng.randf_range(0.12, 0.30)
		var giro: float = rng.randf_range(-0.35, 0.35) + (PI if rng.randf() < 0.5 else 0.0)
		var fondo: float = w * rng.randf_range(0.85, 1.0)
		if not linea_ignea:
			inclinacion += lerpf(0.10, 0.43, f)
			fondo *= 1.35
		var b: Dictionary = _b(id, pos, HieloMallas._inclinar(Vector3.FORWARD, inclinacion, giro), w, alto, fondo, ret, rng)
		b["dur"] = dur_f * rng.randf_range(0.85, 1.2)                                               # cada púa tarda lo suyo en salir, no todas lo mismo
		b["sobre"] = rng.randf_range(SOBREPASO * 0.6, SOBREPASO * 1.9)                              # …y se pasa de su sitio lo suyo: el easing por clave del vídeo
		var ret_hunde: float = (1.0 - f if linea_ignea else f) * 0.5
		b["ret_hunde"] = ret_hunde
		capa.append(b)
		# lajas: 1-2 losas en la base, a un lado y a otro, levantadas hacia fuera (la losa del suelo se rompe y se alza)
		var nl: int = 2 if (i % 3 != 1) else 1
		for q in nl:
			if lajas.size() >= n_lajas:
				break
			var al: float = (PI * 0.5 if q == 0 else -PI * 0.5) + rng.randf_range(-0.7, 0.7)
			var dl: Vector3 = Vector3(sin(al), 0.0, cos(al))
			var wl: float = w * rng.randf_range(0.9, 1.4)
			var bl: Dictionary = _b(MALLAS_LAJA[(i + q) % MALLAS_LAJA.size()], pos + dl * (w * 0.55 + wl * 0.3) + Vector3(0, 0, rng.randf_range(-0.05, 0.05)), HieloMallas._inclinar(-dl, rng.randf_range(0.12, 0.3), rng.randf() * TAU), wl, wl * rng.randf_range(0.14, 0.2), wl, ret + 0.015, rng)
			bl["dur"] = dur_f
			bl["ret_hunde"] = ret_hunde + 0.03
			lajas.append(bl)
	_montar_bloques(c, capa + lajas)
	if linea_ignea:
		_grietas = crear_quad_suelo("Grietas", maxf(_haz_r * 2.6, 0.5), _haz_largo * 1.04, SH_GRIETAS, {"avance": 0.0, "vida": 1.0, "semilla": 0.37, "grosor": 0.02}, Vector3(0, 0.02, -_haz_largo * 0.5))
		_grietas.rotation.y = PI
		c.add_child(_grietas)
	elif _haz_nuevo():
		# 21/11: la línea de tierra también lleva grieta: corre por delante de las púas (la misma del haz ígneo, con el color pardo de las grietas) y se borra al final
		_grietas = crear_quad_suelo("Grietas", maxf(_haz_r * 3.0, 0.9), _haz_largo * 1.04, SH_GRIETAS, {"avance": 0.0, "vida": 0.0, "semilla": 0.37, "grosor": 0.03}, Vector3(0, 0.02, -_haz_largo * 0.5))
		_grietas.rotation.y = PI
		c.add_child(_grietas)


## Ancla cada púa y laja una vez que la línea ya tiene su posición y dirección.
func anclar_linea_al_suelo(cota: Callable) -> void:
	for b: Dictionary in _bloques:
		var pie: Vector3 = to_global(b["pos"])
		pie.y = cota.call(pie)
		b["pos"] = to_local(pie)
	_avanzar_bloques(0.0)


## Lo que dura «nacer» en el haz: anticipación + una púa tras otra + la última saliendo.
func _t_nacer_haz() -> float:
	return 0.05 + _haz_adelanto() + PASO_PUA_S * float(maxi(_haz_n, 1)) + SUBE_PUA_S + 0.05


## s en que solo corre la grieta antes de que brote la primera púa (0 con el interruptor apagado o en la línea ígnea).
func _haz_adelanto() -> float:
	return HAZ_GRIETA_S if _haz_nuevo() else 0.0


func _anim_si_hace_falta() -> void:
	var ap: AnimationPlayer = get_node_or_null("Anim") as AnimationPlayer
	var es_vol: bool = figura != Figura.BOLA
	var nacer: float = T_NACER_BOLA
	var morir_s: float = T_MORIR_BOLA
	if figura == Figura.BOLA and bola_nueva():
		nacer = T_NACER_BOLA_INI
	if figura == Figura.HAZ:
		nacer = _t_nacer_haz()                      # depende de cuántas púas tenga (una tras otra)
		morir_s = HAZ_T_MORIR if _haz_nuevo() else 0.8      # se hunden en orden, de la mano a la punta
	elif figura == Figura.BARRERA and barrera_nueva():
		nacer = T_NACER_BARRERA
		morir_s = T_MORIR_BARRERA
	elif figura == Figura.MURO and MURO_INICIO_FINAL:
		nacer = T_NACER_MURO
		morir_s = T_MORIR_MURO
	elif es_vol:
		nacer = T_NACER
		morir_s = T_MORIR
	if ap != null and _figura_anim == int(figura) and absf(_t_nacer_act - nacer) < 0.001:
		return
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "Anim"
		add_child(ap)
	_figura_anim = int(figura)
	_t_nacer_act = nacer
	var lib: AnimationLibrary = AnimationLibrary.new()
	for nom in ["nacer", "vivir", "morir"]:
		var an: Animation = Animation.new()
		var pista: int = an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(pista, NodePath(".:sube" if (es_vol and nom == "nacer") else (".:hunde" if es_vol else ".:aparicion")))
		match nom:
			"nacer":
				an.length = nacer
				an.track_insert_key(pista, 0.0, 0.0)
				an.track_insert_key(pista, nacer, 1.0)
			"vivir":
				an.length = 1.0
				an.loop_mode = Animation.LOOP_LINEAR
				an.track_insert_key(pista, 0.0, 0.0 if es_vol else 1.0)
			"morir":
				an.length = morir_s
				an.track_insert_key(pista, 0.0, 0.0 if es_vol else 1.0)
				an.track_insert_key(pista, morir_s, 1.0 if es_vol else 0.0)
		an.track_set_interpolation_type(pista, Animation.INTERPOLATION_LINEAR)
		lib.add_animation(nom, an)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	dura_morir = morir_s


# ------------------------------------------------------------------ subir, asentarse y hundirse ------------------------------------------------------------------

## Desplazamiento vertical (fracción del alto, 0 = en su sitio, −1 = bajo tierra) de un bloque con `s` (0..1 tras su anticipación): sube deprisa, se pasa `sobre` y se asienta.
## 7/11 (vídeo de tierra de Pablo, `docs/capturas/referencias/tierra_video_godot/`): allí cada púa lleva SU easing a mano en la clave, no una curva igual para todas; aquí el sobrepaso
## es por bloque (`b["sobre"]`, con SOBREPASO de defecto para todo lo demás: muro, pilar, barrera y el impacto, que no cambian).
static func subida(s: float, sobre: float = SOBREPASO) -> float:
	var u: float = clampf(s, 0.0, 1.0)
	if u < 0.62:
		return -1.0 + (1.0 + sobre) * smoothstep(0.0, 1.0, u / 0.62)
	return sobre * (1.0 - smoothstep(0.0, 1.0, (u - 0.62) / 0.38))


## (pruebas) desplazamiento vertical actual (m) de cada bloque.
func alturas_actuales() -> Array:
	return _y_act


## Pone cada bloque según `sube` (anticipación → subida con sobrepaso → asentamiento) y `hunde` (temblor y bajada bajo tierra). Suelta el polvo y los fragmentos en su momento.
func _avanzar_bloques(delta: float) -> void:
	if _bloques_mms.is_empty() or _bloques.is_empty():
		return
	var sb: float = clampf(sube, 0.0, 1.0)
	var hd: float = clampf(hunde, 0.0, 1.0)
	var tt: float = Time.get_ticks_msec() * 0.001
	_y_act = []
	var es_haz: bool = figura == Figura.HAZ
	var haz_n: bool = _haz_nuevo()
	var barr_n: bool = _barrera_ok()
	var por_bloque: bool = es_haz or barr_n                                     # polvo y cascotes por roca, cuando asoma (púas y barrera en ola), no todo de golpe
	var entierro: float = ENTIERRO_LINEA if es_haz and not linea_ignea else 0.0
	var k_ant: float = ANTICIPO if not es_haz else 0.0
	var asentados: int = 0
	var techo_puesto: bool = true
	for j in _bloques.size():
		var b: Dictionary = _bloques[j]
		var ret: float = float(b["retraso"])
		var h: float = float(b["h"]) * altura
		var pos: Vector3 = b["pos"]
		var alto_sube: float = h if es_haz else h + maxf(pos.y, 0.0)
		var dur: float = float(b.get("dur", -1.0))
		var s: float
		if dur > 0.0:
			s = clampf((sb - ret) / dur, 0.0, 1.0)                                   # púas: cada una sale en su momento y tarda lo mismo
		else:
			s = clampf((sb - k_ant - ret * (1.0 - k_ant)) / maxf(1.0 - k_ant - ret * (1.0 - k_ant), 0.01), 0.0, 1.0)
		var y: float = subida(s, float(b.get("sobre", SOBREPASO))) * alto_sube
		if s >= 0.95:
			asentados += 1
		elif bool(b.get("techo", false)):
			techo_puesto = false
		var rh: float = float(b.get("ret_hunde", -1.0))
		var tiembla: bool = (sb < k_ant + ret) if not por_bloque else (sb < ret and sb > ret - 0.08)
		var te: float = float(b.get("t_estalla", -1.0))                             # MURO que estalla: fracción de `hunde` a la que revienta esta roca (-1: se hunde, como siempre)
		var oculto: bool = false
		if hd > 0.0 and te >= 0.0:
			tiembla = hd < te
			if hd >= te:
				oculto = true
				if not bool(b.get("estallado", false)) and delta > 0.0:
					b["estallado"] = true
					_estallar_bloque(b, h)
		elif hd > 0.0:
			var ini_t: float = rh - HAZ_TIEMBLA if (haz_n or barr_n) else rh                # las púas y las rocas de la barrera se resquebrajan antes de hundirse
			tiembla = tiembla or ((hd < 0.3) if rh < 0.0 else (hd >= ini_t and hd < rh + 0.08))
			if (haz_n or barr_n) and rh >= 0.0 and hd >= rh + 0.03 and not bool(b.get("hundido_ya", false)) and delta > 0.0:
				b["hundido_ya"] = true
				_desmoronar(b, h)                                                          # se rompe al empezar a hundirse: cascotes y polvo
		if tiembla:                                                                  # temblor antes de salir; al morir, antes de hundirse
			pos += Vector3(sin(tt * 61.0 + float(j) * 1.7), 0.0, cos(tt * 53.0 + float(j))) * 0.015
		if hd > 0.0 and te < 0.0:
			if rh >= 0.0:
				y -= alto_sube * 1.05 * smoothstep(rh + 0.04, rh + 0.42, hd)            # en orden (la punta del haz primero); a hunde = 1 todas bajo tierra
			else:
				y -= alto_sube * 1.05 * smoothstep(0.25, 1.0, hd)
		if por_bloque and s >= 0.08 and not bool(b.get("polvo_ya", false)) and delta > 0.0:
			b["polvo_ya"] = true
			_polvo_pua(b)                                                            # 7/11 (Pablo): la púa rompe el suelo y suelta su nube baja y corta
		if por_bloque and s >= 0.62 and not bool(b["soltado"]) and delta > 0.0:
			b["soltado"] = true
			_cascotes_de(b)                                                          # al asomar del todo: cascotes y polvo de su base
		_y_act.append(y)
		var visible: bool = y > -alto_sube * 0.999 and h > 0.0005 and not oculto
		var mi: MultiMeshInstance3D = _bloques_mms[int(b["mm"])]
		if mi == null or not is_instance_valid(mi):
			continue
		var mm: MultiMesh = mi.multimesh
		var idx: int = int(b["idx"])
		if visible:
			mm.set_instance_transform(idx, asentar(mm.mesh, b["rot"], float(b["wx"]) * ancho, h, float(b["wz"]) * ancho, pos + Vector3(0, y - entierro, 0)))
			mm.set_instance_custom_data(idx, Color(float(b["tono"]), 1.0, 0.0, 0.0))
		else:
			HieloMallas.ocultar(mm, idx)
	_avanzar_grietas(sb, hd)
	_avanzar_marca_pilar(sb, hd)
	_avanzar_grietas_muro(delta, sb, hd)
	_avanzar_grietas_barrera(delta, sb, hd)
	_polvo_grieta_haz(delta, sb, hd)
	# MURO que estalla: en cuanto ha reventado la última roca, los trozos y el polvo pasan al padre (siguen cayendo cuando el efecto se libere). No se espera al `hd >= 0,98` de
	# `_polvo_de_bloques`: con un morir de 0,75 s esa ventana dura 15 ms, menos que un fotograma, y se la saltaba (los trozos desaparecían en el aire).
	if delta > 0.0 and figura == Figura.MURO and MURO_INICIO_FINAL and hd >= MURO_ESTALLA_DESDE + MURO_ESTALLA_TRAMO + 0.08 and _piedras != null:
		_soltar_reservas()
		return
	_avanzar_brillo(delta, techo_puesto and sb >= 0.999 and figura == Figura.BARRERA, hd)
	if delta > 0.0 and is_inside_tree():
		_polvo_de_bloques(delta, sb, hd, k_ant, asentados if not por_bloque else 0)


## MURO: la grieta se abre del centro a los extremos en la primera parte del nacer, con polvo arenoso en sus dos frentes; se queda bajo el muro y se cierra al final del morir.
func _avanzar_grietas_muro(delta: float, sb: float, hd: float) -> void:
	if _grietas_muro.is_empty():
		return
	var av: float = clampf(sb / MURO_GRIETA_FRAC, 0.0, 1.0)
	for g in _grietas_muro:
		if g == null or not is_instance_valid(g):
			continue
		var m: ShaderMaterial = (g as MeshInstance3D).material_override as ShaderMaterial
		m.set_shader_parameter("avance", av)
		m.set_shader_parameter("vida", smoothstep(0.0, 0.03, sb) * (1.0 - smoothstep(0.85, 1.0, hd)))
	if delta <= 0.0 or sb <= 0.0 or sb >= MURO_GRIETA_FRAC + 0.05 or hd > 0.0 or _polvo == null or not is_instance_valid(_polvo) or not is_inside_tree():
		return
	var tr: Transform3D = global_transform
	_acc_g += MURO_POLVO_GRIETA * clampf(chispas, 0.0, 1.0) * delta
	while _acc_g >= 1.0:
		_acc_g -= 1.0
		var lado: float = 1.0 if randf() < 0.5 else -1.0
		# casi todo en el frente que avanza; algo, por la grieta ya abierta
		var x: float = lado * semieje_x * (av * randf_range(0.85, 1.0) if randf() < 0.7 else av * randf())
		var z: float = randf_range(-1.0, 1.0) * maxf(semieje_z, 0.15) * 1.6
		_polvo.call("emitir", tr * Vector3(x, 0.06, z), tr.basis * Vector3(lado * randf_range(0.2, 0.7), randf_range(0.25, 0.6), signf(z) * randf_range(0.2, 0.6)), randf_range(0.8, 1.1), randf_range(0.6, 0.95))


## (pruebas) `avance` y `vida` de las grietas del muro (-1 si no las hay).
func estado_grietas_muro() -> Dictionary:
	if _grietas_muro.is_empty() or not is_instance_valid(_grietas_muro[0]):
		return {"avance": -1.0, "vida": -1.0}
	var m: ShaderMaterial = (_grietas_muro[0] as MeshInstance3D).material_override as ShaderMaterial
	return {"avance": float(m.get_shader_parameter("avance")), "vida": float(m.get_shader_parameter("vida"))}


## MURO: una roca revienta en MURO_TROZOS piedras pequeñas que saltan de su volumen hacia fuera y hacia arriba, caen y ruedan, con una nube de polvo.
func _estallar_bloque(b: Dictionary, h: float) -> void:
	if _polvo == null or not is_instance_valid(_polvo) or _piedras == null or not is_instance_valid(_piedras) or not is_inside_tree():
		return
	var tr: Transform3D = global_transform
	var p0: Vector3 = b["pos"]
	var w: float = float(b["wx"]) * ancho
	var wz: float = float(b["wz"]) * ancho
	var piso: float = (tr * p0).y + 0.01
	_piedras.set("suelo_y", global_position.y + 0.01)
	var es_pie: bool = String(b["malla"]).begins_with("piedra_est_")
	for q in (1 if es_pie else MURO_TROZOS):
		var loc: Vector3 = p0 + Vector3(randf_range(-0.4, 0.4) * w, randf_range(0.15, 0.9) * h, randf_range(-0.4, 0.4) * wz)
		var a: float = randf() * TAU
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		_piedras.call("emitir", tr * loc, tr.basis * (d * randf_range(1.0, 2.8) + Vector3(0, randf_range(1.4, 3.4), 0)), randf_range(0.9, 1.4), randf_range(0.1, 0.19) * sqrt(maxf(w, 0.3)), Vector3.ZERO, piso)
	for q in (1 if es_pie else 3):
		var a2: float = randf() * TAU
		var d2: Vector3 = Vector3(cos(a2), 0.0, sin(a2))
		_polvo.call("emitir", tr * (p0 + Vector3(0, randf_range(0.2, 0.7) * h, 0)), tr.basis * (d2 * randf_range(0.6, 1.5) + Vector3(0, 0.5, 0)), 1.0, randf_range(0.9, 1.4) * sqrt(maxf(w, 0.3)))


## PILAR: la marca de tierra partida se abre desde el centro mientras la columna tiembla y sale (el aviso), se queda bajo ella y se cierra cuando ya se ha hundido.
func _avanzar_marca_pilar(sb: float, hd: float) -> void:
	if _marca_pilar == null or not is_instance_valid(_marca_pilar):
		return
	var lado: float = float(_marca_pilar.get_meta("lado", 1.0)) * lerpf(0.3, 1.0, smoothstep(0.0, 0.5, sb))
	_marca_pilar.scale = Vector3(lado, PILAR_MARCA_ALTO, lado)
	(_marca_pilar.material_override as ShaderMaterial).set_shader_parameter("vida", smoothstep(0.0, 0.06, sb) * (1.0 - smoothstep(0.55, 1.0, hd)))


## (pruebas) lado actual (m) y `vida` de la marca del pilar (-1 si no la hay).
func estado_marca_pilar() -> Dictionary:
	if _marca_pilar == null or not is_instance_valid(_marca_pilar):
		return {"lado": -1.0, "vida": -1.0}
	return {"lado": _marca_pilar.scale.x, "vida": float((_marca_pilar.material_override as ShaderMaterial).get_shader_parameter("vida"))}


## HAZ: las grietas corren por delante de las púas (`avance` = hasta dónde ha llegado la secuencia, un tramo por delante) y se van al hundirse.
func _avanzar_grietas(sb: float, hd: float) -> void:
	if _grietas == null or not is_instance_valid(_grietas):
		return
	var m: ShaderMaterial = _grietas.material_override as ShaderMaterial
	if m == null:
		return
	var t_n: float = _t_nacer_haz()
	if _haz_nuevo():
		# 21/11: la grieta sale sola `HAZ_GRIETA_S` antes de la primera púa y llega a la punta (un poco antes de que brote la última); se queda mientras las púas se hunden y se borra al final
		var t_fin: float = _haz_adelanto() + 0.05 + PASO_PUA_S * float(maxi(_haz_n - 1, 0)) - 0.08
		m.set_shader_parameter("avance", clampf(sb * t_n / maxf(t_fin, 0.1), 0.0, 1.0))
		m.set_shader_parameter("vida", (1.0 - smoothstep(0.45, 1.0, hd)) * smoothstep(0.0, 0.02, sb))
		return
	var avance: float = clampf((sb * t_n + 0.12) / maxf(t_n - SUBE_PUA_S, 0.05), 0.0, 1.0)      # en segundos: a la vez que brota la púa k, la grieta va unas púas por delante
	m.set_shader_parameter("avance", avance)
	m.set_shader_parameter("vida", (1.0 - smoothstep(0.0, 0.7, hd)) * smoothstep(0.0, 0.02, sb))


## HAZ: polvo arenoso en el frente de la grieta mientras corre (antes y entre las púas).
func _polvo_grieta_haz(delta: float, sb: float, hd: float) -> void:
	if not _haz_nuevo() or delta <= 0.0 or sb <= 0.0 or sb >= 0.98 or hd > 0.0 or _polvo == null or not is_instance_valid(_polvo) or not is_inside_tree():
		return
	var av: float = float(estado_grietas()["avance"])
	if av <= 0.0 or av >= 1.0:
		return
	var tr: Transform3D = global_transform
	_acc_gb += HAZ_POLVO_GRIETA * clampf(chispas, 0.0, 1.0) * delta
	while _acc_gb >= 1.0:
		_acc_gb -= 1.0
		var z: float = -av * _haz_largo * 1.04 * randf_range(0.9, 1.0) if randf() < 0.75 else -av * _haz_largo * randf()
		var x: float = randf_range(-1.0, 1.0) * maxf(_haz_r, 0.2) * 1.1
		_polvo.call("emitir", tr * Vector3(x, 0.06, z), tr.basis * Vector3(signf(x) * randf_range(0.2, 0.6), randf_range(0.25, 0.6), randf_range(-0.5, 0.1)), randf_range(0.7, 1.0), randf_range(0.5, 0.8))


## BARRERA: la grieta en anillo da la vuelta (cada tramo corre en el sentido del ángulo, uno tras otro) con polvo en su frente; se queda bajo las rocas y la marca de tierra partida la
## releva al hundirse (se borra con el morir).
func _avanzar_grietas_barrera(delta: float, sb: float, hd: float) -> void:
	if _grietas_barrera.is_empty():
		return
	var p: float = clampf(sb / BARRERA_GRIETA_FRAC, 0.0, 1.0)
	var k_n: int = _grietas_barrera.size()
	var activos: Array = []
	for k in k_n:
		var g: MeshInstance3D = _grietas_barrera[k]
		if g == null or not is_instance_valid(g):
			continue
		var av: float = clampf((p * float(k_n + 1) - float(k)) / 1.5, 0.0, 1.0)
		var m: ShaderMaterial = g.material_override as ShaderMaterial
		m.set_shader_parameter("avance", av)
		m.set_shader_parameter("vida", smoothstep(0.0, 0.03, sb) * (1.0 - smoothstep(0.5, 0.95, hd)))
		if av > 0.0 and av < 1.0:
			activos.append(k)
	if delta <= 0.0 or hd > 0.0 or sb >= BARRERA_GRIETA_FRAC + 0.1 or activos.is_empty() or _polvo == null or not is_instance_valid(_polvo) or not is_inside_tree():
		return
	var tr: Transform3D = global_transform
	_acc_gb += BARRERA_POLVO_GRIETA * clampf(chispas, 0.0, 1.0) * delta
	while _acc_gb >= 1.0:
		_acc_gb -= 1.0
		var k2: int = activos[randi() % activos.size()]
		var d: Array = _barrera_dir[k2]
		var av2: float = float(estado_grietas_barrera()["avances"][k2])
		var pos: Vector3 = (d[0] as Vector3) + (d[1] as Vector3) * (float(d[2]) * (av2 - 0.5)) + Vector3(0, 0.04, 0)
		var fuera: Vector3 = Vector3(pos.x / maxf(semieje_x, 0.1), 0.0, pos.z / maxf(semieje_z, 0.1)).normalized()
		_polvo.call("emitir", tr * pos, tr.basis * (fuera * randf_range(0.2, 0.6) + (d[1] as Vector3) * randf_range(0.1, 0.4) + Vector3(0, randf_range(0.25, 0.55), 0)), randf_range(0.8, 1.1), randf_range(0.6, 0.95))


## (pruebas) `avances` de cada tramo de la grieta en anillo de la barrera y `vida` del primero (vacío / -1 si no la hay).
func estado_grietas_barrera() -> Dictionary:
	var av: Array = []
	var vida_g: float = -1.0
	for g in _grietas_barrera:
		if g == null or not is_instance_valid(g):
			continue
		var m: ShaderMaterial = (g as MeshInstance3D).material_override as ShaderMaterial
		av.append(float(m.get_shader_parameter("avance")))
		if vida_g < 0.0:
			vida_g = float(m.get_shader_parameter("vida"))
	return {"avances": av, "vida": vida_g}


## Una roca o púa que empieza a hundirse se rompe: cascotes que saltan de su volumen y polvo.
func _desmoronar(b: Dictionary, h: float) -> void:
	if _polvo == null or not is_instance_valid(_polvo) or _piedras == null or not is_instance_valid(_piedras) or not is_inside_tree():
		return
	var tr: Transform3D = global_transform
	var p0: Vector3 = b["pos"]
	var w: float = float(b["wx"]) * ancho
	var es_laja: bool = String(b["malla"]).begins_with("laja_")
	var es_pie: bool = String(b["malla"]).begins_with("piedra_est_")
	var k: float = clampf(chispas, 0.0, 1.0)
	_piedras.set("suelo_y", global_position.y + 0.01)
	for q in (1 if (es_laja or es_pie) else 3):
		var a: float = randf() * TAU
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		_polvo.call("emitir", tr * (p0 + d * w * 0.35 + Vector3(0, randf_range(0.1, 0.5) * h, 0)), tr.basis * (d * randf_range(0.5, 1.2) + Vector3(0, 0.35, 0)), randf_range(0.7, 1.0), randf_range(0.6, 0.9) * sqrt(maxf(w, 0.3)))
	if es_laja or es_pie:
		return
	for q in 2:
		if randf() > 0.9 * k:
			continue
		var a2: float = randf() * TAU
		var d2: Vector3 = Vector3(cos(a2), 0.0, sin(a2))
		_piedras.call("emitir", tr * (p0 + Vector3(0, randf_range(0.2, 0.8) * h, 0) + d2 * w * 0.3), tr.basis * (d2 * randf_range(0.8, 1.9) + Vector3(0, randf_range(0.8, 1.8), 0)), randf_range(0.9, 1.4), randf_range(0.05, 0.1) * sqrt(maxf(w, 0.3)), Vector3.ZERO, (tr * p0).y + 0.01)


## (pruebas) `avance` y `vida` de las grietas del haz (-1 si no las hay).
func estado_grietas() -> Dictionary:
	if _grietas == null or not is_instance_valid(_grietas) or not (_grietas.material_override is ShaderMaterial):
		return {"avance": -1.0, "vida": -1.0}
	var m: ShaderMaterial = _grietas.material_override as ShaderMaterial
	return {"avance": float(m.get_shader_parameter("avance")), "vida": float(m.get_shader_parameter("vida"))}


## BARRERA: al cerrarse la cúpula (las losas del techo asentadas) un destello de polvo y un disco pardo-naranja tenue dentro que se apaga en 0,4 s.
func _avanzar_brillo(delta: float, cerrada: bool, hd: float) -> void:
	if _brillo == null or not is_instance_valid(_brillo):
		return
	var sm: StandardMaterial3D = _brillo.material_override as StandardMaterial3D
	if sm == null:
		return
	if cerrada and _t_cerrada < 0.0 and delta > 0.0 and _listo:                # solo con tiempo real: al construir (sube = 1 por defecto) no cuenta
		_t_cerrada = 0.0
		if _polvo != null and is_instance_valid(_polvo) and is_inside_tree():
			var tr: Transform3D = global_transform
			for q in 8:
				var a: float = TAU * float(q) / 8.0
				var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
				_polvo.call("emitir", tr * (d * maxf(semieje_x, semieje_z) * 0.7 + Vector3(0, semieje_y * 0.9, 0)), tr.basis * (d * randf_range(1.0, 1.8) + Vector3(0, 0.5, 0)), 0.9, 1.1)
	elif _t_cerrada >= 0.0:
		_t_cerrada += delta
	var alfa: float = 0.0
	if _t_cerrada >= 0.0 and hd <= 0.0:
		alfa = 0.3 * (1.0 - smoothstep(0.0, 0.4, _t_cerrada))
	sm.albedo_color.a = alfa
	_brillo.visible = alfa > 0.005


## (pruebas) opacidad actual del brillo interior de la cúpula y segundos desde que se cerró (-1 si no se ha cerrado).
func estado_brillo() -> Dictionary:
	var a: float = 0.0
	if _brillo != null and is_instance_valid(_brillo) and _brillo.material_override is StandardMaterial3D:
		a = (_brillo.material_override as StandardMaterial3D).albedo_color.a
	return {"alfa": a, "cerrada_hace": _t_cerrada}


## HAZ: la nube de polvo BAJA y CORTA de una púa (o laja) en el momento en que rompe el suelo: unas bocanadas anchas a ras de suelo que se abren hacia fuera y se van en ~0,5 s.
func _polvo_pua(b: Dictionary) -> void:
	if _polvo == null or not is_instance_valid(_polvo) or not is_inside_tree():
		return
	var tr: Transform3D = global_transform
	var w: float = float(b["wx"]) * ancho
	var p0: Vector3 = b["pos"]
	var es_laja: bool = String(b["malla"]).begins_with("laja_")
	var n: int = 1 if es_laja else 4
	for q in n:
		var a: float = randf() * TAU
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		_polvo.call("emitir", tr * (p0 + d * w * 0.3 + Vector3(0, 0.12, 0)), tr.basis * (d * randf_range(0.5, 1.1) + Vector3(0, 0.3, 0)), 0.6, randf_range(1.2, 1.7) * sqrt(maxf(w, 0.3)))


## Cascotes y polvo que saltan de la base de una púa al asomar del todo (y de una laja, menos).
func _cascotes_de(b: Dictionary) -> void:
	if _polvo == null or not is_instance_valid(_polvo) or _piedras == null or not is_instance_valid(_piedras) or not is_inside_tree():
		return
	var tr: Transform3D = global_transform
	var k: float = clampf(chispas, 0.0, 1.0)
	var w: float = float(b["wx"]) * ancho
	var p0: Vector3 = b["pos"]
	var es_laja: bool = String(b["malla"]).begins_with("laja_")
	for q in (1 if es_laja else 2):
		var a: float = randf() * TAU
		var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
		_polvo.call("emitir", tr * (p0 + d * w * 0.4 + Vector3(0, 0.05, 0)), tr.basis * (d * randf_range(0.8, 1.6) + Vector3(0, 0.4, 0)), 0.8, randf_range(0.6, 0.9) * sqrt(maxf(w, 0.3)))
	if not es_laja and randf() < 0.9 * k:
		var a2: float = randf() * TAU
		var d2: Vector3 = Vector3(cos(a2), 0.0, sin(a2))
		_piedras.call("emitir", tr * (p0 + Vector3(0, 0.1, 0) + d2 * w * 0.4), tr.basis * (d2 * randf_range(0.8, 1.8) + Vector3(0, randf_range(1.2, 2.2), 0)), randf_range(0.9, 1.4), randf_range(0.04, 0.08) * sqrt(maxf(w, 0.3)), Vector3.ZERO, (tr * p0).y + 0.01)


## El polvo de la construcción: en la anticipación sale de la base; al asentarse, polvo radial bajo + fragmentos que ruedan (una vez); al hundirse, polvo mientras baja.
func _polvo_de_bloques(delta: float, sb: float, hd: float, k_ant: float, asentados: int) -> void:
	if _polvo == null or not is_instance_valid(_polvo) or _piedras == null or not is_instance_valid(_piedras):
		return
	var tr: Transform3D = global_transform
	var k: float = clampf(chispas, 0.0, 1.0)
	_piedras.set("suelo_y", global_position.y + 0.01)
	if sb < k_ant + 0.2 and sb > 0.0 and asentados == 0 and figura != Figura.HAZ and not _barrera_ok():      # anticipación (y los bloques que aún esperan su retraso): polvo que brota de la base (el haz lo hace púa a púa)
		_acc += 40.0 * k * delta
		while _acc >= 1.0:
			_acc -= 1.0
			var b: Dictionary = _bloques[randi() % _bloques.size()]
			var loc: Vector3 = (b["pos"] as Vector3) + Vector3(randf_range(-0.5, 0.5) * float(b["wx"]), 0.05, randf_range(-0.5, 0.5) * float(b["wz"]))
			_polvo.call("emitir", tr * loc, tr.basis * Vector3(randf_range(-0.4, 0.4), 0.5, randf_range(-0.4, 0.4)), 0.7, 0.6)
	elif asentados > 0 and not _asentado and hd <= 0.0:
		_asentado = true
		for b2 in _bloques:
			var w: float = float(b2["wx"]) * ancho
			var p0: Vector3 = b2["pos"]
			for q in 3:
				var a: float = randf() * TAU
				var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
				_polvo.call("emitir", tr * (p0 + d * w * 0.5 + Vector3(0, 0.05, 0)), tr.basis * (d * randf_range(1.2, 2.2) + Vector3(0, 0.3, 0)), 1.0, randf_range(0.8, 1.3) * sqrt(maxf(w, 0.3)))
			if randf() < 0.75 * k:
				var a2: float = randf() * TAU
				var d2: Vector3 = Vector3(cos(a2), 0.0, sin(a2))
				_piedras.call("emitir", tr * (p0 + Vector3(0, 0.1, 0) + d2 * w * 0.5), tr.basis * (d2 * randf_range(1.0, 2.2) + Vector3(0, randf_range(1.0, 2.0), 0)), randf_range(1.0, 1.6), randf_range(0.05, 0.1) * sqrt(maxf(w, 0.3)))
	elif hd > 0.25 and hd < 0.95:
		_acc += 22.0 * k * delta
		while _acc >= 1.0:
			_acc -= 1.0
			var b3: Dictionary = _bloques[randi() % _bloques.size()]
			var a3: float = randf() * TAU
			var d3: Vector3 = Vector3(cos(a3), 0.0, sin(a3))
			_polvo.call("emitir", tr * ((b3["pos"] as Vector3) + d3 * float(b3["wx"]) * 0.5 + Vector3(0, 0.05, 0)), tr.basis * (d3 * randf_range(0.6, 1.4) + Vector3(0, 0.4, 0)), 0.8, 0.8)
	if hd >= 0.98:
		_soltar_reservas()


## La bola que muere sin impacto: terrones de su superficie que caen, y polvo.
func _romper_bola() -> void:
	var r: float = maxf(semieje_x, semieje_z) * clampf(_c_escala, 0.1, 1.5)
	var tr: Transform3D = global_transform
	_piedras.set("suelo_y", global_position.y - altura_suelo)
	for k in 14:
		var d: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_piedras.call("emitir", tr * (d * r * randf_range(0.3, 0.9)), tr.basis * (d * randf_range(0.6, 2.0)) + _vel_mundo * 0.3, randf_range(0.8, 1.3), randf_range(0.06, 0.14) * sqrt(maxf(r / 0.4, 0.4)))
	if _polvo != null and is_instance_valid(_polvo):
		for q in 6:
			var d2: Vector3 = Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)).normalized()
			_polvo.call("emitir", tr * (d2 * r * 0.5), tr.basis * d2 * 1.2, 1.0, 1.0)
	if bola_nueva():
		_cascotes_bola_final(Vector3.ZERO)


## BOLA, final (21/11): la roca se parte en `BOLA_FIN_CASCOTES` cascotes GRANDES (los terrones de la roca, a su tamaño) que salen de su volumen hacia fuera —y hacia la cara de impacto, si la hay—
## con lo que lleve de velocidad, y una nube de polvo en el sitio.
func _cascotes_bola_final(normal: Vector3) -> void:
	_n_cascotes_final = 0
	if _piedras == null or not is_instance_valid(_piedras) or not is_inside_tree():
		return
	var r: float = maxf(semieje_x, semieje_z) * clampf(_c_escala, 0.3, 1.5)
	var tr: Transform3D = global_transform
	_piedras.set("suelo_y", global_position.y - altura_suelo)
	for k in BOLA_FIN_CASCOTES:
		var d: Vector3 = Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
		var v: Vector3 = d * randf_range(1.4, 3.0) + normal * randf_range(0.5, 1.6) + Vector3(0, randf_range(0.8, 1.8), 0) + _vel_mundo * 0.2
		if _piedras.call("emitir", tr * (d * r * randf_range(0.2, 0.7)), v, randf_range(1.0, 1.6), r * randf_range(0.22, 0.38)) >= 0:
			_n_cascotes_final += 1
	if _polvo != null and is_instance_valid(_polvo):
		for q in 7:
			var d2: Vector3 = Vector3(randf_range(-1, 1), randf_range(-0.2, 0.5), randf_range(-1, 1)).normalized()
			_polvo.call("emitir", tr * (d2 * r * 0.6), d2 * randf_range(0.8, 1.8) + normal * 0.5, randf_range(0.8, 1.1), randf_range(1.0, 1.5) * sqrt(maxf(r / 0.4, 0.5)))


## (pruebas) cascotes grandes de la última rotura de la bola.
func estado_final_bola() -> Dictionary:
	return {"cascotes": _n_cascotes_final}


## BOLA, inicio (21/11): la bola que nace sin carga se COMPACTA: terrones y polvo que acuden de alrededor (de abajo sobre todo, del suelo) a la roca, que crece de aplastada a redonda
## con la animación «nacer». Con carga, ya se hacía con el anillo de piedras.
func _empezar_inicio_bola() -> void:
	if not is_inside_tree():
		return
	if _ini_piedras != null and is_instance_valid(_ini_piedras):
		_ini_piedras.queue_free()
	var p: Piedras = Piedras.new()
	p.name = "Compacta"
	p.gravedad = 0.0
	add_child(p)
	p.montar(28, false)
	_ini_piedras = p
	_ini_t = 0.0
	_ini_n = 0
	_ini_acc = 0.0


func _avanzar_inicio_bola(delta: float) -> void:
	if _ini_t < 0.0 or figura != Figura.BOLA:
		return
	_ini_t += delta
	var u: float = clampf(_ini_t / T_NACER_BOLA_INI, 0.0, 1.0)
	var r: float = maxf(semieje_x, semieje_z)
	var tr: Transform3D = global_transform
	if u < 0.8 and _ini_piedras != null and is_instance_valid(_ini_piedras):
		_ini_acc += BOLA_INI_TASA * clampf(chispas, 0.0, 1.0) * delta
		while _ini_acc >= 1.0:
			_ini_acc -= 1.0
			var d: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1.0, 0.4), randf_range(-1, 1)).normalized()
			var rr: float = r * BOLA_INI_RADIO * randf_range(0.75, 1.15)
			var vida: float = BOLA_INI_SUBIDA_S * randf_range(0.8, 1.1)
			if int(_ini_piedras.call("emitir", d * rr, -d * (rr - r * 0.5) / vida, vida, r * randf_range(0.14, 0.24), Vector3.ZERO)) >= 0:
				_ini_n += 1
			if _polvo != null and is_instance_valid(_polvo) and randf() < 0.3:
				_polvo.call("emitir", tr * (d * rr * 0.8), -(tr.basis * d) * (rr * 0.8) / 0.4, 0.4, 0.45)
	if u >= 1.0:
		_ini_t = -1.0
		if _polvo != null and is_instance_valid(_polvo):
			for q in 6:                                                              # al juntarse: un resoplido de polvo alrededor
				var a: float = TAU * float(q) / 6.0 + randf() * 0.5
				_polvo.call("emitir", tr * (Vector3(cos(a), -0.2, sin(a)) * r * 0.7), tr.basis * (Vector3(cos(a), 0.15, sin(a)) * randf_range(0.8, 1.4)), 0.7, 0.7)
		if _ini_piedras != null and is_instance_valid(_ini_piedras) and is_inside_tree():
			get_tree().create_timer(0.5).timeout.connect(_ini_piedras.queue_free)
		_ini_piedras = null


## (pruebas) inicio de la bola sin carga: segundos desde que empezó (-1: no está), terrones vivos y emitidos.
func estado_inicio_bola() -> Dictionary:
	var v: int = 0
	if _ini_piedras != null and is_instance_valid(_ini_piedras):
		v = int(_ini_piedras.call("vivas"))
	return {"t": _ini_t, "vivas": v, "emitidos": _ini_n}


# ------------------------------------------------------------------ vuelo y reservas ------------------------------------------------------------------

func _set_proyectil(v: bool) -> void:
	proyectil = v


## Reservas de polvo (humo toon pardo, en el mundo) y de piedras (terrones y fragmentos, en el mundo).
func _montar_reservas() -> void:
	var quiero_polvo: int = POLVO_FIG_HAZ if (figura == Figura.HAZ or (figura == Figura.MURO and MURO_INICIO_FINAL) or _barrera_ok()) else POLVO_FIG
	var quiero_piedras: int = PIEDRAS_MURO if ((figura == Figura.MURO and MURO_INICIO_FINAL) or _barrera_ok()) else PIEDRAS_FIG
	if figura == Figura.BOLA and bola_nueva():
		quiero_piedras = PIEDRAS_BOLA_NUEVA
	# 18/11: se rehacen también si la figura pide otra reserva (antes se quedaban las del primer montaje: el muro que estalla solo tenía 24 terrones de los ~50 que suelta)
	if _polvo != null and is_instance_valid(_polvo) and _piedras != null and is_instance_valid(_piedras) and int(_polvo.call("capacidad")) == quiero_polvo and int(_piedras.call("capacidad")) == quiero_piedras:
		return
	for n in [_polvo, _piedras]:
		if n != null and is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	var r: float = maxf(semieje_x, semieje_z) if figura == Figura.BOLA else 0.4
	_polvo = HumoToy.new()
	_polvo.name = "Polvo"
	add_child(_polvo)
	_polvo.call("montar", quiero_polvo, polvo_params(0.28 * sqrt(maxf(r / 0.4, 0.4)), 0.7 * sqrt(maxf(r / 0.4, 0.4)), 1.0, Vector3(0, 0.35, 0), true))
	_piedras = Piedras.new()
	_piedras.name = "Terrones"
	add_child(_piedras)
	_piedras.call("montar", quiero_piedras, true)
	# 7/11: polvo y piedras son top_level (sus posiciones son del MUNDO) pero su MultiMesh trae un custom_aabb de ±40 m alrededor del ORIGEN del mundo: en el juego (el toy a x = 84) la cámara los
	# descartaba por fuera de su caja y el polvo y los cascotes no se veían nunca (en el lab, junto al origen, sí). Caja enorme: nunca se descartan.
	for n in [_polvo, _piedras]:
		for mi in (n as Node).find_children("*", "MultiMeshInstance3D", true, false):
			(mi as MultiMeshInstance3D).custom_aabb = AABB(Vector3.ONE * -4000.0, Vector3.ONE * 8000.0)


func _process(delta: float) -> void:
	super._process(delta)
	_avanzar_carga(delta)
	_avanzar_bola(delta)
	_avanzar_inicio_bola(delta)
	_avanzar_bloques(delta)
	_emitir_bola(delta)


func _avanzar_bola(delta: float) -> void:
	if _inclinable == null or not is_instance_valid(_inclinable):
		return
	var vuela: bool = proyectil and _est != EstadoCarga.APAGANDO
	_giro_bola += (GIRO_VUELO if vuela else GIRO_QUIETA) * velocidad * delta
	if vuela:
		_inclinable.rotation = Vector3(_giro_bola, 0.3, 0.0)                  # rueda sobre el eje X: gira «hacia delante» al volar
	else:
		_inclinable.rotation = Vector3(0.2, _giro_bola, 0.1)


## La bola en vuelo suelta terrones que caen y polvo que se queda atrás.
func _emitir_bola(delta: float) -> void:
	if figura != Figura.BOLA or _piedras == null or not is_instance_valid(_piedras) or not _listo or delta <= 0.0 or not is_inside_tree():
		return
	var pos: Vector3 = global_position
	if _tiene_ult:
		_vel_mundo = (pos - _ult_pos) / delta
	_ult_pos = pos
	_tiene_ult = true
	if _cuerpo == null or not _cuerpo.visible or _est == EstadoCarga.CANCELANDO or _est == EstadoCarga.APAGANDO or not proyectil:
		return
	var r: float = maxf(semieje_x, semieje_z) * clampf(_c_escala, 0.1, 1.5)
	var k: float = clampf(chispas, 0.0, 1.0) * clampf(_c_escala, 0.0, 1.0)
	_piedras.set("suelo_y", pos.y - altura_suelo)
	_acc_p += 9.0 * k * delta
	var tr: Transform3D = global_transform
	while _acc_p >= 1.0:
		_acc_p -= 1.0
		var loc: Vector3 = Vector3(randf_range(-0.5, 0.5) * r, randf_range(-0.5, 0.3) * r, r * randf_range(0.5, 1.2))
		_piedras.call("emitir", tr * loc, _vel_mundo * 0.25 + tr.basis * Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.8), 0.3), randf_range(0.7, 1.1), randf_range(0.04, 0.09) * sqrt(maxf(r / 0.4, 0.3)))
	if _polvo != null and is_instance_valid(_polvo):
		_acc += 7.0 * k * delta
		while _acc >= 1.0:
			_acc -= 1.0
			var loc2: Vector3 = Vector3(randf_range(-0.4, 0.4) * r, randf_range(-0.3, 0.3) * r, r * randf_range(0.8, 1.3))
			_polvo.call("emitir", tr * loc2, _vel_mundo * 0.15 + tr.basis * Vector3(randf_range(-0.4, 0.4), 0.2, 0.2), 0.8, 0.8)

