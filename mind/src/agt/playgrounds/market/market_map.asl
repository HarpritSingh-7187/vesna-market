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
// Entry -> Section 3
map_ec(entry, fv).

// Section 3 -> Door 1 -> Section 2
map_ec(fv, fence_door_rotate).
map_ec(fence_door_rotate, bread).
map_ec(fence_door_rotate, drinks).

// Internal Section 2 flow
map_ec(bread, bakery).
map_ec(drinks, bakery).
map_ec(bakery, dairy).

// Section 2 -> Door 2 -> Section 1
map_ec(bakery, fence_door_rotate_2).
map_ec(dairy, fence_door_rotate_2).
map_ec(fence_door_rotate_2, fish).
map_ec(fence_door_rotate_2, butcher).

// Internal Section 1 flow
map_ec(fish, sauce).
map_ec(fish, butcher).

// Section 1 -> Checkout -> Exit
map_ec(butcher, checkout).
map_ec(fish, checkout).
map_ec(sauce, checkout).
map_ec(checkout, exit).

// --- PO: Partial Overlap (Doors connecting Sections) ---
// Door 1 connects Section 3 (FV) and Section 2 (Bread/Drinks)
map_po(fence_door_rotate, section2).
map_po(fence_door_rotate, section3).

// Door 2 connects Section 2 (Dairy/Bakery) and Section 1 (Fish/Butcher)
map_po(fence_door_rotate_2, section1).
map_po(fence_door_rotate_2, section2).
