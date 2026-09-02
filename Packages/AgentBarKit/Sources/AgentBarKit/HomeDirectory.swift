import Foundation

/// The user's real home directory.
///
/// `NSHomeDirectory()` answers the sandbox container when the process is sandboxed. The app is
/// not sandboxed today, but the passwd entry costs nothing and keeps the readers honest if a
/// sandbox experiment ever comes back.
public enum HomeDirectory {
    public static var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    public static var path: String {
        if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }
}
