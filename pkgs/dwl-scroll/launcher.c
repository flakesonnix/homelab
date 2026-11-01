/* Compositor-owned launcher: no client surface, X11 window or external menu.
 * Included after config.h/client.h/ime.h. Rendering uses a CPU-backed wlroots
 * scene buffer; desktop activation runs in a fresh helper to keep GIO's D-Bus
 * and process-launching work outside the compositor event loop. */
#include <cairo.h>
#include <drm_fourcc.h>
#include <pango/pangocairo.h>
#include <wlr/interfaces/wlr_buffer.h>
#include "launcher-model.c"
#include "launcher-icons.c"

#ifndef LAUNCHER_FONT
#define LAUNCHER_FONT "Iosevka 10"
#endif

enum { LauncherRows = 8, LauncherRowHeight = 28, LauncherHeader = 36, LauncherFooter = 26 };

typedef struct {
	struct wlr_buffer base;
	cairo_surface_t *surface;
} LauncherBuffer;

static struct {
	int active;
	Monitor *mon;
	LauncherModel model;
	LauncherIcons icons;
	struct wlr_scene_buffer *buffer;
	struct wlr_box box;
	int rows;
	unsigned char buttons[KEY_MAX + 1];
} launcher;

static void launcherclose(int restore);

static void
launcherbufferdestroy(struct wlr_buffer *buffer)
{
	LauncherBuffer *image = wl_container_of(buffer, image, base);
	cairo_surface_destroy(image->surface);
	free(image);
}

static bool
launcherbufferaccess(struct wlr_buffer *buffer, uint32_t flags, void **data,
		uint32_t *format, size_t *stride)
{
	LauncherBuffer *image = wl_container_of(buffer, image, base);
	if (flags & WLR_BUFFER_DATA_PTR_ACCESS_WRITE)
		return false;
	*data = cairo_image_surface_get_data(image->surface);
	*format = DRM_FORMAT_ARGB8888;
	*stride = (size_t)cairo_image_surface_get_stride(image->surface);
	return true;
}

static void
launcherbufferend(struct wlr_buffer *buffer)
{
	(void)buffer;
}

static const struct wlr_buffer_impl launcherbufferimpl = {
	.destroy = launcherbufferdestroy,
	.begin_data_ptr_access = launcherbufferaccess,
	.end_data_ptr_access = launcherbufferend,
};

static void
launchercolor(cairo_t *cr, const float color[4])
{
	cairo_set_source_rgba(cr, color[0], color[1], color[2], color[3]);
}

static void
launchertext(cairo_t *cr, PangoLayout *layout, const char *text, int x, int y,
		int width, const float color[4])
{
	/* Never interpret desktop-entry names or user input as markup. */
	pango_layout_set_text(layout, text, -1);
	pango_layout_set_width(layout, MAX(1, width) * PANGO_SCALE);
	launchercolor(cr, color);
	cairo_move_to(cr, x, y);
	pango_cairo_show_layout(cr, layout);
}

static void
launcherrender(void)
{
	LauncherBuffer *image;
	PangoLayout *layout;
	PangoFontDescription *font;
	cairo_t *cr;
	char *prompt, *footer;
	unsigned int i, first;
	int width, height, pixelwidth, pixelheight;
	double scale;
	if (!launcher.active)
		return;
	width = MAX(1, MIN(720, launcher.mon->w.width - 24));
	launcher.rows = MAX(1, MIN(LauncherRows,
			(launcher.mon->w.height - LauncherHeader - LauncherFooter - 24) / LauncherRowHeight));
	height = MIN(MAX(1, launcher.mon->w.height - 24),
			LauncherHeader + launcher.rows * LauncherRowHeight + LauncherFooter);
	scale = MAX(1.0, launcher.mon->wlr_output->scale);
	pixelwidth = (int)ceil(width * scale);
	pixelheight = (int)ceil(height * scale);
	image = ecalloc(1, sizeof(*image));
	image->surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, pixelwidth, pixelheight);
	if (cairo_surface_status(image->surface) != CAIRO_STATUS_SUCCESS) {
		cairo_surface_destroy(image->surface);
		free(image);
		launcherclose(1);
		return;
	}
	wlr_buffer_init(&image->base, &launcherbufferimpl, pixelwidth, pixelheight);
	cr = cairo_create(image->surface);
	cairo_scale(cr, scale, scale);
	launchercolor(cr, focuscolor);
	cairo_paint(cr);
	launchercolor(cr, rootcolor);
	cairo_rectangle(cr, 2, 2, MAX(1, width - 4), MAX(1, height - 4));
	cairo_fill(cr);
	layout = pango_cairo_create_layout(cr);
	font = pango_font_description_from_string(LAUNCHER_FONT);
	pango_layout_set_font_description(layout, font);
	pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);
	pango_layout_set_single_paragraph_mode(layout, true);
	prompt = g_strdup_printf("Apps > %s_", launcher.model.query);
	launchertext(cr, layout, prompt, 12, 10, width - 24, focuscolor);
	g_free(prompt);
	first = launcher.model.selected / (unsigned int)launcher.rows * (unsigned int)launcher.rows;
	for (i = first; i < launcher.model.matches->len && i < first + (unsigned int)launcher.rows; i++) {
		LauncherApp *app = g_ptr_array_index(launcher.model.matches, i);
		int y = LauncherHeader + (int)(i - first) * LauncherRowHeight;
		if (i == launcher.model.selected) {
			launchercolor(cr, focuscolor);
			cairo_rectangle(cr, 2, y, MAX(1, width - 4), LauncherRowHeight);
			cairo_fill(cr);
		}
		launchericondraw(&launcher.icons, cr, g_app_info_get_icon(app->info),
				12, y + 4, 20, (int)ceil(scale),
				i == launcher.model.selected ? rootcolor : focuscolor);
		launchertext(cr, layout, app->name, 42, y + 5, width - 54,
				i == launcher.model.selected ? rootcolor : focuscolor);
	}
	if (!launcher.model.matches->len)
		launchertext(cr, layout, "No applications found", 12, LauncherHeader + 5,
				width - 24, urgentcolor);
	footer = g_strdup_printf("%u apps  |  Up/Down: select  Enter: launch  Esc: close", launcher.model.matches->len);
	launchertext(cr, layout, footer, 12, height - 22, width - 24, focuscolor);
	g_free(footer);
	pango_font_description_free(font);
	g_object_unref(layout);
	cairo_destroy(cr);
	cairo_surface_flush(image->surface);
	if (launcher.buffer)
		wlr_scene_node_destroy(&launcher.buffer->node);
	launcher.buffer = wlr_scene_buffer_create(layers[LyrLauncher], &image->base);
	wlr_buffer_drop(&image->base);
	if (!launcher.buffer) {
		launcherclose(1);
		return;
	}
	launcher.box = (struct wlr_box){
		launcher.mon->w.x + (launcher.mon->w.width - width) / 2,
		launcher.mon->w.y + MIN(12, MAX(0, launcher.mon->w.height - height)), width, height};
	wlr_scene_buffer_set_dest_size(launcher.buffer, width, height);
	wlr_scene_node_set_position(&launcher.buffer->node, launcher.box.x, launcher.box.y);
}

static void
launcherclose(int restore)
{
	Monitor *m = launcher.mon;
	if (!launcher.active)
		return;
	launcher.active = 0;
	launcher.mon = NULL;
	if (launcher.buffer)
		wlr_scene_node_destroy(&launcher.buffer->node);
	launcher.buffer = NULL;
	launchermodelfinish(&launcher.model);
	launchericonsfinish(&launcher.icons);
	if (restore) {
		selmon = m;
		/* Also restore an exclusive layer's keyboard focus, if one exists. */
		arrangelayers(m);
		focusclient(focustop(m), 1);
	}
}

static void
showlauncher(const Arg *arg)
{
	(void)arg;
	if (locked || !selmon || !selmon->wlr_output->enabled || seat->drag
			|| (cursor_mode != CurNormal && cursor_mode != CurPressed))
		return;
	if (launcher.active) {
		launcherclose(1);
		return;
	}
	launchermodelinit(&launcher.model);
	launchericonsinit(&launcher.icons, LAUNCHER_ICON_DIR);
	launcher.mon = selmon;
	/* Deactivate the client and IME before intercepting launcher input. */
	focusclient(NULL, 0);
	input_method_relay_set_focus(input_method_relay, NULL);
	wlr_seat_keyboard_notify_clear_focus(seat);
	wlr_seat_pointer_clear_focus(seat);
	exclusive_focus = NULL;
	launcher.active = 1;
	launcherrender();
}

static void
launcherlaunch(void)
{
	LauncherApp *app;
	const char *id;
	pid_t pid;
	if (!launcher.model.matches->len)
		return;
	app = g_ptr_array_index(launcher.model.matches, launcher.model.selected);
	id = g_app_info_get_id(app->info);
	if (!id)
		return;
	pid = fork();
	if (pid == 0) {
		dup2(STDERR_FILENO, STDOUT_FILENO);
		setsid();
		execl("/proc/self/exe", "dwl-scroll", "-a", id, (char *)NULL);
		_exit(127);
	}
	if (pid < 0) {
		wlr_log(WLR_ERROR, "launcher: fork failed");
		return;
	}
	launcherclose(1);
}

static void
launcherpointer(uint32_t button)
{
	unsigned int first, row;
	double x = cursor->x - launcher.box.x, y = cursor->y - launcher.box.y;
	if (button == BTN_RIGHT || x < 0 || x >= launcher.box.width
			|| y < 0 || y >= launcher.box.height) {
		launcherclose(1);
		return;
	}
	if (button != BTN_LEFT || y < LauncherHeader)
		return;
	first = launcher.model.selected / (unsigned int)launcher.rows * (unsigned int)launcher.rows;
	row = (unsigned int)((y - LauncherHeader) / LauncherRowHeight);
	if (row < (unsigned int)launcher.rows && first + row < launcher.model.matches->len) {
		launcher.model.selected = first + row;
		launcherlaunch();
	}
}

static void
launcherkey(struct wlr_keyboard *keyboard, uint32_t keycode)
{
	xkb_keysym_t sym = xkb_state_key_get_one_sym(keyboard->xkb_state, keycode);
	uint32_t mods = wlr_keyboard_get_modifiers(keyboard);
	if (sym == XKB_KEY_Escape || ((mods & WLR_MODIFIER_LOGO) && sym == XKB_KEY_d)) {
		launcherclose(1);
		return;
	}
	if (mods & (WLR_MODIFIER_LOGO | WLR_MODIFIER_ALT))
		return;
	if (sym == XKB_KEY_Return || sym == XKB_KEY_KP_Enter) {
		launcherlaunch();
		return;
	} else if (sym == XKB_KEY_Up || (mods & WLR_MODIFIER_CTRL && sym == XKB_KEY_p)) {
		launcherselect(&launcher.model, -1);
	} else if (sym == XKB_KEY_Down || (mods & WLR_MODIFIER_CTRL && sym == XKB_KEY_n)) {
		launcherselect(&launcher.model, 1);
	} else if (sym == XKB_KEY_Tab || sym == XKB_KEY_ISO_Left_Tab) {
		launcherselect(&launcher.model, mods & WLR_MODIFIER_SHIFT ? -1 : 1);
	} else if (sym == XKB_KEY_Page_Up || sym == XKB_KEY_Page_Down) {
		launcherselect(&launcher.model, sym == XKB_KEY_Page_Up ? -launcher.rows : launcher.rows);
	} else if (sym == XKB_KEY_Home) {
		launcher.model.selected = 0;
	} else if (sym == XKB_KEY_End && launcher.model.matches->len) {
		launcher.model.selected = launcher.model.matches->len - 1;
	} else if (mods & WLR_MODIFIER_CTRL && (sym == XKB_KEY_u || sym == XKB_KEY_l)) {
		launcher.model.query[0] = '\0';
		launcherfilter(&launcher.model);
	} else if (sym == XKB_KEY_BackSpace || (mods & WLR_MODIFIER_CTRL && sym == XKB_KEY_w)) {
		launcherbackspace(&launcher.model, mods & WLR_MODIFIER_CTRL);
	} else if (!(mods & WLR_MODIFIER_CTRL)) {
		launcherappend(&launcher.model, xkb_state_key_get_utf32(keyboard->xkb_state, keycode));
	}
	launcherrender();
}

static int
launcheractivate(const char *id)
{
	GDesktopAppInfo *app = g_desktop_app_info_new(id);
	GError *error = NULL;
	int result;
	if (!app) {
		fprintf(stderr, "dwl-scroll: desktop entry unavailable: %s\n", id);
		return EXIT_FAILURE;
	}
	result = g_app_info_launch(G_APP_INFO(app), NULL, NULL, &error);
	if (error) {
		fprintf(stderr, "dwl-scroll: launch failed: %s\n", error->message);
		g_error_free(error);
	}
	g_object_unref(app);
	return result ? EXIT_SUCCESS : EXIT_FAILURE;
}
