import Foundation
import FirebaseDatabase

/// Real `LoyaltyCardApi` backed by Firebase Realtime Database.
/// Paths: `users/{uid}/loyaltyCardId`, `loyaltyCards/{code}`.
/// This is the sole place in `Data-LoyaltyCard` that imports `FirebaseDatabase`.
public final class FirebaseLoyaltyCardApiImpl: LoyaltyCardApi {
    public init() {}

    public func fetchLinkedCardId(userId: String) async throws -> String? {
        let snapshot = try await userLoyaltyCardIdReference(userId: userId).getData()
        guard snapshot.exists(), let value = snapshot.value as? String, !value.isEmpty else {
            return nil
        }
        return value
    }

    public func linkCardIdIfAbsent(userId: String, code: String) async throws -> String {
        let reference = userLoyaltyCardIdReference(userId: userId)
        let result = try await runTransaction(on: reference) { currentData in
            if let existing = Self.nonEmptyString(from: currentData.value) {
                currentData.value = existing
                return .success(withValue: currentData)
            }
            currentData.value = code
            return .success(withValue: currentData)
        }
        guard let linked = Self.nonEmptyString(from: result.value) else {
            throw LoyaltyCardError.underlying("Failed to link loyalty card id for user \(userId).")
        }
        return linked
    }

    public func fetchCard(code: String) async throws -> LoyaltyCardDto? {
        let snapshot = try await cardReference(code: code).getData()
        guard snapshot.exists(), snapshot.value != nil else {
            return nil
        }
        do {
            return try snapshot.data(as: LoyaltyCardDto.self)
        } catch {
            throw LoyaltyCardError.underlying("Failed to decode loyalty card \(code): \(error.localizedDescription)")
        }
    }

    public func ensureCardOwned(code: String, ownerUserId: String, points: Int) async throws -> LoyaltyCardDto {
        let reference = cardReference(code: code)
        let abortBox = TransactionAbortBox()

        let snapshot = try await runTransaction(on: reference) { currentData in
            if currentData.value == nil || currentData.value is NSNull {
                currentData.value = [
                    "code": code,
                    "ownerUserId": ownerUserId,
                    "points": points
                ]
                return .success(withValue: currentData)
            }

            guard var dictionary = currentData.value as? [String: Any] else {
                abortBox.reason = .underlying("Unexpected loyalty card payload for \(code).")
                return .abort()
            }

            let existingOwner = Self.nonEmptyString(from: dictionary["ownerUserId"])
            if let existingOwner, existingOwner != ownerUserId {
                abortBox.reason = .alreadyClaimed
                return .abort()
            }

            dictionary["code"] = code
            dictionary["ownerUserId"] = ownerUserId
            if dictionary["points"] == nil {
                dictionary["points"] = points
            }
            currentData.value = dictionary
            return .success(withValue: currentData)
        }

        if let reason = abortBox.reason {
            throw reason
        }

        return try decodeCard(from: snapshot, fallbackCode: code)
    }

    public func claimExistingCard(code: String, userId: String) async throws -> LoyaltyCardDto {
        let reference = cardReference(code: code)
        let abortBox = TransactionAbortBox()

        let snapshot = try await runTransaction(on: reference) { currentData in
            guard currentData.value != nil, !(currentData.value is NSNull) else {
                abortBox.reason = .notFound
                return .abort()
            }

            guard var dictionary = currentData.value as? [String: Any] else {
                abortBox.reason = .underlying("Unexpected loyalty card payload for \(code).")
                return .abort()
            }

            let existingOwner = Self.nonEmptyString(from: dictionary["ownerUserId"])
            if let existingOwner, existingOwner != userId {
                abortBox.reason = .alreadyClaimed
                return .abort()
            }

            dictionary["code"] = dictionary["code"] as? String ?? code
            dictionary["ownerUserId"] = userId
            currentData.value = dictionary
            return .success(withValue: currentData)
        }

        if let reason = abortBox.reason {
            throw reason
        }

        return try decodeCard(from: snapshot, fallbackCode: code)
    }

    // MARK: - Private

    private func userLoyaltyCardIdReference(userId: String) -> DatabaseReference {
        Database.database().reference().child("users").child(userId).child("loyaltyCardId")
    }

    private func cardReference(code: String) -> DatabaseReference {
        Database.database().reference().child("loyaltyCards").child(code)
    }

    private func decodeCard(from snapshot: DataSnapshot, fallbackCode: String) throws -> LoyaltyCardDto {
        if let dto = try? snapshot.data(as: LoyaltyCardDto.self) {
            return dto
        }
        guard let dictionary = snapshot.value as? [String: Any] else {
            throw LoyaltyCardError.underlying("Missing loyalty card payload for \(fallbackCode).")
        }
        let code = dictionary["code"] as? String ?? fallbackCode
        let owner = Self.nonEmptyString(from: dictionary["ownerUserId"])
        let points = dictionary["points"] as? Int
        return LoyaltyCardDto(code: code, ownerUserId: owner, points: points)
    }

    private func runTransaction(
        on reference: DatabaseReference,
        update: @escaping (MutableData) -> TransactionResult
    ) async throws -> DataSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            reference.runTransactionBlock(update) { error, committed, snapshot in
                if let error {
                    continuation.resume(
                        throwing: LoyaltyCardError.underlying(error.localizedDescription)
                    )
                    return
                }
                guard committed, let snapshot else {
                    // Aborted transactions resume with a snapshot of the current value;
                    // callers inspect TransactionAbortBox for typed reasons.
                    if let snapshot {
                        continuation.resume(returning: snapshot)
                    } else {
                        continuation.resume(
                            throwing: LoyaltyCardError.underlying("Loyalty card transaction did not commit.")
                        )
                    }
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
    }

    private static func nonEmptyString(from value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Captures a typed abort reason from inside a Firebase transaction update block.
private final class TransactionAbortBox: @unchecked Sendable {
    var reason: LoyaltyCardError?
}
