extends RefCounted

## PALETA CENTRAL DEL AGUA DE HECHIZO. REGLA DE PABLO: «Como colores toma de referencia el agua ya creada. Para que se sienta igual.»
## 3/11/2026 (turquesa): la referencia es el agua del juego TAL COMO SE VE, es decir, el agua del mundo con `agua_filtro = true` (el valor de serie, presentacion/agua_render_3d.gd), no la versión
## «estándar» (color_hondo_est 0.20,0.52,0.80 y compañía, que sale azul claro y ya no se usa). Antes: HONDO 0.20,0.52,0.80 · SOMERO 0.44,0.80,0.91 · CAUSTICAS 0.72,0.93,1.0 · LECHO 0.16,0.38,0.55.
## De dónde sale cada valor (medido en docs/capturas/comparativa_vfx/godot_agua/turquesa/estanque_con_filtro.png, estanque real AguaSim3D + AguaRender3D con el filtro de serie, sobre el lecho del juego):
##  · MATIZ: el del filtro, FILTRO_COLOR_HONDO = 0.06,0.33,0.38 (turquesa oscuro, H≈0,52), que es el color al que tiende lo hondo y el que se lleva el velo (FILTRO_VELO) y el albedo propio.
##  · HONDO: lo que ve el jugador en lo hondo del estanque (manchas oscuras y centro, sRGB ≈ 0,21-0,28 · 0,39-0,45 · 0,36-0,40) llevado al matiz del filtro. El filtro puro (0.06,0.33,0.38) es
##    demasiado oscuro para una bola o unas gotas sobre un suelo claro (se leerían negras): se sube la luminosidad hasta 0.12,0.46,0.50 manteniendo el matiz turquesa (en el estanque ese tono es
##    el del fondo visto a través del agua, que ya lleva luz del lecho).
##  · SOMERO: lo que se ve en lo poco hondo / zonas claras del estanque (sRGB ≈ 0,36 · 0,50 · 0,47 sobre un lecho verdoso) con el verde del lecho quitado y el matiz del filtro: 0.34,0.74,0.72.
##  · ESPUMA: la del agua del mundo (color_espuma 0.96,0.99,1.0): blanca; no cambia.
##  · CAUSTICAS: red de luz = el somero aclarado hacia la luz del sol, 0.66,0.95,0.92 (en el mundo con filtro las cáusticas son el brillo del lecho bajo el agua).
##  · LECHO (lo que se ve a través: cara trasera, charcos): el hondo del filtro con algo de luz, 0.07,0.34,0.38 (≈ FILTRO_COLOR_HONDO).
##  · FRESNEL: el tinte claro del borde del agua del mundo con el filtro (vec3(0.88, 0.94, 1.0) × FILTRO_FRESNEL en el albedo): no cambia.
## Tres tonos = HONDO / SOMERO / ESPUMA; cáusticas con CAUSTICAS; borde con FRESNEL; lo que se ve a través (cara trasera, charcos) con LECHO.
## Los shaders (agua_toy.gdshaderinc, agua_gota.gdshader) llevan estos mismos valores como defaults y AguaMallas.material() / AguaGotas los pasan como uniforms: si se cambian aquí, hay que
## cambiarlos también en esos dos archivos (la prueba prueba_agua_toy lo comprueba leyendo el .gdshaderinc).
## Y el lenguaje del agua del mundo: bandas por umbral entre somero y hondo (BANDAS escalones), franjas/bordes de espuma, cáusticas como redes de luz y borde claro por fresnel.

const HONDO: Color = Color(0.12, 0.46, 0.50)
const SOMERO: Color = Color(0.34, 0.74, 0.72)
const ESPUMA: Color = Color(0.96, 0.99, 1.0)
const CAUSTICAS: Color = Color(0.66, 0.95, 0.92)
const LECHO: Color = Color(0.07, 0.34, 0.38)
const FRESNEL: Color = Color(0.88, 0.94, 1.0)
const BANDAS: float = 3.0

## nombre del uniform → valor, para pasarlos a cualquier ShaderMaterial del agua.
static func uniforms() -> Dictionary:
	return {"tono_a": HONDO, "tono_b": SOMERO, "tono_c": ESPUMA, "color_causticas": CAUSTICAS, "color_lecho": LECHO, "tinte_fresnel": FRESNEL, "bandas": BANDAS}
