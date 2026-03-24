// Orchestrator Agent
// Coordinates Shoppers and manages the Shopping List

{ include("playgrounds/market/market_map.asl") }

/* Initial Beliefs */

// Exploration zones: predefined region splits for parallel exploration
exploration_zone(1, [fv, breads, drinks, bakery]).
exploration_zone(2, [dairy, fish, sauces, butcher]).

//For single agent 
//exploration_zone(1, [fv, breads, drinks, bakery, dairy, fish, sauces, butcher]).  

!start.

+!start <-
    .print("Orchestrator online. Waiting for agents to register...");
    
    // Wait for agents to register
    .wait({+available(A)}, 5000);
    .wait(2000);
    
    // Get all registered agents
    .findall(Agent, available(Agent), Agents);
    .length(Agents, NA);
    .print("Registered agents: ", Agents, " (", NA, " total)");
    
    +expected_explorers(NA);
    +explorers_done(0);
    
    !assign_zones(Agents, 1);
    .print("Parallel exploration started with ", NA, " agents.").

+!assign_zones([], _) <- .print("All exploration zones assigned.").

+!assign_zones([Agent|Rest], ZoneId) : exploration_zone(ZoneId, Regions) <-
    .print("Assigning zone ", ZoneId, " to ", Agent, ": ", Regions);
    .send(Agent, achieve, explore_zone(Regions));
    NextZone = ZoneId + 1;
    !assign_zones(Rest, NextZone).

// Fallback: more agents than zones — extra agents wait
+!assign_zones([Agent|Rest], ZoneId) : not exploration_zone(ZoneId, _) <-
    .print("No more zones to assign. ", Agent, " will wait for orders.");
    // Decrement expected explorers
    ?expected_explorers(E); -expected_explorers(E); E1 = E - 1; +expected_explorers(E1);
    !assign_zones(Rest, ZoneId).

// React to exploration completion — count signals from all agents
+exploration_completed[source(Agent)] <-
    .print("Received exploration completion signal from ", Agent);
    ?explorers_done(N);
    -explorers_done(N);
    N1 = N + 1;
    +explorers_done(N1);
    ?expected_explorers(Total);
    .print("Exploration progress: ", N1, "/", Total);
    if (N1 == Total) {
        .print("=== ALL AGENTS COMPLETED EXPLORATION ===");
        +exploration_done;
        .findall(A, available(A), AllAgents);
        for (.member(A, AllAgents)) { +idle(A); }
        !check_pending_orders;
    }.

// Base Case: No items left
+!dispatch([], _) <- 
    .print("All orders assigned.").

// Recursive Step: Assign Item to First Agent, then Rotate Agents
+!dispatch([Item|Rest], [Agent|OtherAgents]) <-
    .print("Assigning ", Item, " to ", Agent);
    .send(Agent, achieve, fetch(Item));
    
    // Rotate agents
    .concat(OtherAgents, [Agent], NextAgents);

    !dispatch(Rest, NextAgents).

// React to task completion from shoppers
+tasks_completed(Agent)[source(Agent)] <-
    .print("Agent ", Agent, " has completed all assigned tasks. Now idle.");
    -tasks_completed(Agent)[source(Agent)];
    +idle(Agent);
    // Check if all agents are idle
    .findall(A, idle(A), IdleAgents);
    .findall(A, available(A), AllAgents);
    .length(IdleAgents, NI);
    .length(AllAgents, NA);
    if (NI == NA) {
        // Compute order fulfillment time
        if (order_start(OH, OM, OS)) {
            .time(OH1, OM1, OS1);
            OT0 = OH * 3600 + OM * 60 + OS;
            OT1 = OH1 * 3600 + OM1 * 60 + OS1;
            ODuration = OT1 - OT0;
            .print("[TIME] Order fulfilled in ", ODuration, " seconds");
            -order_start(OH, OM, OS);
        }
        // Trigger pending orders
        !check_pending_orders;
    }.

// Receive a new order from customer agent
+!new_order(List) <-
    .print("=== NEW SHOPPING LIST ORDER RECEIVED ===");
    .print("Order: ", List);
    if (exploration_done) {
        // Exploration complete — check for idle agents
        .findall(A, idle(A), IdleAgents);
        .length(IdleAgents, NI);
        if (NI > 0) {
            for (.member(A, IdleAgents)) { -idle(A); }
            !dispatch(List, IdleAgents);
        } else {
            // All agents busy — queue for later
            .print("All agents busy. Queuing order for later...");
            +pending_order(List);
        }
    } else {
        // Exploration not done yet — queue the order
        .print("Exploration not complete yet. Queuing order...");
        +pending_order(List);
    }.

// Check for queued orders when all agents are idle
+!check_pending_orders : pending_order(List) <-
    .print("=== DISPATCHING QUEUED ORDER ===");
    .print("Order: ", List);
    -pending_order(List);
    // Record order start time
    .time(H, M, S);
    +order_start(H, M, S);
    .findall(A, idle(A), Agents);
    for (.member(A, Agents)) { -idle(A); }
    !dispatch(List, Agents).

+!check_pending_orders : not pending_order(_) <-
    .print("All orders fulfilled. System idle.").
