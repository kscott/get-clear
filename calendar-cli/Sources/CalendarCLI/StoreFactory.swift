// StoreFactory.swift

import CalendarEventKit
import CalendarLib

func makeCalendarStore() async throws -> any CalendarStore {
    try await AppleCalendarStore.authorized()
}
