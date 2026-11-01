/* Algorithm/scene-adapter tests, NOT a wlroots compositor runtime test.
 * Compile the exact patched scroll.c; only dwl's external effects are mocked. */
#include <assert.h>
#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-util.h>

#define MAX(a,b) ((a) > (b) ? (a) : (b))
#define MIN(a,b) ((a) < (b) ? (a) : (b))
#define LENGTH(a) (sizeof(a) / sizeof((a)[0]))
#define VISIBLEON(c,m) ((m) && (c)->mon == (m) && ((c)->tags & (m)->tagset[(m)->seltags]))
typedef union { int i; unsigned int ui; float f; const void *v; } Arg;
struct wlr_box { int x, y, width, height; };
struct node { int x, y, enabled; struct wlr_box clip; };
struct tree { struct node node; };
struct rect { struct node node; int width, height; };
typedef struct Monitor Monitor;
typedef struct {
	struct wl_list link, clients;
	float fraction, restore_fraction;
	int x, width;
} Column;
typedef struct Client {
	Monitor *mon;
	Column *column;
	struct wl_list column_link, flink;
	uint32_t tags;
	int isfloating, isfullscreen, mapped;
	unsigned int bw;
	int clipx, clipy;
	struct wlr_box geom;
	struct tree *scene, *scene_surface;
	struct rect *border[4];
} Client;
typedef struct { void (*arrange)(Monitor *); } Layout;
struct Monitor {
	struct wl_list columns;
	const Layout *lt[2];
	unsigned int sellt, seltags;
	uint32_t tagset[2];
	struct wlr_box w;
	double scrolloffset[32];
	Client *scrollfocus;
	uint32_t scrolltags;
	struct wlr_box scrollarea;
	int scrollinsert;
};
static struct wl_list fstack;
static Monitor *selmon;
static const float scroll_width = 0.55f;
static const float scroll_widths[] = {0.33f, 0.5f, 0.67f, 1.0f};
static const int scroll_column_gap = 12, scroll_window_gap = 8, scroll_padding = 12;
static const int scroll_center = 0, scroll_step = 160;
static void scrolling(Monitor *m);
static void scrollclip(Client *c, struct wlr_box clip);
static void *ecalloc(size_t n, size_t size) { void *p = calloc(n, size); assert(p); return p; }
static int client_is_unmanaged(Client *c) { (void)c; return 0; }
static Client *client_surface(Client *c) { return c; }
static void client_get_size_hints(Client *c, struct wlr_box *max, struct wlr_box *min) {
	(void)c; *max = *min = (struct wlr_box){0};
}
static Client *focustop(Monitor *m) {
	Client *c;
	wl_list_for_each(c, &fstack, flink) if (VISIBLEON(c, m)) return c;
	return NULL;
}
static void arrange(Monitor *m) {
	Client *c;
	wl_list_for_each(c, &fstack, flink)
		if (c->mon == m) c->scene->node.enabled = VISIBLEON(c, m);
	m->lt[m->sellt]->arrange(m);
}
static void focusclient(Client *c, int lift) {
	(void)lift;
	wl_list_remove(&c->flink);
	wl_list_insert(&fstack, &c->flink);
	selmon = c->mon;
	arrange(selmon);
}
static int wlr_box_intersection(struct wlr_box *out, const struct wlr_box *a, const struct wlr_box *b) {
	int x = MAX(a->x, b->x), y = MAX(a->y, b->y);
	int w = MIN(a->x + a->width, b->x + b->width) - x;
	int h = MIN(a->y + a->height, b->y + b->height) - y;
	*out = (struct wlr_box){x, y, MAX(0, w), MAX(0, h)};
	return w > 0 && h > 0;
}
static void wlr_scene_node_set_enabled(struct node *n, int enabled) { n->enabled = enabled; }
static void wlr_scene_node_set_position(struct node *n, int x, int y) { n->x = x; n->y = y; }
static void wlr_scene_rect_set_size(struct rect *r, int w, int h) { r->width = w; r->height = h; }
static void wlr_scene_subsurface_tree_set_clip(struct node *n, const struct wlr_box *box) { n->clip = *box; }
static void resize(Client *c, struct wlr_box box, int interact) {
	(void)interact;
	c->geom = box;
	scrollclip(c, (struct wlr_box){c->clipx, c->clipy, box.width - (int)c->bw, box.height - (int)c->bw});
}
#include "scroll.c"

static const Layout layout = {scrolling};
static Client *allocated[512];
static size_t count;
static void initmon(Monitor *m, int x) {
	memset(m, 0, sizeof(*m));
	wl_list_init(&m->columns);
	m->lt[0] = &layout;
	m->tagset[0] = 1;
	m->scrollinsert = 1;
	m->w = (struct wlr_box){x, 0, 1000, 800};
}
static Client *openclient(Monitor *m, uint32_t tags) {
	Client *c = ecalloc(1, sizeof(*c));
	size_t i;
	assert(count < LENGTH(allocated));
	allocated[count++] = c;
	c->mon = m; c->tags = tags; c->mapped = 1; c->bw = 2;
	c->scene = ecalloc(1, sizeof(*c->scene));
	c->scene_surface = ecalloc(1, sizeof(*c->scene_surface));
	for (i = 0; i < 4; i++) c->border[i] = ecalloc(1, sizeof(*c->border[i]));
	wl_list_insert(&fstack, &c->flink);
	scrollattach(c);
	arrange(m);
	return c;
}
static void closeclient(Client *c) {
	Monitor *m = c->mon;
	scrolldetach(c);
	c->mon = NULL;
	wl_list_remove(&c->flink);
	arrange(m);
}
static void assertclipped(Client *c) {
	size_t i;
	if (!c->scene->node.enabled) return;
	if (c->scene_surface->node.enabled) {
		struct wlr_box b = c->scene_surface->node.clip;
		b.x += c->geom.x + (int)c->bw - c->clipx;
		b.y += c->geom.y + (int)c->bw - c->clipy;
		assert(b.x >= c->mon->w.x && b.y >= c->mon->w.y);
		assert(b.x + b.width <= c->mon->w.x + c->mon->w.width);
		assert(b.y + b.height <= c->mon->w.y + c->mon->w.height);
	}
	for (i = 0; i < 4; i++) {
		struct rect *r = c->border[i];
		if (!r->width || !r->height) continue;
		assert(c->geom.x + r->node.x >= c->mon->w.x);
		assert(c->geom.x + r->node.x + r->width <= c->mon->w.x + c->mon->w.width);
	}
}
int main(void) {
	Monitor a, b;
	Client *one, *two, *three, *stacked, *hidden;
	Column *identity;
	double offset;
	int width;
	float fraction;
	size_t i, j;
	wl_list_init(&fstack);
	initmon(&a, 0); initmon(&b, 1000); selmon = &a;
	assert(scrollactive(&a) && !scrollactive(NULL));
	scrollmaximize(&(Arg){0}); /* no focused window */
	one = openclient(&a, 1); width = one->geom.width; identity = one->column;
	two = openclient(&a, 1); three = openclient(&a, 1);
	assert(one->column == identity && one->geom.width == width);
	assert(wl_list_length(&a.columns) == 3 && a.scrolloffset[1] > 0);
	assert(three->geom.x + three->geom.width <= a.w.width);
	scrollfocuscolumn(&(Arg){.i = -1}); assert(focustop(&a) == two);
	scrollfocuscolumn(&(Arg){.i = -1}); assert(focustop(&a) == one);
	assert(one->geom.x >= 0);
	scrollpan(&(Arg){.i = 1}); offset = a.scrolloffset[1]; arrange(&a);
	assert(a.scrolloffset[1] == offset && focustop(&a) == one);
	a.scrollinsert = 0; stacked = openclient(&a, 1);
	assert(stacked->column == identity && one->geom.height < a.w.height / 2);
	scrollfocuswindow(&(Arg){.i = -1}); assert(focustop(&a) == one);
	scrollfocuswindow(&(Arg){.i = 1}); assert(focustop(&a) == stacked);
	stacked->isfloating = 1; arrange(&a);
	scrollmaximize(&(Arg){0});
	assert(stacked->column->fraction == scroll_width && stacked->column->restore_fraction == 0);
	assert(stacked->column == identity && one->geom.height > a.w.height / 2);
	stacked->isfloating = 0; stacked->isfullscreen = 1; arrange(&a);
	scrollmaximize(&(Arg){0});
	assert(stacked->column->fraction == scroll_width && stacked->column->restore_fraction == 0);
	assert(stacked->column == identity); stacked->isfullscreen = 0;
	focusclient(three, 1); offset = a.scrolloffset[1];
	a.tagset[0] = 2; hidden = openclient(&a, 2); assert(a.scrolloffset[2] == 0);
	a.tagset[0] = 1; arrange(&a); assert(a.scrolloffset[1] == offset);
	a.tagset[0] = 3; arrange(&a); assert(scrollslot(&a) == 0);
	a.tagset[0] = 1u << 30; assert(scrollslot(&a) == 31);
	a.tagset[0] = 1;
	focusclient(stacked, 1);
	a.w.width = 600; arrange(&a);
	assert(stacked->geom.x >= 0 && stacked->geom.x + stacked->geom.width <= a.w.width);
	/* Exercise clipping both sides, including a border-only intersection. */
	for (i = 0; i < count; i++) if (allocated[i]->mon == &a) assertclipped(allocated[i]);
	resize(one, (struct wlr_box){599, 0, 400, 500}, 0); assertclipped(one);
	assert(!one->scene_surface->node.enabled);
	one->clipx = 15; one->clipy = 30; /* client-side shadow/window geometry */
	resize(one, (struct wlr_box){-200, 0, 400, 500}, 0); assertclipped(one);
	/* Same ownership sequence as setmon, including a different output origin. */
	scrolldetach(three); three->mon = &b; selmon = &b; scrollattach(three); arrange(&a); arrange(&b);
	assert(three->column && three->geom.x >= b.w.x);
	assert(b.scrolloffset[1] == 0); assertclipped(three);
	closeclient(hidden); closeclient(two); closeclient(one); closeclient(stacked); closeclient(three);
	assert(wl_list_empty(&a.columns) && wl_list_empty(&b.columns));
	assert(a.scrolloffset[1] == 0 && b.scrolloffset[1] == 0);
	/* Movement operates on explicit memberships, independent of MRU order. */
	selmon = &a; a.scrollinsert = 1;
	one = openclient(&a, 1); two = openclient(&a, 1); three = openclient(&a, 1);
	identity = two->column;
	scrollmovecolumn(&(Arg){.i = -1});
	assert(three->column->link.next == &identity->link);
	scrolltransfer(&(Arg){.i = 1});
	assert(three->column == identity && wl_list_length(&a.columns) == 2);
	scrollmovewindow(&(Arg){.i = -1});
	assert(scrollfirst(identity, &a) == three);
	scrollsplit(&(Arg){.i = 1});
	assert(three->column != identity && wl_list_length(&a.columns) == 3);
	scrollmerge(&(Arg){.i = -1});
	assert(three->column == identity && wl_list_length(&a.columns) == 2);
	scrollsetinsert(&(Arg){.i = -1}); hidden = openclient(&a, 1);
	assert(hidden->column->link.next == &identity->link);
	scrollsetinsert(&(Arg){.i = 2}); assert(a.scrollinsert == 0);
	stacked = openclient(&a, 1); assert(stacked->column == hidden->column);
	/* Maximize the whole column, without fullscreen, then restore its width. */
	identity = stacked->column; fraction = identity->fraction;
	scrollmaximize(&(Arg){0});
	assert(identity->fraction == 1.0f && identity->restore_fraction == fraction);
	assert(stacked->geom.width == hidden->geom.width && !stacked->isfullscreen);
	scrollmaximize(&(Arg){0});
	assert(identity->fraction == fraction && identity->restore_fraction == 0);
	/* Restore widths belong to individual columns, not a global toggle. */
	scrollmaximize(&(Arg){0});
	focusclient(one, 1); scrollmaximize(&(Arg){0});
	assert(one->column->restore_fraction == scroll_width);
	focusclient(stacked, 1); scrollmaximize(&(Arg){0});
	assert(identity->fraction == fraction && one->column->fraction == 1.0f);
	focusclient(one, 1); scrollmaximize(&(Arg){0});
	assert(one->column->fraction == scroll_width);
	focusclient(stacked, 1);
	/* Explicit resize/preset changes end maximization and establish a new width. */
	scrollmaximize(&(Arg){0}); scrollwidth(&(Arg){.f = -0.1f});
	fraction = identity->fraction;
	assert(identity->restore_fraction == 0);
	scrollmaximize(&(Arg){0}); scrollmaximize(&(Arg){0});
	assert(identity->fraction == fraction);
	scrollmaximize(&(Arg){0}); scrollpreset(&(Arg){0});
	assert(identity->fraction == scroll_widths[0] && identity->restore_fraction == 0);
	/* Expelling a row preserves both the maximized width and its restore width. */
	scrollmaximize(&(Arg){0}); scrollsplit(&(Arg){.i = 1});
	assert(stacked->column != identity && stacked->column->restore_fraction == scroll_widths[0]);
	scrollmaximize(&(Arg){0}); assert(stacked->column->fraction == scroll_widths[0]);
	scrollmerge(&(Arg){.i = -1});
	scrollmaximize(&(Arg){0}); /* restore the original column before continuing */
	scrollwidth(&(Arg){.f = 100}); assert(stacked->column->fraction == 1.0f);
	scrollwidth(&(Arg){.f = -100}); assert(stacked->column->fraction == 0.1f);
	scrollpreset(&(Arg){0}); assert(stacked->column->fraction == scroll_widths[0]);
	/* A hidden tag in a mixed column must not be swept into a merge. */
	hidden->tags = 2;
	identity = hidden->column;
	scrollmerge(&(Arg){.i = 1});
	assert(hidden->column == identity && stacked->column != identity);
	closeclient(hidden); closeclient(stacked); closeclient(one); closeclient(two); closeclient(three);
	assert(wl_list_empty(&a.columns));
	/* Deterministic adversarial sequences catch stale memberships and UAFs. */
	for (i = 0; i < 60; i++) {
		selmon = i % 2 ? &a : &b;
		openclient(selmon, i % 3 ? 1 : 2);
	}
	srand(7);
	for (i = 0; i < 3000; i++) {
		Client *c = allocated[(size_t)rand() % count];
		Column *col;
		Client *member;
		Monitor *m;
		int direction = rand() % 2 ? 1 : -1;
		if (!c->mon) continue;
		selmon = c->mon;
		if (VISIBLEON(c, selmon)) focusclient(c, 1);
		switch (rand() % 12) {
		case 0: scrollmovecolumn(&(Arg){.i = direction}); break;
		case 1: scrollmovewindow(&(Arg){.i = direction}); break;
		case 2: scrolltransfer(&(Arg){.i = direction}); break;
		case 3: scrollsplit(&(Arg){.i = direction}); break;
		case 4: scrollmerge(&(Arg){.i = direction}); break;
		case 5: scrollpan(&(Arg){.i = direction}); break;
		case 6:
			m = c->mon; scrolldetach(c); c->mon = m == &a ? &b : &a;
			scrollattach(c); arrange(m); arrange(c->mon); break;
		case 7: selmon->tagset[0] = 1u << (rand() % 2); arrange(selmon); break;
		case 8:
			c->isfloating = !c->isfloating; if (!c->isfloating) scrollattach(c);
			selmon->scrollfocus = NULL; arrange(selmon); break;
		case 9: selmon->w.width = 600 + rand() % 600; arrange(selmon); break;
		case 10: closeclient(c); break;
		case 11: scrollmaximize(&(Arg){0}); break;
		}
		for (j = 0; j < 2; j++) {
			m = j ? &a : &b;
			wl_list_for_each(col, &m->columns, link) {
				assert(!wl_list_empty(&col->clients));
				wl_list_for_each(member, &col->clients, column_link) {
					assert(member->mon == m && member->column == col);
					if (scrollvisible(member, m)) assertclipped(member);
				}
			}
		}
	}
	for (i = 0; i < count; i++) if (allocated[i]->mon) closeclient(allocated[i]);
	assert(wl_list_empty(&a.columns) && wl_list_empty(&b.columns));
	for (i = 0; i < count; i++) {
		for (j = 0; j < 4; j++) free(allocated[i]->border[j]);
		free(allocated[i]->scene); free(allocated[i]->scene_surface); free(allocated[i]);
	}
	puts("dwl-scroll core: insertion, focus, pan, tags, resize, clipping, movement, merge, width, transfer, cleanup OK");
	return 0;
}
