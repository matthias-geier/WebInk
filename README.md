WebInk is a minimal framework for ruby assisting in website development. It
uses rack to dispatch and works under linux. Database adapters shipped with
webink are pg, sqlite3 and mysql; a generic SQL adapter is available which can
be extended to access your favorite SQL database. Look into the pg, sqlite3 or
mysql adapters for guidance.

Here is a small guide to installing it.

Not part of this guide is how to proxy from lighttpd/apache/nginx to the
rack-compatible server, as there are so many tutorials out there already.


## Version History and Upgrade paths

### 3.2.0 -- 2014-04-05

* Added **webink_r** as dependency to the gem
* Added **pg** gem support
* Major refactoring on model and database interfaces
  * *find_references* on model instances returns result additionally to
    setting the appropriate accessor on the instance
  * *find_references* finds arrays or single instances, depending on association
* Extended String with *constantize*, *camelize*, *underscore* and *execute*
* Seeding the database is now done by adding a **db_seed.rb** in the project
  folder
* Add testrunner to execute local unit tests

#### Upgrade path

Rack up files (ex. *config.ru*) need to add

```ruby
  require 'webink/r'
```

Former *find*

```ruby
  Ink::Database.database.find(Entry)
  Ink::Database.database.find(Entry, "WHERE id=15")
```

now becomes

```ruby
  Entry.find
  Entry.find{ |s| s.where('id=15') }
```

Former *find_references* and *find_union*

```ruby
  e = Entry.find{ |s| s.where('id=1') }.first
  Ink::Database.database.find_references(Entry, e.pk, Comment)
  Ink::Database.database.find_references(Entry, e.pk, Comment,
    "AND comment.id>1")
```

now becomes

```ruby
  e = Entry.find{ |s| s.where('id=1').first
  e.find_references(Comment)
  e.find_references(Comment){ |s| s.and('comment.id>1') }
```

Former *query*

```ruby
  Ink::Database.database.query("SELECT * FROM entry;")
```

now becomes

```ruby
  Ink::R.select('*').from('entry').execute
  Ink::R.select('*').from('entry').to_h
```

Former *query* mapping to array

```ruby
  Ink::Database.database.query("SELECT * FROM entry;", Array){ |a,k,v| a << v }
```

now becomes

```ruby
  Ink::R.select('*').from('entry').to_a
  Ink::R.select('*').from('entry').execute(Array){ |a,k,v| a << v}
```



## Requirements

A linux server with ruby, rubygems, (lighttpd or apache or nginx), (pg, mysql or
sqlite3) and the installed gems rack, (pg, mysql or sqlite3), webink_r and
webink.
Also required is a rack-compatible server like thin or webrick, as the apache
would only be proxy for the thin/webrick installation. Most rack-compatible
servers are available as gems.


## Installation

The project folder can be located anywhere on the system, but most admins
seem to like */var/www* as its root. Some web hosters even encourage you to
use your home folder. Where ever this may be, you need to provide a certain
structure, so the dispatcher can find its resources. Assume the project
foldername "blog".

```
  config.rb   --this configures the project
  config.ru   --the rackup file to run the project
  routes.rb   --configures all the routing
  db_seed.rb  --optional database seed
  controllers --this folder contains all controller files
  models      --this folder contains all models
  views       --this folder contains all views
  files       --all static files should be located here
  test        --a place for the unit tests
```

To fetch this folder structure initially, call *webink_init* which comes
with the gem. It will initialize your project with sample values.

After creating some models, you can run *webink_database* to initialize
the tables. When it is required to seed the databases with data, you can
create a *db_seed.rb* file in your project folder which will be loaded
for every database (application and test).

For more information on the folders, have a look at the sample project.


## Production

The **config.rb** comes with a production setting (see documentation on
**database.rb**) which will hide all errors behind the appropriate HTTP
error codes.

To this day, no caching is done when enabling production, it is just a
convenient way to hide possible stack traces.


## Testing

A small unit test suite is provided in the github repos. You can run it by
cloning the github repos, navigating into the repos root folder and running

```sh
  ruby test/run.rb
```

WebInk can be unit tested quite easily, it only requires the minitest and
sqlite3 gems apart from webink and webink_r.

## Unit Tests

Every new project that is created with *webink_init* adds a folder **test** to
the application folder. All tests should be put in there.

All tests can be executed by calling the following command in the application
root folder.

```sh
  webink_testrunner
```

Tests are written in *minitest/spec*. Each testfile is executed inside a
transaction, but make sure to reset all saved changes in the **after** sections
of your specs. Examples are the webink unit tests! Knock yourself out, the
tests are lightning fast.

## Demo

A blog demo software is available on github:
https://github.com/matthias-geier/WebInk-demo
