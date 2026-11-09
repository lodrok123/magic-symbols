// PORT de src/render/figures.js: MAT (lejrimostfa/force-field-vfx-threejs, MIT). Casi negro, con un borde de luz de fuego para que las figuras
// se asienten en la escena en vez de flotar como recortes.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

void fragment() {
	float frente = max(dot(NORMAL, VIEW), 0.0);
	ALBEDO = vec3(0.012, 0.01, 0.008) + vec3(1.0, 0.32, 0.05) * pow(1.0 - frente, 5.0) * 0.5;
}
