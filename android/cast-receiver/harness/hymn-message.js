// Builds the `load` message the phone sends, from the app's own data files,
// the way the iOS app derives it (for the harness and the headless shots).
//   Hymn.sungSequence        a single chorus after every verse (and first, if the hymn opens with it)
//   ExternalHymnView.position "Verse n of N", or the hymnal's chorus label
//   MIDICatalog.resource     midi-manifest.json; SDA Hymnal hymns use their Christ In Song tune
//   Hymn.accompanimentPasses one pass per verse, at least one

/** @param file  the hymnal's <key>.json ({ refrain, hymns: [{ number, title, blocks: [{t, n, l}] }] }) */
export function sungPages(file, hymn) {
  const blocks = hymn.blocks.map((b) => (b.t === 'c'
    ? { kind: 'chorus', lines: b.l }
    : { kind: 'verse', number: b.n ?? 1, lines: b.l }));
  const verseCount = blocks.filter((b) => b.kind === 'verse').length;
  const choruses = blocks.filter((b) => b.kind === 'chorus');
  let sequence = blocks;
  if (choruses.length === 1) {
    sequence = [];
    if (blocks[0]?.kind === 'chorus') sequence.push(choruses[0]);
    for (const block of blocks) {
      if (block.kind === 'verse') sequence.push(block, choruses[0]);
    }
  }
  const pages = sequence.map((b) => ({
    kind: b.kind,
    label: b.kind === 'chorus' ? file.refrain : `Verse ${b.number} of ${verseCount}`,
    lines: b.lines,
  }));
  return { pages, passes: Math.max(1, verseCount) };
}

export function midiFile(manifest, sdahTunes, hymnalKey, number) {
  let key = hymnalKey, n = number;
  if (hymnalKey === 'sdah') {
    const tune = sdahTunes?.tune?.[String(number)];
    if (!tune) return null;
    key = 'english';
    n = tune;
  }
  const entry = manifest?.hymnals?.[key];
  if (!entry || !entry.hymns.includes(n)) return null;
  return `${entry.file.replace(/%0(\d)d/, (_, w) => String(n).padStart(Number(w), '0'))}.mid`;
}

export function loadMessage({ info, file, number, manifest, sdahTunes, pageIndex = 0, theme, autoplay = false, blank = false, tempo }) {
  const hymn = file.hymns.find((h) => h.number === number);
  if (!hymn) throw new Error(`${info.key} has no hymn ${number}`);
  const { pages, passes } = sungPages(file, hymn);
  const message = {
    v: 1,
    type: 'load',
    hymnalKey: info.key,
    hymnalName: info.title,
    number,
    title: hymn.title,
    pages,
    pageIndex,
    blank,
    midi: midiFile(manifest, sdahTunes, info.key, number),
    passes,
    autoplay,
  };
  if (theme) message.theme = theme;
  if (tempo !== undefined) message.tempo = tempo;
  return message;
}
