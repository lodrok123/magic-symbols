# Catálogo de lo que YA HAY: gamefeel, hechizos y combate (22/11/2026)

22/11/2026 · contexto **dirección (análisis)** · **comprobado en el código**, no en los documentos. Es la base para el plan de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`: antes de proponer algo, mirar aquí si ya existe.

**Marcas:** **FALTA** = se buscó y no existe. **A MEDIAS** = existe en parte. **DOC ATRASADO** = un documento lo da por propuesto o nuevo y ya está programado. Las rutas son relativas a `E:\magic-symbols\`. Las cifras son `static var` o `const` y casi todas se pueden ajustar.

---

## 0. Lo más importante

1. **El código va por delante de los documentos.** `REFERENCIAS_JUEGOS_2026-11-21.md` marca como «PROP» o «NUEVO» muchas cosas que ya existen. Algunas son el golpe recibido escalado, la vida baja, la cámara lenta del último enemigo y el juice por potencia (E1). También la sobrecarga con su clic, el buffer de voltereta, el coste por glifo (A3), la previsión de tinta (E4), el golpe F que devuelve tinta (C5), hechizo contra hechizo (B5) y el tope de barreras (C4). **El gamefeel de impacto está casi completo.**
2. **La demo de tres elementos no está montada en el código.** «Nueva partida» abre `PruebaBosque02.tscn` con `kit="pruebas"` (6 elementos y 13 glifos). El kit «demo» (fuego, agua y tierra) solo lo usa el Pantano, que no tiene enemigos.
3. **Huecos de combate que se repiten en las propuestas:** no hay daño contra pared, barra de postura, rendimientos decrecientes, oleadas con aviso, tinta al matar, ni rebote de flechas en barrera o burbuja. Los escudos de elemento son uno solo (el de madera). Fuera del elemental, ningún enemigo tiene furia.
4. **Huecos de gamefeel:** la voltereta no cancela el final del lanzamiento (pasa al revés). El golpe F no tiene buffer. No hay vibración de mando, temblor direccional, imán de apuntado, posproceso al abrir el libro ni libro que reacciona en combate. La reaparición tarda ~2,5 s.
5. **Huecos de hechizos:** ⧖ no se puede dibujar a mano (solo con la paleta F1). Ningún cofre ni nivel da el libro avanzado. El lanzamiento inteligente no tiene menú.

---

## 1. Gamefeel

Casi todo vive en `presentacion/sensacion_3d.gd` (`Sensacion3D`). `ACTIVA` (l.33) lo apaga entero.

### 1.1 Entrada y respuesta
| Qué | Cómo está | Cifras | Dónde |
|---|---|---|---|
| Buffer de páginas 1/2/3 | Guarda la tecla mientras rueda, golpea o encaja un golpe | `BUFFER_PULSACION` 0,15 s | `magia/lanzador_3d.gd:198`, `:1043-1070` |
| Buffer de voltereta | Misma ventana; recuerda la dirección | 0,15 s | `jugador/jugador_3d.gd:1258-1270` |
| Buffer del golpe F | **FALTA**: si no puede, se pierde | — | `jugador_3d.gd:1272-1275` |
| Voltereta cancela el lanzamiento | **FALTA**: `_lanzando` bloquea la voltereta. Al revés sí: en tiempo bruja, lanzar corta la voltereta | — | `jugador_3d.gd:1256`, `:321-339` |
| Enfriamientos | Voltereta 1,5 s y 1 casilla. Golpe F dura 0,45 s y recarga 0,8 s | | `jugador_3d.gd:66-67`, `jugador/golpe_cuerpo.gd:16-17` |
| Voltereta perfecta (tiempo bruja) | Rodar en los últimos 0,6 s del aviso: mundo a ×0,3 durante 0,6 s, invulnerable, «¡Esquiva!», tinte violeta, copias y tic-tac | `VENTANA_ESQUIVA` 0,6 | `enemigos/aviso_ataque_3d.gd:21`, `jugador/tiempo_bruja.gd:15-16` |
| Aceleración y giro | Acelera a 12 u/s² y frena a 30. Gira a 600/720 °/s. Se inclina 6° al girar y 4° al frenar. En hielo patina | | `sensacion_3d.gd:143-144`, `jugador_3d.gd:77-82`, `presentacion/caminar_3d.gd:46-53` |
| Apuntado asistido (imán) | **FALTA**: `apuntado_3d.gd` solo dibuja la cinta y las retículas | — | `presentacion/apuntado_3d.gd` |
| Lanzamiento inteligente | Pulsar lanza hacia el ratón. **A MEDIAS**: solo se activa desde la paleta F1, sin menú | | `lanzador_3d.gd:204-210` |
| Cámara lenta al lanzar | Libro abierto ×0,3, apuntando ×0,3, mantener página ×0,7 | | `lanzador_3d.gd:46-55` |
| «No puedes» | Golpe seco, la página tiembla en rojo y el cursor se pone rojo 0,25 s | | `sensacion_3d.gd:475`, `presentacion/ui/page_hud.gd:35` |

### 1.2 Anticipación
- **Carga en la mano:** aro del color del elemento que se cierra y zumbido que sube de tono. `T_CARGA` 0,55. `sensacion_3d.gd:149-151`.
- **Sobrecarga:** mantener 0,8 s da potencia ×1,5 y cuesta tinta ×2, con temblor, clic, anillo y arco dorado en el HUD. `lanzador_3d.gd:59-65`, `:1348-1370`. **DOC ATRASADO.**
- **Telegrafía del enemigo:** se encoge antes de golpear (`ANTICIPA_ESCALA`, `combate_3d.gd:77`) y hay flechas en el borde de la pantalla para los avisos que quedan fuera (`sensacion_3d.gd:948`). Avisos en §3.2.

### 1.3 Impacto
| Qué | Cómo está | Dónde |
|---|---|---|
| Hitstop por daño | De 0,04 a 0,10 s (tope en 40 de daño o al acertar la debilidad); la jugadora se congela ×0,6 | `sensacion_3d.gd:196`, `combate_3d.gd:65-66` |
| Hitstop y temblor por potencia del hechizo (E1) | Al salir y al impactar: 0 / 0,06 / 0,12 s y temblor 0 / 0,10 / 0,20 | `sensacion_3d.gd:71-72`, `:523` |
| Destello por elemento | Blanco 0,05 s y luego el color 0,20 s (0,28 si es debilidad), con aplastamiento. Debilidad: flash de pantalla de 1 fotograma y ping | `combate_3d.gd:67-76`, `sensacion_3d.gd:432` |
| Empuje por masa | `v0 = fuerza × 2 × k_daño / masa` | `combate_3d.gd:42-50`, `:796` |
| Temblor de cámara | 5 sacudidas aleatorias; si coinciden varias, solo la mayor. Golpe 0,25 / debilidad 0,5. **Direccional: FALTA** | `presentacion/vfx_3d.gd:62`, `:2336`; `combate_3d.gd:51-53` |
| Retroceso de la lanzadora | Paso atrás 1,1 u/s (haz 1,6), la cámara retrocede de 2 a 6 px y zoom de golpe del 2,5 % | `sensacion_3d.gd:35-44`, `:206-281` |
| Arranque y estirón del proyectil | Con estela | `sensacion_3d.gd:78-82` |
| Partículas | Estrella de impacto, chorro direccional y polvo al empujar o caer | `vfx_3d.gd:2374`, `:2398` |
| Sonido del golpe | Tono aleatorio, varios archivos y veda de 70 ms. Cuerpo por familia (carne o piedra), más grave si es debilidad. **Capas transitorio/cuerpo/cola: A MEDIAS** | `nucleo/sfx.gd:399`, `nucleo/sfx_3d.gd:146`, `sensacion_3d.gd:993` |
| Vibración de mando | **FALTA** (no hay `start_joy_vibration`) | — |

### 1.4 Después del golpe
- **Muerte por elemento:** el fuego carboniza, el hielo rompe en 7 trozos, el rayo deja rígido, el agua escurre y la tierra deja polvo y grietas. Como mucho 3 por segundo. `combate_3d.gd:54-61`.
- **Cámara lenta del último enemigo:** ×0,3 durante 0,45 s, con zoom y sonido `sala_limpia`. `sensacion_3d.gd:104-108`, `:925`. **DOC ATRASADO.**
- **Reacción grande:** rótulo ×1,8, mundo congelado 0,12 s y temblor 0,4. `sensacion_3d.gd:110-113`, `:736`.
- **Rótulo de reacción (E2):** anillo y disco en el suelo, con tintineo. `presentacion/feedback_reaccion_3d.gd`.
- **Música de combate:** entra en 1,2 s y sale en 2,5 s.

### 1.5 La jugadora
- **Golpe recibido escalado (E3):** temblor de 0,2 a 0,5 según la vida perdida y hitstop de 0,05 s (0,12 s si baja del 25 %). Viñeta, sonido más grave y empujón. `sensacion_3d.gd:55-68`, `:495`. **DOC ATRASADO.**
- **Invulnerable** 0,4 s tras un golpe y 1,2 s al reaparecer. `jugador_3d.gd:39`, `:863`.
- **Vida baja:** latido por debajo del 34 %, borde rojo y barra que late por debajo del 25 %. `sensacion_3d.gd:129-131`, `presentacion/ui/hud_eow.gd:40-43`.
- **Muerte y vuelta:** ~2,55 s hasta reaparecer, más 0,5 s de salida (`presentacion/ui/pantalla_muerte.gd:17-21`). **No se cumple** la vuelta en menos de 2 s.

### 1.6 Interfaz
- **Barra de la jugadora** con franja fantasma, flash y pulso al curar. **Barra del enemigo** con retardo de 0,35 s. `presentacion/ui/barra_hud.gd:26-36`, `combate_3d.gd:3069`.
- **Números de daño** que saltan con el color del elemento; con debilidad ×1,45 y «!»; el daño continuo se suma. «Resistido» y reacción en el número: **FALTA**. `combate_3d.gd:1359-1409`.
- **Libro:** la mano pasa página en ≤0,45 s; abrir y cerrar con fundido. `presentacion/ui/spellbook.gd:650-666`, `:938`.
- **Libro que reacciona en combate: FALTA**. Solo reacciona el HUD de páginas (tiembla, destella al estar lista y lleva el arco de sobrecarga).
- **Posproceso al abrir el libro: FALTA** (solo baja el tiempo).

### 1.7 Cámara
- Ortográfica e inclinada 60°, tamaño 6 (mínimo 2), seguimiento exponencial. La rueda cambia el zoom. `presentacion/prueba_test2.gd:34-39`.
- Se adelanta al correr y al apuntar. El zoom al apuntar existe pero está apagado (`ZOOM_APUNTA` 0). Balanceo al correr. `sensacion_3d.gd:136-140`, `:309-313`.
- **Cámara confinada a la sala** (20/11, `presentacion/camara_salas.gd`): líneas `; camara x0,y0..x1,y1` en el mapa. Se frena en el borde de la sala y **solo se acerca** (hasta 3,5) si la sala no cabe. **Para C15 (jefes) falta lo contrario: abrir el encuadre** en una sala de jefe.

---

## 2. Hechizos y libro

### 2.1 Elementos y reacciones
- **6 sellos dibujables:** fuego ᚲ, agua ᛚ, tierra ᛗ, rayo ᛊ, hielo y viento ᚢ (`nucleo/gesture_library.gd:26`). El tiempo ᛟ queda para cinemáticas.
- **Kit «demo»:** fuego, agua y tierra; flecha, línea, barrera, altura, raido y suelo; 3 páginas y 6 glifos (`magia/lanzador_3d.gd:137`). **A MEDIAS**: solo lo usa el Pantano.
- **Sellos dobles** (`nucleo/combos_sellos.gd:18`): agua+viento = hielo, fuego+viento = rayo, fuego+tierra = magma y agua+tierra = naturaleza. Agua+fuego y tierra+viento se anulan sin cobrar. Solo con el libro avanzado; **ningún cofre lo da**.
- **Hechizo contra hechizo** (B5, `magia/hechizo_vivo.gd:62`, `CRUCES`): fuego en agua = vapor; viento en fuego = llamarada; rayo en agua = descarga; magma en agua = costra. **DOC ATRASADO.**

### 2.2 Glifos (`nucleo/sigils.gd:379-429`; topes en `nucleo/hechizo.gd:74-80`: 6 glifos, 8 m, 25 s, 8 copias)
| Glifo | Interno | Qué hace | Demo |
|---|---|---|---|
| ᛇ | flecha | Proyectil a 4 u/s, 2 casillas +1 por glifo | Sí |
| ᛁ | linea | Haz de 3 m +1 por glifo; con barrera alarga | Sí |
| ᛜ | barrera | Solidez ×1,5 por glifo; rodea a la jugadora | Sí |
| ᛏ / ⊥ | altura | Más alto (semieje Y) | Sí |
| ᚱ | raido («pulso») | Pulso de 4 casillas por glifo | Sí |
| ᛒ | suelo | Se planta en la casilla apuntada | Sí |
| ᚠ | repeticion | +1 copia | No |
| ᚢ | rebote | +1 rebote | No |
| ᚷ | pulso («crecer») | Crece y semiejes ×1,3 | No |
| ᛉ | permanencia | +2 s | No (cofre de la Gruta Permanencia) |
| ᚦ | perforar | Atraviesa enemigos; el haz atraviesa sólidos | No |
| ᛃ | retorno | Vuelve al acabar la ida | No |
| ᚨ | buscar | Imán con cono | No |
| ⧖ | retardo («carga») | +1 s de espera, más tamaño y potencia; disparador | No |
| — | posicion | Nace donde apuntas (experimental) | No |

- **Reglas R1–R5** (`hechizo_vivo.gd:27-36`): R1 la forma viaja con ᛇ; R2 ᛃ añade la vuelta; R3 copias que orbitan; R4 columna que eleva; R5 agua que crece estalla.
- **Orden de dibujo** (`hechizo.gd:25`): ᛇ antes de ᚠ = ráfaga; ᛜ antes de ᚷ = barrera que late (hecho, aunque el comentario de `hechizo.gd:250` diga que falta).
- **Disparador** (⧖ entre dos formas; `hechizo.gd:35-41`, `:455-507`; `hechizo_vivo.gd:1781-1814`): el hijo nace al impactar o al detenerse; profundidad 2. **FALTA:** dibujar ⧖ a mano (no está en `TrazosRectos.SELLOS`), que esté en el kit de la demo, que ᛒ pueda ser hijo y que el hijo sea de otro elemento.
- **Eventos** (`hechizo.gd:65`): al_nacer, al_golpear, al_matar, al_impactar, al_detenerse, al_expirar, al_rebotar, al_viajar.
- **Reflejo:** barrera + rebote devuelve una vez un hechizo de la jugadora (`hechizo_vivo.gd:1972`). **Tope de barreras:** 3 (`lanzador_3d.gd:68`).

### 2.3 Mundo y materia
- **Materia** (`nucleo/materia.gd`) con 6 materiales: madera, vegetal, piedra, metal, cristal y tela. **Formas de materia** (`hechizo_vivo.gd:48`): sólido, líquido, plasma, energía, gas y campo.
- **Estados del suelo** (`mundo/estados_suelo_3d.gd:149`): helada 20 s, electrificada 6, quemada 8, mojada 20, escombro 6 y vapor 4. Hay tabla de transiciones, topes y propagación.
- **ᛒ suelo** (`magia/glifo_suelo.gd:50`): hielo o tierra = plataforma o capa; el resto = trampa de un uso. Máximo 6 vivas.
- **Burbuja:** radio 1,3 u, revienta al primer golpe (`lanzador_3d.gd:82-91`).

### 2.4 Coste
- **Tinta** (`nucleo/dano.gd`): base 8 / 18 / 34 más un coste por glifo (A3, **DOC ATRASADO**). Recargos por copias, hijo (0,10) y continuo.
- **Barra** (`nucleo/tinta.gd:56-80`): 100 de inicio (techo 300), 3 frascos. Regenera 3/s, o 1/s en combate. +20 por reacción, una vez por enemigo y tipo.
- **Recarga de página:** la del glifo más lento +0,5 por glifo repetido (`sigils.gd:493`). **CastPoints:** tierra ×1,3 y rayo ×0,6 (`magia/cast_points.gd`).
- **Golpe F** devuelve +5 de tinta (+10 si el escudo ya ardió) (`jugador/golpe_cuerpo.gd:32`). **DOC ATRASADO.**

### 2.5 Libro y dibujo
- **Reconocimiento** por trazos rectos con 45° de tolerancia, con $P de respaldo, asistencia y rectificado (`nucleo/trazos_rectos.gd`, `magia/grimorio.gd:156`, `nucleo/gesture_assist.gd`).
- **Libros** (`spellbook.gd:115`): «bosque», con 3 huecos que se abren en orden, y «avanzado», con 2 medallones, corona de 6 huecos y dos zonas. **A MEDIAS**: nada llama a `cambiar_libro` fuera de las pruebas.
- **3 páginas**, guardadas en orden de dibujo (`nucleo/repertoire.gd:222`). El libro no se abre con enemigos cerca (`LIBRO_EN_COMBATE` = false).
- **Previsión** de reacciones, tinta y recarga antes de lanzar (`magia/prevision_hechizo.gd`, `presentacion/prevision_reaccion_3d.gd:76`). **DOC ATRASADO** (E4).

### 2.6 Lanzar y progresión
- **Mantener y soltar** 1/2/3 o pulsar con el lanzamiento inteligente (`lanzador_3d.gd:1040`, `:1077`). Una página necesita un glifo, salvo tierra sola (escalón).
- **Progresión:** cofres con `glifo=` (barrera en el Bosque 02 y la Gruta Batida, raido en la Cueva, permanencia en la Gruta Permanencia). El agua sale del encargo de Marimanta. Las mejoras dan más huecos.
- **No existen:** H1 (hijo de otra página), H10 (selector), H11 (ᛒ que viaja) ni H12 (dos círculos).

---

## 3. Combate

### 3.1 Enemigos
| Enemigo | Vida / DEF | Ataques y aviso | Débil / resiste | Especial | Dónde |
|---|---|---|---|---|---|
| Goblin guerrero (`combate_3d.gd:139`) | 50 / 2 | Golpe de 20; carga 0,6 s **sin aviso** y luego círculo de 1,7 u | En «Bosque*»: débil agua, resiste fuego | — | Bosque 02, Cueva |
| Goblin arquero (`:205`) | 50 / 2 | Flecha de 12 a 9 u/s; tensa 0,9 s sin aviso y el círculo la sigue | Igual | Variante fija de puesto (alcance 20, se asoma) | Bosque 02, Grutas |
| Goblin asesino (`:636`, `:2090`) | 50 / 2 | Dos cortes de 20 con aviso rectangular | Igual | — | Bosque 02 |
| Goblin con escudo (`escudo_3d.gd`) | DEF 5 | Los del guerrero | Fuego: el escudo arde 4 s | Para de frente (120°) | Solo ArenaCombate |
| Elemental del bosque (`combate_3d.gd:150`) | 500 / 6 | Puñetazo de 45 (aviso 1,83 s, **desfasado**, ver C22). Raíces bajo la jugadora (aviso 1,0 s). Enredaderas que lo curan | Débil fuego | El agua lo cura y lo agranda. Furia mientras arde. Por la espalda ×1,5. Una barrera que para el puñetazo lo aturde 1,5 s | Bosque 02 (santuario) |
| Gólem (`golem_3d.gd`) | 70 / 10 | Mazazo de 30, aviso 1,43 s | Inmune de pie | Daño solo con el núcleo expuesto o tumbado; resbala en hielo | SalaGolem |
| Limo (`limo_3d.gd`) | 30 / 0 | Acometida de 15 (30 si es grande), aviso 0,6 s | Toma el primer elemento | El fuego lo divide; el hielo lo hace bloque | SalaLimo |
| Chamán (`chaman_3d.gd`) | 30 / 0 | Flecha y bola de veneno | — | Cura, escuda (escudo de naturaleza que el fuego quema) y ataca; el ritual se corta si le pegan | Bosque 02, salas del chamán |
| Mouro espectro (`mouro_espectro_3d.gd`) | 45 / 1 | Toque de 12 que enraíza, aviso 0,7 s | — | Rebrota en la mámoa abierta | Solo ArenaCombate |
| Santa Compaña / ánimas | 25 / 0 | Toque sin aviso; maldición del guía con aviso 1,0 s | — | Matar las 3 en 2,5 s; la niebla atraviesa muros | Solo ArenaCombate |
| Canouro v2 (`canouro_v2.gd`) | 40 / 0 | Mordisco, aviso 0,4 s | En el Bosque 02: débil agua | La niebla lo protege ×0,5; el fuego se la quita y recibe ×1,5. Si la burbuja para el mordisco, queda aturdido | Bosque 02 |
| Loberno | 50 | Como el guerrero | Igual | Marcha de animal | Bosque 02 |
| Gatopedro | 45 / 0 | Huye | — | — | TerraFina |
| Dragón jefe (`objetos/dragon_jefe_3d.gd`) | 300 | Aliento: carga 0,9 s + anillos 0,8 s; **no usa `AvisoAtaque3D`** (no da tiempo bruja) | El agua lo aturde | Cristales y núcleo | SalaDragon (placeholder) |

**El Pantano no tiene enemigos**: solo una nube de veneno.

### 3.2 Ataques y avisos
- **`AvisoAtaque3D`:** círculo o rectángulo que se llena; mínimo 0,4 s; los últimos 0,6 s son la ventana de esquiva. **La carga previa no tiene aviso**: el guerrero y el arquero cargan sin marca y el aviso sale al empezar la animación.
- **Flechas:** la burbuja las revienta, el muro de viento las desvía y lo sólido las para. Al cruzar fuego se encienden (`combate_3d.gd:2336-2375`). La llamada a `quemar()` en la jugadora no existe: **A MEDIAS**.
- **Furia:** solo la tiene el elemental. Los demás: **FALTA**.

### 3.3 IA
- Ve a 5,75 u y suelta a 10 u. Calcula rutas por casillas y rodea las barreras de la jugadora (el elemental las embiste).
- Tiene miedo al fuego. Se ciega con vapor. Investiga el humo y los animales van al cebo.
- **Grupos:** el chamán apoya y los canouros se turnan. **Turnos de ataque entre goblins: FALTA.**

### 3.4 Defensa de la jugadora
- Vida 100, +20 por mejora; la vida **no se regenera sola**.
- **Voltereta:** invulnerable; con elemento deja un rastro en el suelo.
- **Golpe F:** 5 de daño, cono de 70°; rompe a ×2 lo congelado y la costra.
- **Burbuja:** para el primer golpe y devuelve su elemento. Su tabla de reacciones solo tiene agua↔fuego y hielo+fuego (`lanzador_3d.gd:82-91`, `burbuja_recibe` :2514, `solidez_para` :2192).
- **Consumibles:** poción de 40 (tarda 1,5 s y un golpe la corta), bálsamo que absorbe un golpe, antídotos, humo y cebo.

### 3.5 Daño y estados (`nucleo/dano.gd`)
- **Fórmula:** `D = B×E×G×X×R`, y luego la defensa: `máx(0,2·D, D−DEF)`.
- **E por elemento:** fuego 1,1 · agua 0,8 · tierra 1,15. **X por reacción:** sobre mojado ×1,5; roto ×2. **R:** débil ×1,5, resiste ×0,75.
- **Estados** (`combate_3d.gd:1017`): mojado, ardiendo, congelado, aturdido, enraizado, lento, costra, sofocado, cegado, veneno, llamarada, descarga y patinar.
- **Agua honda:** muerte al instante.
- **FALTA:** daño contra pared (C11), barra de postura y rendimientos decrecientes (C12).

### 3.6 Recursos
- Tinta +20 por reacción (8 tipos premiados).
- **Matar no da tinta: FALTA.** `ganar_jefe()` no la llama nadie.
- Botín y oro por enemigo en `nucleo/datos/botin_tablas.tsv:50-89`.

### 3.7 Terreno y trampas (dañan a los dos bandos)
- **Barril:** mecha de 1,2 s con aviso; 35 a los enemigos y 20 a la jugadora; explota en cadena.
- **Trampa dragón:** aviso de 0,5 s. **Trampa de flechas:** aviso de 0,35 s.
- En la demo solo hay barriles (campamento del Bosque 02).

### 3.8 Jefes y encuentros
- **`PresentacionJefe`** (rótulo y barra; vale para cualquier jefe): solo la usa el dragón. El elemental tiene barra grande pero no rótulo.
- **Salas cerradas:** piezas `vigia` y `cerrojo` (`escenas/puzle.gd:54-63`).
- **Oleadas o aparición con aviso: FALTA.**
- **Abrir la cámara en salas de jefe: FALTA** (ver §1.7).

---

## 4. Qué cambia en la lista de propuestas

| Propuesta | Lo que dice el código |
|---|---|
| C3 (tinta como tensión) | El coste por glifo y el golpe F que devuelve tinta **ya están**. Faltan las gotas al matar |
| C1 (escudos de elemento) | Existe uno, el de madera débil al fuego (solo en ArenaCombate) |
| C9 (rebote visible) | Solo rebotan en el muro de viento |
| C15 (encuadre de jefes) | La cámara por sala existe, pero solo acerca; falta abrir el encuadre |
| C22 (anticipación) | Además del desfase del elemental: la carga previa del guerrero y del arquero no tiene aviso, y el dragón no usa `AvisoAtaque3D` |
| G1 (cancelar y buffer) | El buffer de voltereta ya está; faltan el del golpe F y la cancelación |
| G2, G3 (golpe recibido, vida baja, cámara lenta) | **Ya hechos** |
| G5 (vibración) | Falta |
| G6 (libro que reacciona) | Falta; solo reacciona el HUD de páginas |
| H1b (disparador) | Existe, pero ⧖ no se puede dibujar a mano |
| Demo de tres elementos | El kit existe, pero la partida nueva va con el kit de pruebas |
