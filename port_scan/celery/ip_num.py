import socket

def isIP(ip):
    try:
        socket.inet_aton(ip)
        ip = True
    except socket.error:
        ip = False
    return ip

def isPort(port):
    try:
        i = int(port)
        if i > 0 and i <65536:
            return True
        else:
            return False
    except ValueError:
        return False

def ip2num(ipString):
    octets = [octet.strip() for octet in ipString.split('.')]
    num = (int(octets[0])<<24) + (int(octets[1])<<16) + (int(octets[2])<<8) + int(octets[3])
    return num

def num2ip(numericIp):
    return str(numericIp >> 24) + '.' + str((numericIp >> 16) & 255) + '.' + str((numericIp >> 8) & 255) + '.' + str(numericIp & 255)
