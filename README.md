# RepSound

Reprodutor de música **local** para Android, feito em Flutter. Rápido, minimalista e pensado para bibliotecas grandes. Sua música, do seu jeito — sem depender de internet.

Sem conta, sem login, sem anúncios. Tudo fica no aparelho — o backup é um arquivo JSON/CSV que você compartilha pelo menu do sistema (Drive, Nextcloud, Dropbox, e-mail…).

## Download

APK de release (Android 7.0+, **ARM64**):

[**RepSound 1.0.0 — arm64-v8a**](https://github.com/Adeniltonq/RepSound/releases/latest/download/RepSound-1.0.0-arm64.apk)

Instale com “instalar de fontes desconhecidas” permitido para o app de arquivos/navegador. O APK é assinado e preserva os dados em atualizações (`adb install -r` ou instalação por cima).

---

## Recursos

### Biblioteca
- Leitura da biblioteca pelo **MediaStore do Android**, com metadados, capas e caminhos dos arquivos de áudio.
- Índice persistido em `library_index.json`: abrir o app **não dispara uma nova varredura**.
- Varredura manual (pull-to-refresh, botão de atualizar ou Ajustes).
- Busca instantânea por **título, artista, álbum e pasta**, sem diferenciar acentos ou caixa, com *debounce* de 200 ms.
- Ordenação por título, artista, álbum, data de adição, duração, formato, qualidade, reproduções e pasta (asc/desc).
- Filtros por **formato**, **qualidade estimada** e **pasta**.
- Três visualizações: lista, grade (2–6 colunas) e compacta.
- Coleções automáticas: **Favoritos**, **Ouvidas recentemente**, **Mais ouvidas** e **Adicionadas recentemente**.
- Pastas com contagem de faixas na tela inicial.

### Reprodução
- `just_audio` + `just_audio_background`: reprodução em segundo plano, notificação com controles, tela de bloqueio e botões de fone.
- **Fila por contexto**: tocar uma faixa cria a fila a partir da lista clicada (biblioteca, pesquisa, álbum, playlist, estilo…). Um novo toque redefine o contexto; durante a busca, só os resultados entram na fila.
- “Tocando de: …” mostra a origem da fila. Adições manuais (**tocar a seguir** / **adicionar à fila**), remoção, reordenação, limpar (com confirmação em filas grandes) e **restaurar fila**.
- A fila sobrevive à troca de telas, ao fechamento do app e ao segundo plano; a restauração não inicia a reprodução sozinha. Limite de segurança em **20.000 faixas** (300 no modo econômico).
- Mini player com **voltar | play/pause | avançar**.
- **Swipe na capa** da tela de reprodução: esquerda → próxima, direita → anterior, com animação, limite e vibração. O botão “voltar” reinicia a faixa se ela já passou de 3 s.
- **Toque na capa**: esquerda retrocede, direita avança (5–60 s, padrão 10 s) e o centro pausa/retoma. Ligável em Ajustes → Reprodução, com aviso animado na tela.
- Notificação/lock screen com anterior, play/pause, próxima, progresso e botões de fone. Tocar na notificação abre a tela de reprodução.
- Aleatório e repetição (desligada / tudo / uma faixa).
- Timer para dormir (minutos ou fim da faixa).
- Perfis de qualidade: **Automática** (capas 320 px), **Alta fidelidade** (capas 512 px e mais pré-carregamento) e **Econômica** (capas 192 px, fila de 300 e efeitos desligados).
- Equalizador de **10 bandas** com presets (Plano, Graves, Voz, Rock, Pop, Eletrônico, Jazz, Clássico, Agudos) e curva personalizada, via `AndroidEqualizer`.
- Reforço de graves com `AndroidLoudnessEnhancer`.
- Estatísticas de reprodução por faixa, histórico e favoritos.

### Playlists
- Playlists personalizadas com **reordenação por arrastar**.
- Adição/remoção de faixas em lote com filtro de busca.
- Renomear e excluir.
- Favoritos e coleções sempre disponíveis, mesmo sem playlist criada.

### Seleção múltipla
- Toque longo em qualquer faixa ativa o modo de seleção; tocar marca/desmarca.
- Contador, **selecionar tudo**, cancelar e ações em lote: **adicionar à fila**, **tocar a seguir**, **adicionar à playlist**, **atribuir estilo** e **excluir**.
- A exclusão pede confirmação e usa o `MediaStore.createDeleteRequest` no Android 11+ (o sistema mostra a própria confirmação); em versões anteriores apaga direto. Erros/permissões aparecem em mensagem clara.
- Faixas excluídas são removidas do índice, favoritos, histórico, estatísticas e playlists.

### Recomendações, estilos e Daily
- **Recomendadas para você** na Home: **Mix Favoritas** (sorteio ponderado por favoritas, artistas, histórico e pulos) e **Descobertas** (~50% nunca ouvidas, ~30% de artistas favoritos, ~20% antigas aleatórias, com fallback para app novo).
- Máximo de 2 faixas seguidas do mesmo artista; listas diferentes a cada “atualizar”.
- Peso e proporções centralizados em constantes (`RecommendationService`).
- **Estilos** com nome e cor; vários por faixa, aplicáveis em **faixa, álbum ou artista** (o estilo próprio da faixa tem precedência). Aplicação em lote pela seleção.
- Cada estilo com faixas vira uma **playlist automática na Home**; estilos vazios não aparecem.
- **Daily**: usa apenas os estilos escolhidos, mistura favoritas + descobertas, atualiza automaticamente **1× por dia** (ligável/desligável) e também por botão. A lista gerada é salva e permanece estável durante o dia; data/hora da geração aparecem na tela.

### Histórico e letras
- Reproduções, última reprodução, pulos e **percentual médio ouvido** por faixa.
- Reprodução válida após ~30 s ou ~50% da faixa (o que for menor), usando a duração real.
- Tela **Estatísticas de escuta** com histórico recente, mais reproduzidas e mais puladas.
- Letras locais **`.lrc` sincronizado** ou **`.txt`** ao lado do arquivo de áudio, exibidas no próprio player com destaque da linha atual e rolagem automática.

### Barra inferior personalizável
- Reordene as 5 abas (**Início, Biblioteca, Navegar, Playlists, Ajustes**) por arrastar.
- Escolha a **aba inicial**; a ordem é persistida e entra no backup.
- Reordenar não muda o conteúdo de cada aba. Abrir pelo mini player ou pela notificação leva à reprodução.
- “Restaurar padrão” volta à ordem original.

### Aparência
- Tema **azul + preto + branco**, escuro por padrão (preto profundo para telas OLED).
- Modos escuro, claro e sistema.
- Cores de destaque alternativas.
- Interface em **pt-BR** por padrão e **15 idiomas** (pt, en, es, fr, de, it, ru, ja, ko, zh, ar, hi, id, tr, nl), minimalista, com cartões arredondados e transições suaves.
- Layout adaptativo: telas pequenas e DAPs (**480×640**), inclusive Android 9; em larguras muito estreitas a barra inferior fica só com ícones e o player usa controles compactos.
- Animações podem ser desligadas nos Ajustes (transições de tela instantâneas).

### Backup e privacidade
- Exportação do perfil em **JSON** (completo) ou **CSV** (planilhas).
- Importação com modo **mesclar** ou **substituir**.
- Backup automático local após alterações.
- Nenhum login, nenhuma conta, nenhuma telemetria.

---

## Carregamento sob demanda

O app evita manter a biblioteca inteira "inflada" na memória:

- O índice guarda apenas referências leves de `Song` (metadados e caminhos).
- As **capas** vivem em um cache LRU (`SongCardCache`) dimensionado em **4× a quantidade de itens visíveis** — com ~10 faixas na tela, no máximo ~40 fichas ficam em memória.
- A quantidade visível é medida de verdade pela viewport (`LayoutBuilder` + altura/largura reais), não estimada.
- Ao rolar, as fichas que saem da janela são descartadas e as novas entram.
- A fila é definida pelo contexto (biblioteca, pesquisa, álbum ou playlist) e pode ser editada, limpa ou restaurada, sobrevivendo ao fechamento do app.

---

## Arquitetura

```
lib/
├── main.dart                 # bootstrap: JustAudioBackground, controladores
├── app.dart                  # MultiProvider + MaterialApp + tela de falha
├── core/
│   ├── app_theme.dart        # tema claro/escuro, cores de destaque
│   └── utils.dart            # formatação, normalização de busca, debounce
├── data/
│   ├── models.dart           # Song, Playlist, enums e rótulos
│   ├── media_channel.dart    # ponte com o Kotlin (MethodChannel)
│   ├── index_store.dart      # library_index.json
│   ├── profile_store.dart    # profile.json
│   ├── playlist_controller.dart
│   ├── search_service.dart   # busca indexada e ordenada por relevância
│   ├── song_card_cache.dart  # LRU de capas (4× visível)
│   └── backup_service.dart   # exportação/importação JSON e CSV
├── player/
│   └── equalizer_presets.dart
├── state/
│   ├── library_controller.dart
│   ├── player_controller.dart
│   └── settings_controller.dart
└── ui/
    ├── shell.dart            # 5 abas + mini player
    ├── navigation.dart
    ├── screens/              # home, biblioteca, busca, playlists, ajustes,
    │                         # now playing, equalizador, coleções, detalhes
    ├── sheets/               # ações de faixa, fila, timer, info, playlists
    └── widgets/              # capa, tiles, mini player, lista com janela
```

### Ponte nativa (Android)

`android/app/src/main/kotlin/com/repsound/app/MainActivity.kt` expõe o canal `com.repsound/media`:

| Método | Retorno |
| --- | --- |
| `isSupported` | `true` no Android |
| `querySongs` | lista de mapas com metadados de todas as faixas |
| `queryArtwork` | bytes PNG da capa, ou `null` |

A leitura de metadados roda em um executor dedicado; o Flutter recebe só o necessário e pede capas uma a uma.

---

## Formatos suportados

Dependem do codec do aparelho (MediaStore + `just_audio`). Na prática:

- **Com perdas:** MP3, AAC/M4A, OGG/Opus, WMA (quando suportado)
- **Sem perdas:** FLAC, WAV, ALAC, AIFF, APE, DSF (quando suportado)

A **qualidade** exibida é estimada: formatos sem perdas são marcados como *Lossless*; os demais usam o bitrate aproximado (`tamanho × 8 ÷ duração`).

---

## Requisitos

- Flutter 3.47+ / Dart 3.13+
- Android SDK 36, AGP 9.x, JDK 17+ (o projeto usa Java 17 no Gradle)
- Android 7.0+ (API 24), incluindo **Android 9 (API 28)** de DAPs; layout adaptado a telas **480×640**.

---

## Como rodar

```bash
flutter pub get
flutter run
```

Gerar APK:

```bash
# Debug
flutter build apk --debug

# Release (usa android/key.properties + keystore própria, fora do git)
flutter build apk --release --target-platform android-arm64

# Dividido por ABI (menor)
flutter build apk --split-per-abi
```

O APK fica em `build/app/outputs/flutter-apk/`.

O `applicationId` Android é `com.repsound.app` (mesmo namespace Kotlin em `android/app/src/main/kotlin/com/repsound/app/`). O bundle id do iOS correspondente também é `com.repsound.app`.

### iOS

O projeto compila para iOS, mas a leitura local da biblioteca usa o MediaStore do Android. No iOS, `MediaChannel` trata `MissingPluginException` e o app assume que a biblioteca automática não está disponível.

---

## Permissões

| Permissão | Uso |
| --- | --- |
| `READ_MEDIA_AUDIO` (Android 13+) | ler arquivos de áudio |
| `READ_EXTERNAL_STORAGE` (≤ Android 12) | ler arquivos de áudio |
| `WRITE_EXTERNAL_STORAGE` (≤ Android 9) | excluir faixas pelo MediaStore |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | reprodução em segundo plano |
| `POST_NOTIFICATIONS` | controles na notificação |
| `WAKE_LOCK` | manter a reprodução estável com a tela apagada |

A permissão de notificações é solicitada após a primeira varredura bem-sucedida.

Se o acesso às músicas for negado permanentemente, a tela inicial e a biblioteca exibem o botão **Abrir ajustes**, que leva direto às permissões do app no sistema.

---

## Backup

O arquivo exportado contém:

- Playlists (nome, ordem e faixas)
- Favoritos
- Estatísticas: contagem de reproduções, últimas execuções e histórico
- Ajustes relevantes do perfil

O JSON é a referência; o CSV é uma visão achatada, útil em planilhas. Na importação, o app tenta casar as faixas por `id`, caminho e metadados; faixas não encontradas são contabilizadas no resultado.

Nada é enviado a servidores: a exportação usa o **share sheet** do sistema operacional.

---

## Testes

```bash
flutter test
```

Cobrem:

- `utils_test.dart` — normalização de busca, durações, contagens, bytes e nomes de arquivo
- `search_service_test.dart` — acentos, campos, múltiplos termos, relevância e limite
- `models_test.dart` — roundtrip JSON de `Song`/`Playlist`, estimativa de bitrate e qualidade, igualdade
- `equalizer_presets_test.dart` — integridade dos presets e interpolação logarítmica de ganhos
- `playback_queue_test.dart` — contexto, edições manuais, limpeza e restauração da fila
- `settings_test.dart` — qualidade, animações, persistência e ordem das abas

---

## Limitações conhecidas

- A biblioteca automática é Android-only.
- A qualidade é **estimada**; o MediaStore nem sempre informa bitrate real.
- O equalizador depende do hardware/sistema Android (`AndroidEqualizer`); em outros alvos as curvas ficam salvas, mas inativas.
- O APK publicado contém apenas `arm64-v8a` (Galaxy M51 e aparelhos equivalentes). Para outros ABIs, compile com `--split-per-abi`.

---

## Licença

Distribuído sob a **PolyForm Noncommercial License 1.0.0**. Uso permitido para fins
não comerciais, incluindo uso pessoal, estudo, hobby e organizações sem fins
lucrativos. Uso comercial não é permitido. O texto completo está em
[`LICENSE`](LICENSE) ou em
<https://polyformproject.org/licenses/noncommercial/1.0.0>.

`SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0`
