## Context

目前 request schema 仍以平面欄位為主，像 `items.*.id`、`profile.name` 這種欄位沒有被結構化成 OpenAPI schema。另一方面，Laravel 規則中有一批高頻 rule 可以穩定映射，但另一批只能部分映射或需要保留原始語意。

## Goals / Non-Goals

**Goals**
- 補齊高頻 Laravel request rule 的 normalization。
- 將 dotted / wildcard 欄位轉成 nested object / array schema。
- 建立 rule 的分級映射與降級策略。

**Non-Goals**
- 不在這筆 change 處理 response return analyzer。
- 不在這筆 change 處理專案特化的 response adapter。
- 不在這筆 change 引入 review loop gate，只輸出 unresolved 訊號。

## Decisions

### 1. 將 request rule 拆成中介格式後再組 OpenAPI

parser 先產出欄位中介格式，再由 generator 組裝 nested schema。中介格式至少包含：

- 原始欄位名
- normalized 路徑 segments
- 主型別
- required / nullable
- schema constraints
- unresolved rules

### 2. 高頻規則優先精準映射

優先支援：

- `required`
- `nullable`
- `string`
- `integer`
- `numeric`
- `boolean`
- `array`
- `min`
- `max`
- `between`
- `size`
- `digits`
- `email`
- `url`
- `uuid`
- `date`
- `date_format`
- `in`
- `regex`
- `same`
- `confirmed`

### 3. Password builder 拆成 capability

不把 `Password::min()->letters()->numbers()->mixedCase()->symbols()` 當成單一 rule 名稱，而是拆成：

- `min(n)`
- `letters`
- `numbers`
- `mixedCase`
- `symbols`

可映成 OpenAPI 的部分進 schema，不能穩定映的部分進 description / extension。

### 4. dotted / wildcard fields 轉 nested schema

例如：

- `profile.name` -> object property
- `items.*.id` -> array items property

generator 必須輸出真正 nested structure，而不是平面 property key。

### 5. 部分規則只做降級，不硬猜

像 `exists`、`unique`、`required_if`、`required_with`、`sometimes` 等，只保留主型別與可映部分，並把剩餘語意保留到 unresolved metadata。

## Risks / Trade-offs

- wildcard schema 建構會提高 generator 複雜度。
- 某些規則沒有對應 OpenAPI keyword，只能降級成 description 或 extension。

## Migration Plan

1. 補 `FormRequestParser` 的高頻 rule normalization 與 unresolved rule 收集。
2. 在 `OpenApiGenerator` 加入 nested schema builder。
3. 驗證代表性欄位與 wildcard schema 輸出。
