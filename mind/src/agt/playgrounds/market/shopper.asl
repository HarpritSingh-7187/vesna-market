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

!start.

/* Plans */

+!start : true <- 
    .print("Hello! I am ready to explore the market.");
    .wait(2000);
    !explore.

// Exploration loop: find an unvisited and reachable region and go there
+!explore : region(R) & not visited(R) & not unreachable(R) <-
    .print("Next stop: ", R);
    !visit(R);
    !explore.

+!explore : not (region(R) & not visited(R) & not unreachable(R)) <-
    .print("I have visited (or skipped) all regions! Exploration complete.").

// Plan to visit a specific region
+!visit(R) : true <-
    +target_region(R);
    .print("Walking to ", R, "...");
    vesna.walk(R);
    // Wait for the movement completion signal (max 20 seconds)
    .wait({+movement(completed, destination_reached)}, 20000);
    // The signal handler will add visited(R) and remove target_region(R)
    .print("Arrived at ", R).

// Failure handling for visit (e.g. timeout)
-!visit(R) : true <-
    .print("Failed to reach ", R, " (timeout). Skipping.");
    -target_region(R);
    +unreachable(R).

// Handle movement completion signal
+movement(completed, destination_reached) : target_region(R) <-
    .print("Movement completed. I am at ", R);
    +visited(R);
    -target_region(R);
    // Remove the perception so it doesn't trigger again or accumulate
    -movement(completed, destination_reached).

+movement(failed, Reason) : target_region(R) <-
    .print("Movement to ", R, " failed: ", Reason);
    -target_region(R);
    -movement(failed, Reason).
