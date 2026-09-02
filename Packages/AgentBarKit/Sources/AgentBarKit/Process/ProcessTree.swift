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
