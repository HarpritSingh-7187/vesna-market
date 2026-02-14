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
    .my_name(Me);
    .print("Hello! I am ready. Registering with Orchestrator as ", Me, "...");
    .send(orchestrator, tell, available(Me));
    .print("Waiting for orders...").

+!explore <-
    .print("Exploration command received!");
    .print("First, I will go to the Entry.");
    !visit(entry);
    .wait(1000);
    !auto_explore.

+!start : started <- .print("Shopper agent already started.").

// Find an unvisited, reachable region and go there
+!auto_explore : region(R) & not visited(R) & not unreachable(R) <-
    .print("Next stop: ", R);
    !visit(R);
    !auto_explore.

// If all regions visited or unreachable, return to Entry
+!auto_explore : not (region(R) & not visited(R) & not unreachable(R)) <-
    .print("Exploration complete.");
    .findall(obj(N,R,G), object(N,R,G), MemoryList);
    .print("Remembered objects: ", MemoryList);
    .print("Returning to Base before fetch...");
    !return_home;
    .print("Exploration complete. Notifying Orchestrator...");
    .send(orchestrator, tell, exploration_completed).

// Process a list of orders recursively
//+!process_order([]) <-
    //.print("All orders processed! Mission complete.").

//+!process_order([Item|Rest]) <-
    //.print("Processing order for: ", Item);
    //!fetch(Item);
    //!process_order(Rest).

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



// Mapping agents to their home markers
agent_base(shopper1, "Shopper1").
agent_base(shopper2, "Shopper2").

// If all regions visited or unreachable, return to Home Base
+!auto_explore : not (region(R) & not visited(R) & not unreachable(R)) <-
    .print("Exploration complete.");
    .findall(obj(N,R,G), object(N,R,G), MemoryList);
    .print("Remembered objects: ", MemoryList);
    .print("Returning to Base before fetch...");
    !return_home;
    .print("Exploration complete. Notifying Orchestrator...");
    .send(orchestrator, tell, exploration_completed).

// Queue-based Fetch Logic
+!fetch(Item)[source(Sender)] <-
    .print("Received order for ", Item, ". Adding to queue.");
    +task_queue(Item);
    !process_queue.

+!process_queue : busy <- true. // Already working, do nothing
+!process_queue : not busy & task_queue(Item) <-
    +busy;
    .print("Processing next task: ", Item);
    !perform_fetch(Item);
    -task_queue(Item);
    -busy;
    !process_queue. // Check for more
+!process_queue : not busy & not task_queue(_) <- 
    .print("All tasks in queue completed.").

// Sequential Fetch Logic
+!perform_fetch(SearchName) : object(Name, Region, _) & .substring(SearchName, Name) & godot_name(Region, _) <-
    .print("Looking for ", SearchName, " - found ", Name, " in ", Region);
    .print("Walking directly to ", Name, "...");
    vesna.walk(Name);
    .wait({+movement(completed, destination_reached)}, 120000);
    -movement(completed, destination_reached);
    .print("Reached ", Name, ". Grabbing...");
    vesna.grab(Name);
    .print("Successfully grabbed ", Name, "!");
    .print("Returning to Base...");
    !return_home;
    .print("Back at Base. Fetch complete.").

// Shared plan to return to specific home
+!return_home : .my_name(Me) & agent_base(Me, BaseNode) <-
   .print("Returning to my specific base: ", BaseNode);
   vesna.walk(BaseNode);
   .wait({+movement(completed, destination_reached)}, 120000);
   -movement(completed, destination_reached);
   .print("Arrived at base.").

// Fallback if no base defined
+!return_home : true <-
    .print("No specific base defined. Returning to Entry.");
    !visit(entry).

// Fetch fallback: no matching object in memory
+!perform_fetch(SearchName) : not (object(Name, _, _) & .substring(SearchName, Name)) <-
    .print("Error: no matching object for ", SearchName, ". Explore first.").

// Fetch failure handler (timeout, navigation error, etc.)
-!perform_fetch(SearchName) : true <-
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
// Atom or String fallback
resolve_region(String, Atom) :- godot_name(Atom, String).
resolve_region(String, String) :- not godot_name(_, String). 

// Handler for Positive Events (seen/grabbable) -> Update & Broadcast
+perception(object_state, Event, Name, RegStr, Grabbable) 
    : (Event == "seen" | Event == "grabbable") & resolve_region(RegStr, Region) 
   <- 
    -object(Name, _, _);
    +object(Name, Region, Grabbable);
    .broadcast(tell, object(Name, Region, Grabbable));
    -perception(object_state, Event, Name, RegStr, Grabbable).

// Unified Handler for Negative Events (not_grabbable/lost) -> Update
+perception(object_state, "not_grabbable", Name, RegStr, _) 
    : resolve_region(RegStr, Region)
   <- 
    -object(Name, _, _);
    +object(Name, Region, false);
    -perception(object_state, "not_grabbable", Name, RegStr, _).

+perception(object_state, "lost", Name, _, _) 
    : object(Name, Region, _) 
   <- 
    .print("Lost sight of: ", Name, " (remembered in ", Region, ")");
    -object(Name, _, _);
    +object(Name, Region, false);
    -perception(object_state, "lost", Name, _, _).

// Fallback lost (unknown object)
+perception(object_state, "lost", Name, _, _) 
   <- 
    .print("Lost sight of unknown object: ", Name);
    -perception(object_state, "lost", Name, _, _).

// Deprecated
+perception(vision, Objects) : true <- -perception(vision, Objects).

// Feedback when receiving info from other agents
+object(Name, Region, Grabbable)[source(Sender)]
    : Sender \== self & Sender \== percept
   <- .print("Received info from ", Sender, ": ", Name, " is in ", Region).
