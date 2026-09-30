#!/usr/bin/env python3
"""Accept the current IDA EULA in an ephemeral inspection guest.

Hex-Rays HCLI uses the same idalib registry API when --accept-eula is selected.
The workflow invokes this only after its idle measurements, never in an ISO build.
"""

import json
import os
import shutil
import sys
from pathlib import Path


def main():
    if sys.version_info[:2] != (3, 13):
        interpreters = sorted(Path("/nix/store").glob("*-python3-3.13*/bin/python3.13"))
        if not interpreters:
            raise RuntimeError("IDA's Python 3.13 interpreter is unavailable")
        os.execv(str(interpreters[0]), [str(interpreters[0]), __file__])

    executable = shutil.which("ida")
    if not executable:
        raise RuntimeError("IDA is not installed in the inspection guest")
    install_dir = Path(
        os.environ.get(
            "IDA_INSPECTION_INSTALL_DIR", str(Path(executable).resolve().parent)
        )
    )
    if not (install_dir / "libidalib.so").is_file():
        raise RuntimeError(f"IDA idalib is missing from {install_dir}")

    os.environ["IDADIR"] = str(install_dir)
    sys.path.insert(0, str(install_dir / "idalib" / "python"))

    import idapro  # noqa: F401  # Hex-Rays requires this import before ida_registry.
    import ida_registry

    keys = [f"EULA {version}" for version in range(90, 95)]
    for key in keys:
        ida_registry.reg_write_int(key, 1)
    registry = Path.home() / ".idapro" / "ida.reg"
    if not registry.is_file():
        raise RuntimeError("IDA did not write its per-user EULA registry")
    print(
        json.dumps(
            {
                "status": "accepted",
                "scope": "ephemeral-inspection-guest",
                "versionKeys": keys,
                "installDir": str(install_dir),
                "registry": str(registry),
            }
        )
    )


if __name__ == "__main__":
    main()
