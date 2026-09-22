# Sestavení projektu

## Požadavky

- macOS 14 nebo novější;
- aktuální Xcode s podporou SwiftUI pro zvolený systém;
- nástroje příkazové řádky Xcode.

## Xcode

1. Otevřete `UltimateDownloader.xcodeproj`.
2. Vyberte schéma `UltimateDownloader`.
3. Jako cíl zvolte **My Mac**.
4. Spusťte sestavení nebo aplikaci.

Projekt obsahuje hlavní aplikaci a rozšíření **Share**. Pro vlastní distribuci nastavte vlastní podpisový tým a identifikátory balíčku.

## Příkazová řádka

```sh
xcodebuild \
  -project UltimateDownloader.xcodeproj \
  -scheme UltimateDownloader \
  -configuration Release \
  -derivedDataPath build.noindex \
  build
```

Pracovní sestavení ukládejte mimo repozitář. Soubory v `build.noindex` jsou ignorovány.

