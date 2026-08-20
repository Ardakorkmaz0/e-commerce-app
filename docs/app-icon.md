# The mobile app icon

The Android launcher icon is the site logo,
[`web/public/images/logo.png`](../web/public/images/logo.png), resized into
every density Android asks for. None of those PNGs is edited by hand —
they are generated from two source images by
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons).

## Regenerating it

After changing either source image:

```bash
cd mobile
dart run flutter_launcher_icons
```

Then **fully restart** the app. Launcher icons are baked into the APK at
build time, so a hot reload — and often a plain re-run — keeps showing the
old one. Uninstalling and reinstalling is the reliable way to see the
change on a device that has already cached it.

## The two source images

Both live in `mobile/assets/icon/` and are 1024×1024.

| File | Used by | Background |
| --- | --- | --- |
| `app_icon.png` | Android 7 and older | Cream `#FEFBF5` |
| `app_icon_foreground.png` | Android 8+ adaptive icons | Transparent |

They exist separately because Android 8 changed how icons are drawn. An
**adaptive icon** is two layers — a background and a foreground — and the
launcher crops the pair to whatever shape it likes: a circle, a squircle,
a rounded square, a teardrop. Only the middle of the canvas is guaranteed
to survive that crop, so the foreground carries the mark alone, smaller
and on transparency, while the cream is declared as a flat colour.

The logo's own artwork could not be used directly for either. Its mark
sits off-centre inside a wide border — measured at 762×790 in a 1254×1254
image, about 61% of the canvas, with more space at the bottom left than
the top right. Pasting that into an icon would have produced a small,
visibly lopsided mark. Both sources are therefore built by cropping to the
mark's real bounding box and re-centring it deliberately.

## Why the foreground is 80%

This one is easy to get wrong, and the first attempt did.

Android's adaptive canvas is 108dp. The launcher may crop the outer 18dp
on every side, leaving 72dp visible, and only a circle of roughly 66dp is
guaranteed — about 61% of the canvas. Anything important has to fit
inside that.

The generated `mipmap-anydpi-v26/ic_launcher.xml` also wraps the
foreground in an inset:

```xml
<foreground>
    <inset android:drawable="@drawable/ic_launcher_foreground"
           android:inset="16%" />
</foreground>
```

16% off each side leaves 68% of the layer. That inset multiplies with
whatever size the mark already is in the image. The mark was first drawn
at 56% of its own canvas, which looked safe on its own but came out at
0.56 × 0.68 = **38%** of the finished icon — a tiny mark adrift in cream.

Sizing it at 80% instead lands it at 0.80 × 0.68 = **54%**, comfortably
inside the 61% safe circle and large enough to read at 48dp.

## What the generator produced

```
mipmap-mdpi/ic_launcher.png                48×48     legacy icon
mipmap-hdpi/ic_launcher.png                72×72
mipmap-xhdpi/ic_launcher.png               96×96
mipmap-xxhdpi/ic_launcher.png             144×144
mipmap-xxxhdpi/ic_launcher.png            192×192
drawable-mdpi/ic_launcher_foreground.png  108×108     adaptive foreground
drawable-hdpi/ic_launcher_foreground.png  162×162
drawable-xhdpi/ic_launcher_foreground.png 216×216
drawable-xxhdpi/ic_launcher_foreground.png 324×324
drawable-xxxhdpi/ic_launcher_foreground.png 432×432
mipmap-anydpi-v26/ic_launcher.xml                     adaptive definition
values/colors.xml                                     ic_launcher_background
```

`AndroidManifest.xml` already pointed at `@mipmap/ic_launcher` and did not
need changing. On Android 8+ that name resolves to the XML in
`mipmap-anydpi-v26/`; older versions fall back to the plain PNGs.

## iOS

The config sets `ios: false`, because this project has no `ios/` folder —
it is an Android build only. Turning it on without one makes the generator
crash trying to write into `ios/Runner/Assets.xcassets/`.

If an iOS target is ever added, set `ios: true` and the two iOS settings
already in `pubspec.yaml` take effect. They matter because iOS forbids
transparency in app icons: `remove_alpha_ios` flattens the image and
`background_color_ios` says what to flatten it onto, without which the
corners come out black.
