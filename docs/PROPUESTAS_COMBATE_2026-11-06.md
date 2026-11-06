# Propuestas de mejora del combate (revisión del 6/11/2026)

6/11/2026 · contexto JUEGO · **propuesta para revisión conjunta, nada construido**.

Parte de lo que ya está hecho de `PROPUESTA_COMBATE.md` (lanzamiento rápido, previsión de reacciones, golpe F, tinta por reacción, avisos, tiempo bruja, limo, chamán, gólem, daño por potencia de `DANO_Y_TINTA.md`) y de una lectura del código real el 6/11. No repite lo construido: propone lo siguiente. Las fuentes externas se citan por URL para revisarlas juntos; las de wikis de fans o reseñas van marcadas con *(fan)*.

---

## 0. Diagnóstico del código (6/11)

Lo que de verdad pasa hoy, con rutas:

1. **El rayo domina.** `nucleo/lightning_rune.tres` tiene `damage = 55` fijo, fuera de la tabla de potencia (`nucleo/dano.gd:20`, `:109-115`). Un rayo de 0 glifos hace más que un fuego de 6 (40 × 1,10 = 44), y además aturde 1,2 s y salta a otro enemigo. El hielo también va fuera de tabla (20). Ya existe la propuesta `Dano.PROPUESTA_RAYO` / `PROPUESTA_HIELO` sin aplicar (`dano.gd:45-46`).
2. **Todos los goblins son débiles al agua y resisten el fuego por defecto** (`enemigos/combate_3d.gd:267-268`). Limo, gólem y chamán tienen `debil = ""`. La tabla de debilidades apenas se usa, y castiga el elemento oficial del juego.
3. **Las reacciones elemento × enemigo pasan todas por «mojado»** (`decidir_golpe`, `combate_3d.gd:838-900`): mojado + rayo, mojado + hielo, mojado + fuego (anula). No hay reacción con quemado, congelado ni aturdido. Tierra solo ralentiza y viento solo interrumpe.
4. **El suelo apenas participa en combate.** Solo agua, hielo y fuego escriben estado (`mundo/reacciones_suelo_3d.gd:22`); rayo, tierra y viento no. La electrificada dura 2 s (`mundo/estados_suelo_3d.gd:61`): no da para preparar nada.
5. **IA de goblin plana:** persigue, se planta, un golpe de 20 con 0,6 s de carga y 1,6 s de descanso (`combate_3d.gd:130-132`, `:1639-1660`). Sin flanqueo, sin coordinación, sin huir del fuego ni del agua.
6. **Tinta sin tensión:** recargos por copias, hijos y periódico a 0 (`dano.gd:152-154`), así que repetición y permanencia son gratis en tinta; `Tinta.COSTES` por forma (`nucleo/tinta.gd:77-88`) es código muerto. Fuera de combate sobra tinta, dentro regenera 1/s y se pasa de sobrar a esperar.
7. **Lo interesante vive en salas de prueba.** Limo, gólem y chamán solo aparecen en `SalaLimo.txt`, `SalaGolem.txt`, `SalaChaman.txt` y una entrada de `Bosque_02.txt`. Los niveles jugables son casi solo goblins, sin encuentros combinados.
8. **Feedback asimétrico:** el enemigo tiene hitstop escalado por daño, destello, rótulos y barra; la jugadora recibe siempre la misma viñeta, temblor 0,35 y empuje 4,5 (`jugador/jugador_3d.gd:603`, `presentacion/sensacion_3d.gd:60-61`), sin aviso de vida baja.
9. **La defensa plana solo la nota el gólem y el elemental** (DEF 2 en goblins frente a golpes de 12–44, `dano.gd:62`). «Perforar» solo importa contra el elemental.
10. **Voltereta con 4 s de recarga** (`jugador_3d.gd:49`) y ventana de premio de 0,25 s: fuera de los avisos es casi decorativa, porque la invulnerabilidad de 0,7 s tras un golpe ya protege.
11. **Cifras desfasadas en `PROPUESTA_COMBATE.md`:** limo 60 → 30, gólem 120 → 70, chamán 50 → 30 y ataque v2 de flechas de veneno. El limo no se divide con fuego ni se vuelve bloque con hielo (prometido en §4 del doc original).

---

## 1. Referencias externas y qué se toma de cada una

### Magicka (combinar elementos, fuego amigo)
- Opuestos que se anulan: fuego y frío no se combinan; añadir el opuesto borra el otro de la cola. https://strategywiki.org/wiki/Magicka/Elements *(fan)*
- El fuego amigo es un principio que Arrowhead se negó a quitar; el riesgo es lo que hace que la elección importe. https://gamedeveloper.com/business/postmortem-arrowhead-game-studios-i-magicka-i- · https://pcgamer.com/magicka-wizard-wars-hands-on-calamitous-multiplayer-zapping
- Con ~4.000 combinaciones no se equilibra hechizo a hechizo: se equilibra por reglas estructurales. https://esl.com/article/id-rather-reward-good-teamplay-than-nerf-it-for-the-sake-of-balance-an-interview-with-magicka-wizard-wars-david-nisshagen/

**Se toma:** tabla de opuestos (fuego/hielo, agua/rayo) como freno sin tocar números; que las zonas propias dañen a la jugadora.

### Noita (varitas como programa)
- Los modificadores afectan al siguiente hechizo; el orden importa; cast delay y recharge son dos tiempos. https://noita.wiki.gg/wiki/Guide:_Wand_Mechanics *(fan)* · https://noita.wiki.gg/wiki/Modifier *(fan)*
- Trigger: el siguiente hechizo va como carga y sale al impactar.

**Se toma:** orden de glifos con significado; glifo «al impactar» (ya hay `al_golpear` y `crear_hijo` en los eventos de `Hechizo`).

### Hades / Hades II (ritmo, legibilidad, Omega)
- Dash como pieza central y boons que modifican acciones fijas. https://www.pcgamer.com/hades-is-already-a-killer-combat-game-in-early-access
- Diseño «multiplicativo» para la rejugabilidad (Kasavin). https://amara.org/subtitles/8d0Rd4ibbKQz/en/1/download/How%20Hadess%20Genius%20Design%20Keeps%20You%20Engaged.en.srt
- Omega: mantener para cargar a cambio de Magick; el Cast es un círculo que atrapa. https://www.gameleap.com/articles/hades-2-what-are-omega-moves *(fan)* · https://mobalytics.gg/hades-2/guides/casts *(fan)*
- Legibilidad por iluminación y contraste. https://medium.com/@Nat.Rowley/how-hades-creates-a-responsive-underworld-915715a7c2a *(opinión)*

**Se toma:** carga de página (mantener 1/2/3 más tiempo = sobrecarga); círculo de hielo que atrapa.

### Breath of the Wild / Echoes of Wisdom (motor químico, invocaciones)
- El motor químico es un calculador de estados por reglas: elementos sin estado × materiales con estado. Probado en un prototipo 2D cenital. https://www.thumbsticks.com/gdc-17-breath-of-the-wild-science-lies · https://www.engadget.com/2017/03/12/breath-of-the-wild-gdc-talk/ · https://zeldauniverse.net/2017/03/09/zelda-team-discusses-breath-of-the-wilds-development-and-2d-zelda-prototype-at-gdc/
- Echoes: energía de Tri limitada; invocar uno nuevo borra el más antiguo. https://www.player2.net.au/2024/09/the-legend-of-zelda-echoes-of-wisdom-hands-on-preview/ · https://www.zeldawiki.wiki/wiki/Echo *(fan)*

**Se toma:** estados del suelo como elemento × material (hierba, roca, madera, agua); tope de barreras vivas.

### Death's Door / Tunic (vista fija)
- Acid Nerve descartó la estamina a propósito: «Zelda con combate intenso». https://www.nme.com/features/acid-nerve-developers-david-fenn-and-mark-foster-on-making-deaths-door-3203321
- El hechizo a distancia es un recurso que se recarga golpeando cuerpo a cuerpo. https://gamecritics.com/damiano-gerli/deaths-door-review/ *(reseña)*
- El parry de Tunic se critica por su windup largo. https://steamcommunity.com/app/553420/discussions/0/4778901811095664619 *(fan)*

**Se toma:** el golpe F devuelve tinta; no meter parry.

### Wizard of Legend (gamefeel, reliquias)
- Firma que se carga con combos; reliquias que leen esa carga o el dash (Autograph Pad, Gyroscopic Inkwell, Ignition Rush). https://wizardoflegend.fandom.com/wiki/Autograph_Pad *(fan)* · https://wizardoflegend.fandom.com/wiki/Gyroscopic_Inkwell *(fan)* · https://wizardoflegend.fandom.com/wiki/Ignition_Rush *(fan)*

**Se toma:** voltereta que deja rastro del elemento de la página activa; mejoras que leen la tinta.

### Spellbreak (hechizo × hechizo)
- Bola de fuego + tornado = tornado de fuego; viento apaga charcos; fuego derrite hielo en vapor. https://spellbreak.fandom.com/wiki/Spells_%26_Sorceries_(Patch_3.1) *(fan)* · https://www.pcgamesn.com/spellbreak/combos

**Se toma:** reacciones entre hechizos vivos (`HechizoVivo` × `HechizoVivo`), no solo con el suelo.

### Arx Fatalis / Okami (gestos)
- Arx: reconocimiento estricto frustra; 3 ranuras de hechizo preparado resolvieron el ritmo (lo mismo que nuestras páginas). https://gog.com/forum/arx_fatalis/cannot_cast_spells/page1 *(fan)* · https://classic.rpgfan.com/previews/arx_fatalis/arx_fatalis.html
- Okami: enemigos con debilidad a un trazo concreto; Okami HD puso botones para atacar y reservó el gesto para lo especial. https://wegotthiscovered.com/?p=729160 · https://www.siliconera.com/okami-hd-uses-buttons-to-attack/

**Se toma:** enemigos débiles a un glifo (no a un elemento); no interrumpir el dibujo salvo golpe fuerte.

### Divinity: Original Sin 2 (superficies)
- Superficies y nubes como capas distintas; agua electrificada aturde a todos los que pisan; bendecir/maldecir multiplica estados sin añadir elementos; el tornado limpia. https://divinityoriginalsin.wiki.fextralife.com/Ground+surface+effects *(fan)* · https://dos2.wiki/wiki/Necrofire_(Status) *(fan)* · https://www.gamepressure.com/originalsinii/environmental-effects-and-combinations/zea274

**Se toma:** viento que limpia suelos; capa de nube (vapor) separada del suelo.

### Game feel
- Nijman, «The Art of Screenshake». https://gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games · lista de trucos: https://makegamessa.com/discussion/comment/16542 *(fan)*
- Jonasson y Purho, «Juice it or Lose it». https://kenney.nl/learn/must-see-videos-for-indie-developers

---

## 2. Propuestas

Ordenadas por impacto en la sensación de juego y coste. «Palanca» = dónde se toca; casi todo son datos.

### Bloque A · Equilibrio (barato, solo constantes)

| # | propuesta | de dónde | palanca |
|---|---|---|---|
| A1 | **Meter rayo y hielo en la tabla de potencia** (rayo ×1,00, hielo ×0,90) y revisar el ×1,5 del rayo sobre mojado y el +15 del hielo | Magicka: equilibrar por estructura, no un elemento por encima | `Dano.MULT_ELEMENTO`, `PROPUESTA_RAYO/HIELO` (`nucleo/dano.gd:44-46`), quitar `damage` de los `.tres` |
| A2 | **Debilidades por enemigo, no por defecto.** Quitar el «agua débil / fuego resiste» global; cada pieza de mapa fija `debil`/`resiste`. Variantes: goblin de las ciénagas (resiste agua, débil rayo), goblin de la cueva (débil fuego) | Okami: debilidad concreta y legible | `Combate3D.debil/resiste` por instancia (`combate_3d.gd:262-268`), líneas `; pieza` en `mundo/datos_nivel/mapas/*.txt` |
| A3 | **Tinta por copias y permanencia.** Poner `K_COPIA` ≈ 0,15 y `aporte_glifo` según la tabla propuesta en DANO_Y_TINTA §2; borrar `Tinta.COSTES` | Noita: cada modificador tiene precio | `dano.gd:152-154`, `Sigils.GLIFOS[k].tinta` |
| A4 | **Voltereta a 1,5 s de recarga, invulnerabilidad tras golpe a 0,4 s.** La esquiva pasa a ser la herramienta y no el escudo pasivo | Death's Door: sin estamina, esquiva libre | `jugador_3d.gd:49`, `INVULNERABLE` (`:38-53`) |
| A5 | **Electrificada a 6 s** y quemada con caducidad (8 s) | DOS2: la superficie es una trampa que preparas | `EstadosSuelo3D.DURA` (`estados_suelo_3d.gd:61`) |

### Bloque B · Reacciones nuevas (el corazón del juego)

| # | propuesta | de dónde | palanca |
|---|---|---|---|
| B1 | **Congelado + tierra/viento/golpe F = «roto»:** daño ×2 y el enemigo cae; cuenta para la tinta por reacción | Magicka y DOS2: el estado abre un remate | `decidir_golpe` (`combate_3d.gd:868-880`), `Tinta.REACCIONES_PREMIADAS` |
| B2 | **Quemado + viento = llamarada:** se propaga al enemigo vecino; **quemado + agua = vapor que ciega** (los enemigos pierden a la jugadora 2 s) | Spellbreak: viento aviva; DOS2: nube de vapor | misma rama de `decidir_golpe`; capa «nube» nueva en `estados_suelo_3d.gd` |
| B3 | **Rayo, tierra y viento escriben en el suelo:** rayo sobre mojado electrifica 6 s (ya), tierra deja «escombro» (ralentiza, sólido para proyectiles), viento **limpia** mojado/quemado/electrificado | DOS2: el tornado limpia; BotW: todo elemento deja estado | `ACCION_DE` (`reacciones_suelo_3d.gd:23`), `TRANSICIONES` (`estados_suelo_3d.gd:47-54`) |
| B4 | **Elemento × material.** Añadir «material» por casilla (hierba, roca, madera, agua) y que la tabla sea elemento × material: fuego sobre hierba se propaga (hoy lo hace la maqueta, `_hf`), sobre roca no. Saca la hierba de `prueba_test2.gd` a `mundo/` (ya estaba en PENDIENTES) | BotW GDC 2017 | `estados_suelo_3d.gd` |
| B5 | **Hechizo × hechizo:** un proyectil que cruza una zona viva de otro elemento se transforma (fuego por agua = vapor, viento por fuego = llamarada que avanza, rayo por agua = descarga en área) | Spellbreak | `HechizoVivo` ya detecta zonas para teñir al limo: reutilizar ese camino |
| B6 | **Tabla de opuestos:** fuego apaga hielo y viceversa en el mismo hechizo o en el suelo; la previsión lo muestra | Magicka | `TRANSICIONES` + `PrevisionHechizo` |
| B7 | **Las zonas propias dañan a la jugadora** (suelo electrificado, llama de permanencia) con un umbral suave: 2 por tic. Da peso a dónde pones la barrera | Magicka: fuego amigo como principio | pulso de zona en `magia/hechizo_vivo.gd` (`_abrir_zona`) |

### Bloque C · Glifos y lanzamiento

| # | propuesta | de dónde | palanca |
|---|---|---|---|
| C1 | **Sobrecarga de página:** mantener 1/2/3 más de 0,8 s cobra el doble de tinta y sube un nivel de potencia (G = 1,5). Usa el gancho `Hechizo.potencia` que hoy nadie lee | Hades II Omega | `Lanzador3D.pulsar_pagina/soltar_pagina`, `Dano` G (`dano.gd:15`) |
| C2 | **Orden de glifos con significado:** repetición antes de flecha = abanico; flecha antes de repetición = ráfaga en fila. La receta ya guarda el orden de trazo | Noita | `Receta3D`, `Hechizo.construir` |
| C3 | **Glifo «al impactar»:** rescatar uno de los aparcados (`retardo`) como trigger: el hechizo lleva un hijo que nace en el impacto (flecha de agua que al llegar deja una barrera de hielo) | Noita trigger | eventos `al_golpear` + `crear_hijo` de `Hechizo` (ya existen) |
| C4 | **Tope de barreras vivas:** a la cuarta se disuelve la primera | Echoes of Wisdom (energía de Tri) | contador en `Lanzador3D` |
| C5 | **El golpe F devuelve 5 de tinta** al acertar; con escudo roto, 10 | Death's Door: el melee recarga el rango | `Combate3D.recibir_golpe_cuerpo` → `Tinta` |
| C6 | **Voltereta con rastro:** con una página de fuego/hielo/agua preparada, rodar deja 1 casilla de ese estado (coste 4 de tinta) | Wizard of Legend Ignition Rush | `Jugador3D` voltereta + `EstadosSuelo3D` |

### Bloque D · Enemigos y encuentros

| # | propuesta | de dónde | palanca |
|---|---|---|---|
| D1 | **Sacar limo, gólem y chamán a los niveles reales** y montar 4 encuentros combinados: chamán + 2 guerreros; limo de agua junto a un charco; gólem en sala con hielo; arquero de puesto + limo | Hades: cada sala es una combinación | `mundo/datos_nivel/mapas/*.txt` |
| D2 | **Goblins que reaccionan al mundo:** huyen del fuego y del agua honda, rodean la barrera, el arquero cambia de puesto si le llega agua | BotW: la IA lee la química | `Combate3D` estados persigue/busca (`:104-111`) |
| D3 | **Completar el limo:** fuego lo divide, hielo lo vuelve bloque empujable (enlaza con `BloqueEmpujable3D`) | ya decidido 27/10 en PROPUESTA_COMBATE §4 | `enemigos/limo_3d.gd` |
| D4 | **Enemigo débil a un glifo:** el espectro solo se toca con pulso ᚱ; el escarabajo solo con barrera en punto | Okami | lista E4 pendiente |
| D5 | **Variantes por zona** (vida, DEF, debilidad) desde la pieza de mapa, sin modo de dificultad | — | `vida_max`, `defensa` por instancia |

### Bloque E · Feedback

| # | propuesta | de dónde | palanca |
|---|---|---|---|
| E1 | **Juice escalado por magnitud del hechizo:** temblor e hitstop según nivel de potencia (ligera 0, media 0,06, alta 0,12 + temblor 0,2) y retroceso del mago con el haz | Nijman, Vlambeer | `Sensacion3D`, `Vfx3D.temblor` |
| E2 | **Feedback propio de reacción:** sonido, destello y rótulo distintos cuando salta una reacción (es la recompensa clave); hoy comparte el del golpe | Nijman; Hades (confirmación de golpe) | `Combate3D._numero` y rótulos (`:947-967`) |
| E3 | **Golpe recibido escalado:** temblor y viñeta por daño, aviso de vida baja (latido + borde) y hitstop mayor en el golpe que deja < 25 | Hades | `sensacion_3d.gd:55-61` |
| E4 | **Previsión de tinta y recarga** en el indicador: lo que cuesta y cuándo vuelve, para que el coste opaco por glifos se entienda | — | `PrevisionReaccion3D` |

---

## 3. Orden sugerido

1. **A1 + A2 + A3 + A4** (una tarde de constantes; regenerar el golden de `prueba_dano_tinta.gd` a propósito).
2. **B1 + B3 + A5** (reacciones nuevas de bajo coste, todas en tablas).
3. **E1 + E2 + E3** (feedback).
4. **D1 + D2** (encuentros reales).
5. **C1 + C5** (sobrecarga y golpe que recarga).
6. **B4 + B5** (material y hechizo × hechizo: son los de más calado, mejor tras probar lo anterior).
7. C2, C3, C4, C6, D3, D4, B6, B7 según playtest.

## 4. Decisiones (Pablo, 6/11/2026)

- **A1 aceptado:** ningún elemento es más fuerte que otro. Rayo e hielo entran en la tabla de potencia.
- **A2 aceptado con excepciones:** debilidades por pieza de mapa. El Bosque es el nivel inicial y se queda sencillo; se creará **un nivel posterior con más habilidades** para probar el concepto completo.
- **B7 aceptado:** fuego amigo suave.
- **C1 aceptado:** sobrecarga de página.
- **B4 aceptado:** material por casilla.
- **Arte:** se hará una **tabla de elementos y sus interacciones** (§6) de la que salgan rótulos, colores e iconos de `PrevisionReaccion3D.ESTILO`.
- **Nuevo (Pablo):** **sellos dobles**. En un punto de la aventura la página admite dos sellos en el núcleo. Salvo los contrapuestos (**fuego anula agua**, **tierra anula viento**), cada par crea una reacción distinta: viento + agua = hielo, tierra + fuego = magma. Puede dar «rayos naturales». Ver §5.

---

## 5. Sellos dobles: valoración y tabla

### 5.1 Qué me parece

**Sí, y es la pieza que le faltaba al sistema.** Razones:

- Hoy el elemento es un dato (`.tres`) y la receta se interpreta. Un sello doble es otra fila de datos: **una tabla 6 × 6 en `nucleo/`** que diga «fuego + tierra = magma», con el mismo espíritu que `EstadosSuelo3D.TRANSICIONES`. No hace falta código por combinación.
- Es exactamente el mecanismo de Magicka que la gente recuerda (vapor, hielo, cancelaciones), pero con una diferencia a nuestro favor: en Magicka se combinan al vuelo con teclas; aquí **se dibujan en el libro**, con calma, y se disparan desde la página. El coste de preparar hace que el combo sea una decisión y no un spam. https://strategywiki.org/wiki/Magicka/Elements · https://gamedeveloper.com/business/postmortem-arrowhead-game-studios-i-magicka-i-
- Da la progresión que faltaba: 6 sellos simples al principio, 13 pares después. Es una «herramienta de mazmorra» en sí misma: el **segundo hueco del núcleo** se gana en un cofre, como los huecos de glifo (`Repertoire.max_sigils_per_page`).
- Las cancelaciones (fuego/agua, tierra/viento) hacen de freno estructural (Magicka) y a la vez de **lección**: la primera vez que dibujas dos opuestos el libro los borra con un efecto, y aprendes la regla sin texto.

**Lo que hay que vigilar:**

1. **Coste de materias.** `HechizoVivo` ejecuta por materia (sólido, líquido, plasma, energía, gas). 13 combos no deberían ser 13 materias nuevas. Propongo que **cada combo se resuelva con una materia existente más modificadores** (magma = plasma con `solido_al_enfriar`; barro = líquido con `ralentiza`; tormenta = gas con `rayos_periodicos`). Solo 2 o 3 pedirían materia nueva (magma y cristal, quizá).
2. **VFX.** Cada combo necesita su color y su micro-animación (regla madre: el glifo manda la forma, el elemento el material). Son 13 looks más. Conviene que el combo **mezcle** los dos toys oficiales (FuegoToy + AguaToy) antes de hacer un toy propio.
3. **Reconocimiento.** El núcleo tendría que admitir dos gestos; hoy un gesto del núcleo solo se compara contra elementos, así que no hay conflicto, pero hay que decidir si el segundo sello se dibuja **encima** o el núcleo se parte en dos mitades. Propongo mitades: izquierda y derecha, y el orden no importa (fuego + agua = agua + fuego).
4. **Enemigos.** El limo que se tiñe, el gólem que resbala y la previsión (`PrevisionHechizo`) tienen que entender el combo. Lo más simple: un combo tiene **etiquetas de los dos padres más la suya** (magma = `calor`, `tierra`, `magma`), así las reglas viejas siguen funcionando (el magma quema porque lleva `calor`) y las nuevas leen `magma`.
5. **Rayos naturales:** sí, y propongo que salgan de **hielo + viento = tormenta** (es como nace el rayo de verdad: cristales de hielo chocando en una nube). Así el rayo se obtiene como reacción antes de tener el sello, lo que encaja con los glifos sin progresión que faltan.

### 5.2 Planteamiento de Pablo (6/11, sustituye a la tabla de 6): cuatro elementos base

Los sellos que se dibujan son **cuatro: fuego, agua, tierra y viento**. **Hielo y rayo no son sellos: son reacciones.** Sus runas no se borran: son el resultado que aparece en el núcleo al combinar, y una vez descubierta una reacción su runa queda anotada en el libro.

**Por qué es mejor que 6:**
- Dos parejas de opuestos limpias y simétricas: fuego/agua y tierra/viento. Con 6 había que explicar por qué hielo no era opuesto de fuego.
- Cuatro elementos iniciales son lo que un jugador asimila en el Bosque; hielo y rayo ya estaban «aparcados» en la tabla de daño y se pensaban para zonas posteriores (Torre del Agua).
- Cuatro toys oficiales de VFX (hay dos) en vez de seis; lo derivado hereda.
- Hielo y rayo ganan progresión: se **descubren**, no se reciben.

**Tres niveles:**

| nivel | cómo se obtiene | qué hay |
|---|---|---|
| 1 · base | un sello en el núcleo | fuego, agua, tierra, viento |
| 2 · reacción | dos sellos base (segundo hueco del núcleo, ganado en un cofre) | 6 pares: 2 se anulan, **4 reacciones** |
| 3 · reacción compuesta | una runa de nivel 2 ya descubierta + un sello base | las combinaciones ricas (niebla, barro ardiente, tormenta…) |

**Nivel 2 (4 reacciones + 2 anulaciones):**

| par | reacción | materia base | suelo | al enemigo | nota |
|---|---|---|---|---|---|
| fuego + agua | **se anulan** (vapor cosmético) | — | — | — | lección de opuestos |
| tierra + viento | **se anulan** (polvareda) | — | — | — | ídem |
| agua + viento | **HIELO** ❄ | sólido | `helada` | congela | la runa copo queda anotada |
| fuego + viento | **RAYO** ⚡ (tormenta: el aire cargado) | energía | electrifica mojado | aturde, salta | la runa zigzag queda anotada; «rayo natural» |
| fuego + tierra | **MAGMA** | plasma + sólido al enfriar | `lava` 8 s → roca | quema fuerte, atrapa al enfriar | puente de roca sobre agua |
| agua + tierra | **NATURALEZA** (decisión de Pablo 6/11: antes «barro», con pocas aplicaciones) | líquido | — | envenena (`Hechizo.veneno`, el mismo del chamán) y ralentiza (raíces) | reaprovecha el veneno, la bola y la nube de los goblins |

**Regla de uso de la runa descubierta (decisión para Pablo):** una vez descubierto el hielo, ¿se puede trazar el copo directamente en el núcleo como un sello más (gastando un solo hueco) o siempre hay que dibujar agua + viento? Propongo **sí, directamente**: así el nivel 3 cabe en dos huecos (copo + fuego) y la progresión es «descubrir runas», no «dibujar más».

**Nivel 3 (runa descubierta + base), ejemplo:**

| par | reacción | para qué |
|---|---|---|
| hielo + fuego | **niebla** que ciega; apaga | sigilo frente a arqueros |
| hielo + tierra | **escarcha** permanente, bloques de hielo empujables | puentes duraderos |
| hielo + viento | **ventisca**: ralentiza y congela en área | control de grupo |
| hielo + agua | **granizo** a distancia | hielo sin línea de visión |
| rayo + agua | **charco electrificado** largo (10 s) | trampa preparada |
| rayo + tierra | **cristal resonante** que pulsa descargas | Cueva Resonante; torreta |
| rayo + viento | **vendaval eléctrico**: empuja y aturde todo lo que cruza | murciélagos |
| rayo + fuego | **explosión** en área | muros agrietados |
| magma + agua | **obsidiana**: roca sólida al instante | puente inmediato |
| magma + viento | **llamarada** que se propaga por hierba | limpiar hierba |
| barro + fuego | **cerámica**: suelo firme y quemado | sellar agua |
| barro + viento | **arenisca / polvo**: ciega leve y seca | — |
| rayo + hielo | **estallido**: congela y rompe con metralla | remate (reacción «roto» de B1) |

Hielo + rayo es el único par de dos runas descubiertas que propongo; el resto de nivel 3 es «descubierta + base» para que no explote el número de VFX. Cada runa descubierta hereda las etiquetas de sus padres (hielo = `agua`, `frio`; rayo = `calor`, `viento`, `electrico`) y las reglas de hoy siguen valiendo.

### 5.2 bis · Tabla anterior con 6 elementos base (se conserva como referencia, descartada el 6/11)

15 pares. Dos se anulan. Columnas: qué sale, qué materia lo ejecuta, qué deja en el suelo, qué hace a un enemigo, para qué sirve en puzles.

| par | reacción | materia base | suelo | al enemigo | puzle / nota |
|---|---|---|---|---|---|
| fuego + agua | **se anulan** (vapor residual, cosmético) | — | — | — | lección de opuestos; el vapor ciega 1 s como guiño |
| tierra + viento | **se anulan** (polvareda cosmética) | — | — | — | ídem |
| fuego + tierra | **magma** | plasma + sólido al enfriar | `lava` temporal (8 s) → `roca` | quema fuerte; al enfriarse lo atrapa en roca | crea suelo nuevo sobre agua (puente de roca al enfriar); enfría con agua/hielo |
| fuego + rayo | **explosión** | energía, un solo pulso en área | `quemada` en el radio | daño alto en área, empuja, prende | rompe muros agrietados; mejor hechizo de área puro |
| fuego + hielo | **niebla** | gas (lento, denso) | nada | ciega: los enemigos pierden a la jugadora; apaga lo que arde | sigilo; cruzar salas con arqueros |
| fuego + viento | **llamarada** | gas + prende | `quemada` por donde pasa | prende y empuja; se propaga por hierba | limpiar hierba en línea; viento que lleva el fuego lejos |
| agua + tierra | **naturaleza** (antes barro) | líquido | — | envenenado 4 s a 3/s y ralentizado 2 s | daño sostenido sin gastar más tinta; reusa `envenenado` de Combate3D |
| agua + rayo | **tormenta de charco** | líquido + energía | `electrificada` larga (10 s) | moja y aturde en cadena a todos los que pisan | trampa de suelo preparada |
| agua + hielo | **granizo** | energía en arco (lluvia) | `helada` en el área | daño de área y congela | hielo a distancia sin línea de visión |
| agua + viento | **hielo** (Pablo) | sólido | `helada` | congela; crea puente | la forma de obtener hielo antes de tener su sello |
| tierra + rayo | **cristal resonante** | sólido que pulsa | nada; el cristal queda 10 s | descarga periódica a quien se acerque; aturde | enlaza con la Cueva Resonante; torreta de defensa |
| tierra + hielo | **escarcha** (permafrost) | sólido | `helada` que no se derrite con calor leve | congela y vuelve sólido el suelo mojado/barro | bloques de hielo empujables, puentes duraderos |
| rayo + hielo | **estallido** | energía + sólido que rompe | metralla: `helada` en puntos | congela y rompe al instante (reacción «roto» de B1), metralla a los vecinos | remate de grupo |
| rayo + viento | **vendaval eléctrico** | gas + energía | `electrificada` donde pasa | empuja y aturde a todo lo que cruza; conduce por mojado | limpiar una sala de enemigos pequeños (murciélagos) |
| hielo + viento | **tormenta** → **rayos naturales** | gas que suelta rayos (hijos `rayo`) | `mojada` y `electrificada` a ratos | rayos al azar a quien esté dentro; a mojados, ×1,5 | la fuente del rayo antes del sello; ventisca que ralentiza |

**Regla de orden:** no importa (es una pareja, no una secuencia). Si en el futuro se quiere orden, se usa para el glifo (C2), no para el sello.

**Consistencia con las reglas de hoy:** cada combo lleva las etiquetas de los padres, así `decidir_golpe` y `TRANSICIONES` ya le dan algo (el magma seca y quema; el granizo moja y hiela) y el combo solo añade lo suyo. La previsión muestra el nombre del combo («Magma», «Tormenta») con su color.

### 5.3 Cómo entraría en el código (sin construir)

- `nucleo/combos_sellos.gd`: tabla `{["fuego","tierra"]: "magma", ...}` ordenada alfabéticamente para que el orden no importe; `anulan` como lista de pares.
- Un `.tres` por combo en `nucleo/` con `etiquetas`, `materia`, `modificadores`, igual que las runas de hoy. Datos, no código.
- `Hechizo.construir` recibe `elementos: Array` en vez de uno; si son dos, busca el combo y usa su `.tres` como elemento.
- El núcleo del libro admite 2 gestos cuando `Repertoire.max_sellos` sea 2 (se gana en un cofre).
- Potencia y tinta: un sello doble sube un nivel de potencia de tinta (es más caro) sin subir el daño base: el valor está en la reacción, no en el número.

---

## 6. Tabla de elementos e interacciones (para rótulos, colores e iconos)

Actualizada el 6/11 a **4 elementos base + 4 derivados** (§5.2). Para arte: un icono y un color por fila y por reacción. «(hoy)» existe en código; el resto es propuesta. Los derivados heredan las etiquetas de sus padres (`CombosSellos`), así que lo marcado «hereda» lo hacen ya sin código nuevo.

### 6.1 Los ocho elementos y sus estados

| elemento | origen | color (guía) | estado que deja en el ENEMIGO | estado que deja en el SUELO | extra propio |
|---|---|---|---|---|---|
| **fuego** | base | rojo/naranja | quemado (hoy) | quemada; prende hierba; seca mojado; derrite hielo a charco (hoy) | daño por tics (hoy) |
| **agua** | base | azul | mojado: ×0,75 velocidad, apaga (hoy) | mojada; sobre mojada → helada (hoy) | conduce el rayo (hoy) |
| **tierra** | base | ocre | ralentizado ×0,6 (hoy) | escombro: casilla sólida para proyectiles 6 s (B3) | ×1,15 impacto (hoy) |
| **viento** | base | verde pálido | interrumpe el ataque, empuja (hoy) | **limpia** mojada/quemada/electrificada (B3) | hunde al que empuja al agua (hoy) |
| **hielo** | agua + viento | celeste | congelado 1,5 s (hoy) | helada: puente, resbala (hoy) | congelado se puede **romper** (B1) |
| **rayo** | fuego + viento | amarillo/violeta | aturdido 1,2 s (hoy) | electrificada 6 s sobre mojada (A5) | salta al vecino a ≤ 4,5 u (hoy) |
| **magma** | fuego + tierra | naranja oscuro | quemado fuerte + atrapado al enfriar | lava 8 s → roca (nuevo suelo) | hereda fuego y tierra |
| **naturaleza** | agua + tierra | verde | envenenado 4 s (3/s) y ralentizado 2 s | — (sin estado de suelo propio) | hereda agua y tierra; antes era barro |

### 6.2 Elemento que LLEGA × estado que TIENE el enemigo

| llega ↓ / tiene → | sin estado | mojado | quemado | congelado | aturdido | embarrado |
|---|---|---|---|---|---|---|
| **fuego** | prende (hoy) | seca, «¡Vapor!» (hoy) | aviva +daño | derrite → mojado | — | cuece: embarrado → ralentizado largo |
| **agua** | moja (hoy) | — | apaga + vapor que ciega (B2) | — | — | — |
| **tierra** | ralentiza (hoy) | **embarra** (hereda barro) | — | **roto ×2** (B1) | tumba | — |
| **viento** | interrumpe (hoy) | seca | **llamarada**: contagia al vecino (B2) | **roto** (B1) | — | seca a ralentizado |
| **hielo** | congela (hoy) | congela 2,5 s ×1,5 (A1) | apaga + niebla | — | congela | congela el barro: atrapado sólido |
| **rayo** | aturde (hoy) | ×1,5 y salta (hoy) | explosión pequeña | **roto + metralla** (B1) | prolonga | nada (el barro aísla) |
| **magma** | quema fuerte | seca y quema | aviva | derrite y quema | — | cuece a roca: atrapado 3 s |
| **barro** | embarra | embarra (más tiempo) | apaga | — | — | — |

### 6.3 Elemento que LLEGA × estado del SUELO

| llega ↓ / casilla → | seca | mojada | helada | electrificada | quemada | barro | lava |
|---|---|---|---|---|---|---|---|
| **fuego** | prende hierba (hoy) | seca (hoy) | charco (hoy) | — | — | cuece a seca | — |
| **agua** | moja (hoy) | hiela (hoy) | nada (hoy) | apaga la carga | apaga (hoy) | — | enfría a roca (hoy, lava) |
| **tierra** | escombro (B3) | barro (hereda) | — | — | — | — | — |
| **viento** | — | seca (B3) | — | limpia (B3) | limpia (B3) | seca a seca | aviva |
| **hielo** | hiela (hoy) | hiela (hoy) | — | — | apaga | hiela (sólido) | enfría a roca |
| **rayo** | — | electrifica 6 s (A5) | — | renueva (hoy) | — | nada | — |
| **magma** | lava 8 s → roca | vapor + roca | derrite a mojada | — | — | roca | — |
| **barro** | barro | barro | — | apaga la carga | apaga | — | roca |

**Reglas de lectura:** cada celda es una fila en `EstadosSuelo3D.TRANSICIONES` (6.3) o una rama en `Combate3D.decidir_golpe` (6.2), y un rótulo + color en `PrevisionReaccion3D.ESTILO`. Las celdas vacías no reaccionan y la previsión no dice nada. Los estados nuevos del suelo que pide la tabla: **escombro**, **barro**, **lava** y **roca** (la lava y la roca ya existen en `Lava3D` como pieza; faltan como estado de casilla).
