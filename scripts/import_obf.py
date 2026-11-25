#!/usr/bin/env python3
"""Add face-care products from Open Beauty Facts (https://world.openbeautyfacts.org) to the bundled catalog.

Open Beauty Facts data is under the Open Database License (ODbL) and product photos under CC BY-SA; the app credits
"Product data: Open Beauty Facts" wherever imported products are shown.

What it does
- Searches the public API by brand (brands sold in Indonesia plus well-known international ones) and by category.
- Keeps only face-care products with a usable INCI ingredient list, sorts each into one of the app's categories
  (Cleanser, Toner, Moisturizer, Sunscreen, Serum, Exfoliant, Spot care, Mask, Eye care) and skips body, hair,
  lip, make-up and the like.
- Never touches existing products: their IDs are referenced by saved scans and shelf slots. New products get IDs
  from 10001 upward, remembered per barcode in scripts/data/obf_ids.json so a re-run keeps every ID stable.
- Skips anything already in the catalog (same brand + name) or already imported (same barcode).
- Responses are cached in ~/.cache/skinalyze-obf, so a re-run is fast and gentle on the service. Search requests
  are spaced 6.5 s apart (Open Beauty Facts asks for at most 10 searches a minute).

Only search terms (brand and category names) are sent. Nothing about the user or the app's data leaves the Mac.

Usage (from the repo root):
    python3 -I scripts/import_obf.py                 # fetch, then write SharedSources/Catalog/ProductCatalog.json
    python3 -I scripts/import_obf.py --dry-run       # fetch and report only; writes build/obf-preview.json
    python3 -I scripts/import_obf.py --offline       # use only cached responses
Takes ~15-20 minutes the first time.
"""
import argparse
import hashlib
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "SharedSources", "Catalog", "ProductCatalog.json")
ID_MAP = os.path.join(ROOT, "scripts", "data", "obf_ids.json")
PREVIEW = os.path.join(ROOT, "build", "obf-preview.json")
CACHE = os.path.join(os.path.expanduser("~"), ".cache", "skinalyze-obf")

API = "https://world.openbeautyfacts.org/api/v2/search"
USER_AGENT = "SkinalyzeCatalogImport/1.0 (iOS skincare tracker; catalog build script)"
FIELDS = ",".join([
    "code", "product_name", "product_name_en", "product_name_id", "brands", "categories_tags",
    "ingredients_text", "ingredients_text_en", "ingredients_text_id", "image_front_url",
])
PAGE_SIZE = 100
SEARCH_GAP_SECONDS = 6.5
FIRST_NEW_ID = 10001

# Brand tags as Open Beauty Facts spells them (lowercase, hyphenated). Indonesian brands first.
BRANDS = [
    "wardah", "emina", "make-over", "somethinc", "skintific", "azarine", "scarlett", "avoskin", "whitelab",
    "npure", "hanasui", "glad2glow", "safi", "sariayu", "viva", "pixy", "y-o-u", "elsheskin", "originote",
    "the-originote", "erha", "erhair", "hada-labo", "senka", "biore", "garnier", "pond-s", "ponds", "nivea",
    "vaseline", "cetaphil", "cerave", "la-roche-posay", "avene", "bioderma", "vichy", "eucerin", "neutrogena",
    "simple", "the-ordinary", "the-inkey-list", "paula-s-choice", "cosrx", "some-by-mi", "innisfree", "laneige",
    "skin1004", "anua", "round-lab", "beauty-of-joseon", "isntree", "torriden", "purito", "klairs",
    "dear-klairs", "missha", "etude", "etude-house", "skinfood", "mediheal", "dr-jart", "banila-co", "heimish",
    "axis-y", "numbuzin", "aestura", "illiyoon", "kiehl-s", "clinique", "olay", "l-oreal-paris", "loreal-paris",
    "the-body-shop", "nature-republic", "clean-clear", "mario-badescu", "acnes", "himalaya", "bioaqua",
    "skin-aqua", "anessa", "sunplay", "kose", "melano-cc", "hatomugi", "curel", "minon", "uriage", "svr",
    "a-derma", "caudalie", "nuxe", "garnier-skinactive", "first-aid-beauty", "krave-beauty", "glow-recipe",
]

# Category tags to sweep as well (brands not listed above). Unknown tags simply return nothing.
CATEGORY_TAGS = [
    "en:face-creams", "en:day-creams", "en:night-creams", "en:moisturizers", "en:face-moisturizers",
    "en:sunscreens", "en:sun-protection", "en:facial-cleansers", "en:face-cleansers", "en:face-washes",
    "en:micellar-waters", "en:toners", "en:facial-toners", "en:face-serums", "en:serums", "en:face-masks",
    "en:eye-creams", "en:exfoliants", "en:face-scrubs", "en:acne-treatments",
]
MAX_PAGES = 4

# Out of scope: body, hair, lips, make-up, fragrance, men's shaving, baby, hands and feet, oral care.
EXCLUDE = re.compile(
    r"\b(body|hair|shampoo|conditioner|scalp|deodorant|antiperspirant|lip|lips|lipstick|lipbalm|lip balm|mascara|"
    r"eyeliner|eyeshadow|eye shadow|foundation|concealer|powder|blush|bronzer|primer|cushion|bb cream|cc cream|"
    r"tinted|nail|perfume|parfum|eau de|cologne|fragrance mist|shower|bath|soap bar|hand|hands|foot|feet|baby|"
    r"kid|kids|kinder|enfant|enfants|children|child|bébé|shaving|shave|after shave|aftershave|toothpaste|mouthwash|"
    r"tattoo|tanning|self-tan|self tan|bronz\w*|after sun|aftersun|après-soleil|apres soleil|insect|repellent|"
    r"intimate|feminine|massage|candle|elseve|elvive|elivive|combing|leave-in|sugar scrub|salt scrub|coffee scrub|"
    r"serum-in-lotion|serum burst|körper|corps|cuerpo|corpo|lichaam|kropp\w*|gluta-hya|sonnenmilch|sun spray|"
    r"sonnenspray|family|familie|famille|sport|beach|leg|legs|douche|dusch\w*|elvital|pediatric\w*|"
    r"losyonu|vücut|bodylotion|jelly|kiss of petals|pretty as a peach|cocoa)\b"
)
# Checked in order: the first rule that matches decides the category.
RULES = [
    # Make-up removers (eye ones too) are cleansers.
    ("Cleanser", r"\b(d[ée]maquill\w*|desmaquill\w*|remover|micella\w*|biphas\w*)"),
    ("Mask", r"\b(masks?|masker|masques?|maske|maskesi|maschera|mascarilla|sheet|eye pads?)\b"),
    ("Eye care", r"\b(eye|eyes|under-eye|regard|yeux|olhos|ojos|augen\w*|occhi)\b"),
    ("Sunscreen", r"\b(spf|sunscreen|sun screen|sunblock|sun block|sun protect\w*|sun cream|sun milk|sun gel|"
                  r"sun essence|sun stick|uv protect\w*|uv aqua|uv shield|uv defen\w*|anthelios|photoderm|"
                  r"en:sunscreens|en:sun-protection)\b"),
    # Acne spot products only: "dark spot" serums are serums.
    ("Spot care", r"\b(drying lotion|spot treatment|spot gel|spot corrector|spot patch\w*|pimple|persa gel|acne gel|"
                  r"acne treatment|blemish (gel|stick|patch\w*)|(acne|jerawat)\b.*\bpatch\w*)"),
    ("Exfoliant", r"\b(exfolia\w*|peeling|peel|scrub|gommage|aha|bha|aha/bha|aha bha|glycolic|lactic acid|mandelic|salicylic)\b"),
    ("Cleanser", r"\b(cleans\w*|face wash|facial wash|facial foam|face foam|foam|micellar|wash|nettoyant\w*|"
                 r"démaquillant\w*|reinigung\w*|limpiador\w*|en:facial-cleansers|"
                 r"en:face-cleansers|en:face-washes|en:micellar-waters)\b"),
    ("Toner", r"\b(toner|tonic|toning|en:toners|en:facial-toners)\b"),
    ("Serum", r"\b(serum|ampoule|ampule|essence|en:face-serums|en:serums)\b"),
    ("Moisturizer", r"\b(moistu?ri[sz]\w*|cream|creme|crème|gel cream|emulsion|lotion|day cream|night cream|"
                    r"sleeping|hydrat\w*|aloe|soothing gel|en:face-creams|en:day-creams|en:night-creams|en:moisturizers|"
                    r"en:face-moisturizers)\b"),
    # Named by an active and its strength ("Retinol 0.2% in Squalane", "Niacinamide 10% + Zinc 1%").
    ("Serum", r"\d+(\.\d+)?\s?%"),
]
RULES = [(name, re.compile(pattern)) for name, pattern in RULES]
# Lotions, washes, soaps, scrubs, milks, sprays and oils are body products as often as face ones; for those (and
# for every sunscreen) ask for a sign it's for the face.
AMBIGUOUS = re.compile(r"\b(lotion|wash|soap|scrub|milk|lait|spray|oil)\b")
FACE_SIGNAL = re.compile(r"\b(face|facial|wajah|muka|acne|jerawat|pore|pori|visage|gesicht|viso|rostro|yüz|"
                         r"cara|ansikte|kasvo|gezicht|en:face\w*)")
# Brands that mostly make body care: their products count only when they say they're for the face.
BODY_FIRST_BRANDS = {"vaseline", "dove", "palmer's", "jergens"}
# Face sunscreens that don't say "face": the light, face-only formats.
FACE_SUN_FORMAT = re.compile(r"\b(fluid|fluide|essence|uv aqua|gel cream|anthelios|uvmune|invisible|matt\w*|serum)\b")
# Ingredient lists that aren't INCI (translated names the matcher can't read) or aren't a list at all.
NOT_INCI = re.compile(r"(?i)\b(água|ácido|acido|glicerina|extrato|extracto|óleo|aceite|sulfato de|wasser|huile de|"
                      r"here are|as can be read|from the image|ingredient list)\b")
# One spelling per brand.
BRAND_NAMES = {
    "loreal": "L'Oréal Paris", "loreal paris": "L'Oréal Paris", "l oreal": "L'Oréal Paris",
    "l oreal paris": "L'Oréal Paris", "nivea sun": "Nivea", "nivea men": "Nivea", "biore": "Biore",
    "st ives": "St. Ives", "himalaya": "Himalaya", "garnier skinactive": "Garnier", "la roche posay": "La Roche-Posay",
    "cerave": "CeraVe", "the ordinary": "The Ordinary",
}
# Kept upper-case when a name is re-cased.
KEEP_UPPER = {"spf", "aha", "bha", "pha", "uv", "uva", "uvb", "pa", "svr", "sas", "nyc", "spf50", "spf30", "spf50+",
              "spf30+", "spf15", "b5", "c", "e", "q10", "dna", "lha"}


def fetch(params, offline):
    os.makedirs(CACHE, exist_ok=True)
    query = urllib.parse.urlencode(params)
    path = os.path.join(CACHE, hashlib.sha1(query.encode()).hexdigest() + ".json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    if offline:
        return None
    request = urllib.request.Request(f"{API}?{query}", headers={"User-Agent": USER_AGENT})
    for attempt in range(3):
        try:
            time.sleep(SEARCH_GAP_SECONDS)
            with urllib.request.urlopen(request, timeout=60) as response:
                data = json.load(response)
            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f)
            return data
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            print(f"  retry {attempt + 1} after error: {error}", file=sys.stderr)
            time.sleep(20 * (attempt + 1))
    return None


def sweep(offline):
    queries = [("brands_tags", brand) for brand in BRANDS] + [("categories_tags", tag) for tag in CATEGORY_TAGS]
    found = {}
    for number, (field, value) in enumerate(queries, 1):
        for page in range(1, MAX_PAGES + 1):
            data = fetch({field: value, "fields": FIELDS, "page": page, "page_size": PAGE_SIZE}, offline)
            products = (data or {}).get("products") or []
            for product in products:
                code = str(product.get("code") or "").strip()
                if code:
                    found.setdefault(code, product)
            print(f"[{number}/{len(queries)}] {field}={value} page {page}: {len(products)} (total {len(found)})")
            if len(products) < PAGE_SIZE:
                break
    return found


def latin_share(text):
    letters = [c for c in text if c.isalpha()]
    return sum(1 for c in letters if ord(c) < 0x250) / len(letters) if letters else 0


def tidy_case(text):
    """All-caps (longer than an acronym) or all-lowercase text in title case, keeping SPF, AHA and the like."""
    if not (text.islower() or (text.isupper() and len(text) > 4)):
        return text
    return " ".join(word.upper() if word.lower() in KEEP_UPPER else word.capitalize() for word in text.split(" "))


def clean_name(product):
    for key in ("product_name_en", "product_name", "product_name_id"):
        name = re.sub(r"\s+", " ", html.unescape(product.get(key) or "")).strip(" -–—")
        if len(name) >= 3 and latin_share(name) > 0.9:
            return tidy_case(name)[:120]
    return None


def clean_brand(product):
    brand = html.unescape((product.get("brands") or "").split(",")[0]).strip()
    if len(brand) < 2 or latin_share(brand) < 0.9:
        return None
    ascii_key = re.sub(r"[^a-z0-9]+", " ", brand.lower().replace("é", "e").replace("è", "e")).strip()
    return BRAND_NAMES.get(ascii_key) or tidy_case(brand)


def tidy_ingredient(item):
    """An all-caps INCI name in title case ("CETEARYL ALCOHOL" -> "Cetearyl Alcohol"); codes like PEG-40 stay."""
    if not item.isupper():
        return item

    def part(text):
        return text if len(text) <= 3 or any(c.isdigit() for c in text) else text.capitalize()

    return re.sub(r"[A-Z0-9]+", lambda match: part(match.group(0)), item)


def clean_ingredients(product):
    for key in ("ingredients_text_en", "ingredients_text", "ingredients_text_id"):
        text = (product.get(key) or "").strip()
        if not text:
            continue
        if NOT_INCI.search(text):
            continue
        text = html.unescape(text)
        text = re.sub(r"(?i)^.*?\b(ingredients?|komposisi|bahan|ingrédients)\s*(\(inci\))?\s*:\s*", "", text, count=1)
        text = re.sub(r"^[\d\s./-]+(?=[A-Za-z])", "", text)  # batch numbers printed before the list
        text = re.sub(r"(?i)\b(may contain|dapat mengandung|peut contenir)\b.*$", "", text)
        text = text.replace("\n", ", ").replace(";", ",").replace("•", ",").replace("·", ",")
        text = re.sub(r"_", "", text)  # Open Beauty Facts marks allergens as _name_
        items = [re.sub(r"\s+", " ", item).strip(" .*") for item in text.split(",")]
        items = [item for item in items if item]
        long_items = sum(1 for item in items if len(item) > 80)
        if len(items) < 5 or long_items > 1 or latin_share(" ".join(items)) < 0.95:
            continue
        return ", ".join(tidy_ingredient(item)[:80] for item in items)[:4000]
    return None


def classify(name, tags, brand=""):
    haystack = f"{name} {' '.join(tags)}".lower()
    if EXCLUDE.search(name.lower()) or any(re.search(r"make-?up|mascara|lip|nail", tag) and "remover" not in tag
                                           for tag in tags):
        return None
    face = FACE_SIGNAL.search(haystack)
    if brand.lower() in BODY_FIRST_BRANDS and not face:
        return None
    for category, pattern in RULES:
        if pattern.search(haystack):
            if category == "Sunscreen" and not (face or FACE_SUN_FORMAT.search(name.lower())):
                return None
            if AMBIGUOUS.search(name.lower()) and not face:
                return None
            return category
    return None


def valid_barcode(code):
    """EAN-8, UPC-A or EAN-13 with a correct check digit (Open Beauty Facts also holds internal codes)."""
    if not code.isdigit() or len(code) not in (8, 12, 13):
        return None
    digits = [int(c) for c in code]
    body = digits[:-1][::-1]
    total = sum(d * (3 if i % 2 == 0 else 1) for i, d in enumerate(body))
    return code if (10 - total % 10) % 10 == digits[-1] else None


def key(name, brand):
    return re.sub(r"[^a-z0-9]+", " ", f"{brand} {name}".lower()).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="report and write build/obf-preview.json only")
    parser.add_argument("--offline", action="store_true", help="use cached responses only")
    args = parser.parse_args()

    with open(CATALOG, encoding="utf-8") as f:
        catalog = json.load(f)
    legacy = [p for p in catalog if p.get("source") != "Open Beauty Facts"]
    known = {key(p["name"], p["brand_name"]) for p in legacy}
    ids = {}
    if os.path.exists(ID_MAP):
        with open(ID_MAP, encoding="utf-8") as f:
            ids = json.load(f)
    next_id = max([FIRST_NEW_ID - 1] + list(ids.values())) + 1

    found = sweep(args.offline)
    imported, seen, rejected = [], set(), {}

    def reject(reason):
        rejected[reason] = rejected.get(reason, 0) + 1

    for code, product in sorted(found.items()):
        name, brand = clean_name(product), clean_brand(product)
        if not name or not brand:
            reject("no usable name or brand")
            continue
        category = classify(name, product.get("categories_tags") or [], brand)
        if not category:
            reject("not face care / unknown type")
            continue
        ingredients = clean_ingredients(product)
        if not ingredients:
            reject("no usable ingredient list")
            continue
        product_key = key(name, brand)
        if product_key in known or product_key in seen:
            reject("already in the catalog")
            continue
        seen.add(product_key)
        if code not in ids:
            ids[code] = next_id
            next_id += 1
        imported.append({
            "product_id": ids[code],
            "name": name,
            "brand_name": brand,
            "category": category,
            "photo": product.get("image_front_url") or "",
            "link": f"https://world.openbeautyfacts.org/product/{code}",
            "ingredients": ingredients,
            "barcode": valid_barcode(code),
            "source": "Open Beauty Facts",
        })

    merged = sorted(legacy + imported, key=lambda p: p["product_id"])
    if len({p["product_id"] for p in merged}) != len(merged):
        sys.exit("ERROR: duplicate product_id — nothing written")

    by_category = {}
    for product in imported:
        by_category[product["category"]] = by_category.get(product["category"], 0) + 1
    brands = len({p["brand_name"].lower() for p in imported})
    print(f"\nexisting products kept: {len(legacy)}")
    print(f"imported from Open Beauty Facts: {len(imported)} across {brands} brands")
    for category, count in sorted(by_category.items(), key=lambda item: -item[1]):
        print(f"  {category}: {count}")
    print("skipped:", ", ".join(f"{reason} {count}" for reason, count in sorted(rejected.items())))

    if args.dry_run:
        os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
        with open(PREVIEW, "w", encoding="utf-8") as f:
            json.dump(imported, f, ensure_ascii=False, indent=1)
        print(f"preview: {PREVIEW} (catalog not changed)")
        return
    os.makedirs(os.path.dirname(ID_MAP), exist_ok=True)
    with open(ID_MAP, "w", encoding="utf-8") as f:
        json.dump(ids, f, indent=0, sort_keys=True)
    with open(CATALOG, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, separators=(",", ":"))
    print(f"wrote {CATALOG} ({len(merged)} products)")


if __name__ == "__main__":
    main()
