#!/usr/bin/env python
"""Inventario de los assets traídos de Unreal (26/11/2026): Pure Nature (BK, 7 packs) y Stylescape: Ruins.

Genera, sin escribir nada a mano fila a fila:
  - docs/fab_ue/inventario_piezas.tsv        una fila por pieza (579 pn_* + 199 ss_*)
  - docs/INVENTARIO_ASSETS_UNREAL_2026-11-26.md   resumen por pack y categoría

Lee: arte/pure_nature/indice.json (pack, categoría, caja), arte/pure_nature/piezas|juego (existencia),
arte/stylescape/piezas/*.tscn (caja y categoría en los metadatos), presentacion/fab_ue/tabla_variantes.gd
(qué usa ya el juego), presentacion/paredes_stylescape.gd y demás .gd del juego (SM_*/ss_*), y, si existe,
E:/ue_proyectos (Content y *_export) para ver qué mallas no han llegado a arte/.

Uso (desde la raíz del repo):   python tools/inventario_assets_unreal.py
Las reglas de clasificación (categoría fina, bioma, uso) están en este fichero: se corrigen aquí y se regenera.
Tamaños en u de juego (la caja ya lleva la escala 0,575: 1 casilla = 2,3 u = 4 m).
"""
import csv
import json
import os
import re
import statistics
import sys
from collections import Counter, defaultdict

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PN = os.path.join(RAIZ, "arte", "pure_nature")
SS = os.path.join(RAIZ, "arte", "stylescape")
UE_PROYECTO = r"E:\ue_proyectos\StylescapeRuins"
UE_EXP_PN = r"E:\ue_proyectos\PureNature_export"
UE_EXP_SS = r"E:\ue_proyectos\StylescapeRuins_export"
SALIDA_TSV = os.path.join(RAIZ, "docs", "fab_ue", "inventario_piezas.tsv")
SALIDA_MD = os.path.join(RAIZ, "docs", "INVENTARIO_ASSETS_UNREAL_2026-11-26.md")

PACKS = ["asianvalley", "fantasyforest", "islands", "jungle", "meadows", "mountains", "savanna"]
NOMBRE_PACK = {"asianvalley": "Asian Valley", "fantasyforest": "Fantasy Forest", "islands": "Islands", "jungle": "Jungle",
               "meadows": "Meadows", "mountains": "Mountains", "savanna": "Savanna", "stylescape": "Stylescape: Ruins"}


def leer(ruta):
    with open(ruta, encoding="utf-8") as f:
        return f.read()


# ----------------------------------------------------------------------------------------------------------------------
# Qué usa ya el juego
# ----------------------------------------------------------------------------------------------------------------------
def usos_pure_nature():
    """pieza pn_* -> [ids del juego que la usan] (de TablaVariantes) + referencias directas en otros .gd del juego."""
    usos = defaultdict(list)
    t = leer(os.path.join(RAIZ, "presentacion", "fab_ue", "tabla_variantes.gd"))
    bloque = t.split("const VARIANTES", 1)[1].split("const MEDIDAS", 1)[0]
    for m in re.finditer(r'"(\w+)":\s*\[(.*?)\]', bloque):
        for r in re.findall(r"juego/(pn_\w+)\.tscn", m.group(2)):
            if m.group(1) not in usos[r]:
                usos[r].append(m.group(1))
    return usos


def usos_directos(carpetas, patron):
    """Referencias a piezas fuera de la tabla, en el código del juego (no herramientas ni laboratorios)."""
    res = defaultdict(set)
    for c in carpetas:
        for dp, _, fn in os.walk(os.path.join(RAIZ, c)):
            for f in fn:
                if f.endswith((".gd", ".tscn")) and f != "tabla_variantes.gd":
                    try:
                        txt = leer(os.path.join(dp, f))
                    except OSError:
                        continue
                    for m in re.finditer(patron, txt):
                        res[m.group(0).lower()].add(f)
    return res


# ----------------------------------------------------------------------------------------------------------------------
# Pure Nature: categoría fina, bioma, uso
# ----------------------------------------------------------------------------------------------------------------------
def nombre_corto(pid, pack):
    return pid[len("pn_" + pack + "_"):]


def fina_pn(pack, n, cat, horiz, alto):
    """Categoría fina de una pieza Pure Nature, por nombre y tamaño (la categoría del índice solo distingue 6 clases)."""
    if re.match(r"(asianhill|kilimanjaro)", n):
        return "fondo"
    if re.match(r"(cliff|thincliff|islandcliff|junglecliff)", n):
        return "acantilado"
    if n.startswith("bank_"):
        return "orilla"
    if re.match(r"(bigroots|smallroot)", n):
        return "raiz"
    if re.match(r"(branches|branchs)$", n):
        return "rama"
    if re.match(r"(deadleaves|drypalm)", n):
        return "hojarasca"
    if n.startswith("ivyheart"):
        return "hiedra"
    if re.match(r"(rubble|rocksavanna|bouldersavanna)", n):
        return "escombro"
    if re.match(r"(boulder|stone|mossyrock|pebble|rock_|jungleboulder|bigboulders|block_)", n):
        return "roca"
    if re.match(r"(bamboo_barrier|bamboo_ladder|bamboo_raft)", n):
        return "estructura_bambu"
    if re.match(r"bamboo_\d", n):
        return "vara_bambu"
    if n.startswith("barrier"):
        return "valla"
    if re.match(r"(lotus|lillypads|watermoss|bigkelp|algae|waterfall)", n):
        return "agua"
    if re.match(r"(reeds|wetgrass)", n):
        return "orilla"
    if re.match(r"(shell|starfish|pearl)", n):
        return "marino"
    if re.match(r"(rice|cabbage|radish|pakchoi|carot|barley|wheat|money)", n) or n == "grassrice":
        return "cultivo"
    if cat == "seta" or re.match(r"(mushmush|tinderfungus)", n):
        return "seta"
    if re.match(r"(fern|largefern|bigfern|thinfern|cyrtomium|asplenium|ferneil)", n):
        return "helecho"
    if n == "berries":
        return "planta_baja"
    if re.match(r"(daisy|commonblue|commonpink|commonyellow|flowermeadow|lavender|lupin|heliconia|astilb|cardinal|jenny|anthurium|"
                r"ulmaria|gorse)", n):
        return "flor"
    if re.match(r"(elephant|philo|aloe|cordyline)", n):
        return "planta_hoja"
    if re.match(r"(grass|savannagrass|tallgrassdry|andropogon|sorrel|blindweed|grassmoss)", n):
        return "hierba"
    if n.startswith("bigbush") or (re.match(r"(bush|shrub|rattle|tropica|musa|osmanthus)", n) and alto < 2.5):
        return "arbusto"
    if cat == "arbol" or alto >= 2.5:
        if re.match(r"(fir|spruce|pine|cypres)", n):
            return "conifera"
        if re.match(r"(coconut|banana|pandanace)", n):
            return "palmera"
        if n.startswith("bamboo"):
            return "bambu"
        return "arbol"
    # Islands: nombres inventados por el autor (aquila, cerfolet, couec, glocus…): plantas bajas de isla sin identificar por nombre
    if pack == "islands":
        return "planta_isla"
    return "planta_baja"


def bioma_pn(pack, n, fina, horiz, alto):
    """(bioma principal, secundarios). Bosque gallego-atlántico; cueva, pantano y ruinas como el resto del juego."""
    sec = []
    p = "ninguno"
    if fina == "fondo":
        return "ninguno", sec
    if pack == "fantasyforest":
        p = "bosque"
        if fina == "seta":
            sec = ["pantano", "cueva"]
        elif fina == "helecho" or n.startswith("spider"):
            sec = ["cueva"]
        elif fina == "raiz":
            sec = ["pantano"]
        elif fina in ("roca", "acantilado"):
            sec = ["cueva", "pantano"]
        elif fina == "hiedra":
            sec = ["ruinas"]
        elif fina in ("hojarasca", "rama"):
            sec = ["pantano"]
    elif pack == "meadows":
        p = "bosque"
        if fina == "cultivo" or fina == "valla":
            p = "ninguno"            # trigo, cebada, zanahoria y vallas: aldea o campo, no bosque
        elif n.startswith("reeds"):
            p, sec = "pantano", ["bosque"]
        elif n.startswith("cypres"):
            sec = ["ruinas"]
        elif fina in ("roca", "acantilado"):
            sec = ["cueva"]
        elif fina == "seta":
            sec = ["pantano"]
    elif pack == "mountains":
        p = "bosque"
        if fina == "cultivo":
            p = "ninguno"
        elif n.startswith("reeds"):
            p, sec = "pantano", ["bosque"]
        elif fina in ("roca", "acantilado"):
            sec = ["cueva"]
    elif pack == "jungle":
        p = "pantano"
        if re.match(r"(banana|musa)", n) or n.startswith("block_"):
            p = "ninguno"            # plataneros: demasiado tropicales; block_*: 0,5 u, sin identificar
        elif fina == "helecho":
            sec = ["cueva", "bosque"]
        elif fina in ("hierba", "arbusto", "rama", "planta_baja"):
            sec = ["bosque"]
        elif fina == "roca":
            sec = ["bosque"]
        elif n.startswith("kapokier"):
            sec = ["bosque"]
    elif pack == "savanna":
        if re.match(r"(wetgrass|lillypads|watermoss|waterfall|ulmaria|bank_)", n):
            p = "pantano"
        elif fina == "escombro" and horiz > 0.5:
            p, sec = "cueva", ["ruinas"]
        elif n.startswith("bigboulders"):
            p, sec = "bosque", []
        elif re.match(r"(bush|branches)", n):
            p = "bosque"
        else:
            p = "ninguno"            # acacias, baobabs, hierba seca: sabana seca
    elif pack == "asianvalley":
        if fina == "roca" or fina == "escombro" or fina == "acantilado":
            p, sec = "bosque", ["cueva"]
        elif fina in ("helecho",) or n.startswith(("grass_", "jenny", "astilb", "cardinal")):
            p = "bosque"
            if fina == "helecho":
                sec = ["cueva"]
        elif n.startswith("osmanthus") or re.match(r"(bush|bigbush)", n):
            p = "bosque"
        elif n.startswith("lotus"):
            p = "pantano"
        elif fina in ("bambu", "vara_bambu", "estructura_bambu"):
            p, sec = "ninguno", ["pantano"]
        else:
            p = "ninguno"            # arroz y verduras de huerto, cascada, etc.
    elif pack == "islands":
        if n.startswith("pandanace"):
            p = "pantano"
        elif fina == "roca" and horiz < 5:
            p, sec = "bosque", ["cueva"]
        elif re.match(r"(bush|grass|branches)", n):
            p = "bosque"
        elif fina == "acantilado":
            p = "ninguno"
        else:
            p = "ninguno"
            if fina in ("planta_isla", "helecho", "flor"):
                sec = ["pantano"]
    return p, sec


def uso_pn(pack, n, fina, horiz, alto):
    if fina == "fondo":
        return "no_usar", "fondo lejano (colina o monte de 30-100 u): no es decorado de sala"
    if fina in ("roca", "escombro") and max(horiz, alto) < 0.2:
        return "no_usar", "escala de importación rota (%.3f u; sus hermanas miden 2-5 u): hoy invisible; arreglable reescalando el FBX" % max(horiz, alto)
    if fina == "acantilado":
        if max(horiz, alto) > 7:
            return "no_usar", "acantilado de %.0f u: no cabe en una sala (casilla = 2,3 u); sirve de telón" % max(horiz, alto)
        return "roca", "acantilado pequeño: zona de roca grande"
    if fina == "marino":
        return "no_usar", "pieza de playa (concha, estrella, perla)"
    if fina in ("roca", "escombro"):
        return "roca", ""
    if fina in ("raiz", "rama"):
        return "tronco", ""
    if fina in ("arbol", "conifera", "palmera", "bambu"):
        return "muro_arboles", ("copa muy ancha (%.0f u): solapa varias casillas" % horiz) if horiz > 8 else ""
    if fina == "arbusto":
        return ("decor_claro" if max(horiz, alto) >= 0.8 else "adorno_borde"), ""
    if fina in ("hierba",):
        return "hierba_corta", ""
    if fina == "cultivo":
        return "hierba_corta", "cultivo de huerto"
    if fina == "flor":
        return ("flor_pequena" if max(horiz, alto) < 1.0 else "decor_claro"), ""
    if fina == "helecho":
        return ("decor_claro" if max(horiz, alto) >= 0.9 else "adorno_borde"), ""
    if fina == "planta_hoja":
        return ("decor_claro" if max(horiz, alto) >= 0.9 else "adorno_borde"), ""
    if fina == "seta":
        return ("decor_claro" if max(horiz, alto) >= 1.4 else "adorno_borde"), ""
    if fina in ("hojarasca", "hiedra"):
        return "adorno_borde", ""
    if fina in ("orilla", "agua"):
        return "adorno_borde", "sobre el agua o en la orilla"
    if fina in ("valla", "estructura_bambu", "vara_bambu"):
        return "decor_claro", ""
    if fina in ("planta_baja", "planta_isla"):
        return ("decor_claro" if max(horiz, alto) >= 0.9 else "adorno_borde"), ""
    return "no_usar", "sin clasificar"


def visible(horiz, alto):
    """Desde la cámara cenital inclinada, a tamaño nativo (el juego reescala algunas con MEDIDAS)."""
    m = max(horiz, alto)
    if m < 0.25:
        return "no"
    if m < 0.6:
        return "poco"
    return "si"


# ----------------------------------------------------------------------------------------------------------------------
# Stylescape: categoría fina y uso
# ----------------------------------------------------------------------------------------------------------------------
def fina_ss(n):
    n = n[3:]
    if n == "sombra_base":
        return "sombra"
    if n.startswith("hangingivy"):
        return "hiedra"
    if n.startswith(("stairs", "wood_stair")):
        return "escalera"
    if n.startswith("railing_pillar") or n.startswith("pillar"):
        return "pilar"
    if n.startswith("railing"):
        return "baranda"
    if n.startswith("rafter"):
        return "viga"
    if n.startswith(("floor_ceiling",)):
        return "techo_suelo"
    if n.startswith(("floor", "wood_floor")):
        return "suelo"
    if n.startswith(("rubble", "stone_", "edge_stones")):
        return "escombro"
    if n.startswith(("wooddoor", "doorframe", "windowframe")) or n.startswith("wall_door"):
        return "puerta_ventana"
    if n.startswith("crate"):
        return "caja"
    if n.startswith("arch"):
        return "arco"
    if "ledge" in n:
        return "cornisa"
    if "archdetail" in n or "window_archdetail" in n:
        return "muro_arco"
    if "thick" in n:
        return "muro_grueso"
    if "half" in n:
        return "muro_bajo"
    if "dmg" in n:
        return "muro_danado"
    if "loophole" in n or "window" in n:
        return "muro_ventana"
    if n.startswith("wall"):
        return "muro"
    return "otro"


def bioma_ss(fina):
    if fina == "hiedra":
        return "ruinas", ["bosque", "pantano"]
    if fina == "escombro":
        return "ruinas", ["cueva", "bosque"]
    if fina == "caja":
        return "ruinas", ["cueva"]
    return "ruinas", []


def leer_caja_tscn(txt):
    m = re.search(r"metadata/caja = AABB\(([^)]*)\)", txt)
    if not m:
        return None
    v = [float(x) for x in m.group(1).split(",")]
    return v[3], v[4], v[5]


# ----------------------------------------------------------------------------------------------------------------------
# Comprobación contra Unreal (mallas en Content o exportadas que no han llegado a arte/)
# ----------------------------------------------------------------------------------------------------------------------
def comprobar_unreal(ids_pn, ids_ss_mallas):
    inf = {"disponible": os.path.isdir(UE_PROYECTO)}
    if not inf["disponible"]:
        return inf
    exp_pn = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(UE_EXP_PN, "mallas"))} if os.path.isdir(UE_EXP_PN) else set()
    exp_ss = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(UE_EXP_SS, "mallas"))} if os.path.isdir(UE_EXP_SS) else set()
    content = os.path.join(UE_PROYECTO, "Content")
    sm_pn, sm_ss, foliage = defaultdict(set), set(), []
    for dp, _, fn in os.walk(content):
        rel = os.path.relpath(dp, content).split(os.sep)
        for f in fn:
            if f.startswith("SM_") and f.endswith(".uasset"):
                nom = f[:-7]
                if rel[0].startswith("PureNature_"):
                    sm_pn[rel[0]].add(nom)
                elif rel[0] == "Stylescape":
                    if "FoliageTypes" in rel:
                        foliage.append(nom)
                    else:
                        sm_ss.add(nom)
    sin_exportar = []
    for pk, nombres in sm_pn.items():
        for nom in sorted(nombres):
            if pk + "__" + nom not in exp_pn:
                sin_exportar.append(pk + " " + nom)
    sin_exportar_ss = sorted(n for n in sm_ss if n not in exp_ss)
    inf.update({
        "sm_pn": {k: len(v) for k, v in sorted(sm_pn.items())}, "sm_ss": len(sm_ss), "foliage_types": len(foliage),
        "exportadas_pn": len(exp_pn), "exportadas_ss": len(exp_ss),
        "sin_exportar_pn": sorted(sin_exportar), "sin_exportar_ss": sin_exportar_ss,
        "exportadas_sin_pieza_ss": sorted(n for n in exp_ss if ("ss_" + n[3:].lower()) not in ids_ss_mallas),
        "exportadas_sin_pieza_pn": sorted(n for n in exp_pn if n not in ids_pn),
    })
    return inf


# ----------------------------------------------------------------------------------------------------------------------
def main():
    indice = json.loads(leer(os.path.join(PN, "indice.json")))
    usos = usos_pure_nature()
    directos_pn = usos_directos(["presentacion", "mundo", "nucleo", "objetos", "enemigos", "jugador", "magia", "escenas"],
                                r"\bpn_(?:%s)_\w+" % "|".join(PACKS))
    filas = []

    # ---- Pure Nature
    for pid in sorted(indice):
        d = indice[pid]
        pack = pid.split("_")[1]
        n = nombre_corto(pid, pack)
        sx, sy, sz = d["caja"][3:6]
        horiz = max(sx, sz)
        cat = d["categoria"]
        fina = fina_pn(pack, n, cat, horiz, sy)
        bp, bs = bioma_pn(pack, n, fina, horiz, sy)
        uso, nota = uso_pn(pack, n, fina, horiz, sy)
        vis = visible(horiz, sy)
        notas = [nota] if nota else []
        if vis == "no" and uso not in ("no_usar",):
            notas.append("a tamaño nativo no se ve desde la cámara: solo en mantos o reescalada")
        elif vis == "poco" and uso in ("hierba_corta", "flor_pequena", "adorno_borde"):
            notas.append("pequeña: mejor en grupos o reescalada")
        if n.startswith(("waterfall", "bank_")):
            notas.append("no revisada a ojo: probable malla de cascada/orilla que pide material de agua propio")
        if n.startswith("spider"):
            notas.append("planta sin identificar por el nombre")
        if fina == "planta_isla":
            notas.append("nombre inventado por el autor (planta de isla); no identificada a ojo")
        if uso == "no_usar":
            bp, bs = "ninguno", []
        ju = usos.get(pid, [])
        extra = sorted(directos_pn.get(pid, []))
        usada = ";".join(ju) if ju else (";".join("codigo:" + x for x in extra) if extra else "")
        filas.append({
            "id": pid, "pack": pack, "categoria": cat, "categoria_fina": fina,
            "ruta_tscn": "res://arte/pure_nature/piezas/%s.tscn" % pid,
            "x": sx, "y": sy, "z": sz, "usada_en_juego": usada,
            "tiene_version_juego": "si" if os.path.exists(os.path.join(PN, "juego", pid + ".tscn")) else "no",
            "bioma_sugerido": bp, "biomas_secundarios": ",".join(bs), "uso_sugerido": uso,
            "visible_camara": vis, "nota": "; ".join(notas),
        })

    # ---- Stylescape
    dir_ss = os.path.join(SS, "piezas")
    ss_usadas = set()
    pared = leer(os.path.join(RAIZ, "presentacion", "paredes_stylescape.gd"))
    for m in re.finditer(r"SM_\w+", pared):
        ss_usadas.add("ss_" + m.group(0)[3:].lower())
    sombra_id = re.search(r'SOMBRA_BASE\s*:?=?\s*(?:String\s*=\s*)?"(\w+)"', pared)
    if sombra_id:
        ss_usadas.add(sombra_id.group(1))
    directos_ss = usos_directos(["presentacion", "mundo", "nucleo", "objetos", "enemigos", "jugador", "magia", "escenas"], r"\bss_\w+")
    ids_ss = set()
    for f in sorted(os.listdir(dir_ss)):
        if not (f.startswith("ss_") and f.endswith(".tscn")):
            continue
        pid = f[:-5]
        ids_ss.add(pid)
        txt = leer(os.path.join(dir_ss, f))
        caja = leer_caja_tscn(txt) or (0.0, 0.0, 0.0)
        sx, sy, sz = caja
        fina = fina_ss(pid)
        bp, bs = bioma_ss(fina)
        uso = "ruina"
        notas = []
        if fina == "sombra":
            uso = "no_usar"
            notas.append("auxiliar: franja de sombra de contacto que ya pone paredes_stylescape")
        elif fina == "hiedra":
            uso = "adorno_borde"
            notas.append("cuelga de lo alto de un muro")
        elif fina in ("techo_suelo", "viga"):
            notas.append("interior/techo: solo con cámara que lo permita")
        elif fina == "suelo" and "topface" in pid:
            notas.append("losa de suelo (cara superior)")
        usada = "paredes_stylescape" if pid in ss_usadas else ";".join("codigo:" + x for x in sorted(directos_ss.get(pid, [])))
        filas.append({
            "id": pid, "pack": "stylescape", "categoria": re.search(r'metadata/categoria = "(\w+)"', txt).group(1) if "metadata/categoria" in txt else "",
            "categoria_fina": fina, "ruta_tscn": "res://arte/stylescape/piezas/%s.tscn" % pid,
            "x": sx, "y": sy, "z": sz, "usada_en_juego": usada, "tiene_version_juego": "n/a",
            "bioma_sugerido": bp, "biomas_secundarios": ",".join(bs), "uso_sugerido": uso,
            "visible_camara": visible(max(sx, sz), sy), "nota": "; ".join(notas),
        })

    # ---- TSV
    cols = ["id", "pack", "categoria", "ruta_tscn", "tam_x", "tam_y", "tam_z", "usada_en_juego", "tiene_version_juego",
            "bioma_sugerido", "uso_sugerido", "nota", "categoria_fina", "biomas_secundarios", "visible_camara"]
    os.makedirs(os.path.dirname(SALIDA_TSV), exist_ok=True)
    with open(SALIDA_TSV, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(cols)
        for r in filas:
            w.writerow([r["id"], r["pack"], r["categoria"], r["ruta_tscn"], "%.3f" % r["x"], "%.3f" % r["y"], "%.3f" % r["z"],
                        r["usada_en_juego"], r["tiene_version_juego"], r["bioma_sugerido"], r["uso_sugerido"], r["nota"],
                        r["categoria_fina"], r["biomas_secundarios"], r["visible_camara"]])
    print("TSV:", SALIDA_TSV, len(filas), "filas")

    claves_pn = {d["pack"] + "__" + d["ruta_ue"].split("/")[-1] for d in indice.values()}
    unreal = comprobar_unreal(claves_pn, ids_ss)
    escribir_md(filas, unreal)
    print("MD:", SALIDA_MD)
    return filas, unreal


# ----------------------------------------------------------------------------------------------------------------------
def med(v):
    return statistics.median(v) if v else 0.0


def escribir_md(filas, unreal):
    por_pack = defaultdict(list)
    for r in filas:
        por_pack[r["pack"]].append(r)
    orden = PACKS + ["stylescape"]
    L = []
    a = L.append
    a("# Inventario de assets traídos de Unreal — 26/11/2026")
    a("")
    a("Generado por `python tools/inventario_assets_unreal.py` (se puede repetir: lee el índice, las piezas y las tablas del juego). "
      "Una fila por pieza en [`docs/fab_ue/inventario_piezas.tsv`](fab_ue/inventario_piezas.tsv). Las reglas de bioma y uso son de Claude "
      "(por nombre, categoría y tamaño) y están **sin ver pieza a pieza en pantalla**: Pablo decide.")
    a("")
    a("Tamaños en **u de juego** (la caja ya lleva la escala 0,575; 1 casilla = 2,3 u = 4 m). «Visible» = a tamaño nativo desde la cámara "
      "cenital inclinada: **no** < 0,25 u, **poco** < 0,6 u, **sí** el resto (el juego reescala algunas con `MEDIDAS`, p. ej. las margaritas a 2,3 u de manto).")
    a("")
    # --- Resumen global
    tot = len(filas)
    usadas = [r for r in filas if r["usada_en_juego"]]
    a("## Resumen")
    a("")
    a("| Pack | Piezas | Usadas por el juego | Con versión del juego | Encajan en bosque (principal) | Bosque (principal o secundario) |")
    a("|---|---:|---:|---:|---:|---:|")
    for p in orden:
        rs = por_pack[p]
        us = sum(1 for r in rs if r["usada_en_juego"])
        vj = sum(1 for r in rs if r["tiene_version_juego"] == "si")
        bq = sum(1 for r in rs if r["bioma_sugerido"] == "bosque")
        bq2 = sum(1 for r in rs if r["bioma_sugerido"] == "bosque" or "bosque" in r["biomas_secundarios"].split(","))
        a("| %s | %d | %d | %s | %d | %d |" % (NOMBRE_PACK[p], len(rs), us, vj if p != "stylescape" else "n/a", bq, bq2))
    a("| **Total** | **%d** | **%d** | %d | %d | %d |" % (
        tot, len(usadas), sum(1 for r in filas if r["tiene_version_juego"] == "si"),
        sum(1 for r in filas if r["bioma_sugerido"] == "bosque"),
        sum(1 for r in filas if r["bioma_sugerido"] == "bosque" or "bosque" in r["biomas_secundarios"].split(","))))
    a("")
    a("### Por uso sugerido")
    a("")
    usos_orden = ["muro_arboles", "decor_claro", "adorno_borde", "hierba_corta", "flor_pequena", "roca", "tronco", "ruina", "no_usar"]
    a("| Pack | " + " | ".join(usos_orden) + " |")
    a("|---|" + "---:|" * len(usos_orden))
    for p in orden:
        c = Counter(r["uso_sugerido"] for r in por_pack[p])
        a("| %s | " % NOMBRE_PACK[p] + " | ".join(str(c.get(u, 0)) for u in usos_orden) + " |")
    c = Counter(r["uso_sugerido"] for r in filas)
    a("| **Total** | " + " | ".join("**%d**" % c.get(u, 0) for u in usos_orden) + " |")
    a("")
    a("`uso_sugerido` es lo que la pieza *es*; `bioma_sugerido` dice dónde encaja. Una acacia es `muro_arboles` con bioma `ninguno`. "
      "`no_usar` = telón lejano, acantilado de más de 7 u, escala rota, conchas o pieza auxiliar.")
    a("")
    a("### Sin usar que encajan en bosque")
    a("")
    libres = [r for r in filas if not r["usada_en_juego"] and r["uso_sugerido"] != "no_usar"]
    bq_libres = [r for r in libres if r["bioma_sugerido"] == "bosque"]
    bq_libres2 = [r for r in libres if r["bioma_sugerido"] == "bosque" or "bosque" in r["biomas_secundarios"].split(",")]
    a("De %d piezas aprovechables sin usar, **%d** encajan en bosque como bioma principal (**%d** contando secundario). Por uso:" % (
        len(libres), len(bq_libres), len(bq_libres2)))
    a("")
    cb = Counter(r["uso_sugerido"] for r in bq_libres)
    a("| " + " | ".join(usos_orden[:-1]) + " |")
    a("|" + "---:|" * (len(usos_orden) - 1))
    a("| " + " | ".join(str(cb.get(u, 0)) for u in usos_orden[:-1]) + " |")
    a("")
    a("Las que más aportarían al bosque y hoy no se usan: ")
    a("")
    a("- **Muro de árboles** (los `#`): %d piezas en bosque sin usar (abedules, olmos, robles, pinos, píceas, abetos, cipreses)." % cb.get("muro_arboles", 0))
    a("- **Rocas, setas, helechos, ramas, raíces y hojarasca** para el suelo y los bordes.")
    a("- **Muy pequeñas para verse** (`visible = no`/`poco`): los mantos de florecitas y hierbas finas se ven solo en grupo o reescaladas.")
    a("")

    # --- Por pack
    for p in orden:
        rs = por_pack[p]
        a("## %s (%d piezas)" % (NOMBRE_PACK[p], len(rs)))
        a("")
        porfina = defaultdict(list)
        for r in rs:
            porfina[r["categoria_fina"]].append(r)
        a("| Categoría | Piezas | Tamaño típico (ancho × alto, mediana; rango alto) | Usadas | Visible desde la cámara | Encaja en |")
        a("|---|---:|---|---:|---|---|")
        for fina in sorted(porfina, key=lambda k: -len(porfina[k])):
            g = porfina[fina]
            hz = [max(r["x"], r["z"]) for r in g]
            al = [r["y"] for r in g]
            usad = sum(1 for r in g if r["usada_en_juego"])
            vis = Counter(r["visible_camara"] for r in g)
            vtxt = "/".join("%s %d" % (k, vis[k]) for k in ("si", "poco", "no") if vis.get(k))
            enc = Counter(r["bioma_sugerido"] for r in g)
            sec = set()
            for r in g:
                sec.update(x for x in r["biomas_secundarios"].split(",") if x)
            etxt = ", ".join("%s (%d)" % (k, v) for k, v in enc.most_common())
            if sec:
                etxt += "; sec.: " + ", ".join(sorted(sec))
            a("| %s | %d | %.1f × %.1f u (alto %.1f–%.1f) | %d | %s | %s |" % (fina, len(g), med(hz), med(al), min(al), max(al), usad, vtxt, etxt))
        a("")
        us = sorted((r for r in rs if r["usada_en_juego"]), key=lambda r: r["id"])
        if us:
            a("Usadas por el juego (%d): " % len(us) + ", ".join("`%s`→%s" % (r["id"].replace("pn_%s_" % p, ""), r["usada_en_juego"]) for r in us))
            a("")
        raras = [r for r in rs if r["uso_sugerido"] == "no_usar"]
        if raras:
            a("`no_usar` (%d): " % len(raras) + ", ".join("`%s`" % r["id"].replace("pn_%s_" % p, "") for r in raras[:40]) + (" …" if len(raras) > 40 else ""))
            a("")

    # --- Veredicto por pack
    a("## Qué encaja en cada bioma (criterio)")
    a("")
    a("- **Bosque**: Fantasy Forest, Meadows y Mountains casi enteros (árboles, arbustos, helechos, setas, rocas musgosas, flores de claro). "
      "Las coníferas de Mountains valen para el pinar; el ciprés y el olmo, para el borde.")
    a("- **Pantano**: Jungle (kapokier, helechos, filodendros, rocas de jungla), y de Savanna solo lo húmedo (hierba mojada, nenúfares, musgo de agua, orillas); "
      "lotos de Asian Valley, juncos de Meadows/Mountains, pandanáceas de Islands.")
    a("- **Cueva**: ninguna pieza es de cueva; valen como secundarias helechos, setas, rocas musgosas y escombro.")
    a("- **Ruinas**: Stylescape entero; hiedras como adorno también para bosque y pantano.")
    a("- **Ninguno**: Asian Valley casi entero (huerto, arroz, bambú, colinas), Islands (coco, algas, conchas, plantas de playa), sabana seca (acacia, baobab, hierba seca), "
      "cultivos y vallas de Meadows/Mountains, plataneros.")
    a("")

    # --- Unreal
    a("## Lo que hay en Unreal y no ha llegado a `arte/`")
    a("")
    if not unreal.get("disponible"):
        a("No se pudo comprobar (no está `E:\\ue_proyectos\\StylescapeRuins` en esta máquina).")
    else:
        a("Comprobado leyendo los nombres de los `.uasset` de `Content` (sin abrir Unreal) contra las carpetas `*_export` y las piezas de `arte/`.")
        a("")
        a("- Mallas estáticas (`SM_*`) en Content: " + ", ".join("%s %d" % (k.replace("PureNature_", ""), v) for k, v in unreal["sm_pn"].items()) +
          "; Stylescape %d (+ %d `FoliageTypes`, que son ajustes de follaje y no mallas)." % (unreal["sm_ss"], unreal["foliage_types"]))
        a("- Exportadas: Pure Nature %d, Stylescape %d. Piezas en `arte/`: %d `pn_*`, %d `ss_*`." % (
            unreal["exportadas_pn"], unreal["exportadas_ss"], sum(1 for r in filas if r["pack"] != "stylescape"), sum(1 for r in filas if r["pack"] == "stylescape")))
        sinx = unreal["sin_exportar_pn"]
        a("- **Mallas de Content sin exportar: %d** → %s. Son los montes de fondo `Models/Mountains` de Meadows y Mountains; el exportador "
          "(`tools/ue_exportar_pure_nature.py`, constante `FUERA`) los deja fuera a propósito, junto con nubes, efectos y niebla. No son decorado de sala." % (
              len(sinx), ", ".join(sinx) if sinx else "ninguna"))
        a("- Stylescape: mallas sin exportar: %s." % (", ".join(unreal["sin_exportar_ss"]) or "ninguna"))
        a("- Exportadas sin pieza `.tscn`: Pure Nature %s; Stylescape %s (`SM_Slope` y `SM_Circle_01` son a propósito: `EXCLUIDAS` en `paredes_stylescape.gd`, "
          "el plano inclinado y el círculo de muestrario de Unreal)." % (
              ", ".join(unreal["exportadas_sin_pieza_pn"]) or "ninguna", ", ".join(unreal["exportadas_sin_pieza_ss"]) or "ninguna"))
        a("- `Content/MagicSymbols` tiene solo materiales propios (21 `MI_SinTerreno_*`, variantes sin terreno de materiales de Pure Nature): no son mallas. "
          "`Collections` y `Developers` están vacías.")
        a("- No comprobado: texturas y materiales uno a uno (solo mallas), ni que cada FBX importe bien en Godot más allá de que existe su pieza.")
    a("")
    a("## Piezas con tamaño sospechoso")
    a("")
    rotas = [r for r in filas if r["pack"] != "stylescape" and r["uso_sugerido"] == "no_usar" and max(r["x"], r["y"], r["z"]) < 0.2
             and r["categoria_fina"] in ("roca", "escombro")]
    a("- **Escala rota (%d)**: %s. Miden menos de 0,2 u (el resto de rocas de la sabana miden 2–5 u): el FBX se importó en otra escala." % (
        len(rotas), ", ".join("`%s`" % r["id"].replace("pn_savanna_", "") for r in rotas)))
    enormes = [r for r in filas if r["pack"] != "stylescape" and max(r["x"], r["z"]) > 30]
    a("- **Telones enormes (%d)**: %s." % (len(enormes), ", ".join("`%s` (%.0f u)" % (r["id"], max(r["x"], r["z"])) for r in enormes)))
    a("")
    with open(SALIDA_MD, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")


if __name__ == "__main__":
    main()
