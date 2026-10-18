#!/usr/bin/env python3
"""Recortador de láminas de assets, con dos puntos de revisión (Pipeline).

POR QUÉ ASÍ. Una lámina generada trae muchos assets juntos. Cortarlos es mecánico, pero NADA debe llegar a su sitio
final sin que Pablo lo haya visto: un recorte con sombra pegada o con dos piezas unidas se cuela fácilmente. Por eso el
flujo tiene dos puertas, y el script no deja saltarse ninguna:

  1. APROBACIÓN. `cortar` NO escribe en ninguna carpeta del juego: deja cada pieza en `arte/aprobacion/<lote>/` con un
     id (`<lote>-001`...), una hoja de contacto para verlas de un vistazo y un `lote.json` con el estado de cada una.
     Pablo mira la hoja y aprueba o rechaza (`marcar`).
  2. PROCESAR. Solo lo aprobado, y con destino asignado (`asignar`), se copia a su sitio final (`procesar`).
     Los PERSONAJES llevan una puerta más: antes de procesarse pasan por el laboratorio (humanoides o enemigos) para
     revisar aspecto y animaciones. `laboratorio` los copia allí y `procesar` los rechaza hasta que estén `revisado`.

Estados:  pendiente -> aprobado -> procesado                       (props, iconos, suelo...)
          pendiente -> aprobado -> en_laboratorio -> revisado -> procesado   (personajes)
          cualquiera -> rechazado

Uso (desde la raíz del repo o con --repo):
  python arte/herramientas/recortar_assets.py cortar lamina.png --lote arbustos --tipo prop
  python arte/herramientas/recortar_assets.py estado arbustos
  python arte/herramientas/recortar_assets.py marcar arbustos aprobado 001 002 004      (o --todo)
  python arte/herramientas/recortar_assets.py asignar arbustos 001 --destino arte/props/arbusto_a.png
  python arte/herramientas/recortar_assets.py laboratorio arbustos                      (solo personajes aprobados)
  python arte/herramientas/recortar_assets.py procesar arbustos --lado 256 --simular    (--simular = no escribe)

Dónde puede escribir `procesar`: solo en carpetas del Pipeline (RAICES_PERMITIDAS, según docs/PROPIETARIOS.md).
Nunca pisa un archivo existente sin --sobrescribir. Godot ignora la carpeta de aprobación (`.gdignore`): son borradores.
"""
import argparse
import datetime
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

# --- Convenciones (si cambian las carpetas, se cambian aquí y en ningún otro sitio) ---------------------------------
CARPETA_APROBACION = "arte/aprobacion"
LAB_CARPETAS = {                                   # tipo de personaje -> carpeta que mira su laboratorio
    "personaje_humanoide": "arte/laboratorio/humanoides",
    "personaje_enemigo": "arte/laboratorio/enemigos",
}
RAICES_PERMITIDAS = ["arte", "art", "presentacion/ui/laminas", "presentacion/vfx"]   # lo que posee el Pipeline
TIPOS = ["personaje_humanoide", "personaje_enemigo", "prop", "icono", "suelo", "otro"]
ESTADOS = ["pendiente", "aprobado", "en_laboratorio", "revisado", "procesado", "rechazado"]
COLOR_ESTADO = {"pendiente": (200, 200, 200), "aprobado": (90, 190, 90), "en_laboratorio": (230, 170, 60),
                "revisado": (80, 150, 230), "procesado": (140, 110, 220), "rechazado": (220, 80, 80)}


class Fallo(Exception):
    """Error de uso: se imprime sin traza y sale con código 1."""


# --- Rutas ---------------------------------------------------------------------------------------------------------
def raiz_repo(arg):
    if arg:
        return Path(arg).resolve()
    for p in [Path.cwd(), *Path.cwd().parents, *Path(__file__).resolve().parents]:
        if (p / "project.godot").exists():
            return p
    raise Fallo("No encuentro project.godot: ejecuta desde el repo o pasa --repo.")


def carpeta_lote(repo, lote):
    return repo / CARPETA_APROBACION / lote


def cargar(repo, lote):
    f = carpeta_lote(repo, lote) / "lote.json"
    if not f.exists():
        raise Fallo(f"No existe el lote '{lote}' ({f}).")
    return json.loads(f.read_text(encoding="utf-8"))


def guardar(repo, lote, datos):
    f = carpeta_lote(repo, lote) / "lote.json"
    f.write_text(json.dumps(datos, indent=1, ensure_ascii=False), encoding="utf-8")


def pieza_de(datos, ident):
    """Acepta el id entero (`arbustos-003`) o solo el número (`3`, `003`)."""
    for p in datos["piezas"]:
        if p["id"] == ident or p["id"].endswith("-" + ident.zfill(3)):
            return p
    raise Fallo(f"No hay pieza '{ident}' en el lote '{datos['lote']}'.")


# --- Detección de piezas -------------------------------------------------------------------------------------------
def color_fondo(rgb):
    """El fondo de una lámina es lo que hay en su borde: la mediana de un marco de 2 px (aguanta alguna pieza que lo roce)."""
    marco = np.concatenate([rgb[:2].reshape(-1, 3), rgb[-2:].reshape(-1, 3),
                            rgb[:, :2].reshape(-1, 3), rgb[:, -2:].reshape(-1, 3)])
    return np.median(marco, axis=0)


def separar(img, fondo, tol, une, min_area, tapa, con_sombras=False):
    """Devuelve (rgb, alfa_suave, etiquetas, n, bg). `etiquetas` marca a qué pieza pertenece cada píxel."""
    arr = np.asarray(img.convert("RGBA")).astype(np.float32)
    rgb, a0 = arr[..., :3], arr[..., 3]
    if fondo == "alfa" or (fondo == "auto" and a0.min() < 250):
        dist = np.where(a0 > 16, 255.0, 0.0)                    # ya viene recortada: el fondo es lo transparente
        bg = None
    else:
        if fondo == "auto":
            bg = color_fondo(rgb)
        else:
            h = fondo.lstrip("#")
            bg = np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)
        dist = np.sqrt(((rgb - bg) ** 2).sum(-1))               # distancia de color al fondo
    fg = dist > tol
    if bg is not None and not con_sombras:
        # Sombras del suelo: son el fondo OSCURECIDO (los tres canales bajan en la misma proporción y sin tocar el tono);
        # un objeto, aunque sea gris, no oscurece los canales por igual sobre un fondo de color. Se tratan como fondo.
        r = rgb / np.maximum(bg, 1.0)
        sombra = (r.std(-1) < 0.035) & (r.mean(-1) > 0.45) & (r.mean(-1) < 0.97)
        fg &= ~ndi.binary_opening(sombra, iterations=1)
        dist = np.where(fg, dist, 0.0)
    # Huecos pequeños dentro de una pieza (un ojo blanco, un brillo) se rellenan: no son fondo.
    inv = ~fg
    lab, n = ndi.label(inv)
    if n:
        tam = ndi.sum(inv, lab, range(1, n + 1))
        borde = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
        for i, t in enumerate(tam, 1):
            if i not in borde and t < tapa:
                fg[lab == i] = True
    # Agrupar: se ensancha la máscara `une` px para que las partes sueltas de un mismo asset (una mano, una chispa) cuenten
    # como una pieza. Ensanchar solo sirve para agrupar; el recorte usa la máscara sin ensanchar.
    grupos, n = ndi.label(ndi.binary_dilation(fg, iterations=max(une, 0)))
    area = ndi.sum(fg, grupos, range(1, n + 1))
    for i, t in enumerate(area, 1):
        if t < min_area:
            grupos[grupos == i] = 0                               # polvo: se descarta
    if bg is None:
        alfa = a0 / 255.0
    else:
        # Borde limpio. Un píxel de borde mezcla pieza y fondo; para separarlos se estima el color de la pieza con el del
        # interior más cercano (F) y la cobertura con la proyección del píxel sobre la recta fondo->F. Así una runa oscura
        # sobre papel crema no sale con ribete claro, sea cual sea el color de la pieza.
        solido = ndi.binary_erosion(fg, iterations=2)
        _, (iy, ix) = ndi.distance_transform_edt(~solido, return_indices=True)
        F = rgb[iy, ix]
        num = ((rgb - bg) * (F - bg)).sum(-1)
        den = ((F - bg) ** 2).sum(-1) + 1e-3
        borde = np.clip(num / den, 0, 1)
        cerca = ndi.binary_dilation(fg, iterations=1)
        alfa = np.where(solido, 1.0, np.where(cerca, borde, 0.0)).astype(np.float32)
        rgb = np.where(solido[..., None], rgb, F)                  # el color de un píxel de borde es el de la pieza, no el mezclado
    return rgb, alfa, grupos, n, bg


def orden_lectura(cajas):
    """Filas de arriba abajo y, dentro de cada fila, de izquierda a derecha. Una fila nueva empieza cuando el centro cae
    más de 0,6 alturas medianas por debajo del primero de la fila (así una pieza más alta no rompe su fila)."""
    if not cajas:
        return []
    alto = float(np.median([c[3] - c[1] for c in cajas]))
    idx = sorted(range(len(cajas)), key=lambda i: (cajas[i][1] + cajas[i][3]) / 2)
    filas, actual, y0 = [], [], None
    for i in idx:
        cy = (cajas[i][1] + cajas[i][3]) / 2
        if y0 is None or cy - y0 > 0.6 * alto:
            if actual:
                filas.append(actual)
            actual, y0 = [], cy
        actual.append(i)
    filas.append(actual)
    return [i for f in filas for i in sorted(f, key=lambda j: (cajas[j][0] + cajas[j][2]) / 2)]


def recortar(rgb, alfa, grupos, k, bg, margen, halo):
    """Pieza k como RGBA (el borde ya viene limpio de `separar`)."""
    m = grupos == k
    ys, xs = np.where(m)
    y0, y1, x0, x1 = max(ys.min() - margen, 0), min(ys.max() + margen + 1, m.shape[0]), \
        max(xs.min() - margen, 0), min(xs.max() + margen + 1, m.shape[1])
    # Se conserva solo lo de esta pieza: píxeles de otras piezas dentro de la caja se vuelven transparentes.
    region = ndi.binary_dilation(m, iterations=margen + 2)[y0:y1, x0:x1]
    a = (alfa[y0:y1, x0:x1] * region).astype(np.float32)
    if halo > 0:
        a = ndi.gaussian_filter(ndi.grey_erosion(a, size=(2 * halo + 1,) * 2), 0.7)
    c = rgb[y0:y1, x0:x1]
    out = np.dstack([c, a * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA"), (int(x0), int(y0), int(x1), int(y1))


# --- Hoja de contacto ----------------------------------------------------------------------------------------------
def hoja_contacto(repo, datos):
    """Una imagen con todas las piezas y su id, con el borde del color de su estado. Es lo que mira Pablo para aprobar."""
    carp = carpeta_lote(repo, datos["lote"])
    celda, cols = 190, 6
    filas = max(1, -(-len(datos["piezas"]) // cols))
    hoja = Image.new("RGB", (cols * celda, filas * (celda + 18)), (60, 60, 66))
    d = ImageDraw.Draw(hoja)
    for n, p in enumerate(datos["piezas"]):
        f, c = divmod(n, cols)
        x, y = c * celda, f * (celda + 18)
        im = Image.open(carp / p["archivo"]).convert("RGBA")
        esc = min((celda - 16) / im.width, (celda - 16) / im.height, 9.0)
        im = im.resize((max(1, int(im.width * esc)), max(1, int(im.height * esc))), Image.LANCZOS)
        d.rectangle([x + 3, y + 3, x + celda - 4, y + celda - 4], fill=(96, 96, 104), outline=COLOR_ESTADO[p["estado"]], width=3)
        hoja.paste(im, (x + (celda - im.width) // 2, y + (celda - im.height) // 2), im)
        d.text((x + 6, y + celda), f"{p['id'].split('-')[-1]} {p['tipo'].replace('personaje_', 'pj_')} {p['estado']}",
               fill=COLOR_ESTADO[p["estado"]])
    hoja.save(carp / "hoja_contacto.png")


# --- Órdenes -------------------------------------------------------------------------------------------------------
def cmd_cortar(a, repo):
    ruta = Path(a.imagen)
    if not ruta.exists():
        raise Fallo(f"No existe la imagen {ruta}.")
    lote = a.lote or ruta.stem
    carp = carpeta_lote(repo, lote)
    if (carp / "lote.json").exists() and not a.sobrescribir:
        raise Fallo(f"El lote '{lote}' ya existe: usa otro --lote o --sobrescribir (borra lo aprobado hasta ahora).")
    img = Image.open(ruta)
    rgb, alfa, grupos, n, bg = separar(img, a.fondo, a.tol, a.une, a.min_area, a.tapa, a.con_sombras)
    ids = [i for i in range(1, n + 1) if (grupos == i).any()]
    cajas = []
    for k in ids:
        ys, xs = np.where(grupos == k)
        cajas.append((xs.min(), ys.min(), xs.max(), ys.max()))
    if not ids:
        raise Fallo("No he encontrado ninguna pieza: prueba --tol más bajo o --min-area más bajo.")
    if carp.exists():
        shutil.rmtree(carp)
    (carp / "piezas").mkdir(parents=True)
    (repo / CARPETA_APROBACION / ".gdignore").write_text("", encoding="utf-8")     # Godot no importa borradores
    shutil.copy(ruta, carp / ("original" + ruta.suffix.lower()))
    piezas = []
    for n_, j in enumerate(orden_lectura(cajas), 1):
        im, caja = recortar(rgb, alfa, grupos, ids[j], bg, a.margen, a.halo)
        ident = f"{lote}-{n_:03d}"
        im.save(carp / "piezas" / f"{ident}.png")
        piezas.append({"id": ident, "archivo": f"piezas/{ident}.png", "caja_en_lamina": caja, "tam": [im.width, im.height],
                       "tipo": a.tipo, "nombre": "", "destino": "", "estado": "pendiente", "nota": ""})
    datos = {"lote": lote, "creado": datetime.datetime.now().isoformat(timespec="seconds"), "origen": str(ruta),
             "parametros": {k: getattr(a, k) for k in ("fondo", "tol", "une", "min_area", "tapa", "margen", "halo", "con_sombras")},
             "piezas": piezas}
    guardar(repo, lote, datos)
    hoja_contacto(repo, datos)
    print(f"Lote '{lote}': {len(piezas)} piezas en {carp}\nMira {carp / 'hoja_contacto.png'} y aprueba con `marcar`.")


def cmd_estado(a, repo):
    datos = cargar(repo, a.lote)
    cuenta = {}
    for p in datos["piezas"]:
        cuenta[p["estado"]] = cuenta.get(p["estado"], 0) + 1
        print(f"  {p['id']:<28} {p['tipo']:<20} {p['estado']:<15} {p['destino'] or '(sin destino)'}")
    print("Resumen:", ", ".join(f"{v} {k}" for k, v in cuenta.items()))


def seleccion(datos, ids, todo):
    return datos["piezas"] if todo else [pieza_de(datos, i) for i in ids]


# Qué cambio de estado se permite desde cada uno: la puerta de laboratorio no se puede saltar a mano.
TRANSICIONES = {"aprobado": {"pendiente", "rechazado"}, "rechazado": set(ESTADOS) - {"procesado"},
                "revisado": {"en_laboratorio"}, "pendiente": {"aprobado", "rechazado"}}


def cmd_marcar(a, repo):
    datos = cargar(repo, a.lote)
    if a.estado not in TRANSICIONES:
        raise Fallo(f"Estado '{a.estado}' no se marca a mano (usa aprobado, rechazado, revisado o pendiente).")
    for p in seleccion(datos, a.ids, a.todo):
        if p["estado"] not in TRANSICIONES[a.estado]:
            print(f"  salto {p['id']}: de '{p['estado']}' no se pasa a '{a.estado}'"
                  + (" (los personajes pasan antes por `laboratorio`)" if a.estado == "revisado" else ""))
            continue
        p["estado"] = a.estado
        print(f"  {p['id']}: {a.estado}")
    guardar(repo, a.lote, datos)
    hoja_contacto(repo, datos)


def cmd_asignar(a, repo):
    datos = cargar(repo, a.lote)
    p = pieza_de(datos, a.id)
    if a.destino:
        comprobar_destino(repo, a.destino)
        p["destino"] = a.destino
    if a.tipo:
        p["tipo"] = a.tipo
    if a.nombre:
        p["nombre"] = a.nombre
    guardar(repo, a.lote, datos)
    hoja_contacto(repo, datos)
    print(f"  {p['id']}: tipo={p['tipo']} destino={p['destino'] or '-'}")


def comprobar_destino(repo, destino):
    """El destino tiene que ser un .png relativo al repo y dentro de una carpeta del Pipeline: así un error de tecleo no
    acaba escribiendo en código del Juego ni fuera del proyecto."""
    d = Path(destino)
    if d.is_absolute() or ".." in d.parts or d.suffix.lower() != ".png":
        raise Fallo(f"Destino '{destino}': ha de ser una ruta relativa al repo, sin '..' y terminada en .png.")
    if not any(str(d.as_posix()).startswith(r + "/") for r in RAICES_PERMITIDAS):
        raise Fallo(f"Destino '{destino}' fuera de las carpetas del Pipeline ({', '.join(RAICES_PERMITIDAS)}).")


def cmd_laboratorio(a, repo):
    datos = cargar(repo, a.lote)
    n = 0
    for p in datos["piezas"]:
        if p["tipo"] not in LAB_CARPETAS or p["estado"] != "aprobado":
            continue
        dest = repo / LAB_CARPETAS[p["tipo"]]
        dest.mkdir(parents=True, exist_ok=True)
        shutil.copy(carpeta_lote(repo, a.lote) / p["archivo"], dest / f"{p['id']}.png")
        p["estado"] = "en_laboratorio"
        n += 1
        print(f"  {p['id']} -> {LAB_CARPETAS[p['tipo']]}/ (revísalo en el laboratorio y luego `marcar {a.lote} revisado {p['id'].split('-')[-1]}`)")
    guardar(repo, a.lote, datos)
    hoja_contacto(repo, datos)
    print(f"{n} personaje(s) enviados al laboratorio." if n else "No hay personajes aprobados pendientes de laboratorio.")


def normalizar(im, lado):
    """Lo deja en un lienzo cuadrado `lado` x `lado`, centrado y sin deformar (con 4 % de aire)."""
    esc = lado * 0.96 / max(im.width, im.height)
    im = im.resize((max(1, round(im.width * esc)), max(1, round(im.height * esc))), Image.LANCZOS)
    lienzo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    lienzo.paste(im, ((lado - im.width) // 2, (lado - im.height) // 2), im)
    return lienzo


def cmd_procesar(a, repo):
    datos = cargar(repo, a.lote)
    hechas = 0
    for p in datos["piezas"]:
        if p["estado"] in ("procesado", "rechazado", "pendiente"):
            continue
        es_pj = p["tipo"] in LAB_CARPETAS
        if es_pj and p["estado"] != "revisado":
            print(f"  salto {p['id']}: es un personaje y aún no ha pasado el laboratorio (estado '{p['estado']}')")
            continue
        if not es_pj and p["estado"] != "aprobado":
            continue
        if not p["destino"]:
            print(f"  salto {p['id']}: sin destino (usa `asignar`)")
            continue
        comprobar_destino(repo, p["destino"])
        fin = repo / p["destino"]
        if fin.exists() and not a.sobrescribir:
            print(f"  salto {p['id']}: {p['destino']} ya existe (usa --sobrescribir)")
            continue
        im = Image.open(carpeta_lote(repo, a.lote) / p["archivo"]).convert("RGBA")
        if a.lado:
            im = normalizar(im, a.lado)
        if a.simular:
            print(f"  [simulación] {p['id']} -> {p['destino']} ({im.width}x{im.height})")
            continue
        fin.parent.mkdir(parents=True, exist_ok=True)
        im.save(fin)
        p["estado"] = "procesado"
        hechas += 1
        print(f"  {p['id']} -> {p['destino']} ({im.width}x{im.height})")
    if not a.simular:
        guardar(repo, a.lote, datos)
        hoja_contacto(repo, datos)
    print(f"{hechas} pieza(s) procesadas." + ("  Abre Godot para que importe los PNG nuevos." if hechas else ""))


def cmd_hoja(a, repo):
    hoja_contacto(repo, cargar(repo, a.lote))
    print("Hoja regenerada.")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--repo", help="raíz del repo (por defecto, la que tenga project.godot)")
    sub = ap.add_subparsers(dest="orden", required=True)

    c = sub.add_parser("cortar", help="corta una lámina en piezas y las deja en la carpeta de aprobación")
    c.add_argument("imagen")
    c.add_argument("--lote", help="nombre del lote (por defecto, el de la imagen)")
    c.add_argument("--tipo", choices=TIPOS, default="otro", help="tipo de todas las piezas (se cambia luego una a una)")
    c.add_argument("--fondo", default="auto", help="'auto' (lo del borde), 'alfa' (ya es transparente) o un color #rrggbb")
    c.add_argument("--tol", type=float, default=30, help="distancia de color al fondo para contar como pieza")
    c.add_argument("--une", type=int, default=6, help="px que se ensancha para juntar partes sueltas de una misma pieza")
    c.add_argument("--min-area", type=int, default=400, help="píxeles mínimos de una pieza (menos = polvo)")
    c.add_argument("--tapa", type=int, default=150, help="huecos interiores menores de esto se rellenan")
    c.add_argument("--margen", type=int, default=4, help="px de aire alrededor del recorte")
    c.add_argument("--con-sombras", action="store_true", help="conservar las sombras del suelo (por defecto se descartan)")
    c.add_argument("--halo", type=int, default=0, help="px que se comen del borde si queda ribete del fondo")
    c.add_argument("--sobrescribir", action="store_true")
    c.set_defaults(f=cmd_cortar)

    e = sub.add_parser("estado", help="lista las piezas de un lote")
    e.add_argument("lote")
    e.set_defaults(f=cmd_estado)

    m = sub.add_parser("marcar", help="aprobado | rechazado | revisado | pendiente")
    m.add_argument("lote")
    m.add_argument("estado")
    m.add_argument("ids", nargs="*")
    m.add_argument("--todo", action="store_true")
    m.set_defaults(f=cmd_marcar)

    s = sub.add_parser("asignar", help="destino final, tipo o nombre de una pieza")
    s.add_argument("lote")
    s.add_argument("id")
    s.add_argument("--destino")
    s.add_argument("--tipo", choices=TIPOS)
    s.add_argument("--nombre")
    s.set_defaults(f=cmd_asignar)

    l = sub.add_parser("laboratorio", help="manda al laboratorio los personajes aprobados")
    l.add_argument("lote")
    l.set_defaults(f=cmd_laboratorio)

    p = sub.add_parser("procesar", help="copia lo aprobado (y revisado, si es personaje) a su destino")
    p.add_argument("lote")
    p.add_argument("--lado", type=int, help="lo deja en un lienzo cuadrado de este lado (px)")
    p.add_argument("--simular", action="store_true")
    p.add_argument("--sobrescribir", action="store_true")
    p.set_defaults(f=cmd_procesar)

    h = sub.add_parser("hoja", help="regenera la hoja de contacto")
    h.add_argument("lote")
    h.set_defaults(f=cmd_hoja)

    a = ap.parse_args()
    try:
        a.f(a, raiz_repo(a.repo))
    except Fallo as ex:
        print("ERROR:", ex)
        sys.exit(1)


if __name__ == "__main__":
    main()
