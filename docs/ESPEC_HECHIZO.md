# Especificación del `Hechizo` (v1.1, 19/10/2026, Juego)

> **v1.1 (19/10 09:12, decisiones de Pablo):** Permanencia = **ᛉ algiz**; la flecha conserva su velocidad de ayer
> (**4 u/s de la escala antigua ≈ 1,7 m/s**); un hechizo que viaja **desaparece al acabar el recorrido** (o al chocar)
> salvo que lleve Permanencia: la vida natural del elemento solo cuenta para lo que nace quieto. Campo nuevo
> `permanencia`, separado de `persiste`.

Fuente: tabla de Pablo (19/10 09:00) y sus respuestas (09:08), contrastadas con el código de hoy: `nucleo/hechizo.gd`,
`nucleo/sigils.gd` (`GLIFOS`), `magia/hechizo_vivo.gd` y los siete `*_rune.tres`, leídos de la copia del portátil
(diario hasta la 182). **Objetivo de esta versión: que el hechizo se CONSTRUYA bien.** El cálculo de daño, empuje y
reacciones va después; aquí solo quedan sus campos con valores por defecto.

## 0. Reglas generales

1. **Unidad: 1 casilla = 1 m** (el cubo de 1 m³ de Pablo).
   - Todos los campos de longitud van en **metros-casilla** y las velocidades en m/s.
   - La conversión a unidades del motor (`Terreno3D.casilla`, 2,3–2,4 u) se hace **solo en `HechizoVivo`**, al
     ejecutar.
   - **Hoy está mezclado:** `semiejes`, `distancia_max` y `radio_explosion` van en casillas, pero `velocidad`,
     `aceleracion` y `altura_salida` van en u. Hay que unificarlo.
2. **Nombres: los del código** (decisión de Pablo). Los campos nuevos se nombran en el mismo estilo.
3. **Una sola definición de tiempo de vida (reglas de Pablo, 19/10).** Dos tiempos distintos:
   - `persiste`: **vida natural del elemento**. Solo cuenta para lo que **nace quieto**: un muro de tierra dura 8 s,
     una zona de fuego 3 s.
   - `permanencia`: **tiempo extra que se queda en el sitio**. Solo lo dan glifos (Permanencia ᛉ, barrera). Base 0.

   **Si viaja** (`distancia_max` > 0):
   1. recorre su distancia;
   2. **se para antes si encuentra un obstáculo** (casilla sólida, barrera que bloquea o un golpe más allá de
      `perfora`);
   3. donde se para, **se queda `permanencia` s**;
   4. con `permanencia` = 0, **desaparece al llegar o al chocar**.

   La vida natural del elemento **no** cuenta: una flecha de fuego sin Permanencia no se queda ardiendo.

   **Si no viaja:** nace y vive `persiste` + `permanencia`.

   **Cambia la regla de la entrada 182** («acaba por el alcance o por `persiste`, lo que llegue antes»). Ejemplo:
   alcance 3 m sin Permanencia = avanza 3 casillas (o menos si choca) y desaparece. Los proyectiles y los volúmenes
   que viajan usan la misma regla.
4. **Permanencia** es lo que hace que un hechizo se quede en un sitio: defensas, protecciones, piezas para puzles.
5. **Gravedad ajustable** con un modificador por estado de la materia. Los líquidos caen, pero menos. Valores
   provisionales, a ajustar en el lab.
6. **Nada escondido en constantes.** Todo lo que cambia cómo se comporta un hechizo es un campo de `Hechizo` con su
   valor por defecto. Las constantes que quedan en `HechizoVivo` son técnicas (topes de seguridad, holguras de choque).

## 1. Campos

Columnas: **campo** (nombre en el código) · **unidad** · **base** (sin elemento ni glifos) · **quién lo cambia** ·
**hoy**. En «hoy»: = igual · ≠ cambia · + nuevo · ← sale de una constante de `HechizoVivo`.

### 1.1 Geometría

| campo | unidad | base | quién lo cambia | hoy |
|---|---|---|---|---|
| `semieje_x` (ancho) | m | **0,10** (radio; 24/10, decisión de Pablo: antes 0,25 y 0,15) | ᛁ horizontal: **+0,25/glifo** (`PASO_ANCHO_V2`), tope 3,0 (ᛜ + 4 ᛁ = semieje 1,10 = muro de 3 casillas) | ≠ base 0,15 → 0,25 → 0,10 · paso 0,15 → 0,10 → 0,25 |
| `semieje_z` (fondo) | m | 0,10 | ᛁ vertical: +0,10/glifo (`PASO_FONDO_V2`), tope 3,0 | ≠ base |
| `semieje_y` (alto) | m | 0,10 | ᛏ: **+0,30/glifo** (`PASO_ALTURA_V2`), tope 1,0 (2 niveles con **3 glifos**: 0,10 + 3·0,30 = 1,0; 1 ᛏ = 0,40 y 2 ᛏ = 0,70 siguen en 1 nivel) | ≠ base y tope 2,0 → 1,0 · paso 0,15 → 0,10 → 0,30 |
| `grosor_min` | m | 0,10 (= la base; 24/10: antes 0,15) | — | + (ningún semieje baja de aquí: un muro fino no desaparece) |
| `volumen`, `superficie`, `niveles` | m³, m², nº | derivados | — | `niveles` = ; los otros + |

**Decidido:** `radio`, `longitud` y `altura` de la tabla de Pablo son los tres semiejes con el radio como valor
inicial. Hay **dos** ejes horizontales (ancho X y fondo Z), así que «longitud» se parte en dos.

### 1.2 Movimiento

| campo | unidad | base | quién lo cambia | hoy |
|---|---|---|---|---|
| `velocidad` | m/s | 0 (quieto) | flecha: fija `VELOCIDAD_FLECHA` = **4 u/s de la escala antigua = 4 / `Terreno3D.casilla` ≈ 1,7 m/s** (decisión de Pablo: la misma velocidad que ayer) | ≠ solo la unidad; el valor en pantalla no cambia |
| `distancia_max` | m | 0 | flecha: 2 + 1 por glifo sucesivo, tope 6 | = (pasa a m, que es lo mismo) |
| `aceleracion` | m/s² | 0 | — (lab) | ≠ unidad |
| `gravedad` | factor | **1,0** | × estado (§2) | ≠ base 0 → 1; solo afecta a lo que se desplaza |
| `elevacion` | m | 0 | — (glifo futuro «flota») | + (hoy `altura_salida` 0,9 u solo para proyectiles) |
| `rebotes` | nº | 0 | rebote: +1, tope 3 | = |
| `retorna`, `busca`, `en_punto` | — | false / 0 / false | barrera: `en_punto` | = |

- **Un solo modelo de desplazamiento.** Hoy hay dos: el volumen que «viaja» por tandas a `VEL_VIAJA_V2` = 8
  casillas/s fijas, y el proyectil con `velocidad`. Pasan a ser uno: todo lo que tenga `distancia_max` > 0 se
  desplaza a `velocidad`.
- Si `distancia_max` > 0 y `velocidad` = 0, se usa una velocidad por defecto de **8 m/s**, la de hoy.
- Desaparecen `ALCANCE_DEFECTO_CAS` (12) y `VIDA_DEFECTO_S` (5): con la regla §0.3 ya no hacen falta, porque nada
  vuela para siempre si `distancia_max` tiene tope.
- **El choque acaba el viaje:** casilla sólida, barrera que bloquea (`solidez` > 0 de otro hechizo) o un golpe más
  allá de `perfora`. Con `rebotes` > 0, el choque contra el mundo gasta un rebote en lugar de parar.

### 1.3 Tiempo

| campo | unidad | base | quién lo cambia | hoy |
|---|---|---|---|---|
| `persiste` | s | 0 | elemento (§2) | ≠ significado: vida natural, **solo para lo que nace quieto** (§0.3) |
| `permanencia` | s | 0 | **Permanencia ᛉ**: +2 s/glifo · barrera: +1 s por glifo sucesivo (antes iba a `persiste`) | + (tiempo que se queda donde nace o donde para) |
| `retardo` | s | 0 | — (glifo retardo, aparcado) | + |
| `intervalo` | s | 0,25 | — | ← `TICK_ZONA_V2` |
| `crece` | m/s | 0 | pulso: +0,5, tope 1,5 | ≠ unidad: hoy «escala/s», pasa a m/s de radio |
| `escala_nace` | factor | 0,3 | — | ← `ESCALA_NACE_V2` |

- **`duracion_persistente` no es un campo:** es la vida total, que sale de la regla §0.3 (`persiste` + `permanencia`
  si nace quieto; tiempo de viaje + `permanencia` si viaja).
- **`tiempo_expansion`**, la `velocidad_expansion` y la `expansion_maxima` de Pablo salen de `crece` y los semiejes
  (tiempo = (semieje − semieje × `escala_nace`) / `crece`). Calcularlos evita que dos números tengan que cuadrar a
  mano.

### 1.4 Física y choque

| campo | unidad | base | quién lo cambia | hoy |
|---|---|---|---|---|
| `densidad` | unidad/m³ | 1,0 | estado (§2) | + |
| `masa` | unidad | derivado = densidad × volumen | — | + |
| `solidez` | factor | 0 | barrera: 1 × 1,5ⁿ, tope 3 | = (0 = no bloquea proyectiles) |
| `resistencia` | puntos | 10 | derivado = 10 × `solidez` × … | ← `AGUANTE_SOLIDEZ_V2` (30 por ×1) |
| `pisable` | bool | false | estado sólido + elemento | = |
| `elasticidad` | 0–1 | 0,2 | — | + (velocidad que conserva al rebotar) |
| `perfora` | nº | 0 | — | = |
| `choca_con` | máscara | mundo + enemigos | — | = |
| `golpea_lanzador` | bool | false | — | = |

- **Fuera de esta versión:** `friccion` (no hay nada que ruede).
- **`bloquea_movimiento`** = `pisable` o sólido con `solidez` > 0, así que no es un campo aparte.
- **`es_solido`** = `estado_materia == "solido"`.
- **`protector`** = barrera centrada en el jugador.

### 1.5 Potencia y elemento

| campo | unidad | base | quién lo cambia | hoy |
|---|---|---|---|---|
| `dano` | puntos | **1** | elemento | ≠ base 0 → 1 |
| `dano_periodico` | puntos/s | 0 | elemento (plasma) | ← `FRAC_DANO_ZONA_V2` (20 % del daño por pulso) |
| `potencia` | factor | 1 | — (amplificar, aparcado) | + |
| `intensidad_estado` | factor | 1 | — | + (× todas las duraciones de estado) |
| `temperatura` | −1…+1 | 0 | elemento | + |
| `humedad` | 0…1 | 0 | elemento | + |
| `conductividad` | 0…1 | 0 | elemento | + |
| `quema`, `moja`, `congela`, `congela_mojado`, `aturde`, `ralentiza`, `ralentiza_fuerza`, `interrumpe`, `veneno`, `veneno_dps` | s / factor | 0 | elemento (`.tres`) | = |
| `empuje`, `fuerza_golpe` | 0–1 / fuerza | 0 / 400 | elemento | = (en la fase de cálculo pasarán a salir de `masa` × `velocidad`) |
| `deja`, `estado_materia`, `etiquetas`, `color` | — | — | elemento | = |

- **Temperatura, humedad y conductividad** solo se rellenan en esta versión. En la fase de cálculo, las reacciones
  (vapor, congelar mojado, electrocutar mojado) saldrán de ellas en lugar de estar escritas en `Combate3D`.
- **`efectos [ ]`** de Pablo = los campos de estado de esta tabla + `eventos` (ya existen).

### 1.6 Propagación y copias

| campo | unidad | base | quién lo cambia | hoy |
|---|---|---|---|---|
| `copias` | nº | 1 | repetición: +1, tope 4 | = |
| `separacion` | m | 0,5 | — | + (hoy, el ancho de cada copia) |
| `dispersion` | grados | 15 | — | + (hoy no hay abanico) |

### 1.7 Estados de activación (derivados, nunca se fijan a mano)

| estado | se cumple si | glifo que lo activa |
|---|---|---|
| `viaja` | `distancia_max` > 0 | flecha |
| `flota` | `elevacion` > 0 | (futuro) |
| `anclado` | `permanencia` > 0 | Permanencia ᛉ / barrera |
| `protege` | `solidez` > 0 | barrera |
| `se_expande` | `crece` > 0 | pulso |
| `se_repite` | `copias` > 1 | repetición |
| `rebota` | `rebotes` > 0 | rebote |

### 1.8 Derivados del lanzamiento (ya existen)

`forma` (x_mano / alto / abajo) · `cast_point` · `niveles` · `coste` / `coste_tinta` · `recarga` · `calidad`.

### 1.9 Límites globales de seguridad

En `Hechizo`, aplicados al final de `construir()` y también a lo que se toque en el lab:

| límite | valor | nota |
|---|---|---|
| semieje x / z máximo | 3,0 m | ancho o fondo total de 6 m |
| semieje y máximo | 1,0 m | 2 niveles |
| `elevacion` máxima | 2 m | |
| altura total (`elevacion` + 2 × semieje_y) | 2 niveles | el sólido más alto no se lanza (aviso de hoy) |
| `distancia_max` máxima | 8 m | flecha llega a 6 con 5 glifos |
| `persiste` + `permanencia` máximo | 25 s | |
| `copias` máximas | 8 | el glifo topa en 4; el lab puede subir a 8 |
| glifos máximos por hechizo | 6 | **el mismo número que los huecos de la página del libro** |
| profundidad de hijos / vivos | 2 / 32 | = |

## 2. Lo que aporta cada elemento (`modificadores` de los `.tres`)

Valores de hoy marcados =; los demás son **propuesta inicial** para el lab.

| | fuego | agua | tierra | hielo | rayo | viento | tiempo |
|---|---|---|---|---|---|---|---|
| estado | plasma = | líquido = | sólido = | sólido = | energía = | gas = | campo = |
| dano | 50 = | 40 = | 0 (+18 al golpe) = | 20 = | 55 = | 0 = | 0 = |
| persiste | 3 = | 0 = | 8 = | 6 = | 0,2 = | 1,5 = | 4 = |
| gravedad × | 0 (sube) | **0,5** | 1 | 1 | 0 | 0 | 0 |
| densidad | 0,2 | 1 | 2 | 0,9 | 0 | 0,1 | 0 |
| temperatura | +1 | 0 | 0 | −1 | 0 | 0 | 0 |
| humedad | 0 | 1 | 0,2 | 0,5 | 0 | 0 | 0 |
| conductividad | 0 | 0,3 | 0 | 0 | 1 | 0 | 0 |

`persiste` del elemento solo cuenta para lo que nace quieto (§0.3). Una flecha de cualquier elemento desaparece al
acabar su recorrido salvo que lleve Permanencia ᛉ.

## 3. Glifos (lo de hoy + Permanencia)

| glifo | campos que toca |
|---|---|
| ᛁ horizontal | `semieje_x` +0,25 (tope 3,0) · **sin barrera ni flecha: RAYO (§3b)** |
| ᛁ vertical | `semieje_z` +0,10 (tope 3,0) · **sin barrera ni flecha: RAYO (§3b)** |
| ᛏ | `semieje_y` +0,30 (tope 1,0) |
| ᛇ flecha | `velocidad` = 4 m/s · `distancia_max` 2 + 1 por glifo sucesivo (tope 6) |
| ᛜ barrera | `solidez` 1 × 1,5ⁿ (tope 3) · `en_punto` · `permanencia` +1 s por glifo sucesivo |
| ᚠ repetición | `copias` +1 (tope 4) |
| ᚢ rebote | `rebotes` +1 (tope 3) |
| ᚷ pulso | `crece` +0,5 m/s (tope 1,5) |
| **ᛉ Permanencia** (nuevo; algiz, decidido 19/10) | `permanencia` +2 s por glifo (tope 25 con `persiste`) |

Retardo, atracción, espejo y amplificar siguen aparcados.

## 3b. ᛁ `linea` = RAYO (21/10, decisión de Pablo; el muro es solo de `barrera`)

El glifo `linea` **ya no es «muro delante»**. **El muro es solo de ᛁ-con-`barrera`** (`barrera` pone la `solidez`), y **`linea` + elemento = RAYO**: un **haz recto desde la mano hacia donde apunta**.
«Rayo» es también el elemento relámpago (ᛊ): en el código la forma se llama **`haz`** (`Hechizo.haz`, `Hechizo.figura() == "haz"`, `volumen["haz"]` en la señal `hechizo_v2`); el nombre visible
es «rayo de fuego», «rayo de hielo»…

**Cuándo hay haz** (`Hechizo.haz`, lo mismo que `Sigils.aplicar_v2(...)["haz"]`): se dibujó alguna ᛁ (`linea_x` o `linea_z`: da igual cuál, suman al mismo haz) **y** no hay `barrera` (solidez) **ni** `flecha`
(`distancia_max`). Con barrera es el muro de siempre (ᛁ le da ancho); con flecha es un proyectil alargado.

| campo / constante | valor | qué es |
|---|---|---|
| `Hechizo.HAZ_ALCANCE_BASE` | 3 m | alcance con una ᛁ |
| `Hechizo.HAZ_ALCANCE_POR_GLIFO` | +1 m | por cada ᛁ sucesiva |
| `Hechizo.HAZ_ALCANCE_MAX` | 6 m | tope (≤ `LIM_DISTANCIA`) |
| `Hechizo.HAZ_ANCHO` | 0,35 m | grosor del dibujo (el golpe cubre la casilla entera) |
| `Hechizo.HAZ_DURA_S` | 0,9 s | lo que se ve (+ `permanencia`) |
| `Hechizo.alcance_haz` | derivado | alcance en m (0 si no es haz) |

**Qué hace** (`HechizoVivo._materializar_haz`): es **instantáneo** y aplica el golpe del elemento a TODO el recorrido a la vez. Se **para** en casillas sólidas y en barreras (el mismo `trazar`
del desplazamiento, sin detenerse en enemigos: el haz **perfora**). Cada **casilla** del recorrido recibe el estado de suelo del elemento (`deja`: mojado, quemado, helado…; las alturas ≥ 1 lo
rechazan como siempre) y cada **enemigo y reactivo** de esas casillas, el golpe del elemento **una vez** (daño, estados, empuje del viento). La energía (rayo) usa la descarga de siempre
(recorre el agua y los conductores). **No deja** bloques, agua en la simulación ni zonas, y no bloquea proyectiles (eso es del muro). `copias`, `rebotes` y `crece` no cambian el haz. La forma de lanzar
es siempre `x_mano` (mano al frente).

**Dibujo por elemento** (`VfxElemento3D.haz` → una pieza por elemento): fuego `VfxKit3D.haz` (lanzallamas) · agua `VfxAgua.chorro` (haz translúcido del kit + gotas, salpicadura y charco) ·
tierra `VfxTierra.fila_pinchos` (pinchos `pincho_tierra_*` que brotan en secuencia) · viento `VfxViento.corriente` (cintas rectas con hojas) · rayo `VfxRayo.descarga` (descarga quebrada que cambia
de trazado a saltos) · hielo `VfxHielo.rayo` (haz de cristal con esquirlas y escarcha). Prueba: `herramientas/prueba_haz.gd`; capturas: `herramientas/captura_haz.gd` → `docs/capturas/haz/`.

## 4. Ajustes para implementar

### Juego · E1: unidad y nombres
```
Contexto Juego. Lee docs/ESPEC_HECHIZO.md (proyecto) entero y las entradas 166–182 de docs/DIARIO.md. Comprueba qué máquina está enlazada y que tiene la última versión antes de escribir.
1. nucleo/hechizo.gd: TODOS los campos de longitud en metros-casilla (1 casilla = 1 m) y las velocidades en m/s.
   - velocidad, aceleracion y altura_salida pasan de u a m;
   - la conversión (× Terreno3D.casilla) se hace solo en HechizoVivo;
   - Sigils.VELOCIDAD_FLECHA_U pasa a VELOCIDAD_FLECHA = 4.0 / Terreno3D.casilla m/s (≈ 1,7): la MISMA velocidad que hoy en pantalla (decisión de Pablo). Como depende de casilla, que sea una función o se calcule al construir, no una const;
   - campo nuevo `permanencia` (s, base 0); el modificador «+1 s por glifo sucesivo» de la barrera pasa de persiste a permanencia.
2. Campos nuevos de §1 con sus bases: grosor_min, elevacion, retardo, intervalo, escala_nace, densidad, elasticidad, dano_periodico, potencia, intensidad_estado, temperatura, humedad, conductividad, separacion, dispersion.
   Bases que cambian: semiejes 0,10 (Sigils.RADIO_BASE_V2; 0,25 del 19 al 24/10), gravedad 1, dano 1. El agua de un hechizo líquido NO sale del volumen a secas: `Sigils.volumen_agua_v2` = `VOLUMEN_AGUA_BASE_V2` (la esfera de radio 0,25) × volumen / volumen de la esfera base, para que una esfera sin glifos eche lo de siempre. Copias: separación de centro a centro ≥ `HechizoVivo.SEPARACION_COPIAS_MIN_CASILLAS` (1 casilla).
   Derivados: volumen, superficie, masa, resistencia, y los estados de §1.7 (viaja, flota, anclado, protege, se_expande, se_repite, rebota) como funciones de solo lectura.
3. Límites de §1.9 aplicados al final de construir() y de con() (el lab tampoco puede saltárselos).
4. Los .tres reciben los modificadores de §2 (gravedad, densidad, temperatura, humedad, conductividad); los valores marcados «=» no cambian.
5. Hechizo.EDITABLES y la tabla de F1 del lab incluyen los campos nuevos.
Prueba: prueba_hechizo actualizada (bases nuevas, derivados, límites; que construir() no supera ningún límite en las 495 × 7 combinaciones). Las pruebas que dependan del radio base 0,15 se ajustan con cifras derivadas de RADIO_BASE_V2, no fijas. Diario. Sin commit.
```

### Juego · E2: regla de vida y un solo desplazamiento
```
Contexto Juego. Requiere E1. Lee docs/ESPEC_HECHIZO.md §0.3, §1.2 y §1.3.
En magia/hechizo_vivo.gd:
- un solo modelo de desplazamiento: todo lo que tiene distancia_max > 0 se desplaza a velocidad (8 m/s si velocidad = 0); se acaban las tandas de VEL_VIAJA_V2;
- regla de vida (§0.3), que sustituye a «lo que llegue antes» de la 182:
  · si viaja: nace → (retardo) → crece → recorre distancia_max o SE PARA al chocar (sólido, barrera que bloquea, golpe más allá de perfora; con rebotes, el choque con el mundo gasta un rebote) → se queda `permanencia` s → desaparece. Con permanencia 0 desaparece al llegar o chocar; la `persiste` del elemento NO cuenta;
  · si no viaja: nace y vive persiste + permanencia;
- gravedad × el factor de su estado, solo mientras se desplaza;
- elevacion: el volumen o proyectil nace a esa altura sobre el suelo;
- intervalo, escala_nace, dano_periodico y resistencia salen del Hechizo, no de las constantes: retira TICK_ZONA_V2, ESCALA_NACE_V2, FRAC_DANO_ZONA_V2, AGUANTE_SOLIDEZ_V2, VEL_VIAJA_V2, ALCANCE_DEFECTO_CAS y VIDA_DEFECTO_S, o déjalos solo como valor por defecto en Hechizo;
- copias separadas `separacion` m y abiertas `dispersion` grados.
La señal hechizo_v2 sigue con los mismos campos (más elevacion, separacion y dispersion para el VFX).
Pruebas: prueba_hechizo_vivo y prueba_materia_v2 con la regla nueva:
- flecha de fuego alcance 3 sin Permanencia = avanza 3 y desaparece (aunque el fuego tenga persiste 3);
- con una pared a 2 casillas = se para a 2 y desaparece;
- con Permanencia ×1 = avanza 3 y se queda 2 s;
- muro de tierra quieto = 8 s; con Permanencia ×1 = 10 s.
Regresión de escenarios a 0, ajustando lo que asumía la regla vieja y anotándolo. Diario. Sin commit.
```

### Juego · E3: glifo Permanencia ᛉ
```
Contexto Juego. Lee docs/ESPEC_HECHIZO.md §3. Runa decidida por Pablo: ᛉ algiz (en GestureLibrary.BIBLIA hoy es «algiz», libre: pasa a uso «sello» y nombre «permanencia»).
- Sigils.GLIFOS["permanencia"] = {permanencia +2 s por glifo, tope 25 contando persiste};
- alta en GestureLibrary (SIGILS y RECORDABLE) y en Repertoire;
- PNG en Sigils.GLYPHS (pídelo al Pipeline por el diario si no existe).
Prueba en prueba_hechizo. Pablo graba las muestras con G. Diario. Sin commit.
```

### Pipeline · P-E1: VFX y lab con la especificación
```
Contexto Pipeline. Lee docs/ESPEC_HECHIZO.md y las entradas del Juego E1/E2 en el diario.
- VfxEstado3D: el volumen nace a `elevacion` sobre el suelo; las copias se colocan con `separacion` y `dispersion` (llegan en la señal); el volumen que viaja ahora va a `velocidad` (no a 8 casillas/s fijas), se para donde choca y DESAPARECE al llegar o chocar, salvo que traiga `permanencia` > 0, que es lo que se queda en el sitio (regla nueva §0.3: la `persiste` del elemento solo cuenta para lo que nace quieto); la caída de un hechizo con gravedad < 1 (líquido ×0,5) se dibuja más lenta.
- La señal hechizo_v2 llevará `permanencia` (y la vida total): úsala en lugar de persiste para lo que viaja.
- La esfera base pasó de 0,3 a 0,5 m de diámetro (semieje 0,25) y el 24/10 baja a 0,2 m (semieje 0,10): revisa que los VFX que escalaban con el volumen no queden pequeños o enormes.
- La interfaz compacta del lab (entradas 173–181) enseña los campos nuevos que difieran de su base, en la lista de variables ≠ 0.
- PNG del glifo ᛉ algiz (Permanencia) para el libro (art/ui/glyphs/permanencia.png), con el mismo estilo que los de la lámina de runas, cuando el Juego lo pida (E3).
prueba_vfx_v2 a 0 y una captura del lab con una flecha que viaja y persiste. Diario. Sin commit.
```

## 5. Decisiones de Pablo (19/10)

1. **Permanencia = ᛉ algiz.** Hecho.
2. **Velocidad de la flecha:** la de ayer, 4 u/s de la escala antigua ≈ 1,7 m/s. Hecho.
3. **Lo que viaja desaparece al acabar** (o al chocar) salvo que lleve Permanencia; la vida natural del elemento solo
   cuenta para lo que nace quieto. Hecho (§0.3).
4. **Pendiente:** los valores propuestos de §2 (gravedad por estado, densidad, temperatura, humedad, conductividad) se
   toman como punto de partida y se ajustan en el lab.

— Juego
