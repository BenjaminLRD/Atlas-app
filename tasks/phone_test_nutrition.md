# Phone test: photo to log and nutrition integrity

Install the release APK built from the current work. This is owner verification: widget and unit tests are not device proof. Use a signed-in account with the AI scanner available and an internet connection (except where a case says otherwise).

For every case check four things: what is displayed, what the source note says, which serving quantity is pre-filled, and what happens when you log it.

## 1. A packaged drink with a reliable matching record
Photo of a packaged drink whose brand, name, flavour and size match an Open Food Facts record listed for India (for example a 750 ml Mountain Dew).
- Display: the product name with brand, calories and macros from the record, each with a unit. Nothing says "verified".
- Source: "Open Food Facts" with a link and the note that the data is community-contributed and can be incomplete or inaccurate. Matched as an exact product.
- Serving: the pack size the record states (for example 750 ml), unit ml.
- Logging: logs that amount; the meal card shows the product with no "source not recorded" tag.

## 2. A packaged food with one or more nutrients missing from its record
Photo of a product whose record lacks protein, fibre, sugar or similar.
- Display: missing nutrients show a dash, never 0 g. A note says some values are missing.
- Source: Open Food Facts, same caveat.
- Serving: as in case 1.
- Logging: allowed. The day total for the missing nutrient shows "N+" (a minimum) or a dash if nothing known; if calories are the missing value you are asked to confirm before logging.

## 3. An ambiguous product match
Photo of a product with several similar records (other flavours, sizes or countries).
- Display: a list of candidate products to choose from. Nothing is pre-selected as exact.
- Source: after you choose, "chosen by you" with the Open Food Facts caveat.
- Serving: the pack size of the record you chose; check it fits your pack.
- Logging: only after you choose. Cancelling logs nothing.

## 4. A product not found in the database
Photo of a product that has no record, or with no internet for the lookup.
- Display: a message that no matching record was found (or that the lookup failed), with options to enter the values yourself or use the AI estimate. The estimate is marked as an estimate.
- Source: "AI estimate" or "your entry"; never Open Food Facts.
- Serving: for an AI estimate, a guess that you must confirm or edit; for packaged products no pack size is invented.
- Logging: only after you pick an option. Values the AI left empty show as unknown, and a bare 0 from the AI shows as unknown, not as 0 g.

## 5. A photo whose barcode cannot be read or fails the check digit
Photo where the barcode is blurred, partly covered, or misread.
- Display: no error and no wrong product. The app falls back to searching by name, brand and variant.
- Source: whatever the fallback finds, labelled as in cases 1 to 4. A barcode that was read but looks wrong is never used on its own.
- Serving: as for the fallback result.
- Logging: as for the fallback result.

## 6. A 750 ml package whose per-100-ml values are scaled
Use a record that gives values per 100 ml. Note the per-100-ml calories (say 40 kcal).
- Display: values for the amount, for example 300 kcal for 750 ml; the reference reads "per 100 ml" in the details.
- Source: Open Food Facts.
- Serving: 750 ml. Changing to 250 ml gives one third. Selecting grams for a per-100-ml product is not offered.
- Logging: the logged calories equal the per-100-ml value times 7.5.

## 7. Logging a food with missing protein and checking daily totals
Log the food from case 2 (protein unknown), then add another food with known protein.
- Display: the protein total shows a minimum such as "14+g", never an exact number that looks complete. With only unknown-protein foods it shows a dash. The progress bar fills only by the known amount.
- Source: unchanged.
- Serving: unchanged.
- Logging: the weight-goal banner and coach messages do not say how much protein is left; the Protein Performance card shows a dash with a note until a day with complete protein exists.

## 8. An older meal whose source was not recorded
Open a meal logged before this update.
- Display: the numbers as they were, with "source not recorded" on the meal card. Not labelled verified.
- Source: unrecorded.
- Serving: as logged.
- Logging: nothing changes; you can still delete or edit it.
