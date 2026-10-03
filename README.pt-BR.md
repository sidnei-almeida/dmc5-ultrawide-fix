<p align="center">
  <img src="assets/banner.jpg" alt="Devil May Cry 5 UltraWide Fix" width="100%">
</p>

<h1 align="center">Devil May Cry 5 UltraWide Fix</h1>

<p align="center">
  Remove as barras pretas em monitores 21:9 e 32:9 e mantém HUD, menus e fades das cutscenes no lugar certo.<br>
  Funciona no <strong>build atual da Steam</strong>, o mesmo que matou os patchers antigos de hex-edit.
</p>

<p align="center">
  <a href="LICENSE"><img alt="Licença: MIT" src="https://img.shields.io/badge/license-MIT-green.svg"></a>
  <img alt="Plataforma: Linux e Windows" src="https://img.shields.io/badge/platform-Linux%20%7C%20Windows-blue?logo=linux&logoColor=white">
  <a href="https://github.com/praydog/REFramework"><img alt="Baseado em REFramework" src="https://img.shields.io/badge/powered%20by-REFramework-orange"></a>
  <img alt="Build do jogo 24901913" src="https://img.shields.io/badge/game%20build-24901913%20(Nov%202025)-red">
  <a href="README.md"><img alt="English" src="https://img.shields.io/badge/README-English-success"></a>
</p>

---

## Sumário

- [Resumo](#resumo)
- [Screenshots](#screenshots)
- [Por que os fixes antigos pararam de funcionar](#por-que-os-fixes-antigos-pararam-de-funcionar)
- [Instalação](#instalação)
  - [Uma linha (Linux)](#uma-linha-linux)
  - [Opções do script](#opções-do-script)
  - [Instalação manual (Linux ou Windows)](#instalação-manual-linux-ou-windows)
  - [Opções de inicialização da Steam (Linux / Proton)](#opções-de-inicialização-da-steam-linux--proton)
- [Como verificar](#como-verificar)
- [Como funciona](#como-funciona)
- [Ajustes](#ajustes)
- [Testado em](#testado-em)
- [FAQ e problemas](#faq-e-problemas)
- [Desinstalar](#desinstalar)
- [Reporte seus resultados](#reporte-seus-resultados)
- [Créditos](#créditos)
- [Licença](#licença)

## Resumo

```bash
curl -fsSL https://raw.githubusercontent.com/sidnei-almeida/dmc5-ultrawide-fix/main/install.sh | bash
```

Feche a Steam antes, assim o script também configura a opção de inicialização. Depois é só abrir o jogo.
Sem hex edit, sem patch no binário: o executável do jogo não é tocado.

## Screenshots

Todas as capturas são do jogo em **3440x1440** no Linux (Steam, Proton GE).

| Tela de título | Menu principal |
|---|---|
| ![Tela de título nos 3440px inteiros, sem pillarbox](assets/title.jpg) | ![Menu principal, barra de seleção de ponta a ponta](assets/menu.jpg) |

| Cutscene em tempo real |
|---|
| ![Cutscene renderizada de borda a borda](assets/cutscene.jpg) |

Como fica o fix ultrawide do REFramework **sem** o script de HUD deste pacote (a moldura da barra de vida é escalada pela razão de largura e empurrada para fora da tela, no canto superior esquerdo):

![Moldura da HUD gigante e cortada antes do script](assets/hud-broken-before-script.jpg)

## Por que os fixes antigos pararam de funcionar

O clássico "Vergil Ultrawide Fix" e as receitas de HxD trocavam um float dentro do `DevilMayCry5.exe`
(`6E 40 00 00 80 41 C3 F5 38` para `... AC 41 ...` em 3440x1440). O update da Steam de
**22 de novembro de 2025** (build 24901913) mudou o layout do executável e esse padrão de bytes
não existe mais, então os patchers não acham o que trocar:

```
$ grep -c "6E40000080 41C3F538" DevilMayCry5.exe   # (como bytes)
0
```

Este pacote faz o mesmo trabalho em tempo de execução via [REFramework](https://github.com/praydog/REFramework),
que se engancha na própria RE Engine e sobrevive a updates do jogo.

## Instalação

### Uma linha (Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/sidnei-almeida/dmc5-ultrawide-fix/main/install.sh | bash
```

O script:

1. encontra o jogo em todas as bibliotecas Steam da máquina (e também em prefixos do Heroic, Lutris e Bottles);
2. copia o `dinput8.dll` (REFramework), o `re2_fw_config.txt` pronto e os scripts Lua para a pasta do jogo, fazendo backup de qualquer `dinput8.dll` que já exista;
3. adiciona `WINEDLLOVERRIDES="dinput8=n,b"` às opções de inicialização do jogo no seu perfil da Steam, **se a Steam estiver fechada** (caso contrário imprime a linha para colar).

Ou clone o repositório e rode `./install.sh`.

### Opções do script

```
./install.sh [--path <pasta do jogo>]... [--uninstall] [--dry-run] [--no-launch-options]

  --path DIR            Pasta que contém o DevilMayCry5.exe (pode repetir).
  --uninstall           Remove o fix e restaura um dinput8.dll de backup.
  --dry-run             Mostra o que seria feito sem alterar nada.
  --no-launch-options   Não mexe nas opções de inicialização da Steam.
```

### Instalação manual (Linux ou Windows)

Copie tudo que está em [`payload/`](payload) para a pasta onde fica o `DevilMayCry5.exe`:

```
Devil May Cry 5/
├── DevilMayCry5.exe
├── dinput8.dll                      ← REFramework (nightly, build universal)
├── re2_fw_config.txt                ← opções de ultrawide já ativadas
├── reframework_revision.txt
└── reframework/
    ├── autorun/
    │   ├── dmc5_uw_hud.lua          ← mantém HUD/menus dentro da tela
    │   └── uiscale.lua              ← UI scaler manual, opcional (desligado)
    └── data/
        ├── dmc5_uw_hud.json
        └── uiscale.json
```

No Windows é só isso. No Linux, configure também a opção de inicialização abaixo.

### Opções de inicialização da Steam (Linux / Proton)

O Wine tem o próprio `dinput8.dll`, então o Proton precisa ser instruído a preferir o da pasta do jogo:

```
WINEDLLOVERRIDES="dinput8=n,b" %command%
```

Steam → Devil May Cry 5 → Propriedades → Opções de inicialização. Se você já usa o `dxgi.dll` do
ReShade, combine: `WINEDLLOVERRIDES="dinput8,dxgi=n,b" %command%`.

## Como verificar

- O `re2_framework_log.txt` aparece na pasta do jogo na primeira abertura e contém `Game name: dmc5`.
- Aperte **Insert** no jogo: o menu do REFramework abre. Em **Graphics → Ultrawide/FOV Options**,
  *Ultrawide/FOV/Aspect Ratio Fix* está marcado.
- A tela de título preenche o monitor: zero colunas pretas nas bordas esquerda e direita.

## Como funciona

Três peças, todas em tempo de execução, nada gravado no executável:

1. **O Ultrawide fix do REFramework** (`Graphics_UltrawideFix=true`) define o `DisplayType` da
   scene view para o aspecto real do monitor (`Uniform21x9`, `Uniform32x9`, ...) em vez do pillarbox
   16:9, e com `UltrawideFixVerticalFOV_V2=true` mantém o FOV vertical igual ao de 16:9 e abre só o
   horizontal, então nada é cortado.

2. **`dmc5_uw_hud.lua`** engancha em `re.on_pre_gui_draw_element` e, para cada `via.gui.View` que
   não seja um overlay de tela cheia, força `ResolutionAdjust = true`, `ResAdjustScale = FitSmallRatioAxis`
   e `ResAdjustAnchor = CenterCenter`. O DMC5 desenha HUD e menus com views do tipo **World**, que a
   opção *Constrain UI* do próprio REFramework pula de propósito (ela só mexe em views *Screen*); por
   isso a opção de fábrica deixa a barra de vida fora da tela.

3. **Fades e overlays de cutscene ficam intactos.** `Fade_InGame`, `Fade_Menu`, `Fade_Loading`,
   `ClipPlayGUI` e companhia são quads 1920x1080 com `ResolutionAdjust = false` e escala `Stretch`.
   Forçar um modo "fit" neles (o que o *Constrain UI* faz) estaciona o quad sobre a metade de cima da
   tela, e isso aparece como um retângulo escuro em toda transição de cutscene. Por isso a config
   mantém `Graphics_UltrawideConstrainUI=false` e o script ignora esses nomes.

Tudo que o script faz foi derivado de logar o `ViewType`, `ResolutionAdjust`, `ResAdjustScale` e
`ResAdjustAnchor` originais de cada elemento de GUI numa abertura limpa; ative *Log GUI elements* no
menu do script para ver os mesmos dados no `re2_framework_log.txt`.

## Ajustes

Aperte **Insert** no jogo.

- **Graphics → Ultrawide/FOV Options**: multiplicador de FOV, modo de FOV vertical, modo letterbox 16:10.
- **DMC5 Ultrawide HUD**: liga/desliga a reancoragem da HUD, ativa o log de elementos.
- **UI Scale**: o [UI Scaler do plneappl](https://github.com/plneappl/dmc5_ui_scaler), que vem
  desligado. Desmarque *disable* se preferir posicionar os elementos da HUD na mão (escala x/y e
  offsets, com valores separados para telas de loading). As configurações ficam em `reframework/data/uiscale.json`.

## Testado em

| | |
|---|---|
| Resolução | 3440x1440 (21:9) |
| Build do jogo | Steam 24901913, update de 22/11/2025 |
| SO | Arch Linux (Omarchy), Hyprland |
| Proton | GE-Proton 11-7 |
| REFramework | nightly `d1461375` (ver `payload/reframework_revision.txt`) |
| Conferido | título, menu principal, pausa/opções, cutscenes, fades, gameplay de missão |

32:9 e 3840x1600 passam pelos mesmos caminhos de código no REFramework (`Uniform32x9`,
`Uniform21x9`), mas não foram testados aqui. Por favor [reporte](#reporte-seus-resultados).

## FAQ e problemas

**Nenhum `re2_framework_log.txt` é criado.** O REFramework não carregou. No Linux, a opção de
inicialização está faltando ou a Steam estava aberta quando o instalador rodou; configure na mão.
Confira também se o `dinput8.dll` está ao lado do `DevilMayCry5.exe`, não em subpasta.

**O menu do REFramework não abre com Insert.** Alguns teclados/layouts mapeiam a tecla em outro
lugar; dá para trocar no `re2_fw_config.txt` (`REFrameworkConfig_MenuKey_V2`).

**Um retângulo escuro cobre a metade de cima da tela quando uma cutscene começa.** O *Ultrawide:
Constrain UI to 16:9* foi ativado (vem desligado na config). Desmarque em Graphics → Ultrawide/FOV
Options e **reinicie o jogo**: as configurações de resolution-adjust ficam gravadas nos objetos de GUI
até o processo fechar, então um *Reset scripts* não basta.

**Uso ReShade / Fluffy Mod Manager.** O `dxgi.dll` do ReShade convive bem; adicione `dxgi` à lista
de override como mostrado acima. Mods .pak do Fluffy não interagem com este fix.

**Um update do jogo vai quebrar?** O binário nightly do REFramework é universal e detecta o jogo em
tempo de execução. Se um update futuro mudar o type database, pode precisar de um nightly mais novo;
basta jogar o novo `dinput8.dll` dos [releases do REFramework-nightly](https://github.com/praydog/REFramework-nightly/releases)
por cima do antigo, o resto continua igual.

**Funciona no Windows?** Sim: mesmos arquivos, sem opção de inicialização. Não foi testado aqui.

## Desinstalar

```bash
./install.sh --uninstall
```

Remove a DLL, a config, os scripts e a opção de inicialização, e restaura o `dinput8.dll.bak` se
houver. Manual: apague `dinput8.dll`, `re2_fw_config.txt`, `re2_framework_log.txt` e a pasta
`reframework/`.

## Reporte seus resultados

Abra uma issue com o [template de resultados](.github/ISSUE_TEMPLATE/results.md): resolução, SO,
versão do Proton, o que funciona e um print do que não funciona.

## Créditos

- [praydog/REFramework](https://github.com/praydog/REFramework) (MIT): o mod loader e a
  implementação de ultrawide/FOV. O `payload/dinput8.dll` é um nightly sem modificações.
- [plneappl/dmc5_ui_scaler](https://github.com/plneappl/dmc5_ui_scaler) (MIT): o script opcional
  de UI Scaler.
- As comunidades PCGamingWiki e WSGF por documentarem o fix original de hex-edit.

## Licença

O instalador, o script de HUD e a documentação são MIT, veja [LICENSE](LICENSE). REFramework e o
UI Scaler mantêm as próprias licenças MIT (`payload/reframework/autorun/LICENSE-uiscale.txt`).
