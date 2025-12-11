// Agent shopper in project mind

/* Initial Beliefs and Goals */
// Define the market regions (Omniscience)
region("Entrata").
region("Ortofrutta").
region("Bevande").
region("Panetteria").
region("Dolciumi").
region("Latticini").
region("Salse").
region("Pescheria").
region("Macelleria").
region("Cassa").
region("Uscita").

{ include("market_map.asl") }


!start.

/* Plans */

+!start : not started <- 
    +started;
    .print("Hello! I am ready to explore the market.");
    .print("First, I will go to the Entrata.");
    !visit("Entrata");
    .wait(1000);
    !explore.

+!start : started <- .print("Shopper agent already started.").

// Exploration loop: find an unvisited and reachable region and go there
+!explore : region(R) & not visited(R) & not unreachable(R) <-
    .print("Next stop: ", R);
    !visit(R);
    !explore.

+!explore : not (region(R) & not visited(R) & not unreachable(R)) <-
    .print("I have visited (or skipped) all regions! Exploration complete.");
    .print("Returning to Entrata...");
    !visit("Entrata");
    .print("I am back at the Entrata. Mission accomplished.").

// Plan to visit a specific region
+!visit(R) : true <-
    +target_region(R);
    .print("Walking to ", R, "...");
    vesna.walk(R);
    // Wait for the movement completion signal (max 20 seconds)
    .wait({+movement(completed, destination_reached)}, 20000);
    // The signal handler will add visited(R) and remove target_region(R)
    +visited(R);
    -target_region(R);
    -movement(completed, destination_reached);
    .print("Arrived at ", R).

// Failure handling for visit (e.g. timeout)
-!visit(R) : true <-
    .print("Failed to reach ", R, " (timeout). Skipping.");
    -target_region(R);
    +unreachable(R).

+movement(failed, Reason) : target_region(R) <-
    .print("Movement to ", R, " failed: ", Reason);
    -target_region(R);
    -movement(failed, Reason).

// --- Vision Perception Handling ---

// Handle vision perception from Godot
+perception(vision, Objects) : true <-
    //.print("Vision update received: ", Objects);
    !process_vision_objects(Objects);
    -perception(vision, Objects). // Clear signal

+!process_vision_objects([]) : true.

+!process_vision_objects([Obj|Rest]) : true <-
    // Assuming Obj structure is a map/list from JSON: [Name, Reparto, Coords, IsNew]
    // Note: The exact structure depends on how VesnaAgent.java parses the JSON object.
    // If it comes as a map, we might need specific accessors.
    // For now, let's assume VesnaAgent converts JSON objects to a list of terms or a map.
    // IF VesnaAgent isn't updated, we might receive raw data.
    
    // Let's assume we get a list of maps or similar structure.
    // Since we haven't updated VesnaAgent.java yet, we might need to do that first
    // to ensure clean AgentSpeak terms.
    
    // Placeholder logic:
    // .print("Processing object: ", Obj);
    !process_vision_objects(Rest).

