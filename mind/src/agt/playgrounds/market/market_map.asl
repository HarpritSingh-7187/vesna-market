// * MARKET PLAYGROUND MAP

// --- Regions ---
region(entry).
region(fv).
region(drinks).
region(bakery).
region(breads).
region(dairy).
region(sauces).
region(fish).
region(butcher).
region(checkout).
region(exit).

// Shoppable regions: only these contain products worth exploring
shoppable(fv).
shoppable(drinks).
shoppable(breads).
shoppable(bakery).
shoppable(dairy).
shoppable(sauces).
shoppable(fish).
shoppable(butcher).

// Topological exploration order following the physical market layout
explore_order([fv, breads, drinks, bakery, dairy, fish, sauces, butcher]).

// --- Godot Node Mapping ---
godot_name(entry, "Entry").
godot_name(fv, "FV").
godot_name(drinks, "Drinks").
godot_name(bakery, "Bakery").
godot_name(breads, "Breads").
godot_name(dairy, "Dairy").
godot_name(sauces, "Sauces").
godot_name(fish, "Fish").
godot_name(butcher, "Butcher").
godot_name(checkout, "Checkout").
godot_name(exit, "Exit").
godot_name(fence_door_rotate_1, "FenceDoorRotate1").
godot_name(fence_door_rotate_2, "FenceDoorRotate2").

// --- NTPP: Containment (Regions inside Sections) ---
// Section 1: Proteins/Sauces
map_ntpp(sauces, section1).
map_ntpp(fish, section1).
map_ntpp(butcher, section1).

// Section 2: Dairy/Bakery/Drinks
map_ntpp(dairy, section2).
map_ntpp(bakery, section2).
map_ntpp(breads, section2).
map_ntpp(drinks, section2).

// Section 3: Fruit & Veg
map_ntpp(fv, section3).

// --- EC: Externally Connected (Adjacency flow) ---

// ENTRY -> SECTION 3
map_ec(entry, fv).

// SECTION 3 -> DOOR 1 -> SECTION 2
map_ec(fv, fence_door_rotate_1).
map_ec(fence_door_rotate_1, breads).
map_ec(fence_door_rotate_1, drinks).

// Bread <-> Bakery <-> Dairy
map_ec(breads, bakery).
map_ec(bakery, dairy).

map_ec(drinks, bakery).

// SECTION 2 -> DOOR 2 -> SECTION 1
map_ec(bakery, fence_door_rotate_2).
map_ec(dairy, fence_door_rotate_2).

map_ec(fence_door_rotate_2, fish).
map_ec(fence_door_rotate_2, butcher).

// Fish <-> Sauce <-> Butcher
map_ec(fish, sauces).
map_ec(sauces, butcher).
// Fish <-> Butcher 
map_ec(fish, butcher).

// SECTION 1 -> CHECKOUT -> EXIT
map_ec(butcher, checkout).
map_ec(fish, checkout).
map_ec(sauces, checkout).

map_ec(checkout, exit).


// --- PO: Partial Overlap (Doors connecting Sections) ---
// Door 1 connects Section 3 (FV) and Section 2
map_po(fence_door_rotate_1, section2).
map_po(fence_door_rotate_1, section3).

// Door 2 connects Section 2 and Section 1
map_po(fence_door_rotate_2, section1).
map_po(fence_door_rotate_2, section2).

// --- RCC Rules (symmetric closure) ---
po( X, Y ) :- map_po( X, Y ).
po( Y, X ) :- map_po( X, Y ).
ec( X, Y ) :- map_ec( X, Y ).
ec( Y, X ) :- map_ec( X, Y ).
