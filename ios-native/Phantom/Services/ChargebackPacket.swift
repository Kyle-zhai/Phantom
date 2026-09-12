import Foundation

/// Copy-paste packet for a card-issuer billing dispute after the merchant
/// ignores (or refuses) the EFTA/ROSCA letter. Stays on-device; Phantom does
/// not file the chargeback.
enum ChargebackPacket {
    struct Context {
        var merchant: String
        var amount: Double
        var chargeDate: String
        var reason: DisputeReason
        var confirmationNumber: String
        var letterSentAt: Date?
        var fullName: String
    }

    static func script(for ctx: Context) -> String {
        let amount = fmtUSD(ctx.amount)
        let confirm = ctx.confirmationNumber.isEmpty
            ? "I do not have a confirmation number."
            : "Cancellation confirmation: \(ctx.confirmationNumber)."
        let letterLine: String = {
            guard let sent = ctx.letterSentAt else {
                return "I have already written to the merchant requesting a refund."
            }
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US")
            f.dateFormat = "MMMM d, yyyy"
            return "I mailed/emailed the merchant a written refund request on \(f.string(from: sent)). They have not refunded me."
        }()

        return """
        I am disputing a charge of \(amount) dated \(ctx.chargeDate) from \(ctx.merchant).

        \(ctx.reason.chargebackOneLiner) \(confirm) \(letterLine)

        Please open a billing dispute / chargeback under Regulation E (12 C.F.R. § 1005.6) and, if this is a credit card, Regulation Z (15 U.S.C. § 1666). I am notifying you within 60 days of the statement that listed this charge.

        I request a provisional credit and a written outcome. I can provide the merchant letter and any cancellation confirmation I have.

        \(ctx.fullName.isEmpty ? "" : "Name on the card: \(ctx.fullName)\n")
        """.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func checklist(reason: DisputeReason) -> [String] {
        [
            "Have the charge date, amount, and merchant name in front of you.",
            "Call the number on the back of the card — ask for a billing dispute, not general support.",
            "Read the script. Don't skip the statute names; they change how the case is coded.",
            "Ask for a reference number for the dispute and write it down.",
            reason == .cancelledStillCharged || reason == .unauthorizedCharge
                ? "Most issuers honor Regulation E disputes filed within 60 days of the statement date."
                : "If the issuer stalls, file at consumerfinance.gov/complaint — companies have 15 days to respond.",
        ]
    }
}

extension DisputeReason {
    /// One sentence the card issuer's dispute form actually needs.
    var chargebackOneLiner: String {
        switch self {
        case .forgottenTrial:
            return "This was a free trial that converted to a paid subscription without clear notice or my consent (ROSCA / FTC Negative Option Rule)."
        case .autoRenewalNoNotice:
            return "This was an automatic renewal I did not authorize for the new term, and I received no required pre-renewal notice."
        case .cancelledStillCharged:
            return "I cancelled this subscription before the charge date and was billed anyway. That is an unauthorized electronic fund transfer."
        case .unauthorizedCharge:
            return "I never authorized this charge and have no record of signing up."
        case .priceHikeNoNotice:
            return "The merchant raised the price without the required advance notice or my consent to the new terms."
        }
    }
}
