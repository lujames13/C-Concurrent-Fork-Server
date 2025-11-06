# 網路系統程式開發課期中考 Product Requirements Document (PRD)

---

## Goals and Background Context

### Goals

- **G1**: 實作一個 C 語言的 Client-Server 應用程式。
- **G2**: 伺服器必須使用 fork() 模型進行並行處理，不得使用 threads。
- **G3**: 程式碼必須模組化，將共享功能封裝為動態函式庫 (.so)。
- **G4**: 必須實作雙層（編譯時期與執行時期）的日誌控制。
- **G5**: 必須設計並實作穩健性機制，以處理異常情況。
- **G6**: 專案必須使用 Makefile 或 CMake 進行建置。

### Background Context

本專案的核心挑戰是在嚴格的技術限制下，建立一個可維運且穩健的 C 語言伺服器。許多簡易範例程式碼會忽略關鍵的異常情況，例如 fork() 失敗、因 SIGCHLD 未處理而產生的殭屍進程、或因 SIGPIPE/ECONNRESET/Slowloris 攻擊導致的 I/O 錯誤。

本 PRD 將定義一個模組化的解決方案，其架構核心為「Process-per-Client」的 fork() 模型。共享功能（如日誌系統）將被封裝為動態函式庫 (libutils.so)，並將實作包括 SIGCHLD 處理和 I/O 逾時在內的特定穩健性機制，以確保伺服器在真實世界的異常情境下仍能穩定運作。

### Change Log

| 日期 | 版本 | 描述 | 作者 |
|------|------|------|------|
| 2025-11-06 | 1.0 | Initial PRD draft created from Project Brief v1.1 | John (PM) |

---

## Requirements

### Functional Requirements (FR)

- **FR1**: 實作一個 C 語言的 Client-Server 應用程式。
- **FR2**: Client 必須能夠發送 "GET_SYS_INFO" 請求，並成功接收 Server 回傳的系統資訊（例如 uptime 的輸出）。
- **FR3**: Server 必須能夠接受並同時處理至少 10 個並行 Client 連線。
- **FR4**: Server 的並行模型必須僅使用 fork() 建立子進程來處理客戶端。
- **FR5**: 所有 Client 和 Server 共享的程式碼（至少包含日誌功能）必須被編譯並封裝為一個動態共享函式庫 (.so)。
- **FR6**: 必須提供一個 CMakeLists.txt (或 Makefile)，用於建置所有元件（Server, Client, .so）。
- **FR7**: 必須交付一份包含 tcpdump 封包分析、執行截圖和展示影片的最終報告。
- **FR8**: 必須交付一份內部「SOP 展示文件」，用以協助重現攻擊情境。

### Non-Functional Requirements (NFR)

- **NFR1**: 日誌系統必須支援「編譯時期」控制（例如 NDEBUG 宏）和「執行時期」控制（例如 -d 命令列參數）。
- **NFR2**: Server (Parent) 必須實作 SIGCHLD 訊號處理器，並使用 waitpid() 來防止殭屍進程 (Zombie Processes)。
- **NFR3**: Server (Parent) 必須處理 fork() 失敗的錯誤，向 Client 發送 SERVER_BUSY 訊息並短暫 sleep，以防止 CPU 熱迴圈。
- **NFR4**: Server (Child) 必須忽略 SIGPIPE 訊號（例如 `signal(SIGPIPE, SIG_IGN)`），以防止在寫入已斷線 socket 時崩潰。
- **NFR5**: Server (Child) 必須檢查 read() 和 write() 的回傳值，以正確處理 ECONNRESET 或 EPIPE 等斷線錯誤。
- **NFR6**: Server (Child) 必須使用 `setsockopt(SO_RCVTIMEO)` 設置 I/O 逾時，以防禦 Slowloris 攻擊。
- **NFR7**: 專案必須使用 C 語言（C99/C11）開發。
- **NFR8**: 專案必須在 POSIX 相容的環境（如 Linux）上開發與測試。

---

## Technical Assumptions

### Repository Structure: Monorepo

**決策**: 採用 Monorepo (單一儲存庫)。

**理由**: Client、Server 和共享函式庫 (libutils.so) 三者緊密相關且需同時開發，使用 Monorepo 有助於簡化建置流程和版本控制。

### Service Architecture: Process-per-Client (fork())

**決策**: 伺服器架構核心採用「Process-per-Client」模型。

**理由**: 嚴格遵守考試要求 (C1)，使用 fork() 系統呼叫實現並行處理，明確禁止使用 threads。

### Testing Requirements: Verification Scripts & Manual Validation

**決策**: 測試將依賴手動驗證、netstat / ps 監控，以及一組「攻擊腳本」。

**理由**: 專案的成功不在於自動化單元測試，而在於證明穩健性 (K3)。SOP.md 中定義的「Good Server vs. Bad Server」對比測試，是本專案的核心驗收標準。

### Additional Technical Assumptions and Requests

**語言與環境**: 必須使用 C 語言（C11/C99）；開發和測試環境必須為 POSIX 相容系統（如 Linux）。

**建置系統**: 必須使用 CMake (或 Makefile)。

**共享函式庫**: 共享功能（至少包含日誌）必須編譯為動態共享函式庫 (libutils.so)。

**功能簡潔性**: 「取得系統資訊」功能應保持最簡化實作（例如 exec(uptime)）。

**網路分析**: 必須使用 tcpdump (或 Wireshark) 進行封包擷取並包含在報告中。

---

## Epic List

### Epic 1: 專案基礎與「脆弱伺服器」(Bad Server) 的建立

**目標**: 建立完整的 Monorepo 專案結構、CMake 建置系統 和 libutils.so (含日誌)，並交付一個可運作但缺乏穩健性機制的 Client-Server (即 server_bad)。

### Epic 2: 完整穩健性機制 (Good Server) 與最終交付

**目標**: 在 Epic 1 的基礎上，實作所有關鍵的 NFR 穩健性機制（SIGCHLD, SIGPIPE, SO_RCVTIMEO, fork-fail），以產生 server_good，並打包所有最終交付成果（攻擊腳本、SOP 和報告）。

---

## Epic 1: 專案基礎與「脆弱伺服器」(Bad Server) 的建立

### Story 1.1: 專案結構與 CMake 基礎設定

**As a** 開發者 (Developer),  
**I want** 一個符合 architecture.md 定義的 Monorepo 檔案結構,  
**so that** 我可以開始有組織地放置原始碼，並擁有一個基礎的 CMakeLists.txt 來管理建置。

**Acceptance Criteria**:
- (AC1) 必須建立 `src/`、`src/client`、`src/server`、`src/libutils`、`attacks/` 和 `report/` 目錄結構。
- (AC2) 必須建立一個根 CMakeLists.txt。
- (AC3) 必須建立一個 .gitignore 檔案，至少忽略 `build/` 和 `lib/` 目錄。
- (AC4) 根 CMakeLists.txt 必須能夠定義專案名稱，並包含 `src/libutils`、`src/server` 和 `src/client` 的子目錄。

### Story 1.2: 建立 libutils.so (日誌功能)

**As a** 開發者 (Developer),  
**I want** 將日誌系統 (log.h, log.c) 實作在 `src/libutils` 中,  
**so that** 它可以被編譯成 libutils.so 動態函式庫，供 Server 和 Client 稍後連結使用。

**Acceptance Criteria**:
- (AC1) `src/libutils/log.h` 必須定義 `log_init()`、`get_log_level()`、`log_info()`、`log_debug()` 和 `COMPILE_TIME_LOG_DEBUG` 宏，如 architecture.md 所定義。
- (AC2) `src/libutils/log.c` 必須實作 log.h 中定義的功能，並正確處理日誌層級。
- (AC3) CMakeLists.txt 必須能將 libutils 成功編譯為 libutils.so 動態函式庫。

### Story 1.3: 建立「Bad Server」- 基礎連線

**As a** 開發者 (Developer),  
**I want** 實作 server.c 的基礎，使其能夠 bind 和 listen 在指定的 port 上，並 accept 一個連線,  
**so that** 我們有了一個可運作的伺服器基礎（即 server_bad 的起點）。

**Acceptance Criteria**:
- (AC1) `src/server/server.c` 必須能從命令列參數讀取 port。
- (AC2) 伺服器必須成功呼叫 `socket()`、`bind()`、`listen()`。
- (AC3) 伺服器必須在一個迴圈中呼叫 `accept()`。
- (AC4) 伺服器必須連結 (link) libutils.so（即使尚未在 server.c 中使用日誌功能）。
- (AC5) [關鍵] 此 Story 不得 包含 SIGCHLD 處理 或 fork() 失敗處理。

### Story 1.4: 實作 fork() 並行模型

**As a** 開發者 (Developer),  
**I want** server_bad 在 `accept()` 之後立即 `fork()` 一個新的子進程,  
**so that** Parent process 可以立即回去 accept 下一個連線，而 Child process 則負責處理該客戶端。

**Acceptance Criteria**:
- (AC1) 伺服器 (Parent) 必須在 `accept()` 成功後呼叫 `fork()`。
- (AC2) Parent process 必須在 `fork()` 後關閉它所持有的 client_fd。
- (AC3) Child process 必須接收 client_fd 並開始處理（目前可以只是一個存根(stub)，例如 `handle_client(client_fd)`)。
- (AC4) [關鍵] 此 Story 不得 檢查 fork() 的 -1 失敗回傳值，也不得 實作 SIGCHLD 處理。

### Story 1.5: 建立基礎 Client

**As a** 開發者 (Developer),  
**I want** 實作 client.c，使其能從命令列讀取 IP 和 port,  
**so that** 我可以連線到 server_bad。

**Acceptance Criteria**:
- (AC1) `src/client/client.c` 必須能從命令列參數讀取 IP 和 port。
- (AC2) Client 必須能成功 `socket()` 並 `connect()` 到指定的伺服器。
- (AC3) Client 必須連結 (link) libutils.so。

### Story 1.6: 實作核心功能 (GET_SYS_INFO)

**As a** 助教 (TA) / 教授 (Primary User),  
**I want** Client 能夠發送 "GET_SYS_INFO" 請求並接收到 Server 回傳的系統資訊,  
**so that** 核心的 Client-Server 通訊功能得到驗證。

**Acceptance Criteria**:
- (AC1) Client (Story 1.5) 必須在連線成功後，發送 `"GET_SYS_INFO\n"` 字串。
- (AC2) Server (Child process, Story 1.4) 必須能讀取到這個請求。
- (AC3) Server (Child) 必須執行一個命令（例如 uptime）並將其 stdout 重新導向回 client_fd。
- (AC4) Client 必須能讀取 Server 的回應並將其列印到 stdout。
- (AC5) [關鍵] Child process 不得 忽略 SIGPIPE，也不得 設置 SO_RCVTIMEO。

### Story 1.7: 整合日誌系統 (雙層控制)

**As a** 開發者 (Developer),  
**I want** 將 libutils.so 的日誌功能整合到 server_bad 和 client 中,  
**so that** 我可以透過 NDEBUG 宏（編譯時期）和 -d 旗標（執行時期）來控制日誌輸出。

**Acceptance Criteria**:
- (AC1) server.c 和 client.c 必須能夠解析 -d 旗標，並使用 `log_init()` 初始化日誌層級。
- (AC2) server.c, child.c 和 client.c 必須使用 `log_info()` 和 `COMPILE_TIME_LOG_DEBUG()` 來記錄事件。
- (AC3) 驗證：當不帶 -d 旗標時，只顯示 log_info 訊息。
- (AC4) 驗證：當帶有 -d 旗標時，log_info 和 log_debug 訊息都會顯示。
- (AC5) 驗證：當使用 NDEBUG 宏編譯時（例如 `add_definitions(-DNDEBUG)`)，即使在執行時期啟用了 -d 旗標，log_debug 訊息也不會被印出。

### Story 1.8: 最終化 CMake 建置 (交付 server_bad)

**As a** 開發者 (Developer),  
**I want** 最終化 CMakeLists.txt，使其能明確地建置出「脆弱的」server_bad 版本,  
**so that** 我們完成了 Epic 1 的目標，並為 Epic 2 的「Good Server」對比做好準備。

**Acceptance Criteria**:
- (AC1) CMakeLists.txt 必須定義一個 server_bad 目標。
- (AC2) server_bad 目標必須使用 `target_add_definitions(server_bad PRIVATE NO_ROBUST)` 來注入 `-DNO_ROBUST` 旗標。
- (AC3) CMakeLists.txt 必須同時定義 client 和 utils (for .so) 目標。
- (AC4) `make` (或 `cmake --build`) 必須能成功編譯所有目標 (server_bad, client, libutils.so)。

---

## Epic 2: 完整穩健性機制 (Good Server) 與最終交付

### Story 2.1: 實作 SIGCHLD 處理 (防禦殭屍進程)

**As a** 開發者 (Developer),  
**I want** server_good 能夠註冊一個 SIGCHLD 訊號處理器,  
**so that** Parent process 可以正確地 `waitpid()` 回收所有已退出的 Child processes，防止殭屍進程。

**Acceptance Criteria**:
- (AC1) 必須在 `src/server/` 中建立 signal.c 和 signal.h。
- (AC2) signal.c 必須實作一個 SIGCHLD handler。
- (AC3) 該 handler 必須在一個 while 迴圈中安全地呼叫 `waitpid(-1, NULL, WNOHANG)`，以回收所有已退出的 children。
- (AC4) server.c 必須包含 signal.h 並在啟動時呼叫 `setup_sigchld_handler()`。
- (AC5) 此功能的實作必須被 `#ifndef NO_ROBUST` 條件編譯所包圍。

### Story 2.2: 實作 fork() 失敗處理

**As a** 開發者 (Developer),  
**I want** server_good 能夠在 `fork()` 失敗時 (回傳 -1) 進行處理,  
**so that** 伺服器不會陷入 100% CPU 的熱迴圈，並能禮貌地通知 Client。

**Acceptance Criteria**:
- (AC1) server.c 中 `fork()` 之後，必須檢查回傳值是否為 -1。
- (AC2) 如果 `fork()` 失敗，必須向 client_fd 發送 `"SERVER_BUSY\n"`。
- (AC3) 發送訊息後，必須 `close(client_fd)`。
- (AC4) 關閉 fd 後，必須呼叫 `sleep(1)`，以防止熱迴圈。
- (AC5) 此功能的實作必須被 `#ifndef NO_ROBUST` 條件編譯所包圍。

### Story 2.3: 實作 SIGPIPE 忽略 (防禦斷線崩潰)

**As a** 開發者 (Developer),  
**I want** server_good 的 Child process 忽略 SIGPIPE 訊號,  
**so that** 當 Child process 嘗試 `write()` 到一個已斷線的 socket 時，它不會崩潰。

**Acceptance Criteria**:
- (AC1) 必須在 `src/server/child.c` (或 child.h) 中建立一個 handle_client 函式（如果 Story 1.4 尚未建立）。
- (AC2) handle_client 函式（在 Child process 執行）的第一件事必須是呼叫 `signal(SIGPIPE, SIG_IGN)`。
- (AC3) 此功能的實作必須被 `#ifndef NO_ROBUST` 條件編譯所包圍。

### Story 2.4: 實作 I/O 逾時 (防禦 Slowloris)

**As a** 開發者 (Developer),  
**I want** server_good 的 Child process 為 Client socket 設置 SO_RCVTIMEO,  
**so that** 惡意或緩慢的 Client 無法永久佔用連線名額，導致 DoS 攻擊。

**Acceptance Criteria**:
- (AC1) child.c 必須在 `signal(SIGPIPE, SIG_IGN)` 之後，呼叫 `setsockopt()`。
- (AC2) 必須正確設置 SOL_SOCKET 和 SO_RCVTIMEO。
- (AC3) 必須傳遞一個 struct timeval，其逾時應設置為一個合理的值（例如：5 秒）。
- (AC4) 此功能的實作必須被 `#ifndef NO_ROBUST` 條件編譯所包圍。

### Story 2.5: 實作 I/O 錯誤檢查

**As a** 開發者 (Developer),  
**I want** server_good 的 Child process 嚴格檢查 `read()` 和 `write()` 的回傳值,  
**so that** 它可以優雅地處理正常的 Client 斷線 (read 回傳 0) 或異常斷線 (EPIPE / ECONNRESET)。

**Acceptance Criteria**:
- (AC1) child.c 中 read() 請求的迴圈必須檢查回傳值。
- (AC2) 如果 read() 回傳 0（正常斷線）或 -1 (且 errno 為 ECONNRESET 或 ETIMEDOUT [來自 Story 2.4])，Child process 必須記錄一個 log_debug 訊息並正常 exit。
- (AC3) child.c 中 write() 回應的程式碼必須檢查回傳值。
- (AC4) 如果 write() 回傳 -1 (且 errno 為 EPIPE [因為 Story 2.3])，Child process 必須記錄一個 log_debug 訊息並正常 exit。
- (AC5) [關鍵] 這些錯誤檢查不需要被 `#ifndef NO_ROBUST` 包圍，因為它們是良好程式碼的基礎（但 server_bad 在 Story 2.3 中會因為沒有 SIG_IGN 而崩潰）。

### Story 2.6: 建立 server_good 建置目標

**As a** 開發者 (Developer),  
**I want** CMakeLists.txt 能夠建置 server_good,  
**so that** 我可以產生一個包含所有穩健性機制（NFR2-NFR6） 的最終伺服器執行檔。

**Acceptance Criteria**:
- (AC1) CMakeLists.txt 必須定義一個 server_good 目標。
- (AC2) server_good 目標必須連結 libutils.so。
- (AC3) server_good 目標不得定義 NO_ROBUST 旗標，確保所有 `#ifndef NO_ROBUST` 區塊都被編譯。
- (AC4) `make server_good` (或 `cmake --build . --target server_good`) 必須能成功編譯執行檔。

### Story 2.7: 建立攻擊腳本

**As a** 開發者 (Developer),  
**I want** 建立 SOP.md 中定義的三個攻擊腳本,  
**so that** 我可以執行 K3 成功指標，展示 server_bad 的脆弱性。

**Acceptance Criteria**:
- (AC1) 必須在 `attacks/` 目錄下建立 attack_1_zombie.sh。
- (AC2) 必須在 `attacks/` 目錄下建立 attack_2_slowloris.sh。
- (AC3) 必須在 `attacks/` 目錄下建立 attack_3_sigpipe.sh。
- (AC4) 腳本必須是可執行的 (chmod +x)。

### Story 2.8: 撰寫 SOP 與最終報告

**As a** 助教 (TA) / 教授 (Primary User),  
**I want** 一份 SOP 展示文件 (FR8) 和一份包含 tcpdump 分析的最終報告 (FR7),  
**so that** 我可以驗證專案是否符合所有穩健性要求 (K3) 和網路分析要求 (K4)。

**Acceptance Criteria**:
- (AC1) 必須建立 SOP.md (或 report/SOP.md)，其內容應符合 SOP.md 範本。
- (AC2) SOP 必須清楚說明如何編譯和執行 server_good vs. server_bad。
- (AC3) SOP 必須包含執行三個攻擊腳本的步驟，並說明預期的「失敗」和「成功」結果。
- (AC4) 必須建立 report/report.md (或主 README.md)。
- (AC5) 報告必須包含 tcpdump 擷取的封包分析。
- (AC6) 報告必須包含系統設計說明（可引用 architecture.md）和執行截圖（來自 SOP）。
- (AC7) 必須包含一個 2 分鐘的展示影片（或其連結）。

---

## Checklist Results Report

| 項目 | 狀態 |
|------|------|
| 1. Problem Definition & Context | Pass |
| 2. MVP Scope Definition | Pass |
| 3. User Experience Requirements | N/A - CLI 應用程式，無 UI |
| 4. Functional Requirements | Pass |
| 5. Non-Functional Requirements | Pass |
| 6. Epic & Story Structure | Pass |
| 7. Technical Guidance | Pass |
| 8. Cross-Functional Requirements | Pass |
| 9. Clarity & Communication | Pass |

**最終決定**: **READY FOR ARCHITECT**

在本情境中，這意味著 PRD 已準備好與現有的 architecture.md 一起移交給開發團隊。

---

## Next Steps

### Architect Prompt (Handoff to Development)

*本節根據範本 跳過，因為這是一個 CLI 應用程式。*

### 致 Story Manager (SM) / Developer (Dev) 代理程式

本 prd.md 文件已完成並獲得批准。它定義了「網路系統程式開發課期中考」專案的所有需求和史詩/故事結構。

**關鍵交付順序**：

1. **Epic 1 (Stories 1.1 - 1.8)**: 建立基礎設施 (CMake, libutils.so) 並交付 server_bad。
2. **Epic 2 (Stories 2.1 - 2.8)**: 在 Epic 1 的基礎上添加所有穩健性機制（NFRs）以交付 server_good，並完成所有報告。

**關鍵輸入文件**：

- **architecture.md**: 提供了完整的技術實作藍圖，包括 Good vs. Bad 的條件編譯策略和原始碼樹狀結構。
- **SOP.md**: 提供了 Epic 2 中 Story 2.7 (攻擊腳本) 和 2.8 (報告) 的具體交付內容。

請 SM 代理程式開始從 Story 1.1 提取任務。

---

**文件結束**
