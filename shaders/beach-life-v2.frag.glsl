#version 330 core

out vec4 FragColor;

uniform vec2 uResolution;
uniform float uTime;

// ------------------ CAMERA (CINEMATIC DRIFT) ------------------
vec2 cameraShake(){
    float t = uTime * 0.2;
    return vec2(
        sin(t * 1.3) * 0.02,
        cos(t * 1.7) * 0.01
    );
}

// ------------------ NOISE ------------------
float hash(vec2 p){
    return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}

float noise(vec2 p){
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i+vec2(1,0));
    float c = hash(i+vec2(0,1));
    float d = hash(i+vec2(1,1));

    vec2 u = f*f*(3.0-2.0*f);

    return mix(a,b,u.x) +
           (c-a)*u.y*(1.0-u.x) +
           (d-b)*u.x*u.y;
}

// ------------------ WAVES ------------------
float waveHeight(vec2 uv){
    float w = 0.0;
    w += sin(uv.x*10.0 + uTime*1.2)*0.05;
    w += sin(uv.x*22.0 - uTime*1.8)*0.03;
    w += noise(uv*4.0 + uTime*0.3)*0.04;
    return w;
}

vec3 getNormal(vec2 uv){
    float e = 0.002;
    float h = waveHeight(uv);
    float hx = waveHeight(uv + vec2(e,0));
    float hy = waveHeight(uv + vec2(0,e));
    return normalize(vec3(h - hx, e, h - hy));
}

// ------------------ OBJECTS ------------------
float person(vec2 uv, vec2 pos){
    uv -= pos;
    float head = smoothstep(0.012,0.0,length(uv-vec2(0.0,0.09)));
    float body = smoothstep(0.015,0.0,length(uv-vec2(0.0,0.05)));
    float stepAnim = sin(uTime*3.0 + pos.x*10.0);
    float legs = smoothstep(0.008,0.0,length(uv-vec2(0.0, stepAnim*0.015)));
    return head + body + legs;
}

float boat(vec2 uv, vec2 pos){
    uv -= pos;
    float hull = smoothstep(0.05,0.0,length(uv*vec2(2.0,0.6)));
    return hull;
}

float ship(vec2 uv, vec2 pos){
    uv -= pos;
    float body = smoothstep(0.09,0.0,length(uv*vec2(2.5,0.7)));
    return body;
}

// ------------------ MAIN ------------------
void main(){

    vec2 cam = cameraShake();

    vec2 uv = (gl_FragCoord.xy / uResolution.xy) + cam;
    uv.x *= uResolution.x / uResolution.y;

    float horizon = 0.52;
    float sandLevel = 0.28;

    float cycle = mod(uTime*0.02, 1.0);

    // ---------------- SKY ----------------
    vec3 skyDay = vec3(0.2,0.6,0.95);
    vec3 skySunset = vec3(1.0,0.4,0.2);
    vec3 skyNight = vec3(0.02,0.02,0.08);

    vec3 skyTop =
        (cycle < 0.5)
        ? mix(skyDay, skySunset, cycle*2.0)
        : mix(skySunset, skyNight, (cycle-0.5)*2.0);

    vec3 skyBottom = mix(vec3(1.0,0.7,0.4), vec3(0.05,0.05,0.1), cycle);

    vec3 color = mix(skyBottom, skyTop, uv.y);

    vec2 sunPos = vec2(0.7, 0.75 - cycle*0.7);

    float sun = smoothstep(0.2,0.0,length(uv-sunPos));

    // ---------------- GOD RAYS (fake volumetric) ----------------
    float rays = 0.0;
    for(float i=0.0;i<12.0;i++){
        float a = i/12.0 * 6.283;
        vec2 dir = vec2(cos(a), sin(a))*0.002;

        rays += smoothstep(0.0,0.8, length(uv - sunPos + dir*uTime*0.1));
    }

    rays = 1.0 - rays/12.0;

    color += vec3(1.0,0.8,0.5)*rays*(1.0-cycle)*0.6;
    color += vec3(1.0,0.85,0.5)*sun*(1.0-cycle);

    // ---------------- WATER ----------------
    if(uv.y < horizon){

        vec3 deep = vec3(0.01,0.15,0.28);
        vec3 shallow = vec3(0.0,0.55,0.65);

        float depth = smoothstep(0.0, horizon, uv.y);
        vec3 water = mix(shallow, deep, depth);

        vec3 n = getNormal(uv*2.0);

        float fres = pow(1.0 - max(dot(n, vec3(0,1,0)),0.0), 4.0);
        float spec = pow(max(dot(reflect(normalize(vec3(sunPos-uv,1.0)),n), vec3(0,1,0)),0.0), 80.0);

        water += vec3(1.0,0.85,0.6)*spec*(1.0-cycle);
        water += vec3(0.2,0.4,0.6)*fres;

        // � BIOLUMINESCENCE (night ocean glow)
        float glow = noise(uv*20.0 + uTime*0.5);
        water += vec3(0.0,0.6,0.8) * glow * cycle * 0.4;

        color = water;
    }

    // ---------------- SAND ----------------
    if(uv.y < sandLevel){
        vec3 sand = vec3(0.92,0.82,0.55);
        sand += noise(uv*60.0)*0.04;
        color = sand;
    }

    // ---------------- ATMOSPHERE ----------------
    float fog = smoothstep(0.2, horizon+0.15, uv.y);
    vec3 fogColor = mix(vec3(0.9,0.7,0.5), vec3(0.05,0.05,0.1), cycle);
    color = mix(color, fogColor, fog*0.6);

    // ---------------- PEOPLE ----------------
    vec2 p1 = vec2(mod(uTime*0.08,1.2)-0.1, sandLevel-0.02);
    vec2 p2 = vec2(0.55, sandLevel-0.015);

    float ppl = 0.0;
    ppl += person(uv,p1);
    ppl += person(uv,p2);

    color = mix(color, vec3(0.05), ppl);

    // ---------------- BOATS ----------------
    float boats = 0.0;
    float ships = 0.0;

    for(int i=0;i<5;i++){
        float fi = float(i);
        vec2 bpos = vec2(0.1+fi*0.2, horizon-0.03);
        bpos.y += waveHeight(bpos*2.0);

        boats += boat(uv,bpos);
    }

    for(int i=0;i<3;i++){
        float fi = float(i);
        vec2 spos = vec2(0.2+fi*0.3, horizon-0.08);
        spos.y += waveHeight(spos*2.0)*0.5;

        ships += ship(uv,spos);
    }

    color = mix(color, vec3(0.05), boats);
    color = mix(color, vec3(0.02), ships);

    // ---------------- SIMPLE BLOOM (fake HDR) ----------------
    float brightness = dot(color, vec3(0.2126,0.7152,0.0722));
    float bloom = smoothstep(0.6,1.0,brightness);

    color += color * bloom * 0.6;

    FragColor = vec4(color,1.0);
}