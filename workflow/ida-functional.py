"""Run inside IDA through -S to verify an actual analysis database round trip."""

import json
import os
from pathlib import Path

import ida_auto
import ida_funcs
import ida_lines
import ida_loader
import ida_name
import ida_nalt
import idc

output = Path(os.environ["IDA_INSPECTION_OUTPUT"])
mode = os.environ["IDA_INSPECTION_MODE"]
database = os.environ["IDA_INSPECTION_DATABASE"]

try:
    if not ida_auto.auto_wait():
        raise RuntimeError("IDA auto-analysis was interrupted")
    count = ida_funcs.get_func_qty()
    if count < 1:
        raise RuntimeError("IDA found no functions in the ELF fixture")
    examples = []
    for index in range(min(count, 64)):
        function = ida_funcs.getn_func(index)
        if function is None:
            continue
        line = ida_lines.generate_disasm_line(function.start_ea)
        if line:
            examples.append(
                {
                    "address": hex(function.start_ea),
                    "disassembly": ida_lines.tag_remove(line),
                }
            )
        if len(examples) == 3:
            break
    if not examples:
        raise RuntimeError("IDA found functions but produced no disassembly")
    named_address = int(examples[0]["address"], 16)
    inspection_name = "inspection_roundtrip_function"
    if mode == "analyze" and not ida_name.set_name(
        named_address, inspection_name, ida_name.SN_CHECK
    ):
        raise RuntimeError("IDA could not rename an analyzed function")
    if ida_funcs.get_func_name(named_address) != inspection_name:
        raise RuntimeError("IDA did not retain the renamed function")
    result = {
        "status": "pass",
        "mode": mode,
        "functionCount": count,
        "examples": examples,
        "inputPath": ida_nalt.get_input_file_path(),
        "renamedFunction": inspection_name,
    }
    try:
        import ida_hexrays

        if ida_hexrays.init_hexrays_plugin():
            pseudocode = None
            for index in range(min(count, 64)):
                function = ida_funcs.getn_func(index)
                try:
                    candidate = ida_hexrays.decompile(function.start_ea)
                    if candidate:
                        pseudocode = str(candidate)[:500]
                        break
                except Exception:
                    continue
            if not pseudocode:
                raise RuntimeError("Hex-Rays is available but decompiled no function")
            result["decompiler"] = {"status": "pass", "pseudocode": pseudocode}
        else:
            result["decompiler"] = {"status": "unavailable"}
    except ImportError:
        result["decompiler"] = {"status": "unavailable"}
    if mode == "analyze" and not ida_loader.save_database(database):
        raise RuntimeError("IDA could not save its analysis database")
    output.write_text(json.dumps(result, indent=2) + "\n")
    idc.qexit(0)
except Exception as error:
    output.write_text(
        json.dumps({"status": "fail", "mode": mode, "reason": str(error)}) + "\n"
    )
    idc.qexit(1)
