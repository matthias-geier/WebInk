WebInk is a minimal framework for ruby assisting in website development. It
uses rack to dispatch and works under linux. Database adapters shipped with
webink are sqlite3 and mysql; a generic SQL adapter is available which can
be extended to access your favorite SQL database. Look into the sqlite3 or
mysql adapters for guidance.

Here is a small guide to installing it.

Not part of this guide is how to proxy from lighttpd/apache/nginx to the
rack-compatible server, as there are so many tutorials out there already.


## Version History and Upgrade paths

### 3.1.2 -- 2014-03-08

* Added **webink_r** as dependency to the gem

#### Upgrade path

Rack up files (ex. *config.ru*) need to add

```ruby
  require 'webink/r'
```


## Requirements

A linux server with ruby, rubygems, (lighttpd or apache or nginx), (mysql or
sqlite3) and the installed gems rack, (mysql or sqlite3) and webink.
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
  controllers --this folder contains all controller files
  models      --this folder contains all models
  views       --this folder contains all views
  files       --all static files should be located here
```

To fetch this folder structure initially, call *webink_init* which comes
with the gem. It will initialize your project with sample values.

After creating some models, you can run *webink_database* to initialize
the tables, and for some advanced use cases, copy the *webink_database*
and use the loaded models to easily import data.

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
sqlite3 gems apart from webink.
