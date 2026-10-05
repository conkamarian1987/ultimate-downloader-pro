# Změny

## Beta 0.6.0 — sestavení 10 (5. 10. 2026)

- Doplněno šest aktuálních snímků rozhraní: Z odkazu, YouTube, Hellspy, přehrávač a průběh stahování.

- Nová záložka Hellspy s vyhledáváním přímo v aplikaci.
- Správné stránkování podle ukazatele serveru, automatické načítání dalších výsledků a odstranění duplicit.
- Přehrát, Stáhnout a dostupná kvalita přímo u každé karty; automatický přesun k přehrávači.
- Vestavěný VLC: zvukové stopy, titulky i vlastní soubor, poměr stran, ořez, přiblížení a časový posun.
- Celá obrazovka pro samotné video, návrat klávesou Esc.
- Automatické skrytí kurzoru a lišty po třech sekundách nečinnosti; návrat pohybem myši.
- Ochrana displeje před ztmavením/uspáním při přehrávání na celé obrazovce, uvolnění při pauze nebo ukončení.
- Průběžné procento, přenesené bajty a aktuální rychlost stahování Hellspy. U neznámé velikosti neurčitý indikátor.
- Přímý odkaz na video se obnovuje až při zahájení úlohy, aby nevypršel během čekání.
- Aktualizace navíc počká na zavření přehrávače.
- Balíček pro Apple silicon (`arm64`), ověřený podpis aktualizace Ed25519.
- Sestavení a automatické testy prošly, uživatel potvrdil funkčnost posledních oprav. Skutečný přechod 0.5.0 → 0.6.0 čeká na test po zveřejnění.

## Beta 0.5.0 — sestavení 9 (28. 9. 2026)

- Podepsané aktualizace Sparkle přes kanál na GitHubu.
- Automatická a ruční kontrola nové verze, volitelné automatické stažení.
- Instalace se odkládá při stahování a čekajících úlohách.
- Ověřování podpisu balíčku, identity aplikace a rostoucího čísla sestavení.

## Beta 0.4.0 — sestavení 7 (28. 9. 2026)

- Domovskou obrazovku a levé menu nahrazují horní záložky Z odkazu, YouTube a Fronta.
- Volby stahování jsou přímo pod odkazem; galerie umožňují jednotlivý i hromadný výběr.
- YouTube má vlastní vyhledávání, vložený přehrávač a volby stažení.
- Nastavení je dostupné přes ozubené kolečko, fronta má počet aktivních úloh.
- Zachované opravy 0.3.2/0.3.3: MP4 kompatibilní s Apple přehrávačem, bezpečné nahrazení jediného výstupního souboru, průběh převodu a finalizace.
- Verze i číslo sestavení jsou sjednocené v aplikaci, rozšíření a informacích o aplikaci.
- Univerzální instalační ZIP pro arm64 a x86_64; aktualizovaný návod a SHA-256.
- Doplněny skutečné screenshoty všech tří záložek. Koncové GUI testování zůstává neověřené kvůli pádu ovládací služby; podrobnosti v README.

# Přehled změn

## Beta 0.3.1

- Zvýšen kontrast světlého motivu a pomocných textů.
- Přidáno odebrání jednotlivého dokončeného, neúspěšného nebo zrušeného záznamu.
- Přidáno vymazání celé historie fronty.
- Mazání historie neodstraňuje stažené soubory ani cílové složky.

## Beta 0.3

- Sjednocen název aplikace na **Ultimate Downloader Pro**.
- Přidáno volitelné sledování odkazů ve schránce.
- Přidána systémová oznámení o dokončení a chybě.
- Přidány oblíbené profily stahování.
- Přidán časový výřez videa a zvuku.
- Rozšířeno nastavení a obrazovka o aplikaci.

## Beta 0.2

- Přidán průzkum médií na stránce a galerie obrázků.
- Rozšířen výběr formátů, kvalit a rozměrů.
- Přidáno přihlášení ke službám ve vlastním WebKit okně.

## Beta 0.1

- První nativní verze pro macOS.
- Přeneseno původní chování zkratky do aplikace SwiftUI.
- Základní fronta, profily kvality, protokoly a zrušení stahování.

