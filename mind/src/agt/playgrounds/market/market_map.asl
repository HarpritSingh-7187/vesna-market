// * MARKET PLAYGROUND MAP

// --- NTPP: Containment (Regions inside Sections) ---
// Section 1: Proteins/Sauces
map_ntpp(sauce, section1).
map_ntpp(fish, section1).
map_ntpp(butcher, section1).

// Section 2: Dairy/Bakery/Drinks
map_ntpp(dairy, section2).
map_ntpp(bakery, section2).
map_ntpp(bread, section2).
map_ntpp(drinks, section2).

// Section 3: Fruit & Veg
map_ntpp(fv, section3).

// --- EC: Externally Connected (Adjacency flow) ---

// ENTRY -> SECTION 3
map_ec(entry, fv).

// SECTION 3 -> DOOR 1 -> SECTION 2
map_ec(fv, fence_door_rotate).
map_ec(fence_door_rotate_1, bread).
map_ec(fence_door_rotate_1, drinks).

// Bread <-> Bakery <-> Dairy
map_ec(bread, bakery).
map_ec(bakery, dairy).

map_ec(drinks, bakery).

// SECTION 2 -> DOOR 2 -> SECTION 1
map_ec(bakery, fence_door_rotate_2).
map_ec(dairy, fence_door_rotate_2).

map_ec(fence_door_rotate_2, fish).
map_ec(fence_door_rotate_2, butcher).

// Fish <-> Sauce <-> Butcher
map_ec(fish, sauce).
map_ec(sauce, butcher).
// Fish <-> Butcher 
map_ec(fish, butcher).

// SECTION 1 -> CHECKOUT -> EXIT
map_ec(butcher, checkout).
map_ec(fish, checkout).
map_ec(sauce, checkout).

map_ec(checkout, exit).


// --- PO: Partial Overlap (Doors connecting Sections) ---
// Door 1 connects Section 3 (FV) and Section 2
map_po(fence_door_rotate_1, section2).
map_po(fence_door_rotate_1, section3).

// Door 2 connects Section 2 and Section 1
map_po(fence_door_rotate_2, section1).
map_po(fence_door_rotate_2, section2).
