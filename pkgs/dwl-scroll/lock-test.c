/* Isolated headless-test locker. Never used against the user's display. */
#include <assert.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "ext-session-lock-v1-client-protocol.h"

static struct ext_session_lock_manager_v1 *manager;
static int acquired;

static void
global(void *data, struct wl_registry *registry, uint32_t name,
		const char *interface, uint32_t version)
{
	(void)data;
	(void)version;
	if (!strcmp(interface, ext_session_lock_manager_v1_interface.name))
		manager = wl_registry_bind(registry, name, &ext_session_lock_manager_v1_interface, 1);
}

static void
removed(void *data, struct wl_registry *registry, uint32_t name)
{
	(void)data;
	(void)registry;
	(void)name;
}

static void
locked(void *data, struct ext_session_lock_v1 *lock)
{
	(void)data;
	(void)lock;
	acquired = 1;
}

static void
finished(void *data, struct ext_session_lock_v1 *lock)
{
	(void)data;
	(void)lock;
	assert(!"test lock rejected");
}

int
main(void)
{
	const struct wl_registry_listener registry_listener = {global, removed};
	const struct ext_session_lock_v1_listener lock_listener = {locked, finished};
	struct wl_display *display = wl_display_connect(NULL);
	struct wl_registry *registry;
	struct ext_session_lock_v1 *lock;
	struct pollfd fds[2];
	assert(display);
	registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &registry_listener, NULL);
	assert(wl_display_roundtrip(display) >= 0 && manager);
	lock = ext_session_lock_manager_v1_lock(manager);
	ext_session_lock_v1_add_listener(lock, &lock_listener, NULL);
	while (!acquired)
		assert(wl_display_dispatch(display) >= 0);
	puts("locked");
	fflush(stdout);
	fds[0] = (struct pollfd){STDIN_FILENO, POLLIN, 0};
	fds[1] = (struct pollfd){wl_display_get_fd(display), POLLIN, 0};
	for (;;) {
		char input;
		assert(wl_display_flush(display) >= 0);
		assert(poll(fds, 2, -1) > 0);
		if (fds[0].revents & (POLLIN | POLLHUP)) {
			assert(read(STDIN_FILENO, &input, 1) == 1 && input == 'u');
			break;
		}
		if (fds[1].revents & POLLIN)
			assert(wl_display_dispatch(display) >= 0);
	}
	ext_session_lock_v1_unlock_and_destroy(lock);
	ext_session_lock_manager_v1_destroy(manager);
	wl_registry_destroy(registry);
	assert(wl_display_roundtrip(display) >= 0);
	wl_display_disconnect(display);
	return 0;
}
