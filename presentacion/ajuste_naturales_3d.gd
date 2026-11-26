extends RefCounted
## Paleta derivada: conservar originales y alfa. El trabajo por píxel se hace al
## generar los assets, nunca durante una partida.
const CARPETA_ROCAS: String = "res://arte/suelo_meshy/rocas_rio/"

static func color_roca(c: Color) -> Color:
	var verdor: float = smoothstep(0.015, 0.16, c.g - maxf(c.r, c.b))
	var piedra := Color(c.r * 0.72 + 0.035, c.g * 0.72 + 0.03, c.b * 0.69 + 0.025, c.a)
	var gris: float = c.get_luminance()
	var musgo: Color = Color(gris, gris, gris, c.a).lerp(c, 0.55)
	musgo = Color(musgo.r * 0.76, musgo.g * 0.80, musgo.b * 0.66, c.a)
	return piedra.lerp(musgo, verdor)

static func color_follaje(c: Color, saturacion: float, brillo: float) -> Color:
	var peso: float = smoothstep(0.0, 0.12, c.g - maxf(c.r, c.b))
	var gris: float = c.get_luminance()
	var nuevo: Color = Color(gris, gris, gris, c.a).lerp(c, saturacion)
	nuevo = Color(nuevo.r * brillo, nuevo.g * brillo, nuevo.b * brillo * 0.96, c.a)
	return c.lerp(nuevo, peso)

static func procesar(origen: Image, roca: bool, saturacion: float = 0.62, brillo: float = 0.90) -> Image:
	var im: Image = origen.duplicate()
	if im.is_compressed(): im.decompress()
	im.clear_mipmaps()
	im.convert(Image.FORMAT_RGBA8)
	for y in im.get_height():
		for x in im.get_width():
			var c: Color = im.get_pixel(x,y)
			im.set_pixel(x,y, color_roca(c) if roca else color_follaje(c, saturacion, brillo))
	return im
