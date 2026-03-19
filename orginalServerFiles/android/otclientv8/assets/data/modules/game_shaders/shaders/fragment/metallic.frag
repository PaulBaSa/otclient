
uniform float u_Time;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

const float metallicStrength = 0.85; // Adjust the strength of the metallic effect
const vec3 metallicColor = vec3(0.1, 0.1, 0.1); // Define the metallic color
const float lightSpeed = 0.1; // Adjust the speed of the light effect
const float lightIntensity = 1.0; // Adjust the intensity of the light effect
const float lightWidth = 0.01; // Adjust the width of the light effect

// Perlin noise function
float noise(vec2 uv) {
  return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void main()
{
  // Retrieve the color from the texture
  vec4 texColor = texture2D(u_Tex0, v_TexCoord);

  // Calculate the metallic color by interpolating between the original color and the metallic color
  vec3 finalColor = mix(texColor.rgb, metallicColor, metallicStrength);

  // Calculate the light position based on time and texture coordinates
  float lightPos = mod(u_Time * lightSpeed, 0.15);

  // Calculate the distance from the light position to the current texture coordinate
  float lightDistance = abs(v_TexCoord.y - lightPos);

  // Adjust the light intensity based on the outfit shape and light width
  float lightIntensity = smoothstep(lightWidth, 0.0, lightDistance);

  // Calculate the light color using noise
  float lightColor = 0.5 + 0.5 * noise(vec2(lightPos * 10.0, 0.0));

  // Apply the light effect only on the outfit
  finalColor += lightIntensity * lightColor;

  // Output the final color with the original alpha value
  gl_FragColor = vec4(finalColor, texColor.a);
}
