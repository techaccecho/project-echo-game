shader_type canvas_item;

void fragment() {
    // Sample the texture of the tilemap at the current UV
    vec4 tex_color = texture(TEXTURE, UV);

    // Invert the RGB values, but keep the original Alpha (transparency)
    vec4 inverted_color = vec4(1.0 - tex_color.rgb, tex_color.a);

    // Apply the final color to the tile
    COLOR = inverted_color;
}
