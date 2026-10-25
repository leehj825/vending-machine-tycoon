// The low-poly mesh builder: boxes, flat tiles, windows, roofs, prisms and cones, each triangle
// with its colour baked from a fixed sun and ambient light. Pure arrays, so it has no three.js
// in it; the city view turns the arrays into geometry.

const SUN = normalise([-0.4, 0.8, 0.4]);
const AMBIENT = 0.6;

function normalise([x, y, z]) {
  const len = Math.hypot(x, y, z) || 1;
  return [x / len, y / len, z / len];
}

function rgb(hex) {
  return [((hex >> 16) & 255) / 255, ((hex >> 8) & 255) / 255, (hex & 255) / 255];
}

export class MeshBuilder {
  constructor({ brightness = 1, transform = null } = {}) {
    this.positions = [];
    this.colors = [];
    this.brightness = brightness;
    // Optional map of a point and a direction, for turning or moving the whole piece.
    this.transform = transform;
  }

  point(x, y, z) {
    return this.transform ? this.transform([x, y, z], false) : [x, y, z];
  }

  direction(d) {
    return this.transform ? this.transform(d, true) : d;
  }

  // One flat triangle. outward orients the normal, so it is lit from the outside.
  tri(a, b, c, outward, colorHex) {
    const pa = this.point(...a);
    const pb = this.point(...b);
    const pc = this.point(...c);
    const out = this.direction(outward);
    const e1 = [pb[0] - pa[0], pb[1] - pa[1], pb[2] - pa[2]];
    const e2 = [pc[0] - pa[0], pc[1] - pa[1], pc[2] - pa[2]];
    let n = normalise([
      e1[1] * e2[2] - e1[2] * e2[1],
      e1[2] * e2[0] - e1[0] * e2[2],
      e1[0] * e2[1] - e1[1] * e2[0],
    ]);
    if (n[0] * out[0] + n[1] * out[1] + n[2] * out[2] < 0) n = [-n[0], -n[1], -n[2]];
    const diffuse = Math.max(0, n[0] * SUN[0] + n[1] * SUN[1] + n[2] * SUN[2]);
    const k = (AMBIENT + (1 - AMBIENT) * diffuse) * this.brightness;
    const [r, g, b2] = rgb(colorHex).map((v) => Math.min(1, v * k));
    for (const p of [pa, pb, pc]) {
      this.positions.push(p[0], p[1], p[2]);
      this.colors.push(r, g, b2);
    }
  }

  quad(a, b, c, d, outward, colorHex) {
    this.tri(a, b, c, outward, colorHex);
    this.tri(a, c, d, outward, colorHex);
  }

  // A flat horizontal rectangle at height y.
  flat(x0, z0, x1, z1, y, colorHex) {
    this.quad([x0, y, z0], [x1, y, z0], [x1, y, z1], [x0, y, z1], [0, 1, 0], colorHex);
  }

  // An axis-aligned box. The top takes its own colour when given.
  box(x0, y0, z0, x1, y1, z1, colorHex, { top = null } = {}) {
    this.quad([x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1], [0, 1, 0], top ?? colorHex);
    this.quad([x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1], [0, 0, 1], colorHex);
    this.quad([x1, y0, z0], [x0, y0, z0], [x0, y1, z0], [x1, y1, z0], [0, 0, -1], colorHex);
    this.quad([x1, y0, z1], [x1, y0, z0], [x1, y1, z0], [x1, y1, z1], [1, 0, 0], colorHex);
    this.quad([x0, y0, z0], [x0, y0, z1], [x0, y1, z1], [x0, y1, z0], [-1, 0, 0], colorHex);
  }

  // Window panes on the four faces of a box that spans y0 to y1. Each pane is a flat quad just
  // outside its face, which is cheaper than small boxes. A frame goes behind each pane.
  windows(x0, z0, x1, z1, y0, y1, { cols, rows, glass, lit = null, frame = null }) {
    const edge = 0.1;
    const gap = 0.03;
    const rowH = (y1 - y0) / rows;
    for (let r = 0; r < rows; r++) {
      const wy0 = y0 + rowH * (r + 0.25);
      const wy1 = y0 + rowH * (r + 0.7);
      for (let c = 0; c < cols; c++) {
        const colour = lit !== null && (r + c) % 3 === 0 ? lit : glass;
        const t0 = edge + ((1 - 2 * edge) * c) / cols + gap;
        const t1 = edge + ((1 - 2 * edge) * (c + 1)) / cols - gap;
        if (frame !== null) {
          this.paneOnFaces(x0, z0, x1, z1, t0 - 0.02, t1 + 0.02, wy0 - 0.02, wy1 + 0.02, 0.008, frame);
        }
        this.paneOnFaces(x0, z0, x1, z1, t0, t1, wy0, wy1, 0.014, colour);
      }
    }
  }

  paneOnFaces(x0, z0, x1, z1, t0, t1, wy0, wy1, off, colorHex) {
    const ax0 = x0 + (x1 - x0) * t0;
    const ax1 = x0 + (x1 - x0) * t1;
    const az0 = z0 + (z1 - z0) * t0;
    const az1 = z0 + (z1 - z0) * t1;
    this.quad([ax0, wy0, z1 + off], [ax1, wy0, z1 + off], [ax1, wy1, z1 + off], [ax0, wy1, z1 + off], [0, 0, 1], colorHex);
    this.quad([ax1, wy0, z0 - off], [ax0, wy0, z0 - off], [ax0, wy1, z0 - off], [ax1, wy1, z0 - off], [0, 0, -1], colorHex);
    this.quad([x1 + off, wy0, az1], [x1 + off, wy0, az0], [x1 + off, wy1, az0], [x1 + off, wy1, az1], [1, 0, 0], colorHex);
    this.quad([x0 - off, wy0, az0], [x0 - off, wy0, az1], [x0 - off, wy1, az1], [x0 - off, wy1, az0], [-1, 0, 0], colorHex);
  }

  // A four-sided pyramid roof over a rectangle at height y0.
  roof(x0, z0, x1, z1, y0, yTop, colorHex) {
    const apex = [(x0 + x1) / 2, yTop, (z0 + z1) / 2];
    const a = [x0, y0, z0];
    const b = [x1, y0, z0];
    const c = [x1, y0, z1];
    const d = [x0, y0, z1];
    this.tri(a, b, apex, [0, 0.5, -1], colorHex);
    this.tri(b, c, apex, [1, 0.5, 0], colorHex);
    this.tri(c, d, apex, [0, 0.5, 1], colorHex);
    this.tri(d, a, apex, [-1, 0.5, 0], colorHex);
  }

  // A prism with the given number of sides; its top is capped when top is given.
  prism(cx, cz, radius, sides, y0, y1, colorHex, { top = null } = {}) {
    for (let i = 0; i < sides; i++) {
      const a0 = (i * 2 * Math.PI) / sides;
      const a1 = ((i + 1) * 2 * Math.PI) / sides;
      const mid = (a0 + a1) / 2;
      const p0 = [cx + radius * Math.cos(a0), y0, cz + radius * Math.sin(a0)];
      const p1 = [cx + radius * Math.cos(a1), y0, cz + radius * Math.sin(a1)];
      const t0 = [p0[0], y1, p0[2]];
      const t1 = [p1[0], y1, p1[2]];
      this.quad(p0, p1, t1, t0, [Math.cos(mid), 0, Math.sin(mid)], colorHex);
      if (top !== null) this.tri([cx, y1, cz], t0, t1, [0, 1, 0], top);
    }
  }

  // A cone with the given number of sides, from a round base at y0 to a point at yTop.
  cone(cx, cz, radius, sides, y0, yTop, colorHex) {
    const apex = [cx, yTop, cz];
    for (let i = 0; i < sides; i++) {
      const a0 = (i * 2 * Math.PI) / sides;
      const a1 = ((i + 1) * 2 * Math.PI) / sides;
      const mid = (a0 + a1) / 2;
      const p0 = [cx + radius * Math.cos(a0), y0, cz + radius * Math.sin(a0)];
      const p1 = [cx + radius * Math.cos(a1), y0, cz + radius * Math.sin(a1)];
      this.tri(p0, p1, apex, [Math.cos(mid), 0.6, Math.sin(mid)], colorHex);
    }
  }

  arrays() {
    return { positions: new Float32Array(this.positions), colors: new Float32Array(this.colors) };
  }
}

// Turns a point (x, z) about the vertical axis through (cx, cz) by quarter turns.
export function turnPoint(dx, dz, turns) {
  let x = dx;
  let z = dz;
  for (let i = 0; i < turns % 4; i++) {
    const t = x;
    x = -z;
    z = t;
  }
  return [x, z];
}

// A transform that turns a piece about (cx, cz) by quarter turns, for points and directions.
export function turnTransform(cx, cz, turns) {
  return (v, isDirection) => {
    if (isDirection) {
      const [dx, dz] = turnPoint(v[0], v[2], turns);
      return [dx, v[1], dz];
    }
    const [dx, dz] = turnPoint(v[0] - cx, v[2] - cz, turns);
    return [cx + dx, v[1], cz + dz];
  };
}
