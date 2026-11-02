extends RefCounted

## PALETA CENTRAL DEL HIELO DE HECHIZO. REGLA DE PABLO (2/11/2026): «los colores salen de lo que ya existe en el juego, para que se sienta igual».
## La referencia es el HIELO DEL MUNDO tal como se ve: la placa helada que cubre el agua (presentacion/costra_hielo_3d.gd) y el hielo del agua (agua_render_3d.gd / agua_capa_3d.gd), no un azul inventado.
## De dónde sale cada valor (se leyó del código del juego; no se midió con capturas del estanque helado: los tonos son los uniforms del propio shader del mundo):
##  · CLARO   = costra_hielo_3d.gd `color_claro` 0.72,0.86,0.97 (la cara clara de la placa; en agua_render_3d.gd el hielo claro es 0.70,0.84,0.96 y en agua_capa_3d.gd 0.78,0.90,0.98: los tres coinciden dentro de 0,06).
##  · HONDO   = costra_hielo_3d.gd `color_hondo` 0.46,0.66,0.88 (lo hondo de la placa; agua_render_3d.gd `color_hielo_hondo` es el MISMO valor; agua_capa_3d.gd 0.50,0.70,0.90).
##  · GRIETA  = costra_hielo_3d.gd `color_grieta` 0.30,0.50,0.76 (las grietas de la placa cuando está a punto de romperse: las grietas del cristal antes de romperse).
##  · NUCLEO  = vfx_3d.gd PERFIL «hielo» `nucleo` 0.6,0.88,1.0 (el color del cuerpo de un hechizo de hielo en el juego).
##  · BORDE   = vfx_3d.gd PERFIL «hielo» `borde` 0.92,1.0,1.0 (el borde claro por fresnel de un hechizo de hielo).
##  · ESCARCHA= vfx_estado_3d.gd PERFIL «hielo» `mota` 0.86,0.93,0.99 (los copos y la escarcha del estado hielo; también es el tono más blanco que usa el hielo: lo que sale en las aristas y la base).
## El hielo NO brilla (sin emisión, sin aditivo): tres tonos HONDO / CLARO / ESCARCHA por escalones en las facetas, borde por fresnel, grietas con GRIETA.
## Los shaders (hielo_toy.gdshaderinc) llevan estos mismos valores como defaults y HieloMallas.material() / HieloEsquirlas los pasan como uniforms: si se cambian aquí hay que cambiarlos también en el
## .gdshaderinc (la prueba prueba_hielo_toy lo comprueba leyendo el fichero).

const HONDO: Color = Color(0.46, 0.66, 0.88)
const CLARO: Color = Color(0.72, 0.86, 0.97)
const ESCARCHA: Color = Color(0.86, 0.93, 0.99)
const NUCLEO: Color = Color(0.60, 0.88, 1.0)
const BORDE: Color = Color(0.92, 1.0, 1.0)
const GRIETA: Color = Color(0.30, 0.50, 0.76)
const BANDAS: float = 3.0

## nombre del uniform → valor, para pasarlos a cualquier ShaderMaterial del hielo.
static func uniforms() -> Dictionary:
	return {"tono_a": HONDO, "tono_b": CLARO, "tono_c": ESCARCHA, "color_nucleo": NUCLEO, "color_borde": BORDE, "color_grieta": GRIETA, "bandas": BANDAS}
