#!/bin/bash

# Get the name of the user account, even if run with sudo
USER=`logname`
HOME=`eval echo ~$USER`

dnf -y update

dnf install -y postgresql-server postgresql-contrib postgresql-devel
systemctl enable postgresql
postgresql-setup --initdb
systemctl start postgresql
sudo -u postgres createuser --superuser $USER &> /dev/null
sudo -u postgres createdb taiga &> /dev/null

dnf group install -y "Development Tools"
dnf install -y redhat-rpm-config freetype-devel zlib-devel zeromq-devel gdbm-devel ncurses-devel libffi-devel
dnf install -y git tmux

dnf install -y python3-devel libxml2-devel libxslt-devel



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
sudo chown $USER:$USER /tmp/settings.py

if [ ! -e $HOME/taiga-back ]; then
    sudo -u $USER git clone https://github.com/taigaio/taiga-back.git taiga-back
    pushd $HOME/taiga-back
    sudo -u $USER git checkout -f stable

    sudo -u $USER mv /tmp/settings.py settings/local.py

    sudo -u $USER pyvenv env
    BIN=$HOME/taiga-back/env/bin

    sudo -u $USER $BIN/pip install -r requirements.txt
    sudo -u $USER $BIN/python manage.py migrate --noinput
    sudo -u $USER $BIN/python manage.py compilemessages
    sudo -u $USER $BIN/python manage.py collectstatic --noinput
    sudo -u $USER $BIN/python manage.py loaddata initial_user
    sudo -u $USER $BIN/python manage.py loaddata initial_project_templates
    sudo -u $USER $BIN/python manage.py loaddata initial_role
    sudo -u $USER $BIN/python manage.py sample_data

    popd
fi



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
sudo chown $USER:$USER /tmp/conf.json

if [ ! -e $HOME/taiga-front ]; then
    sudo -u $USER git clone https://github.com/taigaio/taiga-front-dist.git $HOME/taiga-front
    pushd $HOME/taiga-front
    sudo -u $USER git checkout -f stable
    sudo -u $USER mv /tmp/conf.json dist/js/
    popd
fi



firewall-cmd --add-port=8000/tcp
firewall-cmd --permanent --add-port=8000/tcp
firewall-cmd --add-port=9000/tcp
firewall-cmd --permanent --add-port=9000/tcp

cat > $HOME/.tmux-conf.sh <<EOF
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
    cd ~/taiga-back
    source env/bin/activate
    python manage.py runserver 0.0.0.0:8000
}
EOF
sudo chown $USER:$USER $HOME/.tmux-conf.sh

cat > $HOME/.bash_profile <<EOF
[[ -s "\$HOME/.tmux-conf.sh" ]] && source "\$HOME/.tmux-conf.sh"
EOF
sudo chown $USER:$USER $HOME/.bash_profile
