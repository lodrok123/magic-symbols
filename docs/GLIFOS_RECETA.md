# Receta v2: geometría por ejes + propiedades aditivas + elemento por estado (17/10/2026, Juego)

Pablo (21:20): «Sin nada es una esfera de radio r. Glifos que asignan geometría: uno aumenta en horizontal (X), otro en
profundidad (Z), otro en altura (Y); más glifos, más tamaño en ese eje. Glifos que añaden una propiedad de forma
aditiva. Que n combinaciones de un glifo, sea el que sea, se produzcan solas sin hardcodear. Con los elementos igual:
el elemento da su etiqueta, características y tipo (sólido como tierra o hielo, "líquido" como fuego o agua).»

> **REGLA NUEVA (21/10, decisión de Pablo): ᛁ `linea` + elemento = RAYO.** El glifo `linea` deja de ser «muro delante»: **el muro es solo de `barrera`**, y `linea` con un
> elemento da un **haz recto desde la mano hacia donde apuntas** (en el código la forma se llama `haz`, para no mezclarlo con el elemento relámpago ᛊ; el nombre visible es
> «rayo de fuego», «rayo de hielo»…). Detalle en `ESPEC_HECHIZO.md` §3b. Donde más abajo se lea «ᛁᛁ = muro» o «Muro es X grande», vale lo antiguo solo con `barrera`
> (barrera + ᛁ sigue siendo el muro, y ᛁ le da ancho); sin barrera ni flecha, ᛁ es un haz.

## 1. Lo que hay hoy (medido en `magia/lanzador_3d.gd` y `nucleo/`)

- **Dos caminos.** `Receta3D` cuenta cinco glifos de geometría (línea, altura, tamaño, flecha, barrera) y
  `GeometriaHechizo.evaluar` saca formas con **nombre y regla propia** (chorro, muro, arco, corro, columna, punto,
  proyectil): siete ramas escritas a mano. En cuanto aparece otro glifo (rebote, repetición, pulso…), la receta se marca
  `antigua` y se interpreta con la lógica 2D de `SpellRecipe`. Hoy un glifo nuevo obliga a decidir en cuál de los dos
  caminos vive y qué hace con cada forma con nombre.
- **Los sellos ya son datos** (`Sigils.FORM` / `OPERATOR`: cada uno escribe uno o dos números en la receta). Esa parte
  del principio de Pablo ya se cumple; lo que no se cumple es la interpretación.
- **El elemento no dice qué es.** `RuneData` lleva color, daño y `tags` (`fuego, calor` · `hielo, frio` · `rayo,
  electrico` · `tiempo, disipar` · `agua` · `viento` · `tierra`). Que la tierra crea un bloque sólido, que el agua mete
  agua en la simulación o que el hielo se puede pisar está repartido por el código con `if elemento == …`.

## 2. El modelo

Una receta es tres cosas independientes que se multiplican sin conocerse:

```
VOLUMEN  (glifos de eje)   ×   PROPIEDADES  (glifos aditivos)   ×   ELEMENTO  (estado + etiquetas)
qué espacio ocupa              qué hace con él en el tiempo           de qué está hecho ese espacio
```

### 2.1 Volumen: tres ejes

Sin glifos: **esfera de radio r** (0,10 casilla desde el 24/10; ver ESPEC_HECHIZO §1). Cada glifo de eje suma en su eje; el volumen
es un **elipsoide** con semiejes (X, Y, Z), orientado a la mirada (Z = hacia delante, X = de lado, Y = arriba).

| eje | glifo | cada glifo añade | tope |
|---|---|---|---|
| X · horizontal | ᛁ línea dibujada **horizontal** | +0,25 de semieje (`PASO_ANCHO_V2`, 24/10): ᛜ + 4 ᛁ = muro de 3 casillas | semieje 3,0 (6 casillas de ancho) |
| Z · profundidad | ᛁ línea dibujada **vertical** | +0,10 de semieje (`PASO_FONDO_V2`) | semieje 3,0 (6 casillas) |
| Y · altura | ᛏ (antes levitación) | +0,30 de semieje (`PASO_ALTURA_V2`): 3 ᛏ = 2 niveles | semieje 1,0 (2 niveles; `MAX_NIVELES_SUBIBLES` si se puede pisar) |

(Valores del 24/10, decisión de Pablo: base 0,10 y un paso por eje para que con pocos glifos se llegue a 2 niveles y a un muro de 3 casillas. Los costes de §2.5 salen del volumen y por tanto de estos pasos.)

**Línea rotada (decidido 17/10, 21:39).** No choca con altura: la raya sola no pasa por el $P (atajo de raya del
Spellcaster, un solo tramo tras el rectificador) y su orientación sale exacta de las 8 direcciones del rectificador;
ᛏ son tres tramos y nunca es una raya. La orientación se lee **respecto a la página, no al hueco** (en el libro del Bosque
los huecos laterales están a 45° y una raya horizontal quedaría ambigua entre radial y tangencial): más horizontal que
vertical → X, más vertical → Z, diagonal exacta → X. La línea queda **exenta del giro hacia el centro** (127): se pinta
como se dibujó, con el mismo `linea.png` girado 90° para Z. Raido ᚱ quedó libre hasta el 23/10, que pasó a ser el glifo «pulso» (§2.2).

Las formas **dejan de tener nombre en la lógica**: se rasteriza el elipsoide sobre las casillas (como ya hace
`GeometriaHechizo.celdas` con la esfera) y punto. «Muro» es X grande **con `barrera`** (21/10: sin barrera, ᛁ ya no es un muro sino un haz); «pilar», Y grande; «haz», ᛁ sin
barrera ni flecha (se traza como recorrido, no como elipsoide: ver ESPEC §3b); «muro alto», barrera + X e Y; «losa», X y Z; «cortina», Y y Z. El nombre solo se **deriva** al final (eje dominante) para elegir
animación, cast point y VFX:

- Z dominante o la propiedad *viaja* → cast point **eje X** (mano al frente).
- Y dominante → **se eleva** (manos arriba).
- plano (X y/o Z sin Y) y quieto → **hacia abajo**.

Es exactamente la clasificación de `LAB_CASTPOINT.md`, que sale sola de las medidas.

`tamano` sobra (es un glifo de cada eje), `pilar` ya se retiraba y `altura` pasa a ser el glifo Y.

### 2.2 Propiedades: aditivas, una por glifo

Cada glifo de propiedad declara **un parámetro, cuánto suma por glifo y un tope**. Repetir el mismo glifo suma
otra vez. Ninguno sabe qué otros hay:

| glifo | parámetro | por glifo | tope | qué significa para cualquier volumen |
|---|---|---|---|---|
| ᛇ flecha | `viaja` (casillas) | +3 | 6 | desplazamiento: el volumen se desplaza desde la mano hacia delante (ya no es geometría) |
| ᛜ barrera | `solidez` | ×1,5 | ×3 | el volumen bloquea proyectiles y aguanta golpes |
| ᚠ repetición | `copias` | +1 | 4 | n volúmenes, repartidos a lo largo de X |
| ᚢ rebote | `rebotes` | +1 | 3 | al chocar, cambia de dirección (necesita *viaja*; sin él, refleja proyectiles) |
| ᚷ crecer (hasta el 23/10 «pulso») | `crece` (escala/s) | +0,5 | 1,5 | el volumen nace pequeño y crece hasta su tamaño. Id `pulso`, momento *continuo* (sin acción) |
| ᚱ pulso (**construido el 23/10**, id `raido`) | `resuena` (casillas) | +4 | 12 | el volumen suelta un `Pulso3D` que recorre los conductores con el elemento de la receta; actúa **al final** si viaja, **continuo** si el volumen se queda, **al inicio** en el resto (§2.4 bis; `PLAN_PULSO_RESONANTE.md` §2 y §10 bis) |
| ᚦ perforar (**construido el 30/10**, id `perforar`) | `perfora` (enemigos) | +1 | 3 | el proyectil atraviesa ese número de enemigos y se para en el siguiente (`golpes_dados > perfora`); sin proyectil no hace nada |
| ᛃ retorno (**30/10**, id `retorno`, sin PNG) | `retorna` (bool) | fija true | — | al acabar la ida el proyectil vuelve a la mano y golpea de nuevo a todos; un 2.º ᛃ no suma nada (solo recarga, daño y tinta). Contra un enemigo SIN perforar, la ida se para en el golpe y la vuelta no lo roza otra vez: dos golpes al mismo exigen ᚦ. La vuelta no aplica la materia (retorno + barrera no levanta barrera) |
| ᚨ buscar (**30/10**, id `buscar`) | `busca` (fuerza de giro) | +0,5 | 2 | el proyectil gira hacia el enemigo vivo más cercano de su cono de 60° y 6 casillas; sin proyectil no hace nada |
| retardo (**30/10**, id `retardo`, el reloj de arena) | `retardo` (s) | +1 | 3 | lo que sale tarda en salir: el volumen quieto nace tarde (`eventos_de`) y el proyectil espera quieto en la mano (`HechizoVivo.espera`) y luego arranca. La previsión no espera. El haz (ᛁ + elemento) no lo respeta |
| *aparcados* (17/10) | atracción, espejo, amplificar | — | — | se quedan fuera de la v2 hasta encontrarles uso |
| *pendientes* ᛞ ᛈ | `guarda`, `destello`, `oculto` | — | — | ver la propuesta anterior |

### 2.3 Elemento: estado + características

`RuneData` gana campos de **datos** (en los `.tres`, sin código):

| campo | qué es | fuego | agua | tierra | hielo | rayo | viento | tiempo |
|---|---|---|---|---|---|---|---|---|
| `estado` | cómo llena el volumen | plasma | líquido | sólido | sólido | energía | gas | campo |
| `persiste` | s que dura lo creado | 3 | — (la simulación) | 8 | 6 (se derrite) | 0,2 | 1,5 | 4 |
| `empuje` | fuerza sobre lo que toca | baja | media | alta | baja | baja | muy alta | 0 |
| `pisable` | se puede subir encima | no | no | sí | sí | no | no | no |
| `deja` | estado de suelo que deja | quemado | mojado | — | helado | — | — | — |
| `tags` | las de hoy (reacciones de objetos) | fuego, calor | agua | tierra | hielo, frio | rayo, electrico | viento | tiempo, disipar |

**El estado decide qué ES el volumen**, una sola vez por estado, no por forma:

- **sólido** → crea un cuerpo con colisión en las casillas del volumen; bloquea; se puede pisar si `pisable` y Y ≤ niveles
  subibles; se rompe con golpes o se derrite (`persiste`).
- **líquido** → mete agua en `AguaSim3D` en esas casillas (volumen = el del elipsoide); a partir de ahí, la simulación.
- **plasma** → zona de daño durante `persiste` y deja `quemado`; prende lo que arda.
- **energía** → descarga instantánea en el volumen y conduce por agua y conductores (lo que ya hace el emisor).
- **gas** → campo de fuerza durante `persiste` (empuja en la dirección de la mirada, o hacia dentro con `atrae`).
- **campo** → ralentiza lo que esté dentro.

### 2.4 Por qué las combinaciones salen solas

La receta se interpreta en un orden fijo y cada paso lee solo **números**:

1. **Volumen** = elipsoide (X, Y, Z) → casillas.
2. **Copias y espejo** → cuántos volúmenes y dónde.
3. **Vida**: `retardo` → nace → `crece` → se desplaza si `viaja` (rebota, perfora, vuelve) → dura `persiste` × calidad.
4. **Materia**: el `estado` del elemento llena las casillas que ocupe en cada momento; `solidez` y `atrae` se aplican encima.
5. **Daño y empuje**: `daño × potencia`, `empuje` del elemento, más las reacciones por etiqueta (las de hoy).

Ningún paso pregunta «¿hay rebote y repetición?». Ejemplos que salen sin escribirse:

- **ᛁᛁ + agua** = (hasta el 20/10 un muro de agua; **desde el 21/10 es un rayo de agua**: un chorro de 4 m que moja el recorrido y empuja al que toca).
- **ᛁᛁ + tierra** = (hasta el 20/10 un muro pisable; **desde el 21/10 un rayo de tierra**: una fila de pinchos que brotan en secuencia y golpean). El muro de tierra es **ᛜ + ᛁᛁ + tierra**.
- **ᛁᛁ + ᛜ + agua** = muro de agua que además para flechas.
- **ᛏᛏ + hielo** = pilar de hielo de 2 niveles que se puede escalar y se derrite.
- **Z×3 + ᛇ + fuego** = lanza de fuego larga que viaja.
- **Z×3 + ᛇ + ᚢ + rayo** = lanza eléctrica que rebota.
- **ᚷ (crecer) + viento** = onda que empuja y crece.
- **ᚠᚠ + ᛇ + hielo** = tres bolas de hielo en abanico.
- **ᛁ + Z×2 + agua** = (antes una losa de agua) **desde el 21/10, un rayo de agua de 5 m** (Z×2 es ᛁ vertical: cualquier ᛁ suma al mismo haz). La losa/charco grande delante queda para ᛜ + ᛁ + ᛁ.

### 2.4 bis Momento de ejecución (23/10, Pulso resonante fase 2)

La línea de tiempo del paso 3 («nace → crece → viaja → dura») tiene tres puntos donde una propiedad puede **hacer algo**, y cada glifo declara en cuál. Es un **dato del glifo** (en `Sigils.GLIFOS`, como `por_glifo` y `tope`),
no lo elige el jugador ni depende del orden en que dibujó los glifos:

| clave | qué dice |
|---|---|
| `momento` | `"inicio"` (al nacer el volumen, una vez) · `"continuo"` (mientras vive, cada `PERIODO_MIN_CONTINUO_S` como mínimo) · `"final"` (al chocar o acabarse, una vez). Sin él, `MOMENTO_DEFECTO` = inicio. «final» admite además tres valores finos, ver «Los tres finales» |
| `momento_si` | reglas `{cuando, es}` en orden: la primera cuyo `cuando` se cumple cambia el momento. `cuando` ∈ `Hechizo.CONDICIONES_MOMENTO`: `viaja` (es un proyectil) · `persistente` (el volumen se queda: solidez, permanencia o elemento sólido, y no es un haz) |
| `paso` | el paso de §2.4 al que pertenece (1 volumen · 2 copias · 3 vida · 4 materia · 5 daño y efectos): ordena los glifos **dentro de un mismo momento** |
| `accion` | lo que hace en su momento, del catálogo cerrado `Hechizo.ACCIONES` (el mismo de los eventos; hoy `emitir_pulso`). Sin `accion` el glifo no dispara nada: su efecto ya va dentro del ciclo de vida |

- **Orden fijo:** `Hechizo.acciones_en(momento)` devuelve las acciones por `paso` y, a igualdad, por el orden de la tabla (`Hechizo.ordenar_acciones`). El orden de dibujo no existe (la receta es un multiconjunto).
- **Un despachador, un catálogo, un orden (H2, 29/10):** los momentos de los glifos y los eventos de `Hechizo.eventos` pasan por el mismo `HechizoVivo._accion` y el mismo catálogo `Hechizo.ACCIONES`
  (`danar_area`, `crear_hijo`, `estado_suelo`, `sonido`, `vfx`, `emitir_pulso`; una acción desconocida se ignora). Las acciones de un evento se ordenan con `Hechizo.ordenar_acciones`: cada acción añadida por un
  glifo (`op: "anade"`) guarda el `paso` y el `orden` de tabla de ese glifo; las que no vienen de un glifo (laboratorio, elemento) valen paso 1 y orden 0, y a igualdad manda el orden en que se añadieron. La
  explosión de `radio_explosion` se añade después de todas. (`al_viajar`, que es periódico, conserva el orden de su lista.)
- **Los tres finales (H2):** el «final» del hechizo son tres eventos y un hechizo dispara UNO por tramo (`HechizoVivo._disparar_final`; `finales_vistos`):

  | evento | cuándo | `momento` fino del glifo |
  |---|---|---|
  | `al_impactar` | un proyectil se para por **golpe** (`motivo_fin` = golpe); salta después del `al_golpear` del objeto | `"impacto"` |
  | `al_detenerse` | un proyectil se para **sin golpear**: muro, suelo, alcance, tiempo, frenado o retorno | `"detencion"` |
  | `al_expirar` | **extinción**: acaba la vida de lo que nace quieto (persiste + permanencia, o el haz). Un proyectil ya no lo dispara | `"extincion"` |

  Un glifo con `momento: "final"` actúa en los tres (ᚱ no cambia); uno con un valor fino, solo en el suyo (`Hechizo.acciones_en_fin(causa)` resuelve fino + grueso; `acciones_en("final")` sigue devolviendo solo los
  de «final»). El momento «final» de los glifos sale UNA vez, justo antes del evento, con `celdas_de_contacto` (proyectil) o las casillas del volumen (extinción); con `motivo_fin` = «retorno» no sale (el pulso no
  sale al recoger el proyectil). `al_impactar` y `al_detenerse` saltan en el instante de pararse (antes `al_expirar` esperaba la `permanencia`). **Retorna:** la ida y la vuelta son dos tramos pero el final de la
  ida no dispara nada (el proyectil da la vuelta en `_fin_de_ida`); solo cuenta el de la vuelta, así que sigue habiendo un único final por hechizo.
- **Sin reentradas:** «inicio» y «final» disparan una vez por hechizo; mientras corren las acciones de un momento ningún otro momento del mismo hechizo puede dispararse (`HechizoVivo._en_momento`); un hijo de `crear_hijo` no repite los efectos de su padre.
- **Continuo:** el primer disparo es al nacer; luego cada `max(intervalo, PERIODO_MIN_CONTINUO_S)` (1,5 s) hasta que acaba la vida, con tope `MAX_DISPAROS_CONTINUOS` (8). **Cuesta tinta** (§2.5): ×(1 + `COSTE_CONTINUO_V2`) = +25 % si la receta lleva ᚱ,
  no viaja y tiene solidez o permanencia (`Sigils.recargo_continuo`, el mismo número en la receta y en el Hechizo). **Límite conocido:** el coste en tinta solo ve las propiedades de la receta, no el elemento; un ᚱ con un elemento sólido
  (tierra, hielo) sin barrera también late, pero sin recargo.
- **Lo que ya existía** conserva su comportamiento y declara el momento que ya tiene de hecho (solo descriptivo): flecha *continuo* (se desplaza mientras vive) · barrera *continuo* · repetición *inicio* · rebote *final* · ᚷ crecer *continuo* · permanencia *final*; los ejes, *inicio*.
  Las propiedades aparcadas encajarán solas: retardo es «antes del inicio» y destello es «al final» (PLAN §10 bis).
- **Ejemplos que salen sin escribirse:** ᚱ solo → pulso en el sitio donde nace; flecha + ᚱ → el pulso sale **donde choca la flecha**; barrera + ᚱ → el muro **late**; ᚱᚱ (alcance 8) + prisma → llega más lejos.

### 2.5 Equilibrio sin tablas

- **Coste en tinta y recarga ∝ volumen y número de propiedades**: un muro de 3×2 cuesta más que una bola, sin
  escribirlo para «muro».
- **Topes por eje y por propiedad**: los de las tablas.
- **Tope total**: `max_sigils_per_page`, que ya existe.
- **Validez**: un sólido pisable más alto que lo que se puede subir no se lanza (aviso que ya existe, `y_tope`).

## 3. Plan

**F1 · Datos y volumen** (Juego, sin cambiar lo que se ve)
- `Sigils`: cada entrada lleva `tipo: "eje" | "prop"`, `eje`, `por_glifo`, `tope`.
- `RuneData`: campos de §2.3 y los siete `.tres` rellenos.
- `GeometriaV2`: elipsoide → casillas, eje dominante → nombre derivado.
- Todo detrás de `Receta3D.V2 = false`.
- Prueba: **todas las combinaciones** de hasta 4 glifos (miles) evaluadas sin error, casillas acotadas por los topes,
  coste creciente con el volumen.

**F2 · Materia por estado** (Juego): los seis estados de §2.3 reutilizando lo que ya existe:
- sólido → el bloque de tierra y `solidificar_casilla`;
- líquido → `fuente_en` / `limitar_fuente` de la simulación;
- plasma → estados de suelo y fuego de mapa;
- energía → la descarga de `EmisorRayo3D`;
- gas → `push`;
- campo → `time_scale` local.

Quitar los `if elemento ==` que pasen a ser dato.

**F3 · Propiedades** (Juego)
- Primero las nueve de hoy, pasadas a la v2.
- Después las nuevas, de una en una con su prueba.
- Activar `V2 = true` y retirar `antigua` y las siete ramas con nombre.

**F4 · Laboratorio de recetas** (Juego)
- Panel con un contador por glifo y elemento, que lanza la receta y muestra volumen, coste y nombre derivado.
- Modo «barrido»: lanza combinaciones al azar seguidas para detectar casos raros.
- Comparte sala con el lab de cast points.

**Pipeline**
- **VFX por estado + dimensiones, no por forma:** un dibujo por estado (bloque sólido, masa líquida, llama-plasma,
  arco-energía, remolino-gas, burbuja-campo) que se escala a (X, Y, Z). Las firmas por propiedad, como en
  `MEJORAS_POTENCIA.md` §2.
- PNG de los glifos nuevos.

**Pablo**
- Decisiones de §4.
- Regrabar las muestras de los glifos que cambien de runa.

## 4. Decisiones (Pablo, 17/10 21:39)

1. **Eje Z** = la línea ᛁ dibujada en vertical (§2.1). Raido queda libre.
2. **Flecha** = desplazamiento (propiedad `viaja`); la profundidad la da la línea vertical.
3. **ᛏ** = solo altura; quedarse lo decide el elemento (`persiste`).
4. **Retardo, atracción, espejo, amplificar**: aparcados hasta encontrarles uso.
5. **Dónde nace**: desde la mano del personaje, quieto. **No todas las combinaciones tienen que ser útiles**: se aceptan
   combinaciones débiles o raras; no se corrigen a mano.
6. **Topes por eje**: los de §2.1, a ajustar en el lab.

— Juego
