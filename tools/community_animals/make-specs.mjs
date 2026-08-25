import fs from 'node:fs';
import path from 'node:path';

const [sourcePath, outputDir] = process.argv.slice(2);
if (!sourcePath || !outputDir) {
  console.error('usage: node make-specs.mjs <anyCreature quadruped spec> <output-dir>');
  process.exit(2);
}

const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
fs.mkdirSync(outputDir, { recursive: true });

const clone = value => JSON.parse(JSON.stringify(value));
const isNumber = value => typeof value === 'number' && Number.isFinite(value);

function scaleJoint(joint, scale) {
  if (Array.isArray(joint)) {
    if (joint.length >= 3) {
      joint[0] *= scale.side;
      joint[1] *= scale.up;
      joint[2] *= scale.fwd;
    }
    return;
  }
  if (!joint || typeof joint !== 'object') return;
  if (isNumber(joint.side)) joint.side *= scale.side;
  if (isNumber(joint.up)) joint.up *= scale.up;
  if (isNumber(joint.fwd)) joint.fwd *= scale.fwd;
  if (isNumber(joint.ground)) joint.ground *= scale.up;
}

function scalePart(part, scale) {
  const uniform = (scale.side + scale.up + scale.fwd) / 3;
  if (isNumber(part.size)) part.size *= uniform;
  if (Array.isArray(part.size)) {
    for (let i = 0; i < part.size.length; i += 1) {
      if (isNumber(part.size[i])) part.size[i] *= uniform;
    }
  }
  if (isNumber(part.thickness)) part.thickness *= uniform;
  if (Array.isArray(part.offset) && part.offset.length >= 3) {
    part.offset[0] *= scale.side;
    part.offset[1] *= scale.up;
    part.offset[2] *= scale.fwd;
  }
  if (Array.isArray(part.points)) {
    for (const point of part.points) {
      if (Array.isArray(point) && point.length >= 2) {
        point[0] *= uniform;
        point[1] *= uniform;
      }
    }
  }
  if (Array.isArray(part.segments)) {
    for (const segment of part.segments) {
      if (isNumber(segment.len)) segment.len *= uniform;
      if (isNumber(segment.r)) segment.r *= uniform;
    }
  }
}

function reshapeVolumes(spec, scale, volumeBoosts) {
  if (!Array.isArray(spec.volumes)) return;
  for (const volume of spec.volumes) {
    const boost = volumeBoosts[volume.chain] || { width: 1, height: 1 };
    if (!Array.isArray(volume.profile)) continue;
    for (const row of volume.profile) {
      if (!Array.isArray(row) || row.length < 3) continue;
      if (isNumber(row[1])) row[1] *= scale.side * boost.width;
      if (isNumber(row[2])) row[2] *= scale.up * boost.height;
    }
    if (isNumber(volume.ring_step)) volume.ring_step *= (scale.side + scale.up) * 0.5;
  }
}

function setPalette(spec, palette) {
  spec.palette ||= {};
  for (const [key, color] of Object.entries(palette)) {
    spec.palette[key] ||= {};
    spec.palette[key].color = color;
    if (!isNumber(spec.palette[key].rough)) spec.palette[key].rough = 0.88;
  }
}

function scaleEar(spec, factor) {
  if (!Array.isArray(spec.parts)) return;
  for (const part of spec.parts) {
    if (part.type !== 'fin' || !Array.isArray(part.points)) continue;
    for (const point of part.points) {
      if (!Array.isArray(point)) continue;
      for (let i = 0; i < point.length; i += 1) {
        if (isNumber(point[i])) point[i] *= factor;
      }
    }
  }
}

function shortenTail(spec, factor) {
  const names = ['TailRoot', 'Tail1', 'Tail2', 'TailTip'];
  for (const name of names) {
    const joint = spec.joints?.[name];
    if (!joint || Array.isArray(joint)) continue;
    if (isNumber(joint.fwd)) joint.fwd *= factor;
    if (isNumber(joint.up)) joint.up *= Math.max(0.72, factor);
  }
}

function makeSpecies(config) {
  const spec = clone(source);
  spec.name = config.name;
  spec._template = `Hippo OS community-generated ${config.identity}; derived mechanically from the pinned anyCreature quadruped anchor, not from an identifiable real animal.`;

  for (const joint of Object.values(spec.joints || {})) scaleJoint(joint, config.scale);
  reshapeVolumes(spec, config.scale, config.volumeBoosts || {});
  for (const part of spec.parts || []) scalePart(part, config.scale);
  setPalette(spec, config.palette);
  scaleEar(spec, config.earScale || 1);
  shortenTail(spec, config.tailScale || 1);

  // Keep the upstream validated rig/animation topology. The runtime loader maps the
  // upstream `move` clip to Hippo OS walk/run states when bespoke clips are absent.
  spec.ao = spec.ao === false ? false : { ...(typeof spec.ao === 'object' ? spec.ao : {}), samples: 16, strength: 0.64 };
  spec.smooth_angle = config.smoothAngle || 58;
  spec.keep_uv = false;

  const outPath = path.join(outputDir, `${config.file}.json`);
  fs.writeFileSync(outPath, `${JSON.stringify(spec, null, 2)}\n`);
  console.log(`wrote ${outPath}`);
}

makeSpecies({
  file: 'mochi',
  name: 'mochi_pygmy_hippo',
  identity: 'original baby pygmy hippo',
  scale: { side: 1.28, up: 0.82, fwd: 1.04 },
  volumeBoosts: {
    body: { width: 1.28, height: 1.12 },
    head: { width: 1.42, height: 1.24 },
    LFront: { width: 1.18, height: 1.12 },
    LBack: { width: 1.20, height: 1.14 },
    tail: { width: 0.72, height: 0.72 },
  },
  earScale: 0.56,
  tailScale: 0.42,
  smoothAngle: 64,
  palette: {
    fur_body: '#4b4147',
    fur_head: '#58474b',
    fur_tail: '#3f3439',
    fur_leg: '#453b40',
    fur_paw: '#382f34',
    nose: '#21191e',
    ear: '#6b4a50',
    eye: '#c39761',
  },
});

makeSpecies({
  file: 'porky',
  name: 'porky_pig',
  identity: 'stocky domestic pig',
  scale: { side: 1.14, up: 0.88, fwd: 0.94 },
  volumeBoosts: {
    body: { width: 1.22, height: 1.12 },
    head: { width: 1.16, height: 1.08 },
    LFront: { width: 1.08, height: 1.08 },
    LBack: { width: 1.10, height: 1.10 },
    tail: { width: 0.72, height: 0.72 },
  },
  earScale: 0.82,
  tailScale: 0.56,
  smoothAngle: 60,
  palette: {
    fur_body: '#9d6c66',
    fur_head: '#b57c72',
    fur_tail: '#8a5956',
    fur_leg: '#8f615b',
    fur_paw: '#684846',
    nose: '#5b363b',
    ear: '#a86765',
    eye: '#3d2c22',
  },
});

makeSpecies({
  file: 'bao',
  name: 'bao_shar_pei',
  identity: 'broad-headed tan Shar-Pei companion',
  scale: { side: 1.08, up: 0.96, fwd: 0.94 },
  volumeBoosts: {
    body: { width: 1.12, height: 1.06 },
    head: { width: 1.28, height: 1.12 },
    LFront: { width: 1.08, height: 1.06 },
    LBack: { width: 1.08, height: 1.06 },
  },
  earScale: 0.72,
  tailScale: 0.72,
  smoothAngle: 62,
  palette: {
    fur_body: '#94613d',
    fur_head: '#a66f46',
    fur_tail: '#855536',
    fur_leg: '#89593a',
    fur_paw: '#6f492f',
    nose: '#211b18',
    ear: '#76513b',
    eye: '#38281f',
  },
});
