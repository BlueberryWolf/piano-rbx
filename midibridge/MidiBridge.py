"""
qc88 midi-to-xinput bridge

protocol (event stream):
4 gamepads act as parallel event pipelines
each gamepad encodes 18 bits of data per event:
left trigger = note id (7 bits, 0-127 mapped to float 0.0-1.0)
right trigger = velocity (7 bits, 0-127 mapped to float 0.0-1.0)
l1/r1/l3/r3 = channel (4 bits, 0-15)
face buttons = rotated action triggers (a, b, x, y)

the face buttons are rotated each time an event fires
this ensures the roblox client detects a discrete input began event, even for consecutive identical notes
"""

import mido
import vgamepad as vg
import time
import sys
import traceback
from collections import defaultdict

# protocol consts
GAMEPAD_COUNT = 4
START_NOTE    = 36
FOLD_MIN      = 45
FOLD_MAX      = 108
DRUM_CHANNEL  = 9

ACTION_BUTTONS = [
    vg.XUSB_BUTTON.XUSB_GAMEPAD_A,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_B,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_X,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_Y,
]

CHANNEL_BUTTONS = [
    vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_THUMB,
]

def _sleep_until(target: float) -> None:
    slack = target - time.perf_counter()
    if slack > 0.003:
        time.sleep(slack - 0.002)
    while time.perf_counter() < target:
        pass


# bridge
class MidiBridge:

    def __init__(self, path: str, start_note: int = START_NOTE):
        self.path       = path
        self.start_note = start_note

        print(f"Initializing {GAMEPAD_COUNT} virtual XInput controllers …")
        try:
            self.gps = [vg.VX360Gamepad() for _ in range(GAMEPAD_COUNT)]
        except Exception as e:
            print(f"FATAL: {e}\nIs ViGEmBus installed?")
            sys.exit(1)

        self.gp_trigger_idx = [0] * GAMEPAD_COUNT
        self.gp_last_time = [0.0] * GAMEPAD_COUNT

        self.holders: dict[int, dict[int, bool]] = defaultdict(dict)

    # driver helpers

    def _send_event(self, note: int, velocity: int, channel: int) -> None:
        best_gp = 0
        oldest_time = self.gp_last_time[0]
        for i in range(1, GAMEPAD_COUNT):
            if self.gp_last_time[i] < oldest_time:
                best_gp = i
                oldest_time = self.gp_last_time[i]

        now = time.perf_counter()
        gap = 0.016 - (now - oldest_time)
        if gap > 0:
            time.sleep(gap)
            now = time.perf_counter()

        gp_i = best_gp
        gp = self.gps[gp_i]

        prev_idx = (self.gp_trigger_idx[gp_i] - 1) % len(ACTION_BUTTONS)
        gp.release_button(ACTION_BUTTONS[prev_idx])

        gp.left_trigger_float(max(0.0, min(1.0, note / 127.0)))
        gp.right_trigger_float(max(0.0, min(1.0, velocity / 127.0)))

        ch_bits = channel - 1
        for bit in range(4):
            if (ch_bits & (1 << bit)) != 0:
                gp.press_button(CHANNEL_BUTTONS[bit])
            else:
                gp.release_button(CHANNEL_BUTTONS[bit])

        curr_idx = self.gp_trigger_idx[gp_i]
        gp.press_button(ACTION_BUTTONS[curr_idx])
        gp.update()

        self.gp_trigger_idx[gp_i] = (curr_idx + 1) % len(ACTION_BUTTONS)
        self.gp_last_time[gp_i] = now

    def _note_on(self, note: int, velocity: int, channel: int) -> None:
        self._send_event(note, velocity, channel)

    def _note_off(self, note: int, channel: int) -> None:
        self._send_event(note, 0, channel)

    # pre-processing

    def _load(self):
        mid = mido.MidiFile(self.path)
        print(f"  Type {mid.type}  |  {len(mid.tracks)} tracks"
              f"  |  {mid.ticks_per_beat} ticks/beat")

        events = []
        t = 0.0
        for msg in mid:
            t += msg.time
            if msg.is_meta:
                continue
            ch = getattr(msg, 'channel', 0)
            if ch == DRUM_CHANNEL:
                continue
            if msg.type == 'note_on' or msg.type == 'note_off':
                note = msg.note
                vel = msg.velocity if msg.type == 'note_on' else 0

                if vel > 0 or msg.type == 'note_off':
                    while note < FOLD_MIN:
                        note += 12
                    while note > FOLD_MAX:
                        note -= 12

                events.append((t, note, vel, ch + 1))

        events.sort(key=lambda e: e[0])
        on_ct  = sum(1 for e in events if e[2] > 0)
        off_ct = sum(1 for e in events if e[2] == 0)
        dur    = events[-1][0] if events else 0.0
        print(f"  {on_ct} note-on  |  {off_ct} note-off  |  {dur:.1f}s")
        return events

    # playback

    def play(self) -> None:
        try:
            print(f"Loading: {self.path}")
            events = self._load()
            print("Playing …  (Ctrl+C to stop)\\n")

            start = time.perf_counter()

            for abs_t, note, velocity, channel in events:
                _sleep_until(start + abs_t)

                if velocity > 0:
                    self.holders[note][channel] = True
                    self._note_on(note, velocity, channel)
                else:
                    self.holders[note].pop(channel, None)
                    if len(self.holders[note]) == 0:
                        self._note_off(note, channel)

        except KeyboardInterrupt:
            print("\\nStopped by user.")
        except Exception:
            traceback.print_exc()
        finally:
            self._cleanup()

    def _cleanup(self) -> None:
        print("Releasing all notes …")
        for gp in self.gps:
            try:
                gp.reset()
                gp.update()
            except Exception:
                pass
        print("Done.")


# entry point
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python MidiBridge.py <midi_file> [start_note=36]")
        sys.exit(1)
    path  = sys.argv[1]
    start = int(sys.argv[2]) if len(sys.argv) > 2 else START_NOTE
    MidiBridge(path, start).play()
