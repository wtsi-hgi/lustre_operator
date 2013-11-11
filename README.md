lustre_operator
===============

Wrapper script to allow non-root users to run privileged `lfs` commands on particular Lustre filesystems (<http://lustre.org/>)

It takes as its first two arguments the path to the `lfs` binary and the mount point of a Lustre filesystem and it 
will only allow `lfs` commands to run against that filesystem. It is intended with use along with `sudo`, as the `sudoers` 
file can specify that individual users or groups can run this wrapper script against a limited set of Lustre 
filesystems specifically listed. 

Currently wraps up the functionality of the `lfs quota` (as `getquota`), `lfs setquota`, and `lfs find` commands.

In addition to the standard `lfs` command functionality, the wrapper also adds some additional features:
- `getquota` and `setquota` both accept multiple users/groups on the command line
- `setquota` command checks current quotas before setting and refuses to set if the change would put an under-quota user/group over quota (without a `--force=*`)
- `getquota` parses the output of `lfs quota` and outputs it in one of several customisable machine- and human-readable formats (including `JSON`, `TSV`, & `CSV`)


Usage
-----

Up-to-date usage information can be found in the inline perldocs (`perldoc lustre_operator`) or by 
running `lustre_operator` with no arguments or with `--help`.


Configuration
-------------
No configuration is required to run the lustre_operator command as a normal user or for users who already have 
root or full sudo access.  Such users can still benefit from the `setquota` over-quota check and from the sane 
output formats that `lustre_operator` offers.

However, the main strength of `lustre_operator` is that it structures the command-line arguments in such a way 
that it can easily be used to allow a set of users to perform quota and find operations on a particular Lustre 
filesystem (or set of filesystems). 

For example, the following `sudoers` snippet would allow the user `opuser1` to run `getquota`, `setquota`, 
and `find` operations as root on `/mnt/lustre01`:
```sudoers
opuser1 ALL = (root) NOPASSWD : /usr/local/bin/lustre_operator /usr/bin/lfs /mnt/lustre01
```

You could add multiple filesystems like this:
```sudoers
opuser1 ALL = (root) NOPASSWD : /usr/local/bin/lustre_operator /usr/bin/lfs /mnt/lustre01,\
                                /usr/local/bin/lustre_operator /usr/bin/lfs /mnt/lustre02,\
                                /usr/local/bin/lustre_operator /usr/bin/lfs /mnt/lustre03
```

You can also include the subcommands in the sudoers line: 
```sudoers
opuser1 ALL = (root) NOPASSWD : /usr/local/bin/lustre_operator /usr/bin/lfs /mnt/lustre01 getquota,\
opuser1 ALL = (root) NOPASSWD : /usr/local/bin/lustre_operator /usr/bin/lfs /mnt/lustre01 find
```

Users might find it annoying to have to type `/usr/local/bin/lustre_operator /usr/bin/lfs /mnt/lustre01` before 
they can get to the meat of the command, but a shell alias can easily address that issue. 

