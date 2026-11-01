/* dwl-scroll, dwl 0.9 / wlroots 0.20. Rebuild to apply configuration.
 * The three @...@ command paths are substituted by the Nix package.
 * Set configH to another complete header to configure a separate variant. */
#define COLOR(hex) { ((hex >> 24) & 0xff) / 255.0f, \
                    ((hex >> 16) & 0xff) / 255.0f, \
                    ((hex >> 8) & 0xff) / 255.0f, (hex & 0xff) / 255.0f }
static const int sloppyfocus = 0; /* click/key focus; 1 enables pointer focus */
static const int bypass_surface_visibility = 0;
static const unsigned int borderpx = 2;
static const unsigned int snap = 32;
static const float rootcolor[] = COLOR(0x181825ff);
static const float bordercolor[] = COLOR(0x45475aff);
static const float focuscolor[] = COLOR(0xc69bffff);
static const float urgentcolor[] = COLOR(0xf38ba8ff);
static const float fullscreen_bg[] = COLOR(0x000000ff);
#define TAGCOUNT 9
static int log_level = WLR_ERROR;
#define DISCORD_RPC_ENABLED 0
#define DISCORD_RPC_CLIENT_ID NULL
#define DISCORD_RPC_SHOW_APP 0

static const Rule rules[] = {
	/* app_id, title, tags mask (0=current), floating, monitor (-1=current) */
	{ NULL, NULL, 0, 0, -1 },
};

/* Widths are fractions of the padded usable area, not the window count. */
static const float scroll_width = 0.55f;
static const float scroll_widths[] = {0.33f, 0.5f, 0.67f, 1.0f};
static const int scroll_column_gap = 12;
static const int scroll_window_gap = 8;
static const int scroll_padding = 12;
static const int scroll_center = 0; /* 0=minimal reveal; 1=center when focus changes */
static const int scroll_insert = 1; /* -1=new left, 0=focused column, 1=new right */
static const int scroll_step = 160; /* pixels per key press; clamped to content */
#define MODKEY WLR_MODIFIER_LOGO /* use WLR_MODIFIER_ALT for the other sessions' Alt */
static const uint32_t scroll_wheel_mod = MODKEY; /* 0 disables compositor wheel input */
static const double scroll_wheel_scale = 2.0; /* continuous axis delta -> pixels */

static const Layout layouts[] = {
	{ "|||", scrolling },
	{ "[]=", tile },
	{ "><>", NULL },
	{ "[M]", monocle },
};
static const MonitorRule monrules[] = {
	/* name, mfact, nmaster, scale, layout, transform, x, y */
	{ NULL, 0.55f, 1, 1, &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, -1, -1 },
};
static const struct xkb_rule_names xkb_rules = { .options = NULL };
static const int repeat_rate = 25, repeat_delay = 600;
static const int tap_to_click = 1, tap_and_drag = 1, drag_lock = 0;
static const int natural_scrolling = 1, disable_while_typing = 1;
static const int left_handed = 0, middle_button_emulation = 0;
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_CLICKFINGER;
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.0;
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

/* dwl 0.9 matches modifier-independent symbols (lowercase even with Shift). */
#define TAGKEYS(KEY,TAG) \
	{ MODKEY, KEY, view, {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL, KEY, toggleview, {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_SHIFT, KEY, tag, {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, KEY, toggletag, {.ui = 1 << TAG} }
static const char *termcmd[] = { "@terminal@", NULL };
static const char *menucmd[] = { "@launcher@", NULL };
static const char *lockcmd[] = { "@locker@", NULL };

static const Key keys[] = {
	{ MODKEY, XKB_KEY_h, scrollfocuscolumn, {.i = -1} },
	{ MODKEY, XKB_KEY_l, scrollfocuscolumn, {.i = 1} },
	{ MODKEY, XKB_KEY_k, scrollfocuswindow, {.i = -1} },
	{ MODKEY, XKB_KEY_j, scrollfocuswindow, {.i = 1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_h, scrollmovecolumn, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_l, scrollmovecolumn, {.i = 1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_k, scrollmovewindow, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_j, scrollmovewindow, {.i = 1} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_h, scrollpan, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_l, scrollpan, {.i = 1} },
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, XKB_KEY_h, scrolltransfer, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, XKB_KEY_l, scrolltransfer, {.i = 1} },
	{ MODKEY, XKB_KEY_Return, spawn, {.v = termcmd} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_Return, scrollmerge, {.i = 1} },
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, XKB_KEY_Return, scrollmerge, {.i = -1} },
	{ MODKEY, XKB_KEY_i, scrollsetinsert, {.i = 2} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_bracketleft, scrollsetinsert, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_bracketright, scrollsetinsert, {.i = 1} },
	{ MODKEY, XKB_KEY_bracketleft, scrollwidth, {.f = -0.05f} },
	{ MODKEY, XKB_KEY_bracketright, scrollwidth, {.f = 0.05f} },
	{ MODKEY, XKB_KEY_r, scrollpreset, {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Return, scrollsplit, {.i = 1} },
	{ MODKEY, XKB_KEY_d, showlauncher, {0} },
	{ MODKEY, XKB_KEY_q, killclient, {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_space, togglefloating, {0} },
	{ MODKEY, XKB_KEY_f, togglefullscreen, {0} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_Escape, spawn, {.v = lockcmd} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_e, quit, {0} },
	{ MODKEY, XKB_KEY_s, setlayout, {.v = &layouts[0]} },
	{ MODKEY, XKB_KEY_t, setlayout, {.v = &layouts[1]} },
	{ MODKEY, XKB_KEY_v, setlayout, {.v = &layouts[2]} },
	{ MODKEY, XKB_KEY_m, setlayout, {.v = &layouts[3]} },
	/* Stock dwl controls retained for non-scrolling layouts. */
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_j, focusstack, {.i = 1} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_k, focusstack, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_equal, incnmaster, {.i = 1} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_minus, incnmaster, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_comma, setmfact, {.f = -0.05f} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_period, setmfact, {.f = 0.05f} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_z, zoom, {0} },
	{ MODKEY, XKB_KEY_Tab, view, {0} },
	{ MODKEY, XKB_KEY_0, view, {.ui = ~0} },
	{ MODKEY, XKB_KEY_comma, focusmon, {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY, XKB_KEY_period, focusmon, {.i = WLR_DIRECTION_RIGHT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_comma, tagmon, {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_period, tagmon, {.i = WLR_DIRECTION_RIGHT} },
	TAGKEYS(XKB_KEY_1, 0),
	TAGKEYS(XKB_KEY_2, 1),
	TAGKEYS(XKB_KEY_3, 2),
	TAGKEYS(XKB_KEY_4, 3),
	TAGKEYS(XKB_KEY_5, 4),
	TAGKEYS(XKB_KEY_6, 5),
	TAGKEYS(XKB_KEY_7, 6),
	TAGKEYS(XKB_KEY_8, 7),
	TAGKEYS(XKB_KEY_9, 8),
#define CHVT(n) { WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F##n, chvt, {.ui = n} }
	CHVT(1), CHVT(2), CHVT(3), CHVT(4), CHVT(5), CHVT(6),
	CHVT(7), CHVT(8), CHVT(9), CHVT(10), CHVT(11), CHVT(12),
};
static const Button buttons[] = {
	{ MODKEY, BTN_LEFT, moveresize, {.ui = CurMove} },
	{ MODKEY, BTN_RIGHT, moveresize, {.ui = CurResize} },
	{ MODKEY, BTN_MIDDLE, togglefloating, {0} },
};
/* Modifier+wheel is handled continuously by scroll_wheel_mod above.
 * Add ordinary dwl Axis actions here without changing the layout code. */
static const Axis axes[] = {
	{ 0, AxisUp, NULL, {0} },
};
