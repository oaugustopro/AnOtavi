#!/bin/bash
#source ~/bin/shell/libkmrgobash.sh || xmessage "Faltou kmrgobash" || echo "Faltou kmrgobash"

#!/bin/bash

# Function to prompt for media type selection
prompt_for_media_type() {
    zenity --list \
           --text="Choose media type" \
           --radiolist \
           --column="Select" \
           --column="Media Type" \
           FALSE "audio" \
           FALSE "live" \
           TRUE "video"
}

# Function to check for dependencies
check_dependencies() {
    local dependencies=("mpv" "socat" "ffmpeg" "arecord")
    local missing_deps=0

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Error: $dep is not installed." >&2
            missing_deps=$((missing_deps + 1))
        fi
    done

    if [ "$missing_deps" -ne 0 ]; then
        echo "Please install the missing dependencies and run the script again." >&2
        exit 1
    fi
}


# Function to convert timestamp to a format suitable for mpv --start
convert_timestamp() {
    local hms=(${1//:/ })
    echo $((${hms[0]} * 3600 + ${hms[1]} * 60 + ${hms[2]}))
}

# Main processing function
make_org_file() {
    local input_content="$1"
    local mpv_file="$2"
    local line heading paragraph timestamp converted_timestamps
    declare -A chapters

    while IFS='|' read -r timestamp heading paragraph; do
        converted_timestamps=$(convert_timestamp "$timestamp")
        mpv_link="[[shell:mpv --geometry=800x600+300+300 --no-terminal --start=${converted_timestamps} ${mpv_file}][$timestamp]]"

        # Process the heading
        if [ -n "$heading" ]; then
            if [[ -z "${chapters[$heading]}" ]]; then
                # New chapter heading
                chapters[$heading]=1
                echo "* ${mpv_link} ${heading}"
            fi
        fi

        # Add paragraph as a link, if it exists
        if [ -n "$paragraph" ]; then
            echo "  - ${mpv_link} ${paragraph}"
        fi
    done <<< "$input_content"
}

# Function to handle the selected or detected media type
handle_media_type() {
    case $1 in
        "audio")
            echo "Audio option selected or detected."
            # Add your logic for audio here
            ;;
        "live")
            echo "Live option selected."
            # Add your logic for live here
            arecord -f S16_LE > "$baseDir"/"${fileBaseName}".wav &
            pidMidia=$(pgrep -f "arecord|mpv" | tail -n 1)
            oggenc -a $USER -t "$title" -l "Escola" -G "class" -c "Audio de aula" --downmix -q -1 -M 16 -o ~/Downloads/"${fileBaseName}".ogg ~/Downloads/"${fileBaseName}".wav
            kill -STOP "${pidMidia}"
            ;;
        "video")
            echo "Video option selected or detected."
            select_file "$file"
            SOCKET="/tmp/mpvsocket"
            /usr/bin/mpv --input-ipc-server=$SOCKET --screenshot-template="%F-%p" --screenshot-directory="$baseDir" --no-terminal --geometry=800x600+300+300 "$file" &
            create_initial_files
            sleep 1
            loop_text_prompt
            echo '[STREAM]
title='$fileBaseName'' >> "$baseDir"/"${fileBaseName}".metadata
            # Pos processing
            ffmpeg -i "$file" -i "$dirName/$fileBaseName.metadata" -map_metadata 1 -codec copy "$dirName/new.$fileName" || { echo "Não passou o ffmpeg"; exit 1; }
            # Example Usage
            input_data=$(cat "$dirName/$fileBaseName.nodes")
            mpv_file="$file"
            # Call the processing function
            make_org_file "$input_data" "$mpv_file" > "$dirName/$fileBaseName.org"
            ;;
        *)
            echo "No valid selection made or unrecognized option."
            ;;
    esac
}

loop_text_prompt(){
  echo "Press ENTER to make an annotation and press ENTER again to save it."
  pauseTimer=0
  while [ "$end" -eq 1 ]; do
      agora=$(get_playback_time)
      hora=$(bc -l <<< "scale=00;$agora/60/60" 2> /dev/null)
      minuto=$(bc -l <<< "scale=00;$agora%3600/60" 2> /dev/null)
      segundo=$(bc -l <<< "scale=00;$agora%3600%60" 2> /dev/null)
      echo "$(printf "%02d\n" $hora):$(printf "%02d\n" $minuto):$(printf "%.02d\n" $segundo 2> /dev/null) "
      echo " Press (Esc)Pause, (Enter)Annotate, (c)Chapter, (.)Screenshot, (=)Save and Exit [${fileName}]: "
      read -s -n1 keypressed
      agora=$(get_playback_time)
      case "$keypressed" in
      $'\e')
          send_command "pause" "true"
          read -p "PAUSA ${pidMidia}, digite ENTER para voltar: "
          send_command "pause" "false"
          ;;
      '=')
          end=0
          ;;
      'c')
          read -p "Chapter: " capitulo
          endTimer="$(get_playback_time)"
          diffTimer=$( bc -l <<< "$endTimer - $agora" )
          tempoInicio=$(bc -l <<< "scale=00;($agora)")
          tempoFim=$(bc -l <<< "scale=00;($diffTimer+$tempoInicio)")
          horaInicio=$(bc -l <<< "scale=00;$tempoInicio/60/60")
          minutoInicio=$(bc -l <<< "scale=00;($tempoInicio)%3600/60")
          segundoInicio=$(bc -l <<< "scale=00;($tempoInicio)%3600%60")
          echo ''$counter'
'$horaInicio':'$minutoInicio':'$segundoInicio',000 --> '$horaFim':'$minutoFim':'$segundoFim',000
'`echo "$linha" | sed -E 's/(.{30})/\1\n/g' `
          echo '[CHAPTER]
TIMEBASE=1/1000
START='$(( $(printf "%.0f" $(echo "$tempoInicio * 1000" | bc) 2> /dev/null) ))'
END='$(( $(printf "%.0f" $(echo "$tempoFim * 1000" | bc) 2> /dev/null) ))'
title='$capitulo'' >> "$baseDir"/${fileBaseName}.metadata
          echo "$horaInicio:$minutoInicio:$segundoInicio|$capitulo|" >> "$baseDir"/"$fileBaseName.nodes"
          ;;
      '.')
          echo "Taking a picture"
          take_screenshot
          ((counter++))
          read -p "Legenda da foto: " linha
          endTimer="$(get_playback_time)"
          diffTimer=$( bc -l <<< "$endTimer - $agora" )
          tempoInicio=$(bc -l <<< "scale=00;$agora")
          horaInicio=$(bc -l <<< "scale=00;$tempoInicio/60/60")
          minutoInicio=$(bc -l <<< "scale=00;$tempoInicio%3600/60")
          segundoInicio=$(bc -l <<< "scale=00;$tempoInicio%3600%60")
          horaFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)/60/60")
          minutoFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)%3600/60")
          segundoFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)%3600%60")
          echo ''$counter'
'$horaInicio':'$minutoInicio':'$segundoInicio',000 --> '$horaFim':'$minutoFim':'$segundoFim',000
'`echo "FOTO $linha" | sed -E 's/(.{30})/\1\n/g' `'

' >> $baseDir/"$fileBaseName".srt
          echo "$horaInicio:$minutoInicio:$segundoInicio|$capitulo|[[$linha][file:$dirBase/$fileBaseName-$horaInicio:$minutoInicio:$segundoInicio]]" >> "$baseDir"/"$fileBaseName".nodes
          ffmpeg -f video4linux2 -s "1280x960" -i /dev/video0 -ss 0:0:2 -y -hide_banner -loglevel quiet -frames 1 "$baseDir"/"$fileBaseName-$horaInicio_$minutoInicio_$segundoInicio".jpg
          ;;
      $'\0A')
          ((counter++))
          read -p "Texto: " linha
          endTimer="$(get_playback_time)"
          diffTimer=$( bc -l <<< "$endTimer - $agora" )
          tempoInicio=$(bc -l <<< "scale=00;$agora")
          horaInicio=$(bc -l <<< "scale=00;$tempoInicio/60/60")
          minutoInicio=$(bc -l <<< "scale=00;$tempoInicio%3600/60")
          segundoInicio=$(bc -l <<< "scale=00;$tempoInicio%3600%60")
          horaFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)/60/60")
          minutoFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)%3600/60")
          segundoFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)%3600%60")
          echo ''$counter'
'$horaInicio':'$minutoInicio':'$segundoInicio',000 --> '$horaFim':'$minutoFim':'$segundoFim',000
'`echo "$linha" | sed -E 's/(.{30})/\1\n/g' `'

' >> "$baseDir"/"$fileBaseName".srt
          echo "$horaInicio:$minutoInicio:$segundoInicio|$capitulo|$linha" >> "$baseDir"/"$fileBaseName".nodes
          ;;
      esac
  done
}

loop_text_prompt_live(){
  echo "Como usar? Digite ENTER qdo quiser marcar um momento e então escreva, só aperte ENTER novamente quando encontrar outro ponto relevante"
  pauseTimer=0
  inicio="$(date +%s)"
  while [ "$end" -eq 1 ]; do
#      agora="$(date +"%s")"
#      agoraDiff=$(bc -l <<< "$agora - $inicio - $pauseTimer" )
      agora=$(get_playback_time)
      echo "AGORA:$agora"
      hora=$(bc -l <<< "scale=00;$agoraDiff/60/60")
      minuto=$(bc -l <<< "scale=00;$agoraDiff%3600/60")
      segundo=$(bc -l <<< "scale=00;$agoraDiff%3600%60")

      echo "$(printf "%02d\n" $hora):$(printf "%02d\n" $minuto):$(printf "%02d\n" $segundo) "
      echo " Digite (Esc)Pausar, (Enter)Escrever, (c)Capitulo, (.)Foto, (=)FIM [${fileName}]: "
      read -s -n1 keypressed
      startTimer="$(date +%s)"
      case "$keypressed" in
      $'\e')
          case "$fileType" in
            '')
              kill "${pidMidia}"
              read -p "PAUSA ${pidMidia}, digite qq tecla para voltar: "
              arecord -f S16_LE >> "$baseDir"/"${fileName}".wav &
            ;;
            'video')
              send_command "pause" "true"
              read -p "PAUSA ${pidMidia}, digite qq tecla para voltar: "
              send_command "pause" "false"
            ;;
          esac
          pidMidia=$(pgrep -f "arecord|mpv" | tail -n 1)
          endTimer="$(date +"%s")"
          pauseTimer=$(bc -l <<< "$pauseTimer + $endTimer - $startTimer" )
          ;;
      '=') end=0
          ;;
      'c')
          read -p "Chapter: " capitulo
          endTimer="$(date +%s)"
          diffTimer=$( bc -l <<< "$endTimer - $startTimer" )
          tempoInicio=$(bc -l <<< "scale=00;($startTimer - $inicio - $pauseTimer)*1000")
          tempoFim=$(bc -l <<< "scale=00;($diffTimer+$tempoInicio)*1000")
          horaInicio=$(bc -l <<< "scale=00;$tempoInicio/1000/60/60")
          minutoInicio=$(bc -l <<< "scale=00;($tempoInicio/1000)%3600/60")
          segundoInicio=$(bc -l <<< "scale=00;($tempoInicio/1000)%3600%60")
          echo '[CHAPTER]
TIMEBASE=1/1000
START='$tempoInicio'
END='$tempoFim'
title='$capitulo'' >> "$baseDir"/${fileName}.metadata
          echo "$horaInicio:$minutoInicio:$segundoInicio|$capitulo|" >> "$baseDir"/"$fileName.nodes"
          ;;
      '.')
          echo "Tirando foto"
          ((counter++))
          read -p "Legenda da foto: " linha
          endTimer="$(date +%s)"
          diffTimer=$( bc -l <<< "$endTimer - $startTimer" )
          tempoInicio=$(bc -l <<< "scale=00;$startTimer - $inicio - $pauseTimer")
          horaInicio=$(bc -l <<< "scale=00;$tempoInicio/60/60")
          minutoInicio=$(bc -l <<< "scale=00;$tempoInicio%3600/60")
          segundoInicio=$(bc -l <<< "scale=00;$tempoInicio%3600%60")
          horaFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)/60/60")
          minutoFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)%3600/60")
          segundoFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)%3600%60")
          echo ''$counter'
'$horaInicio':'$minutoInicio':'$segundoInicio',000 --> '$horaFim':'$minutoFim':'$segundoFim',000
'`echo "FOTO $linha" | sed -E 's/(.{30})/\1\n/g' `'

' >> "$baseDir"/"$fileName".srt
          echo "$horaInicio:$minutoInicio:$segundoInicio|$capitulo|{{foto}{$fileName-$horaInicio_$minutoInicio_$segundoInicio}}$linha" >> "$baseDir"/"$fileName".nodes
          ffmpeg -f video4linux2 -s "1280x960" -i /dev/video0 -ss 0:0:2 -y -hide_banner -loglevel quiet -frames 1 "$baseDir"/"$fileName-$horaInicio_$minutoInicio_$segundoInicio".jpg
          ;;
      $'\0A')
          ((counter++))
          read -p "Texto: " linha
          endTimer="$(date +%s)"
          diffTimer=$( bc -l <<< "$endTimer - $startTimer" )
          tempoInicio=$(bc -l <<< "scale=00;$startTimer - $inicio - $pauseTimer")
          horaInicio=$(bc -l <<< "scale=00;$tempoInicio/60/60")
          minutoInicio=$(bc -l <<< "scale=00;$tempoInicio%3600/60")
          segundoInicio=$(bc -l <<< "scale=00;$tempoInicio%3600%60")
          horaFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)/60/60")
          minutoFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)%3600/60")
          segundoFim=$(bc -l <<< "scale=00;($tempoInicio+$diffTimer)%3600%60")
          echo ''$counter'
'$horaInicio':'$minutoInicio':'$segundoInicio',000 --> '$horaFim':'$minutoFim':'$segundoFim',000
'`echo "$linha" | sed -E 's/(.{30})/\1\n/g' `'

' >> "$baseDir"/"$fileName".srt
          echo "$horaInicio:$minutoInicio:$segundoInicio|$capitulo|$linha" >> "$baseDir"/"$fileName".nodes
          ;;
      esac
  done
}

send_command() {
    echo '{"command": ["set_property", "'$1'", '$2']}' | /usr/bin/socat - "$SOCKET"
}

select_file(){
  statusOpcao=0
  opcao="$1"
  while [ ! -f "${opcao}" ]; do
      opcao=$(zenity --file-selection --title="Select a file")
      statusOpcao=$?
      if [ "$statusOpcao" -eq 1 ]; then
          exit 1
      fi
  done
  file="$opcao"
  dirName=$(dirname "$opcao")
  baseDir="$dirName"
  fileName="$(basename "$opcao")"
  fileExt="$(echo "$fileName" | rev | cut -d '.' -f1 | rev | tr '[:upper:]' '[:lower:]')"
  fileBaseName=$( basename "$fileName" .$fileExt )
}

create_initial_files(){
  echo ';FFMETADATA1
title='$fileBaseName'
artist='$USER'' > "$baseDir"/${fileBaseName}.metadata
    echo -n '' > "$baseDir"/${fileBaseName}.nodes
    echo -n '' > "$baseDir"/${fileBaseName}.srt
}

# Function to get current playback time in seconds (as an integer)
get_playback_time() {
    local playback_time=$(echo '{"command": ["get_property", "time-pos"]}' | socat - "$SOCKET" | jq -r '.data')
    # Convert to integer (truncate the decimal part)
    echo ${playback_time%.*}
}


# Function to handle screenshot
take_screenshot() {
    echo '{"command": ["screenshot", "video"]}' | socat - "$SOCKET"
}


counter=0
end=1


# Check for dependencies
check_dependencies

# Check if a file argument is provided
if [ $# -gt 0 ]; then
    file="$1"
    mime_type=$(file --mime-type -b "$file")

    if [[ $mime_type == audio/* ]]; then
        handle_media_type "audio"
    elif [[ $mime_type == video/* ]]; then
        handle_media_type "video"
    else
        selected_option=$(prompt_for_media_type)
        handle_media_type "$selected_option"
    fi
else
    selected_option=$(prompt_for_media_type)
    handle_media_type "$selected_option"
fi


trap "kill -- -$$" EXIT
