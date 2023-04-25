# vimwiki-tasks Vim plugin

A similar (and maintained) plugin can be found here: https://github.com/tbabej/taskwiki

## NOTE
This is a very early and very alpha version of the plugin. Use with caution and make a backup of
your `.task` and `vimwiki` folder. You have been warned!

## Features
This plugin adds some additional syntax rules to vimwiki to define a task format with due dates. It
also adds highlighting for tags (`+tag`) and UUID's. The format for a task which has a due date on
2013-11-21:

    * [ ] This is a task with a due date (2013-11-21)

It's also possible to specify a time for the due:

    * [ ] This is a task due at 10am (2013-11-21 10:00)

Please *note* that it is officially not possible to set a due-time in taskwarrior, however by
specifying the correct dateformat it however is possible since internally dates are stored as unix
timestamps. So far I have not really found any side-effects of doing this.

When the vimwiki file is saved all the new tasks with a due date will be added to taskwarrior. To
keep the link between the task in taskwarrior and vimwiki the UUID of the task is appended to the
task in vimwiki. If you have enabled Vim's `conceal` feature the UUID's will be hidden.

It is also possible to add tasks without a due date into taskwarrior by ending the task in Vimwiki
in `#TW`. When the vimwiki file is saved any task which ends in `#TW` will also be added to
taskwarrior and the `#TW` will be replaced by the UUID.

When the file is reopened in Vimwiki all the tasks which have a UUID will be synced and updated from
taskwarrior info the vimwiki-file and it will be marked as modified if any updates took place.

## Installation
1. Install the vimwiki plugin for Vim
1. Install taskwarrior
1. Install this plugin

## Default values
The first 10 lines of a vimwiki file will be checked for some default values which will be used for
all the tasks in that vimwiki-file:

* `%% Project: <projectname>`: set the project for the tasks to '<projectname>'
* `%% Tags: +tag1 +tag2`: add these tags to every task.

## Config
The following configuration options are currently available

* `let g:vimwiki_tasks_annotate_origin = 0`: When `1` a reference to the vimwiki-page where the task
was found will be added as an annotation
* `let g:vimwiki_tasks_tags_nodue = ''`: These tags, e.g. +vimwiki +nodue, will be added to a task
without a due date/time.
* `let g:vimwiki_tasks_tags_duetime = ''`: These tags will be added to a task which has both a due
date and time.
* `let g:vimwiki_tasks_tags_duedate = ''`: These tags will be added to a task which has a due date
but no due time.

## Known issues & Future plans
See the issue list on Github for currently known issues and future plans. Feel free to report issues and add ideas there as well.
