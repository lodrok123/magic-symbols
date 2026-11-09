#[compute]
#version 450
// PORT de src/render/volume.js: resolve + copy (lejrimostfa/force-field-vfx-threejs, MIT). Filtro temporal: la historia se recorta al vecindario 3x3 del
// fotograma nuevo, lo que quita el ruido de la marcha sin fantasmas. modo 0 = resolve (crudo + historia -> salida), modo 1 = copia (salida -> historia).
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(push_constant, std430) uniform Pc { ivec4 tam_modo; } pc;
layout(set = 0, binding = 0, rgba16f) uniform restrict readonly image2D crudo;
layout(set = 0, binding = 1, rgba16f) uniform restrict image2D historia;
layout(set = 0, binding = 2, rgba16f) uniform restrict image2D salida;

void main() {
	ivec2 c = ivec2(gl_GlobalInvocationID.xy);
	ivec2 tam = pc.tam_modo.xy;
	if (c.x >= tam.x || c.y >= tam.y) return;
	if (pc.tam_modo.z == 1) {
		imageStore(historia, c, imageLoad(salida, c));
		return;
	}
	vec4 cur = imageLoad(crudo, c);
	vec4 lo = cur, hi = cur;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec4 n = imageLoad(crudo, clamp(c + ivec2(x, y), ivec2(0), tam - 1));
			lo = min(lo, n);
			hi = max(hi, n);
		}
	}
	imageStore(salida, c, mix(cur, clamp(imageLoad(historia, c), lo, hi), 0.55));
}
