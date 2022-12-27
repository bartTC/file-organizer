#  file-organizer

Collect files from a root folder and move them into a subfolder with the
format YYYY-MM. Only files that are older than specified will be collected.

Example:

    ~/Downloads/b.txt
    ~/Downloads/2022-12/a.txt

Becomes:

    ~/Downloads/2022-12/a.txt
    ~/Downloads/2022-12/b.txt

You may run this tool once or multiple times a day.

```
USAGE: file-organizer [--root-folder <root-folder>] [--days-to-stay <days-to-stay>] [--debug]

OPTIONS:
  -r, --root-folder <root-folder>
                          The root folder. (default: ~/Downloads)
  -d, --days-to-stay <days-to-stay>
                          How many days to leave files in the root folder before moving. (default: 0)
  --debug                 Show whats going on.
  -h, --help              Show help information.
  ```

