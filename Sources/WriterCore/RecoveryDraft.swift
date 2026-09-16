import Foundation

/// The baseline must survive a crash too: otherwise restored text could replace
/// remote changes that arrived while the app was closed.
struct RecoveryDraft: Codable, Sendable {
    let text: String
    let baseline: Data
}
