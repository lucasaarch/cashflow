import WidgetKit
import SwiftUI

@main
struct CashFlowWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CashFlowOverviewWidget()
        CashFlowNextBillWidget()
    }
}
