shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;

void fragment() {
    float dist = distance(UV, vec2(0.5));
    float mask = smoothstep(0.5, 0.2, dist);
    ALBEDO = COLOR.rgb;
    ALPHA = mask * COLOR.a;
}
