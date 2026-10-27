#!/usr/bin/env python3
"""Pisadas SUAVES de la jugadora, sintetizadas (27/10; Pablo: «el sonido es muy fuerte, hay que buscar un sonido sutil»).

Genera en audio/ (o en la carpeta del primer argumento) paso_suave_hierba_0..5, paso_suave_tierra_0..5 y paso_suave_roca_0..5 (.wav).
Por qué otras y no bajar las de siempre: las de `gen_sonidos_ambiente.py` y las de Kenney llevan un golpe y un chasquido agudo que, aun
bajos, se oyen por encima de todo a cada paso. Estas son un toque grave y amortiguado (el peso del pie) con una textura muy leve del
suelo encima, sin nada por encima de ~3,5 kHz que pique, cortas (0,12-0,18 s) y con el pico bajo. Seis variantes por suelo para que
el ritmo no suene a máquina. Requiere numpy y scipy. La semilla es fija: relanzar da lo mismo.
"""
import os
import sys
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
rng = np.random.default_rng(20261027)


def bp(x, lo, hi, o=2):
    return sosfilt(butter(o, [lo, hi], 'band', fs=SR, output='sos'), x)


def lp(x, f, o=2):
    return sosfilt(butter(o, f, 'low', fs=SR, output='sos'), x)


def noise(n):
    return rng.standard_normal(n)


def norm(x, pico):
    return x / np.max(np.abs(x)) * pico


def fundido(x, ms=6):
    # sin clic al final: los últimos milisegundos bajan a cero
    k = int(ms / 1000 * SR)
    x[-k:] *= np.linspace(1, 0, k)
    return x


def toque(n, t, f0, dur):
    # el peso del pie: un golpe grave y blando (ataque de 6 ms, caída corta), sin el chasquido de arriba
    env = np.clip(t / 0.006, 0, 1) * np.exp(-t / dur)
    seno = np.sin(2 * np.pi * f0 * t * (1 - 0.25 * t / (n / SR)))
    golpe = lp(noise(n), 260, 2) * 0.6 + seno * 0.4
    return golpe * env


def paso_hierba(var):
    n = int(0.17 * SR)
    t = np.arange(n) / SR
    x = toque(n, t, 70 + 6 * var, 0.035) * 0.8
    # roce de briznas: ruido medio, sin agudos, que llega un poco después del peso
    env = np.clip((t - 0.01) / 0.03, 0, 1) * np.exp(-t / 0.05)
    x += bp(noise(n), 700 + 60 * var, 2600, 2) * env * 0.35
    return fundido(norm(lp(x, 3200, 2), 0.32))


def paso_tierra(var):
    n = int(0.14 * SR)
    t = np.arange(n) / SR
    x = toque(n, t, 80 + 5 * var, 0.03)
    # tierra suelta: un roce corto y grave
    x += bp(noise(n), 400, 1800, 2) * np.clip(t / 0.008, 0, 1) * np.exp(-t / 0.025) * 0.3
    return fundido(norm(lp(x, 3000, 2), 0.32))


def paso_roca(var):
    n = int(0.15 * SR)
    t = np.arange(n) / SR
    # roca: algo más firme y breve, con una resonancia media muy corta (sin el «clic» de antes)
    x = toque(n, t, 95 + 7 * var, 0.022)
    x += bp(noise(n), 900 + 80 * var, 2200 + 120 * var, 3) * np.clip(t / 0.004, 0, 1) * np.exp(-t / 0.018) * 0.4
    return fundido(norm(lp(x, 3500, 2), 0.34))


def wav(ruta, x):
    x = np.clip(x, -1, 1)
    i = (x * 32767).astype(np.int16)
    with wave.open(ruta, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(i.tobytes())


def main():
    salida = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', 'audio')
    os.makedirs(salida, exist_ok=True)
    for nombre, f in [('hierba', paso_hierba), ('tierra', paso_tierra), ('roca', paso_roca)]:
        for i in range(6):
            x = f(i)
            ruta = os.path.join(salida, f'paso_suave_{nombre}_{i}.wav')
            wav(ruta, x)
            print(os.path.basename(ruta), round(len(x) / SR, 2), 's', 'pico', round(float(np.max(np.abs(x))), 2),
                  'rms', round(float(np.sqrt(np.mean(x ** 2))), 3))


if __name__ == '__main__':
    main()
