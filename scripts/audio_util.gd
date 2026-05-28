extends RefCounted

# Procedural one-shot audio. Generates 16-bit mono PCM data and wraps it as
# an AudioStreamWAV. No on-disk sample files required.


static func make_tone(frequency: float, duration: float, sample_rate := 22050, fade_curve := 1.5) -> AudioStreamWAV:
	var safe_sample_rate: int = max(1, sample_rate)
	var sample_count: int = max(0, int(safe_sample_rate * max(0.0, duration)))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	if sample_count == 0:
		return _make_stream(bytes, safe_sample_rate)
	sample_rate = safe_sample_rate
	var two_pi_f := TAU * frequency
	var inv_sample_rate := 1.0 / float(sample_rate)
	var inv_duration: float = 1.0 / max(duration, 0.001)
	for i in range(sample_count):
		var t := float(i) * inv_sample_rate
		var decay_ratio: float = clamp(t * inv_duration, 0.0, 1.0)
		var envelope := pow(1.0 - decay_ratio, fade_curve)
		var attack: float = clamp(t / 0.005, 0.0, 1.0)
		var sample := sin(t * two_pi_f) * envelope * attack * 0.55
		_write_sample(bytes, i, sample)
	return _make_stream(bytes, sample_rate)


static func make_chord(frequencies: PackedFloat32Array, duration: float, sample_rate := 22050) -> AudioStreamWAV:
	var safe_sample_rate: int = max(1, sample_rate)
	var sample_count: int = max(0, int(safe_sample_rate * max(0.0, duration)))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	if sample_count == 0:
		return _make_stream(bytes, safe_sample_rate)
	sample_rate = safe_sample_rate
	var inv_sample_rate := 1.0 / float(sample_rate)
	var inv_duration: float = 1.0 / max(duration, 0.001)
	var voice_scale: float = 0.6 / max(1.0, float(frequencies.size()))
	for i in range(sample_count):
		var t := float(i) * inv_sample_rate
		var decay_ratio: float = clamp(t * inv_duration, 0.0, 1.0)
		var envelope := pow(1.0 - decay_ratio, 1.6)
		var attack: float = clamp(t / 0.008, 0.0, 1.0)
		var mix := 0.0
		for freq in frequencies:
			mix += sin(t * TAU * freq)
		_write_sample(bytes, i, mix * voice_scale * envelope * attack)
	return _make_stream(bytes, sample_rate)


static func make_noise_burst(duration: float, sample_rate := 22050, low_pass_alpha := 0.45) -> AudioStreamWAV:
	var safe_sample_rate: int = max(1, sample_rate)
	var sample_count: int = max(0, int(safe_sample_rate * max(0.0, duration)))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	if sample_count == 0:
		return _make_stream(bytes, safe_sample_rate)
	sample_rate = safe_sample_rate
	var rng := RandomNumberGenerator.new()
	rng.seed = 19937
	var inv_sample_rate := 1.0 / float(sample_rate)
	var inv_duration: float = 1.0 / max(duration, 0.001)
	var prev := 0.0
	for i in range(sample_count):
		var raw := rng.randf_range(-1.0, 1.0)
		prev = lerp(prev, raw, low_pass_alpha)
		var t := float(i) * inv_sample_rate
		var ratio: float = clamp(t * inv_duration, 0.0, 1.0)
		var envelope := (1.0 - ratio) * (1.0 - ratio)
		_write_sample(bytes, i, prev * envelope * 0.7)
	return _make_stream(bytes, sample_rate)


static func _write_sample(bytes: PackedByteArray, index: int, sample: float) -> void:
	var clamped: float = clamp(sample, -1.0, 1.0)
	var int_sample: int = int(clamped * 32767.0)
	if int_sample < 0:
		int_sample += 65536
	bytes[index * 2] = int_sample & 0xFF
	bytes[index * 2 + 1] = (int_sample >> 8) & 0xFF


static func _make_stream(bytes: PackedByteArray, sample_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream
