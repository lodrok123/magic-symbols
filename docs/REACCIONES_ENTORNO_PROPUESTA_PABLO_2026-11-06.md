# Magic Symbols — Sistema de reacciones elementales con el entorno

**Documento de diseño técnico · Versión de propuesta 1.1 · 6 de noviembre de 2026**  
**Estado:** propuesta para prototipo; no representa una implementación verificada en Godot.

## 0. Propósito y decisiones de partida

Diseñar reacciones emergentes entre **hechizos**, **materiales**, **estados ambientales** y **objetos interactivos**, de modo que las mismas reglas sirvan para combate, exploración y puzles sin escribir una receta especial por cada combinación.

### Reglas de diseño asumidas

- El juego es **3D** (X, Y, Z). Se controla especialmente la construcción/elevación en **Y**, con una altura jugable objetivo de **1–2 niveles**. No se limita artificialmente la puntería 3D de un proyectil.
- El núcleo dispone de **hasta dos sellos** y el modificador de **hasta seis glifos**, con orden irrelevante. Los glifos repetidos potencian su propia variable.
- Cuatro sellos básicos: **Fuego, Agua, Tierra, Aire**. Sus fusiones válidas: **Fuego+Tierra=Magma**, **Fuego+Aire=Rayo**, **Agua+Tierra=Naturaleza**, **Agua+Aire=Hielo**. **Fuego+Agua y Tierra+Aire se anulan dentro de una misma receta.** Dos hechizos independientes de elementos opuestos *sí* pueden interactuar en el mundo.
- Cada hechizo parte de una pequeña geometría **esférica 3D de radio `R0`**; no es necesario un glifo Esfera. Geometría: **Radio, Línea, Altura**. Propiedades: **Flecha, Barrera, Permanencia, Pulso, Repetición, Rebote, Elevación**. Primer glifo Elevación: activa la flotación con desplazamiento Y adicional nulo; sucesivos añaden altura.
- Los **sellos** aportan efectos intrínsecos (quemar, mojar, conducir, solidificar, empujar, crecer…) y multiplicadores sobre atributos del `Hechizo` base. Los **glifos** determinan forma, distribución, movimiento, contacto y duración. La reacción ambiental depende del elemento resultante, del material y del estado real del objetivo.
- Una reacción no debe resultar automáticamente de cualquier contacto: necesita **umbral, intensidad, dosis, material compatible y/o condición ambiental**, según el caso.

### Alcance de “todas las posibles reacciones”

El número literal de combinaciones aumenta sin límite al incorporar nuevos objetos, estados, glifos y cadenas de eventos. Este documento cubre **sistemáticamente las 8 familias elementales frente a 16 familias de materiales/objetos** (128 cruces), más estados, interacciones elementales cruzadas, cadenas y ejemplos aplicados. El motor debe resolver futuros cruces mediante **rasgos, reglas declarativas y prioridades**, sin ampliar indefinidamente una matriz codificada a mano.

---

## 1. Esquema elemental y semántica

| Elemento | Receta de sello | Aporte físico o energético | Identidad jugable | Estados que puede inducir |
|---|---|---|---|---|
| Fuego | Fuego | Calor, ignición | Daño sostenido / combustión | Caliente, ardiendo, seco |
| Agua | Agua | Humedad, enfriamiento, presión | Apagado, mojado, arrastre | Mojado, enfriado, barro |
| Tierra | Tierra | Material denso, impacto, cobertura | Soporte y obstáculo | Cubierto, comprimido, obstruido |
| Aire | Aire | Impulso, flujo y ventilación | Empuje, ventilación, secado | Desplazado, ventilado, seco |
| Magma | Fuego + Tierra | Material fundido, intenso calor | Zona peligrosa persistente | Caliente, ardiendo, recubierto, solidificado |
| Rayo | Fuego + Aire | Impulso eléctrico | Redes conductoras y activación | Cargado, electrificado, aturdido |
| Naturaleza | Agua + Tierra | Crecimiento vegetal / raíces | Enredar y transformar terreno apto | Enraizado, cubierto de vegetación |
| Hielo | Agua + Aire | Frío, escarcha, hielo | Superficies, inmovilización | Enfriado, congelado, escarchado |

**Importante:** Hielo formado por Agua+Aire y Rayo por Fuego+Aire obedecen a una lógica **fantástica**, no a una transformación termodinámica general. Son reglas internas consistentes del mundo mágico.

### 1.1 Fusión de sellos frente a reacción ambiental

| Situación | Ejemplo | Resultado |
|---|---|---|
| Dos sellos en **una receta** | Fuego + Agua | **Anulación**; no se manifiesta el hechizo |
| Dos sellos en **una receta** | Tierra + Aire | **Anulación**; no se manifiesta el hechizo |
| Dos hechizos **independientes** | Fuego impacta una zona previamente mojada | Evaporación/enfriamiento según dosis; no se anula la receta |
| Dos hechizos **independientes** | Tierra impacta aire en movimiento | La estructura puede frenar o desviar el flujo; no se anula la receta |

---

## 2. Contrato de datos del entorno

### 2.1 MaterialReactivo — rasgos estables

Cada objeto expone datos configurables (preferentemente `Resource`):

| Campo sugerido | Tipo | Dominio | Para qué sirve |
|---|---|---|---|
| `material_id` | `StringName` | Identificador | Seleccionar perfil base |
| `tags` | `Array[StringName]` | Ej. `wood`, `organic`, `metal` | Resolver reglas genéricas |
| `flammability` | `float` | 0–1 | Susceptibilidad de ignición |
| `fuel` | `float` | ≥0 | Cuánto puede sostener un incendio |
| `water_absorption` | `float` | 0–1 | Cuánto se moja |
| `water_capacity` | `float` | ≥0 | Humedad máxima local |
| `thermal_response` | `float` | >0 | Cambio térmico por dosis |
| `electrical_conductivity` | `float` | 0–1 | Propagación de carga |
| `freeze_compatibility` | `float` | 0–1 | Facilidad para congelarse o cubrirse de hielo |
| `growth_support` | `float` | 0–1 | Permite germinar/enraizar |
| `porosity` | `float` | 0–1 | Retiene líquido / admite barro |
| `hardness` | `float` | ≥0 | Resistencia a golpes/erosión |
| `fracture_threshold` | `float` | ≥0 | Ruptura estructural |
| `movable` | `bool` | Sí/no | Responde al empuje |
| `anchored` | `bool` | Sí/no | Puede desplazarse o no |
| `supports_weight` | `bool` | Sí/no | Puede funcionar como plataforma |
| `permanent_changes_allowed` | `bool` | Sí/no | Persistencia de cambios de mapa |
| `reaction_allowlist` | `Array[StringName]` | Opcional | Restricciones de un puzle concreto |

**Evitar:** el nombre del objeto como condición principal (`if objeto == puerta_2`); usar rasgos (`metal`, `conductive`, `locked`, `powered`) y componentes de interacción.

### 2.2 EstadoElemental — propiedades cambiantes

| Campo | Tipo | Rango sugerido | Interpretación |
|---|---|---|---|
| `wetness` | `float` | 0–1 | Grado de humedad |
| `temperature` | `float` | −1 a +1 | Frío/calor *abstracto* respecto al entorno |
| `charge` | `float` | 0–1 | Carga eléctrica residual |
| `growth` | `float` | 0–1 | Progreso de crecimiento |
| `frozen_fraction` | `float` | 0–1 | Parte congelada |
| `mud_fraction` | `float` | 0–1 | Grado de embarramiento |
| `burning` | `bool` | Sí/no | Combustión actualmente activa |
| `rooted` | `bool` | Sí/no | Movimiento restringido por raíces |
| `covered` | `StringName` | `none`, `earth`, `ice`, `magma`, etc. | Revestimiento temporal |
| `integrity` | `float` | 0–máx. | Estado estructural |
| `fuel_remaining` | `float` | 0–máx. | Combustible que queda |
| `reaction_cooldowns` | `Dictionary` | ID → tiempo | Antibucle / dosificación |

**Estados derivados**, no variables independientes: `mojado = wetness ≥ umbral`; `seco = wetness ≤ umbral_seco`; `caliente = temperature ≥ umbral_calor`; `electrificado = charge ≥ umbral_carga` durante un intervalo. Evitar estados contradictorios simultáneos sin una regla de precedencia.

### 2.3 Tipos de interacción

1. **Contacto puntual:** golpe de proyectil.
2. **Contacto continuo:** barrera/área persistente, con dosis por segundo.
3. **Superposición volumétrica:** charco, niebla, nube de fuego, hielo.
4. **Vecindad y transmisión:** conducción eléctrica, propagación de incendio, calor, raíces.
5. **Interacción con mecanismos:** interruptores, puertas, bombas, molinos, circuitos.
6. **Contacto contra un estado previo:** por ejemplo Hielo sobre Mojado, Fuego sobre Congelado.

---

## 3. Matriz extensa de reacciones ambientales

**Leyenda:** `—` = sin efecto especial (puede haber impacto, empuje o daño normal); `(*)` = requiere condición/umbral; `TEMP` = cambio temporal por defecto; `PERM` = posible solo con habilitación explícita del objeto.

### 3.1 Materiales orgánicos y naturales

| Objetivo / material | Fuego | Agua | Tierra | Aire | Magma | Rayo | Naturaleza | Hielo |
|---|---|---|---|---|---|---|---|---|
| **Árbol / tronco seco** | Incendia (*) | Humedece | Golpea / cubre | Balancea; aviva fuego (*) | Quema y carboniza (*) | Descarga si mojado (*) | Enreda con lianas (*) | Escarcha; fragiliza ramas (*) |
| **Árbol / tronco húmedo** | Seca antes de arder | Aumenta humedad | Golpea / cubre | Seca gradualmente | Quema intensa (*) | Conduce por superficie mojada (*) | Favorece raíces/lianas (*) | Escarcha |
| **Hierba / maleza seca** | Prende y propaga (*) | Humedece / apaga | Sepulta / aplasta | Arrastra semillas; aviva (*) | Calcina | Descarga si húmeda (*) | Crece / enreda | Congela follaje |
| **Planta viva / enredadera** | Quema / corta propagación | Hidrata | Cubre / da soporte | Agita / desplaza | Quema | Descarga si mojada (*) | Crece / engancha | Ralentiza crecimiento; congela |
| **Tierra fértil / suelo** | Seca / esteriliza temporalmente (*) | Humedece; barro (*) | Eleva/cubre terreno TEMP | Levanta polvo si seca | Calcina / costra (*) | Descarga superficial débil | Germina si húmeda (*) | Endurece / escarcha |
| **Tierra seca / polvo** | Seca todavía más | Humedece; barro (*) | Montículo / muro TEMP | Nube de polvo | Costra caliente | Sin conducción especial | Crecimiento solo si humedecida (*) | Endurece superficie |
| **Arena** | Calienta / vitrifica solo alta potencia (*) | Humedece / compacta | Mezcla o compacta | Tormenta de arena (*) | Vidriado local (*) | Baja conducción | Crece solo si suelo preparado (*) | Escarcha pasajera |
| **Roca / piedra** | Calienta | Enfría / moja fisuras | Refuerza o fractura por impacto (*) | — | Recalienta / recubre | Baja conducción, salvo mineral | Raíces en grietas con sustrato (*) | Escarcha; choque térmico (*) |

### 3.2 Agua, estructuras y manufacturas

| Objetivo / material | Fuego | Agua | Tierra | Aire | Magma | Rayo | Naturaleza | Hielo |
|---|---|---|---|---|---|---|---|---|
| **Charco / estanque** | Evapora parte (*) | Sube nivel hasta capacidad | Enturbia / crea orilla TEMP | Ondas / empuja superficie | Vapor + costra caliente (*) | Electrifica red acuática (*) | Brotes si hay soporte en orilla (*) | Crea placa de hielo TEMP (*) |
| **Corriente / canal de agua** | Evapora parcialmente | Aumenta caudal local (*) | Desvía/bloquea con obstáculo | Cambia oleaje | Vapor; solidifica al enfriar (*) | Propaga por conectividad (*) | Raíces pueden desviar flujo (*) | Bloquea sección con hielo TEMP (*) |
| **Madera construida / puerta** | Arde si umbral (*) | Se humedece; apaga | Golpea / bloquea | Empuja si movible | Quema fuerte | Solo conduce si húmeda/metal | Lianas traban bisagra (*) | Inmoviliza / escarcha (*) |
| **Metal / reja / cadena** | Calienta | Moja / enfría | Impacta / deforma (*) | Mueve si ligero | Calienta intensamente | Conduce hacia conectados | Lianas pueden inmovilizar | Enfría; escarcha exterior (*) |
| **Cristal / vidrio** | Choque térmico/fractura (*) | Enfría | Impacto/fractura (*) | — | Funde solo si habilitado (*) | Aislamiento normal; no arco salvo regla | Enreda marco | Choque térmico/fractura (*) |
| **Tela / cuerda** | Arde / se corta (*) | Se moja, pesa más | Cubre / golpea | Agita, desplaza | Quema | Conduce más si empapada (*) | Enreda / refuerza mediante lianas | Congela y rigidiza (*) |
| **Hielo existente / nieve** | Derrite | Agua superficial, fusiona si frío (*) | Fractura / cubre | Dispersa nieve suelta | Derrite rápido | Descarga solo si camino húmedo | Ralentiza crecimiento | Engrosa / repara (*) |
| **Mecanismo / máquina** | Activa sensor térmico (*) | Activa hidráulica / bloquea si no sellada (*) | Activa placa por peso | Mueve aspas/molino | Activa calor / daña (*) | Alimenta circuito (*) | Activa interruptor orgánico (*) | Congela válvula / plataforma (*) |

### 3.3 Seres vivos y objetos dinámicos (8 × 4)

| Objetivo / estado | Fuego | Agua | Tierra | Aire | Magma | Rayo | Naturaleza | Hielo |
|---|---|---|---|---|---|---|---|---|
| **Enemigo normal** | Quemadura | Mojado / empuje | Impacto / bloqueo | Empuje | Quemadura y daño de contacto | Choque/aturdimiento (*) | Enraizado (*) | Ralentización / congelación (*) |
| **Enemigo mojado** | Seca parcialmente / vapor; daño térmico (*) | Refuerza Mojado | Impacto / barro en suelo | Desplaza / seca | Vapor + daño térmico | **Conducción aumentada** | Enreda con mayor afinidad (*) | **Congela con facilidad** |
| **Objeto físico movible** | Calienta / incendia si combustible | Humedece / arrastra | Empuja / añade peso si cubierto | Empuja | Daña / recubre | Carga si conductor | Ata / sujeta | Hace resbaladizo / inmoviliza |
| **Hechizo persistente del mundo** | Calienta o quema manifestación | Enfría / moja | Bloquea físicamente si sólido | Desvía si afectable | Sobrecalienta | Electrifica si conductor | Enreda si superficie apta | Congela si contiene agua |

**128 cruces cubiertos**: 8 elementos × (8 materiales naturales + 8 materiales/infraestructuras + 4 tipos dinámicos) = **160 cruces**, no 128. Esta tabla final contiene **20 categorías de objetivo y 160 cruces**. Una celda puede representar varias consecuencias sujetas a condiciones. No todos los cruces implican un efecto especial.

### 3.4 Interacciones entre elementos activos en el mundo

Se trata de **contactos entre manifestaciones ya creadas**, no de fusiones de sellos. La matriz completa sería de 8×8 (36 parejas únicas con repetición); en vez de forzar resultados nuevos para cada pareja, se propone un resultado por dominancia de estados:

| Par en contacto | Resultado contextual propuesto |
|---|---|
| Fuego + Fuego | Calor acumulado, hasta límite; incendios pueden unirse |
| Fuego + Agua | Enfriamiento, extinción parcial, vapor si calor suficiente |
| Fuego + Tierra | Tierra se calienta; sin Magma automático |
| Fuego + Aire | Aire puede avivar o desplazar llamas; no crea Rayo automáticamente |
| Fuego + Magma | Refuerza calor; combustión cercana |
| Fuego + Rayo | Calor/descarga simultáneos; sin fusión espontánea |
| Fuego + Naturaleza | Quema vegetación inflamable |
| Fuego + Hielo | Derrite / genera agua y vapor si suficiente energía |
| Agua + Agua | Acumula volumen/humedad hasta capacidad |
| Agua + Tierra | Barro donde el suelo sea poroso y suficientemente húmedo |
| Agua + Aire | Evaporación/secado según condiciones; no genera Hielo automáticamente |
| Agua + Magma | Enfriamiento y vapor; posible costra solidificada |
| Agua + Rayo | Conduce descarga en red de agua |
| Agua + Naturaleza | Facilita crecimiento si hay sustrato |
| Agua + Hielo | Refuerza/congela si hay condición de frío |
| Tierra + Tierra | Material acumulado hasta límite de estructuras |
| Tierra + Aire | Obstáculo desvía viento; erosión / polvo en suelo suelto |
| Tierra + Magma | Magma forma costra de roca al enfriar |
| Tierra + Rayo | Mayormente aislante; veta/mineral conductor es excepción explícita |
| Tierra + Naturaleza | Raíces se aferran a suelo apto |
| Tierra + Hielo | Escarcha / fractura por impacto o choque térmico |
| Aire + Aire | Se suman corrientes, con límite de fuerza |
| Aire + Magma | Dispersa calor y humo; aviva combustión cercana si aplica |
| Aire + Rayo | Puede modificar trayectoria visual; sin incremento gratuito de energía |
| Aire + Naturaleza | Balancea/arrastra esporas; no hace crecer sin recursos |
| Aire + Hielo | Arrastra copos/escarcha; enfría solo si la masa de aire es fría |
| Magma + Magma | Acumula calor/masa hasta límite |
| Magma + Rayo | Descarga por regiones conductoras habilitadas; sin nueva fusión |
| Magma + Naturaleza | Quema vegetación y raíces |
| Magma + Hielo | Derrite, enfría magma, produce vapor, puede formar costra |
| Rayo + Rayo | Suma carga con saturación, no duplicación infinita |
| Rayo + Naturaleza | Descarga por vegetación húmeda; daño / interrupción de crecimiento |
| Rayo + Hielo | Baja conducción en hielo seco; si hay película acuosa, conduce |
| Naturaleza + Naturaleza | Crecimiento cooperativo sujeto a agua, sustrato y presupuesto |
| Naturaleza + Hielo | Crecimiento se inhibe/congela; algunas plantas resistentes persisten |
| Hielo + Hielo | Refuerza capa congelada, limitado por volumen/duración |

> **Regla de coherencia:** crear Magma/Rayo/Naturaleza/Hielo requiere fusionar sellos **dentro de la receta**. Un choque casual de manifestaciones en el entorno aplica reacciones ambientales y **no** inventa automáticamente un nuevo sello.

---

## 4. Reglas condicionales y umbrales — primera calibración

Los números de esta sección son **parámetros de balance iniciales**, no física real ni reglas existentes verificadas.

| ID | Condición previa | Umbral de prueba | Efecto | Histéresis / enfriamiento |
|---|---|---|---|---|
| `WET` | Material absorbe agua | `wetness ≥ 0.40` | Mostrar mojado; ajustar fricción/conductividad | Desactivar al bajar de 0.25 |
| `IGNITE` | `flammability > 0`, `fuel > 0`, `wetness < 0.35` | `temperature ≥ 0.70` durante dosis mínima | `burning = true` | Extinguir si `wetness ≥ 0.65` o sin combustible |
| `FREEZE` | Agua/superficie congelable | `frozen_fraction ≥ 0.70` | Capa de hielo / movilidad reducida | Descongelar cuando baja de 0.35 |
| `ELECTRIFY` | Conexión conductora | `charge ≥ 0.50` | Alimentar mecanismo / aturdir | Descarga con decaimiento y cooldown |
| `MUD` | Suelo poroso y absorbente | `wetness ≥ 0.60` | Zona de barro, fricción/arrastre | Secado bajo 0.30 |
| `GROW` | `growth_support > 0`, superficie libre | `growth ≥ 0.60`, `wetness ≥ 0.35` | Brote/raíz temporal | Requiere espacio y presupuesto vegetal |
| `BREAK` | Estructura frágil | `impact_energy ≥ fracture_threshold` | Fractura, activar mecanismo | Una transición por evento |
| `STEAM` | Agua + calor | Dosis térmica ≥ `steam_threshold` | VFX vapor, pérdida de agua; ocultación opcional | Limitar partículas y duración |
| `MAGMA_CRUST` | Magma se enfría | `temperature ≤ crust_threshold` | Superficie de piedra/costra temporal | Evitar generar geometría ilimitada |
| `SLIP` | Superficie helada | `frozen_fraction ≥ 0.70` | Cambiar material de fricción | Revertir al descongelar |
| `ROOT` | Objetivo en alcance de raíces | `growth ≥ 0.60` y objetivo susceptible | Restringir movimiento | Expira/destruye por fuego/corte |

Los objetos pueden exponer umbrales particulares: un tronco húmedo requiere más dosis para prender que una cuerda seca; una placa metálica conectada puede electrificarse más fácilmente que piedra común.

---

## 5. Modelo matemático

### 5.1 Vector de estado

Para cada objeto o celda reactiva `j`:

\[
\mathbf s_j=(w_j,\theta_j,q_j,g_j,f_j,b_j)
\]

con humedad `w`, temperatura abstracta `θ`, carga `q`, crecimiento `g`, congelación `f` y barro `b`. Otras variables discretas (`burning`, `rooted`, revestimiento) se derivan o actualizan por transiciones.

### 5.2 Aporte elemental por contacto

\[
\mathbf s_j(t+\Delta t)=\operatorname{clamp}\left(\mathbf s_j(t)+\mathbf C_j\odot\mathbf a_e\,P\,c_j\,\tau-\mathbf D_j(\mathbf s_j)\Delta t,\;\mathbf s_{\min},\mathbf s_{\max}\right)
\]

- `a_e`: vector de aporte del elemento (`Sello` resultante).
- `C_j`: vector de susceptibilidad del material (absorción, respuesta térmica, etc.).
- `P`: potencia elemental del hechizo resuelto.
- `c_j`: factor de cobertura/contacto en `[0,1]` calculado por el volumen 3D del hechizo.
- `τ`: exposición: para impacto instantáneo, `τ=1 evento`; para contacto continuo, `τ=Δt` en segundos. **No mezclar ambas unidades**: definir explícitamente tasa por segundo o dosis por evento.
- `D_j`: relajación (secado, enfriamiento, descarga, descongelación). Debe escalar con `Δt` y usar clamps.

**Regla crítica:** resolver una sola vez los modificadores de sellos y glifos en el hechizo; el motor ambiental recibe parámetros ya calculados. No aplicar multiplicadores elementales dos veces.

### 5.3 Vectores elementales iniciales de ejemplo

Valores por **impacto estándar**, antes de susceptibilidad. Los efectos continuos deben usar tasas propias.

| Elemento | Δw | Δθ | Δq | Δg | Δf | Efecto mecánico aparte |
|---|---:|---:|---:|---:|---:|---|
| Fuego | −0.25 | +0.50 | 0 | 0 | −0.20 | Daño térmico |
| Agua | +0.40 | −0.15 | 0 | 0 | 0 | Empuje/caudal |
| Tierra | 0 | 0 | 0 | 0 | 0 | Impacto, material sólido |
| Aire | −0.10 | −0.05 | 0 | 0 | 0 | Fuerza y ventilación |
| Magma | −0.30 | +0.80 | 0 | 0 | −0.40 | Cubierta caliente / daño |
| Rayo | 0 | +0.10 | +0.70 | 0 | 0 | Choque eléctrico |
| Naturaleza | 0 | 0 | 0 | +0.40 | 0 | Creación de raíces |
| Hielo | 0 | −0.40 | 0 | 0 | +0.60 | Superficie deslizante |

`GROW` no necesita crear plantas sobre cualquier superficie: requiere `growth_support`, espacio y, en general, humedad. `FREEZE` requiere agua o un material compatible; `ELECTRIFY` requiere conexión conductora para propagarse.

### 5.4 Ejemplo calculado: Agua sobre tierra fértil

Estado inicial de una baldosa de suelo:

- `wetness = 0.20`
- `water_absorption = 0.75`
- hechizo Agua de potencia `P=1`, cobertura `c=1`, impacto estándar `Δw=0.40`

\[
w'=\operatorname{clamp}(0.20+0.40\cdot1\cdot0.75\cdot1,0,1)=0.50.
\]

Resultado: **Mojado** (`≥0.40`), pero **todavía no Barro** (`<0.60`). Un segundo impacto equivalente alcanzaría `0.80` y produciría barro, sujeto a la capacidad del suelo. Si después se aplica Naturaleza, el crecimiento solo empieza al superar su propio umbral.

### 5.5 Ejemplo calculado: Elevación y construcción

Los glifos solo alteran el **volumen de contacto y la posición**, no el umbral del material. Para Elevación (`n_E` copias):

\[
\mathrm{flota}=n_E\ge 1,\qquad y_{extra}=\min(Y_{max},\max(0,n_E-1)\Delta y).
\]

Altura añade **extrusión geométrica** en Y (`h=\min(H_{max},n_H\Delta h)`); Elevación traslada la manifestación en Y. Una estructura sólida debe cumplir una restricción de altura ocupada, p.ej. `h + y_extra ≤ 2 niveles` referidos a la superficie permitida, con pruebas de colisión y soporte. No aplicar el mismo límite a un proyectil de combate que sobrevuela un desnivel.

### 5.6 Transiciones y orden determinista

1. Acumular dosis por elemento y objetivo durante el paso.
2. Aplicar cambios continuos (mojado, temperatura, carga…).
3. Resolver **transiciones** con un orden de prioridad fijo: extinción/consumo → congelación/descongelación → combustión → electricidad → crecimiento/raíces → transformación de superficie.
4. Publicar eventos de juego (`ignited`, `extinguished`, `electrified`, `grown`, `frozen`, `muddied`, `broken`); VFX escucha eventos y refleja estados.
5. Aplicar propagación con presupuesto y cooldown. No volver a aplicar la misma dosis en el mismo paso por el mismo evento.

Las prioridades propuestas son un punto de partida; deben evitar contradicciones como «ardiendo y completamente congelado» sin transición intermedia definida.

---

## 6. Ejemplos concretos: objetos del mundo y reglas aplicadas

| Objeto en escena | Componentes/rasgos | Acción mágica | Condición de éxito | Resultado jugable | Persistencia |
|---|---|---|---|---|---|
| **Antorcha apagada** | `flammable`, `ignitable`, `puzzle_switch` | Fuego | Dosis térmica supera ignición | Se enciende, activa luz/puerta | PERM si puzle lo permite |
| **Antorcha encendida** | `burning`, `ignitable` | Agua | Humedad/extinción suficiente | Se apaga; deja de alimentar circuito de antorchas | PERM/TEMP según puzle |
| **Puerta de madera** | `wood`, `flammable`, `integrity` | Fuego persistente | Combustible y umbral; tiempo suficiente | Arde; pierde integridad; apertura al romperse | PERM opcional |
| **Puerta de madera mojada** | `wood`, `wet` | Fuego | Primero vencer humedad | Resiste inicialmente; puede secarse y prender después | TEMP |
| **Puerta metálica electrificada** | `metal`, `conductive`, `door`, `powered` | Rayo | Circuito conectado | Desbloquea cierre eléctrico | TEMP/PERM por diseño |
| **Cadena metálica** | `metal`, `conductive` | Rayo | Conecta generador e interruptor | Transmite electricidad por la cadena | TEMP |
| **Placa de presión** | `pressure_plate`, umbral de masa | Tierra | Masa efectiva supera umbral | Abre compuerta mientras haya peso | TEMP |
| **Molino de viento** | `rotatable`, `wind_receiver` | Aire | Impulso suficiente | Rota aspas, bombea agua | TEMP |
| **Molino hidráulico** | `rotatable`, `water_receiver` | Agua | Caudal/presión suficiente | Mueve engranajes | TEMP |
| **Charco frente a generador** | `water`, `conductive_network` | Rayo | Charco conectado a placas | Energiza red y puede afectar enemigos mojados | TEMP |
| **Suelo de tierra seca** | `soil`, `porous` | Agua ×2 | Humedad llega al umbral de barro | Zona ralentizante | TEMP |
| **Semilla en suelo fértil** | `seed`, `growth_support` | Agua → Naturaleza | Humedad y crecimiento suficientes | Brota una enredadera/puente | TEMP/PERM marcada |
| **Pared agrietada** | `stone`, `cracked`, `growth_support` | Naturaleza | Raíces pueden fijarse | Escalera vegetal dentro del presupuesto de Y | TEMP |
| **Reja con hiedra** | `metal`, `vine_anchor` | Naturaleza | Enredo suficiente | Inmoviliza mecanismo o crea agarre | TEMP |
| **Puente colgante de cuerda** | `rope`, `flammable`, `support` | Fuego | Cuerda pierde integridad | Puente cae/abre camino | PERM si mapa lo admite |
| **Lago poco profundo** | `water_body`, `freeze_compatible` | Hielo | Dosis suficiente en superficie | Plataforma helada transitable | TEMP |
| **Lago congelado** | `frozen_surface` | Fuego | Dosis supera fusión local | Se abre un agujero en el hielo | TEMP |
| **Tubería congelada** | `pipe`, `blocked_by_ice` | Fuego | Fusión suficiente | Reanuda circulación de agua | TEMP/PERM |
| **Tubería caliente** | `pipe`, `heat_receiver` | Hielo/Agua | Enfriamiento suficiente | Se puede tocar / desactiva alarma térmica | TEMP |
| **Cofre enterrado** | `buried`, `soil_cover` | Tierra o Aire | Tierra se mueve / polvo se dispersa | Queda expuesto | PERM opcional |
| **Roca móvil** | `movable`, `mass`, `hard` | Aire | Fuerza supera fricción/inercia | Desplaza la roca hacia un interruptor | TEMP |
| **Roca fracturable** | `breakable`, `fracture_threshold` | Tierra + Flecha | Energía de impacto suficiente | Se parte y revela pasaje | PERM opcional |
| **Barril de agua** | `container`, `water_storage` | Fuego | Calor suficiente | Vapor/presión; válvula se acciona (*) | TEMP |
| **Barril de pólvora / material inflamable** | `flammable`, `hazard` | Fuego | Ignición | Evento controlado del escenario | PERM/TEMP |
| **Antorcha tras un canal** | `ignitable`, canal húmedo | Agua → Rayo | Red conductora activa | Enciende un activador eléctrico distinto de la antorcha | TEMP |
| **Enemigo sobre suelo mojado** | `enemy`, `wet`, `conductive` | Rayo | Red y carga suficientes | Aturdimiento y posible descarga en cadena | TEMP |
| **Enemigo atrapado en barro** | `enemy`, `movement` | Agua sobre suelo | Superficie se embarra | Reducción de velocidad, vulnerable a empuje | TEMP |
| **Enemigo con raíces** | `enemy`, `rootable` | Naturaleza | Crecimiento alcanza umbral | Inmovilización limitada | TEMP |
| **Enemigo incendiado** | `enemy`, `burning` | Agua | Dosis de extinción | Apaga quemadura; mantiene efecto Mojado | TEMP |
| **Cristal frágil** | `glass`, `fragile` | Fuego → Hielo | Choque térmico, si habilitado | Se agrieta y rompe | PERM opcional |
| **Suelo de roca caliente** | `stone`, `hot_surface` | Agua | Dosis de calor e hidratación | Vapor que puede ocultar visión | TEMP |
| **Magma vertido sobre agua** | `magma`, `water` | Agua/Hielo ambiental | Enfriamiento suficiente | Costra transitable breve + vapor | TEMP |
| **Nido de abejas de papel** | `paper`, `flammable`, `hive` | Fuego | Ignición | Quema nido; abejas reaccionan según IA | PERM opcional |
| **Nido de pájaros** | `twigs`, `light`, `movable` | Aire | Empuje suave | Se mueve/cae; alternativa de puzle no destructiva | TEMP/PERM |
| **Trampa de flechas de piedra** | `stone`, `mechanism`, `trigger` | Tierra/Permanencia | Bloquea la ranura de salida | Desactiva físicamente la trampa mientras haya obstáculo | TEMP |

**Diseño de objetos:** que una puerta se abra, un puente caiga o un interruptor se active es una **consecuencia de un componente de puzle**, no un atributo mágico arbitrario. La reacción elemental cambia un estado o ejerce una fuerza; el componente del objeto escucha ese evento y ejecuta su acción.

---

## 7. Reacciones encadenadas: ejemplos de puzles completos

| Puzle | Secuencia del jugador | Cadena evaluada por el motor | Solución / límite |
|---|---|---|---|
| **Red eléctrica inundada** | Agua en canal → Rayo | `wetness ↑` → nodo conductor activo → `charge` viaja → interruptor | La descarga solo recorre red conectada y no salta infinitamente |
| **Puente vivo** | Agua en suelo fértil → Naturaleza | Humedad habilita `growth_support` → raíces emergen → `supports_weight` | Máx. 1–2 niveles y estructura temporal |
| **Camino por el lago** | Hielo sobre agua | `frozen_fraction ↑` → placa helada → colisión transitable | Superficie y duración máximas |
| **Entrada bloqueada por maleza** | Fuego en raíces secas → Agua para contener | Ignición → propagación local → raíces pierden integridad; agua extingue en área elegida | El incendio no atraviesa material no inflamable |
| **Puerta por presión** | Tierra + Línea/Altura + Permanencia | Se crea volumen sólido → masa/colisión sobre placa → abre puerta | Altura y número de cuerpos limitados |
| **Pasillo de vapor** | Fuego sobre charco / Magma sobre agua | Calor + agua → vapor temporal → bloquea visibilidad de guardias si el juego lo implementa | El vapor no crea un nuevo elemento de sello |
| **Roca y molino** | Aire empuja roca → placa activa molino | Fuerza → desplazamiento de objeto → presión sobre interruptor | Respeta masa/fricción y geometría del pasillo |
| **Prisión de hielo** | Agua moja enemigo → Hielo | Mojado → frío/congelación suficiente → inmovilización temporal | Inmunidades y tiempo de recuperación |
| **Circuito de enredaderas** | Naturaleza crea lianas sobre rejilla → Agua → Rayo | Lianas húmedas se vuelven conductoras → puentean circuito | Las lianas secas no conducen igual |
| **Compuerta por congelación** | Hielo atasca mecanismo → Fuego libera | Congela válvula → bloqueada → calentamiento → descongelada | Feedback visual claro de estados |
| **Trampa de barro** | Agua sobre suelo + Aire | Barro ralentiza → Aire empuja enemigo a zona segura/peligrosa | Empuje se calcula con fuerza e inercia |
| **Costra de magma** | Magma en canal → Agua | Magma enfría → costra sólida temporal | No generar plataformas permanentes ilimitadas |

**Principio de puzles:** el jugador puede llegar a una solución por diferentes hechizos que creen **el mismo estado o fuerza**. Ej.: una placa de presión admite una roca del mundo o una estructura temporal de Tierra, si ambas cumplen el peso requerido.

---

## 8. Interacción de cada glifo con las reacciones

| Glifo | ¿Qué cambia realmente? | Consecuencia ambiental | Salvaguarda |
|---|---|---|---|
| **Radio** | Radio inicial del volumen de contacto | Afecta más superficie a la vez | Volumen/área máximos |
| **Línea** | Extensión longitudinal en plano XZ, según apuntado | Puede conectar varios objetos | Límite de longitud |
| **Altura** | Extrusión geométrica en Y | Puede alcanzar objetos a distinta altura | Máx. 1–2 niveles para estructuras |
| **Flecha** | Movimiento y alcance de la manifestación | Transporta la dosis a otro punto | Alcance y velocidad máximos |
| **Barrera** | Rodear/proteger con la manifestación | Intercepta objetos; aplica contacto perimetral | Protección depende del elemento/colisión |
| **Permanencia** | Anclaje y duración de contacto | Acumula dosis en el tiempo | Cooldowns, duración y objetos máximos |
| **Pulso** | Expansión progresiva | Efecto en anillos/zonas sucesivas | No reaplicar por frame sin tasa |
| **Repetición** | Número de copias/emisiones | Varios focos de reacción | Presupuesto global por receta |
| **Rebote** | Trayectorias tras colisión | Nueva superficie impactada | Máximo de rebotes; una dosis por contacto |
| **Elevación** | Activa flotación con primera copia; posteriores añaden desplazamiento Y | Lleva el área de contacto a otras alturas | Límite de elevación y ocupación sólida |

La clase `Hechizo` debe calcular **geometría y atributos una sola vez**; `HechizoVivo` informa al motor de reacciones sobre su **elemento, potencia, posición, volumen de contacto y modo de exposición**. El motor no necesita conocer qué combinación exacta de glifos originó el contacto.

---

## 9. Arquitectura propuesta en Godot (sin asumir código existente)

### 9.1 Componentes

| Archivo propuesto | Tipo | Responsabilidad |
|---|---|---|
| `material_reactivo.gd` | `Resource` | Perfil de susceptibilidades, tags y umbrales |
| `estado_elemental.gd` | `RefCounted` o `Resource` por instancia | Valores cambiantes de humedad, calor, carga, crecimiento, etc. |
| `componente_reactivo_3d.gd` | `Node3D` / componente del objeto | Recibir contacto, mantener estado, emitir señales |
| `reaccion_elemental_regla.gd` | `Resource` | Condición, dosis y consecuencia declarativa |
| `reacciones_elementales_3d.gd` | Nodo/servicio | Resolver dosis, umbrales, prioridades y eventos |
| `propagacion_elemental_3d.gd` | Servicio | Colas limitadas de fuego, electricidad, raíces |
| `reacciones_vfx_3d.gd` | Nodo | VFX/SFX en respuesta a señales de estado |
| `interaccion_puzle.gd` | Componente del objeto | Abrir, mover, romper, encender o accionar mecanismos |
| `hechizo_vivo.gd` | Existente o adaptador | Reportar impactos/contactos al servicio ambiental |

**Evitar** que `material_reactivo.gd` y `estado_elemental.gd` se compartan mutablemente entre objetos: los datos estáticos pueden compartirse como `Resource`, pero el estado runtime pertenece a cada instancia.

### 9.2 Datos de contacto (contrato propuesto)

```gdscript
# Ejemplo de estructura de datos, no implementación completa.
class_name ContactoElemental
extends RefCounted

var event_id: int
var source_instance_id: int
var element_id: StringName
var power: float = 1.0
var position: Vector3
var normal: Vector3
var exposure_seconds: float = 0.0
var instant_hit: bool = true
var coverage: float = 1.0
```

### 9.3 Resolución esquemática

```gdscript
# Pseudocódigo orientativo para una llamada del motor.
func aplicar_contacto(contacto: ContactoElemental, objetivo: ComponenteReactivo3D) -> void:
    if objetivo.ya_proceso(contacto.event_id):
        return
    var material = objetivo.material_reactivo
    var estado = objetivo.estado_elemental
    var aportes = obtener_aportes_elementales(contacto.element_id)
    var dosis = resolver_dosis(aportes, material, contacto)
    estado.acumular(dosis)
    var eventos = evaluar_transiciones(estado, material)
    objetivo.marcar_procesado(contacto.event_id)
    for evento in eventos:
        publicar_evento(objetivo, evento)
```

`ya_proceso(event_id)` **no debe bloquear todos los ticks** de un efecto persistente: cada tick de dosis continua necesita un identificador o tramo de exposición definido, con frecuencia controlada (`intervalo_efecto`). Un mismo impacto no debe contarse dos veces por colisiones solapadas.

### 9.4 Detección espacial

- `Area3D` para superficies y zonas de efectos continuos; `PhysicsDirectSpaceState3D` / `RayCast3D` para proyectiles y contactos directos, según la arquitectura elegida.
- Para zonas grandes, usar partición espacial por celdas/sectores en XZ con altura Y y filtros por colisiones; evitar comprobar todos los objetos cada frame.
- Modelar **red de conductividad** por nodos conectados (charcos, tuberías, cadenas, metal), no simplemente por distancia radial.
- Modelar propagación de fuego por proximidad + combustible + humedad + barrera física.
- Modelar crecimiento solo sobre puntos de anclaje y superficies con `growth_support`.

---

## 10. Presupuestos de seguridad, rendimiento y consistencia

| Riesgo | Regla de contención |
|---|---|
| Reacción infinita en cadena | IDs por evento, cooldown y profundidad máxima |
| Electricidad salta por todo el mapa | Red conductora conectada, atenuación por salto y presupuesto de nodos |
| Incendio infinito | Combustible finito, humedad, propagación limitada, posibilidad de extinción |
| Crecimiento que rompe puzles | Requiere sustrato/espacio; altura y número de estructuras limitados |
| Repetición + Permanencia excesivos | Máximo de instancias persistentes y de dosis por segundo |
| Muro + Elevación permite escalar sin límite | Presupuesto conjunto de altura ocupada, respecto al terreno de referencia |
| Proyectil no llega a enemigo alto | No aplicar límites de construcción a trayectorias 3D de combate |
| Estados incompatibles | Transiciones prioritarias, histéresis y cambio de fase explícito |
| VFX excesivos | Eventos agregados por área/tiempo; no instanciar un efecto por cada microcontacto |
| Cambios permanentes inesperados | `permanent_changes_allowed` por objeto/celda de mapa |

Parámetros sugeridos para **primer prototipo**: `max_propagation_depth = 4`, `max_new_reactions_per_tick = 24`, `max_conductive_nodes_per_event = 16`, `reaction_tick = 0.2 s`, `max_temporary_structures = 8`, `max_structure_height = 2 niveles`. **Todos son configurables y orientativos**; medir rendimiento real antes de fijarlos.

---

## 11. Plan incremental de implementación

### Fase 1 — Prototipo del bosque (prioridad alta)

1. Madera/vegetación inflamable + Fuego → Ardiendo.
2. Agua + objeto ardiendo → Apagado.
3. Agua + suelo absorbente → Mojado → Barro.
4. Rayo + red mojada/conductora → Electrificado → Interruptor.
5. Naturaleza + suelo fértil húmedo → Raíces/puente vegetal.
6. Hielo + agua → Superficie congelada transitable.
7. Tierra + objeto/plataforma → Bloqueo y presión por peso.
8. Aire + objeto movible/molino → Impulso mecánico.

### Fase 2 — Cadenas y variaciones

- Magma + agua → vapor/costra; Fuego + Hielo → fusión; cristales y choque térmico; humedad que altera combustión; propagación local de incendio; enredo de enemigos; redes con varios conductores.

### Fase 3 — Expansión sistémica

- Resistencia y rotura por materiales, crecimiento sobre paredes aptas, erosión, temporización de mecanismos, cobertura ambiental, estados por bioma, recetas combinadas con múltiples glifos y cadenas complejas.

### Pruebas de aceptación

| Caso | Resultado exigido |
|---|---|
| Agua sobre madera seca | Humedad aumenta; no arde ni cambia a barro |
| Fuego sobre madera mojada | Requiere más dosis para prender que madera seca |
| Agua sobre fuego activo | Puede extinguir, sin crear nueva fusión de sellos |
| Tierra+Aire en núcleo | Receta anulada; no crea estructura |
| Tierra y Aire como hechizos separados | Pueden bloquear/desviar partículas o empujar obstáculos |
| Rayo en cadena metálica conectada | Se propaga hasta el siguiente nodo conectado |
| Rayo en piedra normal | No crea conducción global |
| Naturaleza sobre piedra lisa seca | No germina sin anclaje o sustrato habilitado |
| Naturaleza sobre suelo fértil húmedo | Genera planta/raíz tras acumular dosis |
| Hielo sobre agua | Capa transitable TEMP, respetando colisión y expiración |
| Pulso persistente | Dosis temporal controlada; no aplica impactos duplicados por frame |
| Glifos dibujados en otro orden | Misma receta y mismo perfil de contacto |
| Elevación ×1 | Flota con desplazamiento vertical adicional cero |
| Elevación ×2 | Flota y añade un incremento Y, sin alterar tamaño |

---

## 12. Decisiones pendientes explícitas

1. **Unidades y límites verticales:** tamaño físico exacto de un «nivel» (m); límite de ocupación cuando se combinan Altura + Elevación en estructuras.
2. **Política de cambios permanentes:** qué objetos/puzles permiten destruir, germinar o congelar de forma persistente.
3. **Naturaleza:** puede crear plantas de la nada (mágicas y TEMP) o necesita siempre semillas/sustrato; recomendación: vegetación temporal solo en superficies aptas, vegetación permanente únicamente cuando el mapa lo admita.
4. **Fuego vs agua:** intensidad relativa, umbral para vapor, cuánto se conserva calor residual.
5. **Electricidad:** si agua pura conduce de forma uniforme en la ficción del juego o si la conductividad depende de materiales/impurezas. Recomendación de gameplay: charcos y superficies mojadas conducen cuando conectan nodos declarados.
6. **Coste de manifestaciones:** si tamaño, duración, área o número de instancias consumen tinta/energía o se limitan únicamente por glifos y máximos globales.
7. **Daño a aliados y jugador:** incluir reglas para que los puzles sean legibles y no haya reacciones sorpresa imposibles de evitar.
8. **Reacciones de magias entre sí:** hoy se definen por estado/contacto, no por crear nuevas fusiones de núcleo.

---

## 13. Principios que deben mantenerse estables

> **Reacción ambiental = función del elemento, material, estado, potencia, tiempo y contacto.**
>
> **Geometría decide dónde; propiedades deciden cómo y cuánto tiempo; sello decide qué aporta; objeto decide a qué es susceptible.**
>
> **Las fusiones de sellos se resuelven al construir la receta; las interacciones entre hechizos ya creados se resuelven en el mundo.**

Con esta estructura, añadir un árbol, una reja, una puerta o un bioma nuevo requiere principalmente configurar **materiales, estados y componentes de puzle**, no añadir excepciones a cada hechizo.
