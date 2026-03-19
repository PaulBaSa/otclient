
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;
uniform float u_Time;  // Elapsed time for animation

// Adjust the speed and intensity of the wave effect
float speed = 1.0;
float intensity = 0.05;

// Adjust the outer glow color and intensity
vec3 glowColor = vec3(0.0, 0.5, 1.0); // Adjust the glow color as desired
float glowIntensity = 4.5; // Adjust the glow intensity as desired
float glowSpeed = 4.0; // Adjust the speed of the glow animation

void main()
{
  // Retrieve the color from the texture
  vec4 texColor = texture2D(u_Tex0, v_TexCoord);

  // Calculate the displacement amount using sine functions
  float displacementX = sin(v_TexCoord.x * speed + u_Time) * intensity;
  float displacementY = sin(v_TexCoord.y * speed + u_Time) * intensity;

  // Apply the displacement to the texture coordinates
  vec2 offset = vec2(displacementX, displacementY);

  // Retrieve the color from the displaced texture coordinates
  vec4 displacedColor = texture2D(u_Tex0, v_TexCoord + offset);

  // Apply a tint color to the displaced color
  vec3 tint = vec3(0.0, 0.5, 1.0); // Adjust the tint color as desired
  vec3 finalColor = displacedColor.rgb * tint;

  // Calculate the distance from the current texel to the center
  float distance = length(v_TexCoord - 0.5);

  // Calculate the glow effect only around the outfit shape based on the distance and time
  float glow = smoothstep(0.53, 0.46, distance + sin(u_Time * glowSpeed) * 0.05);

  // Apply the outer glow color and intensity only to the outfit shape
  vec3 glowEffect = glowIntensity * glow * glowColor * texColor.rgb;

  // Add the outer glow effect to the final color
  finalColor += glowEffect;

  // Output the final color with the original alpha value
  gl_FragColor = vec4(finalColor, texColor.a);
}
