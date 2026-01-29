# $pdf_mode = 4; # sets lualatex to default engine.
$pdf_mode = 1; # sets pdflatex to default engine.
# $pdf_mode = 5; # sets xelatex to default engine.
$dvi_mode = 0;
$postscript_mode = 0;

$pdf_previewer = 'open -a Skim';
$pdflatex = 'pdflatex -synctex=1 %O %S';
$lualatex = 'lualatex -synctex=1 %O %S';
$xelatex = 'xelatex -synctex=1 %O %S';

$out_dir = './.latexmk/out';
$aux_dir = './.latexmk/aux';
