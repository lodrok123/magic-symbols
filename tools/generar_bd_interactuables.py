# -*- coding: utf-8 -*-
"""Genera docs/BD_INTERACTUABLES.xlsx: la base de datos de interactuables del juego.

Dos hojas escritas a mano a partir de leer el código (escenas/puzle.gd, objetos/*.gd, ARQUITECTURA.md) y las tablas:
  · Interactuables   una fila por PIEZA (tipo de Puzle3D, reactivo, enemigo, NPC...) con lo que es, cómo se coloca y qué sabe hacer.
  · Interacciones    una fila por (pieza, lo que le llega -> lo que hace): la misma idea que nucleo/datos/reactivos_mapa.tsv, pero
                     con TODO lo que el código ya hace y las piezas separadas (una por fila).
Y una hoja por cada TSV de nucleo/datos/ (copiadas tal cual al generar, para tenerlo todo en un sitio).

Uso:  python tools/generar_bd_interactuables.py
"""
import csv
import os
import sys

from openpyxl import Workbook
from openpyxl.comments import Comment
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(RAIZ, "nucleo", "datos")
SALIDA = os.path.join(RAIZ, "docs", "BD_INTERACTUABLES.xlsx")

FUENTE = "Arial"
FILAS_LIBRES = 25          # filas vacías con formato y desplegables al final de cada hoja editable

# ---------------------------------------------------------------------------------------------------------------------
# VOCABULARIO (los desplegables)
# ---------------------------------------------------------------------------------------------------------------------
FAMILIAS = ["combustible", "fuego_de_mapa", "agua", "electricidad", "pulso", "recolectable", "rompible", "contenedor",
            "paso", "logica", "fisica", "enemigo", "npc", "nivel", "ambiente", "fauna", "decorado"]
LLEGA = ["fuego", "agua", "hielo", "rayo", "tierra", "viento", "cualquier_hechizo", "golpe", "E", "pulso", "pulso_jugador",
         "explosion", "presencia", "empujon", "corriente", "tiempo", "regla", "enemigo", "pisar"]
ESTADOS = ["hay", "cambio", "nuevo", "idea"]
BLOQUEA = ["si", "no", "mientras_entero", "mientras_cerrado", "mientras_lava", "mientras_colgado"]
ZONAS = ["todas", "bosque", "cueva", "ruinas", "campamento", "santuario", "gruta", "tumulo", "volcan", "bosque_humedo",
         "cumbre", "pantano"]
ELEMENTOS = ["fuego", "agua", "hielo", "rayo", "tierra", "viento"]
PAPELES = ["inflamable", "propaga_llama", "apaga", "mojable", "pesado", "conduce", "congelable", "fuente_fuego", "activable",
           "recibe_agua", "sacudible", "helable"]

# ---------------------------------------------------------------------------------------------------------------------
# INTERACTUABLES
# id · nombre · familia · clase · archivo · colocación · claves del mapa · bloquea · reacciona a · señales · condiciones (si=) ·
# acciones (hace=) · papeles · da / botín · flag · zona · estado · notas
# ---------------------------------------------------------------------------------------------------------------------
CAB_INTER = ["id", "nombre", "familia", "clase", "archivo", "colocacion", "claves_mapa", "bloquea_casilla", "reacciona_a",
             "senales", "condiciones_si", "acciones_hace", "papeles", "da_botin", "flag", "zona", "estado", "notas"]

INTERACTUABLES = [
    # --- combustibles (Reactivo3D) ---
    ["seto", "Seto", "combustible", "Reactivo3D", "objetos/objetos_3d.gd", "letra z · ; pieza seto", "mojable=si|no",
     "mientras_entero", "fuego, rayo, agua, hielo, viento", "consumido, activado", "ardiendo", "encender",
     "inflamable, propaga_llama, apaga", "tabla:seto_quemado (carbón 30 %)", "-", "todas", "hay",
     "Arde 3,5 s, se chamusca y desaparece. Contagia a ≤ 1,7 casillas cada 0,8 s; el viento lleva la llama a ≤ 3,6 en su cono. Mojado (12 s) no prende."],
    ["tronco", "Tronco", "combustible", "Reactivo3D", "objetos/objetos_3d.gd", "letra del mapa", "-", "mientras_entero",
     "fuego, rayo, agua, hielo, viento", "consumido", "-", "-", "inflamable, propaga_llama, apaga", "tabla:seto_quemado", "-", "todas", "hay",
     "Como el seto, arde 4 s."],
    ["telarana", "Telaraña", "combustible", "Reactivo3D", "objetos/objetos_3d.gd", "letra del mapa", "-", "mientras_entero",
     "fuego, rayo, hielo, E (helada)", "consumido", "-", "-", "inflamable, propaga_llama, apaga, helable", "seda:1 (helada + E)", "-", "todas", "hay",
     "Arde 1,6 s. Helada deja de bloquear, ya no arde y se recoge con E."],
    ["puerta_goblin", "Puerta goblin", "combustible", "Reactivo3D", "objetos/objetos_3d.gd", "letra y", "-", "mientras_entero",
     "fuego, rayo, agua, hielo", "consumido", "-", "-", "inflamable, propaga_llama, apaga", "tabla:seto_quemado", "-", "bosque", "hay",
     "Madera del campamento: arde 5 s y deja el paso libre."],
    ["torre_goblin", "Torre goblin", "combustible", "Reactivo3D", "objetos/objetos_3d.gd", "letra o", "-", "mientras_entero",
     "fuego, rayo, agua, hielo", "consumido", "-", "-", "inflamable, propaga_llama, apaga", "tabla:seto_quemado", "-", "bosque", "hay", "Arde 7 s."],
    ["arbol", "Árbol", "fauna", "Reactivo3D", "objetos/objetos_3d.gd", "; pieza arbol", "modelo=arbol_redondo|arbol_redondo_2|pino|pino_2",
     "si", "golpe (F), fuego", "-", "-", "-", "sacudible", "tabla:tronco_golpe (resina 40 %, corteza 20 %) cada 30 s", "-", "bosque", "hay",
     "El golpe cuerpo a cuerpo lo sacude. El fuego (reactivos_mapa: arde 6 s y queda chamuscado) está anotado como «nuevo»."],
    ["cuerda", "Cuerda", "combustible", "Cuerda3D", "objetos/cuerda_3d.gd", "; pieza cuerda", "sostiene=<id>", "no",
     "fuego, rayo, contagio, agua", "rota, ardiendo_cambio", "rota, entera", "quemar", "(grupo flammable3d)", "-", "-", "todas", "hay",
     "Arde 1 s y se rompe; lo que sostiene cae (compuerta -> cerrar, puente -> tender). El agua no arregla una cuerda rota."],
    ["enredadera", "Enredadera / bloqueo de enredaderas", "combustible", "Enredadera3D", "objetos/enredadera_3d.gd", "código (elemental) · marcador bloqueo",
     "-", "mientras_entero", "fuego", "foco, deshecha", "-", "-", "-", "-", "-", "bosque", "hay",
     "Brota, arde por focos (prende lo cercano) y se deshace. Solo el fuego la quema."],
    ["barril", "Barril de pólvora", "combustible", "Barril3D", "objetos/barril_3d.gd", "; pieza barril", "-", "si",
     "fuego, rayo, agua, contagio, lava", "explota", "explotado, encendido, entero", "encender, apagar", "-", "-", "-", "todas", "hay",
     "Mecha 1,2 s y explota en 2,6 u: avisa al grupo explosionable (muro, compuerta roca, jarrón, otro barril). Daña 25 en 1,5 casillas (reactivos_mapa)."],
    # --- fuego de mapa ---
    ["fogata", "Fogata", "fuego_de_mapa", "Reactivo3D", "objetos/objetos_3d.gd", "letra del mapa", "-", "si",
     "fuego, agua, hielo, viento, E (encendida)", "activado, llama, hoguera_abierta", "encendido, apagado", "encender, apagar",
     "fuente_fuego, apaga", "-", "-", "todas", "hay", "Nace encendida. Con E encendida: HOGUERA (síntesis de campo + guardar partida)."],
    ["brasero", "Brasero / antorcha", "fuego_de_mapa", "Reactivo3D", "objetos/objetos_3d.gd", "letra T · ; pieza brasero",
     "rele=<id> espera=<s> dura=<s> luz=<x> modelo=cueva", "si", "fuego, pulso de fuego, agua, hielo, viento, E (encendido)",
     "encendido, apagado, llama, hoguera_abierta", "encendido, apagado", "encender, apagar", "fuente_fuego, apaga", "-", "-", "todas", "hay",
     "Nace apagado. Con relé enciende al siguiente de la fila y se apaga solo. En la Cueva alumbra (luz=2.2)."],
    ["lava", "Lava", "fuego_de_mapa", "Lava3D", "objetos/lava_3d.gd", "; pieza lava", "celdas=<lista> vuelve=<s>", "mientras_lava",
     "agua, hielo, agua de la simulación", "enfriada, apagada", "activa, apagada", "enfriar", "-",
     "basalto (agua) / obsidiana (hielo) vía Recolectable3D basalto", "-", "cueva", "hay",
     "No se pisa, alumbra, prende lo inflamable de al lado cada CADA_FUEGO s. Enfriada en roca (la casilla y 4 vecinas); con vuelve=s se funde otra vez."],
    # --- agua ---
    ["surtidor", "Surtidor / tinaja", "agua", "Surtidor3D · Reactivo3D", "objetos/surtidor_3d.gd · objetos/objetos_3d.gd", "letra u · ; pieza tinaja",
     "canal=<lista>", "si", "agua", "lleno, activado, agua_llega", "-", "mojar, abrir_cauce(caudal,volumen), apagar_fuente", "recibe_agua", "-", "-", "bosque", "hay",
     "Con agua se llena, se inclina y vierte: llena el cauce seco y lo une al río. El hielo no lo llena."],
    ["compuerta", "Compuerta", "agua", "Compuerta3D", "objetos/compuerta_3d.gd", "; pieza compuerta",
     "abierta abre_con=fuego|agua|hielo|rayo|explosion cierra_con=… estrecha vertical", "no (cauce)", "según abre_con / cierra_con, regla, explosión",
     "abierta, cerrada", "abierta, cerrada", "abrir, cerrar, alternar", "-", "-", "-", "todas", "hay",
     "Pared en un cauce: cerrada aparta el agua, abierta la deja pasar. De hielo = abre_con=fuego; roca = abre_con=explosion."],
    ["nivel", "Detector de nivel", "logica", "NivelAgua3D", "objetos/nivel_agua_3d.gd", "; pieza nivel", "objetivo=<u> banda=<u> invertido", "no",
     "profundidad del agua", "alcanzado, perdido", "alcanzado, perdido", "-", "-", "-", "-", "todas", "hay", "Solo avisa (con histéresis). No reacciona a hechizos."],
    ["molino", "Molino de agua", "agua", "Molino3D", "objetos/molino_3d.gd", "; pieza molino", "umbral=<u/s> vertical", "no",
     "corriente, agua (hechizo)", "girando, parado", "girando, parado", "-", "-", "-", "-", "todas", "hay", "Gira con corriente > umbral o 6 s tras un hechizo de agua."],
    ["cuenca", "Cuenca", "agua", "(Puzle3D)", "escenas/puzle.gd", "; pieza cuenca", "celdas=<lista> nivel=<u> fijo=<u>|si", "no",
     "regla", "-", "-", "helar(s)", "-", "-", "-", "todas", "hay", "Abre casillas al agua; nivel las llena; fijo mantiene el nivel (desagüe)."],
    ["manantial", "Manantial", "agua", "(Puzle3D)", "escenas/puzle.gd", "; pieza manantial",
     "caudal volumen rampa inicia celdas sin_piedra bloque terraza pilares espuma", "no", "regla", "-", "-", "abrir_cauce(caudal,volumen), apagar_fuente, helar(s)", "-", "-", "-", "todas", "hay",
     "Echa agua en x,y. inicia=no espera a abrir_cauce."],
    ["nexo", "Nexo eléctrico", "electricidad", "NexoRayo3D", "objetos/nexo_rayo_3d.gd", "; pieza nexo", "-", "no",
     "agua, fuego, tiempo", "conduce, corta", "conduce, corta", "mojar, secar", "-", "-", "-", "todas", "hay",
     "Pila de piedra: mojada conduce 30 s; el fuego la seca al momento."],
    ["emisor", "Emisor de rayo", "electricidad", "EmisorRayo3D", "objetos/emisor_rayo_3d.gd", "letra e · ; pieza emisor", "-", "si",
     "regla (pulso)", "descarga", "-", "pulso(alcance)", "conduce", "-", "-", "todas", "hay",
     "Cada 4 s descarga 1,6 s por el agua conectada (4 vecinas): hiere 8 cada 0,4 s y activa tótems de rayo. El hielo corta."],
    ["charca", "Charca", "agua", "(mundo: AguaSim3D)", "mundo/agua_sim_3d.gd", "letra ~ / cuenca", "-", "si (agua)",
     "hielo, fuego, rayo, tierra", "casilla_cambio", "casilla(x,y).helada|agua", "-", "-", "alga_cueva (helada + E)", "-", "cueva", "hay",
     "Helada 20 s: se pisa, atrapa flotadores y goblins; el alga se ve y se coge."],
    ["flotador", "Flotador (tronco, caja)", "fisica", "Flotador3D", "objetos/flotador_3d.gd", "código", "-", "no",
     "corriente, hielo", "-", "-", "-", "-", "-", "-", "todas", "hay", "Cuerpo rígido que flota y deriva; el hielo lo atrapa."],
    ["tronco_estanque", "Tronco del estanque", "paso", "TroncoEstanque3D", "objetos/tronco_estanque_3d.gd", "marcador V T", "-", "no",
     "profundidad del agua", "paso_abierto", "-", "-", "-", "-", "-", "bosque", "hay", "Sube con el agua; a 0,45 u su casilla pasa a puente (b)."],
    # --- pasos ---
    ["puente", "Puente reactivo (losas)", "paso", "PuenteReactivo3D · Reactivo3D (plegado)", "objetos/puente_reactivo_3d.gd", "marcador P · ; pieza puente",
     "celdas=<lista>", "no", "regla (tender), cuerda, tótem", "tendido, losa_lista, completo", "tendido, plegado", "tender", "-", "-", "-", "todas", "hay",
     "Losas que emergen una a una; cada casilla se vuelve puente."],
    ["tronco_puente", "Tronco-puente", "paso", "TroncoPuente3D", "objetos/tronco_puente_3d.gd", "marcador P (grupo tronco_puente)", "-", "si",
     "fuego", "-", "-", "-", "-", "-", "-", "bosque", "hay", "En pie en la orilla; con fuego cae cruzando el río y queda de puente."],
    ["puerta", "Puerta (losa, llave, reja)", "paso", "PuertaPuzle", "escenas/puzle.gd", "; pieza puerta",
     "modelo=llave|reja giro llave=<flag> gasta abierto=<flag>", "mientras_cerrado", "regla, E / tocar (con llave)", "abierta, cerrada", "abierta, cerrada",
     "abrir, cerrar, alternar", "-", "-", "abierto=<flag>", "todas", "cambio",
     "Con llave= pide la flag; gasta=si la quita. reactivos_mapa: pasar a leer tener.llave y quitar la llave de la bolsa."],
    ["cerrojo", "Cerrojo de sala", "paso", "CerrojoPuzle", "escenas/puzle.gd", "; pieza cerrojo", "celdas sala hasta=<flag>", "mientras_cerrado",
     "pisar la sala, regla", "cerrado, abierto", "cerrado, abierto", "abrir, cerrar", "-", "-", "-", "todas", "hay",
     "Puertas de sala: se cierran al entrar; abrir es definitivo."],
    ["muro", "Muro agrietado", "paso", "MuroAgrietado3D", "objetos/muro_agrietado_3d.gd", "; pieza muro", "golpes=<n>", "mientras_entero",
     "tierra (×golpes), explosion", "roto", "roto, entero", "romper", "-", "-", "<nivel>.<sala>.muro", "todas", "hay",
     "Lo demás no le hace nada pero la casilla es sólida."],
    ["columna", "Columna agrietada / columna-puente", "pulso", "MuroAgrietado3D (como_columna)", "objetos/muro_agrietado_3d.gd", "; pieza columna",
     "golpes cae=n|e|s|o puente=<id lava> largo flag", "mientras_entero", "pulso (×golpes), explosion", "cae", "caida, en_pie", "romper", "-", "-", "flag=", "cueva", "hay",
     "Al golpes-ésimo pulso cae hacia cae. Columna-puente: cubre la lava para siempre."],
    ["pared_hueca", "Pared hueca", "pulso", "ParedHuecaPulso3D", "objetos/pared_hueca_pulso_3d.gd", "; pieza pared_hueca", "flag mira=n|e|s|o", "mientras_cerrado",
     "pulso (eco), pulso_jugador (abre)", "eco, abierta", "abierta, cerrada", "abrir", "-", "-", "flag=", "cueva", "hay",
     "Cualquier pulso: eco (pista). Solo el pulso del jugador (ᚱ) la abre."],
    ["bloque", "Bloque empujable", "fisica", "BloqueEmpujable3D", "objetos/bloque_empujable_3d.gd", "; pieza bloque", "material=piedra|hielo", "si",
     "empujon (jugadora), viento", "movido, reaparece", "quieto, en_marcha", "-", "pesado", "-", "-", "cueva", "hay",
     "Piedra: una casilla por empujón; sobre un hueco de veta lo tiende. Hielo: resbala hasta chocar. Atascado se deshace a los 3 s."],
    ["pulsador", "Pulsador / botón / placa", "logica", "Pulsador3D", "objetos/pulsador_3d.gd", "; pieza pulsador", "modo=magia|agua|presencia rearme=<s> modelo=cueva", "no",
     "cualquier_hechizo (magia) · agua · presencia (jugadora, peso)", "pulsado, soltado", "activo, libre", "pulsar", "-", "-", "-", "todas", "hay",
     "Solo avisa. Si el golpe no vale, lo dice («SOLO AGUA»)."],
    ["placa", "Placa de peso (maqueta)", "logica", "Reactivo3D", "objetos/objetos_3d.gd", "letra del mapa", "-", "no", "presencia (grupo peso)", "activado", "-", "-", "-", "-", "-", "todas", "hay",
     "Se hunde y se queda cuando algo con peso la pisa (bloque de tierra, empujable). La jugadora no pesa."],
    ["totem", "Tótem (fuego | agua | rayo)", "logica", "Reactivo3D", "objetos/objetos_3d.gd", "letra i · ; pieza totem", "-", "si",
     "su elemento (fuego · agua · rayo/descarga)", "activado", "-", "-", "activable", "-", "-", "bosque", "hay", "Se activa una vez con SU elemento y se queda brillando."],
    ["contador", "Contador de encendidos", "logica", "ContadorReactivos3D", "objetos/contador_reactivos_3d.gd", "; pieza contador", "de=<lista> minimo=<n>", "no",
     "is_lit de su lista", "todos, no_todos, cambio", "todos, no_todos", "-", "-", "-", "-", "todas", "hay", "Rótulo «ENCENDIDAS n/m». Solo avisa."],
    ["vigia", "Vigía de sala", "logica", "VigiaPuzle", "escenas/puzle.gd", "; pieza vigia", "de=<lista> flag puesto", "no",
     "enemigo (muertes)", "todos_derrotados", "todos, quedan", "-", "-", "-", "flag=", "todas", "hay", "Con la flag puesta al montar sus enemigos no aparecen."],
    # --- contenedores / botín ---
    ["cofre", "Cofre (normal, épico, legendario)", "contenedor", "CofrePuzle · Cofre3D", "escenas/puzle.gd · presentacion/cofre_3d.gd", "; pieza cofre",
     "aparece_si abre_si abierto=<flag> modelo=legendario|epico glifo da gasta", "si", "E (≤ 2,7 u), regla", "aparecido, abierto", "oculto, cerrado, abierto", "abrir, aparecer", "-",
     "da=<objeto>:n+… | da=tabla:<id> | glifo=<id>", "abierto=<flag>", "todas", "hay",
     "abre_si=tener.llave + gasta=si gasta la llave. Legendario: secuencia del glifo (SecuenciaCofreLegendario3D)."],
    ["jarron", "Jarrón", "rompible", "Rompible3D", "objetos/rompible_3d.gd", "; pieza jarron", "botin=oro|pocion|nada|zona|<objeto> cantidad alto celdas modelo=caja", "mientras_entero",
     "cualquier_hechizo, empujon, explosion, golpe", "roto", "roto, entero", "romper", "-", "tabla:jarron_<zona>", "<nivel>.rompible.<id>", "todas", "hay", "No reaparece."],
    ["caja", "Caja", "rompible", "Rompible3D", "objetos/rompible_3d.gd", "; pieza caja", "botin cantidad pequena celdas", "mientras_entero",
     "cualquier_hechizo, empujon, explosion, golpe", "roto", "roto, entero", "romper", "-", "tabla:jarron_<zona>", "<nivel>.rompible.<id>", "todas", "hay", "Como el jarrón."],
    ["botin_objeto", "Objeto suelto en el suelo", "contenedor", "BotinObjeto3D", "objetos/botin_objeto_3d.gd", "código (Botin.soltar)", "-", "no",
     "presencia (imán)", "-", "-", "-", "-", "objeto:n", "-", "todas", "hay", "Salta, flota y se imanta a la bolsa. Bolsa llena: se queda y avisa."],
    # --- recolectables ---
    ["seta", "Seta", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "; pieza seta", "variante=roja|azul|marron rebrota=<s> madura", "no",
     "E, fuego, agua, hielo, rayo, viento, pulso (madura)", "recogida", "recogida, en_suelo", "recoger", "-", "seta y sus variantes (fuentes.tsv)", "-", "todas", "hay",
     "El elemento lanzado antes de cogerla la transforma; ya no vuelve a cambiar."],
    ["flor", "Flor", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "pieza del mapa", "rebrota", "no",
     "E, fuego, agua, rayo, hielo, viento", "recogida", "-", "-", "-", "flor_luna y variantes", "-", "bosque", "hay", "Objetos.PLANTAS."],
    ["raiz", "Raíz", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "pieza del mapa", "rebrota", "no",
     "E, fuego, agua, rayo, tierra", "recogida", "-", "-", "-", "raiz y variantes; tierra -> cristal_tierra", "-", "bosque", "hay", ""],
    ["alga", "Alga", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "; pieza alga", "coge_si=casilla(x,y).helada rebrota", "no",
     "E (condición), fuego, rayo", "recogida", "recogida, en_suelo", "recoger", "-", "alga_cueva; fuego -> alga_seca; rayo -> alga_cargada (charca electrificada)", "-", "cueva", "hay",
     "Solo se ve y se coge mientras se cumple coge_si."],
    ["basalto", "Basalto / obsidiana", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "; pieza basalto", "coge_si=casilla(x,y).roca rebrota", "no",
     "E (condición)", "recogida", "recogida, en_suelo", "recoger", "-", "basalto (lava + agua) · obsidiana (lava + hielo)", "-", "cueva", "hay", "10 s antes de que vuelva la lava."],
    ["musgo", "Musgo de cueva", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "; pieza musgo", "coge_si rebrota", "no", "E", "recogida", "recogida, en_suelo", "recoger", "-", "musgo_cueva", "-", "cueva", "hay", "Modelo musgo_colgante."],
    ["helecho_cueva", "Helecho de cueva", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "; pieza helecho_cueva", "coge_si rebrota", "no", "E", "recogida", "recogida, en_suelo", "recoger", "-", "helecho_cueva", "-", "cueva", "hay", ""],
    ["seta_palida", "Seta pálida", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "; pieza seta_palida", "coge_si rebrota", "no", "E, fuego", "recogida", "recogida, en_suelo", "recoger", "-", "seta_palida; fuego -> esporas", "-", "cueva", "hay", "Solo en zonas con estado oscuridad."],
    ["lavanda", "Lavanda", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "pieza del mapa", "-", "no", "E", "recogida", "-", "-", "-", "lavanda", "-", "bosque", "hay", ""],
    ["bayas", "Bayas", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "pieza del mapa", "-", "no", "E", "recogida", "-", "-", "-", "baya", "-", "bosque", "hay", ""],
    ["helecho", "Helecho", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "pieza del mapa", "-", "no", "E", "recogida", "-", "-", "-", "helecho", "-", "bosque", "hay", ""],
    ["flor_silvestre", "Flor silvestre", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "pieza del mapa", "-", "no", "E", "recogida", "-", "-", "-", "flor_silvestre", "-", "bosque", "hay", ""],
    ["rocas_pequenas", "Rocas pequeñas", "recolectable", "Recolectable3D", "objetos/recolectable_3d.gd", "pieza del mapa", "-", "no", "E", "recogida", "-", "-", "-", "piedra", "-", "todas", "hay", ""],
    ["hierba", "Hierba", "ambiente", "Hierba3D (maqueta)", "presentacion/prueba_test2.gd", "casillas de hierba", "-", "no",
     "fuego, rayo, agua, hielo, viento, golpe", "casilla_cambio (segada, quemada)", "casilla(x,y).segada|quemada|mojada", "-", "-", "tabla:hierba_segada (baya 10 %, flor 5 %)", "-", "bosque", "cambio",
     "Fina -> crecida (agua) -> prendiendo (1 s) -> ardiendo (5 s) -> cenizas. El rayo se salta el prender. Segar con viento o golpe: tirar la tabla es lo que falta."],
    # --- fauna ---
    ["colmena", "Colmena", "fauna", "Colmena3D", "objetos/colmena_3d.gd", "; pieza colmena", "-", "mientras_colgado (no)", "viento, fuego", "panal_cae, arde", "colgada, vacia", "-", "-",
     "panal:1-2 (viento, una vez)", "<nivel>.colmena.<id>", "bosque", "hay", "Fuego: nube de veneno 3 s y nada de panal. Primitivas hasta que haya pieza."],
    ["nido", "Nido", "fauna", "Nido3D", "objetos/nido_3d.gd", "; pieza nido", "-", "no", "viento", "suelta", "-", "-", "-", "pluma:1 (cada 45 s)", "-", "bosque", "hay", "Primitivas hasta que haya pieza."],
    ["nube_veneno", "Nube de veneno", "ambiente", "NubeVeneno3D", "mundo/nube_veneno_3d.gd", "; pieza nube_veneno · colmena quemada · chamán", "vida=<s> radio=<casillas>", "no",
     "viento (dispersa 8 s), fuego (consume 4 s), presencia (envenena)", "disipada", "-", "-", "-", "-", "-", "todas", "hay", "2 de vida/s dentro y 3 s después. Antídoto y capucha de musgo protegen."],
    # --- pulso ---
    ["cristal", "Cristal resonante (emisor)", "pulso", "CristalPulso3D · MineralPulso", "objetos/cristal_pulso_3d.gd", "; pieza cristal", "cada=<s> alcance=<casillas>", "si",
     "tiempo (cada), cualquier_hechizo, golpe ×2, rayo", "late", "-", "latir", "-", "esquirla_cristal:1 (2 golpes) · cristal_cargado (rayo, nuevo)", "-", "cueva", "hay",
     "Suelta un Pulso3D con el elemento del hechizo. Enfría entre golpes."],
    ["veta", "Veta mineral (conductor)", "pulso", "VetaPulso3D", "objetos/veta_pulso_3d.gd", "; pieza veta", "celdas enlaces aturde=<s> mineral", "no",
     "pulso (conduce), tierra (mineral=si), bloque (enlaces)", "-", "-", "-", "conduce", "mineral_veta:1 (tierra, una vez)", "<nivel>.mineral.<id>", "cueva", "hay",
     "Los huecos (enlaces) solo conducen con un bloque de tierra o de piedra encima."],
    ["receptor", "Receptor rúnico", "pulso", "ReceptorPulso3D", "objetos/receptor_pulso_3d.gd", "; pieza receptor", "elemento flag rearme=<s>", "si",
     "pulso (de su elemento si lo pide)", "activado, apagado", "activo, libre", "activar, apagar", "-", "-", "flag=", "cueva", "hay", "Se queda activo; rearme lo apaga solo."],
    ["prisma", "Prisma orientable", "pulso", "PrismaPulso3D", "objetos/prisma_pulso_3d.gd", "; pieza prisma", "dir=n|e|s|o", "si",
     "pulso (reemite), cualquier_hechizo (gira), E (gira)", "gira, emite", "-", "girar", "-", "-", "-", "cueva", "hay", "Gira 90° horario. No vuelve a pasar dos veces por el mismo prisma."],
    ["geoda", "Geoda explosiva", "pulso", "GeodaPulso3D", "objetos/geoda_pulso_3d.gd", "; pieza geoda", "flag escala cerca", "no",
     "pulso", "explota", "explotada, intacta", "-", "-", "ceniza_geoda:1-2 (cambio: dejar el polvo en el suelo)", "flag=", "cueva", "hay",
     "Carga 0,9 s y explota una vez: avisa a explosionable a 2,8 u; 30 de daño y 2 s de aturdir a Combate3D."],
    ["estalagmita", "Estalagmita resonante", "pulso", "EstalagmitaPulso3D", "objetos/estalagmita_pulso_3d.gd", "; pieza estalagmita", "cae=n|e|s|o flag", "no",
     "pulso ×2", "cae", "caida, en_pie", "-", "-", "-", "flag=", "cueva", "hay", "1.º vibra, 2.º cae: 25 de daño y 3 s de aturdir en la casilla donde cae. Queda estalagmita_rota (no bloquea)."],
    ["estatuas", "Estatuas (secuencia)", "pulso", "EstatuasPulso3D", "objetos/estatuas_pulso_3d.gd", "; pieza estatuas", "celdas secuencia=<e1,e2,…> flag", "si",
     "pulso_jugador de cada elemento, en orden", "acierta, falla, completa", "completa, pendiente", "-", "-", "-", "cueva.c1.estatuas", "cueva", "hay", "Un fallo apaga todas. Abre el cofre épico."],
    ["guardian", "Guardián de la barrera", "pulso", "GuardianBarrera3D", "objetos/guardian_barrera_3d.gd", "; pieza guardian", "en=<lista> cada elemento cerca roto", "si (salvo roto)",
     "tiempo (cada), cualquier_hechizo (dormido)", "levanta", "-", "levantar", "-", "-", "-", "gruta", "hay", "Levanta la barrera (elemento + ᛜ) en sus marcas."],
    # --- nivel ---
    ["salida", "Salida a otro nivel", "nivel", "SalidaNivel3D", "objetos/salida_nivel_3d.gd", "; pieza salida", "a=<Nivel>:<entrada> celdas modo=pisar|usar marca modelo", "no",
     "pisar, E (modo=usar), regla", "usada", "-", "usar", "-", "-", "-", "todas", "hay", "Nace desarmada; se arma al salir de sus casillas."],
    ["entrada", "Entrada de nivel", "nivel", "EntradaNivel3D", "objetos/salida_nivel_3d.gd", "; pieza entrada", "mira=n|e|s|o", "no", "-", "-", "-", "-", "-", "-", "-", "todas", "hay", "Punto de llegada y de reaparición."],
    ["decorado", "Decorado sin mecánica", "decorado", "(Puzle3D)", "escenas/puzle.gd", "; pieza decorado", "modelo=<pieza> giro escala", "no", "-", "-", "-", "-", "-", "-", "-", "todas", "hay", "Kit de la Cueva de adorno."],
    # --- enemigos ---
    ["goblin", "Goblin guerrero", "enemigo", "Combate3D", "enemigos/combate_3d.gd", "letra del mapa / marcador", "oro=<n>", "no",
     "fuego, agua, rayo, hielo, viento, tierra, golpe, empujon", "enemigo_muerto", "(vigia) todos, quedan", "-", "-", "tabla:goblin (oro 10, colmillo 60 %)", "-", "todas", "hay",
     "Vida 100, débil al agua (×2), resiste fuego. Cae al agua honda: muere sin botín. Arde y prende lo que toca."],
    ["goblin_arquero", "Goblin arquero", "enemigo", "Combate3D", "enemigos/combate_3d.gd", "id goblin_archer*", "-", "no", "como el guerrero", "enemigo_muerto", "-", "-", "-", "tabla:goblin", "-", "todas", "hay",
     "Se coloca a 6,5 u, retrocede a < 2,4 y dispara a donde estás ahora. La flecha sale ardiendo si cruza una llama."],
    ["goblin_asesino", "Goblin asesino", "enemigo", "Combate3D + AtaqueDoble", "enemigos/combate_3d.gd", "id goblin_asesino*", "-", "no", "como el guerrero", "enemigo_muerto", "-", "-", "-", "tabla:goblin", "-", "todas", "hay", "Dos cortes. Hoy solo con Alt+F11."],
    ["goblin_escudo", "Goblin con escudo", "enemigo", "Combate3D + Escudo3D", "enemigos/escudo_3d.gd", "laboratorios", "-", "no", "fuego (quema el escudo 3 s)", "escudo_quemado", "-", "-", "inflamable, bloquea_proyectiles", "tabla:goblin_escudo (jirón si ardió)", "-", "todas", "hay",
     "Bloquea de frente en un cono de 120°, 60 de vida propia."],
    ["loberno", "Loberno", "enemigo", "Combate3D", "enemigos/combate_3d.gd", "marcador loberno", "-", "no", "como el guerrero", "enemigo_muerto", "-", "-", "-", "tabla:goblin (hereda)", "-", "bosque", "hay", "Sin rama propia: hereda los valores del guerrero."],
    ["limo", "Limo elemental", "enemigo", "Limo3D", "enemigos/limo_3d.gd", "; pieza limo", "elemento grande", "no",
     "fuego, agua, hielo, rayo, tierra, viento, casilla con estado", "enemigo_muerto", "(vigia)", "-", "-", "tabla:limo (oro 5, baba 70 %)", "-", "todas", "hay",
     "Se tiñe del primer elemento; con el suyo crece; grande, su elemento lo cura. No se envenena."],
    ["golem", "Gólem de piedra", "enemigo", "Golem3D", "enemigos/golem_3d.gd", "; pieza golem", "quieto", "no",
     "golpe (de rodillas: núcleo ×1,5), viento sobre hielo (resbala), agua honda / lava (muere)", "enemigo_muerto", "(vigia)", "-", "-", "tabla:golem (oro 40, polvo 1-2)", "-", "cueva", "hay",
     "De pie nada le hace daño."],
    ["chaman", "Chamán goblin", "enemigo", "Chaman3D", "enemigos/chaman_3d.gd", "; pieza chaman", "quieto", "no",
     "golpe mientras traza (rompe la runa), fuego (quema el escudo de naturaleza)", "enemigo_muerto", "(vigia)", "-", "-", "tabla:chaman (oro 15, pluma 50 %)", "-", "todas", "hay",
     "Escuda a los goblins y tira bolas de veneno (nube)."],
    ["elemental", "Elemental del bosque (jefe)", "enemigo", "Combate3D (rama elemental)", "enemigos/combate_3d.gd", "id elemental_bosque", "-", "no",
     "fuego (débil), agua (lo cura y agranda una vez)", "enemigo_muerto", "-", "-", "-", "tabla:elemental (oro 150, savia 100 %)", "-", "bosque", "hay", "Vida 1000; puñetazos de área y enredaderas."],
    ["gatopedro", "Gatopedro (lince)", "enemigo", "Gatopedro3D", "enemigos/gatopedro_3d.gd", "Terra Fina", "-", "no", "cualquier_hechizo (huye)", "-", "-", "-", "-", "-", "-", "bosque", "hay", "No ataca, huye: práctica de páginas."],
    # --- NPC ---
    ["guardabosques", "Guardabosques", "npc", "Pj3D + Bosque3D/Bosque02", "escenas/bosque_3d.gd · escenas/bosque_02_3d.gd", "; marcador npc guardabosques", "-", "si",
     "E (hablar, comprar)", "-", "-", "-", "-", "barrera (tienda, 20 de oro) · capucha (misión)", "bosque2.guarda.saludo", "bosque", "hay", "El único NPC con tienda. Da misiones."],
    ["librera", "Librera", "npc", "Pj3D + Bosque3D/Bosque02", "escenas/bosque_3d.gd · escenas/bosque_02_3d.gd", "; marcador npc librera", "-", "si", "E (hablar)", "-", "-", "-", "-", "huecos de glifo (idea: comprar)", "-", "bosque", "hay", "Pistas sobre fuego, telaraña y rayo."],
    ["alquimista", "Alquimista", "npc", "Pj3D + Bosque01v01", "escenas/bosque_01_v01_3d.gd", "; marcador npc alquimista", "-", "si", "E (hablar, síntesis, comprar poción, mejoras)", "-", "-", "-", "-", "recetas donde=alquimista · mejoras.tsv", "-", "bosque", "cambio", "Síntesis y mejoras (PLAN_BASE_DATOS F2/F3)."],
    ["goblin_lenador", "Goblin leñador (NPC con rutina)", "npc", "Pj3D + Bosque01v01", "escenas/bosque_01_v01_3d.gd", "; marcador npc", "-", "si", "presencia (te mira)", "-", "-", "-", "-", "-", "-", "bosque", "hay", "Tala y, cuando cae el campamento, cava."],
    ["hoguera", "Hoguera (punto de guardado)", "npc", "Reactivo3D (fogata/brasero encendidos)", "objetos/objetos_3d.gd", "fogata o brasero", "-", "si", "E (encendida, ≤ 2,7 u)", "hoguera_abierta", "-", "-", "-", "recetas donde=hoguera", "-", "todas", "hay", "Abre la síntesis de campo y guarda la partida."],
    # --- ambiente ---
    ["casilla_suelo", "Casilla de suelo (estado)", "ambiente", "EstadosSuelo3D", "mundo/estados_suelo_3d.gd", "todas las casillas", "-", "-",
     "agua, hielo, fuego, rayo (descarga)", "cambio, casilla_cambio", "casilla(x,y).mojada|helada|quemada|electrificada|segada", "-", "-", "-", "-", "todas", "hay",
     "seca -> mojada (agua) / helada (frío); mojada -> helada (agua ×2 o frío) / seca + vapor (calor); helada -> mojada (calor). Escarcha a mojada a los 20 s."],
    ["zona", "Estado de zona (calor, frío, veneno…)", "ambiente", "EstadoZona3D", "mundo/estado_zona_3d.gd · nucleo/datos/estados_mundo.tsv", "zona del mapa · hace=zona.poner(estado,s)", "-", "-",
     "regla (zona.poner / quitar), tiempo", "-", "-", "poner(estado,s), quitar(estado)", "-", "-", "-", "todas", "cambio", "Ver la hoja estados_mundo."],
]

# ---------------------------------------------------------------------------------------------------------------------
# INTERACCIONES (pieza · llega · condición · hace · resultado · botín · flag · cada_s · estado · fuente · nota)
# Parte de nucleo/datos/reactivos_mapa.tsv (las filas con varias piezas, separadas) más lo que el código ya hace y la tabla no lista.
# ---------------------------------------------------------------------------------------------------------------------
CAB_ACC = ["pieza", "llega", "condicion", "hace", "resultado", "botin", "flag", "cada_s", "estado", "fuente", "nota"]

INTERACCIONES = [
    # hierba
    ["hierba", "viento", "-", "segar: la hierba se corta y rebrota", "segada", "tabla:hierba_segada", "-", 60, "nuevo", "reactivos_mapa.tsv", "Hierba3D ya tiene «segada»; falta tirar la tabla"],
    ["hierba", "golpe", "-", "segar", "segada", "tabla:hierba_segada", "-", 60, "nuevo", "reactivos_mapa.tsv", ""],
    ["hierba", "agua", "fina", "crece", "crecida", "-", "-", 0, "hay", "ARQUITECTURA.md (Hierba e incendio)", ""],
    ["hierba", "fuego", "-", "prende (1 s) y arde 5 s; contagia a 4 vecinas a 0,5 casillas/s", "cenizas (quemada)", "-", "-", 0, "hay", "ARQUITECTURA.md", "Tope 60 casillas ardiendo"],
    ["hierba", "rayo", "-", "arde sin fase de prender", "cenizas", "-", "-", 0, "hay", "ARQUITECTURA.md", ""],
    ["hierba", "agua", "ardiendo o prendiendo", "apaga 5×5 y la deja mojada 8 s", "fina (mojada)", "-", "-", 0, "hay", "ARQUITECTURA.md", ""],
    ["hierba", "hielo", "ardiendo", "apaga 5×5; escarcha 20 s", "fina (escarcha)", "-", "-", 0, "hay", "ARQUITECTURA.md", ""],
    ["hierba", "viento", "ardiendo", "lleva la llama en un cono de 3,6 casillas", "ardiendo (vecinas)", "-", "-", 0, "hay", "ARQUITECTURA.md", ""],
    # árbol
    ["arbol", "golpe", "-", "se sacude: caen hojas", "-", "tabla:tronco_golpe", "-", 30, "hay", "reactivos_mapa.tsv · objetos_3d.gd (sacudible)", ""],
    ["arbol", "fuego", "-", "arde 6 s y queda chamuscado (no desaparece)", "chamuscado", "tabla:seto_quemado", "-", 0, "nuevo", "reactivos_mapa.tsv", ""],
    # colmena, nido, telaraña
    ["colmena", "viento", "colgada", "se descuelga: cae el panal", "vacia", "panal:1-2", "<nivel>.colmena.<id>", 0, "hay", "colmena_3d.gd", "Una vez"],
    ["colmena", "fuego", "colgada", "arde: nube de veneno 3 s, nada de panal", "vacia", "-", "<nivel>.colmena.<id>", 0, "hay", "colmena_3d.gd", "Premia hacerlo con viento"],
    ["nido", "viento", "-", "se sacude y suelta una pluma", "-", "pluma:1", "-", 45, "hay", "nido_3d.gd", ""],
    ["telarana", "hielo", "sana", "se hiela: ya no engancha ni arde", "helada", "-", "-", 0, "hay", "objetos_3d.gd (helable)", ""],
    ["telarana", "E", "helada", "se recoge", "cogida", "seda:1", "-", 0, "hay", "objetos_3d.gd", ""],
    ["telarana", "fuego", "sana", "arde 1,6 s y se consume", "consumida", "-", "-", 0, "hay", "objetos_3d.gd", "Sin botín (la seda es la helada)"],
    # combustibles
    ["seto", "fuego", "sano, no mojado", "arde 3,5 s y se consume", "consumido", "tabla:seto_quemado", "-", 0, "cambio", "reactivos_mapa.tsv · objetos_3d.gd", "Tirar la tabla al consumirse"],
    ["seto", "rayo", "sano", "prende", "ardiendo", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["seto", "agua", "ardiendo", "se apaga", "sano", "-", "-", 0, "hay", "objetos_3d.gd (apaga)", ""],
    ["seto", "hielo", "ardiendo", "se apaga", "sano", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["seto", "agua", "sano y mojable=si", "se moja: no prende 12 s", "mojado", "-", "-", 0, "hay", "objetos_3d.gd (mojable)", "El cortafuegos"],
    ["seto", "viento", "ardiendo", "lleva la llama a lo inflamable de ≤ 3,6 casillas en su cono", "-", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["seto", "fuego", "vecino ardiendo (≤ 1,7 casillas)", "se contagia cada 0,8 s", "ardiendo", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["tronco", "fuego", "sano", "arde 4 s y se consume", "consumido", "tabla:seto_quemado", "-", 0, "cambio", "reactivos_mapa.tsv", ""],
    ["puerta_goblin", "fuego", "sana", "arde 5 s y se consume: paso libre", "consumida", "tabla:seto_quemado", "-", 0, "cambio", "reactivos_mapa.tsv", ""],
    ["torre_goblin", "fuego", "sana", "arde 7 s y se consume", "consumida", "tabla:seto_quemado", "-", 0, "cambio", "reactivos_mapa.tsv", ""],
    ["cuerda", "fuego", "entera", "arde 1 s y se rompe: lo que sostiene cae", "rota", "-", "-", 0, "hay", "cuerda_3d.gd", "compuerta -> cerrar · puente -> tender"],
    ["cuerda", "rayo", "entera", "arde", "ardiendo", "-", "-", 0, "hay", "cuerda_3d.gd", ""],
    ["cuerda", "agua", "ardiendo", "se apaga", "entera", "-", "-", 0, "hay", "cuerda_3d.gd", "No arregla una rota"],
    ["enredadera", "fuego", "viva", "arde por focos y se deshace", "quemada", "-", "-", 0, "hay", "enredadera_3d.gd", ""],
    ["barril", "fuego", "entero", "enciende la mecha (1,2 s) y explota en 2,6 u", "explotado", "-", "-", 0, "hay", "barril_3d.gd", "Daña 25 en 1,5 casillas; rompe lo rompible"],
    ["barril", "rayo", "entero", "enciende la mecha (chispa)", "encendido", "-", "-", 0, "hay", "barril_3d.gd", ""],
    ["barril", "agua", "encendido", "apaga la mecha", "entero", "-", "-", 0, "hay", "barril_3d.gd", ""],
    ["barril", "explosion", "entero", "reacción en cadena", "explotado", "-", "-", 0, "hay", "barril_3d.gd", ""],
    # fuego de mapa
    ["brasero", "fuego", "apagado", "se enciende", "encendido", "-", "-", 0, "hay", "objetos_3d.gd", "También un pulso de fuego"],
    ["brasero", "agua", "encendido", "se apaga", "apagado", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["brasero", "hielo", "encendido", "se apaga", "apagado", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["brasero", "viento", "encendido", "se lleva la llama (prende lo inflamable en su cono)", "-", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["brasero", "E", "encendido, ≤ 2,7 u", "HOGUERA: síntesis de campo (donde=hoguera) y guardar la partida", "-", "-", "-", 0, "hay", "objetos_3d.gd (hoguera_abierta)", ""],
    ["brasero", "tiempo", "rele=<id>", "a los 1,5 s enciende al siguiente; a los 6 s se apaga", "apagado", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["fogata", "fuego", "apagada", "se enciende", "encendida", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["fogata", "agua", "encendida", "se apaga", "apagada", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["fogata", "E", "encendida", "HOGUERA (síntesis + guardar)", "-", "-", "-", 0, "hay", "objetos_3d.gd", "La fogata del Bosque es el punto de guardado"],
    ["lava", "agua", "lava", "se enfría 10 s: roca (la casilla y 4 vecinas)", "roca", "basalto (Recolectable3D)", "-", 0, "hay", "lava_3d.gd", ""],
    ["lava", "hielo", "lava", "se enfría: roca del frío", "roca", "obsidiana:1", "-", 0, "hay", "lava_3d.gd (via_de_roca)", ""],
    ["lava", "tiempo", "roca y vuelve>0", "la roca vuelve a ser lava", "lava", "-", "-", 0, "hay", "lava_3d.gd", ""],
    ["lava", "tiempo", "lava", "prende lo inflamable de al lado y enciende barriles", "-", "-", "-", 0, "hay", "lava_3d.gd", "Cada CADA_FUEGO s"],
    # agua y electricidad
    ["charca", "hielo", "-", "se hiela 20 s: se pisa, atrapa flotadores y goblins; el alga se ve", "helada", "alga_cueva (con E)", "-", 0, "hay", "agua_sim_3d.gd", ""],
    ["charca", "fuego", "helada", "funde el hielo", "agua", "-", "-", 0, "hay", "agua_sim_3d.gd", "Sin hielo, evapora (vapor)"],
    ["charca", "rayo", "-", "la descarga recorre el agua conectada", "electrificada", "-", "-", 0, "hay", "lanzador_3d.gd", "alga_cargada (nuevo)"],
    ["charca", "tierra", "-", "aparta el agua (presa)", "solida", "-", "-", 0, "hay", "agua_sim_3d.gd", ""],
    ["surtidor", "agua", "-", "echa un chorro, llena su pila y el cauce", "lleno", "-", "-", 0, "hay", "surtidor_3d.gd", "activado(surtidor, agua)"],
    ["tinaja", "agua", "vacia", "se llena, se inclina y vierte hacia el canal", "vertiendo", "-", "-", 0, "hay", "objetos_3d.gd", "agua_llega al llegar al canal"],
    ["compuerta", "regla", "-", "abrir / cerrar / alternar", "abierta|cerrada", "-", "-", 0, "hay", "compuerta_3d.gd", "Por pulsador o puzle"],
    ["compuerta", "fuego", "abre_con=fuego (de hielo)", "se derrite y abre", "abierta", "-", "-", 0, "hay", "compuerta_3d.gd", ""],
    ["compuerta", "hielo", "cierra_con=hielo", "el hielo la tapona", "cerrada", "-", "-", 0, "hay", "compuerta_3d.gd", ""],
    ["compuerta", "explosion", "abre_con=explosion (roca)", "se abre", "abierta", "-", "-", 0, "hay", "compuerta_3d.gd", ""],
    ["molino", "corriente", "> umbral u/s", "gira", "girando", "-", "-", 0, "hay", "molino_3d.gd", ""],
    ["molino", "agua", "-", "gira 6 s", "girando", "-", "-", 0, "hay", "molino_3d.gd", ""],
    ["nexo", "agua", "seco", "se moja: conduce 30 s", "conduce", "-", "-", 0, "hay", "nexo_rayo_3d.gd", ""],
    ["nexo", "fuego", "mojado", "se seca al momento", "corta", "-", "-", 0, "hay", "nexo_rayo_3d.gd", ""],
    ["emisor", "tiempo", "-", "descarga 1,6 s por el agua conectada: hiere 8 cada 0,4 s y activa tótems de rayo", "-", "-", "-", 4, "hay", "emisor_rayo_3d.gd", "El hielo corta"],
    ["totem", "fuego", "totem de fuego", "se activa y se queda", "activo", "-", "-", 0, "hay", "objetos_3d.gd (activable)", ""],
    ["totem", "agua", "totem de agua", "se activa", "activo", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["totem", "rayo", "totem de rayo (descarga del emisor)", "se activa; tiende el puente", "activo", "-", "-", 0, "hay", "objetos_3d.gd", ""],
    ["tronco_estanque", "agua", "profundidad ≥ 0,45 u", "sube y se vuelve puente", "puente", "-", "-", 0, "hay", "tronco_estanque_3d.gd", ""],
    ["tronco_puente", "fuego", "en pie", "cae cruzando el río: puente", "caido", "-", "-", 0, "hay", "tronco_puente_3d.gd", ""],
    ["puente", "regla", "plegado", "tender: las losas emergen", "tendido", "-", "-", 0, "hay", "puente_reactivo_3d.gd", "También la cuerda al romperse"],
    ["flotador", "corriente", "-", "deriva", "-", "-", "-", 0, "hay", "flotador_3d.gd", ""],
    ["flotador", "hielo", "-", "queda atrapado", "atrapado", "-", "-", 0, "hay", "agua_sim_3d.gd", ""],
    # pasos y lógica
    ["muro", "tierra", "entero", "se agrieta; al golpes-ésimo cae", "roto", "-", "<nivel>.<sala>.muro", 0, "hay", "muro_agrietado_3d.gd", "2 golpes de serie"],
    ["muro", "explosion", "entero", "cae de una vez", "roto", "-", "-", 0, "hay", "muro_agrietado_3d.gd", ""],
    ["columna", "pulso", "en pie", "se agrieta; al golpes-ésimo cae hacia cae", "caida", "-", "flag=", 0, "hay", "muro_agrietado_3d.gd", ""],
    ["columna", "explosion", "en pie", "cae", "caida", "-", "flag=", 0, "hay", "muro_agrietado_3d.gd", "La geoda"],
    ["bloque", "empujon", "quieto", "piedra: avanza una casilla (0,45 s) · hielo: resbala hasta chocar", "movido", "-", "-", 0, "hay", "bloque_empujable_3d.gd", "0,35 s apretando"],
    ["bloque", "viento", "quieto", "se mueve en la dirección dominante", "movido", "-", "-", 0, "hay", "bloque_empujable_3d.gd", ""],
    ["bloque", "tiempo", "atascado sin servir", "se deshace a los 3 s y reaparece en su casilla", "reaparece", "-", "-", 0, "hay", "bloque_empujable_3d.gd", ""],
    ["pulsador", "cualquier_hechizo", "modo=magia", "pulsado", "activo", "-", "-", 0, "hay", "pulsador_3d.gd", "rearme s lo rearma"],
    ["pulsador", "agua", "modo=agua", "pulsado", "activo", "-", "-", 0, "hay", "pulsador_3d.gd", ""],
    ["pulsador", "presencia", "modo=presencia", "pulsado; soltado al irse", "activo", "-", "-", 0, "hay", "pulsador_3d.gd", "Jugadora o cuerpo con peso"],
    ["placa", "presencia", "grupo peso", "se hunde y se queda", "usada", "-", "-", 0, "hay", "objetos_3d.gd", "La jugadora no pesa"],
    ["puerta", "regla", "-", "abrir / cerrar / alternar", "abierta|cerrada", "-", "abierto=<flag>", 0, "hay", "puzle.gd", ""],
    ["puerta", "E", "llave=<flag> puesta", "se abre y se queda; gasta=si quita la flag", "abierta", "-", "<nivel>.<sala>.puerta", 0, "cambio", "reactivos_mapa.tsv · puzle.gd", "Pasar a tener.llave y quitar la llave de la bolsa"],
    ["puerta", "E", "sin llave", "avisa «Hace falta una llave»", "cerrada", "-", "-", 0, "hay", "puzle.gd", ""],
    ["cerrojo", "pisar", "sala", "se cierra", "cerrado", "-", "-", 0, "hay", "puzle.gd", ""],
    ["cerrojo", "regla", "-", "abrir (definitivo)", "abierto", "-", "hasta=<flag>", 0, "hay", "puzle.gd", ""],
    ["vigia", "enemigo", "todos los de de= caídos", "todos_derrotados; pone flag", "completo", "-", "flag=", 0, "hay", "puzle.gd", ""],
    ["contador", "regla", "llega a minimo", "todos", "completo", "-", "-", 0, "hay", "contador_reactivos_3d.gd", "Lee is_lit cada fotograma"],
    # contenedores
    ["cofre", "E", "cerrado, ≤ 2,7 u", "se abre y da da=", "abierto", "da=objeto:n | tabla:<id>", "abierto=<flag>", 0, "hay", "puzle.gd (CofrePuzle)", ""],
    ["cofre", "E", "abre_si=tener.llave", "gasta la llave de la bolsa (gasta=si) y abre", "abierto", "da=", "abierto=<flag>", 0, "hay", "puzle.gd", "tener.<objeto> en las expresiones si="],
    ["cofre", "E", "abre_si no cumplida", "avisa: «El cofre está sellado»", "cerrado", "-", "-", 0, "hay", "puzle.gd", ""],
    ["cofre", "regla", "aparece_si cumplida", "aparece con efecto", "cerrado", "-", "-", 0, "hay", "cofre_3d.gd", ""],
    ["cofre", "E", "modelo=legendario glifo=<id>", "secuencia: el glifo se escribe en el libro y se desbloquea", "abierto", "glifo", "global.glifo.<id>", 0, "hay", "secuencia_cofre_legendario_3d.gd", ""],
    ["jarron", "cualquier_hechizo", "entero", "se rompe: restos y botín de la zona", "roto", "tabla:jarron_<zona>", "<nivel>.rompible.<id>", 0, "hay", "rompible_3d.gd", ""],
    ["jarron", "empujon", "entero", "se rompe", "roto", "tabla:jarron_<zona>", "<nivel>.rompible.<id>", 0, "hay", "rompible_3d.gd", "Viento y atracción"],
    ["jarron", "explosion", "entero", "se rompe", "roto", "tabla:jarron_<zona>", "<nivel>.rompible.<id>", 0, "hay", "rompible_3d.gd", ""],
    ["jarron", "golpe", "entero", "se rompe (golpear())", "roto", "tabla:jarron_<zona>", "<nivel>.rompible.<id>", 0, "hay", "rompible_3d.gd", ""],
    ["caja", "cualquier_hechizo", "entera", "se rompe", "rota", "tabla:jarron_<zona>", "<nivel>.rompible.<id>", 0, "hay", "rompible_3d.gd", "Como el jarrón (empujón, explosión, golpe)"],
    ["botin_objeto", "presencia", "cerca", "se imanta y entra en la bolsa", "cogido", "objeto:n", "-", 0, "hay", "botin_objeto_3d.gd", "Bolsa llena: se queda"],
    # recolectables
    ["seta", "E", "en suelo", "se coge", "recogida", "seta (o su variante)", "-", 0, "hay", "recolectable_3d.gd", "rebrota=s vuelve a salir"],
    ["seta", "fuego", "sin transformar", "se transforma", "seta_asada", "seta_asada", "-", 0, "hay", "fuentes.tsv (reaccion)", ""],
    ["seta", "agua", "sin transformar", "se transforma", "seta_humeda", "seta_humeda", "-", 0, "hay", "fuentes.tsv", ""],
    ["seta", "hielo", "sin transformar", "se transforma", "seta_helada", "seta_helada", "-", 0, "hay", "fuentes.tsv", ""],
    ["seta", "rayo", "sin transformar", "se transforma", "seta_electrificada", "seta_electrificada", "-", 0, "hay", "fuentes.tsv", ""],
    ["seta", "viento", "sin transformar", "se transforma", "esporas", "esporas", "-", 0, "hay", "fuentes.tsv", ""],
    ["seta", "pulso", "madura=si, sin transformar", "brilla y madura", "seta_resonante", "seta_resonante", "-", 0, "hay", "recolectable_3d.gd", ""],
    ["seta_resonante", "viento", "-", "se transforma", "esporas_luminosas", "esporas_luminosas", "-", 0, "nuevo", "fuentes.tsv", ""],
    ["seta_resonante", "hielo", "-", "se transforma", "seta_cristalizada", "seta_cristalizada", "-", 0, "nuevo", "fuentes.tsv", ""],
    ["seta_palida", "E", "zona oscuridad", "se coge", "recogida", "seta_palida", "-", 0, "nuevo", "fuentes.tsv", ""],
    ["seta_palida", "fuego", "-", "se transforma", "esporas", "esporas", "-", 0, "nuevo", "reactivos_mapa.tsv", ""],
    ["flor", "E", "-", "se coge", "recogida", "flor_luna", "-", 0, "hay", "fuentes.tsv", ""],
    ["flor", "fuego", "-", "se transforma", "flor_ardiente", "flor_ardiente", "-", 0, "hay", "fuentes.tsv", ""],
    ["flor", "agua", "-", "se transforma", "flor_rocio", "flor_rocio", "-", 0, "hay", "fuentes.tsv", ""],
    ["flor", "rayo", "-", "se transforma", "flor_chispa", "flor_chispa", "-", 0, "hay", "fuentes.tsv", ""],
    ["flor", "hielo", "-", "se transforma", "flor_escarcha", "flor_escarcha", "-", 0, "hay", "fuentes.tsv", ""],
    ["flor", "viento", "-", "se transforma", "petalos", "petalos", "-", 0, "hay", "fuentes.tsv", ""],
    ["raiz", "E", "-", "se coge", "recogida", "raiz", "-", 0, "hay", "fuentes.tsv", ""],
    ["raiz", "fuego", "-", "se transforma", "raiz_cenizas", "raiz_cenizas", "-", 0, "hay", "fuentes.tsv", ""],
    ["raiz", "agua", "-", "se transforma", "raiz_hinchada", "raiz_hinchada", "-", 0, "hay", "fuentes.tsv", ""],
    ["raiz", "rayo", "-", "se transforma", "raiz_magnetica", "raiz_magnetica", "-", 0, "hay", "fuentes.tsv", ""],
    ["raiz", "tierra", "-", "se transforma", "cristal_tierra", "cristal_tierra", "-", 0, "hay", "fuentes.tsv", ""],
    ["alga", "E", "casilla(x,y).helada", "se coge", "recogida", "alga_cueva", "-", 0, "hay", "fuentes.tsv", ""],
    ["alga", "fuego", "-", "se transforma", "alga_seca", "alga_seca", "-", 0, "hay", "fuentes.tsv", ""],
    ["alga", "rayo", "charca electrificada", "se transforma", "alga_cargada", "alga_cargada", "-", 0, "nuevo", "fuentes.tsv", ""],
    ["basalto", "E", "casilla(x,y).roca", "se coge", "recogida", "basalto | obsidiana", "-", 0, "hay", "fuentes.tsv", "10 s antes de que vuelva la lava"],
    ["musgo", "E", "-", "se coge", "recogida", "musgo_cueva", "-", 0, "nuevo", "fuentes.tsv", ""],
    ["helecho_cueva", "E", "-", "se coge", "recogida", "helecho_cueva", "-", 0, "nuevo", "fuentes.tsv", ""],
    ["lavanda", "E", "-", "se coge", "recogida", "lavanda", "-", 0, "hay", "fuentes.tsv", ""],
    ["bayas", "E", "-", "se coge", "recogida", "baya", "-", 0, "hay", "fuentes.tsv", ""],
    ["helecho", "E", "-", "se coge", "recogida", "helecho", "-", 0, "hay", "fuentes.tsv", ""],
    ["flor_silvestre", "E", "-", "se coge", "recogida", "flor_silvestre", "-", 0, "hay", "fuentes.tsv", ""],
    ["rocas_pequenas", "E", "-", "se coge", "recogida", "piedra", "-", 0, "hay", "fuentes.tsv", ""],
    ["esquirla_cristal", "tierra", "tirada en el suelo", "se muele", "polvo_cristal", "polvo_cristal", "-", 0, "nuevo", "fuentes.tsv", "Botín de objeto + tierra"],
    # pulso
    ["cristal", "tiempo", "cada>0", "late: suelta un pulso", "-", "-", "-", 0, "hay", "cristal_pulso_3d.gd", "cada s"],
    ["cristal", "cualquier_hechizo", "-", "late con el elemento del hechizo", "-", "-", "-", 0, "hay", "cristal_pulso_3d.gd", "Enfría entre golpes"],
    ["cristal", "golpe", "×2", "suelta una esquirla", "-", "esquirla_cristal:1", "-", 0, "hay", "mineral_pulso.gd", ""],
    ["cristal", "rayo", "-", "queda cargado 20 s: la próxima esquirla es cristal_cargado", "cargado", "cristal_cargado:1", "-", 0, "nuevo", "reactivos_mapa.tsv", ""],
    ["veta", "pulso", "-", "conduce y se ilumina casilla a casilla", "-", "-", "-", 0, "hay", "veta_pulso_3d.gd", ""],
    ["veta", "tierra", "mineral=si", "suelta mineral (una vez)", "-", "mineral_veta:1", "<nivel>.mineral.<id>", 0, "hay", "veta_pulso_3d.gd", ""],
    ["veta", "pulso", "aturde=<s>", "aturde a quien pisa la veta", "-", "-", "-", 0, "hay", "veta_pulso_3d.gd", ""],
    ["veta", "tierra", "hueco (enlaces)", "el bloque de tierra tiende el hueco: conduce", "tendido", "-", "-", 0, "hay", "veta_pulso_3d.gd", "También el bloque empujable de piedra"],
    ["receptor", "pulso", "de su elemento (si lo pide)", "se activa y se queda", "activo", "-", "flag=", 0, "hay", "receptor_pulso_3d.gd", "rearme lo apaga"],
    ["prisma", "pulso", "-", "lo reemite por donde mira", "-", "-", "-", 0, "hay", "prisma_pulso_3d.gd", ""],
    ["prisma", "cualquier_hechizo", "-", "gira 90°", "girado", "-", "-", 0, "hay", "prisma_pulso_3d.gd", ""],
    ["prisma", "E", "≤ ALCANCE_GIRO", "gira 90°", "girado", "-", "-", 0, "hay", "prisma_pulso_3d.gd", ""],
    ["pared_hueca", "pulso", "cerrada", "suena hueca (eco)", "cerrada", "-", "-", 0, "hay", "pared_hueca_pulso_3d.gd", "La pista"],
    ["pared_hueca", "pulso_jugador", "cerrada", "se abre: casilla libre", "abierta", "-", "flag=", 0, "hay", "pared_hueca_pulso_3d.gd", ""],
    ["geoda", "pulso", "intacta (y jugadora a ≤ cerca)", "carga 0,9 s y explota: avisa a explosionable a 2,8 u; 30 de daño + 2 s aturdir", "explotada", "ceniza_geoda:1-2", "flag=", 0, "cambio", "geoda_pulso_3d.gd · reactivos_mapa.tsv", "Dejar el polvo en el suelo"],
    ["estalagmita", "pulso", "1.º", "vibra", "en_pie", "-", "-", 0, "hay", "estalagmita_pulso_3d.gd", ""],
    ["estalagmita", "pulso", "2.º", "cae hacia cae: 25 de daño y 3 s aturdir en esa casilla", "caida", "-", "flag=", 0, "hay", "estalagmita_pulso_3d.gd", ""],
    ["estatuas", "pulso_jugador", "elemento de la secuencia, en orden", "se enciende; al acabar pone flag", "completa", "-", "cueva.c1.estatuas", 0, "hay", "estatuas_pulso_3d.gd", "Abre el cofre épico"],
    ["estatuas", "pulso_jugador", "elemento equivocado", "todas se apagan", "pendiente", "-", "-", 0, "hay", "estatuas_pulso_3d.gd", ""],
    ["guardian", "tiempo", "cada>0 (y jugadora a ≤ cerca)", "levanta la barrera en sus marcas", "-", "-", "-", 0, "hay", "guardian_barrera_3d.gd", ""],
    ["guardian", "cualquier_hechizo", "cada=0 (dormido)", "levanta la barrera con el elemento del hechizo", "-", "-", "-", 0, "hay", "guardian_barrera_3d.gd", ""],
    # nivel y NPC
    ["salida", "pisar", "armada", "carga el nivel de a= y deja a la jugadora en su entrada", "usada", "-", "-", 0, "hay", "salida_nivel_3d.gd", ""],
    ["salida", "E", "modo=usar", "carga el nivel", "usada", "-", "-", 0, "hay", "salida_nivel_3d.gd", ""],
    ["guardabosques", "E", "≤ 2,7 u", "habla (líneas en orden)", "-", "-", "-", 0, "hay", "bosque_3d.gd", ""],
    ["guardabosques", "E", "oferta en pie y oro ≥ 20", "vende la barrera", "-", "barrera", "-", 0, "hay", "bosque_3d.gd", ""],
    ["guardabosques", "presencia", "≤ RADIO_SALUDO, sin saludo", "saluda", "-", "-", "bosque2.guarda.saludo", 0, "hay", "bosque_02_3d.gd", ""],
    ["librera", "E", "≤ 2,7 u", "habla", "-", "-", "-", 0, "hay", "bosque_3d.gd", "Vender huecos de glifo: idea"],
    ["alquimista", "E", "-", "habla; síntesis (recetas donde=alquimista); mejoras", "-", "recetas.tsv · mejoras.tsv", "-", 0, "cambio", "bosque_01_v01_3d.gd · PLAN_BASE_DATOS", ""],
    # enemigos
    ["goblin", "fuego", "-", "daño + quemadura 3 s; mojado: vapor y no prende", "quemado", "-", "-", 0, "hay", "combate_3d.gd", "Resiste ×0,5"],
    ["goblin", "agua", "-", "daño ×2 + mojado 6 s (−25 % velocidad); apaga la quemadura", "mojado", "-", "-", 0, "hay", "combate_3d.gd", "Débil"],
    ["goblin", "rayo", "-", "daño + aturde 1,2 s; mojado ×1,5 y salta a otro a < 4,5 u", "aturdido", "-", "-", 0, "hay", "combate_3d.gd", ""],
    ["goblin", "hielo", "-", "congela 1,5 s (2,5 s y +15 si mojado)", "congelado", "-", "-", 0, "hay", "combate_3d.gd", ""],
    ["goblin", "viento", "-", "interrumpe 0,7 s + empujón", "-", "-", "-", 0, "hay", "combate_3d.gd", ""],
    ["goblin", "tierra", "-", "lentitud 3 s + empujón fuerte", "lento", "-", "-", 0, "hay", "combate_3d.gd", ""],
    ["goblin", "empujon", "hacia agua honda", "se hunde y muere sin botín", "muerto", "-", "-", 0, "hay", "combate_3d.gd", ""],
    ["goblin", "fuego", "toca algo ardiendo", "prende (y al revés: ardiendo prende lo que pisa)", "quemado", "-", "-", 0, "hay", "objetos_3d.gd (toca_punto)", ""],
    ["goblin", "enemigo", "muere", "suelta botín", "muerto", "tabla:goblin", "-", 0, "hay", "botin_tablas.tsv", ""],
    ["goblin_escudo", "fuego", "escudo entero", "el escudo arde 3 s; se le quema la mano y queda aturdido", "escudo quemado", "tabla:goblin_escudo", "-", 0, "hay", "escudo_3d.gd", ""],
    ["limo", "cualquier_hechizo", "sin teñir", "se tiñe del elemento", "teñido", "-", "-", 0, "hay", "limo_3d.gd", "También la casilla con estado"],
    ["limo", "cualquier_hechizo", "su elemento, pequeño", "crece", "grande", "-", "-", 0, "hay", "limo_3d.gd", ""],
    ["limo", "cualquier_hechizo", "su elemento, grande", "se cura", "-", "-", "-", 0, "hay", "limo_3d.gd", ""],
    ["limo", "enemigo", "muere", "suelta botín", "muerto", "tabla:limo", "-", 0, "hay", "botin_tablas.tsv", ""],
    ["golem", "golpe", "de rodillas (tras su golpe)", "núcleo a la vista: ×1,5 de daño", "-", "-", "-", 0, "hay", "golem_3d.gd", "De pie nada le hace daño"],
    ["golem", "viento", "sobre casilla helada", "resbala; tumbado = núcleo a la vista", "tumbado", "-", "-", 0, "hay", "golem_3d.gd", "Al agua honda o la lava, muere"],
    ["golem", "enemigo", "muere", "suelta botín", "muerto", "tabla:golem", "-", 0, "hay", "botin_tablas.tsv", ""],
    ["chaman", "golpe", "trazando la runa", "la runa se rompe", "-", "-", "-", 0, "hay", "chaman_3d.gd", ""],
    ["chaman", "fuego", "escudo de naturaleza en los goblins", "quema el escudo", "-", "-", "-", 0, "hay", "escudo_naturaleza_3d.gd", ""],
    ["chaman", "enemigo", "muere", "suelta botín", "muerto", "tabla:chaman", "-", 0, "hay", "botin_tablas.tsv", ""],
    ["elemental", "fuego", "-", "daño ×2", "-", "-", "-", 0, "hay", "combate_3d.gd", "Débil"],
    ["elemental", "agua", "una vez", "se cura y se agranda", "grande", "-", "-", 0, "hay", "combate_3d.gd", ""],
    ["elemental", "enemigo", "muere", "suelta botín", "muerto", "tabla:elemental", "-", 0, "hay", "botin_tablas.tsv", "Jefe"],
    # suelo / zona
    ["casilla_suelo", "agua", "seca", "mojada", "mojada", "-", "-", 0, "hay", "estados_suelo_3d.gd", ""],
    ["casilla_suelo", "agua", "mojada (2.º impacto)", "helada", "helada", "-", "-", 0, "hay", "estados_suelo_3d.gd", ""],
    ["casilla_suelo", "hielo", "seca o mojada", "helada (escarcha)", "helada", "-", "-", 0, "hay", "estados_suelo_3d.gd", "Escarcha -> mojada a los 20 s"],
    ["casilla_suelo", "fuego", "mojada", "seca + vapor", "seca", "-", "-", 0, "hay", "estados_suelo_3d.gd", ""],
    ["casilla_suelo", "fuego", "helada", "mojada", "mojada", "-", "-", 0, "hay", "estados_suelo_3d.gd", ""],
    ["casilla_suelo", "rayo", "mojada / agua", "electrificada (descarga)", "electrificada", "-", "-", 0, "hay", "lanzador_3d.gd", ""],
    ["zona", "regla", "zona.poner(tormenta,60)", "cada 6 s cae un rayo en una casilla mojada", "tormenta", "-", "-", 6, "nuevo", "estados_mundo.tsv", "Ver la hoja estados_mundo para calor, frio, veneno, humedad, oscuridad, vendaval, resonancia"],
]

# ---------------------------------------------------------------------------------------------------------------------
# Estilo
# ---------------------------------------------------------------------------------------------------------------------
F_NORMAL = Font(name=FUENTE, size=10)
F_CAB = Font(name=FUENTE, size=10, bold=True, color="FFFFFF")
F_TITULO = Font(name=FUENTE, size=14, bold=True)
F_NEGRITA = Font(name=FUENTE, size=10, bold=True)
RELLENO_CAB = PatternFill("solid", fgColor="2F4F6F")
RELLENO_EDITABLE = PatternFill("solid", fgColor="FFF8DC")
RELLENO_COPIA = PatternFill("solid", fgColor="4F6F4F")
BORDE = Border(bottom=Side(style="thin", color="D0D0D0"))
ALIN = Alignment(vertical="top", wrap_text=True)

ANCHOS = {"id": 18, "nombre": 28, "familia": 14, "clase": 24, "archivo": 34, "colocacion": 26, "claves_mapa": 36,
          "bloquea_casilla": 14, "reacciona_a": 34, "senales": 24, "condiciones_si": 22, "acciones_hace": 26, "papeles": 24,
          "da_botin": 30, "flag": 22, "zona": 10, "estado": 9, "notas": 60,
          "pieza": 16, "llega": 16, "condicion": 26, "hace": 50, "resultado": 18, "botin": 26, "cada_s": 8, "fuente": 30, "nota": 40}


def _cabecera(ws, cab, relleno=RELLENO_CAB):
    for j, k in enumerate(cab, 1):
        c = ws.cell(row=1, column=j, value=k)
        c.font = F_CAB
        c.fill = relleno
        c.alignment = Alignment(vertical="center", wrap_text=True)
        ws.column_dimensions[get_column_letter(j)].width = ANCHOS.get(k, 16)
    ws.row_dimensions[1].height = 30
    ws.freeze_panes = "B2"


def _filas(ws, filas, desde=2):
    for i, fila in enumerate(filas, desde):
        for j, v in enumerate(fila, 1):
            if isinstance(v, str) and v.strip() != "" and v.strip() != "-":
                # números que vienen de los TSV
                try:
                    if v.lstrip("-").replace(".", "", 1).isdigit():
                        v = float(v) if "." in v else int(v)
                except ValueError:
                    pass
            c = ws.cell(row=i, column=j, value=v)
            c.font = F_NORMAL
            c.alignment = ALIN
            c.border = BORDE
    return desde + len(filas)


def _libres(ws, n_col, desde, n=FILAS_LIBRES):
    for i in range(desde, desde + n):
        for j in range(1, n_col + 1):
            c = ws.cell(row=i, column=j)
            c.font = F_NORMAL
            c.alignment = ALIN
            c.fill = RELLENO_EDITABLE
            c.border = BORDE
    return desde + n


def _validar(ws, col_idx, opciones, hasta):
    letra = get_column_letter(col_idx)
    dv = DataValidation(type="list", formula1='"%s"' % ",".join(opciones), allow_blank=True, showErrorMessage=False)
    ws.add_data_validation(dv)
    dv.add("%s2:%s%d" % (letra, letra, hasta))


def _tsv(nombre):
    with open(os.path.join(DATOS, nombre), encoding="utf-8", newline="") as f:
        filas = [l for l in csv.reader(f, delimiter="\t") if any(x.strip() for x in l)]
    return filas[0], filas[1:]


def hoja_leeme(wb):
    ws = wb.active
    ws.title = "Leeme"
    ws.column_dimensions["A"].width = 26
    ws.column_dimensions["B"].width = 110
    lineas = [
        ("BD DE INTERACTUABLES · Magic Symbols", None),
        ("Generado por tools/generar_bd_interactuables.py el 3/11/2026 a partir de leer el proyecto (escenas/puzle.gd, objetos/*.gd, enemigos/*.gd, ARQUITECTURA.md) y las tablas de nucleo/datos/.", None),
        ("", None),
        ("QUÉ HAY EN CADA HOJA", None),
        ("Interactuables", "UNA FILA POR PIEZA: todo lo que la jugadora puede tocar, golpear, quemar, coger, abrir o con lo que puede hablar. Es el catálogo."),
        ("Interacciones", "UNA FILA POR REACCIÓN: pieza + lo que le llega -> lo que hace. Es la hoja de reactivos_mapa.tsv ampliada con todo lo que el código ya hace. Aquí se AÑADEN interacciones nuevas."),
        ("Vocabulario", "Las listas de valores válidos (familias, vías, elementos, papeles, zonas, estados). Los desplegables de las otras hojas leen de aquí; si añades un valor nuevo, ponlo también en la hoja y en el código."),
        ("objetos / fuentes / botin_tablas / reactivos_mapa / estados_mundo / recetas / mejoras", "COPIA tal cual de nucleo/datos/*.tsv (pestañas verdes). Son las tablas que el juego lee de verdad (BD, nucleo/bd.gd). Para que un cambio entre en el juego hay que pasarlo al .tsv (UTF-8, tabulador, «-» = vacío)."),
        ("", None),
        ("CÓMO AÑADIR", None),
        ("Un objeto nuevo (ingrediente, consumible, llave...)", "Una fila en la hoja objetos (id único, categoría, etiquetas, pila...) y de dónde sale en fuentes. Luego a objetos.tsv / fuentes.tsv. No hace falta GDScript."),
        ("Una interacción nueva", "Una fila en Interacciones: pieza, llega (vía), condición, hace, resultado, botín, flag, cada_s, estado=idea. Si el botín es una tabla, también en botin_tablas. Cuando se programe, pasa a reactivos_mapa.tsv con estado nuevo/hay."),
        ("Una pieza nueva", "Una fila en Interactuables (estado=idea) con su familia, qué le llega y qué señales/condiciones/acciones tendría en Puzle3D; y sus reacciones en Interacciones."),
        ("", None),
        ("COLUMNAS DE Interactuables", None),
        ("id", "El tipo de pieza en Puzle3D (`; pieza <id> <tipo> x y`) o el nombre del reactivo/enemigo en el código."),
        ("familia", "combustible · fuego_de_mapa · agua · electricidad · pulso · recolectable · rompible · contenedor · paso · logica · fisica · enemigo · npc · nivel · ambiente · fauna · decorado"),
        ("colocacion / claves_mapa", "Cómo se pone en un mapa (letra de la hoja o línea `; pieza`) y qué claves admite (escenas/puzle.gd, CLAVES)."),
        ("bloquea_casilla", "Si tapa su casilla al paso (jugadora, enemigos, flechas)."),
        ("reacciona_a", "Lo que le llega y le hace algo: elementos (fuego, agua, hielo, rayo, tierra, viento), golpe (F), E, pulso, explosión, presencia, empujón, corriente, tiempo, regla."),
        ("senales / condiciones_si / acciones_hace", "Lo que Puzle3D sabe de ella: cuando=<id>.<señal>, si=<id>.<cond>, hace=<id>.<acción>."),
        ("papeles", "Los papeles de Reactivo3D (objetos/objetos_3d.gd): inflamable, propaga_llama, apaga, mojable, pesado, conduce, congelable, fuente_fuego, activable, recibe_agua, sacudible, helable."),
        ("da_botin", "Lo que suelta: objeto:n, tabla:<id de botin_tablas>, da=…"),
        ("estado", "hay = ya funciona · cambio = funciona pero hay que tocarlo · nuevo = planificado (reactivos_mapa) · idea = propuesta sin plan."),
        ("", None),
        ("COLUMNAS DE Interacciones", None),
        ("llega", "La vía: fuego, agua, hielo, rayo, tierra, viento, cualquier_hechizo, golpe, E, pulso, pulso_jugador, explosion, presencia, empujon, corriente, tiempo, regla, enemigo, pisar."),
        ("condicion", "Estado en que tiene que estar la pieza (o del mundo: casilla(x,y).helada, tener.llave, flag...) para que la reacción ocurra."),
        ("hace / resultado", "Qué pasa y en qué estado queda la pieza."),
        ("cada_s", "Segundos para volver a dar (rebrota); 0 = una sola vez o sin límite."),
        ("fuente", "De dónde sale el dato: archivo de código o tabla."),
        ("", None),
        ("LEYENDA DE COLORES", None),
        ("Cabecera azul", "Hojas escritas a mano (editables)."),
        ("Cabecera verde", "Copias de los TSV del juego."),
        ("Filas crema", "Filas libres al final de cada hoja para añadir (con desplegables en las columnas de vocabulario)."),
    ]
    for i, (a, b) in enumerate(lineas, 1):
        ca = ws.cell(row=i, column=1, value=a)
        ca.font = F_TITULO if i == 1 else (F_NEGRITA if b is None and a else F_NORMAL)
        ca.alignment = ALIN
        if b is not None:
            cb = ws.cell(row=i, column=2, value=b)
            cb.font = F_NORMAL
            cb.alignment = ALIN


def hoja_interactuables(wb):
    ws = wb.create_sheet("Interactuables")
    _cabecera(ws, CAB_INTER)
    fin = _filas(ws, INTERACTUABLES)
    fin = _libres(ws, len(CAB_INTER), fin)
    _validar(ws, CAB_INTER.index("familia") + 1, FAMILIAS, fin)
    _validar(ws, CAB_INTER.index("bloquea_casilla") + 1, BLOQUEA, fin)
    _validar(ws, CAB_INTER.index("zona") + 1, ZONAS, fin)
    _validar(ws, CAB_INTER.index("estado") + 1, ESTADOS, fin)
    ws.auto_filter.ref = "A1:%s%d" % (get_column_letter(len(CAB_INTER)), fin - 1)
    ws["A1"].comment = Comment("Ejemplo de fila nueva (idea): id=espejo_hielo · nombre=Espejo de hielo · familia=pulso · reacciona_a=hielo, pulso · estado=idea", "BD")


def hoja_interacciones(wb):
    ws = wb.create_sheet("Interacciones")
    _cabecera(ws, CAB_ACC)
    fin = _filas(ws, INTERACCIONES)
    fin = _libres(ws, len(CAB_ACC), fin)
    _validar(ws, CAB_ACC.index("llega") + 1, LLEGA, fin)
    _validar(ws, CAB_ACC.index("estado") + 1, ESTADOS, fin)
    ws.auto_filter.ref = "A1:%s%d" % (get_column_letter(len(CAB_ACC)), fin - 1)
    ws["A1"].comment = Comment("Ejemplo de fila nueva (idea): pieza=colmena · llega=hielo · condicion=colgada · hace=se congela y cae entera · resultado=vacia · botin=panal:3 · estado=idea", "BD")


def hoja_vocabulario(wb):
    ws = wb.create_sheet("Vocabulario")
    listas = [("familia", FAMILIAS), ("llega (vía)", LLEGA), ("elemento", ELEMENTOS), ("papel (Reactivo3D)", PAPELES),
              ("zona", ZONAS), ("estado", ESTADOS), ("bloquea_casilla", BLOQUEA),
              ("categoria (objetos)", ["hongo", "planta", "raiz", "mineral", "animal", "botin", "consumible", "pigmento", "clave", "ropa", "glifo"]),
              ("calidad", ["comun", "epico", "legendario"]),
              ("fuente (fuentes.tsv)", ["recoger", "reaccion", "pulso", "tabla", "reactivo", "golpe", "romper", "enemigo", "cofre", "receta", "comprar", "mision"]),
              ("etiquetas de receta", ["vital", "calor", "agua", "frio", "electrico", "viento", "tierra", "resonante", "tinta", "toxico", "proteccion", "raro"])]
    for j, (titulo, valores) in enumerate(listas, 1):
        c = ws.cell(row=1, column=j, value=titulo)
        c.font = F_CAB
        c.fill = RELLENO_CAB
        ws.column_dimensions[get_column_letter(j)].width = 22
        for i, v in enumerate(valores, 2):
            cc = ws.cell(row=i, column=j, value=v)
            cc.font = F_NORMAL
    ws.freeze_panes = "A2"


def hoja_tsv(wb, nombre):
    cab, filas = _tsv(nombre)
    ws = wb.create_sheet(nombre.replace(".tsv", ""))
    _cabecera(ws, cab, RELLENO_COPIA)
    fin = _filas(ws, filas)
    fin = _libres(ws, len(cab), fin, 15)
    if "categoria" in cab and nombre == "objetos.tsv":
        _validar(ws, cab.index("categoria") + 1, ["hongo", "planta", "raiz", "mineral", "animal", "botin", "consumible", "pigmento", "clave", "ropa", "glifo"], fin)
        _validar(ws, cab.index("calidad") + 1, ["comun", "epico", "legendario"], fin)
        _validar(ws, cab.index("estado") + 1, ["hay", "nuevo"], fin)
    if nombre == "fuentes.tsv":
        _validar(ws, cab.index("fuente") + 1, ["recoger", "reaccion", "pulso", "tabla", "reactivo", "golpe", "romper", "enemigo", "cofre", "receta", "comprar", "mision"], fin)
    if nombre == "reactivos_mapa.tsv":
        _validar(ws, cab.index("estado") + 1, ESTADOS, fin)
    ws.auto_filter.ref = "A1:%s%d" % (get_column_letter(len(cab)), fin - 1)
    ws["A1"].comment = Comment("Copia de nucleo/datos/%s. Lo que cambies aquí hay que pasarlo al .tsv para que el juego lo lea." % nombre, "BD")


def main():
    wb = Workbook()
    hoja_leeme(wb)
    hoja_interactuables(wb)
    hoja_interacciones(wb)
    hoja_vocabulario(wb)
    for n in ["objetos.tsv", "fuentes.tsv", "botin_tablas.tsv", "reactivos_mapa.tsv", "estados_mundo.tsv", "recetas.tsv", "mejoras.tsv"]:
        hoja_tsv(wb, n)
    os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
    wb.save(SALIDA)
    print("escrito", SALIDA, "·", len(INTERACTUABLES), "interactuables ·", len(INTERACCIONES), "interacciones")


if __name__ == "__main__":
    sys.exit(main())
