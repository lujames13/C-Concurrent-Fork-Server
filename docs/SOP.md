# 網路系統程式開發課 - SOP 展示文件

**版本**: 1.1

---

## 文件目的

本 SOP 旨在引導使用者（助教/教授）重現 (reproduce) 本專案的三個核心穩健性機制。我們將透過執行三個獨立的攻擊腳本，來對比「穩健的伺服器 (Good Server)」和「脆弱的伺服器 (Bad Server)」在面對特定攻擊時的不同表現。

---

## 系統架構

- **server_good**: 預設編譯的伺服器，包含所有穩健性機制。
- **server_bad**: 特殊編譯的伺服器，排除了所有穩健性機制（使用 `-DNO_ROBUST` 旗標編譯）。
- **attacks/attack_1_zombie.sh**: 模擬「快速連線/斷線」攻擊，用於測試殭屍進程 (R1)。
- **attacks/attack_2_slowloris.sh**: 模擬「慢速連線」攻擊，用於測試 I/O 逾時 (R2)。
- **attacks/attack_3_sigpipe.sh**: 模擬「寫入時斷線」攻擊，用於測試 SIGPIPE 崩潰 (R4)。

---

## 步驟 1：環境準備與編譯

### 1.1. 環境需求

- Linux 環境 (e.g., Ubuntu 22.04)
- 建置工具：gcc (或 clang), cmake, make
- 網路工具：netstat, ps

### 1.2. 編譯所有目標

在專案根目錄執行：

```bash
mkdir -p build && cd build
cmake ..
make

# [驗證] 檢查 build/ 目錄下是否已產生：
# server_good, server_bad, client
ls -l
```

### 1.3. 賦予攻擊腳本權限

```bash
# 假設腳本放在 attacks/ 目錄下
chmod +x attacks/*.sh
```

---

## 步驟 2：功能驗證 (K1 & K2)

此步驟用於驗證基本功能和 10+ 並行連線，假設 Port 為 8080。

### 2.1. 正常功能 (K1)

**終端機 1 (Server)**：
```bash
./build/server_good 8080
```

**終端機 2 (Client)**：
```bash
./build/client 127.0.0.1 8080
```
應成功取得系統資訊。

### 2.2. 並行 10+ 連線 (K2)

**終端機 3 (Load)**：

```bash
# 啟動 11 個背景 sleep 連線
for i in {1..11}; do (./build/client 127.0.0.1 8080 &); sleep 0.1; done

# 立即驗證並行性
echo "查看並行連線數："
netstat -ptan | grep 8080 | grep ESTABLISHED | wc -l
# 預期輸出: 11 (或更高)
```

---

## 步驟 3：穩健性攻擊展示 (K3)

### 情境 A：攻擊 1 - 殭屍進程 (Zombie Process) (R1)

**目的**：驗證 server_good 的 SIGCHLD handler 是否能正確回收 Child process，防止殭屍。

**腳本**：`attacks/attack_1_zombie.sh` (此腳本會啟動 20 個 Client，發送請求後立即退出)。

#### 3.A.1. 測試 server_bad (預期失敗)

**終端機 1 (Server)**：啟動 server_bad。

```bash
./build/server_bad 8080
```

**終端機 2 (Attack)**：執行殭屍攻擊。

```bash
./attacks/attack_1_zombie.sh 127.0.0.1 8080
```

**終端機 1 (Monitor)**：立即檢查 ps。

```bash
ps aux | grep server_bad
```

**預期失敗**：你會看到大量 `[server_bad] <defunct>` 標記。這些就是「殭屍進程」。server_bad 沒有回收它們，正在耗盡系統資源。

#### 3.A.2. 測試 server_good (預期成功)

**終端機 1 (Server)**：(停止 server_bad) 啟動 server_good (建議使用 `-d` 模式查看日誌)。

```bash
./build/server_good 8080 -d
```

**終端機 2 (Attack)**：再次執行殭屍攻擊。

```bash
./attacks/attack_1_zombie.sh 127.0.0.1 8080
```

**終端機 1 (Monitor)**：檢查 ps。

```bash
ps aux | grep server_good
```

**預期成功**：

- **日誌 (終端機 1)**：你會看到大量 `DEBUG: Handling SIGCHLD, reaping child PID [...]` 的日誌訊息。
- **PS (終端機 1)**：沒有任何 `<defunct>` 殭屍進程。

---

### 情境 B：攻擊 2 - 資源耗盡 (Slowloris) (R2)

**目的**：驗證 server_good 的 SO_RCVTIMEO I/O 逾時是否能清除惡意佔用的連線。

**腳本**：`attacks/attack_2_slowloris.sh` (此腳本會啟動 15 個 Client，連線後保持連線，但不發送任何數據)。

#### 3.B.1. 測試 server_bad (預期失敗)

**終端機 1 (Server)**：啟動 server_bad。

```bash
./build/server_bad 8080
```

**終端機 2 (Attack)**：執行 Slowloris 攻擊。

```bash
./attacks/attack_2_slowloris.sh 127.0.0.1 8080
```

**終端機 3 (Monitor)**：立即檢查 netstat。

```bash
netstat -ptan | grep 8080 | grep ESTABLISHED | wc -l
```

**預期失敗**：netstat 會顯示 15 個連線被卡住。server_bad 的連線池被佔滿，無法服務任何新客戶（DoS 狀態）。

#### 3.B.2. 測試 server_good (預期成功)

**終端機 1 (Server)**：(停止 server_bad) 啟動 server_good (使用 `-d` 模式)。

```bash
./build/server_good 8080 -d
```

**終端機 2 (Attack)**：再次執行 Slowloris 攻擊。

```bash
./attacks/attack_2_slowloris.sh 127.0.0.1 8080
```

**終端機 3 (Monitor)**：持續監看 netstat。

```bash
watch "netstat -ptan | grep 8080 | grep ESTABLISHED | wc -l"
```

**預期成功**：

- **日誌 (終端機 1)**：你會在 5 秒後看到大量 `DEBUG: Client timed out (SO_RCVTIMEO)` 的訊息。
- **Netstat (終端機 3)**：你會看到連線數達到 15，然後在 5 秒後全部被清除，伺服器恢復正常。

---

### 情境 C：攻擊 3 - 斷線崩潰 (SIGPIPE) (R4)

**目的**：驗證 server_good 的 `signal(SIGPIPE, SIG_IGN)` 是否能防止 Child process 在寫入已斷線 socket 時崩潰。

**腳本**：`attacks/attack_3_sigpipe.sh` (此腳本會連線，但在 Server 回應之前就強制關閉 socket)。

#### 3.C.1. 測試 server_bad (預期失敗)

**終端機 1 (Server)**：啟動 server_bad。

```bash
./build/server_bad 8080
```

**終端機 2 (Attack)**：執行 SIGPIPE 攻擊。

```bash
./attacks/attack_3_sigpipe.sh 127.0.0.1 8080
```

**終端機 1 (Monitor)**：觀察伺服器日誌。

**預期失敗**：server_bad 的 Child process 在嘗試 `write()` 時會收到 SIGPIPE 訊號並立即崩潰 (crash)。

#### 3.C.2. 測試 server_good (預期成功)

**終端機 1 (Server)**：(停止 server_bad) 啟動 server_good (使用 `-d` 模式)。

```bash
./build/server_good 8080 -d
```

**終端機 2 (Attack)**：再次執行 SIGPIPE 攻擊。

```bash
./attacks/attack_3_sigpipe.sh 127.0.0.1 8080
```

**終端機 1 (Monitor)**：觀察伺服器日誌。

**預期成功**：

- **日誌 (終端機 1)**：你會清楚地看到 `DEBUG: write() error: Broken pipe (EPIPE)` 訊息。
- **結果**：Child process 捕獲了 EPIPE 錯誤並正常退出，而不是崩潰。

---

## 步驟 4：執行時期 Debug Mode (G4/A4)

此步驟展示雙層日誌控制中的「執行時期」控制。

### 啟動 (無 Debug)

```bash
# 預設啟動 (INFO Level)
./build/server_good 8080
# 預期輸出: 僅 INFO 訊息 (e.g., "Server started on port 8080")
```

### 啟動 (使用 Debug Mode)

```bash
# 使用 -d 旗標 (DEBUG Level)
./build/server_good 8080 -d
# 預期輸出: 大量的 DEBUG 訊息
# e.g., "DEBUG: Accepting new connection..."
# e.g., "DEBUG: Forking child process..."
# e.g., "DEBUG: Handling SIGCHLD, reaping child PID 1234..."
```

---

## 步驟 5：網路封包分析 (K4)

本步驟展示 tcpdump 的使用。

### 開啟 2 個終端機

**終端機 1 (tcpdump)**：

```bash
# 監聽 loopback 介面 (lo) 的 8080 port
sudo tcpdump -i lo -nn -s0 port 8080 -w report/network_capture.pcap
```

**終端機 2 (Client)**：

```bash
# 執行一次正常的 Client-Server 通訊
./build/client 127.0.0.1 8080
```

### 結束封包擷取

終止 tcpdump (在終端機 1 按 Ctrl+C)。

**結果**：`report/network_capture.pcap` 檔案已產生，可用於 Wireshark 分析 TCP 三向交握、GET_SYS_INFO 請求和伺服器回應。

---

**SOP 結束**
