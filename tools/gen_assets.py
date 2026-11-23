#!/usr/bin/env python3
"""
GPT Image API batch asset generator for Kaizo Trap (Godot 4).
Reads GPT_IMAGE_API_KEY and GPT_IMAGE_BASE_URL from environment variables.
Never hardcodes or prints API keys.
"""

import argparse
import base64
import json
import os
import sys
import time
from pathlib import Path

from openai import OpenAI


def get_client() -> OpenAI:
    api_key = os.environ.get("GPT_IMAGE_API_KEY") or os.environ.get("OPENAI_API_KEY")
    base_url = os.environ.get("GPT_IMAGE_BASE_URL") or os.environ.get("OPENAI_BASE_URL") or "https://api.openai.com/v1"
    if not api_key:
        raise RuntimeError(
            "Missing GPT_IMAGE_API_KEY (or OPENAI_API_KEY). "
            "Run via `zsh -c 'source ~/.zshrc && python3 tools/gen_assets.py ...'`."
        )
    return OpenAI(api_key=api_key, base_url=base_url)


def generate_one(
    client: OpenAI,
    prompt: str,
    out_path: Path,
    model: str = "gpt-image-1",
    size: str = "1024x1024",
    quality: str = "medium",
    background: str = "transparent",
    reference_image: Path | None = None,
) -> Path:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(1, 4):
        try:
            if reference_image and reference_image.exists():
                with open(reference_image, "rb") as img_f:
                    resp = client.images.edit(
                        model=model,
                        image=img_f,
                        prompt=prompt,
                        size=size,
                        quality=quality,
                        background=background,
                    )
            else:
                resp = client.images.generate(
                    model=model,
                    prompt=prompt,
                    size=size,
                    quality=quality,
                    background=background,
                )
            b64 = resp.data[0].b64_json
            out_path.write_bytes(base64.b64decode(b64))
            print(f"[OK] {out_path} ({out_path.stat().st_size} bytes)")
            return out_path
        except Exception as e:
            print(f"[WARN] Attempt {attempt} failed for {out_path.name}: {e}", file=sys.stderr)
            if attempt == 3:
                raise
            time.sleep(2 * attempt)
    return out_path


def main():
    parser = argparse.ArgumentParser(description="Generate Kaizo Trap game assets via GPT Image API.")
    parser.add_argument("--manifest", type=Path, help="JSON manifest describing batch assets to generate.")
    parser.add_argument("--only", nargs="*", help="Only generate specific asset IDs from manifest.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing files.")
    parser.add_argument("--prompt", type=str, help="Ad-hoc single prompt.")
    parser.add_argument("--out", type=Path, help="Output path for ad-hoc prompt.")
    parser.add_argument("--size", default="1024x1024")
    parser.add_argument("--quality", default="medium")
    parser.add_argument("--background", default="transparent")
    parser.add_argument("--model", default="gpt-image-1")
    args = parser.parse_args()

    client = get_client()

    if args.prompt and args.out:
        if args.out.exists() and not args.force:
            print(f"[SKIP] Exists: {args.out}")
            return
        generate_one(
            client,
            prompt=args.prompt,
            out_path=args.out,
            model=args.model,
            size=args.size,
            quality=args.quality,
            background=args.background,
        )
        return

    if not args.manifest:
        parser.error("Provide either --manifest or (--prompt and --out).")

    spec = json.loads(args.manifest.read_text(encoding="utf-8"))
    default_model = spec.get("model", args.model)
    style_prefix = spec.get("style_prefix", "")
    items = spec.get("assets", [])

    for item in items:
        aid = item["id"]
        if args.only and aid not in args.only:
            continue
        out_path = Path(item["out"])
        if out_path.exists() and not args.force:
            print(f"[SKIP] {aid} -> {out_path}")
            continue
        prompt = f"{style_prefix} {item['prompt']}".strip()
        ref = Path(item["reference"]) if item.get("reference") else None
        print(f"[GEN] {aid} -> {out_path}")
        generate_one(
            client,
            prompt=prompt,
            out_path=out_path,
            model=item.get("model", default_model),
            size=item.get("size", "1024x1024"),
            quality=item.get("quality", "medium"),
            background=item.get("background", "transparent"),
            reference_image=ref,
        )


if __name__ == "__main__":
    main()
