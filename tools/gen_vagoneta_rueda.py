"""Rodadura seca de vagoneta y roce continuo (25/11/2026).
Pablo: «Traqueteo seco de ruedas y juntas, con roce continuo de fondo».
Sin audio de YouTube: no se pudo escuchar la referencia. Síntesis propia,
sin muestras. Bucle de 6 s y tres juntas cortas de 0,14 s. Requiere numpy.
Uso: python tools/gen_vagoneta_rueda.py
"""
from pathlib import Path
import json
import wave
import numpy as np

SR = 44100
DUR = 6.0
N = round(SR * DUR)
RAIZ = Path(__file__).resolve().parents[1]
rng = np.random.default_rng(25112026)


def ruido_banda(n, lo, hi):
    """Filtro suave de una señal periódica: no corta colas en la costura."""
    f = np.fft.rfftfreq(n, 1 / SR)
    mascara = (1 - np.exp(-(f / lo) ** 4)) * np.exp(-(f / hi) ** 4)
    r = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * mascara, n)
    return r / max(float(np.sqrt(np.mean(r * r))), 1e-12)


def golpe(n, posicion, fuerza, cola):
    # Cola corta sin osciladores afinados ni resonancia sostenida.
    dt = np.mod(np.arange(n) / SR - posicion, n / SR)
    envolvente = (1 - np.exp(-dt / 0.0007)) * np.exp(-dt / cola)
    seco = ruido_banda(n, 260, 4200)
    cuerpo = ruido_banda(n, 90, 700)
    return fuerza * envolvente * (0.74 * seco + 0.26 * cuerpo)


def guardar(nombre, senal, pico):
    senal = senal - np.mean(senal)
    if '_loop' not in nombre:
        # Quitar DC después del fundido desplaza los extremos: devolverlos a cero.
        senal[0] = senal[-1] = 0.0
    senal *= pico / max(float(np.max(np.abs(senal))), 1e-12)
    ruta = RAIZ / 'audio' / nombre
    pcm = np.round(np.clip(senal, -1, 1) * 32767).astype('<i2')
    with wave.open(str(ruta), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return {'archivo': nombre, 'segundos': len(senal) / SR,
            'pico_dbfs': float(20 * np.log10(np.max(np.abs(senal)))),
            'rms_dbfs': float(20 * np.log10(np.sqrt(np.mean(senal ** 2)))),
            'salto_costura': float(abs(senal[0] - senal[-1]))}


def main():
    t = np.arange(N) / SR
    # Roce ancho y cuerpo discreto: no hay silbido agudo constante.
    variacion = 0.88 + 0.08 * np.sin(2 * np.pi * t / DUR * 5)
    roce = ruido_banda(N, 320, 3400) * 0.018 * variacion
    cuerpo = ruido_banda(N, 55, 280) * 0.010
    traqueteo = np.zeros(N)
    # Pares de holgura de ruedas/ejes, NO otras juntas de vía.
    # Las juntas se disparan en el juego al cruzar una casilla.
    for k in range(12):
        inicio = k * DUR / 12 + rng.uniform(-0.035, 0.035)
        fuerza = rng.uniform(0.12, 0.20)
        traqueteo += golpe(N, inicio, fuerza, rng.uniform(0.009, 0.017))
        traqueteo += golpe(N, inicio + rng.uniform(0.075, 0.11), fuerza * 0.62, 0.009)
    datos = [guardar('vagoneta_rueda_loop.wav', roce + cuerpo + traqueteo, 0.65)]
    for i in range(3):
        n = round(SR * 0.14)
        senal = golpe(n, 0.004, 1.0, 0.012 + i * 0.002)
        senal += golpe(n, 0.047 + i * 0.004, 0.45, 0.008)
        # Estos one-shots no vuelven sobre sí mismos: extremos suaves.
        fade = np.minimum(1, np.arange(n) / (SR * 0.002))
        fade *= np.minimum(1, np.arange(n)[::-1] / (SR * 0.014))
        datos.append(guardar(f'vagoneta_junta_{i}.wav', senal * fade, 0.62))
    print(json.dumps(datos, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
