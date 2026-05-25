#!/usr/bin/env python3
"""
Road Trip Bingo — Tile Manager
Usage: GEMINI_API_KEY=your_key python3 tools/tile_manager.py
Opens a browser UI for managing tiles in squares.json and TileImages/.
"""

import base64, json, os, sys, uuid, webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

import requests

# ── Paths (resolved relative to this script) ────────────────────────────────
SCRIPT_DIR   = Path(__file__).parent
REPO_ROOT    = SCRIPT_DIR.parent
SQUARES_JSON = REPO_ROOT / "RoadTripBingo/Resources/squares.json"
TILE_IMAGES  = REPO_ROOT / "RoadTripBingo/Resources/TileImages"

# ── To add a new category: add it to BOTH constants below ───────────────────

CATEGORIES = [
    "vehicles", "nature", "food", "landmarks", "weather", "signs",
    # Add new categories here — they appear in the UI dropdowns automatically
]

CATEGORY_HINTS = {
    # Add a hint for each new category — shapes the image generation prompt
    "vehicles":  "Side view, full vehicle visible.",
    "nature":    "Full subject visible, centered.",
    "signs":     "The physical sign or object itself, not just a flat sign graphic.",
    "landmarks": "Full structure visible.",
    "food":      "Storefront or roadside view.",
    "weather":   "Dramatic sky scene.",
}

RARITIES = ["veryCommon", "common", "uncommon", "rare", "veryRare"]

STYLE = (
    "Flat vector illustration, clean thin outlines, bright colors. "
    "Plain solid white background — the illustration sits directly on white "
    "with absolutely no drop shadow, no border, no card, no frame, no vignette, "
    "no outline around the image edge. "
    "Square composition. No text, no labels, no letters."
)

# Per-tile prompt overrides for subjects that need extra specificity.
# Key = tile text, value = subject phrase (replaces "a {text.lower()}").
OVERRIDES: dict[str, str] = {}

GEMINI_MODEL = "gemini-2.5-flash-image"
GEMINI_URL   = (
    f"https://generativelanguage.googleapis.com/v1beta/models"
    f"/{GEMINI_MODEL}:generateContent"
)

PORT = 8765


def build_prompt(text: str, category: str) -> str:
    """Build the Gemini image generation prompt for a tile."""
    subject = OVERRIDES.get(text, f"a {text.lower()}")
    hint = CATEGORY_HINTS.get(category, "")
    # Strip trailing period and capitalize only the first character
    subject_clean = subject.rstrip(".")
    subject_cap = subject_clean[0].upper() + subject_clean[1:]
    parts = [f"{subject_cap}.", hint, STYLE]
    return " ".join(p for p in parts if p).strip()


# ── File I/O ─────────────────────────────────────────────────────────────────

def load_tiles() -> list[dict]:
    """Load all tiles from squares.json."""
    with open(SQUARES_JSON, encoding="utf-8") as f:
        return json.load(f)


def save_tiles(tiles: list[dict]) -> None:
    """Write tiles back to squares.json.

    Tile array order is preserved as-is. Keys within each tile object
    are sorted alphabetically for stable diffs.
    """
    with open(SQUARES_JSON, "w", encoding="utf-8") as f:
        json.dump(tiles, f, indent=2, sort_keys=True, ensure_ascii=False)
        f.write("\n")


def image_path(tile_id: str) -> Path:
    """Return the Path for a tile's PNG image."""
    return TILE_IMAGES / f"{tile_id}.png"


def save_image(tile_id: str, image_b64: str) -> None:
    """Decode base64 and write the image to TileImages/."""
    data = base64.b64decode(image_b64)
    p = image_path(tile_id)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(data)


# ── Gemini API ────────────────────────────────────────────────────────────────

def generate_image(prompt: str, api_key: str) -> str:
    """Call Gemini to generate an image. Returns base64-encoded PNG. Raises on error."""
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }
    resp = requests.post(
        f"{GEMINI_URL}?key={api_key}",
        json=payload,
        timeout=90,
    )
    resp.raise_for_status()
    data = resp.json()
    parts = data["candidates"][0]["content"]["parts"]
    for part in parts:
        if "inlineData" in part:
            return part["inlineData"]["data"]
    raise ValueError(f"No image in Gemini response; parts received: {parts!r}")


# ── Embedded HTML app (filled in Task 5) ─────────────────────────────────────
HTML_APP = "<html><body><p>UI coming soon</p></body></html>"


# ── HTTP Server ───────────────────────────────────────────────────────────────

class TileManagerHandler(BaseHTTPRequestHandler):
    api_key: str = ""

    def log_message(self, fmt, *args):
        pass  # suppress default per-request logging

    # ── Helpers ───────────────────────────────────────────────────────────────

    def send_json(self, data: object, status: int = 200) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_error_json(self, status: int, message: str) -> None:
        self.send_json({"error": message}, status)

    def read_json_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length))

    # ── Routing ───────────────────────────────────────────────────────────────

    def do_GET(self):
        path = self.path.split("?")[0]  # strip query string
        if path in ("/", "/index.html"):
            self._serve_ui()
        elif path == "/api/tiles":
            self.send_json(load_tiles())
        elif path.startswith("/api/image/"):
            self._serve_image(path[len("/api/image/"):])
        else:
            self.send_error_json(404, "Not found")

    def do_POST(self):
        if self.path == "/api/generate":
            self._handle_generate()
        elif self.path == "/api/tiles":
            self._handle_add_tile()
        elif self.path.startswith("/api/tiles/") and self.path.endswith("/image"):
            tile_id = self.path[len("/api/tiles/"):-len("/image")]
            self._handle_save_image(tile_id)
        else:
            self.send_error_json(404, "Not found")

    def do_PUT(self):
        if self.path.startswith("/api/tiles/"):
            tile_id = self.path[len("/api/tiles/"):]
            self._handle_update_tile(tile_id)
        else:
            self.send_error_json(404, "Not found")

    def do_DELETE(self):
        if self.path.startswith("/api/tiles/"):
            tile_id = self.path[len("/api/tiles/"):]
            self._handle_delete_tile(tile_id)
        else:
            self.send_error_json(404, "Not found")

    # ── Handlers ─────────────────────────────────────────────────────────────

    def _serve_ui(self):
        # Inject runtime config into the HTML so JS knows categories/rarities
        html = HTML_APP.replace(
            "/* __INJECT__ */",
            f"const CATEGORIES = {json.dumps(CATEGORIES)};\n"
            f"    const RARITIES = {json.dumps(RARITIES)};",
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(html)))
        self.end_headers()
        self.wfile.write(html)

    def _serve_image(self, tile_id: str):
        path = image_path(tile_id)
        if not path.exists():
            self.send_error_json(404, "Image not found")
            return
        data = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _handle_generate(self):
        if not self.api_key:
            self.send_error_json(
                503,
                "GEMINI_API_KEY not set — start server with GEMINI_API_KEY=your_key",
            )
            return
        body = self.read_json_body()
        prompt = body.get("prompt", "").strip()
        if not prompt:
            self.send_error_json(400, "prompt is required")
            return
        try:
            image_b64 = generate_image(prompt, self.api_key)
            self.send_json({"image_b64": image_b64})
        except Exception as exc:
            self.send_error_json(500, str(exc))

    def _handle_add_tile(self):
        body = self.read_json_body()
        required = {"text", "emoji", "category", "rarity"}
        missing = required - body.keys()
        if missing:
            self.send_error_json(400, f"Missing fields: {', '.join(sorted(missing))}")
            return
        new_id = str(uuid.uuid4()).upper()
        tile = {
            "id":       new_id,
            "text":     body["text"],
            "emoji":    body["emoji"],
            "category": body["category"],
            "rarity":   body["rarity"],
        }
        tiles = load_tiles()
        tiles.append(tile)
        save_tiles(tiles)
        if "image_b64" in body:
            save_image(new_id, body["image_b64"])
        self.send_json(tile, 201)

    def _handle_update_tile(self, tile_id: str):
        body = self.read_json_body()
        tiles = load_tiles()
        for tile in tiles:
            if tile["id"] == tile_id:
                allowed = {"text", "emoji", "category", "rarity"}
                tile.update({k: v for k, v in body.items() if k in allowed})
                save_tiles(tiles)
                self.send_json(tile)
                return
        self.send_error_json(404, f"Tile {tile_id} not found")

    def _handle_delete_tile(self, tile_id: str):
        tiles = load_tiles()
        new_tiles = [t for t in tiles if t["id"] != tile_id]
        if len(new_tiles) == len(tiles):
            self.send_error_json(404, f"Tile {tile_id} not found")
            return
        save_tiles(new_tiles)
        img = image_path(tile_id)
        if img.exists():
            img.unlink()
        self.send_json({"deleted": tile_id})

    def _handle_save_image(self, tile_id: str):
        body = self.read_json_body()
        image_b64 = body.get("image_b64", "")
        if not image_b64:
            self.send_error_json(400, "image_b64 is required")
            return
        save_image(tile_id, image_b64)
        self.send_json({"saved": tile_id})


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        print("⚠  GEMINI_API_KEY not set — image generation will be disabled")
    TileManagerHandler.api_key = api_key

    server = HTTPServer(("127.0.0.1", PORT), TileManagerHandler)
    url = f"http://localhost:{PORT}"
    print(f"✦  Tile Manager  →  {url}")
    print("   Press Ctrl+C to stop\n")
    webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
