package vesna;

import org.json.JSONObject;

import jason.asSemantics.DefaultInternalAction;
import jason.asSemantics.TransitionSystem;
import jason.asSemantics.Unifier;
import jason.asSyntax.NumberTerm;
import jason.asSyntax.StringTerm;
import jason.asSyntax.Term;

public class walk extends DefaultInternalAction {

    // walk() performs a step
    // walk( n ) performs a step of length n
    // walk( target ) goes to target (full waypoint traversal)
    // walk( target, id ) goes to target with id
    // walk( target, "quick" ) goes to target center only (no waypoint traversal)

    @Override
    public Object execute(TransitionSystem ts, Unifier un, Term[] args) throws Exception {

        String type = "none";
        String mode = "full"; // default: traverse all waypoints

        if (args.length == 0)
            type = "step";
        else if (args.length == 1) {
            if (args[0].isNumeric())
                type = "step";
            else if (args[0].isLiteral() || args[0].isString())
                type = "goto";
        } else if (args.length == 2 && (args[0].isLiteral() || args[0].isString()) && args[1].isString()) {
            // walk(target, "quick") — goto with mode
            type = "goto";
            mode = ((StringTerm) args[1]).getString();
        } else if (args.length == 2 && (args[0].isLiteral() || args[0].isString()) && args[1].isNumeric())
            type = "goto";
        else if (args.length == 2 && (args[0].isLiteral() || args[0].isString()) && !args[1].isGround())
            type = "goto";
        else
            return false;

        JSONObject data = new JSONObject();
        data.put("type", type);
        if (type.equals("step")) {
            if (args.length == 2) {
                data.put("length", ((NumberTerm) args[1]).solve());
            }
        } else if (type.equals("goto")) {
            String target = args[0].toString();
            if (args[0].isString())
                target = ((StringTerm) args[0]).getString();
            data.put("target", target);
            data.put("mode", mode);

            if (args.length == 2 && args[1].isNumeric() && args[1].isGround())
                data.put("id", ((NumberTerm) args[1]).solve());
        }

        JSONObject action = new JSONObject();
        action.put("sender", ts.getAgArch().getAgName());
        action.put("receiver", "body");
        action.put("type", "walk");
        action.put("data", data);

        VesnaAgent ag = (VesnaAgent) ts.getAg();
        ag.perform(action.toString());

        return true;
    }

}
