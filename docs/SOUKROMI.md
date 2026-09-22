# Ochrana soukromí

Ultimate Downloader Pro ukládá nastavení, historii úloh a oblíbené profily lokálně na Macu. Aplikace nemá vlastní analytickou službu ani uživatelský účet.

## Síťová komunikace

Síťové požadavky směřují na adresy, které uživatel vloží nebo vybere, a na služby potřebné pro načtení jejich webového obsahu. Externí nástroje `yt-dlp` a `gallery-dl` mohou komunikovat s příslušnými službami podle zadaného odkazu.

## Přihlášení a cookies

Přihlášení probíhá ve vloženém WebKit okně. Aplikace nečte cookies ze Safari. Při práci s přihlášenou službou se exportují pouze cookies odpovídající dané doméně do dočasného souboru s oprávněním `0600`; po dokončení operace se soubor odstraní.

## Schránka a oznámení

Sledování schránky je volitelné a ve výchozím stavu vypnuté. Rozpoznaný odkaz se pouze nabídne; analýza ani stažení se nespustí bez akce uživatele. Systémová oznámení jsou rovněž volitelná.

## Historie

Vymazání historie odstraní záznamy úloh aplikace. Již stažené soubory ani cílové složky se tím nemažou.

