/* Real icon-theme lookup and image decoding, with no display/toolkit init. */
#include <assert.h>
#include <stdio.h>
#include "launcher-icons.c"

static const float white[4] = {1, 1, 1, 1};
static const float green[4] = {0, 1, 0, 1};

static void
writefixture(const char *root, const char *name, const char *text)
{
	char *path = g_build_filename(root, name, NULL);
	char *parent = g_path_get_dirname(path);
	assert(g_mkdir_with_parents(parent, 0700) == 0);
	assert(g_file_set_contents(path, text, -1, NULL));
	g_free(parent);
	g_free(path);
}

static void
theme(const char *root, const char *name, const char *inherits)
{
	char *path = g_strdup_printf("data/icons/%s/index.theme", name);
	char *text = g_strdup_printf(
			"[Icon Theme]\nName=%s\nInherits=%s\nDirectories=24x24/apps,scalable/apps\n"
			"[24x24/apps]\nSize=24\nType=Fixed\nContext=Applications\n"
			"[scalable/apps]\nSize=24\nType=Scalable\nMinSize=1\nMaxSize=256\nContext=Applications\n",
			name, inherits);
	writefixture(root, path, text);
	g_free(text);
	g_free(path);
}

static uint32_t
center(cairo_surface_t *surface)
{
	int x, y;
	assert(surface && cairo_surface_status(surface) == CAIRO_STATUS_SUCCESS);
	cairo_surface_flush(surface);
	x = cairo_image_surface_get_width(surface) / 2;
	y = cairo_image_surface_get_height(surface) / 2;
	return ((uint32_t *)(cairo_image_surface_get_data(surface)
			+ y * cairo_image_surface_get_stride(surface)))[x];
}

static void
removefixtures(const char *root)
{
	GDir *dir = g_dir_open(root, 0, NULL);
	const char *name;
	assert(dir);
	while ((name = g_dir_read_name(dir))) {
		char *path = g_build_filename(root, name, NULL);
		if (g_file_test(path, G_FILE_TEST_IS_DIR))
			removefixtures(path);
		else
			assert(g_remove(path) == 0);
		g_free(path);
	}
	g_dir_close(dir);
	assert(g_rmdir(root) == 0);
}

int
main(void)
{
	LauncherIcons icons;
	char *root = g_dir_make_tmp("dwl-launcher-icons-XXXXXX", NULL);
	char *data, *config, *path;
	GIcon *red, *svg, *xpm, *fileicon, *symbolic, *missing, *broken;
	GFile *file;
	cairo_surface_t *png, *image, *cached;
	cairo_t *cr;
	uint32_t *pixels;
	unsigned int nonempty = 0;
	int i;
	assert(root);
	data = g_build_filename(root, "data", NULL);
	config = g_build_filename(root, "config", NULL);
	g_setenv("XDG_DATA_HOME", data, TRUE);
	g_setenv("XDG_DATA_DIRS", data, TRUE);
	g_setenv("XDG_CONFIG_HOME", config, TRUE);
	g_unsetenv("DISPLAY");
	g_unsetenv("WAYLAND_DISPLAY");
	writefixture(root, "config/gtk-3.0/settings.ini", "[Settings]\ngtk-icon-theme-name=TestIcons\n");
	theme(root, "TestIcons", "ParentIcons");
	theme(root, "ParentIcons", "hicolor");
	theme(root, "hicolor", "");
	path = g_build_filename(data, "icons/TestIcons/24x24/apps/red.png", NULL);
	{
		char *directory = g_path_get_dirname(path);
		assert(g_mkdir_with_parents(directory, 0700) == 0);
		g_free(directory);
	}
	png = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 2, 1);
	cr = cairo_create(png);
	cairo_set_source_rgba(cr, 1, 0, 0, 0.5);
	cairo_paint(cr);
	cairo_destroy(cr);
	assert(cairo_surface_write_to_png(png, path) == CAIRO_STATUS_SUCCESS);
	cairo_surface_destroy(png);
	writefixture(root, "data/icons/ParentIcons/scalable/apps/green.svg",
			"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\">"
			"<rect width=\"24\" height=\"24\" fill=\"#00ff00\"/></svg>");
	writefixture(root, "data/icons/ParentIcons/scalable/apps/test-symbolic.svg",
			"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\">"
			"<rect width=\"24\" height=\"24\" fill=\"#000000\"/></svg>");
	writefixture(root, "data/icons/hicolor/24x24/apps/blue.xpm",
			"/* XPM */\nstatic char *icon[] = {\"2 2 1 1\", \"a c #0000ff\", \"aa\", \"aa\"};\n");
	writefixture(root, "data/icons/ParentIcons/scalable/apps/broken.svg", "not an SVG image");
	red = g_themed_icon_new("red");
	svg = g_themed_icon_new("green");
	xpm = g_themed_icon_new("blue");
	symbolic = g_themed_icon_new("test-symbolic");
	missing = g_themed_icon_new("no-such-app-icon");
	broken = g_themed_icon_new("broken");
	file = g_file_new_for_path(path);
	fileicon = g_file_icon_new(file);
	g_object_unref(file);
	launchericonsinit(&icons, NULL);
	cached = launchericonload(&icons, red, 20, 1, white);
	assert(center(cached) == 0x80800000); /* Cairo uses premultiplied ARGB. */
	assert(cairo_image_surface_get_width(cached) == 20 && cairo_image_surface_get_height(cached) == 10);
	assert(launchericonload(&icons, red, 20, 1, white) == cached);
	image = launchericonload(&icons, red, 20, 2, white);
	assert(center(image) == 0x80800000 && cairo_image_surface_get_width(image) == 40);
	assert(center(launchericonload(&icons, svg, 20, 1, white)) == 0xff00ff00);
	assert(center(launchericonload(&icons, xpm, 20, 1, white)) == 0xff0000ff);
	assert(center(launchericonload(&icons, fileicon, 20, 1, white)) == 0x80800000);
	assert(center(launchericonload(&icons, symbolic, 20, 1, white)) == 0xffffffff);
	assert(center(launchericonload(&icons, symbolic, 20, 1, green)) == 0xff00ff00);
	assert(!launchericonload(&icons, broken, 20, 1, white));
	assert(!launchericonload(&icons, missing, 20, 1, white));
	image = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 20, 20);
	cr = cairo_create(image);
	launchericondraw(&icons, cr, missing, 0, 0, 20, 1, white);
	cairo_destroy(cr);
	cairo_surface_flush(image);
	pixels = (uint32_t *)cairo_image_surface_get_data(image);
	for (i = 0; i < 400; i++)
		if (pixels[i])
			nonempty++;
	assert(nonempty > 20); /* Missing icons still get a visible vector fallback. */
	cairo_surface_destroy(image);
	launchericonsfinish(&icons);
	/* The standalone package must also work without Papirus in XDG_DATA_DIRS. */
	launchericonsinit(&icons, LAUNCHER_ICON_DIR);
	assert(launchericonload(&icons, NULL, 20, 1, white));
	launchericonsfinish(&icons);
	g_object_unref(red);
	g_object_unref(svg);
	g_object_unref(xpm);
	g_object_unref(fileicon);
	g_object_unref(symbolic);
	g_object_unref(missing);
	g_object_unref(broken);
	g_free(path);
	g_free(data);
	g_free(config);
	removefixtures(root);
	g_free(root);
	puts("PASS: application icons: themed PNG/SVG/XPM, inheritance, file icons, alpha, HiDPI, symbolic colors, caching and fallback");
	return 0;
}
