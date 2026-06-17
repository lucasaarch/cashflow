import Foundation

/// iCloud / CloudKit — preparado, mas desligado por padrão.
///
/// Ativação (requer Apple Developer Program pago):
/// 1. Xcode → Signing & Capabilities → iCloud → CloudKit
/// 2. Build Settings → Active Compilation Conditions → `CLOUDKIT_SYNC`
///
/// Ver `CashFlow/Documentation/iCloud-Sync.md`.
enum CloudKitSync {
    static let containerIdentifier = "iCloud.com.lucasarch.CashFlow"

    #if CLOUDKIT_SYNC
    static let isEnabled = true
    #else
    static let isEnabled = false
    #endif
}
