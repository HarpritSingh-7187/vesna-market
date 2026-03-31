# VEsNA-Market

VEsNA is a framework that enables [JaCaMo](https://jacamo-lang.github.io/) agents to be embodied inside a virtual environment powered by [Godot 4](https://godotengine.org/). This repository focuses on the **Market** playground — a multi-agent supermarket shopping scenario — and contains the full bridge between agent minds and agent bodies.

![](./docs/vesna.gif)

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/<your-username>/vesna-market.git
   cd vesna-market
   ```
2. **Open the Godot project:** launch [Godot 4](https://godotengine.org/download/) and import the Market project from `env/market/`. Press **Play** to start the scene.
3. **Run the agents:** in a separate terminal, navigate to `mind/` and run:
   ```bash
   gradle run
   ```
4. The agents will connect to the Godot bodies via WebSocket and begin acting in the environment.

## Project Structure

```
vesna-market/
├── mind/                         # JaCaMo agent-side (Java + AgentSpeak)
│   ├── build.gradle              # Gradle build (Java 23, JaCaMo 1.2)
│   ├── vesna.jcm                 # Office playground MAS config
│   ├── market.jcm                # Market playground MAS config
│   └── src/
│       ├── agt/
│       │   ├── vesna.asl              # Core VEsNA plans (go_to, follow_path, RCC reasoning)
│       │   ├── vesna/                 # Java internal actions & agent class
│       │   │   ├── VesnaAgent.java    # Embodied agent (WebSocket client)
│       │   │   ├── WsClient.java      # WebSocket client
│       │   │   ├── grab.java          # Grab action
│       │   │   ├── release.java       # Release action
│       │   │   └── via/               # Movement actions
│       │   │       ├── walk.java
│       │   │       ├── rotate.java
│       │   │       └── jump.java
│       │   └── playgrounds/
│       │       ├── office/            # Office scenario agents & map
│       │       └── market/            # Market scenario agents & map
│       └── env/
│           ├── vesna/                 # Base artifact classes
│           │   ├── SituatedArtifact.java
│           │   └── GrabbableArtifact.java
│           └── playgrounds/office/    # Office-specific artifacts
│               ├── CoffeeMachine.java
│               └── Cup.java
└── env/                          # Godot body-side
    ├── office/                   # Office Godot project
    └── market/                   # Market Godot project
```

## Usage

> [!IMPORTANT]
>
> **Requirements**
>
> - Java 23 (if you change version, update `build.gradle`);
> - Gradle (tested with version 8+);
> - Godot 4.
>
> Java dependencies (JaCaMo 1.2, Java-WebSocket, JSON) are managed automatically by Gradle.

The framework provides:

- a set of **internal actions** for spatial reasoning and movement (`walk`, `rotate`, `jump`, `grab`, `release`);
- a **perception system** that delivers visual events from the body to the mind (`object_state`);
- **Region Connection Calculus (RCC)** reasoning with automatic pathfinding;
- **CArtAgO artifacts** for object interaction (`SituatedArtifact`, `GrabbableArtifact`);
- a fully working **Market playground** demonstrating multi-agent supermarket shopping.

### Making a VEsNA agent on JaCaMo

In your `.jcm` file insert the new agent:

```
mas your_mas {
	
	agent bob:bob.asl {
		beliefs:	address( localhost )
					port( 9080 )
		ag-class:	vesna.VesnaAgent
	}

}
```

The new Agent class `VesnaAgent` creates a WebSocket connection between each agent and its body. The body implements a WebSocket server with an address and a port; the agent must include these two values as beliefs.

Inside your agent file you should include the `vesna.asl` file and, if you want, the playground-specific files:

```
{ include("vesna.asl") }
{ include("playgrounds/office.asl") }
```

The `vesna.asl` file provides high-level plans:

- `go_to( Target )`: makes the agent navigate to the target using RCC reasoning;
- `follow_path( [ Path ] )`: makes the agent follow a sequence of waypoints.

These plans make the agent reason with Region Connection Calculus (RCC). A map of the environment in RCC is given in the playground folder.

### Internal Actions

The VEsNA agent has the following `DefaultInternalAction`s:

#### `vesna.walk()`

Can be used with different parameters:

| Signature | Description |
|---|---|
| `vesna.walk()` | Makes a step |
| `vesna.walk( n )` | Makes a step of length `n` |
| `vesna.walk( target )` | Moves to target (full waypoint traversal) |
| `vesna.walk( target, id )` | Moves to target with `id` |
| `vesna.walk( target, "quick" )` | Moves to target center only (no waypoint traversal) |

#### `vesna.rotate()`

| Signature | Description |
|---|---|
| `vesna.rotate( direction )` | Rotates in a direction (`left`, `right`, `backward`, `forward`) |
| `vesna.rotate( target )` | Looks at target |
| `vesna.rotate( target, id )` | Looks at target with `id` |

#### `vesna.jump()`

Makes the agent jump (no parameters).

#### `vesna.grab( artifact_name )`

Grabs a named artifact in the environment. Sends an `interact` message of type `grab` to the body.

#### `vesna.release( artifact_name )`

Releases a previously grabbed artifact. Sends an `interact` message of type `release` to the body.

---

### CArtAgO Artifacts

VEsNA provides two base artifact classes for creating interactive objects in the environment:

- **`SituatedArtifact`**: an artifact placed in a specific region, with a usage limit. Provides `use( region )` and `free()` operations.
- **`GrabbableArtifact`**: an artifact that can be grabbed and carried by an agent. Provides `grab( region )` and `release( region )` operations.

Both artifacts enforce region checks (the agent must be in the same region of the artifact) and forward interaction messages to the Godot body.

---

### Making the VEsNA agent body

To implement your VEsNA body you should implement a WebSocket server. The server communicates with the mind via JSON messages.

#### Mind → Body messages

```json
{
    "sender": "ag_name",
    "receiver": "body",
    "type": "msg_type",
    "data": {
        "type": "inner_type",
        ...
    }
}
```

The `sender` is set to the agent name in the MAS. `msg_type` can be `walk`, `rotate`, `jump` or `interact`.

##### Walk message data

A walk message can have type `goto` or `step`.

`goto`:
```json
{
    "type": "goto",
    "target": "target",
    "mode": "full",
    "id": 0
}
```
- `mode`: `"full"` (default, traverses all waypoints) or `"quick"` (center only).
- `id`: optional.

`step`:
```json
{
    "type": "step",
    "length": 2
}
```
- `length`: optional.

##### Rotate message data

A rotate message can have type `direction` or `lookat`.

`direction`:
```json
{
    "type": "direction",
    "direction": "left"
}
```

`lookat`:
```json
{
    "type": "lookat",
    "target": "target",
    "id": 0
}
```
- `id`: optional.

##### Interact message data

An interact message can have type `grab`, `release`, `use` or `free`.

```json
{
    "type": "grab",
    "art_name": "artifact_name"
}
```

Jump action has an empty data field.

#### Body → Mind messages

The body sends messages back to the mind. `VesnaAgent` handles two types:

##### Signal (movement events)

```json
{
    "sender": "body",
    "receiver": "ag_name",
    "type": "signal",
    "data": {
        "type": "movement",
        "status": "completed",
        "reason": "destination_reached"
    }
}
```

These generate beliefs like `movement( completed, destination_reached )` in the agent.

##### Perception (object state)

```json
{
    "sender": "body",
    "receiver": "ag_name",
    "type": "perception",
    "data": {
        "perception_type": "object_state",
        "event": "seen",
        "object": {
            "name": "object_name",
            "reparto": "region_name",
            "grabbable": true
        }
    }
}
```

Events: `seen`, `grabbable`, `not_grabbable`, `lost`.

These generate beliefs like `perception( object_state, Event, Name, Region, Grabbable )` in the agent.

---

### Playgrounds

#### Office

> [!WARNING]
>
> The Office playground is included in the repository as a **reference example** from the original VEsNA framework. It is **not configured for out-of-the-box use** in this repo and may require adaptation (e.g. Godot scene setup, agent configuration) to run correctly.

The Office playground features **4 agents** (alice, bob, charlie, david) navigating an office environment with shared artifacts (CoffeeMachine with a capacity of 1, and 3 Cups).

Config file: `vesna.jcm`

```
mas vesna {
    agent alice:alice.asl {
        beliefs: address( localhost ) port( 9081 )
        ag-class: vesna.VesnaAgent
    }
    // bob (9080), charlie (9082), david (9083)
    
    workspace wp {
        artifact coffee_machine: vesna.playgrounds.office.CoffeeMachine( "common", 1 )
        artifact cup1: vesna.playgrounds.office.Cup( "common" )
        // ...
    }
}
```

#### Market

The Market playground implements a **multi-agent supermarket shopping** scenario with:

- **Orchestrator**: a logic agent (no Godot body) that coordinates shoppers, assigns exploration zones, and dispatches shopping list orders;
- **Shoppers** (shopper1, shopper2): embodied agents that explore the market in parallel, build object memory via visual perception, and fetch items on demand;
- **Customer**: a logic agent that sends shopping list orders to the orchestrator.

Config file: `market.jcm`

```
mas market {

    // Orchestrator: Logic agent, central coordinator
    agent orchestrator:playgrounds/market/orchestrator.asl {
        beliefs: address("localhost")
                 port(9082) // Fake Jason port (not used for websocket Godot)
    }

    // Shopper 1
    agent shopper1:playgrounds/market/shopper.asl {
        beliefs:    address( localhost )
                    port(9080) 
        goals:      start
        ag-class:   vesna.VesnaAgent
    }

    // Shopper 2
    agent shopper2:playgrounds/market/shopper.asl {
        beliefs:    address( localhost )
                    port(9081) 
        goals:      start
        ag-class:   vesna.VesnaAgent
    }

    // Customer: External agent that sends Shopping List orders (without Godot body)
    agent customer:playgrounds/market/customer.asl {
    }
```

#### Running a playground

> [!IMPORTANT]
>
> Make sure you have all the [requirements](#usage) installed before proceeding.

1. **Start the Godot scene first.** Open Godot 4, import the Market project from `env/market/`, and press **Play** (or `F5`) to start the main scene. The WebSocket servers will begin listening for agent connections.
2. **Then start the agents.** Open a terminal in the `mind/` folder and run:
   ```bash
   gradle run
   ```
3. The agents will automatically connect to their Godot bodies and start executing their plans.

> [!TIP]
>
> Always start Godot **before** Gradle. The agents try to open a WebSocket connection on startup; if the Godot scene is not running yet, the connection will fail.