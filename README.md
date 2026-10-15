# Bombástico

Jogo multiplayer de arena feito em Godot 4.7. O projeto inclui lobby, partidas para até quatro jogadores e um servidor dedicado Linux.

## Abrir e jogar

1. Abra `project.godot` no Godot 4.7.
2. Execute o projeto para abrir o lobby.
3. Para hospedar, escolha um nome e clique em **Criar sala**. Para entrar, informe o IP e a porta do host (8910 por padrão).
4. Libere a porta **UDP 8910** no firewall e, para partidas pela internet, encaminhe essa porta no roteador do host.

### Campanha

No menu, escolha **Iniciar Campanha**. Derrote os inimigos antes do cronômetro de 3 minutos acabar. Você começa com cinco vidas; o coração absorve um golpe. A campanha mistura rondadores, caçadores, inimigos que anunciam uma investida e chefes que também usam investidas nas fases 5, 10 e 12. Os inimigos tentam sair das linhas de explosão. Cada campanha gera uma variação nova dos mapas; revisitar uma fase mantém o layout daquela campanha. Os monstros surgem espalhados por caminhos conectados da arena, longe da posição inicial, e a quantidade cresce de quatro até nove ao longo das fases. Você recebe alguns segundos de proteção no início da fase para se afastar e colocar a primeira bomba. Um coração aparece garantidamente após quebrar oito blocos em cada fase, se nenhum coração já tiver surgido nela durante a campanha. Ao limpar uma fase, escolha o portal dourado para seguir para um mundo novo ou o azul para retornar a um mundo já visitado. Suas escolhas determinam o final. Use WASD ou as setas, ou o analógico esquerdo, para mover; use Espaço ou A para soltar bombas. No controle, START abre o menu de pausa.

## Servidor dedicado Linux

Exporte o preset **Linux Dedicated Server** pelo Godot. A saída esperada é `builds/server/Bombastico_Server.x86_64` e seu arquivo `.pck` correspondente. O preset está configurado para gerar os arquivos nessa pasta.

Para executar diretamente:

```sh
chmod +x builds/server/Bombastico_Server.x86_64
cd builds/server
./Bombastico_Server.x86_64 --headless --server --port=8910
```

O servidor começa a partida quando pelo menos dois jogadores estiverem conectados e todos estiverem prontos.

## Imagem Docker

Primeiro exporte o preset **Linux Dedicated Server** para criar `builds/server/`. Em seguida, na raiz do projeto:

```sh
docker build -t bombastico-server .
docker run --rm -p 8910:8910/udp bombastico-server
```

A imagem exige o executável exportado e o `.pck` na pasta `builds/server/`; a construção falha se o executável não estiver presente. A porta padrão é UDP 8910.

## Exportações

O arquivo `export_presets.cfg` define presets para Windows Desktop, Linux/X11 e Linux Dedicated Server. Os arquivos exportados vão para `builds/`, que não precisa ser incluída no controle de versão; gere-os novamente antes de executar os scripts de servidor ou construir a imagem Docker.

## Novas Mecânicas e Melhorias

- **Power-ups & Hazards:**
  - 🏹 **Bomba Perfurante (Pierce):** O fogo atravessa blocos maciços sem ser bloqueado no primeiro obstáculo.
  - 📡 **Detonador Remoto:** Permite plantar bombas com fusível estático e detoná-las quando desejar com outro toque no botão de bomba.
  - ☠️ **Maldição do Crânio:** Maldição temporária (lentidão extrema, diarreia contínua de bombas ou hiper-velocidade descontrolada) que se transmite ao tocar em outros jogadores.
  - 🧊 **Inércia do Gelo:** No mapa de Neve/Gelo, os jogadores deslizam suavemente por inércia ao mudar de direção.
- **Inteligência Artificial (BattleBot):**
  - Três níveis de dificuldade configuráveis: **Fácil**, **Médio** e **Difícil (Mestre)**.
  - Bots no modo difícil avaliam risco em tempo real, chutam bombas perigosas para longe e posicionam armadilhas mais agressivas.
- **Áudio Dinâmico & Juice:**
  - Trilhas musicais diferentes por arena e tema de vitória, com efeitos sonoros sintetizados durante o jogo.
  - Slow-motion cinematográfico no golpe decisivo de rodada ou perda de vida.
  - Estatísticas de partida enriquecidas com concessão de medalhas e títulos comemorativos ("Demolidor de Paredes", "Mestre da Pólvora", etc.).
- **Multiplayer & Rede:**
  - **UPnP Automático Assíncrono:** Abre portas UDP automaticamente no roteador do host via UPnP em background, facilitando partidas online sem necessidade de abrir portas manualmente no NAT.
  - **Client-Side Prediction:** Predição local imediata no cliente remoto com reconciliação autoritativa; correções do servidor podem ser percebidas conforme a latência da conexão.
- **Internacionalização & CI/CD:**
  - Suporte multilíngue com seletor em tempo real (**Português**, **Inglês** e **Espanhol**) em `assets/translations.csv`.
  - Workflow de CI/CD automatizado no GitHub Actions (`.github/workflows/build.yml`) para compilar executáveis de Windows Desktop, Linux e construir a imagem Docker.

## Estrutura do código

- Consulte [CREDITS.md](CREDITS.md) para a lista de assets em uso e suas fontes/licenças conhecidas. O pacote Bomber Bots utiliza a versão Free oficial do Yahallo Games (uso comercial e pessoal liberado no jogo). As artes do menu e as prévias da campanha foram geradas por IA pelo desenvolvedor, conforme informação do autor; a origem do `icon.svg` ainda precisa ser confirmada.
- `assets/lpc_characters/` e `assets/lpc_monsters/` contêm arte LPC não referenciada pelas cenas/scripts atuais. Seus créditos listam OGA-BY 3.0, CC-BY-SA 3.0 e GPL 3.0 para componentes diferentes; não são assets CC0. Os PNGs foram preservados no projeto e excluídos dos três presets de publicação; confirme a ausência nos pacotes gerados.

- `scripts/game.gd` conecta os sistemas e controla as transições entre lobby, partida e campanha.
- `scripts/bomb_system.gd` concentra colocação, explosões, coleta de itens e sincronização de bombas.
- `scripts/match_round_controller.gd` mantém o estado da rodada e usa `scripts/match_clock.gd` para o cronômetro.
- `scripts/player_spawner.gd` configura jogadores e conecta os sinais autoritativos.
- `scripts/grid_map.gd` representa a arena ativa; `scripts/arena_map_generator.gd` calcula o layout e `scripts/arena_map_styles.gd` guarda nomes, padrões e cores dos mapas. `scripts/arena_map_layout.gd` define o resultado tipado do gerador.
- `scripts/campaign_rules.gd` concentra balanceamento e rotas da campanha. `scripts/campaign_enemy_spawner.gd` escolhe posições alcançáveis para os inimigos.
- `scripts/campaign_enemy.gd` cuida do comportamento dos monstros; `scripts/campaign_enemy_appearance.gd` desenha os personagens.
- `autoload/` contém os serviços que precisam sobreviver à troca de cenas: rede, estado global e áudio.

Os dicionários enviados por RPC continuam sendo o formato de comunicação entre jogadores. Dentro da partida, jogadores, bombas e itens usam referências tipadas para reduzir erros de propriedade.
