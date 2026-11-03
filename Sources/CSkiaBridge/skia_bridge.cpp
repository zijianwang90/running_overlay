#include "skia_bridge.h"
#include "skia_bridge_internal.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkColor.h"
#include "include/core/SkFont.h"
#include "include/core/SkImage.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPath.h"
#include "include/core/SkPathBuilder.h"
#include "include/core/SkPixmap.h"
#include "include/core/SkRRect.h"
#include "include/core/SkSamplingOptions.h"
#include "include/core/SkSurface.h"
#include "include/effects/SkDashPathEffect.h"
#include "include/effects/SkGradient.h"
#include "include/effects/SkImageFilters.h"
#include "include/ports/SkTypeface_mac.h"

#include <CoreText/CoreText.h>
#include <algorithm>
#include <cmath>
#include <vector>

SkiaBridgeContext *skb_create(int width, int height) {
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType, kPremul_SkAlphaType);
    auto surface = SkSurfaces::Raster(info);
    if (!surface) return nullptr;
    auto *ctx = new SkiaBridgeContext();
    ctx->surface = surface;
    return ctx;
}

void skb_destroy(SkiaBridgeContext *ctx) { delete ctx; }

void skb_clear(SkiaBridgeContext *ctx) { ctx->surface->getCanvas()->clear(SK_ColorTRANSPARENT); }

void skb_draw_text(
    SkiaBridgeContext *ctx, const char *utf8, const void *ctFont,
    float x, float baselineY, float r, float g, float b, float a,
    float shadowSigma, float shadowDX, float shadowDY, float shadowAlpha) {
    sk_sp<SkTypeface> typeface = SkMakeTypefaceFromCTFont((CTFontRef)ctFont);
    SkFont font(typeface, (SkScalar)CTFontGetSize((CTFontRef)ctFont));
    font.setSubpixel(true);
    font.setEdging(SkFont::Edging::kAntiAlias);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor4f({r, g, b, a});
    if (shadowAlpha > 0) {
        paint.setImageFilter(SkImageFilters::DropShadow(
            shadowDX, shadowDY, shadowSigma, shadowSigma, SkColor4f{0, 0, 0, shadowAlpha}.toSkColor(), nullptr));
    }
    ctx->surface->getCanvas()->drawString(utf8, x, baselineY, font, paint);
}

void skb_fill_round_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h, float radius,
    float r, float g, float b, float a) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor4f({r, g, b, a});
    ctx->surface->getCanvas()->drawRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(x, y, w, h), radius, radius), paint);
}

void skb_draw_glyphs(
    SkiaBridgeContext *ctx, const void *ctFont,
    const uint16_t *glyphs, const float *xPositions, int count,
    float originX, float baselineY, float r, float g, float b, float a,
    float shadowSigma, float shadowDX, float shadowDY, float shadowAlpha) {
    sk_sp<SkTypeface> typeface = SkMakeTypefaceFromCTFont((CTFontRef)ctFont);
    SkFont font(typeface, (SkScalar)CTFontGetSize((CTFontRef)ctFont));
    font.setSubpixel(true);
    font.setEdging(SkFont::Edging::kAntiAlias);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor4f({r, g, b, a});
    if (shadowAlpha > 0) {
        paint.setImageFilter(SkImageFilters::DropShadow(
            shadowDX, shadowDY, shadowSigma, shadowSigma, SkColor4f{0, 0, 0, shadowAlpha}.toSkColor(), nullptr));
    }
    std::vector<SkPoint> points(count);
    for (int i = 0; i < count; i++) {
        points[i] = SkPoint::Make(originX + xPositions[i], baselineY);
    }
    ctx->surface->getCanvas()->drawGlyphs(
        SkSpan<const SkGlyphID>((const SkGlyphID *)glyphs, count),
        SkSpan<const SkPoint>(points.data(), count),
        SkPoint::Make(0, 0), font, paint);
}

void skb_draw_image(
    SkiaBridgeContext *ctx, const uint8_t *bgra, int width, int height,
    float x, float y, float w, float h, float opacity,
    float shadowSigma, float shadowDX, float shadowDY, float shadowAlpha) {
    SkImageInfo info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType, kPremul_SkAlphaType);
    SkPixmap pixmap(info, bgra, width * 4);
    sk_sp<SkImage> image = SkImages::RasterFromPixmapCopy(pixmap);
    if (!image) return;
    SkPaint paint;
    paint.setAlphaf(opacity);
    if (shadowAlpha > 0) {
        paint.setImageFilter(SkImageFilters::DropShadow(
            shadowDX, shadowDY, shadowSigma, shadowSigma, SkColor4f{0, 0, 0, shadowAlpha}.toSkColor(), nullptr));
    }
    ctx->surface->getCanvas()->drawImageRect(
        image, SkRect::MakeXYWH(x, y, w, h), SkSamplingOptions(SkFilterMode::kLinear), &paint);
}

void skb_save(SkiaBridgeContext *ctx) { ctx->surface->getCanvas()->save(); }
void skb_restore(SkiaBridgeContext *ctx) { ctx->surface->getCanvas()->restore(); }

void skb_begin_shadow_layer(
    SkiaBridgeContext *ctx, float sigma, float dx, float dy,
    float x, float y, float w, float h,
    float r, float g, float b, float alpha) {
    SkPaint paint;
    if (alpha > 0) {
        paint.setImageFilter(SkImageFilters::DropShadow(
            dx, dy, sigma, sigma, SkColor4f{r, g, b, alpha}.toSkColor(), nullptr));
    }
    float pad = sigma * 3.0f + std::max(std::fabs(dx), std::fabs(dy));
    SkRect bounds = SkRect::MakeXYWH(x - pad, y - pad, w + 2.0f * pad, h + 2.0f * pad);
    ctx->surface->getCanvas()->saveLayer(&bounds, &paint);
}

void skb_begin_shadow_chain(
    SkiaBridgeContext *ctx, int count,
    const float *sigmas, const float *dxs, const float *dys, const float *rgba,
    float x, float y, float w, float h) {
    sk_sp<SkImageFilter> filter;
    float pad = 0;
    for (int i = 0; i < count; i++) {
        float r = rgba[i * 4];
        float g = rgba[i * 4 + 1];
        float b = rgba[i * 4 + 2];
        float a = rgba[i * 4 + 3];
        if (a > 0) {
            filter = SkImageFilters::DropShadow(
                dxs[i], dys[i], sigmas[i], sigmas[i], SkColor4f{r, g, b, a}.toSkColor(), filter);
        }
        pad = std::max(pad, sigmas[i] * 3.0f + std::max(std::fabs(dxs[i]), std::fabs(dys[i])));
    }
    SkPaint paint;
    paint.setImageFilter(filter);
    SkRect bounds = SkRect::MakeXYWH(x - pad, y - pad, w + 2.0f * pad, h + 2.0f * pad);
    ctx->surface->getCanvas()->saveLayer(&bounds, &paint);
}

void skb_stroke_line(
    SkiaBridgeContext *ctx, float x1, float y1, float x2, float y2, float width,
    float r, float g, float b, float a) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setStyle(SkPaint::kStroke_Style);
    paint.setStrokeWidth(width);
    paint.setColor4f({r, g, b, a});
    ctx->surface->getCanvas()->drawLine(x1, y1, x2, y2, paint);
}

void skb_fill_circle(
    SkiaBridgeContext *ctx, float cx, float cy, float radius,
    float r, float g, float b, float a) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor4f({r, g, b, a});
    ctx->surface->getCanvas()->drawCircle(cx, cy, radius, paint);
}

void skb_fill_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h,
    float r, float g, float b, float a) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor4f({r, g, b, a});
    ctx->surface->getCanvas()->drawRect(SkRect::MakeXYWH(x, y, w, h), paint);
}

void skb_fill_diagonal_gradient_round_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h, float radius,
    float r0, float g0, float b0, float a0,
    float r1, float g1, float b1, float a1) {
    SkColor4f colors[2] = {{r0, g0, b0, a0}, {r1, g1, b1, a1}};
    SkPoint points[2] = {SkPoint::Make(x, y), SkPoint::Make(x + w, y + h)};
    SkGradient gradient(
        SkGradient::Colors(SkSpan<const SkColor4f>(colors, 2), SkTileMode::kClamp),
        SkGradient::Interpolation{});
    sk_sp<SkShader> shader = SkShaders::LinearGradient(points, gradient);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setShader(shader);
    ctx->surface->getCanvas()->drawRRect(
        SkRRect::MakeRectXY(SkRect::MakeXYWH(x, y, w, h), radius, radius), paint);
}

void skb_stroke_round_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h, float radius,
    float width, float r, float g, float b, float a) {
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setStyle(SkPaint::kStroke_Style);
    paint.setStrokeWidth(width);
    paint.setColor4f({r, g, b, a});
    ctx->surface->getCanvas()->drawRRect(
        SkRRect::MakeRectXY(SkRect::MakeXYWH(x, y, w, h), radius, radius), paint);
}

void skb_stroke_polyline(
    SkiaBridgeContext *ctx, const float *xy, int count, float width,
    float r, float g, float b, float a) {
    if (count < 2) return;
    SkPathBuilder builder;
    builder.moveTo(xy[0], xy[1]);
    for (int i = 1; i < count; i++) {
        builder.lineTo(xy[i * 2], xy[i * 2 + 1]);
    }
    SkPath path = builder.detach();
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setStyle(SkPaint::kStroke_Style);
    paint.setStrokeWidth(width);
    paint.setStrokeCap(SkPaint::kRound_Cap);
    paint.setStrokeJoin(SkPaint::kRound_Join);
    paint.setColor4f({r, g, b, a});
    ctx->surface->getCanvas()->drawPath(path, paint);
}

void skb_clip_circle(SkiaBridgeContext *ctx, float cx, float cy, float radius) {
    SkPathBuilder builder;
    builder.addCircle(cx, cy, radius);
    ctx->surface->getCanvas()->clipPath(builder.detach(), true);
}

void skb_clip_round_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h, float radius) {
    ctx->surface->getCanvas()->clipRRect(
        SkRRect::MakeRectXY(SkRect::MakeXYWH(x, y, w, h), radius, radius), true);
}

void skb_clip_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h) {
    ctx->surface->getCanvas()->clipRect(SkRect::MakeXYWH(x, y, w, h), true);
}

SkiaBridgePath *skb_path_create(void) { return new SkiaBridgePath(); }

void skb_path_destroy(SkiaBridgePath *path) { delete path; }

void skb_path_move_to(SkiaBridgePath *path, float x, float y) {
    path->builder.moveTo(x, y);
}

void skb_path_line_to(SkiaBridgePath *path, float x, float y) {
    path->builder.lineTo(x, y);
}

void skb_path_quad_to(
    SkiaBridgePath *path, float cx, float cy, float x, float y) {
    path->builder.quadTo(cx, cy, x, y);
}

void skb_path_cubic_to(
    SkiaBridgePath *path,
    float c1x, float c1y, float c2x, float c2y, float x, float y) {
    path->builder.cubicTo(c1x, c1y, c2x, c2y, x, y);
}

void skb_path_close(SkiaBridgePath *path) { path->builder.close(); }

void skb_path_add_arc(
    SkiaBridgePath *path, float cx, float cy, float radius,
    float startDegrees, float sweepDegrees, int forceMoveTo) {
    SkRect oval = SkRect::MakeXYWH(
        cx - radius, cy - radius, radius * 2.0f, radius * 2.0f);
    if (forceMoveTo) {
        path->builder.addArc(oval, startDegrees, sweepDegrees);
    } else {
        path->builder.arcTo(oval, startDegrees, sweepDegrees, false);
    }
}

void skb_draw_path(
    SkiaBridgeContext *ctx, const SkiaBridgePath *path,
    int fill, float r, float g, float b, float a,
    float strokeWidth, int cap, int join,
    float dashLength, float dashGap) {
    if (!path) return;
    SkPaint paint;
    paint.setAntiAlias(true);
    if (fill) {
        paint.setStyle(SkPaint::kFill_Style);
    } else {
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(strokeWidth);
        paint.setStrokeCap(static_cast<SkPaint::Cap>(cap));
        paint.setStrokeJoin(static_cast<SkPaint::Join>(join));
        if (dashLength > 0) {
            SkScalar intervals[2] = {dashLength, dashGap};
            paint.setPathEffect(SkDashPathEffect::Make(
                SkSpan<const SkScalar>(intervals, 2), 0));
        }
    }
    paint.setColor4f({r, g, b, a});
    ctx->surface->getCanvas()->drawPath(path->builder.snapshot(), paint);
}

void skb_clip_path(SkiaBridgeContext *ctx, const SkiaBridgePath *path) {
    if (!path) return;
    ctx->surface->getCanvas()->clipPath(path->builder.snapshot(), true);
}

void skb_fill_linear_gradient_rect(
    SkiaBridgeContext *ctx, float x, float y, float w, float h,
    float x0, float y0, float x1, float y1,
    float r0, float g0, float b0, float a0,
    float r1, float g1, float b1, float a1) {
    SkColor4f colors[2] = {{r0, g0, b0, a0}, {r1, g1, b1, a1}};
    SkPoint points[2] = {SkPoint::Make(x0, y0), SkPoint::Make(x1, y1)};
    SkGradient gradient(
        SkGradient::Colors(
            SkSpan<const SkColor4f>(colors, 2), SkTileMode::kClamp),
        SkGradient::Interpolation{});
    sk_sp<SkShader> shader = SkShaders::LinearGradient(points, gradient);
    if (!shader) return;
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setShader(shader);
    ctx->surface->getCanvas()->drawRect(
        SkRect::MakeXYWH(x, y, w, h), paint);
}

void skb_fill_radial_gradient_circle(
    SkiaBridgeContext *ctx, float cx, float cy, float radius,
    float r0, float g0, float b0, float a0,
    float r1, float g1, float b1, float a1) {
    SkColor4f colors[2] = {{r0, g0, b0, a0}, {r1, g1, b1, a1}};
    SkGradient gradient(
        SkGradient::Colors(
            SkSpan<const SkColor4f>(colors, 2), SkTileMode::kClamp),
        SkGradient::Interpolation{});
    sk_sp<SkShader> shader = SkShaders::RadialGradient(
        SkPoint::Make(cx, cy), radius, gradient);
    if (!shader) return;
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setShader(shader);
    ctx->surface->getCanvas()->drawCircle(cx, cy, radius, paint);
}

void skb_begin_blur_layer(
    SkiaBridgeContext *ctx, float sigma,
    float x, float y, float w, float h) {
    SkPaint paint;
    paint.setImageFilter(SkImageFilters::Blur(sigma, sigma, nullptr));
    float pad = sigma * 3.0f;
    SkRect bounds = SkRect::MakeXYWH(x - pad, y - pad, w + 2.0f * pad, h + 2.0f * pad);
    ctx->surface->getCanvas()->saveLayer(&bounds, &paint);
}

const uint8_t *skb_pixels(SkiaBridgeContext *ctx, size_t *rowBytes) {
    if (ctx->grContext) {
        return skb_read_pixels_impl(ctx, rowBytes);
    }
    ctx->surface->peekPixels(&ctx->pixmap);
    *rowBytes = ctx->pixmap.rowBytes();
    return (const uint8_t *)ctx->pixmap.addr();
}
