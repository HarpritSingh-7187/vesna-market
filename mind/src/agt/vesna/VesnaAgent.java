package vesna;

import java.net.URI;

import org.json.JSONObject;

import jason.asSemantics.Agent;
import jason.asSemantics.InternalAction;
import jason.asSemantics.Message;
import jason.asSemantics.Unifier;
import static jason.asSyntax.ASSyntax.createLiteral;
import static jason.asSyntax.ASSyntax.createString;
import static jason.asSyntax.ASSyntax.parseLiteral;
import jason.asSyntax.Literal;
import jason.asSyntax.NumberTerm;
import jason.asSyntax.Term;

// VesnaAgent class extends the Agent class making the agent embodied;
// It connects to the body using a WebSocket connection;
// It needs two beliefs: address( ADDRESS ) and port( PORT ) that describe the address and port of the WebSocket server;
// In order to use it you should add to your .jcm:
// > agent alice:alice.asl {
// >      beliefs: address( localhost )
// >               port( 8080 )
// >      ag-class: vesna.VesnaAgent    
// > }

public class VesnaAgent extends Agent {

    private WsClient client;
    private String my_name;

    // Inizializzazione
    @Override
    public void loadInitialAS(String asSrc) throws Exception {

        super.loadInitialAS(asSrc);
        my_name = getTS().getAgArch().getAgName();

        // Lettura indirizzo e porta dai beliefs
        Unifier address_unifier = new Unifier();
        believes(parseLiteral("address( Address )"), address_unifier);

        Unifier port_unifier = new Unifier();
        believes(parseLiteral("port( Port )"), port_unifier);

        // Controllo se indirizzo e porte sono definiti
        if (address_unifier.get("Address") == null || port_unifier.get("Port") == null) {
            stop("address and port beliefs are not defined!");
            return;
        }

        // Finalizzati i controlli, salvo indirizzo e porta in variabili
        String address = address_unifier.get("Address").toString();
        int port = (int) ((NumberTerm) port_unifier.get("Port")).solve();

        System.out.printf("[%s] Body is at %s:%d%n", my_name, address, port);

        URI body_address = new URI("ws://" + address + ":" + port);
        client = new WsClient(body_address);

        // Imposto il handler per i messaggi e gli errori
        client.setMsgHandler(new WsClientMsgHandler() {
            @Override
            public void handle_msg(String msg) {
                vesna_handle_msg(msg);
            }

            @Override
            public void handle_error(Exception ex) {
                vesna_handle_error(ex);
            }
        });
        // Connessione body
        client.connect();
    }

    // Invio action al body
    public void perform(String action) {
        client.send(action);
    }

    // funzione per segnalare al mind eventuali percezioni
    private void sense(Literal perception) {
        try {
            Message signal = new Message("signal", my_name, my_name, perception);
            getTS().getAgArch().sendMsg(signal);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // prende tutti i dati da un evento e segnala una percezione
    private void handle_event(JSONObject event) {
        String event_type = event.getString("type");
        String event_status = event.getString("status");
        String event_reason = event.getString("reason");
        Literal perception = createLiteral(event_type, createLiteral(event_status), createLiteral(event_reason));
        sense(perception);
    }

    // Elabora eventi object_state (seen/grabbable/lost)
    private void handle_object_state(JSONObject data) {
        String event = data.getString("event");
        JSONObject obj = data.getJSONObject("object");

        String name = obj.getString("name");
        String reparto = obj.getString("reparto");
        boolean grabbable = obj.getBoolean("grabbable");

        // perception(object_state, event, name, reparto, grabbable)
        Literal perception = createLiteral("perception",
                createLiteral("object_state"),
                createString(event),
                createString(name),
                createString(reparto),
                createLiteral(Boolean.toString(grabbable)));
        // System.out.println("[DEBUG] Sensing: " + perception.toString());
        sense(perception);
    }

    // Questa funzione gestisce i messaggi che arrivano dal body
    // tipi: signal
    public void vesna_handle_msg(String msg) {
        // System.out.println("Received message: " + msg);
        JSONObject log = new JSONObject(msg);
        String sender = log.getString("sender");
        String receiver = log.getString("receiver");
        String type = log.getString("type");
        JSONObject data = log.getJSONObject("data");
        switch (type) {
            case "signal":
                handle_event(data);
                break;
            case "perception":
                if (data.getString("perception_type").equals("object_state")) {
                    handle_object_state(data);
                }
                break;
            default:
                System.out.println("Unknown message type: " + type);
        }
    }

    // fermo l'agente e kill
    private void stop(String reason) {
        System.out.println("[" + my_name + " ERROR] " + reason);
        kill_agent();
    }

    // Gestisce errore connessione: stampa errore e kill agente
    public void vesna_handle_error(Exception ex) {
        System.out.println("[" + my_name + " ERROR] " + ex.getMessage());
        kill_agent();
    }

    // L'agente viene killato chiamando InternalAction droppando tutte le
    // intenzioni, desideri ed eventi.
    private void kill_agent() {
        // System.out.println("[" + my_name + " ERROR] Killing agent");
        try {
            InternalAction drop_all_desires = getIA(".drop_all_desires");
            InternalAction drop_all_intentions = getIA(".drop_all_intentions");
            InternalAction drop_all_events = getIA(".drop_all_events");
            InternalAction action = getIA(".kill_agent");

            drop_all_desires.execute(getTS(), new Unifier(), new Term[] {});
            drop_all_intentions.execute(getTS(), new Unifier(), new Term[] {});
            drop_all_events.execute(getTS(), new Unifier(), new Term[] {});
            action.execute(getTS(), new Unifier(), new Term[] { createString(my_name) });
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

}