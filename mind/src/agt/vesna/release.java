package vesna;

import jason.asSemantics.*;
import jason.asSyntax.*;
import org.json.JSONObject;

public class release extends DefaultInternalAction {

    @Override
    public Object execute(TransitionSystem ts, Unifier un, Term[] args) throws Exception {
        // args[0] = artifact name to release
        String artName = args[0].toString();
        if (args[0].isString()) {
            artName = ((StringTerm) args[0]).getString();
        }

        JSONObject data = new JSONObject();
        data.put("type", "release");
        data.put("art_name", artName);

        JSONObject msg = new JSONObject();
        msg.put("sender", ts.getAgArch().getAgName());
        msg.put("receiver", "body");
        msg.put("type", "interact");
        msg.put("data", data);

        VesnaAgent agent = (VesnaAgent) ts.getAg();
        agent.perform(msg.toString());
        return true;
    }
}
