#!/bin/bash
set -e

LOCAL_PATH=${LOCAL_WORKSPACE_FOLDER:-$(pwd)}
DRUN="docker run -w /board -v ${LOCAL_PATH}:/board --rm"
GITHUB_WORKSPACE=""
KICAD_IMAGE="ghcr.io/inti-cmnb/kicad8_auto:latest"
FREEROUTING_IMAGE="ghcr.io/freerouting/freerouting:2.2.4"
BOARDS="main_board"

npm run build

for board in $BOARDS; do
  echo "Processing $board";

  echo "Run kibot"
  ${DRUN} ${KICAD_IMAGE} kibot -b $GITHUB_WORKSPACE/output/pcbs/${board}.kicad_pcb -c $GITHUB_WORKSPACE/scripts/default.kibot.yaml
  
  echo "Export DSN"
  ${DRUN} ${KICAD_IMAGE} $GITHUB_WORKSPACE/scripts/export_dsn.py -b $GITHUB_WORKSPACE/output/pcbs/${board}.kicad_pcb -o $GITHUB_WORKSPACE/output/pcbs/${board}.dsn 

  echo "Autoroute PCB"
  ${DRUN} ${FREEROUTING_IMAGE} java -jar /app/freerouting-executable.jar -de $GITHUB_WORKSPACE/output/pcbs/${board}.dsn -do $GITHUB_WORKSPACE/output/pcbs/${board}.ses -dr $GITHUB_WORKSPACE/scripts/freerouting.rules --user_data_path=$GITHUB_WORKSPACE/scripts -mp 25 -mt 1 -dct 0 -da --gui.enabled=false --profile.email=info@freerouting.app

  echo "Import SES"
  ${DRUN} ${KICAD_IMAGE} $GITHUB_WORKSPACE/scripts/import_ses.py -b $GITHUB_WORKSPACE/output/pcbs/${board}.kicad_pcb -s $GITHUB_WORKSPACE/output/pcbs/${board}.ses -o $GITHUB_WORKSPACE/output/pcbs/${board}_autorouted.kicad_pcb

  echo "Run kibot again"
  ${DRUN} ${KICAD_IMAGE} kibot -b $GITHUB_WORKSPACE/output/pcbs/${board}_autorouted.kicad_pcb -c $GITHUB_WORKSPACE/scripts/boards.kibot.yaml
done

