#!/usr/bin/env python3
"""Sonidos por fase del conjuro V2 (18/10, Pipeline; los pide el diario 160 y los confirma el 162). Síntesis con numpy, sin dependencias:
`python audio/gen_sfx_hechizos.py`. Mismo criterio que gen_sfx_puzles.py: lo mágico no existe grabado, se inventa, y sale igualado en RMS
(el volumen real lo dice el CATALOGO de nucleo/sfx.gd). 44,1 kHz, mono, 16 bits.

  <elemento>_carga   (7)  lo que suena mientras el libro carga el hechizo (fase «runa» del conjuro): un gesto que SUBE y se queda tenso, 0,6-0,8 s,
                          con el timbre de cada elemento para que el oído sepa cuál se está cargando antes de verlo.
  x_mano_impacto, alto_impacto, abajo_impacto (3)  cuando el volumen se materializa, según el nombre derivado de la receta (GeometriaV2.nombre_derivado):
                          x_mano = golpe seco de lado, alto = cae desde arriba (silbido que baja y golpe), abajo = losa pesada contra el suelo.
`<elemento>_disparo` NO se genera: sigue sonando el `elem_*` de siempre."""
import wave, os
import numpy as np

SR = 44100
rng = np.random.default_rng(18102026)


def t(d):
    return np.arange(int(SR * d)) / SR


def ruido(d):
    return rng.uniform(-1, 1, int(SR * d))


def pasabajos(x, fc):
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def pasaaltos(x, fc):
    return x - pasabajos(x, fc)


def banda(x, fc, ancho):
    """Paso de banda barato: pasa-altos(fc - ancho) sobre pasa-bajos(fc + ancho). `fc` puede ser un barrido (array)."""
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    return pasaaltos(pasabajos(x, fc + ancho), np.maximum(fc - ancho, 20.0))


def seno_barrido(f):
    """Seno cuya frecuencia instantánea es el array `f` (Hz): integra la fase."""
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def sube(n, d, k=2.0):
    """Rampa 0..1 con curva (k > 1: arranca despacio y acaba rápido)."""
    return (np.arange(n) / max(n - 1, 1)) ** k


def entra_sale(n, ataque, cola):
    """Envolvente que sube `ataque` s, se mantiene y se apaga en `cola` s (para que la carga acabe tensa pero sin clic)."""
    tt = np.arange(n) / SR
    d = n / SR
    return np.minimum(1.0, tt / max(ataque, 1e-4)) * np.minimum(1.0, (d - tt) / max(cola, 1e-4))


def guardar(nombre, x, rms_obj=0.08):
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


# ------------------------------------------------------------------------------------------------ cargas
def fuego_carga():
    d = 0.7; n = int(SR * d); s = sube(n, d)
    llama = banda(ruido(d), 350 + 650 * s, 250) * (0.5 + 0.5 * s)
    crep = (rng.uniform(0, 1, n) > 0.9985).astype(float)                    # chasquidos sueltos
    crep = pasaaltos(pasabajos(np.convolve(crep, np.exp(-np.arange(400) / 40.0))[:n], 5000), 800) * 3.0
    grave = seno_barrido(110 + 110 * s) * 0.35
    return (llama + crep + grave) * entra_sale(n, 0.12, 0.06)


def agua_carga():
    d = 0.7; n = int(SR * d); s = sube(n, d, 1.5)
    burb = np.zeros(n)
    for _ in range(26):                                                      # burbujas: chirridos cortos que suben, cada vez más seguidas
        c = int(rng.uniform(0, 1) ** 0.7 * (n - 3000))
        f0 = rng.uniform(300, 700) * (1 + 0.8 * c / n)
        tb = np.arange(2600) / SR
        burb[c:c + 2600] += np.sin(2 * np.pi * (f0 * tb + 2200 * tb ** 2)) * np.exp(-tb * 38) * rng.uniform(0.4, 1.0)
    manto = banda(ruido(d), 500 + 700 * s, 400) * 0.35 * s
    return (burb + manto) * entra_sale(n, 0.08, 0.06)


def hielo_carga():
    d = 0.8; n = int(SR * d); s = sube(n, d, 1.6); tt = t(d)
    x = np.zeros(n)
    for k, f in enumerate([2093, 2637, 3136, 3951, 4699]):                    # parciales de cristal, entran de uno en uno
        ent = np.clip((s - 0.12 * k) * 4, 0, 1)
        x += np.sin(2 * np.pi * f * (1 + 0.03 * s) * tt + k) * ent * (0.8 / (1 + k * 0.4)) * (0.7 + 0.3 * np.sin(2 * np.pi * (7 + 2 * k) * tt))
    x += pasaaltos(ruido(d), 6000) * 0.12 * s                                  # escarcha
    return x * entra_sale(n, 0.15, 0.06)


def rayo_carga():
    d = 0.6; n = int(SR * d); s = sube(n, d, 2.2); tt = t(d)
    zumbido = (2 * ((60 + 160 * s) * tt % 1.0) - 1) * 0.5
    zumbido = pasabajos(zumbido, 2500)
    chisp = np.zeros(n)
    for _ in range(int(14 + 40 * 1)):                                          # chispazos cada vez más densos hacia el final
        c = int(rng.uniform(0, 1) ** 0.5 * (n - 1500))
        chisp[c:c + 1200] += pasaaltos(ruido(1200 / SR), 2500) * np.exp(-np.arange(1200) / 160.0) * rng.uniform(0.5, 1.4)
    return (zumbido * (0.3 + 0.7 * s) + chisp * 0.8) * entra_sale(n, 0.05, 0.05)


def viento_carga():
    d = 0.8; n = int(SR * d); s = sube(n, d, 1.4)
    x = banda(ruido(d), 250 + 1100 * s, 200 + 300 * s)
    x += 0.4 * banda(ruido(d), 120 + 500 * s, 100)
    return x * (0.25 + 0.75 * s) * entra_sale(n, 0.2, 0.08)


def tierra_carga():
    d = 0.8; n = int(SR * d); s = sube(n, d, 1.3)
    ret = pasabajos(ruido(d), 140 + 200 * s) * 2.0                            # retumbo
    grave = seno_barrido(48 + 36 * s) * 0.9
    grava = (rng.uniform(0, 1, n) > 0.9992).astype(float)                      # guijarros que se mueven
    grava = pasabajos(np.convolve(grava, np.exp(-np.arange(900) / 120.0))[:n], 1800) * 5.0 * s
    return (ret + grave + grava) * entra_sale(n, 0.15, 0.08)


def tiempo_carga():
    d = 0.8; n = int(SR * d); s = sube(n, d, 1.2); tt = t(d)
    x = np.zeros(n)
    for k, f in enumerate([330, 495, 660]):                                    # campana a medias, desafinada hacia arriba (el tiempo «tensándose»)
        x += np.sin(2 * np.pi * np.cumsum(f * (1 + 0.12 * s + 0.004 * k * np.sin(2 * np.pi * 5 * tt))) / SR) * (0.6 / (1 + k))
    tic = np.zeros(n)
    paso = int(SR * 0.16)
    for c in range(0, n - 800, paso):                                          # tic-tic que se acelera
        tic[c:c + 800] += np.sin(2 * np.pi * 1800 * np.arange(800) / SR) * np.exp(-np.arange(800) / 90.0)
        paso = max(int(paso * 0.93), int(SR * 0.05))
    return (x * 0.6 + tic * 0.5) * entra_sale(n, 0.12, 0.07)


# ------------------------------------------------------------------------------------------------ impactos
def x_mano_impacto():
    d = 0.5; n = int(SR * d); tt = t(d)
    cuerpo = seno_barrido(150 * np.exp(-9 * tt) + 55) * np.exp(-9 * tt)
    golpe = pasaaltos(ruido(d), 900) * np.exp(-tt * 60) * 0.8
    cola = pasabajos(ruido(d), 500) * np.exp(-tt * 12) * 0.5
    return cuerpo * 1.2 + golpe + cola


def alto_impacto():
    d = 0.8; n = int(SR * d); tt = t(d)
    sil = banda(ruido(d), 2400 * np.exp(-tt * 9) + 250, 250) * np.exp(-tt * 7) * 0.9                       # silbido que baja…
    boom = seno_barrido(90 * np.exp(-3.5 * tt) + 38) * np.clip((tt - 0.12) * 80, 0, 1) * np.exp(-(tt - 0.12).clip(0) * 5)  # …y golpe a los 0,12 s
    gol = pasaaltos(ruido(d), 700) * np.clip((tt - 0.12) * 200, 0, 1) * np.exp(-(tt - 0.12).clip(0) * 40) * 0.8
    return sil + boom * 1.4 + gol


def abajo_impacto():
    d = 0.9; n = int(SR * d); tt = t(d)
    losa = seno_barrido(70 * np.exp(-4 * tt) + 30) * np.exp(-4.5 * tt)
    grava = pasabajos(ruido(d), 1500) * np.exp(-tt * 14) * 0.9
    crujido = pasaaltos(ruido(d), 1200) * np.exp(-tt * 40) * 0.5
    tierra = pasabajos(ruido(d), 220) * np.exp(-tt * 6) * 1.2
    return losa * 1.3 + grava + crujido + tierra


if __name__ == "__main__":
    for nombre, f in [("fuego", fuego_carga), ("agua", agua_carga), ("hielo", hielo_carga), ("rayo", rayo_carga),
                      ("viento", viento_carga), ("tierra", tierra_carga), ("tiempo", tiempo_carga)]:
        guardar("%s_carga.wav" % nombre, f())
    guardar("x_mano_impacto.wav", x_mano_impacto())
    guardar("alto_impacto.wav", alto_impacto())
    guardar("abajo_impacto.wav", abajo_impacto())
