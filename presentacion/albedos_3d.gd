class_name Albedos3D
extends RefCounted
## ALBEDOS «EoW» (Pipeline, 22/10, PLAN_EOW_VISUAL §1.2 y pendiente OSCURECER_SUELO de ARTE.md §10): igualar el CONTRASTE y el VALOR de los albedos
## pintados de las tres grandes familias para que el conjunto se lea unificado: la hierba (Hierba3D y la capa de hierba del suelo), el suelo
## (camino, tierra, piedra del shader de la maqueta) y las piezas de Meshy del decorado (material común de Ocluso3D).
##
## Qué hace (todo en los SHADERS; las imágenes no se tocan): por cada muestra de albedo `c` y la media local `m` de su textura (un mip alto):
##       c' = (m + (c - m) * K) * VALOR          (K < 1 comprime el contraste hacia la media; VALOR sube o baja el valor medio)
## Medido (docs/capturas/albedos/MEDIDAS.md): las piezas de Meshy llegan a desviación ~40-60 niveles frente a ~20-25 del suelo y la hierba, y
## el suelo queda a media distinta según la familia. K y VALOR por familia, abajo.
##
## `activo = false` (o `albedos_eow = false` en la maqueta) devuelve exactamente lo de antes: K = 1 y VALOR = 1 (los shaders reciben esos números).
static var activo: bool = true

## --- constantes por familia: K (contraste: < 1 comprime hacia la media, > 1 la separa) y VALOR (multiplica el albedo lineal tras comprimir) ---
## Salen de docs/capturas/albedos/MEDIDAS.md (antes/después). OSCURECER_SUELO (0,78, en la maqueta) se queda como estaba: con estos VALOR el suelo
## efectivo es 0,78 × 0,9 = 0,70 (hierba) y 0,78 × 0,85 = 0,66 (camino), que es justo el 0,64-0,70 que pedía el pendiente de ARTE.md §10.
const HIERBA_K: float = 1.25          ## la textura de hierba del suelo es casi lisa (rango 24 niveles): se separa un poco
const HIERBA_VALOR: float = 0.9
const BRIZNA_K: float = 1.0           ## briznas de Hierba3D (degradado base→punta): solo el valor
const TARJETA_K: float = 0.6          ## tarjetas pintadas (hierba_matojos.png: rango 112 niveles, el doble que cualquier suelo): se comprimen
const CAMINO_K: float = 1.6           ## la arena es la más lisa (rango 14) y la más clara: se le da grano y se le baja el valor
const CAMINO_VALOR: float = 0.85
const TIERRA_K: float = 1.0
const TIERRA_VALOR: float = 1.12      ## la tierra queda en 84/255: algo más clara para sentarse junto a la hierba (la paleta dice 94)
const PIEDRA_K: float = 0.65          ## las losas llevan juntas muy oscuras (rango 67): se comprimen a ~43
const PIEDRA_VALOR: float = 0.93
const PIEZAS_K: float = 0.55          ## piezas de Meshy: rango 91 de media (todas las texturas 60-145): a ~50, el de EoW (25-45) con algo de margen
const PIEZAS_VALOR: float = 0.92      ## en pantalla las copas salían más claras que la hierba (208 contra 198); 0,88 las dejaba caqui y sucias, por eso solo 0,95 y más saturación
const PIEZAS_SAT: float = 1.08        ## devuelve la saturación que se pierde al comprimir el contraste (las copas y los pinos se iban a gris verdoso); 1 = nada
## Nivel de mip con el que el shader saca «la media local» de la textura (alto = casi la media de toda la imagen).
const MIP_MEDIA: float = 12.0
## Nombre del uniform global con (K, VALOR, activo, saturación) de las piezas: lo lee el shader común de Ocluso3D (parcheado por `parchear_ocluso`).
const PARAM_PIEZAS: String = "albedos_piezas"

static var _registrado: bool = false


static func k_de(familia: String) -> float:
	match familia:
		"hierba":
			return HIERBA_K
		"hierba_matojos", "tarjeta":
			return TARJETA_K
		"brizna":
			return BRIZNA_K
		"camino":
			return CAMINO_K
		"tierra", "cuerpo", "lecho_rio":
			return TIERRA_K
		"piedra":
			return PIEDRA_K
		"piezas":
			return PIEZAS_K
	return 1.0


static func valor_de(familia: String) -> float:
	match familia:
		"hierba", "hierba_matojos", "tarjeta", "brizna":
			return HIERBA_VALOR
		"camino":
			return CAMINO_VALOR
		"tierra", "cuerpo", "lecho_rio":
			return TIERRA_VALOR
		"piedra":
			return PIEDRA_VALOR
		"piezas":
			return PIEZAS_VALOR
	return 1.0


## VALOR que se aplica al albedo de un bloque triplanar (StandardMaterial3D de la maqueta: solo se puede tocar el valor): cuerpo = flanco de tierra, stone = piedra.
static func valor_bloque(ruta: String, encendido: bool = true) -> float:
	if not encendido:
		return 1.0
	if "stone" in ruta or "losas" in ruta:
		return PIEDRA_VALOR
	if "cuerpo" in ruta:
		return TIERRA_VALOR
	return 1.0


## (K, VALOR) que recibe el shader de una familia: (1, 1) si el interruptor está apagado.
static func par(k: float, valor: float, encendido: bool = true) -> Vector2:
	return Vector2(k, valor) if encendido else Vector2(1.0, 1.0)


## Pone los uniforms `alb_<familia>` (vec2 K, VALOR) del shader del suelo. `encendido` = el export `albedos_eow` de la maqueta.
static func aplicar_suelo(mat: ShaderMaterial, encendido: bool) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("alb_hierba", par(HIERBA_K, HIERBA_VALOR, encendido))
	mat.set_shader_parameter("alb_camino", par(CAMINO_K, CAMINO_VALOR, encendido))
	mat.set_shader_parameter("alb_tierra", par(TIERRA_K, TIERRA_VALOR, encendido))
	mat.set_shader_parameter("alb_piedra", par(PIEDRA_K, PIEDRA_VALOR, encendido))
	mat.set_shader_parameter("alb_mip", MIP_MEDIA)


## Materiales de Hierba3D: briznas (uniform `alb_hierba` = K, VALOR del degradado) y tarjetas (`alb_hierba` + `alb_media`, la media LINEAL del atlas ponderada por alfa:
## el atlas tiene fondo transparente y un mip alto lo ensuciaría con él). Flores: sin tocar (son el acento de color).
static func aplicar_hierba(mat_brizna: ShaderMaterial, mat_tarjeta: ShaderMaterial, atlas: Texture2D, encendido: bool) -> void:
	if mat_brizna != null:
		mat_brizna.set_shader_parameter("alb_hierba", par(BRIZNA_K, HIERBA_VALOR, encendido))
	if mat_tarjeta != null:
		mat_tarjeta.set_shader_parameter("alb_hierba", par(TARJETA_K, HIERBA_VALOR, encendido))
		mat_tarjeta.set_shader_parameter("alb_media", media_lineal(atlas))


## Media lineal (RGB) de los píxeles con alfa >= 0,5 de una textura. Sin textura o sin píxeles: gris medio.
static func media_lineal(tex: Texture2D) -> Vector3:
	if tex == null:
		return Vector3(0.3, 0.3, 0.3)
	var im: Image = tex.get_image()
	if im == null:
		return Vector3(0.3, 0.3, 0.3)
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	var paso: int = maxi(1, int(sqrt(float(im.get_width() * im.get_height()) / 65536.0)))
	var suma := Vector3.ZERO
	var n: int = 0
	for y in range(0, im.get_height(), paso):
		for x in range(0, im.get_width(), paso):
			var c: Color = im.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var l: Color = c.srgb_to_linear()
			suma += Vector3(l.r, l.g, l.b)
			n += 1
	return suma / float(n) if n > 0 else Vector3(0.3, 0.3, 0.3)

## --- piezas (material común de Ocluso3D) ---
## Ocluso3D.CODIGO no lleva la corrección (su archivo lo toca otra sesión): se INYECTA aquí en el código de sus variantes de culling, antes de que se
## cree ningún material. Idempotente. El interruptor es global y en vivo: `poner_piezas(true|false)`.
const MARCA: String = "// ALBEDOS_EOW"
const FUNCION_SHADER: String = """
global uniform vec4 albedos_piezas;   // ALBEDOS_EOW: x = K · y = VALOR · z = 1 activo · w = saturación
vec3 albedos_eow(sampler2D t, vec3 c) {
	if (albedos_piezas.z < 0.5) {
		return c;
	}
	vec3 m = textureLod(t, vec2(0.5), %f).rgb;
	vec3 r = (m + (c - m) * albedos_piezas.x) * albedos_piezas.y;
	return mix(vec3(dot(r, vec3(0.2126, 0.7152, 0.0722))), r, albedos_piezas.w);
}
"""


static func preparar_global() -> void:
	if _registrado:
		return
	_registrado = true
	RenderingServer.global_shader_parameter_add(PARAM_PIEZAS, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(PIEZAS_K, PIEZAS_VALOR, 1.0 if activo else 0.0, PIEZAS_SAT))


static func poner_piezas(encendido: bool) -> void:
	activo = encendido
	if _registrado:
		RenderingServer.global_shader_parameter_set(PARAM_PIEZAS, Vector4(PIEZAS_K, PIEZAS_VALOR, 1.0 if encendido else 0.0, PIEZAS_SAT))


## Parchea el código de las variantes del shader común de Ocluso3D. Devuelve cuántas variantes quedaron parcheadas (3 si todo va bien).
static func parchear_ocluso() -> int:
	preparar_global()
	var hechas: int = 0
	for cull in ["cull_back", "cull_disabled", "cull_front"]:
		var sh: Shader = Ocluso3D._shader(cull)
		if sh == null:
			continue
		if sh.code.contains(MARCA):
			hechas += 1
			continue
		var codigo: String = sh.code
		var ancla_fn: String = "void fragment() {"
		var ancla_uso: String = "vec4 a = texture(tex_albedo, uv) * color;"
		if not codigo.contains(ancla_fn) or not codigo.contains(ancla_uso):
			continue
		codigo = codigo.replace(ancla_fn, (FUNCION_SHADER % MIP_MEDIA) + ancla_fn)
		# Solo la textura (no el color del material ni el de vértice, que lleva la oclusión) y ANTES del quemado y el disolver.
		codigo = codigo.replace(ancla_uso, "vec4 ta = texture(tex_albedo, uv);\n\tta.rgb = albedos_eow(tex_albedo, ta.rgb);   " + MARCA + "\n\tvec4 a = ta * color;")
		sh.code = codigo
		hechas += 1
	return hechas
