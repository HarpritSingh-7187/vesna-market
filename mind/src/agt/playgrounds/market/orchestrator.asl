// Orchestrator Agent
// Responsabilità: Coordinare Shoppers e gestire la Shopping List

/* Initial Beliefs */
shopping_list(["Watermelon", "Cheese3","Ketchup", "Musterd", "Croissant", "MeatPatty"]).

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
    !assign_orders.

//Dynamic Round-Robin Assignment
+!assign_orders : shopping_list(List) <-
    .findall(Agent, available(Agent), Agents); // Refresh list (in case new agents joined)
    .print("Processing Shopping List: ", List);
    .print("Available Workforce: ", Agents);
    !dispatch(List, Agents). // Dispatch to discovered agents

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
    
