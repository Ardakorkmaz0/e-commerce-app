"use client";

import { useMemo } from "react";

export type AttributeOption = {
  id: number;
  name: string;
  slug: string;
  categories: number[];
  values: { id: number; name: string; slug: string }[];
};

type AttributePickerProps = {
  attributes: AttributeOption[];
  /** Currently selected category id; "" when nothing is chosen yet. */
  categoryId: string;
  selectedValueIds: number[];
};

/**
 * Checkboxes for the filter tags a product carries.
 *
 * Which attributes apply depends on the category chosen in the same form,
 * so the whole list is loaded once on the server and narrowed here as the
 * seller changes the category. Checkbox names are all `attribute_values`,
 * which is what DRF expects for a many-to-many field.
 */
export function AttributePicker({
  attributes,
  categoryId,
  selectedValueIds,
}: AttributePickerProps) {
  const relevant = useMemo(() => {
    const id = Number(categoryId);
    if (!id) return [];
    return attributes.filter((attribute) => attribute.categories.includes(id));
  }, [attributes, categoryId]);

  if (!categoryId) {
    return (
      <p className="form-text mb-0">Choose a category to see its filters.</p>
    );
  }

  if (!relevant.length) {
    return (
      <p className="form-text mb-0">
        This category has no filters yet. An administrator can add them under
        Attributes.
      </p>
    );
  }

  return (
    <div className="d-flex flex-column gap-3">
      {relevant.map((attribute) => (
        <fieldset key={attribute.id}>
          <legend className="attribute-legend">{attribute.name}</legend>
          <div className="d-flex flex-wrap gap-3">
            {attribute.values.map((value) => (
              <div className="form-check" key={value.id}>
                <input
                  className="form-check-input"
                  type="checkbox"
                  name="attribute_values"
                  value={value.id}
                  id={`value-${value.id}`}
                  defaultChecked={selectedValueIds.includes(value.id)}
                />
                <label className="form-check-label" htmlFor={`value-${value.id}`}>
                  {value.name}
                </label>
              </div>
            ))}
          </div>
        </fieldset>
      ))}
    </div>
  );
}
