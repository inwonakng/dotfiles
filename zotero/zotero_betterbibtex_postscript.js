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

