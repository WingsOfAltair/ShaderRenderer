#version 430 core

out vec4 FragColor;

uniform float uTime;
uniform vec2  uResolution;
uniform sampler2D iChannel0;

vec2 rotate2D(vec2 p, float tf)
{
    float s  = sin(tf);
    float sk = cos(tf / max(uTime, 0.001)); // avoid div by zero
    return mat2(sk, -s, s, sk) * p;
}

void main()
{
    vec2 fragCoord = gl_FragCoord.xy;

    vec2 p = (fragCoord * 2.0 - uResolution);
    p /= min(uResolution.x, uResolution.y);

    float fft  = texture(iChannel0, vec2(p.x * 0.5 + 0.5, 3.33)).x;
    float wave = texture(iChannel0, vec2(p.x * 0.5 + 0.5, 1.0)).x;

    fft  = max(fft,  0.0001); // prevent NaN
    wave = max(wave, 0.0001);

    vec3 rColor = vec3(0.7*fft, 0.1*fft, 0.8*fft);
    vec3 gColor = vec3(0.0, 1.8*wave, 1.3*fft);
    vec3 bColor = vec3(0.0, 1.3*fft, 1.8/fft);
    vec3 yColor = vec3(0.7*fft, 1.8*wave, 0.3);

    float a,b,c,d,e,f,g,h;

    p = rotate2D(p, uTime);

    for(int i = 0; i < 32; i++) // FIXED LOOP
    {
        float fi = float(i);

        float factor = (sin(uTime) * 0.33 + 0.33) + 1.33;
        float tf = (fi + factor) / 3.0;

        a = sin(p.y * 3.33 - uTime * 6.66) / tf;
        e = 0.01 / abs(p.x + a);

        b = sin(p.y * 3.33 - uTime * 3.33) / tf;
        f = 0.01 / abs(p.x + b);

        c = sin(p.y * 6.66 - uTime * 8.88) / tf;
        g = 0.01 / abs(p.x + c);

        d = sin(p.y * 1.11 - uTime * 8.22) / tf;
        h = 0.01 / abs(p.x + d);

        yColor += 0.33 - smoothstep(0.33, 0.10, abs(wave - p.y / tf));
    }

    vec3 destColor = rColor * e + gColor * f + bColor * g + yColor * h;

    FragColor = vec4(destColor, 1.0);
}