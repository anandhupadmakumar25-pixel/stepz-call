from PIL import Image

img = Image.open(r'C:\Users\hp\.gemini\antigravity-ide\brain\301d226e-0c14-493b-9eb3-92853253927c\.user_uploaded\media_1793259189924.png')
# Telecaller woman and soundwaves are on the right side
crop = img.crop((520, 0, 1024, 130)).convert('RGBA')
w, h = crop.size
r, g, b, a = crop.split()

fade_w = 120
fade_h = 35
new_alpha = []

for y in range(h):
    for x in range(w):
        factor = 1.0
        if x < fade_w:
            factor *= (x / float(fade_w))
        if y > h - fade_h:
            factor *= ((h - y) / float(fade_h))
        new_alpha.append(int(255 * factor))

alpha_img = Image.new('L', (w, h))
alpha_img.putdata(new_alpha)
crop.putalpha(alpha_img)
crop.save(r'f:\stepz\stepz_call\frontend\assets\images\telecaller_hero_art_exact.png')

# Also crop headset art with soft feathering
hs = img.crop((880, 395, 1015, 505)).convert('RGBA')
hw, hh = hs.size
hs_alpha = []
for y in range(hh):
    for x in range(hw):
        factor = 1.0
        if x < 25:
            factor *= (x / 25.0)
        if y < 25:
            factor *= (y / 25.0)
        hs_alpha.append(int(255 * factor))
hs_a_img = Image.new('L', (hw, hh))
hs_a_img.putdata(hs_alpha)
hs.putalpha(hs_a_img)
hs.save(r'f:\stepz\stepz_call\frontend\assets\images\headset_glowing_card.png')

print("Assets feathered and saved successfully!")
