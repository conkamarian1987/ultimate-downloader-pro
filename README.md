<div align="center">
  <img src="docs/images/app-icon.png" alt="Ultimate Downloader Pro" width="160">

  # Ultimate Downloader Pro

  **Nativní správce stahování médií pro macOS**

  ![Verze](https://img.shields.io/badge/verze-Beta%200.6.0%20%2810%29-13a89e)
  ![macOS](https://img.shields.io/badge/macOS-14%2B-111827?logo=apple)
  ![Architektura](https://img.shields.io/badge/Apple%20silicon-arm64-334155)
  ![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white)
</div>

Ultimate Downloader Pro spojuje stahování videí, audia a obrázků do jedné přehledné aplikace. Nabízí průzkum médií na stránce, výběr kvality a formátu, společnou frontu, historii, protokoly a přihlášení ke službám ve vlastním bezpečně odděleném okně.

> **Beta verze:** aplikace je určena k testování. Funkčnost jednotlivých služeb se může měnit podle jejich webu a použitých extraktorů.

## Stažení a instalace

Aktuální balíček **0.6.0 (10)** je pro Macy s **Apple silicon (M1 a novější)**. VLC je součástí aplikace.

### [Stáhnout Ultimate Downloader Pro Beta 0.6.0 — sestavení 10](https://github.com/conkamarian1987/ultimate-downloader-pro/raw/refs/heads/main/instalace/UltimateDownloaderPro-0.6.0.zip)

**Máte verzi 0.5.0?** V nabídce aplikace zvolte **Zkontrolovat aktualizace…**. Balíček se ověří podpisem a instalace počká na dokončení stahování a zavření přehrávače. Při prvním přechodu na 0.6.0 ještě ověřujeme celý instalační postup.

Pro první instalaci:

1. Stáhněte ZIP a rozbalte jej dvojklikem ve Finderu.
2. Ukončete starší verzi aplikace.
3. Přetáhněte **Ultimate Downloader Pro.app** do složky **Aplikace** a potvrďte nahrazení.
4. Spusťte aplikaci ze složky Aplikace.

Instalátor má lokální podpis a zatím není notarizován společností Apple. Při prvním spuštění proto může macOS vyžadovat potvrzení v **Nastavení systému → Soukromí a zabezpečení**.

Kontrolní SHA-256 je uveden v souboru [SHA256SUMS.txt](instalace/SHA256SUMS.txt).

## Hlavní funkce

- video, audio a obrázky v jedné aplikaci;
- čtyři záložky **Z odkazu**, **YouTube**, **Hellspy** a **Fronta**;
- vyhledávání Hellspy se stránkováním, kvalitou a tlačítky Přehrát / Stáhnout u každého výsledku;
- vestavěný VLC přehrávač se zvukovými stopami, titulky, poměrem stran, ořezem, přiblížením a časovým posunem;
- celá obrazovka pouze pro video; kurzor a ovládání se při přehrávání skryjí po třech sekundách nečinnosti;
- ochrana displeje proti ztmavení a uspání během přehrávání na celé obrazovce;
- živý průběh, přenesená velikost a rychlost stahování z Hellspy;
- podepsané aktualizace přes Sparkle s automatickou i ruční kontrolou;
- univerzální odkaz pro video, audio i galerie; dostupná média zjišťují yt-dlp a gallery-dl;
- volby formátu, kvality a cílové složky přímo pod odkazem;
- přehrávač YouTube přímo v záložce; při přepnutí mimo YouTube se uvolní;
- kontrola MP4 a případný převod na H.264 / AAC pro přehrávače Apple, s průběhem převodu ve frontě;
- vyhledávání YouTube, načtení playlistů a hromadný výběr položek;
- výběr dostupné kvality, MP4, MKV, WebM, MP3, M4A, FLAC, WAV, JPEG a PNG;
- časový výřez videa nebo zvuku;
- samostatné titulky SRT, pokud je zdroj nabízí;
- společná fronta, zrušení úlohy, opakování, historie, protokoly a otevření ve Finderu;
- oblíbené profily stahování;
- volitelné sledování odkazu ve schránce bez automatického spuštění stahování;
- systémová oznámení o dokončení a chybách;
- světlý, tmavý a systémový motiv;
- rozšíření **Sdílet** pro předání odkazu z jiných aplikací.

Ve verzi **Beta 0.6.0 (10)** přibyla záložka Hellspy a vestavěný přehrávač VLC. Nastavení otevřete ozubeným kolečkem. Historie, uložené profily a nastavení zůstávají zachované. Podrobnosti obsahuje [CHANGELOG.md](CHANGELOG.md).

## Jak aplikaci používat

### Z odkazu

Vložte HTTP(S) adresu a zvolte **Načíst odkaz**. Pod ní jsou přímo volby videa či zvuku, formátu, kvality a cílové složky. Po načtení jediného média se položka vybere automaticky. U více položek použijte **Volby stažení**, zaškrtnutí nebo **Vybrat vše**. Obrázkové volby se zobrazí pro nalezené obrázky. Oblíbené profily a časový výřez jsou rozbalovací. **Stáhnout** zařadí úlohu do fronty.

Pro širší průzkum zapněte **Prohledat také obrázky a média na webové stránce**. Pro celý playlist či album použijte příslušný přepínač po načtení odkazu.

### YouTube

Zadejte dotaz nebo odkaz a zvolte **Vyhledat**. U výsledku vyberte **Přehrát** nebo **Volby stažení**. Přehrávač i nastavení stažení se zobrazí ve stejné záložce. Výsledky a rozepsané vstupy zůstávají při přepínání záložek zachované.

### Hellspy a přehrávač

Zadejte název videa a zvolte **Vyhledat**. Další výsledky se načítají při posouvání dolů nebo tlačítkem **Další výsledky**. Každá karta má **Přehrát**, **Stáhnout** a výběr kvality; tlačítko **Načíst další kvality** načte dostupné varianty. Přehrání automaticky přesune pohled k přehrávači. Stahování pokračuje ve společné frontě.

**Obraz a zvuk** umožňuje vybrat zvukovou stopu, zapnout nebo vypnout titulky, přidat vlastní soubor titulků a upravit obraz i časový posun zvuku/titulků. Dostupnost stop závisí na konkrétním videu.

Tlačítkem celé obrazovky zvětšíte samotné video. Po třech sekundách nečinnosti během přehrávání zmizí kurzor i ovládání; pohyb myši je vrátí. **Esc** ukončí celou obrazovku. Při pauze, zastavení nebo návratu do okna se uvolní ochrana displeje proti uspání. Přepnutí na jinou záložku přehrávání ukončí.

### Fronta a nastavení

Záložka **Fronta** ukazuje počet čekajících a spuštěných úloh, průběh stahování i převodu, historii a protokoly. Mazání historie neodstraňuje stažené soubory. Ozubené kolečko otevírá motiv, nástroje, schránku, oznámení a přihlášení ke službám.

## Obrázky rozhraní

Skutečné snímky verze **Beta 0.6.0 (10)** dodané autorem 5. 10. 2026.

### Z odkazu — formát a kvalita

![Z odkazu — formát a kvalita](docs/images/odkaz-0.6.0.png)

### YouTube — volby stažení

![YouTube — volby stažení](docs/images/youtube-volby-0.6.0.png)

### YouTube — výsledky vyhledávání

![YouTube — výsledky vyhledávání](docs/images/youtube-vysledky-0.6.0.png)

### Hellspy — výsledky, kvalita a ovládání u každého videa

![Hellspy — výsledky, kvalita a ovládání u každého videa](docs/images/hellspy-vysledky-0.6.0.png)

### Fronta — procenta, přenesená velikost a rychlost

![Fronta — procenta, přenesená velikost a rychlost](docs/images/fronta-0.6.0.png)

### Hellspy — vestavěný přehrávač VLC

![Hellspy — vestavěný přehrávač VLC](docs/images/hellspy-prehravac-0.6.0.png)

## Potřebné nástroje

Pro stahování přes obecné odkazy a převody aplikace využívá systémové nástroje. VLC a Sparkle jsou vložené přímo do balíčku; samostatnou aplikaci VLC nepotřebujete. Hellspy používá vlastní přímé stahování.

```sh
brew install yt-dlp ffmpeg gallery-dl
```

Jejich stav lze zkontrolovat a aktualizovat přímo v nastavení aplikace. Homebrew se automaticky neinstaluje.

## Soukromí a zabezpečení

- Zpracování a ukládání probíhá lokálně na Macu.
- Sledování schránky je ve výchozím stavu vypnuté a nikdy samo nespustí stahování.
- Přihlášení probíhá ve vlastním WebKit okně aplikace; cookies Safari se nečtou.
- Extraktoru se předají pouze cookies platné pro danou doménu prostřednictvím dočasného souboru s oprávněním `0600`, který se po operaci odstraní.
- Aplikace neobchází DRM. Některé soukromé stránky, CAPTCHA nebo expirované odkazy nemusí fungovat.

Další informace jsou v [zásadách ochrany soukromí](docs/SOUKROMI.md) a [bezpečnostních pokynech](SECURITY.md).

## Systémové požadavky

- macOS 14 Sonoma nebo novější;
- Mac s Apple silicon (aktuálně distribuovaný balíček `arm64`);
- připojení k internetu;
- Homebrew a nástroje uvedené výše pro skutečné stahování a převod.

## Sestavení ze zdrojů

Nejdříve stáhněte připnuté frameworky, poté projekt otevřete v Xcode nebo použijte příkaz:

```sh
python3 Tools/setup_sparkle.py
python3 Tools/setup_vlckit.py
xcodebuild \
  -project UltimateDownloader.xcodeproj \
  -scheme UltimateDownloader \
  -configuration Release \
  -derivedDataPath build.noindex \
  build
```

Podrobnosti jsou v [návodu pro sestavení](docs/SESTAVENI.md). Příspěvky a hlášení chyb se řídí souborem [CONTRIBUTING.md](CONTRIBUTING.md).

## Ověření a známá omezení

Release sestavení 0.6.0 (10) pro `arm64` a kontrola lokálního podpisu aplikace prošly 5. 10. 2026. Aktualizační ZIP má ověřený podpis Ed25519. Prošly testy živých údajů přenosu (známá i neznámá velikost a zrušení), stránkování Hellspy, dekódování VLC, přepínání stop a titulků, poměru stran, časového posunu a odložení aktualizace při obsazené frontě nebo přehrávání. Ruční kontrolu posledních oprav potvrdil uživatel.

**Skutečný přechod z 0.5.0 na 0.6.0 přes Sparkle zatím čeká na ověření.** Test podpisu a dostupnosti balíčku sám o sobě neověřuje instalaci. Aplikace má ad-hoc podpis, není podepsaná Apple Developer ID ani notarizovaná. Podpis aktualizace Sparkle je samostatný mechanismus.

Podrobnosti vydání: [0.6.0](docs/VYDANI-0.6.0.md). Návod pro další podepsané aktualizace: [Tools/AKTUALIZACE.md](Tools/AKTUALIZACE.md).

Podpora webů závisí také na aktuální verzi `yt-dlp`, `gallery-dl` a změnách konkrétních služeb. Označení podporované služby proto neznamená záruku každého odkazu nebo soukromého obsahu.

## Právní upozornění

Stahujte pouze obsah, ke kterému máte potřebná práva nebo souhlas. Uživatel odpovídá za dodržení autorského práva a podmínek příslušné služby.

## Použité projekty

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [FFmpeg](https://ffmpeg.org/)
- [gallery-dl](https://github.com/mikf/gallery-dl)
- [VLCKit](https://code.videolan.org/videolan/VLCKit) — [licence](Tools/VLCKit-LICENSE.txt), [informace k distribuci](Tools/VLCKit-NOTICE.md)
- [Sparkle](https://sparkle-project.org/) — [licence](Tools/Sparkle-LICENSE.txt)

## Autor a licence

Vytvořil [Marian Čonka](https://github.com/conkamarian1987). Zdrojový kód a grafické podklady jsou zveřejněny pro kontrolu a osobní použití; další podmínky určuje soubor [LICENSE](LICENSE).

