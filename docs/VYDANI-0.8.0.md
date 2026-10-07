# Encore 0.8.0 (13)

Přejmenování Ultimate Downloader Pro, nová ikona, levý panel, Liquid Glass a originální značky služeb. Dosavadní funkce zůstávají; Fastshare, Webshare, rádia a Google Disk jsou plán.

## Přechod původních instalací

Zachován cz.ultimate.downloaderpro, SUFeedURL, SUPublicEDKey, schéma ultimatedownloader a Application Support/UltimateDownloaderPro. Sparkle najde Encore.app podle stejného bundle ID a nahradí starou aplikaci na jejím současném místě. Název fyzického souboru může zůstat Ultimate Downloader Pro.app; uvnitř jde o Encore. Staré verze bez Sparkle vyžadují ruční instalaci. Od 0.7.0 je ověření při spuštění povinné. Od 0.7.1 je automatické ukončení po připravenosti instalátoru; starší aktualizační kód může vyžadovat ruční ukončení.

## Ověření

Release build, striktní kontrola podpisu, podpis Ed25519 a automatické testy brány. Skutečný izolovaný test Sparkle: build 1 Ultimate Downloader Pro -> build 2 Encore, různé názvy balíčků, stejná identita; starý PID skončil, nový se spustil, old-only marker odstraněn a new-only marker existuje. GUI potvrzuje dokončení verze 2.

Vizuální ověření celého produkčního okna není potvrzeno kvůli opakované chybě Sky Computer Use. Starší screenshoty v README dokumentují 0.6.0 a nejsou označovány jako nové.
