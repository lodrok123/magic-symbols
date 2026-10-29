# Prompt resumen: especificación de los hechizos (29/10/2026)

> Texto autocontenido para pegar a otra IA (o para leerlo Pablo) y repasar la especificación vigente de los hechizos.
> Fuentes: `docs/ESPEC_HECHIZO.md` (v1.1), `docs/GLIFOS_RECETA.md`, `docs/HECHIZO_CLASE.md`, `docs/DANO_Y_TINTA.md`,
> contrastadas con el código: `nucleo/sigils.gd` (`GLIFOS`, `GLIFOS_V2`), `nucleo/hechizo.gd` (`Hechizo`, `construir`),
> `nucleo/dano.gd` (`Dano`), los siete `nucleo/*_rune.tres` y, puntualmente, `magia/lanzador_3d.gd` (rechazos y capacidad del libro).
> **Cuando doc y código discrepan, manda el código**; las discrepancias están listadas en §3.

---

## 1. Para quien lo reciba

Eres un diseñador de sistemas que revisa la especificación de hechizos de un juego de Godot (todo en español) en el que el
jugador dibuja un **elemento** y unos **glifos** (runas) en una página de un libro y el juego construye un hechizo a partir
de esa receta. Tu trabajo: **revisa esta especificación, señala incoherencias, huecos, casos límite y reglas que choquen
entre sí, y propone actualizaciones concretas** (qué número o regla cambiar y por qué). Trata §2 como la verdad actual
(es lo que hace el código) y §3 como la lista de puntos donde los documentos se han quedado atrás. **Pregunta antes de
inventar**: si algo no está definido aquí, dilo y pregunta a Pablo (el diseñador) en lugar de suponer un comportamiento.
Mantén los nombres del código (ids en español) y la unidad 1 casilla = 1 m.

---

## 2. Especificación vigente (resumen)

### 2.1 Qué es un hechizo

```
elemento (RuneData .tres)  +  glifos (multiconjunto: id -> nº de veces)  +  calidad del trazo
        └──────────── Hechizo.construir(elemento, glifos, calidad) ────────────┘
                                    │  Hechizo (RefCounted, datos puros)
                                    ▼
                         HechizoVivo (Node3D): lo ejecuta en el mundo
```

- **Receta = VOLUMEN (glifos de eje) × PROPIEDADES (glifos aditivos) × ELEMENTO (estado de la materia + etiquetas).**
  Las tres partes no se conocen: ninguna regla pregunta «¿hay rebote y repetición?». Las combinaciones **salen solas**;
  se aceptan combinaciones débiles o raras sin corregirlas a mano.
- **El orden de dibujo no existe** (multiconjunto). Los glifos se aplican en el orden de la tabla `Sigils.GLIFOS`.
- `Hechizo.construir` en orden fijo:
  1. defectos (los `var` de `Hechizo`, más la capa «Bases» del lab, vacía en el juego);
  2. elemento: los campos de `RuneData` (`damage`, `persiste`, `empuje`, `pisable`, `deja`, `estado`) como «fija», y
     después `RuneData.modificadores` del `.tres`;
  3. glifos: `fija` → `suma` → `multiplica`; luego topes de cada modificador; al final `minimo`;
  4. daño por potencia (fuego/agua/tierra/viento sobrescriben `dano` con B × E, §2.9);
  5. la calidad multiplica **solo** `persiste` y `permanencia` (factor `lerp(0,6; 1,0; calidad)`);
  6. límites globales (`_limitar`, §2.4) y derivados (`_derivar`: forma, niveles, cast point, coste, tinta, recarga, en_punto).
- **Modificador** = `{campo, op, valor, tope?, salta?, desde?}`. `op` ∈ suma (v + valor·n) · multiplica (v·valorⁿ) · fija ·
  minimo · anade (eventos). `salta k`: los k primeros glifos no cuentan. `desde`: valor de partida si nadie tocó el campo.
  Valores simbólicos: `@velocidad_flecha`, `@radio_barrera`. **Un glifo o elemento nuevo es solo datos.**
- `Sigils.GLIFOS_V2` es la misma tabla en el formato antiguo (lab, UI de ejes, pruebas); `prueba_hechizo` comprueba que
  coinciden. `Sigils.ALIAS_V2`: `levitacion` → `altura`.

### 2.2 Elementos y estado de la materia

El **estado** decide qué ES el volumen (una vez por estado, no por forma):

| estado | qué hace el volumen |
|---|---|
| sólido | cuerpo con colisión en sus casillas; bloquea; pisable si `pisable` y cabe en los niveles subibles; se rompe o se derrite (`persiste`) |
| líquido | mete agua en `AguaSim3D` (`Sigils.volumen_agua_v2` = agua de la esfera de radio 0,25 × volumen / volumen base); luego, la simulación |
| plasma | zona de daño (`dano_periodico` cada `intervalo`) durante `persiste`; deja `quemado` |
| energía | descarga instantánea que conduce por agua y conductores |
| gas | campo de fuerza (empuje) durante `persiste` |
| campo | ralentiza lo que está dentro (solo el tiempo, que es **cinemático**: el jugador no lo lanza) |

Valores de los `.tres` (código):

| | fuego | agua | tierra | hielo | rayo | viento | tiempo |
|---|---|---|---|---|---|---|---|
| estado | plasma | líquido | sólido | sólido | energía | gas | campo (cinemático) |
| `damage` del .tres | 50 (se sobrescribe) | 40 (se sobrescribe) | 0 | **20 (se usa)** | **55 (se usa)** | 0 | 0 |
| persiste (s) | 3 | 0 | 8 | 6 | 0,2 | 1,5 | 4 |
| empuje (0–1) | 0,2 | 0,5 | 0,8 | 0,2 | 0,2 | 1,0 | 0 |
| pisable / deja | — / quemado | — / mojado | sí / — | sí / helado | — | — | — |
| estado que aplica | quema 3 s | moja 6 s | ralentiza 3 s (fuerza 0,4) | congela 1,5 s (2,5 si mojado) | aturde 1,2 s | interrumpe 0,7 s | — |
| fuerza_golpe | 500 | 600 | 2200 | 300 | 400 | 0 (lo empuja el Lanzador) | 400 (defecto) |
| gravedad × | 0 | 0,5 | 1 | 1 | 0 | 0 | 0 |
| impulso_salida (m/s) | 0 | 1,6 | 2,5 | 2,5 | 0 | 0 | 0 |
| densidad | 0,2 | 1 | 2 | 0,9 | 0 | 0,1 | 0 |
| temperatura / humedad / conductividad | +1 / 0 / 0 | 0 / 1 / 0,3 | 0 / 0,2 / 0 | −1 / 0,5 / 0 | 0 / 0 / 1 | 0 / 0 / 0 | 0 / 0 / 0 |
| otros | `dano_periodico` 40 pts/s | | | | `beam` | | |

Temperatura, humedad, conductividad, `elasticidad` e `intensidad_estado` **solo se rellenan**: aún no los lee nadie
(las reacciones siguen escritas en `Combate3D`).

### 2.3 El volumen: elipsoide

- Sin glifos: **esfera de semieje `RADIO_BASE_V2` = 0,10 m** (0,2 m de diámetro). Cada glifo de eje suma a un semieje.
  Orientado a la mirada: X = de lado (ancho), Y = arriba (alto), Z = hacia delante (fondo).
- Se rasteriza sobre casillas: cuenta una casilla si su centro cae dentro del elipsoide, y siempre la del origen.
- Ningún semieje baja de `grosor_min` = 0,10. Derivados: `volumen`, `superficie`, `masa` = densidad × volumen,
  `niveles` = máx(1, round(2 × semieje_y)).
- En vuelo, un proyectil (`velocidad` > 0) se ve y choca a `ESCALA_PROYECTIL` = 0,5 de sus semiejes.

| eje | glifo | paso por glifo | tope (semieje) | valores con n glifos |
|---|---|---|---|---|
| X ancho | ᛁ dibujada horizontal (`linea_x`) | +0,5 (`PASO_ANCHO_V2`; 29/10, antes 0,25) | 3,0 (`TOPE_EJE_HORIZONTAL_V2`) | 1: 0,60 (1 casilla) · **2: 1,10 (3 casillas)** · 4: 2,10 (5 casillas) · 6: tope 3,0 |
| Z fondo | ᛁ dibujada vertical (`linea_z`) | +0,5 (`PASO_FONDO_V2`; 29/10, antes 0,10) | 3,0 | igual que el ancho: 2 glifos = 3 casillas, 6 = tope |
| Y alto | ᛏ (`altura`; alias `levitacion`) | +0,30 (`PASO_ALTURA_V2`) | 1,0 (`TOPE_EJE_ALTURA_V2`) | 1: 0,40 · 2: 0,70 (1 nivel) · **3: 1,00 (2 niveles)** |

Orientación de la raya ᛁ: respecto a la página; más horizontal → X, más vertical → Z, diagonal exacta → X.

**Forma derivada** (para animación, cast point y VFX; `Hechizo.nombre_derivado`): viaja o Z dominante → `x_mano`;
Y dominante → `alto`; plano y quieto → `abajo`; esfera → `x_mano`. Un haz siempre `x_mano`. **29/10:** con tierra o hielo, ᛁ ya NO hace haz: es un sólido quieto ancho o largo que nace donde apuntas (la pose de la mano sigue siendo `x_mano`). Sus bloques siguen el perfil del elipsoide (los del borde, más estrechos y algo más bajos; solo el dibujo). Y el pulso ᚱ de un proyectil que choca sale de la superficie que tocó (pared, objeto, enemigo o suelo) más la casilla de delante.
**Figura del VFX** (`Hechizo.figura`): haz · barrera (solidez) · proyectil (viaja) · pulso (crece) · esfera.

### 2.4 Límites globales (`Hechizo._limitar`, también para el lab)

| límite | valor |
|---|---|
| semieje X / Z | 3,0 m |
| semieje Y | 1,0 m (2 niveles) |
| `elevacion` | 2 m |
| `distancia_max` | 8 m |
| `persiste` + `permanencia` | **25 s** (primero persiste; la permanencia se queda con el resto) |
| `copias` | 1–8 (el glifo topa en 4) |
| glifos por hechizo | `MAX_GLIFOS` = 6 (lo aplican el libro y el lab; `construir()` no cuenta) |
| hijos / vivos por lanzamiento | profundidad 2 / 32 |

### 2.5 Glifos (código: `Sigils.GLIFOS`)

| runa | id interno | nombre visible | campos que toca (por glifo, tope) | momento | paso | recarga |
|---|---|---|---|---|---|---|
| ᛁ | `linea_x` | linea | semieje_x +0,5 (3,0) | inicio | 1 | 2,0 |
| ᛁ | `linea_z` | linea | semieje_z +0,5 (3,0) | inicio | 1 | 2,0 |
| ᛏ | `altura` (`levitacion`) | altura | semieje_y +0,30 (1,0) | inicio | 1 | 2,0 |
| ᛇ | `flecha` | flecha | `velocidad` fija = 4 u/s ÷ casilla ≈ **1,7 m/s**; `distancia_max` desde 1, +1/glifo (tope 6) → 2, 3, 4, 5, 6 m; `impulso_salida` +0,7 m/s por glifo sucesivo (salta 1) | continuo | 3 | 1,0 |
| ᛜ | `barrera` | barrera | `solidez` desde 1, ×1,5/glifo (tope 3) → 1,5 · 2,25 · 3; `en_punto` = true; `permanencia` +1 s por glifo sucesivo | continuo | 4 | 3,0 |
| ᚠ | `repeticion` | repeticion | `copias` desde 1, +1 (tope 4) | inicio | 2 | 1,5 |
| ᚢ | `rebote` | rebote | `rebotes` +1 (tope 3) | final | 3 | 1,5 |
| ᚷ | `pulso` | **crecer** | `crece` +0,5 m/s (tope 1,5) | continuo | 3 | 2,5 |
| ᛉ | `permanencia` | permanencia | `permanencia` +2 s (tope 25) | final | 3 | 1,5 |
| ᚱ | `raido` | **pulso** | `resuena` +4 casillas (tope 12); acción `emitir_pulso` | inicio; **final si viaja; continuo si persistente** | 5 | 2,0 |

- **Aparcados** (se dibujan, avisan «Aún sin uso», no cuentan para nada): retardo, atracción, espejo, amplificar.
  Propuestas de glifos futuros (no asignados): ᚦ perfora, ᚨ marca, ᛃ vuelve/retorno, ᛞ destello, ᛈ oculto.
- **Nombre visible vs id** (`Sigils.NOMBRE_VISIBLE` / `nombre_visible()`): el id es el de las muestras grabadas, el PNG y
  las tablas, y no se renombra. Solo dos cambian al mostrarse: `pulso` → «crecer» y `raido` → «pulso».
- **Recarga** de la página (`Sigils.cooldown_v2`): la mayor de sus glifos + 0,5 s (`STACK_COOLDOWN`) por cada repetición
  del mismo glifo.

### 2.6 Momento de ejecución

| clave | qué es |
|---|---|
| `momento` | `inicio` (al nacer, una vez) · `continuo` (mientras vive) · `final` (al chocar o acabarse, una vez); sin él, `inicio` |
| `momento_si` | reglas `{cuando, es}`; `cuando` ∈ `viaja` (es proyectil) · `persistente` (no es haz, no viaja y tiene solidez, permanencia o es sólido) |
| `paso` | ordena dentro de un momento: 1 volumen · 2 copias · 3 vida · 4 materia · 5 daño y efectos (a igualdad, el orden de la tabla) |
| `accion` | del catálogo cerrado `Hechizo.ACCIONES` (hoy `emitir_pulso`). Sin acción, el momento es descriptivo |

- Continuo: primer disparo al nacer, luego cada máx(`intervalo`, 1,5 s `PERIODO_MIN_CONTINUO_S`), tope 8 disparos.
- Sin reentradas: un efecto de un momento no vuelve a disparar ese momento; un hijo no repite los efectos del padre.
- Ejemplos: ᚱ solo = pulso donde nace; ᛇ + ᚱ = pulso donde choca; ᛜ + ᚱ = el muro late.

### 2.7 Haz («rayo» como forma)

Hay **haz** si se dibujó alguna ᛁ (`linea_x` o `linea_z`, suman igual) **y** no hay barrera (`solidez`) **ni** flecha
(`distancia_max`), con `Sigils.HAZ_ACTIVO` = true (interruptor de pruebas). Con barrera, ᛁ es el ancho del muro; con flecha,
un proyectil alargado. «Rayo» es también el elemento relámpago ᛊ: en el código la forma se llama `haz`; nombre visible
«rayo de fuego», «rayo de hielo»…

| constante | valor |
|---|---|
| `HAZ_ALCANCE_BASE` / `_POR_GLIFO` / `_MAX` | 3 m con una ᛁ, +1 m por ᛁ sucesiva, tope 6 m |
| `HAZ_ANCHO` | 0,35 m de dibujo (el golpe cubre la casilla) |
| `HAZ_DURA_S` | 0,9 s visible (+ `permanencia`) |

Instantáneo: golpea **todo el recorrido a la vez**, una vez por enemigo/reactivo, perfora enemigos, se para en sólidos y
barreras, deja el estado de suelo del elemento en cada casilla. No deja bloques, agua ni zonas, ni bloquea proyectiles.
`copias`, `rebotes` y `crece` no lo cambian.

### 2.8 Movimiento, vida y colocación

- Un solo modelo: todo lo que tiene `distancia_max` > 0 viaja a `velocidad` (8 m/s si es 0, `VELOCIDAD_VIAJE_DEFECTO`).
  Gravedad = 1 × el factor del elemento, solo mientras se desplaza; un proyectil con gravedad sale con `impulso_salida`
  hacia arriba (arco) desde `altura_salida` (0,9 u ≈ 0,39 m).
- **Regla de vida** (§0.3 de la ESPEC):
  - `persiste` = vida natural del elemento, **solo para lo que nace quieto** (muro de tierra 8 s, zona de fuego 3 s).
  - `permanencia` = tiempo extra que se queda donde nace o donde se para; solo la dan ᛉ (+2 s) y la barrera (+1 s por glifo sucesivo).
  - Si viaja: recorre `distancia_max`, se para antes si choca (sólido, barrera, golpe más allá de `perfora`; con rebotes
    el choque con el mundo gasta un rebote), se queda `permanencia` s y desaparece (con 0, al llegar o chocar).
  - Si no viaja: vive `persiste` + `permanencia` (tope 25 s).
  - Regla de impacto (diario 191): un proyectil al pararse deja su materia una vez en el sitio. La flecha de **tierra** ya
    no levanta bloque sin ᛉ o ᛜ.
- **Rebotes**: +1 por ᚢ, tope 3 (lab hasta 6). `elasticidad` 0,2 existe pero no se usa.
- **Copias**: ᚠ +1, tope 4; `separacion` 0,5 m y `dispersion` 15° (campos); separación mínima de centro a centro 1 casilla.
- **en_punto** (nace donde apuntas, dentro del anillo de alcance): lo pone la barrera y, por regla
  (`SOLIDO_QUIETO_EN_PUNTO`), **todo sólido quieto** (tierra/hielo que ni es haz ni viaja). Si ahí no cabe (agua, casilla
  ocupada, cornisa, encima de la jugadora o de un enemigo, fuera de alcance, demasiada altura) el Lanzador avisa «Ahí no se
  puede construir: …» **antes** de cobrar tinta y recarga.
- **Rechazo por altura**: un **sólido** cuyos `niveles` superan `Jugador3D.MAX_NIVELES_SUBIBLES` (= **1**) no se lanza
  («Demasiada altura: sube N niveles y solo se pueden pisar 1. No se lanza.»), sea pisable o no. Los demás estados no
  tienen tope de altura.
- **Barrera**: `resistencia` = 30 × `solidez` (45 · 67,5 · 90). Bloquea proyectiles. Sola rodea al jugador
  (`RADIO_BARRERA_U` 1,3 u).
- **Crecer** (ᚷ): nace a `escala_nace` = 0,3 de su tamaño y crece `crece` m/s de radio.
- **Pulso resonante** (ᚱ): suelta un `Pulso3D` de `resuena` casillas (4/8/12) que recorre los conductores con el elemento
  de la receta, en el momento resuelto (§2.6).

### 2.9 Daño y tinta (`nucleo/dano.gd`, 29/10)

**Potencia = nº de glifos conocidos de la receta** (repeticiones incluidas; el elemento y los aparcados no cuentan):
0–1 ligera · 2–3 media · ≥ 4 alta.

| potencia | B (daño base) | T_base (tinta) | B×E fuego (×1,10) | agua / viento (×0,80) | tierra (×1,15) |
|---|---|---|---|---|---|
| ligera | 12 | 8 | 13,2 | 9,6 | 13,8 |
| media | 24 | 18 | 26,4 | 19,2 | 27,6 |
| alta | 40 | 34 | 44 | 32 | 46 |

```
D       = (B × E × G × X + suma_X) × R
D_final = máx(0,2 · D, D − DEF)          (un D ≤ 0 se queda en 0)
T       = T_base(potencia) × (1 + Σ recargos)
```

- **G** = `Hechizo.potencia` = 1,0 (ningún glifo lo toca; gancho para amplificar). **X**: rayo sobre mojado ×1,5;
  **suma_X**: hielo sobre mojado +15. **R**: débil ×1,5 · resiste ×0,75 · gólem de pie 0 · núcleo expuesto ×1,5.
- **Hielo y rayo, aparcados**: conservan su daño del `.tres` (20 / 55) sin tabla, pero pasan por R y DEF.
  Propuesta anotada: rayo ×1,00, hielo ×0,90.
- **Daño continuo** (quemadura 3 por tic de 0,5 s, veneno, pulsos de zona) pasa por R, no por DEF.
- **DEF**: goblin 2 · con escudo 5 · limo 0 · chamán 0 · elemental 6 · gólem 10. Vidas a la mitad (goblin 50, limo 30,
  chamán 30, gólem 70, elemental 500, Gatopedro 45).
- **Pigmento de daño** ×1,5 sobre B × E antes de G, X, R y DEF. El daño **no depende de la calidad**.
- **Recargo de tinta**: solo el continuo de ᚱ, +25 % (`COSTE_CONTINUO_V2`) si la receta lleva ᚱ, no viaja y tiene barrera
  o permanencia. La rebaja del pigmento (regla del 1/3) va encima. Barra de 100, +20 por reacción.
- `coste` (∝ volumen × (1 + 0,25 × nº de propiedades)) ya **no cobra**: es solo una medida de tamaño para lab y pruebas.

### 2.10 Capacidad del primer libro

- El primer libro admite **4 elementos y 6 glifos** distintos en su página derecha (`Lanzador3D.CAPACIDAD_PRIMER_LIBRO`
  = [4, 6], `Repertoire.max_elementos` / `max_glifos`); se empieza con menos y se llena jugando. Un libro posterior
  traerá más.
- Por página, cada nivel fija `glifos_por_pagina` (hoy 2 en nivel 1, bosque y gruta; 4 en otro perfil) y el círculo
  conserva sus 3 huecos (decisión del 27/10). Aparte, `Hechizo.MAX_GLIFOS` = 6 glifos por hechizo.

---

## 3. Discrepancias detectadas (doc ↔ código; manda el código)

| # | tema | documento dice | código dice |
|---|---|---|---|
| 1 | Velocidad de la flecha | `ESPEC_HECHIZO.md` §3: «`velocidad` = 4 m/s» (en §1.2 y la cabecera sí dice ≈ 1,7 m/s) | `Sigils.velocidad_flecha()` = 4 u/s ÷ `Terreno3D.casilla` ≈ 1,7 m/s |
| 2 | Alcance de la flecha | `GLIFOS_RECETA.md` §2.2: `viaja` +3 por glifo, tope 6 | `GLIFOS["flecha"]`: `distancia_max` desde 1, +1/glifo, tope 6 → 2, 3…6 m (ESPEC coincide) |
| 3 | Pilar de 2 niveles | `GLIFOS_RECETA.md` §2.4: «ᛏᛏ + hielo = pilar de 2 niveles que se puede escalar»; ESPEC §1.1: 3 ᛏ = 2 niveles | 2 ᛏ = semieje 0,70 → 1 nivel; 3 ᛏ = 2 niveles, pero `aviso_materia` / `puede_construir_en` **rechazan todo sólido de más de `MAX_NIVELES_SUBIBLES` = 1 nivel**: ningún pilar de tierra o hielo de 2 niveles se puede lanzar |
| 4 | Daño base y por elemento | `ESPEC_HECHIZO.md` §1.5/§2: `dano` base 1 y fuego 50, agua 40, tierra 0 (+18 al golpe); `HECHIZO_CLASE.md`: «daño base × calidad» | `construir` sobrescribe `dano` con B × E (fuego/agua/tierra/viento); la tierra ya no suma +18; hielo 20 y rayo 55 se mantienen; la calidad no toca el daño |
| 5 | Coste en tinta | `GLIFOS_RECETA.md` §2.5 y `HECHIZO_CLASE.md`: coste ∝ volumen y propiedades | `Dano.tinta`: T_base por potencia × (1 + recargos); `coste` ya no cobra (`DANO_Y_TINTA.md` coincide con el código) |
| 6 | Resistencia de la barrera | `ESPEC_HECHIZO.md` §1.4: base 10 por solidez | `Hechizo.RESISTENCIA_POR_SOLIDEZ` = 30 (el comentario reconoce la diferencia) |
| 7 | Unidades mezcladas | `ESPEC_HECHIZO.md` §0.1: «hoy `velocidad`, `aceleracion`, `altura_salida` van en u» | ya en m y m/s (`altura_salida` = 0,9 u ÷ casilla); nota obsoleta |
| 8 | Unidad de `crece` | `GLIFOS_RECETA.md` §2.2 y `HECHIZO_CLASE.md`: escala/s | m/s de radio (ESPEC §1.3 y `Hechizo.crece`) |
| 9 | Defectos de forma | `HECHIZO_CLASE.md` §2.2: `solidez` defecto 1, `semiejes` (r,r,r), `velocidad` en u/s, `persiste` campo de movimiento sin `permanencia` | `solidez` 0; semiejes 0,10; m/s; existe `permanencia` separada |
| 10 | Nombre de ᚷ | `ESPEC_HECHIZO.md` §3 y §1.7, `HECHIZO_CLASE.md`: «pulso» = `crece` | `NOMBRE_VISIBLE`: `pulso` se muestra «crecer»; «pulso» es ahora ᚱ `raido` (resuena) |
| 11 | ᛉ | `GLIFOS_RECETA.md` §2.2: ᛉ propuesto como `guarda` | ᛉ algiz = `permanencia` (decidido 19/10) |
| 12 | Abanico de copias | `GLIFOS_RECETA.md` §2.4: «ᚠᚠ + ᛇ + hielo = tres bolas en abanico» | `dispersion` 15° existe como campo, pero el comentario de `hechizo.gd` dice «hoy no hay abanico» |
| 13 | Recargo continuo (comentario) | `sigils.gd` comentario de `COSTE_CONTINUO_V2`: se suma a `COSTE_PROP_V2` por cada glifo con acción continua | `recargo_continuo`: un único ×1,25 según las props (ᚱ + no viaja + barrera o permanencia), no por glifo |
| 14 | Comentario de ejes | `sigils.gd` línea 348: «cada glifo suma LO MISMO que el radio base» | pasos distintos por eje (0,25 / 0,10 / 0,30) |
| 15 | Glifos máximos | `ESPEC_HECHIZO.md` §1.9: 6 glifos por hechizo = «huecos de la página del libro» | `MAX_GLIFOS` = 6, pero las páginas de los niveles tienen `glifos_por_pagina` 2 (o 4) y el círculo 3 huecos; el «6» del libro es de glifos **distintos conocidos** (`Repertoire.max_glifos`), otro concepto |
| 16 | Tiempo como elemento | `ESPEC_HECHIZO.md` §2 y `GLIFOS_RECETA.md` §2.3 lo tratan como un elemento más | `time_rune.tres` es `cinematico`: `construir` devuelve null salvo con `permitir_cinematico` |
| 17 | PNG de ᛏ | — | `Sigils.GLYPHS` no tiene `altura` (sí `levitacion`); `prueba_capacidad_libro` lo anota |
| 18 | Orden de `construir` | `HECHIZO_CLASE.md` §2.1: sumas y luego multiplicaciones, topes, derivados | además `fija` antes de las sumas, `minimo` después de los topes, daño por potencia y calidad antes de `_limitar` |
| 19 | (fuera de los 4 docs) runa de la flecha | `docs/GRUTA_BATIDA.md`: «fuego + ᚠ flecha» | ᚠ es repetición; la flecha es ᛇ |

## 4. Preguntas abiertas (pendientes en los docs)

1. **Proyectiles que dejan materia** (ESPEC §0.3): la flecha de fuego aún deja una zona de llamas de 3 s, la de agua su
   charco y la de hielo hiela, sin Permanencia. ¿Se les aplica la regla de la tierra (solo golpean)?
2. **Valores de §2 de la ESPEC** (gravedad por estado, densidad, temperatura, humedad, conductividad): punto de partida,
   pendientes de ajustar en el lab. ¿Cuándo se usarán para las reacciones en lugar de las reglas escritas en `Combate3D`?
3. **ᚱ con sólido sin barrera** (GLIFOS_RECETA §2.4 bis): late en continuo pero sin recargo de tinta, porque el coste solo
   ve las props y no el elemento.
4. **Hielo y rayo aparcados** (DANO_Y_TINTA §5): ¿aplicar la propuesta ×0,90 / ×1,00? El +15 del hielo sobre mojado pesa
   mucho con el daño nuevo (una ligera pasa de 10,8 a 25,8).
5. **Dos fuegos medios no matan a un goblin** (DANO_Y_TINTA §3): dejan 1,2 de vida; ¿bajar la vida del goblin a 48?
6. **Daños sin retocar** (DANO_Y_TINTA §8): entorno (`EmisorRayo3D` 8/tic, estalagmita 25), quemadura (hasta 18),
   `dano_periodico` del fuego (40 pts/s = 10 por pulso, de cuando el daño era 50) y escudos (60, 25) siguen con las cifras
   de antes con vidas a la mitad.
7. **G (amplificar)**: el gancho existe y vale 1; ¿qué glifo lo toca y cuánto?
8. **Campos sin uso todavía**: `elasticidad`, `intensidad_estado`, `retorna`, `busca`, `perfora`, `golpea_lanzador`, `veneno`, `elevacion`
   (glifo «flota» futuro), `retardo`, eventos y `crear_hijo`: existen con defecto pero ningún glifo los asigna. Los glifos
   futuros (ᚦ ᚨ ᛃ ᛞ ᛈ) no se asignan sin decisión de Pablo.
9. **Rebote sin flecha** (GLIFOS_RECETA §2.2): «sin viaja, refleja proyectiles»: confirmar si está hecho y si se quiere.
10. **Pilar escalable de 2 niveles** (discrepancia 3): ¿se sube `MAX_NIVELES_SUBIBLES`, se permite un sólido no pisable de
    2 niveles o se acepta que ᛏᛏᛏ + tierra/hielo no se lance?
11. **Glifos por hechizo**: con páginas de 2–4 huecos, ¿la potencia alta (≥ 4 glifos) y el tope de 6 son alcanzables en
    el juego normal, o solo en el lab?
