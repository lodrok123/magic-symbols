# Prueba 2 (fuego toon), segunda técnica: material M_FuegoToon según el tutorial de CGHOW «UE 5.5 Quick and Easy Stylized
# Fire» (vídeo 2A4AMI-SHIQ), adaptado al estilo de ref_muro.jpg (Zelda BotW): ruido procedimental (nodo Noise, Voronoi)
# en 2D, recortado por un degradado radial exponencial, contraste con Power, coordenadas estiradas en vertical, paneo
# hacia arriba con el tiempo cuantizado a 12 fps, desfase de paneo distinto por partícula, ParticleColor a emisivo y alfa.
# Adaptación obligatoria: Masked con umbral duro (Step) y rampa de tres tonos planos por dos umbrales sobre la misma
# máscara (crema abajo, naranja cuerpo, rojo borde fino), sin degradado a negro.
# Reutiliza las ayudas de poc2_material.py (clase Grafo, srgb, humo, chispa). Mismos nombres de assets que la técnica 1
# (M_FuegoToon, MI_FuegoToon_Cuerpo = capa base brillante, MI_FuegoToon_Lengua = lenguas) para no romper referencias.
#
# Huecos de la API de Python (comprobados en el editor, ver NOTAS.md):
#  - MaterialFunctionCall(RadialGradientExponential): el nodo no expone sus salidas desde Python (no se puede conectar
#    «Result»), así que el degradado radial se construye a mano con los mismos nodos que usa la función:
#    pow(saturate(1 - distance(uv, centro) / radio), densidad).
#  - DynamicParameter: solo la salida 0 se puede conectar por nombre (las salidas con nombre no resuelven), así que el
#    parámetro dinámico 0 (Densidad) viene de Niagara y los desfases de paneo por partícula salen de ParticleRandom.
import sys, traceback, unreal as ue
sys.path.append(ue.Paths.project_dir() + "Scripts")
import importlib, poc2_material as pm
importlib.reload(pm)
from poc2_material import Grafo, srgb, humo, chispa


def fuego_cghow():
    g = Grafo("M_FuegoToon")
    # mandos (los diez de §1 con el sentido de esta técnica, más los propios del tutorial)
    # ronda 9: umbral y bandas más bajos (en la ronda 8 solo sobrevivía el centro del degradado: fichas rojas pequeñas)
    # ronda 11: menos crema (Banda mayor), lenguas más apuntadas (ruido más estirado y más fino, más erosión arriba)
    # ronda 15: Banda 0.40 -> 0.18 (la crema era el 63 % del fuego; en la referencia es ~10 % de los píxeles saturados)
    Fps = g.esc("Fps", 12); Umbral = g.esc("Umbral", 0.22); Banda = g.esc("Banda", 0.16); BandaBorde = g.esc("BandaBorde", 0.03)
    Altura = g.esc("AlturaLlama", 0.25)        # altura (0 = base, 1 = punta) del centro del degradado radial: abajo = crema en la mitad baja
    Erosion = g.esc("Erosion", 1.4)              # densidad (exponente) del degradado radial: recorta la forma de la lengua
    Despl = g.esc("Desplazamiento", 1.0)         # amplitud del desfase de paneo por partícula (PanOffset del tutorial)
    Contorno = g.esc("Contorno", 0.0); Vel = g.esc("Velocidad", 0.8); Escala = g.esc("EscalaRuido", 3.5); Brillo = g.esc("Brillo", 0.5)
    EstU = g.esc("EstiradoU", 1.0); EstV = g.esc("EstiradoV", 0.2)   # tiling distinto por eje: V menor = ruido estirado en vertical
    Contraste = g.esc("Contraste", 1.0); Radio = g.esc("Radio", 0.75)
    CNucleo = g.vec("ColorNucleo", *srgb("#FFE060")); CCuerpo = g.vec("ColorCuerpo", *srgb("#F07820"))
    CBorde = g.vec("ColorBorde", *srgb("#C83018")); CContorno = g.vec("ColorContorno", *srgb("#3A0A05"))
    tq = g.tiempo_cuantizado(Fps)
    tc = g.nodo(ue.MaterialExpressionTextureCoordinate)
    pr = g.nodo(ue.MaterialExpressionParticleRandom)
    pc = g.nodo(ue.MaterialExpressionParticleColor)
    dp = g.nodo(ue.MaterialExpressionDynamicParameter, param_names=["Densidad", "PanOffsetX", "PanOffsetY", "Reserva"])
    # (6) coordenadas estiradas: uv * (EstiradoU, EstiradoV)
    uvs = g.mul(tc, g.append(EstU, EstV))
    # (7)+(9) paneo hacia arriba con tiempo cuantizado y desfase por partícula
    offx = g.mul(g.op(ue.MaterialExpressionFrac, g.mul(pr, g.const(7.31)), None, ea=""), Despl)
    offy = g.mul(g.op(ue.MaterialExpressionFrac, g.mul(pr, g.const(13.7)), None, ea=""), Despl)
    pan = g.add(uvs, g.append(offx, g.add(offy, g.mul(tq, Vel))))
    # (2)+(3) ruido procedimental 2D: posición (x, y, 0) * EscalaRuido, Voronoi, 2 niveles, salida 0..1
    pos = g.append(g.mul(pan, Escala), g.const(0))
    ruido = g.nodo(ue.MaterialExpressionNoise, noise_function=ue.NoiseFunction.NOISEFUNCTION_VORONOI_ALU, levels=3, output_min=0.0, output_max=1.0,
                   turbulence=False, scale=1.0, quality=1, level_scale=2.0)
    g.con(pos, ruido, "")   # la entrada Position no resuelve por nombre; "" = primera entrada
    # ronda 10: el Voronoi vale 0 en el centro de cada celda y 1 en sus bordes; invertido, las celdas son gotas (lenguas)
    # y no una red de anillos (lo que salió en la ronda 9)
    InvR = g.esc("InvertirRuido", 1.0)
    ruido = g.lerp(ruido, g.uno_menos(ruido), InvR)
    # (4) degradado radial exponencial (a mano): pow(saturate(1 - d / Radio), Erosion * Densidad_particula)
    centro = g.append(g.const(0.5), g.uno_menos(Altura))     # V = 0 arriba en el sprite: centro a (1 - AlturaLlama)
    d = g.div(g.op(ue.MaterialExpressionDistance, tc, centro), Radio)
    sat = g.op(ue.MaterialExpressionSaturate, g.uno_menos(d), None, ea="")
    dens = g.mul(Erosion, dp)   # salida 0 del DynamicParameter = Densidad (1 si Niagara no la fija)
    radial = g.nodo(ue.MaterialExpressionPower); g.con(sat, radial, "Base"); g.con(dens, radial, "Exp")
    # (5) contraste con Power; (8) alfa de la partícula multiplica la máscara (al morir, la lengua se come desde el borde)
    # ronda 13: mando Resta (0 = producto ruido x radial del tutorial, que da bultos redondos; 1 = radial - (1 - ruido) *
    # Amplitud, que recorta puntas en los valles del ruido: lenguas apuntadas como en la referencia)
    Resta = g.esc("Resta", 1.0); Amp = g.esc("AmplitudRuido", 0.5)
    base_m = g.lerp(g.mul(ruido, radial), g.op(ue.MaterialExpressionSaturate, g.sub(radial, g.mul(g.uno_menos(ruido), Amp)), None, ea=""), Resta)
    m0 = g.nodo(ue.MaterialExpressionPower); g.con(base_m, m0, "Base"); g.con(Contraste, m0, "Exp")
    m = g.mul(m0, pc, "", "A")
    # máscara dura (adaptación: Masked, sin opacidad suave)
    g.salida(g.step(Umbral, m), ue.MaterialProperty.MP_OPACITY_MASK)
    # rampa de tres tonos planos sobre la misma máscara: crema donde m es alto (centro bajo), naranja, rojo en el borde fino
    # ronda 12: la crema va en la mitad baja de cada lengua (como en la referencia): el umbral de la crema se evalúa
    # sobre m * (0.5 + PesoBase * (1 - V)), más alto abajo y más bajo arriba
    # ronda 14: la crema es la mitad baja de cada lengua con un corte ondulado por el ruido: crema donde la altura
    # (1 - V) < Banda * (0.7 + 0.6 * ruido). (Con PesoBase sobre m, ronda 12-13, salían islas en el centro.)
    V = g.mask(tc, False, True)
    h_crema = g.mul(Banda, g.add(g.const(0.7), g.mul(ruido, g.const(0.6))))   # ronda 17: menos crema que en la 16
    c1 = g.si(h_crema, g.uno_menos(V), CNucleo, CCuerpo)
    # ronda 16: el borde rojo solo arriba (en la referencia no hay rojo en los lados ni en la base): por debajo de
    # 1,3 x la altura de la crema se suma 1 a m y nunca cae en la banda roja
    m_borde = g.add(m, g.step(g.uno_menos(V), g.mul(h_crema, g.const(1.3))))
    c2 = g.si(m_borde, g.add(Umbral, BandaBorde), c1, CBorde)
    c3 = g.si(m, g.add(Umbral, g.mul(Contorno, g.const(0.05))), c2, CContorno)
    g.salida(g.mul(g.mul(c3, Brillo), pc, "", "RGB"), ue.MaterialProperty.MP_EMISSIVE_COLOR)
    g.terminar()
    # instancias: lenguas (rampa completa) y capa base brillante (todo crema, umbral más bajo, centro más abajo)
    g.instancia("MI_FuegoToon_Lengua")
    g.instancia("MI_FuegoToon_Cuerpo", Umbral=0.30, Banda=2.0, BandaBorde=0.0, AlturaLlama=0.2, Radio=0.6, EscalaRuido=3.0, EstiradoV=0.3,
                ColorCuerpo=srgb("#FFE060"), ColorBorde=srgb("#FFE060"))
    return g


if __name__ == "__cola__" or __name__ == "__main__":
    for paso in (fuego_cghow, humo, chispa):
        try: paso()
        except Exception: print("ERROR", traceback.format_exc())
    print("MATERIALES CGHOW: fin")
