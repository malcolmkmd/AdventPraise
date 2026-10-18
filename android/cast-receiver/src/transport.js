// The accompaniment on the TV: the hymn's MIDI on the shared piano SoundFont,
// played the way the iOS app's HymnMIDIEngine plays it. The tune is played
// once per verse (`passes` times); times are performance time at the written
// tempo; the tempo (0.8 / 1 / 1.2) speeds the clock. The TV is the clock the
// phone follows, so the position comes from the audio context's own clock.

import { Sequencer, WorkletSynthesizer } from 'spessasynth_lib';
import { midiLengthSeconds } from './smf.js';

export class TransportError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const VOICE_CAP = 64; // a four-part hymn with pedal rarely needs 20

export class Transport {
  /** @param {() => void} onChange called on every change of state, hymn, rate or position jump */
  constructor({ onChange, onError, base = '.' }) {
    this.onChange = onChange;
    this.onError = onError;
    this.base = base;
    this.state = 'idle';     // idle | loading | playing | paused | ended
    this.midi = null;        // file name of the loaded hymn
    this.passes = 1;
    this.passDuration = 0;   // seconds, iOS-measured
    this.rate = 1;
    this.anchorPerf = 0;     // performance seconds at anchorTime (the truth while paused)
    this.anchorTime = 0;     // audio context seconds
    this.pass = 0;           // 0-based pass the sequencer is in
    this.engine = null;      // Promise of { context, synth, seq }
    this.engineNow = null;   // the same, once built
    this.loadToken = 0;
    this.boundaryTimer = 0;
    this.watchTimer = 0;
  }

  // MARK: Engine (built once; the SoundFont loads at start-up)

  warmUp() {
    if (!this.engine) {
      this.engine = this.buildEngine().then((engine) => {
        this.engineNow = engine;
        return engine;
      }, (error) => {
        this.engine = null;
        throw error;
      });
      this.engine.catch((error) => this.onError(error.code ?? 'audio_failed', error.message));
    }
    return this.engine;
  }

  async buildEngine() {
    let context;
    try {
      // "playback": larger buffers, fewer underruns on a Chromecast's small CPU.
      context = new AudioContext({ latencyHint: 'playback' });
      await context.audioWorklet.addModule(`${this.base}/vendor/spessasynth_processor.min.js`);
    } catch (error) {
      throw new TransportError('audio_failed', `audio engine: ${error.message ?? error}`);
    }
    const synth = new WorkletSynthesizer(context);
    synth.connect(context.destination);
    try {
      const response = await fetch(`${this.base}/piano.sf2`);
      if (!response.ok) throw new Error(`piano.sf2: ${response.status}`);
      await synth.soundBankManager.addSoundBank(await response.arrayBuffer(), 'piano');
      await synth.isReady;
    } catch (error) {
      throw new TransportError('soundfont_failed', `${error.message ?? error}`);
    }
    // Like iOS's sampler: a dry piano, nothing else.
    synth.setSystemParameter('effectsEnabled', false);
    synth.setSystemParameter('voiceCap', VOICE_CAP);
    const seq = new Sequencer(synth, { skipToFirstNoteOn: false, initialPlaybackRate: 1 });
    seq.loopCount = 0;
    seq.eventHandler.timeDelay = 0;
    return { context, synth, seq };
  }

  /** Every channel plays the piano, whatever program the file asks for (iOS loads only program 0). */
  pinPiano(synth) {
    for (let channel = 0; channel < synth.channelCount; channel++) {
      const ch = synth.midiChannels[channel];
      ch.setSystemParameter('presetLock', false);
      if (channel === 9) ch.setDrums(false);
      synth.programChange(channel, 0);
      ch.setSystemParameter('presetLock', true);
    }
  }

  // MARK: Clock

  now() {
    return this.engineNow ? this.engineNow.context.currentTime : 0;
  }

  /** Performance seconds now (0…duration). */
  position() {
    if (this.state !== 'playing') return this.anchorPerf;
    const perf = this.anchorPerf + (this.now() - this.anchorTime) * this.rate;
    return Math.min(perf, this.duration());
  }

  duration() {
    return this.passDuration * this.passes;
  }

  // MARK: Loading

  /** Loads a hymn's MIDI (or none). Resolves when ready; stops whatever played. */
  async load(midi, passes, { startMs = 0, autoplay = false } = {}) {
    const token = ++this.loadToken;
    this.halt();
    this.midi = midi;
    this.passes = Math.max(1, Math.floor(passes) || 1);
    this.passDuration = 0;
    this.anchorPerf = 0;
    this.pass = 0;
    if (!midi) {
      this.setState('idle');
      return;
    }
    this.setState('loading');
    try {
      const engine = await this.warmUp();
      this.engineNow = engine;
      const response = await fetch(`${this.base}/midi/${encodeURIComponent(midi)}`);
      if (response.status === 404) throw new TransportError('midi_not_found', `midi/${midi}: 404`);
      if (!response.ok) throw new TransportError('midi_load_failed', `midi/${midi}: ${response.status}`);
      const buffer = await response.arrayBuffer();
      let length;
      try {
        length = midiLengthSeconds(buffer);
      } catch (error) {
        throw new TransportError('midi_load_failed', `midi/${midi}: ${error.message}`);
      }
      if (token !== this.loadToken) return;
      if (!(length > 0)) throw new TransportError('midi_load_failed', `midi/${midi}: empty`);
      const loaded = new Promise((resolve) => {
        engine.seq.eventHandler.addEvent('songChange', 'transport-load', () => resolve());
      });
      engine.seq.loadNewSongList([{ binary: buffer, fileName: midi }]);
      await loaded;
      if (token !== this.loadToken) return;
      engine.seq.pause();
      engine.seq.loopCount = 0;
      engine.seq.playbackRate = this.rate;
      this.pinPiano(engine.synth);
      this.seqDuration = engine.seq.duration;
      this.passDuration = length;
      this.anchorPerf = Math.min(Math.max(startMs / 1000, 0), this.duration());
      this.setState('paused');
      if (autoplay) this.play();
    } catch (error) {
      if (token !== this.loadToken) return;
      this.midi = midi;
      this.passDuration = 0;
      this.setState('idle');
      throw error instanceof TransportError ? error : new TransportError('midi_load_failed', String(error.message ?? error));
    }
  }

  // MARK: Transport

  play(fromMs) {
    if (!this.passDuration || this.state === 'loading') return false;
    const engine = this.engineNow;
    if (engine.context.state !== 'running') engine.context.resume().catch(() => {});
    let from = fromMs !== undefined ? fromMs / 1000 : this.position();
    if (this.state === 'ended' && fromMs === undefined) from = 0;
    if (from >= this.duration()) from = 0;
    this.startAt(from);
    this.setState('playing');
    return true;
  }

  pause() {
    if (this.state !== 'playing') return;
    this.anchorPerf = this.position();
    this.halt();
    this.setState('paused');
  }

  /** Silences, rewinds and goes idle; the hymn stays loaded. */
  stop() {
    if (this.state === 'loading') return;
    this.halt();
    this.anchorPerf = 0;
    this.pass = 0;
    this.setState('idle', true);
  }

  seek(ms) {
    if (!this.passDuration) return;
    const to = Math.min(Math.max(ms / 1000, 0), this.duration());
    if (this.state === 'playing') {
      if (to >= this.duration()) { this.finish(); return; }
      this.startAt(to);
    } else {
      this.anchorPerf = to;
      if (this.state === 'ended' || this.state === 'idle') this.state = 'paused';
    }
    this.onChange();
  }

  setRate(rate) {
    const clamped = Math.min(Math.max(Number(rate) || 1, 0.5), 2);
    if (clamped === this.rate) return;
    if (this.state === 'playing') {
      this.anchorPerf = this.position();
      this.anchorTime = this.now();
      this.scheduleBoundary();
    }
    this.rate = clamped;
    if (this.engineNow) this.engineNow.seq.playbackRate = clamped;
    this.onChange();
  }

  // MARK: Passes

  /** Starts the sequencer at a performance time, in the right pass. */
  startAt(perf) {
    const { seq, synth } = this.engineNow;
    this.clearTimers();
    this.pass = Math.min(Math.floor(perf / this.passDuration), this.passes - 1);
    const offset = perf - this.pass * this.passDuration;
    this.anchorPerf = perf;
    this.anchorTime = this.now();
    seq.playbackRate = this.rate;
    if (offset < this.seqDuration) {
      seq.currentTime = offset;
      seq.play();
    } else {
      // In the silence after the last note, before End of Track.
      seq.pause();
      synth.stopAll(false);
    }
    this.scheduleBoundary();
    this.watchTimer = setInterval(() => this.watch(), 100);
  }

  /** The end of this pass: the tune again from the top, or the end of the hymn. */
  scheduleBoundary() {
    clearTimeout(this.boundaryTimer);
    const passEnd = (this.pass + 1) * this.passDuration;
    const wait = Math.max(0, (passEnd - this.position()) / this.rate);
    this.boundaryTimer = setTimeout(() => this.boundary(), wait * 1000);
  }

  watch() {
    if (this.state !== 'playing') return;
    if (this.position() >= (this.pass + 1) * this.passDuration - 0.001) this.boundary();
  }

  boundary() {
    if (this.state !== 'playing') return;
    const passEnd = (this.pass + 1) * this.passDuration;
    if (this.position() < passEnd - 0.002) { this.scheduleBoundary(); return; }
    if (this.pass + 1 >= this.passes) { this.finish(); return; }
    // Next verse: the tune from the top. Like iOS, the clock restarts the
    // pass when the sequencer does, so audio and position never drift apart.
    const { seq } = this.engineNow;
    this.pass += 1;
    this.anchorPerf = this.pass * this.passDuration;
    this.anchorTime = this.now();
    seq.currentTime = 0;
    seq.play();
    this.scheduleBoundary();
    this.onChange();
  }

  /** The last verse ended: back to the start, like iOS's finish(). */
  finish() {
    this.halt();
    this.anchorPerf = 0;
    this.pass = 0;
    this.setState('ended', true);
  }

  halt() {
    this.clearTimers();
    if (this.engineNow) {
      this.engineNow.seq.pause();
      this.engineNow.synth.stopAll(true);
    }
  }

  clearTimers() {
    clearTimeout(this.boundaryTimer);
    clearInterval(this.watchTimer);
    this.boundaryTimer = 0;
    this.watchTimer = 0;
  }

  setState(state, force = false) {
    if (state === this.state && !force) return;
    this.state = state;
    this.onChange();
  }

  /** The fields of `status` this side owns. */
  snapshot() {
    const pos = this.position();
    return {
      state: this.state,
      positionMs: Math.round(pos * 1000),
      durationMs: Math.round(this.duration() * 1000),
      passDurationMs: Math.round(this.passDuration * 1000),
      pass: this.passDuration ? Math.min(Math.floor(pos / this.passDuration), this.passes - 1) + 1 : 0,
      passes: this.passes,
      rate: this.rate,
      midi: this.midi,
    };
  }
}
