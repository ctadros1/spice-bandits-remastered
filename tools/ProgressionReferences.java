import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import java.util.*;

// Read-only bounded traversal through strings, CFString records and literals.
// This inventories statically recovered references, not every dynamic use.
public class ProgressionReferences extends GhidraScript {
    public void run() throws Exception {
        Set<String> needles = Set.of("tonextlevel", "levelpoints", "xppoints", "rank", "rank_short", "levelUp");
        var data = currentProgram.getListing().getDefinedData(true);
        while (data.hasNext()) {
            Data item = data.next();
            Object value = item.getValue();
            if (!(value instanceof String) || !needles.contains(value)) continue;
            var stringBlock = currentProgram.getMemory().getBlock(item.getAddress());
            if (stringBlock == null || !stringBlock.getName().contains("cstring")) continue;
            println("PROGRESSION_STRING " + item.getAddress() + " " + value);
            Set<Address> visited = new HashSet<>();
            Set<String> functions = new TreeSet<>();
            Set<Address> pending = new HashSet<>(); pending.add(item.getAddress());
            for (int depth = 0; depth < 5; depth++) {
                Set<Address> next = new HashSet<>();
                for (Address address : pending) {
                    if (!visited.add(address)) continue;
                    for (Reference reference : currentProgram.getReferenceManager().getReferencesTo(address)) {
                        Address from = reference.getFromAddress();
                        Function function = currentProgram.getFunctionManager().getFunctionContaining(from);
                        if (function != null) functions.add(function.getEntryPoint() + " " + function.getName());
                        else {
                            next.add(from);
                            Data containing = currentProgram.getListing().getDataContaining(from);
                            if (containing != null && containing.getLength() <= 16) next.add(containing.getAddress());
                            var block = currentProgram.getMemory().getBlock(from);
                            if (block != null && block.getName().contains("cfstring")) next.add(from.subtract(8));
                        }
                    }
                }
                pending = next;
            }
            for (String function : functions) println("PROGRESSION_USE " + value + " " + function);
        }
    }
}
