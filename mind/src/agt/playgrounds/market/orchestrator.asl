// Orchestrator Agent
// Responsabilità: Coordinare Shoppers e gestire la Shopping List

!start.

+!start <-
    .print("Orchestrator online. Waiting for other agents...");
    .wait(2000); // Waiting to ensure every agent is online
    .print("Assigning Exploration task to Shopper 1...");
    .send(shopper1, achieve, explore);

    // Wait for exploration to finish
    .print("Letting Shopper 1 explore for 60 seconds...");
    .wait(60000);

    .print("Exploration time over. Assigning orders...");

    // Assign orders
    // Order for Shopper 1
    .print("Order for Shopper 1: Watermelon");
    .send(shopper1, achieve, fetch("Watermelon"));

    // Order for Shopper 2
    .print("Order for Shopper 2: Cheese3");
    .send(shopper2, achieve, fetch("Cheese3")).
    
