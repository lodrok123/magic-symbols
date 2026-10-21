# Prompts para las tiras de transición del suelo (joints)

Hoy las tiras son **procedurales** (migas de la propia textura del suelo y matas de hierba; ver `JOINTS_PARES` en `presentacion/prueba_test2.gd`).
Si se quiere un asset pintado que las sustituya, una textura por pareja, con alfa, **sin costura en horizontal** (se repite a lo largo de la frontera), estilo
pintado a mano de baja saturación como `hierba_borde.png`. Tamaño sugerido 1024 x 256; la tira se tiende con su lado denso hacia el suelo que «lame».

| Pareja | Prompt |
|---|---|
| camino → tierra | Seamless horizontal strip, top-down, stylized hand-painted: loose pale sand crumbs and grains scattered over brown packed dirt, dense on the top edge fading to sparse on the bottom, soft low-contrast colors, transparent background (alpha), no outline. |
| camino → piedra | Seamless horizontal strip, top-down, stylized hand-painted: pale sand drifting over grey flagstone edge, small sand patches with irregular cut edge, dense at the top fading out downwards, transparent background, no outline. |
| tierra → piedra | Seamless horizontal strip, top-down, stylized hand-painted: brown soil and fine gravel crumbs spilling over grey stone slabs, irregular scattered pebbles, dense at the top and sparse at the bottom, transparent background, no outline. |
| hierba → camino | Seamless horizontal strip, top-down, stylized hand-painted: small tufts of green grass and a few leaves sprouting over pale sand, dense at the top fading to single blades at the bottom, transparent background, no outline. |
| hierba → piedra | Seamless horizontal strip, top-down, stylized hand-painted: green grass tufts and moss growing between stone slab edges, dense at the top, sparse at the bottom, transparent background, no outline. |

Integración si llegan: un `sampler2D` por pareja en el shader del suelo y, en `migas()`, sustituir el corte por ruido por `texture(t_joint, vec2(u_a_lo_largo, v_de_0_a_1)).a`
con `v = -sd / ancho` (la misma `sd` que ya calcula `pareja`).
