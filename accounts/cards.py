"""
Card validation and tokenisation.

Everything here works on a number that lives only for the length of one
request. Nothing in this module writes a card number to the database, to a
log, or to any other durable place — see `tokenise` for what survives.
"""

import re
import secrets
from datetime import date

from .models import PaymentMethod


class CardError(ValueError):
    """Raised when a card cannot be accepted."""


def normalise(card_number):
    """Strips the spaces and hyphens people naturally type."""
    return re.sub(r"[ -]", "", card_number or "")


def passes_luhn(digits):
    """
    The checksum every card number carries.

    It catches typos and obviously invented numbers before anything is
    stored; it says nothing about whether the card exists or has funds.
    """
    total = 0
    for index, character in enumerate(reversed(digits)):
        value = int(character)
        if index % 2 == 1:
            value *= 2
            if value > 9:
                value -= 9
        total += value
    return total % 10 == 0


def detect_brand(digits):
    """
    Brand from the issuer identification number.

    Only Visa and Mastercard are supported, so anything else is rejected
    rather than saved under a brand the store cannot charge.
    """
    if re.fullmatch(r"4\d{12}(\d{3})?(\d{3})?", digits):
        return PaymentMethod.VISA

    # Mastercard covers the classic 51-55 range plus the 2221-2720 range
    # added in 2017.
    if re.fullmatch(r"5[1-5]\d{14}", digits):
        return PaymentMethod.MASTERCARD
    if re.fullmatch(r"2(2[2-9]\d|[3-6]\d{2}|7[01]\d|720)\d{12}", digits):
        return PaymentMethod.MASTERCARD

    return None


def validate_expiry(exp_month, exp_year):
    if not 1 <= exp_month <= 12:
        raise CardError("Enter a month between 1 and 12.")

    today = date.today()
    if (exp_year, exp_month) < (today.year, today.month):
        raise CardError("This card has expired.")

    # A card issued more than 20 years out is a typo, not a card.
    if exp_year > today.year + 20:
        raise CardError("Enter a valid expiry year.")


def validate_security_code(code, brand):
    """
    Checked for shape only, then dropped.

    The security code is never stored — storing it is forbidden even for
    providers that are allowed to store the number itself.
    """
    if not re.fullmatch(r"\d{3}", code or ""):
        raise CardError("Enter the three digit security code.")


def tokenise(card_number):
    """
    Turns a card number into the parts that are safe to keep.

    Returns the brand, the last four digits and an opaque token. The number
    itself is not returned and not retained; a real integration would get
    the token from the payment provider instead of minting one here.
    """
    digits = normalise(card_number)

    if not digits.isdigit():
        raise CardError("Enter the card number using digits only.")
    if not 12 <= len(digits) <= 19:
        raise CardError("Enter a valid card number.")
    if not passes_luhn(digits):
        raise CardError("This card number is not valid.")

    brand = detect_brand(digits)
    if brand is None:
        raise CardError("Only Visa and Mastercard are supported.")

    return {
        "brand": brand,
        "last4": digits[-4:],
        "provider_token": f"tok_{secrets.token_hex(16)}",
    }
