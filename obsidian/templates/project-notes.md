<%*
// Startup template: commands render nothing into the active note.
const plugin = app.plugins.plugins["templater-obsidian"];
const { TFile, TFolder, Notice } = tp.obsidian;
const pending = new Map();

async function getToday(target) {
  const date = tp.date.now("YYYY-MM-DD");
  const path = `${target}/${date}.md`;
  const existing = app.vault.getAbstractFileByPath(path);
  if (existing) {
    if (!(existing instanceof TFile)) throw new Error(`Not a note: ${path}`);
    return existing;
  }
  if (pending.has(path)) return pending.get(path);

  const creation = (async () => {
    let folder = app.vault.getAbstractFileByPath(target);
    if (!folder) folder = await app.vault.createFolder(target);
    if (!(folder instanceof TFolder)) throw new Error(`Not a folder: ${target}`);
    const previous = folder.children
      .filter(file => file instanceof TFile && file.extension === "md" &&
        /^\d{4}-\d{2}-\d{2}$/.test(file.basename) && file.basename < date)
      .sort((a, b) => b.basename.localeCompare(a.basename))[0];
    const body = previous
      ? (await app.vault.read(previous)).replace(/^---\r?\n[\s\S]*?\r?\n---(?:\r?\n)?/, "")
      : "";
    const frontmatter = `---\ntitle: ""\nsummary: ""\ndate: ${date}\ntags: []\naliases: []\n---\n`;
    return app.vault.create(path, frontmatter + body);
  })();
  pending.set(path, creation);
  try {
    return await creation;
  } finally {
    pending.delete(path);
  }
}

async function openProjectNote(kind, target, openInObsidian = true) {
  if (kind !== "todo" && kind !== "notes") throw new Error("Unknown project note kind");
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
      projects.map(folder => folder.name), projects, false, `Open project ${kind}`,
    );
    if (!project) return null;
    target = `${project.path}/${kind}`;
  }
  if (!new RegExp(`^projects/[^/]+/${kind}$`).test(target)) {
    throw new Error(`Invalid project note folder: ${target}`);
  }
  const project = app.vault.getAbstractFileByPath(target.slice(0, target.lastIndexOf("/")));
  if (!(project instanceof TFolder)) throw new Error(`Missing project: ${target}`);
  const file = await getToday(target);
  if (openInObsidian) await app.workspace.getLeaf(false).openFile(file);
  return file.path;
}

plugin.projectNotes = { open: openProjectNote };
plugin.register(() => { delete plugin.projectNotes; });
for (const kind of ["todo", "notes"]) {
  plugin.addCommand({
    id: `open-project-${kind}`,
    name: `Open project ${kind}`,
    callback: async () => {
      try {
        await openProjectNote(kind);
      } catch (error) {
        console.error(error);
        new Notice(`Project ${kind}: ${error.message}`);
      }
    },
  });
}
%>
