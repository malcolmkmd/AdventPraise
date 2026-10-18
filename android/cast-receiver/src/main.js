// Advent Praise church mode on a Cast device: the custom Web Receiver.
// Protocol: PROTOCOL.md (v1). The phone owns what's on screen; the TV owns
// audio time. With `?harness=1` the page runs without the Cast SDK and talks
// to its parent window instead (harness/index.html).

import { Display } from './display.js';
import { Transport, TransportError } from './transport.js';

const NAMESPACE = 'urn:x-cast:com.mDev.AdventPraise.church';
const VERSION = 1;
const CAF_SDK = 'https://www.gstatic.com/cast/sdk/libs/caf_receiver/v3/cast_receiver_framework.js';
const STATUS_INTERVAL_MS = 250;   // ~4 Hz while playing
const MAX_IMAGES = 4;
const ORPHAN_TIMEOUT_MS = 10 * 60 * 1000;
const MIDI_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}\.midi?$/;

const params = new URLSearchParams(location.search);
const harness = params.has('harness');

// MARK: State (what the phone has asked for)

const state = {
  hymn: null,        // { hymnalKey, hymnalName, number, title, pages, hymnKey }
  pageIndex: 0,
  blank: false,
  theme: { appearance: 'dark', worshipPointSize: 42, largePrint: false },
  special: null,     // { announcement, imageId }
};
const images = new Map();   // imageId -> { url } or { chunks, count, mime }
let seq = 0;

const display = new Display(document.getElementById('screen'));
const transport = new Transport({
  base: '.',
  onChange: () => sendStatus(),
  onError: (code, message) => sendError(code, message),
});

// MARK: Bus (Cast or the harness)

let bus = null;

function send(message) {
  bus?.send({ v: VERSION, ...message });
}

function sendStatus() {
  send({
    type: 'status',
    ...transport.snapshot(),
    sentAtEpochMs: Date.now(),
    hymnKey: state.hymn?.hymnKey ?? null,
    pageIndex: state.hymn ? state.pageIndex : null,
    blank: state.blank,
    seq: ++seq,
  });
}

function sendError(code, message, request) {
  console.warn(`[receiver] ${code}: ${message}`);
  send({ type: 'error', code, message, ...(request ? { request } : {}) });
}

setInterval(() => { if (transport.state === 'playing') sendStatus(); }, STATUS_INTERVAL_MS);

// MARK: Rendering

let fontsReady = false;
function render(options) {
  if (!fontsReady) return;
  const special = state.special && {
    announcement: state.special.announcement || null,
    imageId: state.special.imageId || null,
    image: state.special.imageId ? images.get(state.special.imageId)?.url ?? null : null,
  };
  display.render({
    theme: state.theme,
    hymn: state.hymn,
    pageIndex: state.pageIndex,
    blank: state.blank,
    special: special && (special.announcement || special.image) ? special : null,
  }, options);
}

// MARK: Messages

class BadMessage extends Error {}

function field(message, name, type, { required = false, nullable = false } = {}) {
  const value = message[name];
  if (value === undefined) {
    if (required) throw new BadMessage(`${message.type}: ${name} is required`);
    return undefined;
  }
  if (value === null && nullable) return null;
  const ok = type === 'array' ? Array.isArray(value)
    : type === 'integer' ? Number.isInteger(value)
    : typeof value === type;
  if (!ok) throw new BadMessage(`${message.type}: ${name} should be ${nullable ? `${type} or null` : type}`);
  return value;
}

function applyTheme(message) {
  const appearance = field(message, 'appearance', 'string');
  if (appearance !== undefined) state.theme.appearance = appearance === 'light' ? 'light' : 'dark';
  const size = field(message, 'worshipPointSize', 'number');
  if (size !== undefined && size > 0) state.theme.worshipPointSize = Math.min(Math.max(size, 20), 120);
  const largePrint = field(message, 'largePrint', 'boolean');
  if (largePrint !== undefined) state.theme.largePrint = largePrint;
}

function parsePages(list) {
  return list.map((page, i) => {
    if (!page || typeof page !== 'object') throw new BadMessage(`load: pages[${i}] should be an object`);
    const kind = page.kind === 'chorus' ? 'chorus' : 'verse';
    const lines = Array.isArray(page.lines) ? page.lines.map((line) => String(line)) : [];
    return { kind, label: typeof page.label === 'string' ? page.label : '', lines };
  });
}

function clampPage(index) {
  if (!state.hymn) return 0;
  if (index < 0) return -1;
  return Math.min(index, Math.max(state.hymn.pages.length - 1, 0));
}

const handlers = {
  load(message) {
    const hymnalKey = field(message, 'hymnalKey', 'string', { required: true });
    const number = field(message, 'number', 'integer', { required: true });
    const title = field(message, 'title', 'string', { required: true });
    const pages = parsePages(field(message, 'pages', 'array', { required: true }));
    const hymnalName = field(message, 'hymnalName', 'string') ?? '';
    const pageIndex = field(message, 'pageIndex', 'integer') ?? 0;
    const blank = field(message, 'blank', 'boolean') ?? false;
    const midi = field(message, 'midi', 'string', { nullable: true }) ?? null;
    const passes = field(message, 'passes', 'integer')
      ?? Math.max(1, pages.filter((page) => page.kind === 'verse').length);
    const tempo = field(message, 'tempo', 'number');
    const autoplay = field(message, 'autoplay', 'boolean') ?? false;
    const startMs = field(message, 'startMs', 'number') ?? 0;
    if (message.theme && typeof message.theme === 'object') applyTheme({ type: 'load', ...message.theme });
    if (midi !== null && !MIDI_NAME.test(midi)) throw new BadMessage(`load: midi "${midi}" is not a file name`);

    const previous = state.hymn;
    const hymnKey = `${hymnalKey}-${number}`;
    state.hymn = { hymnalKey, hymnalName, number, title, pages, hymnKey };
    state.pageIndex = clampPage(pageIndex);
    state.blank = blank;
    render();

    if (tempo !== undefined) transport.setRate(tempo);
    // The loaded hymn again: the audio carries on (iOS: load() of the loaded hymn does nothing).
    const sameAudio = previous && previous.hymnalKey === hymnalKey && previous.number === number
      && transport.midi === midi && transport.passes === Math.max(1, passes)
      && (midi === null || transport.passDuration > 0 || transport.state === 'loading');
    if (sameAudio) {
      if (autoplay && transport.state !== 'playing') transport.play();
      sendStatus();
      return;
    }
    transport.load(midi, passes, { startMs, autoplay }).catch((error) => {
      sendError(error.code ?? 'midi_load_failed', error.message, 'load');
    });
    sendStatus();
  },

  page(message) {
    const pageIndex = field(message, 'pageIndex', 'integer', { required: true });
    if (!state.hymn) throw new TransportError('no_hymn', 'page before load');
    state.pageIndex = clampPage(pageIndex);
    render();
    sendStatus();
  },

  blank(message) {
    state.blank = field(message, 'on', 'boolean', { required: true });
    render();
    sendStatus();
  },

  theme(message) {
    applyTheme(message);
    render();
  },

  special(message) {
    const announcement = field(message, 'announcement', 'string', { nullable: true }) ?? null;
    const imageId = field(message, 'imageId', 'string', { nullable: true }) ?? null;
    state.special = announcement || imageId ? { announcement, imageId } : null;
    render();
  },

  imageChunk(message) {
    const imageId = field(message, 'imageId', 'string', { required: true });
    const index = field(message, 'index', 'integer', { required: true });
    const count = field(message, 'count', 'integer', { required: true });
    const data = field(message, 'data', 'string', { required: true });
    const mime = field(message, 'mime', 'string') ?? 'image/jpeg';
    if (count < 1 || count > 400 || index < 0 || index >= count) throw new BadMessage('imageChunk: bad index or count');
    if (!/^image\/(jpeg|png|webp)$/.test(mime)) throw new BadMessage(`imageChunk: ${mime} is not supported`);
    let entry = images.get(imageId);
    if (!entry || entry.url || entry.count !== count) {
      if (entry?.url) URL.revokeObjectURL(entry.url);
      entry = { chunks: new Array(count), received: 0, count, mime };
      images.set(imageId, entry);
    }
    if (entry.chunks[index] === undefined) entry.received += 1;
    entry.chunks[index] = data;
    if (entry.received < count) return;
    try {
      const binary = atob(entry.chunks.join(''));
      const bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
      images.set(imageId, { url: URL.createObjectURL(new Blob([bytes], { type: entry.mime })) });
    } catch {
      images.delete(imageId);
      sendError('image_failed', `image ${imageId} could not be decoded`, 'imageChunk');
      return;
    }
    // Keep the last few pictures.
    while (images.size > MAX_IMAGES) {
      const [oldest, value] = images.entries().next().value;
      if (oldest === state.special?.imageId) break;
      if (value.url) URL.revokeObjectURL(value.url);
      images.delete(oldest);
    }
    if (state.special?.imageId === imageId) render();
  },

  play(message) {
    const fromMs = field(message, 'fromMs', 'number');
    if (!state.hymn) throw new TransportError('no_hymn', 'play before load');
    if (!transport.midi) throw new TransportError('no_accompaniment', 'this hymn has no accompaniment');
    if (transport.state === 'loading') {
      // Play as soon as it's ready.
      const wait = setInterval(() => {
        if (transport.state === 'loading') return;
        clearInterval(wait);
        if (transport.passDuration) transport.play(fromMs);
      }, 50);
      return;
    }
    if (!transport.play(fromMs)) sendStatus();
  },

  pause() { transport.pause(); },

  stop() { transport.stop(); },

  seek(message) {
    const ms = field(message, 'ms', 'number', { required: true });
    if (!state.hymn) throw new TransportError('no_hymn', 'seek before load');
    transport.seek(ms);
  },

  tempo(message) {
    transport.setRate(field(message, 'rate', 'number', { required: true }));
  },

  getStatus() { sendStatus(); },

  ping(message) {
    send({ type: 'pong', id: message.id ?? null, receivedAtEpochMs: Date.now() });
  },
};

function onMessage(raw) {
  let message = raw;
  try {
    if (typeof message === 'string') message = JSON.parse(message);
  } catch {
    sendError('bad_message', 'not JSON');
    return;
  }
  if (!message || typeof message !== 'object' || typeof message.type !== 'string') {
    sendError('bad_message', 'a message needs a type');
    return;
  }
  if (typeof message.v === 'number' && message.v > VERSION) {
    sendError('unsupported_version', `this receiver speaks v${VERSION}`, message.type);
    return;
  }
  const handler = Object.prototype.hasOwnProperty.call(handlers, message.type) ? handlers[message.type] : null;
  if (!handler) {
    sendError('unknown_type', `unknown type "${message.type}"`, message.type);
    return;
  }
  try {
    handler(message);
  } catch (error) {
    if (error instanceof BadMessage) sendError('bad_message', error.message, message.type);
    else if (error instanceof TransportError) sendError(error.code, error.message, message.type);
    else sendError('bad_message', String(error?.message ?? error), message.type);
  }
}

// MARK: Start

function startHarness() {
  const framed = window.parent && window.parent !== window;
  // Opened on its own (headless shots): messages go in through __receiver, nothing goes out.
  bus = { send: (data) => { if (framed) window.parent.postMessage({ namespace: NAMESPACE, data }, '*'); } };
  window.addEventListener('message', (event) => {
    if (!framed || event.source !== window.parent || event.data?.namespace !== NAMESPACE) return;
    onMessage(event.data.data);
  });
  // A desktop browser needs a gesture before audio plays.
  const unlock = () => transport.engineNow?.context.resume().catch(() => {});
  window.addEventListener('pointerdown', unlock);
  window.addEventListener('keydown', unlock);
  window.__receiver = { state, transport, onMessage, outbox: [] };
  if (!framed) {
    bus.send = (data) => {
      const outbox = window.__receiver.outbox;
      outbox.push(data);
      if (outbox.length > 500) outbox.shift();
    };
  }
  sendStatus();
}

function startCast() {
  const script = document.createElement('script');
  script.src = CAF_SDK;
  script.onload = () => {
    const framework = window.cast.framework;
    const context = framework.CastReceiverContext.getInstance();
    context.setLoggerLevel?.(framework.LoggerLevel.NONE);
    context.addCustomMessageListener(NAMESPACE, (event) => onMessage(event.data));
    // The idle timeout is off (the words stay up between hymns), so the
    // receiver closes itself when every phone has been gone 10 minutes.
    let orphaned = 0;
    context.addEventListener(framework.system.EventType.SENDER_CONNECTED, () => {
      clearTimeout(orphaned);
      sendStatus();
    });
    context.addEventListener(framework.system.EventType.SENDER_DISCONNECTED, () => {
      if (context.getSenders().length > 0) return;
      clearTimeout(orphaned);
      orphaned = setTimeout(() => context.stop(), ORPHAN_TIMEOUT_MS);
    });
    bus = {
      send: (data) => {
        try {
          context.sendCustomMessage(NAMESPACE, undefined, data);
        } catch {
          // No sender connected yet.
        }
      },
    };
    const options = new framework.CastReceiverOptions();
    options.customNamespaces = { [NAMESPACE]: framework.system.MessageType.JSON };
    options.disableIdleTimeout = true;   // the words stay up between hymns
    options.skipPlayersLoad = true;      // no media element: Web Audio only
    options.statusText = 'Advent Praise';
    context.start(options);
  };
  script.onerror = () => console.error('[receiver] Cast SDK failed to load');
  document.head.append(script);
}

(async function start() {
  // The worship display draws only with its faces, so text never reflows.
  try {
    await Promise.race([
      Promise.all(['600 10px "AP Serif"', '700 10px "AP Sans"', 'italic 700 10px "AP Chorus"']
        .map((font) => document.fonts.load(font))),
      new Promise((resolve) => setTimeout(resolve, 3000)),
    ]);
  } catch { /* fall back to the system faces */ }
  fontsReady = true;
  render({ instant: true });
  if (harness) startHarness(); else startCast();
  // The piano loads now, so the first hymn plays at once.
  transport.warmUp().catch(() => {});
})();
