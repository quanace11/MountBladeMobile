class_name FighterSim
extends RefCounted
## Máy trạng thái của một tướng: áp lệnh, di chuyển, xoay mặt, đếm thời gian.
## Không xét trúng; việc đó thuộc CombatResolver.

const S := FighterState.State


static func apply_command(f: FighterState, cmd: FighterCommand, ctx: SimContext, tick: int, events: Array) -> void:
	if not f.is_alive():
		return
	var w := f.def.weapon
	if cmd.dodge and (f.state == S.IDLE or f.state == S.BLOCK or f.state == S.WINDUP):
		if f.stamina >= ctx.rules.dodge_stamina_cost:
			_start_dodge(f, cmd, ctx, events)
			return
		events.append({"type": &"no_stamina", "id": f.id})
	match f.state:
		S.IDLE:
			if cmd.block_dir != Dir.NONE:
				_start_block(f, cmd.block_dir, tick)
			elif cmd.attack_dir != Dir.NONE or (f.buffered_attack_dir != Dir.NONE and tick <= f.buffered_until):
				var buffered := cmd.attack_dir == Dir.NONE
				var d := f.buffered_attack_dir if buffered else cmd.attack_dir
				if f.stamina >= w.attack_stamina_cost:
					_start_windup(f, d, events)
					f.release_queued = cmd.attack_release or buffered
				elif cmd.attack_release or buffered:
					events.append({"type": &"no_stamina", "id": f.id})
				f.buffered_attack_dir = Dir.NONE
		S.RELEASE, S.RECOVERY, S.STAGGER, S.DODGE:
			# Bấm chém sớm khi đang bận: nhớ lệnh để chém ngay khi rảnh. Đang chém, đang thu thì
			# luôn nhớ (chém liên hoàn); đang khựng, đang lăn thì chỉ nhớ khi sắp hết.
			if cmd.attack_release and cmd.attack_dir != Dir.NONE:
				var free_in := _ticks_until_free(f, ctx)
				var chaining := f.state == S.RELEASE or f.state == S.RECOVERY
				if chaining or free_in <= ctx.ticks(ctx.rules.attack_buffer_time):
					f.buffered_attack_dir = cmd.attack_dir
					f.buffered_until = tick + free_in + 2
		S.WINDUP:
			if cmd.block_dir != Dir.NONE and ctx.rules.allow_windup_cancel_to_block:
				_start_block(f, cmd.block_dir, tick)
			elif cmd.attack_release:
				f.release_queued = true
			elif cmd.attack_dir == Dir.NONE and not f.release_queued:
				# Thả tay mà không chém (ví dụ chuyển sang vẽ nét đỡ): hủy gồng.
				f.attack_dir = Dir.NONE
				f.set_state(S.IDLE)
			elif cmd.attack_dir != f.attack_dir and not f.release_queued:
				# Đổi hướng khi đang gồng: gồng lại từ đầu theo hướng mới.
				_start_windup(f, cmd.attack_dir, events)
		S.BLOCK:
			if cmd.block_dir == Dir.NONE:
				f.block_dir = Dir.NONE
				f.set_state(S.IDLE)
			elif cmd.block_dir != f.block_dir:
				f.block_dir = cmd.block_dir
				f.block_started_tick = tick
				events.append({"type": &"block_changed", "id": f.id, "dir": f.block_dir})


static func _start_dodge(f: FighterState, cmd: FighterCommand, ctx: SimContext, events: Array) -> void:
	var d := cmd.move
	f.dodge_dir = d.normalized() if d.length() > 0.2 else -f.forward()
	f.stamina = maxf(0.0, f.stamina - ctx.rules.dodge_stamina_cost)
	f.stamina_wait = ctx.ticks(ctx.rules.stamina_regen_delay)
	f.attack_dir = Dir.NONE
	f.block_dir = Dir.NONE
	f.release_queued = false
	f.buffered_attack_dir = Dir.NONE
	f.set_state(S.DODGE, ctx.ticks(ctx.rules.dodge_time))
	events.append({"type": &"dodge", "id": f.id})


## Số tick còn lại trước khi tướng rảnh tay (về IDLE).
static func _ticks_until_free(f: FighterState, ctx: SimContext) -> int:
	var w := f.def.weapon
	match f.state:
		S.RELEASE:
			return ctx.ticks(w.release_time) - f.state_ticks + ctx.ticks(w.recovery_time)
		S.DODGE:
			return f.state_duration - f.state_ticks + ctx.ticks(ctx.rules.dodge_recovery)
	return maxi(0, f.state_duration - f.state_ticks)


## Đang lăn và còn trong lúc miễn trúng.
static func is_invulnerable(f: FighterState, ctx: SimContext) -> bool:
	return f.state == S.DODGE and f.state_ticks < ctx.ticks(ctx.rules.dodge_iframes)


static func _start_block(f: FighterState, d: int, tick: int) -> void:
	f.attack_dir = Dir.NONE
	f.release_queued = false
	f.block_dir = d
	f.block_started_tick = tick
	f.set_state(S.BLOCK)


static func _start_windup(f: FighterState, d: int, events: Array) -> void:
	f.block_dir = Dir.NONE
	f.attack_dir = d
	f.release_queued = false
	f.set_state(S.WINDUP)
	events.append({"type": &"attack_started", "id": f.id, "dir": d})


## Đếm thời gian trạng thái; chuyển WINDUP -> RELEASE khi đủ thời gian gồng.
static func advance_timers(f: FighterState, ctx: SimContext, events: Array) -> void:
	if not f.is_alive():
		return
	f.state_ticks += 1
	var w := f.def.weapon
	match f.state:
		S.WINDUP:
			if f.release_queued and f.state_ticks >= ctx.ticks(w.windup_time):
				f.stamina = maxf(0.0, f.stamina - w.attack_stamina_cost)
				f.stamina_wait = ctx.ticks(ctx.rules.stamina_regen_delay)
				f.set_state(S.RELEASE)
				events.append({"type": &"attack_released", "id": f.id, "dir": f.attack_dir})
		S.DODGE:
			if f.state_ticks >= f.state_duration:
				f.set_state(S.RECOVERY, ctx.ticks(ctx.rules.dodge_recovery))
		S.RECOVERY, S.STAGGER:
			if f.state_ticks >= f.state_duration:
				f.attack_dir = Dir.NONE
				f.set_state(S.IDLE)
	# Hồi thể lực khi không đánh, không đỡ.
	if f.state == S.IDLE:
		if f.stamina_wait > 0:
			f.stamina_wait -= 1
		else:
			f.stamina = minf(f.def.max_stamina, f.stamina + f.def.stamina_regen * ctx.dt)


## Đòn đang ở pha RELEASE và đã tới lúc chạm chưa.
static func is_impact_tick(f: FighterState, ctx: SimContext) -> bool:
	return f.state == S.RELEASE and f.state_ticks == ctx.ticks(f.def.weapon.release_time)


static func move_and_face(f: FighterState, cmd: FighterCommand, face_target: Vector2, has_target: bool, ctx: SimContext) -> void:
	if not f.is_alive():
		f.velocity = Vector2.ZERO
		return
	if f.state == S.DODGE:
		# Lăn: lao nhanh theo hướng đã chọn rồi chậm dần, không xoay người.
		var t := float(f.state_ticks) / maxf(1.0, f.state_duration)
		var speed := ctx.rules.dodge_distance / ctx.rules.dodge_time / 0.75
		f.velocity = f.dodge_dir * speed * (1.0 - 0.5 * t)
		f.pos += f.velocity * ctx.dt
		return
	var mult := 1.0
	match f.state:
		S.WINDUP, S.RELEASE:
			mult = ctx.rules.move_mult_windup
		S.BLOCK:
			mult = ctx.rules.move_mult_block
		S.STAGGER:
			mult = 0.0
	var mv := cmd.move.limit_length(1.0)
	# Đi lùi, đi ngang chậm hơn đi thẳng; tốc độ thay đổi dần theo gia tốc.
	var dir_mult := 1.0
	if mv.length() > 0.01:
		var fwd_dot := mv.normalized().dot(f.forward())
		dir_mult = lerpf(f.def.strafe_speed_mult, 1.0, fwd_dot) if fwd_dot >= 0.0 else lerpf(f.def.strafe_speed_mult, f.def.backward_speed_mult, -fwd_dot)
	var desired := mv * f.def.move_speed * mult * dir_mult
	var rate := f.def.acceleration if desired.length() >= f.velocity.length() else f.def.deceleration
	f.velocity = f.velocity.move_toward(desired, rate * ctx.dt)
	f.pos += f.velocity * ctx.dt

	# Người chơi tự ngắm thì quay theo hướng lệnh; không thì nhìn địch gần nhất, hoặc hướng đang đi.
	var want := f.yaw
	var turning := false
	if cmd.has_face:
		want = cmd.face_yaw
		turning = true
	else:
		var want_dir := Vector2.ZERO
		if has_target:
			want_dir = face_target - f.pos
		elif mv.length() > 0.1:
			want_dir = mv
		if want_dir.length() > 0.001:
			want = FighterState.yaw_from_direction(want_dir.normalized())
			turning = true
	if turning and f.state != S.STAGGER:
		var turn_mult := ctx.rules.turn_mult_attack if f.state == S.WINDUP or f.state == S.RELEASE else 1.0
		var max_step := deg_to_rad(f.def.turn_speed_deg) * turn_mult * ctx.dt
		var diff := wrapf(want - f.yaw, -PI, PI)
		f.yaw = wrapf(f.yaw + clampf(diff, -max_step, max_step), -PI, PI)
