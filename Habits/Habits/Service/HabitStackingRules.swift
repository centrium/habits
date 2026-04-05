import Foundation

struct HabitStackingValidationContext {
    var parentByChildID: [UUID: UUID]
    var goalTypeByHabitID: [UUID: GoalType]
}

enum HabitStackingRules {
    static func validationContext(
        from habits: [Habit],
        parentOverrideByChildID: [UUID: UUID?] = [:],
        goalTypeOverrideByHabitID: [UUID: GoalType] = [:]
    ) -> HabitStackingValidationContext {
        let habitByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })

        var goalTypeByHabitID: [UUID: GoalType] = [:]
        goalTypeByHabitID.reserveCapacity(habits.count)
        for habit in habits {
            goalTypeByHabitID[habit.id] = goalTypeOverrideByHabitID[habit.id] ?? habit.goalType
        }

        var parentByChildID: [UUID: UUID] = [:]
        parentByChildID.reserveCapacity(habits.count)

        for habit in habits {
            let childID = habit.id
            let childGoalType = goalTypeByHabitID[childID] ?? habit.goalType
            guard childGoalType == .frequency else { continue }

            let resolvedParentID = parentOverrideByChildID[childID] ?? habit.triggerHabitID
            guard let parentID = resolvedParentID else { continue }
            guard parentID != childID else { continue }
            guard let parent = habitByID[parentID] else { continue }

            let parentGoalType = goalTypeByHabitID[parentID] ?? parent.goalType
            guard parentGoalType == .frequency else { continue }

            parentByChildID[childID] = parentID
        }

        return HabitStackingValidationContext(
            parentByChildID: parentByChildID,
            goalTypeByHabitID: goalTypeByHabitID
        )
    }

    static func canAssignTrigger(
        childID: UUID,
        childGoalType: GoalType,
        triggerID: UUID?,
        habits: [Habit],
        parentOverrideByChildID: [UUID: UUID?] = [:],
        goalTypeOverrideByHabitID: [UUID: GoalType] = [:]
    ) -> Bool {
        guard childGoalType == .frequency else {
            return triggerID == nil
        }

        guard let triggerID else { return true }
        guard triggerID != childID else { return false }

        let habitByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
        guard let triggerHabit = habitByID[triggerID] else { return false }

        let resolvedTriggerGoalType = goalTypeOverrideByHabitID[triggerID] ?? triggerHabit.goalType
        guard resolvedTriggerGoalType == .frequency else { return false }

        let context = validationContext(
            from: habits,
            parentOverrideByChildID: parentOverrideByChildID,
            goalTypeOverrideByHabitID: goalTypeOverrideByHabitID
        )

        var visited: Set<UUID> = [childID]
        var cursor: UUID? = triggerID

        while let current = cursor {
            guard visited.insert(current).inserted else {
                return false
            }
            cursor = context.parentByChildID[current]
        }

        return true
    }

    @discardableResult
    static func sanitizeInvalidTriggerAssignments(for habits: [Habit]) -> Bool {
        let context = validationContext(from: habits)
        var didChange = false

        for habit in habits {
            if habit.goalType != .frequency, habit.triggerHabitID != nil {
                habit.triggerHabitID = nil
                didChange = true
                continue
            }

            guard let triggerID = habit.triggerHabitID else { continue }
            if context.parentByChildID[habit.id] != triggerID {
                habit.triggerHabitID = nil
                didChange = true
            }
        }

        return didChange
    }
}
