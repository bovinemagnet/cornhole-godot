extends RefCounted

const AudioUtil = preload("res://scripts/audio_util.gd")


func test_make_tone_returns_audio_stream_wav() -> String:
	var stream: AudioStreamWAV = AudioUtil.make_tone(440.0, 0.05)
	if not (stream is AudioStreamWAV):
		return "expected AudioStreamWAV"
	return ""


func test_make_tone_data_length_matches_duration() -> String:
	var sample_rate := 22050
	var duration := 0.1
	var stream: AudioStreamWAV = AudioUtil.make_tone(440.0, duration, sample_rate)
	var expected_bytes: int = int(sample_rate * duration) * 2
	if stream.data.size() != expected_bytes:
		return "expected %d bytes, got %d" % [expected_bytes, stream.data.size()]
	return ""


func test_make_tone_uses_requested_mix_rate() -> String:
	var stream: AudioStreamWAV = AudioUtil.make_tone(440.0, 0.05, 11025)
	if stream.mix_rate != 11025:
		return "expected mix_rate 11025, got %d" % stream.mix_rate
	return ""


func test_make_tone_format_is_16_bit_mono() -> String:
	var stream: AudioStreamWAV = AudioUtil.make_tone(440.0, 0.05)
	if stream.format != AudioStreamWAV.FORMAT_16_BITS:
		return "expected FORMAT_16_BITS"
	if stream.stereo:
		return "expected mono"
	return ""


func test_make_noise_burst_has_data() -> String:
	var stream: AudioStreamWAV = AudioUtil.make_noise_burst(0.08, 22050)
	if stream.data.size() == 0:
		return "expected non-empty data"
	return ""


func test_make_chord_data_length_matches_duration() -> String:
	var freqs := PackedFloat32Array([440.0, 660.0, 880.0])
	var sample_rate := 22050
	var duration := 0.12
	var stream: AudioStreamWAV = AudioUtil.make_chord(freqs, duration, sample_rate)
	var expected_bytes: int = int(sample_rate * duration) * 2
	if stream.data.size() != expected_bytes:
		return "expected %d bytes, got %d" % [expected_bytes, stream.data.size()]
	return ""
