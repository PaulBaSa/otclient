uniform float u_Time;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

vec4 sepia(vec4 color)
{
    // Ajuste para um azul mais forte e escuro
    float r = dot(color, vec4(.1, .05, .05, .0));
    float g = dot(color, vec4(.1, .05, .05, .0));
    float b = dot(color, vec4(.2, .2, .8, .0)); // Aumentar a influência do azul
    return vec4(r, g, b, 1.0);
}

void main()
{
    vec4 color = texture2D(u_Tex0, v_TexCoord);
    vec4 sepiaColor = sepia(color);

    // Ajustar a intensidade do efeito sepia
    float intensity = 0.5; // Aumenta a intensidade do efeito para dar mais presença ao azul
    vec4 finalColor = mix(color, sepiaColor, intensity);

    // Ajustar a transparência
    float transparency = 1.0; // Manter opaco para um efeito mais forte
    finalColor.a *= transparency;

    gl_FragColor = finalColor;
}
