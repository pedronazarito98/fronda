export const VERTEX_SHADER = `
precision highp float;
attribute vec2 aUV;
attribute vec4 aFilament;
attribute float aFilamentBranch;
uniform vec2 uPivot[5];
uniform vec2 uCrown[5];
uniform float uAngle[5];
uniform float uCap[5];
uniform float uBend[5];
uniform float uGrowth[5];
uniform float uBloom[5];
uniform vec4 uFilament[5];
uniform vec4 uBody;
uniform vec2 uPosition;
uniform float uScale;
uniform float uTime;
varying vec2 vUV;
vec2 rotate(vec2 p, vec2 center, float angle) {
  float c = cos(angle), s = sin(angle);
  vec2 d = p - center;
  return center + vec2(c*d.x-s*d.y, s*d.x+c*d.y);
}
// Arc deformation distributes curvature along the stalk instead of hinging it.
vec2 curve(vec2 p, vec2 pivot, vec2 crown, float bend, float growth) {
  float stalkLength = distance(crown, pivot);
  vec2 axis = (crown-pivot)/stalkLength;
  vec2 normal = vec2(-axis.y, axis.x);
  float along = dot(p-pivot,axis);
  float s = clamp(along/stalkLength,0.0,1.0);
  float angle = bend*s;
  vec2 center = pivot + axis*(stalkLength*s);
  if(abs(bend)>.0001) center = pivot + stalkLength*(axis*sin(angle)+normal*(1.0-cos(angle)))/bend;
  center = pivot + (center-pivot)*(1.0+growth);
  vec2 residual = p-pivot-axis*(stalkLength*s);
  residual -= normal*dot(residual,normal)*growth*.22;
  return center+rotate(residual,vec2(0.0),angle);
}
void main() {
  vUV = aUV;
  vec2 p = aUV;
  float w[5];
  w[0] = (1.0-smoothstep(.34,.57,p.y)) * smoothstep(.36,.48,p.x);
  w[1] = (1.0-smoothstep(.32,.435,p.x)) * (1.0-smoothstep(.405,.48,p.y));
  w[2] = (1.0-smoothstep(.31,.444,p.x)) * smoothstep(.405,.48,p.y) * (1.0-smoothstep(.685,.75,p.y));
  w[3] = smoothstep(.57,.735,p.x) * smoothstep(.34,.40,p.y) * (1.0-smoothstep(.59,.65,p.y));
  w[4] = smoothstep(.535,.69,p.x) * smoothstep(.58,.65,p.y) * (1.0-smoothstep(.82,.87,p.y));
  // Keep the textured crowns cohesive while the connecting stems bend.
  w[0] = max(w[0],1.0-smoothstep(.85,1.2,length((p-vec2(.70,.19))/vec2(.145,.17))));
  w[1] = max(w[1],1.0-smoothstep(.85,1.2,length((p-vec2(.25,.32))/vec2(.145,.115))));
  w[2] = max(w[2],1.0-smoothstep(.85,1.2,length((p-vec2(.25,.56))/vec2(.14,.115))));
  w[3] = max(w[3],1.0-smoothstep(.85,1.2,length((p-vec2(.842,.495))/vec2(.115,.12))));
  w[4] = max(w[4],1.0-smoothstep(.85,1.2,length((p-vec2(.746,.705))/vec2(.105,.115))));
  vec2 shift = vec2(0.0);
  float total = 0.0;
  for(int i=0;i<5;i++) {
    vec2 tissue = p;
    if(abs(aFilamentBranch-float(i))<.1 && aFilament.z>0.0) {
      float wave = sin(uTime*1.75-aFilament.w)*.68+sin(uTime*.89+aFilament.w*1.43)*.32;
      float swing = (uFilament[i].x + wave*uFilament[i].w) * aFilament.z;
      vec2 root = aFilament.xy;
      tissue.y += (p.y-root.y)*(uFilament[i].y+wave*uFilament[i].w*.30)*aFilament.z;
      tissue.x += (root.x-uCrown[i].x)*uFilament[i].z*aFilament.z;
      tissue = rotate(tissue,root,swing);
    }
    float capWeight = 1.0-smoothstep(.08,.22,distance(p,uCrown[i]));
    tissue += (tissue-uCrown[i])*vec2(uBloom[i],uBloom[i]*.38)*capWeight;
    vec2 q = curve(tissue,uPivot[i],uCrown[i],uBend[i],uGrowth[i]);
    vec2 curvedCrown = curve(uCrown[i],uPivot[i],uCrown[i],uBend[i],uGrowth[i]);
    // The cap retains its volume while its connecting stalk flexes.
    vec2 firmCap = curvedCrown + rotate(tissue-uCrown[i],vec2(0.0),uBend[i]);
    q = mix(q,firmCap,capWeight);
    q = rotate(q,uPivot[i],uAngle[i]);
    vec2 crown = rotate(curvedCrown,uPivot[i],uAngle[i]);
    q = rotate(q,crown,uCap[i]*capWeight);
    shift += (q-p)*w[i];
    total += w[i];
  }
  p += shift/max(1.0,total);
  p.y = .932 + (p.y-.932)*uBody.y;
  p.x = .50 + (p.x-.50)*(1.0-(uBody.y-1.0)*.32);
  p = rotate(p,vec2(.50,.932),uBody.x);
  p.y -= uBody.z + uBody.w;
  p = (p-vec2(.5))*uScale + vec2(.5) + uPosition;
  gl_Position = vec4(p.x*2.0-1.0,1.0-p.y*2.0,0.0,1.0);
}`;

export const FRAGMENT_SHADER = `
precision highp float;
uniform sampler2D uTexture;
uniform vec4 uTip[5];
uniform float uTipStrength[5];
uniform vec3 uColor;
uniform vec2 uEyes[2];
uniform vec2 uGaze;
uniform float uBlink;
varying vec2 vUV;
void main() {
  vec2 sampleUV = vUV;
  for(int eye=0;eye<2;eye++) {
    vec2 d = vUV-uEyes[eye];
    float zone = 1.0-smoothstep(.6,1.7,length(d/vec2(.025,.036)));
    sampleUV -= uGaze*vec2(.0055,.0035)*zone;
    float eyeCore = 1.0-smoothstep(.8,1.5,length(d/vec2(.022,.035)));
    sampleUV.y += d.y*(1.0/max(.16,uBlink)-1.0)*eyeCore;
  }
  vec4 pixel = texture2D(uTexture,sampleUV);
  if(pixel.a<.035) discard;
  float tint = 0.0;
  for(int i=0;i<5;i++) {
    vec2 distanceToTip = (vUV-uTip[i].xy)/uTip[i].zw;
    float mask = 1.0-smoothstep(.42,1.05,length(distanceToTip));
    tint = max(tint,mask*uTipStrength[i]);
  }
  float luminance = dot(pixel.rgb,vec3(.2126,.7152,.0722));
  vec3 pigment = uColor*(.35+luminance*.95);
  pixel.rgb = mix(pixel.rgb,pigment,clamp(tint*.94,0.0,.94));
  gl_FragColor = vec4(pixel.rgb*pixel.a,pixel.a);
}`;
