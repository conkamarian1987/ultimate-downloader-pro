# Beta 0.7.0 (11)

Povinná kontrola verze pouze při spuštění aplikace. Při nedostupném internetu nebo serveru nelze pokračovat; uživatel může kontrolu zopakovat nebo aplikaci ukončit. Novou verzi nelze přeskočit. Instalace nahrazuje aktualizovanou kopii a zachovává uživatelská data.

## Ověření před vydáním

- Release build v Xcode úspěšný.
- Kontrola podpisu aplikace a Ed25519 ZIPu úspěšná.
- Testy aktuální/verze navíc, požadované aktualizace, nepodporovaného systému, prázdného kanálu, offline chyby, zavření dialogu, jednorázové instalace a nového zamčeného procesu úspěšné.
- Ovládání skutečného okna nástrojem CUA selhalo. Vizuální stav a celý přechod na 0.7.0 nejsou automaticky ověřené.

## Ruční test

1. Ve verzi 0.6.0 zvolte Zkontrolovat aktualizace a nainstalujte 0.7.0.
2. Ověřte v informacích verzi 0.7.0 (11), historii a nastavení.
3. Ukončete aplikaci, odpojte internet a spusťte ji znovu: pracovní záložky musí zůstat nedostupné.
4. Připojte internet a zvolte Zkusit znovu: po úspěšném ověření musí fungovat běžné rozhraní.
5. Po ověření odpojte internet: aplikace se za běhu nesmí znovu zamknout. Síťové služby samozřejmě připojení potřebují.
6. Další spuštění musí ověření opakovat. Povinnou instalaci novější verze je třeba ověřit při dalším vydání.

Kontrola aktualizace není ochrana trialu ani nákupů. Verze před 0.7.0 ji neobsahují a mohou dále fungovat samostatně.
