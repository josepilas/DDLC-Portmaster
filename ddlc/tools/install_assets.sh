#!/bin/sh

cat <<'EOF'
This wrapper does not download, extract, or install original DDLC assets.

Please copy files from your own original DDLC installation into:

  ddlc/original/game/audio.rpa
  ddlc/original/game/images.rpa
  ddlc/original/game/scripts.rpa
  ddlc/original/game/fonts.rpa
  ddlc/original/characters/monika.chr
  ddlc/original/characters/sayori.chr
  ddlc/original/characters/natsuki.chr
  ddlc/original/characters/yuri.chr

After copying, run:

  ddlc/tools/check_assets.sh ddlc

EOF

exit 0
