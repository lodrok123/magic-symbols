# Daño y tinta por potencia

29/10/2026 · decisión de Pablo (con correcciones de Opus aceptadas) · **construido**. Todo el cálculo vive en `nucleo/dano.gd` (`class_name Dano`); prueba: `herramientas/prueba_dano_tinta.gd`.

Antes el daño de un hechizo era el de su runa (fuego 50, agua 40, tierra 0 + 18…) y la tinta salía del **volumen** (10 × tamaño relativo × propiedades). Ahora los dos salen de la **potencia**: cuántos glifos lleva la receta.

---

## 1. Potencia

**Potencia = nº de glifos de la receta** (los que el juego conoce; el elemento no cuenta y los glifos aparcados —retardo, atracción, espejo, amplificar— tampoco).

| Glifos | Potencia |
|---|---|
| 0–1 | ligera |
| 2–3 | media |
| ≥ 4 | alta (el libro admite 6: `Hechizo.MAX_GLIFOS`) |

Constantes: `Dano.GLIFOS_MEDIA = 2`, `Dano.GLIFOS_ALTA = 4`.

| Potencia | Daño base B | Tinta base T_base |
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
T = T_base(potencia) × ( 1 + Σ recargos )
```

Los recargos son SOLO de glifos especiales que ya encarecían: hoy el **efecto continuo ᚱ** (`Sigils.COSTE_CONTINUO_V2` = 0,25, cuando la receta lleva ᚱ y su volumen se queda: barrera o permanencia). La repetición no tiene recargo propio (antes solo encarecía por contar como «propiedad» del cálculo por volumen, que desaparece). El nº de glifos entra **solo** por T_base: **sin doble conteo**. La rebaja del pigmento (`Tinta.coste_efectivo`, regla del 1/3) se aplica encima, como siempre.

| Receta | Tinta |
|---|---|
| ligera (0–1 glifos) | 8 |
| media (2–3) | 18 |
| alta (≥ 4) | 34 |
| media con ᚱ continuo (p. ej. barrera + ᚱ) | 18 × 1,25 = 22,5 |
| alta con ᚱ continuo | 34 × 1,25 = 42,5 |

La barra sigue en 100 (`Tinta.MAXIMA_INICIAL`) y +20 por reacción (`Tinta.TINTA_POR_REACCION`). El **coste por volumen ya no existe**: `Tinta.coste_receta` y `COSTE_BASE_V2` se han borrado; `Sigils.coste_v2` / `Hechizo.coste` / `Receta3D.tamano_relativo()` quedan solo como medida de TAMAÑO para el laboratorio y las pruebas (no cobran nada).

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

| Enemigo | Elemento | Ligera | Media | Alta |
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

Cuánto cuesta matar (tinta por goblin de 50, DEF 2, fuego): 5 ligeros = 40 · 3 medios = 54 · 2 altos = 68. Los ligeros son más baratos pero necesitan más tiempo y más recargas; la potencia alta mata antes (menos recarga y menos exposición).

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
| Recargo de tinta continuo | `Sigils.recargos_tinta` (`nucleo/sigils.gd`) |
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
