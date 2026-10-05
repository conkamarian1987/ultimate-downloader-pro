# Sestavení projektu

## Požadavky

- macOS 14 nebo novější;
- aktuální Xcode s podporou SwiftUI pro zvolený systém;
- nástroje příkazové řádky Xcode.

## Xcode

Nejdříve spusťte `python3 Tools/setup_sparkle.py` a `python3 Tools/setup_vlckit.py`. Stáhnou připnuté frameworky a ověří jejich SHA-256.

1. Otevřete `UltimateDownloader.xcodeproj`.
2. Vyberte schéma `UltimateDownloader`.
3. Jako cíl zvolte **My Mac**.
4. Spusťte sestavení nebo aplikaci.

Projekt obsahuje hlavní aplikaci a rozšíření **Share**. Pro vlastní distribuci nastavte vlastní podpisový tým a identifikátory balíčku.

## Příkazová řádka

```sh
python3 Tools/setup_sparkle.py
python3 Tools/setup_vlckit.py
xcodebuild \
  -project UltimateDownloader.xcodeproj \
  -scheme UltimateDownloader \
  -configuration Release \
  -derivedDataPath build.noindex \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  build
```

Pracovní sestavení ukládejte mimo repozitář. Soubory v `build.noindex` jsou ignorovány.

