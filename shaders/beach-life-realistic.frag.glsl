#version 330 core

out vec4 FragColor;

uniform vec2 uResolution;
uniform float uTime;

// =====================================================
// � GLOBAL TIME (SLOW CINEMATIC SCALE)
// =====================================================
float T = uTime * 0.03;

// =====================================================
// � CAMERA
// =====================================================
vec2 camera(){
    return vec2(
        sin(T) * 0.4,
        cos(T * 0.6) * 0.08
    );
}

// =====================================================
// � WORLD SPACE
// =====================================================
vec2 getWorld(vec2 fragCoord, vec2 cam){
    return (fragCoord - 0.5 * uResolution.xy) / uResolution.y + cam;
}

// =====================================================
// � NOISE
// =====================================================
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

// =====================================================
// � WAVES (CINEMATIC SLOW)
// =====================================================
float waveHeight(vec2 p){
    float w = 0.0;
    w += sin(p.x*6.0 + T*1.2)*0.06;
    w += sin(p.x*12.0 - T*1.4)*0.03;
    w += noise(p*2.0 + T*0.2)*0.04;
    return w;
}

// =====================================================
// � FOAM
// =====================================================
float foam(vec2 p, float shoreY){
    float d = abs(p.y - shoreY - waveHeight(vec2(p.x,0.0))*0.2);
    float band = smoothstep(0.03, 0.0, d);
    float motion = noise(p*8.0 + T*2.0);
    return band * (0.6 + motion*0.4);
}

// =====================================================
// � PERSON
// =====================================================
float person(vec2 uv, vec2 pos){
    uv -= pos;

    float head = smoothstep(0.012,0.0,length(uv-vec2(0.0,0.09)));
    float body = smoothstep(0.015,0.0,length(uv-vec2(0.0,0.05)));

    float stepAnim = sin(T*1.5 + pos.x*2.0);
    float legs = smoothstep(0.008,0.0,length(uv-vec2(0.0, stepAnim*0.015)));

    return head + body + legs;
}

// =====================================================
// � SWIMMER
// =====================================================
float swimmer(vec2 uv, vec2 pos){
    vec2 p = uv - pos;

    float head = smoothstep(0.01,0.0,length(p-vec2(0.0,0.05)));
    float body = smoothstep(0.02,0.0,length(p));

    float bob = sin(T*2.0 + pos.x*3.0)*0.01;

    return head + body*0.6 + bob;
}

// =====================================================
// � BOAT
// =====================================================
float boat(vec2 uv, vec2 pos){
    uv -= pos;
    return smoothstep(0.05,0.0,length(uv*vec2(2.0,0.6)));
}

// =====================================================
// � SHIP
// =====================================================
float ship(vec2 uv, vec2 pos){
    uv -= pos;
    return smoothstep(0.09,0.0,length(uv*vec2(2.5,0.7)));
}

// =====================================================
// � PALM TREE
// =====================================================
float palmTree(vec2 uv, vec2 pos){
    vec2 p = uv - pos;

    float trunk = smoothstep(0.02,0.0,abs(p.x)) *
                  smoothstep(-0.6,0.0,p.y) *
                  smoothstep(0.4,-0.2,p.y);

    float leaves = 0.0;
    for(int i=0;i<5;i++){
        float a = float(i)*1.2;
        vec2 dir = vec2(cos(a),sin(a));
        leaves += smoothstep(0.25,0.0,length(p - dir*0.15));
    }

    return clamp(trunk+leaves,0.0,1.0);
}

// =====================================================
// � RESORT
// =====================================================
float resort(vec2 uv){
    float b1 = smoothstep(0.08,0.0,length(uv-vec2(-0.4,0.3)));
    float b2 = smoothstep(0.10,0.0,length(uv-vec2(-0.1,0.28)));
    float b3 = smoothstep(0.07,0.0,length(uv-vec2(0.2,0.31)));
    float base = smoothstep(0.05,0.0,abs(uv.y-0.25));
    return base + b1 + b2 + b3;
}

// =====================================================
// � WIND
// =====================================================
vec2 wind(){
    return vec2(sin(T*0.5)*0.5, 0.0);
}

// =====================================================
// � MAIN
// =====================================================
void main(){

    vec2 uv = getWorld(gl_FragCoord.xy, camera());

    const float horizon = 0.2;
    const float sandTop = -0.25;
    const float sandBottom = -0.55;

    float cycle = mod(T*0.6, 1.0);

    // =================================================
    // � SKY
    // =================================================
    vec3 skyDay = vec3(0.2,0.6,0.95);
    vec3 skySunset = vec3(1.0,0.4,0.2);
    vec3 skyNight = vec3(0.02,0.02,0.08);

    vec3 skyTop =
        (cycle < 0.5)
        ? mix(skyDay, skySunset, cycle*2.0)
        : mix(skySunset, skyNight, (cycle-0.5)*2.0);

    vec3 color = mix(vec3(1.0,0.7,0.4), skyTop, uv.y);

    // =================================================
    // � WATER
    // =================================================
    if(uv.y < horizon){

        vec3 shallow = vec3(0.0,0.55,0.65);
        vec3 deep = vec3(0.01,0.15,0.28);

        float depth = smoothstep(-0.2, horizon, uv.y);

        vec3 water = mix(shallow, deep, depth);
        water += vec3(0.0,0.2,0.3) * waveHeight(uv*2.0);

        float f = foam(uv, horizon);
        water += vec3(1.0) * f;

        color = water;
    }

    // =================================================
    // �️ SAND
    // =================================================
    if(uv.y < sandTop && uv.y > sandBottom){
        vec3 sand = vec3(0.92,0.82,0.55);
        sand += noise(uv*50.0)*0.03;
        color = sand;
    }

    // =================================================
    // � FOG
    // =================================================
    float fog = smoothstep(-0.6,0.6,uv.y);
    color = mix(color, vec3(0.05), fog*0.4);

    // =================================================
    // � PEOPLE (BEACH)
    // =================================================
    float ppl = 0.0;

    for(int i=0;i<6;i++){
        float x = fract(sin(float(i)*53.2)*43758.5453)*2.0-1.0;
        vec2 p = vec2(x,(sandTop+sandBottom)*0.5);
        ppl += person(uv,p);
    }

    color = mix(color, vec3(0.05), ppl);

    // =================================================
    // � SWIMMERS
    // =================================================
    float swim = 0.0;

    for(int i=0;i<5;i++){
        float x = fract(sin(float(i)*77.1)*43758.5453)*2.0-1.0;

        vec2 s = vec2(
            x,
            horizon - 0.05 - abs(sin(T + float(i)))*0.08
        );

        swim += swimmer(uv,s);
    }

    color = mix(color, vec3(0.05), swim);

    // =================================================
    // � TREES (WIND)
    // =================================================
    float trees = 0.0;
    vec2 w = wind();

    for(int i=0;i<10;i++){
        float x = fract(sin(float(i)*91.17)*43758.5453)*2.0-1.0;
        vec2 t = vec2(x + sin(T + x*5.0)*0.02, sandBottom-0.05);
        trees += palmTree(uv,t);
    }

    color = mix(color, vec3(0.02,0.08,0.02), trees);

    // =================================================
    // � BOATS
    // =================================================
    float boats = 0.0;

    for(int i=0;i<6;i++){
        float x = fract(sin(float(i)*12.9)*43758.5453)*2.0-1.0;
        vec2 b = vec2(x, horizon + waveHeight(vec2(x,0.0))*0.2);
        boats += boat(uv,b);
    }

    // =================================================
    // � SHIPS
    // =================================================
    float ships = 0.0;

    for(int i=0;i<3;i++){
        float x = fract(sin(float(i)*91.1)*43758.5453)*2.0-1.0;
        vec2 s = vec2(x, horizon-0.08);
        ships += ship(uv,s);
    }

    color = mix(color, vec3(0.05), boats);
    color = mix(color, vec3(0.02), ships);

    // =================================================
    // � RESORT
    // =================================================
    float r = resort(uv);
    color = mix(color, vec3(0.03), r*0.6);

    FragColor = vec4(color,1.0);
}