---
description: "Generate .dto file (Views and Inputs) for an existing Jimmer entity"
---

# DTO Generator — STRICT WORKFLOW

## Step 1: Read the entity

Read the entity interface. Note fields, types, associations, nullability, @Version.

## Step 2: Determine which DTOs to generate

Read the user's request. Count the DTO names mentioned. Generate exactly that number, with exactly those names.

Examples:
- "a View" → one View
- "a ListView" → one ListView
- "CreateInput and UpdateInput" → two Inputs
- "CRUD DTOs" → CreateInput + UpdateInput + one View

## Step 3: Write the .dto file

**File location:** `src/main/dto/{package path}/{EntityName}.dto`

**Syntax reference:** `instructions/jimmer-dto-language.md`

### Scalar fields

Start with `#allScalars`. Use `-fieldName` to exclude what you don't need.

```
ArticleView {
    #allScalars
    -content
    -internalNotes
}
```

For `input` blocks where you include only a small explicit subset, list only those fields instead.

### Nested associations

Each field of a nested block on its own line:

```
ArticleView {
    #allScalars
    category {
        id
        name
    }
}
```

## Step 4: Compile

Run `ls gradlew mvnw 2>/dev/null` in the project root and use the result:
- `gradlew` → `./gradlew compileJava` / `./gradlew compileKotlin`
- `mvnw` → `./mvnw compile`
- neither → `gradle compileJava` / `mvn compile`

Fix errors. Done.
