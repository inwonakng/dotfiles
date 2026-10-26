<%*
// Startup template: commands render nothing into the active note.
const plugin = app.plugins.plugins["templater-obsidian"];
const { TFile, TFolder, Notice } = tp.obsidian;
const pending = new Map();

async function getToday(target) {
  const date = tp.date.now("YYYY-MM-DD");
  const path = `${target}/${date}.md`;
  if (pending.has(path)) return pending.get(path);
  const existing = app.vault.getAbstractFileByPath(path);
  if (existing) {
    if (!(existing instanceof TFile)) throw new Error(`Not a note: ${path}`);
    return existing;
  }

  const creation = (async () => {
    let folder = app.vault.getAbstractFileByPath(target);
    if (!folder) folder = await app.vault.createFolder(target);
    if (!(folder instanceof TFolder)) throw new Error(`Not a folder: ${target}`);
    const template = app.vault.getAbstractFileByPath(`${plugin.settings.templates_folder}/project-daily.md`);
    if (!(template instanceof TFile)) throw new Error("Missing project-daily.md template; run the Obsidian setup script");
    return tp.file.create_new(template, date, false, folder);
  })();
  pending.set(path, creation);
  try {
    return await creation;
  } finally {
    pending.delete(path);
  }
}

async function openProjectDaily(target, openInObsidian = true) {
  if (target === undefined) {
    const root = app.vault.getAbstractFileByPath("projects");
    const projects = root instanceof TFolder
      ? root.children.filter(folder => folder instanceof TFolder)
          .sort((a, b) => a.name.localeCompare(b.name))
      : [];
    if (!projects.length) {
      new Notice("Create a project folder under projects/ first.");
      return null;
    }
    const project = await tp.system.suggester(
      projects.map(folder => folder.name), projects, false, "Open project daily",
    );
    if (!project) return null;
    target = project.path;
  }
  if (typeof target !== "string" || !/^projects\/[^/]+$/.test(target) || [".", ".."].includes(target.split("/")[1])) {
    throw new Error(`Invalid project note folder: ${target}`);
  }
  const project = app.vault.getAbstractFileByPath(target);
  if (!(project instanceof TFolder)) throw new Error(`Missing project: ${target}`);
  const file = await getToday(`${target}/daily`);
  if (!(file instanceof TFile)) throw new Error(`Could not create project daily: ${target}`);
  if (openInObsidian) await app.workspace.getLeaf(false).openFile(file);
  return file.path;
}

plugin.projectNotes = { open: openProjectDaily };
plugin.register(() => { delete plugin.projectNotes; });
plugin.addCommand({
  id: "open-project-daily",
  name: "Open project daily",
  callback: async () => {
    try {
      await openProjectDaily();
    } catch (error) {
      console.error(error);
      new Notice(`Project daily: ${error.message}`);
    }
  },
});
%>
