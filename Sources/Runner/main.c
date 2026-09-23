// A PTY supervisor. stdin is a private liveness/control pipe from Beamlet.
// Its EOF (including an app crash) interrupts only our new child session.
#include <util.h>
#include <sys/wait.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <poll.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static volatile sig_atomic_t stop_requested = 0;
static void stop_signal(int signal_number) { (void)signal_number; stop_requested = 1; }
static double monotonic(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}
static void emit(const char *message) { dprintf(STDERR_FILENO, "BEAMLET_RUNNER_ERROR: %s\n", message); }

int main(int argc, char **argv) {
    // executable, folder, private lock path; remaining arguments are passed verbatim.
    if (argc < 5) { emit("invalid arguments"); return 64; }
    int lock = open(argv[3], O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (lock < 0 || flock(lock, LOCK_EX | LOCK_NB) != 0) { emit("already owned"); return 73; }
    if (chdir(argv[2]) != 0) { emit("folder unavailable"); return 72; }
    signal(SIGINT, stop_signal); signal(SIGTERM, stop_signal); signal(SIGHUP, stop_signal);
    signal(SIGPIPE, SIG_IGN);
    struct winsize size = { .ws_row = 40, .ws_col = 160 };
    int terminal = -1;
    pid_t child = forkpty(&terminal, NULL, NULL, &size);
    if (child < 0) { emit("terminal unavailable"); return 71; }
    if (child == 0) {
        close(lock);
        signal(SIGINT, SIG_DFL); signal(SIGTERM, SIG_DFL); signal(SIGHUP, SIG_DFL);
        signal(SIGPIPE, SIG_DFL);
        // No inherited app descriptors may keep the parent-liveness pipe open.
        for (int fd = 3; fd < getdtablesize(); ++fd) close(fd);
        char **args = calloc((size_t)argc, sizeof(char *));
        if (!args) _exit(71);
        args[0] = argv[1];
        for (int i = 4; i < argc; ++i) args[i - 3] = argv[i];
        execv(argv[1], args);
        emit("executable unavailable"); _exit(127);
    }
    fcntl(terminal, F_SETFL, O_NONBLOCK);
    double stopping_at = 0;
    int stage = 0, status = 0;
    int terminal_open = 1, parent_open = 1;
    for (;;) {
        if (stop_requested && !stage) {
            kill(-child, SIGINT); stopping_at = monotonic(); stage = 1;
        }
        if (stage == 1 && monotonic() - stopping_at > 8) { kill(-child, SIGTERM); stage = 2; }
        if (stage == 2 && monotonic() - stopping_at > 11) { kill(-child, SIGKILL); stage = 3; }
        struct pollfd fds[2] = {
            { .fd = parent_open ? STDIN_FILENO : -1, .events = POLLIN | POLLHUP },
            { .fd = terminal_open ? terminal : -1, .events = POLLIN | POLLHUP }
        };
        int ready = poll(fds, 2, 100);
        if (ready < 0 && errno != EINTR) stop_requested = 1;
        if (fds[0].revents & (POLLIN | POLLHUP | POLLERR)) {
            char controls[64]; ssize_t n = read(STDIN_FILENO, controls, sizeof controls);
            if (n <= 0) { stop_requested = 1; parent_open = 0; }
            for (ssize_t i = 0; i < n; ++i) if (controls[i] == 'I') stop_requested = 1;
        }
        if (fds[1].revents & (POLLIN | POLLHUP | POLLERR)) {
            char output[8192]; ssize_t n;
            while ((n = read(terminal, output, sizeof output)) > 0) {
                ssize_t offset = 0;
                while (offset < n) {
                    ssize_t written = write(STDOUT_FILENO, output + offset, (size_t)(n - offset));
                    if (written < 0 && errno == EINTR) continue;
                    if (written <= 0) { stop_requested = 1; break; }
                    offset += written;
                }
            }
            if (n == 0 || (n < 0 && errno == EIO)) terminal_open = 0;
        }
        siginfo_t info = {0};
        if (waitid(P_PID, (id_t)child, &info, WEXITED | WNOHANG | WNOWAIT) == 0 && info.si_pid == child) {
            // Hold the leader as a zombie until descendants receive termination,
            // so the process-group identifier cannot be reused during cleanup.
            kill(-child, SIGTERM);
            struct timespec grace = { .tv_sec = 0, .tv_nsec = 100000000 };
            nanosleep(&grace, NULL);
            kill(-child, SIGKILL);
            waitpid(child, &status, 0);
            break;
        }
    }
    close(terminal); close(lock);
    if (stop_requested) return 0;
    return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
}
