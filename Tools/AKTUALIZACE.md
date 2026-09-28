# Vydávání aktualizací

Aplikace používá Sparkle 2.10.0, podepsané ZIP balíčky Ed25519 a kanál `updates/appcast.xml` na větvi main. Samotná aplikace je nyní podepsaná ad-hoc; nejde o Apple Developer ID ani notarizaci.

## Sestavení na novém Macu

1. `python3 Tools/setup_sparkle.py` stáhne připnutý Sparkle a zkontroluje SHA-256.
2. Otevřete `UltimateDownloader.xcodeproj` a sestavte Release (Product → Build For → Profiling).
3. Před každým vydáním zvyšte `CFBundleShortVersionString` a celočíselné `CFBundleVersion` v Info.plist.

## Podepsání vydání

Na původním Macu je soukromý klíč uložen v `~/Library/Application Support/UltimateDownloaderSigning/ed25519.key` (složka 0700, soubor 0600). Není součástí repozitáře ani distribučních ZIPů. Zálohujte ho bezpečně; bez něj existující instalace nebudou důvěřovat dalším aktualizacím. Klíč nevkládejte do chatu, GitHubu ani veřejných příloh.

```
python3 Tools/prepare_update.py '/cesta/Ultimate Downloader Pro.app' '/cesta/vydani'
```

Vzniknou `UltimateDownloaderPro-X.Y.Z.zip` a `update-manifest.json`. Přiložte oba soubory k rozepsanému GitHub Release s tagem `vX.Y.Z`, potom vydání publikujte jako stabilní (nikoliv prerelease). Soubory přiložte PŘED publikováním vydání.

Workflow `Publish signed update` stáhne oba soubory, nezávisle ověří podpis pomocí OpenSSL, ověří identitu aplikace a číslo sestavení a aktualizuje appcast na main. Soukromý klíč GitHub nepotřebuje. Ochrana větve musí umožnit zápis workflow; jinak workflow skončí chybou a feed zůstane nezměněný. Po doplnění chybějících příloh lze workflow znovu spustit ručně pro daný tag.

Pouhé nahrání zdrojových kódů nebo nepodepsaného ZIPu aktualizaci nevydá. První verzi se Sparkle je nutné nainstalovat běžným způsobem. Před prvním ostrým vydáním ověřte celý přechod mezi dvěma verzemi, zachování historie a odložení instalace při stahování. Lokální testy nenahrazují toto ověření.

## Chování v aplikaci

Kontrola každých šest hodin při spuštěné aplikaci; uživatel ji může vypnout a spustit ručně. Automatické stahování a instalaci může vypnout samostatně. Instalace čeká i na pozastavenou frontu; čekající úlohy je nutné dokončit nebo zrušit. Při síťové chybě zůstane dosavadní aplikace. Sparkle ověřuje podpis ještě před rozbalením archivu. Aktuální kanál je určen pro Apple Silicon (stejně jako dosavadní sestavení).
