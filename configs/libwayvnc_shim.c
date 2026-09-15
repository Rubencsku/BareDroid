#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>

struct wl_registry;
struct wl_registry_listener {
    void (*global)(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version);
    void (*global_remove)(void *data, struct wl_registry *registry, uint32_t name);
};

static void (*orig_global)(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) = NULL;

static void hooked_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    if (strcmp(interface, "ext_image_copy_capture_manager_v1") == 0) {
        fprintf(stderr, "[wayvnc_shim] Filtering ext_image_copy_capture_manager_v1\n");
        return;
    }
    if (strcmp(interface, "zwlr_output_power_manager_v1") == 0) {
        fprintf(stderr, "[wayvnc_shim] Filtering zwlr_output_power_manager_v1\n");
        return;
    }
    orig_global(data, registry, name, interface, version);
}

static struct wl_registry_listener hooked_listener;

int wl_proxy_add_listener(void *proxy, void (**implementation)(void), void *data) {
    static int (*orig_add_listener)(void *, void (**)(void), void *) = NULL;
    if (!orig_add_listener) {
        orig_add_listener = dlsym(RTLD_NEXT, "wl_proxy_add_listener");
    }
    
    struct wl_registry_listener *l = (struct wl_registry_listener *)implementation;
    if (l && l->global && !orig_global) {
        orig_global = l->global;
        hooked_listener.global = hooked_global;
        hooked_listener.global_remove = l->global_remove;
        return orig_add_listener(proxy, (void (**)(void))&hooked_listener, data);
    }
    return orig_add_listener(proxy, implementation, data);
}
