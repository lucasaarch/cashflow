import SwiftUI

struct CFMetricTile: View {
    let label: String
    let amount: Decimal
    let icon: String
    var tint: Color = CFTheme.accent

    var body: some View {
        HStack(spacing: 10) {
            CFIconBadge(symbolName: icon, tint: tint, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
                CFAnimatedAmount(amount: amount, font: CFTheme.kpiValue(), color: CFTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
