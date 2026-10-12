import XCTest
@testable import FeatureLogin
import DataAuth

final class LoginAuthErrorMessageTests: XCTestCase {
    /// Exact Android `login_error_*` copy in English, Hungarian, and Slovak.
    func testOperationErrorCopyMatchesAndroid() {
        let cases: [(AuthOperationError, String, String, String)] = [
            (
                .invalidCredentials,
                "The email or password is incorrect.",
                "Az e-mail cím vagy a jelszó helytelen.",
                "E-mailová adresa alebo heslo je nesprávne."
            ),
            (
                .invalidEmail,
                "Please enter a valid email address.",
                "Kérjük, adj meg egy érvényes e-mail címet.",
                "Zadajte, prosím, platnú e-mailovú adresu."
            ),
            (
                .emailAlreadyInUse,
                "An account already exists with this email address.",
                "Ehhez az e-mail címhez már tartozik fiók.",
                "Účet s touto e-mailovou adresou už existuje."
            ),
            (
                .weakPassword,
                "The password is too weak. Please choose a stronger password.",
                "A jelszó túl gyenge. Válassz erősebb jelszót.",
                "Heslo je príliš slabé. Zvoľte si, prosím, silnejšie heslo."
            ),
            (
                .accountDisabled,
                "This account has been disabled.",
                "Ez a fiók le van tiltva.",
                "Tento účet bol deaktivovaný."
            ),
            (
                .network,
                "Check your internet connection and try again.",
                "Ellenőrizd az internetkapcsolatot, és próbáld újra.",
                "Skontrolujte internetové pripojenie a skúste to znova."
            ),
            (
                .tooManyRequests,
                "Too many attempts. Please try again later.",
                "Túl sok próbálkozás. Próbáld újra később.",
                "Príliš veľa pokusov. Skúste to znova neskôr."
            ),
            (
                .unexpected,
                "Something went wrong. Please try again.",
                "Valami hiba történt. Próbáld újra.",
                "Niečo sa pokazilo. Skúste to znova."
            )
        ]

        for (operation, en, hu, sk) in cases {
            XCTAssertEqual(message(operation, "en"), en, "\(operation) en")
            XCTAssertEqual(message(operation, "hu"), hu, "\(operation) hu")
            XCTAssertEqual(message(operation, "sk"), sk, "\(operation) sk")
        }
    }

    func testUnknownErrorUsesGenericCopyNotLocalizedDescription() {
        let error = NSError(
            domain: "test",
            code: 0,
            userInfo: [
                NSLocalizedDescriptionKey: "The password is invalid or the user does not have a password."
            ]
        )
        let expected = [
            "en": "Something went wrong. Please try again.",
            "hu": "Valami hiba történt. Próbáld újra.",
            "sk": "Niečo sa pokazilo. Skúste to znova.",
        ]
        for language in ["en", "hu", "sk"] {
            XCTAssertEqual(
                LoginAuthErrorMessage.message(for: error, locale: Locale(identifier: language)),
                expected[language],
                language
            )
        }
    }

    private func message(_ operation: AuthOperationError, _ language: String) -> String {
        LoginAuthErrorMessage.message(for: operation, locale: Locale(identifier: language))
    }
}
