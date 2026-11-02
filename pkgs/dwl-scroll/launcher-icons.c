/* Display-independent freedesktop icon lookup and CPU rendering. No toolkit
 * window or connection to a display is needed. Cache icons for this menu only. */
#include <cairo.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gio/gio.h>
#include <glib/gstdio.h>
#include <librsvg/rsvg.h>
#include <sfdo-basedir.h>
#include <sfdo-icon.h>
#include <stdint.h>
#include <string.h>

#ifndef LAUNCHER_ICON_THEME
#define LAUNCHER_ICON_THEME "Papirus-Dark"
#endif
#ifndef LAUNCHER_ICON_DIR
#define LAUNCHER_ICON_DIR "@launcherIconPath@"
#endif

typedef struct {
	struct sfdo_icon_ctx *context;
	struct sfdo_icon_theme *theme, *fallback;
	GHashTable *cache;
} LauncherIcons;

static void
launchericonsurfacefree(gpointer data)
{
	if (data)
		cairo_surface_destroy(data);
}

static void
launchericonsinit(LauncherIcons *icons, const char *fallback_directory)
{
	struct sfdo_basedir_ctx *basedir = sfdo_basedir_ctx_create();
	GKeyFile *settings = g_key_file_new();
	char *path = g_build_filename(g_get_user_config_dir(), "gtk-3.0", "settings.ini", NULL);
	char *theme = NULL;
	memset(icons, 0, sizeof(*icons));
	icons->cache = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, launchericonsurfacefree);
	icons->context = sfdo_icon_ctx_create(basedir);
	sfdo_basedir_ctx_destroy(basedir);
	if (g_key_file_load_from_file(settings, path, G_KEY_FILE_NONE, NULL))
		theme = g_key_file_get_string(settings, "Settings", "gtk-icon-theme-name", NULL);
	if (!theme || !*theme || strchr(theme, '/')) {
		g_free(theme);
		theme = g_strdup(LAUNCHER_ICON_THEME);
	}
	if (icons->context) {
		sfdo_icon_ctx_set_log_handler(icons->context, SFDO_LOG_LEVEL_SILENT, NULL, NULL);
		icons->theme = sfdo_icon_theme_load(icons->context, theme,
				SFDO_ICON_THEME_LOAD_OPTION_ALLOW_MISSING);
		if (fallback_directory) {
			struct sfdo_string directory = {fallback_directory, strlen(fallback_directory)};
			icons->fallback = sfdo_icon_theme_load_from(icons->context, LAUNCHER_ICON_THEME,
					&directory, 1, SFDO_ICON_THEME_LOAD_OPTION_ALLOW_MISSING);
		}
	}
	g_free(theme);
	g_free(path);
	g_key_file_unref(settings);
}

static void
launchericonsfinish(LauncherIcons *icons)
{
	g_hash_table_unref(icons->cache);
	sfdo_icon_theme_destroy(icons->theme);
	sfdo_icon_theme_destroy(icons->fallback);
	sfdo_icon_ctx_destroy(icons->context);
	memset(icons, 0, sizeof(*icons));
}

static char *
launchericonthemepath(LauncherIcons *icons, const char *name, int size, int scale)
{
	struct sfdo_icon_theme *themes[] = {icons->theme, icons->fallback};
	size_t i;
	for (i = 0; i < sizeof(themes) / sizeof(themes[0]); i++) {
		struct sfdo_icon_file *file;
		char *path;
		if (!themes[i])
			continue;
		file = sfdo_icon_theme_lookup(themes[i], name, SFDO_NT, size, scale, 0);
		if (!file || file == SFDO_ICON_FILE_INVALID)
			continue;
		path = g_strdup(sfdo_icon_file_get_path(file, NULL));
		sfdo_icon_file_destroy(file);
		return path;
	}
	return NULL;
}

static char *
launchericonpath(LauncherIcons *icons, GIcon *icon, int size, int scale)
{
	if (G_IS_EMBLEMED_ICON(icon))
		icon = g_emblemed_icon_get_icon(G_EMBLEMED_ICON(icon));
	if (G_IS_FILE_ICON(icon))
		return g_file_get_path(g_file_icon_get_file(G_FILE_ICON(icon)));
	if (G_IS_THEMED_ICON(icon)) {
		const char *const *names = g_themed_icon_get_names(G_THEMED_ICON(icon));
		for (; *names; names++) {
			char *path = launchericonthemepath(icons, *names, size, scale);
			if (path)
				return path;
		}
	}
	return NULL;
}

static cairo_surface_t *
launchericondecode(const char *path, int pixels)
{
	GStatBuf info;
	cairo_surface_t *surface;
	cairo_t *cr;
	GError *error = NULL;
	if (!path || g_stat(path, &info) || !S_ISREG(info.st_mode)
			|| info.st_size > 16 * 1024 * 1024)
		return NULL;
	if (g_str_has_suffix(path, ".svg")) {
		RsvgHandle *svg = rsvg_handle_new_from_file(path, &error);
		RsvgRectangle viewport = {0, 0, pixels, pixels};
		gboolean rendered;
		g_clear_error(&error);
		if (!svg)
			return NULL;
		surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, pixels, pixels);
		cr = cairo_create(surface);
		rendered = rsvg_handle_render_document(svg, cr, &viewport, &error);
		cairo_destroy(cr);
		g_object_unref(svg);
		g_clear_error(&error);
		if (rendered && cairo_surface_status(surface) == CAIRO_STATUS_SUCCESS)
			return surface;
		cairo_surface_destroy(surface);
		return NULL;
	} else {
		GdkPixbuf *pixbuf;
		int x, y, width, height, channels, stride;
		guchar *source;
		/* Reject huge raster dimensions before allocating/decoding pixels. */
		if (!gdk_pixbuf_get_file_info(path, &width, &height)
				|| width <= 0 || height <= 0 || width > 8192 || height > 8192)
			return NULL;
		pixbuf = gdk_pixbuf_new_from_file_at_scale(path, pixels, pixels, TRUE, &error);
		g_clear_error(&error);
		if (!pixbuf)
			return NULL;
		width = gdk_pixbuf_get_width(pixbuf);
		height = gdk_pixbuf_get_height(pixbuf);
		channels = gdk_pixbuf_get_n_channels(pixbuf);
		stride = gdk_pixbuf_get_rowstride(pixbuf);
		source = gdk_pixbuf_get_pixels(pixbuf);
		surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, width, height);
		if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
			g_object_unref(pixbuf);
			cairo_surface_destroy(surface);
			return NULL;
		}
		for (y = 0; y < height; y++) {
			uint32_t *dest = (uint32_t *)(cairo_image_surface_get_data(surface)
					+ y * cairo_image_surface_get_stride(surface));
			const guchar *pixel = source + y * stride;
			for (x = 0; x < width; x++, pixel += channels) {
				uint32_t alpha = channels == 4 ? pixel[3] : 255;
				dest[x] = alpha << 24 | ((pixel[0] * alpha + 127) / 255) << 16
						| ((pixel[1] * alpha + 127) / 255) << 8 | (pixel[2] * alpha + 127) / 255;
			}
		}
		g_object_unref(pixbuf);
		cairo_surface_mark_dirty(surface);
		return surface;
	}
}

static cairo_surface_t *
launchericonload(LauncherIcons *icons, GIcon *icon, int size, int scale, const float color[4])
{
	char *description = icon ? g_icon_to_string(icon) : NULL;
	char *key = g_strdup_printf("%s:%d:%d:%g:%g:%g:%g", description ? description : "", size,
			scale, color[0], color[1], color[2], color[3]);
	char *path;
	cairo_surface_t *surface;
	gpointer cached;
	g_free(description);
	if (g_hash_table_lookup_extended(icons->cache, key, NULL, &cached)) {
		g_free(key);
		return cached;
	}
	path = launchericonpath(icons, icon, size, scale);
	surface = launchericondecode(path, size * scale);
	if (surface && (g_str_has_suffix(path, "-symbolic.svg") || g_str_has_suffix(path, "-symbolic.png"))) {
		cairo_t *cr = cairo_create(surface);
		cairo_set_operator(cr, CAIRO_OPERATOR_IN);
		cairo_set_source_rgba(cr, color[0], color[1], color[2], color[3]);
		cairo_paint(cr);
		cairo_destroy(cr);
	}
	g_free(path);
	if (!surface) {
		path = launchericonthemepath(icons, "application-x-executable", size, scale);
		surface = launchericondecode(path, size * scale);
		g_free(path);
	}
	g_hash_table_insert(icons->cache, key, surface);
	return surface;
}

static void
launchericondraw(LauncherIcons *icons, cairo_t *cr, GIcon *icon, int x, int y,
		int size, int scale, const float color[4])
{
	cairo_surface_t *surface = launchericonload(icons, icon, size, scale, color);
	cairo_save(cr);
	if (surface) {
		double width = (double)cairo_image_surface_get_width(surface) / scale;
		double height = (double)cairo_image_surface_get_height(surface) / scale;
		cairo_translate(cr, x + (size - width) / 2, y + (size - height) / 2);
		cairo_scale(cr, 1.0 / scale, 1.0 / scale);
		cairo_set_source_surface(cr, surface, 0, 0);
		cairo_paint(cr);
	} else {
		/* Last resort works even without any installed icon themes. */
		cairo_set_source_rgba(cr, color[0], color[1], color[2], color[3]);
		cairo_set_line_width(cr, 1.5);
		cairo_rectangle(cr, x + 2, y + 3, size - 4, size - 6);
		cairo_move_to(cr, x + 2, y + 8);
		cairo_line_to(cr, x + size - 2, y + 8);
		cairo_stroke(cr);
	}
	cairo_restore(cr);
}
