# Progresso do RepSound

> Marcador de onde o desenvolvimento parou. Atualizado em 28/11/2026.

## Estado geral

| Item | Status |
| --- | --- |
| Código | ✅ `dart analyze` sem erros |
| Testes | ✅ 57 testes passando (`flutter test`) |
| APK ARM64 | ✅ `build/app/outputs/flutter-apk/app-release.apk` (~21,7 MB) |
| README + licença | ✅ PolyForm Noncommercial 1.0.0 |
| Validação no aparelho | ⏳ Pendente — Galaxy M51 fora do `adb` |
| Screenshots | ⏳ Pendente — precisa do aparelho |
| GitHub (push + release) | ✅ <https://github.com/Adeniltonq/RepSound/releases/tag/v1.0.0> |

APK publicado: `RepSound-1.0.0-arm64.apk` (arm64-v8a, Android 7+).

## Etapas concluídas

- **Etapa 1 — fila por contexto**: `PlaybackQueue` + `QueueStore`; “Tocando de: …”;
  tocar a seguir, adicionar, remover, reordenar, limpar e restaurar; limite 20.000.
- **Etapa 2 — seleção múltipla**: toque longo ativa, contador, selecionar tudo,
  ações em lote (fila, a seguir, playlist, estilo, excluir com confirmação).
- **Etapa 3 — controles**: notificação/lock screen, botões de fone, mini player
  com anterior/play/próxima, swipe animado na capa, voltar reinicia após 3 s.
- **Etapa 4 — histórico**: reproduções, última reprodução, pulos, % média ouvida;
  tela de estatísticas em Ajustes e na reprodução.
- **Etapa 5 — recomendações**: Mix Favoritas e Descobertas com sorteio ponderado,
  limite de 2 faixas por artista e fallback para app novo.
- **Etapa 6 — estilos**: CRUD com nome/cor, precedência faixa > álbum/artista,
  aplicação em lote, playlists automáticas por estilo na Home.
- **Etapa 7 — Daily**: estilos escolhidos, auto 1×/dia + manual, liga/desliga,
  lista estável no dia e data/hora da geração.
- **Etapa 8 — barra inferior**: 5 abas reordenáveis, aba inicial, persistência,
  restaurar padrão; abrir pela notificação/mini player leva à reprodução.
- **Etapa 9 — letras**: `.lrc` sincronizado e `.txt`, painel integrado ao player.
- 15 idiomas no seletor de Ajustes; tema azul/preto/branco com dark padrão.

## Rodada 28/11/2026

- **Toque na capa**: esquerda retrocede, direita avança e o centro pausa/retoma.
  Passo configurável em Ajustes → Reprodução (5/10/15/30/60 s; padrão 10 s),
  com aviso animado (“+10 s” / “−10 s”) e vibração. Ligável/desligável.
- **Telas pequenas / DAPs**: layout compacto no player para **480×640**
  (capa, título, slider, controles e ações menores); em larguras < 340 dp a
  barra inferior fica só com ícones e os rótulos do player encurtam (EQ, Info).
- **Android 9 (API 28)**: `minSdk = 24` explícito, `WRITE_EXTERNAL_STORAGE`
  (≤ API 28) para exclusão via MediaStore e pedido de permissão de áudio +
  armazenamento em conjunto. `resizeableActivity` e `supports-screens`
  declaram suporte a telas pequenas.
- **Letras**: rolagem automática até a linha ativa (com fallback por estimativa
  quando a linha ainda não foi construída).

## Arquivos-chave

- `lib/ui/screens/now_playing_screen.dart` — swipe, toque para buscar, layout
  compacto, letras e estatísticas
- `lib/ui/sheets/lyrics_sheet.dart` — letras sincronizadas com auto-scroll
- `lib/state/settings_controller.dart` — `tapToSeek`, `seekStepSeconds`,
  ordem das abas, idioma e persistência
- `lib/ui/screens/settings_screen.dart` — atalhos, idioma e opções de reprodução
- `lib/ui/shell.dart` — barra inferior adaptativa
- `lib/state/library_controller.dart` — permissões Android 9/13+
- `android/app/src/main/AndroidManifest.xml` — permissões e telas pequenas
- `android/app/build.gradle.kts` — `minSdk 24`
- `lib/ui/screens/mix_screen.dart` — Mix Favoritas/Descobertas
- `lib/ui/screens/daily_screen.dart` — Daily + estilos + auto update
- `lib/ui/screens/styles_screen.dart` — CRUD e playlist por estilo
- `lib/ui/screens/listening_stats_screen.dart` — histórico/estatísticas
- `lib/ui/screens/customize_bar_screen.dart` — barra inferior
- `lib/ui/sheets/style_sheets.dart` — editor, aplicação em lote e playlist em lote
- `lib/ui/widgets/song_list_view.dart` — seleção múltipla + barra de ações
- `lib/ui/widgets/song_tile.dart` — estados de seleção nas 3 visualizações
- `lib/ui/widgets/mini_player.dart` — botão anterior

## Onde parou / o que falta

1. **Validar no aparelho** quando o Galaxy M51 voltar ao `adb`:
   ```bash
   adb devices
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```
   Testar: exclusão pelo MediaStore, notificação abrindo a reprodução, swipe e
   toque na capa, seleção múltipla em grade/compacta, Daily e letras `.lrc`.
2. **Testar em DAP Android 9 / 480×640** (ou emulador API 28 com 480×640):
   verificar se nada corta no player, Ajustes e barra inferior.
3. **Screenshots** para o README (Home, Reprodução, Seleção, Daily, Estatísticas).
4. Se o aparelho for reconectado, gerar e anexar capturas no release.

## Comandos úteis

```bash
flutter analyze          # ou: dart analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

Emulador de tela pequena (se o SDK tiver a imagem API 28):

```bash
avdmanager create avd -n dap28 -k "system-images;android-28;default;arm64-v8a"
emulator -avd dap28 -skin 480x640
```

Assinatura: `android/key.properties` + `android/app/repsound-release.jks`
(ambos fora do git). Token do GitHub **não** fica no repositório.

## Pendências conhecidas de UX (não bloqueiam)

- A barra de seleção usa ícones compactos; em telas muito estreitas ela rola
  horizontalmente (comportamento esperado).
- A Daily pode ser regenerada ao trocar estilos mesmo com auto-update desligado;
  é uma ação manual explícita.
