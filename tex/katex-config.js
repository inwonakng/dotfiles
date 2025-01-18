const alphabet = "abcdefghijklmnopqrstuvwxyz".split("");

let _macros = {
  "\\bm": "\\boldsymbol{#1}",
  "\\newterm": "{\\bf #1}",
  "\\eqref": "equation~\\ref{#1}",
  "\\Eqref": "Equation~\\ref{#1}",
  "\\ceil": "\\lceil #1 \\rceil",
  "\\floor": "\\lfloor #1 \\rfloor",
  "\\1": "\\bm{1}",
  "\\train": "\\mathcal{D}",
  "\\valid": "\\mathcal{D}_{\\mathrm{valid}}",
  "\\test": "\\mathcal{D}_{\\mathrm{test}}",
  "\\eps": "\\epsilon",
};

// random variables
_macros["\\reta"] = "{\\textnormal{$\\eta$}}";
alphabet.forEach((letter) => {
  // rm is already a command, just don't name any random variables m
  if (letter === "m") return;
  const macroKey = `\\r${letter}`;
  const macroValue = `{\\textnormal{${letter}}}`;
  _macros[macroKey] = macroValue;
});

// random vectors
_macros["\\rvepsilon"] = "{\\mathbf{\\epsilon}}";
_macros["\\rvtheta"] = "{\\mathbf{\\theta}}";
alphabet.forEach((letter) => {
  const macroKey = `\\rv${letter}`;
  const macroValue = `{\\mathbf{${letter}}}`;
  _macros[macroKey] = macroValue;
});

// elements of random vectors
alphabet.forEach((letter) => {
  const macroKey = `\\erv${letter}`;
  const macroValue = `{\\textnormal{${letter}}}`;
  _macros[macroKey] = macroValue;
});

// random matrices
alphabet.forEach((letter) => {
  const macroKey = `\\rm${letter.toUpperCase()}`;
  const macroValue = `{\\mathbf{${letter.toUpperCase()}}}`;
  _macros[macroKey] = macroValue;
});

// elements of random matrices
alphabet.forEach((letter) => {
  const macroKey = `\\erm${letter.toUpperCase()}`;
  const macroValue = `{\\textnormal{${letter.toUpperCase()}}}`;
  _macros[macroKey] = macroValue;
});

// vectors
_macros["\\vzero"] = "{\\bm{0}}";
_macros["\\vone"] = "{\\bm{1}}";
_macros["\\vmu"] = "{\\bm{\\mu}}";
_macros["\\vtheta"] = "{\\bm{\\theta}}";
alphabet.forEach((letter) => {
  const macroKey = `\\v${letter}`;
  const macroValue = `{\\bm{${letter}}}`;
  _macros[macroKey] = macroValue;
});

// elements of vectors
_macros["\\evalpha"] = "{\\alpha}";
_macros["\\evbeta"] = "{\\beta}";
_macros["\\evepsilon"] = "{\\epsilon}";
_macros["\\lambda"] = "{\\lambda}";
_macros["\\omega"] = "{\\omega}";
_macros["\\mu"] = "{\\mu}";
_macros["\\psi"] = "{\\psi}";
_macros["\\sigma"] = "{\\sigma}";
_macros["\\theta"] = "{\\theta}";
alphabet.forEach((letter) => {
  const macroKey = `\\ev${letter}`;
  const macroValue = letter;
  _macros[macroKey] = macroValue;
});

// matrices
_macros["\\mBeta"] = "{\\bm{\\beta}}";
_macros["\\mPhi"] = "{\\bm{\\Phi}}";
_macros["\\mLambda"] = "{\\bm{\\Lambda}}";
_macros["\\mSigma"] = "{\\bm{\\Sigma}}";
alphabet.forEach((letter) => {
  const macroKey = `\\m${letter.toUpperCase()}`;
  const macroValue = `{\\bm{${letter.toUpperCase()}}}`;
  _macros[macroKey] = macroValue;
});

// Tensors
_macros["\\mathsfit"] = "\\mathsf{#1}";
_macros["\\tens"] = "\\bm{\\mathsfit{#1}";
alphabet.forEach((letter) => {
  const macroKey = `\\t${letter.toUpperCase()}`;
  const macroValue = `{\\tens{${letter.toUpperCase()}}}`;
  _macros[macroKey] = macroValue;
});

// Graph
alphabet.forEach((letter) => {
  const macroKey = `\\g${letter.toUpperCase()}`;
  const macroValue = `{\\mathcal{${letter.toUpperCase()}}}`;
  _macros[macroKey] = macroValue;
});

// Sets
alphabet.forEach((letter) => {
  // Don't use a set called E, because this would be the same as our symbol for expectation.
  if (letter === "e") return;
  const macroKey = `\\s${letter.toUpperCase()}`;
  const macroValue = `{\\mathbb{${letter.toUpperCase()}}}`;
  _macros[macroKey] = macroValue;
});

// Entries of matrix
_macros["\\emLambda"] = "{\\Lambda}";
alphabet.forEach((letter) => {
  // Don't use a set called E, because this would be the same as our symbol for expectation.
  const macroKey = `\\em${letter.toUpperCase()}`;
  const macroValue = letter.toUpperCase();
  _macros[macroKey] = macroValue;
});

// Entries of tensor
_macros["\\etens"] = "{\\mathsfit{#1}}";
_macros["\\etLambda"] = "{\\etens{\\Lambda}}";
alphabet.forEach((letter) => {
  // Don't use a set called E, because this would be the same as our symbol for expectation.
  const macroKey = `\\et${letter.toUpperCase()}`;
  const macroValue = `{\\etens{${letter.toUpperCase()}}}`;
  _macros[macroKey] = macroValue;
});

// distribution stuff
_macros["\\pdata"] = "p_{\\rm{data}}"; // The true underlying data generating distribution
_macros["\\ptrain"] = "\\hat{p}_{\\rm{data}}"; // The empirical distribution defined by the training set
_macros["\\Ptrain"] = "\\hat{P}_{\\rm{data}}";
_macros["\\pmodel"] = "p_{\\rm{model}}"; // The model distribution
_macros["\\Pmodel"] = "P_{\\rm{model}}"; // The model distribution
_macros["\\ptildemodel"] = "\\tilde{p}_{\\rm{model}}"; // The model distribution
_macros["\\pencode"] = "p_{\\rm{encoder}}"; // Stochastic autoencoder distributions
_macros["\\pdecode"] = "p_{\\rm{decoder}}";
_macros["\\precons"] = "p_{\\rm{reconstruct}}";
_macros["\\laplace"] = "\\mathrm{Laplace}";

_macros["\\E"] = "\\mathbb{E}"; // Expectation
_macros["\\Ls"] = "\\mathcal{L}"; // Loss function
_macros["\\R"] = "\\mathbb{R}"; // Real numbers
_macros["\\emp"] = "\\tilde{p}"; // Empirical distribution
_macros["\\lr"] = "\\alpha";
_macros["\\reg"] = "\\lambda";
_macros["\\rect"] = "\\mathrm{rectifier}";
_macros["\\softmax"] = "\\mathrm{softmax}";
_macros["\\sigmoid"] = "\\sigma";
_macros["\\softplus"] = "\\zeta";
_macros["\\KL"] = "D_{\\mathrm{KL}";
_macros["\\Var"] = "\\mathrm{Var}";
_macros["\\standarderror"] = "\\mathrm{SE}";
_macros["\\Cov"] = "\\mathrm{Cov}";

_macros["\\normlzero"] = "L^0";
_macros["\\normlone"] = "L^1";
_macros["\\normltwo"] = "L^2";
_macros["\\normlp"] = "L^p";
_macros["\\normmax"] = "L^\\infty";

_macros["\\parents"] = "Pa";

_macros["\\argmax"] = "\\operatorname*{arg\\,max}";
_macros["\\argmin"] = "\\operatorname*{arg\\,min}";

_macros["\\sign"] = "\\operatorname{sign}";
_macros["\\Tr"] = "\\operatorname{Tr}";

export const macros = _macros;
