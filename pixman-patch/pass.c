#define _POSIX_C_SOURCE 200809L
#include <assert.h>
#include <stdlib.h>
#include <setjmp.h>
#include <signal.h>
#include <wlr/util/log.h>
#include "render/pixman.h"

// --- PIXMAN BUG WORKAROUND ---
static __thread sigjmp_buf pixman_sig_jmp;

static void handle_pixman_sig(int sig) {
        siglongjmp(pixman_sig_jmp, 1);
}

#define SAFE_PIXMAN_CALL(code) \
        do { \
                struct sigaction sa = {0}, old_bus = {0}, old_segv = {0}; \
                sa.sa_handler = handle_pixman_sig; \
                sigemptyset(&sa.sa_mask); \
                sigaction(SIGBUS, &sa, &old_bus); \
                sigaction(SIGSEGV, &sa, &old_segv); \
                if (sigsetjmp(pixman_sig_jmp, 1) == 0) { \
                        code; \
                } else { \
                        wlr_log(WLR_ERROR, "[PIXMAN WORKAROUND] Caught SIGSEGV/SIGBUS! Skipping draw."); \
                } \
                sigaction(SIGBUS, &old_bus, NULL); \
                sigaction(SIGSEGV, &old_segv, NULL); \
        } while (0)
// -----------------------------

static const struct wlr_render_pass_impl render_pass_impl;

static struct wlr_pixman_render_pass *get_render_pass(struct wlr_render_pass *wlr_pass) {
        assert(wlr_pass->impl == &render_pass_impl);
        struct wlr_pixman_render_pass *pass = wl_container_of(wlr_pass, pass, base);
        return pass;
}

static struct wlr_pixman_texture *get_texture(struct wlr_texture *wlr_texture) {
        assert(wlr_texture_is_pixman(wlr_texture));
        struct wlr_pixman_texture *texture = wl_container_of(wlr_texture, texture, wlr_texture);
        return texture;
}

static bool render_pass_submit(struct wlr_render_pass *wlr_pass) {
        struct wlr_pixman_render_pass *pass = get_render_pass(wlr_pass);

        wlr_buffer_end_data_ptr_access(pass->buffer->buffer);
        wlr_buffer_unlock(pass->buffer->buffer);
        free(pass);

        return true;
}

static pixman_op_t get_pixman_blending(enum wlr_render_blend_mode mode) {
        switch (mode) {
        case WLR_RENDER_BLEND_MODE_PREMULTIPLIED:
                return PIXMAN_OP_OVER;
        case WLR_RENDER_BLEND_MODE_NONE:
                return PIXMAN_OP_SRC;
        }
        abort();
}

static void render_pass_add_texture(struct wlr_render_pass *wlr_pass,
                const struct wlr_render_texture_options *options) {
        struct wlr_pixman_render_pass *pass = get_render_pass(wlr_pass);
        struct wlr_pixman_texture *texture = get_texture(options->texture);
        struct wlr_pixman_buffer *buffer = pass->buffer;

        if (texture->buffer != NULL && !begin_pixman_data_ptr_access(texture->buffer,
                        &texture->image, WLR_BUFFER_DATA_PTR_ACCESS_READ)) {
                return;
        }

        struct wlr_fbox src_fbox;
        wlr_render_texture_options_get_src_box(options, &src_fbox);
        struct wlr_box src_box = {
                .x = roundf(src_fbox.x),
                .y = roundf(src_fbox.y),
                .width = roundf(src_fbox.width),
                .height = roundf(src_fbox.height),
        };

        struct wlr_box dst_box;
        wlr_render_texture_options_get_dst_box(options, &dst_box);

        pixman_image_t *mask = NULL;
        float alpha = wlr_render_texture_options_get_alpha(options);
        if (alpha != 1) {
                mask = pixman_image_create_solid_fill(&(struct pixman_color){
                        .alpha = 0xFFFF * alpha,
                });
        }

        struct wlr_box orig_box;
        wlr_box_transform(&orig_box, &dst_box, options->transform,
                buffer->buffer->width, buffer->buffer->height);

        int32_t dest_x, dest_y, width, height;
        if (options->transform != WL_OUTPUT_TRANSFORM_NORMAL ||
                        orig_box.width != src_box.width ||
                        orig_box.height != src_box.height) {
                // Cosinus/sinus values are extact integers for enum wl_output_transform entries
                int tr_cos = 1, tr_sin = 0, tr_x = 0, tr_y = 0;
                switch (options->transform) {
                case WL_OUTPUT_TRANSFORM_NORMAL:
                case WL_OUTPUT_TRANSFORM_FLIPPED:
                        break;
                case WL_OUTPUT_TRANSFORM_90:
                case WL_OUTPUT_TRANSFORM_FLIPPED_90:
                        tr_cos = 0;
                        tr_sin = 1;
                        tr_x = buffer->buffer->height;
                        break;
                case WL_OUTPUT_TRANSFORM_180:
                case WL_OUTPUT_TRANSFORM_FLIPPED_180:
                        tr_cos = -1;
                        tr_sin = 0;
                        tr_x = buffer->buffer->width;
                        tr_y = buffer->buffer->height;
                        break;
                case WL_OUTPUT_TRANSFORM_270:
                case WL_OUTPUT_TRANSFORM_FLIPPED_270:
                        tr_cos = 0;
                        tr_sin = -1;
                        tr_y = buffer->buffer->width;
                        break;
                }

                struct pixman_transform transform;
                pixman_transform_init_identity(&transform);
                pixman_transform_rotate(&transform, NULL,
                        pixman_int_to_fixed(tr_cos), pixman_int_to_fixed(tr_sin));
                if (options->transform >= WL_OUTPUT_TRANSFORM_FLIPPED) {
                        pixman_transform_scale(&transform, NULL,
                                pixman_int_to_fixed(-1), pixman_int_to_fixed(1));
                }
                pixman_transform_translate(&transform, NULL,
                        pixman_int_to_fixed(tr_x), pixman_int_to_fixed(tr_y));
                pixman_transform_translate(&transform, NULL,
                        -pixman_int_to_fixed(orig_box.x), -pixman_int_to_fixed(orig_box.y));
                pixman_transform_scale(&transform, NULL,
                        pixman_double_to_fixed(src_box.width / (double)orig_box.width),
                        pixman_double_to_fixed(src_box.height / (double)orig_box.height));
                pixman_image_set_transform(texture->image, &transform);

                dest_x = dest_y = 0;
                width = buffer->buffer->width;
                height = buffer->buffer->height;
        } else {
                pixman_image_set_transform(texture->image, NULL);
                dest_x = dst_box.x;
                dest_y = dst_box.y;
                width = src_box.width;
                height = src_box.height;
        }

        switch (options->filter_mode) {
        case WLR_SCALE_FILTER_BILINEAR:
                pixman_image_set_filter(texture->image, PIXMAN_FILTER_BILINEAR, NULL, 0);
                break;
        case WLR_SCALE_FILTER_NEAREST:
                pixman_image_set_filter(texture->image, PIXMAN_FILTER_NEAREST, NULL, 0);
                break;
        }

        pixman_op_t op = get_pixman_blending(options->blend_mode);

        SAFE_PIXMAN_CALL({
                pixman_image_set_clip_region32(buffer->image, (pixman_region32_t *)options->clip);
                pixman_image_composite32(op, texture->image, mask,
                        buffer->image, src_box.x, src_box.y, 0, 0, dest_x, dest_y,
                        width, height);
                pixman_image_set_clip_region32(buffer->image, NULL);
        });

        pixman_image_set_transform(texture->image, NULL);

        if (texture->buffer != NULL) {
                wlr_buffer_end_data_ptr_access(texture->buffer);
        }

        if (mask != NULL) {
                pixman_image_unref(mask);
        }
}

static void render_pass_add_rect(struct wlr_render_pass *wlr_pass,
                const struct wlr_render_rect_options *options) {
        struct wlr_pixman_render_pass *pass = get_render_pass(wlr_pass);
        struct wlr_pixman_buffer *buffer = pass->buffer;
        struct wlr_box box;
        wlr_render_rect_options_get_box(options, pass->buffer->buffer, &box);

        pixman_op_t op = get_pixman_blending(options->color.a == 1 ?
                WLR_RENDER_BLEND_MODE_NONE : options->blend_mode);

        struct pixman_color color = {
                .red = options->color.r * 0xFFFF,
                .green = options->color.g * 0xFFFF,
                .blue = options->color.b * 0xFFFF,
                .alpha = options->color.a * 0xFFFF,
        };

        pixman_image_t *fill = pixman_image_create_solid_fill(&color);

        SAFE_PIXMAN_CALL({
                pixman_image_set_clip_region32(buffer->image, (pixman_region32_t *)options->clip);
                pixman_image_composite32(op, fill, NULL, buffer->image,
                        0, 0, 0, 0, box.x, box.y, box.width, box.height);
                pixman_image_set_clip_region32(buffer->image, NULL);
        });

        pixman_image_unref(fill);
}

static const struct wlr_render_pass_impl render_pass_impl = {
        .submit = render_pass_submit,
        .add_texture = render_pass_add_texture,
        .add_rect = render_pass_add_rect,
};

struct wlr_pixman_render_pass *begin_pixman_render_pass(
                struct wlr_pixman_buffer *buffer) {
        struct wlr_pixman_render_pass *pass = calloc(1, sizeof(*pass));
        if (pass == NULL) {
                return NULL;
        }

        wlr_render_pass_init(&pass->base, &render_pass_impl);

        if (!begin_pixman_data_ptr_access(buffer->buffer, &buffer->image,
                        WLR_BUFFER_DATA_PTR_ACCESS_READ | WLR_BUFFER_DATA_PTR_ACCESS_WRITE)) {
                free(pass);
                return NULL;
        }

        wlr_buffer_lock(buffer->buffer);
        pass->buffer = buffer;

        return pass;
}
