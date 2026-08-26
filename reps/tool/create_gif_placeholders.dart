// Cria placeholders .gif vazios para cada slug em exercisesSeed.
// O ExerciseThumb detecta arquivos de tamanho zero e exibe um fallback
// colorido com inicial, deixando o app totalmente usavel sem GIFs reais.
//
// Substitua cada arquivo por um GIF real (<= 200kb) quando estiver pronto.
//
// Uso:
//   dart run tool/create_gif_placeholders.dart

import 'dart:io';

// ignore: avoid_relative_lib_imports
import '../lib/features/library/data/exercises_seed.dart';

void main() {
  final dir = Directory('assets/exercises');
  dir.createSync(recursive: true);

  var criados = 0;
  var pulados = 0;

  for (final e in exercisesSeed) {
    final f = File('${dir.path}/${e.slug}.gif');
    if (f.existsSync() && f.lengthSync() > 0) {
      pulados++;
      continue;
    }
    f.createSync();
    criados++;
  }

  stdout.writeln(
    'Placeholders processados: ${exercisesSeed.length}. '
    'Criados: $criados, pulados (ja com conteudo): $pulados.',
  );
}
