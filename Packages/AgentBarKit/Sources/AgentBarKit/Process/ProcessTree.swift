import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Questions about other processes: is it alive, who is its parent, which application
/// owns the window it runs in. All answered by the kernel, none by the agents' files.
public enum ProcessTree {
    /// Whether a process is still alive. Signal 0 asks exactly that and does nothing else.
    public static func isRunning(_ pid: Int) -> Bool {
        kill(pid_t(pid), 0) == 0 || errno == EPERM
    }

    /// A running process: its id, its executable's path and its working directory.
    public struct RunningProcess: Equatable, Sendable {
        public let pid: Int
        public let path: String
        public let cwd: String

        public init(pid: Int, path: String, cwd: String) {
            self.pid = pid
            self.path = path
            self.cwd = cwd
        }
    }

    /// Every process whose executable path contains `needle`, with its working directory.
    /// Answered by libproc; a process that refuses (another user's) is skipped.
    public static func processes(whosePathContains needle: String) -> [RunningProcess] {
        var count = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) / MemoryLayout<pid_t>.size + 64)
        count = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard count > 0 else { return [] }
        var found: [RunningProcess] = []
        for pid in pids.prefix(Int(count) / MemoryLayout<pid_t>.size) where pid > 0 {
            var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { continue }
            let path = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            guard path.contains(needle) else { continue }
            var info = proc_vnodepathinfo()
            let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { continue }
            let cwd = withUnsafePointer(to: &info.pvi_cdir.vip_path) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
            found.append(RunningProcess(pid: Int(pid), path: path, cwd: cwd))
        }
        return found
    }

    public static func parentPID(of pid: Int) -> Int? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid_t(pid)]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return Int(info.kp_eproc.e_ppid)
    }

    /// The application a conversation is running inside - iTerm, Terminal, an editor -
    /// found by walking up from the agent's own process until a parent turns out to be
    /// one. `claude` sits under a shell, under a login, under the terminal itself.
    ///
    /// Electron editors put their terminal under helper processes, and those carry bundle
    /// identifiers of their own - stopping at the first one lands on a helper with no
    /// windows, which activates nothing. Only a `.regular` app owns a window.
    public static func owningApplicationPID(of pid: Int) -> Int? {
        #if canImport(AppKit)
        var current = pid
        var fallback: Int?
        for _ in 0..<12 {
            if let app = NSRunningApplication(processIdentifier: pid_t(current)) {
                if app.activationPolicy == .regular { return current }
                if app.bundleIdentifier != nil, fallback == nil { fallback = current }
            }
            guard let parent = parentPID(of: current), parent > 1 else { break }
            current = parent
        }
        return fallback
        #else
        return nil
        #endif
    }
}
