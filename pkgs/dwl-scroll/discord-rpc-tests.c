/* Real event-loop/Unix IPC tests. Only contact a test-owned runtime directory. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wayland-server-core.h>

#define DISCORD_RPC_ENABLED 1
#define DISCORD_RPC_CLIENT_ID "123456789012345678"
#define DISCORD_RPC_SHOW_APP 1
#define WLR_ERROR 1
typedef struct { const char *appid, *title; } Client;
static Client *focused_client;
static int locked;
static struct wl_event_loop *event_loop;
static const char *client_get_appid(Client *client) { return client->appid; }
static void wlr_log(int level, const char *message, ...) { (void)level; (void)message; }
#include "discord-rpc.c"

static void
drive(int milliseconds)
{
	gint64 end = g_get_monotonic_time() + milliseconds * 1000;
	do {
		assert(wl_event_loop_dispatch(event_loop, 1) >= 0);
	} while (g_get_monotonic_time() < end);
}

static void
readbytes(int fd, void *buffer, size_t size)
{
	gint64 deadline = g_get_monotonic_time() + 2 * G_USEC_PER_SEC;
	size_t have = 0;
	while (have < size && g_get_monotonic_time() < deadline) {
		ssize_t count = recv(fd, (char *)buffer + have, size - have, 0);
		if (count > 0)
			have += (size_t)count;
		else {
			assert(count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK));
			drive(1);
		}
	}
	assert(have == size);
}

static char *
readframe(int fd, uint32_t *opcode)
{
	uint32_t header[2], size;
	char *data;
	readbytes(fd, header, sizeof(header));
	*opcode = GUINT32_FROM_LE(header[0]);
	size = GUINT32_FROM_LE(header[1]);
	assert(size <= DiscordRpcLimit);
	data = g_malloc(size + 1);
	readbytes(fd, data, size);
	data[size] = '\0';
	return data;
}

static void
sendframe(int fd, uint32_t opcode, const void *data, size_t size)
{
	uint32_t header[] = {GUINT32_TO_LE(opcode), GUINT32_TO_LE((uint32_t)size)};
	assert(send(fd, header, sizeof(header), MSG_NOSIGNAL) == sizeof(header));
	if (size)
		assert(send(fd, data, size, MSG_NOSIGNAL) == (ssize_t)size);
	drive(10);
}

static JsonParser *
readjson(int fd)
{
	uint32_t opcode;
	char *data = readframe(fd, &opcode);
	JsonParser *parser = json_parser_new();
	assert(opcode == 1 && json_parser_load_from_data(parser, data, -1, NULL));
	assert(!strstr(data, "TOP SECRET") && !strstr(data, "window_title"));
	g_free(data);
	return parser;
}

static void
expectactivity(int fd, const char *state)
{
	JsonParser *parser = readjson(fd);
	JsonObject *root = json_node_get_object(json_parser_get_root(parser));
	JsonObject *args = json_object_get_object_member(root, "args");
	assert(!strcmp(json_object_get_string_member(root, "cmd"), "SET_ACTIVITY"));
	assert(json_object_get_int_member(args, "pid") == getpid());
	if (state) {
		JsonObject *activity = json_object_get_object_member(args, "activity");
		JsonObject *timestamps = json_object_get_object_member(activity, "timestamps");
		assert(!strcmp(json_object_get_string_member(activity, "state"), state));
		assert(!strcmp(json_object_get_string_member(activity, "details"), "Wayland compositor: dwl-scroll"));
		assert(json_object_get_int_member(timestamps, "start") == discord_rpc.started);
	} else {
		assert(JSON_NODE_HOLDS_NULL(json_object_get_member(args, "activity")));
	}
	g_object_unref(parser);
}

static int
connectserver(int listener)
{
	uint32_t opcode;
	int fd;
	char *data;
	JsonParser *parser;
	JsonObject *root;
	discord_rpc.next_retry = 0;
	discordrpctick(NULL);
	fd = accept(listener, NULL, NULL);
	assert(fd >= 0 && fcntl(fd, F_SETFL, O_NONBLOCK) == 0);
	data = readframe(fd, &opcode);
	parser = json_parser_new();
	assert(opcode == 0 && json_parser_load_from_data(parser, data, -1, NULL));
	root = json_node_get_object(json_parser_get_root(parser));
	assert(json_object_get_int_member(root, "v") == 1);
	assert(!strcmp(json_object_get_string_member(root, "client_id"), DISCORD_RPC_CLIENT_ID));
	g_object_unref(parser);
	g_free(data);
	return fd;
}

static void
ready(int fd)
{
	const char payload[] = "{\"cmd\":\"DISPATCH\",\"evt\":\"READY\",\"data\":{\"v\":1}}";
	sendframe(fd, 1, payload, strlen(payload));
	assert(discord_rpc.ready);
}

int
main(void)
{
	Client editor = {"rpc-test-editor", "TOP SECRET WINDOW TITLE"};
	Client other = {"other\"app\n", "TOP SECRET OTHER WINDOW TITLE"};
	struct sockaddr_un address = {.sun_family = AF_UNIX};
	char *root = g_dir_make_tmp("dwl-rpc-test-XXXXXX", NULL), *applications, *desktop;
	char *state, *payload;
	uint32_t opcode;
	int listener, fd, send_buffer = 512;
	gint64 started;
	assert(root);
	g_setenv("XDG_RUNTIME_DIR", root, TRUE);
	g_setenv("XDG_DATA_HOME", root, TRUE);
	g_setenv("XDG_DATA_DIRS", root, TRUE);
	applications = g_build_filename(root, "applications", NULL);
	desktop = g_build_filename(applications, "rpc-test-editor.desktop", NULL);
	assert(g_mkdir(applications, 0700) == 0);
	assert(g_file_set_contents(desktop, "[Desktop Entry]\nType=Application\nName=Test Editor\nExec=true\n", -1, NULL));
	event_loop = wl_event_loop_create();
	assert(event_loop);
	focused_client = &editor;
	started = g_get_monotonic_time();
	discordrpcsetup();
	assert(discord_rpc.fd == -1 && g_get_monotonic_time() - started < G_USEC_PER_SEC);
	assert(g_snprintf(address.sun_path, sizeof(address.sun_path), "%s/discord-ipc-0", root) < (int)sizeof(address.sun_path));
	listener = socket(AF_UNIX, SOCK_STREAM, 0);
	assert(listener >= 0 && bind(listener, (struct sockaddr *)&address, sizeof(address)) == 0);
	assert(listen(listener, 4) == 0 && fcntl(listener, F_SETFL, O_NONBLOCK) == 0);
	fd = connectserver(listener);
	/* READY must work even when the IPC header arrives in fragments. */
	{
		const char text[] = "{\"evt\":\"READY\"}";
		uint32_t header[] = {GUINT32_TO_LE(1), GUINT32_TO_LE(sizeof(text) - 1)};
		assert(send(fd, header, 5, MSG_NOSIGNAL) == 5);
		drive(10);
		assert(!discord_rpc.ready);
		assert(send(fd, (char *)header + 5, 3, MSG_NOSIGNAL) == 3);
		assert(send(fd, text, sizeof(text) - 1, MSG_NOSIGNAL) == sizeof(text) - 1);
		drive(10);
	}
	expectactivity(fd, "Application: Test Editor");
	state = discordrpcstate(0);
	assert(!strcmp(state, "Desktop"));
	g_free(state);
	discord_rpc.next_update = 0;
	discordrpctick(NULL);
	assert(!discord_rpc.output->len); /* Unchanged activities are not resent. */
	focused_client = &other;
	discordrpctick(NULL);
	assert(!strcmp(discord_rpc.last_state, "Application: Test Editor")); /* rate limit */
	discord_rpc.next_update = 0;
	discordrpctick(NULL);
	expectactivity(fd, "Application: other\"app");
	sendframe(fd, 3, "\0\1\2", 3);
	payload = readframe(fd, &opcode);
	assert(opcode == 4 && !memcmp(payload, "\0\1\2", 3));
	g_free(payload);
	locked = 1;
	discordrpcpause();
	expectactivity(fd, NULL);
	assert(discord_rpc.fd == -1);
	discord_rpc.next_retry = 0;
	discordrpctick(NULL);
	assert(discord_rpc.fd == -1); /* No reconnection or app reads while locked. */
	close(fd);
	locked = 0;
	fd = connectserver(listener);
	ready(fd);
	expectactivity(fd, "Application: other\"app");
	sendframe(fd, 2, "{}", 2);
	assert(discord_rpc.fd == -1);
	close(fd);
	fd = connectserver(listener);
	sendframe(fd, 1, "{bad JSON", 9);
	assert(discord_rpc.fd == -1);
	close(fd);
	fd = connectserver(listener);
	{
		uint32_t header[] = {GUINT32_TO_LE(1), GUINT32_TO_LE(DiscordRpcLimit + 1)};
		assert(send(fd, header, sizeof(header), MSG_NOSIGNAL) == sizeof(header));
		drive(10);
		assert(discord_rpc.fd == -1);
	}
	close(fd);
	fd = connectserver(listener);
	ready(fd);
	expectactivity(fd, "Application: other\"app");
	/* Partial writes/backpressure must never stall the compositor. */
	assert(setsockopt(discord_rpc.fd, SOL_SOCKET, SO_SNDBUF, &send_buffer, sizeof(send_buffer)) == 0);
	payload = g_malloc0(DiscordRpcLimit);
	assert(discordrpcqueue(4, payload, DiscordRpcLimit));
	g_free(payload);
	discordrpcflush();
	assert(discord_rpc.output->len > 0);
	discordrpcpause();
	assert(discord_rpc.fd == -1);
	close(fd);
	focused_client = NULL;
	fd = connectserver(listener);
	ready(fd);
	expectactivity(fd, "Desktop");
	discordrpcfinish();
	expectactivity(fd, NULL);
	close(fd);
	close(listener);
	wl_event_loop_destroy(event_loop);
	assert(g_remove(address.sun_path) == 0 && g_remove(desktop) == 0);
	assert(g_rmdir(applications) == 0 && g_rmdir(root) == 0);
	g_free(desktop);
	g_free(applications);
	g_free(root);
	puts("PASS: Discord RPC handshake, activity/privacy, rate limiting, ping, lock/shutdown clearing, malformed frames, reconnect and backpressure");
	return 0;
}
