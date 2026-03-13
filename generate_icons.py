"""Generate Unburden app icons at all required sizes."""
from PIL import Image, ImageDraw
import math, os

def draw_icon(size):
    """Draw the Unburden logo: overlapping peach + lavender bubbles, amber dot."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size

    # ── Brand colours ──
    cream  = (255, 248, 240)       # #FFF8F0
    peach  = (244, 166, 140, 235)  # #F4A68C @ 92%
    lav    = (196, 181, 227, 224)  # #C4B5E3 @ 88%

    # ── Rounded-rect background — cream ──
    radius = int(s * 0.21)
    draw.rounded_rectangle([(0, 0), (s - 1, s - 1)], radius=radius, fill=cream)

    # ── Left bubble — peach (Venter, speaking) ──
    peach_img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    pd = ImageDraw.Draw(peach_img)
    lcx, lcy = int(s * 0.41), int(s * 0.47)
    lrx, lry = int(s * 0.25), int(s * 0.21)
    pd.ellipse([lcx - lrx, lcy - lry, lcx + lrx, lcy + lry], fill=peach)
    # Bubble tail
    tail_pts = [
        (int(lcx - lrx * 0.4), int(lcy + lry * 0.7)),
        (int(lcx - lrx * 1.0), int(lcy + lry * 1.5)),
        (int(lcx - lrx * 0.05), int(lcy + lry * 0.9)),
    ]
    pd.polygon(tail_pts, fill=peach)
    img = Image.alpha_composite(img, peach_img)

    # ── Right bubble — lavender (Listener) ──
    lav_img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lav_img)
    rcx, rcy = int(s * 0.60), int(s * 0.53)
    rrx, rry = int(s * 0.22), int(s * 0.19)
    ld.ellipse([rcx - rrx, rcy - rry, rcx + rrx, rcy + rry], fill=lav)
    img = Image.alpha_composite(img, lav_img)

    return img


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    web_dir = os.path.join(base, 'unburden_app', 'web')
    icons_dir = os.path.join(web_dir, 'icons')

    # Generate all sizes
    sizes = {
        'favicon.png': 32,
        'icons/Icon-192.png': 192,
        'icons/Icon-512.png': 512,
        'icons/Icon-maskable-192.png': 192,
        'icons/Icon-maskable-512.png': 512,
    }

    for filename, size in sizes.items():
        img = draw_icon(size)
        path = os.path.join(web_dir, filename)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path, 'PNG')
        print(f'  wrote {path} ({size}x{size})')

    # Also generate android icons
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    android_res = os.path.join(base, 'unburden_app', 'android', 'app', 'src', 'main', 'res')
    for folder, size in android_sizes.items():
        img = draw_icon(size)
        folder_path = os.path.join(android_res, folder)
        os.makedirs(folder_path, exist_ok=True)
        img.save(os.path.join(folder_path, 'ic_launcher.png'), 'PNG')
        print(f'  wrote {folder}/ic_launcher.png ({size}x{size})')

    print('Done!')

if __name__ == '__main__':
    main()
