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

        // Unlike `claimExistingCard`, a `null`/uncached first pass here is not a bug:
        // this method's job is precisely "create the card if it doesn't exist yet", so
        // the default `withLocalEvents: true` is fine — there's no false-`notFound` risk
        // to guard against.
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

    // NOTE: This method is only exercised manually (simulator + live DB inspection).
    // `LoyaltyCardRepositoryTests` covers `LoyaltyCardRepositoryImpl` against
    // `InMemoryLoyaltyCardApi`, which does not go through this Firebase transaction
    // code at all, so it would not catch a regression here. If we ever stand up a
    // Firebase emulator harness for tests, this method (and its null/race branches
    // below) should be the first thing covered.
    public func claimExistingCard(code: String, userId: String) async throws -> LoyaltyCardDto {
        // Definitive existence check via a normal read (`getData()` is a real server
        // round-trip). RTDB transaction blocks can still run their *first* pass against
        // a locally-cached `null` for a path the client has never synced before, even
        // when the node exists on the server — returning `.abort()` there cancels the
        // transaction outright instead of letting it resolve, which produced a false
        // `notFound` for seed cards like `MINIT-SEED-0001`. Doing this authoritative
        // check up front rules out real `notFound`/`alreadyClaimed` before we ever touch
        // the transaction.
        guard let prefetched = try await fetchCard(code: code) else {
            throw LoyaltyCardError.notFound
        }
        if let existingOwner = Self.nonEmptyString(from: prefetched.ownerUserId),
           existingOwner != userId {
            throw LoyaltyCardError.alreadyClaimed
        }
        if Self.nonEmptyString(from: prefetched.ownerUserId) == userId {
            return prefetched
        }

        let reference = cardReference(code: code)
        let abortBox = TransactionAbortBox()
        let fallbackPoints = prefetched.points ?? 0

        // `withLocalEvents: false` does *not* change what data the update block below
        // sees (per FIRDatabaseReference.h it only suppresses intermediate values from
        // being delivered to *other* listeners on this path) — it's kept here purely so
        // any other screen observing this card doesn't briefly flash our optimistic
        // guess before the transaction's final, server-confirmed state lands.
        let snapshot = try await runTransaction(on: reference, withLocalEvents: false) { currentData in
            if currentData.value == nil || currentData.value is NSNull {
                // Still null after the pre-read (concurrent delete, or a genuine
                // cache miss): propose the claim from the prefetched snapshot rather
                // than aborting. If the node actually still exists server-side, this
                // write will conflict with the real data — per RTDB's documented
                // "stale data" retry, the SDK re-invokes this block with the real
                // dictionary and we fall into the branch below instead of silently
                // committing wrong data. Rules-side, an existing card also requires
                // `newData.points === data.points`, so a stale `fallbackPoints` guess
                // here would be rejected (surfacing as a thrown error) rather than
                // corrupting the stored value.
                currentData.value = [
                    "code": code,
                    "ownerUserId": userId,
                    "points": fallbackPoints
                ]
                return .success(withValue: currentData)
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
        withLocalEvents: Bool = true,
        update: @escaping (MutableData) -> TransactionResult
    ) async throws -> DataSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            reference.runTransactionBlock(update, andCompletionBlock: { error, committed, snapshot in
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
            }, withLocalEvents: withLocalEvents)
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
