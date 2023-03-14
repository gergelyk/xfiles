use std::fs;
use std::env;
use std::path::{Path, PathBuf, MAIN_SEPARATOR as PATH_SEP};
use std::iter::FromIterator;
use itertools::Itertools;
use expanduser::expanduser;
use atty::Stream;
use std::io::{self, Read}; // `self` evaluates to `std::io`

/// Expand `~`, `.`, `..`, convert to absolute, do not resolve symlinks.
/// Work also with non-existing paths.
fn normalize_path(path: String) -> String {
    let mut parts: Vec<&str> = path.split(PATH_SEP).collect();
    let (home, cwd);

    if parts[0].starts_with("~") {
        // Expand home.
        home = expanduser(parts[0]).unwrap().to_str().unwrap().to_string();
        let mut new_parts: Vec<&str> = home.split(PATH_SEP).collect();
        parts.remove(0);
        new_parts.append(&mut parts);
        parts = new_parts;
    } else if parts[0] != "" {
        // expand relative to absolute
        cwd = env::current_dir().unwrap();
        let mut new_parts: Vec<&str> = cwd.to_str().unwrap().split(PATH_SEP).collect();
        new_parts.append(&mut parts);
        parts = new_parts;
    }

    // Reduce `//`, `/.`, `/..`, also '/' at the end.
    let mut idx = 0;
    while idx < parts.len() {
        if parts[idx] == "" || parts[idx] == "." {
            parts.remove(idx);
        } else if parts[idx] == ".." {
            parts.remove(idx);
            if idx > 0 {
                idx -= 1;
                parts.remove(idx);
            }
        } else {
            idx += 1;
        }
    }

    // Always provide `/` at the beginning.
    PATH_SEP.to_string() + parts.join(&PATH_SEP.to_string()).as_str()
}

fn get_stdin_args() -> Option<Vec<String>> {
    if atty::is(Stream::Stdin) {
        None
    } else {
        let mut buffer = String::new();
        io::stdin().read_to_string(&mut buffer).unwrap();
        Some(buffer.lines().map(|line| line.to_string()).collect())
    }
}

#[derive(Debug)]
struct Selection {
    path: PathBuf,
}

impl Selection {

    fn new() -> Selection {
        let shm = Path::new("/dev/shm");
        let parent_path = if shm.is_dir() {shm} else {Path::new("/tmp")};
        Selection {path: parent_path.join("xfiles")}
    }

    fn read_items(&self) -> Vec<String> {
        let text = fs::read_to_string(&self.path).unwrap();
        let lines = text.lines().filter(|line| !line.is_empty());
        lines.map(|line| line.to_string()).collect()
    }

    fn write_items(&self, items: &Vec::<String>) {
        let text = items.join("\n");
        fs::write(self.path.to_str().unwrap(), text).unwrap();
    }

    fn show(&self) {
        for item in self.read_items() {
            println!("{}", item)
        }
    }

    fn show_path(&self) {
        println!("{}", self.path.to_str().unwrap());
    }

    fn add(&self, items: &[String]) {
        let old_items = self.read_items();
        let ok_items = items.iter().filter(|item| !item.is_empty());
        let new_items = old_items.iter().chain(ok_items).cloned().map(normalize_path);
        self.write_items(&Vec::from_iter(new_items.unique()));
    }

    fn remove(&self, items: &[String]) {
        let old_items = self.read_items();
        let ok_items = items.iter().filter(|item| !item.is_empty());
        let abs_items = Vec::from_iter(ok_items.cloned().map(normalize_path));
        let new_items = old_items.iter().filter(|item| !abs_items.contains(item));
        self.write_items(&new_items.cloned().collect());
    }

    fn clear(&self) {
        fs::File::create(&self.path).unwrap();
    }

}

fn main() {

    let selection = Selection::new();

    let mut argv = env::args();
    argv.next();
    let args: Vec<String> = argv.collect();
    let stdin_args = get_stdin_args();

    if ! args.is_empty() {
        let cmd = &args[0];
        let cmd_args = match stdin_args {
            Some(stdin_args_) => stdin_args_,
            None => args[1..].to_vec(),
            };

        match cmd.as_str() {
            "+" => {
                selection.add(&cmd_args);
                selection.show();
            },
            "-" => {
                selection.remove(&cmd_args);
                selection.show();
            },
            "++" => {
                selection.show_path();
            },
            "--" => {
                selection.clear();
            },
            _ => {
                selection.clear();
                selection.add(&args);
                selection.show();
            },
        };
    } else {

        if let Some(stdin_args_) = stdin_args {
            selection.clear();
            selection.add(&stdin_args_);
        }
        selection.show();
    }
}
