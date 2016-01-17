# Django Development Environment

Configure a virtual-machine to run a django application for development.

* For now it is using nginx/uwsgi, but since this is intended for development
  we should have an option to use "manage.py runserver";

## Virtual Machine Directories

```
/home/$(user)
  /code
    /$(project)     # <-- Your project goes here!
      /$(project)
        /uwsgi.py
  /virtualenvs
    /$(project)
  /logs
    /$(project)-uwsgi.log
    /emperor.log

/tmp/uwsgi/
  /$(project).sock  # SOCK file. Connection between nginx and uwsgi.

/etc/uwsgi/
  /apps-available/
    /$(project).ini
  /apps-enabled
    /$(project).ini  # (link to app-available/$project.ini)
```
