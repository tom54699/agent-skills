## 1. 範本

- [x] 1.1 `assets/templates/deploy.sh`：release 目錄、mkdir 部署鎖、設定檢查、固定版本 pull、migrate job、切換與啟動、health check（container 狀態、image tag、外部 URL）、自動回滾、`rollback` 指令、清理舊 release；相容 bash 3.2
- [x] 1.2 `assets/templates/docker-compose.yml`：固定 `name:`、`${RELEASE_TAG}`、前後端與 `migrate` 服務、named volume、內部網路、health check、port 綁 127.0.0.1
- [x] 1.3 `assets/templates/github-workflow.yml`：test → build matrix（各自 cache、`latest` 與 `sha-<commit>`）→ deploy（`DEPLOY_ENABLED`、缺 secret 失敗、known_hosts、不取消進行中的部署、同步到新 release 目錄）
- [x] 1.4 `assets/templates/nginx.conf.template` 與 `nginx-bootstrap.conf.template`（envsubst 只替換指定變數）
- [x] 1.5 `assets/templates/env.example`

## 2. Skill 與 references

- [x] 2.1 `SKILL.md`：觸發詞、核心規則、授權範圍、三種模式的流程、部署紀錄與 secrets 規則、各階段規則、輸出格式
- [x] 2.2 `references/first-certificate.md`：第一次申請憑證的 HTTP bootstrap 流程與續期驗證
- [x] 2.3 `references/migrations-and-rollback.md`
- [x] 2.4 `references/optional-modules.md`：共享 PostgreSQL、Redis、向量資料庫、部署後同步 job、監控
- [x] 2.5 `references/oracle-cloud.md`
- [x] 2.6 `references/deployment-record.md`：紀錄範本、`.gitignore`、SOPS + age
- [x] 2.7 `references/reference-project.md`：參考專案已實作 vs 範本新增

## 3. 測試

- [x] 3.1 `tests/docker-server-deploy/run-tests.sh`：假的 `docker` / `curl`，涵蓋成功、pull 失敗、migration 失敗、health 逾時回滾、image 不符回滾、手動回滾、鎖被佔用、殘留鎖、缺 `.env`、清理舊 release
- [x] 3.2 `tests/docker-server-deploy/integration-test.sh`：本機 registry + 真的 Docker
- [x] 3.3 執行 A 測試並全部通過
- [x] 3.4 發佈前在有 Docker daemon 的環境執行 B 測試並全部通過

## 4. Repo 文件更新

- [x] 4.1 `README.md`：安裝指令與 Skills 清單
- [x] 4.2 `docs/install-skills.md`
- [x] 4.3 `CLAUDE.md`、`AGENTS.md` 的結構導覽與閱讀順序
- [x] 4.4 `.ai-project-index/config.json` 的 `expectedCoverage`

## 5. 驗證

- [x] 5.1 確認 skill 與測試內沒有任何 secret、真實網域、image 名稱或 server 資訊
- [x] 5.2 `bash -n` 檢查所有 shell 腳本
- [x] 5.3 執行 `python3 skills/ai-project-index/scripts/refresh-index.py` 與 `evaluate-index.py`
- [x] 5.4 執行 `openspec validate add-docker-server-deploy-skill --strict` 與 `openspec validate --all --strict`
