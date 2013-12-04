sudo pip install nodeenv  
https://pypi.python.org/pypi/nodeenv/

######Create new environment:
$ nodeenv env

######Activate new environment:
$ . env/bin/activate

######Chek versions of main packages:

(env) $ node -v  
v0.10.22  
(env) $ npm -v  
1.3.14

######Install requirements
(env) $ npm install -g coffee-script qjobs mongojs

######Start scan
(env) $ which coffee            #do some check  
(env) $ coffee scanner.coffee  
(env) $ time coffee scanner.coffee  #Timing

######Deactivate environment:
(env) $ deactivate_node
