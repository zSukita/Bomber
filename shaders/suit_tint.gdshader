shader_type canvas_item;

// Shader para tingir dinamicamente o traje tático do personagem
// Detecta tons de azul da jaqueta/capuz e converte suavemente para a cor escolhida.

uniform int color_index : hint_range(0, 3) = 0; // 0=Azul, 1=Vermelho, 2=Verde, 3=Amarelo
uniform float tint_strength : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	
	if (col.a >= 0.01 && color_index > 0) {
		// Detecta se o pixel pertence ao tecido azul do casaco/capuz
		bool is_blue_suit = (col.b > col.r * 1.12) && (col.b > col.g * 0.95) && (col.b > 0.18) && (col.r < 0.75);
		
		if (is_blue_suit) {
			float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
			vec3 target_tint = col.rgb;
			
			if (color_index == 1) {
				// Vermelho Carmesim
				target_tint = vec3(luma * 1.45, luma * 0.32, luma * 0.38);
			} else if (color_index == 2) {
				// Verde Esmeralda
				target_tint = vec3(luma * 0.35, luma * 1.35, luma * 0.55);
			} else if (color_index == 3) {
				// Amarelo Dourado
				target_tint = vec3(luma * 1.45, luma * 1.25, luma * 0.28);
			}
			
			col.rgb = mix(col.rgb, target_tint, tint_strength);
		}
	}
	
	COLOR = col;
}
