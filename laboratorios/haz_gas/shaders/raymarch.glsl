#[compute]
#version 450
// PORT de src/render/volume.js: raymarch (lejrimostfa/force-field-vfx-threejs, MIT). Raymarch del gas a una textura HDR de media resolucion, en compute.
// rgb = la luz recogida a lo largo del rayo, a = lo que queda del fondo. La marcha para en las caras de la caja (suelo y acantilado) y, en Godot, tambien en la
// PROFUNDIDAD de la escena (el muro del lab, la jugadora): la demo no lo necesita porque su unico solido es el escudo invisible.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
#include "gas_comun.glslinc"
#include "vista_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler3D gas;
layout(set = 0, binding = 1) uniform sampler3D luz;
layout(set = 0, binding = 2) uniform sampler3D luz_lejos;
layout(set = 0, binding = 3) uniform sampler3D clave;
layout(set = 0, binding = 4) uniform sampler2D profundidad;
layout(set = 0, binding = 5, rgba16f) uniform restrict writeonly image2D crudo;

#define THICKNESS V.look0.x
#define RELIEF V.look0.y
#define EDGE V.look0.z
#define SMOKE_ALBEDO V.look0.w
#define FLAME_BODY V.look1.x
#define EMIT_GAIN V.look1.y
#define FIRE_ON_SMOKE V.look1.z
#define FAR_ON_SMOKE V.look1.w
#define LAMP_ON_SMOKE V.look2.x

float rho(vec3 uvw) { return densidad_humo(textureLod(gas, uvw, 0.0)); }

void main() {
	ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
	if (gid.x >= int(V.tam.x) || gid.y >= int(V.tam.y)) return;
	vec2 uv = (vec2(gid) + 0.5) / V.tam.xy;
	// Fila 0 de la textura = arriba de la pantalla = y +1 del NDC de OpenGL. (Comprobado a mano con la camara ortografica del juego.)
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	// inv_vp sale de Camera3D.get_camera_projection() (convencion OpenGL: z del NDC de -1 cercano a 1 lejano). El rayo va del plano cercano al lejano:
	// vale para la camara en perspectiva de la demo y para la ortografica del juego.
	vec4 a4 = V.inv_vp * vec4(ndc, -1.0, 1.0);
	vec4 b4 = V.inv_vp * vec4(ndc, 1.0, 1.0);
	vec3 ro = a4.xyz / a4.w;
	vec3 rd = normalize(b4.xyz / b4.w - ro);
	vec3 lo = WLO, hi = WLO + WTAM;
	vec3 inv = vec3(1.0) / (rd + vec3(0.00001));
	vec3 t0 = (lo - ro) * inv, t1 = (hi - ro) * inv;
	vec3 mn = min(t0, t1), mx = max(t0, t1);
	float tNear = max(max(max(mn.x, mn.y), mn.z), 0.0);
	float tFar = min(min(mx.x, mx.y), mx.z);
	// Profundidad de la escena. Godot 4.3+ guarda la Z INVERTIDA de Vulkan (1 cercano, 0 lejano; el cielo es 0 y no corta):
	// con su correccion (Projection.set_depth_correction: z_vk = 0,5 - 0,5 z_gl) la z de OpenGL es 1 - 2 d.
	if (V.marcha.z > 0.5) {
		ivec2 pz = clamp(ivec2(uv * V.tam.zw), ivec2(0), ivec2(V.tam.zw) - 1);
		float d = texelFetch(profundidad, pz, 0).r;
		if (d > 0.0) {
			vec4 h4 = V.inv_vp * vec4(ndc, 1.0 - 2.0 * d, 1.0);
			tFar = min(tFar, dot(h4.xyz / h4.w - ro, rd));
		}
		if (V.marcha.w > 0.5) {   // DEPURACION (HazGasRaymarch.depurar): r = d, g = distancia a la escena, b = tNear, a = tFar de la caja
			vec4 h4 = V.inv_vp * vec4(ndc, 1.0 - 2.0 * d, 1.0);
			imageStore(crudo, gid, vec4(d, dot(h4.xyz / h4.w - ro, rd), tNear, min(min(mx.x, mx.y), mx.z)));
			return;
		}
	}
	vec3 color = vec3(0.0);
	float trans = 1.0;
	const vec3 keyColor = vec3(0.03, 0.2, 1.0);
	int pasos = int(V.marcha.x);

	if (tFar > tNear) {
		float dl = (tFar - tNear) / float(pasos);
		// Ruido de gradiente entrelazado: el desfase esconde las bandas y el filtro temporal lo promedia.
		float ign = fract(dot(vec2(gid), vec2(0.06711056, 0.00583715)) * 52.9829189 + V.marcha.y * 0.61803);
		float t = tNear + dl * ign;
		for (int k = 0; k < pasos; k++) {
			vec3 pos = ro + rd * t;
			vec3 uvw = (pos - lo) / WTAM;
			vec4 s = textureLod(gas, uvw, 0.0);
			float smoke = densidad_humo(s);
			// La bruma fina se desvanece y el gas espeso se vuelve solido: el gas se lee como un cuerpo con borde. Las llamas tambien son opacas:
			// el ojo ve la estructura de su capa exterior en vez de la suma de toda la bola de fuego.
			float sigma = smoke * smoke / (smoke + EDGE) * THICKNESS + smoothstep(0.12, 0.34, s.x) * s.x * FLAME_BODY;
			if (sigma > 0.01) {
				// La luz cercana se topa para que el humo junto a las llamas no las vele. La lejana va entera: el humo lejos del fuego ha de casar con el suelo de debajo.
				vec3 close = luz_suave(textureLod(luz, uvw, 0.0).xyz);
				vec3 fire = close * FIRE_ON_SMOKE + textureLod(luz_lejos, uvw, 0.0).xyz * FAR_ON_SMOKE;
				// Direccion de arte: la lampara se apaga donde manda el fuego, asi naranja y azul se tocan sin sumar a lila.
				float calm = (1.0 - smoothstep(0.0, 0.4, s.x)) * max(1.0 - close.x * 1.1, 0.0);
				vec3 toKey = P.key_pos.xyz - pos;
				float dist2 = dot(toKey, toKey);
				vec3 lamp = keyColor * textureLod(clave, uvw, 0.0).x * LAMP_ON_SMOKE / (dist2 + 60.0);
				const vec3 ambient = vec3(0.004, 0.006, 0.014);
				// Sombreado de superficie por el gradiente de densidad: esculpe los pliegues que el campo de sombra es demasiado grueso para ensenar.
				const float e = 0.008;
				vec3 slope = -(vec3(rho(uvw + vec3(e / 2.0, 0.0, 0.0)), rho(uvw + vec3(0.0, e, 0.0)), rho(uvw + vec3(0.0, 0.0, e))) - smoke);
				vec3 nrm = normalize(slope + vec3(0.0001));
				float facing = dot(nrm, normalize(toKey)) * 0.5 + 0.5;
				float folds = (max(dot(nrm, -rd), 0.0) * 0.35 + facing * 0.65) * RELIEF + (1.0 - RELIEF);
				vec3 lit = ((fire + lamp * calm) * folds + ambient) * SMOKE_ALBEDO;
				float seg = exp(-sigma * dl);
				color += (lit + color_fuego(s.x) * EMIT_GAIN) * (1.0 - seg) * trans;
				trans *= seg;
			}
			if (trans < 0.01) break;
			t += dl;
		}
	}
	imageStore(crudo, gid, vec4(sostener_tono(color), trans));
}
