#!/bin/sh

cat <<'EOF'
This wrapper does not download, extract, or install original DDLC assets.

Please copy or extract your own DDLC installation root into:

  ddlc/original/

Examples:

  ddlc/original/game/audio.rpa
  ddlc/original/characters/monika.chr

or:

  ddlc/original/DDLC-1.1.1-pc/game/audio.rpa
  ddlc/original/DDLC-1.1.1-pc/characters/monika.chr

Mods/translations can be applied inside ddlc/original the same way they are
applied to a normal DDLC PC folder.

After copying, run:

  ddlc/tools/check_assets.sh ddlc

EOF

exit 0
