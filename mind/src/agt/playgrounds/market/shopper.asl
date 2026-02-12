// Agent shopper in project mind

/* Initial Beliefs and Goals */

// Define the market regions (Atoms matching market_map.asl)
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

// Mapping logical atoms to Godot Scene Node names (Strings)
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

{ include("playgrounds/market/market_map.asl") }

!start.

/* Plans */

+!start : not started <- 
    +started;
    .print("Hello! I am ready to explore the market.");
    .print("First, I will go to the Entry.");
    !visit(entry);
    .wait(1000);
    !explore.

+!start : started <- .print("Shopper agent already started.").

// Find an unvisited, reachable region and go there
+!explore : region(R) & not visited(R) & not unreachable(R) <-
    .print("Next stop: ", R);
    !visit(R);
    !explore.

// If all regions visited or unreachable, return to Entry
+!explore : not (region(R) & not visited(R) & not unreachable(R)) <-
    .print("Exploration complete.");
    .findall(obj(N,R,G), object(N,R,G), MemoryList);
    .print("Remembered objects: ", MemoryList);
    .print("Returning to Entry before fetch...");
    !visit(entry);
    .print("Starting order processing...");
    !process_order(["Watermelon", "Cheese3", "Pizza"]).

// Process a list of orders recursively
+!process_order([]) <-
    .print("All orders processed! Mission complete.").

+!process_order([Item|Rest]) <-
    .print("Processing order for: ", Item);
    !fetch(Item);
    !process_order(Rest).

// Plan to visit a region
+!visit(R) : godot_name(R, GName) <-
    +target_region(R);
    .print("Walking to ", R, " (Node: ", GName, ")...");
    vesna.walk(GName);
    // Wait max 120 seconds for movement completion signal
    .wait({+movement(completed, destination_reached)}, 120000);
    // Mark as visited and cleanup
    +visited(R);
    -target_region(R);
    -movement(completed, destination_reached);
    .print("Arrived at ", R).

// Handle mapping failure
+!visit(R) : not godot_name(R, _) <-
    .print("Error: No Godot node name defined for region ", R).

// Handle timeout (failure to reach state in time)
-!visit(R) : true <-
    .print("Failed to reach ", R, " (timeout). Skipping.");
    -target_region(R);
    +unreachable(R).

// Handle explicit movement failure
+movement(failed, Reason) : target_region(R) <-
    .print("Movement to ", R, " failed: ", Reason);
    -target_region(R);
    -movement(failed, Reason).



// Fetch: find an object whose name contains SearchName (handles Watermelon1, Watermelon2, etc.)
+!fetch(SearchName) : object(Name, Region, _) & .substring(SearchName, Name) & godot_name(Region, _) <-
    .print("Looking for ", SearchName, " - found ", Name, " in ", Region);
    .print("Walking directly to ", Name, "...");
    vesna.walk(Name);
    .wait({+movement(completed, destination_reached)}, 120000);
    -movement(completed, destination_reached);
    .print("Reached ", Name, ". Grabbing...");
    vesna.grab(Name);
    .print("Successfully grabbed ", Name, "!");
    .print("Returning to Entry...");
    !visit(entry);
    .print("Back at Entry. Fetch complete.").

// Fetch fallback: no matching object in memory
+!fetch(SearchName) : not (object(Name, _, _) & .substring(SearchName, Name)) <-
    .print("Error: no matching object for ", SearchName, ". Explore first.").

// Fetch failure handler (timeout, navigation error, etc.)
-!fetch(SearchName) : true <-
    .print("Failed to fetch ", SearchName, " (timeout or error).").

// Helper: wait for object to become grabbable
// Case 1: already grabbable
+!wait_grabbable(Name, Region) : object(Name, Region, true) <-
    .print(Name, " is already within grab range.").

// Case 2: not yet grabbable -> approach the object, then re-check
+!wait_grabbable(Name, Region) : object(Name, Region, false) <-
    .print(Name, " not in grab range. Approaching...");
    vesna.walk(Name);
    .wait({+movement(completed, destination_reached)}, 60000);
    -movement(completed, destination_reached);
    .print("Approached ", Name, ".");
    !check_grabbable(Name, Region).

// After approach: already grabbable (event fired during walk)
+!check_grabbable(Name, Region) : object(Name, Region, true) <-
    .print(Name, " is now within grab range.").

// After approach: not yet grabbable -> wait for perception
+!check_grabbable(Name, Region) : object(Name, Region, false) <-
    .print("Waiting for ", Name, " to become grabbable...");
    .wait({+object(Name, Region, true)}, 15000).

// Case 3: failure (timeout)
-!wait_grabbable(Name, Region) : true <-
    .print("Timeout waiting for ", Name, " to become grabbable.");
    .fail.

-!check_grabbable(Name, Region) : true <-
    .print("Timeout on check_grabbable for ", Name, ".");
    .fail.


// Perception Handling (object_state)
// Map incoming String (RegionString) back to Atom (RegionAtom) using godot_name
+perception(object_state, "seen", Name, RegionString, Grabbable) : godot_name(RegionAtom, RegionString) <-
    //.print("Seen: ", Name, " in ", RegionString);
    -object(Name, _, _);
    +object(Name, RegionAtom, Grabbable);
    -perception(object_state, "seen", Name, RegionString, Grabbable).

// Fallback: If no atom found, store the string directly (robustness)
+perception(object_state, "seen", Name, RegionString, Grabbable) : not godot_name(RegionAtom, RegionString) <-
    //.print("Warning: Seen object ", Name, " in unknown region '", RegionString, "'.");
    -object(Name, _, _);
    +object(Name, RegionString, Grabbable);
    -perception(object_state, "seen", Name, RegionString, Grabbable).

+perception(object_state, "grabbable", Name, RegionString, Grabbable) : godot_name(RegionAtom, RegionString) <-
    //.print("Grabbable change: ", Name, " -> ", Grabbable);
    -object(Name, _, _);
    +object(Name, RegionAtom, Grabbable);
    -perception(object_state, "grabbable", Name, RegionString, Grabbable).

+perception(object_state, "grabbable", Name, RegionString, Grabbable) : not godot_name(RegionAtom, RegionString) <-
    //.print("Grabbable change (unknown region): ", Name, " -> ", Grabbable);
    -object(Name, _, _);
    +object(Name, RegionString, Grabbable);
    -perception(object_state, "grabbable", Name, RegionString, Grabbable).

// Handle "not_grabbable" event (object left grab range)
+perception(object_state, "not_grabbable", Name, RegionString, _) : godot_name(RegionAtom, RegionString) <-
    -object(Name, _, _);
    +object(Name, RegionAtom, false);
    -perception(object_state, "not_grabbable", Name, RegionString, _).

//Fallback if no atom found 
+perception(object_state, "not_grabbable", Name, RegionString, _) : not godot_name(RegionAtom, RegionString) <-
    -object(Name, _, _);
    +object(Name, RegionString, false);
    -perception(object_state, "not_grabbable", Name, RegionString, _).

// Persistent memory: on lost, keep the belief with grabbable=false
+perception(object_state, "lost", Name, _, _) : object(Name, Region, _) <-
    .print("Lost sight of: ", Name, " (remembered in ", Region, ")");
    -object(Name, _, _);
    +object(Name, Region, false);
    -perception(object_state, "lost", Name, _, _).

// Fallback lost: if no existing belief found
+perception(object_state, "lost", Name, _, _) : not object(Name, _, _) <-
    .print("Lost sight of unknown object: ", Name);
    -perception(object_state, "lost", Name, _, _).

// Deprecated handler
+perception(vision, Objects) : true <-
    .print("Warning: Received deprecated vision list perception.");
    -perception(vision, Objects).
