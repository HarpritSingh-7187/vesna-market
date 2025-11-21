// Agent shopper in project vesna

/* Initial beliefs and rules */

/* Initial goals */

!start.

/* Plans */

+!start : true <- 
    .print("Hello World! I am a shopper in the market.");
    // Wait a bit for connection and physics to settle
    .wait(2000);
    !explore.

+!explore : true <-
    .print("I will try to grab something.");
    // Example action: try to grab a 'carton' (assuming it exists in the scene)
    // In a real scenario, the agent might look for objects first.
    vesna.grab("carton");
    .wait(2000);
    vesna.release("carton");
    .print("I released it.").

// Handle interaction completion signal from body
+interaction(Status, Reason) : Status == "completed" <-
    .print("Interaction completed: ", Reason).

+interaction(Status, Reason) : Status == "failed" <-
    .print("Interaction failed: ", Reason).
