# Daño y tinta por potencia

29/10/2026 · decisión de Pablo (con correcciones de Opus aceptadas) · **construido**. Todo el cálculo vive en `nucleo/dano.gd` (`class_name Dano`); prueba: `herramientas/prueba_dano_tinta.gd`.

Antes el daño de un hechizo era el de su runa (fuego 50, agua 40, tierra 0 + 18…) y la tinta salía del **volumen** (10 × tamaño relativo × propiedades). Ahora salen de cuántos glifos lleva la receta: la **tinta** del nº TOTAL de glifos (potencia) y el **daño** del nº de glifos OFENSIVOS (H3, 29/10: los de geometría ᛁ y ᛏ no suman daño).

---

## 1. Potencia

Hay **dos recuentos** de glifos (el elemento no cuenta y los glifos aparcados —retardo, atracción, espejo, amplificar— tampoco):

- **Potencia de la TINTA = nº TOTAL de glifos** (`Hechizo.n_glifos`, `nivel_potencia`). Una ᛁ o una ᛏ cuestan tinta.

| Glifos (total) | Potencia (tinta) |
|---|---|
| 0–1 | ligera |
| 2–3 | media |
| ≥ 4 | alta (el libro admite 6: `Hechizo.MAX_GLIFOS`) |

Constantes: `Dano.GLIFOS_MEDIA = 2`, `Dano.GLIFOS_ALTA = 4` (`Dano.nivel`, `Dano.tinta`).

- **Nivel de DAÑO = nº de glifos OFENSIVOS** (`Hechizo.n_glifos_dano`, `nivel_dano`): los glifos con `Sigils.cuenta_dano` (todos salvo ᛁ `linea_x`, ᛁ `linea_z` y ᛏ `altura`, que llevan `"cuenta_dano": false`). Así «ᛁ×6» no es la combinación óptima: cuesta la tinta de una alta y daña como una ligera. La repetición ᚠ sí cuenta (ya duplica el daño por sí misma).

| Glifos ofensivos | Nivel de daño |
|---|---|
| 0–2 | ligera |
| 3–4 | media |
| 5–6 | alta |

Constantes: `Dano.GLIFOS_MEDIA_DANO = 3`, `Dano.GLIFOS_ALTA_DANO = 5` (`Dano.nivel_dano`, `nombre_nivel_dano`, `base_dano`, `base_elemental`).

Ejemplos (fuego; tinta antes de la rebaja del pigmento):

| Receta | Glifos (total) → tinta | Ofensivos → daño |
|---|---|---|
| fuego solo | 0 → ligera, 8 | 0 → ligera, 13,2 |
| fuego + ᛁ | 1 → ligera, 8 | 0 → ligera, 13,2 |
| fuego + ᛁᛁ / ᛁᛁᛁ | 2–3 → media, 18 | 0 → ligera, 13,2 |
| flecha + rebote | 2 → media, 18 | 2 → ligera, 13,2 |
| flecha + rebote + ᚱ | 3 → media, 18 | 3 → media, 26,4 |
| flecha + rebote + ᚱ + ᚠ | 4 → alta, 34 | 4 → media, 26,4 |
| flecha + rebote + ᚱ + ᚠ + permanencia | 5 → alta, 34 | 5 → alta, 44 |
| flecha + ᛁ + ᛁ + ᛏ | 4 → alta, 34 | 1 → ligera, 13,2 |

Hielo y rayo (aparcados) conservan su daño de siempre con cualquier geometría.

| Nivel | Daño base B (nivel de daño) | Tinta base T_base (potencia) |
|---|---|---|
| Ligera | 12 | 8 |
| Media | 24 | 18 |
| Alta | 40 | 34 |

**Multiplicador elemental E:** fuego ×1,10 (quemadura) · agua ×0,80 (humedad y conducción) · tierra ×1,15 (impacto y estructuras) · viento ×0,80 (empuje).

| B × E | Ligera | Media | Alta |
|---|---|---|---|
| Fuego | 13,2 | 26,4 | 44 |
| Agua | 9,6 | 19,2 | 32 |
| Tierra | 13,8 | 27,6 | 46 |
| Viento | 9,6 | 19,2 | 32 |

Eficiencia daño/tinta (B / T_base): **ligera 1,5 · media 1,33 · alta 1,18**. La potencia baja es más eficiente en tinta; la alta compensa porque **la defensa plana se come una parte fija de cada golpe** (§4): contra un enemigo con DEF 5, la ligera de fuego pierde el 38 % de su daño en la defensa y la alta solo el 11 %. Lanzar muchos hechizos pequeños gasta menos tinta por punto de daño, pero contra enemigos blindados solo la potencia alta (y la media) hace daño de verdad.

---

## 2. Fórmulas

### Daño por impacto

```
D = ( B × E × G × X + suma_X ) × R          (antes de la defensa)
D_final = máx( SUELO_DEF · D ,  D − DEF )     SUELO_DEF = 0,2
```

| Símbolo | Qué es | Valor hoy |
|---|---|---|
| B | daño base de la potencia | 12 / 24 / 40 |
| E | multiplicador del elemento | tabla de arriba (1 para hielo y rayo) |
| G | glifos con efecto propio sobre el impacto (`Hechizo.potencia`) | **1,0**: ningún glifo lo toca (ver §6) |
| X | la reacción | rayo sobre mojado ×1,5 · el resto 1 |
| suma_X | lo que SUMA la reacción | hielo sobre mojado +15 (entra antes de R) |
| R | lo que le pasa a ESE enemigo con ese elemento | débil ×1,5 · resiste ×0,75 · normal ×1 · gólem de pie 0 · gólem con el núcleo expuesto ×1,5 |
| DEF | defensa plana del enemigo | §4 |

Se acabó `MULT_DEBIL` 2,0 / `MULT_RESISTE` 0,5: ahora **×1,5 / ×0,75** (`Dano.MULT_DEBIL`, `Dano.MULT_RESISTE`; `Combate3D` los reexporta con los nombres de siempre).

**Defensa y su suelo.** `D_final = máx(0,2·D, D − DEF)`: la defensa resta, pero nunca deja menos del 20 % del golpe. Si `DEF > D`, queda `0,2 · D`. Un daño 0 (gólem de pie, R = 0) se queda en 0. El golpe cuerpo a cuerpo F (daño 5) también pasa por la defensa y su suelo: goblin DEF 2 → 3 · guerrero con escudo DEF 5 → **1** (el suelo: 0,2 × 5) · gólem expuesto 5 × 1,5 − 10 → suelo **1,5**.

**Daño continuo** (quemadura, veneno, pulsos de zona): pasa por R, **no** por DEF (`Dano.continuo`). Sus cifras no han cambiado (quemadura 3 por tic de 0,5 s con ×1,5 si el enemigo es débil al fuego; el elemental 6; veneno `veneno_dps`; pulsos `dano_periodico × intervalo`). Los pulsos de zona ahora multiplican por el R del enemigo (antes no pasaban por R).

### Tinta

```
T       = T_base(potencia) + Σ aporte_glifo
T_final = T × ( 1 + recargo_instancias + recargo_periodico )
```

Sale del **`Hechizo` construido**: `Dano.tinta_de(h)` (lo que cobra el juego: `Hechizo.coste_tinta`, `Receta3D.coste_tinta()`) y `Dano.desglose_tinta(h)` → `{base, aportes: {glifo: x}, instancias, periodico, total}` para el laboratorio y las pruebas. Las dos aceptan `ajustes` (solo pruebas) para probar números sin tocar las constantes del juego. `Dano.tinta(n_glifos, recargos)` queda como la base. La rebaja del pigmento (`Tinta.coste_efectivo`, regla del 1/3) se aplica encima, fuera de aquí.

| Término | De dónde sale | Hoy |
|---|---|---|
| `T_base` | nº de glifos → potencia: 0–1 ligera **8** · 2–3 media **18** · ≥ 4 alta **34** | igual |
| `aporte_glifo` | dato `"tinta": {"por_glifo": x, "tope": t}` en cada entrada de `Sigils.GLIFOS`: `mín(x · n, t)` (sin clave, 0) | 0 en los 10 glifos |
| `recargo_instancias` | `Dano.K_COPIA` × (copias − 1) + `Dano.K_HIJO` × hijos previstos (suma de `cuantos` de las acciones `crear_hijo` de todos los eventos) | 0 y 0 |
| `recargo_periodico` | **+0,25** (`Sigils.COSTE_CONTINUO_V2`) si ᚱ y el volumen se queda sin viajar (`Dano.es_continuo`) · más `Dano.K_PERIODICO` si `dano_periodico > 0` o `veneno > 0` | 0,25 como siempre; K_PERIODICO 0 |

El nº de glifos sigue entrando **solo** por `T_base` (sin doble conteo): el aporte de un glifo es un precio propio de ese glifo, no un segundo conteo, y vale 0 hasta que Pablo lo ponga.

**Cuándo es «continuo» (`Dano.CONTINUO_POR_HECHIZO`).** Hoy (`false`) es la condición de siempre, por las propiedades de la receta: ᚱ + no viaja + (barrera o permanencia). Con `true` se decidiría con `Hechizo.persistente`, que cierra PENDIENTES (tierra/hielo + ᚱ sin barrera también laten y no pagaban), pero **cambia el golden**: tierra/hielo + ᚱ sin barrera suben (+25 %: p. ej. ᛁᛁ + ᚱ, 18 → 22,5) y ᛁᛁ + ᛉ + ᚱ (un haz, no se queda) baja (42,5 → 34). Se deja a `false` por la regla «el golden no se regenera»; **decisión para Pablo** (la prueba cubre las dos).

| Receta (constantes del juego, todo a 0) | Tinta |
|---|---|
| esfera · flecha | 8 |
| ᚠᚠ + flecha (3 glifos, 3 copias) | 18 |
| barrera + ᚱ · permanencia + ᚱ | 18 × 1,25 = 22,5 |
| barrera ×2 + ᚱ ×2 (alta) | 34 × 1,25 = 42,5 |
| flecha + ᚱ (viaja: sin recargo) | 18 |
| tierra + ᛁᛁ + ᚱ (sin barrera) | 18 (con `CONTINUO_POR_HECHIZO`: 22,5) |
| fuego (ya hiere por tics: `dano_periodico` 40) | 8 |

**Propuesta de números para Pablo** (nada de esto está aplicado; los topes de los glifos ya están escritos en `Sigils.GLIFOS`):

| Glifo | `por_glifo` propuesto | Glifo | `por_glifo` propuesto |
|---|---|---|---|
| flecha | 2 | permanencia | 3 |
| barrera | 4 | raido (ᚱ) | 4 |
| repetición | 3 | ejes (ᛁ, altura) | 0 |
| rebote | 2 | pulso (crecer) | 2 |

`K_COPIA`, `K_HIJO` y `K_PERIODICO`: sin propuesta fija; ojo con `K_PERIODICO`, porque **el fuego ya hiere por tics de serie** (`dano_periodico` 40): con 0,1 todo hechizo de fuego costaría ×1,1. Si se quiere solo para zonas añadidas por glifos, habrá que decidir qué cuenta. Cuando se pongan números, el golden se regenera a propósito y se anota.

La barra sigue en 100 (`Tinta.MAXIMA_INICIAL`) y +20 por reacción (`Tinta.TINTA_POR_REACCION`). El **coste por volumen ya no existe**: `Tinta.coste_receta` y `COSTE_BASE_V2` se han borrado; `Sigils.coste_v2` / `Hechizo.coste` / `Receta3D.tamano_relativo()` quedan solo como medida de TAMAÑO para el laboratorio y las pruebas (no cobran nada). `Sigils.recargos_tinta` se ha retirado.

---

## 3. Vida y defensa por enemigo

| Enemigo | Vida antes → ahora | DEF | Dónde |
|---|---|---|---|
| Goblin guerrero / arquero / asesino | 100 → **50** | 2 | `Combate3D.VIDA_MAXIMA`, `Dano.DEF_GOBLIN` |
| Guerrero con escudo | 50 | **5** | `Escudo3D.equipar` sube la DEF a `Dano.DEF_ESCUDO` |
| Limo (E1) | 60 → **30** | 0 | `Limo3D.VIDA` |
| Chamán (E2) | 50 → **30** | 0 | `Chaman3D.VIDA` |
| Gólem de piedra (E3) | 120 → **70** | 10 | `Golem3D.VIDA`, `Dano.DEF_GOLEM` |
| Elemental del bosque | 1000 → **500** | 6 | `Combate3D.ELEM_VIDA`, `Dano.DEF_ELEMENTAL` |
| Gatopedro (tutorial) | 85 → **45** | 0 | `Gatopedro3D.VIDA` |

`Combate3D.defensa` es un atributo `@export` por instancia. El criterio de la vida: el daño bajó a ~la mitad (fuego 50 → 26,4 de una media), la vida baja a ~la mitad. Gatopedro (no estaba en la lista): «cae con 2 fuegos» ahora son 2 medios; con 45, uno + toda la quemadura (26,4 + 18 = 44,4) sobrevive por 0,6 y dos (52,8) lo tumban.

### Golpes para matar (R = 1; el gólem, con el núcleo expuesto: R = 1,5 y DEF 10)

H3 (29/10): las columnas son el nivel de DAÑO, o sea los glifos **ofensivos** (ᛁ y ᛏ no cuentan). Los números por nivel no cambian (B y E son los mismos); cambia cuántos glifos hacen falta: **ligera = 0–2 ofensivos** (antes 0–1 glifos), **media = 3–4** (antes 2–3), **alta = 5–6** (antes ≥ 4). Con 0, 1 o 2 ofensivos se mata igual (ligera); la tinta se paga aparte por el total de glifos.

| Enemigo | Elemento | Ligera (0–2 ofensivos) | Media (3–4) | Alta (5–6) |
|---|---|---|---|---|
| **Goblin** (50, DEF 2) | fuego | 11,2 → **5** | 24,4 → **3** | 42 → **2** |
| | agua / viento | 7,6 → 7 | 17,2 → 3 | 30 → 2 |
| | tierra | 11,8 → 5 | 25,6 → **2** | 44 → 2 |
| **Goblin con escudo** (50, DEF 5) | fuego | 8,2 → 7 | 21,4 → 3 | 39 → 2 |
| | agua / viento | 4,6 → 11 | 14,2 → 4 | 27 → 2 |
| | tierra | 8,8 → 6 | 22,6 → 3 | 41 → 2 |
| **Limo** (30, DEF 0) | fuego | 13,2 → 3 | 26,4 → 2 | 44 → 1 |
| | agua / viento | 9,6 → 4 | 19,2 → 2 | 32 → 1 |
| | tierra | 13,8 → 3 | 27,6 → 2 | 46 → 1 |
| **Chamán** (30, DEF 0) | igual que el limo | | | |
| **Gólem expuesto** (70, DEF 10, R 1,5) | fuego | 9,8 → 8 | 29,6 → 3 | 56 → 2 |
| | agua / viento | 4,4 → 16 | 18,8 → 4 | 38 → 2 |
| | tierra | 10,7 → 7 | 31,4 → 3 | 59 → 2 |

(El limo no recibe daño de su propio elemento: lo absorbe. El gólem de pie no recibe nada.)

**Aviso sobre la cuenta de «2 fuegos medios»:** un goblin (50) con DEF 2 recibe 24,4 de un fuego medio: **dos dejan 1,2 de vida** (48,8) y la quemadura lo remata; sin quemadura son 3. Los 5 ligeros sí lo matan (56). Si se quiere que dos medios lo maten a secas, la vida del goblin debería ser 48 o menos.

Cuánto cuesta matar (tinta por goblin de 50, DEF 2, fuego): 5 ligeros = 40 · 3 medios = 54 · 2 altos = 68 (con glifos ofensivos puros; cada ᛁ o ᛏ de más sube la tinta —la potencia por el total— sin subir el daño). Los ligeros son más baratos pero necesitan más tiempo y más recargas; la potencia alta mata antes (menos recarga y menos exposición).

---

## 4. Por qué la defensa plana da sentido a la potencia alta

Sin defensa, daño/tinta sería casi plano (1,5 / 1,33 / 1,18) y lo óptimo sería siempre ligera. Con una defensa plana cada golpe pierde `DEF` puntos: la ligera (13) pierde un 15 % contra DEF 2 y casi la mitad contra DEF 6 (el elemental); la alta (44) apenas nota ese 2 y solo pierde un 14 % contra DEF 6. Contra el gólem (DEF 10, núcleo ×1,5) una ligera de agua hace 4,4 y una alta 38: **8,6 veces más daño por 4,25 veces la tinta**. Así la potencia deja de ser «más caro y más grande» y pasa a ser «lo que hace falta contra lo blindado». El suelo del 20 % impide el efecto contrario: nunca un hechizo útil queda en 0.

---

## 5. Hielo y rayo (aparcados)

Se retomarán. De momento **conservan su daño de siempre** (`nucleo/ice_rune.tres` 20, `lightning_rune.tres` 55 y todas sus reglas: hielo +15 sobre mojado, rayo ×1,5 sobre mojado y salto al enemigo más cercano), sin tabla de potencia; pero **sí pasan por R y por la defensa**, para que todos los enemigos lean igual (un rayo contra un goblin: 55 − 2 = 53).

**Propuesta para cuando se retomen** (no aplicada; anotada en `Dano.PROPUESTA_RAYO` y `PROPUESTA_HIELO`): rayo ×1,00 y hielo ×0,90 sobre la misma tabla de B → rayo 12 / 24 / 40 y hielo 10,8 / 21,6 / 36 (con el aturdimiento y la congelación como su valor extra, como la quemadura al fuego). El +15 del hielo sobre mojado y el ×1,5 del rayo habrá que revisarlos entonces: con el daño nuevo el +15 pesa mucho más (una ligera de hielo pasa de 10,8 a 25,8 sobre un mojado).

---

## 6. Qué hacía antes G y qué se ha hecho

Se buscó `potencia`, `potenciada`, amplificar, rebote, perforar, repetición:

- `Hechizo.potencia` («factor del daño, glifo amplificar, aparcado»): existe, vale 1,0 y **no lo multiplica ni lo lee nadie**.
- `amplificar` está en `Receta3D.APARCADOS` (se dibuja y avisa «Aún sin uso»). `SpellRecipe.power` / `potenciada()` son del 2D antiguo.
- `repetición` hace copias (cada copia golpea con el mismo daño), `rebote` cambia la dirección y `perfora` cuenta enemigos atravesados: ninguno multiplica el daño de un impacto.

Por tanto **G = 1** hoy. El gancho está listo: `Combate3D.decidir_golpe` ya multiplica por `Hechizo.potencia` (G), de modo que el día que `amplificar` (u otro glifo) lo toque, bastará con que ponga ese campo; y el glifo seguirá contando también para el nº de glifos (la potencia). Los glifos que solo cuentan para la potencia **no** entran en G.

---

## 7. Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Tablas, fórmulas, cortes, tinta, DEF por tipo (el único punto del cálculo) | `nucleo/dano.gd` |
| Daño base B × E de un hechizo (`Hechizo.dano`), `n_glifos`, `nivel_potencia`, `coste_tinta` | `nucleo/hechizo.gd` (`construir`, `_derivar`) |
| Tinta (base, aportes, recargos) | `Dano.tinta_de` / `Dano.desglose_tinta` (`nucleo/dano.gd`); aportes en `Sigils.GLIFOS[...]["tinta"]` |
| Tinta antes de construir el Hechizo (comprobar y cobrar) | `Lanzador3D.Receta3D.coste_tinta()` / `n_glifos()` (`magia/lanzador_3d.gd`, `_preparar_pagina` y `lanzar_ahora`) |
| Pigmento de daño (×1,5) | `Lanzador3D.hechizo_de`: multiplica `Hechizo.dano` (B × E) antes de G, X, R y DEF |
| La decisión del golpe: G, X, suma, R, DEF | `Combate3D.decidir_golpe` (+ `golpe` la aplica, `prever_golpe` la enseña) |
| Gólem (R = 0 / ×1,5 y DEF 10) | `Golem3D.decidir_golpe`, `recibir_golpe_cuerpo` |
| Limo (absorbe su elemento) | `Limo3D.decidir_golpe` |
| Golpe F con defensa | `Combate3D.recibir_golpe_cuerpo` |
| Pulsos de zona con R | `magia/hechizo_vivo.gd` (el pulso de las zonas, junto a `_abrir_zona`) |
| Previsión del indicador | `PrevisionHechizo.prever` → `prever_golpe` → `decidir_golpe`: dice el mismo número que el golpe real |
| Número flotante | `Combate3D._numero` (recibe el `D_final`) |
| Pruebas | `herramientas/prueba_dano_tinta.gd` |

Cambios en los datos: la tierra ya no suma +18 (`earth_rune.tres`); `fire_rune.tres` (50) y `water_rune.tres` (40) conservan su `damage` pero `Hechizo.construir` lo sobrescribe con la tabla (hielo y rayo, no).

---

## 8. Cosas que se ven y no se tocaron (para Pablo)

- **Daños de entorno** (`EmisorRayo3D` 8 por tic, `EstalagmitaPulso3D` 25, `GeodaPulso3D`) hieren a los enemigos por `receive_damage` directo; con la vida a la mitad pesan el doble. No se han tocado.
- **Quemadura** (3 por 0,5 s durante 3 s = hasta 18; el elemental 6 por tic) y `dano_periodico` del fuego (40 × 0,25 s = 10 por pulso) siguen con sus cifras de antes: contra un goblin de 50 son un tercio de la vida (la quemadura) y 1,25 s de zona.
- **Escudos** (`Escudo3D.VIDA_ESCUDO` 60, `EscudoNaturaleza3D.VIDA` 25) no son enemigos y no se han reducido.
- **Hielo sobre mojado +15** pesa mucho con el daño nuevo (§5).
