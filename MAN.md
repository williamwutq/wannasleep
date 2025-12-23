TODO(1) - User Commands - TODO(1)

# NAME

todo - a simple command-line todo list manager

# SYNOPSIS

**todo** [**-v** | **--version**] [**-h** | **--help**] *command* [*args*]

# DESCRIPTION

**todo** is a command-line todo list manager written in Zig. It provides a simple yet powerful interface for managing tasks with support for tags, deadlines, and Human-Readable Unique Identifiers (HUIDs). Todo lists are stored locally in a **.todo** directory in the current working directory.

# OPTIONS

**-h**, **--help**  
Display help information and exit.

**-v**, **--version**  
Display version information and exit.

**-vh**  
Display both version and extended help information (options can be grouped).

# COMMANDS

## init

**todo init**

Initialize a new todo list in the current directory by creating a **.todo** directory with necessary files. If the directory already exists, existing files will not be overwritten.

## add

**todo add -m** *message* [**-t** *tags*] [**-d** *deadline*]

Add a new todo item with the specified description, optional tags, and optional deadline. Returns the generated HUID for the new item.

**Options:**
- **-m**, **--message** *message* - Description of the todo item (required)
- **-t**, **--tags** *tag1,tag2,...* - Comma-separated list of tags (optional)
- **-d**, **--deadline** *HUID* - Deadline in HUID format (optional)
- **-h**, **--help** - Display help for this command

**Example:**
```
$ todo add -m "Finish the report" -t work,urgent -d 20210701-120000
Todo item added with HUID: 20210630-170000
```

## la | listall

**todo la** | **todo listall**

See all todo items with full details (equivalent to **todo list -l -a**).

## list

**todo list** [**-l**] [**-a**] [**-d**] [**-s**] [**-t**] [**-u**]

List all todo items with optional filters and display options. By default, only shows open (not completed or canceled) items.

**Options:**
- **-a**, **--all** - Show all items including completed and canceled ones
- **-d**, **--deadline** - Show the deadline of each item
- **-h**, **--help** - Display help for this command
- **-l**, **--long** - Show detailed information (equivalent to -dstu)
- **-s**, **--status** - Show the completion status of each item
- **-t**, **--tags** - Show the tags associated with each item
- **-u**, **--huid** - Show the HUID of each item

**Note:** The **-l** option can only be combined with **-a**; it implies all other display options.

**Status Indicators:**
- **[ ]** - Open item
- **[x]** - Completed item
- **[-]** - Canceled item

**Example:**
```
$ todo list -a -s -u
```

## finish

**todo finish** [**-u**] *huid*

Mark a todo item as completed.

**Options:**
- **-u**, **--huid** *HUID* - HUID of the item to complete (flag is optional)
- **-h**, **--help** - Display help for this command

**Example:**
```
$ todo finish 20210630-170000
Todo item with HUID 20210630-170000 has been marked as completed.
```

## cancel

**todo cancel** [**-u**] *huid*

Cancel a todo item. Unlike completion, cancellation indicates the task was abandoned rather than finished.

**Options:**
- **-u**, **--huid** *HUID* - HUID of the item to cancel (flag is optional)
- **-h**, **--help** - Display help for this command

**Example:**
```
$ todo cancel 20210630-170000
Todo item with HUID 20210630-170000 has been canceled.
```

## edit

**todo edit -u** *huid* [**-m** *message*] [**-t** *tags*] [**-d** *deadline*] [**-n**] [**-c**] [**-x**] [**-o**]

Edit an existing todo item. You can update the description, tags, deadline, or change its status.

**Options:**
- **-u**, **--huid** *HUID* - HUID of the item to edit (required)
- **-m**, **--message** *message* - New description (optional)
- **-t**, **--tags** *tag1,tag2,...* - New comma-separated list of tags (optional)
- **-d**, **--deadline** *HUID* | **x** - New deadline in HUID format, or 'x' to remove (optional)
- **-n**, **--append** - Append to existing tags instead of replacing them
- **-c**, **--complete** - Mark the item as completed
- **-x**, **--cancel** - Mark the item as canceled
- **-o**, **--open** - Mark the item as open (overrides -c and -x)
- **-h**, **--help** - Display help for this command

**Note:** Options **-c**, **-x**, **-o**, and **-n** can be combined. When **-o** is used, **-c** and **-x** cannot be in the same option group.

**Example:**
```
$ todo edit -u 20210630-170000 -m "Finish the updated report" -c
```

## remove

**todo remove** [**-u**] *huid*

Permanently remove a todo item from the list. This operation cannot be undone.

**Options:**
- **-u**, **--huid** *HUID* - HUID of the item to remove (flag is optional)
- **-h**, **--help** - Display help for this command

**Example:**
```
$ todo remove 20210630-170000
Todo item with HUID 20210630-170000 has been removed.
```

## defer

**todo defer** [**-u**] *huid* [**-w** *weeks*] [**-D** *days*] [**-H** *hours*] [**-m** *minutes*] [**-S** *seconds*]

Defer the deadline of a todo item by a specified duration. The item must have an existing deadline.

**Options:**
- **-u**, **--huid** *HUID* - HUID of the item to defer (flag is optional)
- **-w**, **--weeks** *N* - Number of weeks to extend
- **-D**, **--days** *N* - Number of days to extend
- **-H**, **--hours** *N* - Number of hours to extend
- **-m**, **--minutes** *N* - Number of minutes to extend
- **-S**, **--seconds** *N* - Number of seconds to extend
- **-h**, **--help** - Display help for this command

**Example:**
```
$ todo defer 20210630-170000 -D 3 -H 5
Todo item with HUID 20210630-170000 has been deferred to new deadline 20210703-220000.
```

## grep

**todo grep** [**-a**] [**-b**] [**-i**] [**-m**] [**-t**] [**-s** *status*] [**-d** *deadline*] [**-u** *huid*] [*keyword*]

Search todo items by keyword in description or tags with optional filters.

**Options:**
- **-a**, **--all** - Include inactive items (completed or canceled)
- **-b**, **--both** - Search keyword in both description and tags
- **-i**, **--ignore-case** - Perform case-insensitive search
- **-m**, **--message** - Search keyword in description only
- **-t**, **--tags** - Search keyword in tags only
- **-s**, **--status** *status* - Filter by status: 'o' (open), 'c' (completed), 'x' (canceled)
- **-d**, **--deadline** *HUID* - Filter by deadline
- **-u**, **--huid** *HUID* - Filter by specific HUID
- **-h**, **--help** - Display help for this command

**Note:** Options **-a**, **-b**, **-i**, **-m**, and **-t** can be combined. When **-b** is used, **-m** and **-t** cannot be in the same option group.

**Example:**
```
$ todo grep -ti report
```

## remind

**todo remind** [**-s** *start*] [**-e** *end*] [**-u**] [**-t**] [**-d**]

Show todo items that are due within a specified time range. Useful for checking upcoming deadlines.

**Options:**
- **-s**, **--start** *HUID* - Start of time range in HUID format (inclusive)
- **-e**, **--end** *HUID* - End of time range in HUID format (inclusive)
- **-u**, **--huid** - Show the HUID of each item
- **-t**, **--tags** - Show the tags of each item
- **-d**, **--deadline** - Show the deadline of each item
- **-h**, **--help** - Display help for this command

**Note:** Options **-u**, **-t**, and **-d** can be combined.

**Example:**
```
$ todo remind -s 20210701-000000 -e 20210707-235959
```

## huid

**todo huid**

Generate a new Human-Readable Unique Identifier (HUID) based on the current time. HUIDs use the format YYYYMMDD-HHMMSS.

**Note:** To avoid conflicts, HUIDs should not be generated in rapid succession.

**Example:**
```
$ todo huid
20231220-153045
```

## author

**todo author**

Display author information.

## version

**todo version**

Display version information including the build version and Zig compiler version.

## help

**todo help**

Display the main help message.

# HUID FORMAT

Human-Readable Unique Identifiers (HUIDs) use the format **YYYYMMDD-HHMMSS**, where:
- **YYYY** - Four-digit year
- **MM** - Two-digit month (01-12)
- **DD** - Two-digit day (01-31)
- **HH** - Two-digit hour in 24-hour format (00-23)
- **MM** - Two-digit minute (00-59)
- **SS** - Two-digit second (00-59)

**Example:** 20210630-170000 represents June 30, 2021 at 5:00:00 PM.

# SHORT OPTION GROUPING

Most single-letter options can be grouped together for convenience:
- **-asu** is equivalent to **-a -s -u**
- **-vh** is equivalent to **-v -h**
- **-abim** is equivalent to **-a -b -i -m**

Some commands have restrictions on which options can be grouped together. Refer to individual command help for details.

# FILES

**.todo/**  
Directory created by **todo init** that stores all todo list data. This directory should not be manually modified.

# EXIT STATUS

**0**  
Success

**1**  
General error (invalid arguments, item not found, etc.)

# EXAMPLES

Initialize a new todo list:
```
$ todo init
```

Add a todo item with tags and deadline:
```
$ todo add -m "Submit quarterly report" -t work,urgent -d 20240115-170000
```

List all open items with full details:
```
$ todo list -l
```

Search for items tagged with "work":
```
$ todo grep -t work
```

Mark an item as completed:
```
$ todo finish 20240115-170000
```

Defer a deadline by 2 days:
```
$ todo defer 20240115-170000 -D 2
```

Edit an item's description and add tags:
```
$ todo edit -u 20240115-170000 -m "Submit updated report" -t work,urgent,reviewed -n
```

Show items due this week:
```
$ todo remind -s 20240108-000000 -e 20240114-235959 -utd
```

# AUTHOR

Created by William Wu

# SEE ALSO

Task management tools: **taskwarrior**(1), **todo.txt**(1)

# BUGS

Report bugs at the project repository or to the author.

# VERSION

todo (wannasleep) version 0.1.2 (Zig 0.15.2)