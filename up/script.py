#!/usr/bin/env python3
import os
import subprocess
import sys
from signal import signal, SIGTERM

redirect_from = sys.argv[1]
redirect_to = sys.argv[2]

subprocess.check_call(
    ['terraform', 'apply', '-auto-approve'],
    env={
        'TF_VAR_email': os.environ['EMAIL'],
        'TF_VAR_digitalocean_api_token': os.environ['DIGITALOCEAN_API_TOKEN'],
        'TF_VAR_domain_record': redirect_from,
    })

ssh_process = subprocess.Popen([
    '/app/up/tunnel.sh'
],
    env={
        'REDIRECT_TO': redirect_to
    })


def handler(signal_received, frame):
    # Handle any cleanup here
    print('signal detected.')
    # os.system('terraform destroy -auto-approve')
    exit(0)


if __name__ == '__main__':
    signal(SIGTERM, handler)
    ssh_process.wait()
    while True:
        pass
