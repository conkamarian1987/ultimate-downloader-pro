# Beta 0.7.1 (12)

Po stažení a ověření aktualizace aplikace počká na potvrzení připravenosti instalátoru Sparkle. Potom uloží stav a sama se ukončí bez další otázky. Externí instalátor nahrazuje původní kopii na stejném místě a spouští novou verzi. Průběh přípravy je viditelný v aplikaci; vlastní nahrazení může trvat jen krátce. Při chybě před předáním se aplikace neukončí.

Povinné ověření verze pouze při spuštění a blokování bez ověření zůstávají zachované. Další kontroly na pozadí se nepřidávají. Historie, nastavení a média se nemažou.

## Přechod ze starší verze

Ukončete a znovu spusťte 0.7.0. Nabídne 0.7.1. Přechod stále řídí kód 0.7.0; pokud čeká na ruční zavření, může ho vyžadovat naposledy. Opravené předání instalátoru se používá pro aktualizace zahájené z 0.7.1 a novějších.

## Ověření

Release build, testy brány a předání instalace, podpis aplikace i Ed25519 balíčku prošly. [Skutečný test výměny a restartu](TEST-INSTALACE-0.7.1.md) proběhl s odděleným testovacím bundlem, nikoli přepsáním uživatelovy instalace v /Applications. Ta je ponechána pro uživatelský test aktualizace.
