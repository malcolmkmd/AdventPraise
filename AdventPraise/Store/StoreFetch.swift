//
//  StoreFetch.swift
//  Advent Praise
//
//  Offerings and CustomerInfo are asked again after a short wait when the
//  failure is a network blip. A setup error is not asked again. The retry
//  itself is quiet: the caller logs one event, after the last try, with
//  RevenueCat's code (and the root error's domain and code). Never the
//  message, which can carry a URL.
//

import Foundation
@preconcurrency import RevenueCat

enum StoreFetchRetry {
    /// The first try, then two more.
    static let attempts = 3
    /// After the first failure, then after the second. Short on purpose.
    static let delays: [Duration] = [.milliseconds(400), .seconds(1)]

    @MainActor
    static func run<T>(
        sleep: @MainActor (Duration) async throws -> Void,
        _ operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<attempts {
            try Task.checkCancellation()
            do {
                return try await operation()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                let delayIndex = attempt
                let willRetry = attempt + 1 < attempts && StoreErrorReport.isTransient(error)
                guard willRetry else { throw error }
                try await sleep(delays[min(delayIndex, delays.count - 1)])
            }
        }
        throw lastError ?? CancellationError()
    }
}

/// What of a RevenueCat error is safe to count, and which failures are worth
/// another try. Codes and names only.
enum StoreErrorReport {
    /// `ErrorCode` raw values that are a blip: the network, the App Store,
    /// or RevenueCat's backend. A wrong key or a bad receipt is not in here.
    private static let transientRaw: Set<Int> = [
        0,  // unknownError, often a wrapped network failure
        2,  // storeProblemError
        10, // networkError
        12, // unexpectedBackendResponseError
        16, // unknownBackendError
        32, // productRequestTimedOut
        33, // apiEndpointBlockedError
        35, // offlineConnectionError
    ]

    private static let transientNames: Set<String> = [
        "UNKNOWN", "STORE_PROBLEM", "NETWORK_ERROR", "UNEXPECTED_BACKEND_RESPONSE_ERROR",
        "UNKNOWN_BACKEND_ERROR", "PRODUCT_REQUEST_TIMED_OUT_ERROR", "API_ENDPOINT_BLOCKED_ERROR",
        "OFFLINE_CONNECTION_ERROR",
    ]

    static func isTransient(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        if let code = error as? RevenueCat.ErrorCode, transientRaw.contains(code.rawValue) { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain { return true }
        if isRevenueCatDomain(ns.domain), transientRaw.contains(ns.code) { return true }
        if let name = readableName(ns), transientNames.contains(name) { return true }
        if let status = httpStatus(ns), status == 408 || status == 429 || (500...599).contains(status) { return true }
        return false
    }

    /// `NETWORK_ERROR.NSURLErrorDomain.-1009`, or `RC10` when RevenueCat
    /// didn't name it. HTTP status is added when the backend sent one.
    static func analyticsCode(_ error: Error) -> String {
        let ns = error as NSError
        var parts: [String] = []
        if let name = readableName(ns) {
            parts.append(sanitize(name))
        } else if let code = error as? RevenueCat.ErrorCode {
            parts.append("RC\(code.rawValue)")
        } else if isRevenueCatDomain(ns.domain) {
            parts.append("RC\(ns.code)")
        } else {
            parts.append(sanitize("\(ns.domain).\(ns.code)"))
        }
        if let status = httpStatus(ns) {
            parts.append("http\(status)")
        }
        if let root = ns.userInfo["rc_root_error"] as? [String: Any] {
            let domain = sanitize((root["domain"] as? String) ?? "root")
            let code = (root["code"] as? Int) ?? (root["code"] as? NSNumber)?.intValue ?? 0
            parts.append("\(domain).\(code)")
        }
        return String(parts.joined(separator: ".").prefix(160))
    }

    private static func isRevenueCatDomain(_ domain: String) -> Bool {
        domain == "RevenueCat.ErrorCode" || domain.hasSuffix(".ErrorCode")
    }

    private static func readableName(_ ns: NSError) -> String? {
        let raw = (ns.userInfo["readable_error_code"] as? String) ?? (ns.userInfo["rc_code_name"] as? String)
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func httpStatus(_ ns: NSError) -> Int? {
        if let status = ns.userInfo["rc_response_status_code"] as? Int { return status }
        if let status = ns.userInfo["rc_response_status_code"] as? NSNumber { return status.intValue }
        return nil
    }

    /// Letters, digits and the separators we join with. Drops anything a
    /// message or a URL would add.
    private static func sanitize(_ raw: String) -> String {
        String(raw.map { character in
            if character.isLetter || character.isNumber || character == "." || character == "_" || character == "-" {
                return character
            }
            return "_"
        })
    }
}
