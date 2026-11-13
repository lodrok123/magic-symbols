"""Recorta, pasa a mono 44,1 kHz, iguala el pico y escribe en audio/ los sonidos elegidos del lote GDC 2026 de Sonniss (prefijo sn_).
Uso: python procesa_sonniss.py <carpeta sonniss_gdc2026> <carpeta audio del juego>"""
import os, sys, struct
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly
from math import gcd

BASE = "\\\\?\\" + os.path.abspath(sys.argv[1])
DEST = os.path.abspath(sys.argv[2])
SR = 44100
PICO_DB = -3.0

# destino (sin extensión): (trozo del nombre de la carpeta, trozo del nombre del archivo, ini_s, fin_s o None, fundido de salida en s)
ELEGIDOS = {
    "sn_golpe_carne_0": ("Cinematic Fight", "4 x Punch, Body", 0.13, 0.54, 0.04),
    "sn_golpe_carne_1": ("Cinematic Fight", "4 x Punch, Body", 1.11, 1.58, 0.04),
    "sn_golpe_carne_2": ("Cinematic Fight", "4 x Punch, Body", 2.15, 2.57, 0.04),
    "sn_golpe_carne_3": ("Cinematic Fight", "4 x Punch, Body", 3.15, 3.65, 0.04),
    "sn_dano_jugadora_0": ("British Female Detective", "Pain Vocal Female Dying", 0.0, 0.68, 0.05),
    "sn_goblin_grito_0": ("Humanoid Creatures", "Screeching Breath Inhale", 0.0, 0.94, 0.08, 1.18),
    "sn_goblin_grito_1": ("Humanoid Creatures", "Orc Male Attack", 0.02, 1.25, 0.25, 1.18),
    "sn_goblin_grito_2": ("Vox Bestiae", "Violent Humanoid Creature Exhale", 0.0, 1.0, 0.15, 1.18),
    "sn_goblin_muere_0": ("Humanoid Creatures", "Flutter Death", 0.0, 2.3, 0.5, 1.45),
    "sn_hielo_quiebra_0": ("Designed Ice", "ice block snapping", 0.50, 2.0, 0.5),
    "sn_hielo_quiebra_1": ("Designed Ice", "fissure, fast, hard", 0.31, 1.8, 0.5),
    "sn_hielo_quiebra_2": ("Designed Ice", "block of ice crushed", 0.10, 1.7, 0.5),
    "sn_derrumbe_0": ("Colossal Impacts", "Woosh Debris", 0.08, 1.88, 0.25),
    "sn_explosion_0": ("Anime Game", "Explosion Small Blast", 0.01, 1.14, 0.15),
    "sn_hundido_burbujas_0": ("Elemental Mutation", "Water Deep Submerge", 0.02, 1.88, 0.25),
    "sn_limo_golpe_0": ("Tower Defense", "Blood Spill Splat", 0.0, 0.31, 0.03),
    "sn_limo_muere_0": ("Halloween", "Gore Designed Transient", 0.0, 1.33, 0.2),
    "sn_voltereta_0": ("Foley T-Shirt", "ClothMovement24", 0.02, 0.62, 0.2),
    "sn_voltereta_1": ("Foley T-Shirt", "ClothMovement24", 1.31, 1.91, 0.2),
    "sn_voltereta_2": ("Foley T-Shirt", "ClothMovement29", 0.0, 0.62, 0.2),

    # --- 13/11: segunda tanda. Sexto dato = tono (1.0 = sin tocar); séptimo = opciones: «como» iguala el RMS al archivo que sustituye, «bucle» = s de fundido cruzado para que enlace.
    # Elegidos por el nombre del archivo y por su forma de onda (dónde está el golpe, cuánto dura), NO de oído: se validan escuchando docs/escucha_sonniss.html.
    # Sustituyen a un sonido sintetizado:
    "sn_siseo_apagado_0": ("Campfire - Bonfire", "Putting Out Fire", 3.0, 4.8, 0.7, 1.0, {"como": "siseo_apagado.wav"}),
    "sn_chispazo_0": ("InMotionAudio - Arc", "ArcDesign15", 0.0, 0.96, 0.3, 1.0, {"como": "chispazo.wav"}),
    "sn_rayo_carga_0": ("InMotionAudio - Arc", "ArcPowerUpDesign04", 4.6, 5.5, 0.1, 1.0, {"como": "rayo_carga.wav"}),
    "sn_zumbido_electrico_0": ("InMotionAudio - Arc", "Buzz27", 3.0, 4.1, 0.25, 1.0, {"como": "zumbido_electrico.wav"}),
    "sn_viento_0": ("Elemental Palette", "Wind, Rush", 0.0, None, 0.25, 1.0, {"como": "elem_viento.wav"}),
    "sn_magma_0": ("Elemental Mutation", "Whoosh Fire Deep", 0.1, 1.9, 0.4, 1.0, {"como": "elem_fuego.wav"}),
    "sn_salpicadura_0": ("Elemental Palette", "Liquid Impact", 0.1, 0.9, 0.2, 1.0, {"como": "salpicadura.wav"}),
    "sn_hielo_rompe_0": ("Tower Defense", "Skill Freeze", 0.02, 1.64, 0.4, 1.0, {"como": "hielo_rompe.wav"}),
    "sn_escudo_roto_0": ("Elemental Mutation", "Glass Crystal", 0.9, 2.3, 0.4, 1.0, {"como": "escudo_roto.wav"}),
    "sn_escudo_golpe_0": ("HD Game Materials", "Old File Impact", 0.1, 0.42, 0.1, 1.0, {"como": "escudo_golpe.wav"}),
    "sn_dano_0": ("Anime Game", "Combat Punch", 0.0, 0.45, 0.15, 1.0, {"como": "dano.wav"}),
    "sn_no_puedes_0": ("UI Interaction", "Deny Muted", 0.0, 0.45, 0.1, 1.0, {"como": "no_puedes.wav"}),
    "sn_moneda_0": ("UI Interaction", "Ting Coins", 0.04, 0.7, 0.15, 1.0, {"como": "kenney_monedas_1.ogg"}),
    "sn_moneda_1": ("Hybrid Game", "Coin Flip", 0.0, 0.76, 0.15, 1.0, {"como": "kenney_monedas_1.ogg"}),
    "sn_logro_acierto_0": ("Design - User Interface", "Plucks Happy", 0.0, 0.7, 0.15, 1.0, {"como": "logro_acierto.wav"}),
    "sn_objetivo_cumplido_0": ("Hybrid Game", "Game Entry Happy", 0.0, 0.45, 0.15, 1.0, {"como": "objetivo_cumplido.wav"}),
    "sn_logro_brillo_0": ("Design - User Interface", "Arp Twinkle", 0.0, 1.3, 0.3, 1.0, {"como": "logro_brillo.wav"}),
    "sn_cofre_revelado_0": ("CB_Sounddesign", "Magic Creation", 0.15, 2.2, 0.7, 1.0, {"como": "cofre_revelado.wav"}),
    "sn_bolsa_0": ("Fantasy Game 2", "Inventory Open", 0.02, 0.56, 0.1, 1.0, {"como": "kenney_bolsa_tela.ogg"}),
    "sn_aturdido_0": ("Cartoon Bloopers", "Confused Dizzy", 0.0, 0.85, 0.2, 1.0, {"como": "aturdido.wav"}),
    "sn_reaccion_grande_0": ("Colossal Impacts", "Impact Cut Sweep", 0.86, 1.6, 0.3, 1.0, {"como": "reaccion_grande.wav"}),
    "sn_barrido_0": ("Scratch Card", "SurfaceWipe", 0.36, 0.98, 0.15, 1.0, {"como": "barrido.wav"}),
    "sn_recarga_lista_0": ("USA Hotel", "LightSwitch_On", 0.0, 0.16, 0.05, 1.0, {"como": "recarga_lista.wav"}),
    "sn_muerte_0": ("Cartoon & Animation", "Transition Bass Down", 0.2, 2.4, 0.8, 1.0, {"como": "muerte.wav"}),
    "sn_tiempo_tic_0": ("Antique Clocks", "Crooked Antique", 0.97, 1.26, 0.05, 1.0, {"como": "tiempo_tic.wav"}),
    "sn_boton_clic_0": ("HD Lock", "Latch Button", 0.0, 0.2, 0.05, 1.0, {"como": "boton_clic.wav"}),
    "sn_amb_bosque_0": ("Highlands of Norway", "Meadow Pipits", 30.0, 52.0, 0.0, 1.0, {"como": "amb_bosque_loop.wav", "bucle": 2.0}),
    "sn_amb_grillos_0": ("East Coast America", "Forest Crickets", 25.0, 47.0, 0.0, 1.0, {"como": "amb_grillos_loop.wav", "bucle": 2.0}),
    "sn_amb_cueva_0": ("Chimney Wind", "ChimneyWind05", 40.0, 62.0, 0.0, 1.0, {"como": "amb_cueva_loop.wav", "bucle": 2.0}),
    # Acciones que no sonaban (nombres nuevos del catálogo):
    "sn_tinta_sube_0": ("Anime Game", "Power Up Bright", 0.02, 1.3, 0.3),
    "sn_sintetizar_0": ("Fantasy Game 2", "Magic Light Spell", 0.0, 1.7, 0.6),
    "sn_flecha_clava_0": ("Cartoon Bloopers", "Arrow Hit Rattle", 0.0, 0.85, 0.2),
    "sn_aterrizar_0": ("Foley T-Shirt", "SinglePats04", 0.04, 0.36, 0.08),
    "sn_salto_0": ("Ultra Transitions", "Woosh Sweep Slide", 0.0, 0.22, 0.08),
    "sn_golem_rugido_0": ("Dinosaurs Vol. 2", "Large Herbivore Roar", 0.9, 2.6, 0.5),
    "sn_jefe_rugido_0": ("Dinosaurs Vol. 1", "T Rex", 3.6, 5.6, 0.6),
    "sn_limo_divide_0": ("Cartoon & Animation", "Bubbles Short", 0.0, 0.5, 0.1),
    "sn_trueno_0": ("Interior Wind Rain", "Thunder Rumble", 5.6, 9.0, 1.5),
    # --- 13/11, tercera tanda: pistas elegidas por Pablo de oído (él dijo cuál va con qué; los recortes dentro de cada pista son por forma de onda).
    "sn_puzle_resuelto_0": ("UI Interaction", "Accept Boing Crunch", 0.0, 0.8, 0.15, 1.0, {"como": "puzle_resuelto.wav"}),
    "sn_loberno_ladrido_0": ("Dog Vocalisations", "Dog Barks", 0.2, 0.7, 0.15),
    "sn_loberno_ladrido_1": ("Dog Vocalisations", "Dog Barks", 1.6, 2.1, 0.15),
    "sn_loberno_ladrido_2": ("Dog Vocalisations", "Dog Barks", 3.48, 4.0, 0.15),
    "sn_loberno_muere_0": ("Dog Vocalisations", "Dog Shuffle", 0.28, 2.2, 0.6),
    "sn_impacto_suelo_0": ("Melee Weapons", "SWING IMPACTS", 0.0, 1.3, 0.3),
    "sn_impacto_suelo_1": ("Melee Weapons", "SWING IMPACTS", 2.7, 4.2, 0.3),
    "sn_impacto_suelo_2": ("Melee Weapons", "SWING IMPACTS", 5.7, 7.2, 0.3),
    "sn_impacto_suelo_3": ("Melee Weapons", "SWING IMPACTS", 8.7, 10.2, 0.3),
    "sn_libro_abre_0": ("Antique Books", "Pile Of Antique Books", 0.8, 1.9, 0.2, 1.0, {"como": "libro_abre.ogg"}),
    "sn_pagina_0": ("Antique Books", "Flicking Through Pages", 0.15, 1.5, 0.15, 1.0, {"como": "pagina_0.ogg"}),
    "sn_carga_bucle_0": ("Antique Books", "Slow Page Turns", 0.2, 13.4, 0.0, 1.0, {"bucle": 1.0}),
    "sn_naturaleza_0": ("HD Game Materials", "Wood Shaker", 0.1, 1.5, 0.25, 1.0, {"como": "elem_tierra.wav"}),
    "sn_arco_carga_0": ("HD Game Materials", "Wood Shaker", 1.55, 3.3, 0.3),
    "sn_maza_impacto_0": ("Colossal Impacts", "Impact Cut Sweep", 0.86, 1.6, 0.3),
    "sn_explosion_barril_0": ("Fireworks FX", "13 Fireworks", 18.15, 20.4, 1.0),
    "sn_explosion_barril_1": ("Fireworks FX", "13 Fireworks", 2.4, 3.9, 0.8),
    "sn_arde_bucle_0": ("Campfire - Bonfire", "Dropping Fresh Pine", 12.0, 34.0, 0.0, 1.0, {"como": "oga_fuego_crepita_loop.wav", "bucle": 2.0}),
}


def leer_riff(ruta):
    """Lector WAV mínimo (PCM 16/24/32 y float 32) para los archivos cuyo trozo PEAK no acepta libsndfile."""
    with open(ruta, "rb") as fh:
        d = fh.read()
    assert d[:4] == b"RIFF" and d[8:12] == b"WAVE"
    p = 12
    fmt = None
    datos = None
    while p + 8 <= len(d):
        cid = d[p:p + 4]
        tam = struct.unpack("<I", d[p + 4:p + 8])[0]
        cuerpo = d[p + 8:p + 8 + tam]
        if cid == b"fmt ":
            fmt = struct.unpack("<HHIIHH", cuerpo[:16])
        elif cid == b"data":
            datos = cuerpo
        p += 8 + tam + (tam & 1)
    tag, ch, sr, _, _, bits = fmt
    if tag == 0xFFFE:
        tag = struct.unpack("<H", d[d.find(b"fmt ") + 8 + 24:d.find(b"fmt ") + 8 + 26])[0]
    if tag == 3:
        x = np.frombuffer(datos, dtype="<f4").astype(np.float32)
    elif bits == 16:
        x = np.frombuffer(datos, dtype="<i2").astype(np.float32) / 32768.0
    elif bits == 24:
        b = np.frombuffer(datos[: len(datos) // 3 * 3], dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        v = np.where(v & 0x800000, v - 0x1000000, v)
        x = v.astype(np.float32) / 8388608.0
    else:
        x = np.frombuffer(datos, dtype="<i4").astype(np.float32) / 2147483648.0
    x = x[: len(x) // ch * ch].reshape(-1, ch)
    return x, sr


def buscar(carpeta, archivo):
    for r, d, fs in os.walk(BASE):
        if carpeta.lower() not in os.path.basename(r).lower():
            continue
        for f in fs:
            if archivo.lower() in f.lower() and f.lower().endswith(".wav"):
                return os.path.join(r, f)
    return None


def rms_de(nombre):
    """RMS (lineal) de un archivo que ya está en audio/, en mono; None si no está o no se puede leer."""
    ruta = os.path.join(DEST, nombre)
    if not os.path.exists(ruta):
        return None
    try:
        v, _ = sf.read(ruta, dtype="float32", always_2d=True)
    except Exception:
        return None
    return float(np.sqrt((v.mean(axis=1) ** 2).mean()))


informe = []
for destino, datos in ELEGIDOS.items():
    carpeta, archivo, ini, fin, fundido = datos[:5]
    tono = datos[5] if len(datos) > 5 else 1.0
    extra = datos[6] if len(datos) > 6 else {}
    ruta = buscar(carpeta, archivo)
    if ruta is None:
        print("NO ENCONTRADO", destino, carpeta, archivo)
        continue
    try:
        x, sr = sf.read(ruta, dtype="float32", always_2d=True)
    except Exception:
        x, sr = leer_riff(ruta)
    m = x[:, :2].mean(axis=1) if x.shape[1] >= 2 else x[:, 0]
    a = int(ini * sr)
    b = len(m) if fin is None else min(len(m), int(fin * sr))
    m = m[a:b]
    # «tono» va cocido en el archivo (más agudo y más corto): la voz de orco sube a goblin sin tocar el catálogo
    sr_ef = int(round(sr * tono))
    g = gcd(SR, sr_ef)
    y = resample_poly(m, SR // g, sr_ef // g).astype(np.float32)
    # arranque en el primer punto con señal (deja 3 ms) y fundidos
    pico = np.abs(y).max()
    idx = np.nonzero(np.abs(y) > pico * 0.02)[0]
    if len(idx):
        y = y[max(0, idx[0] - int(0.003 * SR)):]
    if "bucle" in extra:
        # 13/11: bucle sin costura. La cola (los últimos «bucle» segundos) se funde sobre el arranque a potencia constante y se quita: el final enlaza con el principio.
        nc = min(int(float(extra["bucle"]) * SR), len(y) // 3)
        t = np.linspace(0.0, 1.0, nc)
        y[:nc] = y[:nc] * np.sqrt(t) + y[-nc:] * np.sqrt(1.0 - t)
        y = y[:-nc]
    else:
        ne = int(0.003 * SR)
        ns = min(len(y), int(fundido * SR))
        y[:ne] *= np.linspace(0.0, 1.0, ne)
        y[-ns:] *= np.linspace(1.0, 0.0, ns) ** 1.5
    y *= (10 ** (PICO_DB / 20.0)) / (np.abs(y).max() + 1e-9)
    # 13/11: «como» = el archivo al que sustituye. Se iguala su RMS (con el pico tope a −1 dB) para que los dB del catálogo sigan valiendo sin tocarlos.
    viejo = rms_de(extra["como"]) if "como" in extra else None
    if viejo is not None and viejo > 0.0:
        y *= viejo / (float(np.sqrt((y ** 2).mean())) + 1e-9)
        tope = 10 ** (-1.0 / 20.0)
        if np.abs(y).max() > tope:
            y *= tope / np.abs(y).max()
    salida = os.path.join(DEST, destino + ".ogg")
    # A trozos de 1 s: libsndfile desborda la pila al codificar Vorbis de golpe un audio largo (los ambientes de 20 s).
    with sf.SoundFile(salida, "w", samplerate=SR, channels=1, format="OGG", subtype="VORBIS") as fh:
        for k in range(0, len(y), SR):
            fh.write(y[k:k + SR])
    rms = 20 * np.log10(np.sqrt((y ** 2).mean()) + 1e-9)
    informe.append((destino, os.path.basename(os.path.dirname(ruta)), os.path.basename(ruta), len(y) / SR, rms))
    print("%-24s %.2fs rms %.1f dB  <- %s" % (destino + ".ogg", len(y) / SR, rms, os.path.basename(ruta)[:70]))

with open(os.path.join(DEST, "sn_informe.tsv"), "w", encoding="utf-8") as fh:
    for fila in informe:
        fh.write("\t".join(str(c) for c in fila) + "\n")
