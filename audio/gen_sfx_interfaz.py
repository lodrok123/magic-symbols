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
    cofre_tapa()       # U5 (solo este: genera el wav nuevo)
