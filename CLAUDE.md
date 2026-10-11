# WindFree — contexto do projeto

App de barra de menus do macOS (SwiftUI `MenuBarExtra`, macOS 13+, Swift Package sem Xcode project) que controla
um ar-condicionado Samsung WindFree pela API REST pública da SmartThings. Projeto pessoal.

## Como trabalhar aqui

- Converse e escreva textos da interface em **português do Brasil**. Identificadores no código em inglês.
- O dono do projeto não é desenvolvedor Swift de carreira: explique passos de Terminal/VS Code de forma direta,
  um comando por vez quando houver risco de confusão.
- Compilar e instalar: `./build.sh --install` (ou `Cmd+Shift+B` no VS Code). Só checar erros: `swift build`.
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

## Autenticação

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
- `ACController.swift` — estado observável, polling de 60 s, atualização otimista, `pending`
- `ControlPanel.swift` — painel, tela de conexão, toggle de iniciar no login
- `LaunchAtLogin.swift` — `SMAppService` (exige o app em /Applications)
- `Keychain.swift`, `WindFreeBarApp.swift`, `build.sh`, `Resources/Info.plist` (`LSUIElement` = sem Dock)

## Ideias pendentes

- Presets com um clique (ex.: "Dormir" = WindFree Sono a 24°)
- Mostrar consumo de energia e alerta de limpeza do filtro
- Timer de desligar
