import type { StateId } from './animation.types.js';
import { STATES } from './states.js';

export async function recordShowcase(source: HTMLCanvasElement, select: (id: StateId) => void, current: () => StateId, onProgress: (label: string) => void): Promise<void> {
  if (!window.MediaRecorder) throw new Error('Este navegador não oferece gravação. Use Chrome para salvar a prévia.');
  const output = document.createElement('canvas');
  output.width = 900; output.height = 1000;
  const context = output.getContext('2d');
  if (!context) throw new Error('Não foi possível preparar o vídeo.');
  const stream = output.captureStream(30);
  const mime = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/mp4'].find(type => MediaRecorder.isTypeSupported(type));
  if (!mime) { stream.getTracks().forEach(track => track.stop()); throw new Error('Formato de vídeo indisponível neste navegador.'); }
  const recorder = new MediaRecorder(stream, { mimeType: mime, videoBitsPerSecond: 5_000_000 });
  const chunks: BlobPart[] = [];
  const dark = document.documentElement.dataset.theme === 'dark';
  let stopped = false, request = 0, lastState = -1;
  const paint = (): void => {
    context.fillStyle = dark ? '#191d18' : '#f5f3ed'; context.fillRect(0, 0, 900, 1000);
    context.fillStyle = dark ? '#bdcca7' : '#526048'; context.font = '40px Georgia'; context.textAlign = 'center'; context.fillText('Fronda', 450, 70);
    context.drawImage(source, 35, 85, 830, 830);
    const state = STATES.find(item => item.id === current())!;
    context.fillStyle = dark ? '#eef0e6' : '#282d25'; context.font = '28px Georgia'; context.fillText(state.label, 450, 920);
    context.fillStyle = dark ? '#b0b8a5' : '#707566'; context.font = '16px sans-serif'; context.fillText(state.detail, 450, 955);
  };
  const started = performance.now();
  return new Promise<void>((resolve, reject) => {
    recorder.ondataavailable = event => { if (event.data.size) chunks.push(event.data); };
    const clean = (): void => { stopped = true; cancelAnimationFrame(request); stream.getTracks().forEach(track => track.stop()); };
    recorder.onerror = () => { clean(); reject(new Error('A gravação foi interrompida.')); };
    recorder.onstop = () => {
      clean();
      const blob = new Blob(chunks, { type: mime });
      const url = URL.createObjectURL(blob), anchor = document.createElement('a');
      anchor.href = url; anchor.download = `fronda-movimento.${mime.startsWith('video/mp4') ? 'mp4' : 'webm'}`;
      anchor.click(); setTimeout(() => URL.revokeObjectURL(url), 60_000); resolve();
    };
    function draw(): void {
      if (stopped) return;
      const elapsed = (performance.now() - started) / 1000;
      const index = Math.min(5, Math.floor(elapsed / 6));
      if (index !== lastState) { lastState = index; select(STATES[index]!.id); onProgress(`Gravando ${index + 1}/6…`); }
      paint();
      if (elapsed >= 36) { recorder.stop(); return; }
      request = requestAnimationFrame(draw);
    }
    paint(); recorder.start(); draw();
  });
}
