#!/usr/bin/env python3
"""Sonidos de la SENSACIÓN DE LANZAR Y DE GOLPEAR (28/10, Juego; lote 1 de gamefeel). Python puro (sin numpy): `python audio/gen_sfx_sensacion.py`.
Mismo criterio que gen_sfx_reacciones.py (44,1 kHz, mono, 16 bits, igualado en RMS: el volumen real lo dice el CATALOGO de nucleo/sfx.gd).
  · lanzar_salida  el «fuuh» corto que acompaña a CUALQUIER hechizo al salir de la mano (capa común, debajo del sonido del elemento)
  · no_puedes      un golpe seco y apagado, como una tapa de libro que no abre: recarga, sin tinta, ahora no
  · aviso_ataque   dos notas cortas que suben: un enemigo marca el suelo antes de golpear (C3)
LOTE 2 (29/10; se generan después de los del lote 1 con el mismo azar, así aquellos salen iguales):
  · tiempo_tic      el «tic» de reloj de la esquiva perfecta (con tono 0,75 en Sfx.play es el «toc» del final)
  · reaccion_grande golpe grave con brillo que sube: vapor, descarga, congelado, hundido…
  · moneda          «ting» corto y brillante al recoger el oro
PRIMERA VERSIÓN SINTETIZADA: se afina escuchando."""
import math, os, random, struct, wave

SR = 44100
rng = random.Random(28102026)


def muestras(d):
    return int(SR * d)


def ruido(d):
    return [rng.uniform(-1.0, 1.0) for _ in range(muestras(d))]


def pasabajos(x, fc):
    a = 1.0 - math.exp(-2 * math.pi * fc / SR)
    y = []
    acc = 0.0
    for v in x:
        acc += a * (v - acc)
        y.append(acc)
    return y


def pasaaltos(x, fc):
    return [v - p for v, p in zip(x, pasabajos(x, fc))]


def guardar(nombre, x, rms_obj=0.12):
    m = sum(x) / len(x)
    x = [v - m for v in x]
    r = math.sqrt(sum(v * v for v in x) / len(x)) + 1e-9
    x = [v * rms_obj / r for v in x]
    pico = max(abs(v) for v in x)
    if pico > 0.95:
        x = [v * 0.95 / pico for v in x]
    fade = muestras(0.004)
    for i in range(fade):
        k = i / fade
        x[i] *= k
        x[-1 - i] *= k
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), nombre)
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in x))
    print(nombre, round(len(x) / SR, 2), "s")


def lanzar_salida():
    """Ruido filtrado con la envolvente de un soplo rápido (0,24 s) y un golpe grave al principio."""
    d = 0.24
    n = ruido(d)
    cuerpo = pasabajos(n, 900.0)
    aire = pasaaltos(pasabajos(n, 5000.0), 1200.0)
    x = []
    fase = 0.0
    for i in range(len(n)):
        tt = i / SR
        forma = math.sin(math.pi * min(tt / d, 1.0)) ** 1.5 * math.exp(-3.0 * tt)
        fase += 2 * math.pi * max(140.0 - 200.0 * tt, 40.0) / SR
        golpe = math.sin(fase) * math.exp(-40.0 * tt)
        x.append((0.6 * cuerpo[i] + 0.9 * aire[i]) * forma + 0.8 * golpe)
    guardar("lanzar_salida.wav", x, 0.13)


def no_puedes():
    """Un golpe sordo (seno grave que cae de tono) con un poco de ruido apagado: «clonc»."""
    d = 0.16
    r = pasabajos(ruido(d), 600.0)
    x = []
    fase = 0.0
    for i in range(muestras(d)):
        tt = i / SR
        fase += 2 * math.pi * 180.0 * math.exp(-6.0 * tt) / SR
        x.append(math.sin(fase) * math.exp(-28.0 * tt) + 0.5 * r[i] * math.exp(-45.0 * tt))
    guardar("no_puedes.wav", x, 0.14)


def aviso_ataque():
    """Dos notas cortas, la segunda más aguda (re → la), con armónicos para que se oiga por encima del combate."""
    def nota(fr, d):
        out = []
        for i in range(muestras(d)):
            tt = i / SR
            e = min(1.0, tt / 0.004) * math.exp(-14.0 * tt)
            out.append((math.sin(2 * math.pi * fr * tt) + 0.35 * math.sin(4 * math.pi * fr * tt) + 0.15 * math.sin(6 * math.pi * fr * tt)) * e)
        return out
    x = nota(587.0, 0.07) + [0.0] * muestras(0.015) + nota(880.0, 0.12)
    guardar("aviso_ataque.wav", x, 0.10)


def tiempo_tic():
    """Un clic de madera agudo (dos parciales inarmónicos que mueren muy deprisa) con un poco de ruido de golpe: el tic de un reloj de bolsillo."""
    d = 0.09
    r = pasaaltos(ruido(d), 2500.0)
    x = []
    for i in range(muestras(d)):
        tt = i / SR
        e = math.exp(-70.0 * tt)
        x.append((math.sin(2 * math.pi * 2300.0 * tt) + 0.6 * math.sin(2 * math.pi * 3710.0 * tt)) * e + 0.7 * r[i] * math.exp(-160.0 * tt))
    guardar("tiempo_tic.wav", x, 0.10)


def reaccion_grande():
    """Un golpe grave que cae de tono (el peso) y encima un brillo de tres notas que sube (la magia que se combina)."""
    d = 0.7
    r = pasabajos(ruido(d), 400.0)
    x = []
    fase = 0.0
    for i in range(muestras(d)):
        tt = i / SR
        fase += 2 * math.pi * (90.0 * math.exp(-4.0 * tt) + 35.0) / SR
        golpe = math.sin(fase) * math.exp(-5.0 * tt) + 0.6 * r[i] * math.exp(-12.0 * tt)
        brillo = 0.0
        for k, fr in enumerate((660.0, 880.0, 1320.0)):
            t0 = 0.05 + 0.07 * k
            if tt >= t0:
                u = tt - t0
                brillo += math.sin(2 * math.pi * fr * u) * min(1.0, u / 0.005) * math.exp(-6.0 * u) * 0.35
        x.append(golpe + brillo)
    guardar("reaccion_grande.wav", x, 0.14)


def moneda():
    """Dos campanadas muy cortas (si → mi agudo) con armónicos de metal."""
    def golpe(fr, d):
        out = []
        for i in range(muestras(d)):
            tt = i / SR
            e = min(1.0, tt / 0.002) * math.exp(-18.0 * tt)
            out.append((math.sin(2 * math.pi * fr * tt) + 0.5 * math.sin(2 * math.pi * fr * 2.76 * tt) + 0.25 * math.sin(2 * math.pi * fr * 5.4 * tt)) * e)
        return out
    x = golpe(1976.0, 0.05) + golpe(2637.0, 0.22)
    guardar("moneda.wav", x, 0.09)


if __name__ == "__main__":
    lanzar_salida()
    no_puedes()
    aviso_ataque()
    tiempo_tic()
    reaccion_grande()
    moneda()
