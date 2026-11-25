class_name AvisoAtaque3D
extends Node3D

## C3 · ATAQUES AVISADOS (docs/PROPUESTA_COMBATE.md §2 y §7; 28/10). Dueño: Juego.
##
## La zona roja en el suelo que un enemigo marca ANTES de su golpe, como los avisos de un MOBA: el borde se ve entero desde el principio y el relleno crece desde el centro
## (o desde el enemigo, en el rectángulo) hasta llenarla justo en el instante del impacto. En los últimos `VENTANA_ESQUIVA` s el borde se pone blanco y late: es la ventana
## de la esquiva con premio (C4, `TiempoBruja`).
##
## Lo crea quien ataca (`Combate3D._avisar_ataque`, `Limo3D`) con la MISMA forma y el mismo centro con que luego comprueba el daño, y el mismo tiempo hasta el golpe; así
## «lo que se ve es lo que pega». Formas:
##   · `circulo(mundo, centro, radio, t_impacto, dueno)`            el guerrero (alrededor de él), la flecha (donde va a caer), el limo (donde va a aterrizar)
##   · `rectangulo(mundo, origen, dir, largo, ancho, t_impacto, dueno)`   el puñetazo del elemental (desde él hacia delante; `ancho` = la mitad a cada lado)
## `seguir(nodo)`: el centro va con ese nodo hasta `fijar(punto, t_restante)` (la flecha: apunta a la jugadora mientras tensa y se queda donde la suelta).
## El reloj es el del juego (delta con `Engine.time_scale`): en cámara lenta el aviso también va lento.
## Se borra solo al llegar el impacto (con un destello corto) o con `cancelar()` (el enemigo interrumpido, congelado, empujado…).
## Todos los vivos están en el grupo GRUPO: `esquiva_a_tiempo(p)` (C4) los recorre.
##
## LÍNEA DE MIRA (21/11/2026, Pablo: «quiero que las flechas sean visibles»; el patrón de los arqueros de Phantom Blade Zero y Soulstice): `linea(mundo, origen, destino, t_suelta, dueno, lanzador)`.
## Una banda fina a ras de suelo desde el arco (o la ranura del mascarón) hasta DONDE SE PARARÁ LA FLECHA: el primer muro, bloque o barrera de su camino (`fin_de_vuelo`, la misma comprobación que usa el
## vuelo: `Lanzador3D.celda_solida`, `solidez_contiene`, `burbuja_contiene`) o el destino. `t_suelta` = s hasta que sale la flecha.
##   · APUNTADO (hasta `fijado_s` antes de soltar): tenue (rayas que corren hacia el destino), fina, y SIGUE el apuntado real (`apuntar(f_origen, f_destino)`).
##   · FIJADO (los últimos T_FIJADO = 0,4 s): deja de seguir, se ensancha, se avisa de un borde claro y se pone casi opaca, con un halo del ancho de lo que de verdad hiere: «ya puedes apartarte a un lado».
##     En ese instante emite `fijado(punto)`: quien dispara DEBE soltar la flecha hacia ese punto (no hacia donde esté la jugadora entonces) o la línea mentiría.
##   · Al soltar: `apagar()` (se apaga en T_APAGA s). No está en GRUPO: NO da premio de esquiva (el círculo del destino del arquero ya lo da; contarlo dos veces regalaría el doble). Grupo GRUPO_LINEAS.

const GRUPO: String = "aviso_ataque3d"
const GRUPO_LINEAS: String = "aviso_linea3d"
const T_FIJADO: float = 0.4                  ## s antes de soltar en que la línea deja de seguir y se avisa
const T_APAGA: float = 0.15                  ## s que tarda en apagarse al soltar
const LINEA_ANCHO_APUNTE: float = 0.09       ## u de ancho total del hilo mientras apunta
const LINEA_ANCHO_FIJO: float = 0.3          ## u de ancho total del hilo ya fijado
const LINEA_ALFA_APUNTE: float = 0.55
const LINEA_ALFA_FIJO: float = 1.0
const LINEA_HALO_DEFECTO: float = 0.45       ## u: mitad del ancho del halo de peligro (la zona que de verdad hiere)
const LINEA_PASO: float = 0.2                ## u entre comprobaciones de `fin_de_vuelo`
const T_FIJAR_RAMPA: float = 0.1             ## s que tarda en pasar de hilo a banda
const COLOR_LINEA_BORDE: Color = Color(1.0, 0.8, 0.72)
const T_MIN: float = 0.4                     ## s mínimos entre que sale el aviso y el golpe (el contrato de C3: si el ataque es más rápido, lo alarga quien ataca)
const VENTANA_ESQUIVA: float = 0.6           ## s antes del impacto en que rodar da premio (C4). Era 0,25 (la propuesta decía «~0,2 s»); 29/10: en el playtest de Pablo las volteretas de reacción caían a 0,45–0,66 s del golpe y ninguna daba premio
const T_DESTELLO: float = 0.12               ## s que se ve el destello del impacto antes de borrarse
const ALTO_SUELO: float = 0.06               ## u sobre los pies, para no pelearse con el suelo
const COLOR: Color = Color(1.0, 0.22, 0.16)
const COLOR_VENTANA: Color = Color(1.0, 0.95, 0.85)

const CODIGO: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.22, 0.16, 1.0);
uniform vec4 color_borde : source_color = vec4(1.0, 0.22, 0.16, 1.0);
uniform float progreso = 0.0;      // 0 al salir ... 1 en el impacto
uniform float circulo = 1.0;       // 1 círculo (UV centrado) · 0 rectángulo (relleno desde v = 0, el lado del enemigo)
uniform float borde = 0.08;        // grosor del borde en UV (0..0.5)
uniform float destello = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float dentro;
	float b;
	float lleno;
	if (circulo > 0.5) {
		float r = length(q);
		dentro = step(r, 1.0);
		b = smoothstep(1.0 - borde * 2.0 - 0.02, 1.0 - borde * 2.0, r);
		lleno = step(r, progreso);
	} else {
		float m = max(abs(q.x), abs(q.y));
		dentro = 1.0;
		b = smoothstep(1.0 - borde * 2.0 - 0.02, 1.0 - borde * 2.0, m);
		lleno = step(UV.y, progreso);
	}
	float a = dentro * max(b * 0.95, 0.16 + lleno * 0.34);
	vec3 c = mix(color.rgb, color_borde.rgb, b);
	c = mix(c, vec3(1.0), destello);
	ALBEDO = c;
	ALPHA = a * color.a * (1.0 - destello * 0.3);
}
"""

## La banda de la línea de mira. UV.x = u recorridas desde el origen, UV.y = 0..1 a lo ancho. Rayas que corren hacia el destino al apuntar; continua al fijar.
const CODIGO_LINEA: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.22, 0.16, 1.0);
uniform vec4 color_borde : source_color = vec4(1.0, 0.8, 0.72, 1.0);
uniform float mitad_geo = 0.45;      // mitad del ancho de la malla (u)
uniform float mitad_nucleo = 0.035;  // mitad del ancho del hilo (u)
uniform float mitad_halo = 0.45;     // mitad del ancho del halo de peligro (u)
uniform float fijo = 0.0;            // 0 apuntando ... 1 fijada
uniform float alfa = 0.4;
uniform float fase = 0.0;
uniform float largo = 1.0;
uniform float vida = 1.0;
void fragment() {
	float x = abs(UV.y * 2.0 - 1.0) * mitad_geo;
	float nucleo = 1.0 - smoothstep(mitad_nucleo * 0.6, mitad_nucleo, x);
	float halo = (1.0 - smoothstep(mitad_halo * 0.7, mitad_halo, x)) * 0.13 * fijo;
	float borde = smoothstep(mitad_nucleo * 0.4, mitad_nucleo * 0.9, x) * nucleo;
	float along = UV.x;
	float flujo = fract(along / 0.8 - fase);
	float raya = smoothstep(0.0, 0.12, flujo) * (1.0 - smoothstep(0.5, 0.62, flujo));
	float trazo = mix(raya, 1.0, fijo * 0.85);
	float salida = smoothstep(0.0, 0.6, along);
	float meta = smoothstep(largo - 0.5, largo, along);
	float a = max(nucleo * max(trazo, meta) * alfa, halo) * salida;
	ALBEDO = mix(color.rgb, color_borde.rgb, borde * fijo * 0.6);
	ALPHA = a * vida;
}
"""

static var _shader: Shader = null
static var _shader_linea: Shader = null

signal fijado(punto: Vector3)                ## la línea pasó a FIJADA: el punto al que apunta (el de la flecha; no recortado por muros)

var dueno: Node = null
var forma: String = "circulo"
var radio: float = 1.0                       ## círculo: radio (u)
var largo: float = 1.0                       ## rectángulo: hasta dónde llega por delante del origen (u)
var ancho: float = 0.5                       ## rectángulo: la mitad del ancho (u)
var atras: float = 0.0                       ## rectángulo: lo que cubre por detrás del origen (u)
var dir: Vector3 = Vector3(0, 0, 1)
var centro: Vector3 = Vector3.ZERO           ## círculo: su centro; rectángulo: el origen (los pies del enemigo)
var t_impacto: float = 0.0                   ## s de juego desde que salió hasta el golpe
var t: float = 0.0
var cancelado: bool = false
## A5 de PLAN_COMBATE (22/11, Pablo: «Sí, a 0,25 s»): la ventana de esquiva perfecta de ESTE aviso. Los ataques lentos (gólem, elemental, aliento, flechas) se quedan en
## VENTANA_ESQUIVA (0,6); el golpe seco del cuerpo a cuerpo usa VENTANA_CUERPO (0,25), que su aviso ya es corto (0,67 s) y con 0,6 parpadeaba en blanco casi entero.
const VENTANA_CUERPO: float = 0.25
var ventana: float = VENTANA_ESQUIVA
var parpadeo: float = 0.0                   ## A2 de PLAN_COMBATE (22/11, Pablo: «rectángulo parpadeante rojo» para el dragón): > 0 = la zona parpadea tantas veces por segundo; 0 = como siempre
const ALFA_PARPADEO_BAJO: float = 0.4        ## alfa de la zona en la mitad apagada del parpadeo
var esquivado: bool = false                  ## ya dio su premio de esquiva (una vez por aviso)
var _sigue: Node3D = null
var _malla: MeshInstance3D = null
var _mat: ShaderMaterial = null
# --- línea de mira ---
var punto_apuntado: Vector3 = Vector3.ZERO   ## línea: adonde apunta (sin recortar por muros); `centro` es el origen
var fin: Vector3 = Vector3.ZERO              ## línea: donde se parará la flecha (recortado por muros, bloques y barreras)
var fijada: bool = false                     ## línea: ya no sigue el apuntado
var fijado_s: float = T_FIJADO
var halo: float = LINEA_HALO_DEFECTO         ## línea: mitad del ancho de la zona que hiere
var color_linea: Color = COLOR
var apagando: bool = false
var t_fijada: float = 0.0                    ## línea: s desde que se fijó
var _t_apaga: float = 0.0
var _lanz_linea: Lanzador3D = null
var _f_origen: Callable = Callable()
var _f_destino: Callable = Callable()
var _ult_origen: Vector3 = Vector3(INF, INF, INF)
var _ult_fin: Vector3 = Vector3(INF, INF, INF)


static func circulo(en: Node, p_centro: Vector3, p_radio: float, p_t: float, p_dueno: Node = null) -> AvisoAtaque3D:
	var a := AvisoAtaque3D.new()
	a.forma = "circulo"
	a.centro = p_centro
	a.radio = p_radio
	a.t_impacto = maxf(p_t, 0.01)
	a.dueno = p_dueno
	a._colgar(en)
	return a


static func rectangulo(en: Node, origen: Vector3, p_dir: Vector3, p_largo: float, p_ancho: float, p_t: float, p_dueno: Node = null, p_atras: float = 0.3) -> AvisoAtaque3D:
	var a := AvisoAtaque3D.new()
	a.forma = "rect"
	a.centro = origen
	var d := Vector3(p_dir.x, 0.0, p_dir.z)
	a.dir = d.normalized() if d.length() > 0.001 else Vector3(0, 0, 1)
	a.largo = p_largo
	a.ancho = p_ancho
	a.atras = p_atras
	a.t_impacto = maxf(p_t, 0.01)
	a.dueno = p_dueno
	a._colgar(en)
	return a


## LÍNEA DE MIRA de una flecha (ver la cabecera). `origen` y `destino` son puntos del mundo a la altura del vuelo (la línea se dibuja en el suelo, bajo ellos); `t_suelta` s hasta que sale la flecha.
## Devuelve null si `Combate3D.AVISAR_ATAQUES` está apagado (así que quien llama no tiene que mirarlo). `p_lanz` (opcional) pone las barreras y la burbuja de la jugadora entre lo que para la flecha.
static func linea(en: Node, origen: Vector3, destino: Vector3, t_suelta: float, p_dueno: Node = null, p_lanz: Lanzador3D = null, p_color: Color = COLOR, p_halo: float = LINEA_HALO_DEFECTO, p_fijado: float = T_FIJADO) -> AvisoAtaque3D:
	if not Combate3D.AVISAR_ATAQUES:
		return null
	var a := AvisoAtaque3D.new()
	a.forma = "linea"
	a.centro = origen
	a.punto_apuntado = destino
	a.t_impacto = maxf(t_suelta, 0.01)
	a.fijado_s = minf(p_fijado, a.t_impacto * 0.7)
	a.halo = p_halo
	a.color_linea = p_color
	a._lanz_linea = p_lanz
	a.dueno = p_dueno
	a.fin = fin_de_vuelo(origen, destino, p_lanz)
	a.add_to_group(GRUPO_LINEAS)
	if en != null:
		en.add_child(a)
	a._construir_linea()
	a._pintar_linea()
	return a


## Hasta dónde llega una flecha que sale de `origen` hacia `destino` en línea recta: el último punto libre antes de un muro/bloque/árbol (casilla sólida a ras de suelo), un volumen con solidez
## (barrera) o la burbuja de la jugadora; si nada la corta, `destino`. Es la comprobación que hacen `FlechaTrampa3D` y los vuelos, sin los efectos.
static func fin_de_vuelo(origen: Vector3, destino: Vector3, p_lanz: Lanzador3D = null) -> Vector3:
	var d: Vector3 = destino - origen
	var dh: float = Vector2(d.x, d.z).length()
	if dh < 0.01:
		return destino
	var n: int = ceili(dh / LINEA_PASO)
	var previo: Vector3 = origen
	for i in range(1, n + 1):
		var p: Vector3 = origen + d * (float(i) / float(n))
		if Terreno3D.celda_solida(Terreno3D.celda_de(p), 0):
			return previo
		if p_lanz != null and is_instance_valid(p_lanz) and (p_lanz.solidez_contiene(p) or p_lanz.burbuja_contiene(p)):
			return previo
		previo = p
	return destino


## ¿Hay algún aviso vivo que cubre `p` y al que le quedan `ventana` s o menos para el golpe? Si lo hay, lo marca como esquivado (da premio una vez) y lo devuelve; si no, null.
## `p_ventana` < 0 (el defecto) = la de cada aviso (`ventana`, A5); si se da, manda sobre todas.
static func esquiva_a_tiempo(arbol: SceneTree, p: Vector3, p_ventana: float = -1.0) -> AvisoAtaque3D:
	if arbol == null:
		return null
	for n in arbol.get_nodes_in_group(GRUPO):
		var a: AvisoAtaque3D = n as AvisoAtaque3D
		if a == null or not is_instance_valid(a) or a.cancelado or a.esquivado or a.t >= a.t_impacto:
			continue
		if a.queda() <= (p_ventana if p_ventana >= 0.0 else a.ventana) and a.contiene(p):
			a.esquivado = true
			return a
	return null


func _colgar(en: Node) -> void:
	add_to_group(GRUPO)
	if en != null:
		en.add_child(self)
	_construir()
	_colocar()
	if Sensacion3D.ACTIVA and is_inside_tree():
		Sfx.play(self, "aviso_ataque")             # gamefeel (28/10): el aviso también se oye


func _construir() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODIGO
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.render_priority = 2
	_mat.set_shader_parameter("color", COLOR)
	_mat.set_shader_parameter("color_borde", COLOR)
	_mat.set_shader_parameter("circulo", 1.0 if forma == "circulo" else 0.0)
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	_malla = MeshInstance3D.new()
	_malla.mesh = pm
	_malla.material_override = _mat
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_malla)


func _construir_linea() -> void:
	if _shader_linea == null:
		_shader_linea = Shader.new()
		_shader_linea.code = CODIGO_LINEA
	_mat = ShaderMaterial.new()
	_mat.shader = _shader_linea
	_mat.render_priority = 1                     # por debajo del círculo del destino
	_malla = MeshInstance3D.new()
	_malla.top_level = true                      # los vértices van en coordenadas del mundo
	_malla.material_override = _mat
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_malla.extra_cull_margin = 40.0
	add_child(_malla)


## Hilo que sigue el apuntado: `f_origen() -> Vector3` y `f_destino() -> Vector3` se evalúan cada fotograma HASTA que se fija.
func apuntar(f_origen: Callable, f_destino: Callable) -> void:
	_f_origen = f_origen
	_f_destino = f_destino


## Anchura (mitad, u) del hilo ahora: de fino a banda en T_FIJAR_RAMPA s desde que se fija.
func _k_fijo() -> float:
	return clampf(t_fijada / T_FIJAR_RAMPA, 0.0, 1.0) if fijada else 0.0


func mitad_nucleo() -> float:
	return lerpf(LINEA_ANCHO_APUNTE, LINEA_ANCHO_FIJO, _k_fijo()) * 0.5


## Reconstruye la cinta (vértices en el mundo, a ras del suelo de cada tramo) y pone los parámetros del shader.
func _pintar_linea() -> void:
	if _malla == null:
		return
	var k: float = _k_fijo()
	var mitad_geo: float = maxf(halo, LINEA_ANCHO_FIJO * 0.5)
	_mat.set_shader_parameter("color", color_linea)
	_mat.set_shader_parameter("color_borde", COLOR_LINEA_BORDE)
	_mat.set_shader_parameter("mitad_geo", mitad_geo)
	_mat.set_shader_parameter("mitad_nucleo", mitad_nucleo())
	_mat.set_shader_parameter("mitad_halo", halo)
	_mat.set_shader_parameter("fijo", k)
	_mat.set_shader_parameter("alfa", lerpf(LINEA_ALFA_APUNTE, LINEA_ALFA_FIJO, k))
	_mat.set_shader_parameter("fase", t * 1.6)
	var d := Vector3(fin.x - centro.x, 0.0, fin.z - centro.z)
	var largo_l: float = d.length()
	_mat.set_shader_parameter("largo", largo_l)
	_mat.set_shader_parameter("vida", 1.0 - clampf(_t_apaga / T_APAGA, 0.0, 1.0) if apagando else 1.0)
	if centro.distance_squared_to(_ult_origen) < 0.0001 and fin.distance_squared_to(_ult_fin) < 0.0001:
		return
	_ult_origen = centro
	_ult_fin = fin
	if largo_l < 0.05:
		_malla.mesh = null
		return
	var u: Vector3 = d / largo_l
	var perp := Vector3(-u.z, 0.0, u.x) * mitad_geo
	var n: int = maxi(1, ceili(largo_l / 0.5))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(n + 1):
		var kk: float = float(i) / float(n)
		var p: Vector3 = centro.lerp(fin, kk)
		var y: float = p.y
		var c: Vector2i = Terreno3D.celda_de(p)
		if Terreno3D.en_mapa(c):
			y = Terreno3D.y_pies(c)
		p.y = y + ALTO_SUELO * 0.9
		st.set_uv(Vector2(kk * largo_l, 0.0))
		st.add_vertex(p + perp)
		st.set_uv(Vector2(kk * largo_l, 1.0))
		st.add_vertex(p - perp)
	for i in range(n):
		var a: int = i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	_malla.mesh = st.commit()


func _proceso_linea(delta: float) -> void:
	if apagando:
		_t_apaga += delta
		if _t_apaga >= T_APAGA:
			queue_free()
			return
	elif t >= t_impacto + 0.25:
		apagar()                                     # nadie la apagó al soltar: no se queda colgada
	if not fijada:
		if _f_origen.is_valid():
			centro = _f_origen.call()
		if _f_destino.is_valid():
			punto_apuntado = _f_destino.call()
		if queda() <= fijado_s:
			fijada = true
			t_fijada = 0.0
	else:
		t_fijada += delta
	fin = fin_de_vuelo(centro, punto_apuntado, _lanz_linea)
	_pintar_linea()
	if fijada and t_fijada == 0.0:
		fijado.emit(punto_apuntado)
		t_fijada = 0.0001


## Se apaga rápido (la flecha ya salió o el ataque se cortó). Idempotente. No da premio ni aviso: es solo dibujo.
func apagar() -> void:
	if forma != "linea":
		cancelar()
		return
	if apagando:
		return
	apagando = true
	_t_apaga = 0.0
	remove_from_group(GRUPO_LINEAS)


## Pone la malla en su sitio y con su tamaño (cada fotograma si sigue a alguien).
func _colocar() -> void:
	if _malla == null:
		return
	if forma == "circulo":
		_malla.scale = Vector3(radio * 2.0, 1.0, radio * 2.0)
		_malla.rotation = Vector3.ZERO
		_poner_en(centro)
		_mat.set_shader_parameter("borde", clampf(0.06 / maxf(radio, 0.1), 0.02, 0.2))
	else:
		var total: float = largo + atras
		var medio: Vector3 = centro + dir * (largo - atras) * 0.5
		_poner_en(medio)
		# La malla mira con su +Z (la v del UV crece hacia +Z) al revés de `dir`: v = 0 queda del lado del enemigo y el relleno crece hacia delante.
		_malla.rotation = Vector3(0.0, atan2(-dir.x, -dir.z), 0.0)
		_malla.scale = Vector3(ancho * 2.0, 1.0, total)
		_mat.set_shader_parameter("borde", clampf(0.06 / maxf(minf(ancho, total * 0.5), 0.1), 0.02, 0.2))


func _poner_en(p: Vector3) -> void:
	var y: float = p.y
	var c: Vector2i = Terreno3D.celda_de(p)
	if Terreno3D.en_mapa(c):
		y = Terreno3D.y_pies(c)
	var q := Vector3(p.x, y + ALTO_SUELO, p.z)
	if is_inside_tree():
		global_position = q
	else:
		position = q


## El centro va con `nodo` (sus pies) hasta `fijar`.
func seguir(nodo: Node3D) -> void:
	_sigue = nodo


## Deja de seguir: el golpe caerá en `p`, dentro de `t_restante` s (≥ 0: si es menor que lo que quedaba, el aviso se acorta; nunca baja de lo que ya pasó).
func fijar(p: Vector3, t_restante: float = -1.0) -> void:
	_sigue = null
	centro = p
	if t_restante >= 0.0:
		t_impacto = t + t_restante
	_colocar()


## A1 de PLAN_COMBATE (22/11): el golpe llegará dentro de `t_restante` s (puede alargar o acortar; el relleno sigue desde donde iba). Lo usa el aviso que sale en la carga previa
## cuando arranca el clip y ya se sabe el instante exacto.
func ajustar(t_restante: float) -> void:
	t_impacto = t + maxf(t_restante, 0.01)


## s de juego que faltan para el golpe (0 = ya).
func queda() -> float:
	return maxf(0.0, t_impacto - t)


## ¿Cubre `p` (en el plano; la altura no cuenta)? Es la MISMA zona que daña: el atacante comprueba el golpe con su propia regla, pero debe coincidir con esto.
func contiene(p: Vector3) -> bool:
	if forma == "linea":
		# La banda: a menos de `halo` del segmento origen → fin (en el plano). Solo informativo (la línea no da premio de esquiva).
		var a := Vector2(centro.x, centro.z)
		var ab: Vector2 = Vector2(fin.x, fin.z) - a
		var l2: float = ab.length_squared()
		var s: float = clampf((Vector2(p.x, p.z) - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0001 else 0.0
		return Vector2(p.x, p.z).distance_to(a + ab * s) <= halo
	var d := Vector3(p.x - centro.x, 0.0, p.z - centro.z)
	if forma == "circulo":
		return d.length() <= radio
	var delante: float = d.dot(dir)
	var lado: float = absf(d.dot(Vector3(-dir.z, 0.0, dir.x)))
	return delante >= -atras and delante <= largo and lado <= ancho


## Las casillas que toca (las que tienen su centro dentro): para las pruebas («cubre las casillas que daña»).
func casillas() -> Array:
	var r: Array = []
	var ext: float = radio if forma == "circulo" else largo + atras + ancho
	var c0: Vector2i = Terreno3D.celda_de(centro)
	var n: int = int(ceil(ext / Terreno3D.casilla)) + 1
	for y in range(c0.y - n, c0.y + n + 1):
		for x in range(c0.x - n, c0.x + n + 1):
			var c := Vector2i(x, y)
			if contiene(Terreno3D.centro_de(c)):
				r.append(c)
	return r


func cancelar() -> void:
	if cancelado:
		return
	cancelado = true
	remove_from_group(GRUPO)
	remove_from_group(GRUPO_LINEAS)
	queue_free()


func _process(delta: float) -> void:
	if cancelado:
		return
	if dueno != null and not is_instance_valid(dueno):
		cancelar()
		return
	t += delta
	if forma == "linea":
		_proceso_linea(delta)
		return
	if _sigue != null and is_instance_valid(_sigue):
		centro = _sigue.global_position
		_colocar()
	var k: float = clampf(t / t_impacto, 0.0, 1.0)
	_mat.set_shader_parameter("progreso", k)
	var en_ventana: bool = queda() <= ventana
	var borde: Color = COLOR
	if en_ventana:
		borde = COLOR.lerp(COLOR_VENTANA, 0.6 + 0.4 * sin(t * 40.0))
	_mat.set_shader_parameter("color_borde", borde)
	if parpadeo > 0.0:
		var encendido: bool = fmod(t * parpadeo, 1.0) < 0.5
		var c: Color = COLOR
		c.a = 1.0 if encendido else ALFA_PARPADEO_BAJO
		_mat.set_shader_parameter("color", c)
	if t >= t_impacto:
		remove_from_group(GRUPO)
		var f: float = clampf((t - t_impacto) / T_DESTELLO, 0.0, 1.0)
		_mat.set_shader_parameter("destello", 1.0 - f)
		if f >= 1.0:
			queue_free()
