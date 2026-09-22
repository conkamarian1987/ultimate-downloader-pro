import Foundation
import Darwin

/// Each operation owns a process group, so Cancel also stops ffmpeg children.
final class ProcessRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var pid: pid_t = 0
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        if pid > 0 { kill(-pid, SIGTERM) }
        lock.unlock()
    }

    func run(executable: String, arguments: [String], line: @escaping @Sendable (String) -> Void,
             completion: @escaping @Sendable (Int32, Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async { [self] in
            var fds: [Int32] = [0, 0]
            guard pipe(&fds) == 0 else { completion(-1, false); return }
            var actions: posix_spawn_file_actions_t?
            var attr: posix_spawnattr_t?
            posix_spawn_file_actions_init(&actions)
            posix_spawnattr_init(&attr)
            posix_spawn_file_actions_adddup2(&actions, fds[1], STDOUT_FILENO)
            posix_spawn_file_actions_adddup2(&actions, fds[1], STDERR_FILENO)
            posix_spawn_file_actions_addclose(&actions, fds[0])
            posix_spawn_file_actions_addclose(&actions, fds[1])
            posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
            var mask = sigset_t()
            sigemptyset(&mask)
            posix_spawnattr_setsigmask(&attr, &mask)
            var defaults = sigset_t()
            sigemptyset(&defaults)
            sigaddset(&defaults, SIGTERM); sigaddset(&defaults, SIGINT); sigaddset(&defaults, SIGPIPE)
            posix_spawnattr_setsigdefault(&attr, &defaults)
            posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF))
            posix_spawnattr_setpgroup(&attr, 0)
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            env["PYTHONUNBUFFERED"] = "1"
            let argv = ([executable] + arguments).map { strdup($0) } + [nil]
            let envp = env.map { strdup("\($0.key)=\($0.value)") } + [nil]
            defer {
                argv.forEach { free($0) }; envp.forEach { free($0) }
                posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attr)
            }
            var child: pid_t = 0
            lock.lock()
            let result: Int32
            if cancelled { result = ECANCELED }
            else { result = posix_spawn(&child, executable, &actions, &attr, argv, envp); if result == 0 { pid = child } }
            lock.unlock()
            close(fds[1])
            guard result == 0 else {
                close(fds[0]); line("Nelze spustit proces: \(String(cString: strerror(result)))")
                completion(result, result == ECANCELED); return
            }
            let handle = FileHandle(fileDescriptor: fds[0], closeOnDealloc: true)
            var pending = Data()
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                pending.append(data)
                while let range = pending.firstRange(of: Data([10])) {
                    let chunk = pending.subdata(in: 0..<range.lowerBound)
                    pending.removeSubrange(0..<range.upperBound)
                    line(String(decoding: chunk, as: UTF8.self))
                }
            }
            if !pending.isEmpty { line(String(decoding: pending, as: UTF8.self)) }
            var status: Int32 = 0
            while waitpid(child, &status, 0) == -1 && errno == EINTR {}
            lock.lock(); pid = 0; let wasCancelled = cancelled; lock.unlock()
            let code = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
            completion(code, wasCancelled)
        }
    }
}
