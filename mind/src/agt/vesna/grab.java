package vesna;

import jason.asSemantics.*;
import jason.asSyntax.*;
import org.json.JSONObject;

public class grab extends DefaultInternalAction {

    @Override
    public Object execute(TransitionSystem ts, Unifier un, Term[] args) throws Exception {
        // args[0] = artifact name to grab
        String artName = args[0].toString();
        if (args[0].isString()) {
            artName = ((StringTerm) args[0]).getString();
        }

        VesnaAgent agent = (VesnaAgent) ts.getAgArch().getTS().getAg();

        JSONObject data = new JSONObject();
        data.put("type", "grab");
        data.put("art_name", artName);

        JSONObject msg = new JSONObject();
        msg.put("sender", agent.getAgName());
        msg.put("receiver", "body");
        msg.put("type", "interact");
        msg.put("data", data);

        agent.perform(msg.toString());
        return true;
    }
}
