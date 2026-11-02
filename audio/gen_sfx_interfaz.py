#!/usr/bin/env python3
"""Sonidos de la INTERFAZ (31/10, Juego; gamefeel tarea M). Python puro: `python audio/gen_sfx_interfaz.py`.
Migra a .wav los cinco sonidos que `nucleo/sonidos.gd` sintetizaba en codigo (bolsa, pocion, recoger, golpe, comprar; `moneda` ya estaba en el catalogo)
y anade los nuevos de la mochila. Mismo criterio que gen_sfx_sensacion.py (44,1 kHz, mono, 16 bits, igualado en RMS: el volumen real lo dice `Sfx.CATALOGO`).
  . bolsa       roce de tela con envolvente irregular + clic de hebilla (abrir y cerrar la mochila)
  . pocion      glu-glu ascendente de 0,35 s (beber; con tono +15 % es `pocion_fin`)
  . recoger     chirrido corto que sube (coger un objeto)
  . golpe_ui    golpe sordo corto
  . comprar     tres notas que suben (tienda)
  . ui_tick     tic muy corto y suave al cambiar de hueco o de consumible
  . ui_equipar  dos notas cortas (equipar un consumible)
PRIMERA VERSION SINTETIZADA: se afina escuchando."""
import math, os, random, struct, wave

SR = 44100
rng = random.Random(31102026)


def muestras(d):
    return int(SR * d)


def guardar(nombre, x, rms_obj=0.12):
    m = sum(x) / len(x)
    x = [v - m for v in x]
    r = math.sqrt(sum(v * v for v in x) / len(x)) + 1e-9
    x = [v * rms_obj / r for v in x]
    pico = max(abs(v) for v in x)
    if pico > 0.95:
        x = [v * 0.95 / pico for v in x]
    fade = muestras(0.003)
    for i in range(fade):
        k = i / fade
        x[i] *= k
        x[-1 - i] *= k
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), nombre)
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in x))
    print(nombre, round(len(x) / SR, 2), "s")


def bolsa():
    n = muestras(0.45)
    x = [0.0] * n
    prev = 0.0
    for i in range(n):
        t = i / SR
        env = (0.55 + 0.45 * math.sin(t * 38.0)) * math.exp(-t * 6.0) * min(1.0, t * 90.0)
        ruido = rng.uniform(-1.0, 1.0)
        prev = prev * 0.9 + ruido * 0.1
        x[i] = (ruido - prev) * 0.55 * env
    clic = muestras(0.16)
    for i in range(muestras(0.03)):
        t = i / SR
        x[clic + i] += math.sin(2 * math.pi * 1800.0 * t) * math.exp(-t * 220.0) * 0.6
    guardar("bolsa.wav", x, 0.10)


def pocion():
    d = 0.35
    x = []
    fase = 0.0
    for i in range(muestras(d)):
        t = i / SR
        f = 300.0 + 700.0 * t + 90.0 * math.sin(t * 60.0)
        fase += 2 * math.pi * f / SR
        x.append(math.sin(fase) * math.sin(math.pi * t / d))
    guardar("pocion.wav", x, 0.12)


def recoger():
    x = []
    fase = 0.0
    for i in range(muestras(0.18)):
        t = i / SR
        fase += 2 * math.pi * (500.0 + 4800.0 * t) / SR
        x.append(math.sin(fase) * math.exp(-t * 16.0))
    guardar("recoger.wav", x, 0.12)


def golpe_ui():
    x = []
    for i in range(muestras(0.12)):
        t = i / SR
        x.append((rng.uniform(-1.0, 1.0) * 0.5 + math.sin(2 * math.pi * 140.0 * t) * 0.7) * math.exp(-t * 38.0))
    guardar("golpe_ui.wav", x, 0.12)


def comprar():
    x = []
    for i in range(muestras(0.3)):
        t = i / SR
        f = 880.0 if t < 0.1 else (1109.0 if t < 0.2 else 1319.0)
        x.append(math.sin(2 * math.pi * f * t) * math.exp(-(t % 0.1) * 18.0))
    guardar("comprar.wav", x, 0.11)


def ui_tick():
    """Tic de madera hueca: un golpecito de 2,4 kHz con caida muy rapida."""
    x = []
    for i in range(muestras(0.035)):
        t = i / SR
        x.append((math.sin(2 * math.pi * 2400.0 * t) * 0.8 + math.sin(2 * math.pi * 3600.0 * t) * 0.2) * math.exp(-t * 170.0))
    guardar("ui_tick.wav", x, 0.12)


def ui_equipar():
    """Dos notas cortas que suben (mi5 y la5), con un armonico suave: 'clic de hebilla' musical."""
    x = [0.0] * muestras(0.26)
    for ini, f in ((0.0, 659.3), (0.09, 880.0)):
        for i in range(muestras(0.15)):
            t = i / SR
            v = (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2 * t)) * math.exp(-t * 22.0) * min(1.0, t * 400.0)
            x[muestras(ini) + i] += v
    guardar("ui_equipar.wav", x, 0.11)


def barrido():
    """U1: vaciar la pagina del grimorio. Roce de ruido filtrado que se abre y cae (una mano que barre el papel), 0,22 s."""
    n = muestras(0.22)
    x = [0.0] * n
    prev = 0.0
    for i in range(n):
        t = i / SR
        env = math.sin(math.pi * min(1.0, t / 0.22)) ** 1.5
        a = 0.85 - 0.6 * (t / 0.22)           # el filtro se cierra: del siseo al soplo
        prev = prev * a + rng.uniform(-1.0, 1.0) * (1.0 - a)
        x[i] = (prev * 2.2) * env
    guardar("barrido.wav", x, 0.10)


def reaparecer():
    """U2: la vuelta tras morir. Dos notas suaves que suben (sol4 y re5) con mucha cola, sin ataque duro, 0,6 s."""
    x = [0.0] * muestras(0.6)
    for ini, f in ((0.0, 392.0), (0.16, 587.3)):
        for i in range(muestras(0.44)):
            t = i / SR
            v = (math.sin(2 * math.pi * f * t) + 0.2 * math.sin(2 * math.pi * f * 2 * t)) * math.exp(-t * 6.5) * min(1.0, t * 60.0)
            x[muestras(ini) + i] += v
    guardar("reaparecer.wav", x, 0.10)


def cofre_tapa():
    """U5: chasquido seco de la tapa del cofre al abrirse. Golpe de madera (tono grave que cae) + un chasquido corto de ruido, 0,14 s."""
    n = muestras(0.14)
    x = [0.0] * n
    r2 = random.Random(5112026)               # generador propio: no altera los demas sonidos
    for i in range(n):
        t = i / SR
        madera = math.sin(2 * math.pi * (260.0 - 500.0 * t) * t) * math.exp(-t * 45.0)
        clic = r2.uniform(-1.0, 1.0) * math.exp(-t * 150.0)
        x[i] = madera * 0.8 + clic * 0.6
    guardar("cofre_tapa.wav", x, 0.12)


def ping_debil():
    """D: has acertado la debilidad. Ping agudo y corto (2,6 kHz + octava), 0,16 s, ataque seco."""
    n = muestras(0.16)
    x = [0.0] * n
    for i in range(n):
        t = i / SR
        x[i] = (math.sin(2 * math.pi * 2637.0 * t) + 0.35 * math.sin(2 * math.pi * 5274.0 * t)) * math.exp(-t * 30.0) * min(1.0, t * 800.0)
    guardar("ping_debil.wav", x, 0.10)


def golpe_sordo():
    """D: el golpe resistido. Golpe grave y apagado (90 Hz que cae + ruido muy filtrado), 0,18 s."""
    n = muestras(0.18)
    x = [0.0] * n
    r2 = random.Random(1112026)               # generador propio
    prev = 0.0
    for i in range(n):
        t = i / SR
        prev = prev * 0.95 + r2.uniform(-1.0, 1.0) * 0.05
        x[i] = (math.sin(2 * math.pi * (95.0 - 140.0 * t) * t) * 0.9 + prev * 3.0) * math.exp(-t * 26.0)
    guardar("golpe_sordo.wav", x, 0.12)


def hielo_rompe():
    """E: el cuerpo congelado se rompe. Estallido de ruido agudo + tres tintineos de cristal que bajan, 0,5 s."""
    n = muestras(0.5)
    x = [0.0] * n
    r2 = random.Random(2112026)
    prev = 0.0
    for i in range(n):
        t = i / SR
        prev = prev * 0.3 + r2.uniform(-1.0, 1.0) * 0.7
        x[i] = (r2.uniform(-1.0, 1.0) - prev * 0.6) * math.exp(-t * 55.0) * 0.9
    for ini, f in ((0.01, 3520.0), (0.07, 2960.0), (0.14, 4186.0)):
        for i in range(muestras(0.3)):
            t = i / SR
            x[muestras(ini) + i] += math.sin(2 * math.pi * f * t) * math.exp(-t * 14.0) * 0.5
    guardar("hielo_rompe.wav", x, 0.11)


def chispazo():
    """E: el cuerpo se queda rigido y suelta chispas. Tres chasquidos de ruido con un zumbido de 120 Hz que se apaga, 0,4 s."""
    n = muestras(0.4)
    x = [0.0] * n
    r2 = random.Random(3112026)
    for ini in (0.0, 0.11, 0.2):
        for i in range(muestras(0.07)):
            t = i / SR
            x[muestras(ini) + i] += r2.uniform(-1.0, 1.0) * math.exp(-t * 90.0)
    for i in range(n):
        t = i / SR
        x[i] += (math.sin(2 * math.pi * 120.0 * t) + 0.5 * math.sin(2 * math.pi * 360.0 * t)) * 0.35 * math.exp(-t * 7.0)
    guardar("chispazo.wav", x, 0.11)


def salpicadura():
    """E: el cuerpo se deshace en agua. Chapoteo corto: ruido que se abre y gotas (burbujas) que suben, 0,45 s."""
    n = muestras(0.45)
    x = [0.0] * n
    r2 = random.Random(4112026)
    prev = 0.0
    for i in range(n):
        t = i / SR
        a = 0.5 + 0.4 * min(1.0, t / 0.2)
        prev = prev * a + r2.uniform(-1.0, 1.0) * (1.0 - a)
        x[i] = prev * 2.0 * math.sin(math.pi * min(1.0, t / 0.3)) ** 1.2 * math.exp(-t * 4.0)
    for ini, f in ((0.05, 500.0), (0.13, 700.0), (0.22, 900.0)):
        fase = 0.0
        for i in range(muestras(0.08)):
            t = i / SR
            fase += 2 * math.pi * (f + 3000.0 * t) / SR
            x[muestras(ini) + i] += math.sin(fase) * math.exp(-t * 40.0) * 0.5
    guardar("salpicadura.wav", x, 0.11)


# ---------------------------------------------------------------------------------------------------------------------
#  AMBIENTE POR ZONA (2/11, tercera tanda, lote 3, tarea C3; nucleo/ambiente_zona.gd). Generador propio (no toca el `rng` compartido). 22,05 kHz, mono.
#  Los bucles son largos y sin costura (frecuencias con ciclos enteros o cruce de la cola con el principio); el volumen real lo dice `Sfx.CATALOGO` (−18 dB).
# ---------------------------------------------------------------------------------------------------------------------
SR_AMB = 22050


def _guardar_amb(nombre, x, rms_obj, bucle):
    m = sum(x) / len(x)
    x = [v - m for v in x]
    r = math.sqrt(sum(v * v for v in x) / len(x)) + 1e-9
    x = [v * rms_obj / r for v in x]
    pico = max(abs(v) for v in x)
    if pico > 0.95:
        x = [v * 0.95 / pico for v in x]
    if not bucle:
        f = int(SR_AMB * 0.01)
        for i in range(f):
            x[i] *= i / f
            x[-1 - i] *= i / f
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), nombre)
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR_AMB)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in x))
    print(nombre, round(len(x) / SR_AMB, 2), "s")


def _cruzar(x, fade):
    """Bucle sin costura: la cola (de `fade` muestras) se mezcla, con cruce de igual potencia, sobre el principio."""
    n = len(x) - fade
    y = x[:n]
    for i in range(fade):
        k = i / fade
        y[i] = x[i] * math.sin(k * math.pi / 2) + x[n + i] * math.cos(k * math.pi / 2)
    return y


def _viento(r, dur, corte, ritmo, hondo):
    """Ruido filtrado (paso bajo de dos polos) con ráfagas lentas. `hondo` baja el suelo de la ráfaga."""
    fade = int(SR_AMB * 0.6)
    n = int(SR_AMB * dur) + fade
    a = math.exp(-2 * math.pi * corte / SR_AMB)
    p1 = p2 = 0.0
    x = [0.0] * n
    for i in range(n):
        t = i / SR_AMB
        p1 = p1 * a + r.uniform(-1.0, 1.0) * (1 - a)
        p2 = p2 * a + p1 * (1 - a)
        rafaga = hondo + (1.0 - hondo) * (0.5 + 0.5 * math.sin(2 * math.pi * ritmo * t + 1.3 * math.sin(2 * math.pi * ritmo * 0.37 * t)))
        x[i] = p2 * rafaga
    return _cruzar(x, fade)


def _gorjeo(r, notas, f_ini, f_fin, dur):
    """Un trino: `notas` silbidos cortos que barren de f_ini a f_fin (Hz) con vibrato. Devuelve las muestras."""
    n = int(SR_AMB * dur)
    x = [0.0] * n
    pos = 0.0
    for k in range(notas):
        ini = int(SR_AMB * (0.04 + k * dur * 0.8 / notas))
        largo = int(SR_AMB * r.uniform(0.07, 0.13))
        fa = r.uniform(f_ini, f_fin) * r.uniform(0.9, 1.1)
        fb = fa * r.uniform(0.7, 1.4)
        fase = 0.0
        for i in range(min(largo, n - ini)):
            u = i / largo
            f = fa + (fb - fa) * u + 90.0 * math.sin(2 * math.pi * 38.0 * i / SR_AMB)
            fase += 2 * math.pi * f / SR_AMB
            x[ini + i] += math.sin(fase) * math.sin(math.pi * u) ** 1.5
    return x


def ambiente_zonas():
    """amb_bosque_loop (viento suave), amb_cueva_loop (viento grave y goteo), amb_sala_loop (zumbido bajo), amb_pajaros_0..2 (trinos) y amb_grillos_loop (noche)."""
    r = random.Random(2112026)
    # bosque: viento suave, ráfagas lentas
    _guardar_amb("amb_bosque_loop.wav", _viento(r, 6.0, 520.0, 0.23, 0.35), 0.10, True)
    # cueva: viento grave y goteo (las gotas caen antes del final para no quedar cortadas por el cruce)
    v = _viento(r, 6.0, 170.0, 0.13, 0.5)
    for _ in range(7):
        ini = int(SR_AMB * r.uniform(0.2, 5.2))
        f0 = r.uniform(900.0, 1500.0)
        fase = 0.0
        amp = r.uniform(0.25, 0.5)
        for i in range(int(SR_AMB * 0.25)):
            t = i / SR_AMB
            fase += 2 * math.pi * (f0 * (1.0 + 0.9 * (1 - math.exp(-t * 30.0)))) / SR_AMB
            v[ini + i] += math.sin(fase) * math.exp(-t * 22.0) * amp * 0.06
    _guardar_amb("amb_cueva_loop.wav", v, 0.10, True)
    # sala / interior: zumbido bajo; todos los componentes dan ciclos enteros en 4 s, así que cierra solo
    n = int(SR_AMB * 4.0)
    z = [0.0] * n
    for i in range(n):
        t = i / SR_AMB
        z[i] = (math.sin(2 * math.pi * 52.0 * t) + 0.5 * math.sin(2 * math.pi * 104.0 * t + 0.6) + 0.22 * math.sin(2 * math.pi * 156.0 * t + 1.1)) * (0.85 + 0.15 * math.sin(2 * math.pi * 0.5 * t))
    _guardar_amb("amb_sala_loop.wav", z, 0.09, True)
    # pájaros: tres trinos distintos, sueltos (los dispara AmbienteZona cada INTERVALO_PAJAROS)
    _guardar_amb("amb_pajaros_0.wav", _gorjeo(r, 4, 2800.0, 4200.0, 1.0), 0.10, False)
    _guardar_amb("amb_pajaros_1.wav", _gorjeo(r, 6, 3200.0, 5200.0, 1.3), 0.10, False)
    _guardar_amb("amb_pajaros_2.wav", _gorjeo(r, 3, 2400.0, 3600.0, 0.8), 0.10, False)
    # grillos (noche): dos insectos con trenes de pulsos de portadora entera, de 4 s exactos
    n = int(SR_AMB * 4.0)
    g = [0.0] * n
    for portadora, periodo, pulsos_s, amp in ((4400.0, 0.5, 38.0, 1.0), (5200.0, 0.4, 44.0, 0.7)):
        for i in range(n):
            t = i / SR_AMB
            c = (t % periodo) / periodo
            if c < 0.32:
                pulso = max(0.0, math.sin(2 * math.pi * pulsos_s * t)) ** 2
                g[i] += math.sin(2 * math.pi * portadora * t) * pulso * math.sin(math.pi * c / 0.32) * amp
    _guardar_amb("amb_grillos_loop.wav", g, 0.08, True)


if __name__ == "__main__":
    bolsa()
    pocion()
    recoger()
    golpe_ui()
    comprar()
    ui_tick()
    ui_equipar()
    barrido()          # al final: el generador aleatorio es compartido y asi los anteriores salen igual que antes
    reaparecer()
    cofre_tapa()       # U5
    ping_debil()       # D y E (31/10-1/11): cada uno con su generador propio, asi que no alteran los anteriores
    golpe_sordo()
    hielo_rompe()
    chispazo()
    salpicadura()
    ambiente_zonas()   # C3 (2/11): ambiente sonoro por zona, con su propio generador
