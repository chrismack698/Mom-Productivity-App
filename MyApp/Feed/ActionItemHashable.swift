import Foundation

extension ActionItem: Hashable {
    static func == (lhs: ActionItem, rhs: ActionItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
