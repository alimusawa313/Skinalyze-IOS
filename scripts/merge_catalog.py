#!/usr/bin/env python3
"""Merge the two legacy product catalogs into one bundled ProductCatalog.json.

- IDs, names, brands, categories and photos come from FinalSkincareProductElFinale.json, because saved scans and
  @AppStorage product slots reference *its* product_id values. Never renumber.
- Ingredients and source links come from SkincareProducts1.json, matched by normalized (name, brand); duplicate
  matches are disambiguated by category.

Usage: python3 -I scripts/merge_catalog.py <final.json> <with_ingredients.json> SharedSources/Catalog/ProductCatalog.json
Prints a short report; exits non-zero if any ID would be lost.
"""
import json
import re
import sys


def key(product):
    name = re.sub(r"\s+", " ", product["name"].strip().lower())
    return name, product["brand_name"].strip().lower()


def main(final_path, ingredients_path, out_path):
    with open(final_path, encoding="utf-8") as f:
        final = json.load(f)
    with open(ingredients_path, encoding="utf-8") as f:
        detailed = json.load(f)

    index = {}
    for product in detailed:
        index.setdefault(key(product), []).append(product)

    merged, unmatched = [], []
    for product in final:
        candidates = index.get(key(product), [])
        same_category = [c for c in candidates if c.get("category") == product.get("category")]
        match = (same_category or candidates or [None])[0]
        if match is None:
            unmatched.append(product["name"])
        merged.append({
            "product_id": product["product_id"],
            "name": product["name"].strip(),
            "brand_name": product["brand_name"].strip(),
            "category": product.get("category"),
            "photo": product.get("photo", ""),
            "link": (match or {}).get("link"),
            "ingredients": (match or {}).get("ingredients") or None,
        })

    if len({p["product_id"] for p in merged}) != len(final):
        sys.exit("ERROR: product_id values lost or duplicated")

    merged.sort(key=lambda p: p["product_id"])
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, separators=(",", ":"))

    with_ingredients = sum(1 for p in merged if p["ingredients"])
    print(f"products: {len(merged)}  with ingredients: {with_ingredients}  unmatched: {unmatched}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
