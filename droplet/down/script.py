#!/usr/bin/env python3

import socket
import time

s = socket.socket()

while True:
    s.connect((''))
    time.sleep(1)
