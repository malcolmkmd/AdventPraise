// The worship display: a port of the iOS app's ExternalHymnView
// (Features/ExternalDisplay.swift). One layer per page; a new page fades in
// over the old one in 0.45 s (iOS: .transition(.opacity) with
// .animation(.easeInOut(duration: 0.45), value: page)). Re-rendering the
// same page (a new text size, the theme) swaps it in place.

import { LOGO_ASPECT, LOGO_PATH, LOGO_VIEWBOX } from './sda-logo.js';

const STAGE_HEIGHT = 1080;
const DEFAULT_WORSHIP_POINT_SIZE = 42; // ReadingSettings.defaultWorshipPointSize
const COMPACT_LEADING = 0.18;          // DS.LineSpacing.compact.leading
const WORSHIP_LEADING_SCALE = 0.6;     // DS.LyricScale.worship.leadingScale
const CHORUS_SIZE_RATIO = 0.92;        // DS.ReadingFont.serif.chorusSizeRatio
const FADE_MS = 450;
// The iOS faces' own line heights (ascent + descent, as a multiple of the
// size), so the lines keep iOS's rhythm whatever face stands in for them:
// New York for verses, Avenir Next for the chorus.
const SERIF_LINE_HEIGHT = 1.18;
const CHORUS_LINE_HEIGHT = 1.366;

const SVG_NS = 'http://www.w3.org/2000/svg';
let logoCount = 0;

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

/** The church logo in the brand's gold gradient (WorshipDisplayGround.logoGradient). */
function logo(width) {
  const id = `logo-gradient-${++logoCount}`;
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('class', 'logo');
  svg.setAttribute('viewBox', LOGO_VIEWBOX);
  svg.setAttribute('width', String(width));
  svg.setAttribute('height', String(width / LOGO_ASPECT));
  const defs = document.createElementNS(SVG_NS, 'defs');
  const gradient = document.createElementNS(SVG_NS, 'linearGradient');
  gradient.setAttribute('id', id);
  gradient.setAttribute('x1', '0'); gradient.setAttribute('y1', '0');
  gradient.setAttribute('x2', '0'); gradient.setAttribute('y2', '1');
  for (const [offset, color] of [['0', '#F3D68C'], ['0.5', '#E2B560'], ['1', '#B9892F']]) {
    const stop = document.createElementNS(SVG_NS, 'stop');
    stop.setAttribute('offset', offset);
    stop.setAttribute('stop-color', color);
    gradient.append(stop);
  }
  defs.append(gradient);
  const path = document.createElementNS(SVG_NS, 'path');
  path.setAttribute('d', LOGO_PATH);
  path.setAttribute('fill', `url(#${id})`);
  svg.append(defs, path);
  return svg;
}

/**
 * SwiftUI's minimumScaleFactor: the largest scale in [min, 1] at which
 * `node` fits `fits()`. Applies the scale to `apply(scale)`.
 */
function shrinkToFit(apply, fits, min) {
  apply(1);
  if (fits()) return 1;
  let lo = min, hi = 1;
  for (let i = 0; i < 12; i++) {
    const mid = (lo + hi) / 2;
    apply(mid);
    if (fits()) lo = mid; else hi = mid;
  }
  apply(lo);
  return lo;
}

export class Display {
  constructor(root) {
    this.screen = root;
    this.stage = root.querySelector('#stage');
    this.ground = root.querySelector('#ground');
    this.pages = root.querySelector('#pages');
    this.current = null;      // { key, node }
    this.lastModel = null;
    this.layout();
    window.addEventListener('resize', () => {
      this.layout();
      if (this.lastModel) this.render(this.lastModel, { instant: true });
    });
  }

  /** Stage size: 1080 high, as wide as the screen's aspect; scaled to fit. */
  layout() {
    const w = window.innerWidth || 1920;
    const h = window.innerHeight || 1080;
    const unit = h / STAGE_HEIGHT;
    this.stageWidth = w / unit;
    const style = this.screen.style;
    style.setProperty('--unit', String(unit));
    style.setProperty('--stage-w', String(this.stageWidth));
    // RadialGradient end radii: max(w, h) × 0.75 for the evergreen, w × 0.4 for the gold.
    style.setProperty('--green-r', String(Math.max(this.stageWidth, STAGE_HEIGHT) * 0.75));
    style.setProperty('--gold-r', String(this.stageWidth * 0.4));
  }

  /**
   * model: { theme: {appearance, worshipPointSize, largePrint},
   *          hymn: {hymnKey, hymnalName, number, title, pages} | null,
   *          pageIndex, blank, special: {announcement, image} | null }
   */
  render(model, { instant = false } = {}) {
    this.lastModel = model;
    const dark = model.theme.appearance !== 'light';
    this.screen.classList.toggle('dark', dark);
    this.screen.classList.toggle('light', !dark);

    const { key, build } = this.page(model);
    const node = build();
    node.dataset.key = key;
    const sameKey = this.current && this.current.key === key;
    if (sameKey || instant) node.classList.add('instant');
    this.pages.append(node);
    this.fit(node, model);

    const previous = this.current;
    this.current = { key, node };
    if (sameKey || instant) {
      node.classList.add('shown');
      if (previous) previous.node.remove();
      requestAnimationFrame(() => node.classList.remove('instant'));
    } else {
      // Cross-fade: the old page fades out while the new one fades in.
      node.getBoundingClientRect();
      node.classList.add('shown');
      if (previous) {
        previous.node.classList.remove('shown');
        const old = previous.node;
        setTimeout(() => old.remove(), FADE_MS + 50);
      }
    }
    // Pages left over from fast page turns.
    for (const child of [...this.pages.children]) {
      if (child !== node && child !== previous?.node && !child.classList.contains('shown')) {
        setTimeout(() => child.remove(), FADE_MS + 50);
      }
    }
  }

  /** The page key, as iOS's `Page` enum: blank, verse(id), title(id), special(id). */
  page(model) {
    const hymn = model.hymn;
    if (model.special && (model.special.announcement || model.special.image)) {
      const s = model.special;
      return { key: `special:${s.imageId ?? ''}|${s.announcement ?? ''}`, build: () => this.special(s) };
    }
    if (!hymn || model.blank) return { key: 'blank', build: () => this.blank() };
    const block = hymn.pages[model.pageIndex];
    if (model.pageIndex >= 0 && block) {
      return { key: `verse:${hymn.hymnKey}-${model.pageIndex}`, build: () => this.verse(model, block) };
    }
    return { key: `title:${hymn.hymnKey}`, build: () => this.titleCard(hymn) };
  }

  blank() {
    const node = el('div', 'page blank');
    node.append(logo(140));
    return node;
  }

  verse(model, block) {
    const hymn = model.hymn;
    const node = el('div', 'page verse');

    const header = el('div', 'header');
    header.append(el('span', 'number', String(hymn.number)), el('span', 'title', hymn.title));

    const body = el('div', 'body');
    const group = el('div', 'lyric-group');
    const isChorus = block.kind === 'chorus';
    if (isChorus) group.append(el('div', 'eyebrow', block.label));
    const lyric = el('div', `lyric${isChorus ? ' chorus' : ''}`, block.lines.join('\n'));
    group.append(lyric);
    body.append(group);

    const footer = el('div', 'footer');
    footer.append(el('span', 'rule'), el('span', 'position', block.label));
    const count = hymn.pages.length;
    if (count > 1 && count <= 12) {
      const dots = el('span', 'dots');
      for (let i = 0; i < count; i++) dots.append(el('span', `dot${i === model.pageIndex ? ' current' : ''}`));
      footer.append(dots);
    }
    footer.append(el('span', 'rule'));

    node.append(header, body, footer);
    return node;
  }

  titleCard(hymn) {
    const node = el('div', 'page title');
    node.append(
      logo(92),
      el('div', 'eyebrow', hymn.hymnalName),
      el('div', 'big-number', String(hymn.number)),
      el('div', 'hymn-title', hymn.title),
    );
    return node;
  }

  special(s) {
    const node = el('div', `page special${s.image ? ' has-image' : ''}`);
    if (s.image) {
      const img = el('img');
      img.src = s.image;
      img.alt = '';
      node.append(img);
    }
    if (s.announcement) node.append(el('div', 'announcement', s.announcement));
    return node;
  }

  /** Sizes that depend on measuring: the verse's shrink-to-fit, the titles' minimum scale. */
  fit(node, model) {
    if (node.classList.contains('verse')) {
      const theme = model.theme;
      // 84 pt on 1080 at the phone's default size; the phone's text size
      // buttons scale it; large print ×1.15.
      const phoneScale = (theme.worshipPointSize || DEFAULT_WORSHIP_POINT_SIZE) / DEFAULT_WORSHIP_POINT_SIZE;
      const pointSize = 84 * phoneScale * (theme.largePrint ? 1.15 : 1);
      const lyric = node.querySelector('.lyric');
      const group = node.querySelector('.lyric-group');
      const body = node.querySelector('.body');
      const isChorus = lyric.classList.contains('chorus');
      const fontSize = isChorus ? pointSize * CHORUS_SIZE_RATIO : pointSize;
      const natural = isChorus ? CHORUS_LINE_HEIGHT : SERIF_LINE_HEIGHT;
      // .lineSpacing(pointSize × compact × worship): extra leading on top of the font's own.
      const extra = pointSize * COMPACT_LEADING * WORSHIP_LEADING_SCALE;
      // .frame(maxWidth: min(width × 0.88, pointSize × 24))
      const maxWidth = Math.min(this.stageWidth * 0.88, pointSize * 24);
      group.style.maxWidth = `${maxWidth}px`;
      lyric.style.maxWidth = `${maxWidth}px`;
      // .minimumScaleFactor(0.3): a verse too long for the screen shrinks to fit.
      shrinkToFit(
        (scale) => {
          lyric.style.fontSize = `${fontSize * scale}px`;
          lyric.style.lineHeight = `${(fontSize * natural + extra) * scale}px`;
        },
        () => group.scrollHeight <= body.clientHeight + 0.5 && lyric.scrollWidth <= maxWidth + 0.5,
        0.3,
      );
      // The title: one line, .minimumScaleFactor(0.6), then truncated.
      const title = node.querySelector('.header .title');
      shrinkToFit(
        (scale) => { title.style.fontSize = `${36 * scale}px`; },
        () => title.scrollWidth <= title.clientWidth + 0.5,
        0.6,
      );
    } else if (node.classList.contains('title')) {
      // Up to three lines, .minimumScaleFactor(0.5).
      const title = node.querySelector('.hymn-title');
      title.style.webkitLineClamp = 'unset';
      const maxHeight = 3 * 76 * 1.18 + 1;
      shrinkToFit(
        (scale) => { title.style.fontSize = `${76 * scale}px`; },
        () => title.scrollHeight <= maxHeight * (parseFloat(title.style.fontSize) / 76) &&
              node.scrollHeight <= node.clientHeight + 0.5,
        0.5,
      );
      title.style.webkitLineClamp = '3';
    } else if (node.classList.contains('special')) {
      const text = node.querySelector('.announcement');
      if (text) {
        // .minimumScaleFactor(0.4) inside 120 pt of margin.
        shrinkToFit(
          (scale) => { text.style.fontSize = `${76 * scale}px`; },
          () => text.scrollHeight <= text.clientHeight + 0.5 && text.scrollWidth <= text.clientWidth + 0.5,
          0.4,
        );
      }
    }
  }
}
