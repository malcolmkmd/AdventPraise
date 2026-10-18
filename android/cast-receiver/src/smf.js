// A Standard MIDI File's length, measured the way the iOS app measures it
// (HymnMIDIEngine.sequenceLength): the longest track's length in beats, to its
// End of Track event, converted to seconds through the file's tempo map.
// The synth's own `duration` stops at the last note instead, which would make
// each verse's pass a little shorter than on the phone.

function readVarLen(data, i) {
  let value = 0;
  for (let n = 0; n < 4; n++) {
    const byte = data[i++];
    value = (value << 7) | (byte & 0x7f);
    if (byte < 0x80) return [value, i];
  }
  throw new Error('bad variable-length quantity');
}

/** @returns {number} seconds at the written tempo */
export function midiLengthSeconds(buffer) {
  const data = new Uint8Array(buffer);
  const view = new DataView(buffer);
  const ascii = (at) => String.fromCharCode(data[at], data[at + 1], data[at + 2], data[at + 3]);
  if (ascii(0) !== 'MThd') throw new Error('not a MIDI file');
  const headerLength = view.getUint32(4);
  const trackCount = view.getUint16(10);
  const division = view.getUint16(12);
  if (division & 0x8000) {
    // SMPTE time: ticks are real time, no tempo map.
    const fps = 256 - (division >> 8);
    const ticksPerFrame = division & 0xff;
    return lastTick(data, view, 8 + headerLength, trackCount).maxTicks / (fps * ticksPerFrame);
  }
  const { maxTicks, tempos } = lastTick(data, view, 8 + headerLength, trackCount);
  // Tempo map: microseconds per quarter note, 120 bpm until the first change.
  tempos.sort((a, b) => a.tick - b.tick);
  let seconds = 0, tick = 0, usPerQuarter = 500000;
  for (const change of tempos) {
    if (change.tick >= maxTicks) break;
    seconds += ((change.tick - tick) / division) * (usPerQuarter / 1e6);
    tick = change.tick;
    usPerQuarter = change.usPerQuarter;
  }
  seconds += ((maxTicks - tick) / division) * (usPerQuarter / 1e6);
  return seconds;
}

function lastTick(data, view, offset, trackCount) {
  let maxTicks = 0;
  const tempos = [];
  for (let t = 0; t < trackCount && offset + 8 <= data.length; t++) {
    const length = view.getUint32(offset + 4);
    let i = offset + 8;
    const end = Math.min(i + length, data.length);
    let tick = 0, running = 0;
    while (i < end) {
      let delta;
      [delta, i] = readVarLen(data, i);
      tick += delta;
      let status = data[i];
      if (status === 0xff) {
        const type = data[i + 1];
        let size;
        [size, i] = readVarLen(data, i + 2);
        if (type === 0x51 && size === 3) {
          tempos.push({ tick, usPerQuarter: (data[i] << 16) | (data[i + 1] << 8) | data[i + 2] });
        }
        i += size;
        if (type === 0x2f) break; // End of Track: the track's length
        continue;
      }
      if (status === 0xf0 || status === 0xf7) {
        let size;
        [size, i] = readVarLen(data, i + 1);
        i += size;
        continue;
      }
      if (status & 0x80) { running = status; i++; } else { status = running; }
      const kind = status & 0xf0;
      i += kind === 0xc0 || kind === 0xd0 ? 1 : 2;
    }
    maxTicks = Math.max(maxTicks, tick);
    offset += 8 + length;
  }
  return { maxTicks, tempos };
}
