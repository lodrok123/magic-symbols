#!/usr/bin/env python3
"""Sonidos de las piezas de puzle (16/10, Pipeline). Síntesis con numpy, sin dependencias: se genera con `python audio/gen_sfx_puzles.py`.
Mismo criterio que gen_sfx.py: todo lo mágico/mecánico que no existe grabado se inventa, y sale igualado en RMS (el volumen real lo dice el
CATALOGO de nucleo/sfx.gd). 44,1 kHz, mono, 16 bits."""
import wave, sys, os
import numpy as np

SR = 44100
rng = np.random.default_rng(16102026)


def t(d):
    return np.arange(int(SR * d)) / SR


def ruido(d):
    return rng.uniform(-1, 1, int(SR * d))


def pasabajos(x, fc):
    a = 1.0 - np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def pasaaltos(x, fc):
    return x - pasabajos(x, fc)


def env(n, ataque=0.003, caida=8.0):
    tt = np.arange(n) / SR
    return np.minimum(1.0, tt / max(ataque, 1e-4)) * np.exp(-caida * tt)


def guardar(nombre, x, rms_obj=0.12):
    x = x - np.mean(x)
    r = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (rms_obj / r)
    pico = np.max(np.abs(x))
    if pico > 0.95:
        x = x * (0.95 / pico)
    fade = int(SR * 0.004)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), nombre)
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print(nombre, round(len(x) / SR, 2), "s")


def boton_clic():
    n = int(SR * 0.14)
    tt = np.arange(n) / SR
    tok = np.sin(2 * np.pi * (220 * np.exp(-14 * tt) + 90) * tt) * env(n, 0.001, 22)
    clac = pasaaltos(ruido(0.14), 1500) * env(n, 0.0005, 70)
    return tok * 0.9 + clac * 0.5


def placa_hunde():
    n = int(SR * 0.4)
    tt = np.arange(n) / SR
    golpe = np.sin(2 * np.pi * (60 + 80 * np.exp(-18 * tt)) * tt) * env(n, 0.002, 9)
    roce = pasabajos(ruido(0.4), 900) * env(n, 0.01, 12) * 0.7
    return golpe + roce


def compuerta_baja():
    d = 0.9
    n = int(SR * d)
    tt = np.arange(n) / SR
    base = pasabajos(ruido(d), 320)
    traba = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 19 * tt + 0.8 * np.sin(2 * np.pi * 3 * tt)))   # estremecimiento de piedra sobre piedra
    rechina = np.sin(2 * np.pi * (140 + 22 * np.sin(2 * np.pi * 7 * tt)) * tt) * 0.25
    x = (base * traba * 1.4 + rechina) * np.clip(tt / 0.05, 0, 1) * np.where(tt < 0.58, 1.0, np.exp(-30 * (tt - 0.58)))
    golpe = np.where(tt >= 0.6, np.sin(2 * np.pi * 70 * (tt - 0.6)) * np.exp(-14 * (tt - 0.6)), 0.0)    # al llegar abajo
    return x + golpe * 1.3


def hielo_quiebra():
    d = 0.75
    x = np.zeros(int(SR * d))
    for k in range(7):
        i = int(SR * (0.0 + k * 0.045 + rng.uniform(0, 0.02)))
        m = int(SR * rng.uniform(0.012, 0.03))
        c = pasaaltos(rng.uniform(-1, 1, m), 2500) * env(m, 0.0003, 160) * rng.uniform(0.5, 1.0)
        x[i:i + m] += c[: len(x) - i]
    for k in range(9):                                       # esquirlas: tintineos agudos que caen
        i = int(SR * (0.1 + rng.uniform(0, 0.45)))
        f = rng.uniform(2400, 5200)
        m = int(SR * 0.16)
        tt = np.arange(m) / SR
        x[i:i + m] += (np.sin(2 * np.pi * f * tt) * np.exp(-26 * tt) * 0.28)[: len(x) - i]
    return x


def mecha():
    d = 1.3
    n = int(SR * d)
    tt = np.arange(n) / SR
    sisea = pasaaltos(ruido(d), 2200) * (0.55 + 0.25 * np.sin(2 * np.pi * 9 * tt)) * (0.7 + 0.5 * tt / d)
    crepita = np.zeros(n)
    for _ in range(46):
        i = int(rng.uniform(0, n - 400))
        m = int(SR * rng.uniform(0.001, 0.004))
        crepita[i:i + m] += rng.uniform(-1, 1, m) * rng.uniform(0.5, 1.4)
    return sisea + pasabajos(crepita, 6000) * 0.9


def explosion():
    d = 1.7
    n = int(SR * d)
    tt = np.arange(n) / SR
    sub = np.sin(2 * np.pi * (34 + 70 * np.exp(-6 * tt)) * tt) * env(n, 0.002, 2.8)
    cuerpo = pasabajos(ruido(d), 1100) * env(n, 0.002, 3.4)
    chasquido = pasaaltos(ruido(d), 1200) * env(n, 0.0005, 38) * 0.8
    cola = pasabajos(ruido(d), 260) * np.exp(-1.4 * tt) * 0.8 * np.clip((tt - 0.1) / 0.3, 0, 1)
    return sub * 1.4 + cuerpo + chasquido + cola


def rueda_chirria():
    d = 1.2
    n = int(SR * d)
    tt = np.arange(n) / SR
    f = 310 + 55 * np.sin(2 * np.pi * 2.2 * tt) + 25 * np.sin(2 * np.pi * 6.7 * tt)
    fase = 2 * np.pi * np.cumsum(f) / SR
    sierra = 2 * ((fase / (2 * np.pi)) % 1.0) - 1
    x = pasabajos(sierra, 1800) * 0.5 + pasaaltos(ruido(d), 3000) * 0.12
    return x * (0.6 + 0.4 * np.sin(2 * np.pi * 3.3 * tt + 1.0)) * np.minimum(1, np.minimum(tt / 0.1, (d - tt) / 0.1))


def zumbido_electrico():
    d = 1.0
    n = int(SR * d)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for k, a in zip(range(1, 9), [1, 0.6, 0.5, 0.35, 0.3, 0.2, 0.15, 0.1]):
        x += a * np.sin(2 * np.pi * 100 * k * tt + k)         # 100 Hz: ciclo entero en 1 s, enlaza sin salto
    x *= 0.6 + 0.4 * np.sin(2 * np.pi * 7 * tt)
    crac = np.zeros(n)
    for _ in range(22):
        i = int(rng.uniform(0, n - 300))
        m = int(SR * rng.uniform(0.0008, 0.003))
        crac[i:i + m] += rng.uniform(-1, 1, m) * 1.6
    return x * 0.5 + pasaaltos(crac, 900)


def llenado():
    d = 1.0
    n = int(SR * d)
    tt = np.arange(n) / SR
    agua = pasabajos(ruido(d), 1500) * (0.6 + 0.4 * pasabajos(ruido(d), 14) * 7)
    x = agua * 0.8
    for _ in range(26):                                      # borbotones: silbidos que suben
        i = int(rng.uniform(0, n - 6000))
        m = int(SR * rng.uniform(0.04, 0.1))
        tm = np.arange(m) / SR
        f0 = rng.uniform(380, 900)
        x[i:i + m] += np.sin(2 * np.pi * (f0 + 1400 * tm) * tm) * np.exp(-30 * tm) * 0.28
    return x * np.minimum(1, np.minimum(tt / 0.08, (d - tt) / 0.08))


for nombre, f, r in [("boton_clic", boton_clic, 0.13), ("placa_hunde", placa_hunde, 0.14), ("compuerta_baja", compuerta_baja, 0.13),
                     ("hielo_quiebra", hielo_quiebra, 0.1), ("mecha", mecha, 0.09), ("explosion", explosion, 0.17),
                     ("rueda_chirria", rueda_chirria, 0.09), ("zumbido_electrico", zumbido_electrico, 0.1), ("llenado", llenado, 0.1)]:
    guardar(nombre + ".wav", f(), r)
