#[compute]
#version 450
// PORT de src/main.js (cadena de post) (lejrimostfa/force-field-vfx-threejs, MIT): hdr = saturacion(escena * vol.a + vol.rgb, 1.3), con vineta.
// En Godot el bloom lo hace despues el glow del WorldEnvironment (umbral 1,1) y el tonemap ACES con exposicion 0,85; la vineta va aqui, ANTES del bloom
// (en la demo va despues: (hdr + bloom) * vineta). Escribe sobre el color de la escena (Forward+, RGBA16F) en el callback POST_TRANSPARENT.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
#define SET_VISTA 1
#include "vista_comun.glslinc"

layout(set = 0, binding = 0) uniform sampler2D vol;
layout(set = 0, binding = 1, rgba16f) uniform restrict image2D escena;

void main() {
	ivec2 c = ivec2(gl_GlobalInvocationID.xy);
	ivec2 tam = ivec2(V.tam.zw);
	if (c.x >= tam.x || c.y >= tam.y) return;
	vec2 uv = (vec2(c) + 0.5) / V.tam.zw;
	vec4 v = textureLod(vol, uv, 0.0);
	vec3 col = imageLoad(escena, c).rgb;
	vec3 hdr = col * v.a + v.rgb;
	float lum = dot(hdr, vec3(0.2126, 0.7152, 0.0722));
	hdr = max(mix(vec3(lum), hdr, V.look2.y), vec3(0.0));
	vec2 centrado = uv - 0.5;
	hdr *= mix(1.0, 1.0 - dot(centrado, centrado) * 0.9, V.look2.z);
	imageStore(escena, c, vec4(hdr, 1.0));
}
