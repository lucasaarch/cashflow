import SwiftUI

struct DayOfMonthField: View {
    @Binding var day: Int

    @State private var text = ""

    var body: some View {
        TextField("—", text: $text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 56)
            .onAppear(perform: syncTextFromDay)
            .onChange(of: day) { _, _ in syncTextFromDay() }
            .onChange(of: text) { _, newValue in
                applyText(newValue)
            }
    }

    private func syncTextFromDay() {
        let rendered = day >= 1 ? "\(day)" : ""
        if text != rendered { text = rendered }
    }

    private func applyText(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        if digits != raw {
            text = digits
            return
        }

        guard !digits.isEmpty else {
            day = 0
            return
        }

        guard let value = Int(digits) else { return }

        if value > 31 {
            text = "31"
            day = 31
        } else if value >= 1 {
            day = value
        } else {
            day = 0
        }
    }
}
