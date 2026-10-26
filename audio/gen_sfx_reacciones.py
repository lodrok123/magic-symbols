#!/usr/bin/env python3
"""Sonidos de las reacciones del mundo (21/10, Pipeline; PL2 de PLAN_EOW). Síntesis con numpy: `python audio/gen_sfx_reacciones.py`.
Mismo criterio que gen_sfx_puzles.py (44,1 kHz, mono, 16 bits, igualado en RMS: el volumen real lo dice el CATALOGO de nucleo/sfx.gd).
Lo que ya existía NO se vuelve a hacer (prender, congelar, chispa, hielo_quiebra, mecha, explosion, zumbido_electrico, dano, muerte, derrumbe…):
aquí solo lo que le faltaba a la tabla reacción → sonido de `ReaccionesVfx3D`. PRIMERA VERSIÓN SINTETIZADA: se afina escuchando."""
import wave, os
import numpy as np

SR = 44100
rng = np.random.default_rng(21102026)


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


def guardar(nombre, x, rms_obj=0.12, bucle=False):
    x = x - np.mean(x)
    r = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (rms_obj / r)
    pico = np.max(np.abs(x))
    if pico > 0.95:
        x = x * (0.95 / pico)
    if not bucle:
        fade = int(SR * 0.004)
        x[:fade] *= np.linspace(0, 1, fade)
        x[-fade:] *= np.linspace(1, 0, fade)
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), nombre)
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print(nombre, round(len(x) / SR, 2), "s")


def siseo_apagado():
    """Agua sobre brasa: un chasquido al principio y el siseo que se apaga."""
    d = 0.9
    n = int(SR * d)
    tt = np.arange(n) / SR
    sis = pasaaltos(ruido(d), 2400) * np.exp(-3.2 * tt) * (0.8 + 0.2 * np.sin(2 * np.pi * 14 * tt))
    pop = pasaaltos(ruido(d), 800) * env(n, 0.0005, 60) * 0.9
    return sis + pop


def chapoteo():
    """Algo cae al agua: golpe grave corto y salpicadura."""
    d = 0.7
    n = int(SR * d)
    tt = np.arange(n) / SR
    golpe = np.sin(2 * np.pi * (140 * np.exp(-9 * tt) + 55) * tt) * env(n, 0.002, 11)
    salp = pasabajos(ruido(d), 3200) * env(n, 0.004, 6.5)
    gotas = np.zeros(n)
    for _ in range(14):
        i = int(SR * rng.uniform(0.08, 0.55))
        m = int(SR * 0.05)
        f = rng.uniform(900, 2600)
        ttm = np.arange(m) / SR
        gotas[i:i + m] += (np.sin(2 * np.pi * f * (1 + 2 * ttm) * ttm) * np.exp(-60 * ttm) * rng.uniform(0.15, 0.4))[: n - i]
    return golpe * 0.9 + salp * 0.8 + gotas


def hundido_burbujas():
    """Se hunde: un «glub» grave que baja y burbujas que suben de tono."""
    d = 1.7
    n = int(SR * d)
    tt = np.arange(n) / SR
    glub = np.sin(2 * np.pi * np.cumsum(220 * np.exp(-2.4 * tt) + 60) / SR) * env(n, 0.01, 3.2) * 0.8
    x = glub
    for k in range(22):
        i = int(SR * (0.15 + k * 0.065 + rng.uniform(0, 0.04)))
        if i >= n - 3000:
            break
        m = int(SR * 0.07)
        ttm = np.arange(m) / SR
        f0 = rng.uniform(380, 700) * (1 + k * 0.03)
        b = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 7 * ttm)) / SR) * np.exp(-34 * ttm) * rng.uniform(0.25, 0.6)
        x[i:i + m] += b[: n - i]
    return x * np.where(tt > 1.3, np.exp(-6 * (tt - 1.3)), 1.0)


def arde_bucle():
    """Fuego pequeño continuo (para algo que arde): lecho de ruido grave + chasquidos. Bucle sin costura."""
    d = 2.0
    n = int(SR * d)
    lecho = pasabajos(ruido(d), 1400) * 0.55
    pops = np.zeros(n)
    for _ in range(40):
        i = int(rng.uniform(0, n - 700))
        m = int(SR * rng.uniform(0.001, 0.005))
        pops[i:i + m] += rng.uniform(-1, 1, m) * rng.uniform(0.4, 1.3)
    x = lecho + pasabajos(pops, 5000) * 0.9
    k = int(SR * 0.15)                                 # fundido cruzado cola→cabeza: el bucle no hace «clic»
    x[:k] = x[:k] * np.linspace(0, 1, k) + x[-k:] * np.linspace(1, 0, k)
    return x[:-k]


def escudo_golpe():
    """Algo choca contra el escudo de madera: golpe seco y un resto metálico corto."""
    n = int(SR * 0.3)
    tt = np.arange(n) / SR
    tok = np.sin(2 * np.pi * (180 * np.exp(-30 * tt) + 110) * tt) * env(n, 0.001, 26)
    toc = pasabajos(ruido(0.3), 2200) * env(n, 0.0007, 50) * 0.8
    anillo = np.sin(2 * np.pi * 760 * tt) * env(n, 0.001, 20) * 0.15
    return tok + toc + anillo


def escudo_roto():
    """El escudo se hace astillas: crujido, astillas que saltan y golpe grave."""
    d = 0.9
    n = int(SR * d)
    tt = np.arange(n) / SR
    cruj = pasaaltos(ruido(d), 600) * env(n, 0.0005, 18) * 0.8
    x = cruj
    for _ in range(18):
        i = int(SR * rng.uniform(0.02, 0.55))
        m = int(SR * rng.uniform(0.004, 0.014))
        x[i:i + m] += (pasaaltos(rng.uniform(-1, 1, m), 1500) * env(m, 0.0003, 140) * rng.uniform(0.4, 1.0))[: n - i]
    golpe = np.sin(2 * np.pi * (90 * np.exp(-10 * tt) + 45) * tt) * env(n, 0.002, 8)
    return x + golpe * 0.9


def aturdido():
    """Mareo: dos notas que se mecen hacia abajo."""
    d = 0.9
    n = int(SR * d)
    tt = np.arange(n) / SR
    f = 520 - 140 * tt + 28 * np.sin(2 * np.pi * 7 * tt)
    a = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.7
    b = np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR) * 0.3
    return (a + b) * env(n, 0.01, 2.6)


def empujado():
    """Un empujón de aire: ruido que sube y baja."""
    d = 0.5
    n = int(SR * d)
    tt = np.arange(n) / SR
    r = ruido(d)
    cuerpo = pasaaltos(pasabajos(r, 1800), 250)
    return cuerpo * np.sin(np.pi * np.clip(tt / d, 0, 1)) ** 2


def secado():
    """Algo se seca: un soplo de vapor suave."""
    d = 0.9
    n = int(SR * d)
    tt = np.arange(n) / SR
    v = pasaaltos(pasabajos(ruido(d), 4200), 1100)
    return v * np.sin(np.pi * np.clip(tt / d, 0, 1)) ** 1.6


def derretido():
    """El hielo se derrite: goteo y un crujido suave."""
    d = 1.1
    n = int(SR * d)
    x = np.zeros(n)
    for k in range(9):
        i = int(SR * (0.05 + k * 0.11 + rng.uniform(0, 0.05)))
        m = int(SR * 0.09)
        ttm = np.arange(m) / SR
        f0 = rng.uniform(1100, 1900)
        x[i:i + m] += (np.sin(2 * np.pi * np.cumsum(f0 * (1 - 3 * ttm).clip(0.3)) / SR) * np.exp(-40 * ttm) * rng.uniform(0.3, 0.7))[: n - i]
    for _ in range(5):
        i = int(SR * rng.uniform(0.0, 0.7))
        m = int(SR * 0.012)
        x[i:i + m] += (pasaaltos(rng.uniform(-1, 1, m), 2500) * env(m, 0.0003, 150) * 0.4)[: n - i]
    return x


if __name__ == "__main__":
    guardar("siseo_apagado.wav", siseo_apagado())
    guardar("chapoteo.wav", chapoteo())
    guardar("hundido_burbujas.wav", hundido_burbujas())
    guardar("arde_bucle.wav", arde_bucle(), bucle=True)
    guardar("escudo_golpe.wav", escudo_golpe())
    guardar("escudo_roto.wav", escudo_roto())
    guardar("aturdido.wav", aturdido())
    guardar("empujado.wav", empujado())
    guardar("secado.wav", secado())
    guardar("derretido.wav", derretido())
