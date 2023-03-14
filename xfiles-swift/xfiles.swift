
//let args = CommandLine.arguments[1...]

/*
for argument in args {
    print(argument)
}
*/

/*
while let line = readLine() {
   print(line)
   print(line.count)
}
*/

//let t = [1, 2, 3]
//print(t)

//let w = Array(readLine())


/*
import Foundation

let text = "abc\n"
let cwd = URL(string: "file://" + FileManager.default.currentDirectoryPath)!
let fileUrl = cwd.appendingPathComponent("foo.txt")


do {
    print("Writing: \(fileUrl)")
    try text.write(to: fileUrl, atomically: false, encoding: String.Encoding.utf8)

    print("Reading: \(fileUrl)")
    let obtained = try String(contentsOf: fileUrl)
    print(obtained)
} catch {
    print("Error: \(error)")
}

*/

import Foundation

class Selection {

    let path: URL

    init() {
        var storage = URL(string: "file:///dev/shm")!
        var isDir = false
        do {
            _ = try storage.checkResourceIsReachable()
            isDir = (try storage.resourceValues(forKeys: [.isDirectoryKey])).isDirectory!
        } catch {
        }
        if !isDir {
            storage = URL(string: "file:///tmp")!
        }
        self.path = storage.appendingPathComponent("xfiles")
    }

    func _read_items() -> [String.SubSequence] {
        var text = ""
        do {
            text = try String(contentsOf: path)
        } catch {
            print("Error: \(error)")
        }
        return text.split(separator: "\n")
    }

    func show() {
        let text = _read_items().joined(separator: "\n")
        if !text.isEmpty {
            print(text)
        }
    }

    func clear() {
        let text = ""
        do {
            try text.write(to: path, atomically: false, encoding: String.Encoding.utf8)
        } catch {
            print("Error: \(error)")
        }
    }
}

let selection = Selection()
selection.show()
selection.clear()



