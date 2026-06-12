extends Node
## 全局音频管理器 — 使用 AudioStreamGenerator 实时合成音效
## 脚步声基于声学物理参数规格设计

const SAMPLE_RATE := 44100

var _footstep_cooldown: float = 0.0
const FOOTSTEP_INTERVAL := 0.55  # 步态周期 500-700ms

# ── 背景音乐 ──
const BGM_PATH := "res://assets/audio/bgm.wav"
const BGM_VOLUME_DB := -10.0  # 背景音乐音量 (dB) — 不遮盖脚步声


func play_footstep() -> void:
	if _footstep_cooldown > 0.0:
		return
	_footstep_cooldown = FOOTSTEP_INTERVAL
	_play_sfx(_gen_footstep, 0.30, 12.0, 1.0)


func play_interact() -> void:
	_play_sfx(_gen_interact, 0.18, 0.0, 1.0)


func play_pickup() -> void:
	_play_sfx(_gen_pickup, 0.14, 1.0, 1.0)


func _play_sfx(gen_callable: Callable, duration: float, vol_db: float, pitch: float) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.volume_db = vol_db
	player.pitch_scale = pitch

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = duration + 0.08
	player.stream = gen

	add_child(player)
	player.play()

	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		player.queue_free()
		return

	var total_frames := int(SAMPLE_RATE * duration)
	var frames := PackedVector2Array()
	frames.resize(total_frames)
	gen_callable.call(frames)

	var pushed := 0
	while pushed < total_frames:
		var avail := pb.get_frames_available()
		if avail <= 0:
			continue
		var to_push := mini(avail, total_frames - pushed)
		pb.push_buffer(frames.slice(pushed, pushed + to_push))
		pushed += to_push

	var timer := get_tree().create_timer(duration + 0.15)
	timer.timeout.connect(func():
		if is_instance_valid(player):
			player.queue_free()
	)


# ═══════════════════════════════════════════════════════════════════
# 脚步声 — 基于声学物理参数规格
# ═══════════════════════════════════════════════════════════════════

func _gen_footstep(data: PackedVector2Array) -> void:
	var total_dur := float(data.size()) / SAMPLE_RATE

	# ── 固定参数 ──
	const BOARD_FREQ := 35.0         # 主共振频率 — 低沉"咚"（人耳最低可感范围）
	const Q := 1.8                   # 带通 Q 值 (低Q=更宽共振，老木头感觉)
	const IMPULSE_WIDTH := 0.008     # 半正弦激励宽度 8ms
	const ATTACK_TIME := 0.004       # 起振 <5ms
	const HEEL_DECAY_END := 0.080    # 主脉冲衰减终点
	const TOE_DELAY := 0.045         # 前掌滞后
	const TAIL_START := 0.095        # 咯吱尾音起点
	const TAIL_END := 0.28           # 尾音终点 (延长至 280ms)
	const HEEL_PEAK := 0.85          # 脚跟峰值 (提高音量)

	for i in data.size():
		var t := float(i) / SAMPLE_RATE

		# ═══ 1. 包络 ═══
		var env: float
		if t < ATTACK_TIME:
			env = t / ATTACK_TIME
		elif t < HEEL_DECAY_END:
			var dt := (t - ATTACK_TIME) / (HEEL_DECAY_END - ATTACK_TIME)
			env = exp(-dt * 2.5)
		elif t < TAIL_START:
			env = exp(-2.5)
		elif t < TAIL_END:
			var dt := (t - TAIL_START) / (TAIL_END - TAIL_START)
			env = exp(-2.5) * exp(-dt * 2.0)
		else:
			env = 0.0

		# ═══ 2. 脚跟撞击：低频"咚" ═══
		var heel_impulse: float = 0.0
		if t < IMPULSE_WIDTH:
			heel_impulse = sin(t / IMPULSE_WIDTH * PI)
		var heel := _bandpass_impulse(heel_impulse, t, BOARD_FREQ, Q) * HEEL_PEAK

		# ═══ 3. 前掌着地：更轻更短的"咚" ═══
		var toe_impulse: float = 0.0
		if t >= TOE_DELAY and t < TOE_DELAY + IMPULSE_WIDTH:
			var tt := (t - TOE_DELAY) / IMPULSE_WIDTH
			toe_impulse = sin(tt * PI) * 0.35
		var toe := _bandpass_impulse(toe_impulse, t, BOARD_FREQ * 1.25, Q * 0.8) * HEEL_PEAK * 0.3

		# ═══ 4. 中频敲击 (极低) ═══
		var click: float = 0.0
		if t < 0.012:
			var click_env := exp(-t * 200.0)
			click = sin(2.0 * PI * 400.0 * t) * 0.03 * click_env

		# ═══ 5. 咯吱尾音 (低沉延长) ═══
		var creak: float = 0.0
		if t >= TAIL_START and t < TAIL_END:
			var ct := (t - TAIL_START) / (TAIL_END - TAIL_START)
			var creak_env := exp(-ct * 3.0)
			var freq := BOARD_FREQ * 0.8
			creak = sin(2.0 * PI * freq * t) * 0.20 * creak_env
			creak += sin(2.0 * PI * freq * 2.0 * t) * 0.06 * creak_env

		# ═══ 6. 混合 ═══
		var s := (heel + toe + click + creak) * env

		# 软削波
		s = maxf(minf(s, 0.88), -0.88)
		data[i] = Vector2(s, s)


func _bandpass_impulse(impulse_val: float, t: float, fc: float, Q: float) -> float:
	if impulse_val <= 0.0001:
		return 0.0
	var omega := 2.0 * PI * fc
	var alpha := omega / (2.0 * Q)
	return impulse_val * exp(-alpha * t) * sin(omega * t)


# ═══════════════════════════════════════════════════════════════════
# 交互音效
# ═══════════════════════════════════════════════════════════════════

func _gen_interact(data: PackedVector2Array) -> void:
	for i in data.size():
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 18.0)
		var s := (sin(2.0 * PI * 1100.0 * t) * 0.4 + sin(2.0 * PI * 1600.0 * t) * 0.3) * env * 0.35
		data[i] = Vector2(s, s)


func _gen_pickup(data: PackedVector2Array) -> void:
	for i in data.size():
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 22.0)
		var freq := lerpf(500.0, 850.0, t / 0.14)
		var s := sin(2.0 * PI * freq * t) * 0.5 * env * 0.7
		data[i] = Vector2(s, s)


# ═══════════════════════════════════════════════════════════════════
# 背景音乐 — AudioStreamGenerator 流式推送（绕开 Godot import）
# ═══════════════════════════════════════════════════════════════════

var _bgm_samples: PackedFloat32Array
var _bgm_player: AudioStreamPlayer
var _bgm_generator: AudioStreamGenerator
var _bgm_playing: bool = false
var _bgm_position: int = 0
var _bgm_sample_rate: int = 44100


func _ready() -> void:
	_load_bgm_samples()


func _load_bgm_samples() -> void:
	var file := FileAccess.open(BGM_PATH, FileAccess.READ)
	if file == null:
		push_warning("AudioManager: 无法打开 BGM 文件 %s" % BGM_PATH)
		return

	# 解析 WAV 头
	file.seek(22); var channels := file.get_16()
	file.seek(24); _bgm_sample_rate = file.get_32()
	file.seek(34); var bits := file.get_16()

	# 找 data chunk
	file.seek(12)
	while file.get_position() < file.get_length() - 8:
		var cid := file.get_buffer(4).get_string_from_ascii()
		var csz := file.get_32()
		if cid == "data":
			var raw := file.get_buffer(csz)
			var count := raw.size() / (bits / 8)
			_bgm_samples.resize(count)
			for i in count:
				var lo := raw[i * 2] as int
				var hi := raw[i * 2 + 1] as int
				if hi >= 128: hi -= 256
				_bgm_samples[i] = float((hi << 8) | lo) / 32768.0
			print("AudioManager: BGM 已加载, %d 采样, %.1f 秒, rate=%d" % [count, float(count) / _bgm_sample_rate, _bgm_sample_rate])
			file.close()
			return
		else:
			file.seek(file.get_position() + csz)
	file.close()
	push_warning("AudioManager: WAV data chunk 未找到")


func play_bgm() -> void:
	if _bgm_samples.is_empty():
		push_warning("AudioManager: play_bgm 失败 — 无采样数据")
		return
	if _bgm_playing:
		return

	_bgm_playing = true
	_bgm_position = 0

	_bgm_generator = AudioStreamGenerator.new()
	_bgm_generator.mix_rate = _bgm_sample_rate
	_bgm_generator.buffer_length = 0.5

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "BGM"
	_bgm_player.volume_db = BGM_VOLUME_DB
	_bgm_player.stream = _bgm_generator
	add_child(_bgm_player)
	_bgm_player.play()

	set_process(true)
	print("AudioManager: BGM 开始播放")


func stop_bgm() -> void:
	_bgm_playing = false
	set_process(false)
	if is_instance_valid(_bgm_player):
		_bgm_player.stop()
		_bgm_player.queue_free()
		_bgm_player = null
		_bgm_generator = null


func _process(delta: float) -> void:
	# 脚步声冷却
	if _footstep_cooldown > 0.0:
		_footstep_cooldown -= delta

	# BGM 音频推送
	if not _bgm_playing or _bgm_player == null:
		return

	var pb := _bgm_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return

	var total := _bgm_samples.size()
	var avail := pb.get_frames_available()
	while avail > 0:
		var batch := mini(avail, 2048)
		var frames := PackedVector2Array()
		frames.resize(batch)
		for j in batch:
			var idx := (_bgm_position + j) % total
			var s := _bgm_samples[idx]
			frames[j] = Vector2(s, s)
		pb.push_buffer(frames)
		_bgm_position = (_bgm_position + batch) % total
		avail -= batch


func set_bgm_volume(volume_db: float) -> void:
	if _bgm_player:
		_bgm_player.volume_db = volume_db
