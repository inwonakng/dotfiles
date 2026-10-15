/* global Zotero, Services, PathUtils, IOUtils, Components */
// Uses Zotero 10 reader internals. No eval, arbitrary file access, or library writes.
var bridge;

function install() {}
function uninstall() {}

async function startup() {
  await Zotero.initializationPromise;
  const dir = PathUtils.join(Services.dirsvc.get("Home", Components.interfaces.nsIFile).path, ".local", "state", "pi-zotero");
  await IOUtils.makeDirectory(dir, { permissions: 0o700, ignoreExisting: true });
  await IOUtils.setPermissions(dir, 0o700);
  const token = Array.from({ length: 2 }, () => Services.uuid.generateUUID().toString().replace(/[{}-]/g, "")).join("");
  const file = PathUtils.join(dir, "bridge.json");
  const port = Zotero.Prefs.get("httpServer.port");
  await IOUtils.writeUTF8(file, JSON.stringify({ version: 1, port, token }), { permissions: 0o600, tmpPath: `${file}.tmp` });
  await IOUtils.setPermissions(file, 0o600);
  bridge = { token, file, endpoints: new Map(), rendering: false };
  for (const [path, handler] of [["/pi-zotero/context", context], ["/pi-zotero/view", capture]]) {
    const endpoint = function () {};
    endpoint.prototype = {
      supportedMethods: ["POST"],
      supportedDataTypes: ["application/json"],
      allowRequestsFromUnsafeWebContent: false,
      async init(request) {
        // Server's connector headers bypass its web-content check, so enforce our own.
        if (request.headers.origin !== undefined || request.headers.authorization !== `Bearer ${token}`) {
          return reply(403, { error: "Forbidden" });
        }
        if (!bridge || bridge.token !== token) return reply(503, { error: "Bridge stopped" });
        try {
          return reply(200, await handler(request.data));
        } catch (error) {
          return reply(400, { error: String(error.message || error) });
        }
      },
    };
    Zotero.Server.Endpoints[path] = endpoint;
    bridge.endpoints.set(path, endpoint);
  }
}

async function shutdown() {
  const old = bridge;
  bridge = undefined;
  if (!old) return;
  for (const [path, endpoint] of old.endpoints) {
    if (Zotero.Server.Endpoints[path] === endpoint) delete Zotero.Server.Endpoints[path];
  }
  try {
    const stored = JSON.parse(await IOUtils.readUTF8(old.file));
    if (stored.token === old.token) await IOUtils.remove(old.file);
  } catch (error) {
    if (error.name !== "NotFoundError") Zotero.logError(error);
  }
}

function reply(status, data) {
  return [status, { "Content-Type": "application/json", "Cache-Control": "no-store" }, JSON.stringify(data)];
}

function object(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Expected an object");
  return value;
}

function active() {
  const win = Services.wm.getMostRecentWindow(null);
  const main = Zotero.getMainWindow();
  // All ReaderTabs share their main window; matching _window first picks an
  // arbitrary tab even when the library is selected.
  const reader = win === main
    ? (main?.Zotero_Tabs?.selectedType === "reader" ? Zotero.Reader.getByTabID(main.Zotero_Tabs.selectedID) : null)
    : Zotero.Reader._readers.find(reader => reader._window === win);
  if (win !== main && !reader) throw new Error("Focus a Zotero library or reader window, then retry");
  return { win, reader };
}

function library(id) {
  const lib = Zotero.Libraries.get(id);
  if (lib.libraryType === "user") return { localID: id, type: "user", id: 0 };
  if (lib.libraryType === "group") return { localID: id, type: "group", id: Zotero.Groups.getGroupIDFromLibraryID(id) };
  return { localID: id, type: lib.libraryType, id: null };
}

function itemData(item) {
  return {
    key: item.key,
    library: library(item.libraryID),
    title: item.getDisplayTitle(),
    itemType: Zotero.ItemTypes.getName(item.itemTypeID),
  };
}

function readerState(reader) {
  const internal = reader._internalReader;
  if (!internal) throw new Error("Reader is not ready");
  // Reading Mode overlays are not PDF renderers. Use the underlying last-used split.
  const view = internal._lastViewPrimary === false ? internal._secondaryView : internal._primaryView;
  const viewer = view?._iframeWindow?.PDFViewerApplication;
  const stats = internal._lastViewPrimary === false ? internal._state.secondaryViewStats : internal._state.primaryViewStats;
  const attachment = Zotero.Items.get(reader.itemID);
  const page = viewer?.pdfViewer?.currentPageNumber ?? (Number.isInteger(stats?.pageIndex) ? stats.pageIndex + 1 : null);
  // View stats can lag a page turn; never pair a fresh page with an old label.
  const pageLabel = page && typeof view?._getPageLabel === "function"
    ? view._getPageLabel(page - 1)
    : (stats?.pageIndex === page - 1 ? stats.pageLabel ?? null : null);
  return { internal, view, viewer, attachment, page, pageLabel };
}

function position(value) {
  if (!value || !Number.isInteger(value.pageIndex) || value.pageIndex < 0 || !Array.isArray(value.rects)) return null;
  // Copy out of the content compartment before invoking callbacks.
  const rects = Array.from(value.rects, rect => Array.isArray(rect) ? Array.from(rect) : [])
    .filter(rect => rect.length === 4 && rect.every(Number.isFinite));
  return rects.length ? { page: value.pageIndex + 1, rects } : null;
}

function readerSnapshot(reader, state) {
  const { internal, attachment, page, pageLabel } = state;
  const parent = attachment.parentItem || attachment;
  const lastView = internal._lastView;
  // Read current selection, never a cached popup that can survive a cleared selection.
  const ranges = Array.from(lastView?._selectionRanges || []).filter(range => !range.collapsed);
  const text = ranges.map(range => range.text || "").join("\n");
  const ids = new Set(Array.from(internal._state.selectedAnnotationIDs || []));
  const annotations = Array.from(internal._state.annotations || []).filter(annotation => ids.has(annotation.id));
  return {
    version: 1,
    capturedAt: new Date().toISOString(),
    source: "reader",
    item: itemData(parent),
    reader: { attachmentKey: attachment.key, type: reader.type, page, pageLabel, pageCount: state.viewer?.pdfDocument?.numPages ?? null },
    selection: {
      available: Array.isArray(lastView?._selectionRanges),
      text: text.slice(0, 16000),
      truncated: text.length > 16000,
      positions: ranges.map(range => position(range.position)).filter(Boolean).slice(0, 3),
      positionsTruncated: ranges.filter(range => position(range.position)).length > 3,
    },
    selectedAnnotations: annotations.slice(0, 5).map(annotation => ({
      key: annotation.id, type: annotation.type,
      text: (annotation.text || "").slice(0, 8000), comment: (annotation.comment || "").slice(0, 8000),
      textTruncated: (annotation.text || "").length > 8000, commentTruncated: (annotation.comment || "").length > 8000,
      position: position(annotation.position),
      nextPagePosition: position({ pageIndex: annotation.position?.pageIndex + 1, rects: annotation.position?.nextPageRects }),
    })),
    annotationsTruncated: annotations.length > 5,
  };
}

async function context(data) {
  if (Object.keys(object(data)).length) throw new Error("Context takes no arguments");
  const { win, reader } = active();
  if (reader) return readerSnapshot(reader, readerState(reader));
  const items = win.ZoteroPane.getSelectedItems();
  const collection = win.ZoteroPane.getSelectedCollection();
  return {
    version: 1, capturedAt: new Date().toISOString(), source: "library",
    items: items.slice(0, 5).map(itemData), itemsTruncated: items.length > 5,
    collection: collection ? { key: collection.key, name: collection.name, library: library(collection.libraryID) } : null,
  };
}

function bounding(rects) {
  return [Math.min(...rects.map(r => r[0])), Math.min(...rects.map(r => r[1])),
    Math.max(...rects.map(r => r[2])), Math.max(...rects.map(r => r[3]))];
}

async function capture(data) {
  object(data);
  if (Object.keys(data).some(key => !["attachmentKey", "libraryID", "target", "page", "rect", "annotationKey"].includes(key))) throw new Error("Unknown capture argument");
  if (!/^[A-Z0-9]{8}$/.test(data.attachmentKey || "")) throw new Error("attachmentKey from zotero_context is required");
  if (!Number.isInteger(data.libraryID) || data.libraryID < 1) throw new Error("libraryID from zotero_context item.library.localID is required");
  if (!["page", "selection", "annotation"].includes(data.target)) throw new Error("Invalid capture target");
  if (data.page !== undefined && (!Number.isInteger(data.page) || data.page < 1)) throw new Error("page must be a positive integer");
  if (data.target !== "page" && (data.page !== undefined || data.rect !== undefined)) throw new Error("page/rect only apply to target=page");
  if (data.target !== "annotation" && data.annotationKey !== undefined) throw new Error("annotationKey only applies to target=annotation");
  const { reader } = active();
  if (!reader || reader.type !== "pdf") throw new Error("Open the PDF in Zotero first");
  const state = readerState(reader);
  if (state.attachment.key !== data.attachmentKey || state.attachment.libraryID !== data.libraryID) throw new Error("Active paper changed; call zotero_context again");
  if (!state.viewer?.pdfDocument || !state.view?._pdfRenderer?.renderRegionCrops) throw new Error("PDF renderer unavailable; leave Reading Mode or wait for the PDF to load");
  const snapshot = readerSnapshot(reader, state);
  let regions;
  if (data.target === "selection") {
    if (snapshot.selection.positionsTruncated) throw new Error("Select text on at most three regions/pages per capture");
    regions = snapshot.selection.positions;
    if (!regions.length) throw new Error("No current PDF text selection");
  } else if (data.target === "annotation") {
    const annotation = snapshot.selectedAnnotations.find(annotation => annotation.key === data.annotationKey);
    if (!annotation?.position) throw new Error("Select that annotation in Zotero first");
    regions = [annotation.position, annotation.nextPagePosition].filter(Boolean);
  } else {
    const page = data.page ?? state.page;
    if (!Number.isInteger(page) || page < 1 || page > state.viewer.pdfDocument.numPages) throw new Error("Page is outside the PDF");
    const pdfPage = await state.viewer.pdfDocument.getPage(page);
    let rect = Array.from(pdfPage.view);
    if (data.rect !== undefined) {
      const r = data.rect;
      if (!Array.isArray(r) || r.length !== 4 || !r.every(Number.isFinite)
          || r[0] < 0 || r[1] < 0 || r[2] <= 0 || r[3] <= 0 || r[0] + r[2] > 1 || r[1] + r[3] > 1) {
        throw new Error("rect must be normalized top-left x,y,width,height inside the page");
      }
      const viewport = pdfPage.getViewport(Components.utils.cloneInto({ scale: 1 }, state.view._iframeWindow));
      const a = viewport.convertToPdfPoint(r[0] * viewport.width, r[1] * viewport.height);
      const b = viewport.convertToPdfPoint((r[0] + r[2]) * viewport.width, (r[1] + r[3]) * viewport.height);
      rect = [Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.max(a[0], b[0]), Math.max(a[1], b[1])];
    }
    regions = [{ page, rects: [rect] }];
  }
  const owner = bridge;
  if (!owner || owner.rendering) throw new Error("Another capture is in progress; retry after it finishes");
  owner.rendering = true;
  try {
    const images = [];
    let size = 0;
    for (const region of regions) {
      const rect = bounding(region.rects);
      const rects = Components.utils.cloneInto([rect], reader._iframeWindow);
      const [url] = await state.view._pdfRenderer.renderRegionCrops(region.page - 1, rects);
      if (!url?.startsWith("data:image/png;base64,")) throw new Error("PDF renderer returned no PNG");
      const png = url.slice("data:image/png;base64,".length);
      size += png.length;
      if (size > 16 * 1024 * 1024) throw new Error("Capture exceeds 12 MiB; request a smaller page region");
      images.push({ page: region.page, rect, mimeType: "image/png", data: png });
    }
    if (bridge !== owner) throw new Error("Bridge stopped during capture");
    return { version: 1, context: snapshot, target: data.target, crop: "PDF-coordinate bounding rectangles, not text-shaped masks; PDF content only, no overlay annotations", images };
  } finally {
    owner.rendering = false;
  }
}
