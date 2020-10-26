#!/usr/bin/env python3

import socket
import subprocess
import time
from datetime import datetime, timedelta

s = socket.socket()


class Persist:
    opened: datetime


persist = Persist()


def destructing():
    subprocess.check_call(['terraform', 'destroy', '-auto-approve'])
    return wait_for_tunnel_open


def tunnel_opened():
    try:
        s.connect(('local-redirect', 8080))
        s.close()
        return tunnel_opened
    except socket.error:
        if datetime.now() - persist.opened > timedelta(minutes=5):
            return destructing


def tunnel_just_opened():
    persist.opened = datetime.now()
    return tunnel_opened


def wait_for_tunnel_open():
    try:
        s.connect(('local-redirect', 8080))
        s.close()
        return tunnel_just_opened
    except:
        time.sleep(1)


state = wait_for_tunnel_open

while True:
    state = state()
