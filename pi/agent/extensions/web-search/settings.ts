export const WEB_PROVIDERS = ["exa", "parallel", "firecrawl", "keenable"] as const;
export type WebProvider = typeof WEB_PROVIDERS[number];

export function configuredProviders(settings: object): readonly WebProvider[] {
  const webSearch = "webSearch" in settings ? settings.webSearch : undefined;
  if (webSearch === undefined) return WEB_PROVIDERS;
  if (!webSearch || typeof webSearch !== "object" || Array.isArray(webSearch)) {
    throw new Error("Invalid Pi settings: webSearch must be an object");
  }
  for (const key of Object.keys(webSearch)) {
    if (key !== "providers") throw new Error(`Invalid Pi settings: unknown setting webSearch.${key}`);
  }
  const providers = (webSearch as { providers?: unknown }).providers;
  if (providers === undefined) return WEB_PROVIDERS;
  if (!Array.isArray(providers) || providers.length === 0) {
    throw new Error("Invalid Pi settings: webSearch.providers must be a non-empty list");
  }
  const result = providers.map((provider: unknown) => {
    const known = WEB_PROVIDERS.find(name => name === provider);
    if (!known) throw new Error(`Invalid Pi settings: webSearch.providers must contain only: ${WEB_PROVIDERS.join(", ")}`);
    return known;
  });
  if (new Set(result).size !== result.length) {
    throw new Error("Invalid Pi settings: webSearch.providers must not contain duplicates");
  }
  return result;
}
