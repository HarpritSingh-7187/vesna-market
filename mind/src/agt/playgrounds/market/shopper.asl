// Agent shopper in project mind

/* Initial Beliefs and Goals */

{ include("playgrounds/market/market_map.asl") }

// Pathfinding via DFS on the map graph
// Only follows ec edges (physical adjacency) between nodes that have a godot_name
// (this excludes abstract sections AND line-level nodes from paths)
find_market_path( Start, Target, Path ) :- find_market_path_r( Start, Target, [ Start ], Path ).
find_market_path_r( Target, Target, Visited, Visited ).
find_market_path_r( Current, Target, Visited, Path ) :-
    ec( Current, Next )
    & godot_name( Next, _ )
    & not .member( Next, Visited )
    & find_market_path_r( Next, Target, [ Next | Visited ], Path ).

// Agent starts at entry
current_location(entry).

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
    // Record exploration start time
    .time(H, M, S);
    +exploration_start(H, M, S);
    .print("First, I will go to the Entry.");
    !visit(entry);
    .wait(1000);
    ?explore_order(Route);
    !auto_explore(Route).

// Parallel exploration: explore only assigned regions
+!explore_zone(RegionList) <-
    .print("Exploration zone received: ", RegionList);
    // Record exploration start time
    .time(H, M, S);
    +exploration_start(H, M, S);
    .print("Going to Entry first...");
    !visit(entry);
    .wait(1000);
    !auto_explore(RegionList).

+!start : started <- .print("Shopper agent already started.").

// Follow topological route: visit each shoppable region in physical order
+!auto_explore([]) <-
    .print("Topological exploration complete.");
    !finish_explore.

// Skip already-visited or unreachable regions
+!auto_explore([R|Rest]) : (visited(R) | unreachable(R)) <-
    !auto_explore(Rest).

// Visit next region in order
+!auto_explore([R|Rest]) : shoppable(R) & not visited(R) & not unreachable(R) <-
    .print("Next stop: ", R);
    !visit(R);
    !auto_explore(Rest).

// (legacy) If regions not in ordered list
+!auto_explore([R|Rest]) : true <-
    .print("Skipping ", R, " (not shoppable)");
    !auto_explore(Rest).

// Finish exploration: report and return
+!finish_explore <-
    // Compute exploration duration
    .time(H1, M1, S1);
    ?exploration_start(H0, M0, S0);
    T0 = H0 * 3600 + M0 * 60 + S0;
    T1 = H1 * 3600 + M1 * 60 + S1;
    Duration = T1 - T0;
    .print("[TIME] Exploration completed in ", Duration, " seconds");
    .findall(obj(N,R,G), object(N,R,G), MemoryList);
    .print("Remembered objects: ", MemoryList);
    .print("Returning to Base before fetch...");
    !return_home;
    .print("Exploration complete. Notifying Orchestrator...");
    .send(orchestrator, tell, exploration_completed).

// NAVIGATION VIA MARKET MAP PATHFINDING

// navigate_to(Dest): find path from current_location to Dest and follow it step by step
+!navigate_to(Dest) : current_location(Dest) <-
    .print("Already at ", Dest, ", no movement needed.").

+!navigate_to(Dest) : current_location(Here) & godot_name(Dest, _) <-
    .print("Planning path from ", Here, " to ", Dest, "...");
    ?find_market_path(Here, Dest, RPath);
    .delete(Here, RPath, LPath);
    .reverse(LPath, Path);
    .print("Path found: ", Path);
    !follow_market_path(Path).

// Fallback: no path found
+!navigate_to(Dest) : current_location(Here) & not (find_market_path(Here, Dest, _)) <-
    .print("ERROR: No path from ", Here, " to ", Dest, ". Trying direct walk...");
    godot_name(Dest, GName);
    vesna.walk(GName, "quick");
    .wait({+movement(completed, destination_reached)}, 120000);
    -movement(completed, destination_reached);
    -current_location(_);
    +current_location(Dest).

// follow_market_path: walk step by step in "quick" mode (fast transit, center only)
+!follow_market_path([]) <-
    .print("Path navigation complete.").

+!follow_market_path([Next|Rest]) : godot_name(Next, GName) <-
    .print("Step -> ", Next, " (Node: ", GName, ")");
    vesna.walk(GName, "quick");
    .wait({+movement(completed, destination_reached)}, 120000);
    -movement(completed, destination_reached);
    -current_location(_);
    +current_location(Next);
    !follow_market_path(Rest).

// Failure on a single step
-!follow_market_path([Next|_]) : true <-
    .print("Failed to reach ", Next, " (timeout on path step). Aborting path.");
    .fail.

// VISIT: uses navigate_to
+!visit(R) : godot_name(R, GName) <-
    +target_region(R);
    .print("Visiting ", R, " via map navigation...");
    !navigate_to(R);
    // Full exploration: walk through ALL waypoints in the region
    .print("Exploring all waypoints in ", R, "...");
    vesna.walk(GName);
    .wait({+movement(completed, destination_reached)}, 120000);
    -movement(completed, destination_reached);
    +visited(R);
    -target_region(R);
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
    .print("All tasks grabbed. Returning to base...");
    !return_home;
    .print("All tasks completed.");
    .my_name(Me);
    .send(orchestrator, tell, tasks_completed(Me)).

// Sequential Fetch Logic — navigate to the region first, then approach the object
+!perform_fetch(SearchName) : object(Name, Region, _) & .substring(SearchName, Name) & godot_name(Region, _) <-
    .time(FH0, FM0, FS0);
    .print("Looking for ", SearchName, " - found ", Name, " in ", Region);
    .print("Navigating to region ", Region, " first...");
    !navigate_to(Region);
    .print("In region ", Region, ". Walking to ", Name, "...");
    vesna.walk(Name);
    .wait({+movement(completed, destination_reached)}, 120000);
    -movement(completed, destination_reached);
    .print("Reached ", Name, ". Grabbing...");
    vesna.grab(Name);
    // Compute fetch duration
    .time(FH1, FM1, FS1);
    FT0 = FH0 * 3600 + FM0 * 60 + FS0;
    FT1 = FH1 * 3600 + FM1 * 60 + FS1;
    FDuration = FT1 - FT0;
    .print("[TIME] Fetched ", Name, " in ", FDuration, " seconds").

// Shared plan to return to specific home — navigate via map to entry, then walk to base marker
+!return_home : .my_name(Me) & agent_base(Me, BaseNode) <-
   .print("Returning to my specific base: ", BaseNode);
   !navigate_to(entry);
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
    .print("Failed to fetch ", SearchName, " (timeout or error).");
    -busy.

// Queue failure handler: release busy flag so next tasks can proceed
-!process_queue : true <-
    -busy;
    .print("Queue processing failed, resetting busy flag.").


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
    -object(Name, _, _);
    +object(Name, Region, false);
    -perception(object_state, "lost", Name, _, _).

// Fallback lost (unknown object)
+perception(object_state, "lost", Name, _, _) 
   <- 
    -perception(object_state, "lost", Name, _, _).

// Info from other agents (silent)
+object(Name, Region, Grabbable)[source(Sender)]
    : Sender \== self & Sender \== percept
   <- true.