/**
 * Shape of what the variant actions hand back to their forms.
 *
 * It lives here rather than in actions.ts because a "use server" module may
 * only export async functions, and `emptyVariantState` is a plain object.
 */
export type VariantActionState = {
  errors: Record<string, string[]>;
  message: string;
  success: boolean;
};

export const emptyVariantState: VariantActionState = {
  errors: {},
  message: "",
  success: false,
};
