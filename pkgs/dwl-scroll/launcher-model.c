/* Desktop-entry discovery and UTF-8 search, shared by dwl and the native tests.
 * GIO implements XDG directory precedence, Hidden/NoDisplay, OnlyShowIn and
 * TryExec. Names and queries are data, never shell commands or Pango markup. */
#include <gio/gdesktopappinfo.h>
#include <string.h>

typedef struct {
	GAppInfo *info;
	char *name, *folded_name, *search;
	int score;
} LauncherApp;

typedef struct {
	GPtrArray *apps, *matches;
	guint selected;
	char query[1024];
} LauncherModel;

static void
launcherappfree(gpointer data)
{
	LauncherApp *app = data;
	g_object_unref(app->info);
	g_free(app->name);
	g_free(app->folded_name);
	g_free(app->search);
	g_free(app);
}

static char *
launcherfold(const char *text)
{
	char *folded = g_utf8_casefold(text ? text : "", -1);
	char *normalized = g_utf8_normalize(folded, -1, G_NORMALIZE_ALL_COMPOSE);
	g_free(folded);
	return normalized;
}

static gint
launcherappcompare(gconstpointer a, gconstpointer b)
{
	const LauncherApp *one = *(LauncherApp *const *)a;
	const LauncherApp *two = *(LauncherApp *const *)b;
	int order = one->score - two->score;
	if (!order)
		order = g_utf8_collate(one->name, two->name);
	return order ? order : g_strcmp0(g_app_info_get_id(one->info), g_app_info_get_id(two->info));
}

static void
launcherfilter(LauncherModel *model)
{
	char *query = launcherfold(model->query);
	char **words = g_strsplit_set(query, " \t\n", -1);
	guint i, j;
	g_ptr_array_set_size(model->matches, 0);
	model->selected = 0;
	for (i = 0; i < model->apps->len; i++) {
		LauncherApp *app = g_ptr_array_index(model->apps, i);
		for (j = 0; words[j]; j++)
			if (*words[j] && !strstr(app->search, words[j]))
				break;
		if (words[j])
			continue;
		app->score = !strcmp(app->folded_name, query) ? 0
				: g_str_has_prefix(app->folded_name, query) ? 1 : 2;
		g_ptr_array_add(model->matches, app);
	}
	g_ptr_array_sort(model->matches, launcherappcompare);
	g_strfreev(words);
	g_free(query);
}

static void
launchermodelinit(LauncherModel *model)
{
	GList *list, *link;
	unsigned int pending;
	/* dwl has a Wayland event loop, not a GLib main loop. Drain a bounded
	 * number of ready file-monitor events so newly installed entries appear. */
	for (pending = 0; pending < 8 && g_main_context_pending(NULL); pending++)
		g_main_context_iteration(NULL, FALSE);
	list = g_app_info_get_all();
	memset(model, 0, sizeof(*model));
	model->apps = g_ptr_array_new_with_free_func(launcherappfree);
	model->matches = g_ptr_array_new();
	for (link = list; link; link = link->next) {
		GAppInfo *info = link->data;
		LauncherApp *app;
		char *keywords, *search;
		const char *name = g_app_info_get_display_name(info);
		const char *const *keyword_list;
		if (!G_IS_DESKTOP_APP_INFO(info) || !g_app_info_should_show(info)
				|| !name || !g_utf8_validate(name, -1, NULL))
			continue;
		keyword_list = g_desktop_app_info_get_keywords(G_DESKTOP_APP_INFO(info));
		keywords = keyword_list ? g_strjoinv(" ", (char **)keyword_list) : g_strdup("");
		search = g_strjoin(" ", name, keywords,
				g_app_info_get_executable(info) ? g_app_info_get_executable(info) : "",
				g_app_info_get_id(info) ? g_app_info_get_id(info) : "", NULL);
		app = g_new0(LauncherApp, 1);
		app->info = g_object_ref(info);
		app->name = g_strdup(name);
		app->folded_name = launcherfold(name);
		app->search = launcherfold(search);
		g_ptr_array_add(model->apps, app);
		g_free(search);
		g_free(keywords);
	}
	g_list_free_full(list, g_object_unref);
	launcherfilter(model);
}

static void
launchermodelfinish(LauncherModel *model)
{
	g_ptr_array_unref(model->matches);
	g_ptr_array_unref(model->apps);
	memset(model, 0, sizeof(*model));
}

static void
launcherselect(LauncherModel *model, int delta)
{
	if (model->matches->len)
		model->selected = (guint)(((int)model->selected + delta
				% (int)model->matches->len + (int)model->matches->len)
				% (int)model->matches->len);
}

static void
launcherbackspace(LauncherModel *model, int word)
{
	char *end = model->query + strlen(model->query), *previous;
	while ((previous = g_utf8_find_prev_char(model->query, end))) {
		int space = g_unichar_isspace(g_utf8_get_char(previous));
		*previous = '\0';
		end = previous;
		if (!word || (!space && (previous == model->query
				|| g_unichar_isspace(g_utf8_get_char(g_utf8_find_prev_char(model->query, previous))))))
			break;
	}
	launcherfilter(model);
}

static void
launcherappend(LauncherModel *model, gunichar character)
{
	char utf8[6];
	size_t length = strlen(model->query);
	int size;
	if (!g_unichar_validate(character) || !g_unichar_isprint(character))
		return;
	size = g_unichar_to_utf8(character, utf8);
	if (length + (size_t)size >= sizeof(model->query))
		return;
	memcpy(model->query + length, utf8, (size_t)size);
	model->query[length + (size_t)size] = '\0';
	launcherfilter(model);
}
