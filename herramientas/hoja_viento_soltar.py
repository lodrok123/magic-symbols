# HOJA Y MEDIDAS DEL VIENTO AL SOLTAR (13/11/2026). Lee las fotos de herramientas/captura_viento_soltar.gd (antes/ y despues/ en
# docs/capturas/vfx_en_juego/haz_gas_elementos/viento_soltar/) y:
#   - cuenta los TROZOS de cada fotograma: componentes conexas de la opacidad del volumen (<nombre>_a.png) por encima de 0,2 con al menos 6 px;
#   - mide lo DURO del borde: de los pixeles del borde de cada trozo (opacidad > 0,5 junto a uno < 0,5), la parte en que la opacidad cae de > 0,6 a < 0,08
#     en un solo pixel (corte seco, sin transicion). 0 = todos los bordes se difuminan; 1 = todos cortados;
#   - monta HOJA_VIENTO_SOLTAR.png: por cada caso una fila de antes y otra de despues, columnas = ms desde que se solto.
#   python herramientas/hoja_viento_soltar.py [carpeta]
import os
import sys
import cv2
import numpy as np

BASE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "docs", "capturas", "vfx_en_juego", "haz_gas_elementos", "viento_soltar")
TIEMPOS = [0, 100, 200, 300, 400, 500, 650, 800]
CASOS = [f"k{k}_{c}_{v}" for k in ("0.5", "1.0") for c in ("nada", "muro") for v in ("lateral", "juego")]
VERSIONES = ["antes", "despues"]


def medir(ruta_a):
    if not os.path.exists(ruta_a):
        return None
    a = cv2.imread(ruta_a, cv2.IMREAD_GRAYSCALE)
    if a is None:
        return None
    a = a.astype(np.float32) / 255.0
    m = (a > 0.2).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
    trozos = int(np.sum(st[1:, cv2.CC_STAT_AREA] >= 6)) if n > 1 else 0
    fuerte = a > 0.6
    vecino_min = cv2.erode(a, np.ones((3, 3), np.uint8))
    borde = (a > 0.5) & (vecino_min < 0.5)
    seco = fuerte & (vecino_min < 0.08)
    nb = int(borde.sum())
    dureza = float(seco.sum()) / nb if nb else 0.0
    areas = st[1:, cv2.CC_STAT_AREA] if n > 1 else np.zeros(0)
    areas = areas[areas >= 6]
    return {"trozos": trozos, "dureza": dureza, "cobertura": float(a.sum()), "area": float(np.mean(areas)) if len(areas) else 0.0}


def leer_foto(nombre):
    for ext in (".jpg", ".png"):
        if os.path.exists(nombre + ext):
            return cv2.imread(nombre + ext)
    return None


def recorte(caso):
    """Caja (x0, y0, x1, y1) en la pantalla de 1280 x 720 que encierra el aire de este caso en todos los fotogramas de las dos versiones, en 2:1."""
    caja = None
    for ver in VERSIONES:
        for t in TIEMPOS:
            ruta = os.path.join(BASE, ver, f"{caso}_{t:03d}_a.png")
            if not os.path.exists(ruta):
                continue
            a = cv2.imread(ruta, cv2.IMREAD_GRAYSCALE)
            ys, xs = np.nonzero(a > 12)
            if len(xs) == 0:
                continue
            esc = 1280.0 / a.shape[1]
            c = (xs.min() * esc, ys.min() * esc, (xs.max() + 1) * esc, (ys.max() + 1) * esc)
            caja = c if caja is None else (min(caja[0], c[0]), min(caja[1], c[1]), max(caja[2], c[2]), max(caja[3], c[3]))
    if caja is None:
        return (0, 0, 1280, 720)
    cx, cy = (caja[0] + caja[2]) / 2, (caja[1] + caja[3]) / 2
    w = max(caja[2] - caja[0], 2 * (caja[3] - caja[1])) * 1.1 + 40
    w = min(w, 1280.0)
    hh = w / 2
    x0 = int(min(max(cx - w / 2, 0), 1280 - w))
    y0 = int(min(max(cy - hh / 2, 0), 720 - hh))
    return (x0, y0, int(x0 + w), int(y0 + hh))


def main():
    filas = []
    print("caso | version | " + " | ".join(f"{t} ms" for t in TIEMPOS) + "   (trozos / dureza del borde)")
    resumen = {v: {"trozos": [], "dureza": [], "area": [], "temprano": []} for v in VERSIONES}
    for caso in CASOS:
        x0, y0, x1, y1 = recorte(caso)
        for ver in VERSIONES:
            celdas = []
            imgs = []
            for t in TIEMPOS:
                nombre = os.path.join(BASE, ver, f"{caso}_{t:03d}")
                r = medir(nombre + "_a.png")
                img = leer_foto(nombre)
                if img is None:
                    img = np.zeros((720, 1280, 3), np.uint8)
                img = cv2.resize(img[y0:y1, x0:x1], (360, 180), interpolation=cv2.INTER_AREA)
                if r is not None:
                    celdas.append(f"{r['trozos']:3d} / {r['dureza']:.2f} / {r['area']:4.0f}")
                    if t > 0:
                        resumen[ver]["trozos"].append(r["trozos"])
                        if t <= 200:                 # lo que Pablo ve al soltar: el haz se parte (100-200 ms)
                            resumen[ver]["temprano"].append(r["trozos"])
                        if r["trozos"] > 0:          # un fotograma vacio no tiene borde: no cuenta para la dureza
                            resumen[ver]["dureza"].append(r["dureza"])
                            resumen[ver]["area"].append(r["area"])
                    txt = f"{t} ms  {r['trozos']} trozos  borde {r['dureza']:.2f}"
                else:
                    celdas.append("   -    ")
                    txt = f"{t} ms"
                cv2.rectangle(img, (0, 0), (360, 18), (0, 0, 0), -1)
                cv2.putText(img, txt, (4, 13), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 255), 1, cv2.LINE_AA)
                imgs.append(img)
            print(f"{caso} | {ver} | " + " | ".join(celdas))
            etiqueta = np.zeros((180, 150, 3), np.uint8)
            for i, linea in enumerate([caso.split("_")[0].replace("k0.5", "basico k0.5").replace("k1.0", "maximo k1.0"), "_".join(caso.split("_")[1:]), ver.upper()]):
                cv2.putText(etiqueta, linea, (6, 60 + 26 * i), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_AA)
            filas.append(np.hstack([etiqueta] + imgs))
    for ver in VERSIONES:
        tr = resumen[ver]["trozos"]
        du = resumen[ver]["dureza"]
        if tr:
            ar = resumen[ver]["area"]
            print(f"MEDIA {ver} (100-800 ms): trozos {np.mean(tr):.1f} (max {max(tr)}) - dureza del borde {np.mean(du):.3f} - area media del trozo {np.mean(ar):.1f} px - trozos a los 100-200 ms {np.mean(resumen[ver]['temprano']):.1f}")
    cab = np.zeros((28, filas[0].shape[1], 3), np.uint8)
    cv2.putText(cab, "VIENTO al soltar el chorro: antes / despues (ms desde que se suelta; trozos = componentes de la opacidad > 0,2; borde = parte del borde cortada en seco)",
                (6, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_AA)
    hoja = np.vstack([cab] + filas)
    salida = os.path.join(BASE, "HOJA_VIENTO_SOLTAR.png")
    cv2.imwrite(salida, hoja)
    print("hoja", os.path.abspath(salida), hoja.shape)


if __name__ == "__main__":
    main()
