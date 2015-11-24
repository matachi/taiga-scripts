# Install on Fedora in Virtual Box

Tested with Fedora Server 23.

1. Download [Fedora Server Edition](https://getfedora.org/en/server/download).
2. Create and install Fedora on a virtual machine in VirtualBox.
3. Port forward the ports `3022 -> 22`, `8000 -> 8000` and `9000 -> 9000`.
4. Start the VM.
5. Copy the install script to the VM:
   `$ scp -P 3022 setup-fedora.sh [USER]@127.0.0.1:~`.
6. Connect to the VM: `$ ssh -p 3022 [USER]@127.0.0.1`.
7. Run the installation: `$ sudo bash setup-fedora.sh`.
8. Load the `taiga-runserver` function: `$ source .bash_profile`.
9. Start the server: `$ taiga-runserver`.
10. Visit <http://localhost:9000/> and sign in with username `admin` and
   password `123123`.
