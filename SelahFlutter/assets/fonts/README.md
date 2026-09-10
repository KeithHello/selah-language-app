# Bundled fonts

Web packages these fonts so the first offline restart does not depend on a font CDN.

- `PlusJakartaSans.ttf`：Google Fonts [Plus Jakarta Sans](https://github.com/google/fonts/tree/main/ofl/plusjakartasans) ，SIL OFL；license in `PlusJakartaSans-OFL.txt`.
- `NotoSansSC.ttf`：Google Fonts [Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc) ，SIL OFL；license in `NotoSansSC-OFL.txt`. Used as the Web CJK fallback.
- `Roboto.ttf`：Flutter SDK material font `roboto-regular.ttf`；Apache 2.0 license in `Roboto-LICENSE.txt`. CanvasKit requires this default family even when the app uses another primary font.

The source fonts are unmodified. Web typography explicitly names the bundled CJK fallback; native typography retains its previous fallback behavior.
