extends Node2D

# ============================================================
# TIC TAC TOE - PC + MOBILE VERSION
# ============================================================
# FIX 1: AI input bleeding fixed — touch is blocked during AI turn + buffer after
# FIX 2: Music toggle moved to HTML overlay (web only). In-game toggles REMOVED.
# FIX 3: Added "editzz" bonus screen with drawn bolt icons and video support via HTML overlay
# FIX 4: SFX toggle removed — SFX always plays when triggered
# FIX 5: Bonus button same size as others, no footer overlap
# FIX 6: Bonus back button smaller
# FIX 7: Audio unlock hint replaced with sketchy hand-drawn note style

# =====================
# BASE SETTINGS
# =====================
const BASE_SCREEN = Vector2(700, 620)
const MIN_PLAYABLE_SIZE = Vector2(320, 520)

const SYMBOL_X = "X"
const SYMBOL_O = "O"

const AI_DIFFICULTY = "perfect" # "classic" = easier, "perfect" = minimax AI
const AI_THINK_TIME = 0.25

const PIECE_POP_DURATION = 0.18
const SCREEN_FADE_DURATION = 0.18
const RIPPLE_DURATION = 0.32

# =====================
# COLORS
# =====================
const COLOR_BG_TOP = Color(0.30, 0.17, 0.075)
const COLOR_BG_BOTTOM = Color(0.11, 0.065, 0.035)
const COLOR_PANEL = Color(0.18, 0.095, 0.035)
const COLOR_PANEL_SOFT = Color(0.25, 0.145, 0.055)
const COLOR_GOLD = Color(0.98, 0.82, 0.42)
const COLOR_GOLD_SOFT = Color(0.78, 0.58, 0.27)
const COLOR_GOLD_DARK = Color(0.48, 0.30, 0.11)
const COLOR_RED = Color(0.82, 0.16, 0.10)
const COLOR_RED_SOFT = Color(1.00, 0.45, 0.35)
const COLOR_TEXT_MUTED = Color(0.60, 0.43, 0.24)
const COLOR_SHADOW = Color(0.0, 0.0, 0.0, 0.36)
const COLOR_HOVER = Color(1.00, 0.78, 0.28, 0.16)
const COLOR_TOUCH_RIPPLE = Color(1.00, 0.82, 0.42, 0.34)

# =====================
# GAME STATE
# =====================
var board = ["", "", "", "", "", "", "", "", ""]
var current_player = SYMBOL_X
var game_active = true
var result_message = ""
var winning_combo = []

var current_screen = "menu"
var vs_ai = false
var ai_character = ""
var ai_thinking = false
var ai_turn_token = 0

var score_charlie = 0
var score_epstein = 0
var score_draws = 0

var music_on = true
var _js_cb_music = null
var _js_cb_unlock = null
var _js_cb_sfx = null
var sfx_on = true

# =====================
# RESPONSIVE LAYOUT
# =====================
var screen_w = BASE_SCREEN.x
var screen_h = BASE_SCREEN.y
var viewport_size = BASE_SCREEN
var ui_scale = 1.0
var safe_margin = 16.0

var board_rect = Rect2()
var cell_size = 160.0
var status_rect = Rect2()
var score_rect = Rect2()
var menu_title_rect = Rect2()
var menu_banner_rect = Rect2()
var menu_button_rects = {}
var secret_image_rect = Rect2()
var secret_back_rect = Rect2()
var bonus_back_rect = Rect2()

# =====================
# ANIMATION STATE
# =====================
var anim_time = 0.0
var last_move_index = -1
var piece_pop_timers = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var mouse_pos = Vector2(-10000, -10000)
var hovered_cell = -1
var screen_fade_timer = 0.0
var ripple_timer = 0.0
var ripple_pos = Vector2.ZERO
var flash_active = false
var flash_timer = 0.0
var flash_color = Color(1, 0, 0, 0.5)
var confetti_particles = []

# =====================
# INPUT BUFFER FIX
# =====================
var _input_blocked_until = 0.0
const INPUT_BLOCK_BUFFER = 0.15  # seconds after AI finishes to swallow lingering touches

# =====================
# TEXTURES
# =====================
var texture_x: Texture2D
var texture_o: Texture2D
var texture_trump: Texture2D
var texture_banner: Texture2D
var texture_charlie: Texture2D
var texture_epstein: Texture2D

# =====================
# AUDIO
# =====================
var menu_music: AudioStreamPlayer
var secret_music: AudioStreamPlayer
var click_sfx: AudioStreamPlayer
var win_sfx: AudioStreamPlayer
var draw_sfx: AudioStreamPlayer
var audio_unlocked = false

# =====================
# WIN CONDITIONS
# =====================
var win_conditions = [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6]
]

# =====================
# READY
# =====================
func _ready():
	randomize()

	if OS.has_feature("windows") or OS.has_feature("macos") or OS.has_feature("linux"):
		DisplayServer.window_set_min_size(Vector2i(int(MIN_PLAYABLE_SIZE.x), int(MIN_PLAYABLE_SIZE.y)))

	update_layout()

	texture_x = load("res://player1.png")
	texture_o = load("res://player2.png")
	texture_trump = load("res://trump.png")
	texture_banner = load("res://banner.png")
	texture_charlie = load("res://charliesmall.png")
	texture_epstein = load("res://epsteinsmall.png")

	menu_music = create_audio_player("res://menu_music.ogg", true)
	secret_music = create_audio_player("res://secret_music.ogg", true)
	click_sfx = create_audio_player("res://click.ogg", false)
	win_sfx = create_audio_player("res://win.ogg", false)
	draw_sfx = create_audio_player("res://draw.ogg", false)

	audio_unlocked = not OS.has_feature("web")
	play_music(menu_music)
	queue_redraw()

	# Web music toggle bridge (called by HTML button)
	if OS.has_feature("web"):
		var js_win = JavaScriptBridge.get_interface("window")
		if js_win:
			_js_cb_unlock = JavaScriptBridge.create_callback(func(_a): unlock_audio())
			js_win.unlockGodotAudio = _js_cb_unlock
			_js_cb_music = JavaScriptBridge.create_callback(func(_a): unlock_audio(); toggle_music())
			js_win.toggleGodotMusic = _js_cb_music
			_js_cb_sfx = JavaScriptBridge.create_callback(func(_a): toggle_sfx())
			js_win.toggleGodotSFX = _js_cb_sfx
			

# =====================
# PROCESS
# =====================
func _process(delta):
	var needs_redraw = false
	anim_time += delta

	if get_viewport_rect().size != viewport_size:
		update_layout()
		needs_redraw = true

	if screen_fade_timer > 0.0:
		screen_fade_timer = max(0.0, screen_fade_timer - delta)
		needs_redraw = true

	if ripple_timer > 0.0:
		ripple_timer = max(0.0, ripple_timer - delta)
		needs_redraw = true

	if flash_active:
		flash_timer += delta
		var flash_wave = sin(flash_timer * 8.0)
		flash_color = Color(1, 0, 0, 0.58) if flash_wave > 0 else Color(1, 1, 1, 0.54)
		needs_redraw = true

		if flash_timer > 2.0:
			flash_active = false
			flash_timer = 0.0

	for i in range(piece_pop_timers.size()):
		if piece_pop_timers[i] > 0.0:
			piece_pop_timers[i] = max(0.0, piece_pop_timers[i] - delta)
			needs_redraw = true

	if ai_thinking:
		needs_redraw = true

	if not game_active and winning_combo.size() == 3:
		needs_redraw = true

	if update_confetti(delta):
		needs_redraw = true

	# Animate the hint wobble
	if not audio_unlocked and not OS.has_feature("web"):
		needs_redraw = true

	if needs_redraw:
		queue_redraw()

# =====================
# DRAW
# =====================
func _draw():
	if current_screen == "menu":
		draw_menu()
	elif current_screen == "secret":
		draw_secret()
	elif current_screen == "bonus":
		draw_bonus()
	else:
		draw_game()

	draw_ripple()
	draw_screen_fade()
	draw_audio_unlock_hint()

# =====================
# RESPONSIVE LAYOUT
# =====================
func update_layout():
	viewport_size = get_viewport_rect().size

	if viewport_size.x < 1 or viewport_size.y < 1:
		viewport_size = BASE_SCREEN

	screen_w = viewport_size.x
	screen_h = viewport_size.y

	ui_scale = clamp(min(screen_w / BASE_SCREEN.x, screen_h / BASE_SCREEN.y), 0.62, 1.28)
	safe_margin = clamp(min(screen_w, screen_h) * 0.035, 12.0, 26.0)

	update_menu_layout()
	update_game_layout()
	update_secret_layout()
	update_bonus_layout()
	update_hovered_cell()

func update_menu_layout():
	var button_w = min(screen_w - safe_margin * 2.0, 390.0 * ui_scale)
	var button_h = clamp(44.0 * ui_scale, 38.0, 52.0)
	var button_gap = clamp(7.0 * ui_scale, 5.0, 9.0)
	var button_count = 5.0

	var footer_h = clamp(58.0 * ui_scale, 46.0, 70.0)
	var content_top = safe_margin + clamp(6.0 * ui_scale, 6.0, 12.0)
	if screen_w < 500.0:
		content_top += clamp(28.0 * ui_scale, 22.0, 34.0)

	var content_bottom = screen_h - footer_h
	var available_h = max(260.0, content_bottom - content_top)
	var title_h = clamp(78.0 * ui_scale, 60.0, 88.0)
	var buttons_total_h = button_h * button_count + button_gap * (button_count - 1.0)
	var banner_h = available_h - title_h - buttons_total_h - button_gap * 2.4

	# FIX: Clamp banner to prevent overlap, reduce if too many buttons
	banner_h = clamp(banner_h, 60.0 * ui_scale, 180.0 * ui_scale)
	var banner_w = min(screen_w - safe_margin * 2.0, banner_h * 1.70)

	menu_banner_rect = Rect2((screen_w - banner_w) / 2.0, content_top, banner_w, banner_h)

	var title_w = min(screen_w - safe_margin * 2.0, 520.0 * ui_scale)
	var banner_title_gap = clamp(10.0 * ui_scale, 8.0, 14.0)
	menu_title_rect = Rect2((screen_w - title_w) / 2.0, menu_banner_rect.end.y + banner_title_gap, title_w, title_h)

	var button_x = (screen_w - button_w) / 2.0
	var button_y = menu_title_rect.end.y + button_gap * 1.2
	menu_button_rects = {
		"two_player": Rect2(button_x, button_y, button_w, button_h),
		"charlie": Rect2(button_x, button_y + (button_h + button_gap), button_w, button_h),
		"epstein": Rect2(button_x, button_y + (button_h + button_gap) * 2.0, button_w, button_h),
		"secret": Rect2(button_x, button_y + (button_h + button_gap) * 3.0, button_w, button_h),
		"bonus": Rect2(button_x, button_y + (button_h + button_gap) * 4.0, button_w, button_h)
	}

func update_game_layout():
	var status_h = clamp(76.0 * ui_scale, 66.0, 92.0)
	status_rect = Rect2(0, screen_h - status_h, screen_w, status_h)

	var score_h = clamp(43.0 * ui_scale, 36.0, 55.0)
	score_rect = Rect2(safe_margin, safe_margin * 0.75, screen_w - safe_margin * 2.0, score_h)

	var top_limit = score_rect.end.y + safe_margin * 0.65
	var bottom_limit = status_rect.position.y - safe_margin
	var available_w = screen_w - safe_margin * 2.0
	var available_h = bottom_limit - top_limit
	var max_board = min(available_w, available_h)

	var board_size = floor(clamp(max_board, 240.0, 560.0))
	cell_size = board_size / 3.0
	board_rect = Rect2((screen_w - board_size) / 2.0, top_limit + (available_h - board_size) / 2.0, board_size, board_size)

func update_secret_layout():
	var bottom_h = clamp(110.0 * ui_scale, 96.0, 132.0)
	secret_image_rect = Rect2(0, 0, screen_w, screen_h - bottom_h)
	var back_w = min(160.0 * ui_scale, screen_w - safe_margin * 2.0)
	secret_back_rect = Rect2((screen_w - back_w) / 2.0, screen_h - bottom_h + 54.0 * ui_scale, back_w, 36.0 * ui_scale)

func update_bonus_layout():
	# FIX: Smaller back button
	var back_w = min(100.0 * ui_scale, screen_w - safe_margin * 2.0)
	var back_h = 32.0 * ui_scale
	bonus_back_rect = Rect2((screen_w - back_w) / 2.0, screen_h - safe_margin - back_h - 20.0, back_w, back_h)

# =====================
# DRAW HELPERS
# =====================
func draw_premium_background():
	var strip_h = 10
	for y in range(0, int(screen_h) + strip_h, strip_h):
		var t = float(y) / max(1.0, screen_h)
		var color = COLOR_BG_TOP.lerp(COLOR_BG_BOTTOM, t)
		draw_rect(Rect2(0, y, screen_w, strip_h), color)

	for i in range(-int(screen_h), int(screen_w), int(22.0 * ui_scale)):
		draw_line(Vector2(i, 0), Vector2(i + screen_h * 0.65, screen_h), Color(0.0, 0.0, 0.0, 0.13), max(1.0, 1.4 * ui_scale))

	draw_rect(Rect2(0, 0, screen_w, screen_h * 0.18), Color(1, 0.78, 0.35, 0.045))
	draw_rect(Rect2(0, screen_h * 0.78, screen_w, screen_h * 0.22), Color(0, 0, 0, 0.22))

func draw_round_rect(rect: Rect2, color: Color, radius: float):
	var r = min(radius, rect.size.x / 2.0, rect.size.y / 2.0)
	draw_rect(Rect2(rect.position.x + r, rect.position.y, rect.size.x - r * 2.0, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + r, rect.size.x, rect.size.y - r * 2.0), color)
	draw_circle(rect.position + Vector2(r, r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)

func draw_premium_panel(rect: Rect2, fill: Color, border: Color, radius: float, border_width := 2.0, shadow := true):
	if shadow:
		draw_round_rect(Rect2(rect.position + Vector2(0, 5.0 * ui_scale), rect.size), COLOR_SHADOW, radius)

	draw_round_rect(rect, border, radius)
	draw_round_rect(rect.grow(-border_width), fill, max(0.0, radius - border_width))

	var shine = Rect2(rect.position + Vector2(border_width * 2.0, border_width * 2.0), Vector2(rect.size.x - border_width * 4.0, min(rect.size.y * 0.24, 14.0 * ui_scale)))
	draw_round_rect(shine, Color(1, 1, 1, 0.045), max(0.0, radius - border_width * 2.0))

func get_text_size(text: String, font_size: int) -> Vector2:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

func fit_font_size(text: String, preferred_size: int, max_width: float, min_size := 10) -> int:
	var size = max(preferred_size, min_size)
	while size > min_size and get_text_size(text, size).x > max_width:
		size -= 1
	return size

func draw_text_centered(text: String, center_x: float, baseline_y: float, font_size: int, color: Color):
	var size = get_text_size(text, font_size)
	draw_string(ThemeDB.fallback_font, Vector2(center_x - size.x / 2.0, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func draw_texture_contain(texture: Texture2D, rect: Rect2):
	if not texture:
		return

	var tex_size = texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return

	var scale = min(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
	var draw_size = tex_size * scale
	var draw_pos = rect.position + (rect.size - draw_size) / 2.0
	draw_texture_rect(texture, Rect2(draw_pos, draw_size), false)

func draw_texture_cover(texture: Texture2D, rect: Rect2):
	if not texture:
		return

	var tex_size = texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0 or rect.size.x <= 0 or rect.size.y <= 0:
		return

	var target_aspect = rect.size.x / rect.size.y
	var source_aspect = tex_size.x / tex_size.y
	var source_rect = Rect2(Vector2.ZERO, tex_size)

	if source_aspect > target_aspect:
		source_rect.size.x = tex_size.y * target_aspect
		source_rect.position.x = (tex_size.x - source_rect.size.x) / 2.0
	else:
		source_rect.size.y = tex_size.x / target_aspect
		source_rect.position.y = (tex_size.y - source_rect.size.y) / 2.0

	draw_texture_rect_region(texture, rect, source_rect)

func draw_button(rect: Rect2, text: String, preferred_font_size: int, fill: Color, border: Color, text_color: Color, icon: Texture2D = null):
	var hovering = rect.has_point(mouse_pos)
	var radius = clamp(9.0 * ui_scale, 7.0, 12.0)
	var button_fill = fill.lightened(0.08) if hovering else fill
	var button_border = border.lightened(0.15) if hovering else border

	draw_premium_panel(rect, button_fill, button_border, radius, max(2.0, 2.5 * ui_scale), true)

	if hovering:
		draw_round_rect(rect.grow(-3.0 * ui_scale), COLOR_HOVER, radius)

	var icon_size = min(rect.size.y - 14.0 * ui_scale, 40.0 * ui_scale)
	if icon:
		draw_texture_rect(icon, Rect2(rect.position.x + 10.0 * ui_scale, rect.position.y + (rect.size.y - icon_size) / 2.0, icon_size, icon_size), false)

	var font_size = fit_font_size(text, preferred_font_size, rect.size.x - 26.0 * ui_scale, 12)
	var baseline_y = rect.position.y + rect.size.y / 2.0 + font_size * 0.36
	draw_text_centered(text, rect.get_center().x, baseline_y, font_size, text_color)

func draw_lightning_bolt(center: Vector2, size: float, color: Color):
	var points = PackedVector2Array([
		center + Vector2(-0.10 * size, -0.50 * size),
		center + Vector2(0.34 * size, -0.50 * size),
		center + Vector2(0.07 * size, -0.06 * size),
		center + Vector2(0.36 * size, -0.06 * size),
		center + Vector2(-0.24 * size, 0.52 * size),
		center + Vector2(-0.03 * size, 0.10 * size),
		center + Vector2(-0.34 * size, 0.10 * size)
	])
	draw_colored_polygon(points, color)

func draw_bonus_menu_button(rect: Rect2):
	var label = "editzz"
	var bolt_size = clamp(20.0 * ui_scale, 15.0, 26.0)
	var gap = 8.0 * ui_scale
	var bolt_gap = 3.0 * ui_scale
	var max_text_w = rect.size.x - 34.0 * ui_scale - bolt_size * 1.55 - gap - bolt_gap
	var font_size = fit_font_size(label, int(19.0 * ui_scale), max_text_w, 12)
	var text_size = get_text_size(label, font_size)
	var total_w = text_size.x + gap + bolt_size * 1.42 + bolt_gap
	var start_x = rect.get_center().x - total_w / 2.0
	var baseline_y = rect.position.y + rect.size.y / 2.0 + font_size * 0.36
	var bolt_y = rect.position.y + rect.size.y / 2.0
	var bolt_x = start_x + text_size.x + gap + bolt_size * 0.34

	draw_button(rect, "", int(19.0 * ui_scale), Color(0.05, 0.05, 0.05), Color.WHITE, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(start_x, baseline_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_lightning_bolt(Vector2(bolt_x, bolt_y), bolt_size, COLOR_GOLD)
	draw_lightning_bolt(Vector2(bolt_x + bolt_size * 0.62 + bolt_gap, bolt_y), bolt_size, COLOR_GOLD)

# =====================
# MENU SCREEN
# =====================
func draw_menu():
	draw_premium_background()

	if texture_banner:
		draw_texture_contain(texture_banner, menu_banner_rect)

	draw_premium_panel(menu_title_rect, COLOR_PANEL, COLOR_GOLD_DARK, 10.0 * ui_scale, 3.0 * ui_scale, true)

	var title_size = fit_font_size("TIC  TAC  TOE", int(40.0 * ui_scale), menu_title_rect.size.x - 24.0 * ui_scale, 24)
	draw_text_centered("TIC  TAC  TOE", screen_w / 2.0, menu_title_rect.position.y + menu_title_rect.size.y * 0.50, title_size, COLOR_GOLD)

	var subtitle_size = fit_font_size("Classic Board Game", int(17.0 * ui_scale), menu_title_rect.size.x - 24.0 * ui_scale, 12)
	draw_text_centered("Classic Board Game", screen_w / 2.0, menu_title_rect.position.y + menu_title_rect.size.y * 0.78, subtitle_size, COLOR_GOLD_SOFT)

	draw_button(menu_button_rects["two_player"], "2 Player Mode", int(22.0 * ui_scale), COLOR_PANEL, COLOR_GOLD_DARK, COLOR_GOLD)
	draw_button(menu_button_rects["charlie"], "   vs Charlie Kirk (AI)", int(22.0 * ui_scale), COLOR_PANEL, COLOR_GOLD_DARK, COLOR_GOLD, texture_charlie)
	draw_button(menu_button_rects["epstein"], "   vs Jeffrey Epstein (AI)", int(22.0 * ui_scale), COLOR_PANEL, COLOR_GOLD_DARK, COLOR_GOLD, texture_epstein)
	draw_button(menu_button_rects["secret"], "Click Here For Feet Pics", int(19.0 * ui_scale), Color(0.18, 0.035, 0.035), COLOR_RED, COLOR_RED_SOFT)
	draw_bonus_menu_button(menu_button_rects["bonus"])

	var footer1 = "Mehad aftab alam"
	var footer2 = "ig-: mehad.1"
	draw_text_centered(footer1, screen_w / 2.0, screen_h - safe_margin - 24.0 * ui_scale, fit_font_size(footer1, int(16.0 * ui_scale), screen_w - safe_margin * 2.0, 11), Color(0.60, 0.40, 0.25))
	draw_text_centered(footer2, screen_w / 2.0, screen_h - safe_margin - 4.0 * ui_scale, fit_font_size(footer2, int(14.0 * ui_scale), screen_w - safe_margin * 2.0, 10), Color(0.55, 0.36, 0.20))

# =====================
# SECRET SCREEN
# =====================
func draw_secret():
	draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0))

	if texture_trump:
		draw_texture_cover(texture_trump, secret_image_rect)

	if flash_active:
		draw_rect(Rect2(0, 0, screen_w, screen_h), flash_color)

	var bottom_rect = Rect2(0, secret_image_rect.end.y, screen_w, screen_h - secret_image_rect.size.y)
	draw_rect(bottom_rect, Color(0.52, 0.0, 0.0))
	draw_rect(Rect2(bottom_rect.position, Vector2(bottom_rect.size.x, 8.0 * ui_scale)), Color(1, 0.25, 0.2, 0.35))

	var caught_text = "CAUGHT YOU RED HANDED!"
	var caught_size = fit_font_size(caught_text, int(28.0 * ui_scale), screen_w - safe_margin * 2.0, 18)
	draw_text_centered(caught_text, screen_w / 2.0, bottom_rect.position.y + 34.0 * ui_scale, caught_size, Color(1, 1, 1))

	draw_button(secret_back_rect, "BACK", int(16.0 * ui_scale), Color(0.30, 0.05, 0.05), Color(0.90, 0.30, 0.20), Color(1, 0.82, 0.70))
	draw_string(ThemeDB.fallback_font, Vector2(safe_margin, screen_h - safe_margin * 0.55), "M = Go Back", HORIZONTAL_ALIGNMENT_LEFT, -1, fit_font_size("M = Go Back", int(14.0 * ui_scale), 140.0 * ui_scale, 10), Color(1, 0.60, 0.60))

# =====================
# BONUS SCREEN
# =====================
func draw_bonus():
	draw_rect(Rect2(0, 0, screen_w, screen_h), Color.BLACK)

	var title = "LOADING VIDEO..."
	var title_size = fit_font_size(title, int(32.0 * ui_scale), screen_w - safe_margin * 2.0, 18)
	draw_text_centered(title, screen_w / 2.0, screen_h / 2.0, title_size, Color.WHITE)

	draw_button(bonus_back_rect, "BACK", int(16.0 * ui_scale), Color(0.1, 0.1, 0.1), Color.WHITE, Color.WHITE)

# =====================
# GAME SCREEN
# =====================
func draw_game():
	draw_premium_background()
	draw_score_header()
	draw_board()
	draw_status_bar()
	draw_confetti()

func draw_score_header():
	var score_text = "Charlie %d   |   Draws %d   |   Epstein %d" % [score_charlie, score_draws, score_epstein]
	draw_premium_panel(score_rect, Color(0.12, 0.07, 0.035, 0.92), Color(0.40, 0.25, 0.10, 0.85), 10.0 * ui_scale, 2.0 * ui_scale, true)
	draw_text_centered(score_text, score_rect.get_center().x, score_rect.position.y + score_rect.size.y * 0.64, fit_font_size(score_text, int(16.0 * ui_scale), score_rect.size.x - 18.0 * ui_scale, 10), Color(0.84, 0.64, 0.32))

func draw_board():
	var outer_rect = board_rect.grow(12.0 * ui_scale)
	draw_premium_panel(outer_rect, COLOR_PANEL_SOFT, COLOR_GOLD_DARK, 14.0 * ui_scale, 4.0 * ui_scale, true)
	draw_round_rect(board_rect, Color(0.13, 0.075, 0.035), 6.0 * ui_scale)

	for i in range(9):
		draw_cell_background(i)

	draw_grid_lines()

	for i in range(9):
		draw_cell_piece(i)

func draw_cell_background(index: int):
	var rect = get_cell_rect(index).grow(-5.0 * ui_scale)

	if index == hovered_cell and board[index] == "" and game_active and not ai_thinking:
		draw_round_rect(rect, COLOR_HOVER, 8.0 * ui_scale)

	if index == last_move_index and board[index] != "":
		draw_round_rect(rect, Color(1.0, 0.78, 0.28, 0.09), 8.0 * ui_scale)

	if winning_combo.has(index):
		var pulse = 0.5 + 0.5 * sin(anim_time * 8.0)
		draw_round_rect(rect, Color(1.0, 0.48 + pulse * 0.20, 0.08, 0.12 + pulse * 0.08), 8.0 * ui_scale)

func draw_grid_lines():
	var line_color = COLOR_GOLD_DARK
	var thickness = max(5.0, 8.0 * ui_scale)
	var x1 = board_rect.position.x + cell_size
	var x2 = board_rect.position.x + cell_size * 2.0
	var y1 = board_rect.position.y + cell_size
	var y2 = board_rect.position.y + cell_size * 2.0

	draw_line(Vector2(x1, board_rect.position.y), Vector2(x1, board_rect.end.y), line_color, thickness)
	draw_line(Vector2(x2, board_rect.position.y), Vector2(x2, board_rect.end.y), line_color, thickness)
	draw_line(Vector2(board_rect.position.x, y1), Vector2(board_rect.end.x, y1), line_color, thickness)
	draw_line(Vector2(board_rect.position.x, y2), Vector2(board_rect.end.x, y2), line_color, thickness)

func draw_cell_piece(index: int):
	var symbol = board[index]
	if symbol == "":
		return

	var rect = get_cell_rect(index)
	var center = rect.get_center()
	var pop_amount = piece_pop_timers[index] / PIECE_POP_DURATION
	var base_size = cell_size * 0.72
	var img_size = base_size * (1.0 + pop_amount * 0.18)
	var piece_rect = Rect2(center.x - img_size / 2.0, center.y - img_size / 2.0, img_size, img_size)

	if symbol == SYMBOL_X and texture_x:
		draw_texture_rect(texture_x, piece_rect, false)
	elif symbol == SYMBOL_O and texture_o:
		draw_texture_rect(texture_o, piece_rect, false)

	if index == last_move_index:
		draw_circle(center, img_size * 0.54, Color(1, 0.80, 0.30, 0.18), false, max(2.0, 3.0 * ui_scale))

func draw_status_bar():
	draw_premium_panel(status_rect.grow(1.0), Color(0.12, 0.065, 0.030), Color(0.45, 0.28, 0.10), 0.0, 2.0, false)

	var mode_text = "2 PLAYER"
	if vs_ai and ai_character == "charlie":
		mode_text = "VS CHARLIE"
	elif vs_ai and ai_character == "epstein":
		mode_text = "VS EPSTEIN"

	var icon_size = clamp(38.0 * ui_scale, 34.0, 46.0)
	var menu_center = Vector2(screen_w - safe_margin - icon_size / 2.0, status_rect.position.y + status_rect.size.y / 2.0)
	var restart_center = menu_center - Vector2(icon_size + 12.0 * ui_scale, 0)
	var compact_status = screen_w < 430.0

	draw_string(ThemeDB.fallback_font, Vector2(safe_margin, status_rect.position.y + status_rect.size.y * 0.36), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_font_size(mode_text, int(14.0 * ui_scale), 130.0 * ui_scale, 9), COLOR_TEXT_MUTED)

	if not compact_status:
		draw_string(ThemeDB.fallback_font, Vector2(safe_margin, status_rect.position.y + status_rect.size.y * 0.72), "R = Restart  |  M = Menu", HORIZONTAL_ALIGNMENT_LEFT, -1, fit_font_size("R = Restart  |  M = Menu", int(12.0 * ui_scale), 170.0 * ui_scale, 8), Color(0.46, 0.29, 0.15))

	var center_text = get_status_text()
	var show_charlie_pic = center_text.contains("Charlie")
	var show_epstein_pic = center_text.contains("Epstein")
	var center_font = int(22.0 * ui_scale) if game_active else int(28.0 * ui_scale)

	var left_limit = safe_margin if compact_status else safe_margin + max(138.0 * ui_scale, 112.0)
	var right_limit = restart_center.x - icon_size / 2.0 - 12.0 * ui_scale
	var center_area = Rect2(left_limit, status_rect.position.y, max(90.0, right_limit - left_limit), status_rect.size.y)

	var pic_size = clamp(32.0 * ui_scale, 28.0, 38.0)
	var max_text_w = center_area.size.x - pic_size - 12.0 * ui_scale
	if not show_charlie_pic and not show_epstein_pic:
		max_text_w = center_area.size.x

	var text_size_font = fit_font_size(center_text, center_font, max_text_w, 12)
	var text_size = get_text_size(center_text, text_size_font)
	var total_w = text_size.x + (pic_size + 10.0 * ui_scale if show_charlie_pic or show_epstein_pic else 0.0)
	var text_x = center_area.position.x + (center_area.size.x - total_w) / 2.0
	var baseline_y = status_rect.position.y + status_rect.size.y * 0.58
	draw_string(ThemeDB.fallback_font, Vector2(text_x, baseline_y), center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size_font, COLOR_GOLD)

	var pic_x = text_x + text_size.x + 10.0 * ui_scale
	var pic_y = status_rect.position.y + (status_rect.size.y - pic_size) / 2.0
	if show_charlie_pic and texture_charlie:
		draw_texture_rect(texture_charlie, Rect2(pic_x, pic_y, pic_size, pic_size), false)
	elif show_epstein_pic and texture_epstein:
		draw_texture_rect(texture_epstein, Rect2(pic_x, pic_y, pic_size, pic_size), false)

	draw_restart_icon(restart_center, icon_size)
	draw_menu_icon(menu_center, icon_size)

func get_status_text() -> String:
	if not game_active:
		return result_message

	if vs_ai and ai_thinking:
		var dots = ""
		for i in range((int(anim_time * 4.0) % 3) + 1):
			dots += "."
		if ai_character == "charlie":
			return "Charlie is thinking" + dots
		return "Epstein is thinking" + dots

	return "Charlie's Turn" if current_player == SYMBOL_X else "Epstein's Turn"

func draw_icon_button_base(center: Vector2, size: float) -> bool:
	var radius = size / 2.0
	var hovering = center.distance_to(mouse_pos) <= radius + 8.0 * ui_scale
	var fill = COLOR_PANEL_SOFT.lightened(0.08) if hovering else COLOR_PANEL_SOFT
	var border = COLOR_GOLD_DARK.lightened(0.15) if hovering else COLOR_GOLD_DARK

	draw_circle(center + Vector2(0, 4.0 * ui_scale), radius, COLOR_SHADOW)
	draw_circle(center, radius, fill)
	draw_circle(center, radius, border, false, max(2.0, 2.4 * ui_scale))
	return hovering

func draw_restart_icon(center: Vector2, size: float):
	draw_icon_button_base(center, size)
	var radius = size * 0.24
	var width = max(2.0, 2.6 * ui_scale)

	draw_arc(center, radius, deg_to_rad(35), deg_to_rad(315), 28, COLOR_GOLD, width)
	var arrow_tip = center + Vector2(cos(deg_to_rad(35)), sin(deg_to_rad(35))) * radius
	draw_line(arrow_tip, arrow_tip + Vector2(-7.0, -1.0) * ui_scale, COLOR_GOLD, width)
	draw_line(arrow_tip, arrow_tip + Vector2(1.0, 7.0) * ui_scale, COLOR_GOLD, width)

func draw_menu_icon(center: Vector2, size: float):
	draw_icon_button_base(center, size)
	var width = max(2.0, 2.6 * ui_scale)
	var half = size * 0.18
	var gap = size * 0.12

	for y in [-gap, 0.0, gap]:
		draw_line(center + Vector2(-half, y), center + Vector2(half, y), COLOR_GOLD, width)

func draw_ripple():
	if ripple_timer <= 0.0:
		return

	var progress = 1.0 - ripple_timer / RIPPLE_DURATION
	var radius = lerp(10.0 * ui_scale, 58.0 * ui_scale, progress)
	var color = COLOR_TOUCH_RIPPLE
	color.a *= 1.0 - progress
	draw_circle(ripple_pos, radius, color, false, max(2.0, 3.0 * ui_scale))

func start_touch_ripple(pos: Vector2):
	ripple_pos = pos
	ripple_timer = RIPPLE_DURATION
	queue_redraw()

func clear_touch_ripple():
	ripple_timer = 0.0
	queue_redraw()

func draw_screen_fade():
	if screen_fade_timer <= 0.0:
		return

	var alpha = screen_fade_timer / SCREEN_FADE_DURATION
	draw_rect(Rect2(0, 0, screen_w, screen_h), Color(0, 0, 0, alpha * 0.22))

# =====================
# AUDIO UNLOCK HINT
# Sketchy hand-drawn note style, bottom-left, no banner overlap
# =====================
func draw_audio_unlock_hint():
	# Web uses HTML overlay toggle — no in-game hint needed
	if OS.has_feature("web"):
		return
	if audio_unlocked:
		return

	# Gentle pulse using sine wave
	var pulse = 0.5 + 0.5 * sin(anim_time * 2.8)
	var base_alpha = lerp(0.72, 1.0, pulse)

	# ---- Layout: bottom-left, small, won't overlap banner ----
	var note_w = clamp(188.0 * ui_scale, 150.0, 230.0)
	var note_h = clamp(62.0 * ui_scale, 52.0, 76.0)
	var note_x = safe_margin
	var note_y = screen_h - safe_margin - note_h - 6.0 * ui_scale
	var note_rect = Rect2(note_x, note_y, note_w, note_h)

	# ---- Torn paper / sticky note background ----
	# Slightly off-white warm tint like a real note
	var paper_color = Color(0.97, 0.94, 0.82, base_alpha * 0.93)
	var paper_shadow = Color(0.0, 0.0, 0.0, 0.28 * base_alpha)

	# Drop shadow (offset, blurred look via multiple rects)
	draw_round_rect(Rect2(note_rect.position + Vector2(3.0, 4.5) * ui_scale, note_rect.size), paper_shadow, 5.0 * ui_scale)
	draw_round_rect(Rect2(note_rect.position + Vector2(2.0, 3.0) * ui_scale, note_rect.size), Color(0, 0, 0, 0.14 * base_alpha), 5.0 * ui_scale)

	# Paper fill
	draw_round_rect(note_rect, paper_color, 5.0 * ui_scale)

	# Ruled line(s) — like lined notebook paper
	var line_y1 = note_y + note_h * 0.52
	var line_y2 = note_y + note_h * 0.78
	var line_color = Color(0.55, 0.70, 0.85, 0.35 * base_alpha)
	draw_line(Vector2(note_x + 10.0 * ui_scale, line_y1), Vector2(note_x + note_w - 10.0 * ui_scale, line_y1), line_color, max(1.0, 1.2 * ui_scale))
	draw_line(Vector2(note_x + 10.0 * ui_scale, line_y2), Vector2(note_x + note_w - 10.0 * ui_scale, line_y2), line_color, max(1.0, 1.2 * ui_scale))

	# Red margin line on left (like a real notebook)
	var margin_x = note_x + 22.0 * ui_scale
	draw_line(Vector2(margin_x, note_y + 6.0 * ui_scale), Vector2(margin_x, note_y + note_h - 6.0 * ui_scale), Color(0.88, 0.35, 0.35, 0.40 * base_alpha), max(1.0, 1.3 * ui_scale))

	# ---- Sketchy arrow drawn in "pen" strokes (bottom-left corner of note) ----
	# Arrow pointing toward the note from slightly outside
	var arrow_ink = Color(0.18, 0.12, 0.06, base_alpha * 0.88)
	var stroke_w = max(1.5, 2.0 * ui_scale)

	# Curved arrow tail going left → points right into note
	# We fake a curve with a few angled line segments
	var ax = note_x - 18.0 * ui_scale
	var ay = note_y + note_h * 0.5
	# Rough curved stroke
	draw_line(Vector2(ax, ay), Vector2(ax + 8.0 * ui_scale, ay - 5.0 * ui_scale), arrow_ink, stroke_w)
	draw_line(Vector2(ax + 8.0 * ui_scale, ay - 5.0 * ui_scale), Vector2(ax + 14.0 * ui_scale, ay + 2.0 * ui_scale), arrow_ink, stroke_w)
	draw_line(Vector2(ax + 14.0 * ui_scale, ay + 2.0 * ui_scale), Vector2(note_x - 1.0 * ui_scale, ay), arrow_ink, stroke_w)
	# Arrowhead
	draw_line(Vector2(note_x - 1.0 * ui_scale, ay), Vector2(note_x + 8.0 * ui_scale, ay - 5.0 * ui_scale), arrow_ink, stroke_w)
	draw_line(Vector2(note_x - 1.0 * ui_scale, ay), Vector2(note_x + 6.0 * ui_scale, ay + 6.0 * ui_scale), arrow_ink, stroke_w)

	# ---- Handwritten-style text ----
	# Line 1: "tap here / anywhere"  (slightly smaller, pen-ink dark)
	var ink = Color(0.12, 0.08, 0.04, base_alpha * 0.92)
	var font1 = fit_font_size("tap here / anywhere", int(11.0 * ui_scale), note_w - 32.0 * ui_scale, 8)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(margin_x + 5.0 * ui_scale, note_y + note_h * 0.40),
		"tap here / anywhere",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font1, ink
	)

	# Line 2: "to enable sound" (slightly larger, more emphasis)
	var font2 = fit_font_size("to enable sound", int(12.0 * ui_scale), note_w - 32.0 * ui_scale, 8)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(margin_x + 5.0 * ui_scale, note_y + note_h * 0.68),
		"to enable sound",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font2, ink
	)

	# Tiny music note doodle to the right of line 2 (simple ♪ as text)
	var note_char_size = fit_font_size("♪", int(14.0 * ui_scale), 20.0 * ui_scale, 9)
	var note_char_color = Color(0.20, 0.14, 0.06, base_alpha * 0.70)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(note_x + note_w - 22.0 * ui_scale, note_y + note_h * 0.72),
		"♪",
		HORIZONTAL_ALIGNMENT_LEFT, -1, note_char_size, note_char_color
	)

	# Small scribble underline under "to enable sound" for emphasis
	var ul_y = note_y + note_h * 0.76
	var ul_x1 = margin_x + 5.0 * ui_scale
	var ul_x2 = ul_x1 + get_text_size("to enable sound", font2).x + 2.0 * ui_scale
	draw_line(Vector2(ul_x1, ul_y), Vector2(ul_x2, ul_y), Color(0.18, 0.12, 0.06, 0.45 * base_alpha), max(1.0, 1.3 * ui_scale))
	# Slightly wobbly second underline for rough look
	draw_line(Vector2(ul_x1 + 2.0 * ui_scale, ul_y + 1.8 * ui_scale), Vector2(ul_x2 - 3.0 * ui_scale, ul_y + 1.4 * ui_scale), Color(0.18, 0.12, 0.06, 0.22 * base_alpha), max(1.0, 1.0 * ui_scale))

# =====================
# INPUT
# =====================
func _input(event):
	if event is InputEventMouseMotion:
		mouse_pos = event.position
		update_hovered_cell()
		queue_redraw()
		return

	if event is InputEventScreenDrag:
		mouse_pos = event.position
		update_hovered_cell()
		queue_redraw()
		return

	# --- CRITICAL FIX: Block ALL press events during AI turn + transition buffer ---
	var now = Time.get_ticks_msec() / 1000.0
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		if now < _input_blocked_until:
			clear_touch_ripple()
			return
		if current_screen == "game" and ai_thinking:
			clear_touch_ripple()
			return

	# Mouse click (PC + editor)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_press(event.position)
		return

	# Touch (mobile + web)
	if event is InputEventScreenTouch and event.pressed:
		mouse_pos = event.position
		handle_press(event.position)
		return

	# Keyboard
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and current_screen == "game":
			restart_game(false)
		elif event.keycode == KEY_M:
			go_to_menu()
		return


func handle_press(pos: Vector2):
	unlock_audio()
	start_touch_ripple(pos)

	if current_screen == "menu":
		handle_menu_press(pos)
	elif current_screen == "secret":
		handle_secret_press(pos)
	elif current_screen == "bonus":
		handle_bonus_press(pos)
	else:
		handle_game_press(pos)

# =====================
# MENU INPUT
# =====================
func handle_menu_press(pos: Vector2):
	if menu_button_rects["two_player"].has_point(pos):
		vs_ai = false
		ai_character = ""
		play_click()
		pulse_haptic(20)
		start_game()
	elif menu_button_rects["charlie"].has_point(pos):
		vs_ai = true
		ai_character = "charlie"
		play_click()
		pulse_haptic(20)
		start_game()
	elif menu_button_rects["epstein"].has_point(pos):
		vs_ai = true
		ai_character = "epstein"
		play_click()
		pulse_haptic(20)
		start_game()
	elif menu_button_rects["secret"].has_point(pos):
		play_click()
		pulse_haptic(30)
		change_screen("secret")
		stop_music(menu_music)
		play_music(secret_music)
		flash_active = true
		flash_timer = 0.0
	elif menu_button_rects["bonus"].has_point(pos):
		play_click()
		pulse_haptic(30)
		stop_music(menu_music)
		change_screen("bonus")
		if OS.has_feature("web"):
			JavaScriptBridge.eval('window.playBonusVideo("bonus-video.mp4")')
		return

# =====================
# SECRET INPUT
# =====================
func handle_secret_press(pos: Vector2):
	if secret_back_rect.has_point(pos):
		play_click()
		pulse_haptic(18)
		go_to_menu()

# =====================
# BONUS INPUT
# =====================
func handle_bonus_press(pos: Vector2):
	if bonus_back_rect.has_point(pos):
		play_click()
		pulse_haptic(18)
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.stopBonusVideo()")
		go_to_menu()

# =====================
# GAME INPUT
# =====================
func handle_game_press(pos: Vector2):
	# --- Extra guard: bail if AI just finished and buffer is active ---
	var now = Time.get_ticks_msec() / 1000.0
	if now < _input_blocked_until:
		clear_touch_ripple()
		return

	var restart_center = get_restart_icon_center()
	var menu_center = get_menu_icon_center()
	var hit_radius = clamp(30.0 * ui_scale, 26.0, 38.0)

	if pos.distance_to(restart_center) <= hit_radius:
		play_click()
		pulse_haptic(18)
		restart_game(false)
		return

	if pos.distance_to(menu_center) <= hit_radius:
		play_click()
		pulse_haptic(18)
		go_to_menu()
		return

	if not game_active or ai_thinking:
		clear_touch_ripple()
		return

	var cell = get_cell_index_at_position(pos)
	if cell == -1:
		return

	if board[cell] != "":
		pulse_haptic(8)
		return

	play_click()
	pulse_haptic(18)
	place_mark(cell, current_player)

	if check_winner():
		return

	if vs_ai and game_active:
		ai_move()

	queue_redraw()

# =====================
# AI LOGIC
# =====================
func ai_move():
	if ai_thinking:
		return

	ai_thinking = true
	clear_touch_ripple()
	ai_turn_token += 1
	var my_token = ai_turn_token
	queue_redraw()

	await get_tree().create_timer(AI_THINK_TIME).timeout

	if my_token != ai_turn_token:
		ai_thinking = false
		return

	if current_screen != "game" or not game_active or not vs_ai:
		ai_thinking = false
		_input_blocked_until = Time.get_ticks_msec() / 1000.0 + INPUT_BLOCK_BUFFER
		queue_redraw()
		return

	var ai_symbol = get_ai_symbol()
	if current_player != ai_symbol:
		ai_thinking = false
		_input_blocked_until = Time.get_ticks_msec() / 1000.0 + INPUT_BLOCK_BUFFER
		queue_redraw()
		return

	var move = find_best_move()
	if move >= 0 and board[move] == "":
		place_mark(move, ai_symbol)
		play_click()
		check_winner()

	ai_thinking = false
	_input_blocked_until = Time.get_ticks_msec() / 1000.0 + INPUT_BLOCK_BUFFER
	queue_redraw()

func find_best_move() -> int:
	if AI_DIFFICULTY == "classic":
		return find_classic_ai_move()

	return find_perfect_ai_move()

func find_classic_ai_move() -> int:
	var ai_symbol = get_ai_symbol()
	var human_symbol = get_human_symbol()

	for i in range(9):
		if board[i] == "":
			board[i] = ai_symbol
			if check_winner_silent(ai_symbol):
				board[i] = ""
				return i
			board[i] = ""

	for i in range(9):
		if board[i] == "":
			board[i] = human_symbol
			if check_winner_silent(human_symbol):
				board[i] = ""
				return i
			board[i] = ""

	if board[4] == "":
		return 4

	var corners = [0, 2, 6, 8]
	var empty_corners = []
	for c in corners:
		if board[c] == "":
			empty_corners.append(c)

	if empty_corners.size() > 0:
		return empty_corners[randi() % empty_corners.size()]

	return get_random_empty_cell()

func find_perfect_ai_move() -> int:
	var ai_symbol = get_ai_symbol()
	var human_symbol = get_human_symbol()
	var best_score = -999
	var best_moves = []

	for i in range(9):
		if board[i] == "":
			board[i] = ai_symbol
			var score = minimax(false, ai_symbol, human_symbol, 0)
			board[i] = ""

			if score > best_score:
				best_score = score
				best_moves = [i]
			elif score == best_score:
				best_moves.append(i)

	if best_moves.size() == 0:
		return -1

	return best_moves[randi() % best_moves.size()]

func minimax(is_ai_turn: bool, ai_symbol: String, human_symbol: String, depth: int) -> int:
	var winner = get_winner_symbol()
	if winner == ai_symbol:
		return 10 - depth
	if winner == human_symbol:
		return depth - 10
	if is_board_full():
		return 0

	if is_ai_turn:
		var best_score = -999
		for i in range(9):
			if board[i] == "":
				board[i] = ai_symbol
				best_score = max(best_score, minimax(false, ai_symbol, human_symbol, depth + 1))
				board[i] = ""
		return best_score

	var worst_score = 999
	for i in range(9):
		if board[i] == "":
			board[i] = human_symbol
			worst_score = min(worst_score, minimax(true, ai_symbol, human_symbol, depth + 1))
			board[i] = ""
	return worst_score

func check_winner_silent(symbol: String) -> bool:
	for condition in win_conditions:
		if board[condition[0]] == symbol and board[condition[1]] == symbol and board[condition[2]] == symbol:
			return true
	return false

# =====================
# WIN CHECK
# =====================
func check_winner() -> bool:
	for condition in win_conditions:
		var a = condition[0]
		var b = condition[1]
		var c = condition[2]

		if board[a] != "" and board[a] == board[b] and board[b] == board[c]:
			game_active = false
			winning_combo = condition

			if board[a] == SYMBOL_X:
				result_message = "Charlie Wins!"
				score_charlie += 1
			else:
				result_message = "Epstein Wins!"
				score_epstein += 1

			play_win()
			spawn_confetti()
			queue_redraw()
			return true

	if is_board_full():
		game_active = false
		result_message = "It's a Draw!"
		score_draws += 1
		play_draw()
		queue_redraw()
		return true

	current_player = SYMBOL_O if current_player == SYMBOL_X else SYMBOL_X
	return false

func get_winner_symbol() -> String:
	for condition in win_conditions:
		var a = condition[0]
		var b = condition[1]
		var c = condition[2]

		if board[a] != "" and board[a] == board[b] and board[b] == board[c]:
			return board[a]

	return ""

func is_board_full() -> bool:
	for cell in board:
		if cell == "":
			return false
	return true

# =====================
# GAME FLOW
# =====================
func change_screen(screen_name: String):
	current_screen = screen_name
	screen_fade_timer = SCREEN_FADE_DURATION
	update_layout()
	queue_redraw()
	if OS.has_feature("web"):
		JavaScriptBridge.eval('window.setGodotScreen("' + screen_name + '")')

func start_game():
	stop_music(menu_music)
	stop_music(secret_music)
	clear_touch_ripple()
	_input_blocked_until = Time.get_ticks_msec() / 1000.0 + 0.35
	change_screen("game")
	restart_game(false)

func restart_game(stop_click_sound := true):
	ai_turn_token += 1
	clear_touch_ripple()

	board = ["", "", "", "", "", "", "", "", ""]
	piece_pop_timers = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	current_player = SYMBOL_X
	game_active = true
	result_message = ""
	winning_combo = []
	last_move_index = -1
	hovered_cell = -1
	ai_thinking = false
	confetti_particles.clear()
	stop_round_sfx()

	if stop_click_sound and click_sfx:
		click_sfx.stop()

	if vs_ai and ai_character == "charlie":
		call_deferred("ai_move")

	queue_redraw()


func go_to_menu():
	ai_turn_token += 1
	ai_thinking = false
	clear_touch_ripple()
	flash_active = false
	flash_timer = 0.0
	stop_music(secret_music)
	stop_round_sfx()

	if music_on:
		play_music(menu_music)

	change_screen("menu")

func place_mark(index: int, symbol: String):
	board[index] = symbol
	last_move_index = index
	piece_pop_timers[index] = PIECE_POP_DURATION
	update_hovered_cell()

# =====================
# GEOMETRY HELPERS
# =====================
func get_cell_rect(index: int) -> Rect2:
	var row = int(index / 3)
	var col = index % 3
	return Rect2(board_rect.position.x + col * cell_size, board_rect.position.y + row * cell_size, cell_size, cell_size)

func get_cell_index_at_position(pos: Vector2) -> int:
	if not board_rect.has_point(pos):
		return -1

	var col = int((pos.x - board_rect.position.x) / cell_size)
	var row = int((pos.y - board_rect.position.y) / cell_size)
	var index = row * 3 + col

	if index < 0 or index >= 9:
		return -1
	return index

func update_hovered_cell():
	if current_screen != "game":
		hovered_cell = -1
		return

	var cell = get_cell_index_at_position(mouse_pos)
	if cell != -1 and board[cell] == "":
		hovered_cell = cell
	else:
		hovered_cell = -1

func get_restart_icon_center() -> Vector2:
	var icon_size = clamp(38.0 * ui_scale, 34.0, 46.0)
	var menu_center = get_menu_icon_center()
	return menu_center - Vector2(icon_size + 12.0 * ui_scale, 0)

func get_menu_icon_center() -> Vector2:
	var icon_size = clamp(38.0 * ui_scale, 34.0, 46.0)
	return Vector2(screen_w - safe_margin - icon_size / 2.0, status_rect.position.y + status_rect.size.y / 2.0)

# =====================
# SYMBOL HELPERS
# =====================
func get_ai_symbol() -> String:
	return SYMBOL_X if ai_character == "charlie" else SYMBOL_O

func get_human_symbol() -> String:
	return SYMBOL_O if ai_character == "charlie" else SYMBOL_X

func get_random_empty_cell() -> int:
	var empty_cells = []

	for i in range(9):
		if board[i] == "":
			empty_cells.append(i)

	if empty_cells.size() == 0:
		return -1

	return empty_cells[randi() % empty_cells.size()]

# =====================
# CONFETTI
# =====================
func spawn_confetti():
	confetti_particles.clear()

	var colors = [
		Color(1.0, 0.78, 0.25),
		Color(1.0, 0.35, 0.20),
		Color(0.95, 0.90, 0.70),
		Color(0.80, 0.48, 0.18)
	]

	var center = board_rect.get_center()
	for i in range(44):
		var angle = randf() * TAU
		var speed = randf_range(70.0 * ui_scale, 190.0 * ui_scale)
		var life = randf_range(0.65, 1.35)
		confetti_particles.append({
			"pos": center + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0)) * ui_scale,
			"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0, -70.0 * ui_scale),
			"life": life,
			"max_life": life,
			"size": randf_range(3.0 * ui_scale, 6.0 * ui_scale),
			"color": colors[i % colors.size()]
		})

func update_confetti(delta: float) -> bool:
	if confetti_particles.size() == 0:
		return false

	for i in range(confetti_particles.size() - 1, -1, -1):
		var particle = confetti_particles[i]
		particle["life"] -= delta

		var velocity = particle["vel"]
		var position = particle["pos"]
		velocity.y += 220.0 * ui_scale * delta
		position += velocity * delta
		particle["vel"] = velocity
		particle["pos"] = position

		if particle["life"] <= 0.0:
			confetti_particles.remove_at(i)
		else:
			confetti_particles[i] = particle

	return true

func draw_confetti():
	for particle in confetti_particles:
		var color = particle["color"]
		color.a *= clamp(particle["life"] / particle["max_life"], 0.0, 1.0)
		var size = particle["size"]
		draw_rect(Rect2(particle["pos"] - Vector2(size / 2.0, size / 2.0), Vector2(size, size)), color)

# =====================
# MOBILE FEEDBACK
# =====================
func pulse_haptic(duration_ms: int):
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(duration_ms)

# =====================
# AUDIO
# =====================
func unlock_audio():
	if audio_unlocked:
		return

	audio_unlocked = true
	if music_on:
		if current_screen == "secret":
			play_music(secret_music)
		else:
			play_music(menu_music)

func create_audio_player(path: String, should_loop: bool) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	var stream = load(path)

	if stream:
		player.stream = stream
		if should_loop:
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			elif stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	add_child(player)
	return player

func toggle_music():
	music_on = !music_on

	if not music_on:
		stop_music(menu_music)
		stop_music(secret_music)
	else:
		if current_screen == "secret":
			play_music(secret_music)
		else:
			play_music(menu_music)
	queue_redraw()

func toggle_sfx():
	sfx_on = !sfx_on
	queue_redraw()
func play_music(player: AudioStreamPlayer):
	if audio_unlocked and music_on and player and player.stream and not player.playing:
		player.play()

func stop_music(player: AudioStreamPlayer):
	if player:
		player.stop()

func play_click():
	if sfx_on and click_sfx and click_sfx.stream:
		click_sfx.stop()
		click_sfx.play()

func play_win():
	if sfx_on and win_sfx and win_sfx.stream:
		win_sfx.play()

func play_draw():
	if sfx_on and draw_sfx and draw_sfx.stream:
		draw_sfx.play()

func stop_round_sfx():
	if win_sfx:
		win_sfx.stop()
	if draw_sfx:
		draw_sfx.stop()

func stop_all_sfx():
	stop_round_sfx()
	if click_sfx:
		click_sfx.stop()
