// StoreFactory.swift

import CalendarLib
import CalendarEventKit

func makeCalendarStore() async throws -> any CalendarStore {
    try await AppleCalendarStore.authorized()
}
