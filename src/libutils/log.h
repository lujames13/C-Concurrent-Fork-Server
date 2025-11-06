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
