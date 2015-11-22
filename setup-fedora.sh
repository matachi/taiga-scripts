#!/bin/bash

sudo dnf -y update

sudo dnf install -y postgresql-server postgresql-contrib postgresql-devel
sudo systemctl enable postgresql
sudo postgresql-setup --initdb
sudo systemctl start postgresql
sudo -u postgres createuser --superuser $USER &> /dev/null
sudo -u postgres createdb taiga &> /dev/null

sudo dnf group install -y "Development Tools"
sudo dnf install -y redhat-rpm-config freetype-devel zlib-devel zeromq-devel gdbm-devel ncurses-devel libffi-devel
sudo dnf install -y git tmux

sudo dnf install -y python3-devel python-virtualenvwrapper libxml2-devel libxslt-devel
source /usr/bin/virtualenvwrapper.sh



pushd ~
cat > /tmp/settings.py <<EOF
from .common import *

MEDIA_URL = "/media/"
STATIC_URL = "/static/"

# This should change if you want generate urls in emails
# for external dns.
SITES["front"]["domain"] = "localhost:8000"

DEBUG = True
PUBLIC_REGISTER_ENABLED = True

DEFAULT_FROM_EMAIL = "no-reply@example.com"
SERVER_EMAIL = DEFAULT_FROM_EMAIL

#EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
#EMAIL_USE_TLS = False
#EMAIL_HOST = "localhost"
#EMAIL_HOST_USER = ""
#EMAIL_HOST_PASSWORD = ""
#EMAIL_PORT = 25

EOF

if [ ! -e ~/taiga-back ]; then
    git clone https://github.com/taigaio/taiga-back.git taiga-back
    pushd ~/taiga-back
    git checkout -f stable

    mv /tmp/settings.py settings/local.py

    mkvirtualenv taiga -p /usr/bin/python3.4
    workon taiga

    pip install -r requirements.txt
    python manage.py migrate --noinput
    python manage.py compilemessages
    python manage.py collectstatic --noinput
    python manage.py loaddata initial_user
    python manage.py loaddata initial_project_templates
    python manage.py loaddata initial_role
    python manage.py sample_data

    deactivate
    popd
fi
popd



pushd ~
cat > /tmp/conf.json <<EOF
{
    "api": "http://localhost:8000/api/v1/",
    "eventsUrl": null,
    "debug": "true",
    "publicRegisterEnabled": true,
    "feedbackEnabled": false,
    "privacyPolicyUrl": null,
    "termsOfServiceUrl": null,
    "maxUploadFileSize": null,
    "gitHubClientId": null,
    "contribPlugins": []
}
EOF

if [ ! -e ~/taiga-front ]; then
    git clone https://github.com/taigaio/taiga-front-dist.git taiga-front
    pushd ~/taiga-front
    git checkout -f stable
    mv /tmp/conf.json dist/js/
    popd
fi
popd



sudo firewall-cmd --add-port=8000/tcp
sudo firewall-cmd --permanent --add-port=8000/tcp
sudo firewall-cmd --add-port=9000/tcp
sudo firewall-cmd --permanent --add-port=9000/tcp

pushd ~
cat > ~/.tmux-conf.sh <<EOF
function taiga-runserver {
    session=taiga
    tmux new-session -ds \$session -n servers
    tmux send-keys -t \$session 'taiga-runserver-front' C-m
    tmux split-window -t \$session
    tmux send-keys -t \$session 'taiga-runserver-back' C-m
    tmux attach -t \$session
}

function taiga-runserver-front {
    cd ~/taiga-front/dist
    python3 -m http.server 9000
}

function taiga-runserver-back {
    workon taiga
    cd ~/taiga-back
    python manage.py runserver 0.0.0.0:8000
}
EOF

cat > ~/.bash_profile <<EOF
[[ -s "\$HOME/.tmux-conf.sh" ]] && source "\$HOME/.tmux-conf.sh"
EOF
popd
