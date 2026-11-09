shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled, skip_vertex_transform;

// HAZ DE FUEGO (ronda de Pablo, 2/11/2026; referencia ref_haz_video_a): un chorro tipo lanzallamas que NACE DE UN PUNTO fino en el origen (casi un hilo con el núcleo más claro), se ABRE
// progresivamente en bocanadas hasta una punta redondeada y algo deshecha, y al cortarse se SUELTA del origen, sigue avanzando y se deshace en bolitas de fuego.
// Geometría: una tira a lo largo del eje del haz (FuegoToyMallas.haz_cono) que el vertex shader GIRA alrededor de ese eje para mirar a la cámara (billboard de eje): el chorro tiene volumen
// visto desde cualquier ángulo y no hay borde recto ni en el origen (ancho ~0) ni en la punta (la anchura se redondea y el alfa se deshace antes del final).
//   crece 0 → 1   el chorro sale del origen hasta su largo (animación «nacer»)
//   corte 0 → 1   el chorro se desprende (su cola se despega del origen y el cuerpo avanza), se rompe en islas (bolitas) y se apaga (animación «morir»)
// Los nombres de los mandos de EfectoToy son los mismos para que se muevan igual (altura no actúa en el haz).

group_uniforms mandos;
uniform float altura : hint_range(0.3, 3.0) = 1.0;
uniform float ancho : hint_range(0.3, 2.0) = 1.0;
uniform float blandura : hint_range(0.05, 1.0) = 0.22;
uniform float ondulacion : hint_range(0.0, 1.5) = 0.6;
uniform float velocidad : hint_range(0.1, 4.0) = 1.0;
uniform float brillo : hint_range(0.3, 3.0) = 1.0;
uniform float tono : hint_range(0.0, 1.0) = 0.0;
uniform float transparencia : hint_range(0.2, 1.0) = 0.97;
uniform float chisporroteo : hint_range(0.0, 1.0) = 0.6;
uniform float vida : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

group_uniforms texturas;
uniform sampler2D lenguas : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_a : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_v : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D ruido_fino : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform sampler2D rampa_azul : source_color, filter_linear, repeat_disable;
group_uniforms;

group_uniforms forma;
uniform float largo = 3.0;                 // m del haz (la malla mide HAZ_LARGO_MALLA veces esto)
uniform float r_origen = 0.012;            // semianchura en el origen (m)
uniform float r_fin = 0.2;                 // semianchura en la punta (m)
uniform float grosor = 1.0;                // × la anchura (el núcleo es más fino)
uniform float crece : hint_range(0.0, 1.0) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 0.0;
uniform float semilla = 0.0;
uniform float giro : hint_range(-1.0, 1.0) = 0.05;
uniform float umbral : hint_range(0.0, 1.0) = 0.27;
uniform float desfase = 0.95;
uniform float fuerza_borde = 1.2;
uniform float calor_extra = 0.3;
uniform float escala_rampa = 1.0;
uniform float v_chorro = 1.0;              // velocidad de las bocanadas hacia fuera (× velocidad)
uniform float rot_lamina = 0.0;            // giro (rad) de la lámina alrededor del eje respecto a la que mira a la cámara: láminas cruzadas para ver volumen mirando a lo largo
uniform float cuerpo = 0.0;                // relleno del centro (suma al campo de fuego en el centro)
uniform float volutas = 1.0;               // amplitud de las bocanadas redondeadas (la anchura se hincha a lo largo)
uniform float tam_bolas = 1.0;             // tamaño de las bolitas al cortarse (× más grandes)
// 9/11 (ideas de la demo de gas de three.js): la punta se vuelve humo, el color no se quema y las lenguas hacen remolino
uniform float humo : hint_range(0.0, 1.0) = 0.0;       // cuánto se ensancha, frena, enrojece y se vuelve humo pardo la punta (0 = como antes)
uniform float tope_calor : hint_range(0.3, 1.0) = 1.0; // tope de la rampa: 0,7 = naranja (nunca el tramo amarillo); 1 = toda la rampa (como antes)
uniform float remolino : hint_range(0.0, 1.0) = 0.5;   // distorsión tipo curl de las lenguas (en vez de un desplazamiento uniforme)
uniform float abre_exp = 1.15;                         // >1: estrecho cerca de la mano y se abre sobre todo al final
group_uniforms;

varying float v_p;       // 0 en el origen, 1 en la punta (en la forma que se mueve con el corte)
varying float v_sc;      // coordenada de contenido en largos
varying float v_lat;     // -1 a 1 a lo ancho
varying float v_w;       // semianchura real (m)

void vertex() {
	float lat = UV.x * 2.0 - 1.0;
	float s = UV.y * 1.8;                              // posición a lo largo, en largos del haz (HAZ_LARGO_MALLA)
	float desp = corte * 0.6;                          // el chorro cortado avanza
	float sc = s - desp;
	float g = max(crece, 0.03);
	float p = sc / g;
	float t = TIME * velocidad * v_chorro;
	float along = sc * largo;
	// bocanadas: la anchura se hincha y se afina en ondas que van hacia fuera
	float boc = textureLod(ruido_v, vec2(along * (0.32 + 0.2 * clamp(volutas - 1.0, 0.0, 1.0)) - t * 0.9 + semilla, semilla * 0.7), 0.0).r;
	float boc2 = textureLod(ruido_a, vec2(along * 0.75 - t * 1.6, 0.4 + semilla), 0.0).r;
	float bm = 0.72 + (0.55 * boc + 0.25 * boc2) * (0.5 + ondulacion * 0.6);
	bm = mix(bm, 0.5 + (0.95 * boc + 0.4 * boc2) * (0.5 + ondulacion * 0.6), clamp(volutas - 1.0, 0.0, 1.0));
	float base = r_origen + (r_fin - r_origen) * pow(clamp(p, 0.0, 1.0), mix(0.8, abre_exp, humo));
	float w = base * bm * grosor * ancho;
	w *= 1.0 + 0.3 * humo * smoothstep(0.5, 0.95, p);                            // la punta se ensancha (la bocanada de humo)
	w *= sqrt(clamp(1.0 - smoothstep(0.8, 1.05, p), 0.0, 1.0));                 // punta redondeada
	w *= mix(1.0, smoothstep(corte * 0.7 - 0.02, corte * 0.7 + 0.22, sc), step(0.001, corte));   // cola suelta: acaba en punta redondeada, no en corte recto
	w = mix(w, r_origen * 0.3, step(p, 0.0));
	vec3 c_w = (MODEL_MATRIX * vec4(0.0, 0.0, VERTEX.z, 1.0)).xyz;
	vec3 eje = normalize((MODEL_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	bool orto = PROJECTION_MATRIX[3][3] == 1.0;
	vec3 a_cam = orto ? INV_VIEW_MATRIX[2].xyz : normalize(INV_VIEW_MATRIX[3].xyz - c_w);
	vec3 der = INV_VIEW_MATRIX[0].xyz;
	der = normalize(der - eje * dot(der, eje));
	vec3 lado = cross(eje, a_cam);
	float ll = length(lado);
	lado = ll > 0.0001 ? lado / ll : der;
	lado = normalize(mix(der * sign(dot(der, lado) + 0.00001), lado, smoothstep(0.03, 0.3, ll)));       // mirando a lo largo del haz, la lámina no se queda en una raya
	lado = lado * cos(rot_lamina) + cross(eje, lado) * sin(rot_lamina);
	vec3 pos = c_w + lado * lat * w;
	VERTEX = (VIEW_MATRIX * vec4(pos, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(a_cam, 0.0)).xyz);
	v_p = p;
	v_sc = sc;
	v_lat = lat;
	v_w = max(w, 0.0001);
}

void fragment() {
	float t = TIME * velocidad * v_chorro;
	float sm = semilla;
	float d = abs(v_lat);
	float along = v_sc * largo;
	float lat_m = v_lat * v_w;
	float p = v_p;
	// textura de lenguas y segundo ruido: corren a lo largo del chorro hacia fuera; los metros laterales son reales (la textura no se estira al ensanchar)
	// pt: 0 cerca de la mano (chorro limpio, estrecho y rápido) → 1 en la punta (lenguas más grandes y lentas, que frenan)
	float pt = smoothstep(0.3, 0.95, p) * humo;
	// remolino: dos ruidos suaves desplazan las coordenadas de las lenguas (curl barato), más fuerte hacia la punta
	vec2 rem = vec2(texture(ruido_v, vec2(along * 0.35 - t * 0.3 + sm, lat_m * 0.9)).r, texture(ruido_v, vec2(along * 0.35 - t * 0.3 + sm + 0.5, lat_m * 0.9 + 0.5)).r) - 0.5;
	rem *= remolino * (0.5 + 0.9 * pt);
	float lat_w = lat_m + rem.x * 0.55;
	float along_w = along + rem.y * 1.1;
	float l1 = texture(lenguas, vec2(lat_w * 1.4 + giro * t + sm, -along_w * 0.5 + t)).r;
	float l2 = texture(lenguas, vec2(lat_w * 1.0 + giro * t * 0.5 + sm + 0.3, -along_w * 0.4 + t * 0.5)).r;
	float l = mix(l1, l2, pt);
	float r2 = texture(ruido_a, vec2(lat_w * 1.0 + 0.37 + sm * 0.5, -along_w * 0.36 + t * 0.8)).r;
	float fino = texture(ruido_fino, vec2(lat_m * 2.2 + sm * 3.0, -along * 1.5 + t * 2.4)).r;
	float f = l * 0.9 + (r2 - 0.5) * 0.9 * (0.5 + ondulacion) * (1.0 - 0.45 * clamp(volutas - 1.0, 0.0, 1.0)) - pow(d, 2.4) * fuerza_borde + desfase;
	f -= smoothstep(0.5, 1.0, p) * (0.5 + (fino - 0.4) * 1.2 * chisporroteo) * 1.1;          // la punta se deshace
	f += (1.0 - smoothstep(0.0, 0.3, p)) * 0.7;                                              // cerca del origen es un hilo sólido
	// al cortarse, el chorro se rompe en islas (bolitas de fuego): cada vez quedan menos zonas con el ruido alto
	f += cuerpo * (1.0 - smoothstep(0.1, 0.95, d)) * smoothstep(0.02, 0.2, p);
	float bola = texture(ruido_a, vec2((along * 0.9 + sm) / tam_bolas, lat_m * 1.8 / tam_bolas + t * 0.08 + 0.2)).r;
	f -= corte * 2.4 * (1.0 - smoothstep(0.4, 0.62, bola));
	f -= corte * 1.2 * cuerpo * (1.0 - smoothstep(0.4, 0.62, bola));
	float a = smoothstep(umbral, umbral + blandura, f);
	a *= smoothstep(0.0, 0.03, p) * (1.0 - smoothstep(0.96, 1.04, p));
	a *= 1.0 - smoothstep(0.86, 1.0, d);
	a *= 1.0 - smoothstep(0.7, 1.0, corte);
	float idx = (f - umbral) * escala_rampa + calor_extra * (1.0 - smoothstep(0.0, 0.8, d)) + 0.18 * (1.0 - smoothstep(0.0, 0.6, p)) + 0.3 * cuerpo * (1.0 - smoothstep(0.0, 0.6, d)) * (1.0 - smoothstep(0.7, 1.0, p));
	// contraste sin amarillo: la rampa se corta en `tope_calor` (las capas solapadas se quedan naranjas, no se queman), el borde y la punta se enrojecen
	idx -= humo * (0.2 * smoothstep(0.45, 1.0, d) + 0.28 * pt + 0.25 * corte);
	idx = clamp(idx, 0.0, 1.0) * tope_calor;      // la rampa se comprime (no se recorta): el gradiente rojo → naranja se conserva
	vec3 col = mix(texture(rampa, vec2(idx, 0.5)).rgb, texture(rampa_azul, vec2(idx, 0.5)).rgb, tono);
	// humo pardo oscuro alrededor de la llama de la punta (donde el fuego se deshace); al soltarse el chorro (corte) las bolitas se apagan en humo en vez de seguir brillando
	float fh = humo * smoothstep(0.4, 0.9, p);
	float a_h = smoothstep(umbral - 0.32, umbral - 0.02, f) * fh * 0.62;
	a_h *= (1.0 - smoothstep(0.8, 1.0, d)) * smoothstep(0.0, 0.03, p) * (1.0 - smoothstep(0.96, 1.04, p));
	a_h *= 1.0 - smoothstep(0.55, 1.0, corte);
	vec3 col_humo = vec3(0.30, 0.15, 0.09) * (0.75 + 0.5 * fino);
	col = mix(col, col_humo * 1.5, humo * corte * 0.5);
	float titila = 1.0 + 0.12 * chisporroteo * (sin(TIME * 9.3 + sm * 31.0) * 0.6 + sin(TIME * 14.1 + sm * 17.0) * 0.4);
	float a_tot = max(a, a_h);
	col = mix(col_humo, col, clamp(a / max(a_tot, 0.0001), 0.0, 1.0));
	ALBEDO = col * brillo * titila;
	ALPHA = clamp(a_tot * transparencia * vida, 0.0, 1.0);
}
