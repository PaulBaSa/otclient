
uniform float u_Time;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

float random(vec2 st)
{
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void main()
{
  float flameSpeed = 0.1; // Adjust the flame animation speed here
  float flameIntensity = 0.5; // Adjust the intensity of the flame effect
  float flameWaveIntensity = 2.9; // Adjust the intensity of the flame waves
  float auraIntensity = 0.8; // Adjust the intensity of the aura outline
  
  float animationProgress = mod(u_Time * flameSpeed, 0.5);
  
  // Calculate the flame position based on the texture coordinates
  vec2 distortedCoord = v_TexCoord + vec2(0.0, sin(v_TexCoord.x * 10.0 + u_Time) * 0.01);
  float flamePos = clamp(distortedCoord.y + animationProgress, 0.0, 1.0);
  
  // Calculate the flame color based on the position
  vec3 baseFlameColor = vec3(1.0, 0.5, 0.0);
  vec3 flameColor = baseFlameColor + vec3(0.4, 0.2, 0.0) * flamePos * flameIntensity;
  
  // Add flame wave effect
  float noise = random(v_TexCoord * 0.2 + vec2(u_Time * 0.01));
  flamePos += noise * flameWaveIntensity;
  
  // Retrieve the color from the texture
  vec4 texColor = texture2D(u_Tex0, v_TexCoord);
  
  // Blend the flame color with the texture color
  vec3 blendedColor = mix(texColor.rgb, flameColor, flamePos);
  
  // Add aura outline
  float auraThreshold = 0.4;
  vec3 auraColor = vec3(1.0, 1.0, 1.0);
  vec3 finalColor = mix(auraColor, blendedColor, smoothstep(auraThreshold - auraIntensity, auraThreshold, flamePos));
  
  
  // Output the final color
  gl_FragColor = vec4(finalColor, texColor.a);
  if(gl_FragColor.a < 0.01) discard;
}
