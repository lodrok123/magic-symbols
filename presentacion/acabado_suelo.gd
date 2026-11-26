extends RefCounted
## ACABADO DEL SUELO · UNA SOLA FUENTE DE VERDAD (26/11/2026). Las juntas y los bordes que Pablo afinó en Monte Sumicio (14/11: relieve de la
## hierba, relieve de la junta, borde extendido y fundido, mezcla de hierba, tinte del borde) viven AQUÍ. Los usan los dos:
##   · `escenas/monte_sumicio_mundo.gd` (`_vestir_suelo`, sobre el GridMap)    · `presentacion/prueba_test2.gd` (`_aplicar_juntas_entremezcladas`,
##     para todos los niveles de la maqueta: los que genera el generador de mapas, Bosque 01/02, labs…).
## Antes cada uno tenía su copia de los números («si se cambian allí, hay que cambiarlos aquí»). Ahora se afina un valor aquí y llega a los dos.
## Es un script de constantes y una función estática: se usa con `const AcabadoSuelo = preload("res://presentacion/acabado_suelo.gd")`.
##
## Qué NO es común, y por qué (ver el informe del 26/11):
##   · Sumicio pinta el suelo con un GridMap y pone encima una malla `TapasEoW` con este mismo shader; la maqueta dibuja los bloques del suelo con
##     el shader directamente. El shader es UNO (`CODIGO_SUELO`, texturas en coordenadas de mundo + tiras «joint»), así que las costuras entre
##     casillas y entre tipos de suelo son las mismas en los dos; lo único distinto es la malla que lo lleva.
##   · Las rampas (`mundo/pendientes_suelo.gd`) solo existen en Sumicio: el generador no hace desniveles.
##   · El tipo «piedra»: Sumicio usa su empedrado (`empedrado_sumicio.png`); los niveles de la maqueta, las losas del bosque (o las de las ruinas).

## Fuerza del relieve (normal) del suelo: 0 liso · 0,5 la de los niveles antiguos · 1 el máximo de la tecla B · 2,5 Sumicio (por encima del máximo de la tecla).
const RUGOSIDAD: float = 2.5
## Relieve de más SOLO en la hierba (14/11, Pablo: «¿por qué no afecta en la hierba?»): 0 = como el resto del suelo; con 1 o más, el ruido de la
## normal se ve granulado sobre la hierba pintada.
const RELIEVE_HIERBA: float = 0.4
## Relieve que conserva la franja pintada de la junta hierba→tierra/camino (14/11, Pablo: «esta junta ha vuelto a afectarse»): 0 = lisa, con su
## dibujo limpio; 1 = el relieve del suelo también encima. Lisa del todo quedaba más clara que la hierba de al lado.
const RELIEVE_JUNTA: float = 0.4
## La franja de hojas de la junta se EXTIENDE en coordenadas de mundo en vez de estirarse sobre la frontera (14/11, Pablo: «sospecho que estás
## estirando la textura en vez de extenderla»): 1 = extendida (sin abanicos en curvas y esquinas) · 0 = como en los niveles antiguos.
const BORDE_EXTIENDE: float = 1.0
## Fundido de esa franja hacia la tierra (14/11, Pablo: «debería tener la textura como un fade y entremezclarse con la tierra»): 1 = se desvanece
## con el corte roto por ruido fino (calvas de tierra entre las hojas) · 0 = banda maciza.
const BORDE_FUNDIDO: float = 1.0
## Tinte de esa franja: el de serie (0,80 0,90 0,72) es para la hierba del bosque y aquí salía menta; este la acerca al verde de Sumicio.
const BORDE_TINTE: Color = Color(0.82, 0.87, 0.64)
## 14/11, 3.ª pasada (Pablo: «sigo sin verlo bien. Mira la junta»): SIN franja de hojas (BORDE_FUERZA 0, así que BORDE_EXTIENDE, BORDE_FUNDIDO y
## BORDE_TINTE no hacen nada mientras tanto) y con la frontera de la hierba rota por ruido fino (MEZCLA_HIERBA): matas de hierba sobre la tierra y el
## empedrado y calvas en la hierba, entremezcladas. Para volver a la franja: BORDE_FUERZA 1 y MEZCLA_HIERBA 0.
const BORDE_FUERZA: float = 0.0
const MEZCLA_HIERBA: float = 1.2     ## 0 = degradado liso · 0,8 suave · 1,4 muy deshilachado

## Estilos en los que el relieve de Sumicio NO se aplica a la rugosidad: en el Pantano sobre el barro mojado sale como un grano brillante por todo
## el suelo (decisión del 17/11 al llevarlo a todos los niveles); allí se queda la rugosidad de siempre. Las juntas sí van.
const ESTILOS_SIN_RUGOSIDAD: Array = ["pantano"]
## Estilos en los que no se aplica nada de esto: en la cueva todo el suelo es roca y el borde de hierba ya está apagado.
const ESTILOS_SIN_JUNTAS: Array = ["cueva"]


## Pone en el material del suelo (el ShaderMaterial de `CODIGO_SUELO`) las juntas y los bordes de Sumicio. Devuelve la rugosidad que ha dejado
## (para que la maqueta la guarde en `_rugosidad`), o `rugosidad_actual` si el estilo no la cambia.
static func aplicar(mat: ShaderMaterial, estilo: String = "bosque", rugosidad_actual: float = 0.5) -> float:
	var rugosidad: float = rugosidad_actual
	if not ESTILOS_SIN_RUGOSIDAD.has(estilo):
		rugosidad = RUGOSIDAD
		mat.set_shader_parameter("rugosidad", rugosidad)
	mat.set_shader_parameter("relieve_hierba", RELIEVE_HIERBA)
	mat.set_shader_parameter("relieve_junta", RELIEVE_JUNTA)
	mat.set_shader_parameter("borde_extiende", BORDE_EXTIENDE)
	mat.set_shader_parameter("borde_fundido", BORDE_FUNDIDO)
	mat.set_shader_parameter("borde_fuerza", BORDE_FUERZA)
	mat.set_shader_parameter("mezcla_hierba", MEZCLA_HIERBA)
	mat.set_shader_parameter("borde_tinte", BORDE_TINTE)
	return rugosidad
