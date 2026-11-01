/* Opt-in Discord Rich Presence over local IPC. All socket I/O is nonblocking
 * and bounded, on dwl's event loop. Never read window titles or account tokens. */
#include <errno.h>
#include <fcntl.h>
#include <gio/gdesktopappinfo.h>
#include <glib/gstdio.h>
#include <json-glib/json-glib.h>
#include <sys/socket.h>
#include <sys/un.h>

#ifndef DISCORD_RPC_ENABLED
#define DISCORD_RPC_ENABLED 0
#endif
#ifndef DISCORD_RPC_CLIENT_ID
#define DISCORD_RPC_CLIENT_ID NULL
#endif
#ifndef DISCORD_RPC_SHOW_APP
#define DISCORD_RPC_SHOW_APP 0
#endif

enum { DiscordRpcLimit = 65536, DiscordRpcInterval = 15, DiscordRpcRetry = 5 };

static struct {
	int fd, connecting, ready;
	struct wl_event_source *io, *timer;
	GByteArray *input, *output;
	char *last_state;
	gint64 started, connected_at, next_retry, next_update, last_warning;
	unsigned int nonce;
} discord_rpc = {.fd = -1};

static gint64
discordrpcnow(void)
{
	return g_get_monotonic_time() / G_USEC_PER_SEC;
}

static void
discordrpcdrop(void)
{
	if (discord_rpc.io)
		wl_event_source_remove(discord_rpc.io);
	discord_rpc.io = NULL;
	if (discord_rpc.fd >= 0)
		close(discord_rpc.fd);
	discord_rpc.fd = -1;
	discord_rpc.ready = discord_rpc.connecting = 0;
	discord_rpc.next_retry = discordrpcnow() + DiscordRpcRetry;
	g_clear_pointer(&discord_rpc.last_state, g_free);
	if (discord_rpc.input)
		g_byte_array_set_size(discord_rpc.input, 0);
	if (discord_rpc.output)
		g_byte_array_set_size(discord_rpc.output, 0);
}

static void
discordrpcinterest(void)
{
	if (discord_rpc.io)
		wl_event_source_fd_update(discord_rpc.io, WL_EVENT_READABLE
				| (discord_rpc.connecting || discord_rpc.output->len ? WL_EVENT_WRITABLE : 0));
}

static int
discordrpcqueue(uint32_t opcode, const void *payload, size_t length)
{
	uint32_t header[2];
	if (discord_rpc.fd < 0)
		return 0;
	if (length > DiscordRpcLimit || discord_rpc.output->len + length + 8 > 2 * DiscordRpcLimit) {
		discordrpcdrop();
		return 0;
	}
	header[0] = GUINT32_TO_LE(opcode);
	header[1] = GUINT32_TO_LE((uint32_t)length);
	g_byte_array_append(discord_rpc.output, (const guint8 *)header, sizeof(header));
	g_byte_array_append(discord_rpc.output, payload, (guint)length);
	discordrpcinterest();
	return 1;
}

static void
discordrpcflush(void)
{
	while (discord_rpc.fd >= 0 && !discord_rpc.connecting && discord_rpc.output->len) {
		ssize_t written = send(discord_rpc.fd, discord_rpc.output->data,
				discord_rpc.output->len, MSG_NOSIGNAL);
		if (written > 0) {
			g_byte_array_remove_range(discord_rpc.output, 0, (guint)written);
		} else if (written < 0 && errno == EINTR) {
			continue;
		} else if (written < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
			break;
		} else {
			discordrpcdrop();
		}
	}
	discordrpcinterest();
}

static char *
discordrpcstate(int show_app)
{
	const char *id;
	GDesktopAppInfo *info = NULL;
	GString *state;
	char *filename, *valid, *limited;
	const char *p;
	if (locked || !show_app || !focused_client)
		return g_strdup("Desktop");
	id = client_get_appid(focused_client);
	if (!id || !*id)
		return g_strdup("Desktop");
	filename = g_str_has_suffix(id, ".desktop") ? g_strdup(id) : g_strconcat(id, ".desktop", NULL);
	if (!strchr(filename, '/') && strlen(filename) <= 256)
		info = g_desktop_app_info_new(filename);
	g_free(filename);
	limited = g_strndup(info ? g_app_info_get_display_name(G_APP_INFO(info)) : id, 1024);
	valid = g_utf8_make_valid(limited, -1);
	g_free(limited);
	state = g_string_new("Application: ");
	for (p = valid; *p; p = g_utf8_next_char(p)) {
		gunichar character = g_utf8_get_char(p);
		if (state->len + (size_t)(g_utf8_next_char(p) - p) > 120)
			break;
		if (g_unichar_isprint(character))
			g_string_append_unichar(state, character);
	}
	g_free(valid);
	g_clear_object(&info);
	return g_string_free(state, FALSE);
}

static void
discordrpcactivity(const char *state)
{
	JsonBuilder *builder = json_builder_new();
	JsonGenerator *generator = json_generator_new();
	JsonNode *root;
	char *payload, *nonce = g_strdup_printf("dwl-%u", ++discord_rpc.nonce);
	gsize length;
	json_builder_begin_object(builder);
	json_builder_set_member_name(builder, "cmd");
	json_builder_add_string_value(builder, "SET_ACTIVITY");
	json_builder_set_member_name(builder, "nonce");
	json_builder_add_string_value(builder, nonce);
	json_builder_set_member_name(builder, "args");
	json_builder_begin_object(builder);
	json_builder_set_member_name(builder, "pid");
	json_builder_add_int_value(builder, getpid());
	json_builder_set_member_name(builder, "activity");
	if (!state) {
		json_builder_add_null_value(builder);
	} else {
		json_builder_begin_object(builder);
		json_builder_set_member_name(builder, "type");
		json_builder_add_int_value(builder, 0);
		json_builder_set_member_name(builder, "details");
		json_builder_add_string_value(builder, "Wayland compositor: dwl-scroll");
		json_builder_set_member_name(builder, "state");
		json_builder_add_string_value(builder, state);
		json_builder_set_member_name(builder, "timestamps");
		json_builder_begin_object(builder);
		json_builder_set_member_name(builder, "start");
		json_builder_add_int_value(builder, discord_rpc.started);
		json_builder_end_object(builder);
		json_builder_end_object(builder);
	}
	json_builder_end_object(builder);
	json_builder_end_object(builder);
	root = json_builder_get_root(builder);
	json_generator_set_root(generator, root);
	payload = json_generator_to_data(generator, &length);
	discordrpcqueue(1, payload, length);
	g_free(payload);
	g_free(nonce);
	json_node_free(root);
	g_object_unref(generator);
	g_object_unref(builder);
}

static void
discordrpcpublish(void)
{
	char *state;
	if (!discord_rpc.ready || locked)
		return;
	state = discordrpcstate(DISCORD_RPC_SHOW_APP);
	if (g_strcmp0(state, discord_rpc.last_state)) {
		discordrpcactivity(state);
		if (discord_rpc.fd >= 0) {
			g_free(discord_rpc.last_state);
			discord_rpc.last_state = g_strdup(state);
			discordrpcflush();
		}
	}
	discord_rpc.next_update = discordrpcnow() + DiscordRpcInterval;
	g_free(state);
}

static const char *
discordrpcstring(JsonObject *object, const char *member)
{
	JsonNode *node = json_object_get_member(object, member);
	return node && JSON_NODE_HOLDS_VALUE(node) && json_node_get_value_type(node) == G_TYPE_STRING
			? json_node_get_string(node) : NULL;
}

static void
discordrpcframe(uint32_t opcode, const guint8 *data, guint length)
{
	JsonParser *parser;
	JsonNode *root;
	JsonObject *object;
	GError *error = NULL;
	const char *event;
	if (opcode == 3) {
		discordrpcqueue(4, data, length);
		return;
	}
	if (opcode == 4)
		return;
	if (opcode != 1) {
		discordrpcdrop();
		return;
	}
	parser = json_parser_new();
	if (!json_parser_load_from_data(parser, (const char *)data, length, &error)
			|| !(root = json_parser_get_root(parser)) || !JSON_NODE_HOLDS_OBJECT(root)) {
		g_clear_error(&error);
		g_object_unref(parser);
		discordrpcdrop();
		return;
	}
	object = json_node_get_object(root);
	event = discordrpcstring(object, "evt");
	if (!g_strcmp0(event, "READY") && !discord_rpc.ready) {
		discord_rpc.ready = 1;
		discordrpcpublish();
	} else if (!g_strcmp0(event, "ERROR")) {
		/* Discord/socket data is untrusted: never print its arbitrary messages. */
		if (discordrpcnow() - discord_rpc.last_warning >= 60) {
			wlr_log(WLR_ERROR, "Discord RPC rejected a request; check the application ID and activity privacy settings");
			discord_rpc.last_warning = discordrpcnow();
		}
		if (!discord_rpc.ready)
			discordrpcdrop();
		else
			g_clear_pointer(&discord_rpc.last_state, g_free);
	}
	g_object_unref(parser);
}

static void
discordrpchandshake(void)
{
	char *payload = g_strdup_printf("{\"v\":1,\"client_id\":\"%s\"}", DISCORD_RPC_CLIENT_ID);
	discordrpcqueue(0, payload, strlen(payload));
	g_free(payload);
}

static int
discordrpcreadable(int fd, uint32_t mask, void *data)
{
	guint8 buffer[4096];
	(void)data;
	if (discord_rpc.connecting) {
		int error = 0;
		socklen_t size = sizeof(error);
		if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &size) || error) {
			discordrpcdrop();
			return 0;
		}
		discord_rpc.connecting = 0;
		discordrpchandshake();
	}
	if (mask & WL_EVENT_READABLE) {
		/* Bound work per callback as well as frame sizes: an IPC peer cannot
		 * monopolize the compositor by streaming endless small messages. */
		unsigned int reads;
		for (reads = 0; reads < 32 && discord_rpc.fd >= 0; reads++) {
			ssize_t length = recv(fd, buffer, sizeof(buffer), 0);
			if (length < 0 && errno == EINTR)
				continue;
			if (length < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
				break;
			if (length <= 0 || discord_rpc.input->len + (size_t)length > 2 * DiscordRpcLimit + 8) {
				discordrpcdrop();
				return 0;
			}
			g_byte_array_append(discord_rpc.input, buffer, (guint)length);
			while (discord_rpc.input->len >= 8) {
				uint32_t header[2], opcode, size;
				memcpy(header, discord_rpc.input->data, sizeof(header));
				opcode = GUINT32_FROM_LE(header[0]);
				size = GUINT32_FROM_LE(header[1]);
				if (size > DiscordRpcLimit || opcode > 4) {
					discordrpcdrop();
					return 0;
				}
				if (discord_rpc.input->len < size + 8)
					break;
				discordrpcframe(opcode, discord_rpc.input->data + 8, size);
				if (discord_rpc.fd < 0)
					return 0;
				g_byte_array_remove_range(discord_rpc.input, 0, size + 8);
			}
		}
	}
	if (mask & (WL_EVENT_HANGUP | WL_EVENT_ERROR))
		discordrpcdrop();
	else
		discordrpcflush();
	return 0;
}

static void
discordrpcconnect(void)
{
	const char *runtime = getenv("XDG_RUNTIME_DIR");
	const char *subdirs[] = {"", "app/com.discordapp.Discord", "snap.discord"};
	GStatBuf info;
	size_t directory;
	int index;
	discord_rpc.next_retry = discordrpcnow() + DiscordRpcRetry;
	/* dwl already requires a private runtime directory. Do not send focused
	 * application information to arbitrary sockets in shared /tmp folders. */
	if (!runtime || g_stat(runtime, &info) || !S_ISDIR(info.st_mode)
			|| info.st_uid != geteuid() || (info.st_mode & 0077))
		return;
	for (directory = 0; directory < sizeof(subdirs) / sizeof(subdirs[0]); directory++) {
		for (index = 0; index < 10; index++) {
			struct sockaddr_un address = {.sun_family = AF_UNIX};
			char *path = g_strdup_printf("%s/%s%sdiscord-ipc-%d", runtime, subdirs[directory],
					*subdirs[directory] ? "/" : "", index);
			int fd, connected;
			if (g_strlcpy(address.sun_path, path, sizeof(address.sun_path)) >= sizeof(address.sun_path)) {
				g_free(path);
				continue;
			}
			g_free(path);
			fd = socket(AF_UNIX, SOCK_STREAM, 0);
			if (fd < 0)
				continue;
			if (fcntl(fd, F_SETFD, FD_CLOEXEC) || fcntl(fd, F_SETFL, O_NONBLOCK)) {
				close(fd);
				continue;
			}
			connected = connect(fd, (struct sockaddr *)&address, sizeof(address));
			if (connected < 0 && errno != EINPROGRESS) {
				close(fd);
				continue;
			}
#ifdef SO_PEERCRED
			if (!connected) {
				struct { pid_t pid; uid_t uid; gid_t gid; } peer;
				socklen_t size = sizeof(peer);
				if (getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &peer, &size) || peer.uid != geteuid()) {
					close(fd);
					continue;
				}
			}
#endif
			discord_rpc.fd = fd;
			discord_rpc.connecting = connected < 0;
			discord_rpc.connected_at = discordrpcnow();
			discord_rpc.io = wl_event_loop_add_fd(event_loop, fd, WL_EVENT_READABLE
					| WL_EVENT_WRITABLE, discordrpcreadable, NULL);
			if (!discord_rpc.io) {
				discordrpcdrop();
				return;
			}
			if (!discord_rpc.connecting)
				discordrpchandshake();
			discordrpcflush();
			return;
		}
	}
}

static void
discordrpcpause(void)
{
	if (discord_rpc.ready && !discord_rpc.output->len) {
		/* Never splice a clear into a partially written frame. Disconnect is
		 * the fallback if the nonblocking clear cannot be written intact. */
		discordrpcactivity(NULL);
		discordrpcflush();
	}
	discordrpcdrop();
}

static int
discordrpctick(void *data)
{
	gint64 now = discordrpcnow();
	(void)data;
	if (discord_rpc.timer)
		wl_event_source_timer_update(discord_rpc.timer, 1000);
	if (locked) {
		if (discord_rpc.fd >= 0)
			discordrpcpause();
	} else if (discord_rpc.fd < 0) {
		if (now >= discord_rpc.next_retry)
			discordrpcconnect();
	} else if (!discord_rpc.ready && now - discord_rpc.connected_at >= 5) {
		discordrpcdrop();
	} else if (discord_rpc.ready && now >= discord_rpc.next_update) {
		discordrpcpublish();
	}
	return 0;
}

static void
discordrpcsetup(void)
{
	const char *id = DISCORD_RPC_CLIENT_ID, *p;
	if (!DISCORD_RPC_ENABLED)
		return;
	if (!id || strlen(id) < 17 || strlen(id) > 20)
		return;
	for (p = id; *p; p++)
		if (!g_ascii_isdigit(*p))
			return;
	discord_rpc.input = g_byte_array_new();
	discord_rpc.output = g_byte_array_new();
	discord_rpc.started = time(NULL);
	discord_rpc.timer = wl_event_loop_add_timer(event_loop, discordrpctick, NULL);
	if (discord_rpc.timer)
		discordrpctick(NULL);
}

static void
discordrpcfinish(void)
{
	if (discord_rpc.timer)
		wl_event_source_remove(discord_rpc.timer);
	discord_rpc.timer = NULL;
	discordrpcpause();
	g_clear_pointer(&discord_rpc.input, g_byte_array_unref);
	g_clear_pointer(&discord_rpc.output, g_byte_array_unref);
}
