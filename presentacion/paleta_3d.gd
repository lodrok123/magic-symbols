class_name Paleta3D
extends RefCounted
## La paleta cerrada del mundo (Fase 14.2 · P2). Es la contraparte en código de docs/ARTE.md §10: si cambia una, cambia la otra.
##
## POR QUÉ UNA PALETA CERRADA. Lo que más «calidad» da al diorama de Echoes of Wisdom no es el detalle, es que todo vive en 3–4 verdes,
## 2 marrones y 1 azul bajo la misma luz. Aquí cada color sale de MEDIR lo que el juego ya dibuja (no de elegirlo a ojo):
##   · hierba, tierra, piedra y flanco de tierra: k-means (3 grupos) de las texturas de arte/suelo_meshy/ (hierba_arriba, tierra_arriba,
##     losas_piedra, cuerpo);
##   · agua: los dos colores del agua estilizada de AguaRender3D (`color_somero_est`, `color_hondo_est`);
##   · madera y metal: los de las piezas de puzle (PiezaPuzle3D) contrastados con el atlas de cofre.glb (madera #7C4119–#A77652,
##     hierro #383942): el del puzle es el punto medio legible a pleno sol.
## Los números que salieron de cada medida están en ARTE.md §10.
##
## USO. Los colores se leen por nombre (`Paleta3D.HIERBA`). Las piezas de Meshy que se salen de la paleta se tiñen con
## `tintar` (multiplica el albedo, no lo sustituye: se conserva el dibujo pintado). El ajuste de color del entorno es ÚNICO:
## todo WorldEnvironment del juego llama a `aplicar_ajuste(env)` y no pone su propio brillo/contraste/saturación.

## Hierba ×3: sombra (los matojos pegados al suelo), media (el suelo) y luz (las puntas al sol).
const HIERBA_SOMBRA: Color = Color("8BC77E")
const HIERBA: Color = Color("9FD180")
const HIERBA_LUZ: Color = Color("B2D983")
## Tierra ×2: la del suelo pisado y la del flanco de los bloques (arcilla naranja).
const TIERRA: Color = Color("835832")
const TIERRA_FLANCO: Color = Color("DB8F59")
## Piedra ×2: la losa clara y su sombra.
const PIEDRA: Color = Color("B8ADB8")
const PIEDRA_OSCURA: Color = Color("7D747C")
## Agua ×2: somera y honda (las de AguaRender3D).
const AGUA_SOMERA: Color = Color("70CCE8")
const AGUA_HONDA: Color = Color("3385CC")
## Madera y metal (uno cada uno).
const MADERA: Color = Color("8C5C33")
const METAL: Color = Color("5C616E")
## El camino/arena (`path_arriba`) es el ÚNICO color medido fuera de la lista cerrada: lo pinta el shader del suelo (del Juego, no se toca)
## y no se usa en piezas. Se anota aquí para que nadie lo busque en la paleta.
const CAMINO_ARENA: Color = Color("FDD495")

## Ajuste de color del entorno (Environment.adjustment_*). Brillo y contraste neutros (1,0) y saturación 1,1. Medido en el Bosque con
## el ajuste aplicado ANTES de tocar la luz: saturación 1,1 sube la del suelo de 0,34 a 0,36 y la de la tierra de 0,60 a 0,64; el
## contraste 1,05 empeoraba el tono del suelo (84° → 80°) porque el canal verde ya está recortado a 1,0, y el brillo 0,94 no lo arregla:
## el recorte ocurre antes del ajuste. Ver ARTE.md §10.
const AJUSTE_BRILLO: float = 1.0
const AJUSTE_CONTRASTE: float = 1.0
const AJUSTE_SATURACION: float = 1.1


## Piezas de Meshy cuyo color medio se sale de la paleta, y a qué color de la paleta se acercan. Formato: id → [color medio medido,
## color de la paleta, fuerza 0–1]. El «medido» sale de `herramientas/medir_color_piezas.gd` (media del albedo ponderada por el área de
## cada triángulo, la textura muestreada en el UV de su centro). Solo están las que se salen de verdad: las demás (marrones de
## troncos, paja, campamento, cofre; losas grises) ya viven en los marrones y grises de la paleta y no se tocan.
##   · verdes: h77–83° y saturación 0,45–0,60 frente a la hierba del suelo (h97°, 0,39): más amarillos, más cargados y más oscuros;
##   · hojas caídas: naranja saturado (s 0,82) frente a la tierra de los flancos (s 0,60).
## NO están la tinaja ni los canales (gris plano #787878, v 0,47): son la «piedra oscura» de la paleta (v 0,49) y deben quedar más
## oscuros que las losas del suelo para leerse sobre ellas; teñirlos hacia la piedra clara los fundía con el suelo (probado: se
## veían blanco rosado sobre las losas).
const PIEZAS: Dictionary = {
	"helecho": [Color("82A944"), HIERBA, 0.6],
	"canas": [Color("89A34C"), HIERBA, 0.6],
	"flores_blancas": [Color("8BAD4D"), HIERBA, 0.5],
	"hierba_alta": [Color("99BB66"), HIERBA, 0.5],
	"hojas_caidas": [Color("C85F24"), TIERRA_FLANCO, 0.5],
}


## El multiplicador de una pieza (blanco = no se toca).
static func tinte_de_pieza(id: String) -> Color:
	if not PIEZAS.has(id):
		return Color.WHITE
	var d: Array = PIEZAS[id]
	return tinte_hacia(d[0] as Color, d[1] as Color, float(d[2]))


## El ajuste único. Se llama sobre el Environment de cada WorldEnvironment (maqueta, laboratorios).
static func aplicar_ajuste(env: Environment, intensidad: float = 1.0) -> void:
	if env == null:
		return
	env.adjustment_enabled = intensidad > 0.0
	env.adjustment_brightness = lerpf(1.0, AJUSTE_BRILLO, intensidad)
	env.adjustment_contrast = lerpf(1.0, AJUSTE_CONTRASTE, intensidad)
	env.adjustment_saturation = lerpf(1.0, AJUSTE_SATURACION, intensidad)


## Multiplicador que acerca `medido` (el color dominante de una pieza) a `objetivo` (el de la paleta), con `fuerza` de 0 a 1.
## Es un multiplicador y no un color de sustitución: albedo_color × tinte conserva el dibujo pintado. Se acota a 1,35 por canal
## para no quemar texturas claras, y a 0,6 por abajo para no ennegrecerlas.
static func tinte_hacia(medido: Color, objetivo: Color, fuerza: float = 0.5) -> Color:
	var r: Array[float] = []
	for k in 3:
		var m: float = maxf(medido[k], 0.05)
		r.append(clampf(lerpf(1.0, objetivo[k] / m, fuerza), 0.6, 1.35))
	return Color(r[0], r[1], r[2])


## Tiñe todas las mallas de `nodo` multiplicando el albedo de sus materiales por `tinte`. Duplica cada material una sola vez
## (los GLB comparten materiales entre copias de una misma pieza: sin duplicar, teñir una teñiría todas).
## Solo toca StandardMaterial3D (los ShaderMaterial del juego —hierba, agua, hielo— llevan su color en sus uniforms).
static func tintar(nodo: Node, tinte: Color) -> void:
	if nodo is MeshInstance3D:
		var mi: MeshInstance3D = nodo as MeshInstance3D
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(s)
				if m is StandardMaterial3D:
					var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					d.albedo_color = d.albedo_color * tinte
					mi.set_surface_override_material(s, d)
	for h in nodo.get_children():
		tintar(h, tinte)
