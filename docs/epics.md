# C-Concurrent-Fork-Server - Epic Breakdown

**Author:** James
**Date:** 2025-11-06
**Project Level:** Level 2-3
**Target Scale:** 教育專案 - 網路系統程式開發課期中考

---

## Overview

This document provides the complete epic and story breakdown for C-Concurrent-Fork-Server, decomposing the requirements from the [PRD](./prd.md) into implementable stories.

### Epic Structure Summary

本專案採用漸進式交付策略，分為兩個主要 Epics：

**Epic 1: 專案基礎與「脆弱伺服器」(Bad Server) 的建立**
- 建立完整的 Monorepo 結構、CMake 建置系統和 libutils.so 共享函式庫
- 實作基礎的 fork() 並行模型和核心 Client-Server 通訊功能
- 交付一個「功能正常但缺乏穩健性」的 server_bad 版本
- **刻意不實作**任何穩健性機制，為後續對比展示建立基準

**Epic 2: 完整穩健性機制 (Good Server) 與最終交付**
- 在 Epic 1 的基礎上，添加所有關鍵的 NFR 穩健性機制
- 實作 SIGCHLD、SIGPIPE、fork-fail handling、I/O timeout 等防禦機制
- 建立攻擊腳本展示 Bad Server 的脆弱性
- 完成最終交付成果：SOP 文件、報告、tcpdump 分析、展示影片

---

## Epic 1: 專案基礎與「脆弱伺服器」(Bad Server) 的建立

**Epic Goal:** 建立完整的專案基礎設施（Monorepo、CMake、libutils.so），並交付一個功能完整但**刻意缺乏穩健性機制**的 server_bad 版本，作為 Epic 2 對比展示的基準。

**Business Value:**
- 為整個專案奠定技術基礎
- 實作核心的 Client-Server 通訊功能
- 建立「Good vs. Bad Server」對比展示的起點
- 驗證基礎架構（fork() 模型、動態函式庫、日誌系統）的可行性

---

### Story 1.1: 專案結構與 CMake 基礎設定

**As a** 開發者 (Developer),
**I want** 一個符合 architecture.md 定義的 Monorepo 檔案結構,
**So that** 我可以開始有組織地放置原始碼，並擁有一個基礎的 CMakeLists.txt 來管理建置。

**Acceptance Criteria:**

**Given** 我需要開始一個全新的 C 語言專案
**When** 我建立專案的初始檔案結構
**Then** 必須包含以下目錄：`src/`、`src/client`、`src/server`、`src/libutils`、`attacks/`、`report/`

**And** 必須建立一個根目錄的 CMakeLists.txt 檔案
**And** 必須建立 .gitignore 檔案，至少忽略 `build/` 和 `lib/` 目錄
**And** 根 CMakeLists.txt 必須能夠定義專案名稱（NetworkMidterm）並設置 C 語言標準（C11 或 C99）
**And** CMakeLists.txt 必須包含 `add_subdirectory()` 或準備連結 `src/libutils`、`src/server` 和 `src/client`

**Prerequisites:** 無（這是第一個 Story）

**Technical Notes:**
- 使用 `cmake_minimum_required(VERSION 3.10)`
- 設置 `project(NetworkMidterm C)`
- 參考 architecture.md 第 5 節的原始碼樹狀結構

---

### Story 1.2: 建立 libutils.so (日誌功能)

**As a** 開發者 (Developer),
**I want** 將日誌系統 (log.h, log.c) 實作在 `src/libutils` 中,
**So that** 它可以被編譯成 libutils.so 動態函式庫，供 Server 和 Client 稍後連結使用。

**Acceptance Criteria:**

**Given** 專案結構已經建立（Story 1.1）
**When** 我實作日誌系統的標頭檔和原始碼
**Then** `src/libutils/log.h` 必須定義以下 API：
- `log_init(int level)`
- `get_log_level()`
- `log_info(const char *format, ...)`
- `log_debug(const char *format, ...)`
- `COMPILE_TIME_LOG_DEBUG()` 宏（受 NDEBUG 控制）

**And** `src/libutils/log.c` 必須實作 log.h 中定義的所有函式
**And** log.c 必須正確處理 LOG_LEVEL_NONE、LOG_LEVEL_INFO、LOG_LEVEL_DEBUG 三個層級
**And** CMakeLists.txt 必須使用 `add_library(utils SHARED src/libutils/log.c)` 成功編譯出 libutils.so

**Prerequisites:** Story 1.1（專案結構）

**Technical Notes:**
- 參考 architecture.md 第 3.2 節的完整 log.h API 定義
- 使用 `target_include_directories(utils PUBLIC ...)` 使標頭檔可被其他模組引用
- 日誌系統需支援「雙層控制」：編譯時期（NDEBUG）和執行時期（-d 旗標）

---

### Story 1.3: 建立「Bad Server」- 基礎連線

**As a** 開發者 (Developer),
**I want** 實作 server.c 的基礎，使其能夠 bind 和 listen 在指定的 port 上，並 accept 一個連線,
**So that** 我們有了一個可運作的伺服器基礎（即 server_bad 的起點）。

**Acceptance Criteria:**

**Given** libutils.so 已經成功編譯（Story 1.2）
**When** 我執行 server_bad 並傳入 port 參數
**Then** `src/server/server.c` 必須能從命令列參數讀取 port（例如：`./server_bad 8080`）

**And** 伺服器必須成功呼叫 `socket(AF_INET, SOCK_STREAM, 0)` 建立 socket
**And** 伺服器必須成功呼叫 `bind()` 綁定到指定的 port
**And** 伺服器必須成功呼叫 `listen()` 開始監聽
**And** 伺服器必須在一個無限迴圈中呼叫 `accept()` 等待客戶端連線
**And** 伺服器必須連結 libutils.so（即使此階段尚未使用日誌功能）

**And** **[關鍵限制]** 此 Story **不得**包含 SIGCHLD 處理或 fork() 失敗處理

**Prerequisites:** Story 1.2（libutils.so）

**Technical Notes:**
- 此階段只需實作「單一連線」邏輯，fork() 將在 Story 1.4 加入
- 使用 `setsockopt(SO_REUSEADDR)` 避免 TIME_WAIT 問題
- 錯誤處理可以簡單使用 `perror()` + `exit(1)`

---

### Story 1.4: 實作 fork() 並行模型

**As a** 開發者 (Developer),
**I want** server_bad 在 `accept()` 之後立即 `fork()` 一個新的子進程,
**So that** Parent process 可以立即回去 accept 下一個連線，而 Child process 則負責處理該客戶端。

**Acceptance Criteria:**

**Given** 伺服器已經能夠 accept 連線（Story 1.3）
**When** 一個客戶端成功連線
**Then** 伺服器（Parent）必須在 `accept()` 成功後立即呼叫 `fork()`

**And** Parent process 必須在 `fork()` 後**立即關閉**它所持有的 client_fd
**And** Parent process 必須立即回到 `accept()` 迴圈等待下一個連線
**And** Child process 必須接收 client_fd 並開始處理客戶端（目前可以只是一個存根，例如 `handle_client(client_fd)`）
**And** Child process 必須在完成處理後呼叫 `close(client_fd)` 並 `exit(0)`

**And** **[關鍵限制]** 此 Story **不得**檢查 fork() 的 -1 失敗回傳值
**And** **[關鍵限制]** 此 Story **不得**實作 SIGCHLD 處理（這將導致殭屍進程累積）

**Prerequisites:** Story 1.3（基礎連線）

**Technical Notes:**
- 建立 `src/server/child.c` 和 `child.h` 來封裝 Child process 的處理邏輯
- 在 child.c 中實作 `handle_client(int client_fd)` 函式
- 此階段的 handle_client 可以只是一個簡單的 sleep + close

---

### Story 1.5: 建立基礎 Client

**As a** 開發者 (Developer),
**I want** 實作 client.c，使其能從命令列讀取 IP 和 port,
**So that** 我可以連線到 server_bad。

**Acceptance Criteria:**

**Given** server_bad 已經能夠 accept 連線（Story 1.3-1.4）
**When** 我執行 client 並傳入 IP 和 port 參數
**Then** `src/client/client.c` 必須能從命令列參數讀取 IP 和 port（例如：`./client 127.0.0.1 8080`）

**And** Client 必須成功呼叫 `socket(AF_INET, SOCK_STREAM, 0)` 建立 socket
**And** Client 必須成功呼叫 `connect()` 連線到指定的伺服器
**And** Client 必須連結 libutils.so
**And** Client 連線成功後應該印出一條訊息（例如：`"Connected to server"`）

**Prerequisites:** Story 1.2（libutils.so）

**Technical Notes:**
- 使用 `inet_pton()` 或 `inet_addr()` 轉換 IP 字串
- 錯誤處理可以簡單使用 `perror()` + `exit(1)`
- CMakeLists.txt 需要添加 `add_executable(client src/client/client.c)`

---

### Story 1.6: 實作核心功能 (GET_SYS_INFO)

**As a** 助教 (TA) / 教授 (Primary User),
**I want** Client 能夠發送 "GET_SYS_INFO" 請求並接收到 Server 回傳的系統資訊,
**So that** 核心的 Client-Server 通訊功能得到驗證。

**Acceptance Criteria:**

**Given** Client 已經能夠連線到 Server（Story 1.5）
**And** Server 的 Child process 已經能夠接收 client_fd（Story 1.4）
**When** Client 連線成功
**Then** Client 必須發送字串 `"GET_SYS_INFO\n"` 到 Server

**And** Server (Child process) 必須能夠 `read()` 讀取到這個請求
**And** Server (Child) 必須執行系統命令（例如 `uptime` 或 `uname -a`）
**And** Server (Child) 必須將命令的 stdout 輸出重新導向回 client_fd（例如使用 `popen()` 或 `dup2()` + `exec()`）
**And** Client 必須能夠 `read()` 讀取 Server 的回應並將其列印到 stdout

**And** **[關鍵限制]** Child process **不得**忽略 SIGPIPE（這將在 Epic 2 處理）
**And** **[關鍵限制]** Child process **不得**設置 SO_RCVTIMEO（這將在 Epic 2 處理）

**Prerequisites:** Story 1.4（fork 模型）、Story 1.5（基礎 Client）

**Technical Notes:**
- 建議使用 `popen("uptime", "r")` 簡化實作
- 或使用 `fork() + exec() + dup2()` 重新導向 stdout
- 參考 architecture.md 第 3.3 節的通訊協定定義

---

### Story 1.7: 整合日誌系統 (雙層控制)

**As a** 開發者 (Developer),
**I want** 將 libutils.so 的日誌功能整合到 server_bad 和 client 中,
**So that** 我可以透過 NDEBUG 宏（編譯時期）和 -d 旗標（執行時期）來控制日誌輸出。

**Acceptance Criteria:**

**Given** libutils.so 的日誌 API 已經實作（Story 1.2）
**And** server.c、child.c 和 client.c 都已完成基礎功能
**When** 我在程式中加入日誌呼叫
**Then** server.c 和 client.c 必須能夠解析 `-d` 命令列旗標

**And** 程式啟動時必須呼叫 `log_init(has_d_flag ? LOG_LEVEL_DEBUG : LOG_LEVEL_INFO)`
**And** server.c、child.c 和 client.c 必須在關鍵事件（連線、fork、斷線）使用 `log_info()` 記錄訊息
**And** server.c、child.c 和 client.c 必須使用 `COMPILE_TIME_LOG_DEBUG()` 記錄詳細的 debug 訊息

**And** **驗證 1**：不帶 `-d` 旗標執行時，只顯示 `log_info()` 訊息
**And** **驗證 2**：帶 `-d` 旗標執行時，同時顯示 `log_info()` 和 `log_debug()` 訊息
**And** **驗證 3**：使用 `-DNDEBUG` 編譯時，即使執行時加 `-d` 旗標，`COMPILE_TIME_LOG_DEBUG()` 也不會印出任何訊息

**Prerequisites:** Story 1.2（日誌系統）、Story 1.3-1.6（Server/Client 基礎功能）

**Technical Notes:**
- 使用 `getopt()` 或手動解析 `-d` 旗標
- 關鍵日誌點：accept 成功、fork 成功、收到請求、發送回應、連線關閉
- 參考 NFR1 的雙層日誌控制需求

---

### Story 1.8: 最終化 CMake 建置 (交付 server_bad)

**As a** 開發者 (Developer),
**I want** 最終化 CMakeLists.txt，使其能明確地建置出「脆弱的」server_bad 版本,
**So that** 我們完成了 Epic 1 的目標，並為 Epic 2 的「Good Server」對比做好準備。

**Acceptance Criteria:**

**Given** 所有原始碼檔案（server.c、child.c、client.c、log.c）都已完成
**When** 我執行 CMake 建置
**Then** CMakeLists.txt 必須定義一個 `server_bad` 建置目標

**And** `server_bad` 目標必須編譯 `src/server/server.c`、`src/server/child.c`（如果有 signal.c 也包含）
**And** `server_bad` 目標必須使用 `target_compile_definitions(server_bad PRIVATE NO_ROBUST)` 注入 `-DNO_ROBUST` 旗標
**And** CMakeLists.txt 必須定義 `client` 建置目標
**And** CMakeLists.txt 必須定義 `utils` 共享函式庫目標（編譯 libutils.so）

**And** 執行 `cmake -B build && cmake --build build` 後，必須成功生成：
- `build/libutils.so`
- `build/server_bad`
- `build/client`

**And** **驗證**：執行 `./build/server_bad 8080` 和 `./build/client 127.0.0.1 8080` 必須能夠完成一次完整的 GET_SYS_INFO 通訊

**Prerequisites:** Story 1.1-1.7（所有 Epic 1 的前置 Stories）

**Technical Notes:**
- 參考 architecture.md 第 6 節的 CMakeLists.txt 概念範例
- 確保 `-DNO_ROBUST` 旗標被正確傳遞給編譯器
- 此階段不需要建置 server_good（那是 Epic 2 的任務）

---

## Epic 2: 完整穩健性機制 (Good Server) 與最終交付

**Epic Goal:** 在 Epic 1 的基礎上，實作所有關鍵的 NFR 穩健性機制（SIGCHLD、SIGPIPE、fork-fail、I/O timeout、錯誤檢查），交付生產級的 server_good，並完成所有考試要求的交付成果（攻擊腳本、SOP、報告、影片）。

**Business Value:**
- 展示「Good vs. Bad Server」的對比，證明穩健性機制的價值
- 滿足所有 NFR 非功能需求（NFR2-NFR6）
- 完成期中考的所有交付要求（FR7-FR8）
- 提供完整的攻擊防禦能力（殭屍進程、Slowloris、斷線崩潰、資源耗盡）

---

### Story 2.1: 實作 SIGCHLD 處理 (防禦殭屍進程)

**As a** 開發者 (Developer),
**I want** server_good 能夠註冊一個 SIGCHLD 訊號處理器,
**So that** Parent process 可以正確地 `waitpid()` 回收所有已退出的 Child processes，防止殭屍進程累積。

**Acceptance Criteria:**

**Given** Epic 1 的 server_bad 已經完成，並且已知會累積殭屍進程
**When** 我為 server_good 添加 SIGCHLD 處理機制
**Then** 必須在 `src/server/` 目錄下建立 `signal.c` 和 `signal.h` 檔案

**And** `signal.h` 必須宣告 `void setup_sigchld_handler(void)` 函式
**And** `signal.c` 必須實作一個 SIGCHLD handler 函式（例如：`sigchld_handler`）
**And** 該 handler 必須在一個 `while` 迴圈中安全地呼叫 `waitpid(-1, NULL, WNOHANG)`，直到沒有更多已退出的 children
**And** 該 handler 必須是 async-signal-safe（不使用 malloc、printf 等不安全函式）
**And** `server.c` 必須在啟動時（accept 迴圈之前）呼叫 `setup_sigchld_handler()`

**And** **[條件編譯]** 此功能必須被 `#ifndef NO_ROBUST` 包圍，確保 server_bad 不會包含此功能

**Prerequisites:** Story 1.8（server_bad 完成）

**Technical Notes:**
- 使用 `sigaction()` 而非 `signal()` 以獲得更好的可移植性
- 設置 `SA_RESTART` 旗標避免 accept() 被中斷
- 參考 architecture.md 第 4.1 節的 R1 實作說明
- 驗證：執行 `attacks/attack_1_zombie.sh` 對 server_good，用 `ps aux | grep defunct` 確認無殭屍進程

---

### Story 2.2: 實作 fork() 失敗處理

**As a** 開發者 (Developer),
**I want** server_good 能夠在 `fork()` 失敗時（回傳 -1）進行處理,
**So that** 伺服器不會陷入 100% CPU 的熱迴圈，並能禮貌地通知 Client。

**Acceptance Criteria:**

**Given** server.c 中已經有 fork() 呼叫（來自 Story 1.4）
**When** fork() 因為系統資源不足而失敗（回傳 -1）
**Then** server.c 中 `fork()` 之後，必須檢查回傳值是否為 -1

**And** 如果 `fork()` 失敗（`pid == -1`），必須記錄一條 log（例如：`log_info("fork() failed: %s", strerror(errno))`）
**And** 必須向 client_fd 發送錯誤訊息字串：`"SERVER_BUSY\n"`
**And** 發送訊息後，必須立即 `close(client_fd)`
**And** 關閉 fd 後，必須呼叫 `sleep(1)` 或 `usleep()`，以防止熱迴圈耗盡 CPU

**And** **[條件編譯]** 此功能必須被 `#ifndef NO_ROBUST` 包圍

**Prerequisites:** Story 1.4（fork 模型）

**Technical Notes:**
- fork() 失敗通常發生在系統達到 process limit 或記憶體不足時
- 可以使用 `ulimit -u 50` 模擬 fork() 失敗情境來測試
- 參考 architecture.md 第 4.1 節的 R3 實作說明
- 參考 architecture.md 第 3.3 節的 SERVER_BUSY 協定定義

---

### Story 2.3: 實作 SIGPIPE 忽略 (防禦斷線崩潰)

**As a** 開發者 (Developer),
**I want** server_good 的 Child process 忽略 SIGPIPE 訊號,
**So that** 當 Child process 嘗試 `write()` 到一個已斷線的 socket 時，它不會崩潰，而是能夠優雅地處理錯誤。

**Acceptance Criteria:**

**Given** child.c 中已經有 `handle_client()` 函式（來自 Story 1.4）
**When** Child process 開始處理客戶端連線
**Then** `handle_client()` 函式的第一件事必須是呼叫 `signal(SIGPIPE, SIG_IGN)`

**And** 此呼叫必須在任何 read() 或 write() 操作之前執行
**And** 忽略 SIGPIPE 後，當 write() 失敗時，它將回傳 -1 並設置 errno 為 EPIPE，而非導致程式崩潰

**And** **[條件編譯]** 此功能必須被 `#ifndef NO_ROBUST` 包圍

**Prerequisites:** Story 1.4（Child process 處理邏輯）

**Technical Notes:**
- SIGPIPE 預設行為是終止程式
- 忽略它後，write() 會回傳 EPIPE 錯誤，我們可以在 Story 2.5 中處理
- 參考 architecture.md 第 4.1 節的 R4 實作說明
- 驗證：執行 `attacks/attack_3_sigpipe.sh` 確認 server_good 的 child processes 不會崩潰

---

### Story 2.4: 實作 I/O 逾時 (防禦 Slowloris)

**As a** 開發者 (Developer),
**I want** server_good 的 Child process 為 Client socket 設置 SO_RCVTIMEO,
**So that** 惡意或緩慢的 Client 無法永久佔用連線名額，導致 DoS 攻擊（Slowloris）。

**Acceptance Criteria:**

**Given** child.c 中已經忽略 SIGPIPE（Story 2.3）
**When** Child process 準備開始讀取客戶端數據
**Then** 必須在 `signal(SIGPIPE, SIG_IGN)` 之後，立即呼叫 `setsockopt()`

**And** 必須正確設置以下參數：
- socket fd: `client_fd`
- level: `SOL_SOCKET`
- optname: `SO_RCVTIMEO`
- optval: 指向 `struct timeval` 的指標，設置合理的逾時值（建議 5-10 秒）
- optlen: `sizeof(struct timeval)`

**And** 設置成功後，任何 `read()` 操作如果在逾時時間內沒有收到數據，將回傳 -1 並設置 errno 為 EAGAIN 或 ETIMEDOUT

**And** **[條件編譯]** 此功能必須被 `#ifndef NO_ROBUST` 包圍

**Prerequisites:** Story 2.3（SIGPIPE 處理）

**Technical Notes:**
- `struct timeval tv = {.tv_sec = 5, .tv_usec = 0};`
- Slowloris 攻擊會建立大量連線但不發送數據，佔滿 server 的連線池
- 參考 architecture.md 第 4.1 節的 R2 實作說明
- 驗證：執行 `attacks/attack_2_slowloris.sh` 確認 server_good 會自動清理超時連線

---

### Story 2.5: 實作 I/O 錯誤檢查

**As a** 開發者 (Developer),
**I want** server_good 的 Child process 嚴格檢查 `read()` 和 `write()` 的回傳值,
**So that** 它可以優雅地處理正常的 Client 斷線（read 回傳 0）或異常斷線（EPIPE / ECONNRESET / ETIMEDOUT）。

**Acceptance Criteria:**

**Given** child.c 中已經設置了 I/O 逾時（Story 2.4）和 SIGPIPE 忽略（Story 2.3）
**When** Child process 執行 read() 或 write() 操作
**Then** `handle_client()` 中的 `read()` 呼叫必須檢查回傳值

**And** 如果 `read()` 回傳 0（正常 EOF，Client 主動關閉連線），必須記錄 `log_debug("Client closed connection")` 並正常 `exit(0)`
**And** 如果 `read()` 回傳 -1，必須檢查 `errno`：
- 如果 errno 為 ECONNRESET（連線被 reset），記錄 log 並正常 exit
- 如果 errno 為 ETIMEDOUT 或 EAGAIN（來自 Story 2.4 的逾時），記錄 log 並正常 exit
- 其他錯誤，記錄 log 並正常 exit

**And** `handle_client()` 中的 `write()` 呼叫必須檢查回傳值
**And** 如果 `write()` 回傳 -1，必須檢查 `errno`：
- 如果 errno 為 EPIPE（來自 Story 2.3 忽略 SIGPIPE 後的結果），記錄 log 並正常 exit
- 如果 errno 為 ECONNRESET，記錄 log 並正常 exit

**And** **[重要]** 這些錯誤檢查**不需要**被 `#ifndef NO_ROBUST` 包圍，因為它們是良好程式設計的基礎（但 server_bad 仍會因為沒有 Story 2.3 的 SIG_IGN 而在 write 時崩潰）

**Prerequisites:** Story 2.3（SIGPIPE 忽略）、Story 2.4（I/O 逾時）

**Technical Notes:**
- 使用 `#include <errno.h>` 和 `strerror(errno)` 來記錄詳細錯誤訊息
- 這些錯誤處理確保 Child process 永遠不會因為 I/O 錯誤而異常退出
- 參考 architecture.md 第 4.1 節的 R4 補充說明
- 參考 PRD NFR5 的錯誤處理要求

---

### Story 2.6: 建立 server_good 建置目標

**As a** 開發者 (Developer),
**I want** CMakeLists.txt 能夠建置 server_good,
**So that** 我可以產生一個包含所有穩健性機制（NFR2-NFR6）的最終伺服器執行檔。

**Acceptance Criteria:**

**Given** 所有穩健性機制（Story 2.1-2.5）都已實作完成
**When** 我執行 CMake 建置
**Then** CMakeLists.txt 必須定義一個 `server_good` 建置目標

**And** `server_good` 目標必須編譯以下原始碼檔案：
- `src/server/server.c`
- `src/server/child.c`
- `src/server/signal.c`（來自 Story 2.1）

**And** `server_good` 目標必須連結 `libutils.so`
**And** `server_good` 目標**不得**定義 `NO_ROBUST` 旗標，確保所有 `#ifndef NO_ROBUST` 區塊都被編譯進去
**And** 執行 `cmake --build build --target server_good` 必須成功生成 `build/server_good` 執行檔

**And** **驗證**：執行 `./build/server_good 8080` 和 `./build/client 127.0.0.1 8080`，必須能夠完成正常的 GET_SYS_INFO 通訊，並且在面對攻擊腳本時表現穩定

**Prerequisites:** Story 2.1-2.5（所有穩健性機制）

**Technical Notes:**
- 參考 architecture.md 第 6 節的 CMakeLists.txt 概念範例
- server_good 和 server_bad 共享相同的原始碼檔案，只是編譯旗標不同
- 建議將 server_good 設為預設建置目標（`make all` 或 `cmake --build build`）

---

### Story 2.7: 建立攻擊腳本

**As a** 開發者 (Developer),
**I want** 建立 SOP.md 中定義的三個攻擊腳本,
**So that** 我可以執行 K3 成功指標，展示 server_bad 的脆弱性和 server_good 的穩健性。

**Acceptance Criteria:**

**Given** server_bad 和 server_good 都已經能夠成功建置（Story 1.8, 2.6）
**When** 我建立攻擊腳本
**Then** 必須在 `attacks/` 目錄下建立 `attack_1_zombie.sh` 腳本

**And** `attack_1_zombie.sh` 必須：
- 啟動多個（例如 20 個）客戶端連線
- 每個連線在發送請求後立即斷開
- 用於測試是否產生殭屍進程

**And** 必須在 `attacks/` 目錄下建立 `attack_2_slowloris.sh` 腳本
**And** `attack_2_slowloris.sh` 必須：
- 建立多個（例如 15 個）連線
- 連線後不發送任何數據，持續佔用連線
- 用於測試 I/O 逾時機制

**And** 必須在 `attacks/` 目錄下建立 `attack_3_sigpipe.sh` 腳本
**And** `attack_3_sigpipe.sh` 必須：
- 連線到伺服器
- 在伺服器開始回寫數據前就關閉 socket
- 用於測試 SIGPIPE 處理

**And** 所有腳本必須具有可執行權限（`chmod +x attacks/*.sh`）
**And** 腳本必須包含清晰的註解說明用途和預期結果

**Prerequisites:** Story 1.8（server_bad）、Story 2.6（server_good）

**Technical Notes:**
- 可以使用 `nc` (netcat)、`telnet` 或簡單的 bash + `/dev/tcp/` 來實作
- 或建立簡單的 C 語言攻擊程式（例如 `attacks/zombie_client.c`）
- 參考 architecture.md 第 4.2 節的攻擊腳本說明
- 攻擊腳本的輸出應該便於在 SOP.md 中展示

---

### Story 2.8: 撰寫 SOP 與最終報告

**As a** 助教 (TA) / 教授 (Primary User),
**I want** 一份 SOP 展示文件（FR8）和一份包含 tcpdump 分析的最終報告（FR7）,
**So that** 我可以驗證專案是否符合所有穩健性要求（K3）和網路分析要求（K4）。

**Acceptance Criteria:**

**Given** 所有程式碼（server_bad、server_good、client、攻擊腳本）都已完成
**And** 我已經執行了所有攻擊腳本並擷取了相關截圖
**When** 我撰寫最終交付文件
**Then** 必須建立 `SOP.md`（或 `report/SOP.md`）

**And** SOP.md 必須包含以下章節：
- 編譯步驟（如何建置 server_good 和 server_bad）
- 執行步驟（如何啟動伺服器和客戶端）
- 攻擊腳本使用說明（如何執行三個攻擊腳本）
- 預期結果對比（server_bad 的失敗現象 vs. server_good 的成功防禦）
- 驗證步驟（使用 `ps aux`、`netstat` 等命令驗證結果）

**And** 必須建立 `report/report.md`（或主 `README.md`）
**And** report.md 必須包含以下內容：
- 專案概述和設計說明（可引用 architecture.md）
- tcpdump 封包擷取和分析（至少包含一次完整的 Client-Server 通訊）
- 執行截圖（來自 SOP 的展示步驟）
- Good vs. Bad Server 對比分析
- 穩健性機制的技術說明

**And** 必須包含或連結一個 2 分鐘的展示影片
**And** 影片必須展示：
- 編譯和執行過程
- 至少一個攻擊腳本的效果對比
- tcpdump 或 Wireshark 的封包分析

**Prerequisites:** Story 2.1-2.7（所有實作和攻擊腳本）

**Technical Notes:**
- 使用 `sudo tcpdump -i lo -w capture.pcap port 8080` 擷取封包
- 使用 `tcpdump -r capture.pcap -A` 或 Wireshark 分析封包內容
- 截圖工具建議：`scrot`、macOS Screenshot、或 Windows Snipping Tool
- 影片錄製工具建議：OBS Studio、QuickTime、或 SimpleScreenRecorder
- 參考 PRD FR7 和 FR8 的交付要求

---

_For implementation: Use the `create-story` workflow to generate individual story implementation plans from this epic breakdown._

