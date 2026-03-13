## Context

目前候選推測已具備 from-commit 範圍與 dependency 關聯能力，但 `Service` 變更仍可能以檔案粒度擴散，造成大量不必要的 `updated` endpoint。這會直接增加人工審核成本，並降低使用者對候選清單的信任度。

系統限制：
- 維持 shell 為主，不依賴 LLM。
- 維持既有 guided-sync 互動流程（先候選、再確認、再產生/同步）。
- 可接受保守漏報少量低風險候選，但需明顯降低誤報。

## Goals / Non-Goals

**Goals:**
- 將 `updated` 推測從檔案級提升到 method/action 級。
- Service 變更時，僅標記實際呼叫被改 method 的 `Controller@action` 對應 endpoint。
- Request/Resource/Exception 的 `updated` 判定也以 action 綁定為主，而非單純類名命中。
- 候選輸出增加可解釋信號，讓使用者快速判斷為何被標記。

**Non-Goals:**
- 本次不引入 PHP AST 套件或外部 parser。
- 本次不改 Apidog 同步策略與 conflict policy。
- 本次不把候選推測改成全量 OpenAPI 重建流程。

## Decisions

1. 以 `git diff --unified=0` 萃取 method 變更為核心訊號。
- 做法：對變更檔（特別是 Service/Controller）先抽 hunk，再映射到 method 名稱。
- 理由：相較檔案層級，method 粒度能直接減少噪音。
- 替代方案：維持檔案層級 + 人工過濾；缺點是清單過大且不穩定。

2. 建立三段式映射：`Service::method -> Controller@action -> route endpoint`。
- 做法：從 controller method source 抽出 service 調用（`$this->xxxService->method(...)` 或明確型別屬性調用），只命中被改 method。
- 理由：避免同一 service 類別下未受影響 action 被一併標記。
- 替代方案：只要 controller 引用了該 service 類別就全標；缺點是誤報仍高。

3. Request/Resource/Exception 採 action 綁定，而非全域 grep。
- 做法：解析每個 route 對應 action 的 method source，判定是否實際引用該 Request/Resource/Exception（含 catch/throw/use）。
- 理由：將 dependency 判定範圍鎖在 action 內，降低跨檔同名誤命中。
- 替代方案：維持 controller 全檔掃描；缺點是 action 間互相污染。

4. 候選輸出加入結構化命中原因。
- 做法：在 `signals` 增加 `service_method_hit`、`controller_action_hit`、`request_bound_hit`、`exception_flow_hit` 等欄位。
- 理由：提升可解釋性，讓使用者快速審核並回饋誤判來源。
- 替代方案：只保留文字 `reason`；缺點是不利除錯與迭代規則。

## Risks / Trade-offs

- [Risk] 動態呼叫或反射（如 `{$method}`）無法準確 method 映射。
  -> Mitigation：此類候選降為 `low confidence` 並標記 `missing_fields`。
- [Risk] 跨層委派（controller -> serviceA -> serviceB）可能漏抓。
  -> Mitigation：第一階段僅保證一跳映射；多跳依賴列入後續增強。
- [Risk] method 抽取過於嚴格可能造成漏報。
  -> Mitigation：保留 `enhanced` 模式，必要時可退回較寬鬆規則並人工確認。
- [Risk] 解析邏輯變複雜，執行時間上升。
  -> Mitigation：維持 cache（service parse cache）並只對候選 action 做深度解析。

## Migration Plan

1. 更新 `infer-candidates.sh`：新增 method 變更抽取與 service->action 精準映射規則。
2. 擴充 `parse-controller.sh`：輸出 action 內 service method 調用清單。
3. 調整 dependency 判定：Request/Resource/Exception 改為 action-bound 檢查。
4. 更新 `SKILL.md`：補充新判定規則與 debug 欄位說明。
5. 以實際專案 commit 範圍做回歸，確認候選數量與準確率改善。

Rollback：
- 回退 `infer-candidates.sh` 與 parser 變更到上一版 FQCN 索引版本。
- 保留產生的 debug/candidates 輸出，作為下一輪規則修正依據。

## Open Questions

- 是否要加入可設定參數（如 `--service-impact-mode=method|file`）以便快速切換容錯策略？
- 是否要在結果中額外顯示「被排除的 endpoint 數量」，方便檢視精準化效果？
