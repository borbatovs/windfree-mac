# WindFree — contexto do projeto

App de barra de menus do macOS (SwiftUI `MenuBarExtra`, macOS 13+, Swift Package sem Xcode project) que controla
um ar-condicionado Samsung WindFree pela API REST pública da SmartThings. Projeto pessoal.

## Como trabalhar aqui

- Converse e escreva textos da interface em **português do Brasil**. Identificadores no código em inglês.
- O dono do projeto não é desenvolvedor Swift de carreira: explique passos de Terminal/VS Code de forma direta,
  um comando por vez quando houver risco de confusão.
- Compilar e instalar: `./build.sh --install` (ou `Cmd+Shift+B` no VS Code). Só checar erros: `swift build`.
- Ver a interface sem instalar: `swift run WindFreeBar --preview` (tarefa "WindFree: pré-visualizar painel").
  Abre o painel numa janela em modo de demonstração (`ACController(demo: true)`): dados de exemplo, sem rede,
  sem Keychain, comandos só mudam a tela. Prefira isso para ajustes visuais; instale só quando o dono pedir.
- Conferir o layout você mesmo: `.build/debug/WindFreeBar --snapshot <pasta>` salva PNGs do painel (ligado frio,
  ligado quente, desligado, configurações; tema escuro). Use a pasta de rascunho, não o repositório.
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
- WindFree (`windFree`/`windFreeSleep`) é recusado no modo `heat` (testado no aparelho em 12/10/2026); o cartão
  fica desativado nesse modo. Nos demais modos ainda não foi testado um por um.
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

- `ACState.swift` — modelo do estado, parse do `/status`, rótulos e ícones em português
- `SmartThingsClient.swift` — HTTP: listar dispositivos, status, comandos
- `AuthManager.swift` — fluxo OAuth e renovação
- `ACController.swift` — estado observável, polling de 60 s, atualização otimista, `pending`, modo demonstração
- `ControlPanel.swift` — painel (cabeçalho com botão liga/desliga, ilustração, controles), configurações em
  duas seções (Conexão com a SmartThings, Inicialização)
- `ACIllustration.swift` — foto do aparelho e fluxo de ar animado no topo do painel
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
  Fios azuis (5 tons do Figma); laranja no modo Quente (tons escolhidos por nós, não estão no Figma).
- Para regerar `AirFlowStrands.swift`: `get_design_context` no nó 9:11825 dá caixa e SVG de cada fio (curva
  cúbica `M…C`; somar o deslocamento `inset` esquerdo/superior da caixa) e `get_motion_context` dá fase
  (`stroke-dashoffset`/`dasharray` em t = 0) e opacidade máxima.

## Ideias pendentes

- Presets com um clique (ex.: "Dormir" = WindFree Sono a 24°)
- Mostrar consumo de energia e alerta de limpeza do filtro
- Timer de desligar
