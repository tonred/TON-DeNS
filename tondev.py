import argparse
import subprocess
import os

parser = argparse.ArgumentParser(description='Build solidity')

parser.add_argument('--tondev_executable', metavar='E', help='Tondev executable path', default='tondev')
parser.add_argument('--input_dir', help='Directory with smart contract')
parser.add_argument('--input_smc', help='Smart contract name')
parser.add_argument('--deploy', default=False)

args = parser.parse_args()

contract_path = args.input_dir + '/' + args.input_smc

exit_code = subprocess.call(
    [args.tondev_executable, 'sol', contract_path, '-l', 'js', '-L', 'deploy'],
    env=os.environ.copy())
if exit_code:
    exit(exit_code)

if args.deploy:
    subprocess.call(['node', 'deploy.js', contract_path])
