---
title: ""
summary: ""
date: <% tp.file.title %>
tags: []
aliases: []
---
<%*
const currentName = tp.file.title;
const folder = tp.file.folder(true);
const previous = app.vault
  .getMarkdownFiles()
  .filter(
    (file) =>
      file.parent?.path === folder &&
      file.basename < currentName &&
      /^\d{4}-\d{2}-\d{2}$/.test(file.basename),
  )
  .sort((a, b) => b.basename.localeCompare(a.basename))[0];

if (previous) {
  const content = await app.vault.cachedRead(previous);
  tR += content.replace(/^---\r?\n[\s\S]*?\r?\n---(?:\r?\n)?/, "");
}
-%>
