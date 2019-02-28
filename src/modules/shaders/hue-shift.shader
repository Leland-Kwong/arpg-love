// https://gamedev.stackexchange.com/questions/59797/glsl-shader-change-hue-saturation-brightness/59879

uniform float hueAdjustAngle = 1.0;
uniform float brightness = 1.0;

vec3 rgb2hsv(vec3 c)
{
  vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

  float d = q.x - min(q.w, q.y);
  float e = 1.0e-10;
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ) {
  vec4 textureColor = texture2D(texture, texture_coords);
  vec3 fragRGB = textureColor.rgb;
  vec3 fragHSV = rgb2hsv(fragRGB).xyz;
  fragHSV.x += color.x / hueAdjustAngle;
  fragHSV.yz *= color.yz;
  fragHSV.xyz = mod(fragHSV.xyz, brightness * 10.0);
  fragRGB = hsv2rgb(fragHSV);
  return vec4(fragRGB, textureColor.w);
}