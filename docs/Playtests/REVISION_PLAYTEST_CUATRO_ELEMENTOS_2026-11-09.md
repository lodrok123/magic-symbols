# Revisión del playtest de cuatro elementos (9/11/2026)

Lectura de [PLAYTEST_CUATRO_ELEMENTOS.md](PLAYTEST_CUATRO_ELEMENTOS.md) contra el código de hoy. **Nada implementado**: esto es
una lista para marcar **sí / no / cambiar**, y lo que se apruebe se incorpora a ese documento (este se archiva).

El documento está bien: los puzles reutilizan piezas reales, los encuentros tienen respuesta preferente y salida alternativa, y
las ampollas están descritas con una regla de uso. Lo que sigue son **diez cosas que cambiaría** (casi todas porque el código no
está donde el documento supone) y **cinco que añadiría** (dos familias de objetos que faltan y el lazo que cierra el bucle).

---

## A · Lo que modificaría

### A1 · La carga de la ampolla se gastaría sola al abrir el libro

**Riesgo alto, es el fallo más fácil de cometer.** El único sitio donde se construye un hechizo con su daño y su forma es
`Lanzador3D.receta_de_ficha` (`magia/lanzador_3d.gd:844`)… y lo llama **también el grimorio** para pintar el resumen de la página
(`Grimorio._actualizar_resumen`). Si la carga se consume ahí, se gasta por mirar el libro.

> **Cambio:** el realce se **lee** en `receta_de_ficha` (para que la previsión lo muestre) y se **gasta** en `_preparar_pagina`,
> al lanzar de verdad. Escribirlo en el documento, no dejarlo al criterio de quien implemente.

### A2 · «Mantenerla al guardar y cargar» hoy no se cumple

El documento pide que la carga pendiente sobreviva al guardado. Pero las protecciones de consumibles
(`Consumibles.inmunidades` / `resistencias`) son `static var` y **no están en `Partida.guardar`**: lo único de consumibles que
viaja con la partida es `consumible_equipado` (`nucleo/partida.gd:147`).

> **Cambio:** si la carga tiene que sobrevivir, hace falta un campo en `Estado` y su línea en `guardar`/`cargar`. Mi
> recomendación: **para este playtest, que no sobreviva** (se dice en el documento) y se guarda la discusión para después; el
> tramo son 20 minutos y no se guarda en medio.

### A3 · El ×1,25 «a la dimensión indicada de su forma» es el trozo caro

Cada forma tiene su propio eje (`Sigils.FORM`: `reach`, `spread`, `origin`, `height`…) y la geometría efectiva la decide
`Receta3D`/`GeometriaV2`. «Ensanchar la bola», «ensanchar el haz» y «alargar el muro» no son el mismo cambio: son cuatro, cada
uno con su tope de construcción. Hay dos caminos más baratos y ya probados:

- **(a)** aplicar el operador **`amplificar`** que ya existe (`Sigils.OPERATOR`, `power 2.0`): una línea, sube daño **e**
  intensidad del dibujo, pero también sube la recarga de la página a 2 s;
- **(b)** un **`reach += 1`** sobre la receta: la forma crece sin tocar la recarga, en un solo sitio, y se valida solo para las
  formas del perfil.

> **Cambio:** empezar por **(b)** con las cuatro formas de la tabla (y dejar fuera las que no estén en el perfil, como ya dice el
> documento). El ×1,5 de daño se queda tal cual: eso sí es una línea al lado de `hechizo.dano *= tinta_.mult_dano(...)`.

### A4 · Las recetas por etiquetas no garantizan los ingredientes que la tabla nombra

`S1 calor>=4 con flor ardiente + seta asada` no es lo que hará el juego: `Sintesis.sugerir` rellena con **lo más barato de la
bolsa que tenga la etiqueta**, así que con `calor>=4` la ampolla puede salir de dos setas asadas y la jugadora nunca mirará la
flor. Para eso está la columna **`ancla`** (ingrediente obligatorio), que ya funciona.

> **Cambio:** poner ancla a las cuatro: `flor_ardiente` (S1), `flor_rocio` (S2), `cristal_tierra` (S3), `petalos` (S4).

### A5 · Los umbrales de agua y viento están calculados sobre una tabla flaca

Objetos con cada etiqueta hoy: `vital 18 · tierra 16 · tinta 12 · resonante 10 · calor 9 · **agua 7** · **viento 6** ·
proteccion 5 · electrico 5 · frio 5 · toxico 4 · raro 3`. Con `viento>=5` y `agua>=4` las ampollas de esos dos elementos salen
más difíciles de juntar que las de fuego y tierra **sin que nadie lo haya decidido**, y eso es precisamente el sesgo que el
playtest quiere medir.

> **Cambio:** antes de añadir recetas, etiquetar `alga_seca`, `alga_cargada` y `flor_luna` como `agua`, y `pluma`, `seda` y
> `panal` como `viento`; y bajar S3/S4 a `>=4` para que los cuatro cuesten lo mismo.

### A6 · Sin debilidades fijadas, la mitad de los encuentros no enseña nada

Desde el 6/11 (bloque A2) **no hay debilidad ni resistencia por defecto**: salen de
`Combate3D.DEBILIDAD_GOBLIN_POR_NIVEL`, que solo tiene la clave `"Bosque"`. Si la zona de prueba no se llama `Bosque*`, todos los
goblins entran **sin debilidad**, y E1/E3/E5/E7 se juegan con daño plano. El documento no dice a qué es débil ningún enemigo.

> **Cambio:** cada pieza de mapa de enemigo declara `debil=` / `resiste=` (`Combate3D.fijar_debilidad`, que ya usa la pieza
> `vigia`), y el documento lleva una columna con esos dos valores por encuentro. Propuesta, con la regla de que nadie sea débil a
> su propio elemento: chamán **fuego**, guerreros **agua**, arquero de puesto **tierra** (cobertura, no daño), gólem **rayo**,
> limo de fuego **agua**, limo de tierra **fuego**, elemental **fuego** (ya es así en V2).

### A7 · E8 «Viento hace resbalar al gólem» choca con su masa

El empuje es `v0 = fuerza × MULT_EMPUJE × ESCALA_EMPUJE × k_dano / masa`, y el gólem tiene **masa 3,3** (el valor que sustituyó al
antiguo multiplicador del elemental). El hielo cambia el rozamiento del suelo, pero **la fórmula del empuje no sabe que el suelo
es helado**: tal como está, el viento sobre hielo lo moverá casi igual que en seco.

> **Cambio:** o se mide primero y se decide un factor de suelo helado en el empuje, o E8 se queda como está hoy (segunda
> solución: la ventana tras el mazazo) y se le quita la promesa del deslizamiento. No prometer en el documento lo que la fórmula
> no hace.

### A8 · E2 ya está hecho (y conviene decirlo)

«Fuego divide al limo» **ya está implementado** (D3, 6/11: `enemigos/limo_3d.gd`, `DIVIDE_CON = "fuego"`, `BLOQUE_CON = "hielo"`,
`FRACCION_VIDA_HIJO 0.5`, señal `dividido`, y un pequeño con fuego muere). También está la regla de que no se divide si no hay dos
casillas libres.

> **Cambio:** E2 pasa de «prototipo» a «montar la sala», y **se añade la condición de espacio al montaje** (dos casillas libres
> alrededor, o el golpe será el de siempre y el encuentro no enseñará nada). Lo mismo con «hielo lo vuelve bloque empujable»: eso
> es una **pieza de puzle** gratis, y hoy no se usa en ningún puzle del documento (ver B4).

### A9 · Dos espacios de IDs que se pisan

Este documento usa `P1…P12` y `docs/PUZLES_LOGICA_Y_ASSETS.md` usa `P01…P09`, **y se solapan sin ser lo mismo**: el P4 de aquí
(galería del dragón) es el P05 de allí; el P6 de aquí (cornisa) es el P03 de allí.

> **Cambio:** prefijo propio para este tramo (`PT-F1`, `PT-A2`, `PT-T1`, `PT-V2`…), y en la fila, el ID del puzle original que
> reutiliza. Dentro de tres semanas nadie va a saber qué P4 es cuál.

### A10 · 20–25 minutos no caben

12 puzles + 8 encuentros + fabricación + patio final no es un tramo de 25 minutos, y el documento ya lo intuye (marca «primera
tanda» y «variantes»).

> **Cambio:** declararlo como **dos sesiones**: pasada 1 = `P1, P3, P5, P7, P9` + `E1, E3, E5, E7` + una ampolla + patio final
> (eso sí son ~25 min); pasada 2 = el resto, con el perfil ya conocido. Y medir aparte, porque la pasada 2 ya no mide
> descubrimiento.

---

## B · Lo que añadiría

### B1 · Objetos contra los estados (familia que falta entera)

El documento solo trae los cuatro realces. Hoy existen `antidoto` (veneno), `frescor` (calor), `abrigo` (frío) y las tres prendas
épicas, pero **de los estados que la jugadora sí sufre no hay cura ninguna**: `quemada`, `mojada`, `ralentizada` y `aturdida`
(los pone `Jugador3D.aplicar_estado`). Y hay un motivo de código: `Jugador3D.tiene_estado` y `curar_estado`
(`jugador/jugador_3d.gd:568` y `:573`) **solo conocen el veneno**, así que un objeto así se gastaría sin hacer nada.

| id | nombre | efecto | receta (`requiere` · ancla · oro) | dónde · se_conoce |
|---|---|---|---|---|
| `unguento_cortafuego` | Ungüento cortafuego | `cura_estado=quemada;inmune=quemada;dura=45` | `agua>=3,vital>=2` · `alga_cueva` · 0 | hoguera, alquimista · al entrar en una zona con calor |
| `sal_de_deshielo` | Sal de deshielo | `cura_estado=ralentizada;inmune=ralentizada;dura=45` | `calor>=3,tierra>=1` · `ceniza_geoda` · 0 | hoguera, alquimista · al entrar en una zona con frio |
| `aislante_de_resina` | Aislante de resina | `cura_estado=aturdida;inmune=aturdida;dura=30` | `proteccion>=3,electrico>=2` · `resina` · 0 | hoguera, alquimista · al tener los ingredientes |
| `polvo_secante` | Polvo secante | `cura_estado=mojada` (**solo cura**) | `tierra>=2,calor>=2` · `carbon` · 0 | hoguera, alquimista · al tener los ingredientes |
| `panacea_del_claro` | Panacea del claro | `cura_estado=todos;inmune=veneno,quemada;dura=60` | `vital>=8,raro>=4` · `savia_elemental` · 50 | alquimista · al tener los ingredientes |

Dos avisos: **`inmune=mojada` sería un error** (la jugadora necesita mojarse para conducir el rayo y para las reacciones de
suelo: por eso el polvo secante solo cura), y la **panacea obliga** a que `Consumibles._efecto_generico` acepte listas con comas y
la palabra `todos` — si no quieres abrir eso ahora, la panacea se cae y no pasa nada.

### B2 · Grados de poción (la otra familia que falta)

Hoy hay dos escalones (`pocion` 40, `pocion_grande` 80) más la mejora `cura_pocion`. Para un tramo de 25 minutos con cuatro
encuentros falta el escalón de abajo (que la hoguera sirva desde el minuto uno) y uno de arriba como premio del patio final.

| id | nombre | efecto | receta (`requiere` · ancla · oro) | dónde · se_conoce |
|---|---|---|---|---|
| `pocion_menor` | Poción menor | `cura=20` | `vital>=2` · — · 0 | hoguera · siempre |
| `pocion_suprema` | Poción suprema | `cura=140;dura=8;tasa=3` (cura y regenera) | `vital>=10,agua>=3` · `perla` · 40 | alquimista · `mejora:cura_pocion>=1` |
| `tonico_tinta_mayor` | Tónico mayor de tinta | `frascos=2` | `tinta>=6,resonante>=2` · — · 10 | alquimista · `mejora:frascos_tinta>=1` |
| `infusion_mayor` | Infusión mayor de brezo | `dura=20;tasa=4` | `vital>=6,viento>=2` · `helecho` · 0 | hoguera, alquimista · al tener los ingredientes |

Ojo con un detalle de código que las bloquea: `Consumibles.motivo_no` y `Consumibles.usar` tienen escrito a mano
`match id: "pocion", "pocion_grande"`, así que **una poción nueva no la bebería nadie**. Se arregla cambiándolo por
`if ef.has("cura")` y pasando siempre el id a `usar_pocion(id)` (ya lo acepta). `Objetos.CONSUMIBLES` en cambio se genera solo de
la tabla: ahí no hay que tocar nada.

### B3 · Un enemigo débil a un GLIFO, no a un elemento

Los ocho encuentros del documento se resuelven eligiendo **elemento**. Pero lo propio de este juego es el **glifo**, y eso no se
prueba en ninguna parte (ya está propuesto como D4 en PROPUESTAS_COMBATE).

> **Añadir enemigos de glifo**, que miden si la jugadora cambia **de forma** y no solo de color. La lista completa, un arquetipo
> por glifo del repertorio, está en **B3 bis** (abajo), con los cuatro que entrarían en la primera pasada.

### B4 · Un puzle que exija fabricar (el lazo que falta)

Tal como está el recorrido, la síntesis llega en el **paso 6 de 6** y es opcional: se puede jugar el tramo entero sin pisar la
hoguera, y entonces el playtest no mide el sistema de recompensas, mide el de puzles.

> **Añadir `PT-X1 · El pasillo envenenado`**: pasillo con nube de veneno que se repone cada 10 s y un cofre al fondo. Se cruza
> aguantando el daño **o** con un antídoto hecho en la hoguera con la baba que sueltan los limos del lavadero (`baba_limo` ya es
> el ingrediente del `antidoto` de hoy, y la receta se descubre «al tener los ingredientes»: se descubre sola). El cofre da el
> ingrediente épico de la ampolla que falte.
>
> Esto convierte el recorrido en un bucle: **enemigo → ingrediente → hoguera → puzle → recompensa**, que es lo que el playtest
> dice en su título que quiere probar. Y de paso estrena dos cosas implementadas y nunca ejercitadas: el descubrimiento de
> recetas y las nubes de veneno como terreno.

### B5 · Que los números los dé el PlayLog, no la memoria

La lista final pide anotar a mano «si se descubrió sin ayuda, tras una pista o con asistencia». Eso está bien para lo cualitativo,
pero las cuatro preguntas que de verdad deciden si el tramo está equilibrado son contables, y `PlayLog` ya escribe el evento
**`cast` con elemento y glifos**: el reparto de uso entre los cuatro elementos sale gratis.

> **Añadir tres eventos a `PlayLog`** (una línea cada uno) y una tabla de resultados al final del documento:
> `sintesis_hecha` (qué receta y dónde), `consumible_usado` (qué y en qué zona) y `puzle_resuelto` (qué flag y con qué pieza, para
> ver si se resolvió por la vía prevista o por un atajo). Sin esto, «¿se craftea algo o se llega al final con la bolsa llena?»
> se responde de oído.

---

## B3 bis · Enemigos por GLIFO: la lista entera

Esto sustituye y amplía B3. **Ninguno existe hoy**: es una lista de arquetipos para cribar. La columna de la derecha queda vacía
a propósito: el siguiente paso es cruzarla con bichos de las **leyendas de la península ibérica** para que cada uno tenga cara, nombre y
sitio, en vez de ser «el enemigo del glifo X».

**Tres reglas que cumple toda la lista:**

1. **Nada se cierra con llave.** Cada enemigo tiene una **salida alternativa** más costosa (más tinta, más tiempo, más riesgo).
   El glifo es el camino bueno, no el único: un jugador que no lo tenga aún pelea peor, no se queda encallado.
2. **El glifo se lee en el cuerpo del enemigo.** Si la respuesta es «perforar», el enemigo tiene que llevar algo *delante*. La
   silueta explica el glifo; el rótulo no.
3. **Un enemigo, un glifo.** Los que piden dos (columna + barrera, buscar + perforar) son élites de segunda pasada, no de la
   primera.

| runa | glifo | id provisional | cómo se comporta | por qué ese glifo lo resuelve | salida alternativa | reutiliza | ser (ver B3 ter) |
|---|---|---|---|---|---|---|---|
| ᛇ | **flecha** | `reventon` | corre directo a ti y **estalla al contacto**; cuerpo a cuerpo es un mal cambio | hay que matarlo **antes de que llegue**: alcance, y cada flecha suma una casilla (tope 6) | barrera para que estalle contra ella | `aviso_ataque_3d` | **Dip** |
| ◇ | **barrera** | `escupidor` | fijo a distancia, suelta ráfagas de tres proyectiles seguidos y no se mueve | la barrera **bloquea proyectiles** y deja avanzar; sin ella el pasillo es un embudo | cobertura del escenario, si la sala la tiene | `trampa_flechas_3d`, `guardian_barrera_3d` | **Cuélebre** |
| ᛁ | **línea** (haz) | `procesion` | tres bichos flacos que caminan **en fila india** por un carril y se reponen por un extremo | un trazo de línea los coge **a los tres de una pasada**; uno a uno llegan igual de rápido que mueren | matarlos por turnos, aguantando el goteo | haz (`SOLIDOS_CON_HAZ`, `Hechizo.haz`) | **Santa Compaña** |
| ᛏ | **altura** | `colgado` | se queda **por encima** del plano del suelo (cornisa, rama, vuelo bajo) y pica en vertical | sin altura el hechizo le pasa por debajo: es la prueba limpia de que ᛏ sube de verdad | esperar a que baje a picar (ventana corta) | `GeometriaV2.aviso_materia` | **Nuberu** |
| ᚷ | **crecer** | `enjambre_disperso` | muchos pequeños que **se abren en cuanto empiezas a dibujar**: el impacto puntual acierta a uno | lo que **crece mientras vive** los barre a todos aunque se separen | pulso ᚱ, si ya lo tienes | `colmena_3d`, limos pequeños | **Galtzagorriak** |
| ᚱ | **pulso** | `soterrado` | se entierra y solo asoma un instante para golpear; apuntarle es perder el turno | el pulso **no se apunta**: sale en área al final y lo saca del suelo | barrera encima del montículo y esperar | `estalagmita_pulso_3d`, `receptor_pulso_3d` | **Ramidreju** |
| ᛉ | **permanencia** | `rebrote` | muere y **vuelve a brotar en su casilla a los 4 s**, indefinidamente | hay que **ocupar la casilla** un rato: lo que se queda (zona, bloque, charco) impide el rebrote | matarlo y correr antes de que vuelva | `enredadera_3d`, `raices_elemental_3d` | **Mouro da mámoa** |
| ᚠ | **repetición** | `tres_cargas` | escudo de tres cargas que **se recarga entero a los 2 s** de dejar de recibir golpes | solo cae con **varios impactos seguidos**: una copia por glifo (hasta 4) | encadenar dos páginas a mano, si la recarga da | `escudo_3d` (vida propia) | **Herensuge** |
| Λ | **rebote** | `aculado` | pelea desde un nicho o una esquina donde **no hay tiro directo** | el rebote le llega por la pared; es el P09 llevado al combate | rodear, si la sala deja (con coste de posición) | pared sólida, `Hechizo` bounces | **Tartalo** |
| ᚦ | **perforar** | `escudero` | va **delante** de otro enemigo, con el escudo por delante, y no se separa de él | perforar **atraviesa** al escudero y le llega al de atrás (tope 3 enemigos) | matar al escudero primero, que es el que menos duele | `Escudo3D.bloquea_proyectiles` (ya bloquea el tiro frontal) | **Jentil con la losa** |
| ᛃ | **retorno** | `caparazon` | **invulnerable de frente**, blando por la espalda; siempre te encara | el proyectil **vuelve** y le pega en la espalda al pasar | pulso por detrás, o rodearlo mientras ataca | `escarabajo_coraza` de la propuesta anterior | **Tarasca** |
| ᚨ | **buscar** | `fatuo` | flota en zigzag y **nunca está donde apuntas**; parpadea | el proyectil **se imanta** al enemigo más cercano del cono (±60/90/120°) | área grande, mucho más cara en tinta | `Hechizo` buscar (ya en `lab_geometrias_3d`) | **Fogo fátuo** |
| — | **carga** (retardo) | `compas` | escudo que **abre y cierra con ritmo fijo** y bien telegrafiado | la carga **retrasa 1 s por glifo** y pega más: se prepara para que caiga en la ventana | acertar a mano en la ventana, sin el extra de daño | `aviso_ataque_3d` (el telegrafiado ya existe) | **Basilisco** |
| — | **posición** | `nidal` | no pelea: **pone crías** desde un nido que está fuera del eje de tiro | posición **nace donde señalas**: se golpea el nido, no al bicho | matar crías sin parar (no acaba nunca) | `nido_3d`, `colmena_3d` | **Cabra Cabriola** |
| — | **atracción** | `huidizo` | mantiene la distancia, retrocede en cuanto te acercas y dispara desde el borde | la atracción **tira de él** y lo saca de su sitio (al agua, a la lava, a tu alcance) | acorralarlo contra una pared de la sala | `atraccion` (`Sigils`), `lava_3d` | **Mãe d'Água** |
| — | **espejo** | `pinza` | **dos a la vez, uno delante y uno detrás**, sincronizados | el espejo sale **también hacia atrás**: una página para los dos | girarse entre golpe y golpe, perdiendo tiempo | pareja de guerreros, IA actual | **Caballucos del Diablu** |
| — | **amplificar** | `coraza_umbral` | **ignora todo golpe por debajo de un umbral** (se ve: el impacto rebota sin número) | amplificar **duplica el daño** del hechizo: hay que pasar el umbral en **un** impacto | golpe F cargado, si llega al umbral | fórmula de `Dano` (DEF), `Combate3D._numero` | **Ojáncanu** |

**Los cuatro que elegiría para la primera pasada** (ver el cruce con mitología en B3 ter, que cambia tres de ellos), porque
enseñan cosas distintas y ninguno pide piezas nuevas de peso:
`escudero` (ᚦ, y ya hay `Escudo3D` con tiro frontal bloqueado), `caparazon` (ᛃ), `tres_cargas` (ᚠ) y `coraza_umbral`
(amplificar, que es puro número). Los otros trece son para la segunda pasada y para el cruce con mitología.

**Lo que esta lista mide**, y que ninguna de las dos listas por elemento mide: si la jugadora entiende que el grimorio se
**prepara**. Un enemigo de elemento se resuelve cambiando de página; uno de glifo se resuelve **rehaciendo la página**, y eso
solo se hace si el juego lo pide alguna vez.

---

## B3 ter · El cruce con las leyendas de la península ibérica

Un ser por arquetipo, **solo de la península** (9/11: decisión de Pablo de priorizar lo peninsular). El fondo céltico sigue
dentro, pero por donde le toca: Galicia, Asturias y Cantabria. Los cuatro irlandeses y galeses de la primera versión
(Abhartach, el ojo de Balor, Caoránach y el Afanc) salen y entran cuatro peninsulares en su sitio; el mouro, la cabra y la madre
del agua traen además a Portugal, que faltaba.

La regla del cruce no cambia: **el mito tiene que pagar el glifo**. No vale ponerle un nombre bonito a `tres_cargas`;
si el bicho elegido no trae de su leyenda la razón por la que ese glifo es la respuesta, no sirve y se busca otro. Por eso la
última columna es la importante: dice **qué cambia del arquetipo** al adoptar el mito, y en tres casos el mito mejora la mecánica.

| runa · glifo | ser | de dónde | qué del mito paga el glifo | cambia respecto al arquetipo |
|---|---|---|---|---|
| ᛇ **flecha** | **Dip** | Cataluña (Pratdip) | perro del diablo, cojo, que se abalanza para chupar la sangre del ganado | **sí**: en vez de estallar, al llegar **se engancha** y drena mientras no te lo quitas de encima. Mismo requisito (matarlo antes de que llegue) y mejor lectura: la cojera hace legible su carrera |
| ◇ **barrera** | **Cuélebre** | Asturias, Cantabria | serpiente alada que guarda el tesoro **desde la boca de su cueva** y escupe a lo que se acerca | no: es el escupidor fijo, ya escrito. La cueva da el embudo gratis |
| ᛁ **línea** | **Santa Compaña** | Galicia | procesión de ánimas **en fila**, guiada por el que lleva la cruz, que no puede soltarla hasta pasarla a otro | **sí, y para bien**: al matar al guía, **la cruz pasa al siguiente** y la fila sigue. El puzle deja de ser «mátalos» y pasa a ser «cógelos a todos de una pasada o no acaba nunca»: exactamente lo que ᛁ premia |
| ᛏ **altura** | **Nuberu** | Asturias | el hombre de las nubes: trae el granizo **desde arriba**, y cuando pierde el sombrero cae y queda a merced | no: el arquetipo pedía justo eso. La salida alternativa («esperar a que baje») **ya está en el mito** (tirarle el sombrero) |
| ᚷ **crecer** | **Galtzagorriak** | País Vasco (gemelos: los **minairons** del Pirineo catalán y aragonés) | diablillos rojos que se guardan en un alfiletero y, suelta la tapa, **se multiplican y se desparraman** si no se les da trabajo | no: es el enjambre que se abre al ver el trazo. El alfiletero es el generador de la sala |
| ᚱ **pulso** | **Ramidreju** | Cantabria | bicho alargado, nacido de una comadreja muy vieja, que **excava** y sale a buscar lo enterrado | no: topo que asoma un instante. El mito explica por qué no se le puede apuntar |
| ᛉ **permanencia** | **Mouro espectral** (el mouro da mámoa) | Galicia y norte de Portugal | el mouro encantado **vuelve a su túmulo** mientras la mámoa siga abierta; se acaba con él cerrándola, no matándolo | no, y es el mejor encaje de la lista: «ocupar la casilla» es literalmente **tapar la mámoa**, y el montículo marca la casilla sin necesidad de rótulo |
| ᚠ **repetición** | **Herensuge** | País Vasco | dragón de **siete cabezas** que rebrotan si no se le remata | **sí**: las tres cargas pasan a ser **tres cabezas**, y «se recarga el escudo» pasa a ser «la cabeza vuelve a crecer». Más legible de lejos que una barra de escudo |
| Λ **rebote** | **Tartalo** | País Vasco | cíclope que pelea **metido en su cueva** y tapona la entrada; al héroe solo le queda el ingenio | no: nicho sin tiro directo. Tiene la pared del rebote por definición |
| ᚦ **perforar** | **Jentil con la losa** | País Vasco (jentilak / mairuak) | gigantes que levantaron los dólmenes y **tiraban piedras**: uno avanza con la losa por delante | no: la losa **es** el escudo, y que perforar atraviese la piedra es la fantasía del glifo |
| ᛃ **retorno** | **Tarasca** | Península (dragón de Corpus) | dragón-tortuga de caparazón que desfila: **impenetrable por arriba y por delante**, blando debajo y detrás | no: el caparazón ya estaba en el mito antes que en la mecánica |
| ᚨ **buscar** | **Fogo fátuo** | Galicia (las *luces de ánimas* del resto de la meseta son lo mismo) | luz que baila, **nunca está donde parece** y lleva al caminante al tremedal | no. Ojo: su hermano el **carbunclo** (la piedra que brilla en la frente) sirve de recompensa visible |
| **carga** (retardo) | **Basilisco** | toda la península (castellano, catalán, portugués) | nace del huevo de un gallo y **mata con la mirada**: el peligro no es su cuerpo, es el instante en que abre los ojos | no, y el telegrafiado sale del mito: los párpados **son** el compás. Nota para después: que se mate **enseñándole su reflejo** apunta a la barrera que refleja (`rebote` + barrera), si algún día se quiere mover de glifo |
| **posición** | **Cabra Cabriola** | Portugal (y el *Papão* como prima) | no pelea: manda a **sus cabritos** desde la cueva donde se esconde, y a ella hay que ir a buscarla | no: se golpea la cueva/el nido, no a las crías |
| **atracción** | **Mãe d'Água** | Portugal (hermana de la *moura da fonte* gallega) | la madre del agua **tira de quien se asoma** a la poza y se lo lleva al fondo | **sí, y para bien**: su tirón es su ataque, y el jugador le devuelve el suyo. Es **invulnerable mientras está en el agua honda** (ahí se cura): hay que sacarla a la orilla. Reutiliza `nivel_agua_3d` y hace del agua un terreno, no un decorado |
| **espejo** | **Caballucos del Diablu** | Cantabria (noche de San Juan) | siete caballos del diablo que cruzan el cielo; **dos de ellos** te toman por delante y por detrás | no: la pinza sincronizada. Dos de los siete, no los siete |
| **amplificar** | **Ojáncanu** | Cantabria | gigante de un ojo, fuerza descomunal, al que **solo se mata arrancándole su único pelo blanco**: los golpes pequeños no le hacen nada | no: el umbral de daño **es** el pelo blanco. Y da la señal visual gratis (el pelo se ve) |

**Reparto**, para que no se note que vienen de un sitio: País Vasco 4 · Cantabria 3 · Portugal 2 (+1 compartido con Galicia) ·
Asturias 2 · Galicia 2 · Cataluña 1 (+1 gemelo pirenaico) · pan-ibéricos 2 (Tarasca y Basilisco). Diecisiete seres, ninguno
repetido, ninguno inventado y ninguno de fuera de la península.

**Encaje con el lore (9/11, Pablo):** en el juego **los mouros ya existen y son los «elfos»**, así que el de ᛉ no es una criatura
nueva sino **un mouro muerto**: misma familia que `elfo_base`, señorío antiguo y seco, no un fantasma genérico. La Santa Compaña
se respeta tal como es en la leyenda y lo que cambia es el aspecto: **espectral y no-muerto**, no aldeanos con vela. Los modelos
de los dos están encargados en [`arte/meshy/PROMPTS_MOUROS_SANTA_COMPANA.md`](../../arte/meshy/PROMPTS_MOUROS_SANTA_COMPANA.md)
(siete piezas: los dos personajes, la cruz y el candil sueltos, la mámoa, su losa, y la lista de lo que NO se pide a Meshy
porque es material de Godot).

**Aviso de reparto:** el País Vasco carga con cuatro (galtzagorriak, Herensuge, Tartalo y el jentil) y tres de ellos son
gigantes o dragones. Si se quiere repartir más, el **Tartalo** (Λ rebote) es el más fácil de sustituir por su primo gallego el
**Olláparo**, que es el mismo cíclope de cueva.

**Los cuatro de la primera pasada, revisados tras el cruce.** Cambian tres respecto a B3 bis, porque el mito los hace más
legibles por el mismo precio:

| orden | ser | glifo | por qué este y no otro |
|---|---|---|---|
| 1 | **Jentil con la losa** | ᚦ perforar | `Escudo3D` ya bloquea el tiro frontal: es el más barato de todos y la losa se lee a diez metros |
| 2 | **Herensuge** | ᚠ repetición | tres cabezas que rebrotan explican el glifo sin un rótulo; sustituye al `tres_cargas` abstracto |
| 3 | **Ojáncanu** | amplificar | puro número (umbral de daño) + una señal visual que ya existe; sustituye al `coraza_umbral` |
| 4 | **Santa Compaña** | ᛁ línea | el único que convierte el glifo en un **problema** y no en una ventaja, y encaja con el haz que ya está hecho |

La **Tarasca** (ᛃ retorno) se queda a las puertas: es la que más arte pide de las cinco.

**Tres seres que no entran, pero que apuntan a mecánicas que no tenemos** (los dejo escritos para no perderlos):

- **Trasgu / Trasgo** (Asturias, Galicia): tiene un **agujero en la mano izquierda**, así que todo lo que carga se le cae. Es un
  ladrón: te roba un objeto de la bolsa y hay que golpearlo para que lo suelte. Toca `Estado` y el botín, no el grimorio.
- **Guaxa** (Asturias): bruja chupadora con **un solo diente**; mientras lo conserve, se cura de todo lo que le hagas. Un enemigo
  con una **parte que hay que romper antes** de poder matarlo (hermano del escudo, pero dentro del cuerpo).
- **Xana** (Asturias): no es un enemigo, es una **recompensa con condición**: encantada en la fuente, suelta su tesoro si se la
  desencanta de la forma correcta (y si se falla, el oro se vuelve carbón). Encaja con el cofre legendario por secuencia.

---

## C · Dependencias comprobadas hoy en el código

Para que la implementación no descubra esto a mitad:

| lo que el documento supone | cómo está de verdad |
|---|---|
| Fuego divide al limo | **hecho** (D3, 6/11, `enemigos/limo_3d.gd`) |
| Hielo vuelve el limo bloque empujable | **hecho** (misma tanda) — y sin usar en ningún puzle |
| La barrera aturde al elemental | **hecho** (regla 6 de ELEMENTAL_V2) |
| `Sintesis` lista para fabricar | **hecha la lógica, no hay interfaz**: el documento ya lo dice. La API que tiene que pintar el panel es `conocidas(donde)`, `puede(id, eleccion)`, `sugerir(id)`, `hacer(id, eleccion)` y las señales `descubierta/hecha/aviso/sintesis_abierta` |
| Los consumibles nuevos aparecen en el HUD | **sí, solos**: `Objetos.CONSUMIBLES` se genera de `uso = equipar` en la tabla |
| Curar estados de la jugadora | **solo veneno** (`jugador_3d.gd:568`, `:573`) |
| Pociones nuevas bebibles | **no**: `match id` escrito a mano en `Consumibles` |
| Debilidad por defecto de los goblins | **no hay** desde el 6/11; solo la clave `"Bosque"` |
| Estado de zona `calor` / `frio` para `frescor` y `abrigo` | declarados en `estados_mundo.tsv`, **nunca ejercitados en una zona de prueba** |
| La carga pendiente sobrevive al guardado | **no**: las protecciones son `static` y no entran en `Partida.guardar` |

---

## D · Checklist

Marca: **sí** / **no** / **cambiar: …**

| # | qué apruebo | marca |
|---|---|---|
| 1 | A1 · Leer el realce en `receta_de_ficha`, gastarlo en `_preparar_pagina` | |
| 2 | A2 · La carga **no** sobrevive al guardado en este playtest | |
| 3 | A3 · La forma crece con **`reach += 1`** (no con `amplificar`, no eje por eje) | |
| 4 | A4 · Ancla obligatoria en las cuatro ampollas | |
| 5 | A5 · Etiquetar 6 ingredientes más de agua y viento, y bajar S3/S4 a `>=4` | |
| 6 | A6 · Columna `debil=` / `resiste=` por encuentro, con la propuesta de reparto | |
| 7 | A7 · Quitar el deslizamiento del gólem de E8 (o medirlo antes) | |
| 8 | A8 · E2 pasa a «montar», con la condición de dos casillas libres | |
| 9 | A9 · Prefijo `PT-` para los IDs de este tramo | |
| 10 | A10 · Dos pasadas declaradas, con la primera tanda cerrada en ~25 min | |
| 11 | B1 · Los cinco objetos anti-estado + ampliar `curar_estado` a los cuatro estados | |
| 12 | B2 · Los cuatro escalones de poción/tónico + arreglar el `match id` | |
| 13 | B3 ter · Los cuatro de la primera pasada: **Jentil con la losa** (ᚦ), **Herensuge** (ᚠ), **Ojáncanu** (amplificar), **Santa Compaña** (ᛁ) | |
| 13b | B3 ter · Los tres cambios que trae el mito: Dip se engancha en vez de estallar · la Santa Compaña se pasa la cruz · la Mãe d'Água es invulnerable en el agua honda | |
| 13c | B3 ter · Guardar `Trasgu`, `Guaxa` y `Xana` como mecánicas para más adelante (no son del grimorio) | |
| 14 | B4 · `PT-X1` el pasillo envenenado, para cerrar el bucle con la síntesis | |
| 15 | B5 · Tres eventos nuevos de `PlayLog` y tabla de resultados | |

Orden de implementación si se aprueba (cada paso deja probado lo que usa el siguiente):

1. **Tablas y estados**: etiquetas (A5), filas de B1/B2, `curar_estado` ampliado, el `match id` de `Consumibles`.
2. **El realce**: A1 + A3, con prueba headless propia (es el único sistema nuevo).
3. **El panel de la hoguera**: lo que de verdad cuesta, y sin él no hay síntesis jugable.
4. **Encuentros**: A6, A7, A8, B3 — todo sobre `Combate3D`, que ya tiene lo que hace falta.
5. **Puzles y recorrido**: la primera tanda + `PT-X1`, y B5 para poder leer la sesión.
