"""Los efectos de sonido del juego, sintetizados.

MISMO CRITERIO QUE gen_fx.py: el sonido es un dato que se genera, no un
archivo que alguien encontro por ahi. Se gana lo mismo que con los
sprites — cambiar como suena el hielo es tocar un numero y relanzar, no
buscar otra grabacion y volver a recortarla— y ademas no hay licencias
que arrastrar.

Lo que NO se gana es realismo. Un crepitar sintetizado no es un crepitar
grabado, y se nota. La estructura esta pensada para que eso se pueda
arreglar despues sin tocar nada mas: cada sonido es un .wav suelto con
su nombre, asi que sustituir uno por una grabacion real es copiar el
archivo encima.

LA COHERENCIA LA DA EL METODO, no el volumen. Cada elemento suena a lo
que ES, no a un golpe generico teñido:
  fuego   ruido rosa modulado por chasquidos irregulares
  agua    ruido filtrado que cae de tono, con burbujas
  hielo   parciales altos que cristalizan hacia arriba y se apagan
  rayo    transitorio brutal de 5 ms y una cola de trueno
  viento  ruido de banda estrecha con el filtro barriendo
  tierra  retumbe grave, sin nada por encima de 300 Hz
  tiempo  una campana del reves: termina donde deberia empezar

Uso:  python gen_sfx.py <carpeta_destino>
"""
import numpy as np
import os
import sys
import wave

SR = 44100


# --------------------------------------------------------------- utiles

def t(dur):
    return np.linspace(0.0, dur, int(SR * dur), endpoint=False)


def noise(dur, seed=0):
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(SR * dur))


def lowpass(x, corte):
    """Un polo. No es un filtro fino, pero es el que quita el brillo sin
    meter resonancias raras, que es justo lo que hace falta para
    convertir ruido blanco en algo que suene a material."""
    a = np.exp(-2.0 * np.pi * corte / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1.0 - a) * x[i] + a * acc
        y[i] = acc
    return y


def highpass(x, corte):
    return x - lowpass(x, corte)


def sweep_lowpass(x, de, a):
    """Filtro con el corte moviendose. Es lo que separa un 'fsss' de un
    viento: el viento CAMBIA de color mientras suena."""
    cortes = np.geomspace(max(de, 20.0), max(a, 20.0), len(x))
    alfa = np.exp(-2.0 * np.pi * cortes / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1.0 - alfa[i]) * x[i] + alfa[i] * acc
        y[i] = acc
    return y


def env(n, ataque, caida, curva=2.5):
    """Envolvente ataque/caida. La caida es exponencial y no lineal
    porque el oido percibe el volumen en escala logaritmica: una caida
    recta suena a que alguien baja un mando, no a que algo se apaga."""
    a = max(1, int(SR * ataque))
    d = max(1, n - a)
    return np.concatenate([
        np.linspace(0.0, 1.0, a),
        np.exp(-curva * np.linspace(0.0, 1.0, d) * 3.0),
    ])[:n]


def tono(dur, f0, f1=None):
    f1 = f0 if f1 is None else f1
    frec = np.geomspace(f0, f1, int(SR * dur))
    fase = np.cumsum(2.0 * np.pi * frec / SR)
    return np.sin(fase)


## Volumen objetivo, medido en RMS y no en pico.
##
## Normalizar por pico es lo natural y esta MAL para esto: el pico dice
## cuanto sube la onda una sola vez, no cuanto se oye. Normalizados a
## pico, el trazo de tiza salia con cuatro veces mas energia que el
## chasquido del arco, y habia que compensarlo a mano con decibelios en
## sfx.gd, que es corregir un error con otro.
##
## Con RMS todos suenan igual de fuertes de verdad, y los decibelios del
## catalogo vuelven a significar lo que deben: no "arreglar este
## archivo", sino "este sonido va discreto".
RMS_OBJETIVO = 0.13

## Tope de pico. Los sonidos de transitorio —el rayo, la pisada— tienen
## muchisimo pico y poquisimo RMS, asi que igualarlos por RMS los haria
## saturar. Cuando pasa, mandan ellos: se baja el conjunto y se acepta
## que suenen algo mas flojos, que es mejor que distorsionar.
PICO_MAXIMO = 0.95


def guardar(nombre, x, destino):
    x = np.nan_to_num(x).astype(float)

    # LAS RAMPAS VAN ANTES DE NORMALIZAR, y esto costo un rato de
    # entender. Al reves, la rampa de entrada se comia justo la muestra
    # mas alta del rayo —que esta en los primeros 5 ms— y el archivo
    # salia con un pico de 0.35 en vez de 0.95: el sonido mas violento
    # del juego era el mas flojo.
    #
    # La entrada es de 0.5 ms y no de 3: un ataque brusco NO hace clic si
    # empieza cerca de cero, y medio milisegundo basta para asegurarlo
    # sin redondear el golpe. La salida si necesita los 3 ms, porque ahi
    # se corta la onda a media oscilacion.
    ent = min(int(SR * 0.0005), len(x) // 2)
    sal = min(int(SR * 0.003), len(x) // 2)
    if ent > 0:
        x[:ent] *= np.linspace(0.0, 1.0, ent)
    if sal > 0:
        x[-sal:] *= np.linspace(1.0, 0.0, sal)

    rms = np.sqrt(np.mean(x ** 2))
    if rms > 0:
        x = x / rms * RMS_OBJETIVO
    pico = np.max(np.abs(x))
    if pico > PICO_MAXIMO:
        x = x / pico * PICO_MAXIMO

    datos = (x * 32767).astype("<i2")
    ruta = os.path.join(destino, nombre + ".wav")
    with wave.open(ruta, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(datos.tobytes())
    print(f"  {nombre + '.wav':22s} {len(x) / SR:.2f}s")


# ----------------------------------------------------------- elementos

def fuego():
    """Bocanada + crepitar.

    El crepitar es lo que lo hace fuego y no un 'fsss': son CHASQUIDOS
    IRREGULARES encima del ruido. Regulares sonarian a motor."""
    dur = 1.1
    base = sweep_lowpass(noise(dur, 1), 1800.0, 600.0)
    base *= env(len(base), 0.04, dur, 1.6)

    rng = np.random.default_rng(11)
    chas = np.zeros(int(SR * dur))
    for _ in range(38):
        p = rng.integers(0, len(chas) - 400)
        largo = rng.integers(60, 340)
        pico = rng.uniform(0.25, 1.0) * (1.0 - p / len(chas))
        chas[p:p + largo] += (noise(largo / SR, int(p))
                              * np.exp(-np.linspace(0, 6, largo)) * pico)
    chas = highpass(chas, 900.0)

    return base * 0.75 + chas * 0.85


def agua():
    """Chapoteo: ruido que CAE de tono, mas burbujas.

    La caida de tono es lo que dice 'liquido'. Sin ella es arena."""
    dur = 0.7
    cuerpo = sweep_lowpass(noise(dur, 2), 4000.0, 500.0)
    cuerpo *= env(len(cuerpo), 0.005, dur, 2.2)

    rng = np.random.default_rng(3)
    burb = np.zeros(int(SR * dur))
    for _ in range(9):
        p = rng.integers(0, len(burb) - 3000)
        d = rng.uniform(0.03, 0.08)
        # Una burbuja es un tono que SUBE al romperse. Es el detalle que
        # convierte "agua" en "agua con algo dentro".
        b = tono(d, rng.uniform(300, 700), rng.uniform(700, 1500))
        b *= np.exp(-np.linspace(0, 9, len(b)))
        burb[p:p + len(b)] += b * rng.uniform(0.2, 0.5)

    return cuerpo * 0.8 + burb * 0.6


def hielo():
    """Cristalizar: parciales altos que SUBEN y se apagan.

    Que suba es la mitad del efecto. El mismo sonido bajando seria algo
    que se derrite; subiendo, es algo que cuaja."""
    dur = 0.9
    x = np.zeros(int(SR * dur))
    for k, (f, peso) in enumerate([(1180, 1.0), (1790, 0.7), (2630, 0.5),
                                   (3410, 0.35), (4700, 0.22)]):
        parcial = tono(dur, f * 0.94, f * 1.03)
        # Cada parcial entra un poco mas tarde: asi el cristal se forma
        # en vez de aparecer entero de golpe.
        retardo = int(SR * 0.012 * k)
        e = env(len(parcial), 0.004, dur, 1.9 + k * 0.25)
        e = np.concatenate([np.zeros(retardo), e])[:len(parcial)]
        x += parcial * e * peso

    escarcha = highpass(noise(dur, 4), 5000.0) * env(int(SR * dur), 0.002, dur, 5.0)
    return x * 0.75 + escarcha * 0.3


def rayo():
    """Cinco milisegundos de latigazo y una cola de trueno.

    El ataque lo es TODO. Un rayo con 30 ms de ataque no es un rayo, es
    un platillo: el cerebro lee la violencia en la pendiente inicial."""
    dur = 1.3
    latigazo = highpass(noise(0.09, 5), 1200.0)
    latigazo *= np.exp(-np.linspace(0, 26, len(latigazo)))

    trueno = lowpass(noise(dur, 6), 180.0)
    trueno *= env(len(trueno), 0.01, dur, 1.3)

    # Crujido intermedio: el rayo real no es un golpe limpio, restalla.
    rng = np.random.default_rng(7)
    crujido = np.zeros(int(SR * dur))
    for _ in range(14):
        p = rng.integers(0, int(SR * 0.45))
        largo = rng.integers(200, 900)
        crujido[p:p + largo] += (highpass(noise(largo / SR, int(p)), 2500.0)
                                 * np.exp(-np.linspace(0, 7, largo))
                                 * rng.uniform(0.2, 0.7))

    x = np.zeros(int(SR * dur))
    x[:len(latigazo)] += latigazo * 1.0
    # El trueno pesa MAS que el crujido: medido, la mezcla anterior
    # dejaba el centro espectral en 9 kHz, o sea estatica de radio. Un
    # rayo tiene el cuerpo abajo y solo el filo arriba.
    return x + trueno * 1.8 + crujido * 0.35


def viento():
    """Ruido de banda con el filtro barriendo arriba y abajo.

    Un viento que no cambia de color es un ventilador."""
    dur = 1.4
    x = sweep_lowpass(noise(dur, 8), 400.0, 2200.0)
    x = highpass(x, 260.0)
    # Hinchada suave, no un golpe: el viento llega, no impacta.
    n = len(x)
    e = np.sin(np.linspace(0.0, np.pi, n)) ** 1.6
    return x * e


def tierra():
    """Retumbe. Nada por encima de 300 Hz: si se oye brillo, es piedra
    rompiendose, y eso es otro sonido."""
    dur = 0.85
    rumor = lowpass(noise(dur, 9), 150.0) * env(int(SR * dur), 0.012, dur, 2.0)
    golpe = tono(0.28, 78, 44) * np.exp(-np.linspace(0, 8, int(SR * 0.28)))
    x = rumor * 0.9
    x[:len(golpe)] += golpe * 0.8
    return x


def tiempo():
    """Una campana del reves.

    Nada natural crece hacia su propio ataque, y por eso un sonido
    invertido se lee al instante como 'algo va al reves'. Es la manera
    mas barata que hay de que una runa suene a magia y no a golpe."""
    dur = 1.0
    x = np.zeros(int(SR * dur))
    for f, peso in [(523, 1.0), (784, 0.55), (1046, 0.4), (1568, 0.22)]:
        x += tono(dur, f) * env(int(SR * dur), 0.002, dur, 2.2) * peso
    x *= 1.0 + 0.15 * np.sin(2 * np.pi * 5.5 * t(dur))   # tremolo de reloj
    return x[::-1]


# -------------------------------------------------------------- mundo

def prender():
    """Lo que prende, no lo que arde: un fogonazo corto."""
    dur = 0.45
    x = sweep_lowpass(noise(dur, 12), 3000.0, 800.0)
    return x * env(len(x), 0.006, dur, 3.2)


def congelar():
    dur = 0.55
    x = tono(dur, 900, 1900) * env(int(SR * dur), 0.006, dur, 2.6)
    x += highpass(noise(dur, 13), 4000.0) * env(int(SR * dur), 0.002, dur, 4.5) * 0.4
    return x


def chispa():
    """El conductor al encenderse: dos ticks y se acabo."""
    dur = 0.22
    x = highpass(noise(dur, 14), 3000.0) * np.exp(-np.linspace(0, 16, int(SR * dur)))
    x[int(SR * 0.06):] += (highpass(noise(dur - 0.06, 15), 4000.0)
                           * np.exp(-np.linspace(0, 20, int(SR * (dur - 0.06)))) * 0.6)
    return x


def puerta_abre():
    """Chirrido que SUBE mientras el porton se levanta, y un tope."""
    dur = 1.0
    chirrido = tono(0.75, 150, 320)
    # Un chirrido es un tono sucio: se ensucia con un poco de ruido
    # modulado por el propio tono, no añadiendo ruido a secas.
    chirrido = np.sign(chirrido) * np.abs(chirrido) ** 0.6
    chirrido *= env(len(chirrido), 0.05, 0.75, 1.0) * 0.5
    chirrido = lowpass(chirrido, 1400.0)

    x = np.zeros(int(SR * dur))
    x[:len(chirrido)] += chirrido
    tope = lowpass(noise(0.2, 16), 220.0) * np.exp(-np.linspace(0, 9, int(SR * 0.2)))
    x[int(SR * 0.72):int(SR * 0.72) + len(tope)] += tope * 1.2
    return x


def puerta_cierra():
    dur = 0.8
    chirrido = tono(0.5, 300, 140)
    chirrido = np.sign(chirrido) * np.abs(chirrido) ** 0.6
    chirrido *= env(len(chirrido), 0.04, 0.5, 1.2) * 0.45
    chirrido = lowpass(chirrido, 1200.0)
    x = np.zeros(int(SR * dur))
    x[:len(chirrido)] += chirrido
    portazo = lowpass(noise(0.28, 17), 160.0) * np.exp(-np.linspace(0, 7, int(SR * 0.28)))
    x[int(SR * 0.48):int(SR * 0.48) + len(portazo)] += portazo * 1.4
    return x


def derrumbe():
    """Rocas: varios golpes secos encadenados, no uno solo."""
    dur = 0.8
    rng = np.random.default_rng(18)
    x = np.zeros(int(SR * dur))
    for _ in range(7):
        p = rng.integers(0, int(SR * 0.45))
        d = rng.uniform(0.06, 0.16)
        g = lowpass(noise(d, int(p)), rng.uniform(300, 900))
        g *= np.exp(-np.linspace(0, 11, len(g)))
        x[p:p + len(g)] += g * rng.uniform(0.4, 1.0)
    return x


def rodar():
    """El canto rodando una casilla: arrastre grave y un asiento."""
    dur = 0.6
    x = sweep_lowpass(noise(dur, 19), 700.0, 200.0)
    x *= np.sin(np.linspace(0, np.pi, len(x))) ** 1.2
    tope = lowpass(noise(0.14, 20), 200.0) * np.exp(-np.linspace(0, 10, int(SR * 0.14)))
    x[-len(tope):] += tope * 1.1
    return x


def arco():
    """Tensar no, soltar: el chasquido de la cuerda."""
    dur = 0.3
    cuerda = tono(dur, 220, 90) * np.exp(-np.linspace(0, 17, int(SR * dur)))
    aire = highpass(noise(dur, 21), 2000.0) * np.exp(-np.linspace(0, 22, int(SR * dur)))
    return cuerda * 0.8 + aire * 0.5


def clavar():
    dur = 0.2
    x = lowpass(noise(dur, 22), 1400.0) * np.exp(-np.linspace(0, 20, int(SR * dur)))
    x += tono(dur, 420, 260) * np.exp(-np.linspace(0, 24, int(SR * dur))) * 0.5
    return x


def pira():
    """La victoria. Un golpe de aire y la llama prendiendo, mas largo y
    mas grave que 'prender': esto es el final del nivel."""
    dur = 1.6
    x = sweep_lowpass(noise(dur, 23), 2400.0, 400.0)
    x *= env(len(x), 0.06, dur, 1.2)
    campana = np.zeros(int(SR * dur))
    for f, p in [(392, 1.0), (587, 0.5), (784, 0.3)]:
        campana += tono(dur, f) * env(int(SR * dur), 0.004, dur, 1.4) * p
    return x * 0.7 + campana * 0.35


# ----------------------------------------------------------- jugador

def paso():
    """60 ms. Un paso mas largo suena a pisar barro y se nota muchisimo
    cuando se repite cien veces por nivel."""
    dur = 0.075
    x = lowpass(noise(dur, 24), 900.0) * np.exp(-np.linspace(0, 13, int(SR * dur)))
    x += tono(dur, 120, 70) * np.exp(-np.linspace(0, 15, int(SR * dur))) * 0.4
    return x


def dano():
    dur = 0.35
    x = tono(dur, 330, 120) * env(int(SR * dur), 0.003, dur, 3.0)
    x += lowpass(noise(dur, 25), 1600.0) * env(int(SR * dur), 0.002, dur, 4.0) * 0.6
    return x


def muerte():
    dur = 1.4
    x = np.zeros(int(SR * dur))
    for f, p in [(220, 1.0), (330, 0.5), (110, 0.7)]:
        x += tono(dur, f, f * 0.42) * env(int(SR * dur), 0.01, dur, 1.1) * p
    return x


# ------------------------------------------------------------- libro

def libro_abre():
    dur = 0.6
    x = sweep_lowpass(noise(dur, 26), 3500.0, 900.0)
    return x * env(len(x), 0.02, dur, 2.8) * 0.8


def libro_cierra():
    dur = 0.45
    x = lowpass(noise(dur, 27), 800.0) * env(int(SR * dur), 0.004, dur, 3.6)
    x += tono(dur, 90, 60) * np.exp(-np.linspace(0, 12, int(SR * dur))) * 0.5
    return x


def trazo():
    """La tiza. Cortisimo y seco: se oye en CADA trazo, asi que
    cualquier cola lo convierte en un zumbido."""
    dur = 0.13
    x = highpass(noise(dur, 28), 2200.0)
    x *= np.sin(np.linspace(0, np.pi, len(x))) ** 0.8
    return x * 0.7


def sello_ok():
    """Dos notas que suben. Es el unico sonido del juego que dice 'has
    acertado', asi que tiene que ser el mas limpio de todos."""
    dur = 0.3
    a = tono(0.14, 880) * np.exp(-np.linspace(0, 8, int(SR * 0.14)))
    b = tono(0.18, 1320) * np.exp(-np.linspace(0, 7, int(SR * 0.18)))
    x = np.zeros(int(SR * dur))
    x[:len(a)] += a
    x[int(SR * 0.1):int(SR * 0.1) + len(b)] += b * 0.8
    return x


def sello_no():
    """Una nota que baja, corta y sin dureza.

    A proposito NO es un pitido de error: el rechazo pasa mucho y un
    sonido agresivo lo convertiria en un castigo. Esto solo dice 'otra
    vez', que es lo que hace falta."""
    dur = 0.22
    x = tono(dur, 330, 200) * env(int(SR * dur), 0.004, dur, 3.4)
    return x * 0.7


## LO QUE SE GENERA, y solo eso.
##
## Faltan seis que este archivo SABIA hacer y ya no hace: el paso, las
## dos puertas, el libro al abrirse y cerrarse, y la flecha al clavarse.
## Ahora son grabaciones de Kenney (CC0), y no por pereza: son foley, el
## oido los conoce de memoria y detecta el fraude al instante. Seis
## pisadas reales distintas valen mas que cualquier algoritmo.
##
## Las funciones que los hacian siguen aqui abajo, sin llamar. Se quedan
## a proposito: documentan como se sintetiza un chirrido o una pisada, y
## el dia que haga falta una puerta que ningun pack tenga —una compuerta
## de piedra, un porton metalico— hay de donde partir.
##
## Lo que SI se genera es todo lo elemental, y ahi la sintesis no es un
## apaño: no existe una grabacion de hielo cristalizando ni del tiempo
## yendo hacia atras.
CATALOGO = {
    "elem_fuego": fuego, "elem_agua": agua, "elem_hielo": hielo,
    "elem_rayo": rayo, "elem_viento": viento, "elem_tierra": tierra,
    "elem_tiempo": tiempo,
    "prender": prender, "congelar": congelar, "chispa": chispa,
    "derrumbe": derrumbe, "rodar": rodar,
    "arco": arco, "pira": pira,
    "dano": dano, "muerte": muerte,
    "trazo": trazo, "sello_ok": sello_ok, "sello_no": sello_no,
}


def main(destino):
    os.makedirs(destino, exist_ok=True)
    for nombre, hacer in CATALOGO.items():
        guardar(nombre, hacer(), destino)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
