// FinanceEvent.swift
// SwiftData model used for persistence

import Foundation
import SwiftData

@Model
final class FinanceEvent {
    // Unique stable ID useful for external references and deduplication
    @Attribute(.unique)
    var id: UUID

    var type: String
    var category: String
    var item: String?
    var amount: Double?
    var currency: String?
    var merchant: String?
    var date: Date? // store as Date in SwiftData

    init(
        id: UUID = UUID(),
        type: String,
        category: String,
        item: String? = nil,
        amount: Double? = nil,
        currency: String? = nil,
        merchant: String? = nil,
        date: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.item = item
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.date = date
    }

    convenience init(from dto: FinanceEventDTO, recordingDate: Date) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let eventDate = formatter.date(from: dto.date ?? "") ?? recordingDate

        self.init(
            type: dto.type,
            category: dto.category,
            item: dto.item,
            amount: dto.amount,
            currency: dto.currency,
            merchant: dto.merchant,
            date: eventDate
        )
    }
}
