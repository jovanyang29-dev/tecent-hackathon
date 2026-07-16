extends Node
## 全局音频管理器 — 使用 AudioStreamGenerator 实时合成音效
## 脚步声基于声学物理参数规格设计

const SAMPLE_RATE := 44100

var _footstep_cooldown: float = 0.0
const FOOTSTEP_INTERVAL := 0.55  # 步态周期 500-700ms

# ── 背景音乐 ──
const BGM_PATH := "res://assets/audio/bgm.ogg"
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
# 背景音乐 — AudioStreamOggVorbis 流式播放（Godot 原生 loop）
# ═══════════════════════════════════════════════════════════════════

var _bgm_stream: AudioStreamOggVorbis = null
var _bgm_player: AudioStreamPlayer = null
var _bgm_playing: bool = false


func _ready() -> void:
	var res := load(BGM_PATH)
	if res is AudioStreamOggVorbis:
		_bgm_stream = res as AudioStreamOggVorbis
		_bgm_stream.loop = true
		print("AudioManager: BGM 已加载")
	else:
		push_warning("AudioManager: 无法加载 BGM 文件: %s" % BGM_PATH)


func play_bgm() -> void:
	if _bgm_stream == null:
		push_warning("AudioManager: play_bgm 失败 — BGM 未加载")
		return
	if _bgm_playing:
		return

	_bgm_playing = true
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "BGM"
	_bgm_player.volume_db = BGM_VOLUME_DB
	_bgm_player.stream = _bgm_stream
	add_child(_bgm_player)
	_bgm_player.play()
	print("AudioManager: BGM 开始播放")


func stop_bgm() -> void:
	_bgm_playing = false
	if is_instance_valid(_bgm_player):
		_bgm_player.stop()
		_bgm_player.queue_free()
		_bgm_player = null


func _process(delta: float) -> void:
	# 脚步声冷却
	if _footstep_cooldown > 0.0:
		_footstep_cooldown -= delta

	# 花洒水声推送
	if _shower_playing and _shower_player != null:
		var spb := _shower_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if spb != null:
			var stotal := _shower_samples.size()
			var savail := spb.get_frames_available()
			while savail > 0:
				var sbatch := mini(savail, 2048)
				var sframes := PackedVector2Array()
				sframes.resize(sbatch)
				for j in sbatch:
					var sidx := (_shower_position + j) % stotal
					var ss := _shower_samples[sidx]
					sframes[j] = Vector2(ss, ss)
				spb.push_buffer(sframes)
				_shower_position = (_shower_position + sbatch) % stotal
				savail -= sbatch


func set_bgm_volume(volume_db: float) -> void:
	if _bgm_player:
		_bgm_player.volume_db = volume_db


# ═══════════════════════════════════════════════════════════════════
# 花洒水声 — 循环滤波白噪声
# ═══════════════════════════════════════════════════════════════════

var _shower_samples: PackedFloat32Array
var _shower_player: AudioStreamPlayer
var _shower_generator: AudioStreamGenerator
var _shower_playing: bool = false
var _shower_position: int = 0


func play_shower_water() -> void:
	if _shower_playing:
		return

	# 预生成 2 秒水声（首次调用时）
	if _shower_samples.is_empty():
		_shower_samples = _gen_water_noise(2.0)

	_shower_playing = true
	_shower_position = 0

	_shower_generator = AudioStreamGenerator.new()
	_shower_generator.mix_rate = SAMPLE_RATE
	_shower_generator.buffer_length = 0.3

	_shower_player = AudioStreamPlayer.new()
	_shower_player.bus = "SFX"
	_shower_player.volume_db = -2.0
	_shower_player.stream = _shower_generator
	add_child(_shower_player)
	_shower_player.play()

	print("AudioManager: 花洒水声开始")


func stop_shower_water() -> void:
	if not _shower_playing:
		return
	_shower_playing = false
	if is_instance_valid(_shower_player):
		_shower_player.stop()
		_shower_player.queue_free()
		_shower_player = null
		_shower_generator = null
	print("AudioManager: 花洒水声停止")


func _gen_water_noise(duration: float) -> PackedFloat32Array:
	var total := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(total)

	# 使用累计平均近似低通滤波（模拟水流的低频特性）
	var running := 0.0
	const SMOOTH := 0.985  # 越接近1 → 越低频
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("shower_water")

	for i in total:
		var raw := rng.randf_range(-1.0, 1.0)
		running = running * SMOOTH + raw * (1.0 - SMOOTH)
		# 叠加少量高频成分模拟水花飞溅
		var sparkle := rng.randf_range(-0.15, 0.15)
		samples[i] = clampf(running * 0.8 + sparkle, -1.0, 1.0)

	return samples
