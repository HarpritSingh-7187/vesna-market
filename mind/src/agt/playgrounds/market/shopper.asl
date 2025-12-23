// Agent shopper in project mind

/* Belief e goals iniziali  */
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

// Ricerca una regione non visitata e raggiungibile e va lì
+!explore : region(R) & not visited(R) & not unreachable(R) <-
    .print("Next stop: ", R);
    !visit(R);
    !explore.

// altrimenti torno in Entrata
+!explore : not (region(R) & not visited(R) & not unreachable(R)) <-
    .print("I have visited (or skipped) all regions! Exploration complete.");
    .print("Returning to Entrata...");
    !visit("Entrata");
    .print("I am back at the Entrata. Mission accomplished.").

// Pianifica una regione da visitare
+!visit(R) : true <-
    +target_region(R);
    .print("Walking to ", R, "...");
    vesna.walk(R);
    // Aspetta al massimo 20 secondi per la ricezione del segnale di movimento completato
    .wait({+movement(completed, destination_reached)}, 20000);
    // Regione visitata e rimuove target a movimento completato
    +visited(R);
    -target_region(R);
    -movement(completed, destination_reached);
    .print("Arrived at ", R).

// Non riceve alcun segnale di visita 

// Timeout
-!visit(R) : true <-
    .print("Failed to reach ", R, " (timeout). Skipping.");
    -target_region(R);
    +unreachable(R).

// Altri motivi
+movement(failed, Reason) : target_region(R) <-
    .print("Movement to ", R, " failed: ", Reason);
    -target_region(R);
    -movement(failed, Reason).


// Gestione perception da Godot (object_state)
+perception(object_state, "seen", Name, Reparto, Coords, Grabbable) : true <-
    //.print("Visto: ", Name, " in ", Reparto);
    +object(Name, Reparto, Coords, Grabbable);
    -perception(object_state, "seen", Name, Reparto, Coords, Grabbable).

+perception(object_state, "grabbable", Name, Reparto, Coords, Grabbable) : true <-
    .print("Grabbable change: ", Name, " -> ", Grabbable);
    -object(Name, _, _, _);
    +object(Name, Reparto, Coords, Grabbable);
    -perception(object_state, "grabbable", Name, Reparto, Coords, Grabbable).

+perception(object_state, "lost", Name, _, _, _) : true <-
    .print("Perso vista di: ", Name);
    -object(Name, _, _, _);
    -perception(object_state, "lost", Name, _, _, _).

// Vecchio handler deprecato
+perception(vision, Objects) : true <-
    .print("Warning: Received deprecated vision list perception.");
    -perception(vision, Objects).

