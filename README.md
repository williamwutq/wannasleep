# wannasleep (TODO Manager)

A Simple Command-Line TODO Manager in Zig, inspired by Git

Open Sourced in case you need it, licensed under the MIT License.

## Features
- Add, list, complete, and manage your TODO items directly from the command line.
- Unique Human-Readable Identifiers (HUIDs) for easy reference (Inspired by Tsoding's HUIDs).
- Store TODO items in a CSV file for easy access and manipulation.
- Filter and display options for listing TODO items.

## Installation
For normal usage, you can either build from source or download pre-built binaries.

Reference Zig [Build Guide](https://ziglang.org/learn/build-system/) for building from source.

This can also be used as a poorly designed library for managing TODO items in your own Zig applications, and all logic code are in `src/root.zig`, the code in main is for command line argument parsing only.

## Usage
```
$ todo init
$ todo add "Buy groceries" --tags shopping,errands --deadline 2025-12-31
$ todo list --all --status --huid
$ todo finish <HUID>
$ todo remove <HUID>
```
Refer to `todo help` for detailed command usage and options.

The "Usage" output should be below:
```
Usage: todo [-v | --version] [-h | --help] <command> [<args>]
Commands:
    add       Add a new todo item and print generated HUID
    author    Show author information
    cancel    Cancel a todo item
    defer     Defer a todo item's due time by a specified duration
    edit      Edit the description or tags of a todo item
    finish    Mark a todo item as completed
    grep      Search todo items by keyword or tag
    help      Show this help message and exit
    huid      Generate a new HUID based on the current time
    init      Creates an empty todo list in the current directory
    list      List all todo items
    remind    Remind about todo items due within a time range
    remove    Remove a todo item
    version   Show version information
Common Options:
    -h, --help       Show this help message and exit
    -v, --version    Show version information and exit
    -d, --deadline   Specify the deadline for the todo item in HUID format
    -m, --message    Specify the description for the todo item (used with 'add' and 'edit' commands)
    -t, --tags       Comma-separated list of tags for the todo item
    -u, --huid       Specify the HUID of the todo item to operate on
Short option grouping:
    Most single-letter options can be grouped together. For example, -as is equivalent to -a -s.
    When no command is specified, the supported options are -h/--help and -v/--version,
    and option grouping between them is allowed (e.g., -vh is equivalent to -v -h).
For detailed help on a specific command, run: todo <command> --help
```

## File Storage
Similar to Git, all TODO items are stored in a CSV file located at `.todo/data/*.csv` in the current working directory. Each line in the CSV represents a TODO item with fields for HUID, description, tags, deadline, and status. Current default filename is `main.csv`. This is for the ability to extend to multiple files and keep track of categories in the future.

## C Compatibility
Not aimed for C compatibility, but you are free to modify the code to suit your needs. If in the future I will need it, I might add C compatibility.

## Remote Repository
Similar to Git, there are ideas to add remote repository support for syncing TODO items across devices, but currently not implemented as it is not needed for my use case.

## Q/A
### Why Make This?
I wanted a lightweight TODO manager that I could use directly from the command line, without the overhead of complex applications. This project is inspired by Git's command-line interface and aims to provide a simple yet effective way to manage TODO items.

### Why This Name?
The name "wannasleep" reflects the common feeling of procrastination and the desire to put off tasks, which is often associated with managing TODO lists. Simply put, this tool aims to help you get back to sleep faster.

### Why Zig?
It's my favorite programming language. That said, I am not updating this project often enought to keep track of Zig master. Current Zig version is 0.15.2.

### Why Command Line?
There are a lot of GUI-based and TUI-based TODO managers out there. I wanted something that could be easily integrated into my terminal workflow, allowing for quick additions and management of tasks without leaving the command line. In addition, wannasleep keep track of todos separately for each project directory, making it easy to manage tasks specific to different projects.

### Why CSV?
Not everyone has a database setup, and writing code that works for all databases is a pain. CSV is simple, human-readable, and easy to manipulate with standard tools.

### Do I use this to track Wannasleep development tasks?
Yes. Why not? (They are also marked TODO in the codebase.)

### Are there memory leaks?
Yes, probably. Most leaks are fixed, and others will be fixed in future releases. If you find any, please report them. It's also important to note that this is a command-line tool, so memory leaks are less of a concern compared to long-running applications.

### Why not C?
Zig offers modern language features, better safety, and a more pleasant development experience compared to C. I have been developing in C for a while and I am entirely capable of writing this in C, but that would take a much longer time, which is undesirable for a small project like this.

### Why not Rust?
No need for it. As you see, this project has zero dependencies except std, and adding Rust's cargo and crates would be overkill for a simple command-line tool.

### How often is this updated?
Not very often. Nightly builds are made every day if any changes are made, and stable releases are made when significant features are added or bugs are fixed.

### Do you often go to sleep?
Ummm, why would you ask that?

### How long is your TODO list?
Around 40-50 items, but mostly closed/completed ones. Around 10-15 active items at any given time. This is why I am not concerned about performance or scalability for now.

### Can I contribute?
Absolutely! Feel free to fork the repository, make changes, and submit pull requests. Contributions are always welcome.