import argparse
from datetime import datetime, timezone, timedelta
import hashlib
import json
from os import path
import sys


# ---------------------------
# Config / constants
# ---------------------------

USER = "joe@hex-rays.com"
LICENSE_ID = "96-2137-ACAB-99"


PUB_MODULUS_UNPATCHED_BYTES = bytes.fromhex(
    "edfd425cf978546e8911225884436c57140525650bcf6ebfe80edbc5fb1de68f4c66c29cb22eb668788afcb0abbb718044584b810f8970cddf227385f75d5dddd91d4f18937a08aa83b28c49d12dc92e7505bb38809e91bd0fbd2f2e6ab1d2e33c0c55d5bddd478ee8bf845fcef3c82b9d2929ecb71f4d1b3db96e3a8e7aaf93"
)

PUB_MODULUS_PATCHED_BYTES = bytes.fromhex(
    "edfd42cbf978546e8911225884436c57140525650bcf6ebfe80edbc5fb1de68f4c66c29cb22eb668788afcb0abbb718044584b810f8970cddf227385f75d5dddd91d4f18937a08aa83b28c49d12dc92e7505bb38809e91bd0fbd2f2e6ab1d2e33c0c55d5bddd478ee8bf845fcef3c82b9d2929ecb71f4d1b3db96e3a8e7aaf93"
)

PUB_MODULUS_PATCHED = int.from_bytes(
    PUB_MODULUS_PATCHED_BYTES,
    byteorder="little",
)

PRIVATE_KEY = int.from_bytes(
    bytes.fromhex(
        "77c86abbb7f3bb134436797b68ff47beb1a5457816608dbfb72641814dd464dd640d711d5732d3017a1c4e63d835822f00a4eab619a2c4791cf33f9f57f9c2ae4d9eed9981e79ac9b8f8a411f68f25b9f0c05d04d11e22a3a0d8d4672b56a61f1532282ff4e4e74759e832b70e98b9d102d07e9fb9ba8d15810b144970029874"
    ),
    byteorder="little",
)


# ---------------------------
# Patcher
# ---------------------------


def patch_binary(filename: str) -> int:
    with open(filename, "rb+") as f:
        data = f.read()

        if PUB_MODULUS_PATCHED_BYTES in data:
            print(f"{filename} already patched")
            return 0

        if PUB_MODULUS_UNPATCHED_BYTES not in data:
            print(f"{filename} missing original modulus")
            return 1

        data = data.replace(PUB_MODULUS_UNPATCHED_BYTES, PUB_MODULUS_PATCHED_BYTES)

        f.seek(0)
        f.write(data)
        f.truncate()

    print(f"{filename} patched successfully")
    return 0


# ---------------------------
# Helpers
# ---------------------------


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="+", help="Files to patch")
    parser.add_argument("--output-dir", required=True, help="Directory to save license")
    return parser.parse_args()


def json_stringify_alphabetical(obj) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"))


def buf_to_bigint(buf: bytes) -> int:
    return int.from_bytes(buf, byteorder="little")


def bigint_to_buf(i: int) -> bytes:
    if i == 0:
        return b"\x00"
    return i.to_bytes((i.bit_length() + 7) // 8, byteorder="little")


def sign_raw(message: bytes) -> bytes:
    value = pow(buf_to_bigint(message[::-1]), PRIVATE_KEY, PUB_MODULUS_PATCHED)
    return bigint_to_buf(value)


# ---------------------------
# License generation
# ---------------------------


def build_license_payload(user: str) -> dict:
    now = datetime.now(timezone.utc)

    start_date = now.strftime("%Y-%m-%d")
    end_date = (now + timedelta(days=365 * 3)).strftime("%Y-%m-%d")
    addon_end = (now + timedelta(days=365 * 10)).strftime("%Y-%m-%d")

    addons_list = [
        "HEXX86",
        "HEXX64",
        "HEXARM",
        "HEXARM64",
        "HEXMIPS",
        "HEXMIPS64",
        "HEXPPC",
        "HEXPPC64",
        "HEXRV",
        "HEXRV64",
        "HEXARC",
        "HEXARC64",
        "TEAMS",
        "LUMINA",
    ]

    add_ons = [
        {
            "id": f"97-1337-DEAD-{i:02}",
            "code": addon,
            "owner": LICENSE_ID,
            "start_date": start_date,
            "end_date": addon_end,
        }
        for i, addon in enumerate(addons_list)
    ]

    return {
        "name": user,
        "email": user,
        "licenses": [
            {
                "id": LICENSE_ID,
                "owner": user,
                "product_id": "IDAPRO",
                "edition_id": "ida-pro",
                "description": "IDA Pro",
                "start_date": start_date,
                "end_date": end_date,
                "issued_on": now.strftime("%Y-%m-%d %H:%M:%S"),
                "license_type": "named",
                "seats": 999,
                "add_ons": add_ons,
            }
        ],
    }


def sign_hexlic(payload: dict) -> str:
    data = json_stringify_alphabetical({"payload": payload})
    digest = hashlib.sha256(data.encode()).digest()
    signature = sign_raw(digest)
    return signature.hex().upper()


# ---------------------------
# Main
# ---------------------------


def main():
    args = parse_args()

    if not path.isdir(args.output_dir):
        print(f"Error: '{args.output_dir}' is not a directory")
        sys.exit(1)

    for file_to_patch in args.files:
        if not path.isfile(file_to_patch):
            print(f"File not found: {file_to_patch}")
            sys.exit(1)

        patch_result = patch_binary(file_to_patch)
        if patch_result != 0:
            print("Patching failed, aborting license generation")
            sys.exit(patch_result)

    payload = build_license_payload(USER)

    license_obj = {
        "header": {"version": 1},
        "payload": payload,
    }

    license_obj["signature"] = sign_hexlic(payload)

    output_dir = args.output_dir

    licence_filename = path.join(output_dir, f"idapro_{LICENSE_ID}.hexlic")

    with open(licence_filename, "w", encoding="utf-8", newline="\n") as f:
        json.dump(license_obj, f, indent=2)

    print(f"Saved new license to: {path.abspath(licence_filename)}")


if __name__ == "__main__":
    main()
