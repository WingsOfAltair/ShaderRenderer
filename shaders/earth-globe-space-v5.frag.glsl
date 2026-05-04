#version 330 core

out vec4 FragColor;

uniform vec2 uResolution;
uniform float uTime;

// =====================================================
// NOISE
// =====================================================
float hash(vec2 p){
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p+34.345);
    return fract(p.x*p.y);
}

float noise(vec2 p){
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i+vec2(1,0));
    float c = hash(i+vec2(0,1));
    float d = hash(i+vec2(1,1));

    vec2 u = f*f*(3.0-2.0*f);

    return mix(a,b,u.x) + (c-a)*u.y*(1.0-u.x) + (d-b)*u.x*u.y;
}

float fbm(vec2 p){
    float v=0.0;
    float a=0.5;
    for(int i=0;i<5;i++){
        v += a*noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// =====================================================
// ROTATION
// =====================================================
mat2 rot(float a){
    float s=sin(a),c=cos(a);
    return mat2(c,-s,s,c);
}

// =====================================================
// SPHERE RAY INTERSECTION
// =====================================================
float sphere(vec3 ro, vec3 rd, float r){
    float b = dot(ro,rd);
    float c = dot(ro,ro)-r*r;
    float h = b*b - c;
    if(h<0.0) return -1.0;
    return -b - sqrt(h);
}

// =====================================================
// EARTH SURFACE (improved continents)
// =====================================================
vec3 earth(vec3 p){
    float lat = asin(p.y);
    float lon = atan(p.z,p.x);

    vec2 uv = vec2(lon,lat);

    float land = fbm(uv*6.0);
    float detail = fbm(uv*25.0);

    float c = smoothstep(0.45,0.6,land);

    vec3 ocean = vec3(0.02,0.06,0.25);
    vec3 landC = vec3(0.05,0.28,0.10);

    return mix(ocean,landC,c) + detail*0.04;
}

// =====================================================
// ATMOSPHERIC SCATTERING (physically inspired approx)
// =====================================================
vec3 atmosphere(vec3 viewDir, vec3 lightDir, vec3 normal){
    float mu = max(dot(viewDir, normal), 0.0);
    float sun = max(dot(lightDir, normal), 0.0);

    float rayleigh = pow(1.0 - mu, 5.0);
    float mie = pow(1.0 - sun, 2.0);

    vec3 sky = vec3(0.35,0.65,1.3);

    return sky * (rayleigh*0.8 + mie*0.3);
}

// =====================================================
// STARFIELD (3D depth illusion)
// =====================================================
float stars(vec2 uv, float scale){
    vec2 gv = fract(uv*scale)-0.5;
    vec2 id = floor(uv*scale);

    float h = hash(id);
    float d = length(gv);

    return smoothstep(0.02,0.0,d) * step(0.98,h);
}

// =====================================================
// GALAXY FIELD
// =====================================================
vec3 galaxy(vec2 uv, vec2 c, vec3 col){
    vec2 p = uv-c;

    float r = length(p);
    float a = atan(p.y,p.x);

    float spiral = sin(3.0*a + r*8.0 - uTime*0.1);
    float glow = exp(-r*2.5);
    float core = exp(-r*14.0);

    return col * (glow*(0.6+0.4*spiral) + core);
}

// =====================================================
// BLACK HOLE LENSING (fake GR warp)
// =====================================================
vec2 lens(vec2 uv){
    float r = dot(uv,uv);
    return uv + uv * (0.15 / (r + 0.05));
}

// =====================================================
// MOON
// =====================================================
vec3 moonPos(){
    float t = uTime*0.3;
    return vec3(1.6*cos(t),0.2,1.6*sin(t));
}

// =====================================================
// MAIN
// =====================================================
void main(){

    vec2 uv = (gl_FragCoord.xy/uResolution.xy)*2.0-1.0;
    uv.x *= uResolution.x/uResolution.y;

    uv = lens(uv);

    vec3 ro = vec3(0.0,0.0,3.0);
    vec3 rd = normalize(vec3(uv,-1.5));

    float t = uTime*0.2;

    ro.xz *= rot(t);
    rd.xz *= rot(t*0.8);

    vec3 col = vec3(0.0);

    // ================= EARTH =================
    float hit = sphere(ro,rd,1.0);

    vec3 sunDir = normalize(vec3(1.0,0.3,0.2));

    if(hit>0.0){
        vec3 p = ro + rd*hit;
        vec3 n = normalize(p);

        vec3 base = earth(n);

        float diff = max(dot(n,sunDir),0.0);
        float night = 1.0 - diff;

        vec3 light = base*(0.2+diff);

        // city lights approximation
        float city = fbm(vec2(atan(n.z,n.x),asin(n.y))*40.0);
        light += vec3(1.0,0.9,0.6)*smoothstep(0.6,0.9,city)*night;

        // clouds
        float cl = fbm(vec2(atan(n.z,n.x),asin(n.y))*10.0 + uTime*0.01);
        light = mix(light, vec3(1.0), smoothstep(0.55,0.75,cl)*0.3);

        // atmosphere (key realism layer)
        light += atmosphere(rd,sunDir,n);

        col = light;
    }
    else{

        // ================= SPACE =================
        vec3 space = vec3(0.0);

        space += stars(uv+uTime*0.01,60.0);
        space += stars(uv+uTime*0.02,150.0);
        space += stars(uv+uTime*0.03,300.0);

        space += galaxy(uv,vec2(-0.5,0.3),vec3(0.8,0.5,1.3));
        space += galaxy(uv,vec2(0.6,-0.4),vec3(1.2,0.6,0.3));

        // faint nebula
        space += fbm(uv*3.0+uTime*0.02)*0.15;

        col = space;
    }

    // ================= MOON =================
    vec3 mp = moonPos();
    vec3 mdir = mp - ro;

    float mb = dot(rd, mdir);
    float mc = dot(mdir, mdir) - 0.27;
    float mh = mb*mb - mc;

    if(mh>0.0){
        col = mix(col, vec3(0.7), 0.8);
    }

    // gamma correction
    col = pow(col, vec3(0.95));

    FragColor = vec4(col,1.0);
}