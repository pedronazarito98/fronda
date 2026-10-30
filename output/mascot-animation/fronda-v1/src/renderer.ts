import type { MotionFrame, Vec2 } from './animation.types.js';
import { BASE_SCALE, CROWNS, EYES, PIVOTS, TIPS, rotate } from './rig.js';
import { branchCrown, worldPoint } from './branch-deformation.js';
import { filamentBinding } from './filaments.js';
import { FRAGMENT_SHADER, VERTEX_SHADER } from './shaders.js';

export class MascotRenderer {
  readonly canvas: HTMLCanvasElement;
  private readonly gl: WebGLRenderingContext;
  private readonly program: WebGLProgram;
  private readonly locations = new Map<string, WebGLUniformLocation>();
  private readonly count: number;
  private texture: WebGLTexture | null = null;
  private frame: MotionFrame | null = null;
  size = 1;
  ready = false;

  constructor(canvas: HTMLCanvasElement) {
    this.canvas = canvas;
    const gl = canvas.getContext('webgl', { alpha: true, antialias: true, premultipliedAlpha: true, preserveDrawingBuffer: true });
    if (!gl) throw new Error('Esta prévia precisa de WebGL. Abra em um navegador com aceleração gráfica.');
    this.gl = gl;
    const program = gl.createProgram();
    if (!program) throw new Error('Não foi possível iniciar a animação.');
    this.program = program;
    gl.attachShader(program, this.shader(gl.VERTEX_SHADER, VERTEX_SHADER));
    gl.attachShader(program, this.shader(gl.FRAGMENT_SHADER, FRAGMENT_SHADER));
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program) ?? 'Falha ao preparar a malha.');
    gl.useProgram(program);
    const points: number[] = [], indices: number[] = [], divisions = 160;
    for (let y = 0; y <= divisions; y++) for (let x = 0; x <= divisions; x++) {
      const point: Vec2 = [x / divisions, y / divisions];
      points.push(...point, ...filamentBinding(point));
    }
    for (let y = 0; y < divisions; y++) for (let x = 0; x < divisions; x++) {
      const a = y * (divisions + 1) + x, b = a + divisions + 1;
      indices.push(a, b, a + 1, a + 1, b, b + 1);
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(points), gl.STATIC_DRAW);
    const attributes = [{ name: 'aUV', size: 2, offset: 0 }, { name: 'aFilament', size: 4, offset: 2 }, { name: 'aFilamentBranch', size: 1, offset: 6 }];
    for (const attribute of attributes) {
      const location = gl.getAttribLocation(program, attribute.name);
      gl.enableVertexAttribArray(location);
      gl.vertexAttribPointer(location, attribute.size, gl.FLOAT, false, 7 * 4, attribute.offset * 4);
    }
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices), gl.STATIC_DRAW);
    this.count = indices.length;
    gl.uniform2fv(this.uniform('uPivot[0]'), new Float32Array(PIVOTS.flat()));
    gl.uniform2fv(this.uniform('uCrown[0]'), new Float32Array(CROWNS.flat()));
    gl.uniform4fv(this.uniform('uTip[0]'), new Float32Array(TIPS.flat()));
    gl.uniform2fv(this.uniform('uEyes[0]'), new Float32Array(EYES.flat()));
    gl.uniform1i(this.uniform('uTexture'), 0);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
    new ResizeObserver(() => this.resize()).observe(canvas);
    canvas.addEventListener('webglcontextlost', event => { event.preventDefault(); this.ready = false; canvas.dispatchEvent(new CustomEvent('rendererror', { detail: 'A conexão gráfica foi interrompida. Recarregue a prévia.' })); });
    this.resize();
  }

  private shader(type: number, source: string): WebGLShader {
    const shader = this.gl.createShader(type);
    if (!shader) throw new Error('Não foi possível preparar a textura.');
    this.gl.shaderSource(shader, source);
    this.gl.compileShader(shader);
    if (!this.gl.getShaderParameter(shader, this.gl.COMPILE_STATUS)) throw new Error(this.gl.getShaderInfoLog(shader) ?? 'Falha gráfica.');
    return shader;
  }

  private uniform(name: string): WebGLUniformLocation {
    const saved = this.locations.get(name);
    if (saved) return saved;
    const location = this.gl.getUniformLocation(this.program, name);
    if (!location) throw new Error(`Parâmetro gráfico ausente: ${name}`);
    this.locations.set(name, location);
    return location;
  }

  async load(url: string): Promise<void> {
    const image = new Image();
    image.src = url;
    await image.decode();
    const gl = this.gl;
    this.texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, this.texture);
    gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    this.ready = true;
    this.canvas.dataset.ready = 'true';
  }

  resize(): void {
    const rect = this.canvas.getBoundingClientRect(), ratio = Math.min(window.devicePixelRatio || 1, 2);
    this.canvas.width = Math.max(1, Math.round(rect.width * ratio));
    this.canvas.height = Math.max(1, Math.round(rect.height * ratio));
    this.gl.viewport(0, 0, this.canvas.width, this.canvas.height);
    if (this.frame) this.render(this.frame);
  }

  render(frame: MotionFrame): void {
    this.frame = frame;
    if (!this.ready) return;
    const gl = this.gl;
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.uniform1fv(this.uniform('uAngle[0]'), frame.angles);
    gl.uniform1fv(this.uniform('uCap[0]'), frame.caps);
    gl.uniform1fv(this.uniform('uBend[0]'), frame.bends);
    gl.uniform1fv(this.uniform('uGrowth[0]'), frame.growth);
    gl.uniform1fv(this.uniform('uBloom[0]'), frame.blooms);
    gl.uniform4fv(this.uniform('uFilament[0]'), frame.filaments);
    gl.uniform1f(this.uniform('uTime'), frame.time);
    gl.uniform1fv(this.uniform('uTipStrength[0]'), frame.tips);
    gl.uniform3fv(this.uniform('uColor'), frame.color);
    gl.uniform4fv(this.uniform('uBody'), new Float32Array(frame.body));
    gl.uniform2fv(this.uniform('uPosition'), new Float32Array(frame.position));
    gl.uniform2fv(this.uniform('uGaze'), new Float32Array(frame.gaze));
    gl.uniform1f(this.uniform('uBlink'), frame.blink);
    gl.uniform1f(this.uniform('uScale'), BASE_SCALE * this.size);
    gl.drawElements(gl.TRIANGLES, this.count, gl.UNSIGNED_SHORT, 0);
  }

  pointOnBranch(index: number): Vec2 {
    const frame = this.frame;
    if (!frame) return [.5, .5];
    return worldPoint(branchCrown(index, frame), frame, BASE_SCALE * this.size);
  }

  hitsBody(point: Vec2): boolean {
    const frame = this.frame;
    if (!frame) return false;
    const scale = BASE_SCALE * this.size;
    let uv: Vec2 = [(point[0] - .5 - frame.position[0]) / scale + .5, (point[1] - .5 - frame.position[1]) / scale + .5 + frame.body[2] + frame.body[3]];
    uv = rotate(uv, [.5, .932], -frame.body[0]);
    uv = [.5 + (uv[0] - .5) / (1 - (frame.body[1] - 1) * .32), .932 + (uv[1] - .932) / frame.body[1]];
    return Math.hypot((uv[0] - .49) / .14, (uv[1] - .77) / .17) < 1 || Math.hypot((uv[0] - .535) / .075, (uv[1] - .558) / .076) < 1;
  }

  get stateSnapshot(): { ready: boolean; frame: MotionFrame | null; size: number } { return { ready: this.ready, frame: this.frame, size: this.size }; }
}
