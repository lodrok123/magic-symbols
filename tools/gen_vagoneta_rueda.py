"""Sintetiza audio/vagoneta_rueda_loop.wav (24/11/2026): la rodadura METÁLICA de la vagoneta sobre los raíles, en bucle sin costura.

Pablo: «sonido metálico al circular». No hay en el proyecto una grabación de vagoneta: se construye con tres capas:
  · retumbo: ruido grave filtrado (la caja de madera y el eje);
  · roce de rueda contra raíl: parciales inarmónicos de metal (como una barra que vibra) excitados a cada vuelta de rueda, con su decaimiento;
  · un leve chirrido agudo que sube y baja (la pestaña de la rueda contra el carril).
Todo en 2,0 s exactos, con el ruido hecho periódico (se repite igual al final y al principio): el bucle no hace clic. El tono lo cambia el juego con la
velocidad (Vagoneta3D). Uso (desde la raíz del repo):  python tools/gen_vagoneta_rueda.py
"""
import os
import wave
import numpy as np
from scipy.signal import butter, sosfiltfilt

SR = 44100
DUR = 2.0
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(7)


def ruido_periodico(lo, hi):
	"""Ruido de banda [lo, hi] Hz que encaja consigo mismo al repetirse (se filtra en el dominio de la frecuencia)."""
	espectro = np.fft.rfft(rng.standard_normal(N))
	f = np.fft.rfftfreq(N, 1 / SR)
	espectro[(f < lo) | (f > hi)] = 0
	r = np.fft.irfft(espectro, N)
	return r / (np.abs(r).max() + 1e-9)


# 24/11, playtest de Pablo: «más metálico». Menos retumbo, metal más fuerte, más agudo y que resuena más, y más roce de rueda contra carril.
# 1 · retumbo grave
retumbo = ruido_periodico(40, 220) * 0.12

# 2 · golpes de rueda: una excitación por vuelta (6 por segundo = 12 en el bucle) que hace sonar parciales de metal
vueltas = 12
metal = np.zeros(N)
parciales = [(612, 0.8, 5.0), (1180, 0.9, 6.0), (1733, 0.8, 7.0), (2650, 0.65, 8.0), (3910, 0.5, 10.0), (5240, 0.35, 12.0), (6870, 0.22, 15.0)]
for k in range(vueltas):
	t0 = k / vueltas * DUR + rng.uniform(-0.01, 0.01)
	fuerza = rng.uniform(0.6, 1.0)
	for reps in (0, 1):                                  # también la cola que da la vuelta al final del bucle
		dt = (t - t0 + reps * DUR)
		mask = dt >= 0
		for fr, a, dec in parciales:
			metal[mask] += fuerza * a * np.sin(2 * np.pi * fr * rng.uniform(0.985, 1.015) * dt[mask]) * np.exp(-dec * dt[mask])
metal *= 0.55 / (np.abs(metal).max() + 1e-9)

# 3 · chirrido de pestaña: un tono agudo que oscila suave (periódico en 2 s), con su armónico
fase = 2 * np.pi * (2900 * t + 120 / (2 * np.pi * 0.5) * np.sin(2 * np.pi * 0.5 * t))
chirrido = (np.sin(fase) + 0.4 * np.sin(2 * fase)) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.0 * t)) ** 2
chirrido *= 0.09

# 4 · roce de hierro contra hierro: ruido agudo pegado al metal
roce = ruido_periodico(2500, 8000) * 0.12

senal = retumbo + metal + chirrido + roce
sos = butter(2, 12000, "low", fs=SR, output="sos")
senal = sosfiltfilt(sos, np.concatenate([senal, senal, senal]))[N:2 * N]   # filtrado circular: sin costura
senal = senal / (np.abs(senal).max() + 1e-9) * 0.8

ruta = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio", "vagoneta_rueda_loop.wav")
with wave.open(ruta, "wb") as w:
	w.setnchannels(1)
	w.setsampwidth(2)
	w.setframerate(SR)
	w.writeframes((senal * 32767).astype(np.int16).tobytes())
print("escrito", ruta, "%.2f s" % DUR, "salto en la costura: %.4f" % abs(senal[0] - senal[-1]))
