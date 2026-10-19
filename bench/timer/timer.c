/*
 * bench-timer: runs one command and prints its cost as a single JSON line.
 *
 *   timer [--timeout-ms N] [--stdout FILE] [--cpus LIST] -- cmd args...
 *
 * Built as a static binary and mounted into every toolchain container, so
 * timings exclude `docker exec` startup. LIST is a cpu list such as "1" or
 * "0-1"; the child is pinned to it before exec.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static double now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

static double tv_ms(struct timeval tv) {
    return tv.tv_sec * 1000.0 + tv.tv_usec / 1000.0;
}

static int parse_cpus(const char *list, cpu_set_t *set) {
    CPU_ZERO(set);
    char *copy = strdup(list);
    if (!copy) return -1;
    char *save = NULL;
    for (char *tok = strtok_r(copy, ",", &save); tok; tok = strtok_r(NULL, ",", &save)) {
        int lo, hi;
        if (sscanf(tok, "%d-%d", &lo, &hi) == 2) {
            for (int c = lo; c <= hi; c++) CPU_SET(c, set);
        } else if (sscanf(tok, "%d", &lo) == 1) {
            CPU_SET(lo, set);
        } else {
            free(copy);
            return -1;
        }
    }
    free(copy);
    return 0;
}

static void fail(const char *msg) {
    printf("{\"error\":\"%s\",\"errno\":%d}\n", msg, errno);
    exit(2);
}

int main(int argc, char **argv) {
    long timeout_ms = 0;
    const char *stdout_path = NULL;
    const char *cpus = NULL;
    int i = 1;
    for (; i < argc; i++) {
        if (strcmp(argv[i], "--") == 0) { i++; break; }
        if (strcmp(argv[i], "--timeout-ms") == 0 && i + 1 < argc) timeout_ms = atol(argv[++i]);
        else if (strcmp(argv[i], "--stdout") == 0 && i + 1 < argc) stdout_path = argv[++i];
        else if (strcmp(argv[i], "--cpus") == 0 && i + 1 < argc) cpus = argv[++i];
        else fail("bad arguments");
    }
    if (i >= argc) fail("missing command");

    cpu_set_t set;
    if (cpus && parse_cpus(cpus, &set) != 0) fail("bad cpu list");

    double start = now_ms();
    pid_t pid = fork();
    if (pid < 0) fail("fork failed");
    if (pid == 0) {
        setpgid(0, 0);
        if (cpus && sched_setaffinity(0, sizeof(set), &set) != 0) _exit(126);
        int fd = open(stdout_path ? stdout_path : "/dev/null", O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) _exit(126);
        dup2(fd, STDOUT_FILENO);
        close(fd);
        execvp(argv[i], &argv[i]);
        _exit(127);
    }

    int status = 0;
    int timed_out = 0;
    struct rusage ru;
    memset(&ru, 0, sizeof(ru));
    for (;;) {
        pid_t r = wait4(pid, &status, WNOHANG, &ru);
        if (r == pid) break;
        if (r < 0 && errno != EINTR) fail("wait4 failed");
        if (!timed_out && timeout_ms > 0 && now_ms() - start > timeout_ms) {
            timed_out = 1;
            kill(-pid, SIGKILL);
            kill(pid, SIGKILL);
        }
        struct timespec nap = {0, 500000};
        nanosleep(&nap, NULL);
    }
    double wall = now_ms() - start;

    int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
    int sig = WIFSIGNALED(status) ? WTERMSIG(status) : 0;
    printf("{\"exit\":%d,\"signal\":%d,\"timeout\":%s,\"wall_ms\":%.3f,"
           "\"user_ms\":%.3f,\"sys_ms\":%.3f,\"maxrss_kb\":%ld}\n",
           exit_code, sig, timed_out ? "true" : "false", wall,
           tv_ms(ru.ru_utime), tv_ms(ru.ru_stime), ru.ru_maxrss);
    return 0;
}
