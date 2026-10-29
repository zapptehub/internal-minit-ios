import Sentry
import XCTest
@testable import minit

final class SentryConfigurationTests: XCTestCase {
    /// Failed-request events carry request headers after sentry-cocoa has already
    /// removed Authorization. This test feeds the header in anyway: our scrub must
    /// remove only `CF-Access-Client-Secret`, including on a breadcrumb attached to
    /// that event. It does not assert that every sensitive header is removed.
    ///
    /// `start` skips `SentrySDK.start` under XCTest. The hooks come from `applyOptions`,
    /// the same function `start` passes into that closure. `screenCapture` is false,
    /// matching development and release, so the scrub is not only installed for replay.
    func testFailedRequestScrubsCFAccessClientSecretAndKeepsOtherHeaders() {
        let options = Options()
        SentryConfiguration.applyOptions(
            options,
            dsn: "https://public@sentry.example/1",
            environment: "development",
            releaseName: "saleseverest.minit@1+1",
            screenCapture: false,
            policy: .on
        )
        XCTAssertEqual(options.environment, "development")
        XCTAssertTrue(options.sendDefaultPii)
        XCTAssertTrue(SentryPiiPolicy.on.sendDefaultPii)
        XCTAssertTrue(SentryPiiPolicy.on.attachUser)
        XCTAssertTrue(SentryPiiPolicy.on.keepHttpQuery)
        XCTAssertFalse(options.attachScreenshot)
        XCTAssertNotNil(options.beforeSend)
        XCTAssertNotNil(options.beforeBreadcrumb)

        let breadcrumb = Breadcrumb(level: .error, category: "http")
        breadcrumb.type = "http"
        breadcrumb.setData(value: "https://api.minit.app/v1/me", key: "url")
        breadcrumb.setData(value: "token=secret&email=a@b.c", key: "http.query")
        breadcrumb.setData(value: "Bearer fake-token", key: "Authorization")
        breadcrumb.setData(value: "fake-access-secret", key: "CF-Access-Client-Secret")
        breadcrumb.setData(
            value: [
                "Authorization": "Bearer fake-token",
                "CF-Access-Client-Secret": "fake-access-secret",
                "cf-access-client-secret": "fake-access-secret",
                "CF-Access-Client-Id": "fake-access-id",
            ],
            key: "headers"
        )

        let scrubbedBreadcrumb = options.beforeBreadcrumb?(breadcrumb)
        assertAccessSecretRemoved(from: scrubbedBreadcrumb?.data)
        XCTAssertEqual(scrubbedBreadcrumb?.data?["http.query"] as? String, "token=secret&email=a@b.c")

        let event = Event(level: .error)
        let request = SentryRequest()
        request.url = "https://api.minit.app/v1/me"
        request.queryString = "token=secret&email=a@b.c"
        request.method = "GET"
        request.headers = [
            "Authorization": "Bearer fake-token",
            "CF-Access-Client-Secret": "fake-access-secret",
            "cf-access-client-secret": "fake-access-secret",
            "CF-Access-Client-Id": "fake-access-id",
            "Content-Type": "application/json",
        ]
        event.request = request
        event.context = [
            "response": [
                "status_code": 500,
                "headers": [
                    "CF-Access-Client-Secret": "fake-access-secret",
                    "Content-Type": "application/json",
                    "Authorization": "Bearer fake-token",
                ],
            ],
        ]
        event.extra = [
            "CF-Access-Client-Secret": "fake-access-secret",
            "screen": "home",
        ]
        let attached = Breadcrumb(level: .error, category: "http")
        attached.setData(value: "fake-access-secret", key: "CF-Access-Client-Secret")
        attached.setData(value: "Bearer fake-token", key: "Authorization")
        attached.setData(value: "token=secret&email=a@b.c", key: "http.query")
        event.breadcrumbs = [attached]

        let scrubbed = options.beforeSend?(event)
        XCTAssertEqual(scrubbed?.request?.queryString, "token=secret&email=a@b.c")
        let headers = scrubbed?.request?.headers ?? [:]
        XCTAssertEqual(headers["Authorization"], "Bearer fake-token")
        XCTAssertEqual(headers["CF-Access-Client-Id"], "fake-access-id")
        XCTAssertEqual(headers["Content-Type"], "application/json")
        XCTAssertFalse(headers.keys.contains { $0.caseInsensitiveCompare("CF-Access-Client-Secret") == .orderedSame })

        let responseHeaders = stringDictionary(scrubbed?.context?["response"]?["headers"])
        XCTAssertEqual(responseHeaders["Content-Type"], "application/json")
        XCTAssertEqual(responseHeaders["Authorization"], "Bearer fake-token")
        XCTAssertFalse(
            responseHeaders.keys.contains { $0.caseInsensitiveCompare("CF-Access-Client-Secret") == .orderedSame }
        )
        XCTAssertEqual(scrubbed?.extra?["screen"] as? String, "home")
        XCTAssertNil(scrubbed?.extra?["CF-Access-Client-Secret"])
        let attachedData = scrubbed?.breadcrumbs?.first?.data ?? [:]
        XCTAssertEqual(attachedData["Authorization"] as? String, "Bearer fake-token")
        XCTAssertNil(attachedData["CF-Access-Client-Secret"])
        XCTAssertEqual(attachedData["http.query"] as? String, "token=secret&email=a@b.c")
    }

    /// Release policy is compile-time (`MINIT_SENTRY_NO_PII`). This applies that value
    /// directly so both policies can be tested from a Debug test host.
    func testReleasePolicyDropsQueryAndDoesNotAddAuthorization() {
        XCTAssertFalse(SentryPiiPolicy.release.sendDefaultPii)
        XCTAssertFalse(SentryPiiPolicy.release.attachUser)
        XCTAssertFalse(SentryPiiPolicy.release.keepHttpQuery)

        let options = Options()
        SentryConfiguration.applyOptions(
            options,
            dsn: "https://public@sentry.example/1",
            environment: "release",
            releaseName: "saleseverest.minit@1+1",
            screenCapture: false,
            policy: .release
        )
        XCTAssertFalse(options.sendDefaultPii)
        XCTAssertFalse(options.attachScreenshot)
        XCTAssertNotNil(options.beforeSend)
        XCTAssertNotNil(options.beforeBreadcrumb)

        let breadcrumb = Breadcrumb(level: .info, category: "http")
        breadcrumb.type = "http"
        breadcrumb.setData(value: "https://api.minit.app/v1/me", key: "url")
        breadcrumb.setData(value: "token=secret&email=a@b.c", key: "http.query")
        let scrubbedBreadcrumb = options.beforeBreadcrumb?(breadcrumb)
        XCTAssertEqual(scrubbedBreadcrumb?.data?["url"] as? String, "https://api.minit.app/v1/me")
        XCTAssertNil(scrubbedBreadcrumb?.data?["http.query"])
        XCTAssertNil(scrubbedBreadcrumb?.data?["Authorization"])

        let event = Event(level: .error)
        let request = SentryRequest()
        request.url = "https://api.minit.app/v1/me"
        request.queryString = "token=secret&email=a@b.c"
        event.request = request
        let attached = Breadcrumb(level: .info, category: "http")
        attached.setData(value: "token=secret&email=a@b.c", key: "http.query")
        attached.setData(value: "https://api.minit.app/v1/me", key: "url")
        event.breadcrumbs = [attached]

        let scrubbed = options.beforeSend?(event)
        XCTAssertEqual(scrubbed?.request?.url, "https://api.minit.app/v1/me")
        XCTAssertNil(scrubbed?.request?.queryString)
        XCTAssertNil(scrubbed?.request?.headers?["Authorization"])
        let attachedData = scrubbed?.breadcrumbs?.first?.data ?? [:]
        XCTAssertNil(attachedData["http.query"])
        XCTAssertNil(attachedData["Authorization"])
        XCTAssertEqual(attachedData["url"] as? String, "https://api.minit.app/v1/me")
    }

    private func assertAccessSecretRemoved(from data: [String: Any]?, file: StaticString = #filePath, line: UInt = #line) {
        let data = data ?? [:]
        XCTAssertEqual(data["Authorization"] as? String, "Bearer fake-token", file: file, line: line)
        XCTAssertNil(data["CF-Access-Client-Secret"], file: file, line: line)
        let headers = stringDictionary(data["headers"])
        XCTAssertEqual(headers["Authorization"], "Bearer fake-token", file: file, line: line)
        XCTAssertEqual(headers["CF-Access-Client-Id"], "fake-access-id", file: file, line: line)
        XCTAssertFalse(
            headers.keys.contains { $0.caseInsensitiveCompare("CF-Access-Client-Secret") == .orderedSame },
            file: file,
            line: line
        )
    }

    private func stringDictionary(_ value: Any?) -> [String: String] {
        if let headers = value as? [String: String] {
            return headers
        }
        guard let headers = value as? [String: Any] else { return [:] }
        return headers.compactMapValues { $0 as? String }
    }
}
