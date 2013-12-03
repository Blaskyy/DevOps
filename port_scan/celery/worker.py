#!/usr/bin/env python
# -*- coding: UTF-8 -*-
import time
import threading
import Queue
import json
import nmap
import pymongo
import urllib
from tasks import scanner

def getips():
    page=urllib.urlopen(open('../url', 'r').read())
    json_data=page.read()
    py_data=json.loads(json_data)
    ip_list=[]
    for i in py_data['ips']:
        ip_list.append(i['ip'])
    return ip_list

class Worker(threading.Thread):
    def __init__(self, dbc, queue):
        threading.Thread.__init__(self)
        self.queue = queue
        self.dbc=dbc
        self.start()

    def run(self):
        # keep working
        while True:
            # quit if empty
            if self.queue.empty():
                print 'queue empty!'
                break
            # get a ip
            ip = self.queue.get()
            # do work, print work
            #clean big port
            result=scanner.delay(ip)
            if result.failed():
                self.queue.put(ip)
                print "Failed to scan " + ip + ", Retry"
                self.queue.task_done()
                continue

            realports=[]
            try:
                ports=result.get()
                realports.extend(ports)
                for j in ports:
                    if j > 10000:
                        realports=[]
                        i=[]
                        i.append(ports)
                        time.sleep(300)
                        i.append(scanner(ip))
                        time.sleep(300)
                        i.append(scanner(ip))
                        tmp1=list(set(i.pop()) & set(i.pop()))
                        tmp2= list(set(i.pop()) & set(tmp1))
                        realports=tmp2
                        break
            except:
                self.queue.put(ip)
                print "Faild to get ports" + ip + ",Retry"
                self.queue.task_done()
                continue

            id=self.dbc.update({"ip":ip},{"$set":{"uptime":time.ctime(), "port":realports}},True,False)
            # task done
            self.queue.task_done()

if __name__ == '__main__':
    tStart = time.time()
    # Queue
    queue = Queue.Queue()
    dbc=pymongo.MongoClient().ips_ports.ips
    alldata=dbc.find()
    olds=[]
    for i in alldata:
        olds.append(i['ip'])
    # add works
    new=getips()
    for i in olds:
        if i not in new:
            dbc.remove({"ip":i})
    for i in new:
        queue.put(i)
    # start thread
    for i in range(20):
        threadName = 'Thread' + str(i)
        Worker(dbc, queue)
    # wait
    queue.join()
    tEnd = time.time()
    print "It cost %f sec" % (tEnd - tStart)
