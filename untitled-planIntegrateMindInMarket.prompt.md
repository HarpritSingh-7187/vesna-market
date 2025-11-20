Breve TL;DR — Estrarre/parametrizzare la logica del “mind” attualmente in `office`, creare o condividere uno script/micro-modulo riutilizzabile e collegarlo alla scena `MarketMain.tscn` (o alla scena `market` in `env/market/`). Questo evita duplicazione e garantisce comportamenti coerenti tra scene.

Plan: Integrare la logica `mind` in Market

Steps
1. Esaminare: aprire `office/scripts/` (es. `actor.gd`, `user.gd`, `vesna.gd`) e `office/office.tscn` per trovare l’entrypoint del mind.
2. Identificare dipendenze: controllare `src/agt/*.asl` e `mind/` per script/risorse usate dal mind.
3. Estrarre: creare `env/scripts/mind.gd` (o `scripts/mind.gd`) con la logica condivisa; mantenere API parametriche.
4. Parametrizzare: sostituire riferimenti hard-coded a nodi in `office` con proprietà esportate (`NodePath`) o metodi init.
5. Adattare scena Market: aprire `docs/env/market/playgrounds/MarketMain.tscn` (o `env/market/`) e aggiungere i nodi richiesti o impostare i `NodePath` per `mind.gd`.
6. Registrare/Caricare: decidere tra AutoLoad singleton (`Project Settings > AutoLoad`) o instanziazione per scena; aggiornare `project.godot` se serve.
7. Test rapido: lanciare la scena `MarketMain.tscn`, osservare console/log, iterare sui NodePath mancanti o segnali non connessi.

Further Considerations
1. Scelta architetturale: preferisci un singleton globale (AutoLoad) / istanza per scena / modulo riutilizzabile? Scegliere ora influisce su passi successivi.
2. Comportamento: vuoi che il mind in Market ripeta esattamente il comportamento di Office o vada adattato (es. agenti diversi, trigger di scena)?
3. Risorse: confermi che asset usati dal mind (animazioni, navigation meshes, addon) sono presenti sotto `env/market/assets` o devono essere copiati?

Domande per l'implementatore
- Preferisci che prepari l'elenco preciso di file/funzioni da modificare (con i `NodePath` attesi), oppure vuoi che crei direttamente una bozza di `mind.gd` riutilizzabile?
- Vuoi che il mind sia un AutoLoad singleton o venga istanziato per scena (consiglio: istanziato per scena se comportamento locale, singleton se stato globale condiviso)?
- Ci sono differenze funzionali note tra Office e Market che richiedono variazioni (es. diversi tipi di agenti o trigger)?

Notes
- Questo file è una copia fedele del piano discusso; nessuna modifica ai file esistenti è stata effettuata in questa fase.
- Quando sei pronto, procedo a generare la lista precisa di file e a proporre patch mirate per il refactor.
