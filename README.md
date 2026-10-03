# DMC5 Ultrawide Fix (21:9 / 32:9) — versão atual do jogo

Remove as barras pretas laterais do **Devil May Cry 5** em monitores ultrawide
(3440x1440, 2560x1080, 3840x1600, 5120x1440...) e mantém a HUD dentro da tela.

Funciona no build atual da Steam (pós-patch de 22/11/2025, build 24901913), que
quebrou os patchers antigos de hex-edit ("Vergil Ultrawide Fix" e afins). Testado
no Linux (Steam + Proton GE) em 3440x1440. No Windows é só copiar os mesmos arquivos.

## Como funciona

O fix antigo trocava um float de aspect ratio dentro do `DevilMayCry5.exe`
(`6E 40 00 00 80 41 C3 F5 38` -> `... AC 41 ...` para 3440x1440). O patch de
novembro/2025 mudou o layout do executável e esse padrão sumiu, então o patcher
não acha mais o que trocar.

Em vez de editar o binário, este pacote usa o **REFramework** (build nightly,
universal para todos os jogos RE Engine), que faz o mesmo em runtime e já
sobrevive a updates:

- `Graphics_UltrawideFix=true` — força `via.SceneView.DisplayType` para o
  aspecto nativo da janela (21:9 / 32:9), removendo pillarbox.
- `Graphics_UltrawideFixVerticalFOV_V2=true` — mantém o FOV vertical igual ao de
  16:9 e expande o horizontal, em vez de cortar imagem.
- `Graphics_UltrawideConstrainUI=true` + `ConstrainChildUI` — reancora os
  elementos de `via.gui` no eixo menor (`FitSmallRatioAxis`, centro), para a
  barra de vida/estilo não sair da tela.
- `reframework/autorun/uiscale.lua` — UI Scaler de **plneappl** (MIT), opcional,
  para ajuste fino de escala/offset da HUD pelo menu do REFramework (tecla
  `Insert`).

## Instalação

### Linux (Steam / Proton)

```bash
git clone https://github.com/sidnei-almeida/dmc5-ultrawide-fix.git
cd dmc5-ultrawide-fix
./install.sh            # detecta a pasta do jogo sozinho
# ou: ./install.sh "/caminho/para/steamapps/common/Devil May Cry 5"
```

Depois, no Steam: **Devil May Cry 5 > Propriedades > Opções de inicialização**:

```
WINEDLLOVERRIDES="dinput8=n,b" %command%
```

Sem isso o Wine usa o `dinput8.dll` interno e o REFramework nunca carrega.

### Windows

Copie o conteúdo de `payload/` para a pasta do jogo (onde está `DevilMayCry5.exe`).

## Verificando

Ao abrir o jogo, o arquivo `re2_framework_log.txt` aparece na pasta do jogo.
Aperte `Insert` para abrir o menu do REFramework; em **Graphics > Ultrawide/FOV
Options** a opção *Ultrawide/FOV/Aspect Ratio Fix* deve estar marcada.

## Desinstalar

```bash
./uninstall.sh
```

## Créditos

- [praydog/REFramework](https://github.com/praydog/REFramework) — o framework
  que faz o trabalho pesado. Binário em `payload/dinput8.dll` é o nightly cujo
  commit está em `payload/reframework_revision.txt`.
- [plneappl/dmc5_ui_scaler](https://github.com/plneappl/dmc5_ui_scaler) — UI Scaler (MIT).

Este repositório só empacota, configura e testa; nenhum código dos projetos
acima foi modificado.
