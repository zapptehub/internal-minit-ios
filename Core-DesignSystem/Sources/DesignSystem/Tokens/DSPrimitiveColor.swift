import SwiftUI

/// Color primitives from the Mode 1 design export.
internal struct DSColorToken: Equatable, Sendable {
    let rgb: UInt32
    let opacity: Double
    let sourceID: String

    init(rgb: UInt32, opacity: Double = 1, sourceID: String) {
        self.rgb = rgb
        self.opacity = opacity
        self.sourceID = sourceID
    }

    var color: SwiftUI.Color {
        SwiftUI.Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: opacity
        )
    }
}

internal enum DSPrimitiveColor {
    static let black = DSColorToken(rgb: 0x000000, sourceID: "VariableID:16:61")
    static let white = DSColorToken(rgb: 0xFFFFFF, sourceID: "VariableID:16:62")
    static let transparent5 = DSColorToken(rgb: 0xFFFFFF, opacity: 0.05, sourceID: "VariableID:16:87")
    static let transparent10 = DSColorToken(rgb: 0xFFFFFF, opacity: 0.10, sourceID: "VariableID:2075:428")
    static let transparent15 = DSColorToken(rgb: 0xFFFFFF, opacity: 0.15, sourceID: "VariableID:2075:429")
    enum Minit {
        static let tone50 = DSColorToken(rgb: 0xFFFAF5, sourceID: "VariableID:2009:84")
        static let tone100 = DSColorToken(rgb: 0xFFE2C4, sourceID: "VariableID:16:5")
        static let tone200 = DSColorToken(rgb: 0xFFCA93, sourceID: "VariableID:16:6")
        static let tone300 = DSColorToken(rgb: 0xFFCA93, sourceID: "VariableID:16:7")
        static let tone400 = DSColorToken(rgb: 0xFF9A31, sourceID: "VariableID:16:8")
        static let tone500 = DSColorToken(rgb: 0xFF8200, sourceID: "VariableID:16:9")
        static let tone600 = DSColorToken(rgb: 0xCE6900, sourceID: "VariableID:16:10")
        static let tone700 = DSColorToken(rgb: 0x9D5000, sourceID: "VariableID:16:11")
        static let tone800 = DSColorToken(rgb: 0x6C3700, sourceID: "VariableID:16:12")
    }

    enum DeepClaret {
        static let tone50 = DSColorToken(rgb: 0xFFFAFC, sourceID: "VariableID:2009:86")
        static let tone100 = DSColorToken(rgb: 0xF4CBDB, sourceID: "VariableID:16:13")
        static let tone200 = DSColorToken(rgb: 0xEA9DBA, sourceID: "VariableID:16:14")
        static let tone300 = DSColorToken(rgb: 0xDF6E99, sourceID: "VariableID:16:15")
        static let tone400 = DSColorToken(rgb: 0xD54078, sourceID: "VariableID:16:16")
        static let tone500 = DSColorToken(rgb: 0xCA1157, sourceID: "VariableID:16:17")
        static let tone600 = DSColorToken(rgb: 0xA20E46, sourceID: "VariableID:16:18")
        static let tone700 = DSColorToken(rgb: 0x790A34, sourceID: "VariableID:16:19")
        static let tone800 = DSColorToken(rgb: 0x510723, sourceID: "VariableID:16:20")
        static let tone850 = DSColorToken(rgb: 0x3D051A, sourceID: "VariableID:4117:7331")
        static let tone900 = DSColorToken(rgb: 0x280311, sourceID: "VariableID:2009:87")
    }

    enum Brown {
        static let tone25 = DSColorToken(rgb: 0xFFF5EB, sourceID: "VariableID:6177:2482")
        static let tone50 = DSColorToken(rgb: 0xD6C9BC, sourceID: "VariableID:6177:2471")
        static let tone100 = DSColorToken(rgb: 0xC2B3A4, sourceID: "VariableID:6177:2472")
        static let tone200 = DSColorToken(rgb: 0xAD9D8D, sourceID: "VariableID:6177:2473")
        static let tone300 = DSColorToken(rgb: 0x85725E, sourceID: "VariableID:6177:2474")
        static let tone400 = DSColorToken(rgb: 0x5C462F, sourceID: "VariableID:6177:2475")
        static let tone500 = DSColorToken(rgb: 0x331A00, sourceID: "VariableID:6177:2476")
        static let tone600 = DSColorToken(rgb: 0x291500, sourceID: "VariableID:6177:2477")
        static let tone700 = DSColorToken(rgb: 0x1F1000, sourceID: "VariableID:6177:2478")
        static let tone800 = DSColorToken(rgb: 0x140A00, sourceID: "VariableID:6177:2479")
    }

    enum DeepGreen {
        static let tone25 = DSColorToken(rgb: 0xE5FCF1, sourceID: "VariableID:6177:2483")
        static let tone50 = DSColorToken(rgb: 0xCFEADD, sourceID: "VariableID:6177:2484")
        static let tone100 = DSColorToken(rgb: 0xB9D7C9, sourceID: "VariableID:6177:2485")
        static let tone200 = DSColorToken(rgb: 0x8DB3A1, sourceID: "VariableID:6177:2486")
        static let tone300 = DSColorToken(rgb: 0x618E78, sourceID: "VariableID:6177:2487")
        static let tone400 = DSColorToken(rgb: 0x356A50, sourceID: "VariableID:6177:2488")
        static let tone500 = DSColorToken(rgb: 0x094528, sourceID: "VariableID:6177:2489")
        static let tone600 = DSColorToken(rgb: 0x073720, sourceID: "VariableID:6177:2490")
        static let tone700 = DSColorToken(rgb: 0x052918, sourceID: "VariableID:6177:2491")
        static let tone800 = DSColorToken(rgb: 0x041C10, sourceID: "VariableID:6177:2492")
        static let tone900 = DSColorToken(rgb: 0x03150C, sourceID: "VariableID:6177:2493")
    }

    enum Green {
        static let tone50 = DSColorToken(rgb: 0xEBF9F2, sourceID: "VariableID:2009:272")
        static let tone100 = DSColorToken(rgb: 0xD7F4E6, sourceID: "VariableID:16:21")
        static let tone200 = DSColorToken(rgb: 0xB0E8CC, sourceID: "VariableID:16:22")
        static let tone300 = DSColorToken(rgb: 0x88DDB3, sourceID: "VariableID:16:23")
        static let tone400 = DSColorToken(rgb: 0x61D199, sourceID: "VariableID:16:24")
        static let tone500 = DSColorToken(rgb: 0x41C885, sourceID: "VariableID:16:25")
        static let tone600 = DSColorToken(rgb: 0x2E9E66, sourceID: "VariableID:16:26")
        static let tone700 = DSColorToken(rgb: 0x22774D, sourceID: "VariableID:16:27")
        static let tone800 = DSColorToken(rgb: 0x174F33, sourceID: "VariableID:16:28")
        static let tone900 = DSColorToken(rgb: 0x0B281A, sourceID: "VariableID:2009:273")
    }

    enum Yellow {
        static let tone50 = DSColorToken(rgb: 0xFEF8E7, sourceID: "VariableID:2009:274")
        static let tone100 = DSColorToken(rgb: 0xFDF1CE, sourceID: "VariableID:16:29")
        static let tone200 = DSColorToken(rgb: 0xFBE39D, sourceID: "VariableID:16:30")
        static let tone300 = DSColorToken(rgb: 0xF9D66C, sourceID: "VariableID:16:31")
        static let tone400 = DSColorToken(rgb: 0xF7C83B, sourceID: "VariableID:16:32")
        static let tone500 = DSColorToken(rgb: 0xF7CB47, sourceID: "VariableID:16:33")
        static let tone600 = DSColorToken(rgb: 0xC49508, sourceID: "VariableID:16:34")
        static let tone700 = DSColorToken(rgb: 0x937006, sourceID: "VariableID:16:35")
        static let tone800 = DSColorToken(rgb: 0x624A04, sourceID: "VariableID:16:36")
        static let tone900 = DSColorToken(rgb: 0x312502, sourceID: "VariableID:2009:275")
    }

    enum Red {
        static let tone50 = DSColorToken(rgb: 0xFDE7E7, sourceID: "VariableID:2009:276")
        static let tone100 = DSColorToken(rgb: 0xFCCFCF, sourceID: "VariableID:16:37")
        static let tone200 = DSColorToken(rgb: 0xF99F9F, sourceID: "VariableID:16:38")
        static let tone300 = DSColorToken(rgb: 0xF66F6F, sourceID: "VariableID:16:39")
        static let tone400 = DSColorToken(rgb: 0xF24040, sourceID: "VariableID:16:40")
        static let tone500 = DSColorToken(rgb: 0xF23A3A, sourceID: "VariableID:16:41")
        static let tone600 = DSColorToken(rgb: 0xBF0D0D, sourceID: "VariableID:16:42")
        static let tone700 = DSColorToken(rgb: 0x900909, sourceID: "VariableID:16:43")
        static let tone800 = DSColorToken(rgb: 0x600606, sourceID: "VariableID:16:44")
        static let tone900 = DSColorToken(rgb: 0x300303, sourceID: "VariableID:2009:277")
    }

    enum Grey {
        static let tone50 = DSColorToken(rgb: 0xF2F2F2, sourceID: "VariableID:16:88")
        static let tone100 = DSColorToken(rgb: 0xE6E6E6, sourceID: "VariableID:16:45")
        static let tone200 = DSColorToken(rgb: 0xCCCCCC, sourceID: "VariableID:16:46")
        static let tone300 = DSColorToken(rgb: 0xB3B3B3, sourceID: "VariableID:16:47")
        static let tone400 = DSColorToken(rgb: 0x999999, sourceID: "VariableID:16:48")
        static let tone500 = DSColorToken(rgb: 0x383838, sourceID: "VariableID:16:49")
        static let tone600 = DSColorToken(rgb: 0x666666, sourceID: "VariableID:16:50")
        static let tone700 = DSColorToken(rgb: 0x4D4D4D, sourceID: "VariableID:16:51")
        static let tone800 = DSColorToken(rgb: 0x333333, sourceID: "VariableID:16:52")
        static let tone900 = DSColorToken(rgb: 0x1A1A1A, sourceID: "VariableID:2009:278")
    }

    enum Blue {
        static let tone50 = DSColorToken(rgb: 0xEBF4F8, sourceID: "VariableID:2009:279")
        static let tone100 = DSColorToken(rgb: 0xD0E3FB, sourceID: "VariableID:16:53")
        static let tone200 = DSColorToken(rgb: 0xA1C6F7, sourceID: "VariableID:16:54")
        static let tone300 = DSColorToken(rgb: 0x72AAF3, sourceID: "VariableID:16:55")
        static let tone400 = DSColorToken(rgb: 0x438EEF, sourceID: "VariableID:16:56")
        static let tone500 = DSColorToken(rgb: 0x2C80ED, sourceID: "VariableID:16:57")
        static let tone600 = DSColorToken(rgb: 0x105BBC, sourceID: "VariableID:16:58")
        static let tone700 = DSColorToken(rgb: 0x0C448D, sourceID: "VariableID:16:59")
        static let tone800 = DSColorToken(rgb: 0x082D5E, sourceID: "VariableID:16:60")
        static let tone900 = DSColorToken(rgb: 0x04172F, sourceID: "VariableID:2009:280")
    }

    static let all: [String: DSColorToken] = [
        "color.black": black,
        "color.white": white,
        "color.transparent-5": transparent5,
        "color.transparent-10": transparent10,
        "color.transparent-15": transparent15,
        "color.minit.50": Minit.tone50,
        "color.minit.100": Minit.tone100,
        "color.minit.200": Minit.tone200,
        "color.minit.300": Minit.tone300,
        "color.minit.400": Minit.tone400,
        "color.minit.500": Minit.tone500,
        "color.minit.600": Minit.tone600,
        "color.minit.700": Minit.tone700,
        "color.minit.800": Minit.tone800,
        "color.deep-claret.50": DeepClaret.tone50,
        "color.deep-claret.100": DeepClaret.tone100,
        "color.deep-claret.200": DeepClaret.tone200,
        "color.deep-claret.300": DeepClaret.tone300,
        "color.deep-claret.400": DeepClaret.tone400,
        "color.deep-claret.500": DeepClaret.tone500,
        "color.deep-claret.600": DeepClaret.tone600,
        "color.deep-claret.700": DeepClaret.tone700,
        "color.deep-claret.800": DeepClaret.tone800,
        "color.deep-claret.850": DeepClaret.tone850,
        "color.deep-claret.900": DeepClaret.tone900,
        "color.brown.25": Brown.tone25,
        "color.brown.50": Brown.tone50,
        "color.brown.100": Brown.tone100,
        "color.brown.200": Brown.tone200,
        "color.brown.300": Brown.tone300,
        "color.brown.400": Brown.tone400,
        "color.brown.500": Brown.tone500,
        "color.brown.600": Brown.tone600,
        "color.brown.700": Brown.tone700,
        "color.brown.800": Brown.tone800,
        "color.deep-green.25": DeepGreen.tone25,
        "color.deep-green.50": DeepGreen.tone50,
        "color.deep-green.100": DeepGreen.tone100,
        "color.deep-green.200": DeepGreen.tone200,
        "color.deep-green.300": DeepGreen.tone300,
        "color.deep-green.400": DeepGreen.tone400,
        "color.deep-green.500": DeepGreen.tone500,
        "color.deep-green.600": DeepGreen.tone600,
        "color.deep-green.700": DeepGreen.tone700,
        "color.deep-green.800": DeepGreen.tone800,
        "color.deep-green.900": DeepGreen.tone900,
        "color.green.50": Green.tone50,
        "color.green.100": Green.tone100,
        "color.green.200": Green.tone200,
        "color.green.300": Green.tone300,
        "color.green.400": Green.tone400,
        "color.green.500": Green.tone500,
        "color.green.600": Green.tone600,
        "color.green.700": Green.tone700,
        "color.green.800": Green.tone800,
        "color.green.900": Green.tone900,
        "color.yellow.50": Yellow.tone50,
        "color.yellow.100": Yellow.tone100,
        "color.yellow.200": Yellow.tone200,
        "color.yellow.300": Yellow.tone300,
        "color.yellow.400": Yellow.tone400,
        "color.yellow.500": Yellow.tone500,
        "color.yellow.600": Yellow.tone600,
        "color.yellow.700": Yellow.tone700,
        "color.yellow.800": Yellow.tone800,
        "color.yellow.900": Yellow.tone900,
        "color.red.50": Red.tone50,
        "color.red.100": Red.tone100,
        "color.red.200": Red.tone200,
        "color.red.300": Red.tone300,
        "color.red.400": Red.tone400,
        "color.red.500": Red.tone500,
        "color.red.600": Red.tone600,
        "color.red.700": Red.tone700,
        "color.red.800": Red.tone800,
        "color.red.900": Red.tone900,
        "color.grey.50": Grey.tone50,
        "color.grey.100": Grey.tone100,
        "color.grey.200": Grey.tone200,
        "color.grey.300": Grey.tone300,
        "color.grey.400": Grey.tone400,
        "color.grey.500": Grey.tone500,
        "color.grey.600": Grey.tone600,
        "color.grey.700": Grey.tone700,
        "color.grey.800": Grey.tone800,
        "color.grey.900": Grey.tone900,
        "color.blue.50": Blue.tone50,
        "color.blue.100": Blue.tone100,
        "color.blue.200": Blue.tone200,
        "color.blue.300": Blue.tone300,
        "color.blue.400": Blue.tone400,
        "color.blue.500": Blue.tone500,
        "color.blue.600": Blue.tone600,
        "color.blue.700": Blue.tone700,
        "color.blue.800": Blue.tone800,
        "color.blue.900": Blue.tone900,
    ]
}
