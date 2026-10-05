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

## Chování v aplikaci od 0.7.0

Jedna povinná kontrola při spuštění procesu. Bez sítě či při chybě ověření zůstávají funkce zamčené. Opakování je ruční. Po ověření aktuální verze se další kontroly neplánují. Vlastní SPUUserDriver nenabízí Skip ani Dismiss uživateli. Instalace přes Sparkle nahrazuje aktualizovanou kopii na stejném místě; nevyhledává ani nemaže jiné kopie na disku. Historie a média leží mimo bundle.

Kanál 0.7.0 používá podepsaný ZIP v `instalace/` na main a raw URL v appcastu. Zveřejňujte zdroje, ZIP a odpovídající appcast v jednom commitu. Před publikací ověřte podpis nástrojem `publish_appcast.py` a upravte adresu enclosure na skutečné umístění archivu. Soukromý klíč do repozitáře nepatří.

Kontrola aktualizací nenahrazuje licencování a nemůže zpětně vynutit politiku ve starých verzích bez brány.

## Předání instalace od 0.7.1

`showReady(toInstallAndRelaunch:)` jen odsouhlasí instalaci a uloží stav. Teprve `showInstallingUpdate(withApplicationTerminated:retryTerminatingApplication:)` potvrzuje připravenost externího instalátoru. Potom se jednorázově zavolá `NSApp.terminate`; AppDelegate v této fázi uloží/zastaví práci bez dalšího potvrzení. Chyba nebo ukončení cyklu ruší čekající požadavek na zavření. Aplikace se tedy neukončuje při pouhém stažení či rozbalování. Výměnu a relaunch provádí Sparkle se zapnutým instalačním UI. Starou verzi nikdy nemažeme před ověřením nové.
