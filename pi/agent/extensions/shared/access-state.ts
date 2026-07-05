export type AccessMode = "readonly" | "write";

const ACCESS_MODES: AccessMode[] = ["readonly", "write"];

export function parseAccessMode(input: string | undefined): AccessMode | undefined {
  if (!input) {
    return undefined;
  }
  const value = input.trim().toLowerCase();
  return ACCESS_MODES.find((mode) => mode === value);
}

let accessMode: AccessMode = parseAccessMode(process.env.PI_SPAWN_ACCESS_MODE) ?? "readonly";

export function getAccessMode(): AccessMode {
  return accessMode;
}

export function setAccessMode(mode: AccessMode): void {
  accessMode = mode;
}
