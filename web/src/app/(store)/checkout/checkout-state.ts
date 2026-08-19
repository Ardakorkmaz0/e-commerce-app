/**
 * What the checkout action hands back to its form.
 *
 * Its own module because a "use server" file may only export async
 * functions, and the initial value is a plain object.
 */
export type CheckoutState = {
  message: string;
  success: boolean;
};

export const emptyCheckoutState: CheckoutState = {
  message: "",
  success: false,
};
