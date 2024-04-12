shader_type canvas_item;
uniform sampler2D species0;
uniform sampler2D species1;
uniform sampler2D species2;

uniform int colour_fx;
#define FX_NONE 0
#define FX_SPATIAL_UV 2

vec4 colourTrail(vec4 trail)
{
	vec3 col = texture(species0, vec2(trail.r, 0.0)).xyz;
		col += texture(species1, vec2(trail.g, 0.0)).xyz;
		col += texture(species2, vec2(trail.b, 0.0)).xyz;
	return vec4(min(vec3(1.0), col), 1.0);
}

void fragment() {
	vec4 trail = texture(TEXTURE, UV);
		
	switch (colour_fx)
	{
		case FX_SPATIAL_UV:
			COLOR = colourTrail(trail);
			COLOR *= vec4(UV + 0.5, UV.x + UV.y + 0.5, 1.0);
			break;
		case FX_NONE:
		default:
			COLOR = colourTrail(trail);
			break;
	}
}
