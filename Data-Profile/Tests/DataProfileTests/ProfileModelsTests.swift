import XCTest
@testable import DataProfile

final class ProfileModelsTests: XCTestCase {
    func testDtoToModelRoundTrip() {
        let dto = ProfileDto(name: "Iveta", surname: "Berzina", email: "iveta@minitbakery.com")

        let model = dto.toModel()

        XCTAssertEqual(model.name, "Iveta")
        XCTAssertEqual(model.surname, "Berzina")
        XCTAssertEqual(model.email, "iveta@minitbakery.com")
        XCTAssertEqual(model.toDto(), dto)
    }

    func testDecodesIncrementalOnboardingProfileWithoutLegacyFields() throws {
        let json = Data(
            #"""
            {
              "name": "Iveta",
              "onboarding": {
                "step": "language",
                "version": 1
              }
            }
            """#.utf8
        )

        let dto = try JSONDecoder().decode(ProfileDto.self, from: json)

        XCTAssertEqual(dto.name, "Iveta")
        XCTAssertEqual(dto.surname, "")
        XCTAssertEqual(dto.email, "")
    }

    func testDecodesNullLegacyFieldsAsEmptyStrings() throws {
        let json = Data(#"{"name":"Iveta","surname":null,"email":null}"#.utf8)

        let dto = try JSONDecoder().decode(ProfileDto.self, from: json)

        XCTAssertEqual(dto.surname, "")
        XCTAssertEqual(dto.email, "")
    }
}

extension ProfileDto: Equatable {
    public static func == (lhs: ProfileDto, rhs: ProfileDto) -> Bool {
        lhs.name == rhs.name && lhs.surname == rhs.surname && lhs.email == rhs.email
    }
}
