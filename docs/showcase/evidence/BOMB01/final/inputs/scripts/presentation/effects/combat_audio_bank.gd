class_name CombatAudioBank
extends RefCounted

## Original procedural mono PCM. Separate fixed RNG, never SimulationWorld.rng.
static func synthesize(kind: String) -> AudioStreamWAV:
	var sample_rate: int = 11025
	var duration: float = 0.7 if kind == "heavy" else 0.28
	if kind == "engine": duration = 1.0
	var count: int = int(duration * sample_rate)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 505
	var low_noise: float = 0.0
	for index: int in range(count):
		var t: float = float(index) / sample_rate
		low_noise = lerpf(low_noise, rng.randf_range(-1,1), 0.12)
		var tone: float = sin(TAU * (48.0 if kind == "heavy" else 130.0) * t)
		var value: float = (tone * 0.35 + low_noise * 0.9) * exp(-t * (7.0 if kind == "heavy" else 22.0))
		if kind == "engine":
			value = (sin(TAU * 55.0 * t) * 0.12 + sin(TAU * 110.0 * t) * 0.04)
		bytes.encode_s16(index*2, int(clampf(value,-1,1)*24000))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	if kind == "engine":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream
