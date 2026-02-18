// Customer Agent — simulates external orders arriving dynamically
// This agent has no body (no Godot instance). It only sends messages.

!place_orders.

+!place_orders <-
    // First order: placed shortly after system starts
    .wait(5000);
    .print("Placing first Shopping List order!");
    .send(orchestrator, achieve, new_order(["Watermelon", "Cheese3", "Ketchup", "Musterd", "Croissant", "MeatPatty"]));

    // Second order: placed after first batch is likely completed
    .wait(120000);
    .print("Placing second Shopping List order!");
    .send(orchestrator, achieve, new_order(["SodaBottle", "Loaf", "Apple", "CakeBirthday"])).
