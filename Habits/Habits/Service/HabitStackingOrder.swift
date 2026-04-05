import Foundation

struct HabitViewModel: Identifiable {
    let habit: Habit
    let id: UUID
    let title: String
    let colorHex: String
    let relationText: String?
    let isStacked: Bool
    let stackRootID: UUID?
    let stackColorHex: String?
    let hasAdjacentChild: Bool
}

struct StackViewModel: Identifiable {
    let rootHabit: HabitViewModel
    let orderedHabits: [HabitViewModel]
    let stackColorHex: String

    var id: UUID {
        rootHabit.id
    }
}

enum TodayItem: Identifiable {
    case single(HabitViewModel)
    case stack(StackViewModel)

    var id: String {
        switch self {
        case .single(let habit):
            return "single-\(habit.id.uuidString)"
        case .stack(let stack):
            return "stack-\(stack.id.uuidString)"
        }
    }
}

struct HabitStackingSnapshot {
    let displayHabits: [Habit]
    let displayHabitViewModels: [HabitViewModel]
    let todayItems: [TodayItem]
    let parentByChildID: [UUID: UUID]
    let childrenByParentID: [UUID: [Habit]]
    let habitViewModelByID: [UUID: HabitViewModel]
    let rootByHabitID: [UUID: UUID]
    let stackColorHexByHabitID: [UUID: String]
}

enum HabitStackingOrder {
    static func resolve(baseHabits: [Habit]) -> HabitStackingSnapshot {
        let context = HabitStackingRules.validationContext(from: baseHabits)
        let parentByChildID = context.parentByChildID
        let habitByID = Dictionary(uniqueKeysWithValues: baseHabits.map { ($0.id, $0) })
        let orderIndexByHabitID = Dictionary(uniqueKeysWithValues: baseHabits.map { ($0.id, $0.orderIndex) })

        func isBefore(_ lhsID: UUID, _ rhsID: UUID) -> Bool {
            let lhsOrder = orderIndexByHabitID[lhsID] ?? .max
            let rhsOrder = orderIndexByHabitID[rhsID] ?? .max
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return lhsID.uuidString < rhsID.uuidString
        }

        func cycleRootID(for cycle: [UUID]) -> UUID {
            precondition(!cycle.isEmpty)
            var currentBest = cycle[0]
            for candidate in cycle.dropFirst() where isBefore(candidate, currentBest) {
                currentBest = candidate
            }
            return currentBest
        }

        var rootByHabitID: [UUID: UUID] = [:]
        rootByHabitID.reserveCapacity(baseHabits.count)

        @discardableResult
        func resolveRootID(for habitID: UUID) -> UUID {
            if let cachedRoot = rootByHabitID[habitID] {
                return cachedRoot
            }

            var path: [UUID] = []
            path.reserveCapacity(8)
            var pathIndexByHabitID: [UUID: Int] = [:]
            pathIndexByHabitID.reserveCapacity(8)

            var cursor = habitID
            var resolvedRootID = habitID

            while true {
                if let cachedRoot = rootByHabitID[cursor] {
                    resolvedRootID = cachedRoot
                    break
                }

                if let cycleStartIndex = pathIndexByHabitID[cursor] {
                    resolvedRootID = cycleRootID(for: Array(path[cycleStartIndex...]))
                    break
                }

                pathIndexByHabitID[cursor] = path.count
                path.append(cursor)

                guard let parentID = parentByChildID[cursor], habitByID[parentID] != nil else {
                    resolvedRootID = cursor
                    break
                }

                cursor = parentID
            }

            for id in path {
                rootByHabitID[id] = resolvedRootID
            }
            return resolvedRootID
        }

        for habit in baseHabits {
            _ = resolveRootID(for: habit.id)
        }

        var habitsByRootID: [UUID: [Habit]] = [:]
        habitsByRootID.reserveCapacity(baseHabits.count)

        for habit in baseHabits {
            let rootID = rootByHabitID[habit.id] ?? habit.id
            habitsByRootID[rootID, default: []].append(habit)
        }

        var orderedRootIDs: [UUID] = []
        orderedRootIDs.reserveCapacity(habitsByRootID.count)
        var seenRootIDs: Set<UUID> = []
        seenRootIDs.reserveCapacity(habitsByRootID.count)

        for habit in baseHabits {
            guard rootByHabitID[habit.id] == habit.id else { continue }
            if seenRootIDs.insert(habit.id).inserted {
                orderedRootIDs.append(habit.id)
            }
        }

        let unresolvedRootIDs = habitsByRootID.keys
            .filter { !seenRootIDs.contains($0) }
            .sorted(by: isBefore)
        orderedRootIDs.append(contentsOf: unresolvedRootIDs)

        var displayHabitViewModels: [HabitViewModel] = []
        displayHabitViewModels.reserveCapacity(baseHabits.count)
        var displayHabits: [Habit] = []
        displayHabits.reserveCapacity(baseHabits.count)
        var todayItems: [TodayItem] = []
        todayItems.reserveCapacity(max(1, orderedRootIDs.count))
        var habitViewModelByID: [UUID: HabitViewModel] = [:]
        habitViewModelByID.reserveCapacity(baseHabits.count)
        var childrenByParentID: [UUID: [Habit]] = [:]
        childrenByParentID.reserveCapacity(parentByChildID.count)
        var stackColorHexByHabitID: [UUID: String] = [:]
        stackColorHexByHabitID.reserveCapacity(baseHabits.count)

        for rootID in orderedRootIDs {
            guard let rootGroup = habitsByRootID[rootID], !rootGroup.isEmpty else { continue }
            let rootHabit = habitByID[rootID] ?? rootGroup[0]
            let stackColorHex = rootHabit.colorHex
            let groupHabitIDs = Set(rootGroup.map(\.id))

            var childrenByParentInGroup: [UUID: [Habit]] = [:]
            childrenByParentInGroup.reserveCapacity(rootGroup.count)
            for child in rootGroup {
                guard let parentID = parentByChildID[child.id], groupHabitIDs.contains(parentID) else { continue }
                childrenByParentInGroup[parentID, default: []].append(child)
            }

            var orderedGroup: [Habit] = []
            orderedGroup.reserveCapacity(rootGroup.count)
            var emittedInGroup: Set<UUID> = []
            emittedInGroup.reserveCapacity(rootGroup.count)
            var queue: [Habit] = [rootHabit]
            var cursor = 0

            while cursor < queue.count {
                let habit = queue[cursor]
                cursor += 1

                guard emittedInGroup.insert(habit.id).inserted else { continue }
                orderedGroup.append(habit)

                if let children = childrenByParentInGroup[habit.id] {
                    for child in children where !emittedInGroup.contains(child.id) {
                        queue.append(child)
                    }
                }
            }

            for habit in rootGroup where !emittedInGroup.contains(habit.id) {
                orderedGroup.append(habit)
            }

            let isStackedGroup = orderedGroup.count > 1
            var orderedViewModels: [HabitViewModel] = []
            orderedViewModels.reserveCapacity(orderedGroup.count)

            for (index, habit) in orderedGroup.enumerated() {
                let parentID = parentByChildID[habit.id]
                let relationText = parentID.flatMap { parentID in
                    habitByID[parentID].map { "After \($0.name)" }
                }

                let hasAdjacentChild: Bool
                if index + 1 < orderedGroup.count {
                    hasAdjacentChild = parentByChildID[orderedGroup[index + 1].id] == habit.id
                } else {
                    hasAdjacentChild = false
                }

                let viewModel = HabitViewModel(
                    habit: habit,
                    id: habit.id,
                    title: habit.name,
                    colorHex: habit.colorHex,
                    relationText: relationText,
                    isStacked: isStackedGroup,
                    stackRootID: isStackedGroup ? rootID : nil,
                    stackColorHex: isStackedGroup ? stackColorHex : nil,
                    hasAdjacentChild: hasAdjacentChild
                )

                orderedViewModels.append(viewModel)
                displayHabitViewModels.append(viewModel)
                displayHabits.append(habit)
                habitViewModelByID[habit.id] = viewModel
                stackColorHexByHabitID[habit.id] = isStackedGroup ? stackColorHex : habit.colorHex

                if let parentID {
                    childrenByParentID[parentID, default: []].append(habit)
                }
            }

            if isStackedGroup,
               let resolvedRootViewModel = orderedViewModels.first(where: { $0.id == rootID }) ?? orderedViewModels.first {
                todayItems.append(
                    .stack(
                        StackViewModel(
                            rootHabit: resolvedRootViewModel,
                            orderedHabits: orderedViewModels,
                            stackColorHex: stackColorHex
                        )
                    )
                )
            } else if let only = orderedViewModels.first {
                todayItems.append(.single(only))
            }
        }

        let displayIndexByHabitID = Dictionary(uniqueKeysWithValues: displayHabits.enumerated().map { ($1.id, $0) })
        for (parentID, children) in childrenByParentID {
            childrenByParentID[parentID] = children.sorted { lhs, rhs in
                let lhsIndex = displayIndexByHabitID[lhs.id] ?? .max
                let rhsIndex = displayIndexByHabitID[rhs.id] ?? .max
                return lhsIndex < rhsIndex
            }
        }

        return HabitStackingSnapshot(
            displayHabits: displayHabits,
            displayHabitViewModels: displayHabitViewModels,
            todayItems: todayItems,
            parentByChildID: parentByChildID,
            childrenByParentID: childrenByParentID,
            habitViewModelByID: habitViewModelByID,
            rootByHabitID: rootByHabitID,
            stackColorHexByHabitID: stackColorHexByHabitID
        )
    }
}
