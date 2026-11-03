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

/// Starts a layer whose contents are blurred with a Gaussian.
void skb_begin_blur_layer(
    SkiaBridgeContext *ctx, float sigma,
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
