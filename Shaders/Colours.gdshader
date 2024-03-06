shader_type canvas_item;
uniform int colour_processing;
uniform sampler2D colour_sp0;
uniform sampler2D colour_sp1;
uniform sampler2D colour_sp2;

#define FX_NONE 0
#define FX_SPATIAL_UV 2

vec4 colourTrail(vec4 trail)
{
	vec3 col = texture(colour_sp0, vec2(trail.r, 0.0)).xyz;
		col += texture(colour_sp1, vec2(trail.g, 0.0)).xyz;
		col += texture(colour_sp2, vec2(trail.b, 0.0)).xyz;
	return vec4(min(vec3(1.0), col), 1.0);
}

void fragment() {
	if (colour_processing != FX_NONE)
	{
		vec4 trail = texture(TEXTURE, UV);
		
		switch (colour_processing)
		{
			case FX_SPATIAL_UV:
				COLOR = colourTrail(trail);
				COLOR *= vec4(UV + 0.5, UV.x + UV.y + 0.5, 1.0);
				break;
			default:
				COLOR = colourTrail(trail);
				break;
		}
	}
}
