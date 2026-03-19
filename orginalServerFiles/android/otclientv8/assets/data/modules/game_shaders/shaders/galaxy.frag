uniform float u_Time;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

const float purpleIntensity = 0.97; // Adjust the intensity of the purple color here

const float starDensity = 0.02; // Adjust the density of the stars

const float starSize = 60.0; // Adjust the base size of the stars

void main()
{
  // Apply the purple color to the base model
  vec4 texColor = texture2D(u_Tex0, v_TexCoord);
  vec3 baseColor = vec3(64.0 / 255.0, 18.0 / 255.0, 139.0 / 255.0);
  vec3 blendedColor = mix(texColor.rgb, baseColor, purpleIntensity);

  // Calculate the star position and intensity
  vec2 starPosition = v_TexCoord / starDensity;
  float randomOffset = fract(sin(dot(starPosition, vec2(12.9898, 78.233))) * 43758.5453);
  starPosition += vec2(randomOffset * 2.0 - 1.0) * 0.1;
  float starIntensity = smoothstep(0.90, 1.0, fract(starPosition.x * starPosition.y + u_Time));

  // Calculate the adjusted star size based on the starIntensity
  float adjustedStarSize = starSize + starSize * starIntensity;

  // Calculate the distance from the star position to the center
  float distanceFromCenter = distance(starPosition, vec2(0.5));

  // Calculate the star glow intensity based on the adjusted star size
  float starGlowIntensity = smoothstep(adjustedStarSize - 0.4, adjustedStarSize, distanceFromCenter);
  
  // Define the star color
  vec3 starColor = vec3(1.0); // White star color

  // Apply the stars on top of the purple color with the adjusted size and glow intensity
  vec3 finalColor = mix(blendedColor, starColor, starIntensity) + starGlowIntensity;

  // Output the final color
  gl_FragColor = vec4(finalColor, texColor.a);
  if(gl_FragColor.a < 0.01) discard;
}
