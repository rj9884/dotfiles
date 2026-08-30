#!/usr/bin/env bash
# ──────────────────────────────────────────────
#   build-wallpapers.sh
#   Generate the optimized wallpaper set committed to the dotfiles repo.
#
#   Source:  ~/.local/share/wallpapers   (the live, safe location on the system)
#   Output:  <repo>/wallpapers/           (deduplicated + compressed)
#
#   What it does:
#     1. Copies only the per-theme collection dirs (glass, material, modern,
#        noro, retro). Root-level loose images are dropped because every one
#        is an exact duplicate of a file already inside a theme dir.
#     2. Converts large photographic PNGs to JPEG (quality 82), which is
#        visually near-identical but ~80-90% smaller.
#     3. Small PNGs that are flat graphics or already tiny are kept as-is.
# ──────────────────────────────────────────────

set -euo pipefail

SOURCE="${WALLPAPER_SOURCE:-$HOME/.local/share/wallpapers}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/wallpapers"

JPEG_QUALITY="${JPEG_QUALITY:-82}"

THEMES=(glass material modern noro retro)

error() { echo "error: $*" >&2; exit 1; }

[ -d "$SOURCE" ] || error "source wallpaper dir not found: $SOURCE"

# Always regenerate from scratch so the repo set stays canonical.
rm -rf "$OUT"
mkdir -p "$OUT"

for theme in "${THEMES[@]}"; do
    src_dir="$SOURCE/$theme"
    [ -d "$src_dir" ] || { echo "  (skip) no theme dir: $theme"; continue; }
    mkdir -p "$OUT/$theme"
    echo "=> $theme"

    while IFS= read -r -d '' f; do
        base="$(basename "$f")"
        ext="${base##*.}"
        ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

        case "$ext" in
            jpg|jpeg)
                cp -p "$f" "$OUT/$theme/$base"
                echo "   cp  $base"
                ;;
            png)
                # Keep small / flat PNGs; convert large photographic ones.
                sz=$(stat -c%s "$f")
                if [ "$sz" -gt 200000 ]; then
                    out_base="${base%.png}.jpg"
                    magick "$f" -quality "$JPEG_QUALITY" "$OUT/$theme/$out_base"
                    echo "   jpg $base -> $out_base"
                else
                    cp -p "$f" "$OUT/$theme/$base"
                    echo "   png $base (kept)"
                fi
                ;;
            *)
                echo "   (skip unsupported: $base)"
                ;;
        esac
    done < <(find "$src_dir" -maxdepth 1 -type f -print0)
done

echo
echo "Done. Repo wallpapers written to: $OUT"
du -sh "$OUT"
