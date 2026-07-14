#!/usr/bin/env python3
"""Generate deterministic Mac App Store marketing screenshots."""

from __future__ import annotations

import argparse
import json
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageCms, ImageDraw, ImageFilter, ImageFont, ImageOps


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPO_ROOT / "AppStore/Screenshots/template.json"
FONT_PATH = Path("/System/Library/Fonts/Avenir Next.ttc")
SRGB_PROFILE_PATH = Path("/System/Library/ColorSync/Profiles/sRGB Profile.icc")
SRGB_PROFILE = ImageCms.ImageCmsProfile(str(SRGB_PROFILE_PATH))
SRGB_ICC = SRGB_PROFILE_PATH.read_bytes()


def repo_path(value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else REPO_ROOT / path


def to_srgb(image: Image.Image) -> Image.Image:
    """Convert embedded wide-gamut captures to sRGB without shifting UI colors."""
    rgb = image.convert("RGB")
    embedded_profile = image.info.get("icc_profile")
    if not embedded_profile:
        return rgb
    source_profile = ImageCms.ImageCmsProfile(BytesIO(embedded_profile))
    return ImageCms.profileToProfile(
        rgb,
        source_profile,
        SRGB_PROFILE,
        renderingIntent=ImageCms.Intent.RELATIVE_COLORIMETRIC,
        outputMode="RGB",
    )


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(to_srgb(image), size, Image.Resampling.LANCZOS)


def rounded_image(image: Image.Image, size: tuple[int, int], radius: int) -> Image.Image:
    fitted = ImageOps.contain(to_srgb(image), size, Image.Resampling.LANCZOS)
    if fitted.size != size:
        raise ValueError(f"source must match the template aspect ratio; got {image.size}")
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    result = Image.new("RGBA", size)
    result.paste(fitted, (0, 0), mask)
    return result


def rounded_alpha_mask(
    size: tuple[int, int],
    radius: int,
    supersampling: int = 4,
) -> Image.Image:
    """Create an antialiased rounded mask for assets with opaque corner pixels."""
    scaled_size = (size[0] * supersampling, size[1] * supersampling)
    mask = Image.new("L", scaled_size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, scaled_size[0] - 1, scaled_size[1] - 1),
        radius=radius * supersampling,
        fill=255,
    )
    return mask.resize(size, Image.Resampling.LANCZOS)


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    if not FONT_PATH.exists():
        raise FileNotFoundError(f"required macOS system font not found: {FONT_PATH}")
    index = {"regular": 7, "medium": 5, "demibold": 2}[weight]
    return ImageFont.truetype(str(FONT_PATH), size=size, index=index)


def draw_slide(manifest: dict, slide: dict) -> Image.Image:
    width = int(manifest["canvas"]["width"])
    height = int(manifest["canvas"]["height"])
    if (width, height) != (2880, 1800):
        raise ValueError("the App Store template canvas must remain 2880 x 1800")

    background_path = repo_path(manifest["canvas"]["background"])
    app_icon_path = repo_path(manifest["app_icon"])
    source_path = repo_path(slide["source"])
    background = Image.open(background_path)
    app_icon = Image.open(app_icon_path)
    source = Image.open(source_path)
    if source.width / source.height != 16 / 9:
        raise ValueError(f"source must be 16:9: {source_path} is {source.size}")

    canvas = cover(background, (width, height)).convert("RGBA")
    # Calm the generated texture behind the copy while keeping the lower route detail.
    wash = Image.new("RGBA", canvas.size, (2, 15, 22, 0))
    wash.putalpha(Image.linear_gradient("L").resize(canvas.size).point(lambda p: 118 - p // 3))
    canvas = Image.alpha_composite(canvas, wash)
    draw = ImageDraw.Draw(canvas)

    title_font = font(82, "demibold")
    subtitle_font = font(36, "regular")
    brand_font = font(32, "demibold")
    draw.text((150, 82), slide["headline"], font=title_font, fill=(239, 250, 255, 255))
    draw.text((154, 205), slide["subtitle"], font=subtitle_font, fill=(151, 198, 214, 255))
    draw.rounded_rectangle((154, 302, 520, 314), radius=6, fill=(67, 200, 245, 255))

    # A plain app identity lockup reads as branding, not an interactive button.
    icon_size = (112, 112)
    icon_xy = (2260, 76)
    icon = ImageOps.fit(to_srgb(app_icon), icon_size, Image.Resampling.LANCZOS).convert("RGBA")
    icon.putalpha(rounded_alpha_mask(icon_size, int(manifest["app_icon_corner_radius"])))
    icon_shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(icon_shadow).rounded_rectangle(
        (icon_xy[0] + 4, icon_xy[1] + 8, icon_xy[0] + icon_size[0] + 4, icon_xy[1] + icon_size[1] + 8),
        radius=26,
        fill=(0, 0, 0, 150),
    )
    canvas = Image.alpha_composite(canvas, icon_shadow.filter(ImageFilter.GaussianBlur(14)))
    canvas.alpha_composite(icon, icon_xy)
    draw = ImageDraw.Draw(canvas)
    brand_first_line, brand_second_line = manifest["brand"].rsplit(" ", maxsplit=1)
    draw.text((2405, 82), brand_first_line, font=brand_font, fill=(239, 250, 255, 255))
    draw.text((2405, 128), brand_second_line, font=brand_font, fill=(151, 198, 214, 255))

    shot_size = (2400, 1350)
    shot_xy = (240, 410)
    shot = rounded_image(source, shot_size, radius=26)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (shot_xy[0] + 12, shot_xy[1] + 26, shot_xy[0] + shot_size[0] + 12, shot_xy[1] + shot_size[1] + 26),
        radius=30,
        fill=(0, 0, 0, 190),
    )
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(32)))
    canvas.alpha_composite(shot, shot_xy)
    ImageDraw.Draw(canvas).rounded_rectangle(
        (shot_xy[0], shot_xy[1], shot_xy[0] + shot_size[0] - 1, shot_xy[1] + shot_size[1] - 1),
        radius=26,
        outline=(99, 168, 191, 150),
        width=3,
    )
    return canvas.convert("RGB")


def validate_output(path: Path, expected_size: tuple[int, int]) -> None:
    with Image.open(path) as image:
        if image.size != expected_size:
            raise ValueError(f"unexpected dimensions for {path}: {image.size}")
        if image.mode != "RGB":
            raise ValueError(f"output must not contain alpha: {path} is {image.mode}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args()

    manifest_path = args.manifest if args.manifest.is_absolute() else REPO_ROOT / args.manifest
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    output_root = repo_path(manifest["output_root"])
    one_x = output_root / "desktop"
    two_x = output_root / "desktop@2x"
    one_x.mkdir(parents=True, exist_ok=True)
    two_x.mkdir(parents=True, exist_ok=True)

    for slide in manifest["slides"]:
        rendered = draw_slide(manifest, slide)
        two_x_path = two_x / slide["filename"]
        one_x_path = one_x / slide["filename"]
        rendered.save(two_x_path, format="PNG", optimize=True, icc_profile=SRGB_ICC)
        rendered.resize((1440, 900), Image.Resampling.LANCZOS).save(
            one_x_path,
            format="PNG",
            optimize=True,
            icc_profile=SRGB_ICC,
        )
        validate_output(two_x_path, (2880, 1800))
        validate_output(one_x_path, (1440, 900))
        print(f"generated {one_x_path.relative_to(REPO_ROOT)}")
        print(f"generated {two_x_path.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
