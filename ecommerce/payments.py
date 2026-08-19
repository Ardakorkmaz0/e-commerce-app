"""
A stand-in for a payment provider.

It takes no card number — there is none stored anywhere in this project —
and decides from the last four digits of the saved card. Real providers
publish test cards that always fail so that the unhappy path can be
rehearsed on demand; this copies that idea rather than failing at random,
which would make the same click pass one minute and fail the next.
"""

from dataclasses import dataclass
from decimal import Decimal
from uuid import uuid4


#: Last four digits that always fail, and why. Everything else succeeds.
#: These are the tails of the published test numbers, so a card added with
#: 4000 0000 0000 0002 behaves the way it would at a real provider.
DECLINED_CARDS = {
    "0002": "Your card was declined.",
    "9995": "Your card has insufficient funds.",
    "9987": "Your card was reported lost or stolen.",
}


@dataclass(frozen=True)
class PaymentResult:
    succeeded: bool
    reference: str
    failure_reason: str = ""


def charge(*, amount: Decimal, brand: str, last4: str) -> PaymentResult:
    """
    Charges a saved card once, in full.

    Only single payments exist here: the amount goes through in one go or
    not at all, which is what the checkout screen offers.
    """
    reference = f"pay_{uuid4().hex[:12]}"

    if amount <= 0:
        return PaymentResult(
            succeeded=False,
            reference=reference,
            failure_reason="Nothing to charge.",
        )

    reason = DECLINED_CARDS.get(last4)
    if reason:
        return PaymentResult(
            succeeded=False, reference=reference, failure_reason=reason
        )

    return PaymentResult(succeeded=True, reference=reference)
