// Agent shopper in project mind

/* Initial Beliefs and Goals */

// Define the market regions (Atoms matching market_map.asl)
region(entry).
region(fv).
region(drinks).
region(bakery).
region(bread).
region(dairy).
region(sauce).
region(fish).
region(butcher).
region(checkout).
region(exit).

// Mapping logical atoms to Godot Scene Node names (Strings)
godot_name(entry, "Entry").
godot_name(fv, "FV").
godot_name(drinks, "Drinks").
godot_name(bakery, "Bakery").
godot_name(bread, "Bread").
godot_name(dairy, "Dairy").
godot_name(sauce, "Sauce").
godot_name(fish, "Fish").
godot_name(butcher, "Butcher").
godot_name(checkout, "Checkout").
godot_name(exit, "Exit").

{ include("market_map.asl") }

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
    .print("I have visited (or skipped) all regions! Exploration complete.");
    .print("Returning to Entry...");
    !visit(entry);
    .print("I am back at the Entry. Mission accomplished.").

// Plan to visit a region
+!visit(R) : godot_name(R, GName) <-
    +target_region(R);
    .print("Walking to ", R, " (Node: ", GName, ")...");
    vesna.walk(GName);
    // Wait max 20 seconds for movement completion signal
    .wait({+movement(completed, destination_reached)}, 20000);
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


// Perception Handling (object_state)
// Map incoming String (RegionString) back to Atom (RegionAtom) using godot_name
+perception(object_state, "seen", Name, RegionString, Coords, Grabbable) : godot_name(RegionAtom, RegionString) <-
    //.print("Seen: ", Name, " in ", RegionString);
    +object(Name, RegionAtom, Coords, Grabbable);
    -perception(object_state, "seen", Name, RegionString, Coords, Grabbable).

// Fallback: If no atom found, store the string directly (robustness)
+perception(object_state, "seen", Name, RegionString, Coords, Grabbable) : not godot_name(RegionAtom, RegionString) <-
    .print("Warning: Seen object ", Name, " in unknown region '", RegionString, "'.");
    +object(Name, RegionString, Coords, Grabbable);
    -perception(object_state, "seen", Name, RegionString, Coords, Grabbable).

+perception(object_state, "grabbable", Name, RegionString, Coords, Grabbable) : godot_name(RegionAtom, RegionString) <-
    .print("Grabbable change: ", Name, " -> ", Grabbable);
    -object(Name, _, _, _);
    +object(Name, RegionAtom, Coords, Grabbable);
    -perception(object_state, "grabbable", Name, RegionString, Coords, Grabbable).

+perception(object_state, "grabbable", Name, RegionString, Coords, Grabbable) : not godot_name(RegionAtom, RegionString) <-
    .print("Grabbable change (unknown region): ", Name, " -> ", Grabbable);
    -object(Name, _, _, _);
    +object(Name, RegionString, Coords, Grabbable);
    -perception(object_state, "grabbable", Name, RegionString, Coords, Grabbable).

+perception(object_state, "lost", Name, _, _, _) : true <-
    .print("Lost sight of: ", Name);
    -object(Name, _, _, _);
    -perception(object_state, "lost", Name, _, _, _).

// Deprecated handler
+perception(vision, Objects) : true <-
    .print("Warning: Received deprecated vision list perception.");
    -perception(vision, Objects).
