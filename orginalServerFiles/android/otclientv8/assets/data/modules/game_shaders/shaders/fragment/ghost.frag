
uniform sampler2D u_Tex0; // Model texture
uniform sampler2D u_SmokeTexture; // Smoke texture
uniform sampler2D u_AlphaMask; // Alpha mask texture
uniform float u_Time; // Time uniform for animation
varying vec2 v_TexCoord;

const float smokeIntensity = 5.5; // Adjust the intensity of the smoke effect
const float smokeSpeed = 1.0; // Adjust the speed of the smoke animation

void main()
{
  // Retrieve the color from the model texture
  vec4 texColor = texture2D(u_Tex0, v_TexCoord);

  // Calculate the offset for the smoke animation based on time and texture coordinates
  vec2 smokeOffset = vec2(0.0, -u_Time * smokeSpeed);

  // Retrieve the color from the smoke texture with applied offset
  vec4 smokeColor = texture2D(u_SmokeTexture, v_TexCoord + smokeOffset);

  // Retrieve the alpha value from the alpha mask texture
  float alphaMaskValue = texture2D(u_AlphaMask, v_TexCoord).r;

  // Apply a mask to control the intensity of the smoke
  smokeColor.rgb *= smoothstep(0.2, 1.0, smokeColor.rgb);

  // Calculate the smoke color (black with adjusted transparency)
  vec4 finalSmokeColor = vec4(0.0, 0.0, 0.0, smokeIntensity) * smokeColor;

  // Blend the smoke color with the texture color based on the alpha mask
  vec4 blendedColor = mix(texColor, finalSmokeColor, alphaMaskValue);

  // Output the final color
  gl_FragColor = blendedColor;
}
