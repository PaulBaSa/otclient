
uniform float u_Time;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

void main()
{
  float rainbowSpeed = 0.05; // Adjust the rainbow animation speed here
  float rainbowWidth = 0.007; // Adjust the width of the rainbow lines
  
  float animationProgress = mod(u_Time * rainbowSpeed, 0.032);
  
  float rainbowPos = mod(v_TexCoord.y + animationProgress, 0.032);
  vec3 rainbowColor = vec3(0.0);
  
  // Calculate the rainbow color based on the position
  if (rainbowPos < rainbowWidth) {
    rainbowColor.r = 1.0;
  } else if (rainbowPos < 2.0 * rainbowWidth) {
    rainbowColor.r = 1.0;
    rainbowColor.g = 1.0;
  } else if (rainbowPos < 3.0 * rainbowWidth) {
    rainbowColor.g = 1.0;
  } else if (rainbowPos < 4.0 * rainbowWidth) {
    rainbowColor.g = 1.0;
    rainbowColor.b = 1.0;
  } else {
    rainbowColor.b = 1.0;
  }
  
  // Retrieve the color from the texture
  vec4 texColor = texture2D(u_Tex0, v_TexCoord);
  
  // Blend the rainbow color with the texture color
  vec3 blendedColor = mix(texColor.rgb, texColor.rgb * rainbowColor, 1.0);
  vec4 finalColor = vec4(blendedColor, texColor.a);
  
  // Output the final color
  gl_FragColor = finalColor;
}
