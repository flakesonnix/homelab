/* Exercise the real GIO-backed model, not a mock desktop-entry parser. */
#include <assert.h>
#include <stdio.h>
#include <glib/gstdio.h>
#include "launcher-model.c"

static void
entry(const char *directory, const char *id, const char *body)
{
	char *path = g_build_filename(directory, id, NULL);
	char *text = g_strconcat("[Desktop Entry]\nType=Application\nExec=true\n", body, NULL);
	assert(g_file_set_contents(path, text, -1, NULL));
	g_free(path);
	g_free(text);
}

static void
query(LauncherModel *model, const char *text)
{
	g_strlcpy(model->query, text, sizeof(model->query));
	launcherfilter(model);
}

static const char *
selected(LauncherModel *model)
{
	LauncherApp *app = g_ptr_array_index(model->matches, model->selected);
	return app->name;
}

int
main(void)
{
	LauncherModel model;
	char *root = g_dir_make_tmp("dwl-launcher-model-XXXXXX", NULL);
	char *directory = g_build_filename(root, "applications", NULL);
	guint i;
	assert(root && g_mkdir(directory, 0700) == 0);
	g_setenv("XDG_DATA_HOME", root, TRUE);
	g_setenv("XDG_DATA_DIRS", root, TRUE);
	g_setenv("XDG_CURRENT_DESKTOP", "dwl-scroll", TRUE);
	entry(directory, "alpha.desktop", "Name=Alpha\nKeywords=Web;Utility;\n");
	entry(directory, "utility.desktop", "Name=Alpha Utility\n");
	entry(directory, "unicode.desktop", "Name=Ärger Editor\nKeywords=Text;\n");
	entry(directory, "literal.desktop", "Name=<b>Literal & Name</b>\n");
	entry(directory, "hidden.desktop", "Name=Hidden\nHidden=true\n");
	entry(directory, "nodisplay.desktop", "Name=NoDisplay\nNoDisplay=true\n");
	entry(directory, "other.desktop", "Name=Other\nOnlyShowIn=GNOME;\n");
	entry(directory, "missing.desktop", "Name=Missing\nTryExec=/nonexistent/dwl-launcher-test\n");
	launchermodelinit(&model);
	assert(model.apps->len == 4 && model.matches->len == 4);
	query(&model, "ALPHA");
	assert(model.matches->len == 2 && !strcmp(selected(&model), "Alpha"));
	launcherselect(&model, -1);
	assert(!strcmp(selected(&model), "Alpha Utility"));
	launcherselect(&model, 1);
	assert(!strcmp(selected(&model), "Alpha"));
	query(&model, "utility web");
	assert(model.matches->len == 1 && !strcmp(selected(&model), "Alpha"));
	query(&model, "ÄRGER text");
	assert(model.matches->len == 1 && !strcmp(selected(&model), "Ärger Editor"));
	query(&model, "a\314\210rger"); /* decomposed ä matches composed Ä */
	assert(model.matches->len == 1 && !strcmp(selected(&model), "Ärger Editor"));
	query(&model, "<b>");
	assert(model.matches->len == 1 && !strcmp(selected(&model), "<b>Literal & Name</b>"));
	query(&model, "unicode.desktop");
	assert(model.matches->len == 1);
	query(&model, "nothing-matches");
	assert(model.matches->len == 0);
	launcherselect(&model, -1);
	assert(model.selected == 0);
	query(&model, "one two   ");
	launcherbackspace(&model, 1);
	assert(!strcmp(model.query, "one "));
	query(&model, "x");
	launcherappend(&model, 0x1f431);
	assert(!strcmp(model.query, "x🐱"));
	launcherbackspace(&model, 0);
	assert(!strcmp(model.query, "x"));
	launcherbackspace(&model, 0);
	launcherbackspace(&model, 0);
	assert(!*model.query);
	for (i = 0; i < sizeof(model.query) * 2; i++)
		launcherappend(&model, 0xe4);
	assert(strlen(model.query) == sizeof(model.query) - 2);
	assert(g_utf8_validate(model.query, -1, NULL));
	launcherappend(&model, '\n');
	assert(g_utf8_validate(model.query, -1, NULL));
	launchermodelfinish(&model);
	entry(directory, "installed-later.desktop", "Name=Installed Later\n");
	for (i = 0; i < 30; i++) {
		g_usleep(100000);
		launchermodelinit(&model);
		query(&model, "Installed Later");
		if (model.matches->len)
			break;
		launchermodelfinish(&model);
	}
	assert(i < 30 && model.matches->len == 1);
	launchermodelfinish(&model);
	/* Every fixture is test-owned; leave no files after native/sanitized runs. */
	{
		GDir *dir = g_dir_open(directory, 0, NULL);
		const char *name;
		while ((name = g_dir_read_name(dir))) {
			char *path = g_build_filename(directory, name, NULL);
			g_remove(path);
			g_free(path);
		}
		g_dir_close(dir);
	}
	g_rmdir(directory);
	g_rmdir(root);
	g_free(directory);
	g_free(root);
	puts("PASS: built-in launcher discovery/refresh, visibility, ranking, Unicode, editing, bounds and empty matches");
	return 0;
}
