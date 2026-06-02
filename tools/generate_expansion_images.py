#!/usr/bin/env python3
"""Batch-generate Gemini images for the 35 expansion tiles that are missing images.

Usage:
    GEMINI_API_KEY=your_key python3 tools/generate_expansion_images.py

Skips any tile that already has an image — safe to re-run.
"""
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from tile_manager import build_prompt, generate_image, image_path, load_tiles, save_image

EXPANSION_IDS = {
    "9B065D10-BFC4-4F13-B55E-4C381E93B5F1",
    "F13130B6-F91E-4AB0-8F5E-0D78012FED10",
    "EE025CEB-CF0C-4B8B-B2C4-5DD5FABF484C",
    "49DCAF71-20F7-425E-83C3-BEA541E82C01",
    "9811541E-7462-4E55-9D72-1EC50E853487",
    "4A6F0A09-BEEE-4B22-9F08-DD3FA5E7861D",
    "8A6DDE7A-D898-4163-B368-7D8527BA7EDB",
    "02F27115-3015-4E82-8D0B-64793ADF6E5E",
    "391C52F2-7048-4306-A5DD-5B7E31F30754",
    "6095A398-03E7-408D-872B-6F4CA92CF523",
    "43EFE221-9ED9-4310-8AD7-48D2E80EA9BD",
    "482FB7B8-8EE6-40A8-969B-59C5B3D277FF",
    "CFBE92A6-A1F6-4D30-B44F-7CDFB5384CD1",
    "12A965BC-8552-456E-90AF-0F6C857FF2A0",
    "C2BCE873-5656-4822-B94C-FD561CEE650F",
    "9C3F7FB1-5250-481F-BA08-DA080930F4F5",
    "2471C006-1253-4783-B0D2-41AE387D3C85",
    "CB459265-48C5-464C-BC93-0E1FA56736A1",
    "3CDE83B2-AE06-430C-B480-40E5CFB51A8E",
    "FA504171-203E-4FB2-A2BB-96B8F4EFF1D7",
    "8220E083-8E42-44FF-A985-1CA60FA75961",
    "6ABE672F-877D-44D0-87D0-ED1876CC2A13",
    "8170774F-790E-48F1-B6BE-2CBE00354839",
    "4154F951-8955-4AE1-B1AC-4F91CF49833C",
    "68B1D9C5-D513-49B7-B5BC-5BC436A37618",
    "9D79F99D-5077-4C25-A5DD-1B83877B1145",
    "51132CE8-299E-4E53-B4A9-FD6265EFC423",
    "76D9D3D6-CD19-47A5-9895-442B3B0D92A7",
    "B2C2C8A7-9681-4917-9978-A0A051B20A3E",
    "D15D9B6D-AB4A-425A-8B2D-F919BE3008C8",
    "08A6045A-0A6C-4CA4-945D-B23A697B6D07",
    "B680DC17-B247-409A-8590-71132BA51CB5",
    "F4F47AEE-19EB-4630-A6A0-BFCB228663DB",
    "9B64F835-F92E-4A5D-AE22-C323BED32157",
    "E2036612-8B10-4F94-B99D-B29FA56B4A30",
}


def main():
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        sys.exit("ERROR: GEMINI_API_KEY is not set.\nUsage: GEMINI_API_KEY=your_key python3 tools/generate_expansion_images.py")

    tiles = load_tiles()
    expansion_tiles = [t for t in tiles if t["id"] in EXPANSION_IDS]

    if len(expansion_tiles) != 35:
        print(f"WARNING: expected 35 expansion tiles, found {len(expansion_tiles)}")
        missing = EXPANSION_IDS - {t["id"] for t in expansion_tiles}
        for mid in sorted(missing):
            print(f"  Missing: {mid}")

    to_generate = [t for t in expansion_tiles if not image_path(t["id"]).exists()]
    already_done = len(expansion_tiles) - len(to_generate)

    if already_done:
        print(f"Skipping {already_done} tiles that already have images.")
    print(f"Generating images for {len(to_generate)} tiles...")

    failed = []
    for i, tile in enumerate(to_generate, 1):
        print(f"[{i}/{len(to_generate)}] {tile['text']}...", end=" ", flush=True)
        try:
            prompt = build_prompt(tile)
            b64 = generate_image(prompt, api_key)
            save_image(tile["id"], b64)
            size = image_path(tile["id"]).stat().st_size
            print(f"✓  ({size:,} bytes)")
        except Exception as exc:
            print(f"✗  ERROR: {exc}")
            failed.append((tile["text"], str(exc)))

        if i < len(to_generate):
            time.sleep(1)  # 1-second pause between requests

    print()
    if failed:
        print(f"⚠  {len(failed)} tiles failed:")
        for name, err in failed:
            print(f"  • {name}: {err}")
        print("Re-run the script to retry failed tiles.")
    else:
        print(f"✓ All {len(to_generate)} images generated successfully.")


if __name__ == "__main__":
    main()
