
local signal = table {
    SIGHUP = 1,
    SIGINT = 2,
    SIGQUIT = 3,
    SIGILL = 4,
    SIGABRT = 6,
    SIGFPE = 8,
    SIGKILL = 9,
    SIGSEGV = 11,
    SIGPIPE = 13,
    SIGALRM = 14,
    SIGTERM = 15,
    SIGCHLD = 17,
    SIGBUS = 7,
    SIGUSR1 = 10,
    SIGUSR2 = 12,
    SIGCONT = 18,
    SIGSTOP = 19,
    SIGTSTP = 20,
    SIGURG = 23,
    SIGIO = 29,
    SIGSYS = 31,
    SIGSTKFLT = 16,
    SIGUNUSED = 31,
    SIGTTIN = 21,
    SIGTTOU = 22,
    SIGXCPU = 24,
    SIGXFSZ = 25,
    SIGVTALRM = 26,
    SIGPROF = 27,
    SIGWINCH = 28,
    SIGPOLL = 29,
    SIGPWR = 30,
}

local const = {signal = signal}
table.update(const, signal)

signal:swap_key_value(true)

return const