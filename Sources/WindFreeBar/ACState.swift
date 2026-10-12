import Foundation

/// Estado do ar-condicionado, montado a partir de GET /v1/devices/{id}/status.
/// Os nomes de capability/atributo vêm do status.json do AR12DXFAAWK (perfil DA-AC-RAC-01001).
struct ACState: Equatable {
    var power = false
    var mode = "cool"
    var supportedModes = ["auto", "cool", "dry", "wind", "heat"]
    var setpoint = 24
    var setpointMin = 16
    var setpointMax = 30
    var fanMode = "auto"
    var supportedFanModes = ["auto", "low", "medium", "high", "turbo"]
    var oscillation = "fixed"
    var supportedOscillation = ["fixed", "vertical", "horizontal", "all"]
    var optionalMode = "off"
    var supportedOptionalModes = ["off", "sleep", "quiet", "smart", "speed", "windFree", "windFreeSleep"]
    var autoClean = false
    var roomTemperature: Double?
    var humidity: Double?

    var isWindFree: Bool { optionalMode == "windFree" || optionalMode == "windFreeSleep" }

    /// Estado de exemplo para a pré-visualização.
    static var demo: ACState {
        var s = ACState()
        s.power = true
        s.fanMode = "high"
        s.roomTemperature = 23
        s.humidity = 55
        return s
    }

    static func parse(_ data: Data) throws -> ACState {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let components = root["components"] as? [String: Any],
            let main = components["main"] as? [String: Any]
        else { throw SmartThingsError.unexpectedResponse }

        func value(_ capability: String, _ attribute: String) -> Any? {
            let cap = main[capability] as? [String: Any]
            let attr = cap?[attribute] as? [String: Any]
            return attr?["value"]
        }
        func string(_ c: String, _ a: String) -> String? { value(c, a) as? String }
        func number(_ c: String, _ a: String) -> Double? { (value(c, a) as? NSNumber)?.doubleValue }
        func strings(_ c: String, _ a: String) -> [String]? {
            guard let list = value(c, a) as? [String], !list.isEmpty else { return nil }
            return list
        }

        var s = ACState()
        s.power = string("switch", "switch") == "on"
        s.mode = string("airConditionerMode", "airConditionerMode") ?? s.mode
        s.supportedModes = strings("airConditionerMode", "supportedAcModes") ?? s.supportedModes

        if let sp = number("thermostatCoolingSetpoint", "coolingSetpoint") { s.setpoint = Int(sp.rounded()) }
        if let range = value("thermostatCoolingSetpoint", "coolingSetpointRange") as? [String: Any] {
            if let min = (range["minimum"] as? NSNumber)?.intValue { s.setpointMin = min }
            if let max = (range["maximum"] as? NSNumber)?.intValue { s.setpointMax = max }
        }

        s.fanMode = string("airConditionerFanMode", "fanMode") ?? s.fanMode
        s.supportedFanModes = strings("airConditionerFanMode", "availableAcFanModes")
            ?? strings("airConditionerFanMode", "supportedAcFanModes")
            ?? s.supportedFanModes

        s.oscillation = string("fanOscillationMode", "fanOscillationMode") ?? s.oscillation
        s.supportedOscillation = strings("fanOscillationMode", "supportedFanOscillationModes") ?? s.supportedOscillation

        s.optionalMode = string("custom.airConditionerOptionalMode", "acOptionalMode") ?? s.optionalMode
        s.supportedOptionalModes = strings("custom.airConditionerOptionalMode", "supportedAcOptionalMode") ?? s.supportedOptionalModes

        s.autoClean = string("custom.autoCleaningMode", "autoCleaningMode") == "on"
        s.roomTemperature = number("temperatureMeasurement", "temperature")
        s.humidity = number("relativeHumidityMeasurement", "humidity")
        return s
    }
}

/// Rótulos em português e ícones (SF Symbols) para os valores da API.
enum Labels {
    static func mode(_ m: String) -> String {
        ["auto": "Auto", "cool": "Frio", "dry": "Seco", "wind": "Ventilar", "heat": "Quente"][m] ?? m
    }
    static func modeIcon(_ m: String) -> String {
        ["auto": "arrow.triangle.2.circlepath", "cool": "snowflake", "dry": "drop",
         "wind": "wind", "heat": "flame"][m] ?? "questionmark"
    }
    static func fan(_ f: String) -> String {
        ["auto": "Auto", "low": "Baixa", "medium": "Média", "high": "Alta", "turbo": "Turbo"][f] ?? f
    }
    static func oscillation(_ o: String) -> String {
        ["fixed": "Fixa", "vertical": "Vertical", "horizontal": "Horizontal", "all": "Todas"][o] ?? o
    }
    static func optional(_ o: String) -> String {
        ["off": "Nenhum", "sleep": "Sono", "quiet": "Silencioso", "smart": "Smart",
         "speed": "Speed", "windFree": "WindFree", "windFreeSleep": "WindFree Sono"][o] ?? o
    }
}
