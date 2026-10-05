# Ultimate Downloader Pro 0.6.0 (10)

Vydání přidává Hellspy a vestavěný VLC přehrávač. Přehled funkcí a ovládání najdete v [README](../README.md), úplný seznam změn v [CHANGELOG](../CHANGELOG.md).

## Ověření 5. 10. 2026

- Release `arm64` sestaveno v Xcode; kontrola `codesign --verify --deep --strict` prošla.
- Aktualizační ZIP podepsán Ed25519 a ověřen podpisovým nástrojem Sparkle.
- Skutečný lokální HTTP přenos: průběžné údaje, rychlost, známá i neznámá velikost a zrušení.
- Stránkování Hellspy: serverový ukazatel, krátká stránka, duplicity a konec výsledků.
- VLC: dekódování obrazu/zvuku, dvě audio stopy, titulky, poměr stran, časování, přetáčení a reset.
- Systémová ochrana displeje: vytvoření a uvolnění požadavku proti uspání.
- Instalace čeká při stahování, čekající frontě i otevřeném přehrávači; poté se spustí právě jednou.
- Uživatel ručně zkontroloval poslední opravy a potvrdil funkčnost.

## Test aktualizace z 0.5.0

1. Ukončete testovací 0.6.0 a spusťte nainstalovanou aplikaci 0.5.0 ze složky Aplikace.
2. Zvolte **Zkontrolovat aktualizace…**. Má se nabídnout **0.6.0 (10)**.
3. Dokončete stažení a instalaci. Aktualizace čeká na dokončení fronty a zavření přehrávače.
4. Po opětovném spuštění ověřte verzi 0.6.0, záložku Hellspy a zachování historie/nastavení.

Tento celý přechod při zveřejnění ještě není potvrzený. Aplikace má lokální ad-hoc podpis; nejde o Apple Developer ID ani notarizaci.
