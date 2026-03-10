/**
 * 16 hand-picked DiceBear avatars.
 * ids 0-7  → "Glow" group (adventurer style, warm tones)
 * ids 8-15 → "Cool" group (adventurer-neutral style, cool tones)
 *
 * Users pick the avatar that feels like them - this IS their identity.
 */

export interface AvatarDef {
  id: number;
  seed: string;
  style: "adventurer" | "adventurer-neutral";
  bg: string;   // hex without #
}

const A = "adventurer" as const;
const B = "adventurer-neutral" as const;

export const AVATARS: AvatarDef[] = [
  { id: 0,  seed: "Lily",  style: A, bg: "ffd6e7" },
  { id: 1,  seed: "Mia",   style: A, bg: "f9c6d0" },
  { id: 2,  seed: "Zoe",   style: A, bg: "e8d5f5" },
  { id: 3,  seed: "Luna",  style: A, bg: "d5e8f5" },
  { id: 4,  seed: "Aria",  style: A, bg: "ffecd2" },
  { id: 5,  seed: "Nova",  style: A, bg: "d5f5e8" },
  { id: 6,  seed: "Bella", style: A, bg: "f5e6d5" },
  { id: 7,  seed: "Ruby",  style: A, bg: "fde68a" },
  { id: 8,  seed: "Leo",   style: B, bg: "c0d8f5" },
  { id: 9,  seed: "Max",   style: B, bg: "bbf7d0" },
  { id: 10, seed: "Kai",   style: B, bg: "bfdbfe" },
  { id: 11, seed: "Finn",  style: B, bg: "ddd6fe" },
  { id: 12, seed: "Axel",  style: B, bg: "a7f3d0" },
  { id: 13, seed: "Cruz",  style: B, bg: "fed7aa" },
  { id: 14, seed: "Rex",   style: B, bg: "fca5a5" },
  { id: 15, seed: "Orion", style: B, bg: "d1fae5" },
];

const BASE = "https://api.dicebear.com/7.x";

export function avatarUrl(idOrDef: number | string | AvatarDef | undefined | null, size = 80): string {
  let def: AvatarDef | undefined;
  if (typeof idOrDef === "object" && idOrDef !== null && "seed" in idOrDef) {
    def = idOrDef as AvatarDef;
  } else {
    const num = Number(idOrDef ?? 0);
    def = AVATARS.find((a) => a.id === num) ?? AVATARS[0];
  }
  return `${BASE}/${def.style}/svg?seed=${def.seed}&backgroundColor=${def.bg}&size=${size}`;
}

export function getAvatar(id: number | string | undefined | null): AvatarDef {
  const num = Number(id ?? 0);
  return AVATARS.find((a) => a.id === num) ?? AVATARS[0];
}
