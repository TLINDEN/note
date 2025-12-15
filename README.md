# note - a perl script for maintaining notes.

> [!CAUTION]
> This software is now being maintained on [Codeberg](https://codeberg.org/scip/note/).

This is the perl script 'note' in version 1.4.2 from 24/09/2024.

## Introduction

This is a  small console program written in perl,  which allows you to
manage notes similar to programs like "knotes" from command line.

There are a couple of different  databases backends, which you can use
with note:

* **binary** - this is the default backend
  and uses a binary file to store your notes.
* **mysql** - this backend uses a mysql
  database to store your notes. You can switch
  easily to another DBMS since this module uses
  the Perl standard module "DBI" for database-
  access. See below for more info on this topic!
* **dbm** - this module uses two DBM files
  for data storage and requires the module DB_FILE,
  which is part of the perl standard distribution.
  See below for more details about the DBM module.
* **general** - uses the module Config::General
  for storage, which makes the data file portable,
  since it is a plain ascii file (binary content
  will be base64 encoded).
* **text** - uses the Storable module for data
  storage (a serializer). Storable is included with
  perl, and since it's written in C, it's very fast.
  But the resulting data files are not that portable
  as the once of NOTEDB::general are.
* **pwsafe3** - uses the
  [PWSAFE3](https://github.com/pwsafe/pwsafe/blob/master/docs/formatV3.txt)
  file format, which is securely encrypted. The file can be opened
  with any other program which supports the format. There are windows
  programs and apps for mobile phones available. **I highly recommend
  to use this backend if you ever intend to store sensitive
  information in it!**

## Where to 

You can download the source at http://www.daemon.de/NOTE or
https://codeberg.org/scip/note.

If you are using debian, you run `can apt-get ìnstall note`.

If you are using gentoo, you can emerge it.



## Features

* Several different database backends, mysql(DBI), dbm,
  binary (bin file), general and text (text files).
* Command line interface using the standard perl module
  Getopt::Long, which allows you to use short or long
  command-line options.
* Interactive interface (pure ascii), the following functions
  are available in interactive mode: list, display, topic,
  delete, edit, help.
* Highly configurable using a perlish configfile ~/.noterc.
  although it is configurable it is not required, note can
  run without a configfile using useful default presets.
* Colourized output is supported using ASCII Escape-Sequences.
* The user can customize the color for each item.
* Data can be stored in various different database backends,
  since all database access is excluded from the program itself
  in perl modules.
* Notes can be deleted, edited and you can search trough your notes.
* Notes can be categorized. Each category (topic) can contain multiple
  notes and even more sup-topics. There is no limitation about
  sub topics.
* You can view all notes in a list and it is possible only to view
  notes under a certain topic.
* There is a tree-view, which allows you to get an overview of your
  topic-hierarchy.
* Notes can be encrypted using DES or IDEA algorithms and Crypt::CBC.
* You can dump the contents of your note database into a plain text
  file, which can later be imported. Imports can be appended or it can
  overwrite an existing database (`-o`).
* Note has scripting capabilities, you can create a new note by piping
  another commands output to note, you can also import a notedump from
  stdin as well es duming to stdout instead a file. Additional, there 
  is an option `--raw` available, which prints everything out completely
  without formatting.
* for better performance, note can cache the database for listings
  or searching.
* It can be installed without root-privileges.
* If Term::ReadLine (and Term::ReadLine::Gnu) is installed, history
  and auto-completion are supported in interactive mode.
* Last, a while ago a user stated: "... it simply does, what it
  says ..."



## Requirements

You need the following things:

* perl installed (5.004x)
* The module IO::Seekable and Fcntl, which should be 
  already installed with your perl distribuion if
  you want to use the binary database backend.
* DBI module and DBI::mysql if you want to use the 
  mysql database backend.
* The module DB_FILE if you want to use the DBM module.
* Getopt::Long (part of perl std distribution)
* Term::ReadLine and optionally Term::ReadLine::Gnu if
  you want to use the auto-completion and history functionality.
* Config::General if you want to use the NOTEDB::general
  backend.
* YAML is needed to create backups using -D. Please note,
  that this format is deprecated starting with 1.4.0. 
  
  **The support will be removed in 1.5.0. Please switch to JSON
  format as soon as possible, either by using the -j
  commandline option or the UseJSON configuration value.**
* The Crypt::PWSafe3 module if you want to use the pwsafe3 backend.

## Installation

Unpack the tar-ball and issue the following command:

`$ perl Makefile.PL`

This creates the Makefile neccessary for installing.
You may add some additional variables to the command line, the
most important one is PREFIX.

Then enter the following command to prepare the installation
process:

`$ make`

After that, you are ready to install. Become root and issue:

`# make install`

The installation process installs all modules for every available
data backends. The default note configuration does not require
additional perl modules.
If you want to use the mysql backend refer to the installation
instructions for the mysql database installation in mysql/README.

If you want to use encryption support, you will need at least
Crypt:CBC and Crypt::Blowfish (or Crypt::DES or whatever you
prefer). You won't need to manually install any of this if you want to
use the pwsafe3 backend, in that case install Crypt::PWSafe3 with all
its dependencies.



## Configuration

This  version  of  note   doesn't  necessarily  need  a  configuration
file. But you can have one and change some default values. Take a look
at  the  file config/noterc  provided  with  this tarball.  There  are
detailed instructions  about every  available parameter.   Simply copy
this file into your home-directory and name it `.noterc` If you decide
not to  use the  default database  backend (a  binary file),  you will
*need* a configuration!


## Usage

Refer to the note(1) manpage for usage instructions.


## Getting help

Although I'm happy  to hear from note users  in private email,
that's the best way for me to forget to do something.

In order to report a bug,  unexpected behavior, feature requests or to
submit    a    patch,    please    open   an    issue    on    github:
https://codeberg.org/scip/note/issues. 

## Deprecation notes

The **binary** database format will be removed with version 1.5.0. No
deprecation note is being printed for now.

The **text** database format will be either removed or will use
another backend module for security reasons. The perl module Storable
will not be used anymore.

## Copyright and License

Copyright (c) 1999-2013 Thomas Linden
Copyright (c) 2013-2024 Thomas von Dein

Licensed under the GNU GENERAL PUBLIC LICENSE version 3.

You can read the complete GPL at: http://www.gnu.org/copyleft/gpl.html

## Author

T.v.Dein <tom AT vondein DOT org>


## Contributors / Credits

Shouts to all those guys who helped me to enhance note: THANKS A LOT!

Jens Heunemann 	- sub tree.
Peter Palmreuther - various additions.

And many other people who sent bug reports, feature requests. If you
feel that I forgot your name in this list, then please send me an email
and I'll add you.


