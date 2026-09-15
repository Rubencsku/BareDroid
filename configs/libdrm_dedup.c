#define _GNU_SOURCE
#include <dlfcn.h>
#include <xf86drm.h>
#include <xf86drmMode.h>
#include <stdint.h>
#include <stdio.h>

static drmModePlanePtr (*orig_drmModeGetPlane)(int fd, uint32_t plane_id) = NULL;

drmModePlanePtr drmModeGetPlane(int fd, uint32_t plane_id) {
    if (!orig_drmModeGetPlane) {
        orig_drmModeGetPlane = (drmModePlanePtr (*)(int, uint32_t))dlsym(RTLD_NEXT, "drmModeGetPlane");
    }
    drmModePlanePtr plane = orig_drmModeGetPlane(fd, plane_id);
    if (!plane) {
        return NULL;
    }

    /* Deduplicate plane formats in-place to prevent Weston assert crashes */
    uint32_t unique_count = 0;
    for (uint32_t i = 0; i < plane->count_formats; i++) {
        uint32_t fmt = plane->formats[i];
        int duplicate = 0;
        for (uint32_t j = 0; j < unique_count; j++) {
            if (plane->formats[j] == fmt) {
                duplicate = 1;
                break;
            }
        }
        if (!duplicate) {
            plane->formats[unique_count++] = fmt;
        }
    }
    plane->count_formats = unique_count;
    return plane;
}

static drmModeConnectorPtr (*orig_drmModeGetConnector)(int fd, uint32_t connector_id) = NULL;
static drmModeConnectorPtr (*orig_drmModeGetConnectorCurrent)(int fd, uint32_t connector_id) = NULL;

drmModeConnectorPtr drmModeGetConnector(int fd, uint32_t connector_id) {
    if (!orig_drmModeGetConnector) {
        orig_drmModeGetConnector = (drmModeConnectorPtr (*)(int, uint32_t))dlsym(RTLD_NEXT, "drmModeGetConnector");
    }
    drmModeConnectorPtr conn = orig_drmModeGetConnector(fd, connector_id);
    if (conn && conn->connector_type == DRM_MODE_CONNECTOR_VIRTUAL) {
        conn->connection = DRM_MODE_DISCONNECTED;
    }
    return conn;
}

drmModeConnectorPtr drmModeGetConnectorCurrent(int fd, uint32_t connector_id) {
    if (!orig_drmModeGetConnectorCurrent) {
        orig_drmModeGetConnectorCurrent = (drmModeConnectorPtr (*)(int, uint32_t))dlsym(RTLD_NEXT, "drmModeGetConnectorCurrent");
    }
    drmModeConnectorPtr conn = orig_drmModeGetConnectorCurrent(fd, connector_id);
    if (conn && conn->connector_type == DRM_MODE_CONNECTOR_VIRTUAL) {
        conn->connection = DRM_MODE_DISCONNECTED;
    }
    return conn;
}

#include <drm/drm.h>
#include <unistd.h>
#include <time.h>

static ssize_t (*orig_read)(int fd, void *buf, size_t count) = NULL;

/* Intercept read() to fix missing/zero timestamps on DRM vblank/page-flip events from Qualcomm SDE.
   Without valid monotonic timestamps, Weston assumes 0ms frame delay and spins at 400% CPU. */
ssize_t read(int fd, void *buf, size_t count) {
    if (!orig_read) {
        orig_read = (ssize_t (*)(int, void *, size_t))dlsym(RTLD_NEXT, "read");
    }
    ssize_t ret = orig_read(fd, buf, count);
    if (ret >= (ssize_t)sizeof(struct drm_event)) {
        char *ptr = (char *)buf;
        char *end = ptr + ret;
        while (ptr + sizeof(struct drm_event) <= end) {
            struct drm_event *e = (struct drm_event *)ptr;
            if (e->length < sizeof(struct drm_event) || ptr + e->length > end) {
                break;
            }
            if (e->type == DRM_EVENT_VBLANK || e->type == DRM_EVENT_FLIP_COMPLETE) {
                if (e->length >= sizeof(struct drm_event_vblank)) {
                    struct drm_event_vblank *v = (struct drm_event_vblank *)e;
                    if (v->tv_sec == 0 && v->tv_usec == 0) {
                        struct timespec ts;
                        clock_gettime(CLOCK_MONOTONIC, &ts);
                        v->tv_sec = (__u32)ts.tv_sec;
                        v->tv_usec = (__u32)(ts.tv_nsec / 1000);
                    }
                }
            }
            ptr += e->length;
        }
    }
    return ret;
}
