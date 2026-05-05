#version 330 core

out vec4 FragColor;

uniform vec2 uResolution;
uniform float uTime;

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

// ------------------ PERSON ------------------
float person(vec2 uv, vec2 pos){
    uv -= pos;

    float head = smoothstep(0.012,0.0,length(uv-vec2(0.0,0.09)));
    float body = smoothstep(0.015,0.0,length(uv-vec2(0.0,0.05)));

    float stepAnim = sin(uTime*3.0 + pos.x*10.0);

    float leg1 = smoothstep(0.008,0.0,length(uv-vec2(-0.01, stepAnim*0.015)));
    float leg2 = smoothstep(0.008,0.0,length(uv-vec2(0.01,-stepAnim*0.015)));

    return head + body + leg1 + leg2;
}

// ------------------ BOAT ------------------
float boat(vec2 uv, vec2 pos){
    uv -= pos;

    float hull = smoothstep(0.05, 0.0, length(uv*vec2(2.0,0.6)));
    float mast = smoothstep(0.004, 0.0, abs(uv.x)) *
                 step(uv.y, 0.08) * step(-0.02, uv.y);

    return clamp(hull + mast, 0.0, 1.0);
}

// ------------------ SHIP ------------------
float ship(vec2 uv, vec2 pos){
    uv -= pos;

    float body = smoothstep(0.09, 0.0, length(uv*vec2(2.5,0.7)));
    float cabin = smoothstep(0.03, 0.0, length(uv-vec2(0.0,0.03)));

    return clamp(body + cabin, 0.0, 1.0);
}

// ------------------ MAIN ------------------
void main(){

    vec2 uv = gl_FragCoord.xy / uResolution.xy;
    uv.x *= uResolution.x / uResolution.y;

    float horizon = 0.52;
    float sandLevel = 0.28;

    // ---------------- DAY / NIGHT ----------------
    float cycle = mod(uTime*0.02, 1.0);

    vec3 skyDayTop = vec3(0.2,0.6,0.95);
    vec3 skySunset = vec3(1.0,0.4,0.2);
    vec3 skyNight = vec3(0.02,0.02,0.08);

    vec3 skyTop =
        (cycle < 0.5)
        ? mix(skyDayTop, skySunset, cycle*2.0)
        : mix(skySunset, skyNight, (cycle-0.5)*2.0);

    vec3 skyBottom = mix(vec3(1.0,0.7,0.4), vec3(0.05,0.05,0.1), cycle);

    vec3 color = mix(skyBottom, skyTop, uv.y);

    vec2 sunPos = vec2(0.7, 0.75 - cycle*0.7);
    vec2 moonPos = vec2(0.3, 0.75 - cycle*0.7);

    float sun = smoothstep(0.2,0.0,length(uv-sunPos));
    float moon = smoothstep(0.15,0.0,length(uv-moonPos));

    vec3 lightDir = normalize(vec3(sunPos - uv, 0.5));

    color += vec3(1.0,0.85,0.5)*sun*(1.0-cycle);
    color += vec3(0.6,0.7,1.0)*moon*cycle;

    // ---------------- WATER (REALISM PASS) ----------------
    if(uv.y < horizon){

        float depth = smoothstep(0.0, horizon, uv.y);

        vec3 deep = vec3(0.01,0.15,0.28);
        vec3 shallow = vec3(0.0,0.55,0.65);

        vec3 water = mix(shallow, deep, depth);

        vec3 n = getNormal(uv*2.0);

        float fresnel = pow(1.0 - max(dot(n, vec3(0,1,0)),0.0), 4.0);
        float spec = pow(max(dot(reflect(lightDir,n), vec3(0,1,0)),0.0), 60.0);

        water += vec3(1.0,0.85,0.6)*spec*(1.0-cycle);
        water += vec3(0.2,0.4,0.6)*fresnel;

        color = water;
    }

    // ---------------- SAND ----------------
    if(uv.y < sandLevel){
        vec3 sand = vec3(0.92,0.82,0.55);
        sand += noise(uv*60.0)*0.04;

        float wet = smoothstep(sandLevel, horizon, uv.y);
        sand *= mix(1.0, 0.7, wet);

        color = sand;
    }

    // ---------------- ATMOSPHERE ----------------
    float fog = smoothstep(0.2, horizon + 0.1, uv.y);
    vec3 fogColor = mix(vec3(0.9,0.7,0.5), vec3(0.05,0.05,0.1), cycle);
    color = mix(color, fogColor, fog*0.6);

    // ---------------- PEOPLE (SAND ONLY) ----------------
    float ppl = 0.0;

    vec2 p1 = vec2(mod(uTime*0.08,1.2)-0.1, sandLevel-0.02);
    vec2 p2 = vec2(0.55, sandLevel-0.015);
    vec2 p3 = vec2(0.65, sandLevel-0.018);

    if(p1.y < sandLevel) ppl += person(uv,p1);
    if(p2.y < sandLevel) ppl += person(uv,p2);
    if(p3.y < sandLevel) ppl += person(uv,p3);

    color = mix(color, vec3(0.05), ppl);

    // ---------------- FOAM ----------------
    float foam = smoothstep(0.01,0.0, abs(uv.y-(horizon+waveHeight(uv*2.0))));
    color += vec3(1.0)*foam*0.5;

    // ---------------- BOATS + WAKES ----------------
    float boats = 0.0;
    float ships = 0.0;

    for(int i=0;i<5;i++){
        float fi = float(i);

        float x = 0.1 + fi*0.2 + sin(uTime*0.4+fi)*0.02;
        vec2 bpos = vec2(fract(x), horizon-0.03);

        float w = waveHeight(bpos*2.0);
        bpos.y += w;

        // wake boost
        vec2 wake = bpos + vec2(-0.04,0.0);
        float wakeMask = smoothstep(0.1,0.0,length(uv-wake));
        color += vec3(0.2,0.3,0.4)*wakeMask*0.3;

        if(bpos.y < horizon+0.05){
            boats += boat(uv,bpos);
        }
    }

    for(int i=0;i<3;i++){
        float fi = float(i);

        float x = 0.2 + fi*0.3 + sin(uTime*0.1+fi)*0.01;
        vec2 spos = vec2(fract(x), horizon-0.08);

        float w = waveHeight(spos*2.0);
        spos.y += w*0.5;

        vec2 trail = spos + vec2(-0.06,0.0);
        float shipWake = smoothstep(0.15,0.0,length(uv-trail));
        color += vec3(0.2,0.3,0.4)*shipWake*0.25;

        if(spos.y < horizon+0.08){
            ships += ship(uv,spos);
        }
    }

    color = mix(color, vec3(0.05), boats);
    color = mix(color, vec3(0.02), ships);

    FragColor = vec4(color,1.0);
}