/// 16 hand-picked DiceBear avatars - direct port from avatars.ts.
class AvatarDef {
  final int id;
  final String seed;
  final String style; // "adventurer" | "adventurer-neutral"
  final String bg; // hex without #

  const AvatarDef({
    required this.id,
    required this.seed,
    required this.style,
    required this.bg,
  });
}

const _a = 'adventurer';
const _b = 'adventurer-neutral';

const List<AvatarDef> avatars = [
  AvatarDef(id: 0, seed: 'Lily', style: _a, bg: 'ffd6e7'),
  AvatarDef(id: 1, seed: 'Mia', style: _a, bg: 'f9c6d0'),
  AvatarDef(id: 2, seed: 'Zoe', style: _a, bg: 'e8d5f5'),
  AvatarDef(id: 3, seed: 'Luna', style: _a, bg: 'd5e8f5'),
  AvatarDef(id: 4, seed: 'Aria', style: _a, bg: 'ffecd2'),
  AvatarDef(id: 5, seed: 'Nova', style: _a, bg: 'd5f5e8'),
  AvatarDef(id: 6, seed: 'Bella', style: _a, bg: 'f5e6d5'),
  AvatarDef(id: 7, seed: 'Ruby', style: _a, bg: 'fde68a'),
  AvatarDef(id: 8, seed: 'Leo', style: _b, bg: 'c0d8f5'),
  AvatarDef(id: 9, seed: 'Max', style: _b, bg: 'bbf7d0'),
  AvatarDef(id: 10, seed: 'Kai', style: _b, bg: 'bfdbfe'),
  AvatarDef(id: 11, seed: 'Finn', style: _b, bg: 'ddd6fe'),
  AvatarDef(id: 12, seed: 'Axel', style: _b, bg: 'a7f3d0'),
  AvatarDef(id: 13, seed: 'Cruz', style: _b, bg: 'fed7aa'),
  AvatarDef(id: 14, seed: 'Rex', style: _b, bg: 'fca5a5'),
  AvatarDef(id: 15, seed: 'Orion', style: _b, bg: 'd1fae5'),
];

const _base = 'https://api.dicebear.com/7.x';

/// Build a DiceBear avatar URL. Uses PNG format for simpler caching.
String avatarUrl(dynamic idOrDef, {int size = 80}) {
  AvatarDef def;
  if (idOrDef is AvatarDef) {
    def = idOrDef;
  } else {
    final num = idOrDef is int ? idOrDef : int.tryParse(idOrDef?.toString() ?? '') ?? 0;
    def = getAvatar(num);
  }
  return '$_base/${def.style}/png?seed=${def.seed}&backgroundColor=${def.bg}&size=$size';
}

/// Get an AvatarDef by id, falling back to avatars[0].
AvatarDef getAvatar(int id) {
  return avatars.where((a) => a.id == id).firstOrNull ?? avatars[0];
}
