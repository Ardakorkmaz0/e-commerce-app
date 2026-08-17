"use client";

import { useActionState } from "react";

import {
  deleteAddress,
  selectAddress,
  type AddressActionState,
} from "./actions";

const initialState: AddressActionState = {
  message: "",
  success: false,
};

type AddressCardActionsProps = {
  addressId: number;
  isSelected: boolean;
};

export function AddressCardActions({
  addressId,
  isSelected,
}: AddressCardActionsProps) {
  const selectAction = selectAddress.bind(null, addressId);
  const deleteAction = deleteAddress.bind(null, addressId);
  const [selectState, selectFormAction, selectPending] = useActionState(
    selectAction,
    initialState,
  );
  const [deleteState, deleteFormAction, deletePending] = useActionState(
    deleteAction,
    initialState,
  );
  const state = deleteState.message ? deleteState : selectState;

  return (
    <div className="address-card-actions">
      {!isSelected ? (
        <form action={selectFormAction}>
          <button
            className="btn btn-sm btn-outline-primary"
            type="submit"
            disabled={selectPending || deletePending}
          >
            {selectPending ? "Selecting..." : "Set as delivery address"}
          </button>
        </form>
      ) : null}

      <form action={deleteFormAction}>
        <button
          className="btn btn-sm btn-link text-danger"
          type="submit"
          disabled={selectPending || deletePending}
          onClick={(event) => {
            if (!window.confirm("Delete this address?")) {
              event.preventDefault();
            }
          }}
        >
          {deletePending ? "Deleting..." : "Delete"}
        </button>
      </form>

      {state.message ? (
        <p
          className={`address-action-message ${state.success ? "success" : "error"}`}
          role={state.success ? "status" : "alert"}
          aria-live="polite"
        >
          {state.message}
        </p>
      ) : null}
    </div>
  );
}
