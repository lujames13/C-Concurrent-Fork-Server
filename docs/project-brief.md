# 專案簡報: 網路系統程式開發課期中考 (v1.1)

**Session Date:** 2025-11-06

**Facilitator:** BMad (Mary, 業務分析師)

**Participant:** BMad

## 1. 執行摘要 (Executive Summary)

為了「網路系統程式開發課」的期中考，本專案旨在實作一個穩健的 (Robust) C 語言 Client-Server 應用程式。伺服器端將使用 `fork()` 模型來並行處理多個客戶端連線，目標是至少能同時處理 10 個連線。核心功能是 Client 能從 Server 獲取系統資訊。專案重點將放在實作多層級的日誌控制、將共享程式碼封裝為動態函式庫 (.so)，並特別強調實作穩健性機制以處理各種異常情況。交付成果將包含使用 CMake (或 Makefile) 的建置系統，以及一份 tcpdump (或 Wireshark) 的封包擷取分析報告。

## 2. 問題陳述 (Problem Statement)

此次期中考的核心問題，不是單純地「建立一個 Client-Server 應用程式」，而是要「在嚴格的技術限制下，建立一個可維運且穩健的 C 語言伺服器」。

許多教科書上的簡易範例程式碼，在面對真實世界的異常情況時會立即失效。它們通常：

- 使用 threads（此專案中明確禁止），或者
- 使用 `fork()`，但忽略了關鍵的程序管理（如 `waitpid()` 來處理 SIGCHLD），導致「殭屍進程」(Zombie Processes) 堆積並耗盡系統資源。
- 忽略了關鍵的錯誤處理，例如 `fork()` 失敗、`read()` / `write()` 時 Client 異常斷線 (SIGPIPE/ECONNRESET)，或 Slowloris 攻擊。

此專案的挑戰 (Problem) 在於：必須從一開始就正確處理這些「異常或例外情況」，並將程式碼以符合規範的方式（如 Makefile/CMake 和動態函式庫 .so）組織起來，以證明對 process-based concurrency 和系統穩健性有深刻的理解。

## 3. 建議的解決方案 (Proposed Solution)

本專案將實作一個模組化且穩健的 C 語言 Client-Server 解決方案，以滿足所有期中考要求。

### 伺服器架構 (Server Architecture)

- 將建立一個 TCP 伺服器，監聽 (listen) 特定的 port。
- 主進程 (Parent) 將在一個 while 迴圈中呼叫 `accept()` 來接收新連線。
- **核心並行 (Concurrency):** 對於每一個接受的 Client 連線，伺服器將呼叫 `fork()` 來建立一個專屬的 Child process 負責處理該 Client 的所有通訊。

### 共享函式庫 (Shared Library)

- 所有 Client 和 Server 共享的程式碼（例如：日誌功能、錯誤處理常式、封包讀寫 wrapper）將被編譯成一個動態共享函式庫 (libutils.so)。
- Client 和 Server 兩端都將在編譯時動態連結 (dynamically link) 到這個 .so 檔案。

### 核心功能 (Feature)

- Child process 將接收 Client 的請求（例如："GET_SYS_INFO"）。
- Server 端將執行一個命令（如 `uname -a` 或 `uptime`），並將其 stdout 重新導向 (redirect) 回 Client socket，以回傳系統資訊。

### 穩健性機制 (Robustness Mechanisms)

**SIGCHLD 處理：** Parent process 將實作一個 SIGCHLD signal handler，並在其中使用 `waitpid()` 來防止「殭屍進程」(Zombie Processes)。

**fork() 失敗處理：** 將檢查 `fork()` 的回傳值。如果失敗，會傳送「伺服器忙碌」訊息給 Client，`close()` socket，並 `sleep()` 一小段時間以避免熱迴圈。

**I/O 錯誤處理：**
- `signal(SIGPIPE, SIG_IGN)` 將被設置，以防止 `write()` 到斷線的 socket 時程式崩潰。
- `read()` 和 `write()` 的回傳值將被嚴格檢查，以處理正常 (0) 和異常 (-1 with ECONNRESET/EPIPE) 的斷線情況。
- 將使用 `setsockopt(SO_RCVTIMEO)` 在 Client socket 上設置 I/O 逾時，以防禦 Slowloris 攻擊。

### 日誌與建置 (Logging & Build)

- 將實作一個支援編譯時期 (Compile-time, e.g., `#ifdef DEBUG`) 和執行時期 (Runtime, e.g., command-line flag) 兩層控制的日誌系統。
- 專案將使用 CMake (或 Makefile) 進行建置，包含編譯主程式和 .so 函式庫的規則。

### 驗證 (Verification)

- 將使用 `netstat -ptan` 展示同時處理 10+ 個連線。
- 將使用 `tcpdump` 進行封包擷取與分析。

## 4. 目標使用者 (Target Users)

### 主要使用者 (Primary User Segment)

**使用者：** 課程助教 (TA) / 教授

**特徵：** 具備 C 語言和網路系統的專業知識。

**需求：** 需要一個清晰、功能完整且符合所有規格（fork、.so、robustness）的提交品，以便進行評分。

**目標：** 快速驗證程式是否能並行處理 10+ 個連線，並透過檢查程式碼和報告來確認穩健性機制是否已正確實作。

### 次要使用者 (Secondary User Segment)

**使用者：** 開發者 (即你本人, BMad)

**特徵：** 需要一個清晰的架構和可管理的任務。

**需求：**
- 需要一個模組化的設計（例如 .so 函式庫）來簡化開發和除錯。
- 需要一份「SOP 展示文件」，用以協助展示考題要求的不同穩健性情境（例如：有/無 SIGCHLD 處理、有/無 I/O 逾時）。

**目標：**
- 高效地完成專案。
- 在進行最終展示（netstat、tcpdump、video）時，能根據 SOP 清楚地重現 (reproduce) 並解說所有功能與穩健性機制。

## 5. 目標與成功指標 (Goals & Success Metrics)

### 業務目標 (Business Objectives) / 專案目標

- **G1:** 實作一個 C 語言的 Client-Server 應用程式。
- **G2:** 伺服器必須使用 `fork()` 模型進行並行處理，不得使用 threads。
- **G3:** 程式碼必須模組化，將共享功能封裝為動態函式庫 (.so)。
- **G4:** 必須實作雙層（編譯時期與執行時期）的日誌控制。
- **G5:** 必須設計並實作穩健性機制，以處理異常情況。
- **G6:** 專案必須使用 Makefile 或 CMake 進行建置。

### 成功指標 (Success Metrics) / 關鍵績效指標 (KPIs)

- **K1 (功能性):** Client 成功從 Server 取得系統資訊。
- **K2 (並行性):** 伺服器被證實（透過 `netstat -ptan`）能同時處理至少 10 個 Client 連線。
- **K3 (穩健性):** [已修改] 成功展示「攻擊腳本」情境。將建立一個「寫得好的伺服器」(Good Server) 和一個「寫得不好的伺服器」(Bad Server)，並執行攻擊腳本以證明「Good Server」能存活，而「Bad Server」會崩潰或耗盡資源。
- **K4 (交付成果):** 提交一份包含系統設計、封包分析 (tcpdump)、執行截圖和 2 分鐘展示影片的完整報告。
- **K5 (SOP):** 交付一份內部「SOP 展示文件」，以協助開發者重現 K3 的情境。

## 6. MVP 範圍 (MVP Scope)

考量到這是一個有明確交付期限的期中考專案，MVP (Minimum Viable Product) 範圍必須嚴格對應考題要求。所有「錦上添花」的功能都將被排除。

### 核心功能 (Must Have)

- **M1 (Server):** 必須使用 `fork()` 建立 Child process 處理連線。
- **M2 (Client):** 必須能發送請求並接收 Server 端的系統資訊。
- **M3 (Concurrency):** Server 必須能處理至少 10 個並行連線。
- **M4 (Library):** 共享功能（至少包含日誌功能）必須封裝在 .so 動態函式庫中。
- **M5 (Logging):** 必須實作編譯時期和執行時期的日誌控制。
- **M6 (Robustness):** 必須實作考題要求的所有穩健性機制（SIGCHLD 處理、`fork()` 失敗、I/O 錯誤、逾時機制）。
- **M7 (Build):** 必須提供 Makefile 或 CMake 檔案。
- **M8 (Report):** 必須交付包含 tcpdump 分析、截圖、設計說明和影片的報告。

### 超出範圍 (Out of Scope for MVP)

- **O1:** 使用 threads 進行並行處理（明確禁止）。
- **O2:** 複雜的 Client 端 GUI（使用簡單的 C 語言 CLI 即可）。
- **O3:** 除了「取得系統資訊」以外的任何其他複雜伺服器功能（例如：檔案傳輸、聊天室等）。
- **O4:** 複雜的加密或安全協定（例如 SSL/TLS）。
- **O5:** 完整的設定檔讀取（執行時期日誌控制可用簡單的命令列參數 `-d` 實現）。

## 7. MVP 後的願景 (Post-MVP Vision)

**階段 2 功能 (Phase 2 Features):** 無。本專案為期中考試項目，所有要求均已納入 MVP 範圍。

**長期願景 (Long-term Vision):** 無。本專案的生命週期在提交並評分後即告終結。

**擴展機會 (Expansion Opportunities):** 無。

## 8. 技術考量 (Technical Considerations)

### 平台需求 (Platform Requirements)

**目標平台:** 任何支援 POSIX 標準的類 Unix 系統（例如 Linux），因為專案需求明確指定了 `fork()`、.so、tcpdump 和 CMake/Makefile。

**效能需求:** 伺服器必須能夠穩定處理並發的 10 個客戶端連線。

### 技術偏好 (Technology Preferences)

- **語言:** C 語言。
- **伺服器模型:** 嚴格限制使用 `fork()` 的 process-per-client 模型。明確禁止使用 threads。
- **客戶端:** 一個簡單的 C 語言命令列 (CLI) 應用程式。
- **資料庫:** 不適用 (N/A)。
- **建置系統:** CMake 或 Makefile。

### 架構考量 (Architecture Considerations)

- **程式碼結構:** 必須將共享功能（如日誌、I/O 封裝）分離出來。
- **整合需求:** 共享程式碼必須被編譯為一個動態共享函式庫 (.so)，並由伺服器和客戶端兩端進行連結 (linking)。
- **通訊:** 使用標準 TCP/IP Sockets。
- **日誌:** 實作一個雙層（編譯時期與執行時期）控制的日誌系統。

## 9. 限制與假設 (Constraints & Assumptions)

### 限制 (Constraints)

- **C1 (架構):** 伺服器必須使用 `fork()`。禁止使用 threads。
- **C2 (語言):** 專案必須使用 C 語言。
- **C3 (並行):** 伺服器必須能夠處理至少 10 個並行連線。
- **C4 (模組化):** 共享功能必須封裝在動態共享函式庫 (.so) 中。
- **C5 (建置):** 必須使用 Makefile 或 CMake。
- **C6 (時程):** 這是一份有截止日期的期中考，所有工作必須在時限內完成。

### 假設 (Assumptions)

- **A1 (環境):** 假設開發和測試環境為 POSIX 相容系統（如 Linux），以支援 `fork()`、CMake、.so 等需求。
- **A2 (功能):** 假設「取得系統資訊」功能，可以透過呼叫 `uname`、`uptime` 等 shell 命令並重新導向其 stdout 來實現，不需要複雜的 C 語言系統呼叫。
- **A3 (網路):** 假設 `netstat -ptan` 是可接受的並行連線證明。
- **A4 (日誌):** 假設「編譯時期日誌控制」可透過 `#ifdef DEBUG` 宏來實現，「執行時期日誌控制」可透過簡單的命令列參數（如 `-d`）來實現。

## 10. 風險與關鍵決策 (Risks & Key Decisions)

### 關鍵風險 (Key Risks)

- **R1 (Process Management):** 未能正確實作 SIGCHLD signal handler 和 `waitpid()`。**影響：** 伺服器將產生大量「殭屍進程」(Zombie Processes)，最終耗盡 process table 資源，導致系統無法建立新程序。

- **R2 (Resource Exhaustion):** 未能實作 I/O 逾時 (例如 SO_RCVTIMEO)。**影響：** 惡意的「慢速」客戶端 (Slowloris attack) 可以輕鬆佔滿所有 10 個並行連線名額，導致伺服器拒絕服務 (DoS)。

- **R3 (CPU Hot Loop):** `fork()` 失敗時，如果僅 `close()` socket 並立即 continue 迴圈。**影響：** 在系統高負載時，主伺服器進程會陷入 100% CPU 的熱迴圈，使系統狀況惡化。

- **R4 (Crash on Disconnect):** 未能處理 SIGPIPE 訊號 (e.g., `signal(SIGPIPE, SIG_IGN)`)。**影響：** 當 Child process 嘗試 `write()` 到一個已斷線的 socket 時，Child process 將意外崩潰 (crash)。

- **R5 (Scope Creep):** 過度專注於「取得系統資訊」功能的複雜性，而忽略了上述 R1-R4 的核心穩健性要求。

### 關鍵設計決策 (Key Design Decisions)

- **D1 (功能範圍):** 「取得系統資訊」功能將採用最簡單的實作（例如：呼叫 `uptime` 並重新導向 stdout）。其唯一目的是證明 Client-Server 之間的通訊機制可以運作。

- **D2 (函式庫範圍):** .so 共享函式庫的內容將嚴格遵守 MVP (Minimum Viable Product) 範圍。它將包含日誌系統和可能的 I/O 封裝 (wrapper functions)，以滿足核心需求即可。

- **D3 (展示範例):** [已修改] 關鍵的展示範例將是「攻擊腳本」。我們將建立一個簡易的攻擊腳本（例如：模擬 Slowloris 或快速連線/斷線），並展示它如何導致「Bad Server」（未實作 R1-R4 穩健性機制）崩潰或產生殭屍進程，而「Good Server」（已實作）則能正常防禦並保持運作。

### 需要進一步研究的領域 (Areas Needing Further Research)

- **R-A:** 找出在 SIGCHLD handler 中安全（async-signal-safe）且正確地使用 `waitpid(-1, NULL, WNOHANG)` 迴圈來回收所有已退出 children 的 C 語言最佳實踐。

- **R-B:** 找出在 C 語言中實作 `setsockopt(SO_RCVTIMEO)` 的精確語法和參數。

## 11. 附錄 (Appendices)

### A. 研究摘要 (Research Summary)

本專案簡報的內容，是基於一場針對「穩健性機制」的結構化腦力激盪。

該會議識別出了 5 個關鍵風險與對應的穩健性機制，包括：`fork()` 失敗、SIGCHLD (殭屍進程)、SIGPIPE (斷線寫入)、ECONNRESET (斷線讀取) 和 SO_RCVTIMEO (Slowloris 攻擊)。

### B. 利害關係人意見 (Stakeholder Input)

開發者 (BMad) 明確要求，專案交付成果中必須包含一份「SOP 展示文件」，用以協助重現「有/無穩健性機制」的對比情境。

開發者 (BMad) 已釐清所有範圍問題：

- 「取得系統資訊」功能應保持最簡化實作。
- 「.so 函式庫」範圍應以 MVP 為主。
- [已修改] 「三個範例」將被整合成一個核心的「攻擊腳本」展示情境，用以對比「Good Server」與「Bad Server」的穩健性。

### C. 參考資料 (References)

「網路系統程式開發課 - 期中考」需求文件。

## 12. 後續步驟 (Next Steps)

### 立即行動 (Immediate Actions)

1. **核准簡報:** 請確認並核准這份「專案簡報」(Project Brief) 作為專案的指導文件。

2. **技術研究:** 立即開始「需要進一步研究的領域」中所列的 R-A (waitpid) 和 R-B (setsockopt) 項目的技術研究，找出 C 語言的最佳實踐範例。

3. **架構設計:** 將這份簡報移交給「架構師」(Architect) 角色（即下一步的你），以開始建立詳細的「技術架構文件」。

4. **SOP 草擬:** [已修改] 開始草擬「SOP 展示文件」的大綱，明確定義如何編譯「Good Server」和「Bad Server」版本，以及如何執行攻擊腳本來重現 K3 的對比情境。

### 移交給「架構師」的提示 (Handoff to Architect)

這份專案簡報提供了『網路系統程式開發課期中考』專案的完整背景、範圍和所有技術限制（fork、.so、robustness）。

請你接手『架構師』的角色，開始建立一份詳細的技術架構文件。這份文件必須定義：

1. 完整的原始碼樹狀結構 (Source Tree) 和 CMake/Makefile 的結構。

2. 動態函式庫 (.so) 的 API 介面（例如：`log_init()`, `log_debug()`）。

3. SIGCHLD、SIGPIPE 和 SO_RCVTIMEO 穩健性機制的具體實作模式和程式碼放置位置。

4. Client 和 Server 之間的通訊協定（例如：請求 "GET_SYS_INFO" 時的封包格式）。

5. [新增] 如何透過編譯旗標 (compile flags) 或其他機制，來切換「Good Server」（完整穩健性）和「Bad Server」（缺少穩健性）的版本，以便於展示。
