from celery import Celery,platforms
import nmap
import json

#Specify mongodb host and datababse to connect to
BROKER_URL = 'mongodb://localhost:27017/celery'
platforms.C_FORCE_ROOT = True

celery = Celery('EOD_TASKS',broker=BROKER_URL)

#Loads settings for Backend to store results of jobs
celery.config_from_object('celeryconfig')

SCAN_ARGVS='-sS -sU -P0'

@celery.task
def add(x, y):
    time.sleep(30)
    return x + y

@celery.task
def scanner(ip):
    nm = nmap.PortScanner()
    nm.scan(hosts=ip, arguments=SCAN_ARGVS, sudo=True)
    content=[]
    for host in nm.all_hosts():
        for proto in nm[host].all_protocols():
            if proto == 'addresses':
                continue
            lport = list(nm[host][proto].keys())
            for port in lport:
                if nm[host][proto][port]['state'] == 'open':
                    content.append(port)
    return content
