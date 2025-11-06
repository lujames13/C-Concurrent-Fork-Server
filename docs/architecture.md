# 網路系統程式開發課 - 技術架構文件

**版本**: 1.1  
**日期**: 2025-11-06  
**架構師**: Winston (BMad Architect)

---

## 1. 簡介 (Introduction)

這份文件概述了「網路系統程式開發課期中考」專案的整體架構。它涵蓋了後端伺服器、客戶端應用程式、共享函式庫以及兩者之間的通訊協定。本架構的主要目標是指導 AI 驅動的開發，確保程式碼的一致性，並精確實作所有穩健性機制（fork() 管理、訊號處理、I/O 逾時），以滿足專案簡報中定義的核心需求。

### 1.1 啟動範本或現有專案 (Starter Template or Existing Project)

根據專案簡報，這是一個「Greenfield」（全新）專案，將從頭開始撰寫。

**決策**：我們不會使用任何外部的 starter template。

**理由**：考試的核心要求是手動且正確地處理底層系統呼叫（如 socket, bind, listen, accept, fork, waitpid）。使用框架或範本會隱藏這些關鍵細節，違背了專案的學習目標。我們將手動建立所有檔案，包括 CMakeLists.txt。

### 1.2 變更日誌 (Change Log)

| 日期 | 版本 | 描述 | 作者 |
|------|------|------|------|
| 2025-11-06 | 1.1 | 更新展示策略與源碼樹以對齊 SOP v1.1 | Winston (Architect) |
| 2025-11-06 | 1.0 | 初始架構文件建立 | Winston (Architect) |

---

## 2. 高層架構 (High-Level Architecture)

本節定義了專案的整體架構風格、技術平台和核心設計模式。

### 2.1 技術摘要 (Technical Summary)

這是一個基於 C 語言的 POSIX 相容、事件驅動的 Client-Server 應用程式。架構核心採用「Process-per-Client」模型，透過 fork() 系統呼叫實現並行處理。伺服器主進程負責監聽 (listen) 和接受 (accept) 連線，而子進程 (child processes) 負責處理客戶端的所有 I/O。

為了提高程式碼的重用性和可維護性，日誌系統和 I/O 封裝等共享功能將被編譯為一個動態共享函式庫 (.so)。

此架構的重點是穩健性，透過明確的訊號處理 (Signal Handling)、I/O 逾時 (Timeouts) 和資源回收 (Process Reaping) 來確保伺服器在面對異常連線和攻擊時的穩定性。

### 2.2 平台與基礎設施 (Platform & Infrastructure)

- **平台**: 任何 POSIX 相容的類 Unix 系統
- **主要開發/測試環境**: Linux (例如 Ubuntu 22.04 LTS)
- **理由**: 這是滿足 fork()、waitpid()、.so 函式庫、CMake/Makefile 和 tcpdump 等所有考試要求的標準環境

### 2.3 儲存庫結構 (Repository Structure)

- **結構**: Monorepo (單一儲存庫)
- **理由**: 由於 Client、Server 和共享函式庫三者緊密相關且需同時開發，使用 Monorepo 可以簡化建置流程和版本控制

### 2.4 架構圖 (Architecture Diagram)

```
Development & Build:
  CMakeLists.txt
    ├─ Build Server
    ├─ Build Client
    └─ Build libutils.so

Runtime Environment (Linux):
  Client Apps (多個實例)
    └─ 連線到 TCP

  Server Process (Parent, PID 100)
    ├─ Listen()
    └─ Accept()
        ├─ fork() → Child Process 1 (PID 101)
        │   ├─ Handle Client
        │   ├─ libutils.so
        │   └─ exec(uptime)
        │
        └─ fork() → Child Process 2 (PID 102)
            ├─ Handle Client
            ├─ libutils.so
            └─ exec(uname)

  OS Kernel
    ├─ Child 進程退出
    ├─ 發送 SIGCHLD
    └─ Parent waitpid()
```

### 2.5 架構模式 (Architectural Patterns)

#### fork() (Process-per-Client)

**描述**：這是本專案的核心限制。主進程 (Parent) 接受 (accept) 新連線後，立即 fork() 一個新的子進程 (Child) 來處理該連線的整個生命週期。

**理由**：滿足考試要求 (C1)。

#### 動態共享函式庫 (.so) (Shared Library)

**描述**：將所有 Client 和 Server 均需使用的通用程式碼（特別是日誌系統）編譯成一個 libutils.so 檔案。

**理由**：滿足考試要求 (C4)，並實踐了 DRY 原則。

#### 訊號處理 (Signal Handling)

**描述**：為關鍵訊號（SIGCHLD, SIGPIPE）註冊 handler，或設置忽略。

**理由**：這是穩健性 (Robustness) 的核心，用以防止殭屍進程和意外崩潰。

#### I/O 逾時 (Socket I/O Timeouts)

**描述**：在 Child process 中，對 Client socket 設置 SO_RCVTIMEO。

**理由**：這是防禦 Slowloris 攻擊（R2 風險）的關鍵機制。

---

## 3. 技術堆疊與 API (Tech Stack & API)

本節定義專案的具體技術選型、共享函式庫 (libutils.so) 的 API 介面，以及客戶端-伺服器之間的通訊協定。

### 3.1 技術堆疊 (Technology Stack)

| 類別 | 技術 | 版本 | 目的 | 理由 |
|------|------|------|------|------|
| 語言 | C | C11 (or C99) | 專案開發 | 滿足考試要求 (C2) |
| 編譯器 | GCC / Clang | System Default | 編譯 C 程式碼 | POSIX 環境標準 |
| 建置系統 | CMake | 3.16+ (or Make) | 自動化建置 Server, Client, 和 .so | 滿足考試要求 (C5) |
| 核心 API | POSIX Sockets | System API | 網路通訊 | 標準 C 語言網路介面 |
| 並行模型 | fork() | System Call | 處理並行連線 | 滿足考試要求 (C1) |
| 函式庫 | Dynamic Shared Lib (.so) | Linux format | 程式碼共享 | 滿足考試要求 (C4) |
| 偵錯 | GDB | System Default | 程式偵錯 | 標準 C 語言偵錯器 |
| 網路分析 | tcpdump / netstat | System Tools | 網路封包分析與連線驗證 | 滿足考試要求 (A3), (K4) |

### 3.2 libutils.so 共享函式庫 API 介面

libutils.so 將提供日誌功能。

#### log.h (標頭檔)

```c
#ifndef LOG_H
#define LOG_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h> // for va_list, va_start, va_end

/**
 * == 日誌層級 (Logging Levels) ==
 * 0: (LOG_LEVEL_NONE) - 安靜模式
 * 1: (LOG_LEVEL_INFO) - 僅顯示標準資訊 (預設)
 * 2: (LOG_LEVEL_DEBUG) - 顯示詳細的 DEBUG 訊息
 */
#define LOG_LEVEL_NONE 0
#define LOG_LEVEL_INFO 1
#define LOG_LEVEL_DEBUG 2

/**
 * @brief 初始化日誌系統。
 * @param level 執行時期的日誌層級 (0, 1, 或 2)。
 */
void log_init(int level);

/**
 * @brief 獲取當前的日誌層級。
 * @return int 當前的日誌層級。
 */
int get_log_level();

/**
 * @brief 寫入一條 INFO 層級的日誌 (總是被印出，除非層級為 NONE)。
 * @param format printf 格式的字串。
 * @param ... 變數參數。
 */
void log_info(const char *format, ...);

/**
 * @brief 寫入一條 DEBUG 層級的日誌 (僅在層級為 DEBUG 時印出)。
 * @param format printf 格式的字串。
 * @param ... 變數參數。
 */
void log_debug(const char *format, ...);

/**
 * == 編譯時期 (Compile-time) 日誌控制 ==
 * 如果定義了 NDEBUG (例如 -DNDEBUG)，
 * 則 log_debug() 宏將被編譯為空操作，
 * 這樣在 Release build 中它不會有任何效能開銷。
 */
#ifdef NDEBUG
    // 在 Release 模式下，將 log_debug 宏定義為空
    #define COMPILE_TIME_LOG_DEBUG(format, ...) ((void)0)
#else
    // 在 Debug 模式下，它就是標準的 log_debug 函式
    #define COMPILE_TIME_LOG_DEBUG(format, ...) log_debug(format, ##__VA_ARGS__)
#endif

#endif // LOG_H
```

### 3.3 Client-Server 通訊協定

**Client 請求**：Client 連線成功後，發送一個固定的字串請求：
```
GET_SYS_INFO\n
```

**Server 回應 (成功)**：Server (Child process) 收到請求，執行 uptime (或 uname -a)，並將其 stdout 完整地重新導向回 client socket。

**Server 回應 (失敗 / 忙碌)**：如果 fork() 失敗，Server (Parent process) 將發送一個錯誤訊息字串：
```
SERVER_BUSY\n
```
然後伺服器會立即 close() 這個連線。

---

## 4. 穩健性機制與展示策略 (Robustness & Demonstration)

本節定義了「Good Server」必須實作的關鍵穩健性機制，以及我們將如何透過「Bad Server」來展示缺少這些機制時的災難性後果。

### 4.1 穩健性實作 (Good Server)

「Good Server」將實作以下所有機制：

#### R1 (防禦殭屍進程)

**SIGCHLD 處理機制**：在 Parent process（server_app）中，我們將註冊一個 SIGCHLD 訊號的 handler。

**實作 (signal.c)**：這個 handler 必須是 async-signal-safe 的。它將在一個迴圈中呼叫 `waitpid(-1, NULL, WNOHANG)`，直到沒有更多已退出的 child process 需要回收。

#### R2 (防禦 Slowloris)

**I/O 逾時 (Timeout) 機制**：在 Child process 中，一旦 fork() 成功，但在進入 read() 迴圈之前，我們將使用 setsockopt()。

**實作 (child.c)**：呼叫 `setsockopt(client_fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv))`，其中 struct timeval tv 將設置一個短暫的逾時（例如：5 秒）。

#### R3 (防禦資源耗盡)

**fork() 失敗處理機制**：在 Parent process 中，在 accept() 之後，fork() 的回傳值將被嚴格檢查。

**實作 (server.c)**：

```c
pid_t pid = fork();
if (pid == -1) {
    // fork 失敗
    log_info("fork() failed: %s", strerror(errno));
    // 傳送 SERVER_BUSY 給 client
    write(client_fd, "SERVER_BUSY\n", 14);
    close(client_fd);
    // sleep 一小段時間防止熱迴圈
    sleep(1);
} else if (pid == 0) {
    // ... Child process code ...
} else {
    // ... Parent process code (只需 close(client_fd)) ...
}
```

#### R4 (防禦斷線崩潰)

**SIGPIPE 處理機制**：在所有 Child process 中，我們必須忽略 SIGPIPE 訊號。

**實作 (child.c)**：在 fork() 成功後，Child process 中的第一件事就是呼叫 `signal(SIGPIPE, SIG_IGN)`。

### 4.2 展示策略 (Bad Server vs. Good Server)

我們將使用編譯時期旗標 (Compile-time Flags) 來控制這些機制的啟用，從而產生兩個版本的 Server。

**CMakeLists.txt (或 Makefile) 將定義**：

- `make server_good` (預設)：編譯 server_good，包含所有穩健性機制。
- `make server_bad`：編譯 server_bad，排除所有穩健性機制（例如：使用 `-DNO_ROBUST` 旗標）。

**程式碼中的條件編譯**：

```c
// --- In server.c (Parent) ---
#ifndef NO_ROBUST
    // Good Server: 註冊 SIGCHLD handler
    setup_sigchld_handler();
#endif

// --- In child.c (Child) ---
#ifndef NO_ROBUST
    // Good Server: 忽略 SIGPIPE
    signal(SIGPIPE, SIG_IGN);
    // Good Server: 設置 I/O 逾時
    setup_socket_timeout(client_fd);
#endif
```

**攻擊腳本 (Attack Scripts)**：我們將建立三個獨立的腳本來模擬特定的攻擊情境。

**情境 1 (殭屍進程 - R1)**：`attacks/attack_1_zombie.sh` 腳本會啟動大量客戶端，連線後立即斷開，用於測試 `server_bad` 是否會累積殭屍進程。

**情境 2 (Slowloris / 資源佔用 - R2)**：`attacks/attack_2_slowloris.sh` 腳本會啟動多個連線，但故意不發送任何數據，用於測試 `server_bad` 的連線池是否會被佔滿。

**情境 3 (寫入時斷線 - R4)**：`attacks/attack_3_sigpipe.sh` 腳本會連線，但在伺服器回寫數據前就關閉 socket，用於測試 `server_bad` 的子進程是否會因此崩潰。

**預期展示結果 (K3)**：

**執行 server_bad**：
- 執行對應的攻擊腳本。
- `ps aux` 會顯示大量殭屍進程 (情境 1)，或 `netstat` 顯示連線被佔滿 (情境 2)，或子進程崩潰 (情境 3)。
- 伺服器最終失效或表現不穩定。

**執行 server_good**：
- 執行相同的攻擊腳本。
- 伺服器能正確回收子進程、清除超時連線、並優雅地處理寫入錯誤，保持正常服務。

---

## 5. 原始碼樹狀結構 (Source Tree)

這定義了我們 Monorepo 的檔案和目錄結構。

```
network-midterm/
├── .gitignore
├── CMakeLists.txt              # [核心] 主建置腳本
├── README.md                   # 專案說明
├── attacks/                    # 存放攻擊腳本
│   ├── attack_1_zombie.sh
│   ├── attack_2_slowloris.sh
│   └── attack_3_sigpipe.sh
├── build/                      # [Git 忽略] 編譯輸出目錄
├── lib/                        # [Git 忽略] 安裝 .so 和 .h 的目錄
├── report/                     # 存放期中報告
│   ├── report.md
│   └── network_capture.pcap    # tcpdump 封包
└── src/                        # 原始碼
    ├── client/                 # 客戶端
    │   └── client.c
    ├── server/                 # 伺服器
    │   ├── server.c            # Main process (listen, accept, fork)
    │   ├── child.c             # Child process 邏輯 (I/O, timeout)
    │   ├── child.h
    │   ├── signal.c            # Signal handlers (SIGCHLD)
    │   └── signal.h
    └── libutils/               # 共享函式庫
        ├── log.c               # 日誌系統的實作
        └── log.h               # 日誌 API (如 3.2 節所定義)
```

---

## 6. 建置系統 (Build System)

我們將使用 CMake 來實現 `-DNO_ROBUST` 旗標的控制。

### CMakeLists.txt (主建置腳本 - 概念)

```cmake
cmake_minimum_required(VERSION 3.10)
project(NetworkMidterm C)

# --- 1. 定義共享函式庫 (libutils) ---
add_library(utils SHARED src/libutils/log.c)
target_include_directories(utils PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src/libutils)

# --- 2. 編譯 "Good Server" (server_good) ---
add_executable(server_good
    src/server/server.c
    src/server/child.c
    src/server/signal.c
)
target_link_libraries(server_good utils)

# --- 3. 編譯 "Bad Server" (server_bad) ---
add_executable(server_bad
    src/server/server.c
    src/server/child.c
    src/server/signal.c
)
# [關鍵] 添加 -DNO_ROBUST 旗標，這會在程式碼中禁用穩健性機制
target_add_definitions(server_bad PRIVATE NO_ROBUST)
target_link_libraries(server_bad utils)

# --- 4. 編譯 Client ---
add_executable(client src/client/client.c)
target_link_libraries(client utils)
```

---

**文件結束**
