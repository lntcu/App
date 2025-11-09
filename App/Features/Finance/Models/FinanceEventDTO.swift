// FinanceEventDTO.swift
// Struct used for LLM extraction via @Generable (no persistence)

import Foundation
import FoundationModels

@Generable
struct FinanceEventDTO: Equatable, Codable {
    @Guide(.anyOf(["expense", "income", "transfer"]))
    let type: String

    @Guide(.anyOf([
        "Food & Drink",
        "Transport",
        "Shopping",
        "Bills & Utilities",
        "Entertainment",
        "Health",
        "Income",
        "Transfer",
        "Other"
    ]))
    let category: String

    @Guide(description: "The specific item purchased, if mentioned (e.g., 'Big Mac', 'coffee'). Omit if not mentioned.")
    let item: String?

    @Guide(description: "Total amount, positive number. Omit if not mentioned.")
    let amount: Double?

    @Guide(description: "ISO currency code or symbol. Omit if not mentioned.")
    let currency: String?

    @Guide(description: "Merchant or source name. Omit if not mentioned.")
    let merchant: String?

    @Guide(description: "Primary event date from recording time (ISO-8601). If utterance specifies another date/time explicitly, put that in dateMentioned and leave date as recording time.")
    let date: String?
}
