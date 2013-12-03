#!/usr/bin/env python
# -*- coding: UTF-8 -*-
from gevent import monkey; monkey.patch_all()
from bottle import route, run, static_file, request, response, get, post, redirect
import json, ip_num
import pymongo

def get_data():
    client=pymongo.MongoClient()
    db=client.ips_ports
    dbc=db.ips
    all_content={}
    all_content['ips']=[]
    all_content['ips'].extend(dbc.find(fields={'_id': False}))
    return all_content

@route('/alarm/<ports_tmp>')
def alarm(ports_tmp):
    response.content_type = 'application/json'
    all_data = get_data()
    ports=[int(i) for i in ports_tmp.split('|')]
    white_list={}
    white_list['data']={}
    for i in all_data['ips']:
        content={}
        content[i['ip']]={}
        content[i['ip']]['status']=True
        content[i['ip']]['value']=[]
        for j in i['port']:
            if j not in ports:
                content[i['ip']]['value'].append(j)
        if content[i['ip']]['value'] != []:
            content[i['ip']]['status'] = False
        white_list['data']=dict(white_list['data'], **content)
    return json.dumps(white_list,
            sort_keys=True, indent=2, separators=(',', ': '))


@route('/result')
def result():
    response.content_type = 'application/json'
    return json.dumps(get_data(),
            sort_keys=True, indent=2, separators=(',', ': '))

@get('/filter')
def filter():
    return '''
    <center>
    <form action="/filter" method="post">
    IP  <input type="text" name="ips" />
    port <input type="text" name="ports" />
    <input type="submit" value="Filter" />
    </form>
    Usage:
    <p>只填写IP则返回该IP的端口信息,可填写格式为单个IP或IP段,如"192.168.1.1-192.168.1.255"</p>
    <p>只填写端口则返回开放该端口的IP列表,可填写格式为单个端口或端口段,如"22-53"</p>
    <p>若既填写IP也填写端口,则返回该IP段除了填写的端口之外开放的端口信息,可填写IP格式,单个IP或IP段,可填写端口格式为单个端口或用竖线"|"隔开的多个端口,如"22|80"</p>
    </center>
    '''
@post('/filter')
def do_filter():
    ip_tmp = request.forms.get('ips')
    port_tmp = request.forms.get('ports')
    if ip_tmp != '' and port_tmp == '':
        ips = ip_tmp.split('-')
        if len(ips) == 1:
            if ip_num.isIP(ips[0]):
                redirect("/filter_ip/%s/%s" % (ips[0],ips[0]))
            else:
                return 'Wrong IP'
        elif len(ips) == 2:
            if ip_num.isIP(ips[0]) & ip_num.isIP(ips[1]):
                redirect("/filter_ip/%s/%s" % (ips[0],ips[1]))
            else:
                return "Wrong IP"
        else:
            return 'Wrong IP'
    elif ip_tmp == '' and port_tmp != '':
        ports = port_tmp.split('-')
        if len(ports) ==1:
            if ip_num.isPort(ports[0]):
                redirect("/filter_port/%s/%s" % (ports[0],ports[0]))
            else:
                return 'Wrong port'
        elif len(ports) == 2:
            if ip_num.isPort(ports[0]) and ip_num.isPort(ports[1]):
                redirect("/filter_port/%s/%s" % (ports[0],ports[1]))
            else:
                return 'Wrong port'
        else:
            return 'Wrong port'

    elif ip_tmp != '' and port_tmp != '':
        redirect('/white_list/%s/%s' % (ip_tmp, port_tmp))
    else:
        return 'Wrong input'

@route('/filter_ip/<ip_from>/<ip_to>')
def do_filter_ip(ip_from, ip_to):
    #ip_from = request.forms.get('ip_from')
    #ip_to = request.forms.get('ip_to')
    json_data=get_data()
    response.content_type = 'application/json'

    #filter ip_range and return json data
    if ip_from != '' and ip_to != '':
        if ip_num.ip2num(ip_from)>ip_num.ip2num(ip_to):
            ip_from,ip_to=ip_to,ip_from
        if ip_from == ip_to:
            content={}
            content[ip_from]={}
            content[ip_from]['port']=[]
            for i in json_data['ips']:
                if i['ip']==ip_from:
                    content[ip_from]['port'].extend(i['port'])
            return json.dumps(content,
                    sort_keys=True, indent=2, separators=(',', ': '))

        ips_content={}
        ips_content['data']={}
        for ip in range(ip_num.ip2num(ip_from), ip_num.ip2num(ip_to)+1):
            content={}
            for i in json_data['ips']:
                if i['ip']==ip_num.num2ip(ip):
                    content[i['ip']]={}
                    content[i['ip']]['port']=[]
                    content[i['ip']]['port'].extend(i['port'])

                    ips_content['data']=dict(ips_content['data'], **content)

        return json.dumps(ips_content,
                sort_keys=True, indent=2, separators=(',', ': '))
    return "Wrong Input"

@route('/filter_port/<port_from>/<port_to>')
def do_filter_port(port_from, port_to):
    #port_from = request.forms.get('port_from')
    #port_to = request.forms.get('port_to')
    json_data=get_data()
    response.content_type = 'application/json'

    #filter port_range and return json data
    if port_from != '' and port_to != '':
        if int(port_from)>int(port_to):
            port_from,port_to=port_to,port_from
        if port_from == port_to:
            content={}
            content[int(port_from)]=[]
            for i in json_data['ips']:
                for j in i['port']:
                    if j==int(port_from):
                        content[int(port_from)].append(i['ip'])
            return json.dumps(content,
                    sort_keys=True, indent=2, separators=(',', ': '))

        ports_content={}
        ports_content['data']={}
        for port in range(int(port_from), int(port_to)+1):
            content={}
            content[port]=[]
            for i in json_data['ips']:
                for j in i['port']:
                    if j==int(port):
                        content[j].append(i['ip'])
            if content[port] == []:
                continue
            ports_content['data']=dict(ports_content['data'], **content)
        return json.dumps(ports_content,
                sort_keys=True, indent=2, separators=(',', ': '))
    return "Wrong Input"

@route('/white_list/<ips_tmp>/<ports_tmp>')
def do_white_list(ips_tmp, ports_tmp):
    #ips_tmp=request.forms.get('ips')
    #ports_tmp=request.forms.get('ports')
    json_data=get_data()
    response.content_type = 'application/json'
    white_list={}
    white_list['data']={}
    if ips_tmp!='' and ports_tmp!='':
        ips=ips_tmp.split('-')
        ports=[int(i) for i in ports_tmp.split('|')]
        if len(ips)==1:
            if ip_num.isIP(ips[0]) == False:
                return 'Wrong IP'
            content={}
            content['ip']=ips[0]
            content['port']=[]
            for i in json_data['ips']:
                if i['ip']==ips[0]:
                    for j in i['port']:
                        if j not in ports:
                            content['port'].append(j)
            return json.dumps(content,
                    sort_keys=True, indent=2, separators=(',', ': '))

        if False == (ip_num.isIP(ips[0]) and ip_num.isIP(ips[1])):
            return 'Wrong IP'
        if ip_num.ip2num(ips[0])>ip_num.ip2num(ips[1]):
            ips[0],ips[1]=ips[1],ips[0]
        for ip in range(ip_num.ip2num(ips[0]),ip_num.ip2num(ips[1]) + 1):
            for i in json_data['ips']:
                if i['ip']==ip_num.num2ip(ip):
                    content={}
                    content[i['ip']]={}
                    content[i['ip']]['port']=[]
                    for j in i['port']:
                        if j not in ports:
                            content[i['ip']]['port'].append(j)
                    white_list['data']=dict(white_list['data'], **content)
        return json.dumps(white_list,
                sort_keys=True, indent=2, separators=(',', ': '))
    return "Wrong Input"


if __name__ == '__main__':
    run(host='0.0.0.0', port=8080, server='gevent', debug=True, reloader=True)


