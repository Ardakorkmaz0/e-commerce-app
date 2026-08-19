# Test cards

This shop does not talk to a bank. Payments go through a stand-in provider
in [`ecommerce/payments.py`](../ecommerce/payments.py), which decides the
outcome from the **last four digits** of the saved card. The same card
therefore behaves the same way every time — the point is that the failure
path can be rehearsed on demand rather than waiting for a random unlucky
click.

> **Never enter a real card number.** These are published test numbers
> that belong to no account and can charge nothing. The project stores no
> card number or security code anywhere — only the brand, the last four
> digits and an expiry — but there is still no reason to type a real one
> into a fake till.

Every number below was checked against the validation in
[`accounts/cards.py`](../accounts/cards.py) and the provider in
`ecommerce/payments.py`.

## Cards that pay

| Number | Brand | Last 4 | Result |
| --- | --- | --- | --- |
| `4242 4242 4242 4242` | Visa | 4242 | Paid |
| `4000 0566 5566 5556` | Visa (debit) | 5556 | Paid |
| `5555 5555 5555 4444` | Mastercard | 4444 | Paid |
| `5200 8282 8282 8210` | Mastercard (debit) | 8210 | Paid |
| `2223 0031 2200 3222` | Mastercard (2-series) | 3222 | Paid |

Any other Visa or Mastercard number that passes the Luhn check also pays —
only the four tails in the next table are refused.

## Cards that fail

| Number | Brand | Last 4 | Message the shopper sees |
| --- | --- | --- | --- |
| `4000 0000 0000 0002` | Visa | 0002 | Your card was declined. |
| `4000 0000 0000 9995` | Visa | 9995 | Your card has insufficient funds. |
| `4000 0000 0000 9987` | Visa | 9987 | Your card was reported lost or stolen. |

A refusal happens **after** the order row is written and **before** any
stock moves, so the shop is left exactly as it was:

- the order stays `pending` with the reason recorded against it,
- no stock is taken,
- the cart is not emptied,
- the order detail page shows the message and invites another card.

## Numbers the form itself rejects

These never reach the provider — the card form turns them away.

| Number | Why |
| --- | --- |
| `3782 822463 10005` | American Express — only Visa and Mastercard are supported |
| `6011 1111 1111 1117` | Discover — same reason |
| `4242 4242 4242 4241` | Fails the Luhn check |

Expiry is checked too: a month and year already in the past is refused
when the card is added, and an expired card is hidden from the checkout
screen rather than being offered and then failing.

## Trying the failure path

1. Sign in, then go to **Profile → Payment methods** and add
   `4000 0000 0000 0002` with any future expiry and any 3-digit code.
2. Put something in the cart and go to checkout.
3. Pick that card and confirm.

You should land on the order page with a red banner reading *"This order
has not been paid for. Your card was declined."* Your cart will still be
full. Add `4242 4242 4242 4242`, start again from the cart, and the same
order goes through.

## Swapping in a real provider

`charge(amount, brand, last4)` returns a small result object with
`succeeded`, `reference` and `failure_reason`. Replacing the fake with a
real integration means rewriting the body of that one function — the
order service calls it and knows nothing else about payments.
