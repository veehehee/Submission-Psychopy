#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Binaural beats x flanker task
Adaptation of Colzato et al. (2017) using a flanker task.
Written for PsychoPy (Python script / Coder); audio is streamed with sounddevice.

SESSION (matches the written PSY310 modified design):
  consent / eligibility documented separately and equipment check
  -> two 25-trial practice blocks WITHOUT sound (repeat a block if accuracy < 50%)
  -> CONDITION 1: Pleasure x Arousal rating -> 1.5 min sound -> 80 flanker trials
     with sound continuing -> second rating
  -> 1 min break WITHOUT sound (SPACE skips it)
  -> CONDITION 2: same procedure with the other sound
  -> debrief question and end

IMPORTANT DESIGN NOTE:
  The original Colzato et al. procedure says the sound continued during both the
  training and experimental blocks. The PSY310 modified design specifies that
  practice is completed once, without sound, before the two sound conditions.
  This script follows the written modified design. Change the procedure itself
  (not just this comment) if you decide to include practice under sound.

SOUND:
  gamma   = 320 Hz left + 360 Hz right (40 Hz difference; 340 Hz mean carrier)
  control = 340 Hz in both ears
  Both conditions use the same white-noise setting.

The 2017 paper reports a 340-Hz carrier and white-noise masking but does not
report calibrated digital amplitudes in the method. TONE_AMP and NOISE_AMP below
are fixed implementation settings, NOT sound-pressure levels (dB SPL). Keep
them identical across conditions and participants; use the same headphones and
output-volume setting. Calibrate/verify the listening level safely before data
collection and document the actual equipment used.

DATA:
  ./data/<participantID>_<timestamp>_trials.csv
  ./data/<participantID>_<timestamp>_ratings.csv
  ./data/<participantID>_<timestamp>_info.txt
  The participant ID entered at startup is stored in the data rows.
"""

import csv
import math
import os
import re
import time
from datetime import datetime

import numpy as np
from psychopy import core, event, gui, visual
from psychopy.hardware import keyboard


# --------------------------------------------------------------------------------------
# CONFIGURATION
# --------------------------------------------------------------------------------------
SCREEN_WIDTH_CM_DEFAULT = 30.0   # Measure the visible screen width; do not assume this value.
VIEW_DIST_CM_DEFAULT = 57.0      # Eye-to-screen distance in cm; keep constant across participants.

ARROW_WIDTH_DEG = 0.8
GAP_NEAR_DEG = 0.1
GAP_FAR_DEG = 1.0                # Pilot: verify that far flankers still cause measurable interference.
FIX_SIZE_DEG = 0.6

FIX_RANGE_S = (0.400, 0.600)
RESPONSE_WINDOW_S = 2.5
ITI_RANGE_S = (0.900, 1.100)

N_PRACTICE_BLOCKS = 2
N_PRACTICE_TRIALS = 25
PRACTICE_FEEDBACK = False        # Feedback was not specified in the procedure; default is no feedback.
CHANCE_LEVEL = 0.50

N_MAIN_TRIALS = 80
N_PER_CELL = N_MAIN_TRIALS // 8  # 8 balanced cells x 10 repetitions = 80 trials per sound.
if N_MAIN_TRIALS % 8 != 0:
    raise ValueError('N_MAIN_TRIALS must be divisible by the 8 experimental cells.')
LEAD_IN_S = 90.0                 # 1.5 minutes before EACH sound-condition task.
BREAK_S = 60.0                  # 1-minute sound-free break; SPACE skips it. Set to 30.0 for 30 seconds.

CARRIER_HZ = 340.0
BEAT_HZ = 40.0
TONE_AMP = 0.25                  # Fixed digital amplitude; not calibrated dB SPL.
NOISE_AMP = 0.05                 # Fixed white-noise SD; not calibrated dB SPL.
FADE_S = 0.5
AUDIO_DEVICE = None              # Select/check the stereo headphone output before testing.

KEYS = {'left': 'z', 'right': 'slash'}
GRID_N = 9
GRID_CELL_PX = 46

TEXT_COLOUR = 'black'
STIM_COLOUR = 'red'
BG_COLOUR = 'white'

DEBUG_SHORT = False             # Test-only shortened timing/trial counts; NEVER use for data collection.


# --------------------------------------------------------------------------------------
# HELPERS
# --------------------------------------------------------------------------------------
class Abort(Exception):
    """Raised when the experimenter/participant presses ESC."""


def parse_numeric_field(value, field_name):
    """Parse a PsychoPy dialog value as a finite number.

    PsychoPy dialog fields can return values such as '18', '18.0', or a
    numeric type depending on the field/default and PsychoPy version. Accept
    all ordinary numeric forms, including a decimal comma, but reject blanks,
    units (for example '30 cm'), NaN, and infinity with a field-specific error.
    """
    try:
        if isinstance(value, (int, float, np.number)):
            number = float(value)
        else:
            text = str(value).strip()
            if text.count(',') == 1 and '.' not in text:
                text = text.replace(',', '.')
            number = float(text)
    except (TypeError, ValueError, OverflowError):
        raise ValueError(
            '%s must contain a number (do not include units such as cm).' % field_name)

    if not math.isfinite(number):
        raise ValueError('%s must be a finite number.' % field_name)
    return number


def deg2pix(deg, view_cm, pix_per_cm):
    """Convert visual angle (degrees) to pixels, assuming a flat screen."""
    return view_cm * math.tan(math.radians(deg)) * pix_per_cm


def build_cells():
    return [(c, d, r)
            for c in ('congruent', 'incongruent')
            for d in ('near', 'far')
            for r in ('left', 'right')]


def build_trials(rng, n_per_cell):
    """Balanced, fully shuffled list of (congruency, distance, target direction)."""
    trials = build_cells() * int(n_per_cell)
    order = rng.permutation(len(trials))
    return [trials[i] for i in order]


def build_practice(rng, n):
    """Random practice list; practice is not used in the main condition analyses."""
    cells = build_cells() * int(math.ceil(n / 8.0))
    order = rng.permutation(len(cells))[:n]
    return [cells[i] for i in order]


def arrow_vertices(width, direction):
    """Arrow polygon pointing right, mirrored for left."""
    w = float(width)
    vertices = [(-0.5 * w, -0.10 * w), (0.05 * w, -0.10 * w),
                (0.05 * w, -0.30 * w), (0.50 * w, 0.0),
                (0.05 * w, 0.30 * w), (0.05 * w, 0.10 * w),
                (-0.5 * w, 0.10 * w)]
    if direction == 'left':
        vertices = [(-x, y) for x, y in vertices]
    return vertices


def make_block(first_sample, frames, sr, f_left, f_right,
               a_left, a_right, noise_amp, rng):
    """Generate continuous stereo tones with the same white-noise waveform in both ears."""
    t = (first_sample + np.arange(frames)) / float(sr)
    noise = noise_amp * rng.standard_normal(frames)
    out = np.empty((frames, 2), dtype=np.float32)
    out[:, 0] = a_left * np.sin(2 * np.pi * f_left * t) + noise
    out[:, 1] = a_right * np.sin(2 * np.pi * f_right * t) + noise
    return out


SOUND_SETTINGS = {
    # name: (left_Hz, right_Hz, left_amplitude, right_amplitude, noise_SD)
    'gamma': (CARRIER_HZ - BEAT_HZ / 2, CARRIER_HZ + BEAT_HZ / 2,
              TONE_AMP, TONE_AMP, NOISE_AMP),
    'control': (CARRIER_HZ, CARRIER_HZ, TONE_AMP, TONE_AMP, NOISE_AMP),
    'test_left': (CARRIER_HZ, CARRIER_HZ, TONE_AMP, 0.0, 0.0),
    'test_right': (CARRIER_HZ, CARRIER_HZ, 0.0, TONE_AMP, 0.0),
}


class SoundPlayer:
    """Continuous stereo audio stream."""

    def __init__(self, device=None):
        import sounddevice as sd
        self.sd = sd
        device_info = sd.query_devices(device, 'output')
        self.sr = int(device_info['default_samplerate'])
        self.device = device
        self.device_name = device_info['name']
        self.rng = np.random.default_rng()
        self.stream = None
        self.settings = None
        self.n = 0
        self.fade_in_n = max(1, int(FADE_S * self.sr))
        self.fade_out_n = max(1, int(FADE_S * self.sr))
        self.fading_out = False
        self.fade_out_done = 0
        self.xruns = 0
        self.current_sound = None
        self.restart_count = 0
        self.callback_error = None

    def _callback(self, outdata, frames, time_info, status):
        """Generate audio on sounddevice's audio thread.

        Catch callback exceptions so they can be reported/recovered from by the
        experiment thread instead of silently killing audio playback.
        """
        if status:
            self.xruns += 1
        try:
            f_left, f_right, a_left, a_right, noise_amp = self.settings
            block = make_block(
                self.n, frames, self.sr, f_left, f_right,
                a_left, a_right, noise_amp, self.rng)
            idx = self.n + np.arange(frames)
            gain = np.minimum(1.0, idx / float(self.fade_in_n))
            if self.fading_out:
                k = self.fade_out_done + np.arange(frames)
                gain *= np.clip(1.0 - k / float(self.fade_out_n), 0.0, 1.0)
                self.fade_out_done += frames
            outdata[:] = block * gain[:, None].astype(np.float32)
            self.n += frames
        except Exception as exc:
            self.callback_error = '%s: %s' % (type(exc).__name__, exc)
            outdata.fill(0)

    def start(self, name):
        if name not in SOUND_SETTINGS:
            raise ValueError('Unknown sound condition: %s' % name)
        self.stop()
        self.current_sound = name
        self.settings = SOUND_SETTINGS[name]
        self.n = 0
        self.fading_out = False
        self.fade_out_done = 0
        self.xruns = 0
        self.callback_error = None
        self.stream = self.sd.OutputStream(
            samplerate=self.sr, channels=2, dtype='float32',
            device=self.device, latency='high', callback=self._callback)
        self.stream.start()
        # Give the OS audio thread a moment to initialize before the lead-in.
        time.sleep(0.15)
        if not self.stream.active:
            raise RuntimeError('The audio output stream did not remain active after starting.')

    def ensure_active(self):
        """Recover if the OS/audio driver stopped the stream during the task."""
        active = self.stream is not None and self.stream.active
        if not active or self.callback_error:
            reason = self.callback_error or 'audio stream was no longer active'
            print('Audio playback recovery (%s): restarting %s.' %
                  (reason, self.current_sound))
            if self.current_sound is None:
                raise RuntimeError('No sound condition has been selected.')
            self.restart_count += 1
            self.start(self.current_sound)

    def stop(self):
        if self.stream is not None:
            self.fading_out = True
            time.sleep(FADE_S + 0.1)
            try:
                self.stream.stop()
            finally:
                self.stream.close()
                self.stream = None
        self.current_sound = None


# --------------------------------------------------------------------------------------
# EXPERIMENT SCREENS AND TRIALS
# --------------------------------------------------------------------------------------
class Experiment:
    def __init__(self, win, kb, view_cm, pix_per_cm, fps, player,
                 trial_writer, rating_writer, info):
        self.win = win
        self.kb = kb
        self.fps = fps
        self.player = player
        self.view_cm = view_cm
        self.ppcm = pix_per_cm
        self.trial_writer = trial_writer
        self.rating_writer = rating_writer
        self.info = info
        self.clock = core.Clock()
        self.rng = np.random.default_rng()
        self.mouse = event.Mouse(win=win, visible=False)

        self.text = visual.TextStim(
            win, text='', color=TEXT_COLOUR, height=28,
            wrapWidth=win.size[0] * 0.8)
        self.fix = visual.TextStim(
            win, text='+', color=STIM_COLOUR,
            height=deg2pix(FIX_SIZE_DEG, view_cm, pix_per_cm))
        arrow_width_px = deg2pix(ARROW_WIDTH_DEG, view_cm, pix_per_cm)
        self.arrows = {
            direction: [
                visual.ShapeStim(win, vertices=arrow_vertices(arrow_width_px, direction),
                                 fillColor=STIM_COLOUR, lineColor=STIM_COLOUR,
                                 closeShape=True)
                for _ in range(5)
            ]
            for direction in ('left', 'right')
        }

    def check_escape(self):
        if self.kb.getKeys(keyList=['escape'], waitRelease=False):
            raise Abort()

    def show_text(self, message, key='space'):
        self.text.text = message
        self.kb.clearEvents()
        while True:
            self.text.draw()
            self.win.flip()
            if self.kb.getKeys(keyList=[key], waitRelease=False):
                return
            self.check_escape()

    def show_choice(self, message, valid_keys):
        """Display a prompt and return the first valid key pressed."""
        self.text.text = message
        self.kb.clearEvents()
        keys_to_check = list(valid_keys) + ['escape']
        while True:
            self.text.draw()
            self.win.flip()
            keys = self.kb.getKeys(keyList=keys_to_check, waitRelease=False)
            if keys:
                pressed = keys[0].name
                if pressed == 'escape':
                    raise Abort()
                if pressed in valid_keys:
                    return pressed

    def wait_seconds(self, seconds, message=None, draw_fix=True):
        """Display fixation (or text) for the specified duration."""
        t0 = self.clock.getTime()
        while self.clock.getTime() - t0 < seconds:
            if message:
                self.text.text = message
                self.text.draw()
            elif draw_fix:
                self.fix.draw()
            self.win.flip()
            self.check_escape()

    def blank(self, seconds):
        n_frames = int(round(seconds * self.fps))
        for _ in range(n_frames):
            self.win.flip()
            self.check_escape()

    # ---- Pleasure x Arousal grid
    def affect_grid(self, label):
        win, cell, n = self.win, GRID_CELL_PX, GRID_N
        half = (n - 1) / 2.0
        cells = {}
        for i in range(n):
            for j in range(n):
                cells[(i, j)] = visual.Rect(
                    win, width=cell, height=cell,
                    pos=((i - half) * cell, (j - half) * cell),
                    lineColor='black', fillColor='white', lineWidth=1)

        edge = n * cell / 2.0
        labels = [
            visual.TextStim(win, text='Unpleasant', color=TEXT_COLOUR, height=22,
                            pos=(-edge + 20, -edge - 30), anchorHoriz='left'),
            visual.TextStim(win, text='Pleasant', color=TEXT_COLOUR, height=22,
                            pos=(edge - 20, -edge - 30), anchorHoriz='right'),
            visual.TextStim(win, text='High arousal', color=TEXT_COLOUR, height=22,
                            pos=(-edge - 20, edge - 10), anchorHoriz='right'),
            visual.TextStim(win, text='Sleepy', color=TEXT_COLOUR, height=22,
                            pos=(-edge - 20, -edge + 10), anchorHoriz='right'),
            visual.TextStim(
                win,
                text='Click the square that best describes how you feel right now, then press SPACE.',
                color=TEXT_COLOUR, height=24, pos=(0, edge + 50),
                wrapWidth=win.size[0] * 0.9),
        ]

        selected = None
        was_down = False
        self.mouse.setVisible(True)
        self.kb.clearEvents()
        while True:
            for key, rect in cells.items():
                rect.fillColor = '#9ecae1' if key == selected else 'white'
                rect.draw()
            for stimulus in labels:
                stimulus.draw()
            win.flip()

            down = self.mouse.getPressed()[0]
            if down and not was_down:
                x, y = self.mouse.getPos()
                i = int(math.floor(x / cell + half + 0.5))
                j = int(math.floor(y / cell + half + 0.5))
                if 0 <= i < n and 0 <= j < n:
                    selected = (i, j)
            was_down = bool(down)

            if selected is not None and self.kb.getKeys(keyList=['space'], waitRelease=False):
                break
            self.check_escape()

        self.mouse.setVisible(False)
        # Store the original Affect Grid scale: -4 (low/negative) through +4 (high/positive).
        # x = pleasure; y = arousal.
        return selected[0] - 4, selected[1] - 4

    # ---- one flanker trial
    def run_trial(self, cong, dist, direction, phase, sound,
                  condition_number, block_number, attempt, trial_no,
                  feedback=False):
        # The background sound must remain active throughout every experimental
        # trial. Practice is intentionally silent in the modified PSY310 design.
        if phase == 'main':
            self.player.ensure_active()
        win, kb = self.win, self.kb
        gap = GAP_NEAR_DEG if dist == 'near' else GAP_FAR_DEG
        target_dir = direction
        flank_dir = direction if cong == 'congruent' else (
            'right' if direction == 'left' else 'left')
        spacing = ARROW_WIDTH_DEG + gap

        stimuli = []
        for position_index in range(-2, 3):
            arrow_direction = target_dir if position_index == 0 else flank_dir
            stimulus = self.arrows[arrow_direction][position_index + 2]
            x = deg2pix(abs(position_index) * spacing,
                        self.view_cm, self.ppcm) * (1 if position_index >= 0 else -1)
            stimulus.pos = (x, 0)
            stimuli.append(stimulus)

        # Jittered fixation cross (400-600 ms).
        fixation_duration = self.rng.uniform(*FIX_RANGE_S)
        for _ in range(int(round(fixation_duration * self.fps))):
            self.fix.draw()
            win.flip()
            self.check_escape()

        # Arrow row remains visible until response or 2500 ms.
        onset = {}

        def mark_onset():
            onset['t'] = self.clock.getTime()
            kb.clock.reset()

        kb.clearEvents()
        win.callOnFlip(mark_onset)
        key, rt = None, None
        first_frame = True
        while True:
            for stimulus in stimuli:
                stimulus.draw()
            win.flip()
            keys = kb.getKeys(
                keyList=[KEYS['left'], KEYS['right'], 'escape'],
                waitRelease=False)
            if keys:
                pressed = keys[0].name
                if pressed == 'escape':
                    raise Abort()
                key = pressed
                rt = keys[0].rt
                break
            if not first_frame and kb.clock.getTime() >= RESPONSE_WINDOW_S:
                break
            first_frame = False

        correct = int(key == KEYS[target_dir]) if key else 0
        iti = self.rng.uniform(*ITI_RANGE_S)
        if feedback:
            feedback_message = 'Correct' if correct else (
                'Too slow' if key is None else 'Wrong')
            self.wait_seconds(0.5, message=feedback_message)
        self.blank(iti)

        self.trial_writer.writerow({
            'participant': self.info['participant'],
            'order': self.info['order'],
            'phase': phase,
            'sound': sound,
            'condition_number': condition_number,
            'block_number': block_number,
            'practice_attempt': attempt if phase == 'practice' else '',
            'trial': trial_no,
            'congruency': cong,
            'distance': dist,
            'target_direction': target_dir,
            'flanker_direction': flank_dir,
            'key': key or '',
            'correct': correct,
            'rt_s': '' if rt is None else '%.4f' % rt,
            'rt_below_150ms': int(rt is not None and rt < 0.150),
            'timed_out': int(key is None),
            'fixation_s': '%.3f' % fixation_duration,
            'iti_s': '%.3f' % iti,
            'onset_time_s': '%.4f' % onset.get('t', float('nan')),
            'frame_rate': '%.2f' % self.fps,
        })
        return correct

    def run_trials(self, trials, phase, sound, condition_number,
                   block_number, attempt=1, feedback=False):
        correct_count = 0
        for trial_no, (cong, dist, direction) in enumerate(trials, start=1):
            correct_count += self.run_trial(
                cong, dist, direction, phase, sound, condition_number,
                block_number, attempt, trial_no, feedback=feedback)
        return correct_count / float(len(trials)) if trials else 0.0

    # ---- one sound condition
    def run_condition(self, sound, cond_no):
        info = self.info
        pleasure, arousal = self.affect_grid('pre')
        self.rating_writer.writerow({
            'participant': info['participant'], 'sound': sound,
            'condition_number': cond_no, 'time': 'pre',
            'pleasure': pleasure, 'arousal': arousal})

        self.show_text(
            'You will now hear a background sound for 1.5 minutes. Keep your eyes on the cross.\n\n'
            'The task will begin automatically when the 1.5 minutes are over. The sound will '
            'continue during all 80 trials.\n\n'
            'Respond to the MIDDLE arrow as quickly and accurately as you can: '
            'Z = pointing left, / = pointing right.\n\n'
            'Press SPACE when you are ready to start.')

        self.player.start(sound)
        try:
            # Verify that the same continuous stream used for the lead-in is
            # still active when the arrow task begins.
            self.player.ensure_active()
            self.wait_seconds(5.0 if DEBUG_SHORT else LEAD_IN_S)
            self.player.ensure_active()
            trials = build_trials(self.rng, 2 if DEBUG_SHORT else N_PER_CELL)
            self.run_trials(
                trials, phase='main', sound=sound,
                condition_number=cond_no, block_number=1,
                attempt=1, feedback=False)
        finally:
            underflows = self.player.xruns
            restarts = self.player.restart_count
            callback_error = self.player.callback_error or ''
            self.player.stop()

        self.info['audio_underflows_%s' % sound] = underflows
        self.info['audio_restarts_%s' % sound] = restarts
        self.info['audio_callback_error_%s' % sound] = callback_error
        pleasure, arousal = self.affect_grid('post')
        self.rating_writer.writerow({
            'participant': info['participant'], 'sound': sound,
            'condition_number': cond_no, 'time': 'post',
            'pleasure': pleasure, 'arousal': arousal})

    def run_break(self):
        """Run a short silent break; SPACE skips it and ESC aborts the session."""
        total = 10 if DEBUG_SHORT else BREAK_S
        start_time = self.clock.getTime()
        skipped = False

        # Clear the SPACE press used to finish the preceding mood rating so
        # only a fresh press during this screen can skip the break.
        self.kb.clearEvents()

        while True:
            keys = self.kb.getKeys(
                keyList=['space', 'escape'], waitRelease=False)
            if keys:
                pressed_names = [key.name for key in keys]
                if 'escape' in pressed_names:
                    raise Abort()
                if 'space' in pressed_names:
                    skipped = True
                    break

            elapsed = self.clock.getTime() - start_time
            remaining = total - elapsed
            if remaining <= 0:
                break

            self.text.text = (
                'Break (no sound). Please rest.\n\n'
                'Time remaining: %d:%02d\n\n'
                'Press SPACE to skip the break.' %
                (int(remaining) // 60, int(remaining) % 60))
            self.text.draw()
            self.win.flip()
            self.check_escape()

        elapsed = self.clock.getTime() - start_time
        self.info['break_skipped'] = skipped
        self.info['break_elapsed_seconds'] = round(elapsed, 2)
        self.info['break_scheduled_seconds'] = total
        # No extra SPACE-to-continue screen: the next condition starts
        # immediately with its pre-condition mood rating.


def audio_and_screen_test(exp, player):
    """Check physical screen scaling and stereo left/right output before data collection."""
    win = exp.win
    bar = visual.Rect(
        win, width=10 * exp.ppcm, height=20,
        fillColor='black', lineColor='black')
    exp.text.pos = (0, 150)
    exp.text.text = (
        'SCREEN CHECK: measure the black bar with a ruler. It should be exactly 10 cm.\n\n'
        'Press SPACE when ready to check it.')
    exp.kb.clearEvents()
    while not exp.kb.getKeys(keyList=['space'], waitRelease=False):
        bar.draw()
        exp.text.draw()
        win.flip()
        exp.check_escape()
    exp.text.pos = (0, 0)

    screen_answer = exp.show_choice(
        'Does the black bar measure 10 cm?\n\nY = yes     N = no', ['y', 'n'])
    if screen_answer == 'n':
        raise Abort('Screen calibration failed; correct screen width and restart.')

    print('Audio output device:', player.device_name, '| sample rate:', player.sr)
    for name, ear_label in (('test_left', 'LEFT'), ('test_right', 'RIGHT')):
        player.start(name)
        try:
            answer = exp.show_choice(
                'A test tone is playing. Did you hear it ONLY in the %s ear?\n\n'
                'Y = yes     N = no' % ear_label,
                ['y', 'n'])
        finally:
            player.stop()
        if answer == 'n':
            raise Abort('Stereo output check failed; correct the headphone/output setup.')

    exp.show_text(
        'Equipment check complete.\n\n'
        'Please use the same in-ear headphones and keep the computer/headphone '
        'volume unchanged for both sound conditions.\n\n'
        'Set a comfortable, safe listening level before proceeding. Press SPACE.')


def write_info_file(path, info, order, sounds, screen_cm, view_cm,
                    fps, win, player):
    with open(path, 'w', encoding='utf-8') as file_handle:
        file_handle.write('participant: %s\n' % info.get('participant', ''))
        file_handle.write('order: %s\n' % order)
        file_handle.write('sounds: %s\n' % sounds)
        file_handle.write('screen_width_cm: %s\n' % screen_cm)
        file_handle.write('viewing_distance_cm: %s\n' % view_cm)
        file_handle.write('screen_resolution_px: %s\n' % (win.size,))
        file_handle.write('frame_rate_hz: %.2f\n' % fps)
        file_handle.write('audio_device: %s\n' % player.device_name)
        file_handle.write('audio_sample_rate_hz: %s\n' % player.sr)
        file_handle.write('carrier_hz: %s\n' % CARRIER_HZ)
        file_handle.write('binaural_beat_hz: %s\n' % BEAT_HZ)
        file_handle.write('gamma_left_hz: %s\n' % (CARRIER_HZ - BEAT_HZ / 2))
        file_handle.write('gamma_right_hz: %s\n' % (CARRIER_HZ + BEAT_HZ / 2))
        file_handle.write('control_left_hz: %s\n' % CARRIER_HZ)
        file_handle.write('control_right_hz: %s\n' % CARRIER_HZ)
        file_handle.write('tone_amplitude_digital: %s\n' % TONE_AMP)
        file_handle.write('white_noise_sd_digital: %s\n' % NOISE_AMP)
        file_handle.write('audio_levels_calibrated_db_spl: NO\n')
        file_handle.write('lead_in_seconds: %s\n' % LEAD_IN_S)
        file_handle.write('break_seconds: %s\n' % BREAK_S)
        file_handle.write('arrow_width_degrees: %s\n' % ARROW_WIDTH_DEG)
        file_handle.write('near_gap_degrees: %s\n' % GAP_NEAR_DEG)
        file_handle.write('far_gap_degrees: %s\n' % GAP_FAR_DEG)
        file_handle.write('practice_trials_per_block: %s\n' % N_PRACTICE_TRIALS)
        file_handle.write('experimental_trials_per_condition: %s\n' % N_MAIN_TRIALS)
        file_handle.write('trials_per_cell_per_condition: %s\n' % N_PER_CELL)
        file_handle.write('practice_feedback: %s\n' % PRACTICE_FEEDBACK)
        file_handle.write('debug_short: %s\n' % DEBUG_SHORT)
        for key, value in info.items():
            if key != 'participant':
                file_handle.write('%s: %s\n' % (key, value))


def main():
    global DEBUG_SHORT

    # Startup dialog: only participant ID and condition order.
    # Participant ID accepts text or numbers and is saved in every data row.
    dialog = gui.Dlg(title='Binaural beats x flanker')
    dialog.addField('Participant ID', '')
    dialog.addField('Condition order (both conditions run)', choices=[
        'Gamma first (40 Hz)', 'Control first (340 Hz)'])
    values = dialog.show()
    if not dialog.OK:
        core.quit()

    participant_id, condition_choice = values
    participant_id = str(participant_id).strip()
    if not participant_id:
        error_dialog = gui.Dlg(title='Invalid participant ID')
        error_dialog.addText('Please enter a participant ID (text or numbers).')
        error_dialog.show()
        core.quit()

    # These display measurements stay in the script, not the startup dialog.
    # Set them to the actual screen width and participant viewing distance.
    screen_cm = parse_numeric_field(SCREEN_WIDTH_CM_DEFAULT, 'Screen width')
    view_cm = parse_numeric_field(VIEW_DIST_CM_DEFAULT, 'Viewing distance')
    if screen_cm <= 0 or view_cm <= 0:
        error_dialog = gui.Dlg(title='Invalid display settings')
        error_dialog.addText(
            'SCREEN_WIDTH_CM_DEFAULT and VIEW_DIST_CM_DEFAULT at the top of '
            'the script must both be greater than zero.')
        error_dialog.show()
        core.quit()

    order = ('gamma_first' if condition_choice.startswith('Gamma')
             else 'control_first')
    sounds = ['gamma', 'control'] if order == 'gamma_first' else ['control', 'gamma']

    # Timestamp prevents repeated sessions for the same participant from
    # overwriting one another. The original participant ID remains in the CSVs.
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    safe_participant_id = re.sub(r'[^A-Za-z0-9_-]+', '_', participant_id).strip('_')
    if not safe_participant_id:
        safe_participant_id = 'participant'
    base = os.path.join('data', '%s_%s' % (safe_participant_id, timestamp))
    print('Participant ID: %s | Condition order: %s' % (participant_id, order))

    # Debug mode is deliberately fixed off for real data collection.
    DEBUG_SHORT = False
    os.makedirs('data', exist_ok=True)

    trial_fields = [
        'participant', 'order', 'phase', 'sound', 'condition_number',
        'block_number', 'practice_attempt', 'trial', 'congruency', 'distance',
        'target_direction', 'flanker_direction', 'key', 'correct', 'rt_s',
        'rt_below_150ms', 'timed_out', 'fixation_s', 'iti_s', 'onset_time_s', 'frame_rate']
    rating_fields = [
        'participant', 'sound', 'condition_number', 'time', 'pleasure', 'arousal']

    trials_file = open(base + '_trials.csv', 'w', newline='', encoding='utf-8')
    ratings_file = open(base + '_ratings.csv', 'w', newline='', encoding='utf-8')
    trial_writer = csv.DictWriter(trials_file, fieldnames=trial_fields)
    rating_writer = csv.DictWriter(ratings_file, fieldnames=rating_fields)
    trial_writer.writeheader()
    rating_writer.writeheader()

    win = None
    player = None
    fps = float('nan')
    info = {
        'participant': participant_id,
        'order': order,
    }

    try:
        win = visual.Window(
            fullscr=True, color=BG_COLOUR, units='pix',
            allowGUI=False, checkTiming=False)
        win.mouseVisible = False
        pix_per_cm = win.size[0] / float(screen_cm)
        fps = win.getActualFrameRate(
            nIdentical=10, nMaxFrames=120, nWarmUpFrames=10, threshold=1) or 60.0
        kb = keyboard.Keyboard()
        player = SoundPlayer(AUDIO_DEVICE)
        exp = Experiment(
            win, kb, float(view_cm), pix_per_cm, fps, player,
            trial_writer, rating_writer, info)

        exp.show_text(
            'Welcome, and thank you for taking part.\n\n'
            'In this experiment you will see rows of five arrows and press a key '
            'for the direction of the MIDDLE arrow, ignoring the others.\n\n'
            'Z = middle arrow points left      / = middle arrow points right\n\n'
            'You will hear two background sounds in separate conditions. You will '
            'not be told which sound is expected to affect performance.\n\n'
            'Respond as quickly and accurately as you can. Press SPACE to begin the equipment check.')
        audio_and_screen_test(exp, player)

        # Two 25-trial practice blocks, once and without sound as specified in the
        # modified PSY310 design. Repeat a block until accuracy is at least 50%.
        for practice_block in range(1, N_PRACTICE_BLOCKS + 1):
            attempt = 1
            while True:
                n_practice = 6 if DEBUG_SHORT else N_PRACTICE_TRIALS
                practice_trials = build_practice(exp.rng, n_practice)
                accuracy = exp.run_trials(
                    practice_trials, phase='practice', sound='none',
                    condition_number=0, block_number=practice_block,
                    attempt=attempt, feedback=PRACTICE_FEEDBACK)
                if accuracy < CHANCE_LEVEL:
                    exp.show_text(
                        'Practice block %d accuracy was %.0f%%, below the 50%% chance level.\n\n'
                        'The block will be repeated. Press SPACE to repeat.' %
                        (practice_block, accuracy * 100))
                    attempt += 1
                else:
                    exp.show_text(
                        'Practice block %d of %d completed. Accuracy: %.0f%%.\n\n'
                        'Press SPACE to continue.' %
                        (practice_block, N_PRACTICE_BLOCKS, accuracy * 100))
                    break

        # Both conditions are completed by every participant. The order is
        # selected in the startup dialog and should be counterbalanced using
        # the experimenter's separate participant-tracking Excel sheet.
        for condition_number, sound in enumerate(sounds, start=1):
            exp.run_condition(sound, condition_number)
            if condition_number == 1:
                exp.run_break()

        guess = exp.show_choice(
            'Debrief question: which of the two sounds do you think was the special one?\n\n'
            'Press 1 = FIRST sound\n'
            'Press 2 = SECOND sound\n'
            'Press 3 = I have no idea',
            ['1', '2', '3'])
        info['debrief_guess'] = {
            '1': 'first_sound',
            '2': 'second_sound',
            '3': 'no_idea',
        }[guess]
        exp.show_text('Thank you. The experiment is complete. Press SPACE to finish.')

    except Abort as exc:
        print('Experiment stopped:', str(exc) or 'aborted by participant/experimenter.')
        info['aborted'] = True
        if str(exc):
            info['abort_reason'] = str(exc)
    finally:
        if player is not None:
            try:
                player.stop()
            except Exception:
                pass
        if win is not None:
            try:
                if player is not None:
                    write_info_file(
                        base + '_info.txt', info, order, sounds,
                        screen_cm, view_cm, fps, win, player)
            except Exception as exc:
                print('Could not write info file:', exc)
            try:
                win.close()
            except Exception:
                pass
        trials_file.close()
        ratings_file.close()
        core.quit()


if __name__ == '__main__':
    main()
