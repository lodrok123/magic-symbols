class_name MuroAgrietado3D
extends Area3D

## MURO AGRIETADO (bloque 2 de la revisión EoW, 23/10). Un bloque de piedra que tapa su casilla y se ROMPE: con `golpes` impactos de TIERRA
## (2 de serie) o de una vez con una EXPLOSIÓN (Barril3D: está en el grupo `explosionable`). Al romperse se deshace por celdas, suelta polvo
## y piedrecitas, libera la casilla y emite `roto`. Lo demás (fuego, agua, rayo…) no le hace nada y lo atraviesa el borde de luz
## (`spell_reacts` solo dice que sí a la tierra), pero la casilla es sólida: los proyectiles se paran en ella igual.
##
## EL ASPECTO lo da un shader propio (sin textura): sillares de piedra con juntas y GRIETAS de Voronoi en coordenadas del objeto. Ya nace con
## algunas (se lee como «esto se puede romper», como los muros agrietados de EoW, cuyo material `Crack` pinta la grieta por encima); cada
## golpe de tierra abre más y el muro tiembla. Al romperse, el mismo disolver por celdas del material común (Ocluso3D, V6).
##
## CON MODELO (la Cueva, 23/10): si existe la pieza `muro_agrietado` (el bloque de sillares de la lámina de Tripo), se usa ella con el
## material común (que sabe deshacerse por celdas) y las grietas van en una CAPA encima (`material_overlay`, `CODIGO_CAPA`). Sin el modelo,
## la caja con el shader de arriba, como antes.
##
## COLUMNA AGRIETADA (24/10, fase 3 del Pulso; PLAN_PULSO_RESONANTE §4, «la columna es el mismo código con otro modelo»). `como_columna(cae)` convierte la pieza en una COLUMNA: el modelo
## `columna_agrietada`, y en vez de la tierra la rompen los PULSOS (grupo `Pulso3D.GRUPO_PULSABLE`, `on_pulso`): cada pulso que la toca la agrieta más y al `golpes`-ésimo CAE, tumbándose
## hacia `cae` (n|e|s|o), levanta polvo, libera su casilla (abre un paso: la que tapa un nicho) y se deshace. Los hechizos no le hacen nada (la tierra tampoco).
##
## ROCA TÉRMICA (F14, 20/11, `; pieza <id> muro <x> <y> termica=si [calor=<s>]`): el mismo bloque pero que los golpes de tierra y las explosiones NO rompen. El fuego la pone al rojo `calor` s (8 por defecto; emisión rojo-naranja, nunca amarillo, y una luz cálida)
## y el agua (o el frío) mientras sigue caliente la parte de golpe, con vapor: choque térmico. Fría, el agua no le hace nada. Señales `calienta`, `se_enfria`, `roto`; condiciones `caliente`|`fria`; acción `calentar`.
##
## Se coloca desde un mapa con `; pieza <id> muro <x> <y> [golpes=<n>]` o `; pieza <id> columna <x> <y> [golpes=<n>] [cae=n|e|s|o]` (escenas/puzle.gd) o con `preparar` desde código.

signal roto
signal calienta                         ## la roca TÉRMICA se pone al rojo (un hechizo de fuego)
signal se_enfria                        ## … y se le pasa el calor sin que el agua la haya partido

const ALTO: float = 1.6
const GRIETAS_INICIO: float = 0.3       ## las que tiene sin tocar
const T_DESHACER: float = 0.7
const MODELO_MURO: String = "muro_agrietado"
const MODELO_COLUMNA: String = "columna_agrietada"
const T_CAER: float = 0.75              ## s que tarda la columna en tumbarse
const DIRS_CAIDA: Dictionary = {"n": Vector3(0.0, 0.0, -1.0), "e": Vector3(1.0, 0.0, 0.0), "s": Vector3(0.0, 0.0, 1.0), "o": Vector3(-1.0, 0.0, 0.0)}
const ESPERA_DESHACER: float = 0.6      ## s que la columna caída se queda en el suelo antes de deshacerse
const ALTO_COLUMNA: float = 2.5         ## u: lo que mide la columna en pie (Pieza3D.MEDIDA["columna_agrietada"]); base del estirado de la columna-puente
const SOLAPE_ORILLA: float = 0.35       ## u que la columna-puente se apoya sobre la orilla de enfrente
## ROCA TÉRMICA (F14, 20/11). Colores del calor: rojo y naranja, NUNCA amarillo (decisión de Pablo para el fuego).
const CALOR_DEFECTO: float = 8.0        ## s al rojo tras el fuego (el agua tiene ese margen; con más calor hace falta menos prisa)
const T_CALENTAR: float = 0.35          ## s que tarda en ponerse al rojo del todo
const FUNDIDO_CALOR_S: float = 2.0      ## s finales en que el rojo se apaga poco a poco
const COLOR_CALOR: Color = Color(1.0, 0.3, 0.06)
const HUNDIR_PUENTE: float = 0.1       ## u que se hunde la columna-puente tendida: poco, o el fuste (más fino que la base) queda por debajo de la superficie de la lava y solo asoma la base

const CODIGO: String = """
shader_type spatial;
uniform vec3 piedra : source_color = vec3(0.60, 0.57, 0.52);
uniform vec3 junta : source_color = vec3(0.33, 0.31, 0.28);
uniform vec3 fondo_grieta : source_color = vec3(0.12, 0.10, 0.09);
uniform vec4 brillo_grieta : source_color = vec4(1.0, 0.72, 0.4, 1.0);
uniform float grietas : hint_range(0.0, 1.0) = 0.3;
uniform float disolver : hint_range(0.0, 1.0) = 0.0;
uniform float alto = 1.6;
uniform float calor : hint_range(0.0, 1.0) = 0.0;
varying vec3 po;

float h31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
vec3 h33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}
// x = id de la celda, y = distancia al punto, z = distancia al borde.
vec3 voronoi(vec3 p) {
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				float d = length(g + h33(ip + g) - fp);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = h31(ip + g + 17.0);
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(id, d1, d2 - d1);
}

void vertex() {
	po = VERTEX;
}

void fragment() {
	// Deshacerse por celdas (como el disolver del decorado): lo alto se va antes; las que están a punto, brillan.
	vec3 vd = voronoi(po / 0.22);
	float altura = clamp(po.y / alto + 0.5, 0.0, 1.0);
	float vida = mix(vd.x, 1.0 - altura, 0.3);
	float resto = vida - disolver * 1.2;
	if (disolver > 0.0 && resto < 0.0) {
		discard;
	}
	// Sillares: hiladas de 0,4 m, cada una desplazada media pieza; juntas oscuras y algo de ruido de valor.
	float fila = floor((po.y + 10.0) / 0.4);
	vec2 q = vec2(po.x + po.z + fila * 0.33, po.y + 10.0) / vec2(0.66, 0.4);
	vec2 f = fract(q);
	float en_junta = 1.0 - smoothstep(0.0, 0.05, min(min(f.x, 1.0 - f.x) * 0.66, min(f.y, 1.0 - f.y) * 0.4));
	float matiz = h31(vec3(floor(q), fila)) * 0.12 - 0.06;
	vec3 c = piedra * (1.0 + matiz);
	c = mix(c, junta, en_junta * 0.8);
	// GRIETAS: bordes de Voronoi grandes; las celdas con id menor que `grietas` muestran su borde (más golpes, más celdas). Una segunda escala,
	// más fina, solo cuando ya está muy agrietado.
	vec3 vg = voronoi(po / 0.45 + vec3(3.1, 0.0, 7.3));
	float g1 = (1.0 - smoothstep(0.0, 0.06, vg.z)) * step(vg.x, grietas);
	vec3 vf = voronoi(po / 0.2 + vec3(11.0, 5.0, 2.0));
	float g2 = (1.0 - smoothstep(0.0, 0.05, vf.z)) * step(vf.x, max(grietas - 0.5, 0.0) * 1.5);
	float grieta = max(g1, g2 * 0.8);
	c = mix(c, fondo_grieta, grieta);
	c = mix(c, vec3(0.45, 0.07, 0.03), calor * 0.55);       // al rojo: la piedra se oscurece hacia rojo vivo (nunca amarillo)
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	// Dentro de la grieta, un fulgor terroso muy leve (la pista de que se rompe), y el borde de lo que se deshace.
	vec3 em = brillo_grieta.rgb * grieta * 0.35 * grietas;
	em += mix(vec3(0.85, 0.12, 0.03), vec3(1.0, 0.34, 0.05), grieta) * calor * (0.8 + 0.8 * grieta);
	if (disolver > 0.0) {
		em += brillo_grieta.rgb * (1.0 - smoothstep(0.0, 0.2, resto)) * 2.0;
	}
	EMISSION = em;
}
"""

## Las grietas sobre el MODELO: una capa encima (material_overlay) con los mismos bordes de Voronoi que la caja, oscuras y con un fulgor terroso.
const CODIGO_CAPA: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform float calor : hint_range(0.0, 1.0) = 0.0;
uniform float grietas : hint_range(0.0, 1.0) = 0.3;
uniform vec4 fondo_grieta : source_color = vec4(0.10, 0.08, 0.07, 1.0);
uniform vec4 brillo_grieta : source_color = vec4(1.0, 0.72, 0.4, 1.0);
varying vec3 po;

float h31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
vec3 h33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}
vec3 voronoi(vec3 p) {
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				float d = length(g + h33(ip + g) - fp);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = h31(ip + g + 17.0);
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(id, d1, d2 - d1);
}

void vertex() {
	po = VERTEX * length(MODEL_MATRIX[0].xyz);
}

void fragment() {
	vec3 vg = voronoi(po / 0.45 + vec3(3.1, 0.0, 7.3));
	float g1 = (1.0 - smoothstep(0.0, 0.06, vg.z)) * step(vg.x, grietas);
	vec3 vf = voronoi(po / 0.2 + vec3(11.0, 5.0, 2.0));
	float g2 = (1.0 - smoothstep(0.0, 0.05, vf.z)) * step(vf.x, max(grietas - 0.5, 0.0) * 1.5);
	float grieta = max(g1, g2 * 0.8);
	float pulso_calor = 0.88 + 0.12 * sin(TIME * 3.0 + po.y * 4.0);
	ALBEDO = mix(fondo_grieta.rgb, vec3(0.5, 0.06, 0.02), calor);
	EMISSION = brillo_grieta.rgb * grieta * 0.35 * grietas + mix(vec3(0.85, 0.12, 0.03), vec3(1.0, 0.34, 0.05), grieta) * calor * pulso_calor * (0.8 + 0.8 * grieta);
	ALPHA = max(grieta * 0.9, calor * 0.55);
}
"""

var celda: Vector2i = Vector2i.ZERO
var golpes: int = 2                     ## impactos de tierra que aguanta
var recibidos: int = 0
var roto_ya: bool = false
var grietas: float = GRIETAS_INICIO     ## las grietas que se ven ahora (0..1)
var _cuerpo: Node3D = null
var _mat: ShaderMaterial = null         ## la caja (sin modelo)
var _capa: ShaderMaterial = null        ## las grietas encima del modelo
var _mats_modelo: Array[ShaderMaterial] = []
var _mundo: Node = null
var modelo_id: String = MODELO_MURO     ## la pieza de `arte/piezas` que se dibuja
var por_pulso: bool = false             ## ¿la rompen los pulsos (columna) en vez de la tierra (muro)?
var cae: String = "s"                   ## columna: hacia dónde se tumba (n|e|s|o)
var pulsos_recibidos: int = 0           ## columna: pulsos que la han golpeado (las pruebas)
var cayendo: bool = false               ## columna: está tumbándose
var puente: Lava3D = null               ## columna-PUENTE (C3): la lava sobre la que se tumba; al caer cubre sus casillas para siempre (`Lava3D.tender_puente`)
var largo_puente: float = 0.0           ## columna-PUENTE: casillas que alcanza al caer (se estira mientras se tumba para llegar a la otra orilla)
var flag: String = ""                   ## columna: se acuerda de que cayó (la pone al caer; con ella ya puesta nace caída y, si es puente, ya tendida)
var cubiertas: Array[Vector2i] = []     ## columna-PUENTE: las casillas de lava que cubrió (las pruebas)
var termica: bool = false               ## ROCA TÉRMICA (F14, 20/11): los golpes y las explosiones no la rompen; el fuego la pone al rojo `calor_dura` s y el agua mientras sigue caliente la parte
var calor_dura: float = CALOR_DEFECTO   ## termica: s que se queda al rojo tras un hechizo de fuego (el siguiente fuego los renueva)
var calor_s: float = 0.0                ## termica: s que le quedan al rojo
var caliente: bool = false              ## termica: al rojo ahora (`calor_s` > 0); las reglas lo leen (`si=<id>.caliente`)
var calor_visual: float = 0.0           ## termica: 0 fría … 1 al rojo (lo que se pinta; sube en `T_CALENTAR` s y baja en los últimos `FUNDIDO_CALOR_S`)
var calentamientos: int = 0             ## termica: veces que el fuego la ha calentado (las pruebas)
var _luz_calor: OmniLight3D = null


## `mundo` = la maqueta (da el modelo con su escala de `Pieza3D.MEDIDA_ANCHO`); sin ella se carga `arte/piezas/muro_agrietado.tscn`.
func preparar(p_celda: Vector2i, p_golpes: int = 2, mundo: Node = null) -> void:
	_mundo = mundo
	celda = p_celda
	golpes = maxi(p_golpes, 1)
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))
	Terreno3D.bloquear_celda(celda)


## ROCA TÉRMICA (F14, 20/11): los golpes de tierra y las explosiones no la rompen. Un hechizo de FUEGO la pone al rojo `p_calor` s (rojo y naranja: emisión en el modelo y una luz cálida) y un hechizo de AGUA (o de frío) MIENTRAS sigue
## caliente la parte de golpe (`romper`: vapor, polvo, se deshace por celdas y libera su casilla). Fría, el agua no le hace nada; el fuego otra vez renueva el calor; pasado el tiempo se enfría sola (`se_enfria`). Se llama antes de añadirlo al árbol.
func como_termica(p_calor: float = CALOR_DEFECTO) -> void:
	termica = true
	calor_dura = maxf(p_calor, 0.5)


## Qué le hace este hechizo a la roca térmica: «calienta» (calor), «parte» (humedad o frío con la roca al rojo), «» (nada: agua en frío, tierra, viento…). Lo dicho por `Materia`, sin mirar nombres de elemento.
func _reaccion_termica(rune_data: RuneData, hechizo: Hechizo = null) -> String:
	if rune_data == null or roto_ya:
		return ""
	var m: Dictionary = Materia.de(hechizo if hechizo != null else rune_data)
	if Materia.calienta(m):
		return "calienta"
	if (Materia.moja(m) or Materia.enfria(m)) and caliente:
		return "parte"
	return ""


func _golpe_termico(rune_data: RuneData, hechizo: Hechizo = null) -> void:
	match _reaccion_termica(rune_data, hechizo):
		"calienta":
			calentar()
		"parte":
			romper()


## Pone al rojo la roca térmica `calor_dura` s (otra vez, si ya lo estaba). También es la acción `calentar` del mapa.
func calentar() -> void:
	if not termica or roto_ya:
		return
	var estaba: bool = caliente
	calor_s = calor_dura
	caliente = true
	calentamientos += 1
	if not estaba:
		if is_inside_tree():
			Sfx.play(self, "fuego_carga")
		calienta.emit()


## Cada fotograma de la roca térmica: cuenta el calor y lleva el rojo (`calor_visual`) hacia lo que toca (sube en T_CALENTAR s; en los últimos FUNDIDO_CALOR_S s baja poco a poco).
func _process(delta: float) -> void:
	if not termica or roto_ya:
		return
	if caliente:
		calor_s = maxf(calor_s - delta, 0.0)
		if calor_s <= 0.0:
			caliente = false
			se_enfria.emit()
	var objetivo: float = clampf(calor_s / FUNDIDO_CALOR_S, 0.0, 1.0) if caliente else 0.0
	var paso: float = delta / T_CALENTAR if objetivo > calor_visual else delta / FUNDIDO_CALOR_S
	calor_visual = move_toward(calor_visual, objetivo, paso)
	_poner_calor_visual(calor_visual)


func _poner_calor_visual(v: float) -> void:
	if _capa != null:
		_capa.set_shader_parameter("calor", v)
	if _mat != null:
		_mat.set_shader_parameter("calor", v)
	if _luz_calor != null:
		_luz_calor.light_energy = 1.4 * v


## Una luz cálida (rojo-naranja) junto a la roca, apagada hasta que se calienta.
func _poner_luz_calor() -> void:
	_luz_calor = OmniLight3D.new()
	_luz_calor.name = "LuzCalor"
	_luz_calor.light_color = COLOR_CALOR
	_luz_calor.light_energy = 0.0
	_luz_calor.omni_range = Terreno3D.casilla * 2.2
	_luz_calor.shadow_enabled = false
	_luz_calor.position = Vector3(0.0, ALTO * 0.55, Terreno3D.casilla * 0.6)
	add_child(_luz_calor)


## Lo convierte en una COLUMNA que rompen los pulsos (ver arriba). Se llama antes de añadirlo al árbol.
func como_columna(p_cae: String = "s") -> void:
	modelo_id = MODELO_COLUMNA
	por_pulso = true
	cae = p_cae if DIRS_CAIDA.has(p_cae) else "s"


## 26/10 (C3, Pablo: «la lava sigue y una columna hace de puente»): la columna, al caer hacia `cae`, se estira hasta `p_largo` casillas y CUBRE para siempre las casillas de `p_lava` que
## quedan bajo ella (`Lava3D.tender_puente`): se pisan y conducen el pulso. Con `p_flag` se acuerda de que cayó (nace ya tendida). Se llama antes de añadirlo al árbol.
func como_puente(p_lava: Lava3D, p_largo: float, p_flag: String = "") -> void:
	puente = p_lava
	largo_puente = maxf(p_largo, 1.0)
	flag = p_flag


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	if por_pulso:
		add_to_group(Pulso3D.GRUPO_PULSABLE)
		add_to_group("explosionable")        # 26/10: la geoda explosiva (GeodaPulso3D) también la tumba
	elif not termica:
		add_to_group("explosionable")             # la roca térmica NO: ni una explosión la rompe (solo el choque de calor y frío)
	if por_pulso and flag != "" and Flags.i().tiene(flag):
		_nacer_caida.call_deferred()
	set_process(termica)                        # solo la roca térmica necesita _process (cuenta su calor)
	if termica:
		_poner_luz_calor()
	var ancho: float = Terreno3D.casilla * 0.96
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ancho, ALTO, ancho)
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO * 0.5, 0.0)
	add_child(forma)
	if _poner_modelo():
		return
	var sh := Shader.new()
	sh.code = CODIGO
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("alto", ALTO)
	_mat.set_shader_parameter("grietas", GRIETAS_INICIO)
	_cuerpo = MeshInstance3D.new()
	_cuerpo.name = "muro"
	var b := BoxMesh.new()
	b.size = Vector3(ancho, ALTO, ancho)
	_cuerpo.mesh = b
	_cuerpo.material_override = _mat
	_cuerpo.position = Vector3(0.0, ALTO * 0.5, 0.0)
	add_child(_cuerpo)


## El modelo de sillares con el material común y la capa de grietas. false si no hay modelo.
func _poner_modelo() -> bool:
	var n: Node3D = null
	if _mundo != null and is_instance_valid(_mundo) and _mundo.has_method("_pieza"):
		n = _mundo.call("_pieza", modelo_id) as Node3D
	if n == null and ResourceLoader.exists("res://arte/piezas/%s.tscn" % modelo_id):
		var escena: PackedScene = load("res://arte/piezas/%s.tscn" % modelo_id) as PackedScene
		n = escena.instantiate() as Node3D if escena != null else null
	if n == null:
		return false
	n.name = "muro"
	add_child(n)
	_cuerpo = n
	_mats_modelo = Ocluso3D.convertir_nodo(n)
	var sh := Shader.new()
	sh.code = CODIGO_CAPA
	_capa = ShaderMaterial.new()
	_capa.shader = sh
	_capa.set_shader_parameter("grietas", grietas)
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_overlay = _capa
	return true


func _poner_grietas(v: float) -> void:
	grietas = v
	if _capa != null:
		_capa.set_shader_parameter("grietas", v)
	if _mat != null:
		_mat.set_shader_parameter("grietas", v)


func _poner_disolver(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("disolver", v)
	for m in _mats_modelo:
		Ocluso3D.poner_disolver(m, v)
	if _mats_modelo.is_empty() and _mat == null and _cuerpo != null:
		_cuerpo.scale = Vector3.ONE * maxf(1.0 - v, 0.01)        # sin material común (Ocluso sin preparar): se encoge


## --- Contrato con los hechizos ---

## 28/10 · A2 (previsión): qué le haría este hechizo AHORA, sin tocarlo: «rompe» (el golpe que falta), «agrieta» (otro golpe de tierra, pero aún no cae) o «» (no le toca). `on_spell_hit` aplica esto.
func reaccion_a(rune_data: RuneData, hechizo: Hechizo = null) -> String:
	if termica or por_pulso or rune_data == null or roto_ya or not Materia.golpea(Materia.de(hechizo if hechizo != null else rune_data)):
		return ""
	return "rompe" if recibidos + 1 >= golpes else "agrieta"


func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> void:
	if termica:
		_golpe_termico(rune_data, hechizo)
		return
	if reaccion_a(rune_data, hechizo) == "":
		return
	recibidos += 1
	if recibidos >= golpes:
		romper()
		return
	_agrietar(float(recibidos) / float(golpes))


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo: Hechizo = null) -> bool:
	if termica:
		return rune_data != null and not roto_ya and _reaccion_termica(rune_data, hechizo) != ""
	return not por_pulso and rune_data != null and not roto_ya and Materia.golpea(Materia.de(hechizo if hechizo != null else rune_data))


## Contrato con el pulso (solo la columna): cada frente que la toca la agrieta más; al `golpes`-ésimo cae. Devuelve true si la hizo caer.
func on_pulso(pulso: Pulso3D) -> bool:
	# 27/10: la columna-PUENTE solo la tumba una explosión (geoda): los pulsos que la tocan no la agrietan ni hacen ruido (antes sonaba y temblaba con cada latido)
	if not por_pulso or roto_ya or pulso == null or puente != null:
		return false
	pulsos_recibidos += 1
	recibidos += 1
	if recibidos >= golpes:
		romper()
		return true
	_agrietar(float(recibidos) / float(golpes))
	return false


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


## Barril3D: una explosión al alcance lo rompe de una vez.
func recibir_explosion(_punto: Vector3) -> void:
	if termica:
		return                                  # la roca térmica no se rompe con golpes ni explosiones: solo con el choque de calor y frío
	romper()


## --- Romperse ---

func romper() -> void:
	if roto_ya:
		return
	roto_ya = true
	collision_layer = 0                     # el nodo se queda (los puzles lo consultan), pero ya no se golpea
	remove_from_group("explosionable")
	Terreno3D.liberar_celda(celda)
	if por_pulso and _cuerpo != null:
		_caer()
		roto.emit()
		return
	Sfx.play(self, "derrumbe")
	if get_parent() is Node3D:
		VfxPuzle3D.polvo(get_parent() as Node3D, global_position + Vector3(0.0, 0.1, 0.0), 1.1)
		if termica:
			VfxPuzle3D.vapor(get_parent() as Node3D, global_position + Vector3(0.0, 0.8, 0.0), 1.8)      # el choque térmico: la piedra caliente suelta vapor al partirse
	_poner_grietas(1.0)
	if _cuerpo != null and _capa != null:
		for g in _cuerpo.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).material_overlay = null      # la capa no se deshace con las celdas: fuera
	var tw: Tween = create_tween()
	tw.tween_method(_poner_disolver, 0.0, 1.0, T_DESHACER).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _cuerpo.visible = false)
	roto.emit()


## La columna se TUMBA hacia `cae` (gira sobre su base, acelerando), al llegar al suelo suena el derrumbe y sube el polvo, y un rato después se deshace por celdas.
func _caer() -> void:
	cayendo = true
	_poner_grietas(1.0)
	if flag != "" and not Flags.i().tiene(flag):
		Flags.i().poner(flag)
	var dir: Vector3 = DIRS_CAIDA[cae]
	var eje: Vector3 = Vector3.UP.cross(dir)
	var base: Basis = _cuerpo.basis
	var k: float = _estirado()
	var tw: Tween = create_tween()
	tw.tween_method(func(a: float) -> void: _cuerpo.basis = Basis(eje, a) * base * Basis.from_scale(Vector3(1.0, lerpf(1.0, k, a / (PI * 0.5)), 1.0)), 0.0, PI * 0.5, T_CAER).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_aterrizar)
	if puente != null:
		return                              # la columna-puente se queda tendida: no se deshace
	tw.tween_interval(ESPERA_DESHACER)
	if _capa != null:
		tw.tween_callback(func() -> void:
			for g in _cuerpo.find_children("*", "GeometryInstance3D", true, false):
				(g as GeometryInstance3D).material_overlay = null)      # la capa no se deshace con las celdas
	tw.tween_method(_poner_disolver, 0.0, 1.0, T_DESHACER).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _cuerpo.visible = false)


func _aterrizar() -> void:
	cayendo = false
	Sfx.play(self, "derrumbe")
	if get_parent() is Node3D:
		var donde: Vector3 = global_position + DIRS_CAIDA[cae] * (Terreno3D.casilla * 0.9) + Vector3(0.0, 0.1, 0.0)
		VfxPuzle3D.polvo(get_parent() as Node3D, donde, 1.4)
	if puente != null:
		_tender()
		var tw: Tween = create_tween()
		tw.tween_property(_cuerpo, "position:y", _cuerpo.position.y - HUNDIR_PUENTE, 0.25)      # se hunde en la roca: el viga queda a ras, no un muro por el que se atraviesa


## Factor en que se estira la columna-puente a lo largo de su eje para llegar de su casilla a la orilla de enfrente (1 si no es puente): hasta el borde lejano de la última casilla
## de lava más `SOLAPE_ORILLA` u sobre la orilla.
func _estirado() -> float:
	if puente == null:
		return 1.0
	return ((largo_puente + 0.5) * Terreno3D.casilla + SOLAPE_ORILLA) / ALTO_COLUMNA


## Cubre de lava (puente permanente) las `largo_puente` casillas que quedan bajo la columna caída, hacia `cae`.
func _tender() -> void:
	var d: Vector3 = DIRS_CAIDA[cae]
	var paso := Vector2i(int(d.x), int(d.z))
	cubiertas.clear()
	for i in range(1, int(ceil(largo_puente)) + 1):
		var c: Vector2i = celda + paso * i
		if puente.tender_puente(c):
			cubiertas.append(c)


## Con la flag de la caída ya puesta (se volvió al nivel): nace ya caída. Un puente nace ya tendido; una columna normal ya se deshizo, así que no se ve.
func _nacer_caida() -> void:
	if roto_ya or _cuerpo == null:
		return
	roto_ya = true
	collision_layer = 0
	remove_from_group("explosionable")
	remove_from_group(Pulso3D.GRUPO_PULSABLE)
	Terreno3D.liberar_celda(celda)
	if puente == null:
		_cuerpo.visible = false
		return
	var dir: Vector3 = DIRS_CAIDA[cae]
	_poner_grietas(1.0)
	_cuerpo.basis = Basis(Vector3.UP.cross(dir), PI * 0.5) * _cuerpo.basis * Basis.from_scale(Vector3(1.0, _estirado(), 1.0))
	_cuerpo.position.y -= HUNDIR_PUENTE
	_tender()


## Abre más grietas (`fraccion` 0..1 de los golpes que lleva) y tiembla un instante.
func _agrietar(fraccion: float) -> void:
	_poner_grietas(lerpf(GRIETAS_INICIO, 0.85, fraccion))
	Sfx.play(self, "tierra")
	if get_parent() is Node3D:
		VfxPuzle3D.polvo(get_parent() as Node3D, global_position + Vector3(0.0, 0.1, 0.0), 0.5)
	var base: Vector3 = _cuerpo.position
	var tw: Tween = create_tween()
	for i in range(4):
		tw.tween_property(_cuerpo, "position", base + Vector3(randf_range(-0.04, 0.04), 0.0, randf_range(-0.04, 0.04)), 0.04)
	tw.tween_property(_cuerpo, "position", base, 0.04)
