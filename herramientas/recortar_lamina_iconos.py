"""Recorta la lámina de iconos de inventario de Pablo (5/11/2026) en un PNG transparente por objeto.

Uso:  python -P herramientas/recortar_lamina_iconos.py <lamina> <carpeta_salida> [hoja_contacto.png]

Qué hace:
  1. Fondo = píxeles casi blancos y poco saturados CONECTADOS con el borde de la imagen (así el blanco de un
     cristal o de la pluma, que está dentro del objeto, se conserva).
  2. Alfa suave: en el borde del objeto (2 px junto al fondo) el alfa sale de la distancia al color del fondo;
     el resto es opaco. El color del borde se "descontamina" (se quita lo que sea fondo blanco mezclado).
  3. Objetos = componentes conectados de la máscara dilatada (junta las gotas de miel, el halo, los rayos...);
     se ordenan por filas (4) y de izquierda a derecha, y se les pone el ID de IDS.
  4. Cada objeto se centra en un lienzo cuadrado de 256x256 con margen igual (MARGEN px) y se guarda <id>.png.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

LADO = 256
MARGEN = 14          # px de aire a cada lado en el lienzo de 256
FILAS = [6, 6, 7, 5]  # objetos por fila de la lámina

# Orden de lectura de la lámina (fila 1..4, izquierda a derecha) -> id del juego.
IDS = [
    "resina", "corteza", "panal", "pluma", "seda", "carbon",
    "jiron_escudo", "gota_veneno", "obsidiana", "polvo_cristal", "ceniza_geoda", "cristal_cargado",
    "baba_limo", "pluma_chaman", "cristal_tierra", "pocion", "antidoto", "frescor", "abrigo",
    "pigmento_carmesi", "pigmento_ocre", "pigmento_musgo", "pigmento_ambar", "pigmento_eco",
]


def main() -> None:
    src = sys.argv[1]
    salida = sys.argv[2]
    contacto = sys.argv[3] if len(sys.argv) > 3 else ""
    im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    h, w, _ = im.shape
    # color de fondo: mediana del marco exterior
    marco = np.concatenate([im[:6].reshape(-1, 3), im[-6:].reshape(-1, 3), im[:, :6].reshape(-1, 3), im[:, -6:].reshape(-1, 3)])
    fondo = np.median(marco, axis=0)
    dist = np.sqrt(((im - fondo) ** 2).sum(axis=2))
    mx = im.max(axis=2)
    mn = im.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1.0)

    def mascara(quitar_sombra: bool):
        # fondo = casi blanco; con quitar_sombra también la sombra suave del suelo (clara, poco saturada, beige)
        cercano = dist < 26.0
        if quitar_sombra:
            cercano = cercano | ((dist < 75.0) & (mn >= 190.0) & (sat < 0.20))
        lab, _ = ndi.label(cercano)
        borde = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        fondo_real = np.isin(lab, list(borde))
        objeto = ndi.binary_opening(~fondo_real, iterations=1)   # fuera las motas sueltas
        cerca_fondo = ndi.binary_dilation(fondo_real, iterations=2) & objeto
        alfa = np.where(objeto, 1.0, 0.0).astype(np.float32)
        suave = np.clip((dist - 12.0) / 40.0, 0.0, 1.0)
        alfa = np.where(cerca_fondo, np.minimum(suave * 1.6, 1.0), alfa)
        alfa = np.where(objeto, alfa, 0.0)
        # descontaminar el color del borde: c = (px - (1-a)*fondo)/a
        a3 = np.maximum(alfa, 0.05)[..., None]
        col = np.where(cerca_fondo[..., None], np.clip((im - (1.0 - a3) * fondo) / a3, 0, 255), im)
        return objeto, np.dstack([col, alfa * 255.0]).clip(0, 255).astype(np.uint8)

    objeto, rgba_suave = mascara(False)     # conserva la sombra: sirve para detectar los objetos
    _, rgba_sin_sombra = mascara(True)
    # estos se comen en la versión sin sombra (la pluma blanca, la seda y la escarcha del frasco son claras como ella)
    CON_SOMBRA_SUAVE = {"pluma", "seda", "frescor"}

    # objetos: componentes de la máscara con poca dilatación; los trozos pequeños (gotas, chispas, halo)
    # se reparten al objeto grande más cercano (a menos de DIST_MAX px) en vez de juntar objetos vecinos.
    junta = ndi.binary_dilation(objeto, iterations=3)
    lab2, n2 = ndi.label(junta)
    areas = ndi.sum(objeto, lab2, index=np.arange(1, n2 + 1))
    grandes = [i for i in range(1, n2 + 1) if areas[i - 1] >= 6000]
    semilla = np.where(np.isin(lab2, grandes), lab2, 0)
    d_sem, (iy, ix) = ndi.distance_transform_edt(semilla == 0, return_indices=True)
    asignado = semilla[iy, ix]
    DIST_MAX = 60.0
    lab2 = np.where(objeto & (d_sem <= DIST_MAX), asignado, 0)
    cajas = []
    for i, sl in enumerate(ndi.find_objects(lab2), start=1):
        if sl is None:
            continue
        area = int((lab2[sl] == i).sum())
        cajas.append((i, sl, area))
    esperados = sum(FILAS)
    print("componentes:", len(cajas), "esperados:", esperados)
    if len(cajas) != esperados:
        for i, sl, area in cajas:
            print(" ", i, sl[1].start, sl[0].start, sl[1].stop, sl[0].stop, area)
        raise SystemExit("no coincide el número de objetos")
    # ordenar por filas: agrupar por centro Y
    cajas.sort(key=lambda c: (c[1][0].start + c[1][0].stop) / 2)
    ordenadas = []
    k = 0
    for f in FILAS:
        fila = sorted(cajas[k:k + f], key=lambda c: (c[1][1].start + c[1][1].stop) / 2)
        ordenadas += fila
        k += f
    hoja = Image.new("RGBA", (6 * LADO, 4 * LADO), (90, 90, 96, 255)) if contacto else None
    for idx, (i, sl, area) in enumerate(ordenadas):
        mask = lab2 == i
        rgba = rgba_suave if IDS[idx] in CON_SOMBRA_SUAVE else rgba_sin_sombra
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        rec = rgba[y0:y1, x0:x1].copy()
        # el alfa solo dentro de la componente (no se cuela el vecino)
        rec[..., 3] = np.where(mask[y0:y1, x0:x1], rec[..., 3], 0)
        # caja ajustada al alfa real
        ys, xs = np.where(rec[..., 3] > 8)
        rec = rec[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        ih, iw = rec.shape[:2]
        escala = (LADO - 2 * MARGEN) / float(max(ih, iw))
        nw, nh = max(1, round(iw * escala)), max(1, round(ih * escala))
        pil = Image.fromarray(rec, "RGBA")
        # premultiplicar para reescalar sin halo blanco
        arr = np.asarray(pil).astype(np.float32)
        arr[..., :3] *= arr[..., 3:4] / 255.0
        pre = Image.fromarray(arr.astype(np.uint8), "RGBA").resize((nw, nh), Image.LANCZOS)
        p = np.asarray(pre).astype(np.float32)
        al = np.maximum(p[..., 3:4], 1.0)
        p[..., :3] = np.clip(p[..., :3] * 255.0 / al, 0, 255)
        pil = Image.fromarray(p.astype(np.uint8), "RGBA")
        lienzo = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
        lienzo.paste(pil, ((LADO - nw) // 2, (LADO - nh) // 2))
        lienzo.save("%s/%s.png" % (salida, IDS[idx]))
        print(IDS[idx], (iw, ih), "->", (nw, nh))
        if hoja is not None:
            hoja.alpha_composite(lienzo, ((idx % 6) * LADO, (idx // 6) * LADO))
    if hoja is not None:
        hoja.save(contacto)


main()
