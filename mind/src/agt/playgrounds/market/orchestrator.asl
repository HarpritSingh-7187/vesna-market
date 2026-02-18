// Orchestrator Agent
// Responsabilità: Coordinare Shoppers e gestire la Shopping List

/* Initial Beliefs */
!start.


+!start <-
    .print("Orchestrator online. Waiting for agents to register...");
    
    // Wait until at least one agent is available
    .wait({+available(A)}, 5000);
    
    // Get all currently available agents
    .findall(Agent, available(Agent), Agents);
    .print("Registered agents: ", Agents);
    
    // Assign Exploration to the first available agent
    .nth(0, Agents, Explorer);
    .print("Assigning Exploration task to ", Explorer, "...");
    .send(Explorer, achieve, explore);

    .print("Exploration started. Waiting for completion signal...").

// React to exploration completion
+exploration_completed[source(Agent)] <-
    .print("Received exploration completion signal from ", Agent);
    +exploration_done;
    // All agents are now idle (exploration is done, no orders dispatched yet)
    .findall(A, available(A), AllAgents);
    for (.member(A, AllAgents)) { +idle(A); }
    !check_pending_orders.

// Base Case: No more items
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
    +idle(Agent);
    // Check if all agents are idle → trigger pending orders
    .findall(A, idle(A), IdleAgents);
    .findall(A, available(A), AllAgents);
    .length(IdleAgents, NI);
    .length(AllAgents, NA);
    if (NI == NA) {
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
    .findall(A, idle(A), Agents);
    for (.member(A, Agents)) { -idle(A); }
    !dispatch(List, Agents).

+!check_pending_orders : not pending_order(_) <-
    .print("All orders fulfilled. System idle.").
