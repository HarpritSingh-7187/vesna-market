// * MARKET PLAYGROUND MAP

// --- NTPP: Containment (Reparti dentro Sezioni) ---
map_ntpp(salse, sezione1).
map_ntpp(pescheria, sezione1).
map_ntpp(macelleria, sezione1).
map_ntpp(border, sezione1).

map_ntpp(latticini, sezione2).
map_ntpp(dolciumi, sezione2).
map_ntpp(panetteria, sezione2).
map_ntpp(bevande, sezione2).

map_ntpp(ortofrutta, sezione3).

// --- EC: Externally Connected (Adiacenze) ---
map_ec(entrata, ortofrutta).
map_ec(uscita, border).
map_ec(uscita, casse).
map_ec(casse, macelleria).
map_ec(casse, pescheria).

// --- PO: Partial Overlap (Porte/Connessioni tra Sezioni) ---
// FenceDoorRotate2 collega Sezione1 e Sezione2
map_po(fence_door_rotate_2, sezione1).
map_po(fence_door_rotate_2, sezione2).

// FenceDoorRotate collega Sezione2 e Sezione3
map_po(fence_door_rotate, sezione2).
map_po(fence_door_rotate, sezione3).
