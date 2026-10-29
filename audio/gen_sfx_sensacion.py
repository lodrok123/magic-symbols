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
LOTE 3 (29/10; después de los anteriores, que salen iguales):
  · combate_loop    capa de combate en BUCLE (4 compases a 110 ppm, la menor): tambor grave, tom, sonajero y un bajo pulsado; empieza y acaba en silencio
                    de golpe para que el bucle no se note (lo pone en bucle Sfx.flujo_en_bucle)
  · sala_limpia     remate al caer el último del combate: golpe de tambor y arpegio que sube (la-do-mi-la)
LOTE 4 (29/10; después de los anteriores, que salen iguales):
  · golpe_carne_0/1   el cuerpo de un enemigo que encaja un hechizo: golpe sordo corto (dos variantes; Sfx varía el tono)
  · golpe_piedra      el gólem que encaja un golpe: toc de piedra
  · limo_golpe        el limo que encaja un golpe: chapoteo gelatinoso corto
  · limo_muere        el limo que revienta: chapoteo largo con burbujas
  · dano_jugadora     la jugadora encaja un golpe: «uf» sordo y grave
  · latido            un latido de corazón EN BUCLE (1 s): suena con la vida baja (lo pone en bucle Sfx.flujo_en_bucle)
  · voltereta         roce de tela rápido de la voltereta
  · recarga_lista     clic suave: una página o la voltereta vuelven a estar listas
  · golpe_mundo       un proyectil que se para contra una pared o un bloque: toc sordo
  · carga_bucle       aro que se cierra en la mano mientras se mantiene 1/2/3 (bucle; el Lanzador le sube el tono)
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


def combate_loop():
    """4 compases de 4/4 a 110 ppm. Todo se suma en una lista y cada golpe se escribe con su envolvente; lo que se sale del final se
    vuelve a sumar al principio (así el bucle no corta colas)."""
    ppm = 110.0
    negra = 60.0 / ppm
    n = muestras(negra * 16)
    x = [0.0] * n

    def poner(t0, sonido):
        i0 = int(t0 * SR)
        for k, v in enumerate(sonido):
            x[(i0 + k) % n] += v

    def tambor(fr0, fr1, d, cae, vol):
        out = []
        fase = 0.0
        for i in range(muestras(d)):
            tt = i / SR
            fase += 2 * math.pi * (fr1 + (fr0 - fr1) * math.exp(-cae * tt)) / SR
            out.append(math.sin(fase) * min(1.0, tt / 0.002) * math.exp(-7.0 * tt) * vol)
        return out

    def sonajero(vol):
        r = pasaaltos(ruido(0.06), 5000.0)
        return [v * math.exp(-60.0 * (i / SR)) * vol for i, v in enumerate(r)]

    def bajo(fr, d, vol):
        out = []
        for i in range(muestras(d)):
            tt = i / SR
            e = min(1.0, tt / 0.004) * math.exp(-9.0 * tt)
            v = math.sin(2 * math.pi * fr * tt) + 0.35 * math.sin(2 * math.pi * fr * 2 * tt) + 0.15 * math.sin(2 * math.pi * fr * 3 * tt)
            out.append(v * e * vol)
        return out

    grave = tambor(95.0, 48.0, 0.5, 18.0, 1.0)
    tom = tambor(180.0, 120.0, 0.25, 25.0, 0.45)
    # Tambor grave: 1, «y» del 2, 3 (y en el 4.º compás un redoble al final).
    for c in range(4):
        t_c = c * 4 * negra
        for b in (0.0, 1.5, 2.0):
            poner(t_c + b * negra, grave)
        for b in (1.0, 3.0):
            poner(t_c + b * negra, tom)
        if c == 3:
            for b in (3.25, 3.5, 3.75):
                poner(t_c + b * negra, tom)
    # Sonajero en corcheas, el contratiempo más fuerte.
    for i in range(32):
        poner(i * negra * 0.5, sonajero(0.22 if i % 2 else 0.12))
    # Bajo: la la do la · la la mi sol (en corcheas, notas de 0,22 s).
    la, do, mi, sol = 55.0, 65.41, 82.41, 98.0
    figura = [la, la, la, do, la, la, mi, sol]
    for c in range(4):
        for i, fr in enumerate(figura):
            if c % 2 == 1 and i == 7:
                fr = mi
            poner((c * 4 + i * 0.5) * negra, bajo(fr, 0.22, 0.5))
    # La guardar normal funde 4 ms al principio y al final, que en un bucle no hace falta pero tampoco se oye.
    guardar("combate_loop.wav", x, 0.10)


def sala_limpia():
    """Un golpe de tambor y un arpegio de campana que sube: se acabó."""
    d = 1.3
    x = [0.0] * muestras(d)
    fase = 0.0
    for i in range(muestras(0.6)):
        tt = i / SR
        fase += 2 * math.pi * (110.0 * math.exp(-15.0 * tt) + 50.0) / SR
        x[i] += math.sin(fase) * math.exp(-6.0 * tt) * 0.8
    for k, fr in enumerate((440.0, 523.25, 659.25, 880.0)):
        i0 = muestras(0.04 + 0.09 * k)
        for i in range(muestras(d) - i0):
            u = i / SR
            e = min(1.0, u / 0.004) * math.exp(-3.5 * u) * (0.3 if k < 3 else 0.42)
            x[i0 + i] += (math.sin(2 * math.pi * fr * u) + 0.3 * math.sin(2 * math.pi * fr * 2.01 * u)) * e
    guardar("sala_limpia.wav", x, 0.12)


def _golpe_sordo(nombre, d, f0, f1, caida, ruido_k, fc, rms):
    """Seno que baja de f0 a f1 con ruido filtrado encima: el esqueleto de todos los golpes sordos."""
    n = pasabajos(ruido(d), fc)
    x = []
    fase = 0.0
    for i in range(muestras(d)):
        tt = i / SR
        fase += 2 * math.pi * (f1 + (f0 - f1) * math.exp(-caida * tt)) / SR
        e = math.exp(-14.0 * tt) * min(1.0, tt / 0.003)
        x.append(math.sin(fase) * e + ruido_k * n[i] * math.exp(-22.0 * tt))
    guardar(nombre, x, rms)


def golpe_carne():
    _golpe_sordo("golpe_carne_0.wav", 0.16, 220.0, 70.0, 40.0, 0.9, 1800.0, 0.14)
    _golpe_sordo("golpe_carne_1.wav", 0.15, 190.0, 65.0, 45.0, 1.1, 1400.0, 0.14)


def golpe_piedra():
    """Toc de piedra: golpe muy corto con dos parciales inarmónicos y un poco de ruido alto."""
    d = 0.18
    n = pasaaltos(ruido(d), 2500.0)
    x = []
    for i in range(muestras(d)):
        tt = i / SR
        e = math.exp(-28.0 * tt)
        x.append((math.sin(2 * math.pi * 410.0 * tt) * 0.7 + math.sin(2 * math.pi * 1130.0 * tt) * 0.35) * e + 0.5 * n[i] * math.exp(-60.0 * tt))
    guardar("golpe_piedra.wav", x, 0.14)


def _chapoteo(nombre, d, burbujas, rms):
    n = pasabajos(ruido(d), 700.0)
    x = []
    fase = 0.0
    for i in range(muestras(d)):
        tt = i / SR
        fase += 2 * math.pi * (90.0 + 60.0 * math.sin(2 * math.pi * 9.0 * tt)) / SR
        e = math.sin(math.pi * min(tt / d, 1.0)) ** 0.7 * math.exp(-5.0 * tt)
        x.append(0.6 * math.sin(fase) * e + 1.2 * n[i] * e)
    for k in range(burbujas):
        t0 = rng.uniform(0.02, d - 0.08)
        fr = rng.uniform(500.0, 1400.0)
        i0 = muestras(t0)
        for i in range(muestras(0.06)):
            u = i / SR
            if i0 + i < len(x):
                x[i0 + i] += math.sin(2 * math.pi * (fr * (1.0 + 2.0 * u)) * u) * math.exp(-45.0 * u) * 0.35
    guardar(nombre, x, rms)


def limo_golpe():
    _chapoteo("limo_golpe.wav", 0.22, 2, 0.12)


def limo_muere():
    _chapoteo("limo_muere.wav", 0.7, 9, 0.13)


def dano_jugadora():
    """«Uf» sordo: golpe grave con un soplo de aire que se apaga."""
    d = 0.3
    aire = pasaaltos(pasabajos(ruido(d), 2200.0), 500.0)
    x = []
    fase = 0.0
    for i in range(muestras(d)):
        tt = i / SR
        fase += 2 * math.pi * (160.0 * math.exp(-18.0 * tt) + 55.0) / SR
        x.append(math.sin(fase) * math.exp(-10.0 * tt) * min(1.0, tt / 0.004) + 0.7 * aire[i] * math.exp(-9.0 * (tt - 0.03)) * (1.0 if tt > 0.03 else 0.0))
    guardar("dano_jugadora.wav", x, 0.14)


def latido():
    """Un ciclo de corazón (lub-dub) en 1,0 s exactos, grave y sordo; empieza y acaba en silencio para el bucle."""
    d = 1.0
    x = [0.0] * muestras(d)
    for t0, fuerza in ((0.0, 1.0), (0.17, 0.65)):
        i0 = muestras(t0)
        fase = 0.0
        for i in range(muestras(0.16)):
            u = i / SR
            fase += 2 * math.pi * (70.0 * math.exp(-12.0 * u) + 40.0) / SR
            if i0 + i < len(x):
                x[i0 + i] += math.sin(fase) * math.exp(-16.0 * u) * min(1.0, u / 0.004) * fuerza
    guardar("latido.wav", x, 0.09)


def voltereta():
    """Roce de tela: ruido en banda media con una envolvente de soplo que sube de tono."""
    d = 0.32
    n = pasaaltos(pasabajos(ruido(d), 3200.0), 700.0)
    x = []
    for i in range(muestras(d)):
        tt = i / SR
        e = math.sin(math.pi * min(tt / d, 1.0)) ** 1.3
        x.append(n[i] * e)
    guardar("voltereta.wav", x, 0.09)


def recarga_lista():
    """Clic suave: dos parciales cortos, como un cierre de madera pequeño."""
    d = 0.09
    x = []
    for i in range(muestras(d)):
        tt = i / SR
        e = math.exp(-50.0 * tt)
        x.append((math.sin(2 * math.pi * 1450.0 * tt) * 0.6 + math.sin(2 * math.pi * 2900.0 * tt) * 0.25) * e)
    guardar("recarga_lista.wav", x, 0.10)


def golpe_mundo():
    _golpe_sordo("golpe_mundo.wav", 0.2, 150.0, 55.0, 35.0, 0.7, 900.0, 0.13)


def carga_bucle():
    """Zumbido en bucle (0,5 s): un acorde de dos senos con un leve temblor; el Lanzador le sube el tono mientras se mantiene la tecla."""
    d = 0.5
    x = []
    for i in range(muestras(d)):
        tt = i / SR
        trem = 1.0 + 0.12 * math.sin(2 * math.pi * 7.0 * tt)
        x.append((math.sin(2 * math.pi * 196.0 * tt) * 0.6 + math.sin(2 * math.pi * 293.7 * tt) * 0.35 + math.sin(2 * math.pi * 392.0 * tt) * 0.15) * trem)
    guardar("carga_bucle.wav", x, 0.09)


if __name__ == "__main__":
    lanzar_salida()
    no_puedes()
    aviso_ataque()
    tiempo_tic()
    reaccion_grande()
    moneda()
    combate_loop()
    sala_limpia()
    golpe_carne()
    golpe_piedra()
    limo_golpe()
    limo_muere()
    dano_jugadora()
    latido()
    voltereta()
    recarga_lista()
    golpe_mundo()
    carga_bucle()
