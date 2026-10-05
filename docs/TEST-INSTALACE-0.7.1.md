# Test předání instalace — 5. 10. 2026

## Automatické testy

`python3 Tests/test_update_gate.py` používá skutečný AppUpdates a AppDelegate. Ověřuje bránu aktuální verze, offline/prázdný/nekompatibilní kanál, neukončení při pouhé připravenosti balíčku, jednorázové ukončení po potvrzení instalátoru, zrušení čekajícího ukončení při chybě a zachování běžného potvrzení ukončení mimo aktualizaci.

## Skutečný instalační cyklus

Byla vytvořena oddělená aplikace InstallProbe s jiným bundle ID, stejným kódem AppUpdates/AppDelegate a vlastním lokálním aktualizačním kanálem. Obsahuje pouze testovací data, nikoli frontu či přihlášení uživatele. Nový ZIP byl podepsán Ed25519 a instalován přes Sparkle 2.10.0.

Po stisku Aktualizovat a restartovat:

1. Verze 1 běžela jako proces 8091.
2. Proběhlo stažení, ověření, příprava instalátoru a uložení stavu.
3. Původní aplikace schválila ukončení bez dalšího uživatelského zásahu.
4. Sparkle na téže cestě nahradil verzi 1 verzí 2.
5. Soubor old-only.txt byl odstraněn; new-only.txt nové verze byl přítomen.
6. Automaticky se spustil nový proces 8108, ověřil kanál a odemkl aplikaci.

Test tedy ověřil skutečné ukončení, nahrazení i automatický restart. Nejde jen o simulaci callbacků. Test nezahrnoval zásah do produkční instalace v /Applications ani obnovu při výpadku napájení. Následné čtení nového okna přes CUA mělo timeout; nový proces, verze na disku a úspěšné ověření kanálu jsou potvrzené protokolem. Samostatné okno instalátoru během velmi rychlé výměny nebylo vizuálně zachyceno.

Pro opakování: připravte fixture pomocí `python3 Tests/prepare_install_probe.py --work-dir /absolutni/cesta/k/nove-slozce.noindex` (vyžaduje místní podpisový klíč). Spusťte vypsanou installed/InstallProbe.app přes Finder a stiskněte Aktualizovat a restartovat. Výsledky jsou v events.log a v nahrazeném bundlu. Po testu ukončete testovací aplikaci i lokální server (Ctrl+C) a odstraňte testovací bundly.
