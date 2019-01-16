target=$(cd $NOTES_LOCATIONS; find . | fzf --preview="if [[ -f {} ]]; then cat {}; elif [[ -n {} ]]; then tree -C {}; fi" --preview-window=right:60%:wrap --reverse)
if [[ "$target" != '' ]]; then
target="$NOTES_LOCATIONS/${target:2}"
if [[ -f "$target" ]]; then
  #### TODO : currently preview shows the local lines around the line you are looking at. would like to highlight the actual line, and open at that line if I select it
  search=$(cat -n "$target" | fzf --preview="val=\$(echo {} | sed -e 's/^[[:space:]]*//' | tr -s ' ' | cut -f1 -d$'\t'); if [[ \$val -le 8 ]]; then val=8; fi; cat -n $target | sed -n \$((\$val-7)),\$((\$val+7))p")
  #echo $(cut -d' ' -f1 <<< $(echo "$search"))

  vim "$target"
  #nf ### uncomment this to cycle if you are still in the notes
elif [[ -n "$target" ]]; then
  if [[ "$target" != '.' ]]; then
	cd "$target"
  else
	cd "$NOTES_LOCATIONS"
  fi
fi
fi

