# C-Concurrent-Fork-Server - Standard Operating Procedure (SOP)

**作者:** James
**日期:** 2025-11-06
**版本:** 1.0
**專案:** Network System Programming - Midterm Project

---

## 目錄

1. [專案概述](#專案概述)
2. [編譯步驟](#編譯步驟)
3. [執行步驟](#執行步驟)
4. [攻擊腳本使用說明](#攻擊腳本使用說明)
5. [預期結果對比](#預期結果對比)
6. [驗證步驟](#驗證步驟)

---

## 專案概述

本專案實作了一個基於 fork() 並行模型的 Client-Server 系統，並展示「Good vs. Bad Server」的對比：

- **server_bad**: 功能正常但缺乏穩健性機制（編譯時定義 `NO_ROBUST`）
- **server_good**: 包含完整穩健性機制的生產級伺服器

### 關鍵穩健性機制

| 機制 | 目的 | 防禦的攻擊 |
|------|------|-----------|
| SIGCHLD 處理 | 自動回收子進程 | 殭屍進程累積 |
| fork() 失敗處理 | 避免 CPU 熱迴圈 | 資源耗盡 |
| SIGPIPE 忽略 | 防止寫入崩潰 | 斷線攻擊 |
| SO_RCVTIMEO 超時 | 清理閒置連線 | Slowloris DoS |
| I/O 錯誤檢查 | 優雅處理異常 | 各種網路異常 |

---

## 編譯步驟

### 前置需求

- CMake 3.10+
- GCC (支援 C11)
- netcat (nc) - 用於測試和攻擊腳本

### 編譯指令

```bash
# 1. 進入專案目錄
cd /path/to/C-Concurrent-Fork-Server

# 2. 使用 CMake 建置
cmake -B build
cmake --build build

# 3. 驗證編譯結果
ls -lh build/
```

### 編譯輸出

成功編譯後會產生以下執行檔：

```
build/libutils.so       - 共享函式庫（日誌系統）
build/server_good       - 穩健版伺服器
build/server_bad        - 脆弱版伺服器
build/client            - 客戶端程式
build/client_release    - Release 版客戶端（NDEBUG）
```

### 編譯差異

| 執行檔 | 編譯旗標 | 穩健性機制 |
|--------|---------|----------|
| server_good | 無 | ✅ 啟用全部 |
| server_bad | `-DNO_ROBUST` | ❌ 全部停用 |

---

## 執行步驟

### 1. 啟動伺服器

#### 啟動 server_bad (脆弱版)

```bash
# 基本啟動
./build/server_bad 8080

# 啟用 debug 日誌
./build/server_bad -d 8080
```

#### 啟動 server_good (穩健版)

```bash
# 基本啟動
./build/server_good 8080

# 啟用 debug 日誌
./build/server_good -d 8080
```

### 2. 執行客戶端

```bash
# 基本連線
./build/client 127.0.0.1 8080

# 客戶端會自動發送 GET_SYS_INFO 請求並顯示回應
```

### 3. 正常通訊流程

```bash
# 終端機 1: 啟動伺服器
./build/server_good 8080

# 終端機 2: 執行客戶端
./build/client 127.0.0.1 8080
```

**預期輸出:**

```
# Client 端:
Connected to server 127.0.0.1:8080
GET_SYS_INFO message sent
 20:00:00 up 10 min,  1 user,  load average: 0.15, 0.20, 0.18

# Server 端:
Server listening on port 8080
Connection accepted from client
Forked child process (PID: 1234)
```

---

## 攻擊腳本使用說明

所有攻擊腳本位於 `attacks/` 目錄。

### Attack 1: Zombie Process Attack (殭屍進程攻擊)

**目的:** 測試 SIGCHLD 處理機制

```bash
# 執行攻擊
./attacks/attack_1_zombie.sh 8080

# 驗證結果
ps aux | grep defunct | grep -v grep
```

**預期結果:**
- **server_bad**: 顯示大量 defunct (zombie) 進程
- **server_good**: 無殭屍進程

### Attack 2: Slowloris Attack (連線池耗盡攻擊)

**目的:** 測試 SO_RCVTIMEO 超時機制

```bash
# 執行攻擊 (會持續 10 秒)
./attacks/attack_2_slowloris.sh 8080

# 在另一個終端監控子進程數量
watch -n 1 'pgrep -P $(pgrep -f "server_good 8080") | wc -l'
```

**預期結果:**
- **server_bad**: 15 個子進程持續存在，佔用連線池
- **server_good**: 5 秒後自動清理，子進程歸零

### Attack 3: SIGPIPE Attack (斷線崩潰攻擊)

**目的:** 測試 SIGPIPE 忽略機制

```bash
# 執行攻擊
./attacks/attack_3_sigpipe.sh 8080

# 驗證伺服器仍在運行
pgrep -af "server_good 8080"
```

**預期結果:**
- **server_bad**: 子進程可能崩潰（取決於時序）
- **server_good**: 所有子進程正常處理，伺服器穩定

---

## 預期結果對比

### 完整對比表

| 攻擊類型 | 檢測指令 | server_bad 結果 | server_good 結果 |
|---------|---------|----------------|-----------------|
| **Zombie Attack** | `ps aux \| grep defunct` | ❌ 20+ 殭屍進程 | ✅ 0 殭屍進程 |
| **Slowloris** | `pgrep -P $PID \| wc -l` | ❌ 15 個持續佔用 | ✅ 5秒後歸零 |
| **SIGPIPE** | `pgrep -f server` | ❌ 可能崩潰 | ✅ 穩定運行 |

### 詳細現象

#### server_bad 的脆弱性

1. **殭屍進程累積**
   ```bash
   $ ps aux | grep defunct
   user  1234  0.0  0.0  0  0 ?  Z  20:00  0:00 [server_bad] <defunct>
   user  1235  0.0  0.0  0  0 ?  Z  20:00  0:00 [server_bad] <defunct>
   ...（持續累積）
   ```

2. **連線池耗盡**
   - Slowloris 攻擊後，新客戶端無法連線
   - 子進程持續佔用資源

3. **SIGPIPE 崩潰風險**
   - 快速斷線可能導致 child process 異常

#### server_good 的穩健性

1. **自動資源回收**
   ```bash
   $ ps aux | grep defunct
   # (無輸出 - 無殭屍進程)
   ```

2. **自動超時清理**
   - 閒置 5 秒後自動關閉連線
   - 連線池永不耗盡

3. **優雅錯誤處理**
   - 所有異常都被捕獲並記錄
   - 伺服器持續穩定運行

---

## 驗證步驟

### 1. 驗證基本功能

```bash
# 啟動伺服器
./build/server_good 8080 &
SERVER_PID=$!

# 測試正常通訊
./build/client 127.0.0.1 8080

# 應該看到系統資訊輸出
```

### 2. 驗證 SIGCHLD 處理

```bash
# 執行殭屍攻擊
./attacks/attack_1_zombie.sh 8080

# 等待 2 秒
sleep 2

# 檢查殭屍進程
ps aux | grep defunct | grep -v grep

# 預期: server_good 無殭屍進程
```

### 3. 驗證 Slowloris 防禦

```bash
# 在背景執行 Slowloris 攻擊
./attacks/attack_2_slowloris.sh 8080 &

# 實時監控子進程數
watch -n 1 'pgrep -P $(pgrep -f "server_good 8080") | wc -l'

# 預期: 初始 15 個 → 5秒後 → 0 個
```

### 4. 驗證 SIGPIPE 防護

```bash
# 執行 SIGPIPE 攻擊
./attacks/attack_3_sigpipe.sh 8080

# 檢查伺服器是否仍在運行
ps aux | grep "server_good 8080" | grep -v grep

# 預期: 伺服器仍穩定運行
```

### 5. 驗證日誌系統

```bash
# 使用 -d 啟動 debug 模式
./build/server_good -d 8080

# 連線客戶端
./build/client 127.0.0.1 8080

# 預期看到詳細的 debug 訊息
```

### 6. 綜合測試腳本

```bash
# 執行完整測試套件
./tests/test_server_good.sh

# 預期: 所有測試通過
```

---

## 總結

本 SOP 涵蓋了：

✅ 完整的編譯指令
✅ 伺服器和客戶端的啟動方式
✅ 三個攻擊腳本的使用方法
✅ server_bad vs. server_good 的對比
✅ 詳細的驗證步驟

透過這些步驟，可以清楚展示穩健性機制的必要性和有效性。

---

**相關文件:**
- [架構文件](docs/architecture.md)
- [PRD](docs/prd.md)
- [Epic 分解](docs/epics.md)
- [最終報告](README.md)
