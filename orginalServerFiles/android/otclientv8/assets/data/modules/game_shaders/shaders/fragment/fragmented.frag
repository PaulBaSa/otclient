
uniform sampler2D u_Texture;
varying vec2 v_TexCoord;
uniform float u_Time;  // Elapsed time for animation

void main() {
    // Retrieve the color from the texture
    vec4 texColor = texture2D(u_Texture, v_TexCoord);

    // Calculate the glitch effect
    float glitchX = sin(v_TexCoord.y * 50.0 + u_Time * 5.0);
    float glitchY = cos(v_TexCoord.x * 30.0 + u_Time * 10.0);
    vec2 glitchOffset = vec2(glitchX, glitchY) * 0.01;

    // Apply the glitch offset to the texture coordinates
    vec2 offsetTexCoord = v_TexCoord + glitchOffset;

    // Retrieve the color from the offset texture coordinates
    vec4 glitchColor = texture2D(u_Texture, offsetTexCoord);

    // Mix the original color with the glitch color
    float mixAmount = 0.5 + sin(u_Time * 10.0) * 0.5;
    vec4 finalColor = mix(texColor, glitchColor, mixAmount);

    gl_FragColor = finalColor;
}
