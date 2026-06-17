extends Node
class_name SoundBank
## Retro sound effects, generated entirely in code (no audio files needed).
##
## Each effect is synthesised once at startup into a small AudioStreamWAV using
## simple waveforms + envelopes — the audio equivalent of the game's
## primitive-drawn visuals. A tiny pool of players lets several sounds overlap.
##
## Usage:  sound.play("found")   (called from Main in response to gs.sfx)

const RATE := 22050
const POOL := 8

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bank: Dictionary = {}     ## name -> AudioStreamWAV
var enabled := true

func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_bank()

func _build_bank() -> void:
	_bank["search"]  = _segments([[220.0, 0.05, "square", 0.18]])
	_bank["empty"]   = _segments([[180.0, 0.05, "square", 0.12], [150.0, 0.05, "square", 0.10]])
	_bank["found"]   = _segments([[523.0, 0.06, "square", 0.22], [659.0, 0.06, "square", 0.22], [880.0, 0.10, "square", 0.24]])
	_bank["plant"]   = _segments([[330.0, 0.04, "saw", 0.20], [110.0, 0.06, "square", 0.18]])
	_bank["detect"]  = _segments([[880.0, 0.04, "sine", 0.18], [0.0, 0.03, "square", 0.0], [880.0, 0.05, "sine", 0.18]])
	_bank["disarm"]  = _segments([[660.0, 0.05, "sine", 0.18], [440.0, 0.08, "sine", 0.16]])
	_bank["door"]    = _segments([[140.0, 0.05, "square", 0.18], [90.0, 0.06, "square", 0.16]])
	_bank["blocked"] = _segments([[120.0, 0.10, "square", 0.16]])
	_bank["win"]     = _segments([[523.0, 0.10, "square", 0.22], [659.0, 0.10, "square", 0.22], [784.0, 0.10, "square", 0.22], [1047.0, 0.18, "square", 0.24]])
	_bank["select"]  = _segments([[440.0, 0.04, "square", 0.18], [660.0, 0.05, "square", 0.18]])
	_bank["death"]   = _boom()

func play(name: String) -> void:
	if not enabled:
		return
	var stream: AudioStreamWAV = _bank.get(name, null)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.play()

# ---------------------------------------------------------------------------
# SYNTHESIS
# ---------------------------------------------------------------------------
## Build a stream from a list of [freq, dur, wave, vol] segments played back to
## back. wave is "square" | "saw" | "sine" | "noise". freq 0 = silence.
func _segments(segs: Array) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	for seg in segs:
		var freq: float = seg[0]
		var dur: float = seg[1]
		var wave: String = seg[2]
		var vol: float = seg[3]
		var n := int(RATE * dur)
		for i in n:
			var t := float(i) / RATE
			var s := 0.0
			if freq > 0.0:
				var ph := fmod(t * freq, 1.0)
				match wave:
					"square": s = 1.0 if ph < 0.5 else -1.0
					"saw":    s = ph * 2.0 - 1.0
					"sine":   s = sin(ph * TAU)
					"noise":  s = randf() * 2.0 - 1.0
			# soft attack + decay envelope to avoid clicks
			var env := 1.0
			var fade := 0.012 * RATE
			if i < fade:
				env = float(i) / fade
			elif i > n - fade:
				env = float(n - i) / fade
			samples.append(s * env * vol)
	return _to_wav(samples)

## A noisy explosion with a low rumble and exponential decay.
func _boom() -> AudioStreamWAV:
	var dur := 0.55
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 7.0)
		var noise := randf() * 2.0 - 1.0
		var rumble := sin(TAU * 65.0 * t)
		samples[i] = clampf((noise * 0.7 + rumble * 0.6) * env * 0.5, -1.0, 1.0)
	return _to_wav(samples)

func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampf(samples[i], -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
