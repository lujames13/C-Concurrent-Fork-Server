#include "log.h"

static int current_log_level = LOG_LEVEL_INFO;

void log_init(int level) {
    if (level >= LOG_LEVEL_NONE && level <= LOG_LEVEL_DEBUG) {
        current_log_level = level;
    }
}

int get_log_level() {
    return current_log_level;
}

void log_info(const char *format, ...) {
    if (current_log_level >= LOG_LEVEL_INFO) {
        va_list args;
        va_start(args, format);
        vprintf(format, args);
        va_end(args);
    }
}

void log_debug(const char *format, ...) {
    if (current_log_level >= LOG_LEVEL_DEBUG) {
        va_list args;
        va_start(args, format);
        printf("[DEBUG] ");
        vprintf(format, args);
        va_end(args);
    }
}
