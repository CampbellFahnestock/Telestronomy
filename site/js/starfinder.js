// Basic star detection: luminance threshold + connected-component (8-neighbour) centroids.

/**
 * @param {{data: Uint8ClampedArray|number[], width:number, height:number}} img RGBA image data
 * @param {{sigma?:number, minPixels?:number, maxPixels?:number, maxStars?:number}} opts
 * @returns {{stars:{x:number,y:number,flux:number,size:number}[], threshold:number}}
 */
export function detectStars(img, opts = {}) {
  const { sigma = 4, minPixels = 2, maxPixels = 400, maxStars = 500 } = opts;
  const { data, width, height } = img;
  const n = width * height;
  const lum = new Float32Array(n);
  let sum = 0, sumSq = 0;
  for (let i = 0; i < n; i++) {
    const v = 0.299 * data[i * 4] + 0.587 * data[i * 4 + 1] + 0.114 * data[i * 4 + 2];
    lum[i] = v; sum += v; sumSq += v * v;
  }
  const mean = sum / n;
  const std = Math.sqrt(Math.max(0, sumSq / n - mean * mean));
  const threshold = Math.min(250, mean + sigma * Math.max(std, 2));
  const seen = new Uint8Array(n);
  const stack = new Int32Array(n);
  const stars = [];
  for (let s = 0; s < n; s++) {
    if (seen[s] || lum[s] < threshold) continue;
    let sp = 0, count = 0, flux = 0, cx = 0, cy = 0;
    stack[sp++] = s; seen[s] = 1;
    while (sp) {
      const p = stack[--sp];
      const px = p % width, py = (p - px) / width;
      const w = lum[p] - mean;
      count++; flux += w; cx += px * w; cy += py * w;
      for (let dy = -1; dy <= 1; dy++) {
        const yy = py + dy;
        if (yy < 0 || yy >= height) continue;
        for (let dx = -1; dx <= 1; dx++) {
          const xx = px + dx;
          if (xx < 0 || xx >= width) continue;
          const q = yy * width + xx;
          if (!seen[q] && lum[q] >= threshold) { seen[q] = 1; stack[sp++] = q; }
        }
      }
    }
    if (count >= minPixels && count <= maxPixels && flux > 0) stars.push({ x: cx / flux, y: cy / flux, flux, size: count });
  }
  stars.sort((a, b) => b.flux - a.flux);
  return { stars: stars.slice(0, maxStars), threshold };
}
