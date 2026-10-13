# WindFree — contexto do projeto

App de barra de menus do macOS (SwiftUI `MenuBarExtra`, macOS 13+, Swift Package sem Xcode project) que controla
um ar-condicionado Samsung WindFree pela API REST pública da SmartThings. Projeto pessoal.

## Como trabalhar aqui

- Converse com o dono em **português do Brasil**. Identificadores e comentários do código seguem como estão
  (identificadores em inglês, comentários em português).
- A interface é **bilíngue (português e inglês)**, escolhida em Configurações › Idioma (padrão: português; não
  segue o idioma do macOS). Todo texto visível — inclusive dicas (`.help`), acessibilidade e mensagens de erro —
  passa por `tr("português", "English")` (`AppLanguage.swift`); rótulos de valores da API ficam em `Labels`.
  Ao trocar o idioma o painel é reconstruído (`.id(language)` no `ControlPanel`). Nunca deixe texto fixo
  só em um idioma. As capturas `en-*` do `--snapshot` mostram a versão em inglês.
- O dono do projeto não é desenvolvedor Swift de carreira: explique passos de Terminal/VS Code de forma direta,
  um comando por vez quando houver risco de confusão.
- Compilar e instalar: `./build.sh --install` (ou `Cmd+Shift+B` no VS Code). Só checar erros: `swift build`.
- Ver a interface sem instalar: `swift run WindFreeBar --preview` (tarefa "WindFree: pré-visualizar painel").
  Abre o painel numa janela em modo de demonstração (`ACController(demo: true)`): dados de exemplo, sem rede,
  sem Keychain, comandos só mudam a tela. Prefira isso para ajustes visuais; instale só quando o dono pedir.
- Conferir o layout você mesmo: `.build/debug/WindFreeBar --snapshot <pasta>` salva PNGs do painel (todos os
  modos, extremos Frio 16° e Quente 30°, desligado, configurações; temas escuro e claro). Use a pasta de
  rascunho, não o repositório. Animações não aparecem em PNG: para transições, capture quadros a cada ~0,1 s
  numa janela fora da tela (foi assim que se achou o "deslizar" da ilustração) e depois remova o código.
- Depois de ajustes visuais, abra a pré-visualização na tela do dono (`.build/debug/WindFreeBar --preview &`)
  para ele testar interações (hover, rolagem, menus), que você não consegue testar.
- Depois de mudar código, compile para confirmar antes de dizer que está pronto.
- **Nunca** coloque tokens, Client ID/Secret ou códigos OAuth em arquivos do repositório. Ficam só no Keychain.

## O aparelho

- Modelo AR12DXFAAWK (WindFree 12.000 BTU, quente/frio), perfil SmartThings `DA-AC-RAC-01001`,
  `deviceTypeName` "Samsung OCF Air Conditioner". Um único componente: `main`.
- Capabilities usadas (comando → valores aceitos):
  - `switch` → `on` / `off`
  - `airConditionerMode.setAirConditionerMode` → auto, cool, dry, wind, heat
  - `thermostatCoolingSetpoint.setCoolingSetpoint` → 16–30, passo 1 (vale também no modo heat)
  - `airConditionerFanMode.setFanMode` → auto, low, medium, high, turbo
  - `fanOscillationMode.setFanOscillationMode` → fixed, vertical, horizontal, all
  - `custom.airConditionerOptionalMode.setAcOptionalMode` → off, sleep, quiet, smart, speed, windFree, windFreeSleep
  - `custom.autoCleaningMode.setAutoCleaningMode` → on, off
  - `refresh.refresh` → pede ao aparelho para reportar o estado
- Sono e WindFree dividem `acOptionalMode`: a tela trata como dois seletores independentes e combina
  (`ACState.optionalMode(windFree:sleep:)`; os dois juntos = `windFreeSleep`).
- WindFree (`windFree`/`windFreeSleep`) é recusado no modo `heat` (testado no aparelho em 12/10/2026); o cartão
  fica desativado nesse modo. Nos demais modos ainda não foi testado um por um. Trocar para `heat` com
  WindFree ligado é aceito: o próprio aparelho abre a aleta e desliga o WindFree (não é preciso desligar antes);
  o `setMode` já mostra "Desligado" na hora para o WindFree simples (WindFree Sono espera a nuvem).
- Com o aparelho desligado, um comando de modo **liga o aparelho**. Por isso, desligado o painel bloqueia
  dimmer, modos e seletores (`.disabled` + dica "Ligue o ar para alterar"); só o botão de energia liga.
- Leituras disponíveis: `temperatureMeasurement`, `relativeHumidityMeasurement`, `powerConsumptionReport`
  (energia acumulada em Wh), `custom.dustFilter` (uso do filtro em horas).
- Desativadas neste modelo (`custom.disabledCapabilities`): sensores de qualidade do ar/poeira/odor,
  luz do display, beep, `custom.spiMode`, entre outras. Não exponha essas na interface.

## Armadilhas conhecidas

- **O aparelho não reporta em tempo real** (`reportStateRealtime` = disabled). Logo depois de um comando,
  `GET /status` devolve o valor antigo por alguns segundos. Por isso o `ACController`:
  1. aplica o valor na tela na hora (otimista);
  2. guarda o comando em `pending` por até 45 s e não deixa leituras antigas desfazerem;
  3. manda `refresh` e relê em 2 s e 8 s.
  Sem isso o toggle "volta" para desligado e o próximo clique liga de novo em vez de desligar.
- A temperatura tem debounce de 0,7 s antes de enviar.
- O app SmartThings do iPhone mostra uma Live Activity que o macOS espelha na barra de menus. Não é deste app.
- O `/status` não traz o nome do aparelho; ele é relido em `GET /devices/{id}` quando o app pede `refresh`
  (abrir o painel, botão Atualizar), para refletir renomeações feitas no SmartThings.
- **Janela do `MenuBarExtra` mede o conteúdo propondo altura mínima**: views dimensionadas só por proporção
  (`GeometryReader` + `aspectRatio`, `Image.resizable().aspectRatio(.fit)` sem altura) encolhem até zero e
  somem. Dê largura e altura explícitas. `NSHostingView.fittingSize` não reproduz o problema; teste com
  `NSHostingController.sizeThatFits(in: NSSize(width: 320, height: 0))`.
- Mensagens de erro passam por `SmartThingsError.message(for:)`: o idioma do Mac do dono é `en-BR`, então
  `localizedDescription` de erros do sistema (rede, JSON, `SMAppService`) viria em inglês.
- **`.animation(_:value:)` anima também a posição/tamanho da view**. Quando o painel muda de altura (ligar/
  desligar), a janela salta para o tamanho final e qualquer view sob esse modificador desliza dentro dela. Não
  anime a altura; anime só opacidade/cor por um `@State` próprio com `withAnimation` em `onChange`
  (ver `ACIllustration.onPhotoOpacity`, `ModeGlow.shown`), inicializado em `onAppear`.
- O SwiftUI do macOS 13 não entrega a roda do mouse: o dimmer usa uma `NSView` por cima (`DialInput`) para
  rolagem, arraste e cursor.
- `Menu` com label personalizado não é desenhado como view no macOS; os seletores usam `Button` + `NSMenu`
  (`OptionMenu`).
- Preferências do app instalado e do `--preview` ficam separadas (o executável do `swift run` não tem bundle id):
  um tema escolhido na pré-visualização não vale no app.
- Para conferir se um texto entrou no binário instalado, não confie em `strings`: textos de até 15 bytes UTF-8
  (ex.: "Inicialização") ficam embutidos nas instruções pelo Swift. Compare datas do binário com o fonte.

## Autenticação

- O Client ID fica em `UserDefaults` (`oauthClientId`) para preencher a tela de conexão; tokens e Secret só no Keychain.
- OAuth com um app `API_ONLY` criado via `POST /v1/apps` (escopos `r/w/x:devices:*`,
  redirect `https://httpbin.org/get`). Não há Homebrew no Mac do dono, então a SmartThings CLI não foi usada.
- `AuthManager` guarda access + refresh token no Keychain e renova quando falta < 5 min; um 401 força renovação
  e uma nova tentativa. Cada renovação traz um refresh token novo, que substitui o anterior.
- O código de autorização vale **uma vez** e expira em minutos. `extractCode` aceita o código puro, o endereço
  do httpbin ou trechos do JSON da página.
- Personal Access Tokens criados hoje valem só 24 h; não use como solução permanente.

## Estrutura

- `ACState.swift` — modelo do estado, parse do `/status`, rótulos e ícones em português, combinação Sono/WindFree
- `SmartThingsClient.swift` — HTTP: listar dispositivos, status, comandos
- `AuthManager.swift` — fluxo OAuth e renovação
- `ACController.swift` — estado observável, polling de 60 s, atualização otimista, `pending`, modo demonstração
- `ControlPanel.swift` — painel: cabeçalho (nome, ambiente, botão de energia), ilustração, dimmer, botões de modo
  (só ícone), 4 seletores (Velocidade, Sono, Direção, WindFree), rodapé com engrenagem; configurações em seções
  (Conexão com "Atualizar agora"/"Desconectar", Aparência, Idioma, Inicialização, "Sair do WindFree") e botão de voltar
  com ícone no rodapé. Modo especial e Auto limpeza foram retirados da tela (o código de envio continua).
- `ACIllustration.swift` — foto do aparelho e fluxo de ar animado no topo do painel
- `TemperatureDial.swift` — dimmer de temperatura e `ModeColor` (cor de cada modo)
- `SelectorTile.swift` — cartão de seleção com menu nativo (`OptionMenu`)
- `ModeGlow.swift` — gradiente de fundo na cor do modo e camadas de temperatura extrema
- `Snowfall.swift` — neve caindo no Frio extremo
- `HoverButtonStyle.swift` — hover/clique dos botões personalizados
- `AppLanguage.swift` — idioma da interface e `tr(_:_:)`
- `SymbolEffects.swift` — animações dos SF Symbols com verificação de versão
- `AppAppearance.swift` — tema Sistema/Claro/Escuro (`NSApp.appearance`)
- `AirFlowStrands.swift` — dados gerados dos 40 fios do fluxo de ar (não editar à mão; ver Figma abaixo)
- `LaunchAtLogin.swift` — `SMAppService` (exige o app em /Applications)
- `Preview.swift` — `--preview` (janela de pré-visualização) e `--snapshot` (capturas em PNG)
- `WindFreeBarApp.swift` — `Launcher` (`@main`) escolhe entre app normal, `--preview` e `--snapshot`
- `Keychain.swift`, `build.sh` (copia `Resources/*.png` para o app), `Resources/Info.plist` (`LSUIElement` = sem Dock)

## Ilustração e Figma

- Arquivo Figma "WindFree" (a chave do arquivo não fica no repositório; peça o link ao dono): componente `ac img` (nó 9:11825, variante
  `state` on/off) e `Air flow` (nó 7:212, variante `Modo` auto/baixa/média/alta/turbo = `fanMode`
  auto/low/medium/high/turbo).
- Variante ligada: quadro 996 × 934, foto 916 × 353 em x = 80, fluxo 980 × 682 em y = 252. A foto fica
  centralizada no painel (288 pt úteis) e o fluxo avança um pouco sobre a margem esquerda.
- Fotos em `Resources/ac-on.png` e `ac-off.png` (reduzidas para 640 px). Fora do .app, `ACIllustration`
  lê de `Resources/` pelo caminho do fonte.
- Animação: em cada fio um trecho de 40% do comprimento percorre o caminho em loop contínuo (o dono pediu loop;
  no Figma ela para depois de ~2 s). Velocidade em comprimentos/s: baixa 0,525, média 0,875, alta 1,4,
  turbo 2,1; auto oscila 0,63–0,87 a cada 8 s. Fase e opacidade de cada fio vêm do Figma.
  Cor dos fios segue o modo (`ModeColor`): 5 variações da cor do modo; Quente usa laranjas escolhidos por nós.
  Os azuis originais do Figma foram trocados pelo azul-gelo do Frio.
- Ligar/desligar: a foto desligada fica sempre por baixo e a ligada só muda de opacidade (ease-in-out 0,4 s),
  então só a aleta parece abrir; o fluxo entra 0,25 s depois. A altura muda na hora. Desligado há 16 pt a mais
  abaixo da foto.

## Visual

- Cores dos modos (`ModeColor`, mudam com o tema): Frio azul-gelo `#8CD6F5` (claro: `#1E96CC`), Quente
  `#FA8C2B`, Seco `#2EC4B6`, Ventilar branco `#FFFFFF` (claro: `#3A3A3C`), Auto `#8E7CF0`. Usadas no dimmer, no
  botão do modo selecionado, nos fios de ar e no fundo.
- Fundo (`ModeGlow`): gradiente do topo até ~metade, opacidade 8–45%. Frio mais intenso quanto mais baixa a
  temperatura, Quente quanto mais alta, demais modos no meio-termo; desligado, sem cor. No fundo o Frio usa um
  azul mais saturado (`#3FAEF5`), porque o gelo virava cinza.
- Temperaturas extremas (3 graus das pontas, 1/3 por grau; cores em `ModeColor.extremeHex`):
  - Frio 18→16°: camada azul vivo `#14A0FF` (claro `#0A8FE8`) no topo do fundo (25/50/75%) e neve caindo
    (`Snowfall`, até 40 flocos sutis com balanço lateral). O dimmer do Frio fica no azul-gelo — o dono testou o
    azul vivo nele e não gostou (no frio extremo só um pedacinho do arco aparece).
  - Quente 28→30°: camada vermelha `#E5392F` no topo do fundo (25/50/75%) e o dimmer inteiro puxando do
    laranja para o vermelho (`ModeColor.dial`).
- Dimmer: arco de 240° com abertura embaixo, marcações a cada meio grau, sem números; sempre mostra um pedacinho
  do arco no mínimo. Rolagem para cima sobe (1 grau por clique da roda, ~12 pt no trackpad, inércia ignorada) e
  arraste vertical (8 pt por grau).
- Botão de energia: ligado cheio na cor do texto (branco no escuro, preto no claro); o dono não quer o azul do
  sistema nele. Desligado discreto, mas não pode parecer desativado quando ligado.
- Botões personalizados têm hover (`HoverButtonStyle`); controles nativos seguem o padrão do macOS.
- Animações de SF Symbols (`SymbolEffects.swift`, com `#available`: macOS 14/15+, estáticas antes): pás do
  ícone de Velocidade giram com o ar ligado (0,5× baixa … 2,6× turbo; `.id(speed)` reinicia o giro, senão a
  velocidade nova não pega); bounce no botão de energia; troca animada do ícone do modo no dimmer, que com o ar
  ligado gira devagar no Auto e "respira" só no tamanho (`.breathe.plain`) nos demais. O dono não quer efeitos
  que piscam ou variam opacidade (variable color, breathe padrão) — o Sono ficou sem animação.
- Para regerar `AirFlowStrands.swift`: `get_design_context` no nó 9:11825 dá caixa e SVG de cada fio (curva
  cúbica `M…C`; somar o deslocamento `inset` esquerdo/superior da caixa) e `get_motion_context` dá fase
  (`stroke-dashoffset`/`dasharray` em t = 0) e opacidade máxima.

## Ideias pendentes

- Presets com um clique (ex.: "Dormir" = WindFree Sono a 24°)
- Mostrar consumo de energia e alerta de limpeza do filtro
- Timer de desligar
- Pré-selecionar modo/temperatura com o ar desligado e aplicar ao ligar (hoje os controles ficam bloqueados)
