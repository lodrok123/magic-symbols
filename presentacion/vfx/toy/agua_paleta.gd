extends RefCounted

## PALETA CENTRAL DEL AGUA DE HECHIZO (3/11/2026). REGLA DE PABLO: «Como colores toma de referencia el agua ya creada. Para que se sienta igual.»
## Los valores son los del agua del mundo (presentacion/agua_render_3d.gd: color_hondo_est, color_somero_est, color_espuma, color_causticas, color_lecho y el tinte de fresnel 0.88,0.94,1.0).
## Tres tonos = HONDO / SOMERO / ESPUMA; cáusticas con CAUSTICAS; borde con FRESNEL; lo que se ve a través (cara trasera, charcos) con LECHO. Nada de azules propios.
## Los shaders (agua_toy.gdshaderinc, agua_gota.gdshader) llevan estos mismos valores como defaults y AguaMallas.material() / AguaGotas los pasan como uniforms: si se cambian aquí, hay que
## cambiarlos también en esos dos archivos (la prueba prueba_agua_toy lo comprueba leyendo el .gdshaderinc).
## Y el lenguaje del agua del mundo: bandas por umbral entre somero y hondo (BANDAS escalones), franjas/bordes de espuma, cáusticas como redes de luz y borde claro por fresnel.

const HONDO: Color = Color(0.20, 0.52, 0.80)
const SOMERO: Color = Color(0.44, 0.80, 0.91)
const ESPUMA: Color = Color(0.96, 0.99, 1.0)
const CAUSTICAS: Color = Color(0.72, 0.93, 1.0)
const LECHO: Color = Color(0.16, 0.38, 0.55)
const FRESNEL: Color = Color(0.88, 0.94, 1.0)
const BANDAS: float = 3.0

## nombre del uniform → valor, para pasarlos a cualquier ShaderMaterial del agua.
static func uniforms() -> Dictionary:
	return {"tono_a": HONDO, "tono_b": SOMERO, "tono_c": ESPUMA, "color_causticas": CAUSTICAS, "color_lecho": LECHO, "tinte_fresnel": FRESNEL, "bandas": BANDAS}
