# /usr/bin/bash

for d in *; do
  # echo $d
  zip -r "${d}.zip" "$d"
done
