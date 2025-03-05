function isICLR(zotero) {
  const pattern = /International.*Conference.*on.*Learning.*Representations/i;
  return zotero.itemType === 'conferencePaper' && pattern.test(zotero.conferenceName);
}

function isArxiv(zotero) {
  // Zotero.debug(JSON.stringify(zotero))
  return (
    zotero.itemType === "preprint" 
    && zotero.number
    && zotero.number.toLowerCase().includes("arxiv")
  )
}

if (isICLR(zotero)) {
  if(zotero.url){
    tex.add({name: 'url', value: zotero.url})
  }
}

if (isArxiv(zotero)) {
  // if it's an arxive document, just re-build the whole thing. We want it to be an article type where the
  Zotero.debug('its arxiv')
  tex.entrytype = 'article'
  tex.add({name: 'journal', value: 'arXiv preprint ' + zotero.number})
  tex.remove("number")
  tex.remove("eprint")
  tex.remove("doi")
  tex.remove("publisher")
}
