#version 330 core

// Must match the 'out' from vertex shader
in vec2 vTexCoord;

// Uniforms
uniform float time;
uniform vec2 ctr;
uniform sampler2D u_tex; 
uniform vec3 colorTop;
uniform vec3 colorBottom;

// In version 330, we define our own output color variable
out vec4 FragColor;

void main()
{
  float maxRad = 0.16;
  vec2 p = vTexCoord; // Using the 'in' variable from vertex shader

  // 1. Calculate Gradient
  vec3 backgroundCol = mix(colorBottom, colorTop, p.y);

  // 2. Ripple Logic
  float distFromCtr = distance(p, ctr);  
  float outerBoundary = maxRad * time;
  
  float maxAmp;
  if (time < 0.1) {
    maxAmp = time / 0.1;
  } else {
    maxAmp = -log(max(0.001, time * 50.0)); 
  }
  maxAmp *= 0.05;

  float amp0 = maxAmp * max(0.0, sin(1.57 * distFromCtr / outerBoundary) / (0.1 + 10.0 * distance(distFromCtr, outerBoundary)));
  amp0 *= step(distFromCtr, outerBoundary);

  vec2 uvDistorted = p + p * amp0 * sin(distFromCtr * 180.0 + 3.14157 * time);
  
  // 3. Sampling and Blending
  vec4 texColor = texture(u_tex, uvDistorted);
  vec3 finalCol = mix(backgroundCol, texColor.rgb, texColor.a);

  FragColor = vec4(finalCol, 1.0);
}