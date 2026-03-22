// Shared between app and test targets.
// Add this file to both the lifetrak and lifetrakUITests targets in Xcode
// (File Inspector → Target Membership).
enum AXID {
    enum Today {
        static let progressRing  = "progressRing"
        static let progressLabel = "progressLabel"
        static let logButton     = "logWaterButton"
        static let streakLabel   = "streakLabel"
        static let weeklyChart   = "weeklyChart"
        static let entryList     = "entryList"
    }
    enum History {
        static let addButton  = "historyAddButton"
        static let entryList  = "historyEntryList"
        static let entryRow   = "historyEntryRow"
    }
}
