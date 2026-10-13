// Reviewed, selected pseudocode and outgoing call graphs; never modifies the preserved binary.
// @category SpiceBandits
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;
import java.io.*;

public class DecompileSelected extends GhidraScript {
    public void run() throws Exception {
        String[] args = getScriptArgs();
        File output = new File(args[0]);
        output.mkdirs();
        DecompInterface decompiler = new DecompInterface();
        decompiler.openProgram(currentProgram);
        FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
        int count = 0;
        while (functions.hasNext() && !monitor.isCancelled()) {
            Function f = functions.next();
            boolean selected = args.length == 1;
            for (int i = 1; i < args.length; i++) {
                if (f.getName(true).contains(args[i]) || f.getEntryPoint().toString().equals(args[i])) selected = true;
            }
            if (!selected) continue;
            DecompileResults result = decompiler.decompileFunction(f, 60, monitor);
            String file = f.getEntryPoint().toString() + "_" + f.getName().replaceAll("[^A-Za-z0-9_-]", "_") + ".c";
            try (PrintWriter writer = new PrintWriter(new File(output, file))) {
                writer.println("/* Ghidra 12.1.4 pseudocode; inferred types require review.");
                writer.println("Program SHA256: " + currentProgram.getExecutableSHA256());
                writer.println("Function: " + f.getName(true) + " at " + f.getEntryPoint());
                writer.println("Outgoing calls:");
                for (Function target : f.getCalledFunctions(monitor)) writer.println(target.getEntryPoint() + " " + target.getName(true));
                writer.println("*/");
                if (result.decompileCompleted()) writer.println(result.getDecompiledFunction().getC());
                else writer.println("/* " + result.getErrorMessage() + " */");
            }
            count++;
        }
        decompiler.dispose();
        println("SELECTED_DECOMPILATIONS " + count);
    }
}
