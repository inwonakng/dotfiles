$pdf_mode = 4; # sets lualatex to default engine.
# $pdf_mode = 1; # sets pdflatex to default engine.
$pdf_previewer = 'open -a Skim';
$pdflatex = 'pdflatex -synctex=1 %O %S';
$lualatex = 'lualatex -synctex=1 %O %S';
