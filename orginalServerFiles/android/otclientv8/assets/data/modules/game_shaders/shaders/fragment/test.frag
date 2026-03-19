
uniform sampler2D u_Texture;
varying vec2 v_TexCoord;
uniform float u_Time;

void main() {
    vec4 texColor = texture2D(u_Texture, v_TexCoord);

    // Define the center point of the energy field
    vec2 center = vec2(0.5, 0.5);

    // Calculate the distance from the current texture coordinate to the center
    float distance = length(v_TexCoord - center);

    // Calculate the pulsating effect using sine function
    float pulsate = sin(u_Time * 5.0 + distance * 10.0) * 0.5 + 0.5;

    // Define the color of the energy field
    vec3 energyColor = vec3(0.0, 1.0, 1.0); // Cyan

    // Apply the pulsating effect to the energy field color
    vec3 finalColor = mix(texColor.rgb, energyColor, pulsate);

    gl_FragColor = vec4(finalColor, texColor.a);
}
