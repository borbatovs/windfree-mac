# WindFree — controle do ar Samsung na barra de menus do macOS

App de status bar (SwiftUI `MenuBarExtra`, macOS 13+) que controla o ar-condicionado Samsung WindFree
AR12DXFAAWK pela API pública da SmartThings.

## Rodar

Requer as Command Line Tools do Xcode (`xcode-select --install`) ou o Xcode.

```bash
cd WindFreeBar
chmod +x build.sh
./build.sh                       # gera build/WindFree.app
open build/WindFree.app
```

Para testar sem empacotar: `swift run`. Para editar no Xcode: `open Package.swift`.

Na primeira vez o painel pede para conectar à SmartThings via OAuth (veja abaixo). O app encontra o ar sozinho e atualiza o estado a cada 60 s.

## Mapeamento da API (perfil DA-AC-RAC-01001)

Todos os comandos vão para `POST /v1/devices/{id}/commands`, componente `main`.

| Controle | Capability | Comando | Valores aceitos pelo seu aparelho |
|---|---|---|---|
| Liga/desliga | `switch` | `on` / `off` | — |
| Modo | `airConditionerMode` | `setAirConditionerMode` | auto, cool, dry, wind, heat |
| Temperatura | `thermostatCoolingSetpoint` | `setCoolingSetpoint` | 16–30 °C, passo 1 (vale também no modo quente) |
| Velocidade | `airConditionerFanMode` | `setFanMode` | auto, low, medium, high, turbo |
| Direção | `fanOscillationMode` | `setFanOscillationMode` | fixed, vertical, horizontal, all |
| WindFree e afins | `custom.airConditionerOptionalMode` | `setAcOptionalMode` | off, sleep, quiet, smart, speed, windFree, windFreeSleep |
| Auto limpeza | `custom.autoCleaningMode` | `setAutoCleaningMode` | on, off |

Leituras: `temperatureMeasurement.temperature`, `relativeHumidityMeasurement.humidity`,
`powerConsumptionReport.powerConsumption` (energia acumulada em Wh).

Exemplo de teste no Terminal:

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  https://api.smartthings.com/v1/devices/$DEVICE/commands \
  -d '{"commands":[{"component":"main","capability":"custom.airConditionerOptionalMode","command":"setAcOptionalMode","arguments":["windFree"]}]}'
```

## Autenticação (OAuth)

O app usa um app OAuth-In seu na SmartThings. Ele guarda access token e refresh token no Keychain e
renova sozinho antes de expirar (o access token dura ~24 h). Cada renovação devolve um refresh token
novo, que substitui o anterior. Se o app ficar muito tempo sem rodar e o refresh token vencer, o painel
pede para autorizar de novo.

Criar o app OAuth (uma vez), com um Personal Access Token que tenha permissões de Apps e Devices:

```bash
export TOKEN="SEU_PAT"
curl -s -X POST https://api.smartthings.com/v1/apps \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "appName": "windfree-mac-'"$(openssl rand -hex 4)"'",
    "displayName": "WindFree Mac",
    "description": "Controle do ar-condicionado pela barra de menus",
    "appType": "API_ONLY",
    "classifications": ["CONNECTED_SERVICE"],
    "singleInstance": true,
    "oauth": {
      "clientName": "WindFree Mac",
      "scope": ["r:devices:*", "w:devices:*", "x:devices:*"],
      "redirectUris": ["https://httpbin.org/get"]
    }
  }' | python3 -m json.tool
```

Guarde `oauthClientId` e `oauthClientSecret` (o secret só aparece nessa resposta). No painel do app:
cole os dois, clique em "Abrir página de autorização", autorize e cole o endereço do httpbin
(com `?code=`). Cada código vale uma vez e por poucos minutos.

Nunca faça commit de tokens ou do Client Secret: eles ficam só no Keychain.

## Estrutura

- `ACState.swift` — modelo do estado e leitura do JSON de status; rótulos em português
- `AuthManager.swift` — fluxo OAuth e renovação automática do token
- `SmartThingsClient.swift` — chamadas HTTP (listar dispositivos, status, comandos)
- `ACController.swift` — estado observável, atualização otimista, polling, debounce da temperatura
- `ControlPanel.swift` — interface do painel e tela de conexão
- `Keychain.swift` — armazenamento das credenciais
- `WindFreeBarApp.swift` — entrada do app e ícone da barra de menus
