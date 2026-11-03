#ifndef SKIA_BRIDGE_H
#define SKIA_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SkiaBridgeContext SkiaBridgeContext;

SkiaBridgeContext *skb_create(int width, int height);
void skb_destroy(SkiaBridgeContext *ctx);
void skb_clear(SkiaBridgeContext *ctx);

/// Draws one line of text. `ctFont` is a CTFontRef; `baselineY` is in top-left pixel coordinates.
void skb_draw_text(
    SkiaBridgeContext *ctx, const char *utf8, const void *ctFont,
    float x, float baselineY,
    float r, float g, float b, float a,
    float shadowSigma, float shadowDX, float shadowDY, float shadowAlpha);

void skb_fill_round_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h, float radius,
    float r, float g, float b, float a);

/// Draws pre-shaped CoreText glyphs. `xPositions` are relative to `originX`;
/// all glyphs share `baselineY`.
void skb_draw_glyphs(
    SkiaBridgeContext *ctx, const void *ctFont,
    const uint16_t *glyphs, const float *xPositions, int count,
    float originX, float baselineY,
    float r, float g, float b, float a,
    float shadowSigma, float shadowDX, float shadowDY, float shadowAlpha);

/// Draws premultiplied BGRA pixels into a rect.
void skb_draw_image(
    SkiaBridgeContext *ctx, const uint8_t *bgra, int width, int height,
    float x, float y, float w, float h, float opacity,
    float shadowSigma, float shadowDX, float shadowDY, float shadowAlpha);

/// Reusable image handle. Create once per asset; the context does not own it.
typedef struct SkiaBridgeImage SkiaBridgeImage;

SkiaBridgeImage *skb_image_create(
    const uint8_t *bgra, int width, int height);
void skb_image_destroy(SkiaBridgeImage *image);
void skb_draw_image_handle(
    SkiaBridgeContext *ctx, const SkiaBridgeImage *image,
    float x, float y, float w, float h, float opacity,
    float shadowSigma, float shadowDX, float shadowDY, float shadowAlpha);
/// Intersects the clip with the image's alpha channel, scaled into the rect.
void skb_clip_image_mask(
    SkiaBridgeContext *ctx, const SkiaBridgeImage *mask,
    float x, float y, float w, float h);
/// Draws an image with destination-in blending. Inside a saved layer this
/// multiplies the layer's existing alpha by the image alpha, which is the
/// feathered-background mask recipe.
void skb_draw_image_dst_in(
    SkiaBridgeContext *ctx, const SkiaBridgeImage *image,
    float x, float y, float w, float h);

void skb_save(SkiaBridgeContext *ctx);
void skb_restore(SkiaBridgeContext *ctx);

/// Starts a layer whose contents are composited with a drop shadow. `x, y, w, h` bounds the
/// layer so the blur does not cover the whole canvas.
void skb_begin_shadow_layer(
    SkiaBridgeContext *ctx, float sigma, float dx, float dy,
    float x, float y, float w, float h,
    float r, float g, float b, float alpha);

/// Starts a layer whose contents are composited with a chain of drop shadows.
/// Entries are ordered innermost (applied first) to outermost. `rgba` has four
/// components per entry.
void skb_begin_shadow_chain(
    SkiaBridgeContext *ctx, int count,
    const float *sigmas, const float *dxs, const float *dys, const float *rgba,
    float x, float y, float w, float h);

void skb_stroke_line(
    SkiaBridgeContext *ctx, float x1, float y1, float x2, float y2, float width,
    float r, float g, float b, float a);

void skb_fill_circle(
    SkiaBridgeContext *ctx, float cx, float cy, float radius,
    float r, float g, float b, float a);

void skb_fill_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h,
    float r, float g, float b, float a);

/// Fills a rounded rect with a linear gradient from its top-left to bottom-right corner.
void skb_fill_diagonal_gradient_round_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h, float radius,
    float r0, float g0, float b0, float a0,
    float r1, float g1, float b1, float a1);

/// Strokes the rounded rect centered on its edge.
void skb_stroke_round_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h, float radius,
    float width, float r, float g, float b, float a);

/// Strokes a polyline with round caps and joins. `xy` is x,y pairs.
void skb_stroke_polyline(
    SkiaBridgeContext *ctx, const float *xy, int count, float width,
    float r, float g, float b, float a);

void skb_clip_circle(SkiaBridgeContext *ctx, float cx, float cy, float radius);
void skb_clip_round_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h, float radius);
void skb_clip_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h);

/// Reusable path for charts, gauges, and segmented bars. The path is in
/// top-left canvas coordinates.
typedef struct SkiaBridgePath SkiaBridgePath;

SkiaBridgePath *skb_path_create(void);
void skb_path_destroy(SkiaBridgePath *path);
void skb_path_move_to(SkiaBridgePath *path, float x, float y);
void skb_path_line_to(SkiaBridgePath *path, float x, float y);
void skb_path_quad_to(
    SkiaBridgePath *path, float cx, float cy, float x, float y);
void skb_path_cubic_to(
    SkiaBridgePath *path,
    float c1x, float c1y, float c2x, float c2y, float x, float y);
void skb_path_close(SkiaBridgePath *path);
/// Adds a circular arc. Angles are in degrees, clockwise from the positive
/// x-axis. `forceMoveTo` starts a new subpath instead of connecting.
void skb_path_add_arc(
    SkiaBridgePath *path, float cx, float cy, float radius,
    float startDegrees, float sweepDegrees, int forceMoveTo);

/// Draws a path as a fill or stroke. `cap` and `join` use the Skia enum
/// values (0 = butt/miter, 1 = round, 2 = square/bevel). A positive
/// `dashLength` enables a two-interval dash with `dashGap`.
void skb_draw_path(
    SkiaBridgeContext *ctx, const SkiaBridgePath *path,
    int fill, float r, float g, float b, float a,
    float strokeWidth, int cap, int join,
    float dashLength, float dashGap);
void skb_clip_path(SkiaBridgeContext *ctx, const SkiaBridgePath *path);

/// Draws a path with a linear gradient. `stops` is interleaved
/// (offset, r, g, b, a) per stop and must be ordered by offset.
void skb_draw_path_gradient(
    SkiaBridgeContext *ctx, const SkiaBridgePath *path,
    int fill, float strokeWidth, int cap, int join,
    const float *stops, int stopCount,
    float x0, float y0, float x1, float y1);

/// Fills a rect with a linear gradient between two points.
void skb_fill_linear_gradient_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h,
    float x0, float y0, float x1, float y1,
    float r0, float g0, float b0, float a0,
    float r1, float g1, float b1, float a1);

/// Fills a circle with a radial gradient.
void skb_fill_radial_gradient_circle(
    SkiaBridgeContext *ctx, float cx, float cy, float radius,
    float r0, float g0, float b0, float a0,
    float r1, float g1, float b1, float a1);

/// Starts a layer whose contents are blurred with a Gaussian.
void skb_begin_blur_layer(
    SkiaBridgeContext *ctx, float sigma,
    float x, float y, float w, float h);

/// Starts a layer whose contents are composited with `alpha`. Use for a
/// whole-module `element.opacity` so overlapping shapes do not double-blend.
void skb_begin_opacity_layer(
    SkiaBridgeContext *ctx, float alpha,
    float x, float y, float w, float h);

/// Premultiplied BGRA pixels, `rowBytes` per row.
const uint8_t *skb_pixels(SkiaBridgeContext *ctx, size_t *rowBytes);

/// Creates a Metal-backed context. `mtlDevice` and `mtlQueue` are borrowed
/// `MTLDevice`/`MTLCommandQueue` handles; the context retains them.
SkiaBridgeContext *skb_create_gpu(
    int width, int height, const void *mtlDevice, const void *mtlQueue);

/// Creates a Metal-backed context without allocating a surface. Wrap an
/// external texture with `skb_wrap_texture` before drawing.
SkiaBridgeContext *skb_create_gpu_context(
    int width, int height, const void *mtlDevice, const void *mtlQueue);

/// Wraps an external `MTLTexture` as the context's render target. Returns 1 on
/// success. The caller keeps the texture alive until the next flush.
int skb_wrap_texture(
    SkiaBridgeContext *ctx, int width, int height, const void *mtlTexture);

/// Flushes pending draws. When `sync` is non-zero, waits for the GPU to finish.
void skb_flush(SkiaBridgeContext *ctx, int sync);

/// Flushes, waits, and reads the surface back into CPU memory.
const uint8_t *skb_read_pixels(SkiaBridgeContext *ctx, size_t *rowBytes);

#ifdef __cplusplus
}
#endif
#endif
