import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;

// Read-only lookup of existing string references in the preserved program.
public class FindStringReferences extends GhidraScript {
    public void run() throws Exception {
        String needle = getScriptArgs()[0];
        var data = currentProgram.getListing().getDefinedData(true);
        while (data.hasNext()) {
            Data item = data.next();
            Object value = item.getValue();
            if (!(value instanceof String) || !((String)value).contains(needle)) continue;
            Address address = item.getAddress();
            println("STRING " + address + " " + value);
            for (Reference reference : currentProgram.getReferenceManager().getReferencesTo(address)) {
                Function function = currentProgram.getFunctionManager().getFunctionContaining(reference.getFromAddress());
                println("REFERENCE " + reference.getFromAddress() + " " + (function == null ? "no function" : function.getEntryPoint() + " " + function.getName()));
            }
        }
    }
}
