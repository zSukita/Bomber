# Créditos e licenças de assets — Bombástico

As licenças são específicas de cada origem. A pasta `assets/legal/` não significa que tudo nela esteja em domínio público ou sob CC0. As associações entre arquivos renomeados e os pacotes originais abaixo refletem os créditos já mantidos pelo projeto; os arquivos originais dos pacotes e um manifesto de hashes não foram preservados, portanto a identificação arquivo a arquivo ainda precisa ser conferida antes da publicação.

## Assets usados pelo jogo

| Arquivos em uso | Origem registrada | Licença / condições |
|---|---|---|
| `assets/legal/characters/character_0.png` a `character_7.png`, `assets/legal/enemies/enemy_0.png` a `enemy_3.png`, `assets/legal/mounts/mount_green.png`, `mount_blue.png`, `mount_yellow.png`, `assets/legal/item_egg.png`, `assets/legal/items.png`, `assets/legal/puff.png`, `assets/legal/fonts/pixel_font.ttf`; músicas `music_lobby.ogg`, `music_battle_1.ogg`, `music_tension.ogg`; jingles `jingle_victory.wav`, `jingle_game_over.wav`, `jingle_stage_clear.wav` | Ninja Adventure Asset Pack, Pixel-boy e AAA — associação registrada pelo projeto | A página do pacote declara **CC0 1.0**. Atribuição não é exigida; o autor agradece um link. [Página oficial do pacote](https://pixel-boy.itch.io/ninja-adventure-asset-pack). A correspondência exata dos arquivos renomeados com o pacote precisa ser verificada no arquivo original. |
| `assets/legal/bomb.png` e parte de `assets/legal/tiles/tileset.png` (bomba, tijolos e destruição de tijolos) | Bomber Bots — Game Asset Pack (versão Free oficial), Yahallo Games | **Pacote gratuito oficial ("Name your own price" / Free Version)**. A licença autoriza expressamente o uso e modificação em projetos pessoais ou comerciais (*"Use and edit this asset in personal or commercial projects"*). A licença apenas proíbe revender, redistribuir ou reempacotar os arquivos brutos do asset isoladamente. [Licença e página do pacote](https://yahallogames.itch.io/bomber-bots-assetpack). |
| `assets/legal/explosion.png` | “Bomberman Explosion Effect”, Satik64 | **CC0**, conforme a página do OpenGameArt. A menção ao autor é opcional. [Página do asset](https://opengameart.org/content/bomberman-explosion-effect). |
| Partes de pedra de `assets/legal/tiles/tileset.png` | Kenney Sokoban, segundo o crédito anterior | A página do pacote declara **Creative Commons CC0**. [Página oficial do Sokoban](https://kenney.nl/assets/sokoban). O atlas combina tiles de mais de uma origem; a separação exata dos tiles deve ser confirmada no arquivo original. |
| `assets/legal/previews/stage_01.png` a `stage_12.png` | Pré-visualizações incluídas no projeto | Referenciadas pela campanha e pelo lobby. A origem/autoria independente não está registrada; não presumir CC0. |
| `assets/menu/background_arena.png`, `character_hero.png`, `logo_bombastico.png`, `avatar_robot.png`, `map_preview_1.png` e `icon.svg` | Origem não registrada nos arquivos do projeto | São usados pela interface/ícone. Autor, origem e licença não foram identificados; confirmar os direitos antes de publicar. |

Os efeitos sonoros de interface e jogabilidade são sintetizados em tempo de execução por `autoload/audio_manager.gd`; não são arquivos de terceiros.

## Assets presentes, mas sem referência no jogo

- `assets/lpc_characters/` e `assets/lpc_monsters/` não aparecem referenciados por cenas ou scripts atuais. Os respectivos `credits_*.txt` listam créditos LPC e opções de licença **OGA-BY 3.0, CC-BY-SA 3.0 e GPL 3.0** para diferentes componentes. Essas licenças têm condições de atribuição e, conforme a opção escolhida, compartilhamento pela mesma licença ou GPL; não são CC0. Os arquivos foram preservados e não foram integrados. Os três presets agora excluem os oito PNGs LPC sem uso; a etapa de exportação precisa confirmar essa exclusão nos pacotes regenerados.
- `assets/menu/character_crop.png`, `logo_crop.png` e `map_preview.png` não são referenciados pelas cenas/scripts atuais. A origem/licença também não está documentada. Os três presets agora os excluem; os pacotes regenerados precisam confirmar a exclusão.
- Também não são carregados pelo `AudioManager`: `music_adventure.ogg`, `music_battle_2.ogg`, `music_dungeon.ogg`, `music_victory_theme.ogg` e `jingle_victory_alt.wav`.

## Pendências de proveniência para publicação

1. Identificar e registrar a origem/licença dos cinco assets ativos em `assets/menu/`, do ícone e das prévias das fases.
2. Conferir os arquivos originais/manifests dos pacotes declarados e associar cada arquivo renomeado à origem correta.
3. Para publicação pública do repositório de código-fonte aberto, atentar à cláusula de não redistribuição dos arquivos brutos do pacote Bomber Bots Free (embora o uso no jogo final compilado seja 100% autorizado).
4. Conferir no pacote exportado se os assets LPC não usados são incluídos; se forem, filtrar a exportação ou resolver as licenças antes de distribuir.
