"use client";

import { useActionState, useState, useTransition } from "react";

import type { AttributeOption } from "@/lib/products";

import { addOption, generateVariants } from "./actions";
import { emptyVariantState, type VariantActionState } from "./variant-state";

type VariantGeneratorProps = {
  slug: string;
  /** Already narrowed to the product's category by the page. */
  attributes: AttributeOption[];
};

/**
 * The seller's copy of the shopper's picker.
 *
 * Deliberately the same swatches and chips the storefront draws, so what
 * the seller ticks here is what the buyer will see. Each group ends with a
 * "+" for typing an option that does not exist yet, and the button at the
 * bottom turns the ticks into variants.
 */
export function VariantGenerator({ slug, attributes }: VariantGeneratorProps) {
  const generateForProduct = generateVariants.bind(null, slug);
  const [state, formAction, pending] = useActionState<
    VariantActionState,
    FormData
  >(generateForProduct, emptyVariantState);

  const [selected, setSelected] = useState<number[]>([]);

  // Which "+" is open: an attribute id, "new" for a whole new group, or
  // null for none. Only one is open at a time so the panel stays calm.
  const [adding, setAdding] = useState<number | "new" | null>(null);
  const [addMessage, setAddMessage] = useState("");
  const [saving, startSaving] = useTransition();

  function toggle(valueId: number) {
    setSelected((current) =>
      current.includes(valueId)
        ? current.filter((id) => id !== valueId)
        : [...current, valueId],
    );
  }

  function submitOption(input: {
    attributeId?: number;
    attributeName?: string;
    name: string;
    swatchColor?: string;
  }) {
    startSaving(async () => {
      const result = await addOption(slug, input);
      setAddMessage(result.message);
      if (result.success) {
        setAdding(null);
      }
    });
  }

  // How many rows the current ticks would produce: the counts per
  // attribute multiplied together, ignoring untouched attributes.
  const combinations = attributes.reduce((total, attribute) => {
    const count = attribute.values.filter((value) =>
      selected.includes(value.id),
    ).length;
    return count ? total * count : total;
  }, 1);

  const willCreate = selected.length ? combinations : 0;

  return (
    <form action={formAction} className="option-picker">
      {attributes.map((attribute) => {
        const isColour = attribute.values.some((value) => value.swatch_color);

        return (
          <fieldset className="variant-group" key={attribute.id}>
            <legend className="variant-group-title">{attribute.name}</legend>

            <div className={isColour ? "variant-swatches" : "variant-chips"}>
              {attribute.values.map((value) => {
                const on = selected.includes(value.id);

                return (
                  <button
                    key={value.id}
                    type="button"
                    className={[
                      isColour ? "variant-swatch" : "variant-chip",
                      on ? "selected" : "",
                    ]
                      .filter(Boolean)
                      .join(" ")}
                    style={
                      isColour
                        ? { backgroundColor: value.swatch_color || "#e2e8f0" }
                        : undefined
                    }
                    aria-pressed={on}
                    title={value.name}
                    onClick={() => toggle(value.id)}
                  >
                    {isColour ? (
                      <span className="visually-hidden">{value.name}</span>
                    ) : (
                      value.name
                    )}
                  </button>
                );
              })}

              <button
                type="button"
                className={isColour ? "variant-swatch add" : "variant-chip add"}
                title={`Add another ${attribute.name.toLowerCase()}`}
                onClick={() =>
                  setAdding(adding === attribute.id ? null : attribute.id)
                }
              >
                +<span className="visually-hidden"> add an option</span>
              </button>
            </div>

            {adding === attribute.id ? (
              <OptionInput
                withColour={isColour}
                saving={saving}
                placeholder={`New ${attribute.name.toLowerCase()}`}
                onCancel={() => setAdding(null)}
                onSubmit={(name, swatchColor) =>
                  submitOption({ attributeId: attribute.id, name, swatchColor })
                }
              />
            ) : null}
          </fieldset>
        );
      })}

      {/* Every selected id travels as its own hidden input, which is what
          DRF expects for a list. */}
      {selected.map((id) => (
        <input key={id} type="hidden" name="value_ids" value={id} />
      ))}

      <div className="mb-3">
        <button
          type="button"
          className="variant-chip add"
          onClick={() => setAdding(adding === "new" ? null : "new")}
        >
          + New option group
        </button>

        {adding === "new" ? (
          <NewGroupInput
            saving={saving}
            onCancel={() => setAdding(null)}
            onSubmit={(attributeName, name, swatchColor) =>
              submitOption({ attributeName, name, swatchColor })
            }
          />
        ) : null}
      </div>

      {addMessage ? (
        <p className="add-to-cart-message ok" role="status" aria-live="polite">
          {addMessage}
        </p>
      ) : null}

      <div className="d-flex align-items-center gap-3">
        <button
          className="btn signin-submit-button"
          type="submit"
          disabled={pending || willCreate === 0}
        >
          {pending
            ? "Building..."
            : willCreate === 0
              ? "Tick some options"
              : `Build ${willCreate} combination${willCreate === 1 ? "" : "s"}`}
        </button>

        {selected.length ? (
          <button
            className="btn btn-link"
            type="button"
            onClick={() => setSelected([])}
          >
            Clear
          </button>
        ) : null}
      </div>

      {state.message ? (
        <p
          className={`add-to-cart-message ${state.success ? "ok" : "error"}`}
          role="status"
          aria-live="polite"
        >
          {state.message}
        </p>
      ) : null}

      {Object.entries(state.errors).map(([field, messages]) => (
        <p className="add-to-cart-message error" key={field}>
          {messages.join(" ")}
        </p>
      ))}
    </form>
  );
}

/** Name, and a colour when the group is drawn as swatches. */
function OptionInput({
  withColour,
  saving,
  placeholder,
  /** Set by the new-group box while its own name is still empty. */
  blocked = false,
  onCancel,
  onSubmit,
}: {
  withColour: boolean;
  saving: boolean;
  placeholder: string;
  blocked?: boolean;
  onCancel: () => void;
  onSubmit: (name: string, swatchColor: string) => void;
}) {
  const [name, setName] = useState("");
  const [colour, setColour] = useState("#4F46E5");
  const [useColour, setUseColour] = useState(withColour);

  return (
    <div className="option-add">
      <input
        className="form-control"
        type="text"
        value={name}
        placeholder={placeholder}
        autoFocus
        maxLength={80}
        onChange={(event) => setName(event.target.value)}
      />

      <div className="form-check">
        <input
          className="form-check-input"
          type="checkbox"
          id={`colour-${placeholder}`}
          checked={useColour}
          onChange={(event) => setUseColour(event.target.checked)}
        />
        <label className="form-check-label" htmlFor={`colour-${placeholder}`}>
          Colour
        </label>
      </div>

      {useColour ? (
        <input
          className="form-control form-control-color"
          type="color"
          value={colour}
          aria-label="Swatch colour"
          onChange={(event) => setColour(event.target.value)}
        />
      ) : null}

      <button
        type="button"
        className="btn btn-sm signin-submit-button"
        disabled={saving || blocked || !name.trim()}
        onClick={() => onSubmit(name, useColour ? colour : "")}
      >
        {saving ? "Adding..." : "Add"}
      </button>
      <button type="button" className="btn btn-sm btn-link" onClick={onCancel}>
        Cancel
      </button>
    </div>
  );
}

/** A group name plus its first value — a group with nothing in it is of no use. */
function NewGroupInput({
  saving,
  onCancel,
  onSubmit,
}: {
  saving: boolean;
  onCancel: () => void;
  onSubmit: (attributeName: string, name: string, swatchColor: string) => void;
}) {
  const [group, setGroup] = useState("");

  return (
    <div className="option-add option-add-group">
      <input
        className="form-control"
        type="text"
        value={group}
        placeholder="Group name, e.g. Bundle"
        autoFocus
        maxLength={80}
        onChange={(event) => setGroup(event.target.value)}
      />

      <OptionInput
        withColour={false}
        saving={saving}
        placeholder="First option, e.g. With game"
        blocked={!group.trim()}
        onCancel={onCancel}
        onSubmit={(name, swatchColor) => onSubmit(group, name, swatchColor)}
      />
    </div>
  );
}
